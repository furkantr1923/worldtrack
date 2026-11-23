import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/utils/turkish_text.dart';
import '../data_events.dart';
import '../models/models.dart';

class CityRepository {
  CityRepository(this._db, this._events);

  final Database _db;
  final DataEvents _events;

  /// Elle eklenen şehirlerin kimlikleri bu değerden başlar; GeoNames kimlikleriyle çakışmaz.
  static const int customIdBase = 1000000000;

  static const _columns =
      'id, country_code, name_tr, name, admin1, lat, lon, population, is_capital, is_custom';

  Future<City?> byId(int id) async {
    final rows = await _db.rawQuery('SELECT $_columns FROM cities WHERE id = ?', [id]);
    return rows.isEmpty ? null : City.fromRow(rows.first);
  }

  /// Türkçe karakter duyarsız şehir araması. Ad başı eşleşmeler ve büyük şehirler önce gelir.
  Future<List<City>> search(String query, {String? countryCode, int limit = 40}) async {
    final q = TurkishText.fold(query);
    final where = <String>[];
    final args = <Object?>[];
    if (q.isNotEmpty) {
      where.add('search_key LIKE ?');
      args.add('%$q%');
    }
    if (countryCode != null) {
      where.add('country_code = ?');
      args.add(countryCode);
    }
    final order = q.isEmpty
        ? 'is_capital DESC, population DESC'
        : "CASE WHEN search_key LIKE ? THEN 0 WHEN search_key LIKE ? THEN 1 ELSE 2 END, population DESC";
    if (q.isNotEmpty) args.addAll(['$q%', '% $q%']);
    final sql = 'SELECT $_columns FROM cities'
        '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
        ' ORDER BY $order LIMIT ?';
    args.add(limit);
    final rows = await _db.rawQuery(sql, args);
    return rows.map(City.fromRow).toList();
  }

  Future<List<City>> topCities(String countryCode, {int limit = 8}) async {
    final rows = await _db.rawQuery(
      'SELECT $_columns FROM cities WHERE country_code = ? AND is_custom = 0 '
      'ORDER BY population DESC LIMIT ?',
      [countryCode, limit],
    );
    return rows.map(City.fromRow).toList();
  }

  Future<City?> findByName(String countryCode, String name) async {
    final key = TurkishText.fold(name);
    final rows = await _db.rawQuery(
      'SELECT $_columns FROM cities WHERE country_code = ? AND '
      '(search_key = ? OR search_key LIKE ?) ORDER BY is_custom ASC, population DESC LIMIT 1',
      [countryCode, key, '$key %'],
    );
    return rows.isEmpty ? null : City.fromRow(rows.first);
  }

  /// Listede bulunamayan bir şehri kullanıcı adıyla ekler. Koordinat isteğe bağlıdır;
  /// verilmezse uydurulmaz, şehir haritada nokta olarak gösterilmez.
  Future<City> addCustom({
    required String countryCode,
    required String name,
    String admin1 = '',
    double? lat,
    double? lon,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Şehir adı boş olamaz');
    if ((lat == null) != (lon == null)) throw ArgumentError('Enlem ve boylam birlikte girilmeli');
    if (lat != null && (lat < -90 || lat > 90)) throw ArgumentError('Enlem -90 ile 90 arasında olmalı');
    if (lon != null && (lon < -180 || lon > 180)) throw ArgumentError('Boylam -180 ile 180 arasında olmalı');
    final existing = await _db.rawQuery(
      'SELECT $_columns FROM cities WHERE country_code = ? AND search_key = ? AND is_custom = 1',
      [countryCode, TurkishText.fold(trimmed)],
    );
    if (existing.isNotEmpty) return City.fromRow(existing.first);

    final maxRow = await _db.rawQuery('SELECT MAX(id) AS m FROM cities WHERE id >= ?', [customIdBase]);
    final id = ((maxRow.first['m'] as int?) ?? (customIdBase - 1)) + 1;
    await _db.insert('cities', {
      'id': id,
      'country_code': countryCode,
      'name_tr': trimmed,
      'name': trimmed,
      'ascii': trimmed,
      'admin1': admin1.trim(),
      'lat': lat,
      'lon': lon,
      'population': 0,
      'is_capital': 0,
      'is_custom': 1,
      'search_key': TurkishText.fold('$trimmed ${admin1.trim()}'),
    });
    _events.emit(DataChange.cities);
    return (await byId(id))!;
  }
}
