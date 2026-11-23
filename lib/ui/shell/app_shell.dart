import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../screens/calendar_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/travels_screen.dart';
import '../widgets/common.dart';

/// Ana sekmeler.
enum AppTab {
  home('Ana Sayfa', Icons.home_outlined, Icons.home_rounded),
  map('Harita', Icons.public_outlined, Icons.public_rounded),
  travels('Seyahatlerim', Icons.luggage_outlined, Icons.luggage_rounded),
  plans('Planlar', Icons.route_outlined, Icons.route_rounded),
  calendar('Takvim', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  discover('Keşfet', Icons.explore_outlined, Icons.explore_rounded),
  settings('Ayarlar', Icons.tune_outlined, Icons.tune_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Telefonda alt çubukta gösterilenler (beşten fazlası dokunmayı zorlaştırır).
  static const mobile = [home, map, travels, plans, calendar];
}

class ShellController extends ChangeNotifier {
  AppTab _tab = AppTab.home;
  AppTab get tab => _tab;

  void go(AppTab t) {
    if (t == _tab) return;
    _tab = t;
    notifyListeners();
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ShellController _shell = ShellController();
  final Set<AppTab> _visited = {AppTab.home};

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onTab);
  }

  void _onTab() => setState(() => _visited.add(_shell.tab));

  @override
  void dispose() {
    _shell.removeListener(_onTab);
    _shell.dispose();
    super.dispose();
  }

  Widget _page(AppTab t) => switch (t) {
        AppTab.home => const HomeScreen(),
        AppTab.map => const MapScreen(),
        AppTab.travels => const TravelsScreen(),
        AppTab.plans => const PlansScreen(),
        AppTab.calendar => const CalendarScreen(),
        AppTab.discover => const DiscoverScreen(),
        AppTab.settings => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final tab = _shell.tab;
    // Sekmeler ilk açıldıklarında oluşturulur ve sonra durumları korunur.
    final stack = IndexedStack(
      index: AppTab.values.indexOf(tab),
      children: [
        for (final t in AppTab.values) _visited.contains(t) ? _page(t) : const SizedBox.shrink(),
      ],
    );

    final body = Column(
      children: [
        const ConnectionBanner(),
        Expanded(child: stack),
      ],
    );

    return ChangeNotifierProvider.value(
      value: _shell,
      child: PopScope(
        // Android geri tuşu: ana sayfada değilsek önce ana sayfaya dön.
        canPop: tab == AppTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _shell.go(AppTab.home);
        },
        child: wide
            ? Scaffold(
                body: Row(
                  children: [
                    _Rail(current: tab, onSelect: _shell.go),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              )
            : Scaffold(
                body: body,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: AppTab.mobile.contains(tab) ? AppTab.mobile.indexOf(tab) : 0,
                  onDestinationSelected: (i) => _shell.go(AppTab.mobile[i]),
                  destinations: [
                    for (final t in AppTab.mobile)
                      NavigationDestination(
                        key: Key('nav_${t.name}'),
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: t == AppTab.travels ? 'Seyahatler' : t.label,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.current, required this.onSelect});
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        width: 232,
        child: Material(
          color: theme.colorScheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/branding/logo.png', width: 38, height: 38),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'WORLDTRACK',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final t in AppTab.values) ...[
                      if (t == AppTab.discover)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Divider(),
                        ),
                      _RailItem(tab: t, selected: t == current, onTap: () => onSelect(t)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Kayıtların yalnızca bu cihazda saklanır.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap});
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('nav_${tab.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? tab.selectedIcon : tab.icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
