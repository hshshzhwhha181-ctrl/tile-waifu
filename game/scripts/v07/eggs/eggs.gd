extends Node














const STAR_CHANCE: = 0.06
const CAMEO_CHANCE: = 0.15
const PEEK_CHANCE: = 0.3
const STAR_GEMS: = 5
const CAMEO_COINS: = 30

var home_line_busy: = false
var dev: = {}
var _screen: Node = null
var _board: Node = null
var _first_tile: Object = null
var _star_pair: Array = []
var _peeked: = false
var _layer: CanvasLayer
var _taps: Array = []
var _clock_check: = 0.0

func _ready() -> void :
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--v7_") and "=" in a:
			dev[a.substr(5).get_slice("=", 0)] = a.get_slice("=", 1)
	if dev.get("heroes", "") == "1":
		for h in G.HERO_ORDER:
			G.S.shards[h] = G.SHARDS_NEED
	_layer = CanvasLayer.new()
	_layer.layer = 55
	add_child(_layer)
	get_tree().node_added.connect( func(n):
		if n is TrayBoard:
			_attach_board.call_deferred(n))


func state() -> Dictionary:
	var st = G.S.get("v7_eggs", {})
	if not (st is Dictionary):
		st = {}
	if not st.has("found"):
		st["found"] = {}
	G.S["v7_eggs"] = st
	return st

func found_count() -> int:
	return state().found.size()

func total() -> int:
	return V7Lines.EGG_NAMES.size()

# toast_delay: a find announced by a heroine's line waits until her bubble is gone, so the line and the
# «Тайник найден» toast never sit on top of each other (and a toast never lands on an open popup: main.toast)
func discover(id: String, toast_delay: = 0.0) -> void :
	var st: = state()
	if st.found.has(id):
		return
	st.found[id] = G.today()
	G.save()
	if toast_delay > 0.0:
		await get_tree().create_timer(toast_delay).timeout
	var h = get_node_or_null("/root/V7Haptics")
	if h:
		h.kind("egg")
	var m: = _main()
	if m and m.has_method("toast"):
		m.toast("Тайник найден: %s · %d из %d" % [V7Lines.EGG_NAMES.get(id, id), found_count(), total()], "star")
	var fx = get_node_or_null("/root/V6Fx")
	if fx:
		fx.layers([["rare", 1.1, -6.0, 0.0], ["shimmer", 1.0, -8.0, 0.08]])

func _main() -> Node:
	var m: = get_tree().current_scene
	return m if m and ("screen_id" in m) else null


func bubble(text: String, pos: Vector2, width: = 330.0, dur: = 3.6, tail_left: = true) -> Control:
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = get_viewport().get_visible_rect().size
	_layer.add_child(root)
	var b: = Common.bubble(root, text, pos, width, tail_left)
	var t: = root.create_tween()
	t.tween_interval(dur)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(root.queue_free)
	return root




func _attach_board(b: Node) -> void :
	if not is_instance_valid(b):
		return
	_board = b
	_first_tile = null
	b.matched.connect( func(mid: Vector2, combo: int, _gold: bool, _shard: String): _on_match(b, mid, combo))
	b.tree_exiting.connect( func():
		if _board == b:
			_board = null)

func _process(dt: float) -> void :

	if _board and is_instance_valid(_board) and not _board.tiles.is_empty():
		var f: Object = _board.tiles[0]
		if f != _first_tile:
			_first_tile = f
			_peeked = false
			_roll_star.call_deferred(_board)
	_home_tick(dt)

func _roll_star(b: Node) -> void :
	_star_pair = []
	if not is_instance_valid(b):
		return
	var force: bool = dev.get("star", "") == "1"
	if not force and randf() > STAR_CHANCE:
		return
	var by_step: = {}
	for t in b.tiles:
		if t.alive and t.shard == "" and not t.gold and t.ice == 0 and not t.secret and not t.gift:
			if not by_step.has(t.step):
				by_step[t.step] = []
			by_step[t.step].append(t)
	var steps: = by_step.keys().filter( func(k): return by_step[k].size() == 2)
	if steps.is_empty():
		return
	steps.sort()

	var teasing: = steps.filter( func(k):
		var a: Node = by_step[k][0]
		var c: Node = by_step[k][1]
		return b.cov.get(a, []).is_empty() != b.cov.get(c, []).is_empty())
	var k
	if not teasing.is_empty():
		k = teasing[randi() % teasing.size()]
	else:
		var lo: = int(steps.size() * 0.25)
		var hi: = maxi(lo + 1, int(steps.size() * 0.75))
		k = steps[randi_range(lo, mini(hi, steps.size()) - 1)]
	_star_pair = by_step[k]
	for t in _star_pair:
		_dress_star(t)

func _dress_star(t: Node2D) -> void :
	var n: = Node2D.new()
	n.name = "V7Star"
	t.add_child(n)
	var g: = Sprite2D.new()
	g.texture = G.fx("tile_glow")
	g.scale = Vector2(Tile.S, Tile.S) * 1.12
	g.material = Fx.add_mat()
	g.modulate = Color(1.0, 0.78, 0.25, 0.9)
	n.add_child(g)
	var tw: = g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 0.95, 0.8).set_trans(Tween.TRANS_SINE)

	var fs = t.get("face_spr")
	if fs:
		fs.self_modulate = fs.self_modulate * Color(1.0, 0.9, 0.62)

	var s: = Sprite2D.new()
	s.texture = V8Art.star(true)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.position = Vector2(Tile.TW * 0.34, - Tile.TH * 0.38)
	s.scale = Vector2(0.5, 0.5)
	n.add_child(s)
	var sh: = Sprite2D.new()
	sh.texture = G.fx("sparkle")
	sh.material = Fx.add_mat()
	sh.position = s.position
	sh.scale = Vector2(0.4, 0.4)
	sh.modulate = Color(1.0, 0.95, 0.7, 0.9)
	n.add_child(sh)
	var shw: = sh.create_tween().set_loops()
	shw.tween_property(sh, "rotation", TAU, 2.4).as_relative()
	var sp: = s.create_tween().set_loops()
	sp.tween_property(s, "scale", Vector2(0.6, 0.6), 0.6).set_trans(Tween.TRANS_SINE)
	sp.tween_property(s, "scale", Vector2(0.45, 0.45), 0.6).set_trans(Tween.TRANS_SINE)

func _on_match(b: Node, mid: Vector2, combo: int) -> void :
	if not is_instance_valid(b):
		return
	var vp: = get_viewport().get_visible_rect().size
	var cpos: Vector2 = get_viewport().canvas_transform.affine_inverse() * mid
	if _star_pair.size() == 2 and _star_pair.all( func(t): return not is_instance_valid(t) or not t.alive):
		_star_pair = []
		_star_caught(cpos)
	if combo == 13:
		bubble(V7Lines.KOKUSHI, Vector2(vp.x * 0.5 - 170, vp.y * 0.44), 340)
		discover("kokushi")
	if combo >= 8 and not _peeked:
		var force: bool = dev.get("peek", "") == "1"
		if force or randf() < PEEK_CHANCE:
			_peeked = true
			_peek_play()

func _star_caught(pos: Vector2) -> void :
	var st: = state()
	st["stars"] = int(st.get("stars", 0)) + 1
	G.S.gems = int(G.S.gems) + STAR_GEMS
	G.save()
	var fx = get_node_or_null("/root/V6Fx")
	if fx:
		fx.burst(pos, "star", 26, Color(1.0, 0.86, 0.4), 1.4)
		fx.burst(pos, "glint", 10, Color(1.0, 0.95, 0.7), 1.0)
		var m: = _main()
		var to: = Vector2(200, 60)
		if m and m.get("gems_lbl") and is_instance_valid(m.gems_lbl):
			to = m.gems_lbl.get_global_rect().get_center()
		fx.reward_fly(pos, to, "gem", STAR_GEMS, func(i):
			if i == 0 and m and m.has_method("refresh_currency"):
				m.refresh_currency(true))
	var h = get_node_or_null("/root/V7Haptics")
	if h:
		h.kind("egg")
	var vp: = get_viewport().get_visible_rect().size
	var who: String = G.S.get("level_partner", G.S.partner)
	if not V7Lines.STAR.has(who):
		who = "mc"
	bubble("★ +%d   %s" % [STAR_GEMS, V7Lines.STAR[who]], Vector2(vp.x * 0.5 - 180, vp.y * 0.34), 360, 4.2)
	discover("star")

func _peek_play() -> void :
	var partner: String = G.S.get("level_partner", G.S.partner)
	var pool: = G.HERO_ORDER.filter( func(h): return h != partner and G.hero_unlocked(h))
	if pool.is_empty():
		return
	var h: String = pool[randi() % pool.size()]
	var vp: = get_viewport().get_visible_rect().size
	var root: = Node2D.new()
	_layer.add_child(root)
	var hero: = Hero.new().setup(h, 520)
	hero.interactive = false
	hero.rotation = deg_to_rad(14)
	hero.position = Vector2(-260, vp.y * 0.62)
	root.add_child(hero)
	var t: = root.create_tween()
	t.tween_property(hero, "position:x", -60.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.2)
	t.tween_property(hero, "position:x", -300.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(root.queue_free)
	hero.react("happy")
	bubble(V7Lines.PEEK_PLAY[h], Vector2(70, vp.y * 0.62 - 560), 300, 2.6)
	discover("peek")




func _home_tick(dt: float) -> void :
	var m: = _main()
	if m == null:
		return
	var scr = m.get("screen")
	if scr != _screen:
		_screen = scr
		home_line_busy = false
		_taps.clear()
		_clock_check = 15.0
		if is_instance_valid(scr) and str(m.screen_id) == "home":
			_on_home.call_deferred(scr)
	if is_instance_valid(_screen) and str(m.screen_id) == "home":
		_clock_check -= dt
		if _clock_check <= 0.0:
			_clock_check = 15.0
			_clock_line(_screen, false)

func _clock() -> Dictionary:
	var dn = get_node_or_null("/root/V7DayNight")
	return dn.clock() if dn else Time.get_datetime_dict_from_system()

func _line_for(table: Dictionary, h: String) -> String:
	return table.get(h, table.get("*", ""))

func _on_home(home: Node) -> void :
	if not is_instance_valid(home):
		return
	var st: = state()
	var d: = _clock()
	var today: = G.today()
	var h: String = G.S.partner

	var md: = "%02d-%02d" % [int(d.month), int(d.day)]
	if V7Lines.DATES.has(md) and st.get("date_seen", "") != today:
		st["date_seen"] = today
		_home_line(home, h, _line_for(V7Lines.DATES[md], h), "date")
	elif not _clock_line(home, true) and int(d.hour) == 5 and st.get("dawn_seen", "") != today:
		st["dawn_seen"] = today
		_home_line(home, h, "Пять утра, а ты уже здесь. Самый ранний гость «Пяти ветров».", "dawn")

	var forced: String = dev.get("cameo", "")
	var moon: bool = int(d.hour) == 0 and h != "yue" and st.get("moon_seen", "") != today
	if moon:
		st["moon_seen"] = today
		_cameo.call_deferred(home, "yue", true)
	elif forced != "" or (st.get("cameo_day", "") != today and randf() < CAMEO_CHANCE):
		st["cameo_day"] = today
		var who: = forced if V7Lines.CAMEO.has(forced) else ""
		if who == "":
			var pool: = G.HERO_ORDER.filter( func(x): return x != h)
			who = pool[randi() % pool.size()]
		_cameo.call_deferred(home, who, false)
	G.S["v7_eggs"] = st


func _clock_line(home: Node, entering: bool) -> bool:
	var d: = _clock()
	var hm: = "%02d:%02d" % [int(d.hour), int(d.minute)]
	if not V7Lines.CLOCK.has(hm):
		return false
	var st: = state()
	var key: = "%s %s" % [G.today(), hm]
	if st.get("clock_seen", "") == key:
		return false
	st["clock_seen"] = key
	_home_line(home, G.S.partner, _line_for(V7Lines.CLOCK[hm], G.S.partner), "clock", 2.6 if entering else 0.2)
	return true

func _home_line(home: Node, h: String, line: String, egg: String, delay: = 2.6) -> void :
	if line == "":
		return
	home_line_busy = true
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(home) or not home.is_inside_tree():
		return
	var dn = get_node_or_null("/root/V7DayNight")
	if dn:
		dn.say_home(home, h, line)
	elif home.has_method("_say"):
		home.call("_say", line)
	discover(egg, 4.2)

func _cameo(home: Node, h: String, moon: bool) -> void :
	await get_tree().create_timer(4.2 if not moon else 3.0).timeout
	if not is_instance_valid(home) or not home.is_inside_tree():
		return
	var W: float = home.size.x
	var H: float = home.size.y
	var locked: = not G.hero_unlocked(h)
	var hero: = Hero.new().setup(h, H * 0.5)
	hero.name = "V7Cameo"
	hero.rotation = deg_to_rad(-15)
	hero.position = Vector2(W + 260, H - 40)
	if locked:
		hero.mat.set_shader_parameter("silhouette", 1.0)
		hero.modulate = Color(1, 1, 1, 0.8)

	var main_hero = home.get("hero")
	# 0.8: a visiting heroine peeks in above the button band (clipped at the top of «Режимы»), never behind the
	# CTAs and the nav bar
	# the clip's bottom edge runs behind the middle of «Режимы» (H - 348), so the cut line is never seen
	var clip: = Control.new()
	clip.name = "V7CameoClip"
	clip.size = Vector2(W, H - 348.0)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(clip)
	if main_hero and main_hero.get_parent() == home:
		home.move_child(clip, main_hero.get_index() + 1)
	clip.add_child(hero)
	hero.tree_exited.connect( func():
		if is_instance_valid(clip):
			clip.queue_free())
	var shown_x: = W + 10.0
	var t: = hero.create_tween()
	t.tween_property(hero, "position:x", shown_x, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var done: = [false]
	var leave: = func():
		if not is_instance_valid(hero):
			return
		var t2: = hero.create_tween()
		t2.tween_property(hero, "position:x", W + 300, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_callback(hero.queue_free)
	hero.tapped.connect( func():
		if done[0]:
			return
		done[0] = true
		hero.react("big")
		var line: String = V7Lines.CAMEO_LOCKED[h] if locked else V7Lines.CAMEO[h]
		if moon and not locked:
			line = "Лунный час — моё время. Я загляну ещё, когда стрелки снова сойдутся у нуля."
		var head: = hero.head_global()
		var bb: = Common.bubble(home, line, Vector2(maxf(16.0, head.x - 360), head.y - 170), 320, false)
		var bt: = bb.create_tween()
		bt.tween_interval(3.6)
		bt.tween_property(bb, "modulate:a", 0.0, 0.3)
		bt.tween_callback(bb.queue_free)
		if not locked:
			Sfx.voice_started.emit(h, line, minf(3.0, 0.4 + line.length() * 0.045))
			G.add_aff(h, 3)
		G.S.coins = int(G.S.coins) + CAMEO_COINS
		G.save()
		Fx.burst(home, head, "heart" if not locked else "sparkle", 12)
		var fx = get_node_or_null("/root/V6Fx")
		var m: = _main()
		if fx and m and m.get("coins_lbl") and is_instance_valid(m.coins_lbl):
			fx.reward_fly(head, m.coins_lbl.get_global_rect().get_center(), "coin", 6, func(i):
				if i == 0:
					m.refresh_currency(true))
		elif m:
			m.refresh_currency(true)
		discover("moon_hour" if moon else ("cameo_locked" if locked else "cameo"))
		get_tree().create_timer(3.4).timeout.connect(leave))

	get_tree().create_timer(7.0).timeout.connect( func():
		if not done[0]:
			done[0] = true
			leave.call())

func _input(e: InputEvent) -> void :

	if not (e is InputEventMouseButton and e.pressed):
		return
	var m: = _main()
	if m == null or str(m.screen_id) != "home" or not is_instance_valid(m.screen):
		return
	if m.overlay and m.overlay.get_children().any( func(c): return c.has_meta("popup")):
		return
	var vp: Vector2 = m.screen.size
	var p: Vector2 = m.screen.get_global_transform_with_canvas().affine_inverse() * e.position
	if not Rect2(vp.x * 0.22, vp.y * 0.18, vp.x * 0.52, vp.y * 0.52).has_point(p):
		return
	var now: = Time.get_ticks_msec() / 1000.0
	_taps.append(now)
	_taps = _taps.filter( func(x): return now - x < 3.5)
	if _taps.size() >= 7:
		_taps.clear()
		var h: String = G.S.partner
		home_line_busy = true
		var home = m.screen
		get_tree().create_timer(0.15).timeout.connect( func():
			if is_instance_valid(home):
				var dn = get_node_or_null("/root/V7DayNight")
				if dn:
					dn.say_home(home, h, V7Lines.TICKLE.get(h, V7Lines.TICKLE.mc))
				discover("tickle"))
