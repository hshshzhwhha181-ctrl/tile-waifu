class_name V10Stamina
extends RefCounted

# V10Stamina — «Чашки чая» energy / stamina system for Tile Waifu 0.11.0.
# Persisted in G.S["v10_stamina"]:
#   {cur, max, last_ts, refills_today, refill_day, kettle_noon_day, kettle_eve_day}
# Base cap 120 (+5 per rank tier), regenerates 1 cup per 360 sec (6 min).

const SAVE_KEY: = "v10_stamina"
const BASE_CAP: = 120
const CAP_PER_TIER: = 5
const REGEN_SEC: = 360
const HARD_MAX: = 2000

const ONBOARDING_MAX_LEVEL: = 5
const COST_NORMAL: = 6
const COST_PATH_BOSS: = 12
const COST_ADVENTURE_BOSS: = 15
const ADVENTURE_DEFEAT_REFUND: = 10

const REFILL_AMOUNT: = 80
const REFILL_COSTS: = [50, 80, 120, 180]
const KETTLE_AMOUNT: = 60
const NOON_START_H: = 12
const NOON_END_H: = 16
const EVE_START_H: = 18
const EVE_END_H: = 23

const GROUP_PILLS: = "v10_stamina_pills"

static var _bound_root: Variant = null


static func bind_root(s_root: Dictionary) -> void:
	_bound_root = s_root
	ensure(s_root)


static func unbind_root() -> void:
	_bound_root = null


static func _g():
	if _bound_root is Dictionary:
		return null
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null


static func _root() -> Dictionary:
	if _bound_root is Dictionary:
		return _bound_root as Dictionary
	var g = _g()
	if g != null and g.get("S") is Dictionary:
		return g.S
	return {}


static func _rank_tier(s_root: Dictionary) -> int:
	var rp: = maxi(0, int(s_root.get("rp", 0)))
	var g = _g()
	if g != null and g.has_method("rank_of"):
		return clampi(int(g.rank_of(rp).get("tier", 0)), 0, 10)
	var per_tiers: = [60, 100, 150, 220, 300, 400]
	var left: = rp
	for t in per_tiers.size():
		var subs: = 3 if t < per_tiers.size() - 1 else 999
		for _s in subs:
			if left < per_tiers[t]:
				return t
			left -= per_tiers[t]
	return per_tiers.size() - 1


static func defaults() -> Dictionary:
	return {
		"cur": BASE_CAP,
		"max": BASE_CAP,
		"last_ts": 0,
		"refills_today": 0,
		"refill_day": "",
		"kettle_noon_day": "",
		"kettle_eve_day": "",
	}


static func ensure(s_root: Variant = null) -> Dictionary:
	var r: Dictionary = s_root if s_root is Dictionary else _root()
	var max_c: = BASE_CAP + CAP_PER_TIER * _rank_tier(r)
	var fresh: = not (r.get(SAVE_KEY) is Dictionary) or not (r[SAVE_KEY] as Dictionary).has("cur")
	if not (r.get(SAVE_KEY) is Dictionary):
		r[SAVE_KEY] = {}
	var st: Dictionary = r[SAVE_KEY]
	var df: = defaults()
	for k in df:
		if not st.has(k):
			st[k] = df[k]
	st["max"] = max_c
	if fresh:
		st["cur"] = max_c
		st["last_ts"] = V10Meta.now_unix()
	else:
		st["cur"] = clampi(int(st.get("cur", max_c)), 0, HARD_MAX)
		st["last_ts"] = int(st.get("last_ts", 0))
	st["refills_today"] = maxi(0, int(st.get("refills_today", 0)))
	st["refill_day"] = str(st.get("refill_day", ""))
	st["kettle_noon_day"] = str(st.get("kettle_noon_day", ""))
	st["kettle_eve_day"] = str(st.get("kettle_eve_day", ""))
	if int(st["last_ts"]) <= 0:
		st["last_ts"] = V10Meta.now_unix()
	return st


static func cap() -> int:
	var r: = _root()
	var c: = BASE_CAP + CAP_PER_TIER * _rank_tier(r)
	if r.get(SAVE_KEY) is Dictionary:
		r[SAVE_KEY]["max"] = c
	return c


static func _sync_day(st: Dictionary) -> void:
	var d: = V10Meta.day_key()
	if str(st.get("refill_day", "")) != d:
		st["refill_day"] = d
		st["refills_today"] = 0


static func _tick() -> Dictionary:
	var st: = ensure()
	var c: = cap()
	st["max"] = c
	_sync_day(st)
	var now: = V10Meta.now_unix()
	var cur: = int(st.get("cur", c))
	var last_ts: = int(st.get("last_ts", now))
	if last_ts <= 0:
		st["last_ts"] = now
		return st
	if cur >= c:
		st["last_ts"] = now
		return st
	if now <= last_ts:
		return st
	var gained: = (now - last_ts) / REGEN_SEC
	if gained > 0:
		var nc: = mini(c, cur + gained)
		st["cur"] = nc
		if nc >= c:
			st["last_ts"] = now
		else:
			st["last_ts"] = last_ts + gained * REGEN_SEC
	return st


static func current() -> int:
	var st: = _tick()
	return int(st.get("cur", BASE_CAP))


static func next_regen_sec() -> int:
	var st: = _tick()
	var c: = int(st.get("max", BASE_CAP))
	if int(st.get("cur", c)) >= c:
		return 0
	var now: = V10Meta.now_unix()
	var last_ts: = int(st.get("last_ts", now))
	return clampi(last_ts + REGEN_SEC - now, 0, REGEN_SEC)


static func full_regen_sec() -> int:
	var st: = _tick()
	var c: = int(st.get("max", BASE_CAP))
	var miss: = c - int(st.get("cur", c))
	if miss <= 0:
		return 0
	return next_regen_sec() + (miss - 1) * REGEN_SEC


static func can_spend(cost: int) -> bool:
	return cost <= 0 or current() >= cost


static func spend(cost: int, _reason: String = "") -> bool:
	if cost <= 0:
		return true
	var st: = _tick()
	var c: = int(st.get("max", BASE_CAP))
	var cur: = int(st.get("cur", 0))
	if cur < cost:
		return false
	var was_full: = cur >= c
	st["cur"] = cur - cost
	if was_full and int(st["cur"]) < c:
		st["last_ts"] = V10Meta.now_unix()
	_notify_pills()
	return true


static func grant(amount: int) -> int:
	if amount <= 0:
		return 0
	var st: = _tick()
	var c: = int(st.get("max", BASE_CAP))
	var cur: = int(st.get("cur", 0))
	var nv: = mini(HARD_MAX, cur + amount)
	var added: = maxi(0, nv - cur)
	st["cur"] = nv
	if nv >= c:
		st["last_ts"] = V10Meta.now_unix()
	_notify_pills()
	return added


static func refund(amount: int) -> int:
	return grant(amount)


static func cost_for_level(lvl: int, mode: String = "path") -> int:
	if mode == "adventure":
		return COST_ADVENTURE_BOSS
	if lvl <= ONBOARDING_MAX_LEVEL:
		return 0
	if lvl % 10 == 0 or V10LevelGen.is_boss(lvl - 1):
		return COST_PATH_BOSS
	return COST_NORMAL


static func cost_for_index(idx: int, mode: String = "path") -> int:
	return cost_for_level(idx + 1, mode)


static func cost_for_adventure_boss() -> int:
	return COST_ADVENTURE_BOSS


static func refund_adventure_defeat() -> int:
	return refund(ADVENTURE_DEFEAT_REFUND)


static func refills_today() -> int:
	var st: = _tick()
	return int(st.get("refills_today", 0))


static func refill_price() -> int:
	var idx: = clampi(refills_today(), 0, REFILL_COSTS.size() - 1)
	return int(REFILL_COSTS[idx])


static func buy_refill() -> bool:
	var st: = _tick()
	if int(st.get("cur", 0)) + REFILL_AMOUNT > HARD_MAX:
		return false
	var price: = refill_price()
	if _bound_root is Dictionary:
		var r: = _bound_root as Dictionary
		var have: = int(r.get("gems", 0))
		if have < price:
			return false
		r["gems"] = have - price
	else:
		if V10Money.can({"gems": price}):
			V10Money.spend({"gems": price}, "tea_refill")
		else:
			var e: = V10Money.econ()
			var prem: = e.wallet.premium() if e != null else V10Money.bal("gems")
			if e == null or prem < price:
				return false
			e.wallet.spend_premium(price, "tea_refill")
			V10Money.sync(_root())
	st["refills_today"] = int(st.get("refills_today", 0)) + 1
	grant(REFILL_AMOUNT)
	var g = _g()
	if g != null and g.has_method("save"):
		g.save()
	return true


static func kettle_slot() -> String:
	var dt: = V10Meta.local_dt(V10Meta.now_unix())
	var h: = int(dt.get("hour", 0))
	if h >= NOON_START_H and h < NOON_END_H:
		return "noon"
	if h >= EVE_START_H and h < EVE_END_H:
		return "eve"
	return ""


static func kettle_ready() -> bool:
	var st: = _tick()
	var slot: = kettle_slot()
	if slot == "":
		return false
	var d: = V10Meta.day_key()
	if slot == "noon":
		return str(st.get("kettle_noon_day", "")) != d
	return str(st.get("kettle_eve_day", "")) != d


static func claim_kettle() -> bool:
	var st: = _tick()
	var slot: = kettle_slot()
	if slot == "":
		return false
	var d: = V10Meta.day_key()
	if slot == "noon":
		if str(st.get("kettle_noon_day", "")) == d:
			return false
		st["kettle_noon_day"] = d
	else:
		if str(st.get("kettle_eve_day", "")) == d:
			return false
		st["kettle_eve_day"] = d
	grant(KETTLE_AMOUNT)
	var g = _g()
	if g != null and g.has_method("save"):
		g.save()
	return true


static func fmt_mmss(sec: int) -> String:
	var s: = maxi(0, sec)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


static func _notify_pills() -> void:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP_PILLS):
		if is_instance_valid(n) and n.has_method("refresh_stamina"):
			n.call("refresh_stamina")


# ── HUD Pill & Popup Sheet ──────────────────────────────────────────────────────────────────────────────────────

static func make_pill(main) -> Control:
	var p: = _TeaPill.new()
	p.main_ref = main
	p.setup()
	return p


static func open_sheet(main) -> Control:
	if main == null or not ("overlay" in main) or main.overlay == null:
		return null
	var sh: = V10BottomSheet.open(main, "Чашки чая")
	var body_ctrl: = _TeaSheetBody.new()
	body_ctrl.setup(main, sh)
	sh.add_body(body_ctrl, 0.0)
	sh.finish(body_ctrl.total_h)
	return sh


class _TeaPill:
	extends Control
	var main_ref
	var _lbl: Label
	var _dot: Control
	var _acc: = 0.0
	var _down: = false

	func setup() -> void:
		name = "TeaPill"
		size = Vector2(156, 48)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("v10_tap", true)
		add_to_group(V10Stamina.GROUP_PILLS)
		var t: Texture2D = load("res://assets/v10/shop/item_tea.png") if ResourceLoader.exists("res://assets/v10/shop/item_tea.png") else null
		if t:
			var ic: = TextureRect.new()
			ic.texture = t
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.position = Vector2(8, 6)
			ic.size = Vector2(36, 36)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ic)
		_lbl = V10Type.label("", "num", 22, V10DS.PAPER_100)
		_lbl.position = Vector2(46, 0)
		_lbl.size = Vector2(100, 48)
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_lbl)
		_dot = _Dot.new()
		_dot.position = Vector2(142, 4)
		_dot.size = Vector2(10, 10)
		add_child(_dot)
		refresh_stamina()
		set_process(true)

	func _has_point(pt: Vector2) -> bool:
		return Rect2(Vector2(0, -16), size + Vector2(0, 32)).has_point(pt)

	func _process(dt: float) -> void:
		_acc += dt
		if _acc >= 1.0:
			_acc = 0.0
			refresh_stamina()

	func refresh_stamina() -> void:
		if is_instance_valid(_lbl):
			_lbl.text = "%d/%d" % [V10Stamina.current(), V10Stamina.cap()]
		if is_instance_valid(_dot):
			_dot.visible = V10Stamina.kettle_ready()
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if not ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch):
			return
		if e.pressed:
			_down = true
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			if _has_point(e.position):
				V9Feel.haptic("button")
				V9Feel.sound("pop", 1.0, -5.0)
				V10Stamina.open_sheet(main_ref)
		accept_event()

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), true, _down, V10Stamina.kettle_ready(), false, false, -1.0, Color.TRANSPARENT)


class _Dot:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size * 0.5, 4.5, V10DS.GOLD_300)


class _TeaBar:
	extends Control
	var ratio: = 1.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var track: = StyleBoxFlat.new()
		track.bg_color = V10DS.NIGHT_800
		track.set_corner_radius_all(6)
		track.set_border_width_all(1)
		track.border_color = Color(V10DS.GOLD_700, 0.55)
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var fw: = maxf(0.0, (size.x - 4.0) * clampf(ratio, 0.0, 1.0))
		if fw > 2.0:
			var fill: = StyleBoxFlat.new()
			fill.bg_color = V10DS.JADE_300 if ratio < 1.0 else V10DS.GOLD_300
			fill.set_corner_radius_all(4)
			draw_style_box(fill, Rect2(2, 2, fw, size.y - 4.0))


class _TeaSheetBody:
	extends Control
	var main_ref
	var sheet_ref: V10BottomSheet
	var total_h: = 472.0
	var _cur_lbl: Label
	var _timer_lbl: Label
	var _bar: _TeaBar
	var _kettle_sub: Label
	var _kettle_btn: V10Button
	var _refill_sub: Label
	var _refill_btn: V10ShopW.Chip
	var _acc: = 0.0

	func setup(m, sh: V10BottomSheet) -> void:
		main_ref = m
		sheet_ref = sh
		size = Vector2(656, total_h)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_to_group(V10Stamina.GROUP_PILLS)

		var top_card: = V10ShopW.Lac.new()
		top_card.over_art = false
		top_card.selected = true
		top_card.position = Vector2(0, 0)
		top_card.size = Vector2(656, 136)
		add_child(top_card)

		var tea_tex: Texture2D = load("res://assets/v10/shop/item_tea.png") if ResourceLoader.exists("res://assets/v10/shop/item_tea.png") else null
		if tea_tex:
			top_card.add_child(V10ShopKit.art(tea_tex, Rect2(18, 20, 88, 88)))

		_cur_lbl = V10Type.label("", "num", 40, V10DS.GOLD_300)
		_cur_lbl.position = Vector2(124, 14)
		_cur_lbl.size = Vector2(508, 48)
		top_card.add_child(_cur_lbl)

		_bar = _TeaBar.new()
		_bar.position = Vector2(124, 68)
		_bar.size = Vector2(508, 16)
		top_card.add_child(_bar)

		_timer_lbl = V10Type.label("", "ui", 18, V10DS.PAPER_300)
		_timer_lbl.position = Vector2(124, 92)
		_timer_lbl.size = Vector2(508, 28)
		top_card.add_child(_timer_lbl)

		var rules: = V10Type.label("Путь 1–5: 0 · Путь 6+: 6 · Босс: 12 · Приключение: 15 (возврат 10)", "ui", 18, V10DS.PAPER_500)
		rules.position = Vector2(4, 148)
		rules.size = Vector2(648, 28)
		add_child(rules)

		# Free daily kettle card
		var ket_card: = V10ShopW.Lac.new()
		ket_card.over_art = false
		ket_card.position = Vector2(0, 188)
		ket_card.size = Vector2(656, 118)
		add_child(ket_card)

		var kt_ov: = V10Type.label("ЧАЙНИК ДНЯ · БЕСПЛАТНО", "overline", 15, V10DS.JADE_300)
		kt_ov.position = Vector2(22, 16)
		kt_ov.size = Vector2(400, 22)
		ket_card.add_child(kt_ov)

		var kt_tl: = V10Type.label("Горячий улун +%d чашек" % V10Stamina.KETTLE_AMOUNT, "ui_strong", 22, V10DS.PAPER_100)
		kt_tl.position = Vector2(22, 42)
		kt_tl.size = Vector2(400, 32)
		ket_card.add_child(kt_tl)

		_kettle_sub = V10Type.label("", "ui", 18, V10DS.PAPER_300)
		_kettle_sub.position = Vector2(22, 76)
		_kettle_sub.size = Vector2(410, 26)
		ket_card.add_child(_kettle_sub)

		_kettle_btn = V10Button.make("play", "Налить +60", Vector2(200, 80))
		_kettle_btn.position = Vector2(440, 19)
		_kettle_btn.pressed.connect(_on_claim_kettle)
		ket_card.add_child(_kettle_btn)

		# Crystal refill card
		var ref_card: = V10ShopW.Lac.new()
		ref_card.over_art = false
		ref_card.position = Vector2(0, 322)
		ref_card.size = Vector2(656, 126)
		add_child(ref_card)

		var rf_ov: = V10Type.label("СВЕЖАЯ ЗАВАРКА · МГНОВЕННО", "overline", 15, V10DS.GOLD_500)
		rf_ov.position = Vector2(22, 16)
		rf_ov.size = Vector2(400, 22)
		ref_card.add_child(rf_ov)

		var rf_tl: = V10Type.label("+%d чашек чая сразу" % V10Stamina.REFILL_AMOUNT, "ui_strong", 22, V10DS.PAPER_100)
		rf_tl.position = Vector2(22, 42)
		rf_tl.size = Vector2(400, 32)
		ref_card.add_child(rf_tl)

		_refill_sub = V10Type.label("", "ui", 18, V10DS.PAPER_300)
		_refill_sub.position = Vector2(22, 78)
		_refill_sub.size = Vector2(400, 26)
		ref_card.add_child(_refill_sub)

		_refill_btn = V10ShopW.Chip.new().setup(V10ShopKit.tex("item_crystal"), "50 · Заварить", Vector2(236, 68))
		_refill_btn.position = Vector2(404, 29)
		_refill_btn.pressed.connect(_on_buy_refill)
		ref_card.add_child(_refill_btn)

		refresh_stamina()
		set_process(true)

	func _process(dt: float) -> void:
		_acc += dt
		if _acc >= 1.0:
			_acc = 0.0
			refresh_stamina()

	func refresh_stamina() -> void:
		var cur: = V10Stamina.current()
		var mx: = V10Stamina.cap()
		_cur_lbl.text = "%d / %d чашек" % [cur, mx]
		_bar.ratio = clampf(float(cur) / float(maxi(1, mx)), 0.0, 1.0)
		_bar.queue_redraw()
		var nxt: = V10Stamina.next_regen_sec()
		if nxt <= 0:
			_timer_lbl.text = "Чайник полон · +1 чашка каждые 6 мин"
		else:
			_timer_lbl.text = "+1 через %s · полный запас через %s" % [V10Stamina.fmt_mmss(nxt), V10Stamina.fmt_mmss(V10Stamina.full_regen_sec())]
		var kr: = V10Stamina.kettle_ready()
		_kettle_btn.modulate.a = 1.0 if kr else 0.55
		_kettle_btn.text = "Налить +60" if kr else "Ждём"
		if kr:
			var slot: = V10Stamina.kettle_slot()
			_kettle_sub.text = "Обеденный чайник готов (12:00–16:00)" if slot == "noon" else "Вечерний чайник готов (18:00–23:00)"
		else:
			_kettle_sub.text = "Раздача в 12:00–16:00 и 18:00–23:00"
		var pr: = V10Stamina.refill_price()
		if is_instance_valid(_refill_btn._l):
			_refill_btn._l.text = "%d · Заварить" % pr
		_refill_sub.text = "За день: %d · цена 50 / 80 / 120 / 180" % V10Stamina.refills_today()

	func _on_claim_kettle() -> void:
		if V10Stamina.claim_kettle():
			V9Feel.haptic("match")
			V9Feel.sound("pop", 1.15, 0.0)
			if main_ref and main_ref.has_method("toast"):
				main_ref.toast("Чайник дня: +60 чашек чая!", "gift")
			if main_ref and main_ref.get("screen") != null and main_ref.screen.has_method("refresh"):
				main_ref.screen.refresh()
			refresh_stamina()

	func _on_buy_refill() -> void:
		var pr: = V10Stamina.refill_price()
		if V10Stamina.buy_refill():
			V9Feel.haptic("match")
			V9Feel.sound("pop", 1.2, 0.0)
			if main_ref and main_ref.has_method("refresh_currency"):
				main_ref.refresh_currency()
			if main_ref and main_ref.has_method("toast"):
				main_ref.toast("Свежая заварка: +80 чашек чая!", "gem")
			if main_ref and main_ref.get("screen") != null and main_ref.screen.has_method("refresh"):
				main_ref.screen.refresh()
			refresh_stamina()
		else:
			var have: = V10Money.bal("gems")
			if main_ref and main_ref.has_method("need_gems"):
				if is_instance_valid(sheet_ref):
					sheet_ref.close()
				main_ref.need_gems(maxi(1, pr - have))
			elif main_ref and main_ref.has_method("toast"):
				main_ref.toast("Не хватает кристаллов", "gem")
