import '../data/models/models.dart';
import 'base_view_model.dart';

enum InfoState { idle, loading, ready, offline, failed }

class CountryDetailViewModel extends BaseViewModel {
  CountryDetailViewModel(super.services, this.code) {
    services.connectivity.addListener(_onConnectivity);
  }

  final String code;
  Country? country;
  bool visited = false;
  bool planned = false;
  List<({City city, int visits})> visitedCities = const [];
  List<TravelRecord> records = const [];
  List<PlannedTrip> plans = const [];
  List<City> topCities = const [];

  InfoState infoState = InfoState.idle;
  CountryInfo? info;
  String? infoError;
  bool _infoRequested = false;

  @override
  Future<void> load() async {
    country = services.countries.byCode(code);
    if (country == null) return;
    visited = (await services.countries.visitedCodes()).contains(code);
    planned = (await services.countries.plannedCodes()).contains(code);
    visitedCities = await services.travels.visitedCities(code);
    records = await services.travels.list(countryCode: code);
    plans = await services.plans.forCountry(code);
    topCities = await services.cities.topCities(code, limit: 8);
    if (!_infoRequested) {
      _infoRequested = true;
      loadInfo();
    }
  }

  Future<void> loadInfo({bool force = false}) async {
    final c = country;
    if (c == null) return;
    infoState = InfoState.loading;
    notify();
    final cached = await services.countryInfo.cached(code);
    if (!services.connectivity.online && !force) {
      info = cached;
      infoState = cached != null ? InfoState.ready : InfoState.offline;
      notify();
      return;
    }
    try {
      info = await services.countryInfo.get(c, forceRefresh: force);
      infoState = InfoState.ready;
      infoError = null;
    } catch (e) {
      info = cached;
      infoError = e.toString();
      infoState = cached != null ? InfoState.ready : InfoState.failed;
    }
    notify();
  }

  void _onConnectivity() {
    // Bağlantı geri gelince, bilgi alınamamışsa güvenle yeniden dene.
    if (services.connectivity.online && (infoState == InfoState.offline || infoState == InfoState.failed)) {
      loadInfo();
    }
  }

  Future<void> toggleManualVisited() async {
    final c = country;
    if (c == null) return;
    await services.countries.setManualVisited(c.code, !c.manualVisited);
  }

  @override
  void dispose() {
    services.connectivity.removeListener(_onConnectivity);
    super.dispose();
  }
}
