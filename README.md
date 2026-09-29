# Ekran Ayarı (macOS)

Tek tıkla akıllı tahta / harici ekran ayarı: yansıtmayı sıfırlar, 30 Hz yapar, yerleşik ekranı yansıtır,
sesi harici ekrana verir, açık Zoom toplantısında hoparlörü "Sistemle aynı" yapar.

- `kaynak/main.swift` — uygulama kaynak kodu
- `Paketle.command` — Mac'te derler, `dagitim/` ve `sunucu/` klasörlerini günceller
- `sunucu/` — **güncelleme sunucusu**. Uygulamalar her açılışta buradan okur:
  `https://raw.githubusercontent.com/anurayli/ekranayari/main/sunucu/`
  - `ayarlar.json` — Hz, adımları aç/kapat, bitiş sesi, Dock sabitleme
  - `zoom.applescript` — Zoom adımı (derleme gerektirmeden güncellenir)
  - `surum.json` + `EkranAyari.zip` — uygulamanın kendisi (Paketle.command üretir)

Ayrıntılar: `BENIOKU.md`
