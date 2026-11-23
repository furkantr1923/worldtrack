import '../data/models/models.dart';
import 'base_view_model.dart';

class PlansViewModel extends BaseViewModel {
  PlansViewModel(super.services);

  List<PlannedTrip> planned = const [];
  List<PlannedTrip> completed = const [];

  @override
  Future<void> load() async {
    planned = await services.plans.list(status: PlanStatus.planned);
    completed = await services.plans.list(status: PlanStatus.completed);
  }
}

class PlanDetailViewModel extends BaseViewModel {
  PlanDetailViewModel(super.services, this.planId);

  final int planId;
  PlannedTrip? plan;
  List<Expense> expenses = const [];
  bool deleted = false;

  @override
  Future<void> load() async {
    plan = await services.plans.byId(planId);
    if (plan == null) {
      deleted = true;
      return;
    }
    expenses = await services.expenses.forTrip(planId);
  }

  Future<void> delete() async {
    deleted = true;
    await services.plans.delete(planId);
  }
}
