class_name V10HudFx
extends RefCounted

# V10HudFx — shared helpers of the premium HUD FX lane (branch v10-hudfx, docs: scripts/v10/hudfx/README.md).
# Every hudfx module goes through these gates, so «полные / умеренные / минимум», «Без тряски и вспышек»,
# the juice particle budget and the one-sheen rule are enforced in one place.
#
#   V10HudFx.level() -> "full" | "mid" | "min"        (V10Hud2Util.fx_override → G.fx_level() → "full")
#   V10HudFx.full() / mid_or_full() / is_min()
#   V10HudFx.calm() -> bool                            (a11y «Без тряски и вспышек»: V10Juice.calm())
#   V10HudFx.n(count) -> int                           (particle count for the level: full ×1, mid ×0.55, min 0)
#   V10HudFx.accent(hero) / glow(hero) / deep(hero) -> Color, element(hero) -> String
#   V10HudFx.tex(name) -> Texture2D                    (res://assets/v10/hudfx/<name>.png, cached; null if missing)
#   V10HudFx.shader(name) -> Shader, mat(name, params) (res://shaders/v10/hudfx/<name>.gdshader)
#   V10HudFx.sound(name, pitch, db)                    (scripts/v10/hudfx/sfx/<name>.ogg → V10Juice sound → silence)
#   V10HudFx.note(step, db)                            (pentatonic pluck, step 0.. rising; reward cascade / stars)
#   V10HudFx.layer() -> CanvasLayer                    (the juice fx layer, CanvasLayer 70)
#   V10HudFx.tw(node) -> Tween                         (a tween bound to node, ALWAYS process mode: runs while paused)
#   V10HudFx.warm()                                    (pre-compile every hudfx shader + load textures/sounds)

const ASSETS: = "res://assets/v10/hudfx/"
const SH: = "res://shaders/v10/hudfx/"
const SFX: = "res://scripts/v10/hudfx/sfx/%s.ogg"

# major pentatonic (C D E G A) over two octaves, as pitch_scale relative to the base pluck (C)
const PENTA: = [1.0, 1.122462, 1.259921, 1.498307, 1.681793, 2.0, 2.244924, 2.519842, 2.996614, 3.363586]

# HUD_V2 §6 motion constants (seconds) used across modules
const T_IN: = 0.24
const T_STEP: = 0.04
const T_OUT: = 0.16
const T_MIN: = 0.12  # fx_level = min: every motion becomes a 120 ms fade
const T_SILK: = 0.22
const T_LACQUER: = 0.60
const T_WIND: = 0.60

# warm light only: additive layers never exceed these (HEROINES §2, juice rule 1)
const LIGHT_ALPHA_MAX: = 0.85
const LIGHT_VALUE_MAX: = 0.8

static var _tex: = {}
static var _shaders: = {}
static var _streams: = {}
static var shaders_list: = []  # filled by modules via register_shader(); warm() draws each once


static func level() -> String:
	return V10Hud2Util.fx_level()


static func full() -> bool:
	return level() == "full"


static func mid_or_full() -> bool:
	return level() != "min"


static func is_min() -> bool:
	return level() == "min"


static func calm() -> bool:
	return V10Juice.calm()


static func n(count: int) -> int:
	match level():
		"full":
			return count
		"mid":
			return int(ceil(count * 0.55))
	return 0


static func accent(hero: String) -> Color:
	return V10DS.hero(hero).accent


static func glow(hero: String) -> Color:
	return V10DS.hero(hero).glow


static func deep(hero: String) -> Color:
	return V10DS.hero(hero).deep


static func element(hero: String) -> String:
	return str(V10DS.hero(hero).element)


# warm-light clamp: keeps a colour at ≤ LIGHT_VALUE_MAX value (never white)
static func warm_light(c: Color, a: = 1.0) -> Color:
	var out: = Color.from_hsv(c.h, c.s, minf(c.v, LIGHT_VALUE_MAX), minf(a, LIGHT_ALPHA_MAX))
	return out


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var p: = ASSETS + name + ".png"
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex[name] = t
	return t


static func register_shader(name: String) -> void:
	if not shaders_list.has(name):
		shaders_list.append(name)


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		var p: = SH + name + ".gdshader"
		_shaders[name] = load(p) if ResourceLoader.exists(p) else null
	return _shaders[name]


static func mat(name: String, params: = {}) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = shader(name)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var p: = SFX % name
		_streams[name] = load(p) if ResourceLoader.exists(p) else null
	return _streams[name]


static func sound(name: String, pitch: = 1.0, db: = 0.0) -> void:
	# hudfx sounds ride the juice player pool (SFX bus, respects S.sound); missing file → juice name → fallback
	var st: = _stream(name)
	if st == null:
		V10Juice.sound(name, pitch, db)
		return
	# juice keeps the pool; we hand it our stream through its cache under a namespaced key
	var key: = "hudfx/" + name
	if not V10Juice._streams.has(key):
		V10Juice._streams[key] = st
	V10Juice.sound(key, pitch, db)


static func note(step: int, db: = -6.0) -> void:
	var i: = clampi(step, 0, PENTA.size() - 1)
	sound("pluck", PENTA[i], db)


static func layer() -> CanvasLayer:
	return V10Juice.layer("fx")


static func tw(node: Node) -> Tween:
	var t: = node.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


static func warm() -> void:
	var l: = layer()
	for name in shaders_list:
		var sh: = shader(name)
		if sh == null:
			continue
		var c: = ColorRect.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size = Vector2(2, 2)
		c.modulate = Color(1, 1, 1, 0.01)
		c.material = mat(name)
		l.add_child.call_deferred(c)
		V10Juice.tree().create_timer(0.25, true, false, true).timeout.connect(c.queue_free)
