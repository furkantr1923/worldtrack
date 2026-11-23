#!/usr/bin/env bash
# Uygulama ikonlarını SVG kaynaklarından üretir (rsvg-convert + ImageMagick gerekir).
set -euo pipefail
cd "$(dirname "$0")/../.."
B=tool/branding
rsvg-convert -w 512 -h 512 $B/icon.svg -o assets/branding/logo.png
RES=android/app/src/main/res
for pair in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read d s f <<< "$pair"
  mkdir -p $RES/mipmap-$d
  rsvg-convert -w $s -h $s $B/icon.svg -o $RES/mipmap-$d/ic_launcher.png
  rsvg-convert -w $f -h $f $B/icon_foreground.svg -o $RES/mipmap-$d/ic_launcher_foreground.png
done
mkdir -p $RES/drawable-nodpi
rsvg-convert -w 288 -h 288 $B/icon_foreground.svg -o $RES/drawable-nodpi/splash_logo.png
tmp=$(mktemp -d)
for s in 16 24 32 48 64 128 256; do rsvg-convert -w $s -h $s $B/icon.svg -o $tmp/$s.png; done
convert $tmp/16.png $tmp/24.png $tmp/32.png $tmp/48.png $tmp/64.png $tmp/128.png $tmp/256.png \
  windows/runner/resources/app_icon.ico
cp $B/icon.svg assets/branding/icon.svg 2>/dev/null || true
rm -rf "$tmp"
echo "ikonlar üretildi"
