extends Control

# V10LanternFx demo (scripts/v10/hudfx/demo/lantern_fx_demo.tscn): the real Чайная (V10HudHome, hero "mc") with the
# lantern helper attached. Lanterns start [lit, unlit, unlit] → light(1) → light(2) → extinguish(0).
# User args (after --):
#   --shots=<abs dir>   PNGs at the key moments (+ a 2× crop of the lantern strip), then quit
#   --fx=full|mid|min   V10Hud2Util.fx_override
#   --selftest=1        run V10HudFxLanternFxTest, print «HUDFX LANTERN_FX SELFTEST passed/total», quit(failures)
#   --loop=1            repeat the script (watch it live)
#   --burst=a,b,step    with --shots: also a contact sheet of lantern 1 from a to b s (review the motion)

const CROP: = Rect2i(8, 72, 384, 176)  # the lantern strip (3 lanterns + captions)
const STEP: = 1.0 / 60.0  # shots: fixed clock

var args: = {}
var t: = 0.0
var home: V10HudHome
var fx: V10LanternFx
var _actions: = []
var _shots: = []
var _shot_dir: = ""
var _fx_name: = "full"
var _quit_at: = -1.0
var _burst: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	_fx_name = V10HudFx.level()
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxLanternFxTest.run(self)
		for l in r.lines:
			print("LANTERN_FX FAIL: ", l)
		var total: = int(r.passed) + int(r.failed)
		print("HUDFX LANTERN_FX SELFTEST %d/%d %s" % [int(r.passed), total, "OK" if int(r.failed) == 0 else "FAILED"])
		get_tree().quit(int(r.failed))
		return
	_shot_dir = str(args.get("shots", ""))
	_build()
	_script()


func _build() -> void:
	if is_instance_valid(home):
		home.queue_free()
	home = V10HudHome.new()
	home.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 6,
			"lit": [true, false, false]})
	add_child(home)
	fx = V10LanternFx.attach(home)
	fx.manual = _shot_dir != ""  # shots: a fixed 60 fps clock, so every capture lands on its moment
	fx.changed.connect(func(i: int, lit: bool) -> void: print("%.2f lantern %d %s" % [t, i, "lit" if lit else "out"]))


func _script() -> void:
	t = 0.0
	_actions.clear()
	_at(0.8, func() -> void: fx.light(1))
	_shot(0.8 + 0.25, "0_swing_peak")
	_shot(0.8 + V10LanternFx.IGNITE_AT + 0.15, "1_swing_ignite")
	_at(2.0, func() -> void: fx.light(2))
	_shot(2.0 + V10LanternFx.SWING_T + 0.25, "2_settled_lit")
	_at(4.6, func() -> void: fx.extinguish(0))
	_shot(4.6 + 0.07, "3_mid_exhale")
	_shot(5.3, "4_final")
	if args.has("burst") and _shot_dir != "":
		var b: PackedStringArray = str(args.burst).split(",")
		var bt: = float(b[0])
		while bt <= float(b[1]) + 0.0001:
			_shots.append({"t": bt, "name": "burst", "burst": true})
			bt += float(b[2])
		_shots.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.t) < float(y.t))
	if args.has("loop"):
		_at(6.5, func() -> void:
			_build()
			_script())
	elif _shot_dir != "":
		_quit_at = 5.4


func _at(time: float, f: Callable) -> void:
	_actions.append({"t": time, "f": f})


func _shot(time: float, name: String) -> void:
	if _shot_dir != "":
		_shots.append({"t": time, "name": name})


func _process(delta: float) -> void:
	if _shot_dir != "":
		delta = STEP
		if is_instance_valid(fx):
			fx.advance(STEP)
	t += delta
	while not _actions.is_empty() and t >= float(_actions[0].t):
		var a: Dictionary = _actions.pop_front()
		(a.f as Callable).call()
	if not _shots.is_empty() and t >= float(_shots[0].t):
		var s: Dictionary = _shots.pop_front()
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		var img: = get_viewport().get_texture().get_image()
		if s.has("burst"):
			_burst.append(img.get_region(Rect2i(120, 72, 160, 176)))
			if not _shots.any(func(x: Dictionary) -> bool: return x.has("burst")):
				_save_burst()
			return
		var path: = "%s/%s_%s.png" % [_shot_dir, _fx_name, s.name]
		img.save_png(path)
		var crop: = img.get_region(CROP)
		crop.resize(CROP.size.x * 2, CROP.size.y * 2, Image.INTERPOLATE_LANCZOS)
		crop.save_png(path.replace(".png", "_crop.png"))
		print("shot %s at %.2f s" % [path, t])
	if _quit_at > 0.0 and t >= _quit_at and _shots.is_empty():
		get_tree().quit(0)


func _save_burst() -> void:
	var w: = 160
	var h: = 176
	var cols: = mini(8, _burst.size())
	var rows: = int(ceil(_burst.size() / float(cols)))
	var sheet: = Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for k in _burst.size():
		var im: Image = _burst[k]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png("%s/%s_burst.png" % [_shot_dir, _fx_name])
	print("burst sheet %d frames" % _burst.size())
