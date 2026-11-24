class_name V10Fonts
extends RefCounted

# V10Fonts — font registry for 0.10 (docs/0.10-spec.md D2 «Шрифты SSR-богинь»).
#
#   V10Fonts.font("zlata_title")            -> FontVariation (cached, fallback chain attached)
#   V10Fonts.skin("zlata", "title", 44)      -> the partner's display font, or Playfair / Nunito
#                                              (size < TITLE_MIN, decorative fonts off, unknown skin)
#   V10Fonts.fit_title(text, "zlata", 44, 600) -> {font, size}: shrinks to FIT_MIN, then falls back to Playfair
#   V10Fonts.credits()                       -> rows for «Настройки → Шрифты и лицензии»
#
# Every font id resolves to one file in res://assets/v10/fonts/<dir>/ (OFL.txt beside it) or to the
# 0.8 subsets in res://assets/fonts/. Fallback chain for every id (spec D2):
#   own file -> playfair-cyr -> playfair-lat -> nunito-cyr -> nunito-lat -> nunito-sym (₽ № € × −)
# The 0.8 nunito/playfair subsets have no ₽, so nunito-sym (2.7 KB, variable) closes every chain.
# Prices are never set in a decorative font: callers use UI.font("body") for any price (spec D2).

const TITLE_MIN: = 24          # below this every kind falls back to Nunito 800 (same rule as UI.font_for)
const FIT_MIN: = 36            # fit_title shrinks a decorative title down to this, then switches to Playfair
const XFADE: = 0.25            # partner change: title cross-fade, seconds (used by the integrator)

const OLD: = "res://assets/fonts/"
const DIR: = "res://assets/v10/fonts/"

# id -> {name, file, wght (only for variable files), role, who, licence, rfn}
#   role: body | display | text | hand
#   rfn: OFL Reserved Font Name -> the file is shipped unmodified (no subset); see tools/build_fonts.py
const FAMILIES: = {
	# --- UI (existing 0.8 subsets, already in res://assets/fonts/) ---
	"ui_body": {"name": "Nunito", "file": OLD + "nunito-cyr.woff2", "lat": OLD + "nunito-lat.woff2", "wght": 800,
		"role": "body", "who": "", "licence": DIR + "licenses/nunito_OFL.txt", "rfn": false},
	"ui_display": {"name": "Playfair Display", "file": OLD + "playfair-cyr.woff2", "lat": OLD + "playfair-lat.woff2", "wght": 800,
		"role": "display", "who": "", "licence": DIR + "licenses/playfair_display_OFL.txt", "rfn": true},
	"ui_display_italic": {"name": "Playfair Display Italic", "file": OLD + "playfair-i-cyr.woff2", "lat": OLD + "playfair-i-lat.woff2", "wght": 700,
		"role": "display", "who": "", "licence": DIR + "licenses/playfair_display_OFL.txt", "rfn": true},
	# --- shared accents ---
	"hand": {"name": "Caveat SemiBold", "file": DIR + "caveat/caveat-600.woff2",
		"role": "hand", "who": "founders", "licence": DIR + "caveat/OFL.txt", "rfn": false},
	"palm": {"name": "Neucha", "file": DIR + "neucha/neucha.woff2",
		"role": "text", "who": "palm_reading", "licence": DIR + "neucha/OFL.txt", "rfn": false},
	# --- SSR goddesses: display (titles, ult name, «Победа!», letter signature) + text accent ---
	"zlata_title": {"name": "Ruslan Display", "file": DIR + "ruslan_display/RuslanDisplay-Regular.ttf",
		"role": "display", "who": "zlata", "licence": DIR + "ruslan_display/OFL.txt", "rfn": true},
	"zlata_text": {"name": "Kurale", "file": DIR + "kurale/kurale.woff2",
		"role": "text", "who": "zlata", "licence": DIR + "kurale/OFL.txt", "rfn": false},
	"minamo_title": {"name": "Cormorant Infant SemiBold Italic", "file": DIR + "cormorant_infant/cormorant-infant-i600.woff2",
		"role": "display", "who": "minamo", "licence": DIR + "cormorant_infant/OFL.txt", "rfn": false},
	"minamo_text": {"name": "Great Vibes", "file": DIR + "great_vibes/great-vibes.woff2",
		"role": "text", "who": "minamo", "licence": DIR + "great_vibes/OFL.txt", "rfn": false},
	"kira_title": {"name": "Russo One", "file": DIR + "russo_one/RussoOne-Regular.ttf",
		"role": "display", "who": "kira", "licence": DIR + "russo_one/OFL.txt", "rfn": true},
	"kira_text": {"name": "Exo 2 SemiBold", "file": DIR + "exo2/exo2-600.woff2",
		"role": "text", "who": "kira", "licence": DIR + "exo2/OFL.txt", "rfn": false},
	"vesper_title": {"name": "Yeseva One", "file": DIR + "yeseva_one/YesevaOne-Regular.ttf",
		"role": "display", "who": "vesper", "licence": DIR + "yeseva_one/OFL.txt", "rfn": true},
	"vesper_text": {"name": "Cormorant Garamond Medium Italic", "file": DIR + "cormorant_garamond/cormorant-garamond-i500.woff2",
		"role": "text", "who": "vesper", "licence": DIR + "cormorant_garamond/OFL.txt", "rfn": false},
	"sigrid_title": {"name": "Philosopher Bold", "file": DIR + "philosopher/philosopher-700.woff2",
		"role": "display", "who": "sigrid", "licence": DIR + "philosopher/OFL.txt", "rfn": false},
	"sigrid_text": {"name": "Jura SemiBold", "file": DIR + "jura/jura-600.woff2",
		"role": "text", "who": "sigrid", "licence": DIR + "jura/OFL.txt", "rfn": false},
	# --- S founders: display for their SSR-outfit banners / ult names (handwriting stays Caveat) ---
	"yue_title": {"name": "Tenor Sans", "file": DIR + "tenor_sans/TenorSans-Regular.ttf",
		"role": "display", "who": "yue", "licence": DIR + "tenor_sans/OFL.txt", "rfn": true},
	"nova_title": {"name": "Unbounded Bold", "file": DIR + "unbounded/unbounded-700.woff2",
		"role": "display", "who": "nova", "licence": DIR + "unbounded/OFL.txt", "rfn": false},
	# --- last link of every chain ---
	"sym": {"name": "Nunito (₽ № €)", "file": DIR + "nunito_sym/nunito-sym.woff2", "wght": 800,
		"role": "body", "who": "", "licence": DIR + "nunito_sym/OFL.txt", "rfn": false},
}

# skin (heroine id from ROSTER_20) -> role -> font id. Only these skins carry a font (spec D2 / ROSTER §1.3):
# the five SSR goddesses, plus the founders' SSR-outfit banners (yue, nova). Modes never use skin fonts.
const SKIN_FONTS: = {
	"zlata": {"title": "zlata_title", "text": "zlata_text"},
	"minamo": {"title": "minamo_title", "text": "minamo_text"},
	"kira": {"title": "kira_title", "text": "kira_text"},
	"vesper": {"title": "vesper_title", "text": "vesper_text"},
	"sigrid": {"title": "sigrid_title", "text": "sigrid_text"},
	"yue": {"title": "yue_title", "text": "hand"},
	"nova": {"title": "nova_title", "text": "hand"},
}

# Optical tweaks so every display face sits at the same visual size as Playfair 800 at one font_size:
# {scale (multiplies font_size, see px()), spacing (extra px per glyph, FontVariation.spacing_glyph),
#  space (extra px per word gap, FontVariation.spacing_space)}. Ruslan Display is unicase and wide,
# Unbounded is extended; the scripts (Cormorant, Great Vibes, Caveat) run small on the em.
const OPTICS: = {
	"zlata_title": {"scale": 0.92, "spacing": 0.0},
	"minamo_title": {"scale": 1.12, "spacing": 0.0},
	"minamo_text": {"scale": 1.25, "spacing": 0.0},
	"vesper_text": {"scale": 1.1, "spacing": 0.0},
	"nova_title": {"scale": 0.86, "spacing": 0.0, "space": 4.0},
	"yue_title": {"scale": 1.0, "spacing": 1.0},
	"hand": {"scale": 1.14, "spacing": 0.0},
}

# Settings → Доступность → «Декоративные шрифты». The integrator mirrors G.S.deco_fonts here.
static var deco: = true

static var _cache: = {}
static var _files: = {}


static func has(id: String) -> bool:
	return FAMILIES.has(id)


static func ids() -> Array:
	return FAMILIES.keys()


static func info(id: String) -> Dictionary:
	return FAMILIES.get(id, {})


static func scale(id: String) -> float:
	return float(OPTICS.get(id, {}).get("scale", 1.0))


# Font size to pass to a Label so `id` reads like Playfair at `size`.
static func px(id: String, size: int) -> int:
	return maxi(1, roundi(size * scale(id)))


static func file(path: String) -> FontFile:
	if _files.has(path):
		return _files[path]
	var f: FontFile = null
	if ResourceLoader.exists(path):
		f = load(path) as FontFile
	_files[path] = f
	return f


static func _wght(ff: FontFile, w: int) -> Dictionary:
	if w <= 0 or ff == null:
		return {}
	var ts: = TextServerManager.get_primary_interface()
	var tag: = ts.name_to_tag("wght")
	if ff.get_supported_variation_list().has(tag):
		return {tag: w}
	return {}


static func _variant(path: String, w: int) -> FontVariation:
	var ff: = file(path)
	if ff == null:
		return null
	var fv: = FontVariation.new()
	fv.base_font = ff
	fv.variation_opentype = _wght(ff, w)
	return fv


# The shared tail of every chain: Playfair (cyr, lat) -> Nunito (cyr, lat) -> nunito-sym, minus files
# already in the head of the chain.
static func _tail(w: int, skip_playfair: bool, have: Array) -> Array:
	var out: = []
	var paths: = [] if skip_playfair else [OLD + "playfair-cyr.woff2", OLD + "playfair-lat.woff2"]
	paths += [OLD + "nunito-cyr.woff2", OLD + "nunito-lat.woff2", FAMILIES.sym.file]
	for p in paths:
		if p in have:
			continue
		var v: = _variant(p, w if w > 0 else 800)
		if v:
			out.append(v)
	return out


# Cached FontVariation for a registry id, fallback chain attached. `weight` only matters for the
# variable UI files (Nunito, Playfair, sym); the v10 files are static instances.
static func font(id: String, weight: = -1) -> FontVariation:
	if not FAMILIES.has(id):
		id = "ui_display"
	var d: Dictionary = FAMILIES[id]
	var w: int = weight if weight > 0 else int(d.get("wght", 0))
	var key: = "%s@%d" % [id, w]
	if _cache.has(key):
		return _cache[key]
	var fv: = _variant(d.file, w)
	if fv == null:
		push_warning("V10Fonts: missing " + str(d.file) + ", using Playfair")
		fv = _variant(OLD + "playfair-cyr.woff2", 800)
	var chain: = []
	if d.has("lat"):
		var lat: = _variant(d.lat, w)
		if lat:
			chain.append(lat)
	chain += _tail(w, d.role == "body", [d.file, d.get("lat", "")])
	fv.fallbacks = chain
	var sp: float = float(OPTICS.get(id, {}).get("spacing", 0.0))
	if sp != 0.0:
		fv.spacing_glyph = roundi(sp)
	var wsp: float = float(OPTICS.get(id, {}).get("space", 0.0))
	if wsp != 0.0:
		fv.spacing_space = roundi(wsp)
	_cache[key] = fv
	return fv


# The font id a skin uses for `role` ("title" | "text"), honouring the decorative switch and the
# 24 px rule. Unknown / empty skin -> Playfair for titles, Nunito for text.
static func skin_id(skin: String, role: = "title", size: = 44) -> String:
	if size < TITLE_MIN:
		return "ui_body"
	if deco and SKIN_FONTS.has(skin) and SKIN_FONTS[skin].has(role):
		return SKIN_FONTS[skin][role]
	return "ui_display" if role == "title" else "ui_body"


static func skin(skin_name: String, role: = "title", size: = 44) -> FontVariation:
	var id: = skin_id(skin_name, role, size)
	return font(id, 800 if id == "ui_body" else -1)


static func width(f: Font, text: String, size: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Fit a one-line title into max_w: the skin font at `size` (optics applied), shrinking to FIT_MIN,
# then Playfair from `size` down to FIT_MIN, then Playfair at whatever size fits.
# Returns {font: FontVariation, size: int, id: String}.
static func fit_title(text: String, skin_name: String, size: int, max_w: float) -> Dictionary:
	var id: = skin_id(skin_name, "title", size)
	var f: = font(id)
	var s: = px(id, size)
	var lo: = px(id, FIT_MIN)
	while s > lo and width(f, text, s) > max_w:
		s -= 1
	if width(f, text, s) <= max_w:
		return {"font": f, "size": s, "id": id}
	f = font("ui_display")
	s = size
	while s > 12 and width(f, text, s) > max_w:
		s -= 1
	return {"font": f, "size": s, "id": "ui_display"}


# Share of `text` drawn by the font's own file (no fallback). Whitespace is ignored.
static func coverage(id: String, text: String, with_fallback: = false) -> float:
	var d: Dictionary = FAMILIES.get(id, {})
	if d.is_empty():
		return 0.0
	var own: = file(d.file)
	if own == null:
		return 0.0
	var chain: Array = [own]
	if with_fallback:
		for fb in font(id).fallbacks:
			chain.append((fb as FontVariation).base_font)
	elif d.has("lat") and file(d.lat):
		chain.append(file(d.lat))
	var n: = 0
	var hit: = 0
	for i in text.length():
		var c: = text.unicode_at(i)
		if c <= 32 or c == 0xA0:
			continue
		n += 1
		for ff in chain:
			if ff and (ff as Font).has_char(c):
				hit += 1
				break
	return 1.0 if n == 0 else float(hit) / float(n)


# Rows for «Настройки → Шрифты и лицензии»: one per family, deduplicated by licence file.
static func credits() -> Array:
	var out: = []
	var seen: = {}
	for id in FAMILIES:
		var d: Dictionary = FAMILIES[id]
		var fam: String = str(d.name).replace(" SemiBold", "").replace(" Bold", "").replace(" Medium", "").replace(" Italic", "")
		if seen.has(fam) or id == "sym":
			continue
		seen[fam] = true
		out.append({"family": fam, "id": id, "who": d.who, "licence": d.licence, "copyright": copyright(id)})
	return out


static func copyright(id: String) -> String:
	var t: = licence_text(id)
	var first: = t.split("\n\n")[0] if t != "" else ""
	return first.replace("\n", " ").strip_edges()


static func licence_text(id: String) -> String:
	var d: Dictionary = FAMILIES.get(id, {})
	if d.is_empty() or not FileAccess.file_exists(d.licence):
		return ""
	return FileAccess.get_file_as_string(d.licence)
