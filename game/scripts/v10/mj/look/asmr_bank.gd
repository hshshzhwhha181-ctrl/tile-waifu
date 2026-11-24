class_name V10MjAsmr
extends Node

# V10MjAsmr — the table's ASMR bank (docs/MODES.md §3.4, BENCHMARK MD-2, UX_RULES §7.4).
# Every key has ≥ 4 recorded variants (res://assets/v10/mj/look/sfx/<key>_<n>.wav, 16-bit mono, peaks ≤ −6 dBFS);
# a shuffle bag never repeats the last variant and every play gets a ±3% pitch.
#
#   V10MjAsmr.clack(material)          tile against tile, 6 per material (porcelain jade bone ice amber lacquer)
#   V10MjAsmr.pick()                   soft lift of a tile
#   V10MjAsmr.place(material = "")     dense seat into the tray / the hand
#   V10MjAsmr.pair(material, combo)    «клак-клак»; combo n raises it a semitone per step (cap an octave),
#                                      every ×5 adds the gong
#   V10MjAsmr.triple(suit)             3-note pentatonic chord, root by suit (G.CATS index 0..4)
#   V10MjAsmr.rotate()                 Cube: quarter-turn rustle
#   V10MjAsmr.thread(i = -1)           Connect: the line's thread, 5 tuned variants
#   V10MjAsmr.felt(own)                riichi discard on the cloth: own quieter, others' louder
#   V10MjAsmr.stick()                  the riichi stick
#   V10MjAsmr.ambient(name, fade)      night-table loop: "rain" | "stream" | "bamboo" | "" (stop)
#   V10MjAsmr.ambient_for(theme)       the table theme's ambient (V10MjTables amb.sfx) unless the player chose one
# All of it is silent when the game sound is off (G.S.sound) or the player turned «ASMR стола» off.
# The node lives at /root/V10MjAsmr, created on first use (no autoload; headless-safe).

const DIR: = "res://assets/v10/mj/look/sfx/"
const AMB_DIR: = "res://assets/v10/mj/look/amb/"
const MATS: = ["porcelain", "jade", "bone", "ice", "amber", "lacquer"]
const PITCH_JITTER: = 0.03
const COMBO_CAP: = 12
const GONG_EVERY: = 5

# key → {n: variants on disk, db: playback trim}
const KEYS: = {
	"clack_porcelain": {"n": 6, "db": 0.0}, "clack_jade": {"n": 6, "db": 0.0}, "clack_bone": {"n": 6, "db": 0.0},
	"clack_ice": {"n": 6, "db": -1.0}, "clack_amber": {"n": 6, "db": 0.0}, "clack_lacquer": {"n": 6, "db": 0.0},
	"pair_porcelain": {"n": 4, "db": 0.0}, "pair_jade": {"n": 4, "db": 0.0}, "pair_bone": {"n": 4, "db": 0.0},
	"pair_ice": {"n": 4, "db": -1.0}, "pair_amber": {"n": 4, "db": 0.0}, "pair_lacquer": {"n": 4, "db": 0.0},
	"pick": {"n": 6, "db": -6.0}, "place": {"n": 6, "db": -2.0},
	"triple_0": {"n": 4, "db": -3.0}, "triple_1": {"n": 4, "db": -3.0}, "triple_2": {"n": 4, "db": -3.0},
	"triple_3": {"n": 4, "db": -3.0}, "triple_4": {"n": 4, "db": -3.0},
	"gong": {"n": 4, "db": -4.0}, "rotate": {"n": 6, "db": -3.0}, "thread": {"n": 5, "db": -4.0},
	"felt": {"n": 6, "db": 0.0}, "stick": {"n": 4, "db": -2.0},
}
const AMBIENTS: = ["rain", "stream", "bamboo"]
const OWN_FELT_DB: = -5.0      # own discard: softer (you made it)
const OTHER_FELT_DB: = 0.0     # a rival's discard: you should notice it
const AMB_DB: = -20.0

var _pool: Array[AudioStreamPlayer] = []
var _next: = 0
var _bags: = {}
var _last: = {}
var _cache: = {}
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var cur_ambient: = ""
# selftest / dev log: the last plays as {key, file, pitch, db}
var played: Array = []
var log_on: = false


static var _inst: V10MjAsmr

static func inst() -> V10MjAsmr:
	if is_instance_valid(_inst):
		return _inst
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var n: = tree.root.get_node_or_null("V10MjAsmr")
	if n == null:
		n = V10MjAsmr.new()
		n.name = "V10MjAsmr"
		tree.root.add_child.call_deferred(n)
		# usable in this frame too: _ready() is idempotent
		n._setup()
	_inst = n as V10MjAsmr
	return _inst


func _ready() -> void:
	_setup()


func _setup() -> void:
	if not _pool.is_empty():
		return
	for i in 10:
		var p: = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_amb_a = AudioStreamPlayer.new()
	_amb_b = AudioStreamPlayer.new()
	add_child(_amb_a)
	add_child(_amb_b)


static func file_for(key: String, n: int) -> String:
	return DIR + "%s_%d.wav" % [key, n]


static func sound_on() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	if g == null:
		return true
	if not bool(g.S.get("sound", true)):
		return false
	return bool(V10MjTileMaterial.st().get("asmr", true))


static func jitter() -> float:
	return randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)


static func combo_pitch(n: int) -> float:
	return pow(2.0, float(clampi(n - 1, 0, COMBO_CAP)) / 12.0)


# shuffle bag without immediate repeats
func _variant(key: String) -> int:
	var n: int = KEYS[key].n
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		for i in n:
			bag.append(i + 1)
		bag.shuffle()
		if bag.size() > 1 and bag[0] == _last.get(key, -1):
			bag.append(bag.pop_front())
	var v: int = bag.pop_front()
	_bags[key] = bag
	_last[key] = v
	return v


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


# core: returns {key, file, pitch, db} (also when muted, so tests can see what would play)
func play_key(key: String, pitch_mul: = 1.0, db: = 0.0) -> Dictionary:
	if not KEYS.has(key):
		push_warning("V10MjAsmr: unknown key %s" % key)
		return {}
	var v: = _variant(key)
	var path: = file_for(key, v)
	var p: = jitter() * pitch_mul
	var vol: float = KEYS[key].db + db
	var rec: = {"key": key, "file": path, "pitch": p, "db": vol, "jitter": p / pitch_mul}
	if log_on:
		played.append(rec)
	if not sound_on() or not is_inside_tree():
		return rec
	var st: = _stream(path)
	if st == null:
		return rec
	var pl: = _pool[_next]
	_next = (_next + 1) % _pool.size()
	pl.stream = st
	pl.pitch_scale = p
	pl.volume_db = vol
	pl.play()
	return rec


# ── named sounds (static entry points) ──────────────────────────────────────────────────────────────────────────

static func _mat(m: String) -> String:
	return m if m in MATS else "porcelain"


static func clack(material: = "porcelain") -> Dictionary:
	var a: = inst()
	return a.play_key("clack_" + _mat(material)) if a else {}


static func pick() -> Dictionary:
	var a: = inst()
	return a.play_key("pick") if a else {}


static func place(material: = "") -> Dictionary:
	var a: = inst()
	if a == null:
		return {}
	var r: = a.play_key("place")
	if material != "":
		# a faint material clack on top: the tray «speaks» the tile's material
		a.play_key("clack_" + _mat(material), 1.0, -12.0)
	return r


static func pair(material: = "porcelain", combo: = 1) -> Dictionary:
	var a: = inst()
	if a == null:
		return {}
	var r: = a.play_key("pair_" + _mat(material), combo_pitch(combo))
	if combo > 0 and combo % GONG_EVERY == 0:
		a.play_key("gong", 1.0)
		r["gong"] = true
	return r


static func triple(suit: int) -> Dictionary:
	var a: = inst()
	return a.play_key("triple_%d" % clampi(suit, 0, 4)) if a else {}


static func rotate() -> Dictionary:
	var a: = inst()
	return a.play_key("rotate") if a else {}


static func thread(i: = -1) -> Dictionary:
	var a: = inst()
	return a.play_key("thread") if a else {}


static func felt(own: = true) -> Dictionary:
	var a: = inst()
	return a.play_key("felt", 1.0, OWN_FELT_DB if own else OTHER_FELT_DB) if a else {}


static func stick() -> Dictionary:
	var a: = inst()
	return a.play_key("stick") if a else {}


# ── ambient night table ─────────────────────────────────────────────────────────────────────────────────────────

static func ambient_path(name: String) -> String:
	return AMB_DIR + "%s.ogg" % name


static func ambient(name: String, fade: = 1.2) -> void:
	var a: = inst()
	if a:
		a._ambient(name, fade)


static func ambient_for(theme: Dictionary) -> void:
	var pick_name: = String(V10MjTileMaterial.st().get("ambient", "auto"))
	if pick_name == "auto":
		pick_name = String(theme.get("amb", {}).get("sfx", ""))
	if pick_name == "off":
		pick_name = ""
	ambient(pick_name)


func _ambient(name: String, fade: float) -> void:
	if name != "" and not (name in AMBIENTS):
		name = ""
	if not sound_on():
		name = ""
	if name == cur_ambient:
		return
	cur_ambient = name
	var old: = _amb_a if _amb_a.playing else _amb_b
	var nw: = _amb_b if old == _amb_a else _amb_a
	if name != "":
		var st: = _stream(ambient_path(name))
		if st:
			st = st.duplicate()
			if st is AudioStreamOggVorbis:
				st.loop = true
			nw.stream = st
			nw.volume_db = -50.0
			nw.play()
			if is_inside_tree():
				create_tween().tween_property(nw, "volume_db", AMB_DB, fade)
			else:
				nw.volume_db = AMB_DB
	if old.playing:
		if is_inside_tree():
			var t: = create_tween()
			t.tween_property(old, "volume_db", -50.0, fade)
			t.tween_callback(old.stop)
		else:
			old.stop()
