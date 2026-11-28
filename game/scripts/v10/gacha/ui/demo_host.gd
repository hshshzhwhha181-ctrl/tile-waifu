class_name V10GachaDemo
extends Control

# V10GachaDemo — the stand-in for main.gd in the lane's runner (gacha_demo.tscn): a top bar with currencies, the
# navbar of 5 tabs, an overlay layer, toast, go/back. Builds the demo save in memory (G.save_path is moved to
# user://gacha_demo.json, the player's save is never touched) and plays the screenshot script (--shots=<dir>).

var W: = 720.0
var H: = 1280.0
var overlay: Control
var holder: Control
var topbar: Control
var navbar: Control
var screen: Control
var out: = ""
var only: = []
var toasts: = []
var gem_l: Label
var tick_l: Label


func start(a: Dictionary) -> void:
	W = size.x
	H = size.y
	if G.save_path == G.SAVE_PATH:
		G.save_path = "user://gacha_demo.json"
	_demo_state()
	holder = Control.new()
	holder.size = size
	add_child(holder)
	_topbar()
	_navbar()
	overlay = Control.new()
	overlay.size = size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	out = String(a.get("shots", ""))
	if a.has("only"):
		only = String(a.only).split(",")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_tree().create_timer(240.0).timeout.connect(func():
			print("GACHA_SHOTS TIMEOUT")
			get_tree().quit(3))
		_script()
	else:
		match String(a.get("screen", "wish")):
			"odds":
				V10OddsScreen.open(overlay, V10WishScreen.make_gacha(), V10Banners.std())
			"first":
				go("summon", {"first": true})
			_:
				go("summon", {"no_first": true})


func _demo_state() -> void:
	var S: Dictionary = G.default_state()
	S["unlocked"] = 12
	var wal: = TWWallet.for_state(S)
	wal.set_balance("gems", 24600)
	wal.set_balance("tickets", 3)
	wal.set_balance("petals", 75)
	S["pulls"] = 63
	S["pity"] = 37
	S["sr_pity"] = 3
	S["guar"] = false
	S["candles"] = 137
	S["newbie_left"] = 37
	S["newbie_ssr"] = false
	S["rates_ver"] = 2
	S["v10_gacha"] = {"mig": true}
	S["first_pick"] = ""
	for id in ["o_cafe", "r_maid", "h_street", "r_base", "h_base", "s_lemon", "b_tea", "y_base"]:
		S.owned[id] = true
	S["ostars"] = {"o_cafe": 2, "r_maid": 1, "h_street": 4, "r_base": 1, "h_base": 1, "y_base": 3}
	S["mastery"] = {"o_cafe": {"p": 1640, "pal": 0}, "y_base": {"p": 420, "pal": 2}}
	G.S = S


# ---------------------------------------------------------------- main.gd surface used by screens
func go(id: String, args: = {}, _animate: = true, _remember: = true) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	match id:
		"summon":
			var s: = V10WishScreen.new()
			s.size = size
			holder.add_child(s)
			screen = s
			var a: Dictionary = args.duplicate()
			if bool(args.get("first", false)):
				s.dev_first_force = true
			a["no_first"] = not bool(args.get("first", false))
			s.build(self, a)
		_:
			toast("Экран «%s» — в основной игре" % id)


func back() -> void:
	toast("Назад")


func show_chrome(top: bool, nav: bool) -> void:
	if topbar:
		topbar.visible = top
	if navbar:
		navbar.visible = nav


func refresh_currency(_punch: = false) -> void:
	if gem_l:
		gem_l.text = UI.fmt(V10Money.bal("gems"))
		tick_l.text = str(V10Money.bal("tickets"))


func toast(text: String, _icon: = "") -> void:
	var c: = V10GUI.chip(text, null, 56, V10GUI.PAPER_100)
	c.position = Vector2((W - c.size.x) * 0.5, 140)
	overlay.add_child(c)
	c.modulate.a = 0.0
	var t: = c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, 0.18)
	t.tween_interval(1.8)
	t.tween_property(c, "modulate:a", 0.0, 0.25)
	t.tween_callback(c.queue_free)


func _topbar() -> void:
	topbar = Control.new()
	topbar.size = Vector2(W, 120)
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbar)
	var x: = W - 24.0
	for k in [["gem", "gems"], ["ticket", "tickets"]]:
		var chip: = V10GUI.sheet(Rect2(0, 36, 180, 56), 0.8)
		x -= 180
		chip.position.x = x
		x -= 12
		chip.add_child(V10GUI.icon(V8Art.cur(k[0]), Rect2(6, 4, 48, 48)))
		var l: = V10GUI.lbl(UI.fmt(int(G.S.get(k[1], 0))), 24, V10GUI.PAPER_100, "body", 900)
		l.position = Vector2(62, 12)
		chip.add_child(l)
		topbar.add_child(chip)
		if k[0] == "gem":
			gem_l = l
		else:
			tick_l = l
	var av: = Common.avatar("mc", Rect2(24, 28, 72, 72))
	topbar.add_child(av)


func _navbar() -> void:
	navbar = Control.new()
	navbar.position = Vector2(0, H - 132)
	navbar.size = Vector2(W, 132)
	navbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(navbar)
	var bg: = ColorRect.new()
	bg.size = navbar.size
	bg.color = Color(V10GUI.NIGHT_800, 0.97)
	navbar.add_child(bg)
	var line: = ColorRect.new()
	line.size = Vector2(W, 1)
	line.color = Color(V10GUI.GOLD_700, 0.35)
	navbar.add_child(line)
	var tabs: = ["Чайная", "Героини", "Столы", "Желания", "Лавка"]
	var icons: = ["home", "wardrobe", "play", "summon", "shop"]
	var tw: = W / tabs.size()
	for i in tabs.size():
		var on: = i == 3
		var ic: = V8Art.icon(icons[i]) if V8Art.icon(icons[i]) else null
		if ic:
			var t: = V10GUI.icon(ic, Rect2(i * tw + tw * 0.5 - 26, 18, 52, 52))
			t.modulate = Color.WHITE if on else Color(0.7, 0.66, 0.62, 0.8)
			navbar.add_child(t)
		var l: = V10GUI.lbl(tabs[i], 17, V10GUI.GOLD_300 if on else V10GUI.PAPER_500, "body", 900 if on else 700)
		UI.center_label(l, Rect2(i * tw, 76, tw, 30))
		navbar.add_child(l)


# ---------------------------------------------------------------- screenshot script
func _want(n: String) -> bool:
	return only.is_empty() or n in only


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = out.path_join("%s.png" % n)
	img.save_png(p)
	print("SHOT ", p, " ", img.get_size())


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func tap_screen() -> void:
	if is_instance_valid(screen) and screen.has_method("dev_act"):
		screen.dev_act("tap")


func _wish(bid: String) -> V10WishScreen:
	go("summon", {"bid": bid})
	return screen as V10WishScreen


func _script() -> void:
	await wait(0.4)
	var ph: = V10Banners.current(G.S)
	if _want("wish_phase"):
		_wish(String(ph.id))
		await wait(1.2)
		await shot("wish_phase")
	if _want("wish_phase_b"):
		# jump the demo clock into the next phase (B, two SSRs, «Цель желания»)
		V10GClock.fixed = int(ph.end) + 3600
		_wish(String(V10Banners.phase_at(V10GClock.fixed).id))
		await wait(1.2)
		await shot("wish_phase_b")
		V10GClock.fixed = int(V10Banners.phase_at(V10GClock.fixed).end) - 20 * 3600
		_wish(String(V10Banners.phase_at(V10GClock.fixed).id))
		await wait(1.0)
		await shot("wish_phase_b_last48h")
		V10GClock.fixed = 0
		G.S.v10_gacha.hw = 0
	if _want("wish_newbie"):
		_wish("first_guest")
		await wait(1.2)
		await shot("wish_newbie")
	if _want("wish_std"):
		_wish("five_winds")
		await wait(1.2)
		await shot("wish_std")
	if _want("reveal"):
		var s: = _wish(String(ph.id))
		await wait(0.6)
		s.dev_act("v2_ssr10")
		await wait(0.5)
		await shot("reveal_1_lantern")
		s.dev_act("tap")
		await wait(1.6)
		await shot("reveal_2_climb")
		await wait(2.2)
		await shot("reveal_3_deal")
		# let the deal run to the SSR showcase
		for i in 40:
			await wait(0.25)
			if s.showcase != null:
				break
		await wait(1.6)
		await shot("reveal_4_showcase")
		s.dev_act("tap")
		for i in 40:
			await wait(0.25)
			if s.results_shown:
				break
		await wait(1.4)
		await shot("reveal_5_results")
	if _want("real_pull"):
		# a real 10-wish on the phase banner (spends demo crystals, grants into the demo save)
		var s2: = _wish(String(ph.id))
		await wait(0.5)
		s2.dev_second = true
		s2._pull(10)
		await wait(0.3)
		s2._skip()
		for i in 60:
			await wait(0.2)
			if s2.showcase != null:
				s2.dev_act("tap")
			if s2.results_shown:
				break
		await wait(1.5)
		await shot("real_pull_results")
	if _want("odds"):
		var g: = V10WishScreen.make_gacha()
		var o: = V10OddsScreen.open(overlay, g, V10Banners.current(G.S))
		await wait(0.6)
		await shot("odds_1_chances")
		o._set_tab(1)
		await wait(0.5)
		await shot("odds_2_rules")
		o._set_tab(2)
		await wait(0.5)
		await shot("odds_3_history")
		o.queue_free()
	if _want("spark"):
		G.S.candles = 200
		var s3: = _wish("five_winds")
		await wait(1.0)
		await shot("candle_ready")
		s3._open_spark()
		await wait(0.6)
		var sp: V10SparkSheet = null
		for c in overlay.get_children():
			if c is V10SparkSheet:
				sp = c
		if sp:
			sp._select(String(sp.cards.keys()[1]))
			await wait(0.4)
		await shot("candle_pick")
		if sp:
			sp._go()
			sp._go()
			await wait(2.0)
			await shot("candle_showcase")
			s3.dev_act("tap")
			await wait(0.8)
		G.S.candles = 137
	if _want("first"):
		G.S.first_pick = ""
		for id in ["o_dragon", "y_queen", "n_ssr"]:
			G.S.owned.erase(id)
		go("summon", {"first": true})
		await wait(3.6)
		await shot("first_1_table")
		var fv: V10FirstPickView = (screen as V10WishScreen).first_view
		fv._focus(1)
		await wait(0.9)
		await shot("first_2_focus")
		fv._try_style(fv.opts[1])
		fv._choose()
		await wait(0.2)
		await shot("first_3_confirm")
		fv._choose()
		await wait(0.5)
		await shot("first_4_hanko")
		await wait(2.4)
		await shot("first_5_showcase")
		(screen as V10WishScreen).dev_act("tap")
		await wait(1.0)
		await shot("first_6_partner")
		for c in overlay.get_children():
			c.queue_free()
	if _want("seven"):
		if is_instance_valid(screen):
			screen.queue_free()
		var bg: = ColorRect.new()
		bg.size = size
		bg.color = V10GUI.NIGHT_900
		holder.add_child(bg)
		G.S.seven = {"days": ["2026-11-20", "2026-11-21", "2026-11-23", "2026-11-24"], "claimed": [true, true, false, false, false, false, false]}
		var p: = V10SevenPanel.make(G.S, Rect2(24, 320, W - 48, 360), func(r): pass)
		holder.add_child(p)
		await wait(0.6)
		await shot("seven_1")
		p._claim_all()
		await wait(0.7)
		await shot("seven_2_claim")
		bg.queue_free()
		p.queue_free()
	if _want("growth"):
		var bg2: = ColorRect.new()
		bg2.size = size
		bg2.color = V10GUI.NIGHT_900
		holder.add_child(bg2)
		var g2: = V10WishScreen.make_gacha()
		var it: Dictionary = G.ITEM["o_cafe"]
		var ring: = V10OutfitGrowth.mastery_ring(it, Rect2(40, 150, 220, 220))
		holder.add_child(ring)
		var pal: = V10OutfitGrowth.palettes(G.ITEM["y_base"], Rect2(300, 170, 380, 86), func(i): pass)
		holder.add_child(pal)
		var pal2: = V10OutfitGrowth.palettes(G.ITEM["r_maid"], Rect2(300, 290, 380, 86), func(i): pass)
		holder.add_child(pal2)
		var cons: = V10OutfitGrowth.constellation(g2, it, Rect2(24, 440, W - 48, 300))
		holder.add_child(cons)
		await wait(0.6)
		await shot("growth_1_constellation_mastery")
		var up: = V10OutfitGrowth.mastery_up(overlay, "o_cafe", 3)
		await wait(1.2)
		await shot("growth_2_mastery_up")
		up.queue_free()
		bg2.queue_free()
		ring.queue_free()
		pal.queue_free()
		pal2.queue_free()
		cons.queue_free()
	if _want("guest"):
		V10GuestScene.open(overlay, self)
		await wait(3.8)
		await shot("guest_done")
	print("GACHA_SHOTS DONE")
	get_tree().quit(0)
