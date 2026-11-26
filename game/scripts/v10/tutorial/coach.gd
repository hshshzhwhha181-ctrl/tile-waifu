class_name V10Coach
extends Control
# Coach mark of the 0.10 tutorial (README §2.4; UX §2 п.7, §3.5, §6.3; HUD_V2 §9.2 «коучмарк-спотлайт с одной
# строкой Caveat, без карточки»). «Тишина и лак»: a night dim with ONE window, a single gold hairline on its edge,
# the heroine's line in Caveat 30 straight on the scene (no bubble, no box), her name as a gold overline.
#
#   var c := V10Coach.new(); V10Coach.layer(main).add_child(c)
#   c.finished.connect(func(r: String) -> void: ...)   # "target" | "tap" | "timeout" | "skip" | "lost"
#   c.show_step({"line": "…", "speaker": "mc", "target": "home.play", "mode": "tap"})
#   c.complete()                                        # the orchestrator saw the player do it
#
# spec keys: line, speaker (hero id | "partner"), portrait (bool), target (tut_id) | rect (Rect2), radius,
#   mode "tap"|"do"|"wait"|"ring", dim (0.72 hubs / 0.45 match), place "auto"|"above"|"below"|"hero",
#   anchor (Rect2, for place "hero"), avoid ([Rect2]), hold (4.0), timeout (8.0; <= 0 = none), skippable (bool),
#   root (Node to search the target under), ctx ("hub"|"work"|"match", optional: margins 32/24, width 560/472).
# Modes:
#   tap  – dim + window. Any tap closes: outside → "tap"; a tap in the window reaches the game too → "target".
#   do   – dim + window. Only the window lets taps through (_has_point is false inside it); closes on complete()
#          or a tap in the window ("target"). A tap outside restarts the tap ring (no error sound).
#   wait – no dim, no blocking (mouse IGNORE), a thin gold outline; the line fades by itself after `hold` ("timeout").
#   ring – no text, no dim, no blocking: the contracting tap ring on the target until complete()/tap/timeout.
# Never locks the player: a target that is not found for 1.5 s turns the step into «wait» and it ends with "lost"
# after `hold`; tap/do/ring end with "timeout" after `timeout` s. fx_level=min: every appearance is a 120 ms fade,
# no «вдох» of the window, no tap ring (a static outline instead).

signal finished(result: String)

const LAYER: = 92
const SPOT: = preload("res://scripts/v10/tutorial/spotlight.gdshader")
const MODES: = ["tap", "do", "wait", "ring"]
const PAD: = 8.0  # window around the target
const GAP: = 24.0  # text block ↔ window
const CLEAR: = 16.0  # the block never comes closer than this to the window
const LOST_T: = 1.5
const GUARD_T: = 0.3  # taps right after the step appears are not read as «close»
const WRITE_T: = 0.4  # pen
const FADE_T: = 0.3  # the line goes out
const IN_T: = 0.24  # dim in / «вдох»
const MIN_T: = 0.12  # fx_level=min: every appearance
const RING_EVERY: = 1.6
const RING_T: = 0.9
const SKIP_SURE_T: = 3.0
const LINE_H: = 36.0  # Caveat 30 line (V10Type.LINE[30])
const HEAD_H: = 24.0  # overline 20 + 4
const POR: = 56.0
const POR_GAP: = 16.0

var spec: = {}
var mode: = ""  # effective mode ("wait" after the target was lost)

var _showing: = false
var _gen: = 0
var _t: = 0.0
var _revealed: = false  # the window was found (or there is none) and the step is on screen
var _degraded: = false
var _seen_t: = 0.0  # last time the target was found
var _search_cd: = 0.0
var _last_ok: = false
var _end_at: = -1.0
var _end_reason: = ""
var _has_hole: = false
var _hit: = Rect2()  # exact target rect (taps pass through here)
var _hole: = Rect2()  # the window (target + PAD)
var _rad: = 4.0
var _vis: = Rect2()  # drawn window (smoothed)
var _vis_rad: = 4.0
var _breath: = 0.0  # 1 → 0: window scale 1.12 → 1.0
var _dim_amt: = 0.0
var _rim_a: = 0.0
var _dim_a: = 0.0
var _ring_on: = false
var _ring_t0: = 0.0
var _written: = false
var _skip_armed: = -1.0
var _placed_for: = Rect2(-9999, -9999, 0, 0)
var _line_text: = ""
var _speaker: = ""
var _lines: = 0
var _last_tap_frame: = -1
var _hole_down: = false
var _last_vs: = Vector2.ZERO

var _dim: ColorRect
var _mat: ShaderMaterial
var _fx: Control
var _block: Control
var _por: Control
var _por_tex: Texture2D
var _por_region: = Rect2()
var _name_l: Label
var _line_l: Label
var _skip: Control
var _skip_l: Label
var _tw_dim: Tween
var _tw_block: Tween
var _tw_move: Tween
var _tw_skip: Tween


static func layer(host: Node) -> CanvasLayer:
	var root: = host.get_tree().root if host != null and host.is_inside_tree() else null
	if root == null:
		return null
	var l: = root.get_node_or_null("V10TutLayer") as CanvasLayer
	if l == null:
		l = CanvasLayer.new()
		l.name = "V10TutLayer"
		l.layer = LAYER
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(l)
	return l


func _init() -> void:
	name = "V10Coach"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(_showing or _dim_amt > 0.0)


# ------------------------------------------------------------------ public API

func show_step(s: Dictionary) -> void:
	_gen += 1
	var was_dim: = _dim_amt > 0.01 and _has_hole
	spec = s.duplicate()
	mode = String(s.get("mode", "tap"))
	if not mode in MODES:
		mode = "tap"
	_showing = true
	_revealed = false
	_degraded = false
	_written = false
	_t = 0.0
	_seen_t = 0.0
	_search_cd = 0.0
	_last_ok = false
	_end_at = -1.0
	_end_reason = ""
	_ring_on = false
	_hole_down = false
	_skip_armed = -1.0
	_line_text = String(s.get("line", "")) if mode != "ring" else ""
	_speaker = _speaker_id(String(s.get("speaker", "")))
	_has_hole = false
	visible = true
	_kill(_tw_dim)
	var tid: = String(s.get("target", ""))
	var r = s.get("rect", null)
	if r is Rect2 and (r as Rect2).has_area():
		_set_hole(r, float(s.get("radius", 4.0)))
	elif tid != "":
		_track(true)
	if _has_hole and not was_dim:
		_vis = _hole
		_vis_rad = _rad
	_apply_mouse()
	set_process(true)
	if _has_hole or tid == "" or (r is Rect2 and (r as Rect2).has_area()):
		_reveal()
	else:
		# the target is not on screen yet: nothing blocks and nothing is dimmed while _process looks for it
		# (LOST_T), then the step degrades to a passive line
		_tw_dim = create_tween()
		_tw_dim.tween_property(self, "_dim_amt", 0.0, MIN_T)
		if _block.visible:
			_kill(_tw_block)
			_tw_block = create_tween()
			_tw_block.tween_property(_block, "modulate:a", 0.0, MIN_T)
		_skip.visible = false


func complete(result: = "target") -> void:
	if not _showing:
		return
	_end(result)


func is_showing() -> bool:
	return _showing


func current_rect() -> Rect2:
	return _hole if _has_hole and not _degraded else Rect2()


# Everything a test or the bot needs to know about the step on screen.
func debug_state() -> Dictionary:
	var tr: = Rect2()
	if _block.visible and _line_text != "":
		tr = Rect2(_block.position, _block.size)
	return {"mode": mode if _showing else "", "hole": current_rect(), "text_rect": tr, "line": _line_text,
		"lines": _lines, "skippable": _showing and _skip.visible, "animated": 1 if _ring_on and _fx_ok() else 0,
		"revealed": _revealed, "speaker": _speaker, "dim": _dim_a * _dim_amt, "skip_rect": Rect2(_skip.position, _skip.size)
			if _skip.visible else Rect2()}


# ------------------------------------------------------------------ build

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color.WHITE
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SPOT
	_mat.set_shader_parameter("dim_color", Color(V10DS.NIGHT_900, 0.0))
	_mat.set_shader_parameter("rim_color", Color(V10DS.GOLD_500, 0.0))
	_mat.set_shader_parameter("rim_w", 1.5)
	_mat.set_shader_parameter("soft", 10.0)
	_mat.set_shader_parameter("amount", 0.0)
	_dim.material = _mat
	_dim.visible = false
	add_child(_dim)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_block = Control.new()
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.visible = false
	add_child(_block)
	_por = Control.new()
	_por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_por.size = Vector2(POR, POR)
	_por.draw.connect(_draw_portrait)
	_block.add_child(_por)
	_name_l = V10Type.label("", "overline", 15, V10DS.GOLD_500, true)
	_name_l.clip_text = false
	_block.add_child(_name_l)
	_line_l = V10Type.label("", "hand", 30, V10DS.PAPER_100, true)
	_line_l.clip_text = false
	_line_l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_line_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_block.add_child(_line_l)
	_skip = Control.new()
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.visible = false
	_skip.set_meta("ux_role", "tertiary")
	_skip.set_meta("tut_id", "tut.skip")
	_skip.gui_input.connect(_skip_input)
	add_child(_skip)
	_skip_l = V10Type.label(V10TutLines.ui("skip"), "ui", 18, V10DS.PAPER_500)
	_skip_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.add_child(_skip_l)


# ------------------------------------------------------------------ show / end

func _reveal() -> void:
	if _revealed or not _showing:
		return
	_revealed = true
	_seen_t = _t
	var fx: = _fx_ok()
	var dur: = IN_T if fx else MIN_T
	# dim and hairline per mode
	match mode:
		"tap", "do":
			_dim_a = clampf(float(spec.get("dim", 0.72)), 0.0, 0.9)
			_rim_a = 0.9 if _has_hole else 0.0
		"wait":
			_dim_a = 0.0
			_rim_a = 0.7 if _has_hole else 0.0
		"ring":
			_dim_a = 0.0
			_rim_a = 0.0
	_dim.visible = true
	_kill(_tw_dim)
	_tw_dim = create_tween()
	_tw_dim.tween_property(self, "_dim_amt", 1.0, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if _has_hole and fx and _dim_amt < 0.05:
		_breath = 1.0
		_tw_dim.parallel().tween_property(self, "_breath", 0.0, IN_T).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if mode in ["do", "ring"] and _has_hole:
		_ring_on = true
		_ring_t0 = _t + (0.25 if fx else 0.0)
	_show_line()
	_show_skip()
	_apply_mouse()
	if mode == "wait":
		_end_at = _t + WRITE_T + _hold()
		_end_reason = "timeout"


func _end(result: String) -> void:
	if not _showing:
		return
	_showing = false
	_ring_on = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx: = _fx_ok()
	_kill(_tw_dim)
	_tw_dim = create_tween()
	_tw_dim.tween_property(self, "_dim_amt", 0.0, IN_T if fx else MIN_T)
	_kill(_tw_block)
	if _block.visible:
		_tw_block = create_tween()
		_tw_block.tween_property(_block, "modulate:a", 0.0, FADE_T if fx else MIN_T)
	_hide_skip()
	_fx.queue_redraw()
	finished.emit(result)


func _degrade() -> void:
	if _degraded or not _showing:
		return
	_degraded = true
	mode = "wait"
	_ring_on = false
	if not _revealed:
		_revealed = true
		_has_hole = false
		_dim_a = 0.0
		_rim_a = 0.0
		_dim.visible = true
		_show_line()
		_show_skip()
	else:
		_kill(_tw_dim)
		_tw_dim = create_tween()
		_tw_dim.tween_property(self, "_dim_amt", 0.0, IN_T if _fx_ok() else MIN_T)
	_apply_mouse()
	_end_at = _t + (WRITE_T + _hold() if _line_text != "" else 0.0)
	_end_reason = "lost"


func _hold() -> float:
	return maxf(1.0, float(spec.get("hold", 4.0)))


func _apply_mouse() -> void:
	var block: = _showing and _revealed and not _degraded and mode in ["tap", "do"]
	mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE


# ------------------------------------------------------------------ the line

func _speaker_id(s: String) -> String:
	if s == "partner":
		var S = G.S if G != null else null
		return String(S.get("partner", "mc")) if S is Dictionary else "mc"
	return s


func _show_line() -> void:
	_kill(_tw_block)
	_lines = 0
	if _line_text == "":
		_block.visible = false
		_written = true
		return
	if _block.visible and _block.modulate.a > 0.05 and _written and not bool(spec.get("instant", false)):
		# a new line over an old one: the old one goes out first (120 ms), then the pen writes the new one
		_tw_block = create_tween()
		_tw_block.tween_property(_block, "modulate:a", 0.0, MIN_T)
		_tw_block.tween_callback(_write_line.bind(_gen))
	else:
		_write_line(_gen)


func _write_line(g: int) -> void:
	if g != _gen or not _showing:
		return
	var fx: = _fx_ok()
	var nm: = V10TutLines.hero_name(_speaker) if _speaker != "" else ""
	_name_l.text = nm.to_upper()
	_name_l.visible = nm != ""
	_setup_portrait()
	_line_l.text = _line_text
	_placed_for = Rect2(-9999, -9999, 0, 0)
	_block.visible = true
	_place(false)
	_kill(_tw_block)
	_tw_block = create_tween()
	if fx:
		_block.modulate.a = 1.0
		_name_l.modulate.a = 0.0
		_por.modulate.a = 0.0
		_line_l.visible_ratio = 0.0
		_tw_block.tween_property(_name_l, "modulate:a", 1.0, V10DS.T_OUT)
		_tw_block.parallel().tween_property(_por, "modulate:a", 1.0, V10DS.T_OUT)
		_tw_block.parallel().tween_property(_line_l, "visible_ratio", 1.0, WRITE_T)
	else:
		_block.modulate.a = 0.0
		_name_l.modulate.a = 1.0
		_por.modulate.a = 1.0
		_line_l.visible_ratio = 1.0
		_tw_block.tween_property(_block, "modulate:a", 1.0, MIN_T)
	_tw_block.tween_callback(func() -> void: _written = true)
	_sfx()


func _finish_write() -> void:
	_kill(_tw_block)
	_block.modulate.a = 1.0
	_name_l.modulate.a = 1.0
	_por.modulate.a = 1.0
	_line_l.visible_ratio = 1.0
	_written = true


func _sfx() -> void:
	var bank: = V10Hud2Util.opt_class("V10SfxBank")
	if bank != null and bank.has_method("play"):  # V10SfxBank (v10-audio); silence without it
		bank.call("play", "notify", {"db": -10})


func _setup_portrait() -> void:
	_por_tex = null
	_por.visible = false
	if not bool(spec.get("portrait", false)) or _speaker == "":
		return
	# the heroine is already on screen → no second face (README §2.4)
	var root: = _root()
	for id in ["home.hero", "match.hero"]:
		if V10TutTarget.find(root, id).ok:
			return
	var path: = "res://assets/v08/emotions/%s_happy.webp" % _speaker
	if not ResourceLoader.exists(path):
		return
	var tex: = load(path) as Texture2D
	if tex == null:
		return
	_por_tex = tex
	var face: = V8Art.emotion_face(_speaker, "happy")
	var fw: = V8Art.emotion_face_w(_speaker, "happy")
	var side: = fw * 1.6
	_por_region = Rect2(face + Vector2(-side * 0.5, -side * 0.5 + fw * 0.08), Vector2(side, side))
	_por.visible = true
	_por.queue_redraw()


func _draw_portrait() -> void:
	if _por_tex == null:
		return
	var c: = Vector2(POR, POR) * 0.5
	var r: = POR * 0.5 - 1.0
	var pts: = PackedVector2Array()
	var uvs: = PackedVector2Array()
	var ts: = Vector2(_por_tex.get_size())
	for i in 64:
		var a: = TAU * i / 64.0
		var d: = Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append((_por_region.position + (d * 0.5 + Vector2(0.5, 0.5)) * _por_region.size) / ts)
	_por.draw_colored_polygon(pts, Color.WHITE, uvs, _por_tex)
	# the edge is the one hairline of the block (gold.700 at the hairline alpha, a touch stronger on the dim)
	_por.draw_arc(c, r + 0.5, 0.0, TAU, 72, Color(V10DS.GOLD_700, 0.8), 1.5, true)


# ------------------------------------------------------------------ placement

func _ctx() -> String:
	var c: = String(spec.get("ctx", ""))
	if c in ["hub", "work", "match"]:
		return c
	if String(spec.get("place", "auto")) == "hero":
		return "match"
	var m: = V10Tutorial.main_node()
	if m != null and str(m.get("screen_id")) == "play":
		return "match"
	return "hub"


func _column(vs: Vector2) -> Rect2:
	var ins: = V10Hud2Util.safe_insets(vs)
	if _ctx() == "match" and vs.x > 760.0:
		return Rect2(24.0 + float(ins.get("left", 0.0)), float(ins.top) + 16.0,
			vs.x - 48.0 - float(ins.get("left", 0.0)) - float(ins.get("right", 0.0)),
			vs.y - float(ins.top) - float(ins.bottom) - 32.0)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	var m: = 32.0 if _ctx() == "hub" else 24.0
	var w: = minf(720.0, vs.x)
	return Rect2(cx + m + float(ins.get("left", 0.0)), float(ins.top) + 16.0,
		w - m * 2.0 - float(ins.get("left", 0.0)) - float(ins.get("right", 0.0)),
		vs.y - float(ins.top) - float(ins.bottom) - 32.0)


func _avoid() -> Array:
	var out: = []
	var a = spec.get("avoid", [])
	if a is Array:
		for r in a:
			if r is Rect2 and (r as Rect2).has_area():
				out.append(r)
	if _ctx() == "match":
		# a match line never lies over the field, the tray or the help row (HUD_V2 §8.1, README §1)
		var root: = _root()
		var vs: = get_viewport_rect().size
		for id in ["match.board", "match.tray", "match.help"]:
			if id == String(spec.get("target", "")):
				continue
			var f: = V10TutTarget.find(root, id)
			# a full-screen holder (e.g. hud.help_row is viewport-sized) says nothing about where its parts are
			if f.ok and (f.rect as Rect2).get_area() < vs.x * vs.y * 0.75:
				out.append(f.rect)
	return out


# Text width for `w` px, balanced so the lines are of similar length: Vector2(width, lines).
func _measure(w: float) -> Vector2:
	var n: = V10Type.lines_needed(_line_text, "hand", 30, w)
	if n <= 1:
		return Vector2(minf(w, ceilf(V10Type.text_w(_line_text, "hand", 30)) + 6.0), 1)
	var lo: = w * 0.4
	var hi: = w
	for i in 12:
		var mid: = (lo + hi) * 0.5
		if V10Type.lines_needed(_line_text, "hand", 30, mid) <= n:
			hi = mid
		else:
			lo = mid
	return Vector2(minf(w, ceilf(hi) + 8.0), n)


# Places the block (portrait · overline · line): above/below/beside the window with GAP, inside the safe column,
# never closer than CLEAR to the window and never over an `avoid` rect. place "hero" tries `anchor` first (narrower
# widths before leaving it). If nothing is clean, the least-overlapping spot wins (the line is never dropped).
func _place(animate: bool) -> void:
	if _line_text == "":
		return
	var vs: = get_viewport_rect().size
	var col: = _column(vs)
	var avoid: = _avoid()
	var hole_g: = _hole.grow(CLEAR) if _has_hole and not _degraded else Rect2()
	var por_w: = (POR + POR_GAP) if _por.visible else 0.0
	var head: = HEAD_H if _name_l.visible else 0.0
	var maxw: = minf(472.0 if _ctx() == "match" else 560.0, col.size.x)
	var best: = {"s": INF}
	var anchor = spec.get("anchor", null)
	if anchor is Rect2 and (anchor as Rect2).has_area() and (String(spec.get("place", "auto")) == "hero" or _ctx() == "match"):
		var a: Rect2 = anchor
		var w0: = minf(maxw, maxf(a.size.x, 224.0))
		# UX §4.1 п.9: ≤ 2 lines; a 3rd line only if the zone is too narrow for any clean 2-line spot
		for max_a in [2, 3]:
			if float(best.s) <= 0.0:
				break
			var w: = w0
			while w >= 224.0:
				_try(best, w, por_w, head, max_a, func(bs: Vector2) -> Array: return _anchor_cands(a, bs, avoid), col, hole_g, avoid)
				if float(best.s) <= 0.0:
					break
				w -= 16.0
	# ≤ 2 lines anywhere clean; 3–4 lines only as the last resort before overlapping something
	for max_l in [2, 3, 4]:
		if float(best.s) <= 0.0:
			break
		for w2 in [maxw, 472.0, 400.0, 344.0, 288.0, 256.0, 224.0]:
			if float(w2) > maxw:
				continue
			_try(best, float(w2), por_w, head, max_l, func(bs: Vector2) -> Array: return _candidates(bs, col, vs, avoid), col,
					hole_g, avoid)
			if float(best.s) <= 0.0:
				break
	if not best.has("r"):
		var m0: = _measure(maxw - por_w)
		best = {"s": 1.0, "m": m0, "r": Rect2(col.position, Vector2(por_w + m0.x, head + m0.y * LINE_H))}
	var m: Vector2 = best.m
	var rr: Rect2 = best.r
	_lines = int(m.y)
	_name_l.position = Vector2(por_w, 0)
	_name_l.size = Vector2(maxf(m.x, 160.0), 20)
	_line_l.position = Vector2(por_w, head)
	_line_l.size = Vector2(m.x, m.y * LINE_H + 4.0)
	_por.position = Vector2.ZERO
	_block.size = rr.size
	_placed_for = _hole if _has_hole else Rect2()
	if animate and _block.visible and _fx_ok() and not bool(spec.get("instant", false)):
		_kill(_tw_move)
		_tw_move = create_tween()
		_tw_move.tween_property(_block, "position", rr.position, V10DS.T_IN).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		_kill(_tw_move)
		_block.position = rr.position
	_place_skip()


func _try(best: Dictionary, w: float, por_w: float, head: float, max_lines: int, cands: Callable, col: Rect2,
		hole_g: Rect2, avoid: Array) -> void:
	var m: = _measure(w - por_w)
	if m.y > max_lines:
		return
	var bs: = Vector2(por_w + m.x, maxf(POR if _por.visible else 0.0, head + m.y * LINE_H))
	for p in cands.call(bs):
		var r: = Rect2(Vector2(roundf(p.x), roundf(p.y)), bs)
		var sc: = _score(r, col, hole_g, avoid)
		if sc < float(best.s):
			best.s = sc
			best.r = r
			best.m = m
		if sc <= 0.0:
			return


func _anchor_cands(a: Rect2, bs: Vector2, avoid: Array) -> Array:
	var xs: = [a.position.x, a.end.x - bs.x]
	for r in avoid:
		if (r as Rect2).end.y > a.position.y and (r as Rect2).position.y < a.end.y:
			xs.append((r as Rect2).end.x + 8.0)
			xs.append((r as Rect2).position.x - 8.0 - bs.x)
	var ys: = [a.position.y + maxf(0.0, (a.size.y - bs.y) * 0.5), a.position.y, a.end.y - bs.y]
	# just clear of the window when it sits right above the anchor (the tray above the heroine zone)
	if _has_hole and not _degraded:
		var hg: = _hole.grow(CLEAR)
		if hg.end.y > a.position.y and hg.position.y < a.position.y:
			ys.append(ceilf(hg.end.y) + 1.0)
	var out: = []
	for y in ys:
		for x in xs:
			out.append(Vector2(x, y))
	return out


func _candidates(bs: Vector2, col: Rect2, vs: Vector2, avoid: Array) -> Array:
	var out: = []
	var place: = String(spec.get("place", "auto"))
	var base_y: = vs.y * 0.62
	var x_lo: = col.position.x
	var x_hi: = maxf(col.position.x, col.end.x - bs.x)
	if _has_hole and not _degraded:
		var h: = _hole
		var sides: = ["below", "above"]
		if place == "above" or (place != "below" and h.get_center().y > vs.y * 0.5):
			sides = ["above", "below"]
		for side in sides:
			var y: = h.end.y + GAP if side == "below" else h.position.y - GAP - bs.y
			for x in [h.position.x, col.position.x, h.get_center().x - bs.x * 0.5, h.end.x - bs.x, col.end.x - bs.x]:
				out.append(Vector2(clampf(float(x), x_lo, x_hi), y))
		# beside the window (small targets near an edge: lanterns, a nav cell, a disc)
		for y2 in [h.position.y, h.get_center().y - bs.y * 0.5, h.end.y - bs.y]:
			out.append(Vector2(h.end.x + GAP, y2))
			out.append(Vector2(h.position.x - GAP - bs.x, y2))
		base_y = out[0].y
	else:
		out.append(Vector2(col.position.x, base_y))
	# last: scan the column outward from the preferred height, at the column edges and next to every avoid rect
	var xs: = [x_lo, x_hi]
	for r in avoid:
		xs.append(clampf((r as Rect2).end.x + 8.0, x_lo, x_hi))
		xs.append(clampf((r as Rect2).position.x - 8.0 - bs.x, x_lo, x_hi))
	var step: = 16.0
	var n: = int(col.size.y / step) + 1
	for i in n:
		for sg: float in [1.0, -1.0]:
			var y3: = base_y + sg * step * i
			if y3 < col.position.y - 0.5 or y3 + bs.y > col.end.y + 0.5:
				continue
			for x2 in xs:
				out.append(Vector2(x2, y3))
	return out


func _score(r: Rect2, col: Rect2, hole_g: Rect2, avoid: Array) -> float:
	var s: = 0.0
	var inside: = r.intersection(col)
	s += (r.get_area() - inside.get_area()) * 4.0
	if hole_g.has_area() and r.intersects(hole_g):
		s += r.intersection(hole_g).get_area() * 8.0 + 1.0
	for a in avoid:
		if r.intersects(a):
			s += r.intersection(a).get_area() * 6.0 + 1.0
	return s


# ------------------------------------------------------------------ skip («Пропустить» → «Точно пропустить?»)

func _show_skip() -> void:
	var on: = bool(spec.get("skippable", false)) and _showing
	_kill(_tw_skip)
	if not on:
		_skip.visible = false
		return
	_skip_set(V10TutLines.ui("skip"), V10DS.PAPER_500)
	_skip.visible = true
	_skip.modulate.a = 0.0
	_tw_skip = create_tween()
	_tw_skip.tween_property(_skip, "modulate:a", 1.0, V10DS.T_IN if _fx_ok() else MIN_T)


func _hide_skip() -> void:
	if not _skip.visible:
		return
	_kill(_tw_skip)
	_tw_skip = create_tween()
	_tw_skip.tween_property(_skip, "modulate:a", 0.0, V10DS.T_OUT)
	_tw_skip.tween_callback(func() -> void:
		if not _showing:
			_skip.visible = false)


func _skip_set(text: String, col: Color) -> void:
	_skip_l.text = text
	_skip_l.label_settings = V10Type.settings("ui", 18, col)
	_place_skip()


func _place_skip() -> void:
	var vs: = get_viewport_rect().size
	var ins: = V10Hud2Util.safe_insets(vs)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	var tw: = ceilf(V10Type.text_w(_skip_l.text, "ui", 18))
	var sz: = Vector2(maxf(V10DS.HIT_MIN, tw + 48.0), V10DS.HIT_MIN)
	var right: = cx + minf(720.0, vs.x) - 8.0
	var top: = float(ins.top) + 4.0
	var bottom: = vs.y - float(ins.bottom) - 4.0 - sz.y
	var cands: = [Vector2(right - sz.x, top), Vector2(cx + 8.0, top), Vector2(right - sz.x, bottom), Vector2(cx + 8.0, bottom)]
	var block: = Rect2(_block.position, _block.size) if _block.visible else Rect2()
	var hole_g: = _hole.grow(CLEAR) if _has_hole and not _degraded else Rect2()
	var pick: Vector2 = cands[0]
	for p in cands:
		var r: = Rect2(p, sz)
		var bad: = (hole_g.has_area() and r.intersects(hole_g)) or (block.has_area() and r.intersects(block))
		if not bad:
			for a in _avoid():
				if r.intersects(a):
					bad = true
					break
		if not bad:
			pick = p
			break
	_skip.position = pick
	_skip.size = sz
	_skip_l.position = Vector2(0, 0)
	_skip_l.size = Vector2(sz.x - 24.0, sz.y)


func _skip_input(e: InputEvent) -> void:
	if not _showing or not _is_release(e):
		if _is_press(e):
			_skip.accept_event()
		return
	_skip.accept_event()
	if not _new_tap():
		return
	if _skip_armed >= 0.0 and _t - _skip_armed <= SKIP_SURE_T:
		_end("skip")
		return
	_skip_armed = _t
	_skip_set(V10TutLines.ui("skip_sure"), V10DS.PAPER_100)


# ------------------------------------------------------------------ input

func _has_point(p: Vector2) -> bool:
	if not _showing or not _revealed or _degraded or not mode in ["tap", "do"]:
		return false
	if _has_hole and _hit.has_point(p):
		return false  # the window lets the tap through to the game
	return true


func _gui_input(e: InputEvent) -> void:
	if not _showing:
		return
	if _is_press(e):
		accept_event()
		return
	if not _is_release(e):
		return
	accept_event()
	if not _new_tap() or _t < GUARD_T:
		return
	if not _written:
		_finish_write()
		return
	if mode == "tap":
		_end("tap")
	elif mode == "do":
		_ring_t0 = _t  # a gentle reminder: the ring runs again at once (no error sound, UX §7.4)


func _input(e: InputEvent) -> void:
	if not _showing or not _revealed or _degraded or not _has_hole or not mode in ["tap", "do", "ring"]:
		return
	var press: = _is_press(e)
	var rel: = _is_release(e)
	if not press and not rel:
		return
	var p: = (make_input_local(e) as InputEventMouse).position if e is InputEventMouse else _touch_pos(e)
	if press:
		_hole_down = _hit.has_point(p)
	elif rel and _hole_down:
		_hole_down = false
		if _hit.grow(12.0).has_point(p):
			# both press and release reached the underlying control; close the coach right after this frame
			_on_hole_tap.call_deferred(_gen)


func _touch_pos(e: InputEvent) -> Vector2:
	var l: = make_input_local(e)
	if l is InputEventScreenTouch:
		return (l as InputEventScreenTouch).position
	return Vector2(-1, -1)


func _on_hole_tap(g: int) -> void:
	if g == _gen and _showing:
		_end("target")


func _is_press(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (e as InputEventMouseButton).pressed
	if e is InputEventScreenTouch:
		return (e as InputEventScreenTouch).pressed
	return false


func _is_release(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed
	if e is InputEventScreenTouch:
		return not (e as InputEventScreenTouch).pressed
	return false


# A touch and its emulated mouse click arrive in the same frame: read only one of them.
func _new_tap() -> bool:
	var f: = Engine.get_process_frames()
	if f == _last_tap_frame:
		return false
	_last_tap_frame = f
	return true


# ------------------------------------------------------------------ per frame

func _process(dt: float) -> void:
	if _showing:
		_t += dt
		_track(false)
		if _showing and _end_at >= 0.0 and _t >= _end_at:
			_end(_end_reason)
		elif _showing and mode in ["tap", "do", "ring"] and not _degraded:
			var to: = float(spec.get("timeout", 8.0))
			if to > 0.0 and _t >= to:
				_end("timeout")
		if _showing and _skip_armed >= 0.0 and _t - _skip_armed > SKIP_SURE_T:
			_skip_armed = -1.0
			_skip_set(V10TutLines.ui("skip"), V10DS.PAPER_500)
	# smooth the window towards the target
	if _has_hole:
		var k: = 1.0 - exp(-16.0 * dt)
		if not _vis.has_area():
			_vis = _hole
			_vis_rad = _rad
		_vis = Rect2(_vis.position.lerp(_hole.position, k), _vis.size.lerp(_hole.size, k))
		_vis_rad = lerpf(_vis_rad, _rad, k)
	var vs: = get_viewport_rect().size
	if _showing and _block.visible and (vs != _last_vs or (_has_hole and not _degraded and
			(_hole.position.distance_to(_placed_for.position) > 8.0 or _hole.size.distance_to(_placed_for.size) > 8.0))):
		_place(true)
	_last_vs = vs
	_update_shader(vs)
	_fx.queue_redraw()
	if not _showing and _dim_amt <= 0.001 and (_tw_block == null or not _tw_block.is_running()):
		_dim.visible = false
		_block.visible = false
		_has_hole = false
		_vis = Rect2()
		set_process(false)


func _track(first: bool) -> void:
	if _degraded:
		return
	var r = spec.get("rect", null)
	if r is Rect2 and (r as Rect2).has_area():
		return
	var id: = String(spec.get("target", ""))
	if id == "":
		return
	if not first:
		_search_cd -= get_process_delta_time()
	# follow every frame while the target is there (the lookup is cached); look again 10×/s while it is not
	if first or _last_ok or _search_cd <= 0.0:
		var res: = V10TutTarget.find(_root(), id)
		_last_ok = bool(res.ok)
		if _last_ok:
			_set_hole(res.rect, float(res.radius))
			_seen_t = _t
			if not _revealed and not first:
				_reveal()
		else:
			_search_cd = 0.1
	if not first and _t - _seen_t >= LOST_T:
		_degrade()


func _set_hole(r: Rect2, radius: float) -> void:
	var loc: = r
	loc.position -= get_global_rect().position if is_inside_tree() else Vector2.ZERO
	_hit = loc
	_hole = loc.grow(PAD)
	_rad = clampf(radius + PAD, 0.0, minf(_hole.size.x, _hole.size.y) * 0.5)
	_has_hole = true


func _root() -> Node:
	var r = spec.get("root", null)
	if r is Node and is_instance_valid(r):
		return r
	var m: = V10Tutorial.main_node()
	if m != null:
		return m
	return get_tree().root if is_inside_tree() else null


func _update_shader(vs: Vector2) -> void:
	_mat.set_shader_parameter("size_px", size if size.x > 1.0 else vs)
	var h: = Rect2()
	if _has_hole:
		var s: = 1.0 + 0.12 * _breath
		var c: = _vis.get_center()
		h = Rect2(c - _vis.size * s * 0.5, _vis.size * s)
	_mat.set_shader_parameter("hole", Vector4(h.position.x, h.position.y, h.size.x, h.size.y))
	_mat.set_shader_parameter("radius", _vis_rad * (1.0 + 0.12 * _breath))
	_mat.set_shader_parameter("dim_color", Color(V10DS.NIGHT_900, _dim_a))
	_mat.set_shader_parameter("rim_color", Color(V10DS.GOLD_500, _rim_a))
	_mat.set_shader_parameter("amount", _dim_amt)
	# the soft shade behind the line follows the block (and its fade); no edge, no card
	var cr: = Rect2()
	if _block.visible and _line_text != "":
		cr = Rect2(_block.position, _block.size).grow_individual(12.0, 4.0, 12.0, 4.0)
	_mat.set_shader_parameter("calm", Vector4(cr.position.x, cr.position.y, cr.size.x, cr.size.y))
	_mat.set_shader_parameter("calm_a", clampf(_dim_a + 0.16, 0.5, 0.86) * _block.modulate.a)


# The tap ring (do / ring): gold.300, 2 px, contracts r+28 → r+6 in 900 ms, once every 1.6 s while we wait.
# fx_level=min: no motion — a static outline at r+6.
func _draw_fx() -> void:
	if not _showing or not _ring_on or not _has_hole or _degraded:
		return
	if not _fx_ok():
		_outline(_hit.grow(6.0), _rad - PAD + 6.0, Color(V10DS.GOLD_300, 0.9), 2.0)
		return
	var ph: = _t - _ring_t0
	if ph < 0.0:
		return
	ph = fmod(ph, RING_EVERY)
	if ph > RING_T:
		return
	var k: = ph / RING_T
	var e: = 1.0 - pow(1.0 - k, 3.0)
	var g: = lerpf(28.0, 6.0, e)
	var a: = minf(1.0, k * 6.0) * (1.0 - smoothstep(0.55, 1.0, k))
	var c: = _hit.get_center() + (_vis.get_center() - _hole.get_center())
	var rr: = Rect2(c - _hit.size * 0.5, _hit.size).grow(g)
	_outline(rr, maxf(0.0, _rad - PAD) + g, Color(V10DS.GOLD_300, 0.95 * a), 2.0)


func _outline(r: Rect2, rad: float, col: Color, w: float) -> void:
	var rd: = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var pts: = PackedVector2Array()
	var corners: = [[Vector2(r.end.x - rd, r.position.y + rd), -PI * 0.5], [Vector2(r.end.x - rd, r.end.y - rd), 0.0],
		[Vector2(r.position.x + rd, r.end.y - rd), PI * 0.5], [Vector2(r.position.x + rd, r.position.y + rd), PI]]
	for c in corners:
		for i in 9:
			var a: float = float(c[1]) + PI * 0.5 * i / 8.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rd)
	pts.append(pts[0])
	_fx.draw_polyline(pts, col, w, true)


# ------------------------------------------------------------------ helpers

func _fx_ok() -> bool:
	return V10Hud2Util.fx_level() != "min"


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
