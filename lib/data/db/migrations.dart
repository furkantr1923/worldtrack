import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Veritabanı şeması ve sürüm geçişleri.
///
/// Yeni bir sürüm eklerken: [latestVersion] artırılır ve [_steps] listesine
/// o sürüme geçişi yapan SQL komutları eklenir. Mevcut kullanıcıların verisi
/// silinmeden sırayla yükseltilir.
class Migrations {
  Migrations._();

  static const int latestVersion = 1;

  static const List<String> _v1 = [
    '''CREATE TABLE countries (
      code TEXT PRIMARY KEY,
      iso3 TEXT,
      name_tr TEXT NOT NULL,
      name_en TEXT,
      region TEXT,
      subregion TEXT,
      continent TEXT,
      type TEXT,
      capital_tr TEXT,
      capital_en TEXT,
      capital_city_id INTEGER,
      population INTEGER,
      area_km2 REAL,
      currency TEXT,
      currency_name TEXT,
      wikidata TEXT,
      has_shape INTEGER NOT NULL DEFAULT 0,
      label_lat REAL,
      label_lon REAL,
      min_label REAL,
      search_key TEXT NOT NULL,
      manual_visited INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE cities (
      id INTEGER PRIMARY KEY,
      country_code TEXT NOT NULL REFERENCES countries(code),
      name_tr TEXT NOT NULL,
      name TEXT,
      ascii TEXT,
      admin1 TEXT,
      lat REAL,
      lon REAL,
      population INTEGER NOT NULL DEFAULT 0,
      is_capital INTEGER NOT NULL DEFAULT 0,
      is_custom INTEGER NOT NULL DEFAULT 0,
      search_key TEXT NOT NULL
    )''',
    'CREATE INDEX idx_cities_country ON cities(country_code, population DESC)',
    '''CREATE TABLE planned_trips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT,
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed')),
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_trips_start ON planned_trips(start_date)',
    '''CREATE TABLE trip_stops (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL REFERENCES planned_trips(id) ON DELETE CASCADE,
      order_index INTEGER NOT NULL,
      country_code TEXT NOT NULL REFERENCES countries(code),
      city_id INTEGER REFERENCES cities(id) ON DELETE RESTRICT,
      arrival_date TEXT,
      duration_days INTEGER CHECK (duration_days IS NULL OR duration_days >= 1),
      transport TEXT
    )''',
    'CREATE INDEX idx_stops_trip ON trip_stops(trip_id, order_index)',
    '''CREATE TABLE travel_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      country_code TEXT NOT NULL REFERENCES countries(code),
      city_id INTEGER NOT NULL REFERENCES cities(id) ON DELETE RESTRICT,
      visit_date TEXT NOT NULL,
      duration_days INTEGER NOT NULL CHECK (duration_days >= 1),
      transport TEXT,
      notes TEXT,
      plan_id INTEGER REFERENCES planned_trips(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_records_date ON travel_records(visit_date DESC)',
    'CREATE INDEX idx_records_country ON travel_records(country_code)',
    'CREATE INDEX idx_records_city ON travel_records(city_id)',
    '''CREATE TABLE travel_photos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      record_id INTEGER NOT NULL REFERENCES travel_records(id) ON DELETE CASCADE,
      file_path TEXT NOT NULL,
      thumb_path TEXT NOT NULL,
      original_name TEXT,
      width INTEGER,
      height INTEGER,
      sort_order INTEGER NOT NULL DEFAULT 0,
      added_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_photos_record ON travel_photos(record_id, sort_order)',
    '''CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      record_id INTEGER REFERENCES travel_records(id) ON DELETE CASCADE,
      trip_id INTEGER REFERENCES planned_trips(id) ON DELETE CASCADE,
      amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
      currency TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT,
      spent_on TEXT,
      created_at TEXT NOT NULL,
      CHECK (record_id IS NOT NULL OR trip_id IS NOT NULL)
    )''',
    'CREATE INDEX idx_expenses_record ON expenses(record_id)',
    'CREATE INDEX idx_expenses_trip ON expenses(trip_id)',
    '''CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )''',
    '''CREATE TABLE country_info_cache (
      code TEXT PRIMARY KEY,
      title TEXT,
      summary TEXT,
      url TEXT,
      fetched_at TEXT NOT NULL
    )''',
  ];

  /// Sürüm → o sürüme yükseltirken çalışacak komutlar.
  static const Map<int, List<String>> _steps = {
    // 2: ['ALTER TABLE ...'],
  };

  static Future<void> create(Database db) async {
    final batch = db.batch();
    for (final sql in _v1) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
    // v1 sonrasındaki adımlar yeni kurulumda da uygulanır.
    for (var v = 2; v <= latestVersion; v++) {
      for (final sql in _steps[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }

  static Future<void> upgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      for (final sql in _steps[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }
}
