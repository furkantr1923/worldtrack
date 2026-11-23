# Test sonuçları

Sonuçlar GitHub Actions'taki gerçek çalıştırmadan alınmıştır
(commit `b030b9c`, 23 Kasım 2026). Loglar ve ekran görüntüleri her çalıştırmada
[`builds`](https://github.com/furkantr1923/worldtrack/tree/builds) dalına konur
(`logs/`, `screens/`).

**Burada "BAŞARILI" yazan her test gerçekten çalıştırıldı.** Yapılmayanlar en altta ayrıca belirtilmiştir.

## Özet

| Kategori | Ortam | Sonuç |
|---|---|---|
| Statik analiz (`flutter analyze`) | Ubuntu, Flutter 3.29.3 | **0 hata** |
| Birim + widget testleri | Ubuntu, gerçek SQLite (FFI) + gömülü gerçek veri | **32 / 32 geçti** |
| Windows release derlemesi + Setup.exe + taşınabilir zip | Windows Server 2022, VS 2022, Inno Setup 6 | **Başarılı** |
| Windows kurulum / açılış / yeniden açılış / kaldırma | aynı sanal makine | **Başarılı** |
| Windows taşınabilir sürüm (veri exe'nin yanında) | aynı sanal makine | **Başarılı** |
| Windows uçtan uca test (19 ekran görüntüsü) | Windows masaüstü | **Geçti** |
| Android release APK derlemesi | Ubuntu, JDK 17, Android SDK 35 | **Başarılı** |
| Android kurulum / açılış / geri tuşu / yeniden açılış / çökme taraması | Android 14 (API 34) emülatörü, Pixel 6 profili | **Başarılı, çökme yok** |
| Android uçtan uca test (19 ekran görüntüsü) | aynı emülatör | **Geçti** |

## Birim ve widget testleri (32)

* **Türkçe metin:** İ/I kuralı, ç/ğ/ı/ö/ş/ü katlama, aksanlar, Türk alfabesiyle sıralama
* **Coğrafya:** İstanbul–Ankara ≈350 km, tarih değiştirme çizgisini geçen büyük daire yayı, nokta-poligon, mesafe biçimi
* **Tarih:** veritabanı biçimi, süre son günü dahil, Türkçe aralık metni, yaz saati
* **Tutar:** "1.250,50" / "1250.50" ayrıştırma, para biçimi
* **Coğrafi veri:** ≈250 ülke ve 30 bin+ şehrin yüklenmesi; `turkiye`, `ALMANYA`, `cekya`, `tayvan`, `munih`, `İSTANBUL`, `corum`, `girne` aramaları
* **Harita tıklama:** Türkiye, Fransa, Brezilya, KKTC doğru; okyanus → seçim yok
* **Şema sürümü**
* **Seyahat kaydı:** oluştur / düzenle / sil; gelecek tarih ve 0 gün reddi; **kapatıp yeniden açınca veri kalıcı**; aynı şehir+tarih uyarısı (bilinçli tekrar mümkün)
* **İstatistik:** Roma'ya 3 kez gidilmesi 1 şehir sayılır; elle işaretlenen ülke ekleniyor, iki kez sayılmıyor
* **Silme zinciri:** kayıt silinince fotoğraf dosyaları ve masraflar da siliniyor
* **Masraf:** para birimine göre ayrı toplam, 0 tutar reddi
* **Plan:** kaydet, durak sırasını değiştir, önerilen tarihler, seyahate dönüştür (tek işlem), planlanan ülkeler; gelecekteki plan dönüştürülemez; plan silinince kayıtlar kalır
* **Takvim:** ay sınırını aşan seyahatin doğru aya düşmesi
* **Elle eklenen şehir:** tekrar eklemede aynı kayıt, aramada bulunur, geçersiz değer reddi
* **Arayüz:** telefon düzeni (alt gezinme, boş durumlar), masaüstü düzeni (yan menü, 7 bölüm)

## Uçtan uca test akışı (Windows ve Android'de aynı)

`integration_test/app_test.dart` uygulamayı gerçek veritabanıyla açar ve kullanıcı gibi dokunur:

| # | Adım | Doğrulama |
|---|---|---|
| 1 | Boş ana sayfa | İstatistik kartları |
| 2 | Seyahat ekle: "italya" → İtalya, "roma" → Roma, tarih, +2 gün, Uçak, not, 2 fotoğraf | Kayıt oluştu |
| 3 | Detay → fotoğraf görüntüleyici (1/2) → bir fotoğrafı kaldır | "Fotoğraflar (1)" |
| 4 | Masraf "1250,50" | Toplam "1.250,50" |
| 5 | Düzenle: süre −1 | Detayda "2 gün" |
| 6 | Arşive 6 kayıt (biri Roma tekrar) | **6 ülke / 6 şehir** (tekrar ziyaret tek sayıldı) |
| 7 | Harita: merkeze dokun → Libya paneli; arama → Japonya → "Gittim" | Ziyaret edilenlere eklendi |
| 8 | Yakınlaştır / uzaklaştır / tüm dünya; Ülke detayı + Vikipedi özeti | Sayfa açıldı |
| 9 | Plan: "Balkan turu", 3 durak (Atina → Sofya otobüs → Belgrad tren) | Rota haritası |
| 10 | Geçmiş tarihli plan → "Seyahate dönüştür" | 2 kayıt oluştu, plan "Tamamlandı" |
| 11 | Takvim: sonraki / önceki ay | Başlık doğru değişti |
| 12 | Keşfet, "munih" araması, Ayarlar, koyu tema | Münih bulundu |
| 13 | Çevrimdışı mod | Uyarı şeridi; kayıt ve fotoğraf açılıyor |
| 14 | Kayıt sil | Sayı 1 azaldı |
| 15 | **Uygulamayı kapat, servisleri yeniden başlat** | 8 kayıt, tüm fotoğraf dosyaları ve "Japonya ziyaret edildi" kalıcı |

## Windows kurulum testi (gerçek log)

```
Kurulum dosyası: WORLDTRACK-1.0.0-Windows-Setup.exe (14.2 MB)
KURULUM: BAŞARILI (WORLDTRACK.exe mevcut)      Başlat menüsü kısayolu: WORLDTRACK.lnk
AÇILIŞ: BAŞARILI (süreç çalışıyor, bellek 136 MB)
Veritabanı oluşturuldu: %APPDATA%\Furkan Baykal\WORLDTRACK\worldtrack.db (4.4 MB)
YENİDEN AÇILIŞ: BAŞARILI
KALDIRMA: BAŞARILI — kişisel veriler korunuyor (beklenen davranış)
TAŞINABİLİR AÇILIŞ: BAŞARILI — veri klasörü exe yanında
```

## Android emülatör testi (gerçek log)

```
Emülatör: sdk_gphone64_x86_64 / Android 14 (API 34)
KURULUM: BAŞARILI          AÇILIŞ: BAŞARILI (soğuk açılış 5,7 sn)
YENİDEN AÇILIŞ: BAŞARILI   (soğuk açılış 2,6 sn)
ÇÖKME: YOK
İzinler: INTERNET, ACCESS_NETWORK_STATE (başka izin yok)
```

## Testler sırasında bulunup düzeltilen hatalar

| Hata | Nasıl bulundu | Düzeltme |
|---|---|---|
| Form altındaki "Kaydet" çubuğu tüm ekranı kaplıyor, form görünmüyordu | E2E testi alanı bulamadı | `Align(heightFactor: 1)` |
| Ulaşım çiplerinin yazısı görünmüyordu (beyaz) | E2E ekran görüntüsü | Çip temasına açık renk |
| Üst çubuk başlıkları küçük | E2E ekran görüntüsü | Başlık stili açıkça tanımlandı |
| CARTO altlığı "API KEY REQUIRED" filigranı | E2E ekran görüntüsü | CARTO kaldırıldı, stilize harita varsayılan |
| Takvim küçük pencerede 9 px taşıyor | Windows E2E (taşma hatası) | Kaydırılabilir ızgara |
| Yan menüde uzun etiket taşması | Widget testi | `Expanded` + `ellipsis` |
| Elle eklenen şehir tekrar oluşturuluyordu | Birim testi | Ad karşılaştırması Türkçe katlamayla |
| Telefonda istatistik etiketi kırpılıyordu | Emülatör ekran görüntüsü | İki satıra izin |

## Yapılmayan testler (dürüstçe)

* **Fiziksel Android telefon** ve **kişisel Windows bilgisayar** üzerinde elle deneme bu
  projede yapılmadı; testler emülatörde ve GitHub'ın Windows sanal makinesinde çalıştı.
* Gerçek sistem fotoğraf seçicisi otomatik testte açılamaz; testlerde aynı arayüzü
  kullanan sahte bir seçiciyle üretilen JPEG'ler içe aktarıldı (kopyalama, önizleme,
  görüntüleme, silme ve kalıcılık gerçek kodla test edildi).
* Binlerce kayıtla yük testi yapılmadı; listeler tembel oluşturulur ve sorgular indekslidir.
