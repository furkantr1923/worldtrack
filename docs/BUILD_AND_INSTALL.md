# Derleme ve kurulum

## Kurulum (son kullanıcı)

### Windows 10 / 11 (64 bit)

**Seçenek A — Kurulum sihirbazı (önerilen)**
1. `WORLDTRACK-1.0.0-Windows-Setup.exe` dosyasını çalıştırın.
2. Windows SmartScreen "tanınmayan uygulama" uyarısı gösterirse **Ek bilgi → Yine de çalıştır**
   seçin. (Kurulum dosyası kod imzalama sertifikasıyla imzalı değildir; bkz. bilinen sınırlamalar.)
3. Kurulum yönetici izni istemez; varsayılan olarak kullanıcı klasörüne kurar.
   İsterseniz masaüstü kısayolu oluşturabilirsiniz.
4. Kaldırmak için: **Ayarlar → Uygulamalar → WORLDTRACK → Kaldır**. Seyahat kayıtlarınız
   (`%APPDATA%\Furkan Baykal\WORLDTRACK`) bilerek silinmez; yeniden kurulumda geri gelir.

**Seçenek B — Taşınabilir (kurulumsuz)**
1. `WORLDTRACK-1.0.0-Windows-Portable.zip` dosyasını bir klasöre çıkarın.
2. `WORLDTRACK-Portable\WORLDTRACK.exe` dosyasını çalıştırın.
3. Klasördeki `portable.txt` durdukça veriler `WORLDTRACK-Veri` alt klasöründe saklanır;
   klasörü USB belleğe taşıyabilirsiniz.

Gerekli Visual C++ çalışma zamanı DLL'leri (`msvcp140`, `vcruntime140`, `vcruntime140_1`)
uygulama klasörüne dahil edilmiştir; ek kurulum gerekmez.

### Android 7.0+ (API 24+)

1. `WORLDTRACK-1.0.0-Android.apk` dosyasını telefona aktarın ve açın.
2. "Bilinmeyen kaynaklardan yükleme" izni istenirse dosyayı açtığınız uygulama için izin verin.
3. İstenen izinler yalnızca **İnternet** ve **Ağ durumu**dur. Fotoğraflar sistemin fotoğraf
   seçicisiyle alınır; depolama, kamera veya konum izni istenmez.

> Not: CI'da `ANDROID_KEYSTORE_*` gizli anahtarları tanımlı değilse APK, derleme
> makinesinin hata ayıklama anahtarıyla imzalanır. Kurulup çalışır; ancak farklı bir
> derlemeyle güncellerken önce eski sürümü kaldırmak gerekebilir. Kalıcı yayın anahtarı
> için aşağıya bakın.

## Geliştirici: kaynaktan derleme

Gereksinimler: Flutter **3.29.3** (stable, Dart 3.7), Git.
* Windows için: Visual Studio 2022 ("Desktop development with C++" iş yükü).
* Android için: Android SDK (API 35), JDK 17.

```bash
git clone https://github.com/furkantr1923/worldtrack.git
cd worldtrack
flutter pub get
flutter run -d windows          # veya: flutter run -d <android-cihaz>
```

### Yayın derlemeleri

```bash
flutter build windows --release   # build/windows/x64/runner/Release/WORLDTRACK.exe
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

Windows kurulum dosyası (Inno Setup 6):
```powershell
iscc /DAppVersion=1.0.0 installer\worldtrack.iss   # out\WORLDTRACK-1.0.0-Windows-Setup.exe
```

### Android yayın anahtarı (isteğe bağlı)

```bash
keytool -genkey -v -keystore worldtrack.jks -keyalg RSA -keysize 2048 -validity 10000 -alias worldtrack
```
Yerelde `android/key.properties`:
```
storeFile=/tam/yol/worldtrack.jks
storePassword=…
keyAlias=worldtrack
keyPassword=…
```
CI'da GitHub **Settings → Secrets → Actions** altında: `ANDROID_KEYSTORE_BASE64`
(`base64 -w0 worldtrack.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Anahtar dosyaları `.gitignore` ile depoya girmez.

### Testler

```bash
flutter test                                      # birim + widget testleri
flutter test integration_test/app_test.dart -d windows   # uçtan uca (masaüstü)
flutter test integration_test/app_test.dart -d <android>  # uçtan uca (telefon/emülatör)
```
Linux'ta birim testleri için `libsqlite3-dev` gerekir.

### Sürekli entegrasyon

`.github/workflows/build.yml` her `main` gönderiminde:
1. `flutter analyze` + birim/widget testleri (Ubuntu)
2. Windows release derlemesi → Setup.exe + taşınabilir zip → **sessiz kurulum, açılış,
   yeniden açılış, kaldırma ve taşınabilir mod testi** → masaüstünde uçtan uca test
3. Android release APK → **API 34 emülatöründe kurulum, açılış, geri tuşu, yeniden açılış,
   çökme kontrolü** → emülatörde uçtan uca test
4. Tüm çıktılar, loglar ve ekran görüntüleri `builds` dalına konur; `v*` etiketi
   gönderilirse GitHub Release oluşturulur.

### Coğrafi veriyi yeniden üretme

```bash
python3 tool/prepare_data.py --out assets/data          # Natural Earth + GeoNames indirir
tool/render_flags.sh <country-flags/svg> assets/flags   # bayrak PNG'leri (rsvg-convert)
tool/branding/generate_icons.sh                          # uygulama ikonları
```
Veri dosyaları değiştiğinde `AppDatabase.geoDataVersion` artırılır; mevcut kullanıcıların
veritabanı, kişisel kayıtlara dokunulmadan güncellenir.
