import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';

const String appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset('assets/branding/logo.png', width: 104, height: 104),
                  ),
                ),
                const SizedBox(height: 16),
                Text('WORLDTRACK',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 4, fontFamily: AppTheme.font)),
                Text('Senin Dünyan. Senin Yolculuğun.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
                const SizedBox(height: 4),
                Text('Sürüm $appVersion', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                WtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Geliştirici', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Developed by Furkan Baykal', style: theme.textTheme.titleMedium, key: const Key('aboutDeveloper')),
                      const SizedBox(height: 4),
                      Text('Yazılım Mühendisi · github.com/furkantr1923',
                          style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WtCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Veri kaynakları', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      const _Source('Ülke sınırları', 'Natural Earth 1:50m — kamu malı'),
                      const _Source('Ülke ve şehir verisi', 'GeoNames — CC BY 4.0'),
                      const _Source('Bayraklar', 'country-flags (Wikimedia Commons) — kamu malı'),
                      const _Source('Ülke özetleri', 'Türkçe Vikipedi — CC BY-SA 4.0 (çevrimiçi)'),
                      const _Source('İsteğe bağlı altlık', '© OpenStreetMap katkıda bulunanlar (ODbL)'),
                      const _Source('Yazı tipi', 'Poppins — SIL Open Font License 1.1'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'WORLDTRACK',
                    applicationVersion: appVersion,
                    applicationLegalese: '© 2026 Furkan Baykal · MIT Lisansı',
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Tüm lisanslar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Source extends StatelessWidget {
  const _Source(this.title, this.detail);
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_outline_rounded, size: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: detail),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
