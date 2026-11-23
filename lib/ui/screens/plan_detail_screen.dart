import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../services/connectivity_service.dart';
import '../../services/routing_service.dart';
import '../../services/settings_controller.dart';
import '../../viewmodels/plans_view_model.dart';
import '../map/route_layers.dart';
import '../map/world_map.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/expenses_section.dart';
import '../widgets/form_fields.dart';

class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final int planId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PlanDetailViewModel(ctx.read<AppServices>(), planId)..refresh(),
      child: const _PlanDetailView(),
    );
  }
}

class _PlanDetailView extends StatelessWidget {
  const _PlanDetailView();

  Future<void> _delete(BuildContext context, PlanDetailViewModel vm) async {
    final ok = await confirmDialog(
      context,
      title: 'Plan silinsin mi?',
      message: '"${vm.plan!.title}" planı ve durakları silinecek. Bu plandan oluşturulmuş seyahat kayıtları silinmez.',
    );
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    await vm.delete();
    nav.pop();
  }

  Future<void> _convert(BuildContext context, PlanDetailViewModel vm) async {
    final plan = vm.plan!;
    final services = context.read<AppServices>();
    final drafts = services.plans.draftRecords(plan);
    if (drafts.isEmpty) {
      showMessage(context, 'Dönüştürmek için en az bir durakta şehir seçili olmalı. Planı düzenleyip şehir ekle.',
          error: true);
      return;
    }
    final result = await showDialog<List<TravelRecord>>(
      context: context,
      builder: (_) => _ConvertDialog(plan: plan, drafts: drafts),
    );
    if (result == null || !context.mounted) return;
    try {
      final ids = await services.plans.convertToRecords(plan.id!, result);
      if (context.mounted) showMessage(context, '${ids.length} seyahat kaydı oluşturuldu. Haritan güncellendi.');
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlanDetailViewModel>();
    if (vm.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final plan = vm.plan;
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Plan bulunamadı', message: 'Bu plan silinmiş olabilir.'),
      );
    }
    final theme = Theme.of(context);
    final wide = isWide(context);
    final map = _RouteMap(plan: plan);
    final details = _PlanDetails(plan: plan, vm: vm, onConvert: () => _convert(context, vm));

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [
          IconButton(
            key: const Key('editPlan'),
            tooltip: 'Düzenle',
            onPressed: () => AppNav.editPlan(context, plan),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('deletePlan'),
            tooltip: 'Sil',
            onPressed: () => _delete(context, vm),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 460, child: details),
                VerticalDivider(width: 1, color: theme.dividerTheme.color),
                Expanded(child: map),
              ],
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: 320, child: map),
                details,
              ],
            ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.plan, required this.vm, required this.onConvert});
  final PlannedTrip plan;
  final PlanDetailViewModel vm;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final points = routePointsFor(plan);
    var total = 0.0;
    for (var i = 0; i + 1 < points.length; i++) {
      total += Geo.distanceKm(points[i].point, points[i + 1].point);
    }
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            plan.isCompleted
                ? const StatusPill(label: 'Tamamlandı', color: StatusColors.visited, icon: Icons.task_alt_rounded)
                : const StatusPill(label: 'Planlandı', color: StatusColors.planned, icon: Icons.event),
            Text(Dates.range(plan.startDate, plan.effectiveEnd), style: theme.textTheme.titleSmall),
          ],
        ),
        if (plan.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(plan.notes, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        if (!plan.isCompleted)
          FilledButton.icon(
            key: const Key('convertPlan'),
            onPressed: plan.stops.isEmpty ? null : onConvert,
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Gerçekleşti: seyahate dönüştür'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => context.read<AppServices>().plans.reopen(plan.id!),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Tekrar "planlandı" yap'),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Rota · ${plan.stops.length} durak', style: theme.textTheme.titleMedium)),
            if (points.length > 1)
              Tooltip(
                message: 'Duraklar arasındaki düz çizgi mesafelerinin toplamı. Gerçek yol mesafesi farklıdır.',
                child: Text('≈ ${Geo.formatKm(total)} kuş uçuşu', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (plan.stops.isEmpty)
          const WtCard(child: Text('Bu planda durak yok. Düzenle ile durak ekleyebilirsin.'))
        else
          for (var i = 0; i < plan.stops.length; i++) _StopRow(plan: plan, index: i),
        const SizedBox(height: 12),
        ExpensesSection(tripId: plan.id, expenses: vm.expenses),
      ],
    );
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), child: list);
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.plan, required this.index});
  final PlannedTrip plan;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = plan.stops[index];
    final prev = index > 0 ? plan.stops[index - 1] : null;
    final a = prev?.city?.point, b = s.city?.point;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prev != null)
          Padding(
            padding: const EdgeInsets.only(left: 13, top: 2, bottom: 2),
            child: Row(
              children: [
                Container(width: 2, height: 26, color: theme.colorScheme.outlineVariant),
                const SizedBox(width: 18),
                if (s.transport != null) ...[
                  Icon(s.transport!.icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(s.transport!.label, style: theme.textTheme.bodySmall),
                ] else
                  Text('Ulaşım belirtilmedi', style: theme.textTheme.bodySmall),
                if (a != null && b != null)
                  Text('  ·  ≈ ${Geo.formatKm(Geo.distanceKm(a, b))} kuş uçuşu', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => AppNav.country(context, s.countryCode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: WtColors.coral,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                CountryFlag(code: s.countryCode, width: 24, radius: 3),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.city?.nameTr ?? s.country?.nameTr ?? s.countryCode, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          if (s.city != null) s.country?.nameTr ?? '',
                          if (s.city == null) 'Şehir seçilmedi',
                          if (s.durationDays != null) Dates.duration(s.durationDays!),
                          if (s.arrivalDate != null) 'Varış ${Dates.short(s.arrivalDate!)}',
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rota haritası. Bağlantı türleri lejantta açıkça ayrılır.
class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.plan});
  final PlannedTrip plan;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final MapController _map = MapController();
  final Map<int, RouteEstimate> _estimates = {};
  String? _routingError;
  bool _routingBusy = false;
  bool _ready = false;

  @override
  void didUpdateWidget(covariant _RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      _estimates.clear();
      _fit();
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fit() {
    if (!_ready) return;
    final pts = routePointsFor(widget.plan).map((p) => p.point).toList();
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(pts.first, 5);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(60), maxZoom: 8));
  }

  Future<void> _estimateRoads() async {
    final services = context.read<AppServices>();
    final settings = context.read<SettingsController>();
    final pts = routePointsFor(widget.plan);
    setState(() {
      _routingBusy = true;
      _routingError = null;
    });
    for (var i = 0; i + 1 < pts.length; i++) {
      final stop = widget.plan.stops[pts[i + 1].index];
      final road = stop.transport == TransportType.car || stop.transport == TransportType.bus;
      if (!road || pts[i].approximate || pts[i + 1].approximate) continue;
      try {
        _estimates[i] = await services.routing.drivingRoute(pts[i].point, pts[i + 1].point, server: settings.routingServer);
      } catch (e) {
        _routingError = e is RoutingException ? e.message : friendlyError(e);
      }
    }
    if (mounted) setState(() => _routingBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final online = context.select<ConnectivityService, bool>((c) => c.online);
    final pts = routePointsFor(widget.plan);
    final segments = <RouteSegment>[
      for (var i = 0; i + 1 < pts.length; i++)
        RouteSegment(
          from: pts[i],
          to: pts[i + 1],
          transport: widget.plan.stops[pts[i + 1].index].transport,
          estimate: _estimates[i],
        ),
    ];
    final hasRoad = segments.any((s) =>
        (s.transport == TransportType.car || s.transport == TransportType.bus) &&
        !s.from.approximate &&
        !s.to.approximate);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: WorldMap(
            controller: _map,
            showLabels: false,
            visited: const {},
            planned: widget.plan.countryCodes,
            initialCenter: pts.isEmpty ? const LatLng(30, 20) : pts.first.point,
            initialZoom: pts.isEmpty ? 2 : 4,
            onReady: () {
              _ready = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
            },
            overlays: [
              PolylineLayer(polylines: segmentPolylines(segments)),
              MarkerLayer(markers: stopMarkers(pts)),
            ],
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          right: 12,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Material(
              color: scheme.surfaceContainerLowest.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LegendLine(color: WtColors.coral, text: 'Uçak: büyük daire yayı (gerçek uçuş rotası değil)'),
                    const _LegendLine(color: WtColors.sunset, text: 'Diğer: basit bağlantı (gerçek yol değil)'),
                    if (_estimates.isNotEmpty)
                      const _LegendLine(color: WtColors.brand, text: 'Tahmini karayolu güzergâhı (OSRM)', solid: true),
                    if (pts.any((p) => p.approximate))
                      const Text('Beyaz daireler: şehir seçilmemiş durak (ülke merkezi, yaklaşık).',
                          style: TextStyle(fontSize: 11.5)),
                    if (hasRoad && settings.routingEnabled && _estimates.isEmpty) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: !online || _routingBusy ? null : _estimateRoads,
                        icon: _routingBusy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.alt_route_rounded, size: 18),
                        label: Text(online ? 'Karayolu güzergâhını tahmin et' : 'Güzergâh tahmini için bağlantı gerekli'),
                      ),
                    ],
                    if (hasRoad && !settings.routingEnabled)
                      Text('Karayolu tahmini Ayarlar\'dan açılabilir (isteğe bağlı).',
                          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    if (_routingError != null)
                      Text(_routingError!, style: TextStyle(fontSize: 11.5, color: scheme.error)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.text, this.solid = false});
  final Color color;
  final String text;
  final bool solid;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              child: Row(
                children: solid
                    ? [Expanded(child: Container(height: 4, color: color))]
                    : [
                        for (var i = 0; i < 3; i++) ...[
                          Container(width: 6, height: 3, color: color),
                          if (i < 2) const SizedBox(width: 4),
                        ],
                      ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(text, style: const TextStyle(fontSize: 11.5))),
          ],
        ),
      );
}

/// Planı seyahat kayıtlarına dönüştürmeden önce tarih ve süreleri onaylatır.
class _ConvertDialog extends StatefulWidget {
  const _ConvertDialog({required this.plan, required this.drafts});
  final PlannedTrip plan;
  final List<TravelRecord> drafts;

  @override
  State<_ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends State<_ConvertDialog> {
  late final List<DateTime> _dates = widget.drafts.map((d) => d.visitDate).toList();
  late final List<int> _durations = widget.drafts.map((d) => d.durationDays).toList();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final skipped = widget.plan.stops.where((s) => s.cityId == null).length;
    final today = Dates.today();
    return AlertDialog(
      title: const Text('Seyahate dönüştür'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Her şehir durağı için bir seyahat kaydı oluşturulacak. Tarihleri kontrol et:'),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.drafts.length; i++) ...[
                Text(widget.drafts[i].city?.nameTr ?? '', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                DateField(
                  label: 'Varış',
                  value: _dates[i],
                  lastDate: today,
                  onChanged: (d) => setState(() => _dates[i] = d ?? _dates[i]),
                ),
                const SizedBox(height: 8),
                DurationField(value: _durations[i], onChanged: (v) => setState(() => _durations[i] = v)),
                const SizedBox(height: 14),
              ],
              if (skipped > 0)
                Text('$skipped durakta şehir seçilmediği için kayıt oluşturulmayacak.',
                    style: Theme.of(context).textTheme.bodySmall),
              if (_error != null) ErrorBox(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('confirmConvert'),
          onPressed: () {
            if (_dates.any((d) => d.isAfter(today))) {
              setState(() => _error = 'Gelecekteki tarihler seyahat kaydı olamaz. Tarihleri düzelt.');
              return;
            }
            Navigator.pop(context, [
              for (var i = 0; i < widget.drafts.length; i++)
                TravelRecord(
                  countryCode: widget.drafts[i].countryCode,
                  cityId: widget.drafts[i].cityId,
                  visitDate: _dates[i],
                  durationDays: _durations[i],
                  transport: widget.drafts[i].transport,
                  planId: widget.plan.id,
                ),
            ]);
          },
          child: const Text('Dönüştür'),
        ),
      ],
    );
  }
}
