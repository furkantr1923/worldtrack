import '../data/models/models.dart';
import 'base_view_model.dart';

class MapViewModel extends BaseViewModel {
  MapViewModel(super.services);

  Set<String> visited = const {};
  Set<String> planned = const {};
  String? selectedCode;
  int selectedRecordCount = 0;
  List<({City city, int visits})> selectedCities = const [];

  Country? get selected => selectedCode == null ? null : services.countries.byCode(selectedCode!);

  @override
  Future<void> load() async {
    visited = await services.countries.visitedCodes();
    planned = await services.countries.plannedCodes();
    await _loadSelection();
  }

  Future<void> _loadSelection() async {
    final code = selectedCode;
    if (code == null) {
      selectedCities = const [];
      selectedRecordCount = 0;
      return;
    }
    selectedCities = await services.travels.visitedCities(code);
    selectedRecordCount = selectedCities.fold(0, (s, e) => s + e.visits);
  }

  Future<void> select(String? code) async {
    selectedCode = code;
    await _loadSelection();
    notify();
  }

  Future<void> toggleManualVisited() async {
    final c = selected;
    if (c == null) return;
    await services.countries.setManualVisited(c.code, !c.manualVisited);
  }
}
