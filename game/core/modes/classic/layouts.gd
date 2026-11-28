class_name V10MjClassicLayouts
extends RefCounted

# «Классика»: 22 forms with explicit coordinates (game/data/mj/classic/layouts.json, built by tools/make_layouts.py).
# x, y in half cells (2 = one tile, odd = the Turtle's half-tile offsets), z = layer. 12 classic forms are for
# everyone; 10 heroine symbols (fan, bowl, sun, crescent, crystal, fox, firebird, pearl, crown, snowflake) are shown
# only while their heroine is in G.HEROES (the five founders now; the rest appear with their wave). No body
# silhouettes anywhere.

const PATH: = "res://data/mj/classic/layouts.json"

# the signature tile face of each founder (MODES §3.4): a pair of it is «her» pair (+25 % Приём, her sting)
const SIGNATURE: = {"mc": 28, "rin": 21, "hana": 9, "yue": 7, "nova": 24}
# flowers and seasons: four different faces each, any two of a group make a pair (classic rule)
const FLOWERS: = [0, 1, 2, 4]
const SEASONS: = [5, 3, 6, 11]
const KEY_FLOWER: = 1000
const KEY_SEASON: = 1001

static var _forms: Array = []
static var _by_id: = {}


static func all() -> Array:
	if _forms.is_empty():
		_load()
	return _forms


static func _load() -> void:
	var f: = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("V10MjClassicLayouts: no %s" % PATH)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		push_error("V10MjClassicLayouts: bad json")
		return
	for raw in d.get("forms", []):
		var pos: Array[Vector3i] = []
		for p in raw.pos:
			pos.append(Vector3i(int(p[0]), int(p[1]), int(p[2])))
		var form: = {"id": String(raw.id), "name": String(raw.name), "kind": String(raw.kind), "hero": String(raw.get("hero", "")),
			"color": Color(String(raw.get("color", "#e8c47e"))), "pos": pos}
		_forms.append(form)
		_by_id[form.id] = form


static func get_form(id: String) -> Dictionary:
	all()
	return _by_id.get(id, {})


static func ids() -> Array:
	return all().map(func(f): return f.id)


# a heroine form is visible only while she is in the roster; a form of a heroine who is not there yet does not
# exist for the player (no silhouette, no teaser)
static func visible(f: Dictionary, roster = null) -> bool:
	if f.is_empty():
		return false
	if f.kind != "hero":
		return true
	var heroes: Dictionary = roster if roster is Dictionary else _roster()
	return heroes.has(f.hero)


static func visible_forms(roster = null) -> Array:
	return all().filter(func(f): return visible(f, roster))


static func classic_forms() -> Array:
	return all().filter(func(f): return f.kind == "classic")


static func _roster() -> Dictionary:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g and g.get("HEROES") is Dictionary:
		return g.HEROES
	return {}


static func match_key(face: int) -> int:
	if face in FLOWERS:
		return KEY_FLOWER
	if face in SEASONS:
		return KEY_SEASON
	return face


# regular faces for quads: every face that is not a flower or a season
static func regular_faces() -> Array:
	var out: = []
	for i in 36:
		if not (i in FLOWERS or i in SEASONS):
			out.append(i)
	return out
