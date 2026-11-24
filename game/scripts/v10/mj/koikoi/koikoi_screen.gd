class_name V10MjKoikoiScreen
extends Control

# Экран «Коикои» (MODES §4.8, UX_RULES §3.7, §6). 720×1280; на длинных экранах лишняя высота уходит в её полосу.
#   её полоса   0 … 220(+ex)  — соперница по пояс, её взятки мелко, её счёт, её рука рубашками
#   стол        … +540        — карты стола в 2 ряда, колода справа
#   мои взятки  … +140        — 4 группы (свет, животные, ленты, пустые) с полосой прогресса
#   рука        … +220        — веер, тап поднимает, совпадения на столе светятся; второй тап — сыграть
#   низ         … +160        — мой счёт, «×2» после кои-кои, ближайшая комбинация, «?»
# Контракт §7.1: setup(main, args) → сигнал finished(result). Награды экран не начисляет — только считает.
# args: {hero, months, seed, presence, auto (ИИ за игрока, для демо), music (bool), fast (ускорение анимаций)}

signal finished(result: Dictionary)

const BASE_H: = 1280.0
const NIGHT_900: = Color("121014")
const NIGHT_800: = Color("1b171c")
const NIGHT_700: = Color("26212a")
const NIGHT_600: = Color("332c36")
const PAPER_100: = Color("f5ead8")
const PAPER_300: = Color("ddd2c4")
const PAPER_500: = Color("b3a89c")
const PAPER_700: = Color("7e756d")
const GOLD_300: = Color("f1d9a0")
const GOLD_500: = Color("e8c47e")
const GOLD_700: = Color("a87b3a")
const ROSE_500: = Color("d796a5")
const ROSE_700: = Color("9a4f66")
const JADE_300: = Color("a9d9c4")
const EMBER: = Color("e07a7a")
const CINNABAR: = Color("c8463c")

# Все видимые строки экрана (для самотеста стоп-слов и подсчёта слов).
const UI_STRINGS: = ["Месяц", "Забрать", "Кои-кои!", "Дальше", "Месяц твой", "Месяц её", "Ничья", "Победа", "Почти",
	"Ещё партия", "Выйти", "Продолжить", "Пауза", "Монеты", "Кристаллы", "Книга", "страница", "Новая карта", "Как играть",
	"Комбинации", "Понятно", "ещё", "очков", "Перехват", "Сыграй карту", "Выбери пару", "первая победа дня"]

const GROUPS: = ["light", "animal", "ribbon", "plain"]

var main = null
var args: = {}
var k: V10MjKoikoi
var rng: = RandomNumberGenerator.new()
var hero: = "rin"
var months: = 6
var auto: = false
var fast: = 1.0
var presence = null
var views: = {}
var sel: = -1
var busy: = true
var awaiting: = ""          # "" / "play" / "pick" / "decide" / "next" / "result"
var t_start: = 0
var pairs: = 0
var my_yaku_seen: = {}
var _last_line_ms: = -100000
var _last_voice_ms: = -100000
var _idle_s: = 0.0
var skins: = {}
var skins_on: = true
var accent: = Color("4fbf9f")

# узлы
var bg: ColorRect
var strip: Control
var portrait: TextureRect
var portrait_atlas: AtlasTexture
var her_line: Label
var her_score: Label
var her_koi: Label
var her_name: Label
var month_lbl: Label
var her_counts: Array = []
var my_score: Label
var my_koi: Label
var hint: Label
var deck_lbl: Label
var deck_stack: Control
var my_counts: Array = []
var my_bars: Array = []
var cards_layer: Control
var fx_layer: Control
var ui_layer: Control
var sheet: Control
var banner: Control
var pause_btn: Button
var help_btn: Button
var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var _bust: = Rect2()
var _face: = Rect2()
var _breath_tw: Tween

# ── размеры ─────────────────────────────────────────────────────────────────────────────────────

func W() -> float:
	return 720.0

func Hh() -> float:
	return maxf(BASE_H, size.y if size.y > 0 else BASE_H)

func ex() -> float:
	return Hh() - BASE_H

func strip_h() -> float:
	return 220.0 + ex()

func y_table() -> float:
	return strip_h()

func table_rect() -> Rect2:
	return Rect2(20, y_table() + 14, 548, 512)

func deck_center() -> Vector2:
	return Vector2(640, y_table() + 270)

func y_caps() -> float:
	return 760.0 + ex()

func y_hand() -> float:
	return 900.0 + ex()

func y_bottom() -> float:
	return 1120.0 + ex()

func sacred_rect() -> Rect2:
	return Rect2(0, y_table(), W(), Hh() - y_table())

# ── жизненный цикл ──────────────────────────────────────────────────────────────────────────────

func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a
	hero = String(a.get("hero", "rin"))
	if not V10MjKoikoiLines.NAME.has(hero):
		hero = "rin"
	months = int(a.get("months", 6))
	auto = bool(a.get("auto", false))
	fast = float(a.get("fast", 1.0))
	presence = a.get("presence", null)
	accent = V10MjKoikoiLines.accent(hero)
	var sd: int = int(a.get("seed", Time.get_ticks_usec() % 1000000007))
	rng.seed = sd + 17
	k = V10MjKoikoi.new()
	k.setup_match(sd, months, int(a.get("dealer", -1)))
	var d: = V10MjKoikoiSave.st()
	skins = d.skins
	skins_on = bool(d.use_skins)
	args["seed"] = sd

func _ready() -> void:
	if k == null:
		setup(null, args)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if size.y <= 0:
		size = get_viewport_rect().size
	_build()
	t_start = Time.get_ticks_msec()
	if bool(args.get("music", true)):
		_start_music()
	if not bool(args.get("no_start", false)):
		_begin_month.call_deferred()

func _process(delta: float) -> void:
	if awaiting == "play" and not busy:
		_idle_s += delta
		if _idle_s > 20.0:
			_idle_s = -40.0
			_pres("idle", {})
			_hint_pulse()

func _pres(ev: String, data: Dictionary) -> void:
	if presence != null and presence.has_method("on"):
		presence.on(ev, data)

func dt(s: float) -> float:
	return s / maxf(0.01, fast)

func wait(s: float) -> void:
	await get_tree().create_timer(dt(s)).timeout

# ── сборка интерфейса ──────────────────────────────────────────────────────────────────────────

func _build() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: = load("res://shaders/v10/mj/koikoi/lacquer.gdshader") as Shader
	if sh:
		var mat: = ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("px_size", Vector2(W(), Hh()))
		mat.set_shader_parameter("tint", accent)
		bg.material = mat
	else:
		bg.color = NIGHT_900
	add_child(bg)

	_build_strip()
	_build_table_frame()

	cards_layer = Control.new()
	cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards_layer)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.z_index = 100
	add_child(fx_layer)
	ui_layer = Control.new()
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	_build_caps_zone()
	_build_bottom()
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)

func _lbl(text: String, sz: int, col: Color, kind: = "body", weight: = 800) -> Label:
	var l: = UI.label(text, sz, col, Color(0, 0, 0, 0), 0, kind, weight)
	return l

func _numeric(text: String, sz: int, col: Color) -> Label:
	var l: = _lbl(text, sz, col, "body", 900)
	return l

func _build_strip() -> void:
	strip = Control.new()
	strip.position = Vector2.ZERO
	strip.size = Vector2(W(), strip_h())
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	# её фон: глубокий тон её акцента, к столу уходит в лак
	var back: = _Grad.new()
	back.size = strip.size
	back.top = Color(accent.darkened(0.78), 1.0)
	back.bottom = Color(NIGHT_900, 0.0)
	strip.add_child(back)
	# поясной кадр
	var tex: Texture2D = load("res://assets/hero/%s.png" % hero) if ResourceLoader.exists("res://assets/hero/%s.png" % hero) else null
	var fr: Dictionary = V10MjKoikoiLines.FRAME.get(hero, V10MjKoikoiLines.FRAME.rin)
	var ph: = strip_h() + 6.0
	var pw: = minf(ph * 1.22, 470.0)
	var rw: = 600.0
	var rh: = rw * ph / pw
	var fc: Vector2 = fr.face
	_bust = Rect2(clampf(fc.x - rw * 0.5, 0, 848 - rw), float(fr.top) - 14.0, rw, rh)
	var fw: = 250.0
	_face = Rect2(fc.x - fw * 0.5, fc.y - fw * ph / pw * 0.52, fw, fw * ph / pw)
	portrait_atlas = AtlasTexture.new()
	portrait_atlas.atlas = tex
	portrait_atlas.region = _bust
	portrait = TextureRect.new()
	portrait.texture = portrait_atlas
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.size = Vector2(pw, ph)
	portrait.position = Vector2(W() - pw + 8.0, 0)
	portrait.pivot_offset = Vector2(pw * 0.5, ph)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(portrait)
	# мягкий переход к столу у ног кадра
	var fade: = _Grad.new()
	fade.position = Vector2(0, strip_h() - 46)
	fade.size = Vector2(W(), 46)
	fade.top = Color(NIGHT_900, 0.0)
	fade.bottom = Color(0.08, 0.065, 0.075, 0.92)
	strip.add_child(fade)
	_breathe()

	pause_btn = _quiet_btn("pause")
	pause_btn.position = Vector2(8, 8)
	pause_btn.pressed.connect(_on_pause)
	add_child(pause_btn)

	month_lbl = _lbl("", 18, PAPER_500)
	month_lbl.position = Vector2(92, 18)
	add_child(month_lbl)
	her_name = _lbl(V10MjKoikoiLines.NAME.get(hero, ""), 26, PAPER_100, "title", 700)
	her_name.position = Vector2(92, 40)
	add_child(her_name)
	her_score = _numeric("0", 40, GOLD_300)
	her_score.position = Vector2(26, 86 + ex() * 0.1)
	add_child(her_score)
	her_koi = _numeric("", 22, accent)
	her_koi.position = Vector2(26 + 64, 98 + ex() * 0.1)
	add_child(her_koi)
	# её взятки: 4 маленькие стопки с числом
	for i in 4:
		var l: = _numeric("", 18, PAPER_300)
		l.position = Vector2(30 + i * 62 + 30, strip_h() - 44)
		add_child(l)
		her_counts.append(l)
	her_line = UI.label("", 30, PAPER_100, Color(0, 0, 0, 0.0), 0, "title", 700)
	var vf: = _voice_font()
	if vf:
		her_line.label_settings.font = vf
	her_line.label_settings.shadow_color = Color(0, 0, 0, 0.55)
	her_line.label_settings.shadow_offset = Vector2(0, 2)
	her_line.label_settings.shadow_size = 6
	her_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	her_line.size = Vector2(250, 80)
	her_line.position = Vector2(W() - pw - 210, 60 + ex() * 0.5)
	her_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	her_line.modulate.a = 0.0
	add_child(her_line)

func _voice_font() -> Font:
	var p: = "res://assets/fonts/playfair-i-cyr.woff2"
	if not ResourceLoader.exists(p):
		return null
	var fv: = FontVariation.new()
	fv.base_font = load(p)
	var fl: = "res://assets/fonts/playfair-i-lat.woff2"
	if ResourceLoader.exists(fl):
		var fb: = FontVariation.new()
		fb.base_font = load(fl)
		fv.fallbacks = [fb]
	var ts: = TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): 600}
	return fv

func _build_table_frame() -> void:
	var tr: = table_rect()
	var tray: = _Tray.new()
	tray.position = tr.position - Vector2(6, 6)
	tray.size = tr.size + Vector2(12, 12)
	tray.line = Color(GOLD_700, 0.35)
	add_child(tray)
	deck_stack = Control.new()
	deck_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deck_stack)
	var dc: = deck_center()
	for i in 3:
		var b: = V10MjKoikoiCard.new().setup(-1, false)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_stack.add_child(b)
		b.place(dc + Vector2(-i * 2.5, -i * 3.0), 0.78)
	deck_lbl = _numeric("", 22, PAPER_300)
	deck_lbl.position = dc + Vector2(-24, 84)
	deck_lbl.size = Vector2(48, 28)
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(deck_lbl)

func _build_caps_zone() -> void:
	var y: = y_caps()
	var line: = ColorRect.new()
	line.color = Color(GOLD_700, 0.25)
	line.position = Vector2(24, y)
	line.size = Vector2(W() - 48, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(line)
	for i in 4:
		var l: = _numeric("", 18, PAPER_300)
		l.position = Vector2(_group_x(i) + 46, y + 100)
		ui_layer.add_child(l)
		my_counts.append(l)
		var bar: = _Bar.new()
		bar.position = Vector2(_group_x(i) - 70, y + 128)
		bar.size = Vector2(108, 4)
		bar.col = JADE_300
		ui_layer.add_child(bar)
		my_bars.append(bar)

func _group_x(i: int) -> float:
	return 96.0 + i * 176.0

func _build_bottom() -> void:
	var y: = y_bottom()
	my_score = _numeric("0", 40, GOLD_300)
	my_score.position = Vector2(26, y + 46)
	ui_layer.add_child(my_score)
	my_koi = _numeric("", 24, ROSE_500)
	my_koi.position = Vector2(100, y + 58)
	ui_layer.add_child(my_koi)
	hint = _lbl("", 20, PAPER_500)
	hint.position = Vector2(170, y + 60)
	hint.size = Vector2(380, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_layer.add_child(hint)
	help_btn = _quiet_btn("help")
	help_btn.position = Vector2(W() - 88, y + 36)
	help_btn.pressed.connect(_on_help)
	ui_layer.add_child(help_btn)

func _quiet_btn(kind: String) -> Button:
	var b: = _Icon.new()
	b.kind = kind
	b.size = Vector2(80, 80)
	b.pivot_offset = Vector2(40, 40)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var sb: = StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): V9Feel.press(b))
	return b

func _btn_primary(text: String, w: float = 560.0, h: float = 104.0) -> Button:
	var b: = Button.new()
	b.text = text
	b.size = Vector2(w, h)
	b.pivot_offset = b.size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	var n: = StyleBoxFlat.new()
	n.bg_color = ROSE_500
	n.set_corner_radius_all(int(h * 0.5))
	n.anti_aliasing = true
	var p: = n.duplicate() as StyleBoxFlat
	p.bg_color = ROSE_700
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", UI.font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", NIGHT_900)
	b.add_theme_color_override("font_hover_color", NIGHT_900)
	b.add_theme_color_override("font_pressed_color", NIGHT_900)
	b.pressed.connect(func(): V9Feel.press(b))
	return b

func _btn_secondary(text: String, col: Color, w: float = 360.0, h: float = 84.0) -> Button:
	var b: = Button.new()
	b.text = text
	b.size = Vector2(w, h)
	b.pivot_offset = b.size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	var n: = StyleBoxFlat.new()
	n.bg_color = Color(col, 0.10)
	n.border_color = Color(col, 0.75)
	n.set_border_width_all(2)
	n.set_corner_radius_all(4)
	n.anti_aliasing = true
	var p: = n.duplicate() as StyleBoxFlat
	p.bg_color = Color(col, 0.25)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", UI.font("title", 700))
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", col.lightened(0.25))
	b.add_theme_color_override("font_hover_color", col.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", col.lightened(0.4))
	b.pressed.connect(func(): V9Feel.press(b))
	return b

# ── раскладка карт ─────────────────────────────────────────────────────────────────────────────

func _view(c: int) -> V10MjKoikoiCard:
	if views.has(c):
		return views[c]
	var v: = V10MjKoikoiCard.new().setup(c, false, skins, skins_on)
	v.tapped.connect(_on_card)
	cards_layer.add_child(v)
	v.place(deck_center(), 0.78)
	views[c] = v
	return v

func _table_slots(n: int) -> Array:
	var tr: = table_rect()
	var cols: = maxi(4, int(ceil(n / 2.0)))
	var gap: = 10.0
	var w: = minf(104.0, (tr.size.x - (cols - 1) * gap) / cols)
	var s: = w / V10MjKoikoiCard.CW
	var h: = V10MjKoikoiCard.CH * s
	var used: = maxi(1, int(ceil(n / 2.0)))
	var x0: = tr.position.x + (tr.size.x - (used * w + (used - 1) * gap)) * 0.5 + w * 0.5
	var cy: = tr.position.y + tr.size.y * 0.5
	var out: = []
	for i in n:
		var r: = i % 2
		var c: = i / 2
		out.append([Vector2(x0 + c * (w + gap), cy + (h * 0.5 + 9.0) * (-1 if r == 0 else 1)), s])
	return out

func _hand_slots(n: int) -> Array:
	var out: = []
	if n == 0:
		return out
	var span: = 600.0
	var step: = minf(112.0, span / maxf(1.0, n - 1)) if n > 1 else 0.0
	var x0: = W() * 0.5 - step * (n - 1) * 0.5
	var cy: = y_hand() + 112.0
	for i in n:
		var off: = i - (n - 1) * 0.5
		out.append([Vector2(x0 + i * step, cy + off * off * 2.6), 1.0, off * 0.045])
	return out

func _her_hand_slots(n: int) -> Array:
	var out: = []
	var cx: = minf(330.0, (portrait.position.x if portrait else 440.0) - 70.0)
	var cy: = strip_h() - 40.0
	if cx < 300.0:
		cx = 110.0
		cy = strip_h() - 160.0
	for i in n:
		var off: = i - (n - 1) * 0.5
		out.append([Vector2(cx + off * 13.0, cy + absf(off) * 1.5), 0.30, off * 0.06])
	return out

func _cap_pos(p: int, kind_i: int, idx: int, n: int) -> Array:
	if p == 0:
		var s: = 0.40
		var step: = minf(13.0, 110.0 / maxf(1.0, n))
		var x: = _group_x(kind_i) - 34.0 + idx * step
		return [Vector2(x, y_caps() + 52.0), s]
	var s2: = 0.22
	var step2: = minf(5.0, 30.0 / maxf(1.0, n))
	return [Vector2(36.0 + kind_i * 62.0 + idx * step2, strip_h() - 74.0), s2]

func _group_of(c: int) -> int:
	return GROUPS.find(V10MjKoikoi.kind(c))

func relayout(dur: float = 0.28, skip: Array = []) -> void:
	var d: = dt(dur)
	# рука
	var hs: = _hand_slots(k.hand[0].size())
	for i in k.hand[0].size():
		var c: int = k.hand[0][i]
		if c in skip:
			continue
		var v: = _view(c)
		var sl: Array = hs[i]
		var pos: Vector2 = sl[0]
		var sc: float = sl[1]
		if c == sel:
			pos.y -= 38.0
			sc = 1.06
		if not v.face_up:
			v.flip_to(true, dt(0.22))
		v.place(pos, sc, sl[2], d)
		v.z_index = 20 + i
		v.pip = true
	# её рука (рубашкой)
	var hh: = _her_hand_slots(k.hand[1].size())
	for i in k.hand[1].size():
		var c: int = k.hand[1][i]
		if c in skip:
			continue
		var v: = _view(c)
		v.face_up = false
		v.queue_redraw()
		v.place(hh[i][0], hh[i][1], hh[i][2], d)
		v.z_index = 5 + i
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# стол
	var ts: = _table_slots(k.table.size())
	for i in k.table.size():
		var c: int = k.table[i]
		if c in skip:
			continue
		var v: = _view(c)
		if not v.face_up:
			v.flip_to(true, dt(0.22))
		v.place(ts[i][0], ts[i][1], 0.0, d)
		v.z_index = 10
		v.mouse_filter = Control.MOUSE_FILTER_STOP
	# взятки
	for p in 2:
		var by: = [[], [], [], []]
		for c in k.caps[p]:
			by[_group_of(c)].append(c)
		for g in 4:
			for i in by[g].size():
				var c: int = by[g][i]
				if c in skip:
					continue
				var v: = _view(c)
				if not v.face_up:
					v.face_up = true
					v.queue_redraw()
				var cp: = _cap_pos(p, g, i, by[g].size())
				v.place(cp[0], cp[1], 0.0, d)
				v.z_index = 2 + i
				v.pip = p == 0
				v.set_hl(false)
				v.set_dim(false)
				v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_hud()

func _refresh_hud() -> void:
	month_lbl.text = "Месяц %d из %d" % [maxi(1, k.month_no), k.months_total]
	her_score.text = str(k.totals[1])
	my_score.text = str(k.totals[0])
	her_koi.text = ("×%d" % (1 << int(k.koi[1]))) if int(k.koi[1]) > 0 else ""
	my_koi.text = ("×%d" % (1 << int(k.koi[0]))) if int(k.koi[0]) > 0 else ""
	deck_lbl.text = str(k.deck.size())
	deck_stack.visible = not k.deck.is_empty()
	deck_lbl.visible = not k.deck.is_empty()
	var cnt: = [[0, 0, 0, 0], [0, 0, 0, 0]]
	for p in 2:
		for c in k.caps[p]:
			cnt[p][_group_of(c)] += 1
	var goal: = [3, 5, 5, 10]
	for g in 4:
		my_counts[g].text = str(cnt[0][g]) if cnt[0][g] > 0 else ""
		her_counts[g].text = str(cnt[1][g]) if cnt[1][g] > 0 else ""
		my_bars[g].value = clampf(float(cnt[0][g]) / float(goal[g]), 0.0, 1.0)
		my_bars[g].queue_redraw()
	# ближайшая комбинация (одна строка)
	if awaiting == "decide":
		hint.text = ""
	else:
		var pr: = V10MjKoikoi.progress(k.caps[0])
		if not pr.is_empty() and pr[0].have > 0:
			hint.text = "%s · ещё %d" % [V10MjKoikoi.YAKU[pr[0].id].name, pr[0].need - pr[0].have]
		else:
			hint.text = ""

# ── ход партии ─────────────────────────────────────────────────────────────────────────────────

func _begin_month() -> void:
	busy = true
	awaiting = ""
	for c in views.keys():
		views[c].queue_free()
	views.clear()
	k.next_month()
	k.take_events()
	_refresh_hud()
	await _deal_anim()
	await _loop()

func _deal_anim() -> void:
	V9Feel.sound("flip", 0.9)
	var order: Array = []
	for i in 8:
		order.append(["t", k.table[i]])
		order.append(["h", k.hand[0][i]])
		order.append(["o", k.hand[1][i]])
	for e in order:
		_view(e[1])
	var ts: = _table_slots(k.table.size())
	var hs: = _hand_slots(8)
	var os: = _her_hand_slots(8)
	var i_t: = 0
	var i_h: = 0
	var i_o: = 0
	for e in order:
		var v: V10MjKoikoiCard = views[e[1]]
		match e[0]:
			"t":
				v.z_index = 10
				v.arc_to(ts[i_t][0], ts[i_t][1], dt(0.32), 30.0)
				_flip_later(v, dt(0.26))
				i_t += 1
			"h":
				v.z_index = 20 + i_h
				v.arc_to(hs[i_h][0], 1.0, dt(0.36), 40.0, hs[i_h][2])
				_flip_later(v, dt(0.3))
				i_h += 1
			"o":
				v.z_index = 5
				v.mouse_filter = Control.MOUSE_FILTER_IGNORE
				v.arc_to(os[i_o][0], os[i_o][1], dt(0.3), -20.0, os[i_o][2])
				i_o += 1
		if int(Time.get_ticks_msec()) % 3 == 0:
			V9Feel.sound("clack%d" % (randi() % 3), randf_range(1.05, 1.2), -10.0)
		await wait(0.035)
	await wait(0.45)
	relayout(0.2)

func _flip_later(v: V10MjKoikoiCard, after: float) -> void:
	await get_tree().create_timer(after).timeout
	if is_instance_valid(v) and not v.face_up:
		v.flip_to(true, dt(0.2))
		V9Feel.sound("flip", randf_range(0.95, 1.1), -8.0)

func _loop() -> void:
	while true:
		if not is_inside_tree():
			return
		if k.phase == "over":
			await _month_end()
			return
		if k.turn == 1 or auto:
			await _ai_step()
			continue
		match k.phase:
			"play":
				_await_input("play")
				return
			"pick":
				_await_input("pick")
				return
			"draw":
				await wait(0.28)
				k.draw()
				await _consume()
			"decide":
				_show_decision()
				return

func _await_input(what: String) -> void:
	awaiting = what
	busy = false
	_idle_s = 0.0
	if presence != null and presence.has_method("sacred"):
		presence.sacred(sacred_rect())
	for c in k.hand[0]:
		_view(c).set_dim(false)
	if what == "pick":
		for t in k.table:
			_view(t).set_hl(k.pick_options.has(t))
		hint.text = "Выбери пару"
	_update_match_hl()

func _ai_step() -> void:
	var p: = k.turn
	var sid: = hero if p == 1 else "mc"
	match k.phase:
		"play":
			await wait(0.55 if p == 1 else 0.35)
			var mv: = V10MjKoikoiAI.choose_play(k, p, sid, rng)
			k.play(int(mv.card), int(mv.target))
		"pick":
			await wait(0.3)
			k.choose(V10MjKoikoiAI.choose_pick(k, p, sid, k.pending, k.pick_options))
		"draw":
			await wait(0.3)
			k.draw()
		"decide":
			await wait(0.7)
			if V10MjKoikoiAI.decide_koi(k, p, sid, rng):
				k.koikoi()
			else:
				k.stop()
	await _consume()

func _consume() -> void:
	var evs: = k.take_events()
	for i in evs.size():
		var nxt: Dictionary = evs[i + 1] if i + 1 < evs.size() else {}
		await _anim(evs[i], nxt)
	relayout(0.24)

# ── ввод игрока ────────────────────────────────────────────────────────────────────────────────

func _on_card(v: V10MjKoikoiCard) -> void:
	if busy or (awaiting != "play" and awaiting != "pick"):
		return
	_idle_s = 0.0
	var c: = v.cid
	if awaiting == "pick":
		if k.pick_options.has(c):
			busy = true
			awaiting = ""
			V9Feel.tile_tap(true)
			k.choose(c)
			await _consume()
			await _loop()
		else:
			V9Feel.tile_tap(false)
		return
	if k.hand[0].has(c):
		if sel == c:
			var ms: = k.matches(c)
			if ms.size() == 2:
				V9Feel.tile_tap(false)
				_flash_options(ms)
				return
			await _player_play(c, -1)
		else:
			sel = c
			V9Feel.tile_tap(true)
			_pres("pick", {"card": c})
			relayout(0.16)
			_update_match_hl()
		return
	if k.table.has(c) and sel >= 0:
		if V10MjKoikoi.month(c) == V10MjKoikoi.month(sel):
			await _player_play(sel, c)
		else:
			V9Feel.tile_tap(false)
		return
	if k.table.has(c) and sel < 0:
		# тап по карте стола без выбора: подсветить, какие карты руки к ней подходят
		for h in k.hand[0]:
			if V10MjKoikoi.month(h) == V10MjKoikoi.month(c):
				sel = h
				relayout(0.16)
				_update_match_hl()
				V9Feel.tile_tap(true)
				return
		V9Feel.tile_tap(false)

func _update_match_hl() -> void:
	for t in k.table:
		var on: = false
		if awaiting == "pick":
			on = k.pick_options.has(t)
		elif sel >= 0:
			on = V10MjKoikoi.month(t) == V10MjKoikoi.month(sel)
		_view(t).set_hl(on)
	if awaiting == "play":
		if sel >= 0:
			hint.text = ""
		else:
			_refresh_hud()

func _flash_options(ms: Array) -> void:
	hint.text = "Выбери пару"
	for t in ms:
		var v: = _view(t)
		var tw: = v.create_tween()
		tw.tween_property(v, "modulate", Color(1.3, 1.2, 1.0), 0.12)
		tw.tween_property(v, "modulate", Color.WHITE, 0.25)

func _player_play(c: int, target: int) -> void:
	busy = true
	awaiting = ""
	sel = -1
	for t in k.table:
		_view(t).set_hl(false)
	V9Feel.sound("pop", 1.0)
	k.play(c, target)
	await _consume()
	await _loop()

# ── анимация событий ───────────────────────────────────────────────────────────────────────────

func _anim(ev: Dictionary, nxt: Dictionary) -> void:
	match String(ev.t):
		"play":
			var v: = _view(int(ev.c))
			v.z_index = 60
			v.set_dim(false)
			var target: = _target_for(int(ev.c), nxt)
			if int(ev.p) == 1:
				v.flip_to(true, dt(0.26))
			V9Feel.sound("whoosh", randf_range(1.1, 1.3), -12.0)
			await v.arc_to(target, _table_scale(), dt(0.34), 70.0 if int(ev.p) == 0 else -30.0).finished
			V9Feel.sound("clack%d" % (randi() % 3), randf_range(0.95, 1.05), -2.0)
		"reveal":
			var v: = _view(int(ev.c))
			v.z_index = 60
			v.face_up = false
			v.queue_redraw()
			v.place(deck_center(), 0.78)
			V9Feel.sound("flip", 1.0, -4.0)
			var tw: = v.place(deck_center() + Vector2(-70, 0), 1.0, 0.0, dt(0.18))
			if tw:
				await tw.finished
			await v.flip_to(true, dt(0.24)).finished
			await wait(0.22)
			var target: = _target_for(int(ev.c), nxt)
			await v.arc_to(target, _table_scale(), dt(0.3), 40.0).finished
			V9Feel.sound("clack%d" % (randi() % 3), 1.0, -3.0)
		"place":
			relayout(0.22)
			await wait(0.12)
		"pick":
			var v: = _view(int(ev.c))
			var ops: Array = ev.options
			var t0: = _view(int(ops[0]))
			v.place(t0.center() + Vector2(0, -24), _table_scale(), 0.0, dt(0.18))
		"capture":
			await _capture_fx(ev)
		"yaku":
			await _yaku_fx(ev)
		"koikoi":
			await _koikoi_fx(ev)
		"stop":
			if int(ev.p) == 1:
				_say("take", true)
				_react("happy")
				await wait(0.9)
			else:
				V9Feel.success(null, "sparkle")
		"over":
			pass
		"turn":
			_refresh_hud()

func _table_scale() -> float:
	var ts: = _table_slots(maxi(8, k.table.size() + 1))
	return float(ts[0][1])

# Куда «приземлить» сыгранную/открытую карту: на совпавшую карту стола (со сдвигом) или в свободный слот.
func _target_for(c: int, nxt: Dictionary) -> Vector2:
	if nxt.get("t", "") == "capture" and int(nxt.get("c", -1)) == c:
		var others: Array = nxt.cards.filter(func(x): return x != c)
		if not others.is_empty():
			return _view(int(others[0])).center() + Vector2(18, 20)
	if nxt.get("t", "") == "pick":
		var ops: Array = nxt.options
		return _view(int(ops[0])).center() + Vector2(0, -24)
	var ts: = _table_slots(k.table.size())
	var idx: = k.table.find(c)
	if idx >= 0 and idx < ts.size():
		return ts[idx][0]
	return table_rect().get_center()

func _capture_fx(ev: Dictionary) -> void:
	var p: = int(ev.p)
	var cards: Array = ev.cards
	var at: = _view(int(ev.c)).center()
	pairs += 1 if p == 0 else 0
	for c in cards:
		var v: = _view(int(c))
		v.z_index = 70
		var tw: = v.create_tween()
		tw.tween_property(v, "modulate", Color(1.35, 1.25, 1.05), dt(0.08))
		tw.tween_property(v, "modulate", Color.WHITE, dt(0.22))
	V9Feel.tile_match(pairs if p == 0 else 1)
	_burst(at, accent if p == 1 else GOLD_300, 8)
	var light: = false
	for c in cards:
		if V10MjKoikoi.kind(int(c)) == "light":
			light = true
	if p == 0:
		_pres("pair", {"cards": cards})
		if light:
			_say("you_light", false)
			_react("impressed")
	elif light:
		_say("month", true)
		_react("happy")
	await wait(0.26)
	relayout(0.34)
	await wait(0.3)

func _yaku_fx(ev: Dictionary) -> void:
	var fresh: Array = ev.get("fresh", [])
	var names: = []
	for y in fresh:
		names.append(V10MjKoikoi.YAKU[y].name)
	if names.is_empty():
		return
	var p: = int(ev.p)
	if p == 0:
		for y in fresh:
			my_yaku_seen[y] = true
		_pres("combo", {"n": int(ev.score)})
	await _banner(" + ".join(names), str(int(ev.score)), GOLD_300 if p == 0 else accent, p == 1)

func _koikoi_fx(ev: Dictionary) -> void:
	var p: = int(ev.p)
	V9Feel.big(null, "combo")
	if p == 1:
		_look_at_camera()
		_say("koikoi", true, true)
		await _brush("Кои-кои!", accent)
		_chip_pop(her_koi)
	else:
		await _brush("Кои-кои!", ROSE_500)
		_chip_pop(my_koi)
		_react("squint")
		_say("you_koi", false)
	_refresh_hud()

# ── решение «Забрать / Кои-кои!» ──────────────────────────────────────────────────────────────

func _show_decision() -> void:
	awaiting = "decide"
	busy = false
	_refresh_hud()
	var y: = y_hand() - 8.0
	sheet = _Sheet.new()
	sheet.position = Vector2(0, y)
	sheet.size = Vector2(W(), Hh() - y)
	sheet.col = NIGHT_700
	sheet.line = Color(GOLD_500, 0.6)
	sheet.z_index = 200
	add_child(sheet)
	var yk: = V10MjKoikoi.yaku_of(k.caps[0])
	var fresh: Array = k.last_yaku[0].keys()
	var title_names: = []
	var orig: = []
	for id in V10MjKoikoi.YAKU_ORDER:
		if yk.has(id):
			title_names.append(V10MjKoikoi.YAKU[id].name)
			orig.append(V10MjKoikoi.YAKU[id].orig)
	var base: = V10MjKoikoi.score_of(yk)
	var mult: = 1 << int(k.koi[0])
	var t: = _lbl(" + ".join(title_names.slice(0, 2)) + (" …" if title_names.size() > 2 else ""), 40, PAPER_100, "title", 700)
	t.position = Vector2(32, 26)
	t.size = Vector2(W() - 64, 52)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	sheet.add_child(t)
	var o: = _lbl(" · ".join(orig.slice(0, 3)), 18, PAPER_500)
	o.position = Vector2(34, 82)
	sheet.add_child(o)
	var sc: = _numeric(str(base * mult), 64, GOLD_300)
	sc.position = Vector2(W() - 32 - 140, 18)
	sc.size = Vector2(140, 76)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sheet.add_child(sc)
	var take: = _btn_primary("Забрать · %d" % (base * mult))
	take.position = Vector2((W() - 560) * 0.5, 128)
	sheet.add_child(take)
	_breathe_btn(take)
	var can_koi: bool = not k.hand[0].is_empty()
	var koi_b: = _btn_secondary("Кои-кои!", accent, 360, 84)
	koi_b.position = Vector2((W() - 360) * 0.5, 252)
	koi_b.visible = can_koi
	sheet.add_child(koi_b)
	take.pressed.connect(func(): _decide(false))
	koi_b.pressed.connect(func(): _decide(true))
	sheet.modulate.a = 0.0
	sheet.position.y += 40
	var tw: = sheet.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "modulate:a", 1.0, dt(0.22))
	tw.tween_property(sheet, "position:y", y, dt(0.22))
	# единственный момент взгляда в камеру
	_look_at_camera()
	_say("dare", true)
	if auto:
		_auto_decide.call_deferred()

func _auto_decide() -> void:
	await wait(0.9)
	if awaiting == "decide":
		_decide(V10MjKoikoiAI.decide_koi(k, 0, "mc", rng))

func _decide(koi: bool) -> void:
	if awaiting != "decide":
		return
	awaiting = ""
	busy = true
	if sheet:
		var s: = sheet
		sheet = null
		var tw: = s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, dt(0.16))
		tw.tween_callback(s.queue_free)
	if koi:
		k.koikoi()
	else:
		k.stop()
	await _consume()
	await _loop()

# ── конец месяца и партии ─────────────────────────────────────────────────────────────────────

func _month_end() -> void:
	await wait(0.4)
	var r: = k.result
	var w: = int(r.get("winner", -1))
	if w == 0:
		_react("pout")
	elif w == 1:
		_react("happy")
	var last: = k.month_no >= k.months_total
	await _tally(r, last)
	if last:
		_show_result()
	else:
		await _begin_month()

func _tally(r: Dictionary, last: bool) -> void:
	awaiting = "next"
	var w: = int(r.get("winner", -1))
	var box: = _Sheet.new()
	var tr: = table_rect()
	box.position = Vector2(24, tr.position.y + 40)
	box.size = Vector2(W() - 48, 420)
	box.col = Color(NIGHT_800, 0.97)
	box.line = Color(GOLD_500, 0.5)
	box.z_index = 200
	add_child(box)
	var title: = "Ничья"
	if w == 0:
		title = "Месяц твой"
	elif w == 1:
		title = "Месяц её"
	var t: = _lbl(title, 44, PAPER_100 if w != 1 else accent.lightened(0.2), "title", 700)
	t.position = Vector2(28, 22)
	box.add_child(t)
	var yk: Dictionary = r.get("yaku", {})
	var y: = 96.0
	for id in V10MjKoikoi.YAKU_ORDER:
		if not yk.has(id):
			continue
		var n: = _lbl(V10MjKoikoi.YAKU[id].name, 24, PAPER_300)
		n.position = Vector2(30, y)
		box.add_child(n)
		var pt: = _numeric(str(int(yk[id])), 24, GOLD_300)
		pt.position = Vector2(box.size.x - 80, y)
		box.add_child(pt)
		y += 38.0
		if y > 280:
			break
	if w >= 0:
		var mline: = ""
		if int(r.mult) > 1:
			mline = "×%d" % int(r.mult)
			if r.get("intercept", false):
				mline += " · Перехват"
		var tot: = _numeric("%d  %s" % [int(r.pts), mline], 40, GOLD_300)
		tot.position = Vector2(30, y + 8)
		box.add_child(tot)
		y += 64.0
	var nb: = _btn_primary("Дальше", 440, 96)
	nb.position = Vector2((box.size.x - 440) * 0.5, y + 24)
	box.size.y = nb.position.y + 120
	box.add_child(nb)
	box.modulate.a = 0.0
	var tw: = box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, dt(0.24))
	if w == 0:
		V9Feel.success(null, "win")
	var done: = [false]
	nb.pressed.connect(func(): done[0] = true)
	if auto:
		await wait(1.2)
		done[0] = true
	while not done[0]:
		await get_tree().process_frame
	var tw2: = box.create_tween()
	tw2.tween_property(box, "modulate:a", 0.0, dt(0.16))
	await tw2.finished
	box.queue_free()
	awaiting = ""

func result_dict() -> Dictionary:
	var win: bool = int(k.totals[0]) > int(k.totals[1])
	var yaku_all: = []
	for h in k.history:
		if int(h.get("winner", -1)) == 0:
			for y in h.yaku:
				if not yaku_all.has(y):
					yaku_all.append(y)
	var rw: = V10MjKoikoiSave.rewards_for(int(k.totals[0]), win)
	return {"mode": "koikoi", "win": win, "score": int(k.totals[0]), "her": int(k.totals[1]), "stars": (3 if k.totals[0] >= k.totals[1] * 2 and win else (2 if win else 0)),
		"time_s": int((Time.get_ticks_msec() - t_start) / 1000), "pairs": pairs, "hero": hero, "seed": int(args.get("seed", 0)),
		"months": k.months_total, "yaku": yaku_all, "rewards": rw}

func _show_result() -> void:
	awaiting = "result"
	busy = true
	var res: = result_dict()
	var rec: = V10MjKoikoiSave.record(hero, int(res.score), bool(res.win), res.yaku)
	res["book_new"] = rec.pages
	res["skin_new"] = rec.skin
	_pres("win" if res.win else "lose", {})
	fx_layer.z_index = 350
	var ov: = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.size = size
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.z_index = 300
	add_child(ov)
	var dim: = ColorRect.new()
	dim.color = Color(NIGHT_900, 0.88)
	dim.size = ov.size
	ov.add_child(dim)
	# она в полный рост справа (обложка журнала)
	var hp: = "res://assets/hero/%s.png" % hero
	if ResourceLoader.exists(hp):
		var hr: = TextureRect.new()
		hr.texture = load(hp)
		hr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var hh: = minf(Hh() * 0.62, 900.0)
		hr.size = Vector2(hh * 848.0 / 1264.0, hh)
		hr.position = Vector2(W() - hr.size.x * 0.82, Hh() * 0.08)
		hr.modulate.a = 0.0
		ov.add_child(hr)
		var t0: = hr.create_tween().set_parallel(true)
		t0.tween_property(hr, "modulate:a", 1.0, dt(0.5))
		t0.tween_property(hr, "position:x", hr.position.x - 30, dt(0.8)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var big: = _lbl("Победа" if res.win else "Почти", 64, GOLD_300 if res.win else PAPER_100, "title", 700)
	big.position = Vector2(32, Hh() * 0.12)
	ov.add_child(big)
	var sc: = _numeric("%d : %d" % [res.score, res.her], 40, PAPER_100)
	sc.position = Vector2(34, Hh() * 0.12 + 84)
	ov.add_child(sc)
	var line: = _lbl(V10MjKoikoiLines.line("win" if res.win else "lose", hero), 26, accent.lightened(0.25), "title", 600)
	var vf: = _voice_font()
	if vf:
		line.label_settings.font = vf
	line.position = Vector2(34, Hh() * 0.12 + 140)
	ov.add_child(line)
	# награды каскадом карточек (≤ 3 жетона, UX §9 P0-3)
	var tokens: = [["Монеты", "+%d" % int(res.rewards.coins), GOLD_300]]
	if int(res.rewards.gems) > 0:
		tokens.append(["Кристаллы", "+%d" % int(res.rewards.gems), Color("c99bff")])
	if not rec.pages.is_empty():
		tokens.append(["Книга", "+%d" % rec.pages.size(), JADE_300])
	var ty: = Hh() * 0.12 + 210
	for i in tokens.size():
		var tk: = _Token.new()
		tk.position = Vector2(32, ty + i * 92)
		tk.size = Vector2(300, 80)
		tk.title = tokens[i][0]
		tk.value = tokens[i][1]
		tk.col = tokens[i][2]
		tk.modulate.a = 0.0
		ov.add_child(tk)
		var tw: = tk.create_tween()
		tw.tween_interval(dt(0.5 + i * 0.08))
		tw.tween_property(tk, "modulate:a", 1.0, dt(0.2))
		tw.tween_callback(func(): V9Feel.sound("star%d" % mini(i, 2), 1.0 + i * 0.12))
	# новая карта альбома: раскрытие переворотом
	if rec.skin != "":
		var cid: = V10MjKoikoi.find(rec.skin)
		var card: = V10MjKoikoiCard.new().setup(cid, false, {rec.skin: true}, true)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.add_child(card)
		card.place(Vector2(W() * 0.5 - 120, Hh() * 0.62), 1.5)
		var nl: = _lbl("Новая карта", 24, GOLD_300, "title", 700)
		nl.size = Vector2(240, 34)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.position = Vector2(W() * 0.5 - 240, Hh() * 0.62 + 150)
		ov.add_child(nl)
		_reveal_later(card)
	var again: = _btn_primary("Ещё партия")
	again.position = Vector2((W() - 560) * 0.5, Hh() - 260)
	ov.add_child(again)
	_breathe_btn(again)
	var out: = _btn_secondary("Выйти", PAPER_300, 300, 80)
	out.position = Vector2((W() - 300) * 0.5, Hh() - 140)
	ov.add_child(out)
	again.pressed.connect(func():
		finished.emit(res.merged({"again": true}))
		_restart(ov))
	out.pressed.connect(func(): finished.emit(res))
	if res.win:
		V9Feel.big(null, "win")
	_last_result = res

var _last_result: = {}

func _reveal_later(card: V10MjKoikoiCard) -> void:
	await wait(1.1)
	if is_instance_valid(card):
		V9Feel.sound("reveal_ssr", 1.0, -4.0)
		card.flip_to(true, dt(0.4))
		_burst(card.center(), GOLD_300, 10)

func _restart(ov: Control) -> void:
	if main != null and not bool(args.get("restart_inside", true)):
		return
	ov.queue_free()
	fx_layer.z_index = 100
	var sd: = int(args.get("seed", 0)) + 1
	args["seed"] = sd
	k = V10MjKoikoi.new()
	k.setup_match(sd, months)
	pairs = 0
	t_start = Time.get_ticks_msec()
	await _begin_month()

# ── пауза и правила (один лист поверх экрана, UX §3.7) ────────────────────────────────────────

func _on_pause() -> void:
	if sheet != null or awaiting == "result":
		return
	_open_sheet("pause")

func _on_help() -> void:
	if sheet != null:
		return
	_open_sheet("help")

func _open_sheet(kind: String) -> void:
	var was_busy: = busy
	busy = true
	var ov: = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.size = size
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.z_index = 400
	add_child(ov)
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = ov.size
	ov.add_child(dim)
	var h: = 420.0 if kind == "pause" else 900.0
	var s: = _Sheet.new()
	s.position = Vector2(0, Hh() - h)
	s.size = Vector2(W(), h)
	s.col = NIGHT_700
	s.line = Color(GOLD_500, 0.5)
	ov.add_child(s)
	var close: = func():
		ov.queue_free()
		busy = was_busy
	if kind == "pause":
		var t: = _lbl("Пауза", 44, PAPER_100, "title", 700)
		t.position = Vector2(32, 28)
		s.add_child(t)
		var go: = _btn_primary("Продолжить")
		go.position = Vector2((W() - 560) * 0.5, 130)
		s.add_child(go)
		go.pressed.connect(close)
		var ex_b: = _btn_secondary("Выйти", PAPER_300, 300, 80)
		ex_b.position = Vector2((W() - 300) * 0.5, 262)
		s.add_child(ex_b)
		ex_b.pressed.connect(func():
			var r: = result_dict()
			r["win"] = false
			r["quit"] = true
			r["rewards"] = {"coins": 0, "gems": 0, "petals": 0, "aff": 0}
			finished.emit(r))
	else:
		var t: = _lbl("Как играть", 44, PAPER_100, "title", 700)
		t.position = Vector2(32, 28)
		s.add_child(t)
		var y: = 96.0
		for line in V10MjKoikoiInfo.HOW:
			var l: = _lbl(line, 22, PAPER_300)
			l.position = Vector2(34, y)
			l.size = Vector2(W() - 68, 32)
			s.add_child(l)
			y += 40.0
		var t2: = _lbl("Комбинации", 26, GOLD_500, "body", 800)
		t2.position = Vector2(32, y + 14)
		s.add_child(t2)
		y += 60.0
		for id in V10MjKoikoi.YAKU_ORDER:
			var page: = V10MjKoikoiBook.page(id)
			var n: = _lbl("%s  ·  %s" % [V10MjKoikoi.YAKU[id].name, page.how], 18, PAPER_300)
			n.position = Vector2(34, y)
			n.size = Vector2(W() - 140, 26)
			n.clip_text = true
			s.add_child(n)
			var pt: = _numeric(str(V10MjKoikoi.YAKU[id].pts) + ("+" if id in ["tan", "tane", "kasu"] else ""), 20, GOLD_300)
			pt.position = Vector2(W() - 90, y - 2)
			s.add_child(pt)
			y += 38.0
		var ok_b: = _btn_primary("Понятно", 440, 96)
		ok_b.position = Vector2((W() - 440) * 0.5, h - 124)
		s.add_child(ok_b)
		ok_b.pressed.connect(close)

# ── героиня в своей полосе (никогда не над столом) ────────────────────────────────────────────

func _breathe() -> void:
	if V9Feel.level() == "min":
		return
	_breath_tw = portrait.create_tween().set_loops()
	_breath_tw.tween_property(portrait, "scale", Vector2(1.006, 1.012), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tw.tween_property(portrait, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _react(kind: String) -> void:
	if portrait == null:
		return
	var tw: = portrait.create_tween()
	match kind:
		"happy":
			tw.tween_property(portrait, "position:y", -8.0, dt(0.14)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(portrait, "position:y", 0.0, dt(0.3)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"impressed":
			tw.tween_property(portrait, "rotation", -0.02, dt(0.2))
			tw.tween_property(portrait, "rotation", 0.0, dt(0.4))
		"squint":
			tw.tween_property(portrait, "position:x", portrait.position.x - 10.0, dt(0.18)).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(portrait, "position:x", portrait.position.x, dt(0.4)).set_trans(Tween.TRANS_QUAD)
		"pout":
			tw.tween_property(portrait, "rotation", 0.025, dt(0.18))
			tw.tween_property(portrait, "rotation", 0.0, dt(0.5))

# Наезд на лицо: она смотрит в камеру. Только в момент «Кои-кои!» (её объявление или твоё решение).
func _look_at_camera() -> void:
	if portrait_atlas == null:
		return
	var from: = portrait_atlas.region
	var tw: = create_tween()
	var setr: = func(t: float) -> void:
		portrait_atlas.region = Rect2(from.position.lerp(_face.position, t), from.size.lerp(_face.size, t))
		portrait.queue_redraw()
	tw.tween_method(setr, 0.0, 1.0, dt(0.38)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dt(1.8))
	var back: = func(t: float) -> void:
		portrait_atlas.region = Rect2(_face.position.lerp(_bust.position, t), _face.size.lerp(_bust.size, t))
		portrait.queue_redraw()
	tw.tween_method(back, 0.0, 1.0, dt(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _say(kind: String, key_moment: bool, force_voice: bool = false) -> void:
	var now: = Time.get_ticks_msec()
	if not key_moment and now - _last_line_ms < 3000:
		return
	var txt: = V10MjKoikoiLines.line(kind, hero)
	if txt == "":
		return
	_last_line_ms = now
	her_line.text = txt
	var tw: = her_line.create_tween()
	her_line.modulate.a = 0.0
	tw.tween_property(her_line, "modulate:a", 1.0, dt(0.25))
	tw.tween_interval(dt(2.6))
	tw.tween_property(her_line, "modulate:a", 0.0, dt(0.3))
	var vkey: String = {"koikoi": "koikoi", "take": "take", "month": "month"}.get(kind, "")
	if vkey != "" and (force_voice or key_moment or now - _last_voice_ms > 20000):
		var vp: = V10MjKoikoiLines.voice_path(hero, vkey)
		if vp != "" and G.S.get("sound", true):
			voice_player.stream = load(vp)
			voice_player.play()
			_last_voice_ms = now

# ── сок ────────────────────────────────────────────────────────────────────────────────────────

func _burst(at: Vector2, col: Color, n: int) -> void:
	if not V9Feel.can_fx():
		return
	n = int(round(n * V9Feel.fx_scale()))
	for i in n:
		var d: = _Spark.new()
		d.col = col
		d.position = at
		fx_layer.add_child(d)
		var ang: = -PI * 0.5 + randf_range(-1.1, 1.1)
		var dist: = randf_range(40.0, 90.0)
		var tw: = d.create_tween().set_parallel(true)
		tw.tween_property(d, "position", at + Vector2.from_angle(ang) * dist, dt(0.42)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "modulate:a", 0.0, dt(0.42))
		tw.chain().tween_callback(d.queue_free)

func _banner(text: String, pts: String, col: Color, hers: bool) -> void:
	V9Feel.sound("combo", 1.0 if not hers else 0.9)
	var b: = Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr: = table_rect()
	b.position = Vector2(0, tr.get_center().y - 60)
	b.size = Vector2(W(), 120)
	fx_layer.add_child(b)
	var stroke: = _Brush.new()
	stroke.col = Color(col.darkened(0.35), 0.55)
	stroke.size = Vector2(W(), 120)
	b.add_child(stroke)
	var l: = _lbl(text, 48, PAPER_100 if not hers else col.lightened(0.55), "title", 700)
	l.size = Vector2(W(), 60)
	l.position = Vector2(0, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings.outline_color = Color(0.07, 0.055, 0.065, 0.9)
	l.label_settings.outline_size = 8
	l.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	l.label_settings.shadow_size = 10
	b.add_child(l)
	var p: = _numeric(pts, 26, GOLD_300)
	p.size = Vector2(W(), 30)
	p.position = Vector2(0, 78)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(p)
	b.modulate.a = 0.0
	b.pivot_offset = b.size * 0.5
	b.scale = Vector2(1.08, 1.08)
	stroke.reveal = 0.0
	var tw: = b.create_tween().set_parallel(true)
	tw.tween_property(b, "modulate:a", 1.0, dt(0.16))
	tw.tween_property(b, "scale", Vector2.ONE, dt(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stroke, "reveal", 1.0, dt(0.32)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(dt(0.7))
	tw.chain().tween_property(b, "modulate:a", 0.0, dt(0.25))
	tw.chain().tween_callback(b.queue_free)
	await wait(1.0)

func _brush(text: String, col: Color) -> void:
	await _banner(text, "×2", col, false)

func _chip_pop(l: Label) -> void:
	l.pivot_offset = Vector2(20, 16)
	var tw: = l.create_tween()
	l.scale = Vector2(1.8, 1.8)
	tw.tween_property(l, "scale", Vector2.ONE, dt(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _breathe_btn(b: Control) -> void:
	if V9Feel.level() == "min":
		return
	var tw: = b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)

func _hint_pulse() -> void:
	# подсказка взглядом: самая ценная карта руки с совпадением чуть приподнимается
	var best: = -1
	var bv: = -1.0
	for c in k.hand[0]:
		if not k.matches(c).is_empty() and V10MjKoikoi.base_value(c) > bv:
			bv = V10MjKoikoi.base_value(c)
			best = c
	if best >= 0:
		var v: = _view(best)
		var tw: = v.create_tween()
		tw.tween_property(v, "modulate", Color(1.25, 1.2, 1.05), 0.3)
		tw.tween_property(v, "modulate", Color.WHITE, 0.5)

func _start_music() -> void:
	var p: String = V10MjKoikoiInfo.INFO.music
	if not ResourceLoader.exists(p):
		return
	if not G.S.get("music", true):
		return
	music_player = AudioStreamPlayer.new()
	music_player.stream = load(p)
	music_player.volume_db = -8.0
	if music_player.stream is AudioStreamOggVorbis:
		(music_player.stream as AudioStreamOggVorbis).loop = true
	elif music_player.stream is AudioStreamMP3:
		(music_player.stream as AudioStreamMP3).loop = true
	add_child(music_player)
	music_player.play()

# ── маленькие рисующие узлы ───────────────────────────────────────────────────────────────────

class _Grad extends Control:
	var top: = Color.BLACK
	var bottom: = Color.TRANSPARENT
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var cols: = PackedColorArray([top, top, bottom, bottom])
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), cols)

class _Tray extends Control:
	var line: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.025, 0.03, 0.45)
		sb.border_color = line
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))

class _Sheet extends Control:
	var col: = Color.BLACK
	var line: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_line(Vector2(24, 1), Vector2(size.x - 24, 1), line, 1.5)

class _Bar extends Control:
	var value: = 0.0
	var col: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), col)

class _Spark extends Control:
	var col: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.2, col)
		draw_circle(Vector2.ZERO, 7.0, Color(col, 0.25))

class _Brush extends Control:
	var col: = Color.WHITE
	var reveal: = 1.0:
		set(v):
			reveal = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		# мазок туши: неровная полоса, «проявляется» слева направо
		var w: = size.x * reveal
		var pts: = PackedVector2Array()
		var n: = 24
		for i in n + 1:
			var x: = w * i / n
			pts.append(Vector2(x, size.y * 0.22 + sin(i * 1.7) * 6.0))
		for i in range(n, -1, -1):
			var x: = w * i / n
			pts.append(Vector2(x, size.y * 0.80 + cos(i * 1.3) * 7.0))
		if w > 2.0:
			draw_colored_polygon(pts, col)

class _Token extends Control:
	var title: = ""
	var value: = ""
	var col: = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("26212a")
		sb.border_color = Color(col, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f: = UI.font("body", 800)
		draw_string(f, Vector2(20, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ddd2c4"))
		var fn: = UI.font("body", 900)
		draw_string(fn, Vector2(20, 54), value, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 40, 34, col)

class _Icon extends Button:
	var kind: = "pause"
	func _draw() -> void:
		var c: = Vector2(40, 40)
		var col: = Color("ddd2c4")
		if kind == "pause":
			draw_line(c + Vector2(-7, -12), c + Vector2(-7, 12), col, 3.0, true)
			draw_line(c + Vector2(7, -12), c + Vector2(7, 12), col, 3.0, true)
		else:
			draw_arc(c, 18.0, 0, TAU, 40, col, 2.5, true)
			var f: = UI.font("body", 900)
			draw_string(f, c + Vector2(-7, 10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
