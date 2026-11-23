import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'core/theme/app_theme.dart';
import 'services/settings_controller.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/shell/app_shell.dart';

/// Kök widget. Açılış ekranı servisleri hazırlar; hazır olunca ana kabuğa geçilir.
class WorldTrackApp extends StatefulWidget {
  const WorldTrackApp({super.key, this.services, this.skipSplashDelay = false});

  /// Testlerde hazır servisler verilebilir.
  final AppServices? services;
  final bool skipSplashDelay;

  @override
  State<WorldTrackApp> createState() => _WorldTrackAppState();
}

class _WorldTrackAppState extends State<WorldTrackApp> {
  AppServices? _services;

  @override
  void initState() {
    super.initState();
    _services = widget.services;
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    if (services == null) {
      return MaterialApp(
        title: 'WORLDTRACK',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: SplashScreen(
          skipDelay: widget.skipSplashDelay,
          onReady: (s) => setState(() => _services = s),
        ),
      );
    }
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<SettingsController>.value(value: services.settings),
        ChangeNotifierProvider.value(value: services.connectivity),
        ChangeNotifierProvider.value(value: services.events),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'WORLDTRACK',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AppShell(),
        ),
      ),
    );
  }
}
