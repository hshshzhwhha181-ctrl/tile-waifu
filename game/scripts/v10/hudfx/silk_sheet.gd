class_name V10SilkSheet
extends Control

# V10SilkSheet — «Шёлк», the one bottom sheet of HUD v2: pause, «Не хватает», confirmations.
# HUD_V2 §2.1 «Лист» (night.700, radius 4 on top, a stack of M/L plates, H1 Display 44 on the left margin, no rim,
# no ribbon), §6 «Лист („Шёлк“) 220 мс QUINT_OUT, снизу вверх, под ним заранее размытый снимок»; UX_RULES §6.1
# «Живого blur на Mali нет», §6.7 «Шёлк 180–240 мс QUINT OUT», §3.6 «лист не открывается поверх листа».
#
#   var s := V10SilkSheet.open(host, content, 472, {"title": "Пауза", "dismiss_outside": true, "tone": 0.5})
#   s.opened / s.closed      signals; closed fires exactly once (close(), outside tap, Android «назад», host freed);
#                            opened does not fire when the sheet is closed during its slide
#   s.close()                sheet down + backdrop fade 160 ms QUINT_IN, then the sheet and its content are freed
#   V10SilkSheet.current()   the open sheet or null; open() over an open sheet swaps it (no second readback)
#
# height = the visible sheet incl. its 24 px padding (on the 8 grid); the safe bottom inset is added below it and
# the sheet never rises above T + 88. content gets the rect under the title: x 24 (720 column), w 672.
#
# Order of events (one readback, nothing per frame afterwards):
#   frame 0   open(): a transparent full-screen blocker (input behind is swallowed at once), sheet below the edge
#   frame 0   RenderingServer.frame_post_draw → get_viewport().get_texture().get_image() ONCE (captures += 1)
#             → shrink_x2 halvings to 90 px wide (exact 2×2 box: 1/8, 90×160) → one more halving to 45×80 →
#             3 passes of a [1,2,1] kernel per axis (σ ≈ 1.2 px there ≈ 20 px on screen) on RGBA packed in int32
#             (exact byte-lane averages, all 4 channels per integer op) → bilinear back to 90×160 → ImageTexture.
#             ≈ 3 ms of CPU on a desktop core besides the readback (a per-byte running sum at 90×160 was 27 ms);
#             the split is printed once per snapshot in debug builds and kept in V10SilkSheet.last_ms
#   220 ms    sheet slides up QUINT_OUT while the backdrop (snapshot, linear, covered + night.900 α tone) fades in
#   160 ms    close(): sheet down + fade QUINT_IN → snapshot texture released, closed, queue_free
# Headless, a failed or empty readback, 3 processed frames with none drawn → a flat night.900 α 0.72 tone (no error).
# Sounds: V10HudFx.sound("silk_open" / "silk_close", 1.0, -10).
# fx_level: full = mid (the sheet has no particles or light); min = 120 ms fades, no slide, the static snapshot stays.
# Game: host = main.overlay (z 400 over the tiles in a match; meta v8_back → main.android_back closes it).
# Works while the tree is paused (PROCESS_MODE_ALWAYS, tweens via V10HudFx.tw bound to the sheet).

signal opened
signal closed

const T_OPEN: = 0.22  # V10HudFx.T_SILK
const T_CLOSE: = 0.16
const PAD: = 24
const TITLE_H: = 56  # H1 Display 44/52 in an 8-grid box
const TITLE_GAP: = 16
const TOP_KEEP: = 88  # the top band (88 + T) always stays visible above the sheet
const TONE_A: = 0.5
const FALLBACK_A: = 0.72
const SNAP_W: = 90  # snapshot texture width: 1/8 of the 720 base
const BLUR_PASSES: = 3  # [1,2,1] passes per axis at 1/16
const LANE: = 0xFEFEFEFE  # byte-lane mask for the packed averages
const CAPTURE_FRAMES: = 3  # processed frames without a drawn one → give up the snapshot, open on the flat tone

static var captures: = 0  # viewport readbacks so far (one per open; a swap reuses the old one)
static var sim_frame: Image = null  # selftest: stands in for the viewport readback (exercises the real pipeline)
static var last_ms: = {}  # {"read", "shrink", "blur", "upload", "total", "src", "out"} of the last snapshot
static var log_timing: = true  # one print per snapshot in debug builds
static var _current_id: = 0

var content: Control
var sheet_h: = 472
var title: = ""
var dismiss_outside: = true
var tone: = TONE_A
var state: = "new"  # new → capturing → opening → open → closing → closed
var blurred: = false  # true: the blurred snapshot is under the sheet; false: the flat fallback tone
var snapshot: ImageTexture = null

var backdrop: Control  # snapshot + tone, fades as one
var snap_rect: TextureRect
var tone_rect: ColorRect
var panel: Control
var title_l: Label
var _guard: Control  # swallows taps on the sheet while it closes
var _tw: Tween
var _press_out: = false
var _wait_frames: = 0
var _handover: = {}


static func open(host: Node, sheet_content: Control, height: int, opts: = {}) -> V10SilkSheet:
	if host == null or not is_instance_valid(host):
		push_warning("V10SilkSheet.open: host is gone")
		return null
	var s: = V10SilkSheet.new()
	s.content = sheet_content
	s.sheet_h = height
	s.title = str(opts.get("title", ""))
	s.dismiss_outside = bool(opts.get("dismiss_outside", true))
	s.tone = clampf(float(opts.get("tone", TONE_A)), 0.0, 1.0)
	s._attach()
	# UX §3.6: never a sheet over a sheet — the old one gives up its snapshot and leaves this frame
	var prev: = _any_live()
	if prev:
		s._handover = prev._hand_over()
	_current_id = s.get_instance_id()
	host.add_child(s)
	return s


static func current() -> V10SilkSheet:
	var s: = _any_live()
	return s if s and s.state != "closing" else null


static func _any_live() -> V10SilkSheet:
	if _current_id == 0:
		return null
	var o: = instance_from_id(_current_id)
	if o is V10SilkSheet and is_instance_valid(o) and not (o as Node).is_queued_for_deletion() and (o as V10SilkSheet).state != "closed":
		return o
	return null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP  # the blocker: nothing behind the sheet gets a tap
	focus_mode = Control.FOCUS_NONE
	backdrop = Control.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate.a = 0.0
	add_child(backdrop)
	snap_rect = TextureRect.new()
	snap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snap_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snap_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	snap_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	snap_rect.visible = false
	backdrop.add_child(snap_rect)
	tone_rect = ColorRect.new()
	tone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tone_rect.color = Color(V10DS.NIGHT_900, FALLBACK_A)
	backdrop.add_child(tone_rect)
	panel = _Panel.new()
	add_child(panel)
	_guard = Control.new()
	_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	_guard.visible = false
	panel.add_child(_guard)


func _attach() -> void:
	# title and content belong to the sheet from open() on: freed with it even if it never enters the tree
	if title != "" and title_l == null:
		title_l = V10Type.label(title, "display", 44, V10DS.PAPER_100)
		panel.add_child(title_l)
	if content and content.get_parent() != panel:
		if content.get_parent():
			content.get_parent().remove_child(content)
		content.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.add_child(content)
	panel.move_child(_guard, -1)


func _ready() -> void:
	set_process(false)
	set_meta("v8_back", close)  # Android «назад» (main.android_back) closes the top sheet
	set_meta("popup", true)
	_attach()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if not _handover.is_empty():
		# swap: the screen behind did not change (the old sheet blocked it), reuse its blurred snapshot
		if _handover.get("tex") != null:
			_show_snapshot(_handover.tex)
		else:
			_flat()
		backdrop.modulate.a = float(_handover.get("alpha", 0.0))
		_handover = {}
		_start_open()
	elif sim_frame != null:
		captures += 1
		_take(sim_frame.duplicate(), Time.get_ticks_usec())
		_start_open()
	elif DisplayServer.get_name() == "headless" or not DisplayServer.window_can_draw():
		_flat()
		_start_open()
	else:
		state = "capturing"
		RenderingServer.frame_post_draw.connect(_on_post_draw, CONNECT_ONE_SHOT)
		# watchdog in frames, not seconds (a long frame is not a missing one): processed frames with nothing drawn
		# (app sent to background, minimised window) → the flat tone, never an invisible blocker that eats taps
		get_tree().process_frame.connect(_on_capture_tick)


func _exit_tree() -> void:
	# the host was freed (or the sheet removed) mid-way: release the snapshot, closed still fires exactly once
	if state != "closed":
		_finish(false)


# ------------------------------------------------------------------ snapshot

func _on_post_draw() -> void:
	if state != "capturing" or not is_inside_tree():
		return
	_stop_capture()
	var t0: = Time.get_ticks_usec()
	var img: Image = null
	var vt: = get_viewport().get_texture()
	if vt:
		img = vt.get_image()  # THE readback (the frame just drawn: the screen without the sheet)
	captures += 1
	_take(img, t0)
	_start_open()


func _on_capture_tick() -> void:
	_wait_frames += 1
	if state == "capturing" and _wait_frames <= CAPTURE_FRAMES:
		return
	_stop_capture()
	if state == "capturing":
		_flat()
		_start_open()


func _stop_capture() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	if is_inside_tree() and get_tree().process_frame.is_connected(_on_capture_tick):
		get_tree().process_frame.disconnect(_on_capture_tick)


func _take(img: Image, t0: int) -> void:
	var tex: = soften(img, t0)
	if tex == null:
		_flat()
		return
	_show_snapshot(tex)


func _show_snapshot(tex: ImageTexture) -> void:
	snapshot = tex
	snap_rect.texture = tex
	snap_rect.visible = true
	tone_rect.color = Color(V10DS.NIGHT_900, tone)
	blurred = true


func _flat() -> void:
	blurred = false
	snap_rect.visible = false
	tone_rect.color = Color(V10DS.NIGHT_900, FALLBACK_A)


func _release_snapshot() -> void:
	if is_instance_valid(snap_rect):
		snap_rect.texture = null
	snapshot = null


# frame → 90 px wide (box-filtered halvings) → blurred at 45 px → 90 px ImageTexture; null on an unusable image
static func soften(img: Image, t0: = -1) -> ImageTexture:
	if t0 < 0:
		t0 = Time.get_ticks_usec()
	if img == null or img.is_empty() or img.is_compressed() or img.get_width() < 8 or img.get_height() < 8:
		return null
	var t1: = Time.get_ticks_usec()
	var src: = img.get_size()
	if img.has_mipmaps():
		img.clear_mipmaps()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	while img.get_width() >= SNAP_W * 2:
		img.shrink_x2()  # exact 2×2 box average: no aliasing on the way down
	if img.get_width() != SNAP_W:
		img.resize(SNAP_W, maxi(8, roundi(img.get_height() * float(SNAP_W) / img.get_width())), Image.INTERPOLATE_BILINEAR)
	var out: = img.get_size()
	img.shrink_x2()  # the blur runs at 1/16: a quarter of the pixels for the same σ on screen
	var t2: = Time.get_ticks_usec()
	var w: = img.get_width()
	var h: = img.get_height()
	var px: = img.get_data().to_int32_array()
	var tmp: = PackedInt32Array()
	tmp.resize(px.size())
	for i in BLUR_PASSES:
		_pass_rows(px, tmp, w, h)
		_pass_cols(tmp, px, w, h)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px.to_byte_array())
	img.resize(out.x, out.y, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)  # opaque whatever the frame's alpha was
	var t3: = Time.get_ticks_usec()
	var tex: = ImageTexture.create_from_image(img)
	var t4: = Time.get_ticks_usec()
	last_ms = {"read": (t1 - t0) / 1000.0, "shrink": (t2 - t1) / 1000.0, "blur": (t3 - t2) / 1000.0,
			"upload": (t4 - t3) / 1000.0, "total": (t4 - t0) / 1000.0, "src": src, "out": out}
	if log_timing and OS.is_debug_build():
		print("V10SilkSheet snapshot %dx%d → %dx%d: read %.1f ms, shrink %.1f, blur %.1f, upload %.1f, total %.1f ms" % [
				src.x, src.y, out.x, out.y, last_ms.read, last_ms.shrink, last_ms.blur, last_ms.upload, last_ms.total])
	return tex


# [1,2,1]/4 along rows on packed RGBA8: avg_floor(avg_ceil(left, right), centre) per byte lane — exact, no
# overflow between lanes, and the ceil/floor roundings cancel (a flat colour stays bit-exact). Edges clamp.
static func _pass_rows(s: PackedInt32Array, d: PackedInt32Array, w: int, h: int) -> void:
	for y in h:
		var i: = y * w
		var e: = i + w - 1
		var a: = s[i]
		var b: = a
		while i <= e:
			var c: = s[i + 1] if i < e else b
			var ac: = (a | c) - (((a ^ c) & LANE) >> 1)
			d[i] = (ac & b) + (((ac ^ b) & LANE) >> 1)
			a = b
			b = c
			i += 1


static func _pass_cols(s: PackedInt32Array, d: PackedInt32Array, w: int, h: int) -> void:
	var n: = w * h
	for x in w:
		var i: = x
		var a: = s[i]
		var b: = a
		while i < n:
			var c: = s[i + w] if i + w < n else b
			var ac: = (a | c) - (((a ^ c) & LANE) >> 1)
			d[i] = (ac & b) + (((ac ^ b) & LANE) >> 1)
			a = b
			b = c
			i += w


# ------------------------------------------------------------------ motion

func _start_open() -> void:
	if state == "closed":
		return
	state = "opening"
	V10HudFx.sound("silk_open", 1.0, -10.0)
	var y_open: = _y_open()
	_tw = V10HudFx.tw(self)
	_tw.set_parallel(true)
	if V10HudFx.is_min():
		# «минимум»: a 120 ms fade in place, no slide (the snapshot is static, so it stays)
		panel.position.y = y_open
		panel.modulate.a = 0.0
		_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(backdrop, "modulate:a", 1.0, V10HudFx.T_MIN)
		_tw.tween_property(panel, "modulate:a", 1.0, V10HudFx.T_MIN)
	else:
		panel.modulate.a = 1.0
		panel.position.y = _vs().y
		_tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		_tw.tween_property(panel, "position:y", y_open, T_OPEN)
		_tw.tween_property(backdrop, "modulate:a", 1.0, T_OPEN)
	_tw.chain().tween_callback(_on_opened)


func _on_opened() -> void:
	if state != "opening":
		return
	state = "open"
	_tw = null
	opened.emit()


func close() -> void:
	if state == "closing" or state == "closed":
		return
	if not is_inside_tree() or state == "new" or state == "capturing":
		_finish(true)  # nothing has been shown yet: no motion, no sound
		return
	state = "closing"
	set_meta("closing", true)  # main.android_back skips a closing popup
	_guard.visible = true  # the sheet's own rows cannot be pressed twice; the blocker keeps the screen behind
	_press_out = false
	if _tw:
		_tw.kill()
	V10HudFx.sound("silk_close", 1.0, -10.0)
	_tw = V10HudFx.tw(self)
	_tw.set_parallel(true)
	if V10HudFx.is_min():
		_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tw.tween_property(backdrop, "modulate:a", 0.0, V10HudFx.T_MIN)
		_tw.tween_property(panel, "modulate:a", 0.0, V10HudFx.T_MIN)
	else:
		_tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		_tw.tween_property(panel, "position:y", _vs().y, T_CLOSE)
		_tw.tween_property(backdrop, "modulate:a", 0.0, T_CLOSE)
	_tw.chain().tween_callback(_finish.bind(true))


func _finish(free_node: = true) -> void:
	if state == "closed":
		return
	state = "closed"
	set_meta("closing", true)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = null
	_stop_capture()
	_release_snapshot()
	if _current_id == get_instance_id():
		_current_id = 0
	closed.emit()
	if free_node and not is_queued_for_deletion():
		queue_free()


func _hand_over() -> Dictionary:
	# called by open() of the next sheet: give it the snapshot and the backdrop's alpha, vanish this frame
	var d: = {"tex": snapshot if blurred else null, "alpha": backdrop.modulate.a if blurred else 0.0}
	visible = false
	_finish(true)
	return d


# the running tween (open or close) — tests and the demo step it by hand
func tween() -> Tween:
	return _tw


# ------------------------------------------------------------------ layout and input

func _vs() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)


func visible_h() -> float:
	var vs: = _vs()
	var ins: = V10Hud2Util.safe_insets(vs)
	return clampf(float(sheet_h), PAD * 2.0 + 8.0, vs.y - float(ins.top) - float(ins.bottom) - TOP_KEEP)


func _y_open() -> float:
	return _vs().y - panel.size.y


func panel_rect() -> Rect2:
	return Rect2(panel.position, panel.size)


func _layout() -> void:
	if not is_inside_tree():
		return
	var vs: = _vs()
	var ins: = V10Hud2Util.safe_insets(vs)
	if get_parent() is CanvasItem:
		global_position = Vector2.ZERO  # cover the viewport whatever the host's rect is
	else:
		position = Vector2.ZERO
	size = vs
	backdrop.size = vs
	snap_rect.size = vs
	tone_rect.size = vs
	var vh: = visible_h()
	panel.size = Vector2(vs.x, vh + float(ins.bottom))
	match state:
		"open":
			panel.position.y = _y_open()
		"new", "capturing":
			panel.position = Vector2(0, vs.y)
	panel.position.x = 0.0
	var col: = minf(vs.x, 720.0)
	var x: = floorf((vs.x - col) * 0.5) + PAD
	var cw: = col - PAD * 2.0
	var y: = float(PAD)
	if title_l:
		title_l.position = Vector2(x, y)
		title_l.size = Vector2(cw, TITLE_H)
		y += TITLE_H + TITLE_GAP
	if content:
		content.position = Vector2(x, y)
		content.size = Vector2(cw, maxf(0.0, vh - y - PAD))
	_guard.position = Vector2.ZERO
	_guard.size = panel.size
	panel.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	# only taps OUTSIDE the sheet land here (the sheet is MOUSE_FILTER_STOP); all of them are swallowed
	accept_event()
	if not dismiss_outside or (state != "opening" and state != "open"):
		return
	var tap: = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if not tap:
		return
	if e.is_pressed():
		_press_out = not panel_rect().has_point(e.position)
	elif _press_out:
		_press_out = false
		if not panel_rect().has_point(e.position):
			close()


class _Panel:
	extends Control
	# the sheet surface: night.700, radius 4 on the top corners, lacquer tone, ONE gold.700 α 0.35 hairline on top

	var _sb: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_sb = StyleBoxFlat.new()
		_sb.bg_color = V10DS.NIGHT_700
		_sb.corner_radius_top_left = V10DS.RADIUS
		_sb.corner_radius_top_right = V10DS.RADIUS
		_sb.anti_aliasing = true

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		draw_style_box(_sb, r)
		# lacquer: paper.100 α 0.05 → 0 under the top edge (a tone, not a gloss stripe)
		var lh: = minf(size.y * 0.4, 160.0)
		var lac: = Color(V10DS.PAPER_100, V10DS.LACQUER_A)
		var clear: = Color(V10DS.PAPER_100, 0.0)
		draw_polygon(PackedVector2Array([Vector2(2, 1), Vector2(size.x - 2, 1), Vector2(size.x - 2, lh), Vector2(2, lh)]),
				PackedColorArray([lac, lac, clear, clear]))
		V10Plate.hairline(self, V10DS.HAIR_INSET, size.x - V10DS.HAIR_INSET, 0.5, V10DS.hair())
