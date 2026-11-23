import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../services/connectivity_service.dart';
import '../../services/settings_controller.dart';
import '../../viewmodels/map_view_model.dart';
import '../map/world_map.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => MapViewModel(ctx.read<AppServices>())..refresh(),
      child: const _MapView(),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final MapController _map = MapController();
  bool _ready = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(WorldMap.minZoom, WorldMap.maxZoom));
  }

  void _resetView() {
    if (_ready) _map.move(const LatLng(28, 18), 2.2);
  }

  /// Seçilen ülkeye kamerayı yumuşakça odaklar.
  void _focus(String code) {
    if (!_ready) return;
    final shape = context.read<AppServices>().shapes.shapeOf(code);
    if (shape == null) return;
    final b = shape.mainBounds;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(b.minLat, b.minLon), LatLng(b.maxLat, b.maxLon)),
      padding: EdgeInsets.fromLTRB(60, 120, isWide(context) ? 420 : 60, isWide(context) ? 60 : 260),
      maxZoom: 7,
    ));
  }

  Future<void> _searchCountry(MapViewModel vm) async {
    final c = await pickCountry(context, title: 'Haritada ülke bul');
    if (c == null || !mounted) return;
    await vm.select(c.code);
    _focus(c.code);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MapViewModel>();
    final wide = isWide(context);
    final selected = vm.selected;
    final panel = selected == null ? null : _CountryPanel(vm: vm, country: selected);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: WorldMap(
              key: const Key('worldMap'),
              controller: _map,
              visited: vm.visited,
              planned: vm.planned,
              selected: vm.selectedCode,
              onReady: () => _ready = true,
              onCountryTap: (code) => vm.select(code),
            ),
          ),
          // Üst çubuk: arama + lejant
          Positioned(
            left: 16,
            right: wide && panel != null ? 416 : 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(onTap: () => _searchCountry(vm)),
                    const SizedBox(height: 10),
                    const _LegendBar(),
                    const _TileWarning(),
                  ],
                ),
              ),
            ),
          ),
          // Yakınlaştırma düğmeleri
          Positioned(
            right: wide && panel != null ? 416 : 16,
            bottom: wide ? 24 : (panel != null ? 300 : 24),
            child: _ZoomControls(
              onIn: () => _zoomBy(1),
              onOut: () => _zoomBy(-1),
              onReset: _resetView,
            ),
          ),
          if (panel != null && wide)
            Positioned(
              top: 16,
              right: 16,
              bottom: 16,
              width: 384,
              child: panel,
            ),
          if (panel != null && !wide)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                child: panel,
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('mapSearch'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Ülke ara ve haritada göster',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        );
    return Material(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            dot(WtColors.visited, 'Ziyaret edildi'),
            dot(WtColors.sunset, 'Planlandı'),
            dot(WtColors.coral, 'Seçili'),
          ],
        ),
      ),
    );
  }
}

class _TileWarning extends StatelessWidget {
  const _TileWarning();

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectivityService>();
    final settings = context.watch<SettingsController>();
    if (settings.basemap == BasemapProvider.none) return const SizedBox.shrink();
    String? text;
    if (!conn.online) {
      text = 'Çevrimdışı: altlık harita yüklenmiyor, ülke sınırları ve kayıtların kullanılabilir.';
    } else if (conn.tilesFailing) {
      text = 'Altlık harita karoları alınamıyor. Ülke seçimi çalışmaya devam eder; '
          'Ayarlar\'dan başka bir altlık seçebilirsin.';
    } else if (settings.basemap == BasemapProvider.custom && settings.customTileUrl.isEmpty) {
      text = 'Özel karo adresi girilmedi. Ayarlar\'dan adres ekle veya başka altlık seç.';
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: const Color(0xFF3A4A5E),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.layers_clear_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onIn, required this.onOut, required this.onReset});
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, VoidCallback f, Key key) => IconButton(
          key: key,
          tooltip: tip,
          onPressed: f,
          icon: Icon(icon),
        );
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.add_rounded, 'Yakınlaştır', onIn, const Key('zoomIn')),
          btn(Icons.remove_rounded, 'Uzaklaştır', onOut, const Key('zoomOut')),
          btn(Icons.public_rounded, 'Tüm dünya', onReset, const Key('zoomReset')),
        ],
      ),
    );
  }
}

class _CountryPanel extends StatelessWidget {
  const _CountryPanel({required this.vm, required this.country});
  final MapViewModel vm;
  final Country country;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final visited = vm.visited.contains(country.code);
    final planned = vm.planned.contains(country.code);
    return Material(
      key: const Key('countryPanel'),
      elevation: 6,
      shadowColor: Colors.black38,
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CountryFlag(code: country.code, width: 54, radius: 8),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(country.nameTr, style: theme.textTheme.titleLarge, key: const Key('panelCountryName')),
                      Text(
                        [country.capitalTr, country.subregion.isEmpty ? country.region : country.subregion]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => vm.select(null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (visited)
                  const StatusPill(label: 'Ziyaret edildi', color: StatusColors.visited, icon: Icons.check_rounded)
                else
                  StatusPill(label: 'Henüz gidilmedi', color: muted),
                if (planned) const StatusPill(label: 'Planlandı', color: StatusColors.planned, icon: Icons.event),
              ],
            ),
            if (vm.selectedCities.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Ziyaret ettiğin şehirler', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in vm.selectedCities.take(10))
                    Chip(
                      label: Text(c.visits > 1 ? '${c.city.nameTr} ×${c.visits}' : c.city.nameTr),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${vm.selectedRecordCount} seyahat kaydı',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ] else if (country.manualVisited) ...[
              const SizedBox(height: 10),
              Text('Bu ülke ayrıntı girilmeden "ziyaret edildi" olarak işaretlendi.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('panelDetails'),
                  onPressed: () => AppNav.country(context, country.code),
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Ülke detayları'),
                ),
                OutlinedButton.icon(
                  key: const Key('panelAddTravel'),
                  onPressed: () => AppNav.newTravel(context, country: country),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Seyahat ekle'),
                ),
                if (vm.selectedCities.isEmpty)
                  TextButton.icon(
                    key: const Key('panelToggleVisited'),
                    onPressed: vm.toggleManualVisited,
                    icon: Icon(country.manualVisited ? Icons.undo_rounded : Icons.check_circle_outline_rounded),
                    label: Text(country.manualVisited ? 'İşareti kaldır' : 'Gittim olarak işaretle'),
                  ),
              ],
            ),
            if (!country.hasShape) ...[
              const SizedBox(height: 10),
              Text('Bu bölge harita ölçeğinde ayrı çizilmiyor.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}
