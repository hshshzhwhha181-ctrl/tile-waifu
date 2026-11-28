class_name TWSkin
extends RefCounted

# TWSkin (P28 / WP9b): a skin is a SET OF TOKEN OVERRIDES, nothing else. It replaces V10HudSkin's per-widget recolouring:
# every TW widget reads its colours through TWSkin.c("NAME") (NAME = a TWTokens colour constant), so a skin only has to
# say {"PLATE_RIM": Color(...), "ROSE_500": Color(...)}. apply()/reset() tell every live widget (group "tw_skinned") to redraw.
#
#   TWSkin.apply("midnight", {"PLATE_RIM": some_color})   # partial overrides; unknown names are ignored and counted
#   TWSkin.c("PLATE_RIM")                                # override, else the TWTokens value
#   TWSkin.reset()                                       # back to the base style

const GROUP: = "tw_skinned"

static var current: = ""
static var revision: = 0
static var rejected: = 0
static var _over: Dictionary = {}
static var _base: Dictionary = {}


static func _consts() -> Dictionary:
	if _base.is_empty():
		var all: Dictionary = (TWTokens.new().get_script() as Script).get_script_constant_map()
		for k in all:
			if all[k] is Color:
				_base[k] = all[k]
	return _base


static func has_token(token: String) -> bool:
	return _consts().has(token)


static func c(token: String) -> Color:
	if _over.has(token):
		return _over[token]
	var b: Dictionary = _consts()
	return b[token] if b.has(token) else Color.MAGENTA


static func a(token: String) -> float:
	# alpha tokens are floats (HAIR_A, LACQUER_A ...): not overridable, read straight from TWTokens
	return float(TWTokens.new().get_script().get_script_constant_map().get(token, 1.0))


static func apply(skin_id: String, overrides: Dictionary) -> int:
	_over.clear()
	rejected = 0
	for k in overrides:
		if has_token(str(k)) and overrides[k] is Color:
			_over[str(k)] = overrides[k]
		else:
			rejected += 1
	current = skin_id
	_changed()
	return _over.size()


static func reset() -> void:
	_over.clear()
	current = ""
	rejected = 0
	_changed()


static func overrides() -> Dictionary:
	return _over.duplicate()


static func _changed() -> void:
	revision += 1
	var ml: = Engine.get_main_loop()
	if ml is SceneTree:
		(ml as SceneTree).call_group(GROUP, "_skin_changed")
