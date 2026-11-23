import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';

/// Açılış ekranı: marka, imza ve arka planda veritabanı / harita hazırlığı.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onReady, this.skipDelay = false});

  final ValueChanged<AppServices> onReady;
  final bool skipDelay;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  String _status = 'Hazırlanıyor…';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _status = 'Hazırlanıyor…';
    });
    try {
      final started = DateTime.now();
      final services = await AppServices.initialize(
        onProgress: (m) {
          if (mounted) setState(() => _status = m);
        },
      );
      // Marka ekranı en az kısa bir süre görünsün (ilk açılışta zaten daha uzun sürer).
      final elapsed = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1300);
      if (!widget.skipDelay && elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
      if (mounted) widget.onReady(services);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF071A2C);
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Hafif bir ışık halesi (aşırı gradyan yok).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [WtColors.brand.withValues(alpha: 0.28), bg],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(fade),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset('assets/branding/logo.png', width: 128, height: 128),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'WORLDTRACK',
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Senin Dünyan. Senin Yolculuğun.',
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_error == null) ...[
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF4FC3C9)),
                      ),
                      const SizedBox(height: 14),
                      Text(_status, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                    ] else
                      _ErrorPanel(error: _error!, onRetry: _start),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: fade,
                child: Text(
                  'Developed by Furkan Baykal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.font,
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A80), size: 32),
          const SizedBox(height: 10),
          const Text('Uygulama başlatılamadı',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Kayıtların güvende; veriler silinmedi. Ayrıntı: $error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}
