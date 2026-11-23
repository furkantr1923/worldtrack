import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:worldtrack/core/utils/dates.dart';
import 'package:worldtrack/core/utils/geo.dart';
import 'package:worldtrack/ui/widgets/expenses_section.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Geo', () {
    test('İstanbul–Ankara kuş uçuşu ≈ 350 km', () {
      final km = Geo.distanceKm(const LatLng(41.0138, 28.9497), const LatLng(39.9199, 32.8543));
      expect(km, closeTo(350, 10));
    });

    test('büyük daire yayı uç noktaları korur ve tarih çizgisini kesintisiz geçer', () {
      const tokyo = LatLng(35.68, 139.69), sf = LatLng(37.77, -122.42);
      final arc = Geo.greatCircle(tokyo, sf, segments: 32);
      expect(arc.first.latitude, closeTo(tokyo.latitude, 1e-6));
      expect(arc.last.latitude, closeTo(sf.latitude, 1e-6));
      for (var i = 1; i < arc.length; i++) {
        expect((arc[i].longitude - arc[i - 1].longitude).abs(), lessThan(180));
      }
    });

    test('nokta-poligon testi', () {
      final square = [const LatLng(0, 0), const LatLng(0, 10), const LatLng(10, 10), const LatLng(10, 0)];
      expect(Geo.pointInRing(5, 5, square), isTrue);
      expect(Geo.pointInRing(15, 5, square), isFalse);
    });

    test('mesafe biçimi', () {
      expect(Geo.formatKm(0.4), '< 1 km');
      expect(Geo.formatKm(57.2), '57 km');
      expect(Geo.formatKm(2345), '2.350 km');
    });
  });

  group('Dates', () {
    test('veritabanı biçimi gidiş-dönüş', () {
      final d = DateTime(2024, 3, 9);
      expect(Dates.toDb(d), '2024-03-09');
      expect(Dates.fromDb('2024-03-09'), d);
      expect(Dates.tryFromDb('bozuk'), isNull);
    });

    test('süre son günü dahil eder', () {
      expect(Dates.endOf(DateTime(2024, 2, 28), 3), DateTime(2024, 3, 1));
      expect(Dates.endOf(DateTime(2024, 1, 1), 1), DateTime(2024, 1, 1));
    });

    test('Türkçe aralık metni', () {
      expect(Dates.range(DateTime(2024, 3, 12), DateTime(2024, 3, 15)), '12 – 15 Mart 2024');
      expect(Dates.long(DateTime(2024, 8, 30)), '30 Ağustos 2024');
    });

    test('günler arası fark yaz saatinden etkilenmez', () {
      expect(Dates.daysBetween(DateTime(2024, 3, 30), DateTime(2024, 4, 2)), 3);
    });
  });

  group('Tutar ayrıştırma', () {
    test('Türkçe ve İngilizce biçimler', () {
      expect(parseMoneyInput('1.250,50'), 125050);
      expect(parseMoneyInput('1250,5'), 125050);
      expect(parseMoneyInput('1250.50'), 125050);
      expect(parseMoneyInput('1.250'), 125000);
      expect(parseMoneyInput('42'), 4200);
      expect(parseMoneyInput(''), isNull);
      expect(parseMoneyInput('abc'), isNull);
    });
    test('para biçimi', () {
      expect(formatMoney(125050, 'TRY'), contains('1.250,50'));
    });
  });
}
