import '../core/utils/dates.dart';
import '../core/utils/turkish_text.dart';
import '../data/models/models.dart';
import 'base_view_model.dart';

class TravelsViewModel extends BaseViewModel {
  TravelsViewModel(super.services);

  List<TravelRecord> _all = const [];
  String _query = '';
  int upcomingPlanCount = 0;

  String get query => _query;
  bool get isEmpty => _all.isEmpty;
  int get totalCount => _all.length;

  List<TravelRecord> get filtered {
    final q = TurkishText.fold(_query);
    if (q.isEmpty) return _all;
    return _all.where((r) {
      final hay = TurkishText.fold(
          '${r.city?.nameTr ?? ''} ${r.city?.name ?? ''} ${r.country?.nameTr ?? ''} ${r.notes}');
      return hay.contains(q);
    }).toList();
  }

  /// Yıl → kayıtlar (yeniden eskiye).
  List<({int year, List<TravelRecord> items})> get groupedByYear {
    final out = <({int year, List<TravelRecord> items})>[];
    for (final r in filtered) {
      if (out.isEmpty || out.last.year != r.visitDate.year) {
        out.add((year: r.visitDate.year, items: [r]));
      } else {
        out.last.items.add(r);
      }
    }
    return out;
  }

  void setQuery(String q) {
    _query = q;
    notify();
  }

  @override
  Future<void> load() async {
    _all = await services.travels.list();
    final today = Dates.today();
    final plans = await services.plans.list(status: PlanStatus.planned);
    upcomingPlanCount = plans.where((p) => !p.effectiveEnd.isBefore(today)).length;
  }
}
