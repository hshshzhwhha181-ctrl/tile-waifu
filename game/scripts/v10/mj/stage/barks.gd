class_name V10MjBarks
extends Control

# V10MjBarks — what she says during a match: the line in her hand (Caveat 30, written with a pen in 0.4 s, held
# 4 s, gone in 0.3 s, no box — UX §6.3) at her shoulder, outside the sacred zone, and her voice (−14 LUFS files,
# the music bus ducked −8 dB under it through Sfx.duck, UX §7.4). Lines: V10MjStageLines (5 founders ×
# 8 match events × 3 + 8 table calls).
#
#   barks.setup(hero, budget, opts)        opts: voice (bool), quiet (bool: no text, no voice), fx
#   barks.say(event, place: Rect2, finish = false) -> Dictionary   {} when the budget said no, else
#        {line, text, voice: bool, n}. The budget decides (V10MjBudget: voice ≤ 1 / 20 s, a line ≤ 1 / 60 s).
#        A spoken line and its subtitle go together; when the voice is off, the subtitle obeys the same budget.
#   barks.place_rect -> where the text is (screen px), for the sacred-zone audit
#   static V10MjBarks.pick(hero, event, rng, free: Callable) -> int   variant index for other lanes (table AI)
# Stats: said (count), voiced (count).

const WRITE_T: = 0.4
const HOLD_T: = 4.0
const OUT_T: = 0.3
const FONT_SIZE: = 30
const FONT_CYR: = "res://assets/v10/mj/stage/fonts/caveat-cyrillic-600-normal.woff2"
const FONT_LAT: = "res://assets/v10/mj/stage/fonts/caveat-latin-600-normal.woff2"
const VOICE_BUS: = "Voice"
const DUCK_DB: = -8.0

var hero_id: = "mc"
var budget: V10MjBudget
var voice_on: = true
var quiet: = false
var fx: = "full"
var label: Label
var player: AudioStreamPlayer
var rng: = RandomNumberGenerator.new()
var place_rect: = Rect2()
var said: = 0
var voiced: = 0
var last_text: = ""
var _tw: Tween
var _last_n: = {}
static var _font: Font


func setup(hero: String, b: V10MjBudget, opts: = {}) -> V10MjBarks:
	hero_id = hero
	budget = b
	voice_on = bool(opts.get("voice", true))
	quiet = bool(opts.get("quiet", false))
	fx = String(opts.get("fx", "full"))
	rng.seed = int(opts.get("seed", 0)) if int(opts.get("seed", 0)) != 0 else int(Time.get_ticks_usec())
	name = "Barks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.name = "BarkLine"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", V10MjStageData.TOK.paper100)
	# soft shadow instead of a bubble (UX §6.3: «Voice 30 с мягкой тенью у плеча»)
	label.add_theme_color_override("font_shadow_color", Color(0.07, 0.05, 0.08, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	add_child(label)
	player = AudioStreamPlayer.new()
	player.name = "Voice"
	player.bus = VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) >= 0 else "Master"
	add_child(player)
	return self


static func font() -> Font:
	if _font == null:
		var f: = FontFile.new()
		if ResourceLoader.exists(FONT_CYR):
			var cyr: FontFile = load(FONT_CYR)
			var lat: FontFile = load(FONT_LAT) if ResourceLoader.exists(FONT_LAT) else null
			if lat:
				cyr = cyr.duplicate()
				cyr.fallbacks = [lat]
			_font = cyr
		else:
			_font = ThemeDB.fallback_font
	return _font


# variant for an event: not the one she said last for it, and free of the 60 s rule when possible
static func pick(hero: String, ev: String, r: RandomNumberGenerator, free: Callable, last: = -1) -> int:
	var vs: = V10MjStageLines.variants(hero, ev)
	if vs.is_empty():
		return -1
	var order: = range(vs.size())
	for i in range(order.size() - 1, 0, -1):
		var j: = r.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var fallback: = -1
	for i in order:
		var id: = "%s_%s_%d" % [V10MjStageLines.hero_key(hero), ev, i + 1]
		if free.is_valid() and not bool(free.call(id)):
			continue
		if i == last and vs.size() > 1:
			fallback = i
			continue
		return i
	return fallback


func say(ev: String, place: Rect2, finish: = false) -> Dictionary:
	if quiet:
		return {}
	if not budget.voice_free(finish):
		return {}
	var n: = pick(hero_id, ev, rng, budget.line_free, int(_last_n.get(ev, -1)))
	if n < 0:
		return {}
	var line_id: = "%s_%s_%d" % [V10MjStageLines.hero_key(hero_id), ev, n + 1]
	if not budget.take_voice(line_id, finish):
		return {}
	_last_n[ev] = n
	var v: Array = V10MjStageLines.variants(hero_id, ev)[n]
	var text: = String(v[0])
	var spoke: = false
	if voice_on:
		spoke = _play_voice(V10MjStageLines.voice_path(hero_id, ev, n + 1))
	_show_text(text, place)
	said += 1
	if spoke:
		voiced += 1
	return {"line": line_id, "text": text, "voice": spoke, "n": n}


func _play_voice(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var tree: = get_tree()
	var g = tree.root.get_node_or_null("G") if tree else null
	if g and g.get("S") is Dictionary and not bool((g.S as Dictionary).get("voice", true)):
		return false
	var st: AudioStream = load(path)
	if st == null:
		return false
	player.stream = st
	player.volume_db = 0.0
	player.play()
	var dur: = st.get_length()
	var sfx = tree.root.get_node_or_null("Sfx") if tree else null
	if sfx and sfx.has_method("duck"):
		sfx.duck(DUCK_DB, dur + 0.3)
	return true


func show_line(text: String, place: Rect2) -> void:
	_show_text(text, place)


func _show_text(text: String, place: Rect2) -> void:
	if place.size.x < 120.0 or place.size.y < 36.0:
		place_rect = Rect2()
		return
	place_rect = place
	last_text = text
	label.text = text
	label.position = place.position - global_position
	label.size = place.size
	label.visible = true
	label.modulate.a = 1.0
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	if fx == "min":
		label.visible_ratio = 1.0
		label.modulate.a = 0.0
		V10MjStageFx.step(_tw, label, "modulate:a", 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	else:
		# the pen: letters appear left to right in 0.4 s
		label.visible_ratio = 0.0
		V10MjStageFx.step(_tw, label, "visible_ratio", 1.0, WRITE_T, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	_tw.tween_interval(HOLD_T)
	V10MjStageFx.step(_tw, label, "modulate:a", 0.0, OUT_T, Tween.TRANS_SINE, Tween.EASE_IN)
	_tw.tween_callback(func():
		label.visible = false
		place_rect = Rect2())


func hide_now() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	label.visible = false
	place_rect = Rect2()


func is_showing() -> bool:
	return label.visible
