extends Node

# Registry selftest (P07): V10Registry discovers every module through its game/core/**/module.gd manifest.
# Run:
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/core/registry_selftest.tscn
#   ... -- --registry_dump=1     prints a canonical JSON dump of the whole registry (ids in order, specs with
#                                Callables as "<fn>", depth graph, screens, ensure_all keys, wiring flags);
#                                tools/tw_test.py --registry-dump wraps it, the dump is what proves that a
#                                registry refactor changes nothing
# Prints: REGISTRY_SELFTEST <ok>/<total>

# the 43 modules of 0.12 in their historical initialisation order (registry_list.gd, before P07): they must all stay
# discovered, in this relative order; new modules may be added anywhere (one module.gd file, no edit here)
const LEGACY_IDS: = ["responsive", "economy", "meta", "hud2", "fonts", "profile", "look", "shop", "auth", "clarity", "tutorial", "juice", "levels", "path", "salon", "rituals", "chat", "phone", "gacha", "rig", "voice", "audio", "hudfx", "tower", "mj_stage", "mj_look", "mj_triples", "mj_riichi", "mj_sanma", "mj_koikoi", "mj_classic", "mj_connect", "mj_cube", "mj_garden", "mj_bridge", "palm", "duels", "challenge", "wave1", "adventure", "online", "events", "stamina"]

var ok: int = 0
var total: int = 0
var fails: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(msg)
		print("REGISTRY FAIL: ", msg)


func _norm(v):
	if v is Callable:
		return "<fn>"
	if v is Dictionary:
		var o: = {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		var a: = []
		for x in v:
			a.append(_norm(x))
		return a
	if v is Object:
		return "<obj>"
	return v


func _dump() -> void:
	var out: = {}
	out["ids"] = V10Registry.ids()
	var mods: = {}
	for id in V10Registry.ids():
		var m: Dictionary = V10Registry.get_module(id).duplicate()
		m.erase("order")
		m.erase("id")
		m.erase("_manifest")
		mods[id] = _norm(m)
	out["mods"] = mods
	out["selftests"] = _norm(V10Registry.selftests())
	out["depth"] = V10Registry.depth_graph()
	var sk: Array = V10Registry.screens().keys()
	sk.sort()
	out["screens"] = sk
	var S: = {}
	V10Registry.ensure_all(S)
	var ks: Array = S.keys()
	ks.sort()
	out["ensure_keys"] = ks
	out["wired"] = {
		"gclock": V10GClock.now_fn.is_valid(),
		"salon_grant": V10Salon.grant_cb.is_valid(),
		"salon_bond": V10Salon.bond_cb.is_valid(),
		"salon_letter": V10Salon.letter_cb.is_valid(),
		"salon_day": V10Salon.day_cb.is_valid(),
		"salon_level": V10Salon.level_cb.is_valid(),
		"salon_help": V10Salon.help_cb.is_valid(),
		"salon_season": V10Salon.season_cb.is_valid(),
	}
	var tray: Array = V10Tray.ids()
	tray.sort()
	out["tray_ids"] = tray
	var cos: = []
	for cdef in V10Pagoda.cos_defs():
		cos.append(V10ProfileCos.has(String(cdef.get("id", "")), ""))
	out["pagoda_cos_registered"] = cos
	print("REGISTRY_DUMP_BEGIN")
	print(JSON.stringify(out, "  ", true))
	print("REGISTRY_DUMP_END")


func _run() -> void:
	if "--registry_dump=1" in OS.get_cmdline_user_args():
		_dump()
		get_tree().quit(0)
		return
	var ids: Array = V10Registry.ids()
	check(ids.size() >= 43, "at least the 43 legacy modules (got %d)" % ids.size())
	var pos: = -1
	var in_order: = true
	for lid in LEGACY_IDS:
		var at: = ids.find(lid)
		check(at >= 0, "legacy module %s discovered" % lid)
		if at <= pos:
			in_order = false
		pos = at
	check(in_order, "legacy modules keep their historical initialisation order")
	var seen: = {}
	var dup: = false
	for id in ids:
		if seen.has(id):
			dup = true
		seen[id] = true
	check(not dup, "no duplicate module id")
	var prev: = -1
	var ordered: = true
	var order_missing: = false
	for id in ids:
		var m: Dictionary = V10Registry.get_module(id)
		check(String(m.get("id", "")) == String(id), "%s: spec.id equals the registered id" % id)
		if not m.has("order"):
			order_missing = true
			continue
		if int(m.order) <= prev:
			ordered = false
		prev = int(m.order)
		check(int(m.get("step", 0)) >= 1 and int(m.get("step", 0)) <= 4, "%s: step in 1..4" % id)
		check(String(m.get("_manifest", "")).ends_with("/module.gd"), "%s: discovered through a module.gd" % id)
		var st = m.get("selftest")
		if st is Dictionary and not (st as Dictionary).is_empty():
			var sc: String = String(st.get("scene", st.get("script", "")))
			if sc != "":
				check(ResourceLoader.exists(sc), "%s: selftest scene exists (%s)" % [id, sc])
			check(String(st.get("marker", "")) != "", "%s: selftest marker set" % id)
	check(not order_missing, "every module declares an order")
	check(ordered, "module order is strictly increasing in registration order")
	check(V10Registry.get_module("responsive").get("order", 9999) < V10Registry.get_module("stamina").get("order", -1), "responsive before stamina")
	check(V10Registry.manifest_errors().is_empty(), "no manifest errors: %s" % str(V10Registry.manifest_errors()))
	print("REGISTRY_SELFTEST %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)
