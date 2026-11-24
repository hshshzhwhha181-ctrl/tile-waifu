class_name V10MjMusic
extends Node

# V10MjMusic — music of the mahjong modes (docs/MODES.md §6.5). Seamless loops, −16 LUFS, on the "Music" bus that
# Sfx ducks under heroine voice and cut-ins.
#   V10MjMusic.play(mode, fade = 1.0)      "classic" | "triples" | "connect" | "cube" | "riichi" | "raid" |
#                                          "moon" | "koikoi" | "garden" | "" (stop). Modes without their own loop yet
#                                          fall back (FALLBACK) so a screen is never silent.
#   V10MjMusic.set_tension(level)          riichi only: 0 base · 1 + layer 1 (someone declared riichi) ·
#                                          2 + layer 2 (two or more riichi). Layers are sample-locked to the base.
# The node lives at /root/V10MjMusic (created on first use). While it plays, Sfx's own music is stopped
# (Sfx.music("")) so two loops never overlap; the integrator restores the tab music on exit with Sfx.music(<tab>).

const DIR: = "res://assets/v10/mj/look/music/"
const TRACKS: = {"classic": "classic", "triples": "triples", "connect": "connect", "cube": "cube",
	"riichi": "riichi", "raid": "raid"}
# no loop of their own yet (budget, see README «Открытые вопросы»): nearest in mood
const FALLBACK: = {"moon": "riichi", "sanma": "riichi", "koikoi": "classic", "garden": "classic",
	"bridge": "classic", "memory": "classic", "blitz": "triples", "dragon": "raid"}
const LAYERS: = ["riichi_r1", "riichi_r2"]
const VOL_DB: = -6.0
const OFF_DB: = -60.0

var cur: = ""
var tension: = 0
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _layers: Array[AudioStreamPlayer] = []
var _tw: Tween


static var _inst: V10MjMusic

static func inst() -> V10MjMusic:
	if is_instance_valid(_inst):
		return _inst
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var n: = tree.root.get_node_or_null("V10MjMusic")
	if n == null:
		n = V10MjMusic.new()
		n.name = "V10MjMusic"
		n._setup()
		tree.root.add_child.call_deferred(n)
	_inst = n as V10MjMusic
	return _inst


static func track_for(mode: String) -> String:
	if TRACKS.has(mode):
		return TRACKS[mode]
	return TRACKS.get(FALLBACK.get(mode, ""), "")


static func path_for(track: String) -> String:
	return DIR + track + ".ogg"


static func play(mode: String, fade: = 1.0) -> String:
	var m: = inst()
	if m == null:
		return ""
	if m.is_inside_tree():
		m._play(mode, fade)
	else:
		m.call_deferred("_play", mode, fade)
	return track_for(mode)


static func set_tension(level: int) -> void:
	var m: = inst()
	if m:
		m._tension(clampi(level, 0, 2))


func _setup() -> void:
	if _a:
		return
	var bus: = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = bus
		add_child(p)
	for i in LAYERS.size():
		var l: = AudioStreamPlayer.new()
		l.bus = bus
		l.volume_db = OFF_DB
		add_child(l)
		_layers.append(l)


static func _music_on() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	return g == null or bool(g.S.get("music", true))


static func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path).duplicate()
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st


func _play(mode: String, fade: float) -> void:
	_setup()
	var tr: = track_for(mode)
	if not _music_on():
		tr = ""
	if tr == cur:
		return
	cur = tr
	var sfx = get_tree().root.get_node_or_null("Sfx") if is_inside_tree() else null
	if sfx and tr != "":
		sfx.music("", fade)
	var old: = _a if _a.playing else _b
	var nw: = _b if old == _a else _a
	if tr != "":
		var st: = _loop(path_for(tr))
		if st:
			nw.stream = st
			nw.volume_db = OFF_DB
			nw.play()
			create_tween().tween_property(nw, "volume_db", VOL_DB, fade)
			_start_layers(tr == "riichi", nw)
	else:
		_start_layers(false, null)
	if old.playing:
		var t: = create_tween()
		t.tween_property(old, "volume_db", OFF_DB, fade)
		t.tween_callback(old.stop)


func _start_layers(on: bool, base: AudioStreamPlayer) -> void:
	tension = 0
	for i in _layers.size():
		var l: = _layers[i]
		if on:
			var st: = _loop(path_for(LAYERS[i]))
			if st:
				l.stream = st
				l.volume_db = OFF_DB
				# same start frame as the base: the loops share length, so they stay locked
				l.play(base.get_playback_position() if base else 0.0)
		else:
			l.stop()


func _tension(level: int) -> void:
	tension = level
	if _tw and _tw.is_valid():
		_tw.kill()
	if not is_inside_tree():
		return
	_tw = create_tween().set_parallel()
	for i in _layers.size():
		var want: = VOL_DB if level > i else OFF_DB
		_tw.tween_property(_layers[i], "volume_db", want, 1.2 if level > i else 2.0)
