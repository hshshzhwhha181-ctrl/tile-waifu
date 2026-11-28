class_name TWPresence
extends Control

# TWPresence (P34 / WP10): the heroine's presence in a round, over the finished V10LiveRig (live_rig.gd is NOT touched).
# One interface for every screen that shows her during play; the rig stays an asset behind it (ARCH: "live_rig behind a TWPresence interface").
#
# CONTRACT (GDD v11 3.5.1, 7.2, 9.2; DECISIONS 33):
#   * three modes: FULL (a column beside the board, opt-in, board >= 50% of the width), STANDARD (a strip under the tray, height
#     <= 28% of the SCREEN height, waist-up, DEFAULT), MINIMUM (a 160 px medallion; the default in Classic, Connect and Garden);
#   * not a pixel on the board: layout() takes the rect to keep clear (field + tray) and never overlaps it; the strip and the
#     medallion are clipped to their own rect, so a gesture that swings wide cannot leave it;
#   * <= 1 rig on screen (V10RigCatalog.mount frees a previous rig of the same parent), no video;
#   * touches on the heroine are OFF in a round (they live in the Tea Room and the Salon): every Control here ignores the mouse and the
#     rig is mounted with handle_input = false. The ult is a separate ring button, not a tap on her;
#   * reactions combo_t1 / combo_t2 / combo_t3, clear, fail, tray_danger, ult_cast are driven by core events (TWBoardEvents MATCH.combo,
#     CLEARED, TRAY_FULL, TRAY_WARN, and the shell event ULT_CAST) through TWBus; the gesture starts in the SAME call that
#     delivers the event (synchronous), so the delay is one function call, far below the 100 ms limit;
#   * a heroine without a finished rig (only mc_gown, rin_officer, hana_base are ready) gets the MEDALLION STUB: her portrait in a
#     160 px disc that pulses on the same reactions. No other code path differs.
#
# API
#   TWPresence.layout(screen, avoid, mode, insets = {}) -> Dictionary   pure rect maths (see below), tested on 3 aspects
#   TWPresence.resolve_mode(pref, game_mode) -> String                   settings "presence_mode" (auto|full|standard|minimum) x game mode
#   TWPresence.reaction_gesture(entry, reaction) -> String               which gesture of a rig plays a reaction ("" = none)
#   TWPresence.Tracker                                                   TWBoardEvents -> reaction id (combo tiers by edge), pure
#   var p := TWPresence.new(); p.configure(hero, outfit, mode); p.set_screen(size, avoid, insets); add_child(p); p.bind(bus)
#   p.play("clear") / p.set_mode(m) / p.set_screen(...) / p.set_active(false)
#   signals reaction_started(reaction, gesture), mode_changed(mode)

signal reaction_started(reaction: String, gesture: String)
signal mode_changed(mode: String)

const MODE_FULL: = "full"
const MODE_STANDARD: = "standard"
const MODE_MINIMUM: = "minimum"
const MODES: = [MODE_FULL, MODE_STANDARD, MODE_MINIMUM]

const STRIP_MAX_FRAC: = 0.28          # GDD 3.5 / 7.2 / 9.2: strip height <= 28% of the screen height
const STRIP_MIN_H: = 96.0             # below this a strip is no use: it degrades to the medallion
const MEDALLION: = 160.0              # px at the 720 px base (the project stretches canvas_items to a 720 wide viewport)
const MEDALLION_MIN: = 96.0           # only when there is no room under the board at all (flagged "clamped")
const MARGIN: = 16.0
const FULL_COL_FRAC: = 0.38           # opt-in column; the board keeps 62% >= the 50% of DECISIONS 33
const FULL_BOARD_MIN_FRAC: = 0.5
const ANCHOR_X: = 0.5                 # the figure is centred in the strip
const WAIST_FRAC: = 0.64              # the strip shows the top 64% of the art (waist-up)
const TOP_MARGIN_FRAC: = 0.03         # of the strip height: air above the hair (the art starts at its top edge)
const FACE_SPAN: = 430.0              # art px across the medallion (head and shoulders)
const FACE_DROP: = 60.0               # the face centre sits a little above the disc centre
const ART_H: = 1400.0

const EV_ULT_CAST: = "ULT_CAST"       # shell event: the ult ring button was pressed (no core event exists for it)
const R_COMBO_T1: = "combo_t1"
const R_COMBO_T2: = "combo_t2"
const R_COMBO_T3: = "combo_t3"
const R_CLEAR: = "clear"
const R_FAIL: = "fail"
const R_TRAY_DANGER: = "tray_danger"
const R_ULT_CAST: = "ult_cast"
const REACTIONS: = [R_COMBO_T1, R_COMBO_T2, R_COMBO_T3, R_CLEAR, R_FAIL, R_TRAY_DANGER, R_ULT_CAST]
const COMBO_TIERS: = [5, 10, 20]      # GDD 9.3: T1 x5, T2 x10, T3 x20

# one rig has a handful of gestures (rig data contract, gestures.json); a reaction is the first of its candidates the rig owns.
# Order matters only between rigs (mc_gown / rin_officer / hana_base each own a different subset).
const CANDIDATES: = {
	R_COMBO_T1: ["tail_flick", "braid_flick", "hair_shake", "hair_touch", "shoulder_roll", "settle"],
	R_COMBO_T2: ["shoulder_roll", "adjust_glasses", "fist_pump", "side_stretch", "wave", "lean_in"],
	R_COMBO_T3: ["wink_grin", "air_kiss", "smirk", "fist_pump", "wave"],
	R_CLEAR: ["wave", "wink_grin", "fist_pump", "smirk", "adjust_glasses", "nuzzle"],
	R_FAIL: ["pout", "huff"],
	R_TRAY_DANGER: ["look_neutral"],
	R_ULT_CAST: ["lean_in", "fan_hide", "lunge_lean", "air_kiss", "wink_grin"],
}
# a stronger reaction may cut in on a weaker one; a weaker one is dropped while a stronger one is fresh
const PRIORITY: = {R_FAIL: 90, R_ULT_CAST: 80, R_CLEAR: 70, R_COMBO_T3: 60, R_COMBO_T2: 50, R_COMBO_T1: 40, R_TRAY_DANGER: 30}
const GAP_S: = 0.6                    # a reaction of lower or equal priority within this time after another one is dropped
const REPEAT_S: = {R_TRAY_DANGER: 4.0, R_COMBO_T1: 1.0, R_COMBO_T2: 1.0, R_COMBO_T3: 1.0}   # same reaction again
const KEEP_LOG: = 32

var mode: = MODE_STANDARD
var effective_mode: = MODE_STANDARD   # what is on screen (a strip with no room degrades to the medallion)
var hero: = ""
var outfit: = ""
var rig: V10LiveRig
var rig_entry: Dictionary = {}
var stub: = false                      # no finished rig for this heroine: the medallion stub
var geom: Dictionary = {}              # the last layout()
var history: Array = []                    # last KEEP_LOG {reaction, gesture, t_ms}
var dropped: = 0
var tracker: Tracker = Tracker.new()
var _bus: TWBus
var _tokens: Array = []
var _view: _View
var _frame: _Frame
var _portrait: TextureRect
var _screen: = Vector2(720, 1280)
var _avoid: = Rect2()
var _insets: Dictionary = {}
var _last_t: = -1000.0
var _last_prio: = 0
var _last_by: Dictionary = {}
var _clock: Callable = Callable()      # tests inject a clock (seconds); default = real time
var _built: = false


# ------------------------------------------------------------------ layout (pure)

# screen: logical size. avoid: the rect to keep clear (the board + the tray; may be empty). insets: {top, bottom} safe area.
# Returns {mode (asked), effective (shown), rect (the Control rect), hero (rect of the figure area, == rect), disc (bool),
#          clamped (bool, smaller than 160), degraded (bool), hidden (bool: no room at all, rect is empty), board_max_w (FULL only: the widest the board may be), strip_frac (rect.h / screen.h)}
static func layout(screen: Vector2, avoid: Rect2, mode: String, insets: Dictionary = {}) -> Dictionary:
	var top_in: float = float(insets.get("top", 0.0))
	var bot_in: float = float(insets.get("bottom", 0.0))
	var bottom: = screen.y - bot_in
	var out: = {"mode": mode, "effective": mode, "rect": Rect2(), "hero": Rect2(), "disc": false, "clamped": false,
			"degraded": false, "hidden": false, "board_max_w": screen.x, "strip_frac": 0.0}
	var clear_y: = maxf(avoid.end.y, 0.0) if avoid.size != Vector2.ZERO else 0.0
	match mode:
		MODE_FULL:
			var w: = floorf(screen.x * FULL_COL_FRAC)
			var r: = Rect2(screen.x - w, top_in, w, bottom - top_in)
			out.rect = r
			out.board_max_w = screen.x - w
		MODE_MINIMUM:
			out = _medallion(out, screen, clear_y, bottom)
		_:
			var top: = maxf(clear_y, bottom - floorf(screen.y * STRIP_MAX_FRAC))
			if bottom - top < STRIP_MIN_H:
				out.degraded = true
				out = _medallion(out, screen, clear_y, bottom)
			else:
				out.effective = MODE_STANDARD
				out.rect = Rect2(0.0, top, screen.x, bottom - top)
	out.hero = out.rect
	out.strip_frac = (out.rect as Rect2).size.y / maxf(screen.y, 1.0)
	return out


static func _medallion(out: Dictionary, screen: Vector2, clear_y: float, bottom: float) -> Dictionary:
	var room: = bottom - MARGIN - clear_y - MARGIN
	out.effective = MODE_MINIMUM
	out.disc = true
	if room < MEDALLION_MIN:
		# the board leaves no room at all: the heroine is hidden rather than drawn over the field
		out.hidden = true
		out.clamped = true
		out.rect = Rect2(screen.x - MARGIN, bottom, 0.0, 0.0)
		return out
	var d: = minf(MEDALLION, room)
	out.clamped = d < MEDALLION
	out.rect = Rect2(screen.x - MARGIN - d, bottom - MARGIN - d, d, d)
	return out


# the avoid rect of the standard board-first layout (GDD 7.2): field + tray take the top 72% of the screen
static func standard_avoid(screen: Vector2) -> Rect2:
	return Rect2(0.0, 0.0, screen.x, floorf(screen.y * (1.0 - STRIP_MAX_FRAC)))


# where the rig goes inside its area: {scale, position} in the area's local coordinates (art px -> area px)
static func fit(area: Vector2, effective: String, center_x: float, face_pivot: Vector2, art_h: float = ART_H) -> Dictionary:
	if effective == MODE_MINIMUM:
		var k: = minf(area.x, area.y) / FACE_SPAN
		var c: = area * 0.5 - Vector2(0.0, 0.0)
		return {"scale": k, "position": c - (face_pivot + Vector2(0.0, FACE_DROP)) * k}
	var s: float
	if effective == MODE_FULL:
		s = minf(area.y / (art_h * 0.92), area.x / (center_x * 2.0 * 0.95))
		return {"scale": s, "position": Vector2(area.x * 0.5 - center_x * s, area.y - art_h * s * 0.98)}
	s = area.y / (art_h * WAIST_FRAC)
	return {"scale": s, "position": Vector2(area.x * ANCHOR_X - center_x * s, area.y * TOP_MARGIN_FRAC)}


static func default_mode_for(game_mode: String) -> String:
	if game_mode in ["classic", "connect", "garden"]:
		return MODE_MINIMUM
	return MODE_STANDARD


# settings key "presence_mode": auto | full | standard | minimum
static func resolve_mode(pref: String, game_mode: String) -> String:
	if MODES.has(pref):
		return pref
	return default_mode_for(game_mode)


# ------------------------------------------------------------------ reactions (data)

# the gestures of a rig (gestures.json entry) that may play in a round: not bold, not legs (the strip ends at the waist),
# not marked n/a, not a layer/fx entry
static func usable_gestures(entry: Dictionary) -> Array:
	var out: Array = []
	for g in entry.get("gestures", []):
		if not (g is Dictionary):
			continue
		var gd: Dictionary = g
		if String(gd.get("status", "")).begins_with("n/a") or String(gd.get("rig", "R")) == "V":
			continue
		if String(gd.get("tier", "base")) == "bold" or bool(gd.get("legs", false)):
			continue
		if not (String(gd.get("use", "")) in ["auto", "both", "react"]):
			continue
		var nm: = String(gd.get("name", ""))
		if nm != "" and not out.has(nm):
			out.append(nm)
	return out


static func reaction_gesture(entry: Dictionary, reaction: String) -> String:
	var have: Array = usable_gestures(entry)
	for c in CANDIDATES.get(reaction, []):
		if have.has(c):
			return String(c)
	return ""


# ------------------------------------------------------------------ events -> reactions (pure)

class Tracker extends RefCounted:
	# combo tiers by EDGE: T1 when the combo reaches 5, T2 at 10, T3 at 20; a broken combo (a smaller number) lowers the tier again,
	# so a new streak fires again. Other events map one to one.
	var tier: = 0

	func reset() -> void:
		tier = 0

	static func tier_of(combo: int) -> int:
		var t: = 0
		for i in TWPresence.COMBO_TIERS.size():
			if combo >= int(TWPresence.COMBO_TIERS[i]):
				t = i + 1
		return t

	func feed(ev: Dictionary) -> String:
		match str(ev.get("t", "")):
			TWBoardEvents.MATCH:
				var nt: = tier_of(int(ev.get("combo", 0)))
				var fired: = ""
				if nt > tier:
					fired = [TWPresence.R_COMBO_T1, TWPresence.R_COMBO_T2, TWPresence.R_COMBO_T3][nt - 1]
				tier = nt
				return fired
			TWBoardEvents.CLEARED:
				return TWPresence.R_CLEAR
			TWBoardEvents.TRAY_FULL:
				return TWPresence.R_FAIL
			TWBoardEvents.TRAY_WARN:
				return TWPresence.R_TRAY_DANGER if int(ev.get("left", 1)) <= 1 else ""
			TWPresence.EV_ULT_CAST:
				return TWPresence.R_ULT_CAST
		return ""


# ------------------------------------------------------------------ the node

class _View extends Control:
	var disc: = false

	func _draw() -> void:
		if disc:   # the disc is the mask of its children (clip_children = CLIP_CHILDREN_ONLY); it is not shown itself
			draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color.WHITE)


class _Frame extends Control:
	var disc: = false
	var letter: = ""
	var flash: = 0.0

	func _draw() -> void:
		if not disc:
			return
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.5
		if letter != "":
			var f: = ThemeDB.fallback_font
			draw_circle(c, r - 2.0, Color(TWTokens.NIGHT_800, 0.0))
			draw_string(f, Vector2(0.0, c.y + 24.0), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, TWTokens.PAPER_300)
		draw_arc(c, r - 2.0, 0.0, TAU, 64, TWTokens.PLATE_RIM, 3.0, true)
		if flash > 0.0:
			draw_arc(c, r - 2.0, 0.0, TAU, 64, Color(TWTokens.PLATE_SPARK, flash), 6.0, true)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "TWPresence"


func configure(p_hero: String, p_outfit: String = "", p_mode: String = MODE_STANDARD) -> void:
	hero = p_hero
	outfit = p_outfit
	mode = p_mode if MODES.has(p_mode) else MODE_STANDARD
	rig_entry = V10RigCatalog.find_for(hero, outfit)
	stub = not V10RigCatalog.has_rig(hero, outfit)
	if _built:
		_unmount()
		_mount()
		_apply()


func set_screen(size: Vector2, avoid: Rect2 = Rect2(), insets: Dictionary = {}) -> void:
	_screen = size
	_avoid = avoid if avoid.size != Vector2.ZERO else standard_avoid(size)
	_insets = insets
	if _built:
		_apply()


func set_mode(m: String) -> void:
	if not MODES.has(m) or m == mode:
		return
	mode = m
	if _built:
		_apply()


func set_clock(c: Callable) -> void:
	_clock = c


func set_active(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _ready() -> void:
	_view = _View.new()
	_view.name = "View"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_frame = _Frame.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_built = true
	if hero != "":
		_mount()
	_apply()


func _exit_tree() -> void:
	unbind()


func _mount() -> void:
	if stub or rig_entry.is_empty():
		stub = true
		_portrait = TextureRect.new()
		_portrait.name = "Portrait"
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var req: = "hero_png:%s" % hero
		if TWAssets.has(req):
			_portrait.texture = TWAssets.tex(req)
		_view.add_child(_portrait)
		_frame.letter = "" if _portrait.texture != null else hero.substr(0, 1).to_upper()
		return
	# the rig is added by the catalog; handle_input = false: touches on her are OFF in a round
	rig = V10RigCatalog.mount(_view, hero, outfit, Rect2(0, 0, 720, 1280), {"show_background": false, "handle_input": false})
	if rig == null:
		stub = true
		_mount()


func _unmount() -> void:
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	rig = null
	if _portrait != null and is_instance_valid(_portrait):
		_portrait.queue_free()
	_portrait = null
	_frame.letter = ""


func _apply() -> void:
	geom = layout(_screen, _avoid, mode, _insets)
	var r: Rect2 = geom.rect
	position = r.position
	size = r.size
	visible = not bool(geom.hidden)
	_view.position = Vector2.ZERO
	_view.size = r.size
	_frame.position = Vector2.ZERO
	_frame.size = r.size
	var disc: bool = geom.disc
	_view.disc = disc
	_view.clip_children = CanvasItem.CLIP_CHILDREN_ONLY if disc else CanvasItem.CLIP_CHILDREN_DISABLED
	_view.clip_contents = not disc
	_frame.disc = disc
	var eff: String = geom.effective
	var changed: = eff != effective_mode
	effective_mode = eff
	if _portrait != null:
		_portrait.position = Vector2.ZERO
		_portrait.size = r.size
		_portrait.visible = true
	if rig != null and is_instance_valid(rig):
		var cx: = float(rig_entry.get("fit", {}).get("center_x", 700.0))
		var art_h: = ART_H
		if rig.def.has("size"):
			art_h = float(rig.def.size[1])
		var f: Dictionary = fit(r.size, eff, cx, rig.face_pivot, art_h)
		rig.scale = Vector2.ONE * float(f.scale)
		rig.position = f.position
	_view.queue_redraw()
	_frame.queue_redraw()
	if changed:
		mode_changed.emit(eff)


# ------------------------------------------------------------------ events

func bind(bus: TWBus) -> void:
	unbind()
	_bus = bus
	for k in [TWBoardEvents.MATCH, TWBoardEvents.CLEARED, TWBoardEvents.TRAY_FULL, TWBoardEvents.TRAY_WARN, EV_ULT_CAST]:
		_tokens.append(bus.subscribe(k, _on_event))   # no owner: TWBus connects tree_exiting once per subscription, which clashes on one Node; _exit_tree unbinds


func unbind() -> void:
	if _bus != null:
		for t in _tokens:
			_bus.unsubscribe(t)
	_tokens.clear()
	_bus = null


func new_round() -> void:
	tracker.reset()
	_last_t = -1000.0
	_last_prio = 0
	_last_by.clear()


func _on_event(ev: Dictionary) -> void:
	var r: = tracker.feed(ev)
	if r != "":
		play(r)


func _now() -> float:
	if _clock.is_valid():
		return float(_clock.call())
	return Time.get_ticks_msec() / 1000.0


# plays a reaction now. Returns the gesture name ("pulse" for the stub, "" when dropped)
func play(reaction: String) -> String:
	if not REACTIONS.has(reaction):
		return ""
	var now: = _now()
	var prio: int = int(PRIORITY.get(reaction, 0))
	if now - _last_t < GAP_S and prio <= _last_prio:
		dropped += 1
		return ""
	if _last_by.has(reaction) and now - float(_last_by[reaction]) < float(REPEAT_S.get(reaction, 0.0)):
		dropped += 1
		return ""
	var g: = "pulse"
	if not stub and rig != null and is_instance_valid(rig):
		g = reaction_gesture(rig_entry, reaction)
		if g == "":
			dropped += 1
			return ""
		rig.gesture(g)
	else:
		_pulse(prio)
	_last_t = now
	_last_prio = prio
	_last_by[reaction] = now
	history.append({"reaction": reaction, "gesture": g, "t_ms": int(now * 1000.0)})
	if history.size() > KEEP_LOG:
		history.pop_front()
	reaction_started.emit(reaction, g)
	return g


func _pulse(prio: int) -> void:
	if not is_inside_tree():
		return
	var tw: = create_tween()
	_view.pivot_offset = size * 0.5
	var k: = 1.0 + (0.05 + 0.0015 * prio)
	tw.tween_property(_view, "scale", Vector2(k, k), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_view, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw2: = create_tween()
	tw2.tween_method(func(v: float) -> void:
		_frame.flash = v
		_frame.queue_redraw(), 0.9, 0.0, 0.45)


# ------------------------------------------------------------------ measurement (the P41 method, structure side)

# {draw_items, textures, tex_mem_rgba_mb, tex_mem_rgba_mips_mb, rigs} of what this presence holds. draw_items is an upper bound
# (one canvas item per visible textured node, no batching) - the P41 "draw_items_upper" - and the real GL count is lower.
func measure() -> Dictionary:
	var texs: = {}
	var items: = 0
	var rigs: = 0
	var stack: Array = [_view]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is V10LiveRig:
			rigs += 1
		var t: Texture2D = null
		if n is Polygon2D:
			t = (n as Polygon2D).texture
			if (n as Polygon2D).visible and t != null:
				items += 1
		elif n is Sprite2D:
			t = (n as Sprite2D).texture
			if t != null:
				items += 1
			var m: Material = (n as Sprite2D).material
			if m is ShaderMaterial:
				var it = (m as ShaderMaterial).get_shader_parameter("iris_tex")
				if it is Texture2D:
					texs[it.get_rid()] = it
		elif n is TextureRect and (n as TextureRect).texture != null:
			t = (n as TextureRect).texture
			items += 1
		if t != null:
			texs[t.get_rid()] = t
	var bytes: = 0.0
	for k in texs:
		var tx: Texture2D = texs[k]
		bytes += float(tx.get_width()) * float(tx.get_height()) * 4.0
	return {"draw_items": items + 1, "textures": texs.size(), "tex_mem_rgba_mb": bytes / 1048576.0,
			"tex_mem_rgba_mips_mb": bytes * 4.0 / 3.0 / 1048576.0, "rigs": rigs}
