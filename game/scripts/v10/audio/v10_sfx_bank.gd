class_name V10SfxBank
extends Node

# 0.10 premium SFX bank: id -> variants, base gain, pitch spread, polyphony and retrigger limits.
# No autoload needed: the first call creates one instance under /root (deferred-safe).
#
#   V10SfxBank.play("tile_click")                  random variant (never the same one twice in a row),
#                                                  random pitch within the id's spread
#   V10SfxBank.play("coin_fly", {"pitch": 1.1, "db": -3, "at": 0.0})   overrides
#   V10SfxBank.match_tier(tier)                    tier 1..3 -> match_1/1b, match_2, match_3
#   V10SfxBank.combo(n) -> float                   pair n of a combo: combo_step a semitone higher each pair (as
#                                                  Sfx.combo_pitch, capped at an octave); n >= 8 adds combo_finale
#   V10SfxBank.voice(hero, kind) -> String         a new 0.10 bark (riichi / rankup) on the voice player, emits
#                                                  Sfx.voice_started for lip-sync/subtitles; returns the RU subtitle
#   V10SfxBank.has(id) / ids() / path_of(id) / length_of(id)
#
# Polyphony: each id has max voices (oldest instance of that id is stolen), a min retrigger gap (taps spammed
# faster than that are merged), and the whole bank has POOL players. Respects G.S.sound / G.S.voice.
# Mastering: SFX -14 LUFS (transient sounds peak-capped at -1 dBFS, so clicks land lower — "db" below balances).

const DIR: = "res://assets/v10/audio/sfx/"
const VOICE_DIR: = "res://assets/v10/audio/voice/"
const POOL: = 20

# id: [variants], db (playback gain), spread (± semitones), max (voices of this id), gap (s, min retrigger),
# vdb (optional per-variant trim so random variants land at the same loudness; measured 100 ms K-weighted peak)
const BANK: = {
	"tile_click": {"v": ["tile_click", "tile_click_b", "tile_click_c"], "vdb": [0.0, 0.8, -2.6], "db": -2.0, "spread": 0.6, "max": 4, "gap": 0.03},
	"tile_select": {"v": ["tile_select"], "db": -3.0, "spread": 0.5, "max": 4, "gap": 0.03},
	"tile_deny": {"v": ["tile_deny"], "db": -4.0, "spread": 0.3, "max": 2, "gap": 0.12},
	"match_1": {"v": ["match_1", "match_1b"], "db": 0.0, "spread": 0.4, "max": 3, "gap": 0.04},
	"match_2": {"v": ["match_2"], "db": -2.0, "spread": 0.3, "max": 3, "gap": 0.05},
	"match_3": {"v": ["match_3"], "db": -3.0, "spread": 0.2, "max": 2, "gap": 0.08},
	"combo_step": {"v": ["combo_step"], "db": -4.0, "spread": 0.0, "max": 4, "gap": 0.03},
	"combo_finale": {"v": ["combo_finale"], "db": -4.0, "spread": 0.0, "max": 1, "gap": 0.4},
	"fever_ignite": {"v": ["fever_ignite"], "db": -3.0, "spread": 0.0, "max": 1, "gap": 1.0},
	"fever_end": {"v": ["fever_end"], "db": -5.0, "spread": 0.0, "max": 1, "gap": 1.0},
	"ult_ready": {"v": ["ult_ready"], "db": -4.0, "spread": 0.0, "max": 1, "gap": 0.8},
	"ult_cast": {"v": ["ult_cast"], "db": -3.0, "spread": 0.0, "max": 1, "gap": 0.5},
	"cutin_whoosh": {"v": ["cutin_whoosh"], "db": -2.0, "spread": 0.4, "max": 2, "gap": 0.15},
	"chest_open": {"v": ["chest_open"], "db": 0.0, "spread": 0.2, "max": 1, "gap": 0.4},
	"coin_fly": {"v": ["coin_fly"], "db": -7.0, "spread": 0.8, "max": 3, "gap": 0.06},
	"gem_fly": {"v": ["gem_fly"], "db": 0.0, "spread": 0.8, "max": 3, "gap": 0.06},
	"reward_pop": {"v": ["reward_pop"], "db": -5.0, "spread": 1.0, "max": 4, "gap": 0.05},
	"star": {"v": ["star"], "db": -2.0, "spread": 0.0, "max": 3, "gap": 0.1},
	"rank_up": {"v": ["rank_up"], "db": -2.0, "spread": 0.0, "max": 1, "gap": 1.0},
	"btn_hover": {"v": ["btn_hover"], "db": -14.0, "spread": 0.8, "max": 2, "gap": 0.06},
	"btn_press": {"v": ["btn_press", "btn_press_b"], "vdb": [1.9, -1.9], "db": -4.0, "spread": 0.5, "max": 3, "gap": 0.04},
	"tab_switch": {"v": ["tab_switch"], "db": -6.0, "spread": 0.4, "max": 2, "gap": 0.08},
	"page_turn": {"v": ["page_turn"], "db": -6.0, "spread": 0.6, "max": 2, "gap": 0.08},
	"notify": {"v": ["notify"], "db": -2.0, "spread": 0.0, "max": 1, "gap": 0.3},
	"lantern_rise": {"v": ["lantern_rise"], "db": -3.0, "spread": 0.0, "max": 1, "gap": 0.5},
	"card_flip": {"v": ["card_flip"], "db": -4.0, "spread": 0.7, "max": 4, "gap": 0.04},
	"sr_reveal": {"v": ["sr_reveal"], "db": -3.0, "spread": 0.0, "max": 1, "gap": 0.3},
	"ssr_reveal": {"v": ["ssr_reveal"], "db": -1.0, "spread": 0.0, "max": 1, "gap": 0.5},
	"booster": {"v": ["booster"], "db": -3.0, "spread": 0.3, "max": 1, "gap": 0.2},
	"undo": {"v": ["undo"], "db": 0.0, "spread": 0.3, "max": 1, "gap": 0.1},
	"shuffle": {"v": ["shuffle"], "db": -1.0, "spread": 0.2, "max": 1, "gap": 0.3},
	"heart": {"v": ["heart"], "db": -4.0, "spread": 0.5, "max": 2, "gap": 0.15},
}

# new 0.10 barks (Japanese, cloned from each heroine's existing 0.7 voice, like assets/voice/*.mp3);
# subtitle text = Sfx.VOICED[hero][kind][0]
const VOICE_KINDS: = ["riichi", "rankup"]
const HEROES: = ["mc", "rin", "hana", "yue", "nova"]
const COMBO_MAX_STEP: = 12

static var _inst: V10SfxBank = null

var _pool: Array[AudioStreamPlayer] = []
var _owner: = {}  # player -> id
var _started: = {}  # player -> ticks ms
var _last_at: = {}  # id -> ticks ms
var _last_var: = {}  # id -> index
var _cache: = {}
var _voice: AudioStreamPlayer
var _pending: Array = []
var _rng: = RandomNumberGenerator.new()


static func inst() -> V10SfxBank:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree: = Engine.get_main_loop() as SceneTree
	_inst = V10SfxBank.new()
	_inst.name = "V10SfxBank"
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_inst)
	return _inst


static func play(id: String, opts: = {}) -> void :
	inst()._call("_play", [id, opts])


static func match_tier(tier: int) -> void :
	play("match_%d" % clampi(tier, 1, 3))


static func combo_pitch(n: int) -> float:
	return pow(2.0, float(clampi(n - 1, 0, COMBO_MAX_STEP)) / 12.0)


static func combo(n: int) -> float:
	var p: = combo_pitch(n)
	play("combo_step", {"pitch": p, "spread": 0.0})
	if n >= 8 and n % 4 == 0:
		play("combo_finale")
	return p


static func voice(hero: String, kind: String) -> String:
	var me: = inst()
	var text: = me._voice_text(hero, kind)
	me._call("_say", [hero, kind, text])
	return text


static func has(id: String) -> bool:
	return BANK.has(id)


static func ids() -> Array:
	return BANK.keys()


static func path_of(variant: String) -> String:
	return DIR + variant + ".ogg"


static func voice_path(hero: String, kind: String) -> String:
	return VOICE_DIR + "%s_%s1.ogg" % [hero, kind]


static func length_of(id: String) -> float:
	if not BANK.has(id):
		return 0.0
	var st: AudioStream = load(path_of(BANK[id]["v"][0]))
	return st.get_length() if st != null else 0.0


# ---------------------------------------------------------------------------------------------------------

func _call(method: String, args: Array) -> void :
	if is_inside_tree():
		callv(method, args)
	else:
		_pending.append([method, args])


func _ready() -> void :
	_rng.randomize()
	for i in POOL:
		var p: = AudioStreamPlayer.new()
		p.name = "S%d" % i
		add_child(p)
		_pool.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.volume_db = 1.0
	add_child(_voice)
	for p in _pending:
		callv(p[0], p[1])
	_pending.clear()


func _exit_tree() -> void :
	if _inst == self:
		_inst = null


func _g_flag(key: String) -> bool:
	var g: = get_node_or_null("/root/G")
	if g == null:
		return true
	return bool(g.S.get(key, true))


func _stream(variant: String) -> AudioStream:
	if not _cache.has(variant):
		_cache[variant] = load(path_of(variant)) if ResourceLoader.exists(path_of(variant)) else null
	return _cache[variant]


func active_of(id: String) -> int:
	var n: = 0
	for p in _pool:
		if p.playing and _owner.get(p, "") == id:
			n += 1
	return n


func _play(id: String, opts: Dictionary) -> void :
	if not BANK.has(id):
		push_warning("V10SfxBank: unknown id %s" % id)
		return
	if not _g_flag("sound"):
		return
	var e: Dictionary = BANK[id]
	var now: = Time.get_ticks_msec()
	if now - int(_last_at.get(id, -100000)) < int(float(e["gap"]) * 1000.0) and not opts.get("force", false):
		return
	_last_at[id] = now
	# variant: random, never the same twice in a row
	var vs: Array = e["v"]
	var vi: = 0
	if vs.size() > 1:
		vi = _rng.randi_range(0, vs.size() - 2)
		if vi >= int(_last_var.get(id, -1)):
			vi += 1
	_last_var[id] = vi
	var st: = _stream(String(vs[vi]))
	if st == null:
		return
	# polyphony: steal the oldest voice of this id when at its limit, else a free player, else the oldest overall
	var p: AudioStreamPlayer = null
	if active_of(id) >= int(e["max"]):
		p = _oldest(func(q): return q.playing and _owner.get(q, "") == id)
	if p == null:
		for q in _pool:
			if not q.playing:
				p = q
				break
	if p == null:
		p = _oldest(func(q): return true)
	var spread: = float(opts.get("spread", e["spread"]))
	var pitch: = float(opts.get("pitch", 1.0)) * pow(2.0, _rng.randf_range(-spread, spread) / 12.0)
	p.stop()
	p.stream = st
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	var vdb: Array = e.get("vdb", [])
	p.volume_db = float(e["db"]) + (float(vdb[vi]) if vi < vdb.size() else 0.0) + float(opts.get("db", 0.0))
	p.bus = String(opts.get("bus", "Master"))
	_owner[p] = id
	_started[p] = now
	p.play(float(opts.get("at", 0.0)))


func _oldest(pred: Callable) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	var t: = 1 << 62
	for q in _pool:
		if pred.call(q) and int(_started.get(q, 0)) < t:
			t = int(_started.get(q, 0))
			best = q
	return best


func _voice_text(hero: String, kind: String) -> String:
	var s: = get_node_or_null("/root/Sfx")
	if s != null:
		var v: Dictionary = s.get_script().get_script_constant_map().get("VOICED", {}) if s.get_script() != null else {}
		if v.has(hero) and v[hero].has(kind):
			return String(v[hero][kind][0])
	return ""


func _say(hero: String, kind: String, text: String) -> void :
	var path: = voice_path(hero, kind)
	var dur: = 1.2
	if _g_flag("sound") and _g_flag("voice") and ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		_voice.stream = st
		_voice.play()
		dur = st.get_length()
	var s: = get_node_or_null("/root/Sfx")
	if s != null and s.has_signal("voice_started"):
		s.voice_started.emit(hero, text, dur)
