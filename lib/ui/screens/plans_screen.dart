import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/models.dart';
import '../../viewmodels/plans_view_model.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/travel_tiles.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PlansViewModel(ctx.read<AppServices>())..refresh(),
      child: const _PlansView(),
    );
  }
}

class _PlansView extends StatelessWidget {
  const _PlansView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlansViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planlar'),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              Tab(key: const Key('tabPlanned'), text: 'Planlanan (${vm.planned.length})'),
              Tab(key: const Key('tabCompleted'), text: 'Tamamlanan (${vm.completed.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('fabAddPlan'),
          heroTag: 'fabPlan',
          onPressed: () => AppNav.newPlan(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Plan oluştur'),
        ),
        body: vm.loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _PlanList(
                    plans: vm.planned,
                    empty: const EmptyState(
                      icon: Icons.route_outlined,
                      title: 'Planlanmış seyahat yok',
                      message: 'Gelecekteki bir yolculuk için durakları sırala, ulaşımı seç, rotayı haritada gör.',
                    ),
                  ),
                  _PlanList(
                    plans: vm.completed,
                    empty: const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Tamamlanan plan yok',
                      message: 'Bir plan gerçekleştiğinde "Seyahate dönüştür" ile tek dokunuşla '
                          'seyahat geçmişine eklenir ve burada listelenir.',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.plans, required this.empty});
  final List<PlannedTrip> plans;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return empty;
    final pad = isWide(context) ? 32.0 : 16.0;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 100),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => ContentWidth(maxWidth: 900, child: PlanTile(plan: plans[i])),
    );
  }
}
