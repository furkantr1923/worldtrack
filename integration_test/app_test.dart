// WORLDTRACK uçtan uca testi.
//
// Gerçek uygulama gerçek SQLite veritabanıyla açılır ve kullanıcı gibi dokunularak
// tüm temel akışlar denenir. Her önemli adımda ekran görüntüsü alınır
// (geçici klasör / worldtrack_screens). Fotoğraf seçici, sistem penceresi
// açılamayacağı için test görselleri üreten sahte bir kaynakla değiştirilir.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:worldtrack/app.dart';
import 'package:worldtrack/app_services.dart';
import 'package:worldtrack/core/utils/dates.dart';
import 'package:worldtrack/data/models/models.dart';
import 'package:worldtrack/data/storage_paths.dart';
import 'package:worldtrack/services/photo_service.dart';

class FakePhotoSource implements PhotoSource {
  FakePhotoSource(this.dir);
  final Directory dir;
  int _n = 0;

  /// Gökyüzü + güneş + tepeler çizen basit test görselleri üretir.
  XFile _make(int seed) {
    const w = 900, h = 600;
    final im = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final t = y / h;
      final r = (40 + 180 * t + seed * 20).clamp(0, 255).toInt();
      final g = (120 + 60 * t).clamp(0, 255).toInt();
      final b = (220 - 90 * t).clamp(0, 255).toInt();
      for (var x = 0; x < w; x++) {
        im.setPixelRgb(x, y, r, g, b);
      }
    }
    img.fillCircle(im, x: 650 - seed * 80, y: 180, radius: 70, color: img.ColorRgb8(255, 214, 102));
    for (var x = 0; x < w; x++) {
      final hill = (430 + 60 * (0.5 + 0.5 * ((x + seed * 97) % 300) / 300)).toInt();
      for (var y = hill; y < h; y++) {
        im.setPixelRgb(x, y, 30 + seed * 10, 110, 80);
      }
    }
    final f = File('${dir.path}/foto_${seed}_${_n++}.jpg')..writeAsBytesSync(img.encodeJpg(im, quality: 85));
    return XFile(f.path, name: 'tatil_$seed.jpg');
  }

  @override
  Future<List<XFile>> pickImages() async => [_make(0), _make(1)];
}

late Directory screensDir;
final GlobalKey shotKey = GlobalKey();

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.runAsync(() async {
    final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    File('${screensDir.path}/$name.png').writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('EKRAN GÖRÜNTÜSÜ: $name.png');
    if (Platform.isAndroid) {
      // Test bitince uygulama kaldırıldığı için görüntüler loga da yazılır (CI ayıklar).
      final b64 = base64Encode(bytes);
      for (var i = 0; i < b64.length; i += 800) {
        // ignore: avoid_print
        print('WTSHOT|$name|${b64.substring(i, i + 800 > b64.length ? b64.length : i + 800)}');
      }
    }
  });
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Zaman aşımı, bulunamadı: $f');
}

Future<void> waitGone(WidgetTester t, Finder f, {int seconds = 25}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isEmpty) return;
  }
  throw TestFailure('Zaman aşımı, kaybolmadı: $f');
}

Future<void> idle(WidgetTester t, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await waitFor(t, f);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first);
  await t.pump(const Duration(milliseconds: 200));
}

/// Uygulama Türkçe olduğu için (geri ipucu "Geri") tester.pageBack() yerine
/// ekrandaki geri düğmesine dokunulur.
Future<void> goBack(WidgetTester t) async {
  final back = find.byType(BackButton);
  await waitFor(t, back);
  await t.tap(back.last);
  await idle(t, 700);
}

Finder keyPrefix(String prefix) => find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix));

/// Sekmeye git: geniş ekranda yan menü, telefonda alt çubuk / ana sayfa düğmeleri.
Future<void> goTab(WidgetTester t, String tab) async {
  if (find.byKey(Key('nav_$tab')).evaluate().isNotEmpty) {
    await tapKey(t, 'nav_$tab');
  } else {
    await tapKey(t, 'nav_home');
    await tapKey(t, tab == 'discover' ? 'homeDiscover' : 'homeSettings');
  }
  await idle(t, 600);
}

Future<void> confirmDatePicker(WidgetTester t) async {
  await waitFor(t, find.text('Seç'));
  await t.tap(find.text('Seç'));
  await idle(t, 400);
}

Future<void> pickCountry(WidgetTester t, String query, String code) async {
  await waitFor(t, find.byKey(const Key('countrySearchField')));
  await t.enterText(find.byKey(const Key('countrySearchField')), query);
  await idle(t, 300);
  await tapKey(t, 'countryOption_$code');
  await idle(t, 400);
}

Future<void> pickFirstCity(WidgetTester t, String query) async {
  await waitFor(t, find.byKey(const Key('citySearchField')));
  await t.enterText(find.byKey(const Key('citySearchField')), query);
  await idle(t, 700);
  final opt = keyPrefix('cityOption_');
  await waitFor(t, opt);
  await t.tap(opt.first);
  await idle(t, 400);
}

Future<AppServices> startServices(Directory dataDir, PhotoSource photos) async {
  final paths = await StoragePaths.forDirectory(dataDir.path);
  return AppServices.initialize(paths: paths, photoSource: photos);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WORLDTRACK uçtan uca', (t) async {
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
    final tmp = await getTemporaryDirectory();
    screensDir = Directory('${tmp.path}/worldtrack_screens')..createSync(recursive: true);
    final dataDir = Directory('${tmp.path}/worldtrack_e2e_${DateTime.now().millisecondsSinceEpoch}')
      ..createSync(recursive: true);
    final photoDir = Directory('${dataDir.path}/fake_photos')..createSync();
    final photos = FakePhotoSource(photoDir);

    var s = await t.runAsync(() => startServices(dataDir, photos));
    await t.pumpWidget(RepaintBoundary(key: shotKey, child: WorldTrackApp(services: s)));
    await waitFor(t, find.byKey(const Key('statCountries')));
    await idle(t, 1200);
    await shot(t, '01_ana_sayfa_bos');

    // ------------------------------------------------ 1. Seyahat ekle (form)
    await goTab(t, 'travels');
    await tapKey(t, 'emptyAddTravel');
    await tapKey(t, 'fieldCountry');
    await pickCountry(t, 'italya', 'IT');
    await tapKey(t, 'fieldCity');
    await pickFirstCity(t, 'roma');
    expect(find.textContaining('Roma'), findsWidgets);
    await tapKey(t, 'fieldDate');
    await confirmDatePicker(t);
    await tapKey(t, 'durationPlus');
    await tapKey(t, 'durationPlus');
    expect(find.text('3 gün'), findsOneWidget);
    await tapKey(t, 'transport_plane');
    await t.enterText(find.byKey(const Key('fieldNotes')), 'Kolezyum ve Trevi Çeşmesi. Harika bir hafta sonu!');
    await tapKey(t, 'formAddPhotos');
    await waitFor(t, find.textContaining('2 fotoğraf kaydedilince'));
    await shot(t, '02_seyahat_formu');
    await tapKey(t, 'saveTravel');
    await waitFor(t, keyPrefix('travel_'), seconds: 40);
    await idle(t, 800);
    expect(await t.runAsync(() => s!.travels.list()), hasLength(1));

    // ------------------------------------------------ 2. Detay, fotoğraf, masraf, düzenleme
    await t.tap(keyPrefix('travel_').first);
    await waitFor(t, find.byKey(const Key('photo_0')), seconds: 40);
    await idle(t, 800);
    await shot(t, '04_seyahat_detay');
    await t.tap(find.byKey(const Key('photo_0')));
    await waitFor(t, find.text('1 / 2'));
    await idle(t, 600);
    await shot(t, '05_foto_goruntuleyici');
    await goBack(t);
    await idle(t, 600);
    await tapKey(t, 'removePhoto_1');
    await waitFor(t, find.text('Kaldır'));
    await t.tap(find.text('Kaldır'));
    await waitFor(t, find.text('Fotoğraflar (1)'));

    await t.ensureVisible(find.text('Masraf ekle'));
    await t.tap(find.text('Masraf ekle'));
    await waitFor(t, find.byKey(const Key('expenseAmount')));
    await t.enterText(find.byKey(const Key('expenseAmount')), '1250,50');
    await tapKey(t, 'expenseSave');
    await waitFor(t, find.byKey(const Key('expenseTotal')));
    expect(find.textContaining('1.250,50'), findsWidgets);

    await tapKey(t, 'editTravel');
    await waitFor(t, find.byKey(const Key('durationMinus')));
    await tapKey(t, 'durationMinus');
    await tapKey(t, 'saveTravel');
    await waitFor(t, find.byKey(const Key('editTravel')));
    await waitFor(t, find.text('2 gün'));
    await goBack(t);
    await idle(t, 600);

    // Gerçekçi bir arşiv için birkaç kayıt daha (veritabanı üzerinden) + tekrar ziyaret
    await t.runAsync(() async {
      Future<City> c(String cc, String q) async => (await s!.cities.search(q, countryCode: cc)).first;
      final today = Dates.today();
      final data = [
        ('IT', 'roma', DateTime(today.year - 2, 4, 12), 3, TransportType.plane),
        ('DE', 'berlin', DateTime(today.year - 1, 9, 3), 4, TransportType.train),
        ('TR', 'istanbul', DateTime(today.year - 1, 6, 20), 5, TransportType.bus),
        ('FR', 'paris', DateTime(today.year - 3, 12, 27), 4, TransportType.plane),
        ('ES', 'barcelona', DateTime(today.year - 2, 7, 8), 6, TransportType.plane),
        ('NL', 'amsterdam', DateTime(today.year - 1, 4, 18), 3, TransportType.train),
      ];
      for (final d in data) {
        final city = await c(d.$1, d.$2);
        await s!.travels.insert(TravelRecord(
            countryCode: d.$1, cityId: city.id, visitDate: d.$3, durationDays: d.$4, transport: d.$5));
      }
    });
    await idle(t, 1200);
    await shot(t, '03_seyahatlerim');

    // ------------------------------------------------ 3. İstatistik (tekrar ziyaret tek sayılır)
    final st = await t.runAsync(() => s!.travels.stats());
    expect(st!.visitedCountries, 6);
    expect(st.visitedCities, 6); // Roma iki kez ziyaret edildi, bir kez sayılır
    await goTab(t, 'home');
    await idle(t, 1500);
    expect(find.descendant(of: find.byKey(const Key('statCountries')), matching: find.text('6')), findsOneWidget);
    await shot(t, '06_ana_sayfa');

    // ------------------------------------------------ 4. Harita
    await goTab(t, 'map');
    await waitFor(t, find.byKey(const Key('worldMap')));
    await idle(t, 3000); // altlık karolar (çevrimiçi ise)
    await shot(t, '07_harita');
    await t.tap(find.byKey(const Key('worldMap')));
    await waitFor(t, find.byKey(const Key('countryPanel')));
    await idle(t, 600);
    await shot(t, '08_harita_ulke_secimi');
    await tapKey(t, 'mapSearch');
    await pickCountry(t, 'japonya', 'JP');
    await waitFor(t, find.descendant(of: find.byKey(const Key('countryPanel')), matching: find.text('Japonya')));
    await tapKey(t, 'panelToggleVisited');
    await idle(t, 800);
    expect(await t.runAsync(() => s!.countries.visitedCodes()), contains('JP'));
    await tapKey(t, 'zoomIn');
    await tapKey(t, 'zoomOut');
    await tapKey(t, 'zoomReset');
    await idle(t, 1500);
    await tapKey(t, 'panelDetails');
    await waitFor(t, find.byKey(const Key('countryTitle')));
    await idle(t, 5000); // Vikipedi özeti (çevrimiçi ise)
    await shot(t, '09_ulke_detay');
    await goBack(t);
    await idle(t, 600);

    // ------------------------------------------------ 5. Plan oluştur (UI)
    await goTab(t, 'plans');
    await tapKey(t, 'fabAddPlan');
    await waitFor(t, find.byKey(const Key('planTitle')));
    await t.enterText(find.byKey(const Key('planTitle')), 'Balkan turu');
    await tapKey(t, 'planStart');
    await confirmDatePicker(t);
    final stops = [('yunanistan', 'GR', 'atina', null), ('bulgaristan', 'BG', 'sofya', 'bus'), ('sirbistan', 'RS', 'belgrad', 'train')];
    for (final stop in stops) {
      await tapKey(t, 'addStop');
      await tapKey(t, 'stopCountry');
      await pickCountry(t, stop.$1, stop.$2);
      await tapKey(t, 'stopCity');
      await pickFirstCity(t, stop.$3);
      if (stop.$4 != null) await tapKey(t, 'transport_${stop.$4}');
      await tapKey(t, 'stopSave');
      await idle(t, 300);
    }
    expect(find.textContaining('Belgrad'), findsWidgets);
    await shot(t, '10_plan_duzenleyici');
    await tapKey(t, 'savePlan');
    await waitFor(t, keyPrefix('plan_'));
    await t.tap(keyPrefix('plan_').first);
    await waitFor(t, find.byKey(const Key('convertPlan')));
    await idle(t, 3000);
    await shot(t, '11_plan_rota');
    await goBack(t);
    await idle(t, 600);

    // Geçmiş tarihli plan → seyahate dönüştür (UI)
    final pastPlanId = await t.runAsync(() async {
      final vienna = (await s!.cities.search('viyana', countryCode: 'AT')).first;
      final prague = (await s.cities.search('prag', countryCode: 'CZ')).first;
      return s.plans.save(PlannedTrip(
        title: 'Orta Avrupa',
        startDate: Dates.today().subtract(const Duration(days: 40)),
        stops: [
          TripStop(countryCode: 'AT', cityId: vienna.id, durationDays: 3, transport: TransportType.plane),
          TripStop(countryCode: 'CZ', cityId: prague.id, durationDays: 2, transport: TransportType.train),
        ],
      ));
    });
    await idle(t, 800);
    await t.tap(find.byKey(Key('plan_$pastPlanId')));
    await tapKey(t, 'convertPlan');
    await tapKey(t, 'confirmConvert');
    await waitFor(t, find.text('Tamamlandı'));
    final afterConvert = await t.runAsync(() => s!.travels.list());
    expect(afterConvert!.where((r) => r.planId == pastPlanId), hasLength(2));
    await goBack(t);
    await idle(t, 600);

    // ------------------------------------------------ 6. Takvim
    await goTab(t, 'calendar');
    await waitFor(t, find.byKey(const Key('calMonthTitle')));
    await idle(t, 800);
    await shot(t, '12_takvim');
    final title = (t.widget(find.byKey(const Key('calMonthTitle'))) as Text).data;
    await tapKey(t, 'calNext');
    await idle(t, 400);
    expect((t.widget(find.byKey(const Key('calMonthTitle'))) as Text).data, isNot(title));
    await tapKey(t, 'calPrev');
    await idle(t, 400);
    expect((t.widget(find.byKey(const Key('calMonthTitle'))) as Text).data, title);

    // ------------------------------------------------ 7. Keşfet, arama, ayarlar, koyu tema
    await goTab(t, 'discover');
    await idle(t, 800);
    await shot(t, '13_kesfet');
    await goTab(t, 'home');
    await tapKey(t, 'homeSearch');
    await t.enterText(find.byKey(const Key('globalSearchField')), 'munih');
    await waitFor(t, find.text('Münih'));
    await shot(t, '14_arama');
    await goBack(t);
    await idle(t, 400);
    await goTab(t, 'settings');
    await idle(t, 600);
    await shot(t, '15_ayarlar');
    await t.tap(find.text('Koyu'));
    await idle(t, 800);
    await goTab(t, 'home');
    await idle(t, 1000);
    await shot(t, '16_ana_sayfa_koyu');
    await goTab(t, 'map');
    await idle(t, 2500);
    await shot(t, '17_harita_koyu');
    await goTab(t, 'settings');
    await t.tap(find.text('Sistem'));
    await idle(t, 600);

    // ------------------------------------------------ 8. Çevrimdışı
    s!.connectivity.setOnline(false);
    await idle(t, 600);
    expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
    await goTab(t, 'travels');
    await t.tap(keyPrefix('travel_').first);
    await waitFor(t, find.byKey(const Key('editTravel')));
    await idle(t, 800);
    await shot(t, '18_cevrimdisi_kayit');
    await goBack(t);
    s.connectivity.setOnline(true);
    await idle(t, 600);

    // ------------------------------------------------ 9. Silme
    final before = (await t.runAsync(() => s!.travels.list()))!.length;
    await t.enterText(find.byKey(const Key('travelFilter')), 'amsterdam');
    await idle(t, 400);
    await waitFor(t, keyPrefix('travel_'));
    await t.tap(keyPrefix('travel_').first);
    await tapKey(t, 'deleteTravel');
    await waitFor(t, find.text('Sil'));
    await t.tap(find.text('Sil'));
    await waitFor(t, find.byKey(const Key('fabAddTravel')));
    await idle(t, 800);
    final afterDelete = (await t.runAsync(() => s!.travels.list()))!.length;
    expect(afterDelete, before - 1);
    await t.enterText(find.byKey(const Key('travelFilter')), '');
    await idle(t, 400);

    // ------------------------------------------------ 10. Yeniden başlatma: veriler kalıcı mı?
    Future<List<TravelPhoto>> allPhotos() async {
      final out = <TravelPhoto>[];
      for (final r in await s!.travels.list()) {
        out.addAll(await s.travels.photos(r.id!));
      }
      return out;
    }

    final photosBefore = (await t.runAsync(allPhotos))!;
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => s!.dispose());
    s = await t.runAsync(() => startServices(dataDir, photos));
    await t.pumpWidget(RepaintBoundary(key: shotKey, child: WorldTrackApp(services: s)));
    await waitFor(t, find.byKey(const Key('statCountries')));
    final reopened = await t.runAsync(() => s!.travels.list());
    expect(reopened, hasLength(afterDelete));
    final photosAfter = (await t.runAsync(allPhotos))!;
    expect(photosAfter.length, photosBefore.length);
    for (final p in photosAfter) {
      expect(File(p.filePath).existsSync(), isTrue, reason: 'fotoğraf dosyası kalıcı olmalı');
    }
    expect((await t.runAsync(() => s!.countries.visitedCodes()))!, contains('JP'));
    await idle(t, 1000);
    await shot(t, '19_yeniden_baslatma');
    // ignore: avoid_print
    print('UÇTAN UCA TEST TAMAMLANDI: ${reopened!.length} kayıt kalıcı.');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
