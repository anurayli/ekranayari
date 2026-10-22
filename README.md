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

## Otomatik çalışma (sürüm 8+)
Uygulama bir kez elle açıldıktan sonra arka planda küçük bir izleyici kurar (menü çubuğunda ekran simgesi):
- **Ekran kablosu takılınca** ayarlar kendiliğinden yapılır.
- **Ekran bağlıyken Zoom toplantısı başlayınca** hoparlör "Sistemle aynı" yapılır.
- Menü çubuğundaki simgeden: *Şimdi çalıştır*, *Kablo takılınca otomatik çalış* (aç/kapat), *Kayıtları göster*.
- Tüm Mac'lerde uzaktan kapatmak için `sunucu/ayarlar.json` → `"otomatikIzleme": false`.

## Otomatik derleme
`kaynak/main.swift` GitHub'a yüklendiğinde GitHub Actions uygulamayı derler ve `sunucu/` klasörünü günceller
(`.github/workflows/paketle.yml`). Mac'te Paketle.command çalıştırmaya gerek yoktur.
