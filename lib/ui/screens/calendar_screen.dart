import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/dates.dart';
import '../../viewmodels/calendar_view_model.dart';
import '../navigation.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CalendarViewModel(ctx.read<AppServices>())..refresh(),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView();

  void _open(BuildContext context, CalendarEvent e) {
    if (e.recordId != null) {
      AppNav.travel(context, e.recordId!);
    } else if (e.planId != null) {
      AppNav.plan(context, e.planId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    final theme = Theme.of(context);
    final wide = isWide(context);
    final grid = _MonthGrid(vm: vm, onEvent: (e) => _open(context, e));
    final list = _EventList(vm: vm, onEvent: (e) => _open(context, e));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takvim'),
        actions: [
          TextButton(onPressed: vm.goToday, child: const Text('Bugün')),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('calPrev'),
                  tooltip: 'Önceki ay',
                  onPressed: vm.previous,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    Dates.monthYear(vm.month),
                    key: const Key('calMonthTitle'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('calNext'),
                  tooltip: 'Sonraki ay',
                  onPressed: vm.next,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 16,
              children: [
                _Dot(color: StatusColors.visited, label: 'Gerçekleşen seyahat'),
                _Dot(color: StatusColors.planned, label: 'Plan'),
              ],
            ),
          ),
          Expanded(
            child: wide
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: SingleChildScrollView(child: grid)),
                        const SizedBox(width: 24),
                        SizedBox(width: 340, child: list),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    children: [
                      grid,
                      const SizedBox(height: 12),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: list),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.vm, required this.onEvent});
  final CalendarViewModel vm;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = vm.gridDays;
    final today = Dates.today();
    final wide = isWide(context);
    return WtCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final d in Dates.weekdayShort)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          for (var w = 0; w < 6; w++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _DayCell(
                      day: days[w * 7 + d],
                      inMonth: days[w * 7 + d].month == vm.month.month,
                      isToday: days[w * 7 + d] == today,
                      events: vm.eventsOn(days[w * 7 + d]),
                      height: wide ? 92 : 58,
                      showTitles: wide,
                      onEvent: onEvent,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.events,
    required this.height,
    required this.showTitles,
    required this.onEvent,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<CalendarEvent> events;
  final double height;
  final bool showTitles;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: events.isEmpty
          ? null
          : () => events.length == 1 ? onEvent(events.first) : _chooser(context),
      child: Container(
        height: height,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isToday ? scheme.primary.withValues(alpha: 0.10) : null,
          border: isToday ? Border.all(color: scheme.primary, width: 1.2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: inMonth ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            for (final e in events.take(showTitles ? 3 : 2))
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: showTitles ? 16 : 5,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: CalendarViewModel.colorFor(e, scheme).withValues(alpha: inMonth ? 0.9 : 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: showTitles
                    ? Text(e.title,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600))
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooser(BuildContext context) async {
    final e = await showModalBottomSheet<CalendarEvent>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(Dates.long(day), style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final ev in events)
              ListTile(
                leading: Icon(ev.isPlan ? Icons.event_note_rounded : Icons.luggage_rounded,
                    color: CalendarViewModel.colorFor(ev, Theme.of(ctx).colorScheme)),
                title: Text(ev.title),
                subtitle: Text(ev.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, ev),
              ),
          ],
        ),
      ),
    );
    if (e != null) onEvent(e);
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.vm, required this.onEvent});
  final CalendarViewModel vm;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = vm.monthEvents;
    final content = events.isEmpty
        ? WtCard(
            child: Text('${Dates.monthYear(vm.month)} için seyahat veya plan yok.',
                style: theme.textTheme.bodyMedium),
          )
        : Column(
            children: [
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WtCard(
                    key: Key('calEvent_${e.isPlan ? 'p' : 'r'}${e.planId ?? e.recordId}'),
                    padding: const EdgeInsets.all(12),
                    onTap: () => onEvent(e),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 40,
                          decoration: BoxDecoration(
                            color: CalendarViewModel.colorFor(e, theme.colorScheme),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (e.countryCode != null) ...[
                          CountryFlag(code: e.countryCode!, width: 26, radius: 3),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${Dates.range(e.start, e.end)} · ${e.isPlan ? 'Plan' : 'Gerçekleşti'}',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
    if (isWide(context)) {
      return ListView(children: [
        Text('Bu ay', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        content,
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bu ay', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        content,
      ],
    );
  }
}
