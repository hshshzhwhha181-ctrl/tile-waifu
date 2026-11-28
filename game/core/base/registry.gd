class_name V10Registry
extends RefCounted

# V10Registry — one table of every 0.10 module (docs/0.10-spec.md §2.8, docs/INTEGRATION_0.10.md §3.8).
# Each module is ONE file: game/core/<anywhere>/module.gd, found by scanning res://core (P07; no shared list):
#
#   extends RefCounted
#   static func spec() -> Dictionary:
#       return {
#       "id": "economy",                            the module id (unique)
#       "order": 20,                                initialisation order: ascending, ties by id (explicit, so
#                                                   directory listing order never matters)
#       "step": 1..4,                               integration step (W1–W4) that wires it into the game
#       "selftest": {scene, args, fast_args, needs_render, resolution, marker, static_only},
#       "save": {key: defaults},                    top-level save keys (registered with V10Save once step <= STEP)
#       "ensure": Callable(S),                      idempotent repair of its keys on every load (module's own ensure)
#       "migrator": Callable(S, now),               one-time 7 → 8 step (V10Save.register_migrator)
#       "screens": {id: "res://…gd"},               merged into main.SCREENS (only for wired modules)
#       "home_slot": {"id", "builder", "priority"}, a slot of the home screen (lanterns; W2+)
#       "nav": {screen_id: [parent_screen_id, …]},  edges for depth_graph() (UX П-5)
#       "wire": Callable(),                         one-time boot wiring of callbacks/providers/tray sources; runs
#                                                   once after every manifest is registered (only when step <= STEP)
#       }
#   (V10Registry.module(id, spec) stays available for tests and tools that register a module by hand.)
#
#   V10Registry.load_all()   idempotent; G._ready() calls it before the save is read
#   screens() / selftests() / ensure_all(S) / depth_graph() / depth_of(id)

# the integration step this build is at: modules of later steps keep their selftests in --v10_selftest but do not
# put keys into the save or screens into the navigation yet
const STEP: = 4

const SCAN_ROOT: = "res://core"
const MANIFEST: = "module.gd"

static var _mods: = {}
static var _order: Array = []
static var _loaded: = false
static var _errors: Array = []


static func module(id: String, spec: Dictionary) -> void:
	if not _mods.has(id):
		_order.append(id)
	_mods[id] = spec


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_discover()
	for id in _order:
		var m: Dictionary = _mods[id]
		if int(m.get("step", 1)) > STEP:
			continue
		if m.get("wire") is Callable:
			(m.wire as Callable).call()
	for id in _order:
		var m: Dictionary = _mods[id]
		if int(m.get("step", 1)) > STEP:
			continue
		var sv: Dictionary = m.get("save", {})
		for k in sv:
			V10Save.register(k, sv[k])
		if m.get("migrator") is Callable:
			V10Save.register_migrator(id, m.migrator)


# every module.gd under SCAN_ROOT, sorted by ("order", "id"), registered through module()
static func _discover() -> void:
	var paths: Array = []
	_scan(SCAN_ROOT, paths)
	var found: Array = []
	for p in paths:
		var scr = load(p)
		if not (scr is GDScript) or not _has_spec(scr):
			_errors.append("%s: not a script with a static spec()" % p)
			continue
		var spec = scr.call("spec")
		if not (spec is Dictionary) or String((spec as Dictionary).get("id", "")) == "":
			_errors.append("%s: spec() must return a Dictionary with an \"id\"" % p)
			continue
		(spec as Dictionary)["_manifest"] = p
		found.append(spec)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: = int(a.get("order", 1000))
		var ob: = int(b.get("order", 1000))
		if oa != ob:
			return oa < ob
		return String(a.id) < String(b.id))
	for spec in found:
		if _mods.has(spec.id):
			_errors.append("%s: duplicate module id %s (already from %s)" % [spec._manifest, spec.id, _mods[spec.id].get("_manifest", "module()")])
			continue
		module(spec.id, spec)


static func _has_spec(scr) -> bool:
	return scr is GDScript and (scr as GDScript).get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "spec")


# exported builds list scripts as module.gd.remap / module.gdc: both load as res://…/module.gd
static func _scan(dir: String, out: Array) -> void:
	var d: = DirAccess.open(dir)
	if d == null:
		_errors.append("%s: cannot open" % dir)
		return
	var subs: Array = []
	for f in d.get_files():
		if f == MANIFEST or f == MANIFEST + ".remap" or f == MANIFEST + "c":
			var p: = dir.path_join(MANIFEST)
			if not (p in out):
				out.append(p)
	for sd in d.get_directories():
		if not sd.begins_with("."):
			subs.append(sd)
	subs.sort()
	for sd in subs:
		_scan(dir.path_join(sd), out)


# problems found while scanning (empty = healthy); the registry selftest asserts it is empty
static func manifest_errors() -> Array:
	load_all()
	return _errors.duplicate()


static func ids() -> Array:
	load_all()
	return _order.duplicate()


static func get_module(id: String) -> Dictionary:
	load_all()
	return _mods.get(id, {})


static func wired(id: String) -> bool:
	return int(get_module(id).get("step", 99)) <= STEP


static func screens() -> Dictionary:
	load_all()
	var out: = {}
	for id in _order:
		var m: Dictionary = _mods[id]
		if int(m.get("step", 1)) > STEP:
			continue
		var sc: Dictionary = m.get("screens", {})
		for k in sc:
			var p: String = sc[k]
			if ResourceLoader.exists(p):
				out[k] = load(p)
	return out


static func selftests() -> Array:
	load_all()
	var out: = []
	for id in _order:
		var st = _mods[id].get("selftest")
		out.append({"id": id, "spec": st if st is Dictionary else {}})
	return out


# every load (fresh game, old save, recovery import): each wired module repairs its own keys
static func ensure_all(S: Dictionary) -> void:
	load_all()
	for id in _order:
		var m: Dictionary = _mods[id]
		if int(m.get("step", 1)) > STEP:
			continue
		if m.get("ensure") is Callable:
			(m.ensure as Callable).call(S)


# navigation graph for UX П-5: tab roots are depth 0, every edge adds 1. Core edges (old screens kept reachable in
# W1) plus each module's "nav". Returns {screen_id: depth}; unreachable screens get -1.
const TAB_ROOTS: = ["home", "collection", "tables", "summon", "shop"]
const CORE_NAV: = {
	"profile": ["home"],            # avatar → Профиль
	"letters": ["home"],            # Телефон (W1: the old letters screen)
	"room": ["collection"],         # Героини → её карточка → комната (W2: салон)
	"levels": ["tables"],           # свиток Пути → полная карта
	"modes": ["tables"],            # полки → экран режима
	"arena": ["modes", "tables"],   # партия режима
	"v7event": ["tables"],          # «Сегодня»/Афиша → Событие
	"v7tourney": ["tables", "profile"],
	"v7play": ["v7event"],
	"play": ["home", "tables", "levels", "v10path", "v10salon"],
}


static func depth_graph() -> Dictionary:
	load_all()
	var parents: = {}
	for k in CORE_NAV:
		parents[k] = (CORE_NAV[k] as Array).duplicate()
	for id in _order:
		var nv: Dictionary = _mods[id].get("nav", {})
		if int(_mods[id].get("step", 1)) > STEP:
			continue
		for k in nv:
			if not parents.has(k):
				parents[k] = []
			(parents[k] as Array).append_array(nv[k])
	var depth: = {}
	for r in TAB_ROOTS:
		depth[r] = 0
	var changed: = true
	while changed:
		changed = false
		for k in parents:
			for p in parents[k]:
				if depth.has(p):
					var d: = int(depth[p]) + 1
					if not depth.has(k) or d < int(depth[k]):
						depth[k] = d
						changed = true
	for k in parents:
		if not depth.has(k):
			depth[k] = -1
	return depth


static func depth_of(screen_id: String) -> int:
	return int(depth_graph().get(screen_id, -1))
