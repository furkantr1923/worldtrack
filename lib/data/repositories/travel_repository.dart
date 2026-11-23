import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/utils/dates.dart';
import '../data_events.dart';
import '../models/models.dart';
import 'country_repository.dart';

/// Seyahat kayıtları ve fotoğrafları.
class TravelRepository {
  TravelRepository(this._db, this._events, this._countries);

  final Database _db;
  final DataEvents _events;
  final CountryRepository _countries;

  static const _select = '''
    SELECT r.*,
      c.id AS c_id, c.country_code AS c_country_code, c.name_tr AS c_name_tr, c.name AS c_name,
      c.admin1 AS c_admin1, c.lat AS c_lat, c.lon AS c_lon, c.population AS c_population,
      c.is_capital AS c_is_capital, c.is_custom AS c_is_custom,
      (SELECT COUNT(*) FROM travel_photos p WHERE p.record_id = r.id) AS photo_count,
      (SELECT p.thumb_path FROM travel_photos p WHERE p.record_id = r.id
         ORDER BY p.sort_order, p.id LIMIT 1) AS cover_thumb
    FROM travel_records r
    JOIN cities c ON c.id = r.city_id
  ''';

  TravelRecord _map(Map<String, Object?> row) {
    final r = TravelRecord.fromRow(row);
    return r.withCountry(_countries.byCode(r.countryCode));
  }

  /// Kayıtları tarihe göre (yeniden eskiye) listeler.
  Future<List<TravelRecord>> list({String? countryCode, int? cityId, int? limit}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (countryCode != null) {
      where.add('r.country_code = ?');
      args.add(countryCode);
    }
    if (cityId != null) {
      where.add('r.city_id = ?');
      args.add(cityId);
    }
    final sql = '$_select'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
        ' ORDER BY r.visit_date DESC, r.id DESC'
        '${limit != null ? ' LIMIT $limit' : ''}';
    final rows = await _db.rawQuery(sql, args);
    return rows.map(_map).toList();
  }

  Future<TravelRecord?> byId(int id) async {
    final rows = await _db.rawQuery('$_select WHERE r.id = ?', [id]);
    return rows.isEmpty ? null : _map(rows.first);
  }

  /// Takvim için: [from]–[to] aralığıyla kesişen kayıtlar.
  Future<List<TravelRecord>> inRange(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      "$_select WHERE r.visit_date <= ? AND date(r.visit_date, '+' || (r.duration_days - 1) || ' days') >= ? "
      'ORDER BY r.visit_date',
      [Dates.toDb(to), Dates.toDb(from)],
    );
    return rows.map(_map).toList();
  }

  /// Aynı şehir için aynı tarihte kayıt var mı? (Yanlışlıkla çift kayıt uyarısı için.)
  Future<bool> hasDuplicate(int cityId, DateTime date, {int? excludeId}) async {
    final rows = await _db.rawQuery(
      'SELECT 1 FROM travel_records WHERE city_id = ? AND visit_date = ?'
      '${excludeId != null ? ' AND id <> ?' : ''} LIMIT 1',
      [cityId, Dates.toDb(date), if (excludeId != null) excludeId],
    );
    return rows.isNotEmpty;
  }

  String? validate(TravelRecord r) {
    if (r.durationDays < 1) return 'Süre en az 1 gün olmalı.';
    if (r.durationDays > 3650) return 'Süre 3650 günden uzun olamaz.';
    if (r.visitDate.isAfter(Dates.today())) {
      return 'Gelecekteki seyahatler için plan oluşturun; seyahat kaydı geçmiş bir tarih olmalı.';
    }
    if (r.notes.length > 2000) return 'Not en fazla 2000 karakter olabilir.';
    return null;
  }

  Future<int> insert(TravelRecord r) async {
    final error = validate(r);
    if (error != null) throw ArgumentError(error);
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('travel_records', {...r.toRow(), 'created_at': now, 'updated_at': now});
    _events.emit(DataChange.travels);
    return id;
  }

  Future<void> update(TravelRecord r) async {
    if (r.id == null) throw ArgumentError('Kayıt kimliği yok');
    final error = validate(r);
    if (error != null) throw ArgumentError(error);
    await _db.update('travel_records', {...r.toRow(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [r.id]);
    _events.emit(DataChange.travels);
  }

  /// Kaydı ve ona bağlı fotoğraf dosyalarını siler. Masraflar veritabanında
  /// ON DELETE CASCADE ile birlikte silinir.
  Future<void> delete(int id) async {
    final photos = await _db.query('travel_photos', where: 'record_id = ?', whereArgs: [id]);
    await _db.delete('travel_records', where: 'id = ?', whereArgs: [id]);
    for (final p in photos) {
      await _deleteFile(p['file_path'] as String?);
      await _deleteFile(p['thumb_path'] as String?);
    }
    _events.emit(DataChange.travels);
  }

  /// İstatistikler gerçek kayıtlardan hesaplanır:
  /// * Ülke: kayıtlı veya elle işaretlenmiş farklı ülke sayısı.
  /// * Şehir: farklı şehir sayısı — aynı şehre yapılan tekrar ziyaretler bir kez sayılır.
  Future<TravelStats> stats() async {
    final countries = await _db.rawQuery('''
      SELECT COUNT(*) AS n FROM (
        SELECT country_code FROM travel_records
        UNION
        SELECT code FROM countries WHERE manual_visited = 1
      )
    ''');
    final cities = await _db.rawQuery('SELECT COUNT(DISTINCT city_id) AS n FROM travel_records');
    return TravelStats(
      visitedCountries: (countries.first['n'] as int?) ?? 0,
      visitedCities: (cities.first['n'] as int?) ?? 0,
    );
  }

  /// Bir ülkede ziyaret edilen şehirler ve ziyaret sayıları.
  Future<List<({City city, int visits})>> visitedCities(String countryCode) async {
    final rows = await _db.rawQuery('''
      SELECT c.id, c.country_code, c.name_tr, c.name, c.admin1, c.lat, c.lon, c.population,
             c.is_capital, c.is_custom, COUNT(*) AS visits, MAX(r.visit_date) AS last_visit
      FROM travel_records r JOIN cities c ON c.id = r.city_id
      WHERE r.country_code = ?
      GROUP BY c.id ORDER BY last_visit DESC
    ''', [countryCode]);
    return rows.map((r) => (city: City.fromRow(r), visits: r['visits'] as int)).toList();
  }

  // ---------------------------------------------------------------- fotoğraflar

  Future<List<TravelPhoto>> photos(int recordId) async {
    final rows = await _db.query('travel_photos',
        where: 'record_id = ?', whereArgs: [recordId], orderBy: 'sort_order, id');
    return rows.map(TravelPhoto.fromRow).toList();
  }

  Future<int> addPhoto({
    required int recordId,
    required String filePath,
    required String thumbPath,
    String originalName = '',
    int? width,
    int? height,
  }) async {
    final maxRow = await _db.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS m FROM travel_photos WHERE record_id = ?', [recordId]);
    final id = await _db.insert('travel_photos', {
      'record_id': recordId,
      'file_path': filePath,
      'thumb_path': thumbPath,
      'original_name': originalName,
      'width': width,
      'height': height,
      'sort_order': (maxRow.first['m'] as int) + 1,
      'added_at': DateTime.now().toIso8601String(),
    });
    _events.emit(DataChange.photos);
    return id;
  }

  Future<void> removePhoto(TravelPhoto photo) async {
    await _db.delete('travel_photos', where: 'id = ?', whereArgs: [photo.id]);
    await _deleteFile(photo.filePath);
    if (photo.thumbPath != photo.filePath) await _deleteFile(photo.thumbPath);
    _events.emit(DataChange.photos);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Dosya zaten yoksa veya erişilemiyorsa kayıt silme işlemi yine tamamlanır.
    }
  }
}
