class_name V10LuckyWheelScreen
extends Control

# Screen "v10wheel" — «Колесо Удачи Чайной» (0.12.0). 8 sectors, 1 free spin a day, then 80 crystals (5 extra a day).
# Save: G.S["v10_wheel"] = {day, free_used, paid, total, hist}.

const SAVE_KEY: = "v10_wheel"
const PAID_COST: = 80
const PAID_MAX: = 5
const WHEEL_TEX: = "res://assets/v10/hf_ui/wheel_fortune_bg.webp"
const WHEEL_PX: = 560.0

# Clockwise from the top; golden spokes lie at i * 45 deg, so sector i is centred at (i + 0.5) * 45 deg.
const SECTORS: Array[Dictionary] = [
	{"label": "300 крист.", "short": "300\nкрист.", "gems": 300, "w": 3},
	{"label": "2 Билета", "short": "2\nБилета", "tickets": 2, "w": 5},
	{"label": "+80 Чая", "short": "+80\nЧая", "tea": 80, "w": 30},
	{"label": "Шёлковый веер ♥", "short": "Веер\n♥", "gift": "gift_silk_fan", "w": 6},
	{"label": "150 крист.", "short": "150\nкрист.", "gems": 150, "w": 15},
	{"label": "1 500 монет", "short": "1 500\nмонет", "coins": 1500, "w": 36},
	{"label": "Нефритовая заколка ♥", "short": "Заколка\n♥", "gift": "gift_jade_pin", "w": 2},
	{"label": "ДЖЕКПОТ · 800 крист.", "short": "800\nДЖЕКПОТ", "gems": 800, "w": 1, "jackpot": true},
]


static func sector_angle_deg(idx: int) -> float:
	return (float(idx) + 0.5) * 45.0


static func sector_short_label(idx: int) -> String:
	var d: Dictionary = SECTORS[posmod(idx, SECTORS.size())]
	return str(d.get("short", d.get("label", "")))


static func state() -> Dictionary:
	var root: Dictionary = G.S
	if not (root.get(SAVE_KEY) is Dictionary):
		root[SAVE_KEY] = {}
	var st: Dictionary = root[SAVE_KEY]
	var today: = V10Meta.day_key()
	if str(st.get("day", "")) != today:
		st["day"] = today
		st["free_used"] = false
		st["paid"] = 0
	st["free_used"] = bool(st.get("free_used", false))
	st["paid"] = int(st.get("paid", 0))
	st["total"] = int(st.get("total", 0))
	if not (st.get("hist") is Array):
		st["hist"] = []
	return st


static func free_spin_ready() -> bool:
	return not bool(state().free_used)


static func paid_left() -> int:
	return maxi(0, PAID_MAX - int(state().paid))


static func next_cost() -> int:
	return 0 if free_spin_ready() else PAID_COST


static func can_spin() -> bool:
	if free_spin_ready():
		return true
	return paid_left() > 0 and V10Money.can({"gems": PAID_COST})


static func total_weight() -> int:
	var s: = 0
	for d in SECTORS:
		s += int(d.w)
	return s


# r in [0,1) -> sector index (weighted)
static func pick_sector(r: float) -> int:
	var x: = r * float(total_weight())
	var acc: = 0.0
	for i in SECTORS.size():
		acc += float(SECTORS[i].w)
		if x < acc:
			return i
	return SECTORS.size() - 1


static func apply_reward(idx: int) -> String:
	var d: Dictionary = SECTORS[idx]
	if int(d.get("gems", 0)) > 0:
		V10Money.grant({"gems": int(d.gems)}, "wheel")
	if int(d.get("tickets", 0)) > 0:
		V10Money.grant({"tickets": int(d.tickets)}, "wheel")
	if int(d.get("coins", 0)) > 0:
		V10Money.grant({"coins": int(d.coins)}, "wheel")
	if int(d.get("tea", 0)) > 0:
		V10Stamina.grant(int(d.tea))
	if str(d.get("gift", "")) != "":
		V10AffCurve.grant_gift(str(d.gift), 1)
	return str(d.label)


# force < 0: random by weights. Pays the price and the prize at once (no exploit by closing the screen mid-spin).
static func spin(force: int = -1, r: float = -1.0) -> Dictionary:
	var st: = state()
	var free: = free_spin_ready()
	if not free:
		if paid_left() <= 0:
			return {"ok": false, "reason": "limit"}
		if not V10Money.spend({"gems": PAID_COST}, "wheel"):
			return {"ok": false, "reason": "gems"}
		st["paid"] = int(st.paid) + 1
	else:
		st["free_used"] = true
	var idx: = force if force >= 0 else pick_sector(randf() if r < 0.0 else r)
	var label: = apply_reward(idx)
	st["total"] = int(st.total) + 1
	var h: Array = st.hist
	h.push_front(label)
	while h.size() > 6:
		h.pop_back()
	G.save()
	return {"ok": true, "sector": idx, "free": free, "cost": 0 if free else PAID_COST, "label": label}


# ── UI ───────────────────────────────────────────────────────────────────────────────────────────────────────────

var main
var W: = 720.0
var H: = 1280.0
var _wheel: _Wheel
var _pointer: Control
var _btn_holder: Control
var _info: Label
var _hist: Label
var _fx: Control
var _spinning: = false
var _last_tick: = 0
var _center: = Vector2.ZERO
var _result_panel: Control


func build(m, _args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	Sfx.music("menu")
	var br: = V10Layout.bleed_rect(self)
	var base: = ColorRect.new()
	base.color = Color("#14060F")
	base.position = br.position
	base.size = br.size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	Common.backdrop(self, "bg_palace", size, 2.2, 0.42).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scrim: = ColorRect.new()
	scrim.color = Color(0.15, 0.02, 0.08, 0.44)
	scrim.position = br.position
	scrim.size = br.size
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	Common.vignette(self, size, Color(0.34, 0.04, 0.1), 0.52).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fx.ambient(self, "petals", size)
	var safe_t: = _safe_top()
	var safe_b: = _safe_bot()
	var back_b: = V10VipBoudoirScreen._pill(Rect2(16, 16 + safe_t, 64, 56), Color(0.13, 0.06, 0.19, 0.9), Color("#E8C47E"), 18)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	back_b.add_child(UI.center_label(UI.label("‹", 34, Color("#FFF4DE"), Color(0.06, 0.02, 0.1), 3, "body", 900), Rect2(0, -3, 64, 56)))
	back_b.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e):
			back_b.accept_event()
			V9Feel.press(back_b, "tap")
			_back())
	add_child(back_b)
	add_child(UI.center_label(UI.label("Колесо Удачи Чайной", 34, Color("#FFE9A6"), Color(0.2, 0.03, 0.1), 6, "body", 900), Rect2(88, 20 + safe_t, W - 176, 50)))
	_info = UI.center_label(UI.label("", 22, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 4, "body", 800), Rect2(20, 90 + safe_t, W - 40, 34))
	add_child(_info)
	_center = Vector2(W * 0.5, clampf(H * 0.37 + safe_t * 0.35, 430.0 + safe_t, H - safe_b - WHEEL_PX * 0.5 - 260.0))
	var aura: = Sprite2D.new()
	aura.texture = G.fx("glow")
	aura.material = Fx.add_mat()
	aura.position = _center
	aura.scale = Vector2.ONE * 7.2
	aura.modulate = Color(1.0, 0.78, 0.36, 0.24)
	add_child(aura)
	_wheel = _Wheel.new()
	_wheel.size = Vector2(WHEEL_PX, WHEEL_PX)
	_wheel.position = _center - _wheel.size * 0.5
	_wheel.pivot_offset = _wheel.size * 0.5
	_wheel.rotation_degrees = 360.0 - sector_angle_deg(7)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel)
	_wheel.setup()
	_pointer = _Pointer.new()
	_pointer.size = Vector2(70, 96)
	_pointer.pivot_offset = Vector2(35, 22)
	_pointer.position = Vector2(_center.x - 35.0, _center.y - WHEEL_PX * 0.5 - 38.0)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.z_index = 5
	add_child(_pointer)
	_btn_holder = Control.new()
	_btn_holder.position = Vector2(0, minf(_center.y + WHEEL_PX * 0.5 + 40.0, H - safe_b - 230.0))
	_btn_holder.size = Vector2(W, 130)
	add_child(_btn_holder)
	_hist = UI.center_label(UI.label("", 20, Color("#EDE0CE"), Color(0.06, 0.02, 0.1), 3, "body", 700), Rect2(30, _btn_holder.position.y + 140.0, W - 60, 90))
	V10VipBoudoirScreen.wrap_size(_hist, Vector2(W - 60, 90))
	add_child(_hist)
	_fx = Control.new()
	_fx.size = size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = 60
	add_child(_fx)
	set_meta("v8_back", _back)
	_refresh()


func _refresh() -> void:
	var st: = state()
	if free_spin_ready():
		_info.text = "Сегодня: 1 бесплатное вращение!"
	else:
		_info.text = "Ещё вращений сегодня: %d · кристаллов: %d" % [paid_left(), V10Money.bal("gems")]
	var hs: Array = st.hist
	_hist.text = ("Последние призы: " + " · ".join(PackedStringArray(hs))) if not hs.is_empty() else "Крути колесо — призы выдаются сразу"
	for c in _btn_holder.get_children():
		c.queue_free()
	var free: = free_spin_ready()
	var txt: = "Крутить бесплатно!" if free else ("Крутить за %d крист." % PAID_COST if paid_left() > 0 else "Лимит на сегодня")
	var b: = V10Button.make("play", txt, Vector2(580, 104))
	b.position = Vector2((W - 580.0) * 0.5, 0)
	var ok: = can_spin() and not _spinning
	b.modulate = Color.WHITE if ok else Color(0.65, 0.65, 0.7, 0.9)
	b.breathing = free and ok
	b.pressed.connect(_on_spin)
	_btn_holder.add_child(b)


func _on_spin() -> void:
	if _spinning:
		return
	if not can_spin():
		if main != null and main.has_method("toast"):
			main.toast("Не хватает кристаллов или лимит исчерпан", "lock")
		return
	var res: = spin()
	if not bool(res.get("ok", false)):
		return
	_spinning = true
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	var idx: = int(res.sector)
	var cur: = _wheel.rotation_degrees
	var target: = (floorf(cur / 360.0) + 6.0) * 360.0 - sector_angle_deg(idx)
	_last_tick = _sector_under()
	Sfx.play("whoosh", 1.0, -6.0)
	var tw: = create_tween()
	tw.tween_property(_wheel, "rotation_degrees", target, 5.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_stopped.bind(res))
	_refresh()


func _sector_under() -> int:
	return int(floorf(-_wheel.rotation_degrees / 45.0))


func _process(_dt: float) -> void:
	if not _spinning:
		return
	var s: = _sector_under()
	if s != _last_tick:
		_last_tick = s
		Sfx.play("tap" if s % 2 == 0 else "clack0", 1.0 + 0.1 * float(posmod(s, 3)), -8.0)
		_pointer.rotation = 0.55
		create_tween().tween_property(_pointer, "rotation", 0.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_stopped(res: Dictionary) -> void:
	_spinning = false
	var jackpot: bool = bool(SECTORS[int(res.sector)].get("jackpot", false))
	Sfx.play("reveal_ssr" if jackpot else "win", 1.0, -3.0)
	Sfx.say("mc", "ssr" if jackpot else "win")
	Fx.burst(_fx, _center, "sparkle", 48 if jackpot else 26)
	Fx.burst(_fx, _center, "heart", 12)
	Fx.flash_glow(_fx, _center, Color(1, 0.85, 0.5), 4.0 if jackpot else 2.4, 0.6)
	var fl: = Fx.float_text(_fx, _center + Vector2(0, -80), "+ " + str(res.label), Color("#FFE9A6"), 36)
	Common.fit_line(fl, W - 48.0, 22)
	fl.position.x = 24.0
	fl.size.x = W - 48.0
	fl.pivot_offset.x = (W - 48.0) * 0.5
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	_refresh()


func _safe_top() -> float:
	if main != null and main.get("safe_top") != null:
		return maxf(0.0, float(main.safe_top) - position.y)
	return maxf(0.0, float(V10Layout.safe_insets(size).get("top", 0.0)) - position.y)


func _safe_bot() -> float:
	var vp_h: = get_viewport_rect().size.y if is_inside_tree() else H
	var extra: = maxf(0.0, vp_h - (position.y + size.y))
	if main != null and main.get("safe_bottom") != null:
		return maxf(0.0, float(main.safe_bottom) - extra)
	return maxf(0.0, float(V10Layout.safe_insets(size).get("bottom", 0.0)) - extra)


func _back() -> void:
	if main != null and main.has_method("back"):
		main.back()


class _Wheel extends Control:
	var _art: Texture2D

	func setup() -> void:
		_art = V10VipBoudoirScreen._load_tex(WHEEL_TEX)
		if _art != null:
			var tr: = TextureRect.new()
			tr.texture = _art
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.size = size
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tr)
		var R: = size.x * 0.5
		var mid_r: = R * 0.58
		var bw: = 96.0
		var bh: = 52.0
		for i in SECTORS.size():
			var arm: = Control.new()
			arm.position = size * 0.5
			var ang: = V10LuckyWheelScreen.sector_angle_deg(i)
			arm.rotation = deg_to_rad(ang)
			arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(arm)
			var txt: = V10LuckyWheelScreen.sector_short_label(i)
			var lb: = UI.label(txt, 17, Color("#FFFFFF"), Color(0.13, 0.01, 0.05, 0.98), 5, "body", 900)
			var ls: LabelSettings = lb.label_settings
			ls.line_spacing = -2.0
			var fs: int = ls.font_size
			while fs > 14:
				var widest: = 0.0
				for ln in txt.split("\n"):
					widest = maxf(widest, ls.font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0)
				if widest <= 88.0:
					break
				fs -= 1
			ls.font_size = fs
			lb.position = Vector2(-bw * 0.5, -mid_r - bh * 0.5)
			lb.size = Vector2(bw, bh)
			if ang > 90.0 and ang < 270.0:
				lb.pivot_offset = lb.size * 0.5
				lb.rotation = PI
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lb.autowrap_mode = TextServer.AUTOWRAP_OFF
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arm.add_child(lb)

	func _draw() -> void:
		var c: = size * 0.5
		var R: = size.x * 0.5
		if _art != null:
			return
		else:
			draw_circle(c, R, Color("#D9A93C"))
			for i in SECTORS.size():
				var pts: = PackedVector2Array([c])
				for k in 13:
					var a: = deg_to_rad(float(i) * 45.0 + float(k) * 45.0 / 12.0)
					pts.append(c + Vector2(sin(a), -cos(a)) * (R - 22.0))
				var col: = Color("#B3162F") if i % 2 == 0 else Color("#F6D58A")
				if bool(SECTORS[i].get("jackpot", false)):
					col = Color("#8A1C8F")
				draw_colored_polygon(pts, col)
				var a0: = deg_to_rad(float(i) * 45.0)
				draw_line(c, c + Vector2(sin(a0), -cos(a0)) * (R - 22.0), Color("#FFE9A6"), 3.0)
			for k in 24:
				var ab: = float(k) * TAU / 24.0
				draw_circle(c + Vector2(sin(ab), -cos(ab)) * (R - 11.0), 6.0, Color("#FFF6D0"))
			draw_arc(c, R - 22.0, 0, TAU, 64, Color("#FFE9A6"), 4.0)
			draw_circle(c, 64.0, Color("#D9A93C"))
			draw_circle(c, 52.0, Color("#6B0F26"))
			draw_string(ThemeDB.fallback_font, c + Vector2(-16, 14), "福", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#FFE9A6"))


class _Pointer extends Control:
	func _draw() -> void:
		var pts: = PackedVector2Array([Vector2(35, 94), Vector2(6, 26), Vector2(14, 8), Vector2(56, 8), Vector2(64, 26)])
		draw_colored_polygon(pts, Color("#FFD36E"))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color("#7A4A12"), 3.0)
		draw_circle(Vector2(35, 30), 10.0, Color("#B3162F"))
