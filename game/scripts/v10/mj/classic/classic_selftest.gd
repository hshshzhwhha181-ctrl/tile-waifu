extends Node

# «Классика» selftest (MODES §4.1, contract §7.1). Runs headless; nothing is rendered here:
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/classic/classic_selftest.tscn -- \
#     --mj_classic_selftest=1 [--mj_classic_full=1] [--mj_classic_shots=<dir>]
#   (default)                 quick sample: 22 forms × 3 seeds for certificates and bot bands (≤ 120 s on 1 core)
#   --mj_classic_full=1       the full run: 22 forms × 20 seeds (certificates, bands), 4 shuffles per form
#   --mj_classic_shots=<dir>  also check the demo's snapshots there (classic_demo.tscn, 720×1280 and 1080×2400)
# Final line: MJ_CLASSIC ok/total; exit code 0 only when all pass. Watchdog 600 s.

const SHOT_NAMES: = ["lobby", "lobby_daily", "match_turtle_start", "match_h_yue_start", "match_dragon_start", "match_play",
	"match_ult", "match_zoom", "match_pause", "match_flat", "match_win", "match_result", "daily_start", "memory_start",
	"memory_play", "memory_result"]
# the event dictionary of MODES §3.2 that a solitaire table may send
const EVENTS: = ["pick", "pair", "combo", "motif", "danger", "signature", "wave", "ult", "last_pair", "win", "lose", "idle"]
# UX_RULES §4.3: jargon that never shows (lower case = any case; the rest exact, as whole words)
const JARGON: = ["гарант", "пити", "pity", "50/50", "гача", "ролл", "крутка", "фивер", "ивент", "квартал", "перк",
	"ульта", "банер", "донат", "успей", "последний шанс", "топ-100", "x2 только сегодня"]
const JARGON_EXACT: = ["SR", "SR+", "SSR+", "ХИТ", "ВЫГОДНО", "BEST", "NEW", "ID"]
const LINT: = "res://core/meta/lint.gd"
const STAGE: = "res://scripts/v10/mj/stage/presence.gd"
const LOOK: = "res://scripts/v10/mj/look/tile_material.gd"
const TABLES: = "res://scripts/v10/mj/look/table_themes.gd"

var args: = {}
var ok: = 0
var total: = 0
var fails: Array = []
var full: = false
var seeds: = 3
var _t_sec: = 0


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		printerr("FAIL ", what)


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
		elif s == "--quick":
			args["quick"] = "1"
	full = String(args.get("mj_classic_full", "")) == "1"
	seeds = 20 if full else 3
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_CLASSIC %d/%d (watchdog 600 s)" % [ok, total + 1])
		get_tree().quit(2))
	# progress lives in a sandbox: the player's save is never read or written here
	V10MjClassicData.persist = false
	V10MjClassicData.sandbox = {}
	await get_tree().process_frame
	var t0: = Time.get_ticks_msec()
	_t_sec = t0
	_layouts()
	_sec("layouts")
	_free_rule()
	_sec("free rule")
	_certificates()
	_sec("certificates")
	_reshuffle()
	_sec("shuffle")
	await _undo()
	_sec("undo, hint, auto shuffle")
	await _ults_board()
	_sec("Приёмы on the board")
	_bands()
	_sec("bot bands")
	_memory()
	_sec("memory rules")
	_hidden()
	_sec("hidden forms")
	_data()
	_sec("save, rewards")
	_presence()
	_sec("presence resolve")
	await _screens()
	_sec("screens")
	await _flow()
	_sec("screen flow")
	await _memory_screen()
	_sec("memory screen")
	_words()
	_sec("words")
	_shots()
	for f in fails:
		printerr("  - ", f)
	print("time %d ms (%s)" % [Time.get_ticks_msec() - t0, "full" if full else "quick sample; --mj_classic_full=1 for 22 × 20"])
	print("MJ_CLASSIC %d/%d" % [ok, total])
	V10MjClassicData.sandbox = {}
	get_tree().quit(0 if ok == total else 1)


func _sec(name: String) -> void:
	var now: = Time.get_ticks_msec()
	print("  [%5d ms] %s" % [now - _t_sec, name])
	_t_sec = now


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# a stand-in for args.presence: records what the screen sends (MODES §7.1 contract: on + sacred)
class _Mock:
	extends RefCounted
	signal portrait_tapped
	var events: Array = []
	var rects: Array = []
	var said: Array = []
	var input_on: = true
	var avoid: Array = []
	func on(event: String, data: = {}) -> Dictionary:
		events.append([event, data])
		return {"event": event, "acts": []}
	func sacred(r: Rect2) -> void:
		rects.append(r)
	func clear_sacred() -> void:
		rects.clear()
	func say(text: String, _force: = false) -> bool:
		said.append(text)
		return true
	func kinds() -> Array:
		return events.map(func(e): return e[0])


# a screen of the given size in its own viewport (headless lays out just the same)
func _vp(sz: Vector2i) -> SubViewport:
	var vp: = SubViewport.new()
	vp.size = sz
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	return vp


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


# ---- 22 forms × N seeds solvable by certificate ------------------------------------------------------------------
func _certificates() -> void:
	var bad: = 0
	var n: = 0
	var groups_ok: = true
	for f in V10MjClassicLayouts.all():
		for s in seeds:
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
	check(bad == 0, "every form × %d seeds solvable by its certificate (%d/%d)" % [seeds, n - bad, n])
	check(groups_ok, "flowers: four different faces paired as one kind")
	# the board rule: a flower takes any flower, never a season or a plain face
	check(V10MjClassicLayouts.match_key(0) == V10MjClassicLayouts.match_key(4), "flower pairs with flower")
	check(V10MjClassicLayouts.match_key(5) == V10MjClassicLayouts.match_key(11), "season pairs with season")
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
		for s in (4 if full else 1):
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
func _board(holder: Node, fid: String, s: int, diff: = "normal", opts: = {"fx": "min"}) -> V10MjClassicBoard:
	var b: = V10MjClassicBoard.new()
	holder.add_child(b)
	b.setup(V10MjClassicLayouts.get_form(fid), s, diff, opts)
	b.fit(Rect2(0, 0, 720, 1000))
	return b


func _undo() -> void:
	var holder: = Control.new()
	holder.size = Vector2(720, 1000)
	add_child(holder)
	var b: = _board(holder, "turtle", 4242)
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
	# tapping a closed tile is denied and changes nothing
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
	check(b.hint() and b.hints == 1, "«Подсказка» counts (no limit, it costs the ★★★ only)")
	# view: flat and back, the same tiles stay
	b.set_view("flat")
	check(b.view == "flat" and b.remaining() == s0.alive.count(1), "«Плоский» keeps the table")
	b.set_view("3d")
	check(b.view == "3d", "«Объёмный» back")
	# double tap zoom (half the table) and back
	b.zoom_to(2.0, Vector2(360, 500))
	await _wait(0.35)
	check(is_equal_approx(b.zoom, 2.0) and b.scale.x > 1.9 * b.base_scale, "zoom to 2× (double tap: half the table)")
	b.zoom_to(1.0, Vector2(360, 500))
	await _wait(0.35)
	check(is_equal_approx(b.zoom, 1.0) and b.position == b.base_pos, "zoom back to 1×")
	# free tiles breathe 1.00–1.01 (full effects, V6 tiles)
	var bb: = _board(holder, "cat", 11, "easy", {"fx": "full"})
	bb.deal_in(true)
	for k in 4:
		await get_tree().process_frame
	var lo: = 9.0
	var hi: = 0.0
	for i in bb.geo.n:
		if bb.is_free(i):
			lo = minf(lo, (bb.tiles[i] as Tile).scale.x)
			hi = maxf(hi, (bb.tiles[i] as Tile).scale.x)
	check(lo >= 0.999 and hi <= 1.0101, "free tiles breathe within 1.00–1.01 (%.4f..%.4f)" % [lo, hi])
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
				var sh: bool = b.shuffles == 0  # the automatic one is free: it does not cost ★★
				holder.queue_free()
				return okk and sh and got[0] and b.history[-1].kind == "shuffle" and b.history[-1].auto
		b.queue_free()
	holder.queue_free()
	return false


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.alive == b.alive and a.faces == b.faces and a.keys == b.keys and a.sel == b.sel and a.moves == b.moves


# ---- Приёмы on the Classic table (MODES §5.5) ---------------------------------------------------------------------
func _ults_board() -> void:
	var holder: = Control.new()
	holder.size = Vector2(720, 1000)
	add_child(holder)
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		check(V10MjClassicUlts.ult_name(h) != "" and V10MjClassicUlts.desc(h) != "", "%s: Приём has a name and a line" % h)
		var b: = _board(holder, "turtle", 4242)
		for k in 6:
			var hp0: = b.hint_pair()
			if hp0.size() == 2:
				b.tap(hp0[0])
				b.tap(hp0[1])
		var r0: = b.remaining()
		var m0: = b.moves
		var hp: = b.hint_pair()
		var zs_hint: int = b.geo.pos[hp[0]].z + b.geo.pos[hp[1]].z
		var r: = V10MjClassicUlts.cast(h, b)
		var cert_ok: = V10MjClassicGen.certify(b.geo, b.cert, b.keys, b.alive)
		match h:
			"mc":
				check(r.kind == "take" and r.pairs.size() == 1 and b.remaining() == r0 - 2 and cert_ok, "mc «Снять пару»: 1 pair of the certificate, table stays solvable")
				b.undo()
				check(b.remaining() == r0 and b.moves == m0, "mc: the Приём pair can be undone")
			"hana":
				check(r.kind == "take" and r.pairs.size() == 2 and b.remaining() == r0 - 4 and cert_ok, "hana «Рывок»: 2 pairs in a row, table stays solvable")
			"nova":
				var p: Array = r.pairs[0] if r.pairs.size() > 0 else [-1, -1]
				var zs: int = b.geo.pos[p[0]].z + b.geo.pos[p[1]].z if p[0] >= 0 else 99
				check(r.kind == "deep" and r.pairs.size() == 1 and b.remaining() == r0 - 2 and cert_ok and b.keys[p[0]] == b.keys[p[1]], "nova «Взлом»: one pair, table stays solvable")
				check(zs <= zs_hint, "nova: the pair is no higher than the safe one (z %d ≤ %d)" % [zs, zs_hint])
			"rin":
				var sh: Dictionary = r.get("shown", {})
				var pr: Array = sh.get("pair", [])
				var closed: = pr.size() == 2 and not (b.is_free(pr[0]) and b.is_free(pr[1]))
				check(r.kind == "path" and pr.size() == 2 and b.keys[pr[0]] == b.keys[pr[1]] and b.remaining() == r0, "rin: shows a pair, takes nothing")
				check(closed and not (sh.get("path", []) as Array).is_empty(), "rin: the pair is still closed and the tiles that hold it are lit")
			"yue":
				var ps: Array = r.get("shown", [])
				check(r.kind == "pairs" and ps.size() == b.pairs_now().size() and ps.size() > 0 and b.remaining() == r0, "yue: lights every free pair, takes nothing")
		b.queue_free()
	# her signature pair and the pairs of the Приём itself (charge) — on the screen, see _flow
	holder.queue_free()
	await get_tree().process_frame


# ---- difficulty bands of the bot ---------------------------------------------------------------------------------
func _bands() -> void:
	# quick: easy on 3 seeds a form, normal and master on 6 (the bot without undo is cheap); full: 20 each
	var per: = {"easy": seeds, "normal": seeds if full else 6, "master": seeds if full else 6}
	var res: = {"easy": 0, "normal": 0, "master": 0}
	var traps: = {"easy": 0.0, "normal": 0.0, "master": 0.0}
	var games: = {"easy": 0, "normal": 0, "master": 0}
	for f in V10MjClassicLayouts.all():
		for d in res:
			for s in int(per[d]):
				games[d] += 1
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
	var pc: = {}
	var tp: = {}
	var tol: = {}
	for d in res:
		pc[d] = 100.0 * res[d] / games[d]
		tp[d] = 100.0 * traps[d] / games[d]
		# a quick sample is checked against the band widened by its sampling error (2σ); the full run is strict
		tol[d] = 0.0 if full else 200.0 * sqrt(0.35 * 0.65 / float(games[d]))
	print("  bands (%d/%d/%d games): easy %.0f%% (undo), normal %.0f%% (no undo), master %.0f%% (no undo); traps easy %.0f%% normal %.0f%% master %.0f%%%s" % [
		games.easy, games.normal, games.master, pc.easy, pc.normal, pc.master, tp.easy, tp.normal, tp.master,
		"" if full else " (sample, ±%.0f%% for master)" % tol.master])
	check(pc.easy >= 95.0 - tol.easy * 0.3, "easy: bot ≥ 95%% (%.0f%%)" % pc.easy)
	check(pc.normal >= 70.0 - tol.normal, "normal without undo: bot ≥ 70%% (%.0f%%)" % pc.normal)
	check(pc.master >= 25.0 - tol.master and pc.master <= 45.0 + tol.master, "master without undo: bot 25–45%% (%.0f%%%s)" % [pc.master, "" if full else ", sample ±%.0f" % tol.master])
	check(tp.easy < 0.5, "easy: no traps (%.1f%%)" % tp.easy)
	check(absf(tp.normal - 20.0) <= 6.0, "normal: ~20%% traps (%.0f%%)" % tp.normal)
	check(absf(tp.master - 45.0) <= 8.0, "master: ~45%% traps (%.0f%%)" % tp.master)


# ---- memory rules ------------------------------------------------------------------------------------------------
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
	for h in ["mc", "rin", "hana", "yue", "nova", "kohaku"]:
		check(V10MjClassicMemory.crest_tex(h) != null, "her crest on the backs (%s, else the founder's)" % h)
		check(V10MjClassicUlts.memory_effect(h).has("kind"), "%s: a Приём in Memory" % h)


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
	check(l.seg.items.size() == 3 and l.seg.items[0] == "Свободная" and l.seg.items[1] == "Раскладка дня" and l.seg.items[2] == "Память", "one switch: Свободная · Раскладка дня · Память")
	l.variant = "daily"
	check(l.cover_hero() == V10MjClassicData.daily_host(V10MjClassicData.msk_date()), "«Раскладка дня»: the cover is the hostess of the day")
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
	# Afisha «Режим дня»: the daily layout's first win is multiplied, a free table's is not
	V10MjClassicData.sandbox = {}
	var md: = V10MjClassicData.record({"variant": "daily", "form": "turtle", "win": true, "stars": 3, "time_s": 300, "mult": 2}, "2026-11-24")
	check(md.rewards.coins == 40, "Afisha ×2 on «Раскладка дня»: 40 coins (%d)" % md.rewards.coins)
	V10MjClassicData.sandbox = {}
	var mf: = V10MjClassicData.record({"variant": "free", "form": "turtle", "win": true, "stars": 3, "time_s": 300, "mult": 2}, "2026-11-24")
	check(mf.rewards.coins == 20, "no multiplier on a free table")
	V10MjClassicData.sandbox = {}
	var mx: = V10MjClassicData.record({"variant": "daily", "form": "turtle", "win": true, "stars": 3, "time_s": 300, "mult": 50}, "2026-11-24")
	check(mx.rewards.coins == 60, "the multiplier is capped at ×3")
	# hearts (bookmarks)
	V10MjClassicData.sandbox = {}
	check(V10MjClassicData.toggle_heart("lotus") and "lotus" in V10MjClassicData.st().hearts, "heart on a form")
	check(not V10MjClassicData.toggle_heart("lotus") and not "lotus" in V10MjClassicData.st().hearts, "heart off again")
	# first 7 days the free tiles are lit
	V10MjClassicData.sandbox = {}
	check(V10MjClassicData.light_free("2026-11-24"), "day 1: free tiles lit")
	check(V10MjClassicData.light_free("2026-11-30"), "day 7: still lit")
	check(not V10MjClassicData.light_free("2026-12-01"), "day 8: softer")
	# the layout of the day and its hostess
	check(V10MjClassicData.daily_form("2026-11-24") == V10MjClassicData.daily_form("2026-11-24"), "form of the day is the same for everyone")
	var forms_seen: = {}
	var hosts_seen: = {}
	for k in 30:
		forms_seen[V10MjClassicData.daily_form("2026-12-%02d" % (k + 1))] = true
		hosts_seen[V10MjClassicData.daily_host("2026-12-%02d" % (k + 1))] = true
	check(forms_seen.size() >= 6, "form of the day rotates (%d forms in 30 days)" % forms_seen.size())
	check(hosts_seen.size() >= 4 and hosts_seen.keys().all(func(h): return h in V10MjClassicData.HOSTS), "the hostess of the day rotates among the founders (%d)" % hosts_seen.size())
	check(V10MjClassicData.daily_host("2026-11-24", {"mc": 1}) == "mc", "the hostess is from the roster")
	check(V10MjClassicData.msk_date(0.0) == "1970-01-01" and V10MjClassicData.msk_date(22.0 * 3600.0) == "1970-01-02", "day changes at MSK midnight")
	var fast: = V10MjClassicData.faster_than(120, 72, "2026-11-24")
	var slow: = V10MjClassicData.faster_than(1800, 72, "2026-11-24")
	check(fast > slow and fast >= 90 and slow <= 10, "«быстрее N%%» falls with time (%d → %d)" % [fast, slow])
	V10MjClassicData.sandbox = {}


# ---- the heroine: args.presence, the stage director, the built-in one ---------------------------------------------
func _presence() -> void:
	var host: = Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var r0: = V10MjClassicPresence.resolve(null, host, "rin", {"band_rect": Rect2(0, 0, 720, 140)})
	check(r0[0] is V10MjClassicPresence and r0[0] == r0[1], "no args.presence -> the built-in heroine")
	var m: = _Mock.new()
	var r1: = V10MjClassicPresence.resolve(m, host, "rin", {"avoid": [Rect2(0, 0, 10, 10)]})
	check(r1[0] == m and r1[1] == null and m.avoid.size() == 1, "an object with on/sacred -> used as is, HUD rects passed as avoid")
	var r2: = V10MjClassicPresence.resolve({"junk": 1}, host, "rin", {})
	check(r2[0] is V10MjClassicPresence, "a wrong args.presence -> the built-in heroine")
	if ResourceLoader.exists(STAGE):
		var r3: = V10MjClassicPresence.resolve("stage", host, "hana", {"band_rect": Rect2(0, 0, 720, 140)})
		var o: Object = r3[0]
		check(o != null and o.get_script() != null and String(o.get_script().resource_path) == STAGE and r3[1] == null, "«stage» -> V10MjPresence of the stage lane")
	else:
		check(true, "stage lane absent: built-in heroine (skipped)")
	host.queue_free()


# ---- screens: budget, the heroine never over the sacred zone, the form in the field, look and table ----------------
func _screens() -> void:
	var cases: = [["turtle", "mc", null], ["h_yue", "yue", "stage"], ["butterfly", "hana", null]]
	var tm = load(LOOK) if ResourceLoader.exists(LOOK) else null
	var tt = load(TABLES) if ResourceLoader.exists(TABLES) else null
	for sz in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		for c in cases:
			var vp: = _vp(sz)
			var s: = V10MjClassicScreen.new()
			var a: = {"form": c[0], "hero": c[1], "seed": 3, "fx": "min", "no_save": true, "view": "3d"}
			if c[2] != null:
				a["presence"] = c[2]
			if tm and c[2] != null:
				a["look"] = tm.look_dict("", c[1])
			if tt and c[2] != null:
				a["table"] = tt.theme_for(c[1], "SSR", true)
			vp.add_child(s)
			s.setup(null, a)
			await get_tree().process_frame
			await get_tree().process_frame
			var tag: = "%s %dx%d %s" % [c[0], sz.x, sz.y, "stage" if c[2] != null else "built-in"]
			# UX budget in play: ≤ 6 tappables, ≤ 8 words
			check(s.tappables().size() <= 6 and s.words_in_play() <= 8, "%s: budget taps %d ≤ 6, words %d ≤ 8" % [tag, s.tappables().size(), s.words_in_play()])
			# she never draws over the sacred zone while input is on
			var p: Object = s.presence
			var on: bool = p.is_input_on() if p.has_method("is_input_on") else bool(p.get("input_on"))
			var hits: Array = p.sacred_hits() if p.has_method("sacred_hits") else []
			check(on and hits.is_empty(), "%s: input on, heroine clear of the sacred zone (%d)" % [tag, hits.size()])
			# the sacred zone is the field and the help row
			var sr: Array = p.get("sacred_rects") if "sacred_rects" in p else []
			check(sr.size() == 2 and (sr[0] as Rect2).grow(10).encloses(s.field.get_global_rect()), "%s: field + help row are sacred" % tag)
			# the board fits the field: every tile inside the field at zoom 1
			var fr: Rect2 = s.field.get_global_rect()
			var inside: = true
			for t in s.board.tiles:
				var gp: Vector2 = (t as Tile).get_global_transform_with_canvas().origin
				if not fr.grow(2).has_point(gp):
					inside = false
			check(inside, "%s: whole form inside the field" % tag)
			check(s.board.tile_scale_px() >= 52.0, "%s: tiles ≥ 52 px (%.0f)" % [tag, s.board.tile_scale_px()])
			check(s.board.dressed == (a.has("look") and (a.look as Dictionary).has("v10mj")), "%s: tiles wear args.look when given" % tag)
			check((s.table_view != null) == a.has("table"), "%s: her table of the look lane when args.table is given" % tag)
			check(s.goal_text().begins_with("Осталось %d" % s.board.remaining()), "%s: the goal line" % tag)
			vp.queue_free()
			await get_tree().process_frame


# ---- a match from the first tap to the result (mock presence), the layout of the day ------------------------------
func _flow() -> void:
	var vp: = _vp(Vector2i(720, 1280))
	var m: = _Mock.new()
	var s: = V10MjClassicScreen.new()
	vp.add_child(s)
	s.setup(null, {"form": "cat", "hero": "rin", "seed": 21, "fx": "min", "no_save": false, "presence": m, "need": 8,
		"result_sheet": false, "diff": "junk"})
	await get_tree().process_frame
	check(s.presence == m and s.lite == null, "args.presence drives the screen; no built-in heroine then")
	check(s.diff == "normal", "an unknown difficulty falls back to «Обычная»")
	check(m.rects.size() == 2, "sacred(field) + sacred(help row) sent")
	# a pair by taps: pick + pair, +1 charge
	var hp: = s.board.hint_pair()
	s.board.tap(hp[0])
	s.board.tap(hp[1])
	check("pick" in m.kinds() and "pair" in m.kinds() and s.charge == 1, "a pair: pick, pair, +1 to the ring (%d)" % s.charge)
	var pd: Dictionary = m.events.filter(func(e): return e[0] == "pair")[0][1]
	check(pd.has("charge") and float(pd.charge) > 0.0 and float(pd.charge) <= 1.0, "pair carries the ring 0..1")
	# her signature pair: +25 % of the ring
	var c0: = s.charge
	s._on_pair(null, null, Vector2(100, 100), 9999, int(V10MjClassicLayouts.SIGNATURE["rin"]))
	check(s.charge == c0 + 1 + 2 and "signature" in m.kinds(), "her signature pair: +1 and +25 %% of the ring (%d → %d)" % [c0, s.charge])
	# not ready: a tap on her window only bounces
	check(not s.try_ult(), "Приём waits for a full ring")
	# full ring: a tap on her window casts (Rin shows the pair and what holds it; she takes nothing)
	s.charge = s.need
	var r0: = s.board.remaining()
	m.portrait_tapped.emit()
	await _wait(0.15)
	check(s.ults == 1 and s.charge == 0 and "ult" in m.kinds() and s.last_ult.get("kind", "") == "path" and s.board.remaining() == r0, "her window -> Приём (Rin: the way to a pair)")
	check(s.board.input_on, "input is back after the Приём")
	# auto shuffle: the line on the goal and from her
	s.board.shuffled.emit(true)
	check(s.goal.text == "Ходов нет — перемешала" and "Ходов нет — перемешала" in m.said, "no moves: «Ходов нет — перемешала»")
	# pause: «Плоский/Объёмный» lives there
	s.open_pause()
	await get_tree().process_frame
	var vt: Node = s.sheet.get_meta("panel").get_node_or_null("ViewToggle") if s.sheet and s.sheet.has_meta("panel") else null
	check(vt != null and not s.board.input_on, "pause: input off, «Плоский/Объёмный» in the sheet")
	if vt:
		vt.pressed.emit()
		check(s.board.view == "flat", "the toggle flips the table flat")
		vt.pressed.emit()
	s.close_pause()
	await get_tree().process_frame
	check(s.sheet == null and s.board.input_on, "pause closes, input back")
	# play out to the clean table: the result and its rewards (the screen pays nothing itself)
	var coins_before = G.S.get("coins") if G.get("S") is Dictionary else null
	V10MjClassicData.sandbox = {}
	var got: = [null]
	s.finished.connect(func(r): got[0] = r)
	# the live certificate is the way to a clean table (the hint's pair each time; hint() itself is not pressed)
	var guard: = 0
	while s.board.remaining() > 0 and guard < 100:
		guard += 1
		var hq: = s.board.hint_pair()
		if hq.size() < 2:
			break
		s.board.take(hq[0], hq[1])
	check(s.board.remaining() == 0 and s.board.hints == 0, "the certificate leads to a clean table")
	check("last_pair" in m.kinds(), "last_pair sent")
	for k in 40:
		if got[0] != null:
			break
		await _wait(0.05)
	var res = got[0]
	check(res is Dictionary and "win" in m.kinds(), "win sent, finished(result) emitted")
	if res is Dictionary:
		var keys_ok: = true
		for k in ["mode", "win", "score", "stars", "time_s", "pairs", "hero", "seed", "level", "rewards"]:
			if not res.has(k):
				keys_ok = false
		var rw: Dictionary = res.get("rewards", {})
		check(keys_ok and rw.has("coins") and rw.has("gems") and rw.has("petals") and rw.has("aff"), "result schema §7.1 {mode, win, score, stars, time_s, pairs, hero, seed, rewards{coins, gems, petals, aff}}")
		check(res.mode == "classic" and res.win and res.hero == "rin" and res.form == "cat", "result: classic, won, her, the form")
		check(int(res.stars) == 3 and int(res.ults) == 1, "Приём keeps the ★★★ (clean game = no hints, no shuffles)")
		check(int(rw.coins) == 20 and int(rw.aff) == 1 and res.get("first_today", false), "first win of the day in result.rewards")
	var coins_after = G.S.get("coins") if G.get("S") is Dictionary else null
	check(coins_before == coins_after, "the screen pays nothing itself")
	s.show_result()
	await get_tree().process_frame
	check(s.sheet != null, "the result sheet builds")
	vp.queue_free()
	await get_tree().process_frame
	# the Приём pairs give no charge (Hana takes 2)
	vp = _vp(Vector2i(720, 1280))
	var m2: = _Mock.new()
	var s2: = V10MjClassicScreen.new()
	vp.add_child(s2)
	s2.setup(null, {"form": "turtle", "hero": "hana", "seed": 5, "fx": "min", "no_save": true, "presence": m2, "need": 6})
	await get_tree().process_frame
	s2.charge = s2.need
	var rr: = s2.board.remaining()
	s2.try_ult()
	await _wait(0.15)
	check(s2.board.remaining() == rr - 4 and s2.charge == 0, "Hana «Рывок»: 2 pairs, and they give no charge (%d)" % s2.charge)
	vp.queue_free()
	await get_tree().process_frame
	# «Раскладка дня»: the form and the hostess of the date, her line at the start, time on the goal line
	vp = _vp(Vector2i(720, 1280))
	var m3: = _Mock.new()
	var s3: = V10MjClassicScreen.new()
	vp.add_child(s3)
	var date: = "2026-11-24"
	s3.setup(null, {"variant": "daily", "date": date, "fx": "min", "presence": m3, "no_save": true, "form": "lotus", "mult": 2})
	await _wait(0.2)
	var fname: String = V10MjClassicLayouts.get_form(V10MjClassicData.daily_form(date)).name
	check(s3.form.id == V10MjClassicData.daily_form(date) and s3.diff == "normal", "daily: the form of the date for everyone, «Обычная»")
	check(s3.hero == V10MjClassicData.daily_host(date), "daily: hosted by the heroine of the day (%s)" % s3.hero)
	var line: = "Сегодня у всех «%s»." % fname
	check(line in s3.lines_said and line in m3.said, "daily: her line at the start «%s»" % line)
	check(s3.goal_text().contains("время") and s3.words_in_play() <= 8, "daily: the goal line keeps time (%s)" % s3.goal_text())
	check(int(s3._result(false).mult) == 2, "daily: the Afisha multiplier reaches the result")
	vp.queue_free()
	await get_tree().process_frame


# ---- Memory on screen: her crest, her Приём, the result --------------------------------------------------------
func _memory_screen() -> void:
	var vp: = _vp(Vector2i(720, 1280))
	var m: = _Mock.new()
	var s: = V10MjClassicMemory.new()
	vp.add_child(s)
	s.setup(null, {"size": "4x4", "hero": "mc", "seed": 2, "fx": "min", "no_save": false, "presence": m, "result_sheet": false})
	await get_tree().process_frame
	check(s.presence == m and s.cards.size() == 16, "memory 4×4 with args.presence")
	check(Array(s.goal_text().split(" ", false)).filter(func(w): return not w.is_valid_int() and w != "·").size() <= 8, "memory: goal line ≤ 8 words")
	var f0: = s.found
	s.charge = s.need
	check(s.try_ult() and s.found == f0 + 1, "mc in Memory: her Приём finds a pair")
	vp.queue_free()
	await get_tree().process_frame
	vp = _vp(Vector2i(720, 1280))
	s = V10MjClassicMemory.new()
	vp.add_child(s)
	s.setup(null, {"size": "4x4", "hero": "yue", "seed": 3, "fx": "min", "no_save": true, "presence": _Mock.new()})
	await get_tree().process_frame
	s.charge = s.need
	check(s.try_ult() and s.peeking and s.found == 0, "yue in Memory: every card face up for a moment")
	await _wait(1.15)
	check(not s.peeking, "…and back face down after 1 s")
	vp.queue_free()
	await get_tree().process_frame
	# play it out: perfect memory is ★★★, the result keeps the schema
	vp = _vp(Vector2i(720, 1280))
	m = _Mock.new()
	s = V10MjClassicMemory.new()
	vp.add_child(s)
	V10MjClassicData.sandbox = {}
	s.setup(null, {"size": "4x5", "hero": "rin", "seed": 4, "fx": "min", "no_save": false, "presence": m, "result_sheet": false})
	await get_tree().process_frame
	var got: = [null]
	s.finished.connect(func(r): got[0] = r)
	for pr in s.peek_pairs():
		s.flip(pr[0])
		s.flip(pr[1])
	for k in 40:
		if got[0] != null:
			break
		await _wait(0.05)
	var res = got[0]
	check(res is Dictionary and res.variant == "memory" and res.win and int(res.stars) == 3 and int(res.moves) == 10, "memory: 10 moves on 10 pairs = ★★★")
	if res is Dictionary:
		check(res.has("rewards") and int(res.rewards.coins) == 20 and res.has("seed") and res.has("hero"), "memory result: schema and the first win of the day")
	check("win" in m.kinds(), "memory: win sent")
	vp.queue_free()
	await get_tree().process_frame


# ---- words: §4.3 jargon in every visible string, the heroine's stop-words in her lines -----------------------
func _words() -> void:
	# every string literal with Cyrillic in the module's code (what the player can see)
	var re: = RegEx.new()
	re.compile("\"([^\"\\\\]*[А-Яа-яЁё][^\"\\\\]*)\"")
	var visible: Array = []
	var dir: = "res://scripts/v10/mj/classic/"
	var core_dir: = "res://core/modes/classic/"  # UI-free files moved by WP3: scan both directories
	var scan_files: = []
	for d0 in [dir, core_dir]:
		for f0 in DirAccess.get_files_at(d0):
			scan_files.append(d0 + f0)
	for fp in scan_files:
		var f: String = String(fp).get_file()
		if not f.ends_with(".gd") or f == "classic_selftest.gd":
			continue
		var txt: = FileAccess.get_file_as_string(fp)
		for line in txt.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for mt in re.search_all(line):
				visible.append(mt.get_string(1))
	for fm in V10MjClassicLayouts.all():
		visible.append(String(fm.name))
	check(visible.size() > 60, "visible strings collected (%d)" % visible.size())
	var jar: = []
	for t in visible:
		var low: = String(t).to_lower()
		for w in JARGON:
			if low.contains(w):
				jar.append("%s: %s" % [w, t])
		for w in JARGON_EXACT:
			var rw: = RegEx.new()
			rw.compile("(^|[^A-Za-zА-Яа-яЁё])" + w.replace("+", "\\+") + "($|[^A-Za-zА-Яа-яЁё])")
			if rw.search(String(t)):
				jar.append("%s: %s" % [w, t])
	check(jar.is_empty(), "no §4.3 jargon in visible strings %s" % str(jar.slice(0, 3)))
	# her lines (what she says) through V10Lint, if the class is in the tree, else the local copy of §4.3 above
	var hers: Array = []
	hers.append_array(V10MjClassicPresence.IDLE_LINES)
	hers.append_array(["Стол чист! Красиво.", "Ходов нет — перемешала", "Все нашлись. У тебя хорошая память."])
	for fm in V10MjClassicLayouts.classic_forms():
		hers.append("Сегодня у всех «%s»." % fm.name)
	for h in V10MjClassicData.HOSTS:
		hers.append(V10MjClassicUlts.ult_name(h))
		hers.append(V10MjClassicUlts.desc(h))
	if ResourceLoader.exists(LINT):
		var lint = load(LINT)
		var dirty: Array = lint.scan(hers)
		check(dirty.is_empty(), "her lines pass V10Lint %s" % str(dirty.slice(0, 2)))
	else:
		check(true, "V10Lint absent: §4.3 list only")
	# simple words: no «ульта», the Приём is «Приём»
	check(not V10MjClassicInfo.INFO.line.to_lower().contains("ульт") and V10MjClassicInfo.HOW.size() == 3, "«Как играть»: 3 lines")
	check(V10MjClassicStyle.TOK.night900 == V10DS.NIGHT_900 and V10MjClassicStyle.TOK.rose500 == V10DS.ROSE_500, "tokens aliased to V10DS")
	var sv_box: = {}
	var sv_d: = V10MjClassicSave.st(sv_box)
	check(sv_box.has(V10MjClassicSave.KEY) and sv_d is Dictionary, "V10MjClassicSave.st(S) idempotent")
	var raw_time: = 0
	for f2 in DirAccess.get_files_at(dir):
		if f2.ends_with(".gd") and f2 != "classic_selftest.gd":
			var tx2: = FileAccess.get_file_as_string(dir + f2)
			raw_time += tx2.count("Time." + "get_unix_time_from_system") + tx2.count("Time." + "get_date_string_from_system")
	check(raw_time == 0, "zero raw Time.*_from_system calls (%d)" % raw_time)


# ---- snapshots of the demo (only with --mj_classic_shots=<dir>) -----------------------------------------------------
func _shots() -> void:
	var dir: = String(args.get("mj_classic_shots", ""))
	if dir == "":
		print("  shots: skipped (no --mj_classic_shots=<dir>)")
		return
	for tag in [["720", Vector2i(720, 1280)], ["1080", Vector2i(1080, 2400)]]:
		for nm in SHOT_NAMES:
			var p: = "%s/classic_%s_%s.png" % [dir, tag[0], nm]
			var good: = FileAccess.file_exists(p)
			if good:
				var img: = Image.load_from_file(p)
				good = img != null and img.get_size() == tag[1]
				if good:
					# not a blank frame: many colours across the picture
					var cols: = {}
					for k in 300:
						var px: = img.get_pixel((k * 7919) % img.get_width(), (k * 104729) % img.get_height())
						cols[px.to_html(false).substr(0, 4)] = true
					good = cols.size() > 12
			check(good, "shot %s" % p.get_file())
