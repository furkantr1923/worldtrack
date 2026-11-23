import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'data/data_events.dart';
import 'data/db/app_database.dart';
import 'data/repositories/city_repository.dart';
import 'data/repositories/country_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/plan_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/travel_repository.dart';
import 'data/storage_paths.dart';
import 'services/connectivity_service.dart';
import 'services/country_info_service.dart';
import 'services/map_shape_service.dart';
import 'services/photo_service.dart';
import 'services/routing_service.dart';
import 'services/settings_controller.dart';

/// Uygulamanın bağımlılık kabı: veritabanı, depolar ve servisler bir kez oluşturulur
/// ve arayüze Provider ile verilir.
class AppServices {
  AppServices._({
    required this.paths,
    required this.database,
    required this.events,
    required this.countries,
    required this.cities,
    required this.travels,
    required this.plans,
    required this.expenses,
    required this.settingsRepo,
    required this.settings,
    required this.shapes,
    required this.photos,
    required this.countryInfo,
    required this.routing,
    required this.connectivity,
  });

  final StoragePaths paths;
  final AppDatabase database;
  final DataEvents events;
  final CountryRepository countries;
  final CityRepository cities;
  final TravelRepository travels;
  final PlanRepository plans;
  final ExpenseRepository expenses;
  final SettingsRepository settingsRepo;
  final SettingsController settings;
  final MapShapeService shapes;
  final PhotoService photos;
  final CountryInfoService countryInfo;
  final RoutingService routing;
  final ConnectivityService connectivity;

  static Future<AppServices> initialize({
    StoragePaths? paths,
    AssetBundle? bundle,
    PhotoSource? photoSource,
    http.Client? httpClient,
    bool startConnectivity = true,
    void Function(String message)? onProgress,
  }) async {
    final resolved = paths ?? await StoragePaths.resolve();
    onProgress?.call('Veritabanı açılıyor…');
    final database = await AppDatabase.open(resolved.databaseFile, bundle: bundle, onProgress: onProgress);
    final events = DataEvents();
    final countries = CountryRepository(database.db, events);
    await countries.load();
    final settingsRepo = SettingsRepository(database.db);
    await settingsRepo.load();
    onProgress?.call('Harita hazırlanıyor…');
    final shapes = MapShapeService();
    await shapes.load(bundle: bundle);
    final connectivity = ConnectivityService();
    if (startConnectivity) await connectivity.start();
    return AppServices._(
      paths: resolved,
      database: database,
      events: events,
      countries: countries,
      cities: CityRepository(database.db, events),
      travels: TravelRepository(database.db, events, countries),
      plans: PlanRepository(database.db, events, countries),
      expenses: ExpenseRepository(database.db, events),
      settingsRepo: settingsRepo,
      settings: SettingsController(settingsRepo),
      shapes: shapes,
      photos: PhotoService(resolved, source: photoSource),
      countryInfo: CountryInfoService(database.db, client: httpClient),
      routing: RoutingService(client: httpClient),
      connectivity: connectivity,
    );
  }

  Future<void> dispose() async {
    connectivity.dispose();
    await database.close();
  }
}
