extends Control

# look_demo — showcase of the v10/mj/look lane: 6 materials × 5 founders' tables, a 4-layer stack, the tray,
# contrast mode and the 144-tile stack. Run:
#   godot --path game res://scripts/v10/mj/look/look_demo.tscn -- [--page=rin] [--shots=<dir>] [--hl=1] [--contrast=1]
# --shots renders every page and saves <page>_<W>x<H>.png (run once at 720x1280 and once at 1080x2400).

const PAGES: = ["mc", "rin", "hana", "yue", "nova", "materials", "contrast", "a_partner", "stack144"]
const STEP: = Vector2(84, 88)        # tile pitch: faces abut (V10MjStackCache needs non-overlapping faces)
const LAYER_OFF: = Vector2(-7, -9)   # each layer up-left: height reads at a glance

var args: = {}
var page_root: Control


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	get_viewport().size_changed.connect(_rebuild)
	if args.has("perf"):
		_perf.call_deferred()
	elif args.has("shots"):
		_shots.call_deferred()
	else:
		show_page(String(args.get("page", "rin")))


var _cur: = ""

func _rebuild() -> void:
	if _cur != "":
		show_page(_cur)


func show_page(name: String) -> void:
	_cur = name
	if page_root:
		page_root.queue_free()
	V10MjTileView.clear_cache()
	page_root = Control.new()
	page_root.size = get_viewport_rect().size
	add_child(page_root)
	build_page(page_root, name, args)


func _shots() -> void:
	var dir: = String(args.shots)
	DirAccess.make_dir_recursive_absolute(dir)
	var sz: = DisplayServer.window_get_size()
	var pages: Array = Array(String(args.get("pages", ",".join(PAGES))).split(","))
	for p in pages:
		show_page(p)
		for i in 40:
			await get_tree().process_frame
		var img: = get_viewport().get_texture().get_image()
		img.save_png("%s/look_%s_%dx%d.png" % [dir, p, sz.x, sz.y])
		print("SHOT ", p)
	get_tree().quit()


# dev: --perf=<page> [--hide=shadow,contact,body,face,far,near,cloth,fx] → average ms/frame over 120 frames
func _perf() -> void:
	show_page(String(args.perf))
	var hide: = String(args.get("hide", "")).split(",")
	for i in 3:
		await get_tree().process_frame
	for n in page_root.find_children("*", "", true, false):
		if n is V10MjTileView:
			for part in ["shadow", "contact", "body", "face_spr"]:
				if (part.trim_suffix("_spr") in hide):
					n.get(part).visible = false
		if n is V10MjTableView:
			if "far" in hide:
				n.far_layer.visible = false
			if "cloth" in hide:
				n.cloth_rect.visible = false
			if "fx" in hide:
				n.fx_layer.visible = false
		if n is V10MjStackCache and "stack" in hide:
			n.visible = false
		if n is V10MjStackCache and "live" in hide:
			for f in n.live.values():
				f.visible = false
		if n.name == "V10MjTableFront" and "near" in hide:
			n.visible = false
	Engine.max_fps = 0
	for i in 20:
		await get_tree().process_frame
	var t0: = Time.get_ticks_usec()
	for i in 120:
		await RenderingServer.frame_post_draw
	print("PERF %s hide=%s %.2f ms" % [args.perf, args.get("hide", ""), float(Time.get_ticks_usec() - t0) / 120000.0])
	get_tree().quit()


# ── page builders (also used by look_selftest) ─────────────────────────────────────────────────────────────────

static func board_rect(sz: Vector2) -> Rect2:
	# MODES §4 frame: her band 0–120 (+ extra height), tray 120–300, board 300 – H−186, helpers H−186 – H−40
	var extra: = maxf(sz.y - 1280.0, 0.0)
	var top: = 300.0 + extra * 0.6
	return Rect2(Vector2(24, top), Vector2(sz.x - 48, sz.y - 186.0 - top))


static func build_page(root: Control, name: String, a: = {}) -> Dictionary:
	var sz: = root.size
	var br: = board_rect(sz)
	var st: = V10MjTileMaterial.st()
	st.hl_free = name == "contrast" or String(a.get("hl", "0")) == "1"
	st.contrast = name == "contrast" or String(a.get("contrast", "0")) == "1"
	var th: Dictionary
	var mat: String
	match name:
		"materials", "stack144":
			th = V10MjTables.get_theme("house")
		"contrast":
			th = V10MjTables.theme_for("yue")
		"a_partner":
			th = V10MjTables.theme_for("rin")          # A partner: house table, her light and particles
		_:
			th = V10MjTables.get_theme(name)
			th.full = true
	mat = String(a.get("material", th.material))
	# no full-screen backdrop rect: the far layer + cloth cover every pixel; the clear colour is night.900
	RenderingServer.set_default_clear_color(Color("121014"))
	var tv: = V10MjTableView.make(root, th, br, br, sz)
	var lt: = tv.light()
	var board: = Node2D.new()
	board.name = "Board"
	root.add_child(board)
	var info: = {"theme": th, "board_rect": br, "table": tv, "board": board, "tiles": []}
	match name:
		"materials":
			info.tiles = _materials_grid(board, br, lt, th)
		"stack144":
			info.tiles = stack(board, br, lt, th, mat, [[12, 6], [10, 4], [8, 3], [4, 2]], 0.64)
		_:
			info.tiles = stack(board, br, lt, th, mat, [[8, 6], [6, 4], [4, 2], [2, 1]], 0.94, false)
			if name == "contrast":
				_mark_specials(info.tiles)
			_cache(board, info.tiles, lt)
	tv.attach_front(root)
	if name != "stack144":
		_tray(root, th, lt, sz)
	_header(root, th, mat, name)
	return info


static func _header(root: Control, th: Dictionary, mat: String, name: String) -> void:
	var t: = Label.new()
	var title: = String(th.name)
	if name == "materials":
		title = "Материалы фишек"
	elif name == "stack144":
		title = "144 фишки"
	elif name == "contrast":
		title = "Контрастный режим"
	t.text = title
	t.position = Vector2(32, 26)
	t.add_theme_font_override("font", UI.font("title", 700))
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("f5ead8"))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(t)
	var c: = Label.new()
	var line: = "%s · %s" % [V10MjTileMaterial.display_name(mat), String(th.zone)]
	if name == "materials":
		line = "Шесть материалов на одном столе"
	elif name == "contrast":
		line = "Масть и номер в углу, особые — формой"
	elif name == "a_partner":
		line = "Партнёр A: свет и частицы Рин"
	c.text = line
	c.position = Vector2(32, 72)
	c.add_theme_font_override("font", UI.font("body", 700))
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", Color("ddd2c4"))
	c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	c.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(c)


# tray 120–300: the 7-well tray with one tile of each material (the «витрина»)
static func _tray(root: Control, th: Dictionary, lt: Dictionary, sz: Vector2) -> void:
	var extra: = maxf(sz.y - 1280.0, 0.0)
	var r: = Rect2(Vector2(24, 150 + extra * 0.6 - 4), Vector2(sz.x - 48, 116))
	var tf: = V10MjTrayFrame.make(root, r, th, 7)
	tf.set_fill(6)
	var layer: = Node2D.new()
	root.add_child(layer)
	var mats: = V10MjTileMaterial.ORDER
	for i in mats.size():
		var t: = V10MjTileView.new()
		layer.add_child(t)
		t.setup([0, 21, 3, 7, 24, 33][i], 0, mats[i], lt, th.accent)
		t.position = tf.slot_center(i) + Vector2(-2, -3)
		t.scale = Vector2.ONE * 0.92
		t.set_state(true, false)


# Shanghai-style stack: layers [[cols, rows], …] centred on the board; returns the tiles (with .gx/.gy/.z meta)
static func _cache(board: Node2D, tiles: Array, lt: Dictionary) -> V10MjStackCache:
	var sc: = V10MjStackCache.new()
	sc.name = "StackCache"
	board.add_child(sc)
	sc.build(tiles, lt)
	return sc


static func stack(board: Node2D, br: Rect2, lt: Dictionary, th: Dictionary, mat: String, layers: Array, k: = 1.0, cached: = true) -> Array:
	var tiles: = []
	var seed_faces: = []
	var total: = 0
	for l in layers:
		total += int(l[0]) * int(l[1])
	for i in total / 2:
		var f: = (i * 7 + 3) % 36
		seed_faces.append(f)
		seed_faces.append(f)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 1010
	for i in range(seed_faces.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var tmp = seed_faces[i]
		seed_faces[i] = seed_faces[j]
		seed_faces[j] = tmp
	var c0: = br.get_center()
	var w0: = float(layers[0][0]) * STEP.x * k
	var h0: = float(layers[0][1]) * STEP.y * k
	var origin: = c0 - Vector2(w0, h0) * 0.5 + STEP * k * 0.5 + Vector2(0, 6)
	var cells: = {}
	var n: = 0
	for z in layers.size():
		var cols: int = layers[z][0]
		var rows: int = layers[z][1]
		var ox: = float(int(layers[0][0]) - cols) * 0.5
		var oy: = float(int(layers[0][1]) - rows) * 0.5
		for y in rows:
			for x in cols:
				var gx: = ox + x
				var gy: = oy + y
				cells[Vector3(gx, gy, z)] = true
				var t: = V10MjTileView.new()
				board.add_child(t)
				t.setup(seed_faces[n % seed_faces.size()], z, mat, lt, th.accent, Color(0.04, 0.02, 0.04, 1.0))
				t.position = origin + Vector2(gx * STEP.x, gy * STEP.y) * k + LAYER_OFF * float(z) * k
				t.scale = Vector2.ONE * k
				t.z_index = z * 200 + int(gy * 2.0) * 12 + int(gx * 2.0)
				t.set_meta("cell", Vector3(gx, gy, z))
				t.set_meta("pos", t.position)      # main-canvas position (the cache moves the node into a SubViewport)
				t.set_meta("k", k)
				tiles.append(t)
				n += 1
	# freedom: nothing on top, and the left or the right neighbour missing
	for t in tiles:
		var c: Vector3 = t.get_meta("cell")
		var covered: = false
		for dx in [-0.5, 0.0, 0.5]:
			for dy in [-0.5, 0.0, 0.5]:
				if cells.has(Vector3(c.x + dx, c.y + dy, c.z + 1)):
					covered = true
		var left: = cells.has(Vector3(c.x - 1, c.y, c.z))
		var right: = cells.has(Vector3(c.x + 1, c.y, c.z))
		var open: = not covered and (not left or not right)
		t.set_state(open, not open)
		t.set_contrast(V10MjTileMaterial.st().contrast)
	if cached:
		_cache(board, tiles, lt)
	return tiles


static func _mark_specials(tiles: Array) -> void:
	var kinds: = ["gold", "ice", "lock", "chain", "joker", "bomb", "gift", "secret", "sig"]
	var i: = 0
	for t in tiles:
		if t.is_open and i < kinds.size():
			t.set_contrast(true, [kinds[i]])
			i += 1


static func _materials_grid(board: Node2D, br: Rect2, lt: Dictionary, th: Dictionary) -> Array:
	var out: = []
	var mats: = V10MjTileMaterial.ORDER
	var cw: = br.size.x / 2.0
	var ch: = br.size.y / 3.0
	for i in mats.size():
		var cell: = Rect2(br.position + Vector2((i % 2) * cw, (i / 2) * ch), Vector2(cw, ch))
		var sub: = Rect2(cell.position + Vector2(0, -6), cell.size - Vector2(0, 34))
		var ts: = stack(board, sub, lt, th, mats[i], [[3, 2], [2, 1]], 0.86)
		out.append_array(ts)
		var l: = Label.new()
		l.text = V10MjTileMaterial.display_name(mats[i])
		l.add_theme_font_override("font", UI.font("body", 800))
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color("f5ead8"))
		l.position = Vector2(cell.get_center().x - 40, cell.end.y - 40)
		l.size = Vector2(80, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_index = 2000
		board.add_child(l)
	return out
