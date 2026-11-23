import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../../viewmodels/travel_detail_view_model.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/expenses_section.dart';
import 'photo_viewer_screen.dart';

class TravelDetailScreen extends StatelessWidget {
  const TravelDetailScreen({super.key, required this.recordId});
  final int recordId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TravelDetailViewModel(ctx.read<AppServices>(), recordId)..refresh(),
      child: const _TravelDetailView(),
    );
  }
}

class _TravelDetailView extends StatelessWidget {
  const _TravelDetailView();

  Future<void> _delete(BuildContext context, TravelDetailViewModel vm) async {
    final r = vm.record!;
    final ok = await confirmDialog(
      context,
      title: 'Seyahat silinsin mi?',
      message: '${r.city?.nameTr ?? ''} (${Dates.long(r.visitDate)}) kaydı, '
          '${vm.photos.length} fotoğrafı ve ${vm.expenses.length} masrafıyla birlikte kalıcı olarak silinecek.',
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await vm.delete();
      navigator.pop();
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _addPhotos(BuildContext context, TravelDetailViewModel vm) async {
    try {
      final added = await vm.addPhotos();
      if (!context.mounted) return;
      if (vm.importErrors.isNotEmpty) {
        showMessage(context, '${vm.importErrors.length} fotoğraf içe aktarılamadı.', error: true);
      } else if (added > 0) {
        showMessage(context, '$added fotoğraf eklendi.');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TravelDetailViewModel>();
    final r = vm.record;
    if (vm.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Kayıt bulunamadı',
          message: 'Bu seyahat silinmiş olabilir.',
        ),
      );
    }
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final wide = isWide(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            actions: [
              IconButton(
                key: const Key('editTravel'),
                tooltip: 'Düzenle',
                onPressed: () => AppNav.editTravel(context, r),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: const Key('deleteTravel'),
                tooltip: 'Sil',
                onPressed: () => _delete(context, vm),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 100),
              title: Text(r.city?.nameTr ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (vm.photos.isNotEmpty)
                    LocalImage(path: vm.photos.first.thumbPath, cacheWidth: 900)
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      alignment: Alignment.center,
                      child: CountryFlag(code: r.countryCode, width: 150, radius: 12),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, theme.colorScheme.surface.withValues(alpha: 0.95)],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 900,
              child: Padding(
                padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 8, wide ? 32 : 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => AppNav.country(context, r.countryCode),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CountryFlag(code: r.countryCode, width: 28, radius: 4),
                            const SizedBox(width: 10),
                            Text(r.country?.nameTr ?? r.countryCode, style: theme.textTheme.titleMedium),
                            if (r.city?.admin1.isNotEmpty ?? false)
                              Text(' · ${r.city!.admin1}', style: TextStyle(color: muted)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: muted, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    WtCard(
                      child: Wrap(
                        spacing: 28,
                        runSpacing: 14,
                        children: [
                          _Fact(icon: Icons.event_rounded, label: 'Tarih', value: Dates.range(r.visitDate, r.endDate)),
                          _Fact(icon: Icons.schedule_rounded, label: 'Süre', value: Dates.duration(r.durationDays)),
                          _Fact(
                            icon: r.transport?.icon ?? Icons.commute_rounded,
                            label: 'Ulaşım',
                            value: r.transport?.label ?? 'Belirtilmedi',
                          ),
                        ],
                      ),
                    ),
                    if (r.notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'Anı / not'),
                      WtCard(child: Text(r.notes, style: theme.textTheme.bodyLarge)),
                    ],
                    const SizedBox(height: 16),
                    SectionHeader(
                      title: 'Fotoğraflar (${vm.photos.length})',
                      action: 'Fotoğraf ekle',
                      onAction: vm.importTotal > 0 ? null : () => _addPhotos(context, vm),
                    ),
                    if (vm.importTotal > 0) ...[
                      LinearProgressIndicator(value: vm.importing / vm.importTotal),
                      const SizedBox(height: 6),
                      Text('Fotoğraflar işleniyor: ${vm.importing}/${vm.importTotal}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 10),
                    ],
                    _PhotoGrid(vm: vm),
                    const SizedBox(height: 16),
                    ExpensesSection(recordId: r.id, expenses: vm.expenses, defaultCurrency: r.country?.currency),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value, style: theme.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.vm});
  final TravelDetailViewModel vm;

  Future<void> _remove(BuildContext context, TravelPhoto p) async {
    final ok = await confirmDialog(
      context,
      title: 'Fotoğraf kaldırılsın mı?',
      message: 'Fotoğrafın uygulama içindeki kopyası silinir. Cihazındaki orijinal galeri dosyası etkilenmez.',
      confirmLabel: 'Kaldır',
    );
    if (ok) await vm.removePhoto(p);
  }

  @override
  Widget build(BuildContext context) {
    if (vm.photos.isEmpty) {
      return WtCard(
        child: Row(
          children: [
            Icon(Icons.photo_library_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Bu seyahate henüz fotoğraf eklenmedi.')),
          ],
        ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 150).floor().clamp(3, 6);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vm.photos.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (_, i) {
          final p = vm.photos[i];
          return ClipRRect(
            key: Key('photo_$i'),
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Material(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(photos: vm.photos, initialIndex: i),
                    )),
                    child: Ink(child: LocalImage(path: p.thumbPath, cacheWidth: 360)),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: Key('removePhoto_$i'),
                      tooltip: 'Kaldır',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white,
                      onPressed: () => _remove(context, p),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
