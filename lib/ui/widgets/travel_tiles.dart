import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/models/models.dart';
import '../navigation.dart';
import 'common.dart';

/// Kapak fotoğraflı (yoksa bayraklı) dikey seyahat kartı — ana sayfadaki yatay liste için.
class TravelPosterCard extends StatelessWidget {
  const TravelPosterCard({super.key, required this.record});
  final TravelRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: WtCard(
        padding: EdgeInsets.zero,
        onTap: () => AppNav.travel(context, record.id!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              width: double.infinity,
              child: record.coverThumb != null
                  ? LocalImage(path: record.coverThumb!, cacheWidth: 420)
                  : _FlagCover(code: record.countryCode),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.city?.nameTr ?? '—',
                      style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(record.country?.nameTr ?? record.countryCode,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('${Dates.short(record.visitDate)} · ${Dates.duration(record.durationDays)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagCover extends StatelessWidget {
  const _FlagCover({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: CountryFlag(code: code, width: 84, radius: 8),
    );
  }
}

/// Seyahat geçmişi listesindeki satır.
class TravelListTile extends StatelessWidget {
  const TravelListTile({super.key, required this.record});
  final TravelRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return WtCard(
      key: Key('travel_${record.id}'),
      padding: const EdgeInsets.all(12),
      onTap: () => AppNav.travel(context, record.id!),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: record.coverThumb != null
                  ? LocalImage(path: record.coverThumb!, cacheWidth: 200)
                  : _FlagCover(code: record.countryCode),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(record.city?.nameTr ?? '—',
                          style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    CountryFlag(code: record.countryCode, width: 20, radius: 3),
                  ],
                ),
                Text(record.country?.nameTr ?? record.countryCode,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted), maxLines: 1),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Meta(icon: Icons.event_rounded, text: Dates.range(record.visitDate, record.endDate)),
                    _Meta(icon: Icons.schedule_rounded, text: Dates.duration(record.durationDays)),
                    if (record.transport != null) _Meta(icon: record.transport!.icon, text: record.transport!.label),
                    if (record.photoCount > 0)
                      _Meta(icon: Icons.photo_library_outlined, text: '${record.photoCount} fotoğraf'),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12.5, color: muted)),
      ],
    );
  }
}

/// Plan kartı: başlık, tarih, rota özeti ve durum.
class PlanTile extends StatelessWidget {
  const PlanTile({super.key, required this.plan});
  final PlannedTrip plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = Dates.today();
    final daysLeft = Dates.daysBetween(today, plan.startDate);
    final String when;
    if (plan.isCompleted) {
      when = 'Tamamlandı';
    } else if (daysLeft > 1) {
      when = '$daysLeft gün kaldı';
    } else if (daysLeft == 1) {
      when = 'Yarın';
    } else if (!plan.effectiveEnd.isBefore(today)) {
      when = 'Devam ediyor';
    } else {
      when = 'Tarihi geçti';
    }
    final color = plan.isCompleted ? StatusColors.visited : StatusColors.planned;
    return WtCard(
      key: Key('plan_${plan.id}'),
      onTap: () => AppNav.plan(context, plan.id!),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(plan.isCompleted ? Icons.task_alt_rounded : Icons.flight_takeoff_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(plan.title,
                          style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    StatusPill(label: when, color: color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(Dates.range(plan.startDate, plan.effectiveEnd),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 8),
                Text(
                  plan.routeSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppTheme.font, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                if (plan.stops.any((s) => s.transport != null)) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in plan.stops.map((s) => s.transport).whereType<TransportType>().toSet())
                        Icon(t.icon, size: 16, color: muted),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
