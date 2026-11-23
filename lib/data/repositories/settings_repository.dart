import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Anahtar-değer ayarları (tema, harita altlığı, güzergâh tahmini…).
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;
  final Map<String, String?> _cache = {};

  Future<void> load() async {
    final rows = await _db.query('settings');
    _cache
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r['key'] as String, r['value'] as String?)));
  }

  String? get(String key) => _cache[key];

  String getOr(String key, String fallback) => _cache[key] ?? fallback;

  bool getBool(String key, {bool fallback = false}) {
    final v = _cache[key];
    return v == null ? fallback : v == '1';
  }

  Future<void> set(String key, String? value) async {
    _cache[key] = value;
    await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');
}
