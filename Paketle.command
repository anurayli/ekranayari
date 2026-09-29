#!/bin/bash
# EkranAyari'yı derler, yeni sürüm numarası verir ve "sunucu" klasörüne yayınlar.
# Her çalıştırma = yeni sürüm. Programı açan tüm Mac'ler bu sürümü kendiliğinden indirir.
cd "$(dirname "$0")"
clear
echo "=== EkranAyari paketleniyor ==="

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Derleyici yok. Açılan pencerede 'Yükle'ye basın, bitince tekrar çalıştırın."
  xcode-select --install 2>/dev/null
  read -n 1 -s -r -p "Kapatmak için bir tuşa basın..."; exit 0
fi

# Sunucu adresi (ilk seferde bu Mac olarak ayarlanır; değiştirmek için sunucu_adresi.txt'yi düzenleyin)
if [ ! -s sunucu_adresi.txt ]; then
  echo "http://$(scutil --get LocalHostName).local:8080/" > sunucu_adresi.txt
fi
ADRES=$(tr -d '[:space:]' < sunucu_adresi.txt)

SURUM=$(( $(cat kaynak/SURUM 2>/dev/null || echo 0) + 1 ))
echo "Sürüm: $SURUM   Sunucu: $ADRES"

TMP=$(mktemp -d)
APP="$TMP/EkranAyari.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Derleniyor..."
if ! swiftc -O -target arm64-apple-macos12 kaynak/main.swift -o "$TMP/arm64" 2> "$TMP/hata.txt"; then
  cat "$TMP/hata.txt"; echo "Derleme başarısız."; read -n 1 -s -r -p "Kapatmak için bir tuşa basın..."; exit 1
fi
if swiftc -O -target x86_64-apple-macos13 kaynak/main.swift -o "$TMP/x86_64" 2>/dev/null; then
  lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$APP/Contents/MacOS/EkranAyari"
  echo "  Apple Silicon + Intel"
else
  cp "$TMP/arm64" "$APP/Contents/MacOS/EkranAyari"
  echo "  Yalnızca Apple Silicon (Intel derlemesi bu Mac'te yapılamadı)"
fi

echo "$ADRES" > "$APP/Contents/Resources/sunucu.txt"

# Simge (simge.png varsa)
if [ -f simge.png ]; then
  SET="$TMP/AppIcon.iconset"; mkdir -p "$SET"
  for b in 16 32 128 256 512; do
    sips -z $b $b simge.png --out "$SET/icon_${b}x${b}.png" >/dev/null
    b2=$((b*2)); sips -z $b2 $b2 simge.png --out "$SET/icon_${b}x${b}@2x.png" >/dev/null
  done
  if iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"; then echo "  Simge eklendi"; fi
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>EkranAyari</string>
  <key>CFBundleDisplayName</key>       <string>Ekran Ayarı</string>
  <key>CFBundleIdentifier</key>        <string>tr.k12.sevizmir.ekranayari</string>
  <key>CFBundleExecutable</key>        <string>EkranAyari</string>
  <key>CFBundleIconFile</key>          <string>AppIcon</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.$SURUM</string>
  <key>CFBundleVersion</key>           <string>$SURUM</string>
  <key>LSMinimumSystemVersion</key>    <string>12.0</string>
  <key>LSUIElement</key>               <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Zoom ses ayarını "Sistemle aynı" yapmak için gereklidir.</string>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Güncellemeleri okul ağındaki sunucudan almak için gereklidir.</string>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP" 2>/dev/null

mkdir -p sunucu dagitim
rm -rf dagitim/EkranAyari.app
ditto "$APP" dagitim/EkranAyari.app
( cd "$TMP" && ditto -c -k --keepParent EkranAyari.app EkranAyari.zip )
cp "$TMP/EkranAyari.zip" sunucu/EkranAyari.zip
cp "$TMP/EkranAyari.zip" dagitim/EkranAyari.zip
cat > sunucu/surum.json <<JSON
{ "uygulamaSurum": $SURUM, "uygulamaDosyasi": "EkranAyari.zip" }
JSON
echo "$SURUM" > kaynak/SURUM
rm -rf "$TMP"

echo
echo "✓ Hazır."
echo "  Dağıtılacak uygulama : dagitim/EkranAyari.app  (veya dagitim/EkranAyari.zip)"
echo "  Sunucuya yayınlandı  : sunucu/  (sürüm $SURUM)"
read -n 1 -s -r -p "Kapatmak için bir tuşa basın..."
echo
