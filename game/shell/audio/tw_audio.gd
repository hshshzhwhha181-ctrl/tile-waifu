class_name TWAudio
extends Node

# TWAudio (P30 / WP10, GDD V11 8): one audio bus for the v11 shell. It replaces, screen by screen, Sfx (sound, voice, duck),
# V9Feel sound/haptics, V7Haptics and the V10Music facade. No new audio assets: SFX come from V10SfxBank.BANK, music from V10Music.
# Not an autoload (project.godot is frozen): the shell creates one, adds it to the tree and hands it out as ctx.provide("audio", a).
#
# Buses (game/default_bus_layout.tres, ensure_buses() builds the same when the layout is missing):
#   Master -> Music | SFX | Voice | UI       UI sits at -2 dB (GDD 8.1); sliders move the bus volume, ducks add to it
#
# API
#   play_cue(name, data = {}) / stop_cue(name)   what TWResultModal / screens send (stings, star, gem_fly ...); optional service contract
#   sfx(id, opts = {}) -> bool                   one SFX (bank id) on SFX, or on UI for the UI ids; false when the budget dropped it
#   combo(n) -> float                            the combo pitch ladder (pair n of a combo = n-1 semitones up, cap an octave)
#   tile_click() / match_tier(t)                 the match sounds
#   say(hero, kind, opts = {}) -> Dictionary     a heroine line through TWVoiceQueue; opts: line_id, ctx "lobby"|"match", dur, rare, roll
#                                                 returns the queue verdict + {"text", "audible", "subtitle"} (subtitles always)
#   stop_voice()                                 cut the voice (screen change)
#   duck_combo_t3() / ult(hero) / summon_reveal(on)   the other ducks of GDD 8.5
#   music(screen_id) / tension(fill) / fever(on) / sting(id) / stop_music()   V10Music facade, honours the Music slider
#   haptic(kind) -> Array                        GDD 8.6 layer 1; the pulse list is also returned for tests
#   configure(settings) / set_profile(name)      sliders, voice mode, per-heroine mute, haptics level, device profile
#
# Time: the node advances its own clock in _process; with `manual = true` the caller advances it with advance(dt) (selftests).

signal voice_started(hero: String, text: String, dur: float)
signal voice_dropped(hero: String, kind: String, reason: String)

const BUS_MASTER: = "Master"
const BUS_MUSIC: = "Music"
const BUS_SFX: = "SFX"
const BUS_VOICE: = "Voice"
const BUS_UI: = "UI"
const UI_BUS_DB: = -2.0
const BUSES: = [BUS_MUSIC, BUS_SFX, BUS_VOICE, BUS_UI]

const COMBO_MAX_STEP: = 12
const PROFILES: = {"normal": {"max_sfx": 16}, "weak_mali": {"max_sfx": 8}}
const MAX_VOICES: = 1

# bank ids that go to the UI bus; priority classes of the voice budget (finale > normal > hover)
const UI_IDS: = ["btn_hover", "btn_press", "tab_switch", "page_turn", "notify"]
const PRIO_HIGH: = ["combo_finale", "fever_ignite", "ult_cast", "ult_ready", "ssr_reveal", "sr_reveal", "rank_up", "chest_open"]
const PRIO_LOW: = ["btn_hover", "tile_select", "page_turn", "tab_switch"]
# result-chain / screen cue names -> bank ids (sting_victory_short has no asset yet: a placeholder bank sound stands in for it)
const CUE_ALIAS: = {"sting_victory_short": "rank_up", "gem_fly": "gem_fly", "coin_fly": "coin_fly", "star": "star"}
const STING_CUES: = {"sting_victory": "victory", "sting_defeat": "defeat"}

# GDD 8.6 layer 1: [ms, amplitude, pause_after_ms]; "error" is deliberately empty (no vibration)
const HAPTICS: = {
	"select": [[10, 0.3, 0]], "match": [[20, 0.5, 0]], "ult": [[60, 0.8, 0]], "error": [],
	"clear": [[30, 0.8, 70], [30, 0.8, 70], [60, 1.0, 0]], "reveal": [[24, 0.6, 0]],
}
const HAPTIC_MIN_GAP_S: = 0.035
const HAPTIC_SCALE: = {"off": 0.0, "weak": 0.5, "full": 1.0}

var manual: = false
var profile: = "normal"
var settings: Dictionary = {"music": 1.0, "voice": 1.0, "sfx": 1.0, "ui": 1.0, "voice_mode": "lobby", "hero_off": {}, "haptics": "full"}
var queue: TWVoiceQueue = TWVoiceQueue.new()
var pool: TWSfxPool = TWSfxPool.new(16)
var duck_music: TWDuck = TWDuck.new()
var duck_sfx: TWDuck = TWDuck.new()
var voice_resolver: Callable = Callable()   # (hero, kind) -> AudioStream | null; default: V10SfxBank voice file or assets/voice
var text_resolver: Callable = Callable()    # (hero, kind) -> String; default: Sfx.VOICED[hero][kind][0] when the legacy autoload exists
var haptic_sink: Callable = Callable()      # (ms: int, amp: float) -> void; default: Input.vibrate_handheld
var haptic_log: Array = []

var _t: = 0.0
var _players: Array[AudioStreamPlayer] = []
var _slot_cue: Array = []
var _voice_player: AudioStreamPlayer
var _cache: Dictionary = {}
var _last_var: Dictionary = {}
var _last_haptic: = -1.0
var _rng: = RandomNumberGenerator.new()
var _sting_cue: = ""
var voice_current: Dictionary = {}
var stats: = {"sfx_played": 0, "sfx_dropped": 0, "voices_started": 0, "peak_players": 0}


# ── buses ────────────────────────────────────────────────────────────────────────────────────────────────────────────────

static func ensure_buses() -> void:
	for n in BUSES:
		if AudioServer.get_bus_index(n) >= 0:
			continue
		AudioServer.add_bus()
		var i: = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, BUS_MASTER)
		AudioServer.set_bus_volume_db(i, UI_BUS_DB if n == BUS_UI else 0.0)


static func combo_pitch(n: int) -> float:
	return pow(2.0, float(clampi(n - 1, 0, COMBO_MAX_STEP)) / 12.0)


# weak Mali: the Android GPUs in the budget class; everything else is "normal". The shell may override with set_profile().
static func detect_profile() -> String:
	if OS.get_name() == "Android" and RenderingServer.get_video_adapter_name().to_lower().contains("mali"):
		return "weak_mali"
	return "normal"


# ── lifecycle / clock ────────────────────────────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	ensure_buses()
	_rng.randomize()
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "Voice"
	_voice_player.bus = BUS_VOICE
	add_child(_voice_player)
	set_profile(profile if profile != "normal" else detect_profile())
	apply_volumes()


func set_profile(name: String) -> void:
	if not PROFILES.has(name):
		name = "normal"
	profile = name
	var n: int = int(PROFILES[name]["max_sfx"])
	pool = TWSfxPool.new(n)
	for p in _players:
		p.stop()
		p.queue_free()
	_players.clear()
	_slot_cue.clear()
	for i in n:
		var p: = AudioStreamPlayer.new()
		p.name = "S%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
		_slot_cue.append("")


func configure(s: Dictionary) -> void:
	for k in s:
		settings[k] = s[k]
	apply_volumes()


func now() -> float:
	return _t


func advance(dt: float) -> void:
	_t += dt
	_update(dt)


func _process(dt: float) -> void:
	if manual:
		return
	_t = Time.get_ticks_msec() / 1000.0
	_update(dt)


func _update(dt: float) -> void:
	var started: = queue.tick(_t)
	if not started.is_empty():
		_begin_voice(started["entry"])
	if not queue.busy(_t):
		voice_current = {}
	if not queue.busy(_t):
		duck_music.clear_source("voice")
		duck_sfx.clear_source("voice")
	duck_music.step(dt)
	duck_sfx.step(dt)
	apply_volumes()
	var playing: = 0
	for p in _players:
		if p.playing:
			playing += 1
	stats["peak_players"] = maxi(int(stats["peak_players"]), playing)


func _slider_db(key: String) -> float:
	var v: = clampf(float(settings.get(key, 1.0)), 0.0, 1.0)
	return -80.0 if v <= 0.0001 else linear_to_db(v)


func bus_db(bus: String) -> float:
	match bus:
		BUS_MUSIC:
			return _slider_db("music") + duck_music.cur_db
		BUS_SFX:
			return _slider_db("sfx") + duck_sfx.cur_db
		BUS_VOICE:
			return _slider_db("voice")
		BUS_UI:
			return UI_BUS_DB + _slider_db("ui") + duck_sfx.cur_db
	return 0.0


func apply_volumes() -> void:
	for b in BUSES:
		var i: = AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, bus_db(b))


# ── SFX ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func prio_of(id: String) -> int:
	if PRIO_HIGH.has(id):
		return 3
	if PRIO_LOW.has(id):
		return 1
	return 2


func sfx(id: String, opts: Dictionary = {}) -> bool:
	if not V10SfxBank.BANK.has(id):
		push_warning("TWAudio.sfx: unknown id %s" % id)
		return false
	if _slider_db("sfx") <= -79.0 and not UI_IDS.has(id):
		return false
	var e: Dictionary = V10SfxBank.BANK[id]
	var vs: Array = e["v"]
	var vi: = 0
	if vs.size() > 1:
		vi = _rng.randi_range(0, vs.size() - 2)
		if vi >= int(_last_var.get(id, -1)):
			vi += 1
	_last_var[id] = vi
	var st: = _stream(V10SfxBank.path_of(String(vs[vi])))
	var spread: = float(opts.get("spread", e["spread"]))
	var pitch: = clampf(float(opts.get("pitch", 1.0)) * pow(2.0, _rng.randf_range(-spread, spread) / 12.0), 0.25, 4.0)
	var dur: = (st.get_length() / pitch) if st != null else 0.3
	var slot: = pool.acquire(id, dur, prio_of(id), _t, int(e["max"]), float(opts.get("gap", e["gap"])))
	if slot < 0:
		stats["sfx_dropped"] += 1
		return false
	stats["sfx_played"] += 1
	var p: = _players[slot] if slot < _players.size() else null
	if p != null and st != null:
		var vdb: Array = e.get("vdb", [])
		p.stop()
		p.stream = st
		p.pitch_scale = pitch
		p.volume_db = float(e["db"]) + (float(vdb[vi]) if vi < vdb.size() else 0.0) + float(opts.get("db", 0.0))
		p.bus = BUS_UI if UI_IDS.has(id) else BUS_SFX
		_slot_cue[slot] = id
		p.play()
	return true


func combo(n: int) -> float:
	var pitch: = combo_pitch(n)
	sfx("combo_step", {"pitch": pitch, "spread": 0.0})
	if n >= 8 and n % 4 == 0:
		sfx("combo_finale")
	haptic("match" if n < 3 else "select")
	return pitch


func tile_click() -> bool:
	haptic("select")
	return sfx("tile_click")


func match_tier(tier: int) -> bool:
	haptic("match")
	return sfx("match_%d" % clampi(tier, 1, 3))


func play_cue(name: String, data: Dictionary = {}) -> void:
	if STING_CUES.has(name):
		_sting_cue = name
		sting(String(STING_CUES[name]))
		return
	var id: String = String(CUE_ALIAS.get(name, name))
	if V10SfxBank.BANK.has(id):
		sfx(id, data.get("opts", {}))


func stop_cue(name: String) -> void:
	if name == _sting_cue or STING_CUES.has(name):
		_sting_cue = ""
		stop_music()
		return
	var id: String = String(CUE_ALIAS.get(name, name))
	pool.release_id(id, _t)
	for i in _players.size():
		if _slot_cue[i] == id and _players[i].playing:
			_players[i].stop()


# ── voice ────────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _voice_gate(hero: String, ctx: String) -> bool:
	if bool(settings.get("hero_off", {}).get(hero, false)):
		return false
	match String(settings.get("voice_mode", "lobby")):
		"off":
			return false
		"lobby":
			return ctx != "match"
	return true


func _default_voice(hero: String, kind: String) -> AudioStream:
	# only the 0.10 bank barks (riichi, rankup) resolve by default; the rest of the line registry arrives through voice_resolver
	# (TWAssets stream ids), because the shell may not name res://assets paths (lint ASSET_ID_ONLY)
	var p: = V10SfxBank.voice_path(hero, kind)
	return load(p) if ResourceLoader.exists(p) else null


func _text_for(hero: String, kind: String) -> String:
	if text_resolver.is_valid():
		return String(text_resolver.call(hero, kind))
	var s: = get_node_or_null("/root/Sfx")
	if s != null and s.get_script() != null:
		var v: Dictionary = s.get_script().get_script_constant_map().get("VOICED", {})
		if v.has(hero) and v[hero].has(kind) and not v[hero][kind].is_empty():
			return String(v[hero][kind][0])
	return ""


func _voice_stream(hero: String, kind: String) -> AudioStream:
	if voice_resolver.is_valid():
		return voice_resolver.call(hero, kind)
	return _default_voice(hero, kind)


func say(hero: String, kind: String, opts: Dictionary = {}) -> Dictionary:
	var ctx: String = String(opts.get("ctx", "lobby"))
	var st: AudioStream = _voice_stream(hero, kind)
	var dur: = float(opts["dur"]) if opts.has("dur") else (st.get_length() if st != null else TWVoiceQueue.DEFAULT_DUR_S)
	var r: = queue.request(hero, kind, _t, dur, opts)
	r["text"] = _text_for(hero, kind)
	r["audible"] = false
	r["subtitle"] = r["verdict"] != "dropped"
	if r["verdict"] == "dropped":
		voice_dropped.emit(hero, kind, String(r["reason"]))
	elif r["verdict"] == "play":
		_begin_voice(r["entry"])
		r["audible"] = _voice_gate(hero, ctx) and st != null
	return r


func _begin_voice(e: Dictionary) -> void:
	var hero: String = String(e["hero"])
	var kind: String = String(e["kind"])
	var st: = _voice_stream(hero, kind)
	var ctx: String = String(e.get("ctx", "lobby"))
	voice_current = e
	stats["voices_started"] += 1
	var audible: = st != null and _voice_gate(hero, ctx)
	if _voice_player != null:
		_voice_player.stop()
		if audible:
			_voice_player.stream = st
			_voice_player.play()
	if audible:   # a line that is only a subtitle does not pull the music down
		duck_music.set_source("voice", TWDuck.VOICE_MUSIC_DB)
		duck_sfx.set_source("voice", TWDuck.VOICE_SFX_DB)
	voice_started.emit(hero, _text_for(hero, kind), float(e["dur"]))


func voice_playing() -> bool:
	return queue.busy(_t)


func stop_voice() -> void:
	queue.cut(_t)
	voice_current = {}
	if _voice_player != null:
		_voice_player.stop()
	duck_music.clear_source("voice")
	duck_sfx.clear_source("voice")


func preload_partner(hero: String, kinds: Array) -> int:
	var n: = 0
	for k in kinds:
		if _voice_stream(hero, String(k)) != null:
			n += 1
	return n


# ── ducks of GDD 8.5 ─────────────────────────────────────────────────────────────────────────────────────────────────────

func duck_combo_t3(hold: float = 1.2) -> void:
	duck_music.set_source("combo_t3", TWDuck.COMBO_T3_MUSIC_DB, hold)


func ult(hero: String) -> Dictionary:
	duck_music.set_source("ult", TWDuck.ULT_MUSIC_DB, 1.6)
	haptic("ult")
	sfx("ult_cast")
	return say(hero, "ult_cast", {"line_id": "ult_cast", "ctx": "match"})


# summon reveal: music out in 150 ms, 400 ms of silence belongs to the caller's timeline, back in 0.6 s on end
func summon_reveal(on: bool) -> void:
	if on:
		duck_music.set_source("summon", TWDuck.SUMMON_DB, -1.0, TWDuck.SUMMON_ATTACK_S, TWDuck.SUMMON_RELEASE_S)
	else:
		duck_music.clear_source("summon")


# ── music facade (V10Music) ──────────────────────────────────────────────────────────────────────────────────────────────

func music_on() -> bool:
	return _slider_db("music") > -79.0


func music(screen_id: String, fade: float = 1.2) -> void:
	if music_on():
		V10Music.play_screen(screen_id, fade)


func tension(fill: float) -> void:
	if music_on():
		V10Music.set_tension(fill)


func fever(on: bool) -> void:
	if music_on() or not on:
		V10Music.fever(on)


func sting(id: String, resume: bool = false) -> void:
	if _slider_db("sfx") > -79.0:
		V10Music.sting(id, resume)


func stop_music() -> void:
	V10Music.stop()


# ── haptics (GDD 8.6 layer 1) ────────────────────────────────────────────────────────────────────────────────────────────

func haptic(kind: String) -> Array:
	var level: String = String(settings.get("haptics", "full"))
	var scale: = float(HAPTIC_SCALE.get(level, 1.0))
	var seq: Array = HAPTICS.get(kind, [])
	if scale <= 0.0 or seq.is_empty():
		return []
	if _last_haptic >= 0.0 and _t - _last_haptic < HAPTIC_MIN_GAP_S:
		return []
	_last_haptic = _t
	var out: Array = []
	for pu in seq:
		out.append([int(pu[0]), clampf(float(pu[1]) * scale, 0.05, 1.0), int(pu[2])])
	haptic_log.append([kind, out])
	if haptic_log.size() > 64:
		haptic_log.pop_front()
	for pu in out:
		if haptic_sink.is_valid():
			haptic_sink.call(pu[0], pu[1])
		else:
			Input.vibrate_handheld(pu[0], pu[1])
	return out
