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
