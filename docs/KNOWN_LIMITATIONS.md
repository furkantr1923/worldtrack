# Bilinen sınırlamalar

Dürüst ve eksiksiz bir liste. Hiçbiri temel özellikleri engellemez.

| Konu | Durum | Neden / Çözüm |
|---|---|---|
| Windows kod imzası | Setup.exe ve WORLDTRACK.exe dijital sertifikayla imzalı değil | SmartScreen ilk çalıştırmada uyarı gösterebilir ("Ek bilgi → Yine de çalıştır"). Ücretli kod imzalama sertifikası gerekir. |
| Android imzası | Gizli anahtar tanımlı değilse APK, derleme makinesinin hata ayıklama anahtarıyla imzalanır | Kurulur ve çalışır; ancak sonraki bir derlemeyle güncellemede önce kaldırmak gerekebilir. Kalıcı anahtar için `BUILD_AND_INSTALL.md`. Play Store'a yüklemek için yayın anahtarı ve AAB gerekir. |
| Şehir kapsamı | GeoNames'te nüfusu **15.000+** olan ≈32 bin yerleşim | Küçük köy/kasabalar "Şehri elle ekle" ile eklenir; konum isteğe bağlıdır, uygulama koordinat tahmin etmez. |
| Türkçe şehir adları | GeoNames'te Türkçe adı olan şehirlerde Türkçe ad (Münih, Viyana…), diğerlerinde yerel/uluslararası ad | Arama her iki adla da çalışır. |
| Harita sınır hassasiyeti | Natural Earth 1:50m (≈1 km'ye yuvarlanmış) | Ülke seçimi için yeterli; çok küçük ada ülkeleri yakınlaştırınca seçilebilir, hepsi aramayla bulunabilir. 13 küçük bölgenin (ör. Cebelitarık) ayrı poligonu yoktur; arama ve detay sayfası çalışır. |
| Ayrıntılı altlık harita | Varsayılan harita stilizedir (ülke düzeyi); yol/şehir ayrıntısı için OSM altlığı isteğe bağlıdır | OSM ücretsiz karoları yoğun/ticari kullanım için değildir; ticari dağıtımda lisanslı bir sağlayıcı (Ayarlar → Özel adres) kullanılmalıdır. Çevrimiçi karolar için kalıcı çevrimdışı önbellek yoktur. |
| Gerçek güzergâhlar | Uçuş ve demiryolu güzergâhı verisi yoktur | Uçuşlar "büyük daire yayı", diğerleri "basit bağlantı" olarak açıkça etiketlenir. Karayolu için isteğe bağlı OSRM tahmini vardır (demo sunucusu garanti vermez). |
| Kur çevrimi | Yapılmaz | Bilinçli tercih: canlı kur servisi gerektirmemek ve yanıltıcı toplam göstermemek için masraflar para birimine göre ayrı toplanır. |
| Yedekleme | Otomatik bulut yedeği yoktur (kapsam dışı) | Veritabanı ve fotoğraflar tek klasördedir (Ayarlar'da yol gösterilir); klasör elle kopyalanarak yedeklenebilir. Taşınabilir sürümde klasör zaten exe'nin yanındadır. |
| HEIC fotoğraflar (Windows) | Windows'ta HEIC dosyaları için önizleme üretilemeyebilir | Dosya yine saklanır ve "önizleme yok" gösterilir. Android'de sistem seçicisi HEIC'i JPEG'e dönüştürür. |
| Gerçek cihaz testi | Android testleri API 34 emülatöründe, Windows testleri GitHub'ın Windows Server 2022 sanal makinesinde yapıldı | Fiziksel telefon ve kişisel bilgisayarda elle deneme bu projede yapılmadı; sonuçlar `TEST_RESULTS.md`'de ayrı ayrı belirtilmiştir. |
