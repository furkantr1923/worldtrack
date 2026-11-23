import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/utils/turkish_text.dart';
import 'migrations.dart';

/// Yerel SQLite veritabanı.
///
/// * Şema [Migrations] ile sürümlenir; her yükseltme sırayla uygulanır.
/// * Yabancı anahtarlar her bağlantıda açılır (PRAGMA foreign_keys = ON).
/// * Ülke ve şehir verileri uygulamayla gelen dosyalardan ilk açılışta yüklenir;
///   veri sürümü değişirse kullanıcı kayıtlarına dokunmadan güncellenir.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// Paketlenen coğrafi verinin sürümü. Veri dosyaları değiştiğinde artırılır.
  static const int geoDataVersion = 1;

  static bool _ffiReady = false;

  static Future<AppDatabase> open(
    String path, {
    AssetBundle? bundle,
    void Function(String message)? onProgress,
  }) async {
    if (!_ffiReady) {
      sqfliteFfiInit();
      _ffiReady = true;
    }
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: Migrations.latestVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await Migrations.create(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await Migrations.upgrade(db, oldVersion, newVersion);
        },
      ),
    );
    final appDb = AppDatabase._(db);
    await appDb._seedGeoDataIfNeeded(bundle ?? rootBundle, onProgress);
    return appDb;
  }

  Future<void> close() => db.close();

  Future<void> _seedGeoDataIfNeeded(AssetBundle bundle, void Function(String)? onProgress) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['geo_data_version']);
    final current = rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
    if (current >= geoDataVersion) return;

    onProgress?.call('Ülke verileri hazırlanıyor…');
    final countriesJson = await bundle.loadString('assets/data/countries.json');
    final citiesGz = await bundle.load('assets/data/cities.tsv.gz');
    final gzBytes = citiesGz.buffer.asUint8List(citiesGz.offsetInBytes, citiesGz.lengthInBytes);

    final parsed = await Isolate.run(() => _parseGeoData(countriesJson, gzBytes));

    onProgress?.call('Şehir veritabanı hazırlanıyor…');
    await db.transaction((txn) async {
      var batch = txn.batch();
      for (final c in parsed.countries) {
        batch.rawInsert('''
          INSERT INTO countries (code, iso3, name_tr, name_en, region, subregion, continent, type,
            capital_tr, capital_en, capital_city_id, population, area_km2, currency, currency_name,
            wikidata, has_shape, label_lat, label_lon, min_label, search_key)
          VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
          ON CONFLICT(code) DO UPDATE SET
            iso3=excluded.iso3, name_tr=excluded.name_tr, name_en=excluded.name_en,
            region=excluded.region, subregion=excluded.subregion, continent=excluded.continent,
            type=excluded.type, capital_tr=excluded.capital_tr, capital_en=excluded.capital_en,
            capital_city_id=excluded.capital_city_id, population=excluded.population,
            area_km2=excluded.area_km2, currency=excluded.currency,
            currency_name=excluded.currency_name, wikidata=excluded.wikidata,
            has_shape=excluded.has_shape, label_lat=excluded.label_lat,
            label_lon=excluded.label_lon, min_label=excluded.min_label,
            search_key=excluded.search_key
        ''', c);
      }
      await batch.commit(noResult: true);

      batch = txn.batch();
      var n = 0;
      for (final c in parsed.cities) {
        batch.rawInsert('''
          INSERT INTO cities (id, country_code, name_tr, name, ascii, admin1, lat, lon,
            population, is_capital, is_custom, search_key)
          VALUES (?,?,?,?,?,?,?,?,?,?,0,?)
          ON CONFLICT(id) DO UPDATE SET
            country_code=excluded.country_code, name_tr=excluded.name_tr, name=excluded.name,
            ascii=excluded.ascii, admin1=excluded.admin1, lat=excluded.lat, lon=excluded.lon,
            population=excluded.population, is_capital=excluded.is_capital,
            search_key=excluded.search_key
        ''', c);
        if (++n % 5000 == 0) {
          await batch.commit(noResult: true);
          batch = txn.batch();
        }
      }
      await batch.commit(noResult: true);
      await txn.insert('settings', {'key': 'geo_data_version', 'value': '$geoDataVersion'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

class _ParsedGeo {
  _ParsedGeo(this.countries, this.cities);
  final List<List<Object?>> countries;
  final List<List<Object?>> cities;
}

_ParsedGeo _parseGeoData(String countriesJson, Uint8List citiesGz) {
  final countries = <List<Object?>>[];
  for (final raw in (jsonDecode(countriesJson) as List)) {
    final c = raw as Map<String, dynamic>;
    final aliases = ((c['aliases'] as List?) ?? const []).join(' ');
    final key = TurkishText.fold('${c['nameTr']} ${c['nameEn']} $aliases ${c['code']} ${c['iso3']}');
    countries.add([
      c['code'], c['iso3'], c['nameTr'], c['nameEn'], c['region'], c['subregion'],
      c['continent'], c['type'], c['capitalTr'], c['capitalEn'], c['capitalCityId'],
      c['population'], (c['areaKm2'] as num?)?.toDouble(), c['currency'], c['currencyName'],
      c['wikidata'], (c['hasShape'] == true) ? 1 : 0, (c['labelLat'] as num?)?.toDouble(),
      (c['labelLon'] as num?)?.toDouble(), (c['minLabel'] as num?)?.toDouble(), key,
    ]);
  }
  final text = utf8.decode(gzip.decode(citiesGz));
  final cities = <List<Object?>>[];
  final lines = const LineSplitter().convert(text);
  for (var i = 1; i < lines.length; i++) {
    final f = lines[i].split('\t');
    if (f.length < 10) continue;
    final key = TurkishText.fold('${f[2]} ${f[3]} ${f[4]}');
    cities.add([
      int.parse(f[0]), f[1], f[2], f[3], f[4], f[5], double.parse(f[6]), double.parse(f[7]),
      int.tryParse(f[8]) ?? 0, f[9] == '1' ? 1 : 0, key,
    ]);
  }
  return _ParsedGeo(countries, cities);
}
