class_name V10StreakChip
extends Control

# The tea bowl by the partner's portrait (Р3): day count, 0–2 leaves resting on the rim, live steam.
#   setup(V10Streak.view())        draw the state (warm / waiting / cold / empty)
#   play_win(from, to)             win window: the bowl fills with steam 0.6 s, the number rolls, a quiet bell
#   play_forgiven()                a leaf glides down like a pendulum (1.2 s) onto the bowl; one leaf icon leaves
#   play_cool()                    steam dies, the glaze frosts over (blue)
#   play_warmed(n)                 a burst of steam, colour returns, number rolls
# Emits `tapped` (open V10StreakSheet). Size 150×184.

signal tapped

const W: = 150.0
const H: = 184.0
const COLD_TINT: = Color(0.68, 0.8, 0.98)

var _bowl: TextureRect
var _steam: CPUParticles2D
var _num: Label
var _cap: Label
var _leaves: Array = []
var _frost: CPUParticles2D
var _view: = {}
var _n: = 0


func _init() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var glow: = TextureRect.new()
	glow.texture = V10RitUI.soft_dot()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(170, 120)
	glow.position = Vector2(-10, 30)
	glow.modulate = Color(V10RitUI.GOLD500, 0.18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.name = "glow"
	add_child(glow)
	_steam = V10RitUI.steam(self, Vector2(W * 0.5, 44), 54, 16, Color(1, 0.98, 0.94, 0.62))
	_bowl = V10RitUI.tex(V10RitUI.ART + "bowl.webp", Rect2(17, 28, 116, 108))
	add_child(_bowl)
	_leaves = []
	for i in 2:
		var lf: = V10RitUI.tex(V10RitUI.ART + "leaf.webp", Rect2(98 + i * 18, 18 + i * 6, 34, 36))
		lf.rotation = deg_to_rad(-30 + i * 24)
		add_child(lf)
		_leaves.append(lf)
	_num = V10RitUI.label("0", 40, V10RitUI.GOLD300, "num")
	_num.position = Vector2(0, 124)
	_num.size = Vector2(W, 44)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_num)
	_cap = V10RitUI.label("СЕРИЯ", 15, V10RitUI.GOLD500, "over")
	_cap.position = Vector2(0, 164)
	_cap.size = Vector2(W, 20)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cap)


func setup(view: Dictionary) -> void:
	_view = view
	_n = int(view.get("n", 0))
	_num.text = str(_n)
	_set_leaves(int(view.get("leaves", 0)))
	_apply_state(str(view.get("state", "warm")), false)


func _set_leaves(n: int) -> void:
	for i in _leaves.size():
		(_leaves[i] as CanvasItem).visible = i < n
		(_leaves[i] as CanvasItem).modulate.a = 1.0


func _apply_state(stt: String, animate: bool) -> void:
	var cold: = stt == "cold"
	var dim: = stt == "empty"
	var tint: Color = COLD_TINT if cold else (Color(0.8, 0.78, 0.76) if dim else Color.WHITE)
	_steam.emitting = not cold and not dim and V9Feel.can_fx()
	_num.label_settings.font_color = V10RitUI.FROST if cold else (V10RitUI.PAPER500 if dim else V10RitUI.GOLD300)
	var glow: CanvasItem = get_node_or_null("glow")
	if animate:
		var t: = create_tween().set_parallel()
		t.tween_property(_bowl, "modulate", tint, 0.8)
		if glow:
			t.tween_property(glow, "modulate", Color(V10RitUI.FROST, 0.22) if cold else Color(V10RitUI.GOLD500, 0.18), 0.8)
	else:
		_bowl.modulate = tint
		if glow:
			glow.modulate = Color(V10RitUI.FROST, 0.22) if cold else Color(V10RitUI.GOLD500, 0.18)
	if cold and _frost == null and V9Feel.can_fx():
		_frost = V10RitUI.steam(self, Vector2(W * 0.5, 80), 90, 8, Color(0.85, 0.93, 1.0, 0.55))
		_frost.gravity = Vector2(0, 4)
		_frost.initial_velocity_min = 2
		_frost.initial_velocity_max = 8
		_frost.scale_amount_min = 0.08
		_frost.scale_amount_max = 0.16
		_frost.lifetime = 1.6
	elif not cold and _frost:
		_frost.queue_free()
		_frost = null


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		V9Feel.press(self, "pop", "button")
		tapped.emit()
		accept_event()


func play_win(from: int, to: int) -> void:
	_apply_state("warm", true)
	V10RitUI.sfx("tea_pour", "sparkle", 1.0, -4.0)
	var old_amt: = _steam.amount
	_steam.initial_velocity_max = 70.0
	_steam.scale_amount_max = 1.3
	var t: = create_tween()
	t.tween_property(_bowl, "scale", Vector2(1.08, 0.95), 0.12).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_bowl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_steam.initial_velocity_max = 38.0
		_steam.scale_amount_max = 0.9)
	var t2: = create_tween()
	t2.tween_interval(0.35)
	t2.tween_callback(func():
		V10RitUI.roll(_num, from, to, 0.6)
		_pop_num())
	t2.tween_interval(0.62)
	t2.tween_callback(func(): V10RitUI.sfx("bell", "sparkle", 1.0, -6.0))
	_n = to


func _pop_num() -> void:
	_num.pivot_offset = _num.size * 0.5
	var t: = _num.create_tween()
	t.tween_property(_num, "scale", Vector2.ONE * 1.25, 0.12)
	t.tween_property(_num, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_forgiven(leaves_after: int) -> float:
	var leaf: = V10RitUI.tex(V10RitUI.ART + "leaf.webp", Rect2(0, 0, 46, 50))
	add_child(leaf)
	var start: = Vector2(-90, -230)
	var end: = Vector2(W * 0.5 - 23, 46)
	leaf.position = start
	leaf.rotation = deg_to_rad(-40)
	var dur: = 1.2 if V9Feel.can_fx() else 0.3
	var t: = create_tween()
	t.tween_method(func(k: float):
		# pendulum glide: sideways swing that narrows as it lands, rotation follows the swing
		var sw: = sin(k * PI * 3.0) * (1.0 - k) * 70.0
		leaf.position = start.lerp(end, k * k * (3.0 - 2.0 * k)) + Vector2(sw, 0)
		leaf.rotation = deg_to_rad(cos(k * PI * 3.0) * 28.0 * (1.0 - k) - 10.0), 0.0, 1.0, dur)
	t.tween_callback(func():
		V10RitUI.sfx("leaf_land", "flip", 1.0, -2.0)
		V9Feel.haptic("button")
		_pop_num())
	t.tween_property(leaf, "scale", Vector2(1.15, 0.9), 0.08)
	t.tween_property(leaf, "scale", Vector2.ONE, 0.2)
	t.tween_property(leaf, "modulate:a", 0.0, 0.5).set_delay(0.3)
	t.tween_callback(leaf.queue_free)
	# the spent leaf icon on the rim fades out with the landing
	var t2: = create_tween()
	t2.tween_interval(dur)
	for i in _leaves.size():
		if i >= leaves_after and (_leaves[i] as CanvasItem).visible:
			t2.parallel().tween_property(_leaves[i], "modulate:a", 0.0, 0.4)
	return dur + 0.8


func play_cool() -> void:
	_steam.emitting = false
	_apply_state("cold", true)
	V10RitUI.sfx("steam", "whoosh", 0.7, -10.0)


func play_warmed(n: int) -> void:
	var burst: = V10RitUI.steam(self, Vector2(W * 0.5, 50), 80, 24, Color(1, 1, 1, 0.75))
	burst.one_shot = true
	burst.explosiveness = 0.8
	burst.preprocess = 0.0
	burst.initial_velocity_min = 80
	burst.initial_velocity_max = 160
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	_apply_state("warm", true)
	V10RitUI.sfx("steam", "sparkle", 1.0, -2.0)
	V10RitUI.roll(_num, _n, n, 0.6)
	_n = n
	_pop_num()
	var t: = create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func(): V10RitUI.sfx("bell", "sparkle", 1.1, -6.0))
