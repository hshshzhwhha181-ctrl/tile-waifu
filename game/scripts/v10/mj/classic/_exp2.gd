extends SceneTree
func _init() -> void:
	await process_frame
	for fid in ["crab", "fan"]:
		var f := V10MjClassicLayouts.get_form(fid)
		for s in 5:
			var deal := V10MjClassicGen.generate(f, 1000 + s, "easy")
			var g: V10MjClassicGen.Geo = deal.geo
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			var alive := V10MjClassicGen.ones(g.n)
			var moves := 0
			while true:
				var pairs := V10MjClassicGen.available_pairs(g, alive, deal.keys)
				if pairs.is_empty(): break
				var fr := V10MjClassicGen.free_list(g, alive)
				var pick = null
				for p in pairs:
					if V10MjClassicGen._safe(g, alive, deal.keys, deal.keys[p[0]], fr):
						pick = p
						break
				if pick == null:
					pick = pairs[rng.randi_range(0, pairs.size() - 1)]
				alive[pick[0]] = 0
				alive[pick[1]] = 0
				moves += 1
			var left := V10MjClassicGen.count_alive(alive)
			var sol := V10MjClassicGen.solve(g, alive, deal.keys, 3000) if left > 0 else PackedInt32Array()
			var desc := []
			var bykey := {}
			for i in g.n:
				if alive[i]:
					bykey[deal.keys[i]] = bykey.get(deal.keys[i], []) + ["%s%s" % [str(g.pos[i]), "F" if g.free_in(i, alive) else ""]]
			print(fid, " seed ", s, " left ", left, " solvable-from-stuck? ", sol.size() > 0)
			if left > 0 and left <= 40:
				for k in bykey:
					print("   key ", k, ": ", bykey[k])
	quit()
