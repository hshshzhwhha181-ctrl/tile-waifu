class_name V10Registry
extends RefCounted

# V10Registry — one table of every 0.10 module (docs/0.10-spec.md §2.8, docs/INTEGRATION_0.10.md §3.8).
# Each module adds ONE line to registry_list.gd:
#
#   V10Registry.module(id, {
#       "step": 1..4,                               integration step (W1–W4) that wires it into the game
#       "selftest": {scene, args, fast_args, needs_render, resolution, marker, static_only},
#       "save": {key: defaults},                    top-level save keys (registered with V10Save once step <= STEP)
#       "ensure": Callable(S),                      idempotent repair of its keys on every load (module's own ensure)
#       "migrator": Callable(S, now),               one-time 7 → 8 step (V10Save.register_migrator)
#       "screens": {id: "res://…gd"},               merged into main.SCREENS (only for wired modules)
#       "home_slot": {"id", "builder", "priority"}, a slot of the home screen (lanterns; W2+)
#       "nav": {screen_id: [parent_screen_id, …]},  edges for depth_graph() (UX П-5)
#   })
#
#   V10Registry.load_all()   idempotent; G._ready() calls it before the save is read
#   screens() / selftests() / ensure_all(S) / depth_graph() / depth_of(id)

# the integration step this build is at: modules of later steps keep their selftests in --v10_selftest but do not
# put keys into the save or screens into the navigation yet
const STEP: = 4

static var _mods: = {}
static var _order: Array = []
static var _loaded: = false


static func module(id: String, spec: Dictionary) -> void:
	if not _mods.has(id):
		_order.append(id)
	_mods[id] = spec


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	V10RegistryList.register_all()
	for id in _order:
		var m: Dictionary = _mods[id]
		if int(m.get("step", 1)) > STEP:
			continue
		var sv: Dictionary = m.get("save", {})
		for k in sv:
			V10Save.register(k, sv[k])
		if m.get("migrator") is Callable:
			V10Save.register_migrator(id, m.migrator)


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
