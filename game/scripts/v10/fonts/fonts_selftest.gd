class_name V10FontsSelftest
extends RefCounted

# --fonts_selftest=1 (spec D2): headless, no save touched.
#   every registry file loads and has OFL.txt beside it; Cyrillic + «»—…№₽ through the chain 100 %,
#   own file ≥ 98 %; the longest titles at 44 px fit 600 px in every skin font or fit_title rescues
#   them; deco off -> Playfair; < 24 px -> Nunito; every SSR goddess + yue/nova has a title font;
#   credits rows carry a copyright line; asset budget ≤ 1 MB.

const F: = preload("res://scripts/v10/fonts/fonts.gd")

const CYR: = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"
const PUNCT: = "«»—…№₽0123456789!?.,:"
const LONG_TITLES: = ["Карточка игрока", "Шансы и правила", "Мастерство наряда", "Победа!", "Весна пришла!"]
const SKINS_REQUIRED: = ["zlata", "minamo", "kira", "vesper", "sigrid", "yue", "nova"]
const BUDGET: = 1024 * 1024

static var ok: = 0
static var bad: = 0


static func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		printerr("FONTS FAIL: " + what)


static func run() -> int:
	ok = 0
	bad = 0
	var deco_was: bool = F.deco
	F.deco = true
	for id in F.FAMILIES:
		var d: Dictionary = F.FAMILIES[id]
		check(F.file(d.file) != null, id + " loads " + str(d.file))
		if d.has("lat"):
			check(F.file(d.lat) != null, id + " loads " + str(d.lat))
		check(FileAccess.file_exists(d.licence), id + " licence " + str(d.licence))
		if str(d.file).begins_with(F.DIR):
			check(str(d.licence) == str(d.file).get_base_dir().path_join("OFL.txt"), id + " OFL.txt beside the font")
		check(F.copyright(id).begins_with("Copyright"), id + " copyright line")
		var full: = F.coverage(id, CYR + PUNCT, true)
		check(is_equal_approx(full, 1.0), "%s chain covers Cyrillic+punct (%.3f)" % [id, full])
		if id != "sym":
			var own: = F.coverage(id, CYR + PUNCT)
			check(own >= 0.98, "%s own file ≥98%% (%.3f)" % [id, own])
			check(is_equal_approx(F.coverage(id, CYR), 1.0), id + " own file has every Cyrillic letter")
		var fv: = F.font(id)
		check(fv != null and fv.fallbacks.size() >= 1, id + " has a fallback chain")
		check(F.font(id) == fv, id + " is cached")
	for s in SKINS_REQUIRED:
		check(F.SKIN_FONTS.has(s), "skin font for " + s)
		var tid: String = F.SKIN_FONTS.get(s, {}).get("title", "")
		check(F.has(tid) and F.FAMILIES[tid].role == "display", s + " title id is a display face")
		check(F.skin_id(s, "title", 44) == tid, s + " skin_id(title, 44)")
		check(F.skin_id(s, "title", 20) == "ui_body", s + " < 24 px -> Nunito")
		for t in LONG_TITLES:
			var r: Dictionary = F.fit_title(t, s, 44, 600.0)
			var w: = F.width(r.font, t, r.size)
			check(w <= 600.0, "%s «%s» fits 600 px (%.0f at %d px, %s)" % [s, t, w, r.size, r.id])
			check(r.size >= F.FIT_MIN or r.id == "ui_display", "%s «%s» stays ≥%d px or falls back" % [s, t, F.FIT_MIN])
			if t == LONG_TITLES[0]:
				print("  fit %-7s «%s» -> %s %d px, %.0f px wide" % [s, t, r.id, r.size, w])
	check(F.skin_id("", "title", 44) == "ui_display", "no skin -> Playfair")
	check(F.skin_id("mc", "title", 44) == "ui_display", "A goddess -> Playfair")
	F.deco = false
	for s in SKINS_REQUIRED:
		check(F.skin_id(s, "title", 44) == "ui_display", s + " deco off -> Playfair")
		check(F.skin_id(s, "text", 30) == "ui_body", s + " deco off text -> Nunito")
	F.deco = true
	var rows: = F.credits()
	check(rows.size() >= 16, "credits rows (%d)" % rows.size())
	var total: = 0
	var seen: = {}
	for id in F.FAMILIES:
		var p: String = F.FAMILIES[id].file
		if p.begins_with(F.DIR) and not seen.has(p) and FileAccess.file_exists(p):
			seen[p] = true
			var fa: = FileAccess.open(p, FileAccess.READ)
			if fa:
				total += fa.get_length()
	if seen.size() > 0:
		check(total <= BUDGET, "font budget %d ≤ %d bytes" % [total, BUDGET])
	F.deco = deco_was
	print("FONTS SELFTEST: %d ok, %d failed (fonts %d bytes)" % [ok, bad, total])
	return bad
