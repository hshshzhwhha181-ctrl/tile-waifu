extends SceneTree
func _init() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var forms := V10MjClassicLayouts.all()
	var args := OS.get_cmdline_user_args()
	var safe := 1.0
	var noise := 1.0
	for a in args:
		if a.begins_with("--safe="): safe = float(a.split("=")[1])
		if a.begins_with("--noise="): noise = float(a.split("=")[1])
	var fails := 0
	var tot := {"easy": 0, "normal": 0, "master": 0}
	var games := 0
	for f in forms:
		var res := {"easy": 0, "normal": 0, "master": 0}
		for s in 5:
			for d in ["easy", "normal", "master"]:
				var deal := V10MjClassicGen.generate(f, 1000 + s, d)
				if deal.is_empty():
					fails += 1
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = s
				for r in 4:
					var w: bool = V10MjClassicGen.bot_play_undo(deal.geo, V10MjClassicGen.ones(deal.geo.n), deal.keys, rng, 1500).win if d == "easyX" else V10MjClassicGen.bot_play(deal.geo, V10MjClassicGen.ones(deal.geo.n), deal.keys, rng, safe, noise).win
					if w:
						res[d] += 1
		games += 20
		for d in res: tot[d] += res[d]
		print("%-10s easy %d normal %d master %d /20" % [f.id, res.easy, res.normal, res.master])
	print("TOTAL easy %.0f%% normal %.0f%% master %.0f%%  fails %d  ms %d" % [100.0 * tot.easy / games, 100.0 * tot.normal / games, 100.0 * tot.master / games, fails, Time.get_ticks_msec() - t0])
	quit()
