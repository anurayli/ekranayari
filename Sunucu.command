#!/bin/bash
# Bu Mac'i güncelleme sunucusu yapar. Pencere açık kaldıkça çalışır.
cd "$(dirname "$0")/sunucu" || exit 1
clear
echo "=== EkranAyari güncelleme sunucusu ==="
echo "Adres (aynı ağdaki Mac'ler için): http://$(scutil --get LocalHostName).local:8080/"
IP=$(ipconfig getifaddr en0 2>/dev/null); [ -n "$IP" ] && echo "IP ile            : http://$IP:8080/"
echo "Kapatmak için bu pencereyi kapatın veya Ctrl+C."
echo
/usr/bin/python3 -m http.server 8080
