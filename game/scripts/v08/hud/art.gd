class_name V8Art
extends RefCounted

# 0.8 art set (docs/ART.md, res://assets/v08/ui/*): ONE cached loader for every new UI texture.
# Never load() these files directly from screens — go through V8Art so the art can be swapped in one place.
#
#   V8Art.tex("misc/logo")            any file under assets/v08/ui ("<dir>/<name>", .png assumed) or a full res:// path
#   V8Art.rank(tier)                  rank medallion (G.RANKS tier 0..5)     — Common.rank_emblem wraps it
#   V8Art.league(tier)                weekly league crest (same 6 tiers)    — Common.league_emblem wraps it
#   V8Art.icon(name)                  icon/*: circle icons (tasks visits letters rating profile back help settings)
#                                     and gold glyphs (hint undo shuffle sound sound_off lock gift heart close plus trophy);
#                                     old names are aliased (mail -> letters, star -> nav/play …); a name with no new art
#                                     falls back to V8Art.old_icon(). G.icon() and Common.ui_icon() route here too.
#   V8Art.nav(name)                   nav/*: home wardrobe play wishes shop
#   V8Art.cur(name)                   cur/*: gem coin ticket
#   V8Art.event_cur(icon_id)          cur/ev_<hero>: event currencies (V7Event.cur_icon wraps it)
#   V8Art.frame(name)                 frame/*: avatar avatar_top card_r card_sr card_ssr (or a rarity "R"/"SR"/"SSR")
#   V8Art.btn(name)                   btn/*: primary primary_red secondary secondary_jade play_title ribbon panel (raw texture)
#   V8Art.misc(name)                  misc/*: chest_closed chest_open node_cur node_done node_lock logo star_empty
#   V8Art.star(on) / star_rect(on, r) rating star: nav/play filled, misc/star_empty (graphite copy) empty
#   V8Art.bg(name)                    bg/*.webp: profile tourney
#   V8Art.rect(tex, r, keep = true)   TextureRect like UI.tex() but sampled with mipmaps (crisp when drawn small)
#   V8Art.nine(name, r)               NinePatchRect for btn primary/secondary/ribbon/panel sized to r; children are NOT
#                                     scaled (the texture itself is resampled to fit), so add labels straight into it
#   V8Art.avatar(parent, src, r, top) round portrait inside the gold avatar frame; r is the FRAME box (square),
#                                     the portrait sits in the frame's hole (see hole_rect()). src = hero id ("mc"),
#                                     outfit image id ("rin_base") or a Texture2D. top = Dragon/Celestial frame.
#   V8Art.emotion(hero, emo)          heroine emotion portrait (assets/v08/emotions), base portrait when missing;
#                                     busts, crossfades and round emotion avatars — see «heroine emotions» below

const ROOT: = "res://assets/v08/ui/"
const TIER_NAMES: = ["bamboo", "jade", "pearl", "gold", "dragon", "celestial"]
const ICON_ALIAS: = {"mail": "letters", "letter": "letters", "rank": "rating", "cup": "trophy",
	"settings_flat": "settings", "back_flat": "back", "close_flat": "close", "gift_flat": "gift", "heart_flat": "heart",
	"hint_flat": "hint", "lock_flat": "lock", "plus_flat": "plus", "undo_flat": "undo", "shuffle_flat": "shuffle",
	"sound_flat": "sound", "trophy_flat": "trophy", "task": "tasks", "quests": "tasks", "visit": "visits", "mute": "sound_off"}
# glyph names whose 0.8 art lives outside icon/: the gold sakura star (nav/play) is THE star glyph everywhere
const GLYPH_ALIAS: = {"star": "nav/play", "star_flat": "nav/play"}
const NAV_ALIAS: = {"wardrobe": "wardrobe", "closet": "wardrobe", "summon": "wishes", "wish": "wishes", "modes": "play"}
const CUR_ALIAS: = {"gems": "gem", "coins": "coin", "tickets": "ticket"}
# outfit art retired from every surface (HEROINES.md §6) -> what is drawn in its place
const RETIRED_IMG: = {"mc_tutor": "mc_base"}

# Nine-patch margins in source pixels (left, top, right, bottom), measured on the PNGs:
#   primary 600×199: pill caps + sakura end at x≈120, the straight run is uniform x 120…480, rows 92…106
#   secondary 600×177: caps end at x≈80, uniform rows 71…113
#   ribbon 600×121: tails + flowers occupy x 0…160 / 440…600, band uniform between; no vertical stretch room
#   panel 600×433: sakura corner ornaments ≈ 80×64, gold rim 8 px, seigaiha fill tiles
# primary_red / secondary_jade are recolours of primary / secondary (same geometry): boss CTAs and «on» / done states
const NINE: = {
	"primary": {"m": [124, 64, 124, 64], "fit": "h"},
	"primary_red": {"m": [124, 64, 124, 64], "fit": "h"},
	"secondary": {"m": [92, 60, 92, 56], "fit": "h"},
	"secondary_jade": {"m": [92, 60, 92, 56], "fit": "h"},
	"ribbon": {"m": [164, 56, 164, 58], "fit": "h"},
	"panel": {"m": [92, 76, 92, 76], "fit": "box", "tile": true},
}

# Transparent hole of the avatar frames, as fractions of the 256² frame (flood-filled from the centre):
#   avatar.png      hole x 39…217, y 25…197 → centre (128,111), r≈87
#   avatar_top.png  hole x 58…196, y 46…165 → centre (127,106), r≈66
const HOLE: = {
	false: {"c": Vector2(0.5, 0.434), "r": 0.355},
	true: {"c": Vector2(0.496, 0.414), "r": 0.272},
}

static var _cache: = {}
static var _nine_cache: = {}


static func _path(p: String) -> String:
	if p.begins_with("res://"):
		return p
	if p.get_extension() == "":
		p += ".png"
	return ROOT + p


static func tex(path: String) -> Texture2D:
	var p: = _path(path)
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	else:
		push_warning("V8Art: missing texture %s" % p)
	_cache[p] = t
	return t


static func has(path: String) -> bool:
	return ResourceLoader.exists(_path(path))


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]


static func rank(tier: int) -> Texture2D:
	return tex("rank/" + tier_name(tier))


static func league(tier: int) -> Texture2D:
	return tex("league/" + tier_name(tier))


static func icon(name: String) -> Texture2D:
	if GLYPH_ALIAS.has(name):
		return tex(GLYPH_ALIAS[name])
	var n: String = ICON_ALIAS.get(name, name)
	if has("icon/" + n):
		return tex("icon/" + n)
	return old_icon(name)


# Pre-0.8 icon (assets/v06/hud/icons, then assets/icons). Loaded here directly — not via G.icon — because G.icon is
# redirected to V8Art. Used only when a name has no 0.8 art (event currencies and the like).
static func old_icon(name: String) -> Texture2D:
	for p in ["res://assets/v06/hud/icons/%s.png" % name, "res://assets/icons/%s.png" % name]:
		if ResourceLoader.exists(p):
			return tex(p)
	return null


static func nav(name: String) -> Texture2D:
	var n: String = NAV_ALIAS.get(name, name)
	if has("nav/" + n):
		return tex("nav/" + n)
	return icon(name)


static func cur(name: String) -> Texture2D:
	return tex("cur/" + String(CUR_ALIAS.get(name, name)))


# Event currency (event_data "icon": "cur_<hero>") -> cur/ev_<hero>: glossy lacquered objects in the cur/gem and
# cur/coin style (tea leaves, holo chip, firefly orb, medal, moon drop; gold filigree + sakura, light top-left).
# Falls back to the 0.7 file if a new event has no art yet.
static func event_cur(icon_id: String) -> Texture2D:
	var n: = "cur/ev_" + icon_id.trim_prefix("cur_")
	if has(n):
		return tex(n)
	return tex("res://assets/v07/event/%s.png" % icon_id)


static func frame(name: String) -> Texture2D:
	var n: = name
	if name.to_upper() in ["R", "SR", "SSR"]:
		n = "card_" + name.to_lower()
	return tex("frame/" + n)


static func btn(name: String) -> Texture2D:
	return tex("btn/" + name)


static func misc(name: String) -> Texture2D:
	return tex("misc/" + name)


# Star rating: the gold sakura star (nav/play) when earned, its graphite copy (misc/star_empty) when not.
# Every star rating (victory, map nodes, chests, event tables, modes, album) uses this — never assets/fx/star*.
static func star(on: = true) -> Texture2D:
	return tex("nav/play" if on else "misc/star_empty")


# TextureRect with the rating star, mipmapped so it stays crisp at 26…104 px.
static func star_rect(on: bool, r: Rect2) -> TextureRect:
	return rect(star(on), r)


static func bg(name: String) -> Texture2D:
	return tex("bg/%s.webp" % name)


static func rect(t: Texture2D, r: Rect2, keep: = true) -> TextureRect:
	var tr: = UI.tex(t, r, keep)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return tr


# ------------------------------------------------------------------ nine-patch

# scale factor the source is resampled by so that it fits r: buttons/ribbons keep their full height
# (k = h / tex_h, only the middle stretches sideways); panels scale their corners with the box.
static func nine_scale(name: String, size: Vector2) -> float:
	var spec: Dictionary = NINE.get(name, NINE.panel)
	var t: = btn(name)
	if t == null:
		return 1.0
	var m: Array = spec.m
	var k: float
	if spec.fit == "h":
		k = size.y / float(t.get_height())
	else:
		k = clampf(minf(size.x, size.y) / 560.0, 0.28, 0.8)
	# never let the fixed edges overlap
	k = minf(k, (size.x - 2.0) / float(m[0] + m[2]))
	k = minf(k, (size.y - 2.0) / float(m[1] + m[3])) if spec.fit != "h" else k
	return clampf(snappedf(k, 0.02), 0.06, 1.0)


static func _scaled(name: String, k: float) -> Texture2D:
	var src: = btn(name)
	if src == null or is_equal_approx(k, 1.0):
		return src
	var key: = "%s@%d" % [name, int(round(k * 100.0))]
	if _nine_cache.has(key):
		return _nine_cache[key]
	var img: Image = src.get_image()
	if img == null or img.is_empty():
		_nine_cache[key] = null
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(maxi(1, int(round(img.get_width() * k))), maxi(1, int(round(img.get_height() * k))), Image.INTERPOLATE_LANCZOS)
	var t: = ImageTexture.create_from_image(img)
	_nine_cache[key] = t
	return t


static func nine(name: String, r: Rect2) -> NinePatchRect:
	var spec: Dictionary = NINE.get(name, NINE.panel)
	var np: = NinePatchRect.new()
	np.position = r.position
	np.size = r.size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.name = "V8" + name.capitalize()
	var k: = nine_scale(name, r.size)
	var t: = _scaled(name, k)
	if t == null:
		# headless / no image data: native texture, margins as measured
		t = btn(name)
		k = 1.0
	np.texture = t
	var m: Array = spec.m
	np.patch_margin_left = int(round(m[0] * k))
	np.patch_margin_top = int(round(m[1] * k))
	np.patch_margin_right = int(round(m[2] * k))
	np.patch_margin_bottom = int(round(m[3] * k))
	if spec.get("tile", false):
		np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
		np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	np.set_meta("v8_scale", k)
	return np


# Inner rect (in the nine's own coordinates) that is safe for text: inside the rim / caps.
static func nine_content(name: String, size: Vector2) -> Rect2:
	var spec: Dictionary = NINE.get(name, NINE.panel)
	var k: = nine_scale(name, size)
	var m: Array = spec.m
	var pad: = {"primary": [0.55, 0.12, 0.55, 0.14], "primary_red": [0.55, 0.12, 0.55, 0.14], "secondary": [0.5, 0.12, 0.5, 0.12], "secondary_jade": [0.5, 0.12, 0.5, 0.12], "ribbon": [0.85, 0.05, 0.85, 0.3], "panel": [0.25, 0.25, 0.25, 0.25]}.get(name, [0.3, 0.3, 0.3, 0.3])
	var l: float = m[0] * k * pad[0]
	var t: float = size.y * pad[1] if spec.fit == "h" else m[1] * k * pad[1]
	var rr: float = m[2] * k * pad[2]
	var b: float = size.y * pad[3] if spec.fit == "h" else m[3] * k * pad[3]
	return Rect2(l, t, size.x - l - rr, size.y - t - b)


# ------------------------------------------------------------------ avatar

# Where the portrait circle sits inside a frame box of `size` (top = Dragon/Celestial frame).
static func hole_rect(size: Vector2, top: = false) -> Rect2:
	var h: Dictionary = HOLE[top]
	var d: float = size.x * float(h.r) * 2.0
	var c: Vector2 = size * Vector2(h.c)
	return Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d))


static func _portrait(src, r: Rect2) -> TextureRect:
	var t: Texture2D = null
	var focus: = Vector2(0.5, 0.2)
	var zoom: = 4.0
	if src is Texture2D:
		t = src
	elif src is String or src is StringName:
		var s: = String(src)
		if Hero.RIGS.has(s) and ResourceLoader.exists("res://assets/hero/%s.png" % s):
			t = load("res://assets/hero/%s.png" % s)
			var rig: Dictionary = Hero.RIGS[s]
			focus = Vector2(rig.head_c.x / float(t.get_width()), (rig.head_c.y + 15.0) / float(t.get_height()))
			zoom = 4.6
		else:
			# retired art (o_tutor, HEROINES.md §6) never shows, even from an old save or a stored league avatar
			if RETIRED_IMG.has(s):
				s = RETIRED_IMG[s]
			var p: = "res://assets/outfits/%s.webp" % s
			if not ResourceLoader.exists(p):
				p = "res://assets/outfits/mc_base.webp"
			t = load(p)
			var fc: Array = V8Population.face(s)
			focus = Vector2(fc[0], fc[1])
			zoom = float(fc[2])
	if t == null:
		t = load("res://assets/hero/mc.png")
	var art: = Common.card_art(t, r, focus, zoom, r.size.x * 0.5)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	art.name = "Pic"
	return art


static func avatar(parent: Control, src, r: Rect2, top: = false) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = "V8Avatar"
	var hr: = hole_rect(r.size, top)
	# dark disc behind the portrait so transparent outfit edges never show the screen through
	var disc: = UI.rbox("graphite", hr.grow(1.0), hr.size.x * 0.5 + 1.0, 0, 0)
	disc.colors(Color("2a2230"), Color("15111a"))
	disc.set_param("shadow_color", Color(0, 0, 0, 0))
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(disc)
	# portrait is a little larger than the hole so its edge tucks under the gold ring
	c.add_child(_portrait(src, hr.grow(hr.size.x * 0.03)))
	var fr: = rect(frame("avatar_top" if top else "avatar"), Rect2(Vector2.ZERO, r.size))
	fr.name = "Frame"
	c.add_child(fr)
	if parent != null:
		parent.add_child(c)
	return c


# Dragon (4) and Celestial (5) players wear the ornate frame.
static func top_tier(tier: int) -> bool:
	return tier >= 4


# ------------------------------------------------------------------ heroine emotions
#
# Waist-up emotion portraits (docs/ART.md «Эмоции героинь»): assets/v08/emotions/<hero>_<emotion>.webp,
# hero ∈ mc hana rin yue nova, emotion ∈ happy sad surprised pout shy, transparent, ≈600×800.
#
#   V8Art.emotion(hero, emo)            the texture; a missing file falls back to the base portrait assets/hero/<hero>.png
#   V8Art.has_emotion(hero, emo)        true when the emotion file exists (callers keep the rigged Hero otherwise)
#   V8Art.emo_name(kind)                normalise a reaction kind («big», «smug», «fail», «deny» …) to one of EMOTIONS
#   V8Art.win_emotion(hero)             «happy», or «shy» once her affection level is high (SHY_LEVEL)
#   V8Art.emotion_face(hero, emo)       face centre in texture pixels (between the eyes and the mouth)
#   V8Art.emotion_face_w(hero, emo)     face width (cheek to cheek) in texture pixels — the scale anchor
#   V8Art.rig_face(hero) / RIG_FACE_W   the same two numbers on the rigged base art (assets/hero/<hero>.png)
#   V8Art.emotion_avatar(h, e, r, pal)  round portrait in a ring (Common.avatar look) cropped on the emotion face
#   V8Art.bust(h, e, size, at, face_w)  Control that draws the emotion bust with its face centre at `at` and the face
#                                       `face_w` px wide; the bottom (the waist cut) fades out. Never takes taps.
#   V8Art.bust_set(bust, emo, dur)      crossfade (+ slight scale) to another emotion, faces stay aligned, no pops
#   V8Art.bust_bounce(bust, amt)        subtle springy bounce around the face

const EMO_ROOT: = "res://assets/v08/emotions/"
const EMOTIONS: = ["happy", "sad", "surprised", "pout", "shy"]
const EMO_ALIAS: = {"big": "happy", "smug": "happy", "win": "happy", "joy": "happy", "combo": "happy", "greet": "happy",
	"lose": "sad", "fail": "sad", "cry": "sad", "deny": "pout", "anger": "pout", "angry": "pout", "steal": "pout",
	"wow": "surprised", "rankup": "surprised", "record": "surprised", "danger": "surprised", "blush": "shy", "love": "shy"}
# affection level from which a win makes her shy instead of plainly happy (room scenes open at 2 / 4 / 7 / 10)
const SHY_LEVEL: = 7

# Face centre of every emotion file as a fraction of the image (x, y), measured on the art: the eyes-to-mouth middle.
const EMO_FACE: = {
	"mc": {"happy": [0.49, 0.28], "sad": [0.5, 0.3], "surprised": [0.5, 0.265], "pout": [0.5, 0.29], "shy": [0.5, 0.29]},
	"hana": {"happy": [0.5, 0.27], "sad": [0.5, 0.31], "surprised": [0.5, 0.29], "pout": [0.48, 0.31], "shy": [0.5, 0.31]},
	"rin": {"happy": [0.5, 0.31], "sad": [0.5, 0.35], "surprised": [0.5, 0.31], "pout": [0.5, 0.34], "shy": [0.53, 0.35]},
	"yue": {"happy": [0.46, 0.27], "sad": [0.5, 0.28], "surprised": [0.48, 0.21], "pout": [0.5, 0.32], "shy": [0.5, 0.31]},
	"nova": {"happy": [0.52, 0.27], "sad": [0.5, 0.33], "surprised": [0.5, 0.33], "pout": [0.5, 0.3], "shy": [0.52, 0.35]},
}
# face width (cheek to cheek at the eyes) in px: emotion art / rigged base art — the ratio keeps a swap the same size
const EMO_FACE_W: = {"mc": 180.0, "hana": 172.0, "rin": 188.0, "yue": 170.0, "nova": 180.0}
const RIG_FACE_W: = {"mc": 100.0, "hana": 90.0, "rin": 76.0, "yue": 80.0, "nova": 86.0}

const BUST_SHADER: = "shader_type canvas_item;\nvarying vec4 vcol;\nuniform float fade = 0.16;\nuniform float flash = 0.0;\n" + \
	"void vertex() { vcol = COLOR; }\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n" + \
	"\tc.rgb = mix(c.rgb, vec3(1.0), flash);\n\tc.a *= 1.0 - smoothstep(1.0 - max(fade, 0.001), 1.0, UV.y);\n\tCOLOR = c * vcol;\n}\n"


static func emo_hero(hero: String) -> String:
	if Hero.RIGS.has(hero):
		return hero
	var p: = hero.get_slice("_", 0)
	return p if Hero.RIGS.has(p) else hero


static func emo_name(kind: String) -> String:
	if kind in EMOTIONS:
		return kind
	return String(EMO_ALIAS.get(kind, ""))


static func emotion_path(hero: String, emo: String) -> String:
	return EMO_ROOT + "%s_%s.webp" % [emo_hero(hero), emo_name(emo)]


static func has_emotion(hero: String, emo: String) -> bool:
	return emo_name(emo) != "" and ResourceLoader.exists(emotion_path(hero, emo))


static func emotion(hero: String, emo: String) -> Texture2D:
	if has_emotion(hero, emo):
		return tex(emotion_path(hero, emo))
	var h: = emo_hero(hero)
	if not Hero.RIGS.has(h):
		h = "mc"
	return tex("res://assets/hero/%s.png" % h)


static func win_emotion(hero: String) -> String:
	return "shy" if G.aff_level(emo_hero(hero)) >= SHY_LEVEL else "happy"


# face centre on the rigged base art: halfway between the eye line and the mouth
static func rig_face(hero: String) -> Vector2:
	var rig: Dictionary = Hero.RIGS.get(emo_hero(hero), Hero.RIGS.mc)
	var el: Vector4 = rig.eye_l
	var er: Vector4 = rig.eye_r
	var m: Vector4 = rig.mouth
	return Vector2((el.x + er.x + m.x * 2.0) * 0.25, ((el.y + er.y) * 0.5 + m.y) * 0.5)


static func emotion_face(hero: String, emo: String) -> Vector2:
	var h: = emo_hero(hero)
	if not has_emotion(h, emo):
		return rig_face(h)
	var t: = emotion(h, emo)
	var f: Array = EMO_FACE.get(h, {}).get(emo_name(emo), [0.5, 0.3])
	return Vector2(t.get_width() * float(f[0]), t.get_height() * float(f[1]))


static func emotion_face_w(hero: String, emo: String) -> float:
	var h: = emo_hero(hero)
	if not has_emotion(h, emo):
		return float(RIG_FACE_W.get(h, 90.0))
	return float(EMO_FACE_W.get(h, 180.0))


# round emotion portrait inside a ring, the same build as Common.avatar (ring rbox, 5 px inset, round crop)
static func emotion_avatar(hero: String, emo: String, r: Rect2, ring_pal: = "gold") -> Control:
	var h: = emo_hero(hero)
	if not has_emotion(h, emo) and Hero.RIGS.has(h):
		return Common.avatar(h, r, ring_pal)
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = "V8EmoAvatar"
	c.add_child(UI.rbox(ring_pal, Rect2(Vector2.ZERO, r.size), r.size.x * 0.5, 3, 8))
	var t: = emotion(h, emo)
	var face: = emotion_face(h, emo)
	var fw: = emotion_face_w(h, emo)
	var inner: = Rect2(Vector2(5, 5), r.size - Vector2(10, 10))
	# the face (plus a little hair and the chin) fills the circle: visible width ≈ 1.6 face widths
	var zoom: = maxf(1.0, float(t.get_width()) / (fw * 1.6))
	var focus: = Vector2(face.x / t.get_width(), (face.y + fw * 0.08) / t.get_height())
	var art: = Common.card_art(t, inner, focus, zoom, inner.size.x * 0.5)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	art.name = "Pic"
	c.add_child(art)
	return c


# the waist-fade shader lives on the bust (shared by its layers), not in a static: nothing outlives the screen
static func _bust_mat(b: Control) -> ShaderMaterial:
	var sh = b.get_meta("shader") if b.has_meta("shader") else null
	if not sh is Shader:
		sh = Shader.new()
		(sh as Shader).code = BUST_SHADER
		b.set_meta("shader", sh)
	var m: = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("fade", float(b.get_meta("fade")))
	return m


static func _bust_layer(b: Control, emo: String) -> TextureRect:
	var h: String = b.get_meta("hero")
	var t: = emotion(h, emo)
	var face: = emotion_face(h, emo)
	var k: float = float(b.get_meta("face_w")) / emotion_face_w(h, emo)
	var at: Vector2 = b.get_meta("at")
	var tr: = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(t.get_width(), t.get_height()) * k
	tr.position = at - face * k
	tr.pivot_offset = face * k
	tr.material = _bust_mat(b)
	tr.name = "Emo_" + emo_name(emo)
	return tr


# the bust container: `size` is the box it lives in (for the caller's layout), `at` the face centre in it
static func bust(hero: String, emo: String, size: Vector2, at: Vector2, face_w: float, fade: = 0.16) -> Control:
	var b: = Control.new()
	b.name = "V8EmoBust"
	b.size = size
	b.pivot_offset = at
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("hero", emo_hero(hero))
	b.set_meta("at", at)
	b.set_meta("face_w", face_w)
	b.set_meta("fade", fade)
	var e: = emo_name(emo)
	if e == "":
		e = "happy"
	b.set_meta("emo", e)
	var l: = _bust_layer(b, e)
	b.add_child(l)
	b.set_meta("layer", l)
	return b


static func bust_emo(b: Control) -> String:
	return String(b.get_meta("emo", "")) if b and is_instance_valid(b) else ""


# crossfade to `emo`: the new face fades in over the old one (slightly zoomed, settling to 1.0), the old one fades
# a beat later, so the swap never shows the background through a half-transparent pair; dur 0 swaps at once
static func bust_set(b: Control, emo: String, dur: = 0.32) -> void:
	if b == null or not is_instance_valid(b):
		return
	var e: = emo_name(emo)
	if e == "" or e == bust_emo(b):
		return
	b.set_meta("emo", e)
	var old = b.get_meta("layer", null)
	var nl: = _bust_layer(b, e)
	b.add_child(nl)
	b.set_meta("layer", nl)
	if dur <= 0.0:
		if old != null and is_instance_valid(old):
			(old as Node).queue_free()
		return
	nl.modulate.a = 0.0
	nl.scale = Vector2.ONE * 1.035
	var t: = nl.create_tween().set_parallel()
	t.tween_property(nl, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(nl, "scale", Vector2.ONE, dur * 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old != null and is_instance_valid(old):
		var o: Control = old
		var to: = o.create_tween().set_parallel()
		to.tween_property(o, "modulate:a", 0.0, dur * 0.6).set_delay(dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		to.tween_property(o, "scale", Vector2.ONE * 0.985, dur).set_trans(Tween.TRANS_SINE)
		to.chain().tween_callback(o.queue_free)


static func bust_bounce(b: Control, amt: = 0.035) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b.has_meta("bounce_tw"):
		var old = b.get_meta("bounce_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	b.scale = Vector2.ONE
	var t: = b.create_tween()
	t.tween_property(b, "scale", Vector2(1.0 - amt * 0.4, 1.0 + amt), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("bounce_tw", t)
