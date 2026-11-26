class_name V10Voice
extends Node

# 0.10 Russian voices of the five founders (docs/AUDIO_BIBLE.md §13): 24 lines each, one ogg per line.
# No autoload needed: the first call creates one instance under /root (deferred-safe), like V10SfxBank.
#
#   V10Voice.play(hero, slot, opts = {}) -> String    plays the line, ducks music -8 dB for its length, emits
#                                                     Sfx.voice_started(hero, text, dur) (subtitle + rig lip-sync),
#                                                     returns the subtitle ("" when the line is not allowed now)
#       opts: {"aff": int}       close1..3 need Симпатия >= CLOSE_AFF (whispered lines, UX_RULES §8.3)
#             {"force": true}    skip the per-slot cooldown (tutorial, summon, cut-in)
#   V10Voice.tap(hero, zone, opts) -> String          rig tap zone (head / hair / armL / armR / outfit) -> line;
#                                                     the 3rd such tap within SPAM_WINDOW s plays tap_spam. Dead zones
#                                                     ("none": bust, hips) and "bg" return "" and never count as taps,
#                                                     so V10LiveRig.tapped can be wired straight to this
#   V10Voice.visit()                                 new visit of the home screen: resets the idle-call cap (2 a visit)
#   V10Voice.combo(hero, n) -> String                 combo showcase ×5 / ×10 / ×20 (HUD_V2 §7.3)
#   V10Voice.bind_rig(rig, hero)                     lip-sync: while this hero speaks, rig.set_mouth_level(0..1) every frame
#                                                     from the line's envelope (manifest "lip", 30 Hz); -1 hands the mouth back
#   V10Voice.mouth_level(hero) -> float              the same level for any other face (-1 when she is silent)
#   V10Voice.text(hero, slot) / path(hero, slot) / length_of(hero, slot) / has(hero, slot)
#   V10Voice.lines(hero) -> Array of slot ids that have a file
#
# Data: res://assets/v10/voice/manifest.json (built by tools/audio/voice_build.py): per hero the voice id and model
# that made it, per line text, file, duration, LUFS, peak, ASR check (Whisper + Russian CTC character error rate).
# Respects G.S.sound and G.S.voice. One line at a time: a new line stops the previous one.

const DIR: = "res://assets/v10/voice/"
const MANIFEST: = DIR + "manifest.json"
const HEROES: = ["mc", "rin", "hana", "yue", "nova"]
const SLOTS: = ["greet", "tap_head", "tap_hair", "tap_prop", "tap_acc", "tap_spam", "combo5", "combo10", "combo20",
	"priem", "tag", "win", "lose", "summon", "birthday", "comeback", "idle", "danger", "close1", "close2", "close3",
	"tut1", "tut2", "tut3"]
const CLOSE: = ["close1", "close2", "close3"]
const CLOSE_AFF: = 6
# rig tap zones (V10LiveRig.tapped) -> slot; "bg" has no voiced line (the rig only looks at the point)
const ZONE_SLOT: = {"head": "tap_head", "hair": "tap_hair", "armL": "tap_prop", "armR": "tap_prop", "outfit": "tap_acc"}
const COOLDOWN: = 60.0      # the same tap reaction at most once a minute (UX_RULES §8.2)
const SPAM_WINDOW: = 2.0    # third tap within 2 s -> tap_spam (0.10-spec D4.4)
const DUCK_DB: = -8.0       # music under a line (UX_RULES §7.4)
const IDLE_PER_VISIT: = 2   # the idle call by name, at most twice a visit (UX_RULES §8.4)
const COOLDOWN_SLOTS: = ["tap_head", "tap_hair", "tap_prop", "tap_acc", "tap_spam", "idle", "danger", "combo5",
	"combo10", "combo20", "close1", "close2", "close3"]

static var _inst: V10Voice = null
static var _data: = {}

var _player: AudioStreamPlayer
var _cache: = {}
var _last: = {}       # hero:slot -> seconds
var _taps: = {}       # hero -> Array of tap times
var _pending: Array = []
var _now_override: = -1.0   # selftest clock
var _cur_hero: = ""
var _cur_lip: = ""
var _rigs: = {}       # hero -> WeakRef of a V10LiveRig (or anything with set_mouth_level)
var _rig_live: = {}   # hero -> true while we drive its mouth
var _idle_n: = 0


static func inst() -> V10Voice:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree: = Engine.get_main_loop() as SceneTree
	_inst = V10Voice.new()
	_inst.name = "V10Voice"
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_inst)
	return _inst


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(MANIFEST):
		var j = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if j is Dictionary:
			_data = j
	return _data


static func _line(hero: String, slot: String) -> Dictionary:
	var h: Dictionary = data().get("heroes", {}).get(hero, {})
	return h.get("lines", {}).get(slot, {})


static func has(hero: String, slot: String) -> bool:
	var l: = _line(hero, slot)
	return not l.is_empty() and ResourceLoader.exists(DIR + String(l.get("file", "")))


static func text(hero: String, slot: String) -> String:
	return String(_line(hero, slot).get("text", ""))


static func path(hero: String, slot: String) -> String:
	var l: = _line(hero, slot)
	return DIR + String(l.get("file", "")) if not l.is_empty() else ""


static func length_of(hero: String, slot: String) -> float:
	return float(_line(hero, slot).get("dur", 0.0))


static func lines(hero: String) -> Array:
	var out: = []
	for s in SLOTS:
		if has(hero, s):
			out.append(s)
	return out


static func visit() -> void:
	# a new visit of the home / room screen: the idle call may sound twice again
	inst()._idle_n = 0


static func bind_rig(rig: Node, hero: String) -> void:
	if rig == null:
		inst()._rigs.erase(hero)
	else:
		inst()._rigs[hero] = weakref(rig)


static func mouth_level(hero: String) -> float:
	var v: = inst()
	if v._player == null or not v._player.playing or v._cur_hero != hero or v._cur_lip == "":
		return -1.0
	var hz: = float(data().get("lip_hz", 30))
	var i: = int(v._player.get_playback_position() * hz)
	if i < 0 or i >= v._cur_lip.length():
		return 0.0
	return float(v._cur_lip.unicode_at(i) - 48) / 9.0


static func play(hero: String, slot: String, opts: = {}) -> String:
	return inst()._play(hero, slot, opts)


static func tap(hero: String, zone: String, opts: = {}) -> String:
	return inst()._tap(hero, zone, opts)


static func combo(hero: String, n: int, opts: = {}) -> String:
	var slot: = "combo20" if n >= 20 else ("combo10" if n >= 10 else ("combo5" if n >= 5 else ""))
	if slot == "":
		return ""
	return play(hero, slot, opts)


# ---------------------------------------------------------------------------------------------------------

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	add_child(_player)
	for p in _pending:
		_start(p[0], p[1], p[2])
	_pending.clear()


func _now() -> float:
	return _now_override if _now_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func _g_flag(key: String) -> bool:
	var g: = get_node_or_null("/root/G") if is_inside_tree() else null
	if g == null:
		return true
	return bool(g.S.get(key, true))


# returns "" when the line is gated (unknown, cooldown, closeness); otherwise plays it and returns its subtitle
func _play(hero: String, slot: String, opts: Dictionary) -> String:
	var l: = _line(hero, slot)
	if l.is_empty():
		return ""
	if slot in CLOSE and int(opts.get("aff", 0)) < CLOSE_AFF:
		return ""
	var key: = hero + ":" + slot
	var t: = _now()
	if not opts.get("force", false) and slot in COOLDOWN_SLOTS and _last.has(key) and t - float(_last[key]) < COOLDOWN:
		return ""
	if slot == "idle" and not opts.get("force", false):
		if _idle_n >= IDLE_PER_VISIT:
			return ""
		_idle_n += 1
	_last[key] = t
	var txt: = String(l.get("text", ""))
	if _player == null:
		_pending.append([hero, slot, txt])
	else:
		_start(hero, slot, txt)
	return txt


func _tap(hero: String, zone: String, opts: Dictionary) -> String:
	# only taps on her voiced zones count: a dead zone ("none": bust, hips — V10LiveRig.zone_at) or the background
	# never gets a line and never adds up to tap_spam (UX_RULES §8.2: those taps get no reaction at all)
	if not ZONE_SLOT.has(zone):
		return ""
	var t: = _now()
	var arr: Array = _taps.get(hero, [])
	arr = arr.filter(func(x): return t - float(x) <= SPAM_WINDOW)
	arr.append(t)
	_taps[hero] = arr
	if arr.size() >= 3:
		_taps[hero] = []
		return _play(hero, "tap_spam", opts)
	return _play(hero, ZONE_SLOT[zone], opts)


func _start(hero: String, slot: String, txt: String) -> void:
	var p: = path(hero, slot)
	var dur: = length_of(hero, slot)
	var sfx: = get_node_or_null("/root/Sfx")
	if sfx != null and sfx.get("voice") is AudioStreamPlayer and sfx.voice.playing:
		sfx.voice.stop()   # an old 0.9 line must not talk over a 0.10 one
	# one line at a time: the previous line stops even when this one is subtitle-only (voice or sound off),
	# otherwise it would keep talking while the lip-sync target already moved to the new speaker
	_player.stop()
	_cur_hero = hero
	_cur_lip = String(_line(hero, slot).get("lip", ""))
	if _g_flag("sound") and _g_flag("voice") and ResourceLoader.exists(p):
		if not _cache.has(p):
			_cache[p] = load(p)
		var st: AudioStream = _cache[p]
		if st != null:
			_player.stream = st
			_player.play()
			dur = st.get_length()
			if sfx != null and sfx.has_method("duck"):
				sfx.duck(DUCK_DB, dur + 0.3)
	if sfx != null and sfx.has_signal("voice_started"):
		sfx.voice_started.emit(hero, txt, maxf(dur, 1.0))


func _process(_dt: float) -> void:
	for h in _rigs.keys():
		var r = _rigs[h].get_ref()
		if r == null:
			_rigs.erase(h)
			_rig_live.erase(h)
			continue
		var lv: = mouth_level(h)
		if lv >= 0.0:
			r.set_mouth_level(lv)
			_rig_live[h] = true
		elif _rig_live.get(h, false):
			r.set_mouth_level(-1.0)
			_rig_live.erase(h)


func is_playing() -> bool:
	return _player != null and _player.playing


func stop() -> void:
	if _player != null:
		_player.stop()
