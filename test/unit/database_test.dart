import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:worldtrack/app_services.dart';
import 'package:worldtrack/core/utils/dates.dart';
import 'package:worldtrack/data/db/migrations.dart';
import 'package:worldtrack/data/models/models.dart';
import 'package:worldtrack/data/repositories/expense_repository.dart';

import '../helpers.dart';

/// Gerçek SQLite (FFI) ve uygulamayla gelen gerçek ülke/şehir verisiyle testler.
void main() {
  late Directory dir;
  late AppServices s;

  setUp(() async {
    dir = tempDir('db');
    s = await createTestServices(dir);
  });

  tearDown(() async {
    await s.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<City> city(String code, String name) async => (await s.cities.search(name, countryCode: code)).first;

  group('Coğrafi veri', () {
    test('ülkeler ve şehirler yüklendi', () async {
      expect(s.countries.all.length, greaterThan(240));
      expect(s.countries.byCode('TR')!.nameTr, 'Türkiye');
      expect(s.countries.byCode('TR')!.capitalTr, 'Ankara');
      expect(s.countries.byCode('XC')!.nameTr, 'Kuzey Kıbrıs Türk Cumhuriyeti');
      final n = await s.database.db.rawQuery('SELECT COUNT(*) AS n FROM cities');
      expect(n.first['n'] as int, greaterThan(30000));
    });

    test('Türkçe karakter duyarsız ülke ve şehir araması', () async {
      expect(s.countries.search('turkiye').first.code, 'TR');
      expect(s.countries.search('ALMANYA').first.code, 'DE');
      expect(s.countries.search('cekya').first.code, 'CZ');
      expect(s.countries.search('tayvan').first.code, 'TW');
      expect((await s.cities.search('munih')).first.nameTr, 'Münih');
      expect((await s.cities.search('istanbul')).first.countryCode, 'TR');
      expect((await s.cities.search('İSTANBUL')).first.nameTr, 'İstanbul');
      expect((await s.cities.search('corum', countryCode: 'TR')).first.nameTr, 'Çorum');
      expect((await s.cities.search('girne', countryCode: 'XC')).isNotEmpty, isTrue);
    });

    test('harita tıklama testi doğru ülkeyi bulur', () {
      expect(s.shapes.hitTest(const LatLng(39.0, 35.0)), 'TR');
      expect(s.shapes.hitTest(const LatLng(48.85, 2.35)), 'FR');
      expect(s.shapes.hitTest(const LatLng(-14.2, -51.9)), 'BR');
      expect(s.shapes.hitTest(const LatLng(35.3, 33.5)), 'XC');
      expect(s.shapes.hitTest(const LatLng(0, -30)), isNull); // Atlas Okyanusu
    });

    test('şema sürümü', () async {
      final v = await s.database.db.rawQuery('PRAGMA user_version');
      expect(v.first.values.first, Migrations.latestVersion);
    });
  });

  group('Seyahat kayıtları', () {
    test('oluştur, düzenle, sil', () async {
      final rome = await city('IT', 'roma');
      final id = await s.travels.insert(TravelRecord(
        countryCode: 'IT',
        cityId: rome.id,
        visitDate: DateTime(2023, 5, 10),
        durationDays: 4,
        transport: TransportType.plane,
        notes: 'Kolezyum',
      ));
      var r = (await s.travels.byId(id))!;
      expect(r.city!.nameTr, 'Roma');
      expect(r.country!.nameTr, 'İtalya');
      expect(r.endDate, DateTime(2023, 5, 13));

      await s.travels.update(TravelRecord(
        id: id,
        countryCode: 'IT',
        cityId: rome.id,
        visitDate: DateTime(2023, 5, 11),
        durationDays: 2,
        transport: TransportType.train,
      ));
      r = (await s.travels.byId(id))!;
      expect(r.durationDays, 2);
      expect(r.transport, TransportType.train);
      expect(r.notes, '');

      await s.travels.delete(id);
      expect(await s.travels.byId(id), isNull);
    });

    test('gelecek tarih ve geçersiz süre reddedilir', () async {
      final rome = await city('IT', 'roma');
      final future = Dates.today().add(const Duration(days: 3));
      expect(
        () => s.travels.insert(TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: future, durationDays: 1)),
        throwsArgumentError,
      );
      expect(
        () => s.travels.insert(TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: DateTime(2020), durationDays: 0)),
        throwsArgumentError,
      );
    });

    test('yeniden başlatma sonrası veri kalıcı', () async {
      final paris = await city('FR', 'paris');
      await s.travels.insert(TravelRecord(countryCode: 'FR', cityId: paris.id, visitDate: DateTime(2022, 7, 1), durationDays: 3));
      await s.dispose();
      s = await createTestServices(dir);
      final list = await s.travels.list();
      expect(list, hasLength(1));
      expect(list.first.city!.nameTr, 'Paris');
    });

    test('çift kayıt tespiti engellemez, uyarır', () async {
      final paris = await city('FR', 'paris');
      final rec = TravelRecord(countryCode: 'FR', cityId: paris.id, visitDate: DateTime(2022, 7, 1), durationDays: 3);
      await s.travels.insert(rec);
      expect(await s.travels.hasDuplicate(paris.id, DateTime(2022, 7, 1)), isTrue);
      expect(await s.travels.hasDuplicate(paris.id, DateTime(2023, 7, 1)), isFalse);
      await s.travels.insert(rec); // bilinçli tekrar mümkün
      expect(await s.travels.list(), hasLength(2));
    });
  });

  group('İstatistikler', () {
    test('tekrar ziyaretler bir kez sayılır, elle işaretleme ülke sayısına eklenir', () async {
      final rome = await city('IT', 'roma');
      final milan = await city('IT', 'milano');
      final berlin = await city('DE', 'berlin');
      for (final d in [DateTime(2020, 1, 1), DateTime(2021, 1, 1), DateTime(2022, 1, 1)]) {
        await s.travels.insert(TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: d, durationDays: 2));
      }
      await s.travels.insert(TravelRecord(countryCode: 'IT', cityId: milan.id, visitDate: DateTime(2022, 3, 1), durationDays: 1));
      await s.travels.insert(TravelRecord(countryCode: 'DE', cityId: berlin.id, visitDate: DateTime(2022, 4, 1), durationDays: 1));

      var st = await s.travels.stats();
      expect(st.visitedCountries, 2);
      expect(st.visitedCities, 3);

      await s.countries.setManualVisited('JP', true);
      await s.countries.setManualVisited('IT', true); // zaten sayılıyor; tekrar sayılmaz
      st = await s.travels.stats();
      expect(st.visitedCountries, 3);
      expect(st.visitedCities, 3);
      expect(await s.countries.visitedCodes(), containsAll(['IT', 'DE', 'JP']));

      final itCities = await s.travels.visitedCities('IT');
      expect(itCities.firstWhere((c) => c.city.id == rome.id).visits, 3);
    });
  });

  group('Fotoğraflar ve masraflar', () {
    test('kayıt silinince fotoğraf dosyaları ve masraflar da silinir', () async {
      final rome = await city('IT', 'roma');
      final id = await s.travels.insert(
          TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: DateTime(2023, 1, 1), durationDays: 1));
      final file = File('${s.paths.photosDir}/test.jpg')..writeAsBytesSync([1, 2, 3]);
      final thumb = File('${s.paths.thumbsDir}/test.jpg')..writeAsBytesSync([1, 2]);
      await s.travels.addPhoto(recordId: id, filePath: file.path, thumbPath: thumb.path, originalName: 'test.jpg');
      await s.expenses.save(Expense(recordId: id, amountMinor: 12550, currency: 'EUR', category: 'Gezi'));
      expect(await s.travels.photos(id), hasLength(1));
      expect(await s.expenses.forRecord(id), hasLength(1));

      await s.travels.delete(id);
      expect(file.existsSync(), isFalse);
      expect(thumb.existsSync(), isFalse);
      final left = await s.database.db.rawQuery('SELECT COUNT(*) AS n FROM expenses');
      expect(left.first['n'], 0);
    });

    test('masraf toplamları para birimine göre ayrılır', () async {
      final rome = await city('IT', 'roma');
      final id = await s.travels.insert(
          TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: DateTime(2023, 1, 1), durationDays: 1));
      await s.expenses.save(Expense(recordId: id, amountMinor: 10000, currency: 'EUR', category: 'Konaklama'));
      await s.expenses.save(Expense(recordId: id, amountMinor: 2550, currency: 'EUR', category: 'Yeme-içme'));
      await s.expenses.save(Expense(recordId: id, amountMinor: 50000, currency: 'TRY', category: 'Ulaşım'));
      final list = await s.expenses.forRecord(id);
      expect(list, hasLength(3));
      expect(ExpenseRepository.totals(list), {'EUR': 12550, 'TRY': 50000});
      expect(() => s.expenses.save(Expense(recordId: id, amountMinor: 0, currency: 'EUR', category: 'Gezi')),
          throwsArgumentError);
    });
  });

  group('Planlar', () {
    test('kaydet, durak sırasını değiştir, seyahate dönüştür', () async {
      final paris = await city('FR', 'paris');
      final madrid = await city('ES', 'madrid');
      final lisbon = await city('PT', 'lizbon');
      final start = DateTime(2024, 6, 1);
      var id = await s.plans.save(PlannedTrip(
        title: 'İber turu',
        startDate: start,
        stops: [
          TripStop(countryCode: 'FR', cityId: paris.id, durationDays: 2, transport: TransportType.plane),
          TripStop(countryCode: 'ES', cityId: madrid.id, durationDays: 3, transport: TransportType.train),
          TripStop(countryCode: 'PT', cityId: lisbon.id, durationDays: 2, transport: TransportType.bus),
        ],
      ));
      var plan = (await s.plans.byId(id))!;
      expect(plan.stops.map((e) => e.city!.nameTr).toList(), ['Paris', 'Madrid', 'Lizbon']);
      expect(plan.effectiveEnd, DateTime(2024, 6, 7));
      expect(await s.countries.plannedCodes(), containsAll(['FR', 'ES', 'PT']));

      // Sıra değiştir: Lizbon başa
      final reordered = [plan.stops[2], plan.stops[0], plan.stops[1]];
      id = await s.plans.save(PlannedTrip(id: id, title: plan.title, startDate: start, stops: reordered));
      plan = (await s.plans.byId(id))!;
      expect(plan.stops.map((e) => e.city!.nameTr).toList(), ['Lizbon', 'Paris', 'Madrid']);

      final drafts = s.plans.draftRecords(plan);
      expect(drafts.map((d) => d.visitDate).toList(), [DateTime(2024, 6, 1), DateTime(2024, 6, 3), DateTime(2024, 6, 5)]);
      await s.plans.convertToRecords(id, drafts);
      plan = (await s.plans.byId(id))!;
      expect(plan.isCompleted, isTrue);
      final records = await s.travels.list();
      expect(records, hasLength(3));
      expect(records.every((r) => r.planId == id), isTrue);
      expect((await s.travels.stats()).visitedCountries, 3);
      expect(await s.countries.plannedCodes(), isEmpty);
    });

    test('gelecekteki plan dönüştürülemez; plan silinince kayıtlar kalır', () async {
      final paris = await city('FR', 'paris');
      final future = Dates.today().add(const Duration(days: 30));
      final id = await s.plans.save(PlannedTrip(
        title: 'Paris',
        startDate: future,
        stops: [TripStop(countryCode: 'FR', cityId: paris.id, durationDays: 2)],
      ));
      final plan = (await s.plans.byId(id))!;
      expect(() => s.plans.convertToRecords(id, s.plans.draftRecords(plan)), throwsArgumentError);
      await s.plans.delete(id);
      expect(await s.plans.byId(id), isNull);
    });

    test('takvim aralığı sorguları', () async {
      final rome = await city('IT', 'roma');
      await s.travels.insert(
          TravelRecord(countryCode: 'IT', cityId: rome.id, visitDate: DateTime(2024, 1, 30), durationDays: 5));
      final feb = await s.travels.inRange(DateTime(2024, 2, 1), DateTime(2024, 2, 29));
      expect(feb, hasLength(1)); // 30 Ocak – 3 Şubat, Şubat'la kesişir
      final mar = await s.travels.inRange(DateTime(2024, 3, 1), DateTime(2024, 3, 31));
      expect(mar, isEmpty);
    });
  });

  group('Elle eklenen şehir', () {
    test('ekle, tekrar eklemede aynısını döndür, aramada bul', () async {
      final c1 = await s.cities.addCustom(countryCode: 'TR', name: 'Kapadokya Köyü', admin1: 'Nevşehir');
      final c2 = await s.cities.addCustom(countryCode: 'TR', name: 'kapadokya köyü');
      expect(c2.id, c1.id);
      expect(c1.isCustom, isTrue);
      expect(c1.point, isNull);
      expect((await s.cities.search('kapadokya koyu', countryCode: 'TR')).first.id, c1.id);
      expect(() => s.cities.addCustom(countryCode: 'TR', name: '  '), throwsArgumentError);
      expect(() => s.cities.addCustom(countryCode: 'TR', name: 'X', lat: 95, lon: 0), throwsArgumentError);
    });
  });
}
