# Harita sağlayıcıları ve veri kaynakları

## Kısa cevap: API anahtarı veya hesap gerekiyor mu?

**Hayır.** Uygulamanın hiçbir özelliği ücretli servis, hesap veya API anahtarı gerektirmez.

## Harita altlığı (Ayarlar → Harita)

Ülke sınırları uygulamanın içindedir; altlık yalnızca görsel arka plandır.

| Seçenek | Adres | Anahtar | Not |
|---|---|---|---|
| **CARTO** (varsayılan) | `basemaps.cartocdn.com/{light,dark}_nolabels` | Gerekmez | Sade, etiketsiz; uygulamanın Türkçe etiketleriyle çakışmaz. CARTO'nun ücretsiz basemap koşulları kişisel/ticari olmayan kullanım içindir; ticari dağıtımda CARTO lisansı gerekir. |
| OpenStreetMap Standart | `tile.openstreetmap.org` | Gerekmez | OSMF karo kullanım politikası yoğun kullanımı yasaklar; uygulama tanımlayıcı `User-Agent` gönderir. |
| Kapalı | — | — | Tamamen çevrimdışı; yalnızca ülke sınırları çizilir. |
| Özel adres | `https://…/{z}/{x}/{y}.png` | Sağlayıcıya göre | Anahtar gerekiyorsa kullanıcı adrese kendisi ekler. Anahtar yalnızca cihazdaki ayarlarda saklanır, **kaynak koda yazılmaz**. |

Karo sağlayıcısı yalnızca görüntülenen harita bölgesinin karo isteklerini görür.
Karolar alınamazsa (çevrimdışı, kota, servis kesintisi) harita boş altlıkla çalışmaya
devam eder ve üstte açıklayıcı bir uyarı gösterilir.

## Gömülü veriler (uygulamanın içinde)

| Veri | Kaynak | Lisans | Dosya |
|---|---|---|---|
| Ülke sınırları (1:50m) | [Natural Earth](https://www.naturalearthdata.com) | Kamu malı | `assets/data/world_shapes.json` |
| Ülke Türkçe adları, bölge, etiket konumu, Wikidata kimliği | Natural Earth Admin-0 | Kamu malı | `assets/data/countries.json` |
| Başkent, nüfus, yüzölçümü, para birimi | [GeoNames](https://www.geonames.org) `countryInfo` | CC BY 4.0 | `assets/data/countries.json` |
| Şehirler (nüfus ≥ 15.000, ≈32 bin) | GeoNames `cities15000` + `admin1CodesASCII` | CC BY 4.0 | `assets/data/cities.tsv.gz` |
| Türkçe şehir adları (Münih, Viyana, Lizbon…) | GeoNames `alternateNamesV2` (`tr`) | CC BY 4.0 | aynı dosya |
| Bayraklar | [country-flags](https://github.com/hampusborgos/country-flags) (Wikimedia Commons) | Kamu malı | `assets/flags/*.png` |
| Yazı tipi | Poppins | SIL OFL 1.1 | `assets/fonts/` |

Veriler `tool/prepare_data.py` ile yeniden üretilebilir (bkz. `BUILD.md`). Araç hiçbir
bilgi uydurmaz; kaynakta olmayan alan boş bırakılır ve uygulamada gösterilmez.

Özel durumlar:
* **KKTC** (`XC`) ve **Somaliland** (`XS`) Natural Earth'te ayrı çizilir; ISO kodları
  olmadığı için uygulama içi kod kullanılır. Bu bölgelerdeki şehirler 1:10m hassas
  sınırlarla nokta-poligon testiyle atanır. Lefkoşa bölünmüş bir şehir olduğundan
  GeoNames kaydı Kıbrıs'ta kalır, KKTC'nin başkenti olarak da gösterilir.
* Nüfus değerleri GeoNames'in yayımladığı değerlerdir ve uygulamada "Nüfus (GeoNames)"
  olarak etiketlenir.

## Çevrimiçi kaynaklar

| Özellik | Servis | Gönderilen bilgi | Çevrimdışıyken |
|---|---|---|---|
| Ülke özeti | Wikidata API + Türkçe Vikipedi REST | Yalnızca ülkenin Wikidata kimliği / adı | Önbellekteki özet; yoksa açıklayıcı mesaj, bağlantı gelince otomatik yeniden deneme |
| Karayolu güzergâh tahmini (**varsayılan kapalı**) | OSRM (`router.project-osrm.org` demo veya kullanıcının sunucusu) | Yalnızca iki durağın koordinatı, kullanıcı düğmeye bastığında | Düğme devre dışı; basit bağlantılar gösterilir |

Vikipedi metni CC BY-SA 4.0'dır; her özetin altında kaynak ve "Devamını oku" bağlantısı bulunur.
OSRM demo sunucusu ücretsizdir ancak hizmet garantisi yoktur; yoğun kullanım için kendi
sunucunuzu Ayarlar'dan girebilirsiniz.

## Rota çizimleri ne anlama gelir?

| Çizgi | Anlamı |
|---|---|
| Turuncu-kırmızı kesikli yay | Uçak: iki şehir arasındaki **büyük daire** yayı. Gerçek uçuş rotası değildir. |
| Turuncu kesikli düz çizgi | Otobüs/tren/araba: **basit bağlantı**. Gerçek yol veya demiryolu değildir. |
| Düz yeşil-mavi çizgi | Kullanıcı istediğinde OSRM'den alınan **tahmini karayolu** güzergâhı. |

Mesafeler her zaman "kuş uçuşu" olarak etiketlenir.
