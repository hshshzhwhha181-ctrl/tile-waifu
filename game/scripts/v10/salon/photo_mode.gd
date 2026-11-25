class_name V10SalonPhoto
extends Control

# Photo mode of a zone scene (spec §Р2 п.4): the interface melts away in 0.25 s, three framing presets
# (В рост · По пояс · Портрет) zoom the stage, the shutter waits one frame, a vignette «flash» in the zone accent
# (never white, UX §6.7), a small watermark «Tile Waifu · ИИ-арт» is drawn into the picture, and the PNG goes to
# user://photos/ with an index in S.v10_salon.photos (integration: V7Album / TWShare in 1.0, see README).
# Scenes of outfits with sfw=false use their `alt` in modest mode — the zone scenes 0.10 are base outfits (sfw).

signal shot(path: String)

const PRESETS: = [
	{"name": "В рост", "zoom": 1.0, "focus": Vector2(0.5, 0.5)},
	{"name": "По пояс", "zoom": 1.45, "focus": Vector2(0.5, 0.36)},
	{"name": "Портрет", "zoom": 2.1, "focus": Vector2(0.5, 0.2)},
]

var host: Control
var stage: Control
var ui: Control
var zid: = ""
var preset: = 0
var bar: Control
var chips: = []
var last_path: = ""
var _busy: = false


static func open(host_: Control, stage_: Control, ui_: Control, zid_: String) -> V10SalonPhoto:
	var p: = V10SalonPhoto.new()
	p.host = host_
	p.stage = stage_
	p.ui = ui_
	p.zid = zid_
	p.size = host_.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 60
	host_.add_child(p)
	p._build()
	return p


func _build() -> void:
	var W: = size.x
	var H: = size.y
	# the interface melts (0.25 s); the floor shade goes with it
	var t: = create_tween()
	t.tween_property(ui, "modulate:a", 0.0, 0.25)
	for nm in ["FloorShade", "TopShade"]:
		var fs: = host.get_node_or_null(nm)
		if fs:
			t.parallel().tween_property(fs, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): ui.visible = false)
	bar = Control.new()
	bar.size = Vector2(W, 220)
	bar.position = Vector2(0, H - 220)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate.a = 0.0
	add_child(bar)
	var cw: = 172.0
	var x0: = (W - (cw * 3 + 24)) * 0.5
	# the three framings are ONE segmented control (ux_role on the row); each chip has an 80 px hit zone
	var row: = Control.new()
	row.name = "Presets"
	row.position = Vector2(x0, -8)
	row.size = Vector2(cw * 3 + 24, 80)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("ux_role", "secondary")
	bar.add_child(row)
	for i in PRESETS.size():
		var b: = V10SalonButton.make("chip", PRESETS[i].name, Rect2(i * (cw + 12), 0, cw, 80))
		b.selected = i == preset
		var ii: = i
		b.pressed.connect(func(): set_preset(ii))
		row.add_child(b)
		chips.append(b)
	# the shutter is the one main action of photo mode: the round shape, rose fill
	var shutter: = V10SalonButton.make("quiet", "", Rect2(W * 0.5 - 56, 88, 112, 112))
	shutter.icon = "camera"
	shutter.fill = true
	shutter.set_meta("ux_role", "primary")
	shutter.sound = ""
	shutter.pressed.connect(func(): shoot())
	shutter.name = "Shutter"
	bar.add_child(shutter)
	var done: = V10SalonButton.make("quiet", "", Rect2(W - 112, 104, 80, 80))
	done.icon = "close"
	done.pressed.connect(close)
	bar.add_child(done)
	var bt: = create_tween()
	bt.tween_interval(0.2)
	bt.tween_property(bar, "modulate:a", 1.0, 0.22)


func set_preset(i: int) -> void:
	preset = i
	for k in chips.size():
		chips[k].selected = k == i
	var p: Dictionary = PRESETS[i]
	var W: = size.x
	var H: = size.y
	var z: float = p.zoom
	var f: Vector2 = p.focus
	# zoom about the focus, keep the frame filled
	var pos: = Vector2(W * 0.5, H * 0.5) - Vector2(W * f.x, H * f.y) * z
	pos.x = clampf(pos.x, W - W * z, 0.0)
	pos.y = clampf(pos.y, H - H * z, 0.0)
	stage.pivot_offset = Vector2.ZERO
	var t: = create_tween()
	t.tween_property(stage, "scale", Vector2(z, z), 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(stage, "position", pos, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func next_preset() -> void:
	set_preset((preset + 1) % PRESETS.size())


func shoot() -> String:
	if _busy:
		return ""
	_busy = true
	bar.visible = false
	var mark: = V10SalonUI.label("Tile Waifu · ИИ-арт", 18, Color(V10SalonUI.PAPER_100, 0.6), "body", 700, 0.5)
	mark.position = Vector2(size.x - V10SalonUI.text_w("Tile Waifu · ИИ-арт", 18) - 24, size.y - 44)
	add_child(mark)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	mark.queue_free()
	bar.visible = true
	V10SalonUI.sound("salon_shutter", 1.3, -4.5)  # file peak −2 dBFS → ≤ −6 dBFS played (UX З-4)
	V10SalonUI.haptic("flip")
	_flash()
	var path: = _save(img)
	last_path = path
	_busy = false
	shot.emit(path)
	return path


func _flash() -> void:
	# a vignette pulse in her accent colour instead of a white flash
	var acc: Color = V10SalonData.zone(zid).get("accent", V10SalonUI.ROSE_300)
	var v: = ColorRect.new()
	v.size = size
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm: = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = "shader_type canvas_item; uniform vec4 c : source_color; uniform float a = 0.0; void fragment(){ float d = length(UV - 0.5) * 1.41; COLOR = vec4(c.rgb, a * smoothstep(0.35, 1.0, d)); }"
	sm.shader = sh
	sm.set_shader_parameter("c", acc)
	v.material = sm
	add_child(v)
	var t: = create_tween()
	t.tween_method(func(x): sm.set_shader_parameter("a", x), 0.0, 0.85, 0.08)
	t.tween_method(func(x): sm.set_shader_parameter("a", x), 0.85, 0.0, 0.35)
	t.tween_callback(v.queue_free)


func _save(img: Image) -> String:
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute("user://photos")
	var s: = V10Salon.st()
	var n: = (s.photos as Array).size() + 1
	var path: = "user://photos/salon_%s_%03d.png" % [zid, n]
	var err: = img.save_png(path)
	if err != OK:
		push_warning("V10SalonPhoto: save failed %s" % error_string(err))
		return ""
	(s.photos as Array).append({"path": path, "zone": zid, "preset": PRESETS[preset].name})
	V10Salon._save()
	return path


func close() -> void:
	ui.visible = true
	var t: = create_tween()
	t.tween_property(stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(stage, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ui, "modulate:a", 1.0, 0.25)
	for nm in ["FloorShade", "TopShade"]:
		var fs: = host.get_node_or_null(nm)
		if fs:
			t.parallel().tween_property(fs, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)
