class_name V10Hud2Util
extends RefCounted

# Small glue for hud2: optional sibling-branch classes are looked up by name at runtime, so this branch works
# with or without them (V10Layout from v10-responsive, V10Music / V10SfxBank from v10-audio).

static var sim_insets: = {}  # tests / demo: {"top": 48, "bottom": 24}; empty -> real insets
static var fx_override: = ""  # tests / demo: "full" | "mid" | "min"
static var _classes: = {}


static func opt_class(n: String) -> Script:
	if _classes.has(n):
		return _classes[n]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if str(c["class"]) == n:
			s = load(str(c["path"]))
			break
	_classes[n] = s
	return s


static func safe_insets(vs: Vector2) -> Dictionary:
	var out: = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not sim_insets.is_empty():
		for k in sim_insets:
			out[k] = float(sim_insets[k])
		return out
	var lay: = opt_class("V10Layout")
	if lay:
		var d: Dictionary = lay.call("safe_insets", vs)
		for k in out:
			out[k] = float(d.get(k, 0.0))
	return out


static func fx_level() -> String:
	if fx_override != "":
		return fx_override
	var ml: = Engine.get_main_loop()
	if ml is SceneTree:
		var g: = (ml as SceneTree).root.get_node_or_null("G")
		if g and g.has_method("fx_level"):
			return str(g.fx_level())
	return "full"


static func sfx(id: String) -> void:
	# V10SfxBank when v10-audio is merged, else the 0.7 Sfx autoload's nearest sound, else silence
	var bank: = opt_class("V10SfxBank")
	if bank:
		bank.call("play", id, {})
		return
	var ml: = Engine.get_main_loop()
	if ml is SceneTree:
		var s: = (ml as SceneTree).root.get_node_or_null("Sfx")
		if s and s.has_method("play"):
			var legacy: = {"cutin_whoosh": "whoosh", "combo_finale": "reveal_sr", "heart": "sparkle"}
			var name: = str(legacy.get(id, id))
			if ResourceLoader.exists("res://assets/sfx/%s.wav" % name):
				s.call("play", name)


static func music(method: String, args: = []) -> void:
	var m: = opt_class("V10Music")
	if m:
		m.callv(method, args)
