import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connectivity_service.dart';
import '../../services/settings_controller.dart';

/// Ülke sınırları uygulamanın içinden (Natural Earth) çizilen etkileşimli dünya haritası.
///
/// * Altlık karolar isteğe bağlıdır ve internet yoksa sessizce boş kalır;
///   ülkeler, renkler ve tıklama yine çalışır.
/// * Ülke tıklaması kendi nokta-poligon testimizle yapılır (platformdan bağımsız).
class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    this.controller,
    this.visited = const {},
    this.planned = const {},
    this.selected,
    this.onCountryTap,
    this.overlays = const [],
    this.showLabels = true,
    this.interactive = true,
    this.initialCenter = const LatLng(28, 18),
    this.initialZoom = 2.2,
    this.onReady,
  });

  final MapController? controller;
  final Set<String> visited;
  final Set<String> planned;
  final String? selected;
  final ValueChanged<String?>? onCountryTap;
  final List<Widget> overlays;
  final bool showLabels;
  final bool interactive;
  final LatLng initialCenter;
  final double initialZoom;
  final VoidCallback? onReady;

  static const double minZoom = 1.4;
  static const double maxZoom = 14;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  late final MapController _controller = widget.controller ?? MapController();
  StreamSubscription<MapEvent>? _events;
  double _zoom = 2.2;
  LatLngBounds? _bounds;
  Timer? _throttle;

  List<Polygon<Object>>? _polygons;
  String? _polygonKey;

  @override
  void dispose() {
    _events?.cancel();
    _throttle?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _events = _controller.mapEventStream.listen((event) {
      _throttle ??= Timer(const Duration(milliseconds: 90), () {
        _throttle = null;
        if (!mounted) return;
        setState(() {
          _zoom = event.camera.zoom;
          _bounds = event.camera.visibleBounds;
        });
      });
    });
    setState(() {
      _zoom = _controller.camera.zoom;
      _bounds = _controller.camera.visibleBounds;
    });
    widget.onReady?.call();
  }

  List<Polygon<Object>> _buildPolygons(AppServices services, Brightness b, bool tilesOn) {
    final key = '${b.name}|$tilesOn|${widget.selected}|${(widget.visited.toList()..sort()).join(',')}|'
        '${(widget.planned.toList()..sort()).join(',')}';
    if (_polygons != null && key == _polygonKey) return _polygons!;
    final land = WtColors.land(b).withValues(alpha: tilesOn ? 0.45 : 1);
    final border = WtColors.border(b);
    final normal = <Polygon<Object>>[];
    final selected = <Polygon<Object>>[];
    for (final shape in services.shapes.shapes.values) {
      final code = shape.code;
      final isSel = code == widget.selected;
      final Color fill;
      if (isSel) {
        fill = WtColors.coral.withValues(alpha: 0.55);
      } else if (widget.visited.contains(code)) {
        fill = WtColors.visited.withValues(alpha: b == Brightness.dark ? 0.75 : 0.62);
      } else if (widget.planned.contains(code)) {
        fill = WtColors.sunset.withValues(alpha: 0.6);
      } else {
        fill = land;
      }
      for (final part in shape.parts) {
        (isSel ? selected : normal).add(Polygon<Object>(
          points: part.first,
          holePointsList: part.length > 1 ? part.sublist(1) : null,
          color: fill,
          borderColor: isSel ? WtColors.coral : border,
          borderStrokeWidth: isSel ? 2.2 : 0.6,
        ));
      }
    }
    // Seçili ülkenin kenarı komşularının altında kalmasın diye en sona çizilir.
    final out = [...normal, ...selected];
    _polygonKey = key;
    _polygons = out;
    return out;
  }

  List<Marker> _labels(AppServices services, Brightness b) {
    if (!widget.showLabels) return const [];
    final bounds = _bounds;
    final out = <Marker>[];
    final textColor = b == Brightness.dark ? Colors.white : const Color(0xFF1E2B3A);
    final halo = b == Brightness.dark ? const Color(0xCC0B1A2B) : const Color(0xE6FFFFFF);
    for (final c in services.countries.all) {
      final p = c.labelPoint;
      if (p == null) continue;
      final min = c.minLabel ?? 5;
      if (_zoom + 0.6 < min) continue;
      if (bounds != null && !bounds.contains(p)) continue;
      final big = _zoom >= min + 1.5;
      out.add(Marker(
        point: p,
        width: 150,
        height: 30,
        child: IgnorePointer(
          child: Center(
            child: Text(
              c.nameTr,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontFamily: AppTheme.font,
                fontSize: big ? 12.5 : 11,
                fontWeight: c.code == widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
                shadows: [
                  Shadow(color: halo, blurRadius: 3),
                  Shadow(color: halo, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ));
      if (out.length > 160) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final settings = context.watch<SettingsController>();
    final brightness = Theme.of(context).brightness;
    final online = context.select<ConnectivityService, bool>((c) => c.online);
    final basemap = settings.basemapFor(brightness);
    final tilesOn = basemap != null && online;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        minZoom: WorldMap.minZoom,
        maxZoom: WorldMap.maxZoom,
        backgroundColor: WtColors.ocean(brightness),
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(const LatLng(-80, -180), const LatLng(84, 180)),
        ),
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: _onMapReady,
        onTap: widget.onCountryTap == null
            ? null
            : (_, point) => widget.onCountryTap!(services.shapes.hitTest(point)),
      ),
      children: [
        if (tilesOn)
          TileLayer(
            urlTemplate: basemap.urlTemplate,
            subdomains: basemap.subdomains,
            maxNativeZoom: basemap.maxNativeZoom,
            userAgentPackageName: 'com.furkanbaykal.worldtrack',
            retinaMode: basemap.urlTemplate.contains('{r}') && RetinaMode.isHighDensity(context),
            errorTileCallback: (tile, error, stackTrace) =>
                context.read<ConnectivityService>().reportTileError(),
          ),
        PolygonLayer<Object>(
          polygons: _buildPolygons(services, brightness, tilesOn),
          simplificationTolerance: 0.4,
        ),
        ...widget.overlays,
        MarkerLayer(markers: _labels(services, brightness)),
        if (tilesOn)
          SimpleAttributionWidget(
            source: Text(basemap.attribution, style: const TextStyle(fontSize: 11)),
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}
