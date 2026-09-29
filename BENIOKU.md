# Ekran Ayarı — taşınabilir sürüm

## Klasördekiler
- **Paketle.command**: Programı derler, sürüm numarasını bir artırır, `dagitim/` ve `sunucu/` klasörlerine koyar.
- **Sunucu.command**: Bu Mac'i güncelleme sunucusu yapar (8080 portu).
- **sunucu/**: Güncelleme dosyaları. Buradaki dosyaları değiştirmek, programı kullanan bütün Mac'leri günceller.
  - `ayarlar.json`: hedef Hz, hangi adımların çalışacağı, sunucu taşınınca kullanılacak yeni adres.
  - `zoom.applescript`: Zoom adımı. Değiştirmek için yeniden derleme gerekmez.
  - `surum.json` + `EkranAyari.zip`: programın kendisi (Paketle.command üretir).
- **dagitim/EkranAyari.app**: Diğer Mac'lere kopyalanacak uygulama.
- **sunucu_adresi.txt**: Yeni derlenen uygulamanın bağlanacağı adres.

## Kullanım
Kullanmak için `EkranAyari.app`'a çift tıklamanız yeterli. Uygulama kurulum istemez, USB bellekte, Masaüstünde ya da herhangi bir klasörde çalışır.

Her açılışta programın yaptıkları:
1. Sunucudan ayarları ve Zoom betiğini alır. Sunucuya ulaşamazsa son kaydettiğini kullanır.
2. Sunucuda daha yeni bir sürüm varsa kendini günceller ve yeniden başlar.
3. Ekran, ses ve Zoom adımlarını çalıştırır.

Kayıt dosyası: `~/Library/Logs/EkranAyari.log`

## Güncelleme türleri
| Ne değişiyor | Nasıl | İzin yeniden gerekir mi? |
|---|---|---|
| Hz, adımları aç/kapat | `sunucu/ayarlar.json`'u düzenleyin | Hayır |
| Zoom adımı | `sunucu/zoom.applescript`'i değiştirin | Hayır |
| Programın kendisi | `main.swift`'i değiştirip Paketle.command'ı çalıştırın | **Evet**, Erişilebilirlik izni her Mac'te yeniden verilmeli |

## Sunucuyu taşımak
1. `sunucu/` klasörünün içeriğini yeni sunucuya (herhangi bir web sunucusu) kopyalayın.
2. Eski sunucudaki `ayarlar.json`'da `"yeniSunucu": "http://yeni-adres/klasor/"` yazın. Mac'ler bir sonraki açılışta yeni adrese geçer.
3. Yeni derlemelerin de yeni adresi kullanması için `sunucu_adresi.txt`'yi güncelleyin.

## Başka bir Mac'e ilk kurulum
1. `dagitim/EkranAyari.app`'ı kopyalayın (AirDrop, USB vb.). Uygulamalar ya da Masaüstü gibi yazılabilir bir klasöre koyun. İndirilenler klasöründen çalıştırmayın, kendini güncelleyemez.
2. İlk açılışta "açılamıyor" uyarısı çıkarsa: sağ tıklayın › **Aç**. Ya da Sistem Ayarları › Gizlilik ve Güvenlik › **Yine de Aç**.
3. Sistem Ayarları › Gizlilik ve Güvenlik › **Erişilebilirlik** › + › EkranAyari. Bu izin Zoom adımı için gerekli.
4. "Yerel ağdaki aygıtları bulmak istiyor" ve "System Events'i denetlemek istiyor" sorularına **İzin Ver** deyin.
