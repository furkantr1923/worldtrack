import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/utils/dates.dart';
import '../data_events.dart';
import '../models/models.dart';
import 'country_repository.dart';

/// Gelecek seyahat planları, durakları ve plan → seyahat kaydı dönüşümü.
class PlanRepository {
  PlanRepository(this._db, this._events, this._countries);

  final Database _db;
  final DataEvents _events;
  final CountryRepository _countries;

  Future<List<PlannedTrip>> list({PlanStatus? status}) async {
    final rows = await _db.query(
      'planned_trips',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: status == PlanStatus.completed ? 'start_date DESC, id DESC' : 'start_date ASC, id ASC',
    );
    return _withStops(rows);
  }

  Future<PlannedTrip?> byId(int id) async {
    final rows = await _db.query('planned_trips', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return (await _withStops(rows)).first;
  }

  /// Takvim için: aralıkla kesişen planlar.
  Future<List<PlannedTrip>> inRange(DateTime from, DateTime to) async {
    final rows = await _db.query('planned_trips',
        where: 'start_date <= ?', whereArgs: [Dates.toDb(to)], orderBy: 'start_date');
    final trips = await _withStops(rows);
    return trips.where((t) => !t.effectiveEnd.isBefore(from)).toList();
  }

  Future<List<PlannedTrip>> forCountry(String code) async {
    final rows = await _db.rawQuery('''
      SELECT DISTINCT t.* FROM planned_trips t JOIN trip_stops s ON s.trip_id = t.id
      WHERE s.country_code = ? ORDER BY t.start_date
    ''', [code]);
    return _withStops(rows);
  }

  Future<List<PlannedTrip>> _withStops(List<Map<String, Object?>> tripRows) async {
    if (tripRows.isEmpty) return const [];
    final ids = tripRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final stopRows = await _db.rawQuery('''
      SELECT s.*, c.id AS c_id, c.country_code AS c_country_code, c.name_tr AS c_name_tr,
        c.name AS c_name, c.admin1 AS c_admin1, c.lat AS c_lat, c.lon AS c_lon,
        c.population AS c_population, c.is_capital AS c_is_capital, c.is_custom AS c_is_custom
      FROM trip_stops s LEFT JOIN cities c ON c.id = s.city_id
      WHERE s.trip_id IN ($placeholders)
      ORDER BY s.trip_id, s.order_index
    ''', ids);
    final byTrip = <int, List<TripStop>>{};
    for (final r in stopRows) {
      final code = r['country_code'] as String;
      byTrip.putIfAbsent(r['trip_id'] as int, () => []).add(TripStop(
            id: r['id'] as int,
            countryCode: code,
            cityId: r['city_id'] as int?,
            durationDays: r['duration_days'] as int?,
            transport: TransportType.fromDb(r['transport'] as String?),
            arrivalDate: Dates.tryFromDb(r['arrival_date'] as String?),
            city: r['c_id'] != null ? City.fromRow(r, prefix: 'c_') : null,
            country: _countries.byCode(code),
          ));
    }
    return tripRows
        .map((r) => PlannedTrip(
              id: r['id'] as int,
              title: r['title'] as String,
              startDate: Dates.fromDb(r['start_date'] as String),
              endDate: Dates.tryFromDb(r['end_date'] as String?),
              notes: (r['notes'] as String?) ?? '',
              status: r['status'] == 'completed' ? PlanStatus.completed : PlanStatus.planned,
              stops: byTrip[r['id'] as int] ?? const [],
            ))
        .toList();
  }

  String? validate(PlannedTrip t) {
    if (t.title.trim().isEmpty) return 'Plan adı boş olamaz.';
    if (t.title.trim().length > 120) return 'Plan adı en fazla 120 karakter olabilir.';
    if (t.endDate != null && t.endDate!.isBefore(t.startDate)) {
      return 'Bitiş tarihi başlangıç tarihinden önce olamaz.';
    }
    for (final s in t.stops) {
      if (s.durationDays != null && (s.durationDays! < 1 || s.durationDays! > 3650)) {
        return 'Durak süresi 1–3650 gün arasında olmalı.';
      }
    }
    return null;
  }

  /// Planı ve duraklarını tek işlemde kaydeder; durak sırası listedeki sıradır.
  Future<int> save(PlannedTrip t) async {
    final error = validate(t);
    if (error != null) throw ArgumentError(error);
    final now = DateTime.now().toIso8601String();
    final values = {
      'title': t.title.trim(),
      'start_date': Dates.toDb(t.startDate),
      'end_date': t.endDate == null ? null : Dates.toDb(t.endDate!),
      'notes': t.notes.trim().isEmpty ? null : t.notes.trim(),
      'updated_at': now,
    };
    final id = await _db.transaction<int>((txn) async {
      int tripId;
      if (t.id == null) {
        tripId = await txn.insert('planned_trips', {...values, 'status': 'planned', 'created_at': now});
      } else {
        tripId = t.id!;
        await txn.update('planned_trips', values, where: 'id = ?', whereArgs: [tripId]);
        await txn.delete('trip_stops', where: 'trip_id = ?', whereArgs: [tripId]);
      }
      for (var i = 0; i < t.stops.length; i++) {
        final s = t.stops[i];
        await txn.insert('trip_stops', {
          'trip_id': tripId,
          'order_index': i,
          'country_code': s.countryCode,
          'city_id': s.cityId,
          'arrival_date': s.arrivalDate == null ? null : Dates.toDb(s.arrivalDate!),
          'duration_days': s.durationDays,
          'transport': s.transport?.name,
        });
      }
      return tripId;
    });
    _events.emit(DataChange.plans);
    return id;
  }

  Future<void> delete(int id) async {
    await _db.delete('planned_trips', where: 'id = ?', whereArgs: [id]);
    _events.emit(DataChange.plans);
  }

  /// Planın duraklarından seyahat kayıtları için önerilen tarihleri hesaplar.
  /// Durakta varış tarihi varsa o kullanılır; yoksa plan başlangıcından
  /// önceki durakların süreleri toplanarak bulunur.
  List<TravelRecord> draftRecords(PlannedTrip t) {
    final out = <TravelRecord>[];
    var cursor = t.startDate;
    for (final s in t.stops) {
      final date = s.arrivalDate ?? cursor;
      final days = s.durationDays ?? 1;
      if (s.cityId != null) {
        out.add(TravelRecord(
          countryCode: s.countryCode,
          cityId: s.cityId!,
          visitDate: date,
          durationDays: days,
          transport: s.transport,
          planId: t.id,
          city: s.city,
          country: s.country,
        ));
      }
      cursor = DateTime(date.year, date.month, date.day + days);
    }
    return out;
  }

  /// Tamamlanan planı seyahat kayıtlarına dönüştürür (tek işlem: ya hepsi ya hiçbiri).
  Future<List<int>> convertToRecords(int planId, List<TravelRecord> records) async {
    if (records.isEmpty) throw ArgumentError('Dönüştürülecek durak yok.');
    final today = Dates.today();
    for (final r in records) {
      if (r.visitDate.isAfter(today)) {
        throw ArgumentError('${r.city?.nameTr ?? 'Durak'} için tarih gelecekte; önce tarihleri düzenleyin.');
      }
      if (r.durationDays < 1) throw ArgumentError('Süre en az 1 gün olmalı.');
    }
    final now = DateTime.now().toIso8601String();
    final ids = await _db.transaction<List<int>>((txn) async {
      final ids = <int>[];
      for (final r in records) {
        ids.add(await txn.insert('travel_records', {
          ...r.toRow(),
          'plan_id': planId,
          'created_at': now,
          'updated_at': now,
        }));
      }
      await txn.update('planned_trips', {'status': 'completed', 'completed_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [planId]);
      return ids;
    });
    _events.emit(DataChange.plans);
    _events.emit(DataChange.travels);
    return ids;
  }

  /// Tamamlanan planı tekrar "planlandı" durumuna alır (oluşan kayıtlar silinmez).
  Future<void> reopen(int planId) async {
    await _db.update('planned_trips', {'status': 'planned', 'completed_at': null},
        where: 'id = ?', whereArgs: [planId]);
    _events.emit(DataChange.plans);
  }
}
