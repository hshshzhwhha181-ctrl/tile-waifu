extends Node

# Self-test for the 0.10 audio lane (V10Music + V10SfxBank + assets/v10/audio). Run:
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --audio-driver Dummy --path game \
#       res://scripts/v10/audio/v10_audio_selftest.tscn
# Prints "V10AUDIO OK <passed>/<total>" or "V10AUDIO FAIL ..." and quits with code 0/1.
# Checks: every track/sfx/voice id resolves and loads; loops are flagged as loops and stings are not;
# loop lengths match manifest.json (±0.05 s); every SCREENS id maps to a real track; tap-class SFX are short;
# crossfade + fever + tension + sting state machine; per-id polyphony limit and retrigger gap.

const MANIFEST: = "res://assets/v10/audio/manifest.json"
const TAP_IDS: = ["tile_click", "tile_select", "tile_deny", "btn_hover", "btn_press", "tab_switch", "page_turn"]

var ok: = 0
var total: = 0
var fails: = []


func _check(cond: bool, what: String) -> void :
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)


func _ready() -> void :
	await get_tree().process_frame
	_assets()
	await _runtime()
	if fails.is_empty():
		print("V10AUDIO OK %d/%d" % [ok, total])
	else:
		print("V10AUDIO FAIL %d/%d" % [ok, total])
		for f in fails:
			print("  - ", f)
	get_tree().quit(0 if fails.is_empty() else 1)


func _assets() -> void :
	var man: Dictionary = {}
	var f: = FileAccess.open(MANIFEST, FileAccess.READ)
	_check(f != null, "manifest.json opens")
	if f != null:
		man = JSON.parse_string(f.get_as_text())
	var mtracks: Dictionary = man.get("music", {})
	for id in V10Music.TRACKS:
		var path: = V10Music.path_of(id)
		_check(ResourceLoader.exists(path), "track exists: " + id)
		var st: AudioStream = load(path)
		_check(st != null and st.get_length() > 1.0, "track loads: " + id)
		if st == null:
			continue
		var want_loop: bool = V10Music.TRACKS[id]["loop"]
		if st is AudioStreamOggVorbis:
			_check(st.loop == want_loop, "import loop flag %s == %s" % [id, want_loop])
		_check(mtracks.has(id), "manifest has " + id)
		if mtracks.has(id):
			_check(bool(mtracks[id]["loop"]) == want_loop, "manifest loop flag " + id)
			_check(absf(float(mtracks[id]["len"]) - st.get_length()) < 0.06, "length matches manifest: %s %.2f vs %.2f" % [id, st.get_length(), float(mtracks[id]["len"])])
			if want_loop:
				_check(float(mtracks[id].get("seam_flux_pct", 100)) <= 90.0, "loop seam inaudible (flux pct <= 90): " + id)
	for sid in V10Music.SCREENS:
		_check(V10Music.TRACKS.has(V10Music.SCREENS[sid]), "screen %s -> real track" % sid)
	for h in V10Music.HEROES:
		_check(V10Music.TRACKS.has("motif_" + h), "motif for " + h)
	for id in V10SfxBank.BANK:
		for v in V10SfxBank.BANK[id]["v"]:
			var p: = V10SfxBank.path_of(v)
			_check(ResourceLoader.exists(p), "sfx exists: " + v)
			var st: AudioStream = load(p)
			_check(st != null and st.get_length() > 0.05, "sfx loads: " + v)
			if st is AudioStreamOggVorbis:
				_check(not st.loop, "sfx not looped: " + v)
			if id in TAP_IDS and st != null:
				_check(st.get_length() <= 0.5, "tap sfx short (<= 0.5 s): %s %.2f" % [v, st.get_length()])
	for id in V10SfxBank.BANK:
		var e: Dictionary = V10SfxBank.BANK[id]
		if e.has("vdb"):
			_check(e["vdb"].size() == e["v"].size(), "vdb per variant: " + id)
	for h in V10SfxBank.HEROES:
		for k in V10SfxBank.VOICE_KINDS:
			var p: = V10SfxBank.voice_path(h, k)
			_check(ResourceLoader.exists(p) and load(p) != null, "voice: %s %s" % [h, k])
	var demo: GDScript = load("res://scripts/v10/audio/v10_audio_demo.gd")
	_check(demo != null and demo.can_instantiate(), "demo script parses")
	_check(is_equal_approx(V10SfxBank.combo_pitch(1), 1.0) and is_equal_approx(V10SfxBank.combo_pitch(13), 2.0) and is_equal_approx(V10SfxBank.combo_pitch(30), 2.0), "combo ladder 1..octave")


func _frames(n: int) -> void :
	for i in n:
		await get_tree().process_frame


func _secs(t: float) -> void :
	await get_tree().create_timer(t).timeout


func _runtime() -> void :
	# music state machine
	V10Music.play_screen("home")
	await _frames(3)
	var m: = V10Music.inst()
	_check(m.is_inside_tree(), "V10Music self-installs under /root")
	_check(V10Music.current() == "lobby", "home -> lobby (%s)" % V10Music.current())
	await _secs(1.0)
	var st: Dictionary = m.debug_state()
	_check((st["a"][0] and st["a"][1] > -7.0) or (st["b"][0] and st["b"][1] > -7.0), "lobby faded in to level: %s" % str(st))
	V10Music.play_screen("shop")
	await _frames(2)
	st = m.debug_state()
	_check(st["a"][0] and st["b"][0], "crossfade: both players run during the 0.8 s fade")
	await _secs(1.0)
	st = m.debug_state()
	_check(not (st["a"][0] and st["b"][0]), "crossfade done: old player stopped")
	_check(V10Music.current() == "shop", "shop track")
	V10Music.play_screen("shop")
	_check(V10Music.current() == "shop", "same screen again is a no-op")
	V10Music.play_screen("match")
	await _secs(0.9)
	V10Music.set_tension(0.8)
	_check(V10Music.current() == "match_tense", "tension 0.8 -> tense")
	V10Music.set_tension(0.6)
	_check(V10Music.current() == "match_tense", "hysteresis: 0.6 stays tense")
	V10Music.set_tension(0.3)
	_check(V10Music.current() == "match_calm", "tension 0.3 -> calm")
	await _secs(1.3)
	V10Music.fever(true)
	await _secs(0.6)
	st = m.debug_state()
	_check(st["fever"] and st["fever_p"][0] and st["fever_p"][1] > -7.0, "fever layer up: %s" % str(st))
	var base_db: float = st["a"][1] if st["a"][0] else st["b"][1]
	_check(base_db <= -20.0, "base ducked under fever (%.1f dB)" % base_db)
	# tray fills up during fever: calm -> tense must keep the fever layer on top, the new base comes in ducked
	V10Music.set_tension(0.8)
	await _secs(1.4)
	st = m.debug_state()
	_check(V10Music.current() == "match_tense" and st["fever"] and st["fever_p"][0] and st["fever_p"][1] > -7.0, "tension switch keeps fever: %s" % str(st))
	base_db = st["a"][1] if st["a"][0] else st["b"][1]
	_check(int(st["a"][0]) + int(st["b"][0]) == 1 and base_db <= -20.0, "tense base ducked under fever: %s" % str(st))
	V10Music.set_tension(0.2)
	await _secs(1.4)
	V10Music.fever(false)
	await _secs(1.1)
	st = m.debug_state()
	_check(not st["fever_p"][0], "fever layer stopped")
	V10Music.sting("victory")
	await _frames(2)
	st = m.debug_state()
	_check(st["sting_p"][0], "victory sting plays")
	await _secs(0.5)
	st = m.debug_state()
	_check(maxf(st["a"][1], st["b"][1]) <= -25.0, "loop dips under the sting: %s" % str(st))
	# "next level" right after the victory sting: same track -> the dipped loop must come back up
	V10Music.play_screen("match")
	await _secs(1.0)
	st = m.debug_state()
	_check(V10Music.current() == "match_calm" and maxf(st["a"][1], st["b"][1]) > -7.0, "same track after sting comes back to level: %s" % str(st))
	# defeat sting with resume, then a tab hop before it ends: the old loop must not be revived
	V10Music.sting("defeat", true)
	await _secs(0.3)
	V10Music.play_screen("shop")
	await _secs(float(load(V10Music.path_of("sting_defeat")).get_length()) + 0.6)
	st = m.debug_state()
	_check(V10Music.current() == "shop" and int(st["a"][0]) + int(st["b"][0]) == 1, "sting resume does not revive a faded-out loop: %s" % str(st))
	V10Music.play_screen("summon")
	_check(V10Music.current() == "summon", "summon track")
	V10Music.motif("yue")
	_check(V10Music.current() == "motif_yue", "motif")
	V10Music.play_screen("no_such_screen")
	_check(V10Music.current() == "lobby", "unknown screen falls back to lobby")
	await _secs(1.0)
	st = m.debug_state()
	_check(int(st["a"][0]) + int(st["b"][0]) == 1, "rapid tab hopping settles on one player: %s" % str(st))
	# legacy bus: V10 plays on Music so Sfx.duck works
	_check(AudioServer.get_bus_index("Music") >= 0, "Music bus exists")
	_check(m.get_node("A").bus == "Music" and m.get_node("Fever").bus == "Music", "players on Music bus")
	# sfx bank
	V10SfxBank.play("tile_click")
	await _frames(2)
	var b: = V10SfxBank.inst()
	_check(b.is_inside_tree(), "V10SfxBank self-installs under /root")
	_check(b.active_of("tile_click") == 1, "tile_click plays")
	for i in 12:
		V10SfxBank.play("card_flip", {"force": true})
	_check(b.active_of("card_flip") <= int(V10SfxBank.BANK["card_flip"]["max"]), "polyphony limit card_flip (%d)" % b.active_of("card_flip"))
	V10SfxBank.play("rank_up")
	V10SfxBank.play("rank_up")
	_check(b.active_of("rank_up") == 1, "retrigger gap merges spam")
	_check(is_equal_approx(V10SfxBank.combo(3), pow(2.0, 2.0 / 12.0)), "combo(3) = +2 semitones")
	var txt: = V10SfxBank.voice("rin", "riichi")
	_check(txt != "" or get_node_or_null("/root/Sfx") == null, "voice returns subtitle")
	V10Music.stop()
	await _secs(1.0)
	st = m.debug_state()
	_check(not st["a"][0] and not st["b"][0], "stop silences")
