class_name V10Music
extends Node

# 0.10 music director: every screen/tab has its own loop (generated for Tile Waifu, one sonic identity:
# guzheng/koto, erhu, dizi, warm piano/Rhodes, soft synths, lo-fi drums), switched with a 0.8 s equal-power
# crossfade. No autoload needed: the first call creates one instance under /root (deferred-safe).
#
#   V10Music.play_screen("home")            screen id -> track (SCREENS); unknown ids fall back to the lobby
#   V10Music.play_track("pagoda")           a track id directly (TRACKS)
#   V10Music.motif("rin")                   heroine leitmotif as the screen music (profile/wardrobe/letters of her)
#   V10Music.set_tension(fill)              match only: 0..1 (tray fill / danger). >= 0.7 -> tense loop, < 0.5 -> calm
#   V10Music.fever(true/false)              fever layer: a second player fades in over the match loop, the base keeps
#                                           running at -22 dB underneath and comes back where it was
#   V10Music.sting("victory"|"defeat")      one-shot jingle; the loop dips to -30 dB while it plays, then stays down
#                                           (resume=false) or comes back (resume=true)
#   V10Music.stop(fade = 0.8)               silence
#   V10Music.current() -> String            the track id playing (for tests / dev overlay)
#
# Levels: all loops are mastered to -16 LUFS (stings -16, SFX -14). Players run on the "Music" bus, so
# Sfx.duck()/Sfx.duck_hold() (scripts/sfx.gd) duck V10 music exactly like the old loops. When V10Music starts a
# track it silences the 0.7 Sfx.music() loops (Sfx.music("")), so the two never overlap.
# Respects G.S.music (and G.S.sound for stings). Returning to a screen within RESUME_S seconds resumes the loop
# where it was instead of restarting it (feels like one continuous soundtrack while hopping between tabs).

const DIR: = "res://assets/v10/audio/music/"
const BUS: = "Music"
const FADE: = 0.8
const LEVEL_DB: = -6.0  # loops at -16 LUFS sit ~1 dB above the 0.7 menu loop played at -9 dB
const SILENT_DB: = -60.0
const FEVER_BASE_DB: = -22.0
const STING_DIP_DB: = -30.0
const RESUME_S: = 90.0
const TENSE_ON: = 0.7
const TENSE_OFF: = 0.5

# track id -> {file, loop, mood}. Lengths/loop points: assets/v10/audio/manifest.json.
const TRACKS: = {
	"lobby": {"file": "lobby.ogg", "loop": true, "mood": "главная/лобби — яркий хук на гучжэне, тёплое пиано, lo-fi 96 BPM"},
	"path": {"file": "path.ogg", "loop": true, "mood": "карта Пути — флейта дицзы, кото-остинато, «путешествие» 104 BPM"},
	"match_calm": {"file": "match_calm.ogg", "loop": true, "mood": "партия спокойно — lo-fi Rhodes + гучжэн, 88 BPM"},
	"match_tense": {"file": "match_tense.ogg", "loop": true, "mood": "партия напряжённо — тайко, тремоло гучжэна, 120 BPM"},
	"fever": {"file": "fever.ogg", "loop": true, "mood": "фивер — аниме-EDM, суперсо, эрху-хук, 128 BPM"},
	"summon": {"file": "summon.ogg", "loop": true, "mood": "призыв — челеста, арфа, тайко-сердцебиение, ожидание"},
	"shop": {"file": "shop.ogg", "loop": true, "mood": "Лавка — ночной рынок, пиццикато, пипа, свинг 108 BPM"},
	"salon": {"file": "salon.ogg", "loop": true, "mood": "Салон — city-pop/нео-соул, Rhodes, эрху, роскошь 84 BPM"},
	"phone": {"file": "phone.ogg", "loop": true, "mood": "Телефон — уютный bedroom lo-fi, музыкальная шкатулка 78 BPM"},
	"pagoda": {"file": "pagoda.ogg", "loop": true, "mood": "Пагода Луны — мистика, храмовые колокола, дицзы 82 BPM"},
	"duels": {"file": "duels.ogg", "loop": true, "mood": "Дуэли — battle-pop, трэп-хэты, пипа-рифф 140 BPM"},
	"motif_mc": {"file": "motif_mc.ogg", "loop": true, "mood": "лейтмотив Маджонг-тян — игривый кавай-поп, нефрит и розовый"},
	"motif_rin": {"file": "motif_rin.ogg", "loop": true, "mood": "лейтмотив Рин — чайная церемония, кото, сякухати"},
	"motif_hana": {"file": "motif_hana.ogg", "loop": true, "mood": "лейтмотив Ханы — спортивный солнечный поп-рок"},
	"motif_yue": {"file": "motif_yue.ogg", "loop": true, "mood": "лейтмотив Юэ — лунный двор, гуцинь, вальс"},
	"motif_nova": {"file": "motif_nova.ogg", "loop": true, "mood": "лейтмотив Новы — чиптюн + синтвейв + кото"},
	"sting_victory": {"file": "sting_victory.ogg", "loop": false, "mood": "победа — фанфара 9 с"},
	"sting_defeat": {"file": "sting_defeat.ogg", "loop": false, "mood": "поражение — мягкий, ободряющий 7,6 с"},
}

# screen / tab id -> track id. Ids follow the 0.10 screens (docs/0.10-spec.md); add aliases freely.
const SCREENS: = {
	"title": "lobby", "splash": "lobby", "auth": "lobby", "home": "lobby", "lobby": "lobby", "menu": "lobby",
	"levels": "path", "path": "path", "map": "path", "peaks": "path", "wander": "path",
	"play": "match_calm", "match": "match_calm", "zen": "match_calm", "modes": "path", "palm": "match_calm",
	"summon": "summon", "gacha": "summon", "banner": "summon",
	"shop": "shop", "lavka": "shop", "pass": "shop", "offers": "shop",
	"salon": "salon", "room": "salon", "wardrobe": "salon", "collection": "salon", "album": "salon",
	"phone": "phone", "chat": "phone", "mail": "phone", "letters": "phone", "feed": "phone",
	"pagoda": "pagoda", "tower": "pagoda",
	"duels": "duels", "duel": "duels", "league": "duels", "tourney": "duels", "event": "duels", "ranked": "duels",
	"profile": "lobby", "settings": "lobby", "glossary": "lobby", "tutorial": "lobby",
}

const HEROES: = ["mc", "rin", "hana", "yue", "nova"]

static var _inst: V10Music = null

var _a: AudioStreamPlayer  # two base players, crossfaded
var _b: AudioStreamPlayer
var _fever: AudioStreamPlayer
var _sting_p: AudioStreamPlayer
var _cur: = ""
var _screen: = ""
var _tense: = false
var _fever_on: = false
var _pos: = {}  # track id -> [position_s, left_at_ticks_s]
var _cache: = {}
var _tw: Dictionary = {}  # player -> Tween
var _pending: Array = []


static func inst() -> V10Music:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree: = Engine.get_main_loop() as SceneTree
	_inst = V10Music.new()
	_inst.name = "V10Music"
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(_inst)
	return _inst


static func play_screen(screen_id: String, fade: = FADE) -> void :
	var me: = inst()
	me._screen = screen_id
	me._tense = false
	me._call("_play", [String(SCREENS.get(screen_id, "lobby")), fade])


static func play_track(track_id: String, fade: = FADE) -> void :
	inst()._call("_play", [track_id, fade])


static func motif(hero: String, fade: = FADE) -> void :
	inst()._call("_play", ["motif_" + (hero if hero in HEROES else "mc"), fade])


static func set_tension(fill: float) -> void :
	var me: = inst()
	if not me._cur.begins_with("match"):
		return
	var want: = me._tense
	if fill >= TENSE_ON:
		want = true
	elif fill < TENSE_OFF:
		want = false
	if want != me._tense:
		me._tense = want
		me._call("_play", ["match_tense" if want else "match_calm", 1.2])


static func fever(on: bool) -> void :
	inst()._call("_set_fever", [on])


static func sting(id: String, resume: = false) -> void :
	inst()._call("_sting", [id, resume])


static func stop(fade: = FADE) -> void :
	inst()._call("_play", ["", fade])


static func current() -> String:
	return inst()._cur


static func track_for(screen_id: String) -> String:
	return String(SCREENS.get(screen_id, "lobby"))


static func path_of(track_id: String) -> String:
	return DIR + String(TRACKS[track_id]["file"]) if TRACKS.has(track_id) else ""


# ---------------------------------------------------------------------------------------------------------

func _call(method: String, args: Array) -> void :
	if is_inside_tree():
		callv(method, args)
	else:
		_pending.append([method, args])


func _ready() -> void :
	_ensure_bus()
	_a = _mk("A")
	_b = _mk("B")
	_fever = _mk("Fever")
	_sting_p = _mk("Sting")
	_sting_p.bus = "Master"  # stings are not ducked by Sfx.duck (they ARE the moment)
	for p in _pending:
		callv(p[0], p[1])
	_pending.clear()


func _exit_tree() -> void :
	if _inst == self:
		_inst = null


func _mk(n: String) -> AudioStreamPlayer:
	var p: = AudioStreamPlayer.new()
	p.name = n
	p.bus = BUS
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _ensure_bus() -> void :
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var i: = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")


func _music_on() -> bool:
	var g: = get_node_or_null("/root/G")
	if g == null:
		return true
	return bool(g.S.get("music", true))


func _sound_on() -> bool:
	var g: = get_node_or_null("/root/G")
	if g == null:
		return true
	return bool(g.S.get("sound", true))


func _stream(track_id: String) -> AudioStream:
	if not TRACKS.has(track_id):
		return null
	if not _cache.has(track_id):
		var st: AudioStream = load(path_of(track_id))
		if st == null:
			return null
		st = st.duplicate()
		if st is AudioStreamOggVorbis:
			st.loop = bool(TRACKS[track_id]["loop"])
		_cache[track_id] = st
	return _cache[track_id]


func _fade(p: AudioStreamPlayer, to_db: float, t: float, stop_after: = false) -> void :
	if _tw.has(p) and _tw[p] != null and _tw[p].is_valid():
		_tw[p].kill()
	if t <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw: = create_tween()
	# equal-power feel: fade in on an ease-out curve, fade out on ease-in (dB domain)
	tw.tween_property(p, "volume_db", to_db, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if to_db > p.volume_db else Tween.EASE_IN)
	if stop_after:
		tw.tween_callback(p.stop)
	_tw[p] = tw


func _silence_legacy() -> void :
	var s: = get_node_or_null("/root/Sfx")
	if s != null and String(s.get("cur_music")) != "":
		s.music("", 0.6)


func _play(track_id: String, fade: float) -> void :
	if track_id == _cur and (track_id == "" or _a.playing or _b.playing):
		return
	var old: = _a if _a.playing and (not _b.playing or _a.volume_db >= _b.volume_db) else _b
	var nw: = _b if old == _a else _a
	if _cur != "" and old.playing:
		_pos[_cur] = [old.get_playback_position(), Time.get_ticks_msec() / 1000.0]
	if _fever_on:
		_set_fever(false)
	_cur = track_id
	if old.playing:
		_fade(old, SILENT_DB, fade, true)
	if track_id == "" or not _music_on():
		return
	var st: = _stream(track_id)
	if st == null:
		push_warning("V10Music: no track %s" % track_id)
		return
	_silence_legacy()
	nw.stop()
	nw.stream = st
	nw.volume_db = SILENT_DB
	var from: = 0.0
	if _pos.has(track_id):
		var rec: Array = _pos[track_id]
		if Time.get_ticks_msec() / 1000.0 - float(rec[1]) < RESUME_S:
			from = fmod(float(rec[0]), maxf(st.get_length(), 0.01))
	nw.play(from)
	_fade(nw, LEVEL_DB, fade)


func _base() -> AudioStreamPlayer:
	return _a if _a.playing and (not _b.playing or _a.volume_db >= _b.volume_db) else _b


func _set_fever(on: bool) -> void :
	if on == _fever_on:
		return
	_fever_on = on
	var base: = _base()
	if on:
		if not _music_on():
			return
		_fever.stream = _stream("fever")
		_fever.volume_db = SILENT_DB
		_fever.play()
		_fade(_fever, LEVEL_DB + 1.0, 0.35)
		if base.playing:
			_fade(base, FEVER_BASE_DB, 0.35)
	else:
		if _fever.playing:
			_fade(_fever, SILENT_DB, 0.9, true)
		if base.playing:
			_fade(base, LEVEL_DB, 0.9)


func _sting(id: String, resume: bool) -> void :
	var key: = id if id.begins_with("sting_") else "sting_" + id
	if not _sound_on():
		return
	var st: = _stream(key)
	if st == null:
		push_warning("V10Music: no sting %s" % key)
		return
	if _fever_on:
		_set_fever(false)
	var base: = _base()
	if base.playing:
		_fade(base, STING_DIP_DB, 0.25)
	_sting_p.stream = st
	_sting_p.volume_db = LEVEL_DB + 1.0
	_sting_p.play()
	if resume and base.playing:
		var tw: = create_tween()
		tw.tween_interval(maxf(0.5, st.get_length() - 0.6))
		tw.tween_callback(func(): _fade(base, LEVEL_DB, 1.2))


# dev / tests
func debug_state() -> Dictionary:
	return {"cur": _cur, "screen": _screen, "tense": _tense, "fever": _fever_on,
		"a": [_a.playing, _a.volume_db], "b": [_b.playing, _b.volume_db],
		"fever_p": [_fever.playing, _fever.volume_db], "sting_p": [_sting_p.playing]}
