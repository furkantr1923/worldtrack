import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../services/routing_service.dart';

/// Haritada gösterilecek bir durak.
class RoutePoint {
  const RoutePoint({required this.index, required this.point, required this.label, required this.approximate});
  final int index;
  final LatLng point;
  final String label;

  /// Şehir seçilmemişse ülkenin etiket noktası kullanılır; bu yaklaşık bir konumdur.
  final bool approximate;
}

/// İki ardışık durak arasındaki çizim.
class RouteSegment {
  const RouteSegment({required this.from, required this.to, this.transport, this.estimate});
  final RoutePoint from;
  final RoutePoint to;
  final TransportType? transport;

  /// Varsa karayolu güzergâh tahmini (OSRM).
  final RouteEstimate? estimate;

  double get straightKm => Geo.distanceKm(from.point, to.point);
}

List<RoutePoint> routePointsFor(PlannedTrip plan) {
  final out = <RoutePoint>[];
  for (var i = 0; i < plan.stops.length; i++) {
    final s = plan.stops[i];
    final p = s.city?.point;
    if (p != null) {
      out.add(RoutePoint(index: i, point: p, label: s.city!.nameTr, approximate: false));
    } else if (s.country?.labelPoint != null) {
      out.add(RoutePoint(index: i, point: s.country!.labelPoint!, label: s.label, approximate: true));
    }
  }
  return out;
}

/// Kesik çizgi: noktaları kısa parçalara bölerek çizer (gerçek güzergâh olmadığını vurgular).
List<Polyline> dashed(List<LatLng> points, {required Color color, double width = 3, double dashKm = 60}) {
  final out = <Polyline>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final a = points[i], b = points[i + 1];
    final km = Geo.distanceKm(a, b);
    final pieces = (km / dashKm).ceil().clamp(1, 400);
    for (var k = 0; k < pieces; k += 2) {
      final t0 = k / pieces, t1 = ((k + 1) / pieces).clamp(0.0, 1.0);
      out.add(Polyline(
        points: [
          LatLng(a.latitude + (b.latitude - a.latitude) * t0, a.longitude + (b.longitude - a.longitude) * t0),
          LatLng(a.latitude + (b.latitude - a.latitude) * t1, a.longitude + (b.longitude - a.longitude) * t1),
        ],
        color: color,
        strokeWidth: width,
      ));
    }
  }
  return out;
}

/// Segment çizimleri: uçak → büyük daire yayı (kesikli), karayolu tahmini → düz çizgi,
/// diğerleri → kesikli düz bağlantı. Hiçbiri gerçek uçuş/demiryolu güzergâhı değildir.
List<Polyline> segmentPolylines(List<RouteSegment> segments) {
  final out = <Polyline>[];
  for (final s in segments) {
    final est = s.estimate;
    if (est != null) {
      out.add(Polyline(
        points: est.points,
        color: WtColors.brand,
        strokeWidth: 4.5,
        borderColor: Colors.white,
        borderStrokeWidth: 1.5,
      ));
      continue;
    }
    final km = s.straightKm;
    final line = s.transport == TransportType.plane
        ? Geo.greatCircle(s.from.point, s.to.point, segments: 48)
        : [s.from.point, s.to.point];
    out.addAll(dashed(line,
        color: s.transport == TransportType.plane ? WtColors.coral : WtColors.sunset,
        dashKm: (km / 40).clamp(4, 120)));
  }
  return out;
}

List<Marker> stopMarkers(List<RoutePoint> points) => [
      for (final p in points)
        Marker(
          point: p.point,
          width: 34,
          height: 34,
          child: Tooltip(
            message: p.approximate ? '${p.label} (yaklaşık konum)' : p.label,
            child: Container(
              decoration: BoxDecoration(
                color: p.approximate ? Colors.white : WtColors.coral,
                shape: BoxShape.circle,
                border: Border.all(color: p.approximate ? WtColors.coral : Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              alignment: Alignment.center,
              child: Text(
                '${p.index + 1}',
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w700,
                  color: p.approximate ? WtColors.coral : Colors.white,
                ),
              ),
            ),
          ),
        ),
    ];
