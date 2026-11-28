extends Node






func _ready() -> void :
	await get_tree().process_frame
	_run()
	get_tree().quit()

func _run() -> void :
	var bad: = 0
	var total: = 0
	var greedy_plain: = 0
	var greedy_spec: = 0
	var kinds: = {}
	for li in mini(48, G.LEVELS.size()):
		for rep in 6:
			var cfg: Dictionary = TWLevels.at(li).duplicate(true)
			cfg.seed = int(cfg.seed) + rep * 7919
			seed(int(cfg.seed))
			var plan: = V6Specials.plan_for(cfg, "")
			var r: = _play(cfg, plan, true)
			total += 1
			if not r.ok:
				bad += 1
				printerr("FAIL %s rep %d left %d (%s)" % [cfg.code, rep, r.left, r.why])
			for k in r.kinds:
				kinds[k] = kinds.get(k, 0) + 1
			seed(int(cfg.seed))
			if _play(cfg, {}, false).ok:
				greedy_plain += 1
			seed(int(cfg.seed))
			if _play(cfg, plan, false).ok:
				greedy_spec += 1
			if rep == 0:
				printerr("%s specials=%s" % [cfg.code, str(r.kinds)])
	printerr("SPECIAL SELFTEST solver %d/%d solved; greedy plain %d/%d, greedy with specials %d/%d; kinds %s; unstick used %d" % [total - bad, total, greedy_plain, total, greedy_spec, total, str(kinds), unsticks])

var unsticks: = 0

func _play(cfg: Dictionary, plan: Dictionary, solver: bool) -> Dictionary:
	var b: = V6SpecialBoard.new()
	add_child(b)
	b.setup(cfg)
	b.apply_specials(plan)
	var ks: = b.kinds()
	var ok: = true
	var why: = ""
	var guard: = 0
	while b.board_count() > 0 and guard < 3000:
		guard += 1
		var t: Tile = b.solver_move() if solver else b.best_move()
		if t == null and not solver and b.unstick():
			unsticks += 1
			t = b.best_move()
		if t == null:
			ok = false
			why = "no move"
			break
		if t.ice > 0:
			t.ice -= 1
			continue
		if t.face == V6SpecialBoard.JOKER:
			for x in b.tray:
				if x.face != V6SpecialBoard.JOKER:
					t.face = x.face
					break
		elif not b.tray.any( func(x): return x.face == t.face):
			for x in b.tray:
				if x.face == V6SpecialBoard.JOKER:
					x.face = t.face
					break
		var twin: Tile = null
		for x in b.tray:
			if x.face == t.face:
				twin = x
				break
		if twin:
			b.tray.erase(twin)
			twin.alive = false
			t.alive = false
			b._pair_gone(twin, t, true)
		else:
			b.tray.append(t)
			if b.tray.size() >= TrayBoard.SLOTS:
				ok = false
				why = "tray full"
				break
	var left: = b.board_count()
	b.queue_free()
	return {"ok": ok and left == 0, "left": left, "why": why, "kinds": ks}
