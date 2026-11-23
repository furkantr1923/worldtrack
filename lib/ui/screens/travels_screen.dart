import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../viewmodels/travels_view_model.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';
import '../widgets/common.dart';
import '../widgets/travel_tiles.dart';

class TravelsScreen extends StatelessWidget {
  const TravelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TravelsViewModel(ctx.read<AppServices>())..refresh(),
      child: const _TravelsView(),
    );
  }
}

class _TravelsView extends StatelessWidget {
  const _TravelsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TravelsViewModel>();
    final wide = isWide(context);
    final groups = vm.groupedByYear;
    final hPad = wide ? 32.0 : 16.0;

    Widget body;
    if (vm.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.isEmpty) {
      body = EmptyState(
        icon: Icons.luggage_outlined,
        title: 'Seyahat geçmişin boş',
        message: 'Gittiğin bir şehri ekle: ülke, şehir, tarih ve süre yeterli. '
            'Fotoğrafları ve notları daha sonra da ekleyebilirsin.',
        action: FilledButton.icon(
          key: const Key('emptyAddTravel'),
          onPressed: () => AppNav.newTravel(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('İlk seyahatini ekle'),
        ),
      );
    } else {
      body = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 900,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('travelFilter'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Şehir, ülke veya notlarda ara',
                      ),
                      onChanged: vm.setQuery,
                    ),
                    if (vm.upcomingPlanCount > 0) ...[
                      const SizedBox(height: 12),
                      WtCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: StatusColors.planned.withValues(alpha: 0.10),
                        onTap: () => context.read<ShellController>().go(AppTab.plans),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: StatusColors.planned),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${vm.upcomingPlanCount} yaklaşan plan var — planlar ayrı listelenir.'),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (groups.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Eşleşen kayıt yok',
                message: 'Arama ifadesini değiştirmeyi dene.',
              ),
            ),
          for (final g in groups) ...[
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
                  child: Row(
                    children: [
                      Text('${g.year}', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 10),
                      Text('${g.items.length} kayıt',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: g.items.length,
              itemBuilder: (_, i) => ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
                  child: TravelListTile(record: g.items[i]),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.loading || vm.isEmpty ? 'Seyahatlerim' : 'Seyahatlerim · ${vm.totalCount}'),
      ),
      floatingActionButton: vm.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('fabAddTravel'),
              heroTag: 'fabTravel',
              onPressed: () => AppNav.newTravel(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Seyahat ekle'),
            ),
      body: body,
    );
  }
}
