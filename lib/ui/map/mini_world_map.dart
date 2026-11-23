import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/map_shape_service.dart';

/// Ana sayfadaki statik dünya özeti (eşdikdörtgen izdüşüm). Ağ gerektirmez.
/// Ülke yolları bir kez oluşturulup önbelleğe alınır; yalnızca boyanır.
class MiniWorldMap extends StatelessWidget {
  const MiniWorldMap({super.key, required this.shapes, required this.visited, required this.planned});

  final MapShapeService shapes;
  final Set<String> visited;
  final Set<String> planned;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AspectRatio(
      aspectRatio: 360 / 150,
      child: CustomPaint(
        painter: _MiniMapPainter(
          paths: _MiniPaths.of(shapes),
          visited: visited,
          planned: planned,
          land: b == Brightness.dark ? const Color(0xFF2A3D58) : const Color(0xFFD5E2EA),
          stroke: b == Brightness.dark ? const Color(0xFF0F1A2B) : Colors.white,
        ),
      ),
    );
  }
}

class _MiniPaths {
  _MiniPaths(this.byCode);
  final Map<String, Path> byCode;

  static _MiniPaths? _cache;
  static MapShapeService? _cacheSource;

  /// Boylam -180..180 → x 0..360, enlem 84..-66 → y 0..150 (Antarktika dışarıda).
  static _MiniPaths of(MapShapeService shapes) {
    if (_cache != null && identical(_cacheSource, shapes)) return _cache!;
    final out = <String, Path>{};
    shapes.shapes.forEach((code, shape) {
      if (code == 'AQ') return;
      final path = Path();
      for (final part in shape.parts) {
        final ring = part.first;
        if (ring.length < 3) continue;
        path.moveTo(ring.first.longitude + 180, 84 - ring.first.latitude);
        for (var i = 1; i < ring.length; i++) {
          path.lineTo(ring[i].longitude + 180, 84 - ring[i].latitude);
        }
        path.close();
      }
      out[code] = path;
    });
    _cacheSource = shapes;
    return _cache = _MiniPaths(out);
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.paths,
    required this.visited,
    required this.planned,
    required this.land,
    required this.stroke,
  });

  final _MiniPaths paths;
  final Set<String> visited;
  final Set<String> planned;
  final Color land;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 150);
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25
      ..color = stroke;
    paths.byCode.forEach((code, path) {
      fill.color = visited.contains(code)
          ? WtColors.visited
          : planned.contains(code)
              ? WtColors.sunset
              : land;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.visited != visited || old.planned != planned || old.land != land || old.paths != paths;
}
