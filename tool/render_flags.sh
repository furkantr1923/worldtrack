#!/usr/bin/env bash
# Bayrak PNG'lerini üretir. Kaynak: github.com/hampusborgos/country-flags (kamu malı SVG'ler)
# Kullanım: tool/render_flags.sh <country-flags/svg klasörü> assets/flags
set -euo pipefail
src="$1"; dst="$2"; mkdir -p "$dst"
for f in "$src"/*.svg "$(dirname "$0")"/flags/*.svg; do
  b=$(basename "$f" .svg | tr '[:upper:]' '[:lower:]')
  rsvg-convert -w 240 --keep-aspect-ratio "$f" -o "$dst/$b.png"
done
