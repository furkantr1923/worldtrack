import 'package:flutter/foundation.dart';

import '../app_services.dart';

/// Ekran modellerinin ortak tabanı: yükleme / hata durumu ve veri değişince
/// otomatik yenileme. Görünüm (View) yalnızca bu modeli dinler.
abstract class BaseViewModel extends ChangeNotifier {
  BaseViewModel(this.services) {
    services.events.addListener(_onDataChanged);
  }

  final AppServices services;

  bool _loading = true;
  Object? _error;
  bool _disposed = false;
  bool _reloadQueued = false;
  bool _busy = false;

  bool get loading => _loading;
  Object? get error => _error;
  bool get isDisposed => _disposed;

  /// Alt sınıf verisini burada yükler.
  @protected
  Future<void> load();

  Future<void> refresh() async {
    if (_busy) {
      _reloadQueued = true;
      return;
    }
    _busy = true;
    try {
      await load();
      _error = null;
    } catch (e, st) {
      _error = e;
      debugPrint('ViewModel hata: $e\n$st');
    } finally {
      _busy = false;
      _loading = false;
      notify();
    }
    if (_reloadQueued) {
      _reloadQueued = false;
      await refresh();
    }
  }

  void _onDataChanged() {
    if (!_disposed) refresh();
  }

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    services.events.removeListener(_onDataChanged);
    super.dispose();
  }
}
