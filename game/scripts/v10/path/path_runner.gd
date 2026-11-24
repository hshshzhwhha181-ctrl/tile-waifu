extends Node

# Standalone runner of the 0.10 Path map (scene res://scripts/v10/path/path_demo.tscn). It hosts the REAL main
# (topbar, navbar, overlay, toasts) and swaps its screen for V10PathMap, so screenshots show the real chrome.
# Run with XDG_DATA_HOME pointing to a scratch dir so the player's save is never touched.
#
#   --path_selftest=1                      model + boosters + jam + UI tree checks → «PATH SELFTEST ok/total»
#   --path_state=fresh|mid|peaks|legend|arc2   progress preset (default mid)
#   --path_shots=<dir> --path_seq=map,card,card_peak,... --path_name=<prefix>   screenshots
#   (also pass a bare --shots so main skips its title splash)

const State = preload("res://scripts/v10/path/path_state.gd")
const Boost = preload("res://scripts/v10/path/path_boosters.gd")
const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const PathMap = preload("res://scripts/v10/path/path_map.gd")
const Card = preload("res://scripts/v10/path/path_card.gd")
const Dlg = preload("res://scripts/v10/path/path_dialogs.gd")
const PFx = preload("res://scripts/v10/path/path_fx.gd")
const Jam = preload("res://scripts/v10/path/path_jam.gd")

var a: = {}
var main
var map


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	if a.has("path_selftest"):
		var st: = load("res://scripts/v10/path/path_selftest.gd").new()
		add_child(st)
		var r: Array = await st.run()
		get_tree().quit(0 if int(r[0]) == int(r[1]) else 1)
		return
	State.dry = true
	preset(str(a.get("path_state", "mid")))
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	open_map({})
	if a.has("path_shots"):
		await shots(str(a.path_shots), str(a.get("path_seq", "map")).split(","), str(a.get("path_name", "path")))
		get_tree().quit()


func open_map(args: Dictionary) -> void:
	for c in main.overlay.get_children():
		c.queue_free()
	if main.screen and is_instance_valid(main.screen):
		main.screen.queue_free()
	map = Control.new()
	map.set_script(PathMap)
	map.size = Vector2(main.W, main.H)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.screen_root.add_child(map)
	main.screen = map
	main.screen_id = "v10path"
	PathMap.on_play = func(i, cfg):
		main.toast("Старт %s%s%s" % [Gen.code(i), " · облегчённый стол" if cfg.get("assist", false) else "", " · бустеры: " + ", ".join(cfg.get("v10_boost", [])) if not cfg.get("v10_boost", []).is_empty() else ""])
	map.build(main, args)
	if main.has_method("_select_tab"):
		main._select_tab("levels")
	print("PATH map build %.1f ms, live chapters %d, nodes %d" % [float(map.get_meta("build_ms")), map.sections.size(), map.nodes.size()])


# ------------------------------------------------------------------ presets

func preset(kind: String) -> void:
	var S: Dictionary = G.S
	S.intro_done = true
	S.profile_done = true
	S.gems = 1200
	S.coins = 3400
	S.stars = {}
	S.unlocked = 1
	S.erase("v10_levels")
	S.erase("v10_boosters")
	State.st()
	Boost.st()
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	var upto: = 0
	match kind:
		"fresh":
			upto = 0
		"mid":
			upto = 36
		"peaks":
			upto = 79
		"legend":
			upto = 99
		"arc2":
			upto = 131
	for i in upto:
		if not Gen.is_peak(i):
			State.on_win(i, 1 + rng.randi() % 3 if i % 7 != 0 else 3)
	for i in upto:
		if Gen.is_peak(i) and State.state_of(i) == "open" and rng.randf() < 0.5:
			State.on_win(i, 1 + rng.randi() % 3)
	match kind:
		"mid":
			Boost.st().flame = 2
			Boost.st().lantern = 1
			State.st().chests["0"] = 3
			State.st().chests["1"] = 1
			State.st().daily_full = {"day": State.day_key(), "n": 11}
		"peaks":
			Boost.st().flame = 3
			State.st().summits = 9
			for gc in 7:
				State.st().chests[str(gc)] = 3
		"legend":
			State.legend_rec(0).tries = 5
			Boost.st().flame = 1
			for gc in 9:
				State.st().chests[str(gc)] = 3
		"arc2":
			State.legend_rec(0).tries = 6
			State.legend_rec(0).bypass = true
			for gc in 13:
				State.st().chests[str(gc)] = 3
	State.st().fails = {}
	print("PATH preset %s: unlocked %d, current %s, flame %d" % [kind, int(S.unlocked), Gen.code(State.current()), Boost.flame()])


# ------------------------------------------------------------------ screenshots

func shots(dir: String, seq: Array, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.4).timeout
	var k: = 0
	for step in seq:
		var wait: = await act(str(step))
		await get_tree().create_timer(wait).timeout
		var img: = get_viewport().get_texture().get_image()
		var p: = "%s/%s_%02d_%s.png" % [dir, name, k, str(step).replace(":", "-")]
		img.save_png(p)
		print("PATH shot ", p)
		k += 1


func _first_peak(open: bool) -> int:
	for i in State.released_total():
		if Gen.is_peak(i) and (not open or State.state_of(i) == "open"):
			return i
	return 7


func act(step: String) -> float:
	var parts: = step.split(":")
	var cmd: = parts[0]
	match cmd:
		"map":
			return 0.4
		"close":
			for c in main.overlay.get_children():
				c.queue_free()
			return 0.4
		"card":
			var i: = int(parts[1]) if parts.size() > 1 else State.current()
			map.scroll_to_level(i, false)
			Card.open(main, map, i)
			return 1.0
		"card_peak":
			var p: = _first_peak(true)
			map.scroll_to_level(p, false)
			Card.open(main, map, p)
			return 1.2
		"card_intro":
			var ii: = 30
			for k in Gen.INTRO:
				if int(k) < State.unlocked() and int(k) > 20:
					ii = int(k)
			State.st().seen_mech = []
			Card.open(main, map, ii)
			return 1.6
		"arcs":
			Dlg.arcs_sheet(main, map)
			return 1.0
		"assist":
			var j: = State.current()
			State.st().fails[str(j)] = 2
			Dlg.assist(main, j, Callable(), Callable())
			return 1.2
		"fail", "fail_peak":
			var f: = State.current() if cmd == "fail" else _first_peak(true)
			var cfg: = State.play_cfg(f)
			var log: = Jam.demo_fail_log(cfg, 3)
			State.on_fail(f)
			var res: = State.on_fail(f)
			var jam: = Jam.find(cfg, log)
			Dlg.fail_window(main, f, res, jam, Callable(), Callable())
			return 1.0
		"summit":
			var res2: = {"summit": true, "summits": 10, "frame_step": 1}
			Dlg.win_peak(main, res2)
			return 1.3
		"peak_enter":
			PFx.peak_enter(main.overlay, main.get_viewport_rect().size)
			return 0.55
		"chest":
			for key in map.chests:
				var b: Control = map.chests[key]
				if State.chest_state(int(b.get_meta("gc")), str(b.get_meta("kind"))) == "ready":
					map.scroll = map._clamp_scroll(b.get_global_rect().position.y + map.scroll - map.H * 0.5)
					map._apply_scroll()
					await get_tree().process_frame
					map._chest_tap(b)
					break
			return 0.45
		"won":
			var from: = State.current()
			State.on_win(from, 3)
			open_map({"won": {"i": from, "stars": 3}})
			return 1.6
		"scroll":
			map.scroll = map._clamp_scroll(map.scroll + float(parts[1]))
			map._apply_scroll()
			return 0.5
		"top":
			map.scroll = 0.0
			map._apply_scroll()
			return 0.5
		"fx_min":
			G.set_fx_level("min")
			open_map({})
			return 0.8
	return 0.5
