import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/data_events.dart';
import '../../data/models/models.dart';
import '../../services/settings_controller.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

/// Profil ve ayarlar: tema, harita altlığı, isteğe bağlı güzergâh tahmini, veri ve gizlilik.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TravelStats? _stats;
  late final DataEvents _events = context.read<AppServices>().events;

  @override
  void initState() {
    super.initState();
    _events.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    _events.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final st = await context.read<AppServices>().travels.stats();
    if (mounted) setState(() => _stats = st);
  }

  Future<void> _editCustomUrl(SettingsController settings) async {
    final ctrl = TextEditingController(text: settings.customTileUrl);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Özel karo adresi'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'XYZ biçiminde bir raster karo adresi gir. API anahtarı gerekiyorsa adresin içine sen eklersin; '
                  'anahtar yalnızca bu cihazdaki ayarlarda saklanır, kaynak koda yazılmaz.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'https://ornek.com/tiles/{z}/{x}/{y}.png',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final err = await settings.setCustomTileUrl(ctrl.text);
                if (err != null) {
                  setLocal(() => error = err);
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _editRoutingServer(SettingsController settings) async {
    final ctrl = TextEditingController(text: settings.routingServer);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Güzergâh sunucusu (OSRM)'),
          content: SizedBox(
            width: 480,
            child: TextField(controller: ctrl, decoration: InputDecoration(errorText: error)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final err = await settings.setRoutingServer(ctrl.text);
                if (err != null) {
                  setLocal(() => error = err);
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final services = context.read<AppServices>();
    final theme = Theme.of(context);
    final pad = isWide(context) ? 32.0 : 16.0;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil ve Ayarlar')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 40),
        children: [
          ContentWidth(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WtCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset('assets/branding/logo.png', width: 56, height: 56),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Seyahat profilin', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              _stats == null
                                  ? '…'
                                  : '${_stats!.visitedCountries} ülke · ${_stats!.visitedCities} şehir',
                              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                            Text('Hesap gerekmez; tüm kayıtların bu cihazda.',
                                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Görünüm'),
                WtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tema', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto_rounded)),
                          ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_rounded)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_rounded)),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) => settings.setThemeMode(s.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Harita'),
                WtCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Ülke sınırları uygulamanın içindedir ve internetsiz çalışır. Çevrimiçi bir altlık '
                          'seçersen karolar o servisten yüklenir; servis yalnızca görüntülediğin harita '
                          'bölgesini görür, kişisel kayıtlarını görmez.',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                      for (final p in BasemapProvider.values)
                        ListTile(
                          key: Key('basemap_${p.name}'),
                          leading: Icon(
                            settings.basemap == p ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: settings.basemap == p ? theme.colorScheme.primary : muted,
                          ),
                          title: Text(p.label),
                          subtitle: Text(_basemapNote(p, settings)),
                          trailing: p == BasemapProvider.custom
                              ? IconButton(
                                  tooltip: 'Adresi düzenle',
                                  onPressed: () => _editCustomUrl(settings),
                                  icon: const Icon(Icons.edit_outlined),
                                )
                              : null,
                          onTap: () async {
                            await settings.setBasemap(p);
                            if (p == BasemapProvider.custom && settings.customTileUrl.isEmpty) {
                              await _editCustomUrl(settings);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Rotalar'),
                WtCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('routingSwitch'),
                        value: settings.routingEnabled,
                        onChanged: settings.setRoutingEnabled,
                        title: const Text('Karayolu güzergâh tahmini (isteğe bağlı)'),
                        subtitle: const Text(
                          'Açıkken, araba/otobüs bağlantıları için plan sayfasında "tahmin et" düğmesi görünür. '
                          'Düğmeye bastığında yalnızca iki durağın koordinatları güzergâh sunucusuna gönderilir. '
                          'Kapalıyken hiçbir veri gönderilmez ve duraklar basit çizgilerle bağlanır.',
                        ),
                      ),
                      ListTile(
                        enabled: settings.routingEnabled,
                        title: const Text('Güzergâh sunucusu'),
                        subtitle: Text('${settings.routingServer}\nVarsayılan: OSRM herkese açık demo sunucusu — '
                            'ücretsiz, anahtarsız; hizmet garantisi yoktur.'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: settings.routingEnabled ? () => _editRoutingServer(settings) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Veri ve gizlilik'),
                WtCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Kayıtların cihazında'),
                        subtitle: Text(
                          'Seyahatler, fotoğraflar ve planlar yalnızca bu cihazda saklanır; hesap, bulut eşitleme '
                          've analitik yoktur.\nKonum: ${services.paths.root}'
                          '${services.paths.isPortable ? '\n(Taşınabilir mod: veriler programın yanındaki klasörde)' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                      ListTile(
                        leading: const Icon(Icons.wifi_tethering_rounded),
                        title: const Text('İnternete giden istekler'),
                        subtitle: const Text(
                          '• Harita karoları (seçili altlık servisi)\n'
                          '• Ülke özeti: Wikidata ve Türkçe Vikipedi (yalnızca ülke kimliği)\n'
                          '• İsteğe bağlı: güzergâh tahmini (yalnızca iki durağın koordinatı)',
                        ),
                        isThreeLine: true,
                      ),
                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: const Text('Ülke özeti önbelleğini temizle'),
                        subtitle: const Text('Vikipedi özetleri bir sonraki açılışta yeniden indirilir.'),
                        onTap: () async {
                          final n = await services.countryInfo.clearCache();
                          if (context.mounted) showMessage(context, '$n ülke özeti silindi.');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Uygulama'),
                WtCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('openAbout'),
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('WORLDTRACK hakkında'),
                        subtitle: const Text('Sürüm, geliştirici, veri kaynakları ve lisanslar'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _basemapNote(BasemapProvider p, SettingsController s) => switch (p) {
        BasemapProvider.none => 'İnternet ve anahtar gerekmez; ülke sınırları ve Türkçe adlar uygulamanın içinden çizilir.',
        BasemapProvider.osm => 'Anahtarsız; yol ve şehir ayrıntısı ekler. OSM karo politikası yoğun kullanımı sınırlar.',
        BasemapProvider.custom => s.customTileUrl.isEmpty ? 'Henüz adres girilmedi.' : s.customTileUrl,
      };
}
