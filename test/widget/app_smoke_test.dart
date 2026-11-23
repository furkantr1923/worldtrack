import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worldtrack/app.dart';
import 'package:worldtrack/app_services.dart';

import '../helpers.dart';

/// Arayüz duman testi: telefon ve masaüstü düzeni, boş durumlar, sekme geçişleri.
void main() {
  late Directory dir;
  late AppServices s;

  setUp(() async {
    dir = tempDir('ui');
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('telefon düzeni: alt gezinme, boş durumlar', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    s = (await t.runAsync(() => createTestServices(dir)))!;
    await t.pumpWidget(WorldTrackApp(services: s));
    await settle(t);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('statCountries')), findsOneWidget);
    expect(find.text('Ziyaret edilen ülke'), findsOneWidget);
    expect(find.text('Ziyaret edilen şehir'), findsOneWidget);

    await t.tap(find.byKey(const Key('nav_travels')));
    await settle(t);
    expect(find.text('Seyahat geçmişin boş'), findsOneWidget);

    await t.tap(find.byKey(const Key('nav_calendar')));
    await settle(t);
    expect(find.byKey(const Key('calMonthTitle')), findsOneWidget);

    await t.tap(find.byKey(const Key('nav_plans')));
    await settle(t);
    expect(find.text('Planlanmış seyahat yok'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => s.dispose());
  });

  testWidgets('masaüstü düzeni: yan menü ve tüm bölümler', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    s = (await t.runAsync(() => createTestServices(dir)))!;
    await t.pumpWidget(WorldTrackApp(services: s));
    await settle(t);

    expect(find.byType(NavigationBar), findsNothing);
    for (final tab in ['home', 'map', 'travels', 'plans', 'calendar', 'discover', 'settings']) {
      expect(find.byKey(Key('nav_$tab')), findsOneWidget, reason: tab);
    }
    await t.tap(find.byKey(const Key('nav_discover')));
    await settle(t);
    expect(find.text('Keşfet'), findsWidgets);

    await t.tap(find.byKey(const Key('nav_settings')));
    await settle(t);
    expect(find.text('Profil ve Ayarlar'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => s.dispose());
  });
}
