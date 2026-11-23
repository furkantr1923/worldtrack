import '../core/utils/dates.dart';
import '../data/models/models.dart';
import 'base_view_model.dart';

class HomeViewModel extends BaseViewModel {
  HomeViewModel(super.services);

  TravelStats stats = TravelStats.empty;
  List<TravelRecord> recent = const [];
  List<PlannedTrip> upcoming = const [];
  Set<String> visited = const {};
  Set<String> planned = const {};

  @override
  Future<void> load() async {
    stats = await services.travels.stats();
    recent = await services.travels.list(limit: 8);
    final today = Dates.today();
    final plans = await services.plans.list(status: PlanStatus.planned);
    // Yaklaşan planlar: bitişi bugünden sonra olanlar, en yakın tarihli önce.
    upcoming = plans.where((p) => !p.effectiveEnd.isBefore(today)).take(4).toList();
    if (upcoming.isEmpty) upcoming = plans.take(4).toList();
    visited = await services.countries.visitedCodes();
    planned = await services.countries.plannedCodes();
  }
}
