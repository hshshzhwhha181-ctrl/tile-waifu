extends Node








const PHASES: = ["morning", "day", "evening", "night"]

const LOOK: = {
	"morning": {"mul": Color(1.0, 0.93, 0.9), "glow": Color(1.0, 0.72, 0.6, 0.35), "glow_at": Vector2(0.85, 0.12), 
		"rim": Color(1.0, 0.86, 0.78), "rim_amt": 0.5, "hero": Color(1.0, 0.98, 0.97), "fx": []}, 
	"day": {"mul": Color(1, 1, 1), "glow": Color(0, 0, 0, 0), "glow_at": Vector2(0.5, 0.2), 
		"rim": Color(1.0, 0.85, 0.75), "rim_amt": 0.45, "hero": Color(1, 1, 1), "fx": []}, 
	"evening": {"mul": Color(1.0, 0.8, 0.68), "glow": Color(1.0, 0.45, 0.2, 0.32), "glow_at": Vector2(0.15, 0.85), 
		"rim": Color(1.0, 0.66, 0.42), "rim_amt": 0.55, "hero": Color(1.0, 0.93, 0.88), "fx": ["lanterns"]}, 
	"night": {"mul": Color(0.4, 0.44, 0.78), "glow": Color(1.0, 0.62, 0.3, 0.3), "glow_at": Vector2(0.5, 0.78), 
		"rim": Color(0.75, 0.8, 1.0), "rim_amt": 0.35, "hero": Color(0.8, 0.82, 0.96), "fx": ["fireflies", "stars", "lanterns"]}, 
}

signal phase_changed(phase: String)

var phase: = ""
var _hour_override: = -1
var _min_override: = -1
var _screen: Node = null
var _deco: Node = null
var _chip: Control = null
var _chip_lbl: Label = null
var _check: = 0.0

func _ready() -> void :
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--v7_hour="):
			_hour_override = int(a.get_slice("=", 1))
		elif a.begins_with("--v7_min="):
			_min_override = int(a.get_slice("=", 1))
	phase = phase_now()

func enabled() -> bool:
	var st = G.S.get("v7_daynight", {})
	return not (st is Dictionary) or st.get("on", true)


func clock() -> Dictionary:
	var d: = Time.get_datetime_dict_from_system()
	if _hour_override >= 0:
		d.hour = _hour_override
		d.minute = _min_override if _min_override >= 0 else 0
	return d

func phase_of(h: int) -> String:
	if h >= 5 and h < 11:
		return "morning"
	if h >= 11 and h < 17:
		return "day"
	if h >= 17 and h < 21:
		return "evening"
	return "night"

func phase_now() -> String:
	return phase_of(int(clock().hour))


func music_name(name: String) -> String:
	if name == "menu" and enabled() and phase != "day" and phase != "":
		return "v7_menu_" + phase
	return name

func music_path(name: String) -> String:
	if name.begins_with("v7_"):
		return "res://assets/v07/daynight/%s.ogg" % name.substr(3)
	return "res://assets/music/%s.ogg" % name


func _process(dt: float) -> void :
	var m: = get_tree().current_scene
	if m == null or not ("screen" in m):
		return
	var scr = m.get("screen")
	if scr != _screen:
		_screen = scr
		_deco = null
		_chip = null
		if is_instance_valid(scr) and str(m.get("screen_id")) == "home":
			_decorate_home.call_deferred(scr, false)
	_check -= dt
	if _check <= 0.0:
		_check = 5.0
		var p: = phase_now()
		if p != phase:
			phase = p
			phase_changed.emit(p)
			var sfx = get_node_or_null("/root/Sfx")
			if sfx and (sfx.cur_music == "menu" or str(sfx.cur_music).begins_with("v7_menu")):
				sfx.music("menu", 3.0)
			if is_instance_valid(_screen) and str(m.get("screen_id")) == "home":
				_decorate_home(_screen, true)
		_update_chip()


func _decorate_home(home: Node, animate: bool) -> void :
	if not is_instance_valid(home) or not enabled():
		return
	var W: float = home.size.x
	var H: float = home.size.y
	var lk: Dictionary = LOOK[phase]
	var old: = _deco
	var root: = Control.new()
	root.name = "V7DayNight"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = home.size
	_deco = root
	var hero = home.get("hero")
	var outfit: bool = hero != null and not hero.visible

	var idx: = 1
	if hero != null and hero.get_parent() == home:
		idx = maxi(1, hero.get_index() - 1)
	if outfit:
		idx = home.get_child_count()
	home.add_child(root)
	home.move_child(root, mini(idx, home.get_child_count() - 1))

	var mul: Color = lk.mul
	if outfit:
		mul = Color.WHITE.lerp(mul, 0.45)
	if mul != Color.WHITE:
		var tint: = ColorRect.new()
		tint.size = home.size
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.color = mul
		var cm: = CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		tint.material = cm
		root.add_child(tint)

	var gc: Color = lk.glow
	if gc.a > 0.0:
		var g: = Sprite2D.new()
		g.texture = G.fx("glow")
		g.material = Fx.add_mat()
		g.position = Vector2(W, H) * (lk.glow_at as Vector2)
		g.scale = Vector2(11, 9)
		g.modulate = gc if not outfit else Color(gc.r, gc.g, gc.b, gc.a * 0.6)
		root.add_child(g)
		var gt: = g.create_tween().set_loops()
		gt.tween_property(g, "modulate:a", g.modulate.a * 0.7, 3.2).set_trans(Tween.TRANS_SINE)
		gt.tween_property(g, "modulate:a", g.modulate.a, 3.2).set_trans(Tween.TRANS_SINE)
	if phase == "night":

		for i in 3:
			var l: = Sprite2D.new()
			l.texture = G.fx("glow")
			l.material = Fx.add_mat()
			l.position = Vector2([0.08, 0.92, 0.5][i] * W, [0.3, 0.36, 0.1][i] * H)
			l.scale = Vector2(2.6, 2.6)
			l.modulate = Color(1.0, 0.6, 0.28, 0.42)
			root.add_child(l)
			var lt: = l.create_tween().set_loops()
			lt.tween_property(l, "modulate:a", 0.25, randf_range(0.8, 1.6)).set_trans(Tween.TRANS_SINE)
			lt.tween_property(l, "modulate:a", 0.45, randf_range(0.8, 1.6)).set_trans(Tween.TRANS_SINE)
	if phase == "morning":
		Common.rays(root, Vector2(W * 0.9, -40), 1100, Color(1.0, 0.88, 0.72, 0.35), 7, 0.02, 0.4)
	for k in lk.fx:
		var area: = Vector2(W, H)
		if k == "stars":
			area = Vector2(W, H * 0.4)
		var a: = Fx.ambient(root, k, area)
		if k == "lanterns":
			a.modulate = Color(1, 1, 1, 0.65)

	if hero != null and hero.visible and hero.get("mat"):
		hero.mat.set_shader_parameter("rim_color", lk.rim)
		hero.mat.set_shader_parameter("rim", lk.rim_amt)
		if animate:
			hero.create_tween().tween_property(hero, "modulate", lk.hero, 2.5)
		else:
			hero.modulate = lk.hero

	if _chip == null or not is_instance_valid(_chip):
		_chip = _make_chip(home)
	_update_chip()

	if animate:
		root.modulate.a = 0.0
		var t: = root.create_tween()
		t.tween_property(root, "modulate:a", 1.0, 2.5)
		if is_instance_valid(old):
			var t2: = old.create_tween()
			t2.tween_property(old, "modulate:a", 0.0, 2.5)
			t2.tween_callback(old.queue_free)
	elif is_instance_valid(old):
		old.queue_free()
	if not animate:
		_greet_later(home)

func _make_chip(home: Node) -> Control:
	var W: float = home.size.x
	var c: = UI.rbox("glass", Rect2(108, 128, W - 108 - 222, 44), 22, 2, 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(c)
	_chip_lbl = UI.label("", 16, Color("fff1dc"), UI.DARK, 3, "body", 900)
	_chip_lbl.size = c.size
	_chip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_chip_lbl)
	UI.slide_in(c, Vector2(0, -20), 0.4)
	return c

func _update_chip() -> void :
	if _chip_lbl == null or not is_instance_valid(_chip_lbl):
		return
	var d: = clock()
	_chip_lbl.text = "%02d:%02d  %s · %s" % [int(d.hour), int(d.minute), V7Lines.PHASE_NAME[phase], V7Lines.PHASE_SUB[phase]]


func _greet_later(home: Node) -> void :
	var st: Dictionary = G.S.get("v7_daynight", {})
	var key: = "%s|%s" % [G.today(), phase]
	if st.get("greet", "") == key:
		return
	await get_tree().create_timer(2.6).timeout
	if not is_instance_valid(home) or not home.is_inside_tree():
		return
	if get_node_or_null("/root/V7Eggs") and get_node("/root/V7Eggs").home_line_busy:
		return
	var h: String = G.S.partner
	var arr: Array = V7Lines.TIME_GREET.get(h, V7Lines.TIME_GREET.mc)[phase]
	var line: String = arr[randi() % arr.size()]
	say_home(home, h, line)
	st["greet"] = key
	G.S["v7_daynight"] = st
	G.save()


func say_home(home: Node, h: String, line: String) -> void :
	if not is_instance_valid(home) or not home.has_method("_say"):
		return
	home.call("_say", line)
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.voice_started.emit(h, line, minf(3.0, 0.4 + line.length() * 0.045))
