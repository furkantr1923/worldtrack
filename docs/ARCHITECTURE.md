# Mimari

WORLDTRACK, **tek bir Flutter kod tabanından** Windows ve Android uygulaması üretir.
İki platform aynı iş mantığını, aynı veritabanı şemasını ve aynı ekranları paylaşır.
Yalnızca düzen (layout) ekran genişliğine göre değişir.

## Neden Flutter (ve .NET MAUI değil)?

Ana gereksinimde tercih edilen teknoloji .NET MAUI idi. Ancak MAUI'nin resmî harita
kontrolü (`Microsoft.Maui.Controls.Maps`) **Windows'u desteklemez**. Windows'ta harita
için WebView içinde JavaScript harita kütüphanesi çalıştırmak gerekirdi ve bu, iki
platformda iki ayrı harita yığını anlamına gelirdi. Flutter + `flutter_map` ise iki
platformda aynı Dart koduyla çalışır. Ülke sınırları da uygulamanın içinden çizildiği
için harita internetsiz de kullanılabilir. Bu güvenilirlik farkı nedeniyle Flutter seçildi.

## Katmanlar (MVVM)

```
lib/
├── main.dart, app.dart          Giriş noktası, tema, yerelleştirme (yalnızca tr_TR)
├── app_services.dart            Bağımlılık kabı: veritabanı + depolar + servisler
├── core/
│   ├── theme/app_theme.dart     Renk sistemi, tipografi (Poppins), bileşen temaları
│   ├── utils/turkish_text.dart  Türkçe katlama (ç→c, ı→i …) ve Türk alfabesiyle sıralama
│   ├── utils/dates.dart         Takvim günü olarak tarih (yyyy-MM-dd), Türkçe biçimler
│   ├── utils/geo.dart           Haversine mesafe, büyük daire yayı, nokta-poligon
│   └── licenses.dart            Veri / yazı tipi lisanslarının uygulamaya kaydı
├── data/                        MODEL katmanı
│   ├── db/app_database.dart     SQLite açılışı, ilk veri yükleme (ülke + şehir)
│   ├── db/migrations.dart       Sürümlü şema ve geçişler
│   ├── models/models.dart       Country, City, TravelRecord, TravelPhoto, PlannedTrip,
│   │                            TripStop, Expense, TravelStats, CountryInfo
│   ├── repositories/            Tüm SQL burada: ülke, şehir, seyahat+fotoğraf,
│   │                            plan, masraf, ayarlar
│   ├── data_events.dart         "Veri değişti" yayını (ekranlar otomatik yenilenir)
│   └── storage_paths.dart       Veritabanı ve fotoğraf klasörleri (taşınabilir mod dahil)
├── services/
│   ├── map_shape_service.dart   Gömülü ülke sınırlarını yükler, tıklanan ülkeyi bulur
│   ├── photo_service.dart       Fotoğraf seçme, tek kopya saklama, önizleme üretme
│   ├── connectivity_service.dart Çevrimiçi/çevrimdışı durumu, karo hatası takibi
│   ├── country_info_service.dart Vikipedi özeti + önbellek
│   ├── routing_service.dart     İsteğe bağlı OSRM karayolu tahmini
│   └── settings_controller.dart Tema, altlık harita, güzergâh ayarları
├── viewmodels/                  VIEWMODEL katmanı (ChangeNotifier)
│   └── home, map, travels, travel_detail, plans, calendar, country_detail
└── ui/                          VIEW katmanı
    ├── shell/app_shell.dart     Geniş ekranda yan menü, telefonda alt çubuk, geri tuşu
    ├── screens/                 16 ekran (ana sayfa, harita, seyahatler, plan, takvim…)
    ├── map/                     Dünya haritası, mini harita, rota katmanları
    └── widgets/                 Ortak bileşenler, form alanları, seçiciler, masraflar
```

### Veri akışı

1. Görünüm (ör. `TravelsScreen`) kendi ViewModel'ini oluşturur ve dinler.
2. ViewModel, depodan (repository) veriyi asenkron yükler.
3. Bir kayıt değiştiğinde depo `DataEvents.emit()` çağırır; açık olan tüm ViewModel'ler
   kendini yeniler. Böylece seyahat eklendiğinde harita renkleri, istatistikler, takvim
   ve ülke detayı ekstra kod olmadan güncellenir.

### Harita

* **Ülke sınırları**: Natural Earth 1:50m, uygulamaya gömülü (`assets/data/world_shapes.json`,
  0,01° hassasiyet). Poligonlar `flutter_map`'in `PolygonLayer`'ı ile çizilir;
  ziyaret edildi / planlandı / seçili durumları renkle ayrılır.
* **Ülke seçimi**: Haritaya dokunulan nokta, ayrı bir izolatta yüklenen poligonlarda
  sınır kutusu ön elemesiyle nokta-poligon testinden geçirilir. Küçük ülkeler büyüklerin
  içinde kalabildiği için (Vatikan/İtalya) en küçük sınır kutulu eşleşme seçilir.
* **Etiketler**: Türkçe ülke adları, Natural Earth `MIN_LABEL` değerine göre yakınlaştırma
  düzeyiyle ve yalnızca görünür alandakiler çizilir.
* **Altlık**: İsteğe bağlı raster karolar (CARTO / OSM / özel adres / kapalı). Bkz. `MAP_PROVIDERS.md`.

### Performans önlemleri

* Ağır işler ana iş parçacığında yapılmaz: coğrafi veri ayrıştırma, poligon yükleme ve
  fotoğraf önizleme üretimi `Isolate.run` ile ayrı izolatta çalışır. SQLite, FFI
  fabrikasının arka plan izolatında çalışır.
* İlk açılışta ≈32 bin şehir tek işlemde (`transaction` + toplu `batch`) yüklenir.
* Listeler `ListView.builder` / `SliverList` ile tembel oluşturulur; küçük resimler
  `cacheWidth` ile ekran boyutunda çözülür; tam ekran görüntüleyici ekran çözünürlüğüne göre çözer.
* Poligon listesi yalnızca seçim veya renk durumu değişince yeniden kurulur.
* Ülke listesi (≈250) bellekte tutulur; şehir aramaları indeksli SQL ile yapılır.

### Gizlilik

Kişisel kayıtlar hiçbir zaman ağ üzerinden gönderilmez. İnternete giden istekler yalnızca:
harita karoları (görüntülenen bölge), Wikidata/Vikipedi (ülke kimliği) ve kullanıcı
açıkça etkinleştirip düğmeye basarsa OSRM (iki durağın koordinatı). Analitik veya takip yoktur.
