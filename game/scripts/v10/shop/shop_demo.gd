extends Control

# Standalone runner of Лавка 2 (no main.gd, no save):
#   xvfb-run -a /opt/tw-tools/godot --path game res://scripts/v10/shop/shop_demo.tscn --rendering-driver opengl3 \
#     --audio-driver Dummy --resolution 720x1280 -- [--view=vitrina|outfits|topup|pass|purchases|age|age_stop|confirm|
#     need|outfit_buy|month|retro|all] [--shots=/abs/dir] [--sizes=720x1280,720x1600,960x1280] [--level=12]
#     [--fx=min] [--store=1]
#   --shop_selftest=1 runs V10ShopSelftest (headless is fine for logic; layout checks use SubViewports) and quits
#   with exit code = number of failures.
# Interactive (no --shots): the full flow at window size — tabs, sheets, stub payments, pass, age gate.

const T0_ISO: = "2026-11-24T14:00:00"

var args: = {}


static func demo_model(opts: = {}) -> V10ShopModel:
	V10ShopPay.force_test = not bool(opts.get("store", false))
	V10ShopPay.force_store = bool(opts.get("store", false))
	var t0: = int(Time.get_unix_time_from_datetime_string(T0_ISO))
	var prov: = V10ShopPay.make_provider()
	var econ: = V10Econ.new({}, prov, [], t0)
	econ.shop.caps.server_wallet = V10ShopPay.is_test()   # test build: consumables on the stub
	econ.shop.st.install = t0 - 3 * 86400
	econ.grant({"crystal": int(opts.get("crystal", 1240)), "moon": int(opts.get("moon", 0)), "wish": int(opts.get("wish", 0)),
		"petal": int(opts.get("petals", 0))}, "demo")
	var day0: = t0 - (t0 + 3 * 3600) % 86400 + 4 * 3600      # 04:00 МСК of today (01:00 UTC)
	econ.pass_.rollover("s1", day0 - 20 * 86400, day0 + 22 * 86400)
	econ.pass_.add_xp(int(opts.get("pass_xp", 1240)))
	var st: = V10ShopModel.defaults()
	var m: = V10ShopModel.new(econ, st)
	V10Age.set_year(st, int(opts.get("year", 1996)), t0)
	var lvl: = int(opts.get("level", 12))
	m.level_fn = func(): return lvl
	var owned: = {"r_yukata": true}
	m.owns_fn = func(id): return owned.has(id) or econ.st.inv.has(id)
	m.items_fn = func():
		var out: = []
		var g = Engine.get_main_loop().root.get_node_or_null("G") if Engine.get_main_loop() is SceneTree else null
		if g and g.get("ITEMS") is Array:
			for it in g.ITEMS:
				if String(it.get("cat", "")) == "outfit" and not bool(it.get("start", false)) and not bool(it.get("hidden", false)) \
						and not bool(it.get("bold", false)):
					out.append(it)
		# shop-priced first (crystals), then the rest (petals)
		out.sort_custom(func(a, b): return int(a.get("shop", 0)) > int(b.get("shop", 0)))
		return out
	m.free_paths_fn = func(): return [{"text": "Задания дня: ещё 50 кристаллов сегодня"}]
	return m


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("fx"):
		V10Hud2Util.fx_override = String(args.fx)
	if args.has("shop_selftest"):
		await get_tree().process_frame
		var fails: = await V10ShopSelftest.run(self)
		get_tree().quit(fails)
		return
	if args.has("shots"):
		await _shots(String(args.shots))
		get_tree().quit(0)
		return
	_interactive()


# ---------------------------------------------------------------- interactive
var m: V10ShopModel
var cur: Control


func _interactive() -> void:
	m = demo_model({"level": int(args.get("level", "12")), "store": args.get("store", "0") == "1"})
	_open(String(args.get("view", "vitrina")), self, get_viewport_rect().size)


func _open(view: String, host: Control, vs: Vector2) -> Control:
	for c in host.get_children():
		c.queue_free()
	var bg: = ColorRect.new()
	bg.color = V10DS.NIGHT_900
	bg.size = vs
	host.add_child(bg)
	var scr: Control
	var nav: = true
	match view:
		"vitrina", "outfits", "topup", "confirm", "need", "outfit_buy":
			var tab: int = {"outfits": 1, "topup": 2, "need": 2, "outfit_buy": 0}.get(view, 0)
			scr = V10Shop2.make(m, {"tab": tab, "bottom_reserve": 120.0})
			scr.go_screen.connect(func(id, _a): _go(id, host, vs))
		"pass", "retro":
			scr = V10PassScreen.make(m)
			scr.go_screen.connect(func(id, _a): _go(id, host, vs))
			nav = false
		"purchases":
			scr = V10Purchases.make(m)
			scr.go_screen.connect(func(id, _a): _go(id, host, vs))
			nav = false
		"age", "age_stop", "age_pick":
			scr = V10AgeGate.make({}, m.now())
			scr.done.connect(func(band):
				if band != "child":
					_go("vitrina", host, vs))
			nav = false
		"month":
			scr = V10Shop2.make(m, {"tab": 0, "bottom_reserve": 120.0})
	scr.size = vs
	host.add_child(scr)
	if nav:
		var nb: = NavMock.new()
		nb.position = Vector2(0, vs.y - 120)
		nb.size = Vector2(vs.x, 120)
		host.add_child(nb)
	var ov: = Control.new()
	ov.name = "Overlay"
	ov.size = vs
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(ov)
	V10ShopSheet.layer = ov
	return scr


func _go(id: String, host: Control, vs: Vector2) -> void:
	match id:
		"back":
			_open("vitrina", host, vs)
		"pass", "purchases":
			_open(id, host, vs)
		_:
			_open("vitrina", host, vs)


# ---------------------------------------------------------------- screenshots in SubViewports (any size per run)
func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var sizes: = String(args.get("sizes", "720x1280,720x1600,960x1280")).split(",")
	var views: Array = ["vitrina", "outfits", "topup", "confirm", "need", "outfit_buy", "pass", "retro", "purchases", "age", "age_pick", "age_stop", "month"]
	if args.has("view") and String(args.view) != "all":
		views = String(args.view).split(",")
	for sz in sizes:
		var p: = sz.split("x")
		var vs: = Vector2(int(p[0]), int(p[1]))
		for v in views:
			if sz != sizes[0] and not (v in ["vitrina", "topup", "pass", "age", "confirm", "outfits"]):
				continue
			await _shot(v, vs, "%s/%s_%s.png" % [dir, v, sz])
	print("SHOTS done → ", dir)


func _shot(view: String, vs: Vector2, path: String) -> void:
	var svc: = SubViewportContainer.new()
	svc.size = vs
	svc.stretch = false
	add_child(svc)
	var sv: = SubViewport.new()
	sv.size = Vector2i(vs)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	sv.gui_embed_subwindows = true
	svc.add_child(sv)
	var host: = Control.new()
	host.size = vs
	sv.add_child(host)
	var opts: = {"level": int(args.get("level", "12")), "store": args.get("store", "0") == "1"}
	if view == "outfits":
		opts["petals"] = 40
	if view == "retro":
		opts["pass_xp"] = 1240
	m = demo_model(opts)
	if view == "month":
		m.econ.shop._month_extend()
	if view == "purchases":
		var p: V10StubPay = m.provider()
		p.instant = true
		for s in ["first_79", "moon_900", "month_449"]:
			m.buy(s)
		p.next_status = "pending"
		m.buy("moon_180")
		m.econ.spend.set_limit(3000)
	var scr: = _open(view, host, vs)
	for i in 3:
		await get_tree().process_frame
	match view:
		"confirm":
			V10ShopFlow.confirm(scr, m, "guest_149")
		"need":
			V10ShopFlow.need(scr, m, 320, Callable(scr, "go_topup"))
		"outfit_buy":
			var its: = m.outfits("crystal")
			for it in its:
				if not bool(it.owned) and int(it.price) >= 1000:
					m.econ.grant({"moon": 300}, "demo")
					V10ShopFlow.outfit(scr, m, it)
					break
		"retro":
			m.econ.pass_.unlock(false, "demo")
			(scr as V10PassScreen).build()
			await get_tree().process_frame
			(scr as V10PassScreen).retro_cascade()
			await get_tree().create_timer(0.55).timeout
		"month":
			var s2: = scr as V10Shop2
			if s2.carousel:
				s2.carousel.go(1)
			await get_tree().create_timer(0.3).timeout
		"age_pick":
			var g: = scr as V10AgeGate
			g.drum.set_year(1998)
		"age_stop":
			var g2: = scr as V10AgeGate
			g2.drum.set_year(2012)
			g2._confirm()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img: = sv.get_texture().get_image()
	img.save_png(path)
	print("shot ", path)
	svc.queue_free()
	await get_tree().process_frame


# a stand-in for main.gd's 5-tab navbar (demo only, so screenshots read like the game)
class NavMock:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), V10DS.NIGHT_900)
		V10Plate.hairline(self, 0, size.x, 0.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))
		var tabs: = [["tab_tea", "Чайная"], ["tab_heroines", "Героини"], ["tab_tables", "Столы"], ["tab_wishes", "Желания"], ["tab_shop", "Лавка"]]
		var w: = size.x / 5.0
		var f: = V10Type.font("ui")
		for i in 5:
			var on: = i == 4
			var c: = Vector2(w * i + w * 0.5, 44)
			V10Icons.draw(self, tabs[i][0], c, 40, V10DS.GOLD_300 if on else V10DS.PAPER_500)
			var s: String = tabs[i][1]
			var tw: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(f, Vector2(c.x - tw * 0.5, 96), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10DS.GOLD_300 if on else V10DS.PAPER_500)
