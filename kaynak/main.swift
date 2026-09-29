// EkranAyari — Harici ekran (monitör / akıllı tahta) için tek tıkla ayar
// Taşınabilir: kurulum gerektirmez. Her açılışta sunucudan ayar/betik/sürüm günceller.
//
// Adımlar (mümkün olanlar yapılır, olmayanlar hata vermeden atlanır):
//   1. Harici ekrandaki yansıtmayı durdur
//   2. Harici ekranın yenileme hızını hedef Hz'e (varsayılan 30) ayarla
//   3. Harici ekranı "Yerleşik Retina Ekranı yansıt" yap
//   4. Harici ekranın ses aygıtını varsayılan ses çıkışı yap
//   5. Zoom toplantısı açıksa hoparlörü "Sistemle aynı / Same as System" yap

import AppKit
import CoreAudio
import CoreGraphics
import Foundation

// MARK: - Yollar ve günlük

let fm = FileManager.default
let destek: URL = {
    let u = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/EkranAyari")
    try? fm.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}()
let logURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/EkranAyari.log")
var ozet: [String] = []

let logKilidi = NSLock()
func log(_ s: String) {
    logKilidi.lock(); defer { logKilidi.unlock() }
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let line = "[\(df.string(from: Date()))] \(s)\n"
    print(line, terminator: "")
    guard let data = line.data(using: .utf8) else { return }
    var hedefler = [logURL]
    // Geliştirme Mac'inde günlüğü proje klasörüne de yaz
    let pk = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/EkranAyariProje")
    if fm.fileExists(atPath: pk.appendingPathComponent("kaynak").path) {
        hedefler.append(pk.appendingPathComponent("EkranAyari.log"))
    }
    for u in hedefler {
        if let h = try? FileHandle(forWritingTo: u) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: u)
        }
    }
}

func bekle(_ sn: Double) {
    RunLoop.current.run(until: Date().addingTimeInterval(sn))
}

/// Koşul sağlanana kadar (en fazla `maks` sn) 0,1 sn aralıkla bekler
@discardableResult
func bekleKadar(_ maks: Double, _ kosul: () -> Bool) -> Bool {
    let bitis = Date().addingTimeInterval(maks)
    while Date() < bitis {
        if kosul() { return true }
        bekle(0.1)
    }
    return kosul()
}

var bekciKimligi = UUID()
/// Bekçi: ne olursa olsun program en geç bu süre sonunda kapanır
func bekciKur(_ sn: Double) {
    let kimlik = UUID()
    bekciKimligi = kimlik
    DispatchQueue.global().asyncAfter(deadline: .now() + sn) {
        guard bekciKimligi == kimlik else { return }
        log("Bekçi: \(Int(sn)) sn doldu, program kapatılıyor")
        exit(0)
    }
}

// MARK: - Ayarlar (sunucudan gelir, yoksa varsayılan)

var hedefHz: Double = 30
var adimYansitmaDurdur = true
var adimHz = true
var adimYerlesikYansit = true
var adimSes = true
var adimZoom = true
var bitisSesi = "Glass"   // "" = ses yok
var dockaSabitlensin = true

func ayarlariUygula(_ j: [String: Any]) {
    if let v = j["hedefHz"] as? Double { hedefHz = v }
    if let v = j["yansitmayiDurdur"] as? Bool { adimYansitmaDurdur = v }
    if let v = j["hzAyarla"] as? Bool { adimHz = v }
    if let v = j["yerlesikEkraniYansit"] as? Bool { adimYerlesikYansit = v }
    if let v = j["sesAyarla"] as? Bool { adimSes = v }
    if let v = j["zoomAyarla"] as? Bool { adimZoom = v }
    if let v = j["bitisSesi"] as? String { bitisSesi = v }
    if let v = j["dockaSabitle"] as? Bool { dockaSabitlensin = v }
    // Sunucu taşındığında: yeni adres buraya yazılır, program bir dahaki açılışta oradan okur
    if let v = j["yeniSunucu"] as? String, !v.isEmpty {
        try? v.write(to: destek.appendingPathComponent("sunucu.txt"), atomically: true, encoding: .utf8)
        log("Sunucu adresi güncellendi: \(v)")
    }
}

// MARK: - Uzaktan güncelleme

func sunucuAdresi() -> String? {
    let oku: (URL) -> String? = { u in
        (try? String(contentsOf: u, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let s = oku(destek.appendingPathComponent("sunucu.txt")), !s.isEmpty { return s }
    if let r = Bundle.main.url(forResource: "sunucu", withExtension: "txt"), let s = oku(r), !s.isEmpty { return s }
    return nil
}

func indir(_ adres: String, zamanAsimi: Double = 5) -> Data? {
    guard let url = URL(string: adres) else { return nil }
    var istek = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: zamanAsimi)
    istek.setValue("EkranAyari", forHTTPHeaderField: "User-Agent")
    let sem = DispatchSemaphore(value: 0)
    var sonuc: Data?
    URLSession.shared.dataTask(with: istek) { d, r, _ in
        if let h = r as? HTTPURLResponse, h.statusCode == 200 { sonuc = d }
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: .now() + zamanAsimi + 1)
    return sonuc
}

func birlestir(_ taban: String, _ ad: String) -> String {
    taban.hasSuffix("/") ? taban + ad : taban + "/" + ad
}

func kendiSurumum() -> Int {
    Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
}

func kayitliAyarlariUygula() {
    if let d = try? Data(contentsOf: destek.appendingPathComponent("ayarlar.json")),
       let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
        ayarlariUygula(j)
    }
}

/// Arka planda çalışır: sunucudan ayarları, Zoom betiğini ve (gerekirse) yeni uygulamayı alır.
/// Yenilikler bir sonraki açılışta geçerli olur; o anki işi hiç geciktirmez.
func guncelle() {
    guard let taban = sunucuAdresi() else { log("Güncelleme: sunucu adresi tanımlı değil — atlandı"); return }
    guard let sd = indir(birlestir(taban, "surum.json"), zamanAsimi: 3),
          let surum = try? JSONSerialization.jsonObject(with: sd) as? [String: Any] else {
        log("Güncelleme: sunucuya ulaşılamadı (\(taban)) — kayıtlı ayarlar kullanıldı")
        return
    }
    if let d = indir(birlestir(taban, "ayarlar.json"), zamanAsimi: 3),
       (try? JSONSerialization.jsonObject(with: d)) != nil {
        try? d.write(to: destek.appendingPathComponent("ayarlar.json"), options: .atomic)
    }
    if let d = indir(birlestir(taban, "zoom.applescript"), zamanAsimi: 3),
       let s = String(data: d, encoding: .utf8), s.contains("on run") {
        try? d.write(to: destek.appendingPathComponent("zoom.applescript"), options: .atomic)
    }

    let uzak = surum["uygulamaSurum"] as? Int ?? 0
    let benim = kendiSurumum()
    guard uzak > benim else { log("Güncelleme: ayarlar alındı, uygulama güncel (sürüm \(benim))"); return }

    log("Güncelleme: yeni sürüm \(uzak) bulundu (mevcut \(benim)), indiriliyor...")
    let uygulama = Bundle.main.bundleURL
    guard uygulama.pathExtension == "app",
          fm.isWritableFile(atPath: uygulama.deletingLastPathComponent().path),
          !uygulama.path.contains("/AppTranslocation/") else {
        log("Güncelleme: uygulamanın bulunduğu klasöre yazılamıyor (\(uygulama.path)) — atlandı")
        return
    }
    guard let zip = indir(birlestir(taban, surum["uygulamaDosyasi"] as? String ?? "EkranAyari.zip"), zamanAsimi: 30) else {
        log("Güncelleme: uygulama indirilemedi"); return
    }
    let gecici = fm.temporaryDirectory.appendingPathComponent("EkranAyari-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: gecici) }
    try? fm.createDirectory(at: gecici, withIntermediateDirectories: true)
    let zipYolu = gecici.appendingPathComponent("yeni.zip")
    do { try zip.write(to: zipYolu) } catch { log("Güncelleme: yazılamadı"); return }
    let ac = Process()
    ac.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ac.arguments = ["-x", "-k", zipYolu.path, gecici.path]
    do { try ac.run(); ac.waitUntilExit() } catch { log("Güncelleme: zip açılamadı"); return }
    let yeni = gecici.appendingPathComponent("EkranAyari.app")
    guard ac.terminationStatus == 0,
          fm.fileExists(atPath: yeni.appendingPathComponent("Contents/MacOS/EkranAyari").path) else {
        log("Güncelleme: zip içinde geçerli EkranAyari.app yok"); return
    }
    do {
        _ = try fm.replaceItemAt(uygulama, withItemAt: yeni)
        log("Güncelleme: ✓ sürüm \(uzak) kuruldu — bir sonraki açılışta geçerli")
    } catch {
        log("Güncelleme: uygulama değiştirilemedi: \(error.localizedDescription)")
    }
}

// MARK: - Ekranlar

func cevrimiciEkranlar() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
    return Array(ids.prefix(Int(count)))
}

func yerlesikEkran() -> CGDirectDisplayID? {
    cevrimiciEkranlar().first { CGDisplayIsBuiltin($0) != 0 }
}

func hariciEkranlar() -> [CGDirectDisplayID] {
    cevrimiciEkranlar().filter { CGDisplayIsBuiltin($0) == 0 }
}

func ekranAdi(_ id: CGDirectDisplayID) -> String? {
    for s in NSScreen.screens {
        if let n = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           n.uint32Value == id {
            return s.localizedName
        }
    }
    return nil
}

@discardableResult
func ekranYapilandir(_ aciklama: String, _ govde: (CGDisplayConfigRef) -> CGError) -> Bool {
    var cfg: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&cfg) == .success, let c = cfg else {
        log("  ✗ \(aciklama): yapılandırma başlatılamadı"); return false
    }
    let e = govde(c)
    if e != .success {
        CGCancelDisplayConfiguration(c)
        log("  ✗ \(aciklama): hata \(e.rawValue)"); return false
    }
    let r = CGCompleteDisplayConfiguration(c, .permanently)
    if r != .success { log("  ✗ \(aciklama): uygulanamadı (\(r.rawValue))"); return false }
    return true
}

func yansitmayiDurdur() {
    let yansitanlar = cevrimiciEkranlar().filter { CGDisplayMirrorsDisplay($0) != kCGNullDirectDisplay }
    if yansitanlar.isEmpty { log("1) Yansıtma zaten kapalı — atlandı"); return }
    let ok = ekranYapilandir("Yansıtmayı durdur") { c in
        for d in yansitanlar {
            let e = CGConfigureDisplayMirrorOfDisplay(c, d, kCGNullDirectDisplay)
            if e != .success { return e }
        }
        return .success
    }
    if ok {
        log("1) ✓ Yansıtma durduruldu"); ozet.append("Yansıtma durduruldu")
        bekleKadar(3) { cevrimiciEkranlar().allSatisfy { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay } }
        bekle(0.3)
    }
}

func hzAyarla(_ ext: CGDirectDisplayID) -> Bool {
    let ad = ekranAdi(ext) ?? "Ekran \(ext)"
    guard let mevcut = CGDisplayCopyDisplayMode(ext) else {
        log("2) \(ad): mevcut mod okunamadı — atlandı"); return false
    }
    if abs(mevcut.refreshRate - hedefHz) < 1 {
        log("2) \(ad): zaten \(Int(mevcut.refreshRate.rounded())) Hz — atlandı"); return true
    }
    let secenek = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    guard let modlar = CGDisplayCopyAllDisplayModes(ext, secenek) as? [CGDisplayMode] else {
        log("2) \(ad): mod listesi alınamadı — atlandı"); return false
    }
    let aday = modlar.filter { abs($0.refreshRate - hedefHz) < 1 && $0.isUsableForDesktopGUI() }
    if aday.isEmpty {
        log("2) \(ad): \(Int(hedefHz)) Hz destekli mod yok — atlandı"); return false
    }
    // Önce mevcut çözünürlükle aynı olanı, yoksa en yüksek çözünürlüğü seç
    let ayni = aday.first {
        $0.pixelWidth == mevcut.pixelWidth && $0.pixelHeight == mevcut.pixelHeight &&
        $0.width == mevcut.width && $0.height == mevcut.height
    } ?? aday.first {
        $0.pixelWidth == mevcut.pixelWidth && $0.pixelHeight == mevcut.pixelHeight
    }
    let hedef = ayni ?? aday.max { $0.pixelWidth * $0.pixelHeight < $1.pixelWidth * $1.pixelHeight }!
    let ok = ekranYapilandir("\(Int(hedefHz)) Hz") { c in CGConfigureDisplayWithDisplayMode(c, ext, hedef, nil) }
    if ok {
        log("2) ✓ \(ad): \(hedef.pixelWidth)x\(hedef.pixelHeight) @ \(String(format: "%.2f", hedef.refreshRate)) Hz")
        bekleKadar(3) { abs((CGDisplayCopyDisplayMode(ext)?.refreshRate ?? 0) - hedefHz) < 1 }
        bekle(0.3)
    }
    return ok
}

func yerlesigiYansit(_ ext: CGDirectDisplayID, _ builtin: CGDirectDisplayID) {
    let ad = ekranAdi(ext) ?? "Ekran \(ext)"
    if CGDisplayMirrorsDisplay(ext) == builtin {
        log("3) \(ad): zaten yerleşik ekranı yansıtıyor — atlandı"); return
    }
    let ok = ekranYapilandir("Yansıt") { c in CGConfigureDisplayMirrorOfDisplay(c, ext, builtin) }
    if ok {
        log("3) ✓ \(ad): Yerleşik Retina Ekranı yansıtılıyor")
        ozet.append("Yerleşik ekran yansıtılıyor")
        bekleKadar(3) { CGDisplayMirrorsDisplay(ext) == builtin }
        bekle(0.3)
    }
}

// MARK: - Ses (CoreAudio)

let sistem = AudioObjectID(kAudioObjectSystemObject)

func adres(_ sel: AudioObjectPropertySelector,
           _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: 0)
}

func sesAygitlari() -> [AudioDeviceID] {
    var a = adres(kAudioHardwarePropertyDevices)
    var boyut: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(sistem, &a, 0, nil, &boyut) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(boyut) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(sistem, &a, 0, nil, &boyut, &ids) == noErr else { return [] }
    return ids
}

func cikisVarMi(_ id: AudioDeviceID) -> Bool {
    var a = adres(kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput)
    var boyut: UInt32 = 0
    return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &boyut) == noErr && boyut > 0
}

func sesAdi(_ id: AudioDeviceID) -> String {
    var a = adres(kAudioObjectPropertyName)
    var ad: Unmanaged<CFString>?
    var boyut = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &a, 0, nil, &boyut, &ad) == noErr, let s = ad else { return "?" }
    return s.takeRetainedValue() as String
}

func tasimaTuru(_ id: AudioDeviceID) -> UInt32 {
    var a = adres(kAudioDevicePropertyTransportType)
    var t: UInt32 = 0
    var boyut = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(id, &a, 0, nil, &boyut, &t)
    return t
}

func varsayilanCikisYap(_ id: AudioDeviceID) -> Bool {
    var dev = id
    let boyut = UInt32(MemoryLayout<AudioDeviceID>.size)
    var a1 = adres(kAudioHardwarePropertyDefaultOutputDevice)
    let r1 = AudioObjectSetPropertyData(sistem, &a1, 0, nil, boyut, &dev)
    var a2 = adres(kAudioHardwarePropertyDefaultSystemOutputDevice)   // uyarı sesleri
    _ = AudioObjectSetPropertyData(sistem, &a2, 0, nil, boyut, &dev)
    return r1 == noErr
}

func hariciEkranSesiniSec(ekranAdlari: [String]) {
    let cikislar = sesAygitlari().filter(cikisVarMi)
    let hdmiDP: Set<UInt32> = [kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort]
    // 1. öncelik: HDMI / DisplayPort ses aygıtı  2. öncelik: adı ekran adıyla eşleşen aygıt (ör. USB)
    let secilen = cikislar.first { hdmiDP.contains(tasimaTuru($0)) } ?? cikislar.first { d in
        let n = sesAdi(d).lowercased()
        return ekranAdlari.contains { e in
            let e2 = e.lowercased()
            return !e2.isEmpty && (n.contains(e2) || e2.contains(n))
        }
    }
    guard let d = secilen else {
        log("4) Harici ekrana ait ses aygıtı bulunamadı — atlandı"); return
    }
    if varsayilanCikisYap(d) {
        log("4) ✓ Ses çıkışı: \(sesAdi(d))"); ozet.append("Ses: \(sesAdi(d))")
    } else {
        log("4) ✗ Ses çıkışı ayarlanamadı: \(sesAdi(d))")
    }
}


// Sunucuya ulaşılamazsa kullanılan gömülü Zoom betiği
let gomuluZoomBetigi = """
-- Zoom toplantı penceresi › "Audio options" (mikrofon yanındaki ok) › "Sistemle aynı"
on oz(el, k)
	tell application "System Events"
		try
			set v to value of attribute k of el
			if v is missing value then return ""
			return v as text
		on error
			return ""
		end try
	end tell
end oz

on esles(t)
	return (t contains "Same as System") or (t contains "Sistem ile aynı") or (t contains "Sistemle aynı") or (t contains "Sistemle Aynı") or (t contains "sistemle aynı")
end esles

on metin(el)
	return my oz(el, "AXTitle") & "|" & my oz(el, "AXDescription") & "|" & my oz(el, "AXValue")
end metin


-- Öğenin ortasına gerçek fare tıklaması (CGEvent, JXA ile).
-- Tıklama anında fiziksel fare imleçten ayrılır, sonra imleç eski yerine döner:
-- kullanıcı fareyi oynatsa bile tıklama doğru yere gider.
on ortayaTikla(el)
	tell application "System Events"
		set p to position of el
		set b to size of el
	end tell
	set x to (item 1 of p) + ((item 1 of b) div 2)
	set y to (item 2 of p) + ((item 2 of b) div 2)
	set js to "ObjC.import('CoreGraphics'); var p={x:" & x & ",y:" & y & "}; " & ¬
		"var eski=$.CGEventGetLocation($.CGEventCreate(null)); " & ¬
		"try { $.CGAssociateMouseAndMouseCursorPosition(0); $.CGWarpMouseCursorPosition(p); delay(0.03); " & ¬
		"$.CGEventPost(0,$.CGEventCreateMouseEvent(null,5,p,0)); delay(0.03); " & ¬
		"$.CGEventPost(0,$.CGEventCreateMouseEvent(null,1,p,0)); delay(0.06); " & ¬
		"$.CGEventPost(0,$.CGEventCreateMouseEvent(null,2,p,0)); delay(0.05); " & ¬
		"$.CGWarpMouseCursorPosition(eski); } finally { $.CGAssociateMouseAndMouseCursorPosition(1); }"
	do shell script "/usr/bin/osascript -l JavaScript -e " & quoted form of js
	return "tik@" & x & "," & y
end ortayaTikla

on okuBul()
	tell application "System Events"
		tell process "zoom.us"
			set tp to missing value
			repeat with w in windows
				set wn to ""
				try
					set wn to (name of w) as text
				end try
				if wn is "Zoom Toplantısı" or wn is "Zoom Meeting" then set tp to window wn
			end repeat
			if tp is missing value then return missing value
			set ec to entire contents of tp
			repeat with el in ec
				try
					if (role of el) is "AXButton" then
						set d to my oz(el, "AXDescription")
						if d is "Audio options" or d starts with "Ses seçenek" or d starts with "Audio option" then return contents of el
					end if
				end try
			end repeat
		end tell
	end tell
	return missing value
end okuBul

-- Açık menü penceresindeki "Sistemle aynı" adaylarını döndürür
on adaylar()
	set liste to {}
	tell application "System Events"
		tell process "zoom.us"
			repeat with w in windows
				set wn to ""
				try
					set wn to (name of w) as text
				end try
				if wn is not in {"Zoom Toplantısı", "Zoom Meeting", "Zoom Workplace", "Ayarlar", "Settings"} then
					try
						set ec to entire contents of w
						repeat with el in ec
							try
								if my esles(my metin(el)) then set end of liste to (contents of el)
							end try
						end repeat
					end try
				end if
			end repeat
		end tell
	end tell
	return liste
end adaylar

-- Tek deneme: menüyü aç, hoparlör satırını seç, menünün kapandığını doğrula
on dene()
	set iz to ""
	tell application "System Events" to set frontmost of process "zoom.us" to true
	delay 0.15
	set ok to my okuBul()
	if ok is missing value then return "ok-yok"
	tell application "System Events" to click ok
	-- menü açılana kadar kısa aralıklarla bekle (en fazla 2 sn)
	set a to {}
	repeat 20 times
		delay 0.1
		set a to my adaylar()
		if (count of a) > 0 then exit repeat
	end repeat
	if (count of a) is 0 then
		tell application "System Events" to key code 53
		return "secenek-yok"
	end if
	set secilen to missing value
	tell application "System Events"
		repeat with el in a
			set r to ""
			try
				set r to role of el
			end try
			set t to my metin(el)
			if not (t contains "Mikrofon" or t contains "Microphone" or t contains "mikrofon") then
				if r is not "AXStaticText" then set secilen to (contents of el)
				if secilen is missing value then set secilen to (contents of el)
			end if
		end repeat
	end tell
	if secilen is missing value then
		tell application "System Events" to key code 53
		return "hoparlor-adayi-yok"
	end if
	try
		set iz to my ortayaTikla(secilen)
	on error e
		set iz to "tikHata=" & e
	end try
	-- menü kapanana kadar bekle (en fazla 1,5 sn)
	repeat 15 times
		delay 0.1
		if (count of my adaylar()) is 0 then exit repeat
	end repeat
	if (count of my adaylar()) > 0 then
		tell application "System Events" to key code 53
		delay 0.4
		return iz & " menu-hala-acik"
	end if
	return iz & " TAMAM"
end dene

on run
	tell application "System Events"
		if not (exists process "zoom.us") then return "SONUC=zoom-kapali"
	end tell
	set gecmis to ""
	repeat with i from 1 to 3
		set r to my dene()
		set gecmis to gecmis & "deneme" & i & "=" & r & " ; "
		if r ends with "TAMAM" then return gecmis & "SONUC=tamam"
		if r is "ok-yok" then return gecmis & "SONUC=toplanti-yok"
		delay 0.3
	end repeat
	return gecmis & "SONUC=secilemedi"
end run
"""

// MARK: - Zoom

func zoomAcikMi() -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    p.arguments = ["-x", "zoom.us"]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run(); p.waitUntilExit() } catch { return false }
    return p.terminationStatus == 0
}

let projeKlasoru = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/EkranAyariProje")

func zoomHoparlorunuAyarla() {
    guard zoomAcikMi() else { log("5) Zoom açık değil — atlandı"); return }
    // Geliştirme Mac'inde proje klasöründeki betik, diğerlerinde sunucudan indirilen betik
    let yerel = projeKlasoru.appendingPathComponent("sunucu/zoom.applescript")
    let indirilen = fm.fileExists(atPath: yerel.path) ? yerel : destek.appendingPathComponent("zoom.applescript")
    let kaynak = (try? String(contentsOf: indirilen, encoding: .utf8)) ?? gomuluZoomBetigi
    var hata: NSDictionary?
    guard let betik = NSAppleScript(source: kaynak) else { log("5) ✗ Zoom betiği derlenemedi"); return }
    let sonuc = betik.executeAndReturnError(&hata).stringValue ?? ""
    if let h = hata {
        log("5) ✗ Zoom betik hatası: \(h[NSAppleScript.errorMessage] ?? h) — Erişilebilirlik iznini kontrol edin")
        return
    }
    if sonuc.hasSuffix("SONUC=tamam") {
        log("5) ✓ Zoom hoparlörü: Sistemle aynı"); ozet.append("Zoom: Sistemle aynı")
    } else {
        log("5) Zoom adımı atlandı: \(sonuc)")
    }
}

// MARK: - Dock'a sabitleme

func calistir(_ yol: String, _ arg: [String], girdi: Data? = nil) -> (Int32, Data) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: yol)
    p.arguments = arg
    let cikis = Pipe(); p.standardOutput = cikis
    p.standardError = FileHandle.nullDevice
    let giris = Pipe()
    if girdi != nil { p.standardInput = giris }
    do { try p.run() } catch { return (-1, Data()) }
    if let g = girdi { giris.fileHandleForWriting.write(g); try? giris.fileHandleForWriting.close() }
    let veri = cikis.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, veri)
}

/// Uygulamayı Dock'a sabitler; kullanıcı kaldırmışsa tekrar ekler. Zaten varsa Dock'a dokunmaz.
func docaSabitle() {
    let uygulama = Bundle.main.bundleURL
    guard uygulama.pathExtension == "app", !uygulama.path.contains("/AppTranslocation/") else {
        log("Dock: geçici konumdan çalışıyor — sabitleme atlandı"); return
    }
    let bid = Bundle.main.bundleIdentifier ?? "tr.k12.sevizmir.ekranayari"
    let adres = uygulama.absoluteString.hasSuffix("/") ? uygulama.absoluteString : uygulama.absoluteString + "/"

    let (d1, veri) = calistir("/usr/bin/defaults", ["export", "com.apple.dock", "-"])
    guard d1 == 0,
          var dock = (try? PropertyListSerialization.propertyList(from: veri, options: .mutableContainersAndLeaves, format: nil)) as? [String: Any] else {
        log("Dock: ayarlar okunamadı — atlandı"); return
    }
    var ogeler = dock["persistent-apps"] as? [[String: Any]] ?? []
    func url(_ o: [String: Any]) -> String {
        ((o["tile-data"] as? [String: Any])?["file-data"] as? [String: Any])?["_CFURLString"] as? String ?? ""
    }
    func kimlik(_ o: [String: Any]) -> String {
        (o["tile-data"] as? [String: Any])?["bundle-identifier"] as? String ?? ""
    }
    if ogeler.contains(where: { url($0) == adres }) { return }   // zaten sabit

    // Eski konumdaki kopyaların kayıtlarını temizle, yenisini ekle
    ogeler.removeAll { kimlik($0) == bid || url($0).hasSuffix("/EkranAyari.app/") }
    ogeler.append([
        "tile-type": "file-tile",
        "tile-data": [
            "bundle-identifier": bid,
            "file-label": "Ekran Ayarı",
            "file-data": ["_CFURLString": adres, "_CFURLStringType": 15] as [String: Any]
        ] as [String: Any]
    ])
    dock["persistent-apps"] = ogeler
    guard let yeni = try? PropertyListSerialization.data(fromPropertyList: dock, format: .xml, options: 0) else {
        log("Dock: yeni ayar hazırlanamadı — atlandı"); return
    }
    let (d2, _) = calistir("/usr/bin/defaults", ["import", "com.apple.dock", "-"], girdi: yeni)
    guard d2 == 0 else { log("Dock: ayar yazılamadı — atlandı"); return }
    _ = calistir("/usr/bin/killall", ["Dock"])
    log("Dock: ✓ uygulama Dock'a sabitlendi")
}

// MARK: - Bildirim

func bildir(_ metin: String) {
    let temiz = metin.replacingOccurrences(of: "\"", with: "'")
    var h: NSDictionary?
    NSAppleScript(source: "display notification \"\(temiz)\" with title \"Ekran Ayarı\"")?
        .executeAndReturnError(&h)
}

// MARK: - İlk açılış: izinler

func uyari(_ baslik: String, _ metin: String, _ dugmeler: [String]) -> Int {
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = baslik
    a.informativeText = metin
    for d in dugmeler { a.addButton(withTitle: d) }
    return a.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
}

func erisilebilirlikVarMi() -> Bool { AXIsProcessTrusted() }

func izinleriHazirla() {
    // Otomasyon (System Events) izni — soru penceresini hemen çıkarır
    var h: NSDictionary?
    _ = NSAppleScript(source: "tell application \"System Events\" to get name of first process")?
        .executeAndReturnError(&h)
    if h != nil { log("İzin: System Events otomasyon izni verilmedi") }

    guard !erisilebilirlikVarMi() else { return }
    log("İzin: Erişilebilirlik izni yok — ilk kurulum penceresi gösteriliyor")

    let secim = uyari("Ekran Ayarı — ilk kurulum",
        "Zoom ses ayarını yapabilmek için bir kez Erişilebilirlik izni gerekiyor.\n\n" +
        "\"İzin Ver\"e bastığınızda Sistem Ayarları açılacak. Listede \"EkranAyari\"nın yanındaki anahtarı açmanız yeterli " +
        "(istenirse parolanızı girin).\n\nİzni verince program kendiliğinden devam eder.",
        ["İzin Ver", "Şimdilik Geç"])
    guard secim == 0 else { log("İzin: kullanıcı erteledi"); return }
    bekciKur(240)

    // Eski/bozuk kaydı temizle, uygulamayı listeye ekle, ayar sayfasını aç
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
    t.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "tr.k12.sevizmir.ekranayari"]
    t.standardOutput = FileHandle.nullDevice; t.standardError = FileHandle.nullDevice
    try? t.run(); t.waitUntilExit()
    let secenek = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(secenek)
    bekle(0.5)
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

    let bitis = Date().addingTimeInterval(180)
    while Date() < bitis && !erisilebilirlikVarMi() { bekle(1) }
    if erisilebilirlikVarMi() {
        log("İzin: ✓ Erişilebilirlik verildi")
        _ = uyari("Ekran Ayarı", "Tüm izinler tamam. Program şimdi çalışacak.", ["Tamam"])
    } else {
        log("İzin: Erişilebilirlik 3 dakika içinde verilmedi — Zoom adımı atlanabilir")
    }
    bekciKur(90)
}

// MARK: - Ana akış

_ = NSApplication.shared

// Aynı anda tek kopya: önceki takılı kalmış kopyaları kapat
if let bid = Bundle.main.bundleIdentifier {
    let benim = ProcessInfo.processInfo.processIdentifier
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bid)
    where app.processIdentifier != benim {
        app.forceTerminate()
    }
}

bekciKur(90)
log("===== EkranAyari sürüm \(kendiSurumum()) başladı (\(Bundle.main.bundlePath)) =====")

kayitliAyarlariUygula()
let guncellemeBitti = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .utility).async { guncelle(); guncellemeBitti.signal() }
izinleriHazirla()

if hariciEkranlar().isEmpty {
    log("Harici ekran bulunamadı — ekran ve ses adımları atlandı")
} else {
    let adlar = hariciEkranlar().compactMap(ekranAdi)
    log("Harici ekran(lar): \(adlar.isEmpty ? "(adı okunamadı)" : adlar.joined(separator: ", "))")
    // Zaten istenen durumdaysa (yerleşik ekranı yansıtıyor + doğru Hz) ekranı hiç titretme
    let builtinId = yerlesikEkran()
    let zatenHazir = hariciEkranlar().allSatisfy { ext in
        let yansitma = !adimYerlesikYansit || (builtinId != nil && CGDisplayMirrorsDisplay(ext) == builtinId!)
        let hz = !adimHz || abs((CGDisplayCopyDisplayMode(ext)?.refreshRate ?? 0) - hedefHz) < 1
        return yansitma && hz
    }
    if zatenHazir {
        log("1-3) Ekran zaten istenen durumda — atlandı")
    } else {
    if adimYansitmaDurdur { yansitmayiDurdur() }

    if adimHz {
        for ext in hariciEkranlar() where hzAyarla(ext) { ozet.append("\(Int(hedefHz)) Hz") }
    }
    if adimYerlesikYansit {
        if let builtin = yerlesikEkran() {
            for ext in hariciEkranlar() { yerlesigiYansit(ext, builtin) }
            if adimHz {
                for ext in hariciEkranlar() {
                    if let m = CGDisplayCopyDisplayMode(ext), abs(m.refreshRate - hedefHz) >= 1 {
                        log("   Yansıtma sonrası Hz \(Int(m.refreshRate.rounded())) oldu, tekrar deneniyor")
                        _ = hzAyarla(ext)
                    }
                }
            }
        } else {
            log("3) Yerleşik ekran bulunamadı (kapak kapalı olabilir) — atlandı")
        }
    }
    }
    if adimSes { hariciEkranSesiniSec(ekranAdlari: adlar) }
}

if adimZoom { zoomHoparlorunuAyarla() }

let mesaj = ozet.isEmpty ? "Yapılacak bir değişiklik bulunamadı" : ozet.joined(separator: " • ")
log("Bitti: \(mesaj)")
bildir(mesaj)
if !bitisSesi.isEmpty, let ses = NSSound(named: NSSound.Name(bitisSesi)) {
    ses.play()
    bekle(max(0.8, ses.duration))
}
if dockaSabitlensin { docaSabitle() }
// Arka plandaki güncelleme bitmediyse kısa süre bekle (işler zaten tamamlandı)
_ = guncellemeBitti.wait(timeout: .now() + 35)
exit(0)
