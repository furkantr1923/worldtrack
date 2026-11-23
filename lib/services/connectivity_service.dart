import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Ağ bağlantısı durumu. Çevrimdışıyken uygulama çalışmaya devam eder;
/// yalnızca harita altlığı ve çevrimiçi ülke bilgileri beklemeye alınır.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity;

  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool _tilesFailing = false;

  bool get online => _online;

  /// Ağ var görünse de harita karoları alınamıyorsa (servis kapalı, kota vb.).
  bool get tilesFailing => _tilesFailing;

  Future<void> start() async {
    final c = _connectivity ?? Connectivity();
    try {
      _apply(await c.checkConnectivity());
      _sub = c.onConnectivityChanged.listen(_apply, onError: (_) {});
    } catch (_) {
      // Bağlantı eklentisi kullanılamazsa çevrimiçi varsayılır; istekler kendi hatasını yönetir.
      _online = true;
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next != _online) {
      _online = next;
      if (next) _tilesFailing = false;
      notifyListeners();
    }
  }

  void reportTileError() {
    if (!_tilesFailing) {
      _tilesFailing = true;
      notifyListeners();
    }
  }

  void reportTileSuccess() {
    if (_tilesFailing) {
      _tilesFailing = false;
      notifyListeners();
    }
  }

  /// Testler için.
  @visibleForTesting
  void setOnline(bool value) => _apply([value ? ConnectivityResult.wifi : ConnectivityResult.none]);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
