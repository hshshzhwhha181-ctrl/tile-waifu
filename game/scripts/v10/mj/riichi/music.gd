class_name V10MjRiichiMusic
extends Node

# Riichi music in layers (MODES §4.6): base → layer 1 at the first riichi of a hand → layer 2 at the second →
# a sting once when the last hand starts. Keys come from args.look.music {base, r1, r2, sting}; else the look lane's
# files (v10-mj-look: music/riichi*.ogg); else the game's play loop. Layers run in sync, only their volume moves.

const LOOK_BASE: = "res://assets/v10/mj/look/music/riichi.ogg"
const LOOK_R1: = "res://assets/v10/mj/look/music/riichi_r1.ogg"
const LOOK_R2: = "res://assets/v10/mj/look/music/riichi_r2.ogg"
const FALLBACK_BASE: = "res://assets/music/play.ogg"
const FALLBACK_STING: = "res://assets/sfx/reveal_sr.wav"
const ON_DB: = -9.0
const OFF_DB: = -60.0

var level: = 0          # 0 base, 1 first riichi, 2 second riichi
var sting_done: = false
var stings: = 0
var players: = []
var sting_player: AudioStreamPlayer
var paths: = {}
var enabled: = true

func setup(look: Dictionary) -> V10MjRiichiMusic:
	var m: Dictionary = look.get("music", {}) if look.get("music") is Dictionary else {}
	paths = {
		"base": _pick([m.get("base", ""), LOOK_BASE, FALLBACK_BASE]),
		"r1": _pick([m.get("r1", ""), LOOK_R1]),
		"r2": _pick([m.get("r2", ""), LOOK_R2]),
		"sting": _pick([m.get("sting", ""), FALLBACK_STING]),
	}
	return self

static func _pick(cands: Array) -> String:
	for c in cands:
		if String(c) != "" and ResourceLoader.exists(String(c)):
			return String(c)
	return ""

func start() -> void:
	if not enabled:
		return
	var ml: = Engine.get_main_loop()
	if ml is SceneTree and ml.root.has_node("Sfx") and ml.root.get_node("Sfx").has_method("music"):
		ml.root.get_node("Sfx").music("", 0.6)
	for k in ["base", "r1", "r2"]:
		var p: = AudioStreamPlayer.new()
		p.volume_db = ON_DB if k == "base" else OFF_DB
		add_child(p)
		players.append(p)
		if paths[k] != "":
			var st: AudioStream = load(paths[k])
			if st is AudioStreamOggVorbis:
				st = st.duplicate()
				st.loop = true
			p.stream = st
			p.play()
	sting_player = AudioStreamPlayer.new()
	sting_player.volume_db = -6.0
	add_child(sting_player)

func new_hand(last: bool) -> void:
	set_level(0)
	if last and not sting_done:
		sting_done = true
		stings += 1
		if sting_player and paths.sting != "":
			sting_player.stream = load(paths.sting)
			sting_player.play()

func on_riichi(n: int) -> void:
	set_level(clampi(n, 0, 2))

func set_level(n: int) -> void:
	level = n
	for i in players.size():
		var p: AudioStreamPlayer = players[i]
		var want: = ON_DB if i <= level else OFF_DB
		if i > 0 and i <= level:
			want = ON_DB - 2.0
		if p.is_inside_tree():
			create_tween().tween_property(p, "volume_db", want, 1.2 if want > p.volume_db else 2.0)
		else:
			p.volume_db = want

func stop() -> void:
	for p in players:
		if p.is_inside_tree():
			create_tween().tween_property(p, "volume_db", OFF_DB, 0.8)
