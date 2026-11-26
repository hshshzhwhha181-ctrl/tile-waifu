class_name V10Look
extends Node

# V10Look — the partner's «набор богини» resolved into what the player sees (docs/0.10-spec.md D1).
# Static API (works without an autoload); the optional autoload «V10LookHub» (this script) only makes the
# signal hub live in the tree. Nothing here writes G.S except migrate() and set_choice().
#
#   V10Look.resolve(hero, outfit, ctx = {}) -> Dictionary
#        {hero, outfit, rank, frame, accent{name,col,glow,deep,particles}, tile, table, hud, sting, font, palette,
#         open{element: bool}, src{element: "kit"|"base"|"choice"|"preview"}}
#        ctx: {ranked: bool}. Ranked keeps the kit but faces stay standard and the table static (tile_look()).
#   V10Look.current(S = null, ctx = {}) -> Dictionary   partner + outfit + the S.look choices (+ preview);
#                                                       ctx.no_preview: the player's own kit even during a try-on
#                                                       (card payload, anything other players see)
#   V10Look.owned_elements(S) -> {frame: [], tile: [], table: [], hud: []}
#   V10Look.set_choice(S, slot, value) -> String       slot frame|tile|table|hud, value auto|base|<id>; "" = ok
#   V10Look.migrate(S) -> bool                         S.skin -> look.tile, profile.frame -> look.frame (idempotent)
#   V10Look.tile_look(S = null, ctx = {}) -> Dictionary  drop-in for G.skin_look()
#   V10Look.preview(hero, outfit = "") / end_preview()  try-on (banner «Примерить стиль»): never writes S.look
#   V10Look.wave(root, accent = null) -> Node          «надевание»: 0,6 с full, fade 0,3 с mid, nothing at min
#   V10Look.hub().look_changed(look)                    emitted by notify(); titles, HUD skin and tables listen
#
# S.look = {frame, tile, table, hud}: "auto" (как у партнёра) | "base" | element id.

signal look_changed(look: Dictionary)

const SLOTS: = ["frame", "tile", "table", "hud"]
const AUTO: = "auto"
const BASE: = "base"
const DEFAULT_LOOK: = {"frame": AUTO, "tile": AUTO, "table": AUTO, "hud": AUTO}
const WAVE_T: = 0.6
const WAVE_FADE_T: = 0.3

static var _hub: V10Look
static var _preview: = {}
# test builds: `--skin=zlata` reveals a hidden goddess's kit for review (spec D7)
static var dev_reveal: = {}


func _enter_tree() -> void:
	if _hub == null or not is_instance_valid(_hub):
		_hub = self


static func hub() -> V10Look:
	if _hub == null or not is_instance_valid(_hub):
		_hub = V10Look.new()
	return _hub


static func notify(S = null) -> void:
	hub().look_changed.emit(current(S))


static func _gS():
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	return g.S if g else {}


# ------------------------------------------------------------------------------------------------- resolve

static func resolve(hero: String, outfit: = "", ctx: = {}) -> Dictionary:
	var k: = V10KitData.kit(hero)
	if k.is_empty():
		k = V10KitData.kit("mc")
		hero = "mc"
	var rank: = V10KitData.kit_rank(hero, outfit)
	var open: = {}
	for e in V10KitData.ELEMENTS:
		open[e] = V10KitData.element_open(e, rank)
	var up: Dictionary = k.get("up", {}).get(outfit, {})
	var out: = {"hero": hero, "outfit": outfit, "rank": rank, "hero_rank": V10KitData.hero_rank(hero),
		"kit_name": String(k.get("name", "")), "accent": _accent(k), "open": open, "src": {},
		"frame": String(k.get("frame", V10KitData.BASE_FRAME)), "tile": "", "table": "", "hud": V10KitData.BASE_HUD,
		"sting": "", "font": "", "palette": "", "sig": int(k.get("sig", 0)), "ranked": bool(ctx.get("ranked", false))}
	for e in ["frame", "accent"]:
		out.src[e] = "kit"
	if open.tile:
		out.tile = String(up.get("tile", k.get("tile", "")))
		out.table = String(up.get("table", k.get("table", "")))
		out.src.tile = "kit"
		out.src.table = "kit"
	else:
		# A kits: no theme, the accent's legacy skin is the tile (ROSTER §1.3 «существующие предметы входят в наборы»)
		out.tile = String(k.get("legacy_tile", "s_sakura"))
		out.src.tile = "base"
		out.src.table = "base"
	if open.hud:
		out.hud = String(k.get("hud", V10KitData.BASE_HUD))
		out.sting = String(k.get("sting", ""))
		out.font = String(k.get("font", ""))
		out.palette = String(k.get("palettes", {}).get(outfit, ""))
		for e in ["hud", "sting", "font"]:
			out.src[e] = "kit"
	else:
		out.src.hud = "base"
	if out.tile != "" and not V10TileTheme.has(out.tile):
		out.tile = "s_sakura"
	return out


static func _accent(k: Dictionary) -> Dictionary:
	var a: Dictionary = k.get("accent", {})
	return {"name": String(a.get("name", "")), "col": Color(String(a.get("col", "ff8fb8"))),
		"glow": Color(String(a.get("glow", "ffd3e0"))), "deep": Color(String(a.get("deep", "8e3f5c"))),
		"particles": String(a.get("particles", "petals"))}


# ------------------------------------------------------------------------------------------------- state

static func look_of(S: Dictionary) -> Dictionary:
	var lk = S.get("look")
	if not (lk is Dictionary):
		return DEFAULT_LOOK.duplicate()
	var out: = DEFAULT_LOOK.duplicate()
	for s in SLOTS:
		if lk.has(s) and lk[s] is String and String(lk[s]) != "":
			out[s] = String(lk[s])
	return out


static func partner_of(S: Dictionary) -> Array:
	var h: = String(S.get("partner", "mc"))
	var of = S.get("outfit", {})
	var o: = String(of.get(h, "")) if of is Dictionary else ""
	return [h, o]


static func current(S = null, ctx: = {}) -> Dictionary:
	if S == null:
		S = _gS()
	var p: = partner_of(S)
	var src_ctx: = ctx.duplicate()
	var prev: = not _preview.is_empty() and not bool(ctx.get("no_preview", false))
	if prev:
		p = [String(_preview.hero), String(_preview.get("outfit", ""))]
	var r: = resolve(p[0], p[1], src_ctx)
	if prev:
		# try-on shows the whole kit and ignores the player's manual choices
		for e in r.src:
			r.src[e] = "preview"
		r["preview"] = true
		return r
	var lk: = look_of(S)
	# ownership is only needed for a hand pick (the common all-auto save skips it: G.skin_look() runs per board)
	var own: = {}
	for slot in SLOTS:
		if lk[slot] != AUTO and lk[slot] != BASE:
			own = owned_elements(S)
			break
	for slot in SLOTS:
		var v: String = lk[slot]
		if v == AUTO:
			continue
		if v == BASE:
			r[slot] = _base(slot, S)
			r.src[slot] = "base"
		elif v in own.get(slot, []):
			r[slot] = v
			r.src[slot] = "choice"
		# a choice of something not owned (lost / tampered) quietly stays auto (spec D1 selftest)
	return r


static func _base(slot: String, S: Dictionary) -> String:
	match slot:
		"frame":
			return V10KitData.BASE_FRAME
		"tile":
			var sk: = String(S.get("skin", "s_sakura"))
			return sk if V10TileTheme.has(sk) else "s_sakura"
		"table":
			return ""   # "" = the location's own V6 table
		"hud":
			return V10KitData.BASE_HUD
	return ""


static func tile_look(S = null, ctx: = {}) -> Dictionary:
	var cur: = current(S, ctx)
	var id: String = cur.tile if cur.tile != "" else "s_sakura"
	var lk: = V10TileTheme.look(id, ctx)
	# A goddess: her accent colours the highlight and particles even on a legacy skin
	lk["accent"] = cur.accent.col
	lk["particles"] = cur.accent.particles
	return lk


# ------------------------------------------------------------------------------------------------- ownership

static func hero_owned(S: Dictionary, h: String, ctx = null) -> bool:
	if dev_reveal.has(h):
		return true
	var k: = V10KitData.kit(h)
	if k.is_empty():
		return false
	if bool(k.get("hidden", false)) and not V10ProfileCos.released(h):
		return false
	if not (ctx is Dictionary):
		ctx = V10ProfileCos.ctx_from_save(S)
	return (ctx as Dictionary).heroes.has(h)


static func _owns_item(S: Dictionary, id: String) -> bool:
	var o = S.get("owned", {})
	return o is Dictionary and o.has(id)


# Everything the player may pick by hand in «Мой стиль»: kit elements of owned goddesses (and of owned SSR
# outfits that lift a kit), legacy skins they already own, the base of every slot.
static func owned_elements(S: Dictionary) -> Dictionary:
	var out: = {"frame": [], "tile": [], "table": [], "hud": []}
	var ctx: = V10ProfileCos.ctx_from_save(S)   # once, not once per kit
	for h in V10KitData.KITS:
		if not hero_owned(S, h, ctx):
			continue
		var k: Dictionary = V10KitData.KITS[h]
		var r0: = resolve(h, "")
		_push(out.frame, r0.frame)
		if r0.open.tile:
			_push(out.tile, r0.tile)
			_push(out.table, r0.table)
		if r0.open.hud:
			_push(out.hud, r0.hud)
		for o in k.get("up", {}):
			if _owns_item(S, o):
				_push(out.tile, String(k.up[o].tile))
				_push(out.table, String(k.up[o].table))
	for id in V10TileTheme.THEMES:
		if V10TileTheme.THEMES[id].get("legacy", false) and (_owns_item(S, id) or id == "s_sakura"):
			_push(out.tile, id)
	# frames owned through V10ProfileCos (laurels, shop, seasons…) are pickable too
	for id in V10ProfileCos.unlocked("frame", ctx):
		_push(out.frame, String(id))
	for s in out:
		out[s] = out[s].filter(func(x): return String(x) != "")
	return out


static func _push(arr: Array, v: String) -> void:
	if v != "" and not (v in arr):
		arr.append(v)


static func set_choice(S: Dictionary, slot: String, value: String) -> String:
	if not (slot in SLOTS):
		return "нет такого слота"
	if value != AUTO and value != BASE and not (value in owned_elements(S).get(slot, [])):
		return "ещё не открыто"
	var lk: = look_of(S)
	lk[slot] = value
	S["look"] = lk
	if slot == "tile" and value != AUTO and value != BASE and V10TileTheme.has(value) and V10TileTheme.THEMES[value].get("legacy", false):
		S["skin"] = value   # 0.9 readers (album, levels button) keep showing the same skin
	return ""


static func migrate(S: Dictionary) -> bool:
	if S.get("look") is Dictionary:
		var fixed: = look_of(S)
		var changed: bool = fixed != S.look
		S["look"] = fixed
		return changed
	var lk: = DEFAULT_LOOK.duplicate()
	var sk: = String(S.get("skin", "s_sakura"))
	if sk != "" and sk != "s_sakura" and V10TileTheme.has(sk):
		lk.tile = sk
	var prof = S.get("profile", {})
	if prof is Dictionary:
		var fr: = String(prof.get("frame", ""))
		if fr != "" and fr != V10KitData.BASE_FRAME and V10ProfileCos.has(fr, "frame"):
			lk.frame = fr
	S["look"] = lk
	return true


# ------------------------------------------------------------------------------------------------- try-on

static func preview(hero: String, outfit: = "") -> void:
	_preview = {"hero": hero, "outfit": outfit}
	notify()


static func end_preview() -> void:
	_preview = {}
	notify()


static func previewing() -> bool:
	return not _preview.is_empty()


# ------------------------------------------------------------------------------------------------- wave

# «Надевание»: a ring of the accent light grows from the centre over the root while the accent particles
# drift outward. full 0,6 с; mid — 0,3 с fade of a flat accent veil; min — nothing (instant).
static func wave(root: Control, accent = null, level: = "") -> Control:
	if root == null:
		return null
	if level == "":
		level = V9Feel.level() if _gS() is Dictionary and not (_gS() as Dictionary).is_empty() else "full"
	if level == "min":
		return null
	var col: Color = accent if accent is Color else current().accent.col
	var w: = _Wave.new()
	w.col = col
	w.full = level == "full"
	w.size = root.size
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(w)
	return w


class _Wave extends Control:
	var col: = Color.WHITE
	var full: = true
	var k: = 0.0

	func _ready() -> void:
		var tw: = create_tween()
		var dur: = V10Look.WAVE_T if full else V10Look.WAVE_FADE_T
		tw.tween_property(self, "k", 1.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(queue_free)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not full:
			draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.22 * sin(k * PI)))
			return
		var c: = size * 0.5
		var R: = size.length() * 0.55 * k
		var a: = sin(k * PI)
		# a soft band of accent light, never white (HEROINES §2)
		for i in 6:
			var rr: = R - i * 10.0
			if rr > 0.0:
				draw_arc(c, rr, 0.0, TAU, 96, Color(col, a * (0.30 - i * 0.045)), 12.0, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(col.darkened(0.6), 0.10 * a))
