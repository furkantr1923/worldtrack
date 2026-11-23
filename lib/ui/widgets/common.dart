import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../services/connectivity_service.dart';

/// Geniş ekran (Windows / tablet yatay) eşiği.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// İçerik genişliğini büyük ekranlarda sınırlar; okunabilirliği korur.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        // heightFactor: 1 → yükseklik içeriğe göre; alt çubuklarda tüm ekranı kaplamaz.
        heightFactor: 1,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

class WtCard extends StatelessWidget {
  const WtCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code, this.width = 36, this.radius = 6});
  final String code;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.6),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Image.asset(
          'assets/flags/${code.toLowerCase()}.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.public_rounded, size: height * 0.7, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 18),
              Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Büyük sayı + etiket. Ana sayfadaki iki istatistik için.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.hint,
  });
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = WtCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    v.round().toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface, height: 1.1),
                  ),
                ),
                Text(label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
    return hint == null ? tile : Tooltip(message: hint!, child: tile);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
            Text(label,
                style: TextStyle(fontFamily: AppTheme.font, fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}

class TransportChip extends StatelessWidget {
  const TransportChip({super.key, required this.type});
  final TransportType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StatusPill(label: type.label, color: scheme.primary, icon: type.icon);
  }
}

/// Önizleme görseli; dosya yoksa veya bozuksa zarif bir yer tutucu gösterir.
class LocalImage extends StatelessWidget {
  const LocalImage({super.key, required this.path, this.fit = BoxFit.cover, this.cacheWidth, this.fallbackCode});
  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final String? fallbackCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        color: scheme.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text('Fotoğraf bulunamadı',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Çevrimdışı olunca üstte görünen ince bilgi şeridi.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.select<ConnectivityService, bool>((c) => c.online);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              color: const Color(0xFF3A4A5E),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.cloud_off_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Çevrimdışısın. Kayıtların ve fotoğrafların kullanılabilir; harita altlığı ve '
                          'çevrimiçi bilgiler bağlantı gelince yenilenir.',
                          style: TextStyle(color: Colors.white, fontSize: 12.5),
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

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Sil',
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
    ));
}

/// Hata mesajlarını kullanıcıya uygun metne çevirir.
String friendlyError(Object e) {
  if (e is ArgumentError) return e.message?.toString() ?? 'Geçersiz değer.';
  final s = e.toString();
  if (s.contains('FOREIGN KEY')) return 'Bu kayıt başka kayıtlarda kullanıldığı için işlem yapılamadı.';
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('TimeoutException')) {
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
  return 'Beklenmeyen bir hata oluştu: $s';
}

/// Kayıt alanlarındaki "Planlandı" / "Ziyaret edildi" renkleri.
class StatusColors {
  static const visited = WtColors.visited;
  static const planned = WtColors.sunset;
  static const selected = WtColors.coral;
}
