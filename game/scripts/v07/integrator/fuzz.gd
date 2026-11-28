class_name V7Fuzz
extends RefCounted




static func run(host: Node, reps: int) -> void :
	await host.get_tree().process_frame
	var bad: = 0
	var games: = 0
	var clears: = 0
	var fails: = 0
	var blocked_takes: = 0
	for li in mini(48, G.LEVELS.size()):
		for rep in reps:
			var cfg: Dictionary = TWLevels.at(li).duplicate(true)
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
					_shuffle_sync(b)
				elif r < 0.06:
					var ps: Array = b._pairs_on_board()
					if not ps.is_empty():
						var p: Array = ps[randi() % ps.size()]
						p[0].alive = false
						p[1].alive = false
						_pair_gone_sync(b, p[0], p[1], false)
				elif r < 0.08 and not b.history.is_empty():
					var t0: Tile = b.history.pop_back()
					b.tray.erase(t0)
				else:
					var fr: Array = b.free_tiles()
					if fr.is_empty():
						if not _unstick_sync(b):
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
			host.remove_child(b)
			b.free()
			if games % 24 == 0:
				await host.get_tree().process_frame
	printerr("FUZZ %d games: rule errors %d, blocked takes %d, cleared %d, lost %d" % [games, bad, blocked_takes, clears, fails])
	await host.get_tree().process_frame
	host.get_tree().quit()


static func _shuffle_sync(b: V6SpecialBoard) -> void :
	var ts: = b.tiles.filter( func(t): return b.on_board(t) and t.shard == "" and t.face != V6SpecialBoard.JOKER)
	b.reassign_faces(ts)


static func _unstick_sync(b: V6SpecialBoard) -> bool:
	if b.board_count() == 0 or not b.free_tiles().is_empty():
		return false
	var any: = false
	for t in b.spec:
		var s: Dictionary = b.spec[t]
		if s.kind == "lock" and not s.open:
			s.open = true
			any = true
		elif s.kind == "chain" and int(s.n) > 0:
			s.n = 0
			any = true
	return any


static func _pair_gone_sync(b: V6SpecialBoard, a: Tile, b_tile: Tile, by_match: bool) -> void :
	b.pairs_done += 1
	for pr in [[a, b_tile], [b_tile, a]]:
		var j: Tile = pr[0]
		var o: Tile = pr[1]
		if b.spec.has(j) and b.spec[j].kind == "joker" and not (b.spec.has(o) and b.spec[o].kind == "joker"):
			var mate: Tile = b.spec[j].get("mate")
			if mate and mate.alive and mate.face == V6SpecialBoard.JOKER:
				mate.face = o.face
				mate.step = o.step
				b.spec.erase(mate)
				b.icons.erase(mate)
	for t in [a, b_tile]:
		if not b.spec.has(t):
			continue
		var s: Dictionary = b.spec[t]
		if s.kind == "key" and (t == a or not b.spec.has(a) or b.spec[a].kind != "key"):
			var g: int = int(s.group)
			for lt in b.spec:
				var ls: Dictionary = b.spec[lt]
				if ls.kind == "lock" and int(ls.group) == g and not ls.open:
					ls.open = true
		elif s.kind == "bomb" and by_match and (t == a or not b.spec.has(a) or b.spec[a].kind != "bomb"):
			_blast_sync(b, [a.home, b_tile.home])
	for ct in b.spec:
		var cs: Dictionary = b.spec[ct]
		if cs.kind == "chain" and int(cs.n) > 0 and ct.alive and ct != a and ct != b_tile:
			cs.n = int(cs.n) - 1


static func _blast_sync(b: V6SpecialBoard, homes: Array) -> void :
	var cand: = []
	for t in b.tiles:
		if not b.on_board(t) or t.pending or t.shard != "":
			continue
		var d: = 99999.0
		for h in homes:
			d = minf(d, (t.home - h).length())
		if d < Tile.TW * 1.75:
			cand.append([d - t.gz * 30.0, t])
	cand.sort_custom( func(x, y): return x[0] < y[0])
	var taken: = {}
	var pairs: = []
	for c in cand:
		if pairs.size() >= 3:
			break
		var t: Tile = c[1]
		if taken.has(t):
			continue
		var twin: Tile = null
		for o in b.tiles:
			if o != t and o.alive and not o.pending and o.step == t.step and o.face == t.face and not taken.has(o):
				twin = o
				break
		if twin == null:
			continue
		taken[t] = true
		taken[twin] = true
		pairs.append([t, twin])
	for pr in pairs:
		for t in pr:
			if b.tray.has(t):
				b.tray.erase(t)
				b.history.erase(t)
				b.display.erase(t)
			t.alive = false
		_pair_gone_sync(b, pr[0], pr[1], false)


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
		_pair_gone_sync(b, twin, t, true)
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
