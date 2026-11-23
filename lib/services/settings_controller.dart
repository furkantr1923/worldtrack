import 'package:flutter/material.dart';

import '../data/repositories/settings_repository.dart';
import 'routing_service.dart';

/// Harita altlığı sağlayıcıları. Hiçbiri API anahtarı gerektirmez; ülke sınırları
/// her durumda uygulamanın içinden çizildiği için "Kapalı" seçeneği tamamen çevrimdışıdır.
enum BasemapProvider {
  carto('CARTO (sade, temaya uyumlu)'),
  osm('OpenStreetMap Standart'),
  none('Kapalı — yalnızca ülke sınırları'),
  custom('Özel karo adresi');

  const BasemapProvider(this.label);
  final String label;

  static BasemapProvider parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => BasemapProvider.carto);
}

class BasemapConfig {
  const BasemapConfig({
    required this.urlTemplate,
    required this.subdomains,
    required this.attribution,
    this.maxNativeZoom = 19,
  });

  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
  final int maxNativeZoom;
}

/// Kullanıcı ayarları (tema, harita, güzergâh tahmini). Değişince arayüz yenilenir.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repo);

  final SettingsRepository _repo;

  static const _kTheme = 'theme_mode';
  static const _kBasemap = 'basemap';
  static const _kCustomUrl = 'basemap_custom_url';
  static const _kRouting = 'routing_enabled';
  static const _kRoutingServer = 'routing_server';

  ThemeMode get themeMode => switch (_repo.get(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  BasemapProvider get basemap => BasemapProvider.parse(_repo.get(_kBasemap));
  String get customTileUrl => _repo.getOr(_kCustomUrl, '');
  bool get routingEnabled => _repo.getBool(_kRouting);
  String get routingServer => _repo.getOr(_kRoutingServer, RoutingService.defaultServer);

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.set(_kTheme, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setBasemap(BasemapProvider p) async {
    await _repo.set(_kBasemap, p.name);
    notifyListeners();
  }

  /// Özel karo adresi {z}, {x}, {y} içermelidir. Geçersizse hata mesajı döner.
  Future<String?> setCustomTileUrl(String url) async {
    final u = url.trim();
    if (!(u.startsWith('https://') || u.startsWith('http://'))) return 'Adres http(s):// ile başlamalı.';
    if (!u.contains('{z}') || !u.contains('{x}') || !u.contains('{y}')) {
      return 'Adres {z}, {x} ve {y} yer tutucularını içermeli.';
    }
    await _repo.set(_kCustomUrl, u);
    notifyListeners();
    return null;
  }

  Future<void> setRoutingEnabled(bool v) async {
    await _repo.setBool(_kRouting, v);
    notifyListeners();
  }

  Future<String?> setRoutingServer(String url) async {
    final u = url.trim();
    if (!u.startsWith('https://') && !u.startsWith('http://')) return 'Adres http(s):// ile başlamalı.';
    await _repo.set(_kRoutingServer, u);
    notifyListeners();
    return null;
  }

  /// Seçili altlığın karo yapılandırması; kapalıysa null.
  BasemapConfig? basemapFor(Brightness brightness) {
    switch (basemap) {
      case BasemapProvider.carto:
        final style = brightness == Brightness.dark ? 'dark_nolabels' : 'light_nolabels';
        return BasemapConfig(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/$style/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          attribution: '© OpenStreetMap katkıda bulunanlar · © CARTO',
          maxNativeZoom: 19,
        );
      case BasemapProvider.osm:
        return const BasemapConfig(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: [],
          attribution: '© OpenStreetMap katkıda bulunanlar',
          maxNativeZoom: 19,
        );
      case BasemapProvider.custom:
        final url = customTileUrl;
        if (url.isEmpty) return null;
        return BasemapConfig(
          urlTemplate: url,
          subdomains: const ['a', 'b', 'c'],
          attribution: 'Özel karo sağlayıcısı',
        );
      case BasemapProvider.none:
        return null;
    }
  }
}
