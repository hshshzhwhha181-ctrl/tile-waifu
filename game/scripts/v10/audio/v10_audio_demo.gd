extends Control

# Audition board for the 0.10 audio lane: one button per screen (crossfades like the real tabs), the match
# controls (tension slider, fever, stings), every SFX id, heroine motifs and the new barks.
#   /opt/tw-tools/godot --path game res://scripts/v10/audio/v10_audio_demo.tscn
# User args (after --):  --tour=1  auto-tour every screen for 6 s each, then the match states and SFX (for a
#                                  --write-movie capture), then quit.

const BG: = Color("1b1420")
const INK: = Color("f6e9f0")
const ACC: = Color("e7a6c4")

var _state: Label
var _tension: HSlider


func _ready() -> void :
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sc: = ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 16
	sc.offset_right = -16
	sc.offset_top = 16
	sc.offset_bottom = -16
	add_child(sc)
	var col: = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	sc.add_child(col)
	_title(col, "Tile Waifu 0.10 — музыка и звуки")
	_state = Label.new()
	_state.add_theme_color_override("font_color", ACC)
	col.add_child(_state)
	_title(col, "Экраны (кроссфейд 0,8 с)")
	var screens: = ["home", "path", "match", "summon", "shop", "salon", "phone", "pagoda", "duels"]
	_grid(col, screens, func(s): V10Music.play_screen(s))
	_title(col, "Партия")
	_tension = HSlider.new()
	_tension.min_value = 0.0
	_tension.max_value = 1.0
	_tension.step = 0.01
	_tension.custom_minimum_size = Vector2(0, 48)
	_tension.value_changed.connect(func(v): V10Music.set_tension(v))
	col.add_child(_tension)
	_grid(col, ["fever on", "fever off", "victory", "defeat", "duck 1.4 s"], func(s):
		match s:
			"fever on":
				V10SfxBank.play("fever_ignite")
				V10Music.fever(true)
			"fever off":
				V10SfxBank.play("fever_end")
				V10Music.fever(false)
			"victory", "defeat":
				V10Music.sting(s)
			"duck 1.4 s":
				var sfx: = get_node_or_null("/root/Sfx")
				if sfx != null:
					sfx.duck(-8.0, 1.4)
	)
	_title(col, "Лейтмотивы героинь")
	_grid(col, V10Music.HEROES, func(h): V10Music.motif(h))
	_title(col, "Голос (новые реплики)")
	var vb: = []
	for h in V10SfxBank.HEROES:
		for k in V10SfxBank.VOICE_KINDS:
			vb.append("%s %s" % [h, k])
	_grid(col, vb, func(s):
		var p: PackedStringArray = s.split(" ")
		_state.text = V10SfxBank.voice(p[0], p[1])
	)
	_title(col, "SFX")
	var ids: = V10SfxBank.ids()
	ids.sort()
	_grid(col, ids, func(id): V10SfxBank.play(id))
	_grid(col, ["combo x8"], func(_s): _combo())
	V10Music.play_screen("home")
	if "--tour=1" in OS.get_cmdline_user_args():
		_tour()


func _process(_dt: float) -> void :
	if _state != null and V10Music._inst != null and V10Music._inst.is_inside_tree():
		var st: Dictionary = V10Music._inst.debug_state()
		_state.tooltip_text = str(st)
		if not _state.text.begins_with("«"):
			_state.text = "играет: %s   фивер: %s" % [st["cur"], "да" if st["fever"] else "нет"]


func _title(parent: Control, t: String) -> void :
	var l: = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)


func _grid(parent: Control, items: Array, cb: Callable) -> void :
	var g: = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	for it in items:
		var b: = Button.new()
		b.text = String(it)
		b.custom_minimum_size = Vector2(216, 64)
		b.pressed.connect(func():
			V10SfxBank.play("btn_press")
			cb.call(it)
		)
		b.mouse_entered.connect(func(): V10SfxBank.play("btn_hover"))
		g.add_child(b)


func _combo() -> void :
	for n in range(1, 9):
		V10SfxBank.combo(n)
		await get_tree().create_timer(0.22).timeout


func _tour() -> void :
	for s in ["home", "path", "match", "summon", "shop", "salon", "phone", "pagoda", "duels"]:
		V10Music.play_screen(s)
		V10SfxBank.play("tab_switch")
		await get_tree().create_timer(6.0).timeout
	V10Music.play_screen("match")
	for t in [0.2, 0.8]:
		V10Music.set_tension(t)
		await get_tree().create_timer(5.0).timeout
	V10SfxBank.play("fever_ignite")
	V10Music.fever(true)
	await _combo()
	await get_tree().create_timer(4.0).timeout
	V10Music.fever(false)
	V10Music.sting("victory")
	await get_tree().create_timer(9.0).timeout
	get_tree().quit()
