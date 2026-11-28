class_name TrayBridge
extends RefCounted

# The seam between the tray board's Tile nodes and TWBoard (P18). The tiles are where skills, ults and the special / level /
# hand boards read and write, so every rule operation first copies them into the rules engine (load) and, when the
# operation moved tiles between the table and the tray, reads the tray lists back (pull). No rule is decided here.


# the tiles (on the table / alive / face / step / gold / ice / hidden / shard / forced free) and the tray, as they are now
static func load(b: TrayBoard) -> void :
	var n: = b.tiles.size()
	var pr: = PackedByteArray()
	var al: = PackedByteArray()
	var gd: = PackedByteArray()
	var ic: = PackedByteArray()
	var sc: = PackedByteArray()
	var sh: = PackedByteArray()
	var op: = PackedByteArray()
	var fc: = PackedInt32Array()
	var sp: = PackedInt32Array()
	for a in [pr, al, gd, ic, sc, sh, op, fc, sp]:
		a.resize(n)
	for i in n:
		var t: Tile = b.tiles[i]
		pr[i] = 1 if b.on_board(t) else 0
		al[i] = 1 if t.alive else 0
		gd[i] = 1 if t.gold else 0
		ic[i] = t.ice
		sc[i] = 1 if t.secret else 0
		sh[i] = 1 if t.shard != "" else 0
		op[i] = 1 if b.opened.has(t) else 0
		fc[i] = t.face
		sp[i] = t.step
	b.core.load_view({"present": pr, "alive": al, "face": fc, "step": sp, "gold": gd, "ice": ic, "sec": sc, "shard": sh, "opened": op,
		"tray": b._ids(b.tray), "history": b._ids(b.history)})
	b.core.slots = b.slots
	b.core.cracks = b.cracks
	b.core.max_tray = b.max_tray


# the tray, the undo history and the counters the operation changed
static func pull(b: TrayBoard) -> void :
	b.tray.clear()
	b.history.clear()
	for i in b.core.tray:
		b.tray.append(b.tiles[i])
	for i in b.core.history:
		b.history.append(b.tiles[i])
	b.max_tray = b.core.max_tray
	b.cracks = b.core.cracks


# cov / sides (Tile -> the tiles on it / its left and right neighbours): the topology of the table, for readers of the old API
static func topology(b: TrayBoard) -> void :
	b.cov.clear()
	b.sides.clear()
	var of: = func(ids: Array) -> Array: return ids.map( func(i): return b.tiles[i])
	for i in b.tiles.size():
		b.cov[b.tiles[i]] = of.call(b.core.cov_by[i])
		b.sides[b.tiles[i]] = [of.call(b.core.lft[i]), of.call(b.core.rgt[i])]


# the tiles take the deal TWBoard made (faces, steps, gold, ice, secret, shard)
static func take_deal(b: TrayBoard, shard: String) -> void :
	for i in b.tiles.size():
		var t: Tile = b.tiles[i]
		t.face = b.core.face0[i]
		t.step = b.core.step0[i]
		t.gold = b.core.gold0[i] == 1
		t.ice = b.core.ice0[i]
		t.secret = b.core.secret0[i] == 1
		if b.core.shard0[i] == 1:
			t.shard = shard
