import 'package:intl/intl.dart';

/// Tarih yardımcıları.
///
/// Seyahat tarihleri saat dilimi içermeyen "takvim günü" olarak saklanır
/// (yyyy-MM-dd). Böylece cihazın saat dilimi değişse bile 12 Mart, 12 Mart kalır.
class Dates {
  Dates._();

  static final DateFormat _db = DateFormat('yyyy-MM-dd');
  static final DateFormat _long = DateFormat('d MMMM y', 'tr_TR');
  static final DateFormat _short = DateFormat('d MMM y', 'tr_TR');
  static final DateFormat _dayMonth = DateFormat('d MMMM', 'tr_TR');
  static final DateFormat _monthYear = DateFormat('MMMM y', 'tr_TR');
  static final DateFormat _weekday = DateFormat('EEEE', 'tr_TR');

  static DateTime today() => dateOnly(DateTime.now());

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String toDb(DateTime d) => _db.format(dateOnly(d));

  static DateTime fromDb(String s) {
    final parts = s.split('-');
    if (parts.length != 3) throw FormatException('Geçersiz tarih: $s');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static DateTime? tryFromDb(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return fromDb(s);
    } on FormatException {
      return null;
    }
  }

  static String long(DateTime d) => _long.format(d);
  static String short(DateTime d) => _short.format(d);
  static String monthYear(DateTime d) => _capitalize(_monthYear.format(d));
  static String weekday(DateTime d) => _capitalize(_weekday.format(d));

  /// Son gün dahil olacak şekilde süre hesaplar: 3 gün → başlangıç + 2.
  static DateTime endOf(DateTime start, int durationDays) =>
      DateTime(start.year, start.month, start.day + (durationDays < 1 ? 0 : durationDays - 1));

  /// İki takvim günü arasındaki gün sayısı (yaz saati geçişlerinden etkilenmez).
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// "12 – 15 Mart 2024" veya "28 Şubat – 3 Mart 2024" biçiminde aralık.
  static String range(DateTime start, DateTime end) {
    if (start == end) return long(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${long(end)}';
    }
    if (start.year == end.year) return '${_dayMonth.format(start)} – ${long(end)}';
    return '${long(start)} – ${long(end)}';
  }

  static String duration(int days) => days == 1 ? '1 gün' : '$days gün';

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Pazartesi ile başlayan haftanın kısa gün adları.
  static const weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
}
