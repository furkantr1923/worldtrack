import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Karayolu güzergâh TAHMİNİ (isteğe bağlı, varsayılan kapalı).
///
/// OSRM uyumlu bir sunucuya yalnızca iki durağın koordinatları gönderilir.
/// Varsayılan sunucu OSRM'nin herkese açık demo sunucusudur: ücretsizdir ama
/// hizmet garantisi yoktur ve yoğun kullanım için uygun değildir. Ayarlardan
/// kendi sunucunuzu girebilirsiniz. Sonuç her zaman "tahmini" olarak etiketlenir.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, RouteEstimate> _cache = {};

  static const String defaultServer = 'https://router.project-osrm.org';

  Future<RouteEstimate> drivingRoute(LatLng a, LatLng b, {required String server}) async {
    final key = '$server|${a.latitude},${a.longitude}|${b.latitude},${b.longitude}';
    final hit = _cache[key];
    if (hit != null) return hit;
    final base = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final uri = Uri.parse('$base/route/v1/driving/'
        '${a.longitude.toStringAsFixed(5)},${a.latitude.toStringAsFixed(5)};'
        '${b.longitude.toStringAsFixed(5)},${b.latitude.toStringAsFixed(5)}'
        '?overview=simplified&geometries=geojson');
    final res = await _client
        .get(uri, headers: const {'User-Agent': 'WORLDTRACK/1.0'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw RoutingException('Güzergâh servisi yanıtı: ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') throw RoutingException('Karayolu güzergâhı bulunamadı (${body['code']}).');
    final route = (body['routes'] as List).first as Map<String, dynamic>;
    final coords = ((route['geometry'] as Map<String, dynamic>)['coordinates'] as List)
        .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final est = RouteEstimate(
      points: coords,
      distanceKm: (route['distance'] as num).toDouble() / 1000,
      durationHours: (route['duration'] as num).toDouble() / 3600,
    );
    _cache[key] = est;
    return est;
  }
}

class RouteEstimate {
  const RouteEstimate({required this.points, required this.distanceKm, required this.durationHours});
  final List<LatLng> points;
  final double distanceKm;
  final double durationHours;
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}
