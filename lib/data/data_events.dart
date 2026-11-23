import 'package:flutter/foundation.dart';

/// Veride ne değiştiği.
enum DataChange { travels, photos, plans, expenses, countries, cities, settings }

/// Depolar bir kayıt değiştirdiğinde bunu duyurur; ekran modelleri (ViewModel)
/// dinleyip kendini yeniler. Böylece ekranlar arasında veri hep tutarlı kalır.
class DataEvents extends ChangeNotifier {
  DataChange? _last;
  int _revision = 0;

  DataChange? get last => _last;
  int get revision => _revision;

  void emit(DataChange change) {
    _last = change;
    _revision++;
    notifyListeners();
  }
}
