import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../viewmodels/home_view_model.dart';
import '../map/mini_world_map.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';
import '../widgets/common.dart';
import '../widgets/travel_tiles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => HomeViewModel(ctx.read<AppServices>())..refresh(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final theme = Theme.of(context);
    final wide = isWide(context);
    final shell = context.read<ShellController>();
    final greeting = _greeting();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text('Seyahat arşivin', style: theme.textTheme.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('homeSearch'),
            tooltip: 'Ülke veya şehir ara',
            onPressed: () => AppNav.search(context),
            icon: const Icon(Icons.search_rounded),
          ),
          if (!wide) ...[
            IconButton(
              tooltip: 'Keşfet',
              onPressed: () => shell.go(AppTab.discover),
              icon: const Icon(Icons.explore_outlined),
            ),
            IconButton(
              key: const Key('homeSettings'),
              tooltip: 'Profil ve ayarlar',
              onPressed: () => shell.go(AppTab.settings),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 4, wide ? 32 : 16, 32),
                children: [
                  ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCard(vm: vm, onOpenMap: () => shell.go(AppTab.map)),
                        const SizedBox(height: 16),
                        _StatsRow(stats: vm.stats),
                        const SizedBox(height: 20),
                        _QuickActions(shell: shell),
                        const SizedBox(height: 12),
                        SectionHeader(
                          title: 'Son seyahatler',
                          action: vm.recent.isEmpty ? null : 'Tümü',
                          onAction: () => shell.go(AppTab.travels),
                        ),
                        if (vm.recent.isEmpty)
                          WtCard(
                            child: _InlineEmpty(
                              icon: Icons.luggage_outlined,
                              text: 'Henüz seyahat kaydın yok. İlk seyahatini ekleyerek haritanı renklendir.',
                              action: 'Seyahat ekle',
                              onTap: () => AppNav.newTravel(context),
                            ),
                          )
                        else
                          SizedBox(
                            height: 214,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: vm.recent.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => TravelPosterCard(record: vm.recent[i]),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SectionHeader(
                          title: 'Yaklaşan planlar',
                          action: vm.upcoming.isEmpty ? null : 'Tümü',
                          onAction: () => shell.go(AppTab.plans),
                        ),
                        if (vm.upcoming.isEmpty)
                          WtCard(
                            child: _InlineEmpty(
                              icon: Icons.route_outlined,
                              text: 'Planlanmış bir seyahatin yok. Durakları ve rotayı şimdiden hazırlayabilirsin.',
                              action: 'Plan oluştur',
                              onTap: () => AppNav.newPlan(context),
                            ),
                          )
                        else
                          ...vm.upcoming.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: PlanTile(plan: p),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.vm, required this.onOpenMap});
  final HomeViewModel vm;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0C2236) : const Color(0xFF0A3D62),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('homeHeroMap'),
        onTap: onOpenMap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dünyadaki izlerin',
                      style: TextStyle(
                          fontFamily: AppTheme.font, color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Haritayı aç', style: TextStyle(color: Colors.white, fontSize: 13)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MiniWorldMap(
                shapes: context.read<AppServices>().shapes,
                visited: vm.visited,
                planned: vm.planned,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Legend(color: WtColors.visited, label: 'Ziyaret edildi'),
                  _Legend(color: WtColors.sunset, label: 'Planlandı'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
        ],
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final TravelStats stats;

  @override
  Widget build(BuildContext context) {
    final countries = StatTile(
      key: const Key('statCountries'),
      value: stats.visitedCountries,
      label: 'Ziyaret edilen ülke',
      icon: Icons.flag_rounded,
      color: WtColors.visited,
      hint: 'Seyahat kaydı olan veya elle işaretlenen farklı ülkeler. Her ülke bir kez sayılır.',
    );
    final cities = StatTile(
      key: const Key('statCities'),
      value: stats.visitedCities,
      label: 'Ziyaret edilen şehir',
      icon: Icons.location_city_rounded,
      color: WtColors.brand,
      hint: 'Farklı şehir sayısı. Aynı şehre birden fazla gitmen tek şehir olarak sayılır.',
    );
    return Row(
      children: [
        Expanded(child: countries),
        const SizedBox(width: 12),
        Expanded(child: cities),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.shell});
  final ShellController shell;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.add_location_alt_rounded, 'Seyahat ekle', () => AppNav.newTravel(context), const Key('quickAddTravel')),
      (Icons.edit_calendar_rounded, 'Plan oluştur', () => AppNav.newPlan(context), const Key('quickAddPlan')),
      (Icons.public_rounded, 'Dünya haritası', () => shell.go(AppTab.map), const Key('quickMap')),
      (Icons.explore_rounded, 'Ülkeleri keşfet', () => shell.go(AppTab.discover), const Key('quickDiscover')),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: WtCard(
                key: it.$4,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                onTap: it.$3,
                child: Row(
                  children: [
                    Icon(it.$1, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(it.$2,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.text, required this.action, required this.onTap});
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        FilledButton.tonal(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}
