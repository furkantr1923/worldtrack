import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data_events.dart';
import '../models/models.dart';

/// İsteğe bağlı, basit seyahat masrafları. Kur dönüşümü yapılmaz; toplamlar
/// para birimi başına ayrı gösterilir (yanıltıcı tek toplam üretilmez).
class ExpenseRepository {
  ExpenseRepository(this._db, this._events);

  final Database _db;
  final DataEvents _events;

  Future<List<Expense>> forRecord(int recordId) async {
    final rows = await _db.query('expenses', where: 'record_id = ?', whereArgs: [recordId], orderBy: 'id');
    return rows.map(Expense.fromRow).toList();
  }

  Future<List<Expense>> forTrip(int tripId) async {
    final rows = await _db.query('expenses', where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'id');
    return rows.map(Expense.fromRow).toList();
  }

  String? validate(Expense e) {
    if (e.amountMinor <= 0) return 'Tutar sıfırdan büyük olmalı.';
    if (e.amountMinor > 100000000000) return 'Tutar çok büyük.';
    if (e.currency.length != 3) return 'Geçerli bir para birimi seçin.';
    if (e.recordId == null && e.tripId == null) return 'Masraf bir seyahate bağlı olmalı.';
    return null;
  }

  Future<int> save(Expense e) async {
    final error = validate(e);
    if (error != null) throw ArgumentError(error);
    int id;
    if (e.id == null) {
      id = await _db.insert('expenses', {...e.toRow(), 'created_at': DateTime.now().toIso8601String()});
    } else {
      id = e.id!;
      await _db.update('expenses', e.toRow(), where: 'id = ?', whereArgs: [id]);
    }
    _events.emit(DataChange.expenses);
    return id;
  }

  Future<void> delete(int id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    _events.emit(DataChange.expenses);
  }

  /// Para birimi → toplam (kuruş).
  static Map<String, int> totals(List<Expense> list) {
    final out = <String, int>{};
    for (final e in list) {
      out[e.currency] = (out[e.currency] ?? 0) + e.amountMinor;
    }
    return out;
  }
}
