# Veritabanı

Yerel SQLite dosyası (`worldtrack.db`). Bağlantı açılırken `PRAGMA foreign_keys = ON`
uygulanır. Şema `lib/data/db/migrations.dart` içinde sürümlenir (şu an **v1**).

| Konum | Yol |
|---|---|
| Windows (kurulu) | `%APPDATA%\Furkan Baykal\WORLDTRACK\worldtrack.db` |
| Windows (taşınabilir) | `<exe klasörü>\WORLDTRACK-Veri\worldtrack.db` |
| Android | Uygulamanın özel alanı (`/data/data/com.furkanbaykal.worldtrack/files`) |

Fotoğraflar aynı klasörde `photos/originals` ve `photos/thumbs` altında tutulur.

## Tablolar

| Tablo | Açıklama | Önemli kurallar |
|---|---|---|
| `countries` | ≈252 ülke/bölge (Natural Earth + GeoNames) | `code` (ISO-3166 alfa-2; KKTC=`XC`, Somaliland=`XS`) birincil anahtar. `manual_visited`: kayıt girmeden "gittim" işareti. `search_key`: Türkçe katlanmış arama anahtarı |
| `cities` | ≈32 bin şehir (GeoNames, nüfus ≥ 15.000) + kullanıcının elle eklediği yerler | Kimlik = GeoNames kimliği. Elle eklenenler `1.000.000.000`'dan başlar, `is_custom = 1`; koordinat isteğe bağlıdır |
| `travel_records` | Gerçekleşmiş ziyaret: ülke + şehir + tarih + süre | `duration_days >= 1`; şehir silinemez (`RESTRICT`); `plan_id` → plan silinirse `NULL` |
| `travel_photos` | Kayda bağlı fotoğraflar | Kayıt silinince `CASCADE`; dosyalar depo katmanında ayrıca silinir |
| `planned_trips` | Gelecek planı | `status` ∈ {`planned`, `completed`} |
| `trip_stops` | Plan durakları | `order_index` ile sıralı; plan silinince `CASCADE`; şehir isteğe bağlı |
| `expenses` | İsteğe bağlı masraflar | Tutar **kuruş cinsinden tamsayı** (`amount_minor`); bir kayda veya plana bağlı olmalı (`CHECK`) |
| `settings` | Anahtar–değer ayarlar | tema, altlık, güzergâh, `geo_data_version` |
| `country_info_cache` | Vikipedi özet önbelleği | 30 gün tazelik; çevrimdışıyken eski kopya gösterilir |

## Tarihler

Tüm seyahat tarihleri saat dilimi içermeyen **takvim günü** (`yyyy-MM-dd`) olarak saklanır.
Süre son gün dahil hesaplanır: 12 Mart + 3 gün → 12–14 Mart.
Seyahat kaydı gelecekte olamaz (gelecek için plan kullanılır).

## İstatistik tanımları

* **Ziyaret edilen ülke** = `travel_records` içindeki farklı ülkeler ∪ `manual_visited = 1`
  olan ülkeler. Bir ülke kaç kez ziyaret edilirse edilsin **bir kez** sayılır.
* **Ziyaret edilen şehir** = `travel_records` içindeki **farklı** `city_id` sayısı.
  Aynı şehre yapılan tekrar ziyaretler **bir şehir** olarak sayılır (ziyaret sayısı
  ülke detayında "Roma · 3 kez" şeklinde ayrıca gösterilir).

## Veri kaybına karşı önlemler

* Silme işlemleri onay penceresi ister ve neyin silineceğini açıkça yazar.
* Plan → kayıt dönüşümü ve plan kaydı tek bir işlem (transaction) içindedir: ya hepsi ya hiçbiri.
* Uygulama kaldırıldığında kişisel veriler silinmez (yeniden kurulumda arşiv korunur).
* Coğrafi veri güncellemesi `ON CONFLICT … DO UPDATE` ile yapılır; kullanıcı işaretleri ve
  elle eklenen şehirler korunur.
* Örnek/sahte kayıt üretilmez. Test verileri yalnızca testlerin kendi geçici klasöründe oluşturulur.

## Yeni sürüm (geçiş) eklemek

```dart
static const int latestVersion = 2;
static const Map<int, List<String>> _steps = {
  2: ['ALTER TABLE travel_records ADD COLUMN rating INTEGER'],
};
```
