class_name V10ComboShowcase
extends Control

# V10ComboShowcase — «она появляется при комбо» (docs/HUD_V2.md §7). The heroine bursts in large, in a pose,
# with her light and petals, holds, and leaves. Three tiers:
#   T1 «Кромка»  ×5   0.9 s, 60 % of the screen height, input LIVE (taps pass through), never in the centre zone
#   T2 «Выход»   ×10  1.2 s, 70 %, input PAUSED (timers frozen), table dimmed 45 %, tap = skip
#   T3 «Витрина» ×20 / Азарт  1.4 s, 80 %, PAUSED, dim 55 %, particle wave + accent backlight, tap = skip
# Rules (§7.1): first time per match per tier, ≥ 20 s between shows, ≤ 3 per match, the higher tier wins,
# deferred while an ult cut-in plays; setting «Героиня на серии»: full / short (all as T1, no pause) / off;
# ranked → short; tutorial levels 1–3 → T1 only. fx_level=min: fades 120 ms, no particles or light.
#
#   var sc := V10ComboShowcase.new(); add_child(sc)        # full rect, on top of the HUD
#   sc.hud = hud; sc.hero = "mc"; sc.outfit = "base"
#   sc.input_paused.connect(func(on): board.input_enabled = not on; timers_paused = on)
#   sc.on_combo(n)          # call on every combo step; returns the tier shown (0 = none)
#   sc.fever_start()        # T3 with «Азарт»
#   sc.hold() / sc.release()  # around an ult cut-in (the cut-in wins, the showcase waits)
#   sc.trigger(tier, n)     # force one (debug / demo)

signal input_paused(on: bool)
signal started(tier: int)
signal finished(tier: int, skipped: bool)
signal sound(tier: int)

const DIR: = "res://assets/v10/hud2/combo/"
const TIERS: = {
	1: {"in": 0.20, "hold": 0.50, "out": 0.20, "h": 0.60, "dim": 0.0, "pause": false, "n": 6},
	2: {"in": 0.28, "hold": 0.70, "out": 0.22, "h": 0.70, "dim": 0.45, "pause": true, "n": 12},
	3: {"in": 0.30, "hold": 0.86, "out": 0.24, "h": 0.80, "dim": 0.55, "pause": true, "n": 18},
}
const SKIP_T: = 0.12
const LINES: = {
	"mc": {2: "Ну как тебе?", 3: "Смотри только на меня~"},
	"rin": {2: "Неплохо. Продолжай.", 3: "Позволю себе улыбнуться."},
	"hana": {2: "Да-а! Ещё!", 3: "Вот это серия!"},
	"yue": {2: "Любопытно…", 3: "Луна сегодня твоя."},
	"nova": {2: "Бит пойман!", 3: "Это хит."},
}

var hud: V10HudMatch
var board_override: = Rect2()
var hero: = "mc"
var outfit: = "base"
var mode: = "full"  # full | short | off  («Героиня на серии»)
var ranked: = false
var tutorial_level: = 0
var min_gap: = 20.0
var max_per_match: = 3

var active: = false
var tier: = 0
var phase: = ""
var phase_t: = 0.0
var elapsed: = 0.0
var skipped: = false

var _clock: = 0.0
var _last_show: = -1.0e9
var _count: = 0
var _done_tiers: = {}
var _held: = false
var _queued: = {}
var _paused_now: = false
var _last_voice: = -1.0e9
var _meta: = {}

var _dim: ColorRect
var _fx: Control
var _sprite: TextureRect
var _mat: ShaderMaterial
var _num: Label
var _line: Label
var _place: = {}
var _n: = 0
var _word: = ""
var _parts: = []
var _fxl: = "full"
var _glow_tex: GradientTexture2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(V10DS.NIGHT_900, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_fx = _Fx.new()
	_fx.sc = self
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_sprite = TextureRect.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/v10/hud2/showcase_sprite.gdshader")
	_sprite.material = _mat
	_sprite.visible = false
	add_child(_sprite)
	_num = V10Type.label("", "display_italic", 64, V10DS.GOLD_300, true)
	_num.clip_text = false
	_num.visible = false
	add_child(_num)
	_line = V10Type.label("", "hand", 30, V10DS.PAPER_100, true)
	_line.visible = false
	add_child(_line)
	_glow_tex = GradientTexture2D.new()
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256
	var g: = Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(Color.WHITE, 0.0))
	_glow_tex.gradient = g
	_load_meta()


func _load_meta() -> void:
	var p: = DIR + "combo_meta.json"
	if FileAccess.file_exists(p):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			_meta = d.get("sprites", {})


# ------------------------------------------------------------------ rules

func new_match() -> void:
	_done_tiers.clear()
	_count = 0
	_last_show = -1.0e9
	_queued.clear()


static func tier_for(n: int) -> int:
	if n >= 20:
		return 3
	if n >= 10:
		return 2
	if n >= 5:
		return 1
	return 0


func on_combo(n: int) -> int:
	var t: = tier_for(n)
	if t == 0 or _done_tiers.has(t):
		return 0
	return _request(t, n, "")


func fever_start() -> int:
	return _request(3, 0, "Азарт", true)


func _request(t: int, n: int, word: String, repeatable: = false) -> int:
	if mode == "off":
		return 0
	if _count >= max_per_match or _clock - _last_show < min_gap or active:
		return 0
	var shown: = t
	if mode == "short" or ranked or (tutorial_level >= 1 and tutorial_level <= 3):
		shown = 1
	if not repeatable:
		for k in range(1, t + 1):
			_done_tiers[k] = true
	if _held:
		_queued = {"tier": shown, "n": n, "word": word}
		return shown
	trigger(shown, n, word)
	return shown


func hold() -> void:
	_held = true


func release() -> void:
	_held = false
	if not _queued.is_empty():
		var q: = _queued
		_queued = {}
		trigger(int(q.tier), int(q.n), str(q.word))


# ------------------------------------------------------------------ sprite & placement

func sprite_path(h: String, o: String, t: int) -> String:
	# §7.5 fallback: outfit tier → base tier → lower tier of the outfit/base. Never an empty show.
	for tt in range(t, 0, -1):
		for cand in ["%s%s_%s_t%d.png" % [DIR, h, o, tt], "%s%s_t%d.png" % [DIR, h, tt]]:
			if ResourceLoader.exists(cand):
				return cand
	return ""


func sprite_meta(path: String) -> Dictionary:
	var key: = path.get_file().get_basename()
	return _meta.get(key, {})


static func placement(t: int, vs: Vector2, board: Rect2, tray_y: float, tex: Vector2, face: Rect2) -> Dictionary:
	var W: = vs.x
	var H: = vs.y
	var cfg: Dictionary = TIERS[t]
	var s: float = float(cfg.h) * H / tex.y
	if t > 1:
		# T2/T3: at least 70 / 80 % tall AND the face in the upper third with the cut line under the screen edge
		var fcy: = face.position.y + face.size.y * 0.5
		s = maxf(s, (H * 2.0 / 3.0) / maxf(1.0, tex.y - fcy))
		s = minf(s, W * 1.1 / tex.x)
	var w: = tex.x * s
	var h: = tex.y * s
	var fc: = (face.position + face.size * 0.5) * s
	var x: = 0.0
	var y: = 0.0
	if t == 1:
		# «Кромка»: she rises out of her scene at the right edge; the face sits on the tray line,
		# below the board, so the centre zone stays free and the face is never under the board mask
		y = tray_y + 24.0 - fc.y
		x = W - 150.0 - fc.x
		x = minf(x, W - 16.0 - face.end.x * s)
	else:
		y = H - h
		if y + fc.y > H / 3.0:
			y = H / 3.0 - fc.y
		x = W * 0.64 - w * 0.5
		x = clampf(x, minf(176.0, W - w), W - w * 0.92)
	return {"rect": Rect2(x, y, w, h), "scale": s, "face": Rect2(Vector2(x, y) + face.position * s, face.size * s)}


func _board() -> Rect2:
	if hud:
		return hud.board_rect()
	return board_override


func _tray_y() -> float:
	if hud:
		return float((hud.L.get("tray", Rect2(16, 792, 688, 104)) as Rect2).position.y)
	return _board().end.y + 8.0


static func center_of(b: Rect2) -> Rect2:
	return Rect2(b.position + b.size * 0.2, b.size * 0.6)


# ------------------------------------------------------------------ show

func trigger(t: int, n: = 0, word: = "") -> void:
	var path: = sprite_path(hero, outfit, t)
	if path == "":
		return
	var tex: Texture2D = load(path)
	var m: = sprite_meta(path)
	var tsz: = tex.get_size()
	var face: = Rect2(tsz.x * 0.4, tsz.y * 0.08, tsz.x * 0.2, tsz.y * 0.12)
	if m.has("face"):
		face = Rect2(m.face[0], m.face[1], m.face[2], m.face[3])
	var vs: = get_viewport_rect().size
	_place = placement(t, vs, _board(), _tray_y(), tsz, face)
	_fxl = V10Hud2Util.fx_level()
	_sprite.texture = tex
	_sprite.size = (_place.rect as Rect2).size
	_sprite.pivot_offset = Vector2(_sprite.size.x * 0.5, _sprite.size.y)
	_sprite.visible = true
	var b: = _board()
	_mat.set_shader_parameter("board_rect", Vector4(b.position.x, b.position.y, b.size.x, b.size.y))
	var cz: = center_of(b)
	_mat.set_shader_parameter("center_rect", Vector4(cz.position.x, cz.position.y, cz.size.x, cz.size.y))
	_mat.set_shader_parameter("board_alpha", 0.45 if t == 1 else 1.0)
	_mat.set_shader_parameter("center_alpha", 0.0 if t == 1 else 1.0)
	_mat.set_shader_parameter("rim", 0.0)
	_mat.set_shader_parameter("rim_color", V10DS.hero(hero).accent)
	tier = t
	_n = n
	_word = word
	active = true
	skipped = false
	phase = "in"
	phase_t = 0.0
	elapsed = 0.0
	_count += 1
	_last_show = _clock
	# number / word: one per show, left above the tray; the HUD's own number steps aside
	if hud:
		hud.combo_l.visible = false
	var anchor: = hud.combo_anchor() if hud else Rect2(24, b.end.y - 80, 320, 80)
	if word != "":
		_num.label_settings = V10Type.settings("display_italic", 44, V10DS.GOLD_300, true)
		_num.text = word
	else:
		_num.label_settings = V10Type.settings("display_italic", 64, V10DS.GOLD_300, true)
		_num.text = "×%d" % n if n > 0 else ""
	_num.position = anchor.position
	_num.size = anchor.size
	_num.pivot_offset = Vector2(0, anchor.size.y * 0.5)
	_num.visible = _num.text != ""
	_num.modulate.a = 0.0
	# one voice line (T2/T3, not within 4 s of the last one)
	_line.visible = false
	if t >= 2 and _clock - _last_voice > 4.0:
		var txt: String = LINES.get(hero, LINES.mc).get(t, "")
		if txt != "":
			_last_voice = _clock
			var fr: Rect2 = _place.face
			var lw: = minf(300.0, V10Type.text_w(txt, "hand", 30) + 8.0)
			var lx: = clampf(fr.position.x - 48.0 - lw, 24.0, vs.x - lw - 24.0)
			var ly: = fr.position.y + fr.size.y * 0.5 - 20.0
			if lx + lw > fr.position.x - 8.0:  # not enough room on the left: under the chin, left-aligned
				lx = clampf(fr.position.x - lw * 0.5, 24.0, vs.x - lw - 24.0)
				ly = fr.end.y + 48.0
			_line.text = txt
			_line.position = Vector2(lx, ly)
			_line.size = Vector2(lw, 40)
			_line.visible = true
			_line.modulate.a = 0.0
	# particles
	_parts.clear()
	var np: int = TIERS[t].n
	if _fxl == "mid":
		np = np / 2
	if _fxl != "min":
		var rng: = RandomNumberGenerator.new()
		rng.seed = hash(str(t) + hero + str(_count))
		var r: Rect2 = _place.rect
		for i in np:
			var p: = Vector2(rng.randf_range(r.position.x + r.size.x * 0.3, vs.x + 40.0), rng.randf_range(r.position.y - 40.0, r.position.y + r.size.y * 0.7))
			_parts.append({"p": p, "v": Vector2(rng.randf_range(-170.0, -60.0), rng.randf_range(20.0, 90.0)) * (1.4 if t == 3 else 1.0),
					"rot": rng.randf() * TAU, "vr": rng.randf_range(-3.0, 3.0), "s": rng.randf_range(5.0, 10.0), "d": rng.randf() * 0.25})
	# input
	var pause: bool = TIERS[t].pause
	mouse_filter = Control.MOUSE_FILTER_STOP if pause else Control.MOUSE_FILTER_IGNORE
	if pause:
		_set_paused(true)
	if hud:
		hud.hero_show(false, float(TIERS[t]["in"]))
	_audio(t)
	started.emit(t)
	_advance(0.0)


func _audio(t: int) -> void:
	sound.emit(t)
	match t:
		1:
			V10Hud2Util.sfx("cutin_whoosh")
		2:
			V10Hud2Util.sfx("cutin_whoosh")
			V10Hud2Util.sfx("heart")
		3:
			V10Hud2Util.sfx("combo_finale")


func _set_paused(on: bool) -> void:
	if _paused_now == on:
		return
	_paused_now = on
	input_paused.emit(on)


func skip() -> void:
	if not active or phase == "out":
		return
	skipped = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_paused(false)  # input is back at once; the picture leaves in 120 ms
	_out_len = SKIP_T
	_out_from = _cur_alpha()
	phase = "out"
	phase_t = 0.0


var _out_len: = 0.2
var _out_from: = 1.0
var _alpha_now: = 0.0


func _cur_alpha() -> float:
	return _alpha_now


func _gui_input(e: InputEvent) -> void:
	if not active:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		skip()
		accept_event()


func _process(delta: float) -> void:
	_clock += delta
	if active:
		_advance(delta)


func _advance(dt: float) -> void:
	# one deterministic step (the selftest drives this directly)
	elapsed += dt
	phase_t += dt
	var cfg: Dictionary = TIERS[tier]
	var tin: float = 0.12 if _fxl == "min" else float(cfg["in"])
	var thold: float = cfg.hold
	if phase == "in" and phase_t >= tin:
		phase = "hold"
		phase_t -= tin
	if phase == "hold" and phase_t >= thold:
		phase = "out"
		phase_t -= thold
		_out_len = 0.12 if _fxl == "min" else float(cfg.out)
		_out_from = 1.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_paused(false)
	if phase == "out" and phase_t >= _out_len:
		_finish()
		return
	var r: Rect2 = _place.rect
	var a: = 1.0
	var dx: = 0.0
	var sc: = 1.0
	match phase:
		"in":
			var p: = clampf(phase_t / tin, 0.0, 1.0)
			a = clampf(p * 2.0, 0.0, 1.0)
			if _fxl != "min":
				var e: = 1.0 - pow(2.0, -10.0 * p)
				match tier:
					1:
						dx = lerpf(160.0, 0.0, e)
					2:
						if p < 0.75:
							dx = lerpf(200.0, -8.0, 1.0 - pow(2.0, -10.0 * p / 0.75))
						else:
							dx = lerpf(-8.0, 0.0, sin((p - 0.75) / 0.25 * PI * 0.5))
					3:
						dx = lerpf(220.0, 0.0, e)
						sc = lerpf(1.04, 1.0, e)
			else:
				a = p
		"hold":
			# alive, not a still: breathing 1.5 %, a slow drift
			if _fxl != "min":
				sc = 1.0 + 0.015 * sin(phase_t * TAU / 1.6)
				dx = -6.0 * phase_t / thold
			if tier == 3 and _fxl != "min":
				var rp: = clampf(phase_t / 0.6, 0.0, 1.0)
				_mat.set_shader_parameter("rim", sin(rp * PI))
				_mat.set_shader_parameter("rim_phase", rp)
		"out":
			var q: = clampf(phase_t / maxf(_out_len, 0.001), 0.0, 1.0)
			a = _out_from * cos(q * PI * 0.5)  # SINE_IN
			if _fxl != "min" and not skipped:
				dx = -6.0 + (120.0 if tier == 1 else 60.0) * (1.0 - cos(q * PI * 0.5))
	_alpha_now = a
	_sprite.position = r.position + Vector2(dx, 0)
	_sprite.scale = Vector2.ONE * sc
	_sprite.modulate.a = a
	_dim.color = Color(V10DS.NIGHT_900, float(cfg.dim) * a)
	_num.modulate.a = a
	if phase == "in" and _fxl != "min":
		var p2: = clampf(phase_t / 0.12, 0.0, 1.0)
		_num.scale = Vector2.ONE * lerpf(1.15, 1.0, p2)
	else:
		_num.scale = Vector2.ONE
	_line.modulate.a = a if phase != "in" else 0.0
	# particles drift on
	for pt in _parts:
		if elapsed > float(pt.d):
			pt.p += pt.v * dt
			pt.rot += pt.vr * dt
	_fx.set("alpha", a)
	_fx.queue_redraw()


func _finish() -> void:
	active = false
	phase = ""
	_sprite.visible = false
	_num.visible = false
	_line.visible = false
	_dim.color = Color(V10DS.NIGHT_900, 0.0)
	_parts.clear()
	_fx.queue_redraw()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_paused(false)
	if hud:
		hud.hero_show(true, 0.2)
	finished.emit(tier, skipped)


# ------------------------------------------------------------------ selftest helpers

static func mask_alpha(p: Vector2, board: Rect2, t: int, feather: = 24.0) -> float:
	# GDScript twin of showcase_sprite.gdshader's mask (keep in sync)
	var a: = 1.0
	var ba: = 0.45 if t == 1 else 1.0
	var ca: = 0.0 if t == 1 else 1.0
	var db: = _odist(board, p)
	a = lerpf(ba, 1.0, clampf(db / 64.0, 0.0, 1.0))
	var cz: = center_of(board)
	var dc: = _odist(cz, p)
	a = minf(a, lerpf(ca, 1.0, clampf(dc / feather, 0.0, 1.0)))
	return a


static func _odist(r: Rect2, p: Vector2) -> float:
	var d: = Vector2(maxf(r.position.x - p.x, p.x - r.end.x), maxf(r.position.y - p.y, p.y - r.end.y))
	return maxf(d.x, d.y)


# ------------------------------------------------------------------ light and particles

class _Fx:
	extends Control
	var sc: V10ComboShowcase
	var alpha: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if sc == null or not sc.active or sc._fxl == "min":
			return
		var hc: Dictionary = V10DS.hero(sc.hero)
		var acc: Color = hc.accent
		var r: Rect2 = sc._place.rect
		var vs: = size
		var a: = alpha
		# soft halo behind her (accent, no white, ≤ 70 % brightness)
		var halo: = Color(acc.r * 0.7, acc.g * 0.7, acc.b * 0.7, 0.30 * a)
		var fr: Rect2 = sc._place.face
		var hc_pos: = fr.position + fr.size * 0.5 + Vector2(0, fr.size.y * 1.4)
		var hr: = r.size.x * (0.65 if sc.tier == 3 else 0.5)
		draw_texture_rect(sc._glow_tex, Rect2(hc_pos - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false, halo)
		# one slanted ray from the top right
		if sc.tier >= 2:
			var c0: = Color(acc, 0.0)
			var c1: = Color(acc.r * 0.7, acc.g * 0.7, acc.b * 0.7, 0.22 * a)
			var x0: = vs.x + 40.0
			var sk: = vs.y * 0.55
			var wband: = 150.0 if sc.tier == 3 else 110.0
			var p: = PackedVector2Array([Vector2(x0 - wband, -20), Vector2(x0, -20), Vector2(x0 - sk, vs.y + 20), Vector2(x0 - sk - wband, vs.y + 20)])
			var mid0: = (p[0] + p[1]) * 0.5
			var mid1: = (p[2] + p[3]) * 0.5
			draw_polygon(PackedVector2Array([p[0], mid0, mid1, p[3]]), PackedColorArray([c0, c1, c1, c0]))
			draw_polygon(PackedVector2Array([mid0, p[1], p[2], mid1]), PackedColorArray([c1, c0, c0, c1]))
		# particles of her element
		var el: String = hc.element
		for pt in sc._parts:
			if sc.elapsed < float(pt.d):
				continue
			var pos: Vector2 = pt.p
			var s: float = pt.s
			draw_set_transform(pos, float(pt.rot), Vector2.ONE)
			match el:
				"petal":
					_petal(s, Color(hc.glow, 0.9 * a), Color(acc, 0.9 * a))
				"leaf":
					_petal(s * 1.1, Color(hc.glow, 0.85 * a), Color(hc.deep, 0.85 * a))
				"spark":
					var cs: = Color(acc.r, acc.g, acc.b, 0.9 * a)
					draw_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.25, 0), Vector2(0, s), Vector2(-s * 0.25, 0)]), PackedColorArray([cs, cs, cs, cs]))
					draw_polygon(PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 0.25), Vector2(s, 0), Vector2(0, s * 0.25)]), PackedColorArray([cs, cs, cs, cs]))
				"dust":
					draw_circle(Vector2.ZERO, s * 0.35, Color(hc.glow, 0.9 * a), true, -1.0, true)
					draw_circle(Vector2.ZERO, s * 0.9, Color(acc, 0.18 * a), true, -1.0, true)
				"glitch":
					draw_rect(Rect2(-s * 0.6, -s * 0.25, s * 1.2, s * 0.5), Color(acc, 0.8 * a))
					draw_rect(Rect2(-s * 0.6 + 3, -s * 0.25 + 2, s * 1.2, s * 0.5), Color(hc.deep, 0.5 * a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _petal(s: float, c0: Color, c1: Color) -> void:
		var pts: = PackedVector2Array()
		var cols: = PackedColorArray()
		for i in 12:
			var t: = TAU * i / 12.0
			var rr: = s * (1.0 - 0.25 * pow(sin(t * 0.5), 8.0))
			pts.append(Vector2(cos(t) * rr, sin(t) * rr * 0.55))
			cols.append(c0.lerp(c1, (cos(t) + 1.0) * 0.5))
		draw_polygon(pts, cols)
