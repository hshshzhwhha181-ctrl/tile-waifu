class_name V10RigCatalog
extends RefCounted

# V10RigCatalog — unified catalog and stage helper for V10 living heroine rigs (spec 0.10 D4, DATA.md, LEGWEAR §4-5).
# Reads every `res://assets/v10/rig/<rig>/gestures.json` once, resolves `(hero, outfit)` to a rig entry, instantiates
# at most ONE live rig per container, applies `fit`, `motion` (honouring `fx_level` & `a11y_calm`), `up_amp` (0.6 in
# base builds, 1.0 when 18+ bold is enabled), attaches `V10RigSheen` when present, and filters autonomous gestures by
# affinity, outfit allow/deny, framing (`alt_rect` disables `legs:true` + sheen), and age gate (`bold` never on tap,
# only idle at aff >= 6 when 18+).

const RIG_ROOT: = "res://assets/v10/rig"
const KNOWN_RIGS: = ["mc_gown", "rin_officer", "hana_base"]

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_cache.clear()
	_loaded = false
	_ensure()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dirs: Array[String] = []
	for k in KNOWN_RIGS:
		dirs.append(k)
	var da: = DirAccess.open(RIG_ROOT)
	if da != null:
		da.list_dir_begin()
		var d: = da.get_next()
		while d != "":
			if da.current_is_dir() and not d.begins_with(".") and not dirs.has(d):
				dirs.append(d)
			d = da.get_next()
		da.list_dir_end()
	for rname in dirs:
		var gp: = "%s/%s/gestures.json" % [RIG_ROOT, rname]
		if not FileAccess.file_exists(gp):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(gp))
		if parsed is Dictionary:
			var entry: Dictionary = parsed
			entry["_dir"] = "%s/%s" % [RIG_ROOT, rname]
			entry["_gestures_path"] = gp
			_cache[String(entry.get("rig", rname))] = entry


static func all() -> Dictionary:
	_ensure()
	return _cache


static func ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k in _cache:
		out.append(String(k))
	return out


static func get_rig(rig_id: String) -> Dictionary:
	_ensure()
	return _cache.get(rig_id, {})


static func find_for(hero: String, outfit: String = "") -> Dictionary:
	_ensure()
	var eff_outfit: = outfit
	if eff_outfit == "":
		eff_outfit = _base_outfit_of(hero)
	for k in _cache:
		var e: Dictionary = _cache[k]
		if String(e.get("hero", "")) != hero:
			continue
		var outs: Array = e.get("outfits", [])
		if eff_outfit != "" and outs.has(eff_outfit):
			return e
	# Fallback: base rig of this heroine when outfit is empty / default
	if outfit == "":
		for k2 in _cache:
			var e2: Dictionary = _cache[k2]
			if String(e2.get("hero", "")) == hero:
				return e2
	return {}


static func has_rig(hero: String, outfit: String = "") -> bool:
	var e: = find_for(hero, outfit)
	return not e.is_empty() and ResourceLoader.exists(String(e.get("scene", "")))


static func _base_outfit_of(hero: String) -> String:
	match hero:
		"mc":
			return "o_base"
		"rin":
			return "r_base"
		"hana":
			return "h_base"
		"yue":
			return "y_base"
		"nova":
			return "n_base"
	return hero.substr(0, 2) + "_base"


static func bold_ok() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G") != null:
		if bool(G.S.get("sfw_mode", false)):
			return false
	if ClassDB.class_exists("V10Age") or ResourceLoader.exists("res://scripts/v10/auth/age_gate.gd"):
		var ag = load("res://scripts/v10/auth/age_gate.gd")
		if ag != null and ag.has_method("bold_ok"):
			return bool(ag.call("bold_ok"))
	return false


static func calm_mode() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G") != null:
		if bool(G.S.get("a11y_calm", false)):
			return true
		if G.has_method("fx_level") and String(G.fx_level()) == "min":
			return true
	return false


static func allowed_auto_gestures(entry: Dictionary, outfit: String = "", aff: int = 0, alt_rect: bool = false, is_bold_ok: bool = false) -> Array[String]:
	var out: Array[String] = []
	var eff_out: = outfit if outfit != "" else _base_outfit_of(String(entry.get("hero", "")))
	for g in entry.get("gestures", []):
		if not (g is Dictionary):
			continue
		var gd: Dictionary = g
		if gd.has("status") and String(gd.get("status", "")).begins_with("n/a"):
			continue
		var u: = String(gd.get("use", ""))
		if not (u in ["auto", "both"]):
			continue
		if String(gd.get("rig", "R")) == "V":
			continue
		var tier: = String(gd.get("tier", "base"))
		if tier == "bold" and (not is_bold_ok or aff < 6):
			continue
		if int(gd.get("aff_min", 0)) > aff:
			continue
		if alt_rect and bool(gd.get("legs", false)):
			continue
		var allow: Array = gd.get("outfits_allow", [])
		var deny: Array = gd.get("outfits_deny", [])
		if not allow.is_empty() and eff_out != "" and not allow.has(eff_out):
			continue
		if deny.has(eff_out):
			continue
		var nm: = String(gd.get("name", ""))
		if nm != "" and not out.has(nm):
			out.append(nm)
	return out


# Instantiates the matching V10LiveRig into `parent` (enforcing <= 1 V10LiveRig child in `parent`), fits it to `rect`,
# configures motion/up_amp/sheen, and returns the rig (or null if unavailable).
static func mount(parent: Node, hero: String, outfit: String = "", rect: Rect2 = Rect2(0, 0, 720, 1280), opts: Dictionary = {}) -> V10LiveRig:
	if parent == null:
		return null
	var e: = find_for(hero, outfit)
	if e.is_empty():
		return null
	var scene_path: = String(e.get("scene", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return null
	for c in parent.get_children():
		if c is V10LiveRig:
			c.queue_free()
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return null
	var rig: V10LiveRig = ps.instantiate() as V10LiveRig
	if rig == null:
		return null
	rig.show_background = bool(opts.get("show_background", false))
	rig.handle_input = bool(opts.get("handle_input", true))
	var mot_cfg: Dictionary = e.get("motion", {})
	var profile_mode: = bool(opts.get("profile", false))
	var calm: = bool(opts.get("calm", calm_mode()))
	if calm:
		rig.motion = float(mot_cfg.get("fx_min", 0.5))
	elif profile_mode:
		rig.motion = float(mot_cfg.get("profile", 0.7))
	else:
		rig.motion = float(mot_cfg.get("default", 1.0))
	var b_ok: = bool(opts.get("bold_ok", bold_ok()))
	if "up_amp" in rig:
		rig.set("up_amp", 1.0 if b_ok else float(e.get("up_amp", 0.6)))
	fit_rig(rig, e, rect)
	parent.add_child(rig)
	var alt_rect: = bool(opts.get("alt_rect", false))
	var sh_cfg: Dictionary = (e.get("shaders", {}) as Dictionary).get("sheen", {})
	if not sh_cfg.is_empty() and ResourceLoader.exists("res://scripts/v10/rig/rig_sheen.gd"):
		var sh: V10RigSheen = V10RigSheen.attach(rig, sh_cfg)
		if sh != null:
			sh.enabled = not calm and not alt_rect
	return rig


static func fit_rig(rig: Node2D, entry: Dictionary, rect: Rect2) -> void:
	if rig == null:
		return
	var fit: Dictionary = entry.get("fit", {})
	var cx: float = float(fit.get("center_x", 700.0))
	var h_frac: float = float(fit.get("height", 0.705))
	var bottom_over: float = float(fit.get("bottom", 12.0))
	var art_h: = 1400.0
	var sc: float = (rect.size.y * h_frac) / art_h * 1.42
	rig.scale = Vector2.ONE * sc
	rig.position = Vector2(
		rect.position.x + rect.size.x * 0.5 - cx * sc,
		rect.position.y + rect.size.y + bottom_over - art_h * sc
	)
