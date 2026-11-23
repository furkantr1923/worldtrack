import 'package:flutter/material.dart';

import '../core/utils/dates.dart';
import '../data/models/models.dart';
import 'base_view_model.dart';

/// Takvimde gösterilen olay: tamamlanmış bir seyahat veya bir plan.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.isPlan,
    this.recordId,
    this.planId,
    this.countryCode,
  });

  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final bool isPlan;
  final int? recordId;
  final int? planId;
  final String? countryCode;

  bool covers(DateTime day) => !day.isBefore(start) && !day.isAfter(end);
}

class CalendarViewModel extends BaseViewModel {
  CalendarViewModel(super.services) : month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime month;
  List<CalendarEvent> events = const [];

  /// Ayın ilk gününü içeren haftanın pazartesisinden başlayan 6 haftalık ızgara.
  List<DateTime> get gridDays {
    final first = DateTime(month.year, month.month, 1);
    final start = DateTime(first.year, first.month, first.day - (first.weekday - 1));
    return List.generate(42, (i) => DateTime(start.year, start.month, start.day + i));
  }

  List<CalendarEvent> eventsOn(DateTime day) => events.where((e) => e.covers(day)).toList();

  void previous() {
    month = DateTime(month.year, month.month - 1);
    refresh();
  }

  void next() {
    month = DateTime(month.year, month.month + 1);
    refresh();
  }

  void goToday() {
    final now = DateTime.now();
    month = DateTime(now.year, now.month);
    refresh();
  }

  @override
  Future<void> load() async {
    final days = gridDays;
    final from = days.first, to = days.last;
    final records = await services.travels.inRange(from, to);
    final plans = await services.plans.inRange(from, to);
    final list = <CalendarEvent>[
      for (final r in records)
        CalendarEvent(
          title: r.city?.nameTr ?? r.country?.nameTr ?? r.countryCode,
          subtitle: '${r.country?.nameTr ?? r.countryCode} · ${Dates.duration(r.durationDays)}',
          start: r.visitDate,
          end: r.endDate,
          isPlan: false,
          recordId: r.id,
          countryCode: r.countryCode,
        ),
      for (final p in plans)
        // Seyahat kaydına dönüştürülmüş planlar kayıtlarla zaten görünür.
        if (!p.isCompleted)
          CalendarEvent(
            title: p.title,
            subtitle: p.routeSummary,
            start: p.startDate,
            end: p.effectiveEnd,
            isPlan: true,
            planId: p.id,
            countryCode: p.stops.isEmpty ? null : p.stops.first.countryCode,
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    events = list;
  }

  /// Ayın içinde kalan olaylar (liste için).
  List<CalendarEvent> get monthEvents {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return events.where((e) => !e.end.isBefore(first) && !e.start.isAfter(last)).toList();
  }

  static Color colorFor(CalendarEvent e, ColorScheme scheme) =>
      e.isPlan ? const Color(0xFFF2994A) : const Color(0xFF14A38B);
}
