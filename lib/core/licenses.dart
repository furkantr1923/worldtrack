import 'package:flutter/foundation.dart';

/// Uygulamayla gelen veri ve yazı tipi lisansları "Lisanslar" sayfasında listelenir.
void registerDataLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['Natural Earth (ülke sınırları)'], '''
Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com.
Natural Earth verileri kamu malıdır (public domain).
Kullanılan katman: Admin 0 – Countries, 1:50m (çizim) ve 1:10m (şehir ataması).''');
    yield const LicenseEntryWithLineBreaks(['GeoNames (ülke ve şehir verisi)'], '''
GeoNames — www.geonames.org
Creative Commons Attribution 4.0 License (CC BY 4.0).
Kullanılan dosyalar: countryInfo.txt, cities15000, admin1CodesASCII, alternateNamesV2 (Türkçe adlar).
Veriler uygulama için biçim olarak dönüştürülmüştür; içerik değiştirilmemiştir.''');
    yield const LicenseEntryWithLineBreaks(['Bayraklar'], '''
github.com/hampusborgos/country-flags — Wikimedia Commons kaynaklı SVG bayraklar.
Ulusal bayraklar kamu malıdır. KKTC bayrağı resmî tarifine göre çizilmiştir.''');
    yield const LicenseEntryWithLineBreaks(['Vikipedi (çevrimiçi ülke özetleri)'], '''
Ülke özetleri Türkçe Vikipedi'den alınır ve CC BY-SA 4.0 lisanslıdır.
Her özetin altında kaynak sayfa bağlantısı gösterilir.''');
    yield const LicenseEntryWithLineBreaks(['Harita altlığı'], '''
© OpenStreetMap katkıda bulunanlar (ODbL) — openstreetmap.org/copyright
CARTO Basemaps © CARTO — carto.com/attributions''');
    yield const LicenseEntryWithLineBreaks(['Poppins yazı tipi'], '''
Copyright 2020 The Poppins Project Authors (github.com/itfoundry/Poppins)
SIL Open Font License, Version 1.1.''');
  });
}
