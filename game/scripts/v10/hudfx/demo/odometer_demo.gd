extends Control

# V10Odometer demo (scripts/v10/hudfx/demo/odometer_demo.tscn) — the odometer in its real HUD v2 places:
#   match   V10HudMatch (hero "mc"): the status row «1-2 · Осталось 30» → 29 → 28 (quiet ±1 crossfades),
#           then 28 → 25 (quiet roll). The odometer is wired exactly as the integrator hook does it
#           (V10Odometer.attach(status_n) + set_value(n, "quiet") in set_left).
#   reward  V10HudVictory (hero "mc"): an S plate with crystals «1 980» → «2 130» (reward, plate.ping()) and a big
#           Numerals 40 gold.300 reward counter 120 → 1 240 beside the stars (reward: roll, bump, tint).
# User args (after --):
#   --shots=<abs dir>   capture PNGs at the key moments (mid-roll stills are exact: the odometers are stepped
#                       with advance() on manual_clock), then quit
#   --fx=full|mid|min   V10Hud2Util.fx_override (shot names get a _mid / _min suffix)
#   --film=1            with --shots: also a 60 fps filmstrip film_00..30 of the reward roll + bump
#   --selftest=1        run V10HudFxOdometerTest, print «HUDFX ODOMETER SELFTEST passed/total», quit(failures)
# Without --shots the two scenes loop.

const TILE_DIR: = "res://assets/v08/table/"

var args: = {}
var fx: = "full"
var shot_dir: = ""
var hud: V10HudMatch
var vic: V10HudVictory
var plate: V10Plate
var plate_odo: V10Odometer
var big: V10Odometer
var _left: = 30


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("fx"):
		fx = str(args.fx)
		V10Hud2Util.fx_override = fx
	if args.has("selftest"):
		var r: Dictionary = await V10HudFxOdometerTest.run(self)
		for l in r.lines:
			print("  FAIL ", l)
		print("HUDFX ODOMETER SELFTEST %d/%d" % [r.passed, r.passed + r.failed])
		get_tree().quit(int(r.failed))
		return
	shot_dir = str(args.get("shots", ""))
	_run()


func _run() -> void:
	while true:
		await _match_scene()
		await _reward_scene()
		if shot_dir != "":
			get_tree().quit(0)
			return


# ------------------------------------------------------------------ match: status row «Осталось N»

func _match_scene() -> void:
	_clear()
	hud = V10HudMatch.new()
	add_child(hud)
	hud.configure({"hero": "mc", "level": "1-2", "total": 30, "left": 30,
			"helpers": {"undo": 2, "hint": 3, "shuffle": 1}, "stake_offer": false})
	hud.set_ult(0.35)
	_left = 30
	_hook_match_build()
	_board()
	await _wait(1.2)
	await _shot("match_30")
	_set_left(29)
	await _still([_status_odo()], 0.05, "match_cross_mid")
	await _wait(0.6)
	_set_left(28)
	await _wait(0.6)
	await _shot("match_28")
	_set_left(25)
	await _still([_status_odo()], 0.06, "match_roll_mid")
	await _wait(0.7)
	await _shot("match_settled")


# the integrator hook, verbatim (V10HudMatch._build() after add_child(status_n); set_left(n) after left = n)
func _hook_match_build() -> void:
	var odo_s: = V10Hud2Util.opt_class("V10Odometer")
	if odo_s:
		odo_s.call("attach", hud.status_n, hud.left)


func _set_left(n: int) -> void:
	_left = n
	hud.set_left(n)
	if hud.status_n.has_node("Odometer"):
		hud.status_n.get_node("Odometer").call("set_value", n, "quiet")


func _status_odo() -> V10Odometer:
	return hud.status_n.get_node_or_null("Odometer") as V10Odometer


func _board() -> void:
	# a small stand-in pyramid (the game puts its board into hud.board_layer) + two tiles in the tray
	var tw: = 76.0
	var th: = 106.0
	var rows: = [[7, 0.0], [6, 38.0], [5, 76.0], [4, 114.0], [3, 152.0], [2, 190.0], [1, 228.0]]
	var y0: = 640.0 - th
	var face: = 0
	for r in rows.size():
		var cols: int = rows[r][0]
		var x0: = (688.0 - 7.0 * tw) * 0.5 + float(rows[r][1])
		for c in cols:
			_tile(hud.board_layer, face % 34, Rect2(x0 + c * tw, y0 - r * 86.0, tw, th))
			face += 5
	for i in 2:
		var cr: = hud.tray_cell_rect(i)
		_tile(self, [7, 21][i], Rect2(cr.position - get_global_rect().position, cr.size))
	hud.set_tray_fill(2)


func _tile(parent: Control, f: int, r: Rect2) -> void:
	var p: = TILE_DIR + "t%02d.png" % f
	if not ResourceLoader.exists(p):
		return
	var tr: = TextureRect.new()
	tr.texture = load(p)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = r.position
	tr.size = r.size
	parent.add_child(tr)


# ------------------------------------------------------------------ reward: S plate + big Numerals 40

func _reward_scene() -> void:
	_clear()
	vic = V10HudVictory.new()
	add_child(vic)
	vic.configure({"hero": "mc", "level": "1-4 · Чайный сад", "stars": 3, "next": 5})
	await get_tree().process_frame
	var vs: = get_viewport_rect().size
	var L: = V10HudVictory.compute(vs, V10Hud2Util.safe_insets(vs))
	# S plate «crystals» top left (where a reward flies to): painted crystal or a drawn fallback, odometer value
	plate = V10Plate.make("S", 144, "", "", "", "")
	var ct: = V10HudFx.tex("items/crystal")
	if ct:
		plate.icon_tex = ct
	add_child(plate)
	plate.position = Vector2(float(L.cx) + 24.0, float(L.T) + 40.0)
	if ct == null:
		var g: = _Gem.new()
		g.position = Vector2(16, 12)
		g.size = Vector2(24, 24)
		plate.add_child(g)
	plate_odo = V10Odometer.in_plate(plate, 1980)
	# big reward counter on the caption row, right column (the table's dark fade, off her dress ornaments):
	# coin 40 + Numerals 40 gold.300 (num.reward), on art → the §3 shadow; the digit baseline is the caption's
	var cr: Rect2 = L.caption
	var base_y: = cr.position.y + 20.0
	var cnt_x: = float(L.cx) + 688.0 - 112.0
	var cn: = V10HudFx.tex("items/coin")
	var icon: Control
	if cn:
		var trc: = TextureRect.new()
		trc.texture = cn
		trc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = trc
	else:
		icon = _Coin.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(40, 40)
	icon.position = Vector2(cnt_x - 52.0, base_y - 14.0 - 20.0)
	add_child(icon)
	big = V10Odometer.make(120, 40, V10DS.GOLD_300)
	big.on_art = true
	big.align = "left"
	big.size = Vector2(112, 56)
	# Label-style centring: baseline = floor((56 - font_h) / 2) + ascent → place the box so it lands on base_y
	var f40: = V10Type.font("num")
	big.position = Vector2(cnt_x, base_y - (floorf((56.0 - f40.get_height(40)) * 0.5) + f40.get_ascent(40)))
	add_child(big)
	await _wait(1.4)
	await _shot("reward_start")
	big.set_value(1240, "reward")
	plate_odo.set_value(2130, "reward")
	if args.has("film"):  # a 60 fps filmstrip of the whole reward (roll + bump) for motion review
		for i in 31:
			await _still([big, plate_odo], i / 60.0, "film_%02d" % i, false)
	await _still([big, plate_odo], 0.07, "reward_roll_mid", false)
	await _still([big, plate_odo], 0.40, "reward_bump")
	await _wait(0.9)
	await _shot("reward_settled")


func _clear() -> void:
	for n in [hud, vic, plate, big]:
		if is_instance_valid(n):
			n.queue_free()
	for c in get_children():
		c.queue_free()
	hud = null
	vic = null
	plate = null
	big = null


# ------------------------------------------------------------------ clock and shots

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _still(odos: Array, at: float, name: String, thaw: = true) -> void:
	# exact still of an in-flight change: the odometers are frozen at «at» seconds after set_value (stepped with
	# advance() on manual_clock, so the frame rate of the capture run does not matter), shot, then thawed
	if shot_dir == "":
		return
	for o in odos:
		var od: V10Odometer = o
		od.manual_clock = true
		od.advance(maxf(0.0, at - float(od.get_meta("demo_t", 0.0))))
		od.set_meta("demo_t", at)
	await _shot(name)
	if not thaw:
		return
	for o in odos:
		var od2: V10Odometer = o
		if is_instance_valid(od2):
			od2.remove_meta("demo_t")
			od2.manual_clock = false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if shot_dir == "":
		return
	var suffix: = "" if fx == "full" else "_" + fx
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var path: = "%s/%s%s.png" % [shot_dir, name, suffix]
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


# ------------------------------------------------------------------ drawn fallbacks for the painted items

class _Gem:
	extends Control
	# a small faceted crystal: light from the top left, one spark, no plate, no rim (HUD_V2 §4)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: = size.x / 24.0
		var p: = func(x: float, y: float) -> Vector2: return Vector2(x, y) * s
		var crown_l: = PackedVector2Array([p.call(2, 9), p.call(7, 3), p.call(12, 3), p.call(10, 9)])
		var crown_r: = PackedVector2Array([p.call(12, 3), p.call(17, 3), p.call(22, 9), p.call(14, 9)])
		var table: = PackedVector2Array([p.call(10, 9), p.call(12, 3), p.call(14, 9)])
		var pav_l: = PackedVector2Array([p.call(2, 9), p.call(10, 9), p.call(12, 22)])
		var pav_m: = PackedVector2Array([p.call(10, 9), p.call(14, 9), p.call(12, 22)])
		var pav_r: = PackedVector2Array([p.call(14, 9), p.call(22, 9), p.call(12, 22)])
		draw_colored_polygon(crown_l, V10DS.PAPER_100)
		draw_colored_polygon(table, Color(V10DS.ROSE_300, 0.95))
		draw_colored_polygon(crown_r, V10DS.PAPER_300)
		draw_colored_polygon(pav_l, Color(V10DS.JADE_300, 0.95))
		draw_colored_polygon(pav_m, V10DS.PAPER_300)
		draw_colored_polygon(pav_r, V10DS.PAPER_500)
		draw_line(p.call(2, 9), p.call(22, 9), Color(V10DS.PAPER_100, 0.6), 1.0, true)
		_spark(self, p.call(6.5, 4.5), 3.0 * s)

	static func _spark(ci: CanvasItem, c: Vector2, r: float) -> void:
		var col: = Color(V10DS.PAPER_100, 0.95)
		ci.draw_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22), c + Vector2(r, 0),
				c + Vector2(r * 0.22, r * 0.22), c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22), c + Vector2(-r, 0),
				c + Vector2(-r * 0.22, -r * 0.22)]), PackedColorArray([col]))


class _Coin:
	extends Control
	# a round coin with a square hole (the table's own currency look): gold tones only, light top left

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: = size * 0.5
		var r: = minf(size.x, size.y) * 0.42
		draw_circle(c + Vector2(0, 1.5), r, Color(V10DS.NIGHT_900, 0.45), true, -1.0, true)
		draw_circle(c, r, V10DS.GOLD_700, true, -1.0, true)
		draw_circle(c + Vector2(-0.8, -0.8), r - 2.0, V10DS.GOLD_500, true, -1.0, true)
		draw_arc(c, r - 5.5, 0.0, TAU, 48, Color(V10DS.GOLD_700, 0.55), 1.5, true)
		draw_arc(c, r - 2.5, PI * 1.05, PI * 1.6, 24, Color(V10DS.GOLD_300, 0.9), 2.0, true)
		var h: = r * 0.32
		draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), V10DS.NIGHT_800)
		draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), Color(V10DS.GOLD_700, 0.9), false, 1.0)
		_Gem._spark(self, c + Vector2(-r * 0.5, -r * 0.55), r * 0.28)
