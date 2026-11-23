#!/usr/bin/env bash
# Android emülatöründe kurulum, açılış, yeniden başlatma ve uçtan uca test.
# reactivecircus/android-emulator-runner içinden çalıştırılır.
set -u
PKG=com.furkanbaykal.worldtrack
APK=$(ls out/*.apk | head -1)
mkdir -p logs out/screens-android
R=logs/android-emulator.txt
: > "$R"
log() { echo "$*" | tee -a "$R"; }

log "== Emülatör: $(adb shell getprop ro.product.model) / Android $(adb shell getprop ro.build.version.release) (API $(adb shell getprop ro.build.version.sdk))"
log "== APK kurulumu: $APK"
if adb install -r "$APK" >> "$R" 2>&1; then log "KURULUM: BAŞARILI"; else log "KURULUM: BAŞARISIZ"; fi

log "== İzinler"
adb shell dumpsys package $PKG | grep -E "android.permission" | sed 's/^ */  /' | sort -u | tee -a "$R"

adb logcat -c
log "== Açılış"
adb shell am start -W -n $PKG/.MainActivity >> "$R" 2>&1
sleep 25
if [ -n "$(adb shell pidof $PKG)" ]; then log "AÇILIŞ: BAŞARILI (süreç çalışıyor)"; else log "AÇILIŞ: BAŞARISIZ"; fi
adb exec-out screencap -p > out/screens-android/a01_acilis.png

log "== Geri tuşu (ana sayfadayken uygulamadan çıkılmalı, çökmemeli)"
adb shell input keyevent KEYCODE_BACK
sleep 3
adb shell am start -n $PKG/.MainActivity > /dev/null 2>&1
sleep 8

log "== Zorla kapatıp yeniden açma"
adb shell am force-stop $PKG
sleep 2
adb shell am start -W -n $PKG/.MainActivity >> "$R" 2>&1
sleep 12
if [ -n "$(adb shell pidof $PKG)" ]; then log "YENİDEN AÇILIŞ: BAŞARILI"; else log "YENİDEN AÇILIŞ: BAŞARISIZ"; fi
adb exec-out screencap -p > out/screens-android/a02_yeniden_acilis.png
if adb shell run-as $PKG ls files >/dev/null 2>&1; then :; fi

log "== Çökme kontrolü (logcat)"
if adb logcat -d | grep -E "FATAL EXCEPTION|AndroidRuntime: FATAL" > logs/android-crash.txt; then
  log "ÇÖKME: VAR (logs/android-crash.txt)"
else
  log "ÇÖKME: YOK"
fi
adb logcat -d -s flutter > logs/android-flutter-logcat.txt 2>&1 || true

log "== Uçtan uca test (emülatörde, hata ayıklama derlemesi)"
adb uninstall $PKG > /dev/null 2>&1 || true
if timeout 2400 flutter test integration_test/app_test.dart -d emulator-5554 -r expanded > logs/android-e2e.log 2>&1; then
  log "E2E (Android): BAŞARILI"
else
  log "E2E (Android): BAŞARISIZ — ayrıntı logs/android-e2e.log"
fi
tail -5 logs/android-e2e.log | tee -a "$R"
adb exec-out run-as $PKG tar -c -C cache worldtrack_screens > /tmp/screens.tar 2>/dev/null || true
if [ -s /tmp/screens.tar ]; then
  mkdir -p /tmp/scr && tar -xf /tmp/screens.tar -C /tmp/scr && cp /tmp/scr/worldtrack_screens/*.png out/screens-android/ 2>/dev/null || true
fi
log "== Ekran görüntüleri: $(ls out/screens-android | wc -l)"
exit 0
