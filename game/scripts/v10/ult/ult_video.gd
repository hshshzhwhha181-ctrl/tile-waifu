class_name V10UltVideo
extends Control

signal finished

const VID_DIR: = "res://assets/v10/ult_video/"
const CG_DIR: = "res://assets/v10/cg_16/"
const LOBBY_VID: = "res://assets/v09/video/mc_lobby.ogv"
const LOBBY_STILL: = "res://assets/v09/video/mc_lobby_still.webp"
const MAX_VID_DUR: = 3.2
# 0.12 wave 1: the five goddesses' 16+ video ults and CGs. Every file is optional: a missing .ogv falls back to the CG,
# a missing CG to her outfit art in res://assets/v10/wave1/outfits/ (never a blank screen).
const W1_VIDEO: = {"kohaku": "kohaku.ogv", "shirin": "shirin.ogv", "tsubame": "tsubame.ogv", "zlata": "zlata.ogv", "miel": "miel.ogv"}
const W1_CG: = {"kohaku": "cg_kohaku_16.webp", "shirin": "cg_shirin_16.webp", "tsubame": "cg_tsubame_16.webp",
	"zlata": "cg_zlata_16.webp", "miel": "cg_miel_16.webp"}
const W1_OUTFIT_DIR: = "res://assets/v10/wave1/outfits/"
const CG_DUR: = 2.0

static var _live: Array = []

var hero_id: = "mc"
var outfit_id: = ""
var ult_title: = "Умение"
var played_visual: = false
var _done: = false
var _skipping: = false
var _elapsed: = 0.0
var _dur: = CG_DUR
var _vp: VideoStreamPlayer
var _cg: TextureRect
var _cg_base_pos: = Vector2.ZERO
var _cg_base_sz: = Vector2.ZERO
var _vid_rect: = Rect2()
var _fx_canvas: Control
var _accent: = Color("ff7fa8")


static func any_playing() -> bool:
	for v in _live:
		if is_instance_valid(v) and not v._done:
			return true
	return false


func is_done() -> bool:
	return _done


static func _has_res(p: String) -> bool:
	return p != "" and (ResourceLoader.exists(p) or FileAccess.file_exists(p))


static func resolve_video_path(h: String, outf: String = "") -> String:
	if bool(G.S.get("modest", false)):
		return ""
	var img_id: = String(G.ITEM.get(outf, {}).get("img", "")) if outf != "" else ""
	var cands: Array[String] = []
	if outf != "":
		cands.append(VID_DIR + outf + ".ogv")
		if outf in ["y_queen", "y_ball", "o_queen"]:
			cands.append(VID_DIR + "yue_queen.ogv")
		elif outf in ["n_ssr", "n_offline", "o_roof"]:
			cands.append(VID_DIR + "nova_roof.ogv")
	if img_id != "":
		cands.append(VID_DIR + img_id + ".ogv")
	if h != "":
		cands.append(VID_DIR + h + ".ogv")
	var wh: = _w1_hero(h, outf)
	if W1_VIDEO.has(wh):
		cands.append(VID_DIR + String(W1_VIDEO[wh]))
	if h == "mc":
		cands.append(LOBBY_VID)
	for p in cands:
		if _has_res(p):
			return p
	return ""


static func resolve_still_path(h: String, outf: String = "", vpath: String = "") -> String:
	var mod_on: = bool(G.S.get("modest", false))
	var img_id: = String(G.ITEM.get(outf, {}).get("img", "")) if outf != "" else ""
	if not mod_on:
		if vpath == LOBBY_VID and ResourceLoader.exists(LOBBY_STILL):
			return LOBBY_STILL
		if vpath != "":
			var stem: = vpath.get_file().get_basename()
			if ResourceLoader.exists(CG_DIR + stem + ".webp"):
				return CG_DIR + stem + ".webp"
			if ResourceLoader.exists(CG_DIR + "cg_%s_16.webp" % stem):
				return CG_DIR + "cg_%s_16.webp" % stem
		for k in [outf, img_id, h]:
			if k != "" and ResourceLoader.exists(CG_DIR + k + ".webp"):
				return CG_DIR + k + ".webp"
		var wcg: = w1_cg_path(_w1_hero(h, outf))
		if wcg != "":
			return wcg
	var w1_art: = w1_outfit_still(h, outf)
	if w1_art != "":
		return w1_art
	var eff: = outf if outf != "" else (V9Ults.for_hero(h) if not V10W1Core.is_wave1_hero(h) else V10W1Core.base_of(h))
	var sh: Dictionary = V9Ults.clip_art(eff)
	var simg: = String(sh.get("img", ""))
	if simg != "" and ResourceLoader.exists(simg):
		return simg
	for wp in ["res://assets/v10/wave1/poses/%s_win.webp" % h, "res://assets/v10/wave1/poses/%s_idle.webp" % h]:
		if ResourceLoader.exists(wp):
			return wp
	if V8Art.has_emotion(h, "happy"):
		return V8Art.emotion_path(h, "happy")
	var hp: = V10W1Core.hero_png(h)
	if ResourceLoader.exists(hp):
		return hp
	return "res://assets/hero/mc.png" if ResourceLoader.exists("res://assets/hero/mc.png") else "res://assets/outfits/mc_base.webp"


# the wave-1 goddess an ult belongs to: the hero id, or the owner of a wave-1 outfit id ("" for everyone else)
static func _w1_hero(h: String, outf: String = "") -> String:
	if V10W1Core.is_wave1_hero(h):
		return h
	if outf != "" and V10W1Core.is_wave1_item(outf):
		return String(V10W1Core.item(outf).get("hero", ""))
	return ""


# res://assets/v10/ult_video/<hero>.ogv of a wave-1 goddess, "" when the file is not there (the CG / outfit art plays)
static func w1_video_path(h: String) -> String:
	var p: = VID_DIR + String(W1_VIDEO.get(h, ""))
	return p if W1_VIDEO.has(h) and _has_res(p) else ""


# res://assets/v10/cg_16/cg_<hero>_16.webp, "" when missing
static func w1_cg_path(h: String) -> String:
	if not W1_CG.has(h):
		return ""
	var p: = CG_DIR + String(W1_CG[h])
	return p if ResourceLoader.exists(p) else ""


# the safe last stop for a wave-1 goddess: the outfit she wears (SFW alt in modest mode), else her base outfit card
static func w1_outfit_still(h: String, outf: String = "") -> String:
	var wh: = _w1_hero(h, outf)
	if wh == "":
		return ""
	var modest: = bool(G.S.get("modest", false))
	var ids: Array = []
	if outf != "":
		ids.append(outf)
	var worn: = String(G.S.get("outfit", {}).get(wh, "")) if G.S.get("outfit") is Dictionary else ""
	if worn != "":
		ids.append(worn)
	ids.append(V10W1Core.base_of(wh))
	for id in ids:
		var it: Dictionary = V10W1Core.item(String(id))
		if it.is_empty():
			continue
		var img: = String(it.get("img", ""))
		if modest and (bool(it.get("bold", false)) or not bool(it.get("sfw", true))) and it.has("alt"):
			img = String(it.alt)
		var p: = V10W1Core.outfit_webp(img)
		if img != "" and ResourceLoader.exists(p):
			return p
	return ""


static func _theora_dims(p: String) -> Vector2:
	if p == LOBBY_VID:
		return Vector2(720, 1280)
	var f: = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return Vector2.ZERO
	var buf: = f.get_buffer(mini(4096, f.get_length()))
	for i in maxi(0, buf.size() - 24):
		if buf[i] == 0x80 and buf[i + 1] == 0x74 and buf[i + 2] == 0x68 and buf[i + 3] == 0x65:
			var pw: = (int(buf[i + 14]) << 16) | (int(buf[i + 15]) << 8) | int(buf[i + 16])
			var ph: = (int(buf[i + 17]) << 16) | (int(buf[i + 18]) << 8) | int(buf[i + 19])
			if pw > 32 and ph > 32:
				return Vector2(pw, ph)
			break
	return Vector2.ZERO


static func play(parent: Control, h: String, outf: String = "", uname: String = "") -> V10UltVideo:
	var v: = V10UltVideo.new()
	v.name = "V10UltVideo"
	v.hero_id = h if h != "" else "mc"
	v.outfit_id = outf
	v.ult_title = uname if uname != "" else String(G.SKILLS.get(v.hero_id, {}).get("name", "Умение"))
	if DisplayServer.get_name() == "headless" or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		v._done = true
		v.finished.emit.call_deferred()
		return v
	v.played_visual = true
	parent.add_child(v)
	v._setup(parent)
	return v


func _setup(parent: Control) -> void:
	position = Vector2.ZERO
	size = parent.size if parent.size.x > 0.0 else Vector2(720, 1280)
	z_index = 350
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_accent = G.HEROES.get(hero_id, {}).get("color", Color("ff7fa8"))
	_live.append(self)
	tree_exiting.connect(func(): _live.erase(self))

	var br: = V10Layout.bleed_rect(parent)
	var vpath: = resolve_video_path(hero_id, outfit_id)
	var spath: = resolve_still_path(hero_id, outfit_id, vpath)
	var stex: Texture2D = load(spath) as Texture2D if spath != "" and ResourceLoader.exists(spath) else null

	var bg: = ColorRect.new()
	bg.position = br.position
	bg.size = br.size
	bg.color = Color(0.05, 0.02, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	if stex != null:
		var amb: = TextureRect.new()
		amb.texture = stex
		amb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		amb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		amb.position = br.position
		amb.size = br.size
		amb.modulate = Color(_accent.r * 0.45 + 0.2, _accent.g * 0.35 + 0.15, _accent.b * 0.45 + 0.22, 0.42)
		amb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(amb)

	var stream: VideoStream = null
	if vpath != "":
		if ResourceLoader.exists(vpath):
			stream = load(vpath) as VideoStream
		if stream == null and FileAccess.file_exists(vpath):
			var th: = VideoStreamTheora.new()
			th.file = vpath
			stream = th

	if stream != null:
		_dur = MAX_VID_DUR
		var vdim: = _theora_dims(vpath)
		if vdim == Vector2.ZERO and stex != null:
			vdim = stex.get_size()
		if vdim == Vector2.ZERO:
			vdim = Vector2(720, 720)
		var vr: Rect2
		if vdim.y > vdim.x * 1.15:
			vr = V10Layout.cover_rect(vdim, br, Vector2(0.5, 0.38))
		else:
			var side: = clampf(maxf(br.size.x * 1.34, br.size.y * 0.64), br.size.x, br.size.x * 1.48)
			vr = Rect2(br.get_center().x - side * 0.5, br.position.y + (br.size.y - side) * 0.34, side, side)
			_vid_rect = Rect2(vr.position - br.position, vr.size)
		if stex != null:
			var still: = TextureRect.new()
			still.texture = stex
			still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			still.position = vr.position
			still.size = vr.size
			still.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(still)
		_vp = VideoStreamPlayer.new()
		_vp.stream = stream
		_vp.expand = true
		_vp.position = vr.position
		_vp.size = vr.size
		_vp.volume_db = -80.0
		_vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp.finished.connect(_finish)
		add_child(_vp)
		_vp.play()
	else:
		_dur = CG_DUR
		if stex != null:
			var cr: = V10Layout.cover_rect(stex.get_size(), br, Vector2(0.5, 0.32))
			_cg = TextureRect.new()
			_cg.texture = stex
			_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_cg.position = cr.position
			_cg.size = cr.size
			_cg.pivot_offset = cr.size * Vector2(0.5, 0.36)
			_cg.scale = Vector2.ONE * 1.04
			_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_cg)
			_cg_base_pos = cr.position
			_cg_base_sz = cr.size

	_fx_canvas = Control.new()
	_fx_canvas.position = br.position
	_fx_canvas.size = br.size
	_fx_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_canvas.draw.connect(_draw_fx)
	add_child(_fx_canvas)

	_build_banner_and_skip(br)
	Sfx.duck(-7.0, _dur)
	Sfx.play("reveal_ssr", 1.08, -3.0)
	var vline: = Sfx.say(hero_id, "fever")
	if vline != "" and has_node("Banner/VoiceSub"):
		(get_node("Banner/VoiceSub") as Label).text = "«%s»" % vline

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.14)
	gui_input.connect(func(e: InputEvent):
		if _elapsed >= 0.22 and ((e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)):
			accept_event()
			skip())


func _build_banner_and_skip(br: Rect2) -> void:
	var ins: = V10Layout.safe_insets(br.size)
	var banner: = Control.new()
	banner.name = "Banner"
	var bw: = minf(660.0, size.x - 32.0)
	var bh: = 138.0
	banner.position = Vector2((size.x - bw) * 0.5, br.end.y - float(ins.bottom) - bh - 34.0)
	banner.size = Vector2(bw, bh)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	var box: = UI.rbox("plum", Rect2(Vector2.ZERO, banner.size), 26, 3, 12)
	box.colors(Color(0.16, 0.05, 0.12, 0.94), Color(0.07, 0.02, 0.08, 0.97))
	box.borders(Color("ffe7a6"), Color("c58a2c"))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(box)

	var hname: = String(G.HEROES.get(hero_id, {}).get("name", "Героиня")).to_upper()
	var over: = UI.label(hname, 16, _accent.lightened(0.45), Color(0.1, 0.02, 0.08), 4, "body", 900)
	over.position = Vector2(24, 10)
	over.size = Vector2(bw - 48, 24)
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(over)

	var ttl_txt: = "ПРИЁМ · %s" % ult_title
	var fs: = 32
	var tf: = UI.font("title", 900)
	while fs > 22 and tf.get_string_size(ttl_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > bw - 44.0:
		fs -= 2
	var ttl: = UI.title(ttl_txt, fs, Color("fff3d6"), Color("4a0e24"))
	ttl.position = Vector2(20, 34)
	ttl.size = Vector2(bw - 40, 52)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ttl.clip_text = true
	banner.add_child(ttl)

	var sub: = UI.label("", 18, Color("ffe7a6"), Color(0.08, 0.02, 0.08), 3, "body", 800)
	sub.name = "VoiceSub"
	sub.position = Vector2(24, 90)
	sub.size = Vector2(bw - 48, 36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	banner.add_child(sub)
	UI.slide_in(banner, Vector2(0, 36), 0.04, 0.28)

	var sk: = Control.new()
	sk.name = "SkipBtn"
	sk.size = Vector2(184, 52)
	sk.position = Vector2(size.x - sk.size.x - 16.0, br.position.y + float(ins.top) + 18.0)
	sk.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sk)
	var sbox: = UI.rbox("graphite", Rect2(Vector2.ZERO, sk.size), 26, 2, 6)
	sbox.colors(Color(0.1, 0.06, 0.14, 0.88), Color(0.05, 0.03, 0.08, 0.92)).borders(Color("ffe7a6"), Color("c58a2c"))
	sbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sk.add_child(sbox)
	var sl: = UI.center_label(UI.label("Пропустить ›", 19, Color("fff3d6"), Color(0.08, 0.02, 0.1), 3, "body", 900), Rect2(Vector2.ZERO, sk.size))
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sk.add_child(sl)
	sk.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			sk.accept_event()
			skip())


func _draw_fx() -> void:
	if _fx_canvas == null:
		return
	var sz: = _fx_canvas.size
	if _vid_rect.size.y > 0.0:
		var ty0: = maxf(0.0, _vid_rect.position.y - 2.0)
		var ty1: = ty0 + 96.0
		_fx_canvas.draw_rect(Rect2(0, 0, sz.x, ty0 + 2.0), Color(0.05, 0.02, 0.08, 0.96), true)
		_fx_canvas.draw_polygon(PackedVector2Array([Vector2(0, ty0), Vector2(sz.x, ty0), Vector2(sz.x, ty1), Vector2(0, ty1)]),
			PackedColorArray([Color(0.05, 0.02, 0.08, 0.96), Color(0.05, 0.02, 0.08, 0.96), Color(0.05, 0.02, 0.08, 0.0), Color(0.05, 0.02, 0.08, 0.0)]))
		var vy1: = minf(sz.y, _vid_rect.end.y + 2.0)
		var vy0: = vy1 - 110.0
		_fx_canvas.draw_polygon(PackedVector2Array([Vector2(0, vy0), Vector2(sz.x, vy0), Vector2(sz.x, vy1), Vector2(0, vy1)]),
			PackedColorArray([Color(0.05, 0.02, 0.08, 0.0), Color(0.05, 0.02, 0.08, 0.0), Color(0.05, 0.02, 0.08, 0.96), Color(0.05, 0.02, 0.08, 0.96)]))
		_fx_canvas.draw_rect(Rect2(0, vy1 - 2.0, sz.x, maxf(0.0, sz.y - vy1 + 4.0)), Color(0.05, 0.02, 0.08, 0.96), true)
	# Top and bottom soft luxury cinematic vignettes
	var th: = sz.y * 0.18
	_fx_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), Vector2(sz.x, th), Vector2(0, th)]),
		PackedColorArray([Color(0.04, 0.01, 0.06, 0.82), Color(0.04, 0.01, 0.06, 0.82), Color(0.04, 0.01, 0.06, 0.0), Color(0.04, 0.01, 0.06, 0.0)]))
	var by0: = sz.y * 0.72
	_fx_canvas.draw_polygon(PackedVector2Array([Vector2(0, by0), Vector2(sz.x, by0), sz, Vector2(0, sz.y)]),
		PackedColorArray([Color(0.04, 0.01, 0.06, 0.0), Color(0.04, 0.01, 0.06, 0.0), Color(0.04, 0.01, 0.06, 0.92), Color(0.04, 0.01, 0.06, 0.92)]))
	if not V9Feel.can_fx():
		return
	# Diagonal golden & sakura speedlines + katana slashes
	var k: = clampf(_elapsed / maxf(0.1, _dur), 0.0, 1.0)
	for i in 10:
		var ph: = fmod(_elapsed * (2.6 + float(i % 3) * 0.7) + float(i) * 0.21, 1.0)
		var y0: = sz.y * (0.10 + 0.78 * fmod(float(i) * 0.173, 1.0))
		var x0: = lerpf(-220.0, sz.x + 120.0, ph)
		var dir: = Vector2(240.0, -56.0)
		var col: = Color("ffe7a6") if i % 2 == 0 else _accent.lightened(0.35)
		var a: = sin(ph * PI) * (0.42 if _vp == null else 0.24)
		_fx_canvas.draw_line(Vector2(x0, y0), Vector2(x0, y0) + dir, Color(col.r, col.g, col.b, a), 2.5 if i % 3 != 0 else 4.2, true)
	# Sweeping golden burst slash on entry
	if _elapsed < 0.55:
		var sk: = _elapsed / 0.55
		var sa: = (1.0 - sk) * 0.75
		var p1: = Vector2(-40.0, sz.y * 0.68 - sk * 40.0)
		var p2: = Vector2(sz.x + 40.0, sz.y * 0.28 - sk * 40.0)
		_fx_canvas.draw_line(p1, p2, Color(_accent.r, _accent.g, _accent.b, sa * 0.7), 14.0 * (1.0 - sk * 0.5), true)
		_fx_canvas.draw_line(p1, p2, Color(1.0, 0.93, 0.72, sa), 4.5, true)
	if _cg != null:
		var z: = 1.04 + 0.13 * (1.0 - pow(1.0 - k, 2.0))
		_cg.scale = Vector2.ONE * z
		_cg.position = _cg_base_pos + Vector2(lerpf(-14.0, 14.0, k), lerpf(10.0, -18.0, k))


func _process(dt: float) -> void:
	if _done:
		return
	_elapsed += dt
	if _fx_canvas:
		_fx_canvas.queue_redraw()
	if not _skipping and _elapsed >= _dur:
		skip()


func skip() -> void:
	if _done or _skipping:
		return
	_skipping = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(_finish)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _vp and is_instance_valid(_vp):
		_vp.stop()
	_live.erase(self)
	finished.emit()
	queue_free()
