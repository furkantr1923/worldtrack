import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Coğrafi hesaplar. Burada üretilen hiçbir değer "gerçek güzergâh" değildir;
/// yalnızca iki nokta arasındaki kuş uçuşu mesafe ve büyük daire yayıdır.
class Geo {
  Geo._();

  static const double earthRadiusKm = 6371.0088;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  /// Haversine formülüyle kuş uçuşu mesafe (km).
  static double distanceKm(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h.toDouble())));
  }

  /// İki nokta arasındaki büyük daire yayını [segments] parçaya böler.
  /// Uçuşları göstermek için kullanılır; gerçek uçuş rotası değildir.
  static List<LatLng> greatCircle(LatLng a, LatLng b, {int segments = 64}) {
    final lat1 = _rad(a.latitude), lon1 = _rad(a.longitude);
    final lat2 = _rad(b.latitude), lon2 = _rad(b.longitude);
    final d = 2 *
        math.asin(math.sqrt(math.pow(math.sin((lat2 - lat1) / 2), 2) +
            math.cos(lat1) * math.cos(lat2) * math.pow(math.sin((lon2 - lon1) / 2), 2)));
    if (d < 1e-9) return [a, b];
    final points = <LatLng>[];
    double? prevLon;
    for (var i = 0; i <= segments; i++) {
      final f = i / segments;
      final fa = math.sin((1 - f) * d) / math.sin(d);
      final fb = math.sin(f * d) / math.sin(d);
      final x = fa * math.cos(lat1) * math.cos(lon1) + fb * math.cos(lat2) * math.cos(lon2);
      final y = fa * math.cos(lat1) * math.sin(lon1) + fb * math.cos(lat2) * math.sin(lon2);
      final z = fa * math.sin(lat1) + fb * math.sin(lat2);
      final lat = _deg(math.atan2(z, math.sqrt(x * x + y * y)));
      var lon = _deg(math.atan2(y, x));
      // Tarih değiştirme çizgisinde kesintisiz çizim için boylamı açarız.
      if (prevLon != null) {
        while (lon - prevLon > 180) {
          lon -= 360;
        }
        while (lon - prevLon < -180) {
          lon += 360;
        }
      }
      prevLon = lon;
      points.add(LatLng(lat.clamp(-90.0, 90.0), lon));
    }
    return points;
  }

  /// Ray-casting ile nokta-poligon testi. [ring] kapalı kabul edilir.
  static bool pointInRing(double lon, double lat, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Boylamı -180..180 aralığına getirir.
  static double normalizeLon(double lon) {
    var l = lon;
    while (l > 180) {
      l -= 360;
    }
    while (l < -180) {
      l += 360;
    }
    return l;
  }

  static String formatKm(double km) {
    if (km < 1) return '< 1 km';
    final rounded = km < 100 ? km.round() : (km / 10).round() * 10;
    final s = rounded.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '$s km';
  }
}
