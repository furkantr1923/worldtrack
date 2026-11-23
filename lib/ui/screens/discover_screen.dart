import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/turkish_text.dart';
import '../../data/data_events.dart';
import '../../data/models/models.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// Keşfet: ülkeleri bölgeye göre gezme. Kişisel kayıtlar yalnızca rozet olarak görünür;
/// genel bilgiler (başkent, bölge) açık veri kaynaklarından gelir. Öneri uydurulmaz.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _region = 'Tümü';
  bool _onlyUnvisited = false;
  String _query = '';
  Set<String> _visited = const {};
  Set<String> _planned = const {};
  late final DataEvents _events = context.read<AppServices>().events;

  static const _regions = ['Tümü', 'Avrupa', 'Asya', 'Afrika', 'Amerika', 'Okyanusya'];

  @override
  void initState() {
    super.initState();
    _events.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _events.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.read<AppServices>();
    final v = await s.countries.visitedCodes();
    final p = await s.countries.plannedCodes();
    if (mounted) {
      setState(() {
        _visited = v;
        _planned = p;
      });
    }
  }

  List<Country> _filtered(List<Country> all) {
    final q = TurkishText.fold(_query);
    return all.where((c) {
      if (c.code == 'AQ') return false;
      if (_region != 'Tümü' && c.region != _region) return false;
      if (_onlyUnvisited && _visited.contains(c.code)) return false;
      if (q.isNotEmpty && !TurkishText.fold('${c.nameTr} ${c.nameEn} ${c.capitalTr}').contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.read<AppServices>().countries.all;
    final list = _filtered(all);
    final wide = isWide(context);
    final pad = wide ? 32.0 : 16.0;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Keşfet')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dünyanın ${all.length - 1} ülke ve bölgesini incele. Bilgiler Natural Earth, GeoNames ve '
                    'Vikipedi\'den gelir.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('discoverSearch'),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Ülke veya başkent ara'),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final r in _regions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(r),
                              selected: _region == r,
                              onSelected: (_) => setState(() => _region = r),
                            ),
                          ),
                        FilterChip(
                          label: const Text('Gitmediklerim'),
                          selected: _onlyUnvisited,
                          onSelected: (v) => setState(() => _onlyUnvisited = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${list.length} sonuç', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.travel_explore_rounded, title: 'Sonuç yok', message: 'Filtreleri değiştir.'),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 172,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return WtCard(
                    key: Key('discover_${c.code}'),
                    padding: const EdgeInsets.all(14),
                    onTap: () => AppNav.country(context, c.code),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CountryFlag(code: c.code, width: 60, radius: 6),
                            const Spacer(),
                            if (_visited.contains(c.code))
                              const Icon(Icons.check_circle_rounded, color: StatusColors.visited, size: 22)
                            else if (_planned.contains(c.code))
                              const Icon(Icons.event_rounded, color: StatusColors.planned, size: 22),
                          ],
                        ),
                        const Spacer(),
                        Text(c.nameTr, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          [c.capitalTr, c.subregion.isEmpty ? c.region : c.subregion].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
