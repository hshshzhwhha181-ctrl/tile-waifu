class_name V7Photo
extends Control







const D: = preload("res://scripts/v07/album/album_data.gd")
const FILTER: = preload("res://shaders/v07/album/photo_filter.gdshader")

var play
var main
var layer: Control
var stars: = 3
var secs: = 0.0
var W: = 720.0
var H: = 1280.0
var shot: = 0
var pose: = 0
var frame_i: = 0
var filter_i: = 0
var caption: = true
var comp: Control
var bar: Control
var hidden_nodes: Array = []
var last_path: = ""
var busy: = false


static func victory_hook(p, root: Control, st: int, s: float) -> void :
	var w: float = p.size.x
	var h: float = p.size.y
	var by: = h - 150.0 - 76.0
	# 0.8 widths follow the result window's column grid (play.V8_RES_COL1 = 250, gap 10): «Повтор» over the
	# secondary button, «Фото» starting where the primary CTA starts
	var has_rb: bool = V7Replay.has_log(p.board)
	if has_rb:
		var rb: = JButton.make("Повтор", "graphite", Rect2(w * 0.5 - 230, by, 250, 62), V8Art.icon("undo"), 22)
		rb.pressed.connect( func(): V7Replay.run(p, root))
		root.add_child(rb)
		UI.pop_in(rb, 1.1)
	var fb: = JButton.make("Фото", "graphite", Rect2(w * 0.5 + 10, by, 190 if has_rb else 250, 62), null, 22)
	fb.pressed.connect( func(): V7Photo.open(p, root, st, s))
	root.add_child(fb)
	UI.pop_in(fb, 1.15)
	var nw: = V7Album.take_new()
	if nw.size() > 0:
		# 0.8: a count, not a list of tile names — the names never fit the left column at 16 px
		var txt: = "Коллекция фишек: +%d %s" % [nw.size(), V8PlayRules.plural(nw.size(), "награда", "награды", "наград")]  # v10-clarity (was «Альбом: +N марок»)
		var ch: = Common.chip(root, V8Art.icon("star"), txt, Rect2(w * 0.5 - 250, by - 56, 500, 44), "plum", 18)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 64 px high touch target around the 44 px chip (play._v8_narrow_chip keeps its width in step)
		var hit: = Control.new()
		hit.name = "Hit"
		hit.position = Vector2(0, -16)
		hit.size = Vector2(ch.size.x, 64)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				UI.tap(ch, 0.05)
				V7AlbumView.open(p.main, "stamps"))
		ch.add_child(hit)
		UI.pop_in(ch, 1.3)
		if V7Album.claimable() > 0:
			Common.badge(ch, V7Album.claimable(), Vector2(486, -10))

	var dw: = String(V7Album.dev.get("win", ""))
	if dw != "":
		await p.get_tree().create_timer(float(V7Album.dev.get("win_at", "3.0"))).timeout
		if is_instance_valid(root) and root.is_inside_tree():
			if dw == "replay":
				V7Replay.run(p, root)
			else:
				V7Photo.open(p, root, st, s)

static func open(p, root: Control, st: int, s: float) -> V7Photo:
	var v: = V7Photo.new()
	v.play = p
	v.main = p.main
	v.layer = root
	v.stars = st
	v.secs = s
	v.size = p.size
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var fr: = String(V7Album.st().get("frame", "rose"))
	var frames: = v._frames()
	for i in frames.size():
		if frames[i].id == fr:
			v.frame_i = i
	v.filter_i = int(V7Album.st().get("filter", 0)) % D.FILTERS.size()
	p.add_child(v)

	for kv in String(V7Album.dev.get("photo", "")).split(",", false):
		var a: PackedStringArray = kv.split(":")
		if a.size() == 2:
			match a[0]:
				"frame": v.frame_i = int(a[1])
				"filter": v.filter_i = int(a[1])
				"pose": v.pose = int(a[1])
				"shot": v.shot = int(a[1])
				"caption": v.caption = a[1] != "0"
	v._open()
	if V7Album.dev.get("photo_save", "") == "1":
		v._save_pressed()
	return v

func _open() -> void :
	W = size.x
	H = size.y
	layer.visible = false
	_hide_hud()
	Sfx.play("whoosh", 1.1)
	_set_shot()
	_rebuild()
	_build_bar()



func _hide_hud() -> void :
	hidden_nodes.append_array(V7Replay.hide_hud(play, [self]))

func _close() -> void :
	if busy:
		return
	Sfx.play("tap")
	V7Replay.hide_all(play.board)
	V7Replay.show_nodes(hidden_nodes)
	if is_instance_valid(layer):
		layer.visible = true
	queue_free()

func _frames() -> Array:
	var r: = D.FRAMES.filter( func(f): return V7Album.frame_unlocked(f))
	r.append_array(V7Album.gold_frames())
	return r

func _poses() -> Array:
	var r: = ["right", "left"]
	if G.equipped(play.partner) != "":
		r.append("card")
	r.append("none")
	return r

func _set_shot() -> void :
	if shot == 0 and V7Replay.has_log(play.board):
		V7Replay.show_start(play.board)
	else:
		V7Replay.hide_all(play.board)


func _rebuild() -> void :
	if comp:
		comp.queue_free()
	comp = Control.new()
	comp.size = size
	comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(comp)
	if bar:
		move_child(bar, -1)
	var poses: = _poses()
	var ps: String = poses[pose % poses.size()]
	var hero_h: = minf(H * 0.5, 680.0)
	if ps in ["right", "left"]:
		var hero: = Hero.new().setup(play.partner, hero_h)
		hero.interactive = false
		hero.position = Vector2(W * (0.78 if ps == "right" else 0.22), H - 24)
		if ps == "left":
			hero.scale = Vector2(-1, 1)
		comp.add_child(hero)
		hero.react("happy")
	elif ps == "card":
		var it: Dictionary = G.ITEM[G.equipped(play.partner)]
		var cw: = 300.0
		var chh: = 420.0
		var pc: = Control.new()
		pc.position = Vector2(W - cw - 34, H - chh - 210)
		pc.size = Vector2(cw, chh)
		pc.pivot_offset = pc.size * 0.5
		pc.rotation = deg_to_rad(5.0)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comp.add_child(pc)
		var pf: = UI.rbox("rose", Rect2(0, 0, cw, chh), 10, 2, 14)
		pf.colors(Color("fbf4ea"), Color("e9ddd0"))
		pc.add_child(pf)
		pc.add_child(Common.card_art(G.art_tex(it), Rect2(14, 14, cw - 28, chh - 80), Vector2(0.5, 0.3), 1.0, 4))
		var nl: = UI.center_label(UI.label(it.name, 20, Color("4a2a33"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, chh - 62, cw, 50))
		pc.add_child(nl)

	var fl: Dictionary = D.FILTERS[filter_i]
	if fl.id != "none":
		var fr: = ColorRect.new()
		fr.size = size
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: = ShaderMaterial.new()
		m.shader = FILTER
		m.set_shader_parameter("mode", filter_i)
		m.set_shader_parameter("t", G.time)
		fr.material = m
		comp.add_child(fr)

	var frames: = _frames()
	var fd: Dictionary = frames[frame_i % frames.size()]
	var fa: = FrameArt.new()
	fa.size = size
	fa.trim = fd.trim
	fa.deep = fd.deep
	fa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comp.add_child(fa)
	if caption:
		_captions(fd)

func _captions(fd: Dictionary) -> void :
	var win: String = "Ва-банк!" if play.riichi else "Победа"  # v10-clarity
	var rib: = Common.ribbon(comp, win, Rect2(W * 0.5 - 210, 54, 420, 86), "pink", 44)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: = UI.rbox("glass", Rect2(W * 0.5 - 280, 150, 560, 150), 24, 3, 10)
	plate.borders(fd.trim, fd.trim.darkened(0.5))
	comp.add_child(plate)
	var code: = String(play.cfg.get("code", ""))
	var lvn: = ("%s · %s" % [code, play.cfg.get("name", "")]) if code != "" else String(play.cfg.get("name", ""))
	plate.add_child(UI.center_label(UI.label(lvn, 24, UI.INK, UI.DARK, 3, "title", 800), Rect2(0, 8, 560, 34)))
	for i in 3:
		var s: = V8Art.star_rect(i < stars, Rect2(280 - 30 + (i - 1) * 66, 42 + (0 if i == 1 else 6), 60, 60))
		plate.add_child(s)
	var bits: = ["%d с" % int(secs)]
	if play.max_combo >= 2:
		bits.append("комбо ×%d" % play.max_combo)
	if play.boosters_used == 0:
		bits.append("без подсказок")
	bits.append(G.rank_of(int(G.S.rp)).title)
	plate.add_child(UI.center_label(UI.label(" · ".join(bits), 18, UI.INK, UI.DARK, 3, "body", 900), Rect2(0, 108, 560, 30)))

	var ys: Array = play.yaku_list.slice(0, 3)
	var x: = W * 0.5 - (ys.size() * 176 - 8) * 0.5
	for y in ys:
		var ch: = Common.chip(comp, null, play._yaku_name(y), Rect2(x, 312, 168, 36), "plum", 15)
		ch.borders(fd.trim, fd.trim.darkened(0.5))
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: Label = ch.get_node("L")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position.x = 6
		l.size.x = 156
		x += 176

	var lg: = V8Art.rect(V8Art.misc("logo"), Rect2(36, H - 186, 230, 130))
	comp.add_child(lg)
	var d: = Time.get_date_dict_from_system()
	var dl: = UI.label("%02d.%02d.%d · с %s" % [d.day, d.month, d.year, G.HEROES[play.partner].name], 17, UI.INK, UI.DARK, 4, "body", 900)
	dl.position = Vector2(40, H - 66)
	comp.add_child(dl)

class FrameArt extends Control:
	var trim: = Color.WHITE
	var deep: = Color.BLACK
	func _draw() -> void :
		var w: = 22.0
		var r: = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(0, 0, r.size.x, w), deep)
		draw_rect(Rect2(0, r.size.y - w, r.size.x, w), deep)
		draw_rect(Rect2(0, 0, w, r.size.y), deep)
		draw_rect(Rect2(r.size.x - w, 0, w, r.size.y), deep)
		draw_rect(r.grow( - w + 1), trim, false, 3.0)
		draw_rect(r.grow( - w - 7), Color(trim, 0.55), false, 1.5)
		draw_rect(r.grow(-6), Color(trim, 0.35), false, 1.0)
		for c in [Vector2(w, w), Vector2(r.size.x - w, w), Vector2(w, r.size.y - w), Vector2(r.size.x - w, r.size.y - w)]:
			var k: = 15.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, - k), c + Vector2(k, 0), c + Vector2(0, k), c + Vector2( - k, 0)]), trim)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), deep)


func _build_bar() -> void :
	if bar:
		bar.queue_free()
	bar = Control.new()
	bar.size = Vector2(W, 214)
	bar.position = Vector2(0, H - 214)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var bgp: = UI.rbox("graphite", Rect2(10, 0, W - 20, 204), 28, 3, 12)
	bar.add_child(bgp)
	var poses: = _poses()
	var frames: = _frames()
	var pose_names: = {"right": "справа", "left": "слева", "card": "наряд", "none": "без неё"}
	var opts: = [
		["Кадр", "стол" if shot == 0 else "финал", _opt_shot], 
		["Героиня", pose_names[poses[pose % poses.size()]], _opt_pose], 
		["Рамка", frames[frame_i % frames.size()].name, _next_frame], 
		["Фильтр", D.FILTERS[filter_i].name, _opt_filter], 
		["Подписи", "да" if caption else "нет", _opt_caption], 
	]
	var bw: = (W - 40 - 4 * 8) / 5.0
	for i in opts.size():
		var o: Array = opts[i]
		var b: = JButton.make(o[0], "graphite", Rect2(20 + i * (bw + 8), 12, bw, 82), null, 18)
		b.set_sub(String(o[1]), 14)
		var cb: Callable = o[2]
		b.pressed.connect( func():
			if busy:
				return
			cb.call()
			_build_bar())
		bar.add_child(b)
	var cl: = JButton.make("", "graphite", Rect2(20, 108, 84, 84), null, 20)
	cl.add_child(V8Art.rect(V8Art.icon("close"), Rect2(20, 20, 44, 44)))
	cl.pressed.connect(_close)
	bar.add_child(cl)
	var sv: = JButton.make("Сохранить", "gold", Rect2(116, 108, (W - 156) * 0.5, 84), null, 26)
	sv.pressed.connect( func(): _save_pressed())
	bar.add_child(sv)
	var sh: = JButton.make("Поделиться", "pink", Rect2(116 + (W - 156) * 0.5 + 12, 108, (W - 156) * 0.5 - 12, 84), null, 26)
	sh.shine_every = 2.4
	sh.pressed.connect( func(): _share_pressed())
	bar.add_child(sh)

func _opt_shot() -> void :
	shot = 1 - shot
	_set_shot()
	_rebuild()

func _opt_pose() -> void :
	pose = (pose + 1) % _poses().size()
	_rebuild()

func _opt_filter() -> void :
	filter_i = (filter_i + 1) % D.FILTERS.size()
	V7Album.st()["filter"] = filter_i
	_rebuild()

func _opt_caption() -> void :
	caption = not caption
	_rebuild()

func _next_frame() -> void :
	var frames: = _frames()
	frame_i = (frame_i + 1) % frames.size()
	V7Album.st()["frame"] = frames[frame_i].id
	if frame_i == 0 and frames.size() < D.FRAMES.size() + 5:
		var locked: = D.FRAMES.filter( func(f): return not V7Album.frame_unlocked(f))
		if locked.size() > 0:
			main.toast("Рамка «%s»: %s" % [locked[0].name, V7Album.frame_hint(locked[0])], "lock")
	_rebuild()

func caption_text() -> String:
	var code: = String(play.cfg.get("code", ""))
	var where: = ("партию %s «%s»" % [code, play.cfg.get("name", "")]) if code != "" else "«%s»" % play.cfg.get("name", "")
	var s: = "Прошёл %s в Tile Waifu за %d с" % [where, int(secs)]
	if play.max_combo >= 3:
		s += ", комбо ×%d" % play.max_combo
	return s + " ★%d" % stars


func capture() -> Image:
	bar.visible = false
	_hide_hud()
	var ov: Array = []
	for c in main.overlay.get_children():
		if c is CanvasItem and c.visible:
			c.visible = false
			ov.append(c)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = null
	var tex: = get_viewport().get_texture()
	if tex:
		img = tex.get_image()
	bar.visible = true
	for c in ov:
		if is_instance_valid(c):
			c.visible = true
	return img

func _flash() -> void :
	var f: = ColorRect.new()
	f.size = size
	f.color = Color(1, 1, 1, 0.85)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var t: = f.create_tween()
	t.tween_property(f, "color:a", 0.0, 0.35)
	t.tween_callback(f.queue_free)
	Sfx.play("clack1", 1.6, -2)

func _save() -> String:
	busy = true
	var img: = await capture()
	busy = false
	if img == null or img.is_empty():
		main.toast("Не получилось сделать снимок", "close")
		return ""
	_flash()
	var p: = save_image(img)
	if p == "":
		main.toast("Не получилось сохранить снимок", "close")
		return ""
	V7Album.add_photo(p)
	print("V7PHOTO saved ", p)
	last_path = p
	return p

func _save_pressed() -> void :
	if busy:
		return
	var p: = await _save()
	if p != "":
		main.toast("Снимок сохранён%s" % (" в галерею: Pictures/TileWaifu" if not p.begins_with(OS.get_user_data_dir()) else " в альбом игры"), "star")

func _share_pressed() -> void :
	if busy:
		return
	var p: = await _save()
	if p == "":
		return
	DisplayServer.clipboard_set(caption_text())
	open_file(main, p, true)


static func open_file(m, path: String, shared: = false) -> void :
	var err: = OS.shell_open(path)
	if err != OK:
		m.toast("Снимок лежит тут: %s" % path, "mail")
	elif shared:
		m.toast("Подпись скопирована. В галерее нажми «Поделиться»", "mail")


static func save_image(img: Image) -> String:
	if img.get_width() > 1080:
		img.resize(1080, int(1080.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var stamp: = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var name: = "TileWaifu_%s.png" % stamp
	var dirs: = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--album_photos="):
			dirs.append(a.substr(15))
	if OS.get_name() == "Android":
		var pics: = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		if pics != "":
			dirs.append(pics.path_join("TileWaifu"))
	dirs.append(OS.get_user_data_dir().path_join("photos"))
	for d in dirs:
		if DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
			continue
		var p: String = d.path_join(name)
		if img.save_png(p) == OK and FileAccess.file_exists(p):
			return p
	return ""

func dev_act(a: String) -> void :
	var m: = {"shot": _opt_shot, "pose": _opt_pose, "frame": _next_frame, "filter": _opt_filter, "caption": _opt_caption}
	if m.has(a):
		(m[a] as Callable).call()
		_build_bar()
	elif a == "save":
		_save_pressed()
