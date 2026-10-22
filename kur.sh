#!/bin/bash
# Ekran Ayarı — tek satırla kurulum:
#   curl -fsSL https://raw.githubusercontent.com/anurayli/ekranayari/main/kur.sh | bash
set -e
ZIP="https://github.com/anurayli/ekranayari/raw/main/sunucu/EkranAyari.zip"
HEDEF="/Applications"
[ -w "$HEDEF" ] || { HEDEF="$HOME/Applications"; mkdir -p "$HEDEF"; }
GECICI=$(mktemp -d)
echo "Ekran Ayarı indiriliyor..."
curl -fsSL -o "$GECICI/EkranAyari.zip" "$ZIP"
killall EkranAyari 2>/dev/null || true
rm -rf "$HEDEF/EkranAyari.app"
ditto -x -k "$GECICI/EkranAyari.zip" "$HEDEF"
xattr -dr com.apple.quarantine "$HEDEF/EkranAyari.app" 2>/dev/null || true
rm -rf "$GECICI"
echo "✓ Kuruldu: $HEDEF/EkranAyari.app — açılıyor. İzin pencerelerinde 'İzin Ver' deyin."
open "$HEDEF/EkranAyari.app"
