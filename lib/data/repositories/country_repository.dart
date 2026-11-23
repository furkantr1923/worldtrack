import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/utils/turkish_text.dart';
import '../data_events.dart';
import '../models/models.dart';

/// Ülke listesi bellekte tutulur (≈250 kayıt); ziyaret/plan durumu veritabanından hesaplanır.
class CountryRepository {
  CountryRepository(this._db, this._events);

  final Database _db;
  final DataEvents _events;

  final Map<String, Country> _byCode = {};
  final Map<String, String> _searchKeys = {};
  List<Country> _sorted = const [];

  List<Country> get all => _sorted;

  Country? byCode(String code) => _byCode[code];

  Future<void> load() async {
    final rows = await _db.query('countries');
    _byCode.clear();
    _searchKeys.clear();
    for (final r in rows) {
      final c = Country.fromRow(r);
      _byCode[c.code] = c;
      _searchKeys[c.code] = r['search_key'] as String;
    }
    _sorted = _byCode.values.toList()..sort((a, b) => TurkishText.compare(a.nameTr, b.nameTr));
  }

  /// Ada, İngilizce ada veya ISO koduna göre arama. Ad başında eşleşenler öne gelir.
  List<Country> search(String query, {int limit = 30}) {
    final q = TurkishText.fold(query);
    if (q.isEmpty) return _sorted.take(limit).toList();
    final starts = <Country>[], contains = <Country>[];
    for (final c in _sorted) {
      final key = _searchKeys[c.code] ?? '';
      if (key.startsWith(q) || key.contains(' $q')) {
        starts.add(c);
      } else if (key.contains(q)) {
        contains.add(c);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  /// Ziyaret edilmiş ülkeler: geçmiş seyahat kaydı olanlar + elle işaretlenenler.
  /// Bir ülke kaç kez ziyaret edilirse edilsin bir kez sayılır.
  Future<Set<String>> visitedCodes() async {
    final rows = await _db.rawQuery('''
      SELECT country_code AS code FROM travel_records
      UNION
      SELECT code FROM countries WHERE manual_visited = 1
    ''');
    return rows.map((r) => r['code'] as String).toSet();
  }

  /// Tamamlanmamış planlarda durak olarak geçen ülkeler.
  Future<Set<String>> plannedCodes() async {
    final rows = await _db.rawQuery('''
      SELECT DISTINCT s.country_code AS code
      FROM trip_stops s JOIN planned_trips t ON t.id = s.trip_id
      WHERE t.status = 'planned'
    ''');
    return rows.map((r) => r['code'] as String).toSet();
  }

  Future<bool> hasTravelRecords(String code) async {
    final r = await _db.rawQuery('SELECT 1 FROM travel_records WHERE country_code = ? LIMIT 1', [code]);
    return r.isNotEmpty;
  }

  Future<void> setManualVisited(String code, bool visited) async {
    await _db.update('countries', {'manual_visited': visited ? 1 : 0},
        where: 'code = ?', whereArgs: [code]);
    final rows = await _db.query('countries', where: 'code = ?', whereArgs: [code]);
    if (rows.isNotEmpty) {
      _byCode[code] = Country.fromRow(rows.first);
      _sorted = _byCode.values.toList()..sort((a, b) => TurkishText.compare(a.nameTr, b.nameTr));
    }
    _events.emit(DataChange.countries);
  }
}
