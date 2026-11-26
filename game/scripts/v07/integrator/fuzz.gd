class_name V7Fuzz
extends RefCounted




static func run(host: Node, reps: int) -> void :
	var bad: = 0
	var games: = 0
	var clears: = 0
	var fails: = 0
	var blocked_takes: = 0
	for li in mini(48, G.LEVELS.size()):
		for rep in reps:
			var cfg: Dictionary = G.LEVELS[li].duplicate(true)
			cfg.seed = int(cfg.seed) + rep * 7919
			seed(int(cfg.seed) + 17)
			var b: = V6SpecialBoard.new()
			host.add_child(b)
			b.setup(cfg)
			b.apply_specials(V6Specials.plan_for(cfg, ""))
			games += 1
			var why: = ""
			var guard: = 0
			var rescues: = 1
			while b.board_count() > 0 and guard < 4000 and why == "":
				guard += 1
				var r: = randf()
				if r < 0.03:
					b.shuffle_board()
				elif r < 0.06:
					var ps: Array = b._pairs_on_board()
					if not ps.is_empty():
						var p: Array = ps[randi() % ps.size()]
						b._pair_gone(p[0], p[1], false)
						p[0].alive = false
						p[1].alive = false
				elif r < 0.08 and not b.history.is_empty():
					var t0: Tile = b.history.pop_back()
					b.tray.erase(t0)
				else:
					var fr: Array = b.free_tiles()
					if fr.is_empty():
						if not b.unstick():
							why = "no free tile"
						continue
					var t: Tile = null
					for x in fr:
						if b.tray.any( func(y): return y.face == x.face):
							t = x
					if t == null or randf() < 0.3:
						t = fr[randi() % fr.size()]
					if not b.is_free(t):
						blocked_takes += 1
					if t.ice > 0:
						t.ice = 0
						continue
					_take(b, t)
					if b.tray.size() >= b.slots:
						if rescues > 0:
							rescues -= 1
							for i in mini(3, b.tray.size()):
								var rt: Tile = b.tray.pop_back()
								b.history.erase(rt)
						else:
							fails += 1
							why = "tray full (player lost, fine)"
				var odd: = _odd_faces(b)
				if not odd.is_empty():
					why = "ODD faces %s" % str(odd)
			if why == "" and b.board_count() == 0:
				if b.tray.is_empty():
					clears += 1
				else:
					why = "ORPHANS in tray %s" % str(b.tray.map( func(t): return t.face))
			if why.begins_with("ODD") or why.begins_with("ORPHANS") or why == "no free tile":
				bad += 1
				printerr("FUZZ BAD %s rep %d: %s" % [cfg.code, rep, why])
			b.free()
	printerr("FUZZ %d games: rule errors %d, blocked takes %d, cleared %d, lost %d" % [games, bad, blocked_takes, clears, fails])
	host.get_tree().quit()

static func _take(b: V6SpecialBoard, t: Tile) -> void :
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
		b.history.erase(twin)
		twin.alive = false
		t.alive = false
		b._pair_gone(twin, t, true)
	else:
		b.tray.append(t)
		b.history.append(t)

static func _odd_faces(b: TrayBoard) -> Array:
	var c: = {}
	for t in b.tiles:
		if t.alive and t.face != V6SpecialBoard.JOKER:
			c[t.face] = c.get(t.face, 0) + 1
	var jokers: = b.tiles.filter( func(t): return t.alive and t.face == V6SpecialBoard.JOKER).size()
	var out: = []
	for f in c:
		if c[f] %2 == 1:
			out.append(f)
	if out.size() <= jokers and jokers > 0:
		return []
	return out
