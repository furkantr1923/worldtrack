import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../viewmodels/country_detail_view_model.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/travel_tiles.dart';

class CountryDetailScreen extends StatelessWidget {
  const CountryDetailScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CountryDetailViewModel(ctx.read<AppServices>(), code)..refresh(),
      child: const _CountryDetailView(),
    );
  }
}

class _CountryDetailView extends StatelessWidget {
  const _CountryDetailView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CountryDetailViewModel>();
    final c = vm.country;
    if (vm.loading && c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.public_off_rounded, title: 'Ülke bulunamadı', message: ''),
      );
    }
    final theme = Theme.of(context);
    final wide = isWide(context);
    final nf = NumberFormat.decimalPattern('tr_TR');
    final pad = wide ? 32.0 : 16.0;

    final facts = <(IconData, String, String)>[
      if (c.capitalTr.isNotEmpty) (Icons.account_balance_rounded, 'Başkent', c.capitalTr),
      if (c.region.isNotEmpty) (Icons.public_rounded, 'Bölge', c.region),
      if (c.subregion.isNotEmpty) (Icons.map_outlined, 'Alt bölge', c.subregion),
      if (c.population != null && c.population! > 0)
        (Icons.groups_rounded, 'Nüfus (GeoNames)', nf.format(c.population)),
      if (c.areaKm2 != null && c.areaKm2! > 0)
        (Icons.straighten_rounded, 'Yüzölçümü', '${nf.format(c.areaKm2!.round())} km²'),
      if (c.currency.isNotEmpty)
        (Icons.payments_outlined, 'Para birimi', c.currencyName.isEmpty ? c.currency : '${c.currencyName} (${c.currency})'),
      if (c.type.isNotEmpty) (Icons.verified_outlined, 'Statü (Natural Earth)', c.type),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(c.nameTr)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 40),
        children: [
          ContentWidth(
            maxWidth: 980,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Başlık
                WtCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CountryFlag(code: c.code, width: wide ? 132 : 96, radius: 10),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nameTr, style: theme.textTheme.headlineSmall, key: const Key('countryTitle')),
                            if (c.nameEn.isNotEmpty && c.nameEn != c.nameTr)
                              Text(c.nameEn, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (vm.visited)
                                  const StatusPill(label: 'Ziyaret edildi', color: StatusColors.visited, icon: Icons.check_rounded)
                                else
                                  StatusPill(label: 'Henüz gidilmedi', color: theme.colorScheme.onSurfaceVariant),
                                if (vm.planned)
                                  const StatusPill(label: 'Planlandı', color: StatusColors.planned, icon: Icons.event),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('countryAddTravel'),
                      onPressed: () => AppNav.newTravel(context, country: c),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Seyahat ekle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => AppNav.newPlan(context, country: c),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Plan oluştur'),
                    ),
                    if (vm.records.isEmpty)
                      TextButton.icon(
                        key: const Key('countryToggleVisited'),
                        onPressed: vm.toggleManualVisited,
                        icon: Icon(c.manualVisited ? Icons.undo_rounded : Icons.check_circle_outline_rounded),
                        label: Text(c.manualVisited ? 'İşareti kaldır' : 'Gittim olarak işaretle'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Genel bilgiler'),
                WtCard(
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 16,
                    children: [
                      for (final f in facts)
                        SizedBox(
                          width: wide ? 260 : 220,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(f.$1, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.$2, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    Text(f.$3, style: theme.textTheme.titleSmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (facts.isEmpty) const Text('Bu bölge için ek bilgi bulunmuyor.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AboutCard(vm: vm),
                const SizedBox(height: 16),
                SectionHeader(title: 'Ziyaret ettiğin şehirler (${vm.visitedCities.length})'),
                if (vm.visitedCities.isEmpty)
                  WtCard(
                    child: Text(c.manualVisited
                        ? 'Ülke "gittim" olarak işaretli; şehir eklemek için seyahat kaydı oluşturabilirsin.'
                        : 'Bu ülkede kayıtlı bir şehir ziyaretin yok.'),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in vm.visitedCities)
                        Chip(
                          avatar: const Icon(Icons.location_on_rounded, size: 18, color: StatusColors.visited),
                          label: Text(v.visits > 1 ? '${v.city.nameTr} · ${v.visits} kez' : v.city.nameTr),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                SectionHeader(title: 'Bu ülkedeki seyahatlerin (${vm.records.length})'),
                if (vm.records.isEmpty)
                  const WtCard(child: Text('Henüz seyahat kaydı yok.'))
                else
                  for (final r in vm.records)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: TravelListTile(record: r)),
                const SizedBox(height: 16),
                SectionHeader(title: 'Planlar (${vm.plans.length})'),
                if (vm.plans.isEmpty)
                  const WtCard(child: Text('Bu ülkeyi içeren bir plan yok.'))
                else
                  for (final p in vm.plans) Padding(padding: const EdgeInsets.only(bottom: 8), child: PlanTile(plan: p)),
                const SizedBox(height: 16),
                if (vm.topCities.isNotEmpty) ...[
                  const SectionHeader(title: 'Başlıca şehirler'),
                  Text('Nüfusa göre (GeoNames). Dokunarak bu şehir için seyahat kaydı başlatabilirsin.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final city in vm.topCities)
                        ActionChip(
                          avatar: Icon(city.isCapital ? Icons.star_rounded : Icons.location_city_rounded, size: 18),
                          label: Text(city.population > 0
                              ? '${city.nameTr} · ${NumberFormat.compact(locale: 'tr_TR').format(city.population)}'
                              : city.nameTr),
                          onPressed: () => AppNav.newTravel(context, country: c, city: city),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Kişisel kayıtların (ziyaretler, planlar) yalnızca bu cihazda tutulur. Genel bilgiler '
                  'Natural Earth, GeoNames ve Vikipedi\'den gelir; uygulama bilgi üretmez.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.vm});
  final CountryDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget body = const SizedBox.shrink();
    switch (vm.infoState) {
      case InfoState.idle:
      case InfoState.loading:
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Vikipedi\'den özet alınıyor…'),
          ]),
        );
      case InfoState.offline:
        body = Row(children: [
          Icon(Icons.cloud_off_rounded, color: muted),
          const SizedBox(width: 10),
          const Expanded(child: Text('Çevrimdışısın. Bağlantı gelince ülke özeti otomatik yüklenecek.')),
        ]);
      case InfoState.failed:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Özet şu an alınamadı. ${vm.infoError ?? ''}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => vm.loadInfo(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        );
      case InfoState.ready:
        final info = vm.info!;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Kaynak: Vikipedi (CC BY-SA 4.0) · ${Dates.short(info.fetchedAt)} tarihinde alındı',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Devamını oku'),
                ),
              ],
            ),
          ],
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Hakkında'),
        WtCard(child: body),
      ],
    );
  }
}
