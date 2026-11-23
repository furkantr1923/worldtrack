import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../core/utils/geo.dart';

/// Bir ülkenin harita şekli: bir veya daha fazla poligon (ada ülkeleri için çok parçalı).
class CountryShape {
  CountryShape(this.code, this.parts);

  final String code;

  /// Her parça: [0] dış halka, [1..] delikler.
  final List<List<List<LatLng>>> parts;

  late final ({double minLat, double maxLat, double minLon, double maxLon}) bounds = _computeBounds();

  ({double minLat, double maxLat, double minLon, double maxLon}) _computeBounds() {
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final part in parts) {
      for (final p in part.first) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLon) minLon = p.longitude;
        if (p.longitude > maxLon) maxLon = p.longitude;
      }
    }
    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }

  bool contains(LatLng point) {
    final lon = Geo.normalizeLon(point.longitude), lat = point.latitude;
    final b = bounds;
    if (lat < b.minLat || lat > b.maxLat || lon < b.minLon || lon > b.maxLon) return false;
    for (final part in parts) {
      if (Geo.pointInRing(lon, lat, part.first) &&
          !part.skip(1).any((hole) => Geo.pointInRing(lon, lat, hole))) {
        return true;
      }
    }
    return false;
  }

  /// En büyük parçanın sınırları (ör. Fransa için Avrupa kısmı) — kamerayı odaklamak için.
  ({double minLat, double maxLat, double minLon, double maxLon}) get mainBounds {
    List<LatLng>? biggest;
    var bestArea = -1.0;
    for (final part in parts) {
      final ring = part.first;
      var area = 0.0;
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        area += (ring[j].longitude + ring[i].longitude) * (ring[j].latitude - ring[i].latitude);
      }
      area = area.abs();
      if (area > bestArea) {
        bestArea = area;
        biggest = ring;
      }
    }
    if (biggest == null) return bounds;
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in biggest) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }
}

/// Uygulamayla gelen Natural Earth ülke sınırlarını yükler ve tıklama testini yapar.
/// İnternet gerektirmez; harita altlığı yüklenemese bile ülke seçimi çalışır.
class MapShapeService {
  final Map<String, CountryShape> _shapes = {};

  Map<String, CountryShape> get shapes => _shapes;
  bool get isLoaded => _shapes.isNotEmpty;

  CountryShape? shapeOf(String code) => _shapes[code];

  Future<void> load({AssetBundle? bundle}) async {
    if (isLoaded) return;
    final raw = await (bundle ?? rootBundle).loadString('assets/data/world_shapes.json');
    final parsed = await Isolate.run(() => _parseShapes(raw));
    _shapes
      ..clear()
      ..addAll(parsed);
  }

  /// Dokunulan noktadaki ülke. Küçük ülkeler büyüklerin içinde kalabileceği
  /// için (ör. Vatikan / İtalya) önce en küçük sınır kutusuna sahip olan seçilir.
  String? hitTest(LatLng point) {
    String? best;
    var bestArea = double.infinity;
    for (final s in _shapes.values) {
      if (!s.contains(point)) continue;
      final b = s.bounds;
      final area = (b.maxLat - b.minLat) * (b.maxLon - b.minLon);
      if (area < bestArea) {
        bestArea = area;
        best = s.code;
      }
    }
    return best;
  }
}

Map<String, CountryShape> _parseShapes(String raw) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final out = <String, CountryShape>{};
  data.forEach((code, polys) {
    final parts = <List<List<LatLng>>>[];
    for (final poly in polys as List) {
      final rings = <List<LatLng>>[];
      for (final ring in poly as List) {
        final flat = ring as List;
        final pts = <LatLng>[];
        for (var i = 0; i + 1 < flat.length; i += 2) {
          pts.add(LatLng((flat[i + 1] as num) / 100.0, (flat[i] as num) / 100.0));
        }
        if (pts.length >= 3) rings.add(pts);
      }
      if (rings.isNotEmpty) parts.add(rings);
    }
    out[code] = CountryShape(code, parts);
  });
  return out;
}
