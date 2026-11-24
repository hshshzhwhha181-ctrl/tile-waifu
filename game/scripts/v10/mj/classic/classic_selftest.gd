extends Node

# «Классика» selftest (MODES §4.1, contract §7.1). Run (rendering checks need xvfb; without a renderer the
# snapshot block is skipped and counted as failed):
#   xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#     res://scripts/v10/mj/classic/classic_selftest.tscn -- --mj_classic_selftest=1 [--shots=<dir>] [--quick]
# Final line: MJ_CLASSIC ok/total; exit code 0 only when all pass. Watchdog 600 s.

var ok: = 0
var total: = 0
var fails: Array = []
var shots: = ""
var quick: = false
const SEEDS: = 20


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		printerr("FAIL ", what)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.split("=")[1]
		elif a == "--quick":
			quick = true
	if shots == "":
		shots = "user://classic_selftest_shots"
	var wd: = get_tree().create_timer(600.0)
	wd.timeout.connect(func():
		print("MJ_CLASSIC %d/%d (watchdog)" % [ok, total + 1])
		get_tree().quit(2))
	V10MjClassicData.persist = false
	V10MjClassicData.sandbox = {}
	await get_tree().process_frame
	var t0: = Time.get_ticks_msec()
	_layouts()
	_free_rule()
	_certificates()
	_reshuffle()
	await _undo()
	_bands()
	_memory()
	_hidden()
	_data()
	await _screens()
	for f in fails:
		printerr("  - ", f)
	print("time %d ms" % (Time.get_ticks_msec() - t0))
	print("MJ_CLASSIC %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)


# ---- layouts ----------------------------------------------------------------------------------------------------
func _layouts() -> void:
	var forms: = V10MjClassicLayouts.all()
	check(forms.size() == 22, "22 forms (%d)" % forms.size())
	check(V10MjClassicLayouts.classic_forms().size() == 12, "12 classic forms")
	var names: = {}
	for f in forms:
		var n: int = f.pos.size()
		check(n >= 72 and n <= 144 and n % 2 == 0, "%s count %d in 72..144 even" % [f.id, n])
		var seen: = {}
		var dup: = false
		var floating: = false
		for p in f.pos:
			if seen.has(p):
				dup = true
			seen[p] = true
		for p in f.pos:
			if p.z == 0:
				continue
			var sup: = false
			for q in f.pos:
				if q.z == p.z - 1 and absi(q.x - p.x) < 2 and absi(q.y - p.y) < 2:
					sup = true
					break
			if not sup:
				floating = true
		check(not dup and not floating, "%s: no duplicate or floating tile" % f.id)
		names[f.name] = true
	check(V10MjClassicLayouts.get_form("turtle").pos.size() == 144, "Черепаха has 144")
	check(names.size() == 22, "22 distinct names")
	var hero_ids: = forms.filter(func(f): return f.kind == "hero").map(func(f): return f.hero)
	for h in ["mc", "rin", "hana", "yue", "nova", "kohaku", "zlata", "minamo", "vesper", "sigrid"]:
		check(h in hero_ids, "hero form of %s" % h)


# ---- the free rule on reference stacks --------------------------------------------------------------------------
func _g(pos: Array) -> V10MjClassicGen.Geo:
	var a: Array[Vector3i] = []
	for p in pos:
		a.append(p)
	return V10MjClassicGen.geo(a)


func _free_rule() -> void:
	# a row of three: the ends are free, the middle is not
	var g: = _g([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0)])
	var al: = V10MjClassicGen.ones(3)
	check(g.free_in(0, al) and not g.free_in(1, al) and g.free_in(2, al), "row of 3: ends free, middle closed")
	al[0] = 0
	check(g.free_in(1, al), "row: middle free once a neighbour is gone")
	# a tile on top closes the one under it
	g = _g([Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	al = V10MjClassicGen.ones(2)
	check(not g.free_in(0, al) and g.free_in(1, al), "stack: lower closed, upper free")
	# half-cell: a tile offset by half covers all four under it (the Turtle's crown)
	g = _g([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 2, 0), Vector3i(2, 2, 0), Vector3i(1, 1, 1)])
	al = V10MjClassicGen.ones(5)
	var all_closed: = true
	for i in 4:
		if g.free_in(i, al):
			all_closed = false
	check(all_closed and g.free_in(4, al), "half-offset crown closes the four under it")
	# a half-row tile touching two rows: both rows block that edge
	g = _g([Vector3i(0, 1, 0), Vector3i(2, 0, 0), Vector3i(2, 2, 0), Vector3i(-2, 1, 0)])
	al = V10MjClassicGen.ones(4)
	check(not g.free_in(0, al), "half-row tile with both edges touched is closed")
	al[1] = 0
	check(not g.free_in(0, al), "half-row: the second row still shuts the right edge")
	al[2] = 0
	check(g.free_in(0, al), "half-row: free once both rows let go")
	# a gap of half a tile is not a neighbour
	g = _g([Vector3i(0, 0, 0), Vector3i(3, 0, 0), Vector3i(6, 0, 0)])
	al = V10MjClassicGen.ones(3)
	check(g.free_in(1, al), "a half-tile gap is an open edge")
	# the Turtle itself
	var t: = V10MjClassicLayouts.get_form("turtle")
	var tg: = V10MjClassicGen.geo(t.pos)
	var ta: = V10MjClassicGen.ones(tg.n)
	var crown: int = t.pos.find(Vector3i(7, 13, 4))
	check(crown >= 0 and tg.free_in(crown, ta), "Turtle crown is free")
	var under: = 0
	for i in tg.n:
		var p: Vector3i = t.pos[i]
		if p.z == 3 and not tg.free_in(i, ta):
			under += 1
	check(under == 4, "Turtle: the four under the crown are closed (%d)" % under)
	var head: int = t.pos.find(Vector3i(7, 0, 0))
	check(head >= 0 and tg.free_in(head, ta), "Turtle head is free")
	var fr: = V10MjClassicGen.free_list(tg, ta)
	check(fr.size() >= 8, "Turtle starts with ≥ 8 free tiles (%d)" % fr.size())


# ---- 22 forms × 20 seeds solvable by certificate -----------------------------------------------------------------
func _certificates() -> void:
	var bad: = 0
	var n: = 0
	var groups_ok: = true
	for f in V10MjClassicLayouts.all():
		for s in (3 if quick else SEEDS):
			var deal: = V10MjClassicGen.generate(f, 5000 + s * 37, ["easy", "normal", "master"][s % 3])
			n += 1
			if deal.is_empty() or not V10MjClassicGen.certify(deal.geo, deal.order, deal.keys):
				bad += 1
				printerr("  cert fail ", f.id, " seed ", s)
				continue
			# flowers / seasons: four different faces each, one key
			var fl: = {}
			for i in deal.geo.n:
				if deal.keys[i] == V10MjClassicLayouts.KEY_FLOWER:
					fl[deal.faces[i]] = true
			if deal.geo.n >= 24 and fl.size() != 4:
				groups_ok = false
	check(bad == 0, "every form × %d seeds solvable by its certificate (%d/%d)" % [3 if quick else SEEDS, n - bad, n])
	check(groups_ok, "flowers: four different faces paired as one kind")
	# the board rule: a flower takes any flower, never a season or a plain face
	check(V10MjClassicLayouts.match_key(0) == V10MjClassicLayouts.match_key(4), "flower pairs with flower")
	check(V10MjClassicLayouts.match_key(0) != V10MjClassicLayouts.match_key(5), "flower does not pair with season")
	check(V10MjClassicLayouts.match_key(9) == 9, "plain faces pair with themselves")


# ---- shuffle keeps the table solvable ----------------------------------------------------------------------------
func _reshuffle() -> void:
	var good: = 0
	var n: = 0
	var multiset_ok: = true
	var rng: = RandomNumberGenerator.new()
	rng.seed = 99
	for f in V10MjClassicLayouts.all():
		for s in (2 if quick else 4):
			var deal: = V10MjClassicGen.generate(f, 700 + s, "master")
			var g: V10MjClassicGen.Geo = deal.geo
			var alive: = V10MjClassicGen.ones(g.n)
			var faces: PackedInt32Array = deal.faces
			var keys: PackedInt32Array = deal.keys
			# play randomly until stuck (or a random point), then shuffle
			var stop: = rng.randi_range(5, g.n / 2)
			for k in stop:
				var ps: = V10MjClassicGen.available_pairs(g, alive, keys)
				if ps.is_empty():
					break
				var p: Array = ps[rng.randi_range(0, ps.size() - 1)]
				alive[p[0]] = 0
				alive[p[1]] = 0
			if V10MjClassicGen.count_alive(alive) == 0:
				continue
			n += 1
			var before: = _multiset(alive, faces)
			var r: = V10MjClassicGen.reshuffle(g, alive, faces, rng, deal.order)
			if V10MjClassicGen.certify(g, r.order, r.keys, r.alive) and not V10MjClassicGen.available_pairs(g, r.alive, r.keys).is_empty():
				good += 1
			if _multiset(r.alive, r.faces) != before:
				multiset_ok = false
	check(n > 0 and good == n, "shuffle keeps the table solvable (%d/%d)" % [good, n])
	check(multiset_ok, "shuffle keeps the same tiles")
	# the worst case: two last tiles stacked in one column cannot be dealt in place: they move
	var g2: = _g([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(4, 0, 0), Vector3i(6, 0, 0)])
	var al2: = PackedByteArray([1, 1, 0, 0])
	var f2: = PackedInt32Array([9, 9, -1, -1])
	var r2: = V10MjClassicGen.reshuffle(g2, al2, f2, rng, PackedInt32Array([2, 3, 0, 1]))
	check(r2.relocated and V10MjClassicGen.certify(g2, r2.order, r2.keys, r2.alive), "stacked last pair is moved and stays solvable")


func _multiset(alive: PackedByteArray, faces: PackedInt32Array) -> Dictionary:
	var m: = {}
	for i in alive.size():
		if alive[i]:
			m[faces[i]] = int(m.get(faces[i], 0)) + 1
	return m


# ---- undo restores the state bit for bit (on the real board) ----------------------------------------------------
func _undo() -> void:
	var holder: = Control.new()
	holder.size = Vector2(720, 1000)
	add_child(holder)
	var b: = V10MjClassicBoard.new()
	holder.add_child(b)
	b.setup(V10MjClassicLayouts.get_form("turtle"), 4242, "normal", {"fx": "min"})
	b.fit(Rect2(0, 0, 720, 1000))
	await get_tree().process_frame
	var s0: = b.state()
	var rng: = RandomNumberGenerator.new()
	rng.seed = 5
	var snaps: Array = [s0]
	for k in 12:
		var ps: = b.pairs_now()
		if ps.is_empty():
			break
		var p: Array = ps[rng.randi_range(0, ps.size() - 1)]
		b.tap(p[0])
		b.tap(p[1])
		snaps.append(b.state())
	check(b.moves == snaps.size() - 1, "taps take pairs (%d moves)" % b.moves)
	var same: = true
	for k in range(snaps.size() - 1, 0, -1):
		b.undo()
		if not _same(b.state(), snaps[k - 1]):
			same = false
	check(same, "undo after pairs restores every state bit for bit")
	check(_same(b.state(), s0), "back at the deal after undoing all")
	# selection survives nothing: undo clears it; tapping a closed tile is denied and changes nothing
	var closed: = -1
	for i in b.geo.n:
		if not b.is_free(i):
			closed = i
			break
	var before: = b.state()
	b.tap(closed)
	check(_same(b.state(), before), "a closed tile cannot be taken")
	# manual shuffle and its undo
	var s1: = b.state()
	b.shuffle(false)
	await get_tree().process_frame
	check(V10MjClassicGen.certify(b.geo, b.cert, b.keys, b.alive), "after «Перемешать» the live certificate holds")
	check(b.shuffles == 1, "shuffle counted")
	b.input_on = true
	b.undo()
	check(_same(b.state(), s1), "undo of a shuffle restores bit for bit")
	# hint: a takeable pair that keeps the table solvable
	var hp: = b.hint_pair()
	check(hp.size() == 2 and b.is_free(hp[0]) and b.is_free(hp[1]) and b.keys[hp[0]] == b.keys[hp[1]], "hint shows a free pair")
	var al: = PackedByteArray(b.alive)
	al[hp[0]] = 0
	al[hp[1]] = 0
	check(V10MjClassicGen.solve(b.geo, al, b.keys, 6000).size() > 0 or V10MjClassicGen.count_alive(al) == 0, "the hinted pair keeps the table solvable")
	# auto shuffle when no pair is free: force a dead table
	var dead_ok: = _dead_table_shuffles()
	check(dead_ok, "no moves -> automatic shuffle, solvable, «Ходов нет — перемешала» path")
	holder.queue_free()
	await get_tree().process_frame


func _dead_table_shuffles() -> bool:
	# play a master deal randomly on a board until stuck; the board must shuffle by itself
	var holder: = Control.new()
	add_child(holder)
	for s in 30:
		var b: = V10MjClassicBoard.new()
		holder.add_child(b)
		b.setup(V10MjClassicLayouts.get_form("fortress"), 900 + s, "master", {"fx": "min"})
		var rng: = RandomNumberGenerator.new()
		rng.seed = s
		var got: = [false]
		b.shuffled.connect(func(auto): if auto: got[0] = true)
		var guard: = 0
		while b.remaining() > 0 and guard < 200:
			guard += 1
			var ps: = b.pairs_now()
			if ps.is_empty():
				break
			var p: Array = ps[rng.randi_range(0, ps.size() - 1)]
			b.take(p[0], p[1])
			if b.remaining() > 0 and b.pairs_now().is_empty():
				# the board arms its shuffle on a timer; call it now (as the timer would)
				b.auto_shuffle()
				var okk: bool = V10MjClassicGen.certify(b.geo, b.cert, b.keys, b.alive) and not b.pairs_now().is_empty()
				holder.queue_free()
				return okk and got[0] and b.history[-1].kind == "shuffle" and b.history[-1].auto
		b.queue_free()
	holder.queue_free()
	return false


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.alive == b.alive and a.faces == b.faces and a.keys == b.keys and a.sel == b.sel and a.moves == b.moves


# ---- difficulty bands of the bot ---------------------------------------------------------------------------------
func _bands() -> void:
	var seeds: = 3 if quick else SEEDS
	var res: = {"easy": 0, "normal": 0, "master": 0}
	var traps: = {"easy": 0.0, "normal": 0.0, "master": 0.0}
	var games: = 0
	for f in V10MjClassicLayouts.all():
		for s in seeds:
			games += 1
			for d in res:
				var deal: = V10MjClassicGen.generate(f, 31000 + s * 101, d)
				traps[d] += float(deal.traps) / maxf(1.0, float(deal.quads))
				var rng: = RandomNumberGenerator.new()
				rng.seed = 77 + s
				var w: bool
				if d == "easy":
					w = V10MjClassicGen.bot_play_undo(deal.geo, V10MjClassicGen.ones(deal.geo.n), deal.keys, rng, 1500).win
				else:
					w = V10MjClassicGen.bot_play(deal.geo, V10MjClassicGen.ones(deal.geo.n), deal.keys, rng, 1.0, 1.0).win
				if w:
					res[d] += 1
	var pe: float = 100.0 * res.easy / games
	var pn: float = 100.0 * res.normal / games
	var pm: float = 100.0 * res.master / games
	print("bands: easy %.0f%% (undo), normal %.0f%% (no undo), master %.0f%% (no undo); traps easy %.0f%% normal %.0f%% master %.0f%%" % [pe, pn, pm,
		100.0 * traps.easy / games, 100.0 * traps.normal / games, 100.0 * traps.master / games])
	check(pe >= 95.0, "easy: bot ≥ 95%% (%.0f%%)" % pe)
	check(pn >= 70.0, "normal without undo: bot ≥ 70%% (%.0f%%)" % pn)
	check(pm >= 25.0 and pm <= 45.0, "master without undo: bot 25–45%% (%.0f%%)" % pm)
	check(traps.easy / games < 0.005, "easy: no traps (%.1f%%)" % (100.0 * traps.easy / games))
	check(absf(100.0 * traps.normal / games - 20.0) <= 6.0, "normal: ~20%% traps (%.0f%%)" % (100.0 * traps.normal / games))
	check(absf(100.0 * traps.master / games - 45.0) <= 8.0, "master: ~45%% traps (%.0f%%)" % (100.0 * traps.master / games))


# ---- memory ------------------------------------------------------------------------------------------------------
func _memory() -> void:
	for sz in ["4x4", "4x5", "5x6", "6x6"]:
		var all_found: = true
		var pairs_ok: = true
		for s in 10:
			var f: = V10MjClassicMemory.deal(sz, s + 1)
			var d: = V10MjClassicMemory.dims(sz)
			if f.size() != d.x * d.y:
				pairs_ok = false
			var cnt: = {}
			for v in f:
				cnt[v] = int(cnt.get(v, 0)) + 1
			for v in cnt:
				if cnt[v] != 2:
					pairs_ok = false
			var r: = _memory_bot(f, s)
			if r.found != f.size() / 2:
				all_found = false
		check(pairs_ok, "memory %s: every face exactly twice" % sz)
		check(all_found, "memory %s: a player who remembers finds every pair" % sz)
	for p in [8, 10, 15, 18]:
		var a: = int(round(p * 1.75))
		var b: = int(round(p * 2.5))
		check(V10MjClassicMemory.stars_for(a, p) == 3 and V10MjClassicMemory.stars_for(a + 1, p) == 2, "memory %d pairs: ★★★ up to %d moves" % [p, a])
		check(V10MjClassicMemory.stars_for(b, p) == 2 and V10MjClassicMemory.stars_for(b + 1, p) == 1, "memory %d pairs: ★★ up to %d moves" % [p, b])
	check(V10MjClassicMemory.dims("5x6") == Vector2i(5, 6), "memory sizes parse")


func _memory_bot(faces: PackedInt32Array, s: int) -> Dictionary:
	var rng: = RandomNumberGenerator.new()
	rng.seed = s
	var known: = {}
	var matched: = {}
	var moves: = 0
	var found: = 0
	var n: = faces.size()
	while found < n / 2 and moves < 4 * n:
		moves += 1
		# a known pair first
		var pick: Array = []
		var by: = {}
		for i in known:
			if not matched.has(i):
				by[faces[i]] = by.get(faces[i], []) + [i]
		for k in by:
			if by[k].size() == 2:
				pick = by[k]
				break
		if pick.is_empty():
			var unknown: = []
			for i in n:
				if not known.has(i) and not matched.has(i):
					unknown.append(i)
			var a: int = unknown[rng.randi_range(0, unknown.size() - 1)]
			known[a] = true
			var b: = -1
			for i in known:
				if i != a and not matched.has(i) and faces[i] == faces[a]:
					b = i
			if b < 0:
				unknown.erase(a)
				b = unknown[rng.randi_range(0, unknown.size() - 1)] if not unknown.is_empty() else a
				known[b] = true
			pick = [a, b]
		if pick[0] != pick[1] and faces[pick[0]] == faces[pick[1]]:
			matched[pick[0]] = true
			matched[pick[1]] = true
			found += 1
	return {"found": found, "moves": moves}


# ---- hidden heroines' forms ---------------------------------------------------------------------------------------
func _hidden() -> void:
	var founders: = {"mc": 1, "rin": 1, "hana": 1, "yue": 1, "nova": 1}
	var vis: = V10MjClassicLayouts.visible_forms(founders)
	check(vis.size() == 17, "12 classic + 5 founders visible (%d)" % vis.size())
	var leak: = false
	for f in vis:
		if f.kind == "hero" and not founders.has(f.hero):
			leak = true
	check(not leak, "no form of a heroine who is not in the roster")
	var with_k: = founders.duplicate()
	with_k["kohaku"] = 1
	check(V10MjClassicLayouts.visible(V10MjClassicLayouts.get_form("h_kohaku"), with_k), "Kohaku's fox appears with her")
	check(not V10MjClassicLayouts.visible(V10MjClassicLayouts.get_form("h_kohaku"), founders), "Kohaku's fox is hidden without her")
	# the lobby shelf shows exactly the visible forms of the live roster
	var l: = V10MjClassicLobby.new()
	add_child(l)
	l.setup(null, {"hero": "mc", "no_save": true, "fx": "min"})
	var live: = V10MjClassicLayouts.visible_forms()
	var ids: = l.cards.map(func(c): return c.form.id)
	var hidden_on_shelf: = ids.filter(func(id): return not V10MjClassicLayouts.visible(V10MjClassicLayouts.get_form(id)))
	check(ids.size() == live.size() and hidden_on_shelf.is_empty(), "shelf = visible forms only (%d cards)" % ids.size())
	l.queue_free()


# ---- progress and rewards --------------------------------------------------------------------------------------
func _data() -> void:
	V10MjClassicData.sandbox = {}
	var d: = V10MjClassicData.st()
	check(d.has("stars") and d.view == "3d", "save defaults")
	V10MjClassicData.sandbox[V10MjClassicData.KEY] = {"stars": "junk", "view": 7}
	d = V10MjClassicData.st()
	check(d.stars is Dictionary and d.view == "3d", "save repairs junk")
	V10MjClassicData.sandbox = {}
	check(V10MjClassicData.stars_of(true, 0, 0) == 3 and V10MjClassicData.stars_of(true, 2, 0) == 2 and V10MjClassicData.stars_of(true, 0, 1) == 1 and V10MjClassicData.stars_of(false, 0, 0) == 0, "★ / ★★ / ★★★ rules")
	var r1: = V10MjClassicData.record({"variant": "free", "form": "turtle", "win": true, "stars": 3, "time_s": 300}, "2026-11-24")
	check(r1.rewards.coins == 20 and r1.rewards.aff == 1 and r1.first_today, "first win of the day: 20 coins + 1 sympathy")
	var r2: = V10MjClassicData.record({"variant": "free", "form": "dragon", "win": true, "stars": 2, "time_s": 300}, "2026-11-24")
	check(r2.rewards.coins == 0 and r2.rewards.aff == 0, "only the first win of the day pays")
	check(r2.rank_up == 1 and r2.rewards.gems == 30 and "frame_classic" in r2.gifts, "rank I at 5 ★: 30 crystals + frame")
	var gems: = 30
	var day: = 25
	for fid in ["cat", "fortress", "crab", "spider", "bridge", "pyramid", "gate", "fan", "butterfly", "lotus", "h_mc", "h_rin", "h_hana", "h_yue", "h_nova"]:
		var r: = V10MjClassicData.record({"variant": "free", "form": fid, "win": true, "stars": 3, "time_s": 200}, "2026-11-%02d" % mini(day, 30))
		gems += int(r.rewards.gems)
		day += 1
	V10MjClassicData.record({"variant": "free", "form": "dragon", "win": true, "stars": 3, "time_s": 200}, "2026-12-01")
	var r3: = V10MjClassicData.record({"variant": "free", "form": "dragon", "win": true, "stars": 3, "time_s": 200}, "2026-12-01")
	gems += int(r3.rewards.gems)
	var sd: = V10MjClassicData.st()
	check(V10MjClassicData.rank_of(V10MjClassicData.star_sum(sd)) == 5 and int(sd.ranks_paid) == 5, "mastery V reached (%d ★)" % V10MjClassicData.star_sum(sd))
	check(gems == 150, "milestones pay 5 × 30 crystals once (%d)" % gems)
	check("title_keeper" in sd.cosmetics and "back_classic" in sd.cosmetics, "title «Хранительница форм» and the tile back")
	var again: = V10MjClassicData.record({"variant": "free", "form": "cat", "win": true, "stars": 3, "time_s": 100}, "2026-12-01")
	check(again.rewards.gems == 0, "milestones never pay twice")
	check(V10MjClassicData.daily_form("2026-11-24") == V10MjClassicData.daily_form("2026-11-24"), "form of the day is the same for everyone")
	var forms_seen: = {}
	for k in 30:
		forms_seen[V10MjClassicData.daily_form("2026-12-%02d" % (k + 1))] = true
	check(forms_seen.size() >= 6, "form of the day rotates (%d forms in 30 days)" % forms_seen.size())
	check(V10MjClassicData.msk_date(0.0) == "1970-01-01" and V10MjClassicData.msk_date(22.0 * 3600.0) == "1970-01-02", "day changes at MSK midnight")
	var fast: = V10MjClassicData.faster_than(120, 72, "2026-11-24")
	var slow: = V10MjClassicData.faster_than(1800, 72, "2026-11-24")
	check(fast > slow and fast >= 90 and slow <= 10, "«быстрее N%%» falls with time (%d → %d)" % [fast, slow])
	V10MjClassicData.sandbox = {}


# ---- screens: budget, the heroine never over the sacred zone, snapshots of three forms at two sizes ------------
func _screens() -> void:
	var renders: = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(shots)
	var cases: = [["turtle", "mc"], ["h_yue", "yue"], ["butterfly", "hana"]]
	var shot_ok: = 0
	for sz in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		for c in cases:
			var vp: = SubViewport.new()
			vp.size = sz
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			var s: = V10MjClassicScreen.new()
			vp.add_child(s)
			s.setup(null, {"form": c[0], "hero": c[1], "seed": 3, "fx": "min", "no_save": true})
			await get_tree().process_frame
			await get_tree().process_frame
			# UX budget in play: ≤ 6 tappables, ≤ 8 words, one progress bar
			var taps: = 1 + s.help.size()
			var words: = 0
			for w in s.goal.text.split(" ", false):
				if w.to_int() == 0 and w != "·":
					words += 1
			for b in s.help:
				words += String(b.text).split(" ", false).size()
			check(taps <= 6 and words <= 8, "%s %s: budget taps %d ≤ 6, words %d ≤ 8" % [c[0], str(sz), taps, words])
			# she never draws over the sacred zone while input is on
			var p = s.presence
			var hits: Array = p.sacred_hits() if p.has_method("sacred_hits") else []
			check(hits.is_empty(), "%s %s: heroine clear of the sacred zone" % [c[0], str(sz)])
			# the board fits the field: every tile inside the field at zoom 1
			var fr: Rect2 = s.field.get_global_rect()
			var inside: = true
			for t in s.board.tiles:
				var gp: Vector2 = (t as Tile).get_global_transform_with_canvas().origin
				if not fr.grow(2).has_point(gp):
					inside = false
			check(inside, "%s %s: whole form inside the field" % [c[0], str(sz)])
			check(s.board.tile_scale_px() >= 52.0, "%s %s: tiles ≥ 52 px (%.0f)" % [c[0], str(sz), s.board.tile_scale_px()])
			if renders:
				await RenderingServer.frame_post_draw
				var img: = vp.get_texture().get_image()
				var path: = "%s/selftest_%s_%dx%d.png" % [shots, c[0], sz.x, sz.y]
				if img and not img.is_empty():
					img.save_png(path)
					# not a blank frame: the field has many colours
					var cols: = {}
					for k in 400:
						var px: = img.get_pixel(int(fr.position.x + randf() * fr.size.x), int(fr.position.y + randf() * fr.size.y))
						cols[px.to_html(false).substr(0, 4)] = true
					if cols.size() > 20:
						shot_ok += 1
			vp.queue_free()
			await get_tree().process_frame
	check(shot_ok == 6, "snapshots of three forms at 720×1280 and 9:20 rendered (%d/6) -> %s" % [shot_ok, shots])
