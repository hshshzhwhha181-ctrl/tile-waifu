class_name TWFree
extends RefCounted

# TWFree (P16 / WP5): the geometry of the tile table and the ONE rule of a "free" tile, as pure static code with no
# Node, no Tile and no render stack. tray_board, V10LevelSim and the mode boards (triples, garden, classic, ...) each
# carry their own copy of this rule; TWBoard and every later mode board take it from here.
#
# Grid: tiles sit on integer cells (x, y, z); a tile is 2 cells wide and 2 cells high, layer z sits half a tile off the
# layer below, so x and y of layer z have the parity of z.
#
# THE rule (identical to tray_board.is_free / V10LevelSim.is_free):
#   a tile is COVERED by a present tile o with o.z > t.z, |o.x - t.x| < 2 and |o.y - t.y| < 2;
#   a tile is FREE when nothing present covers it AND NOT (a present tile on the left side AND a present tile on the
#   right side). Left/right = same z, dx = -2 / +2, |dy| < 2.
#   "present" = on the table: not taken and not sitting in the tray.
#
#   TWFree.gen_layout(cfg)        the cell list of a board config (cols, rows, layers, fill, shape, upper, seed)
#   TWFree.positions(cfg)         gen_layout + the odd tile removed + sorted: the tile ids of tray_board.setup / V10LevelGen
#   TWFree.topology(pos)          {cov_by, covers, lft, rgt, lft_of, rgt_of}: adjacency lists by tile id
#   TWFree.world(pos)             Vector2 of a cell on the table in tray_board pixels (blast radius, hint distance, views)
#
# gen_layout draws from the ENGINE generator seeded with cfg.seed, on purpose: the certificates of the 1000 Path levels
# (levels_bake.json) and the baked triples / bridge tables were made from exactly this stream, and WP5 forbids altering
# the generators. Everything TWBoard deals on top of a layout (faces, ice, gold, ...) uses TWRng instead.

const MAX_COLS: = 6
const MAX_ROWS: = 9

# tray_board / Tile pixel constants (Tile.TW = 84, Tile.S = TW / 185, Tile.TH = 192 * S); only distances are used
const TW: = 84.0
const TH: = 192.0 * (84.0 / 185.0)
const UX: = TW * 0.5 + 1.0
const UY: = TH * 0.5 + 1.0
const DZ: = Vector2(-6.0, -13.0)


static func shape_keep(shape: String, i: int, j: int, C: int, R: int) -> bool:
	var x: float = (2.0 * i / max(1, C - 1)) - 1.0
	var y: float = (2.0 * j / max(1, R - 1)) - 1.0
	var ax: = absf(x)
	match shape:
		"heart":
			return not (y > 0.25 and ax > 1.05 - (y - 0.25) * 1.25) and not (y < -0.8 and ax < 0.3)
		"diamond":
			return ax * 0.8 + absf(y) * 0.75 <= 1.12
		"butterfly":
			return not (ax < 0.3 and absf(y) > 0.4)
		"cross":
			return ax < 0.45 or absf(y) < 0.4
		"ring":
			return not (ax < 0.3 and absf(y) < 0.4)
		"pyramid":
			return ax <= (y + 1.0) * 0.5 + 0.25
		"towers":
			return ax > 0.3 or y > 0.6
	return V6Layouts.keep(shape, x, y)


static func gen_layout(cfg: Dictionary) -> Array:
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var C: int = cfg.cols
	var R: int = cfg.rows
	var L: int = cfg.layers
	if C > MAX_COLS:
		R = mini(R + (C - MAX_COLS), MAX_ROWS)
		L += 1
		C = MAX_COLS
	var fill: float = cfg.get("fill", 0.65)
	if int(cfg.cols) > MAX_COLS:
		fill = minf(0.95, fill * 1.3)
	var shape: String = cfg.get("shape", "rect")
	var pos: = []
	var occ: = {}
	for i in C:
		for j in R:
			if not shape_keep(shape, i, j, C, R):
				continue
			var corner: = (i == 0 or i == C - 1) and (j == 0 or j == R - 1)
			if shape == "rect" and corner and L >= 3 and rng.randf() < 0.5:
				continue
			pos.append(Vector3i(2 * i, 2 * j, 0))
			occ[Vector3i(2 * i, 2 * j, 0)] = true
	for z in range(1, L):
		var xs: = range(z, 2 * (C - 1) - z + 1, 2)
		var ys: = range(z, 2 * (R - 1) - z + 1, 2)
		if xs.is_empty() or ys.is_empty():
			break
		var mid: float = (xs[0] + xs[xs.size() - 1]) * 0.5
		var keep: = {}
		var dens: = fill * pow(0.88, z - 1)
		for yy in ys:
			for xx in xs:
				if xx > mid:
					continue
				var sup: = 0
				for dx in [-1, 1]:
					for dy in [-1, 1]:
						if occ.has(Vector3i(xx + dx, yy + dy, z - 1)):
							sup += 1
				var mx: = int(round(2 * mid - xx))
				var sup_m: = 0
				for dx in [-1, 1]:
					for dy in [-1, 1]:
						if occ.has(Vector3i(mx + dx, yy + dy, z - 1)):
							sup_m += 1
				if sup < 3 or sup_m < 3:
					continue
				if rng.randf() < dens * V6Layouts.upper_w(cfg.get("upper", ""), xx, yy, z, xs, ys):
					keep[Vector2i(xx, yy)] = true
		for k in keep:
			pos.append(Vector3i(k.x, k.y, z))
			occ[Vector3i(k.x, k.y, z)] = true
			var mx: = int(round(2 * mid - k.x))
			if mx != k.x:
				pos.append(Vector3i(mx, k.y, z))
				occ[Vector3i(mx, k.y, z)] = true
	return pos


# the take-order key of tray_board.setup: layer first, then row, then column
static func sort_positions(pos: Array) -> void:
	pos.sort_custom( func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)


# gen_layout as the tile table: an odd count loses its first top-most cell, then the cells are sorted (tile id = index)
static func positions(cfg: Dictionary) -> Array:
	var pos: Array = gen_layout(cfg)
	if pos.size() % 2 == 1:
		var top: = 0
		for k in pos.size():
			if pos[k].z > pos[top].z:
				top = k
		pos.remove_at(top)
	sort_positions(pos)
	return pos


# geometry of the cover rule for one pair of cells: does `o` lie on top of `t`
static func covers(o: Vector3i, t: Vector3i) -> bool:
	return o.z > t.z and absi(o.x - t.x) < 2 and absi(o.y - t.y) < 2


# Adjacency by tile id (index into `pos`). Works for any cell list, not only the lattice gen_layout produces.
#   cov_by[i]  tiles lying on top of i        covers[j]   tiles j lies on top of      (inverse of each other)
#   lft[i] / rgt[i]   the same-layer neighbours at dx = -2 / +2 (|dy| < 2)            lft_of[j] / rgt_of[j]  inverse
static func topology(pos: Array) -> Dictionary:
	var n: = pos.size()
	var at: = {}
	var maxz: = 0
	for i in n:
		var p: Vector3i = pos[i]
		at[p] = i
		maxz = maxi(maxz, p.z)
	var cov_by: = []
	var covers_: = []
	var lft: = []
	var rgt: = []
	var lft_of: = []
	var rgt_of: = []
	for i in n:
		cov_by.append([])
		covers_.append([])
		lft.append([])
		rgt.append([])
		lft_of.append([])
		rgt_of.append([])
	for i in n:
		var p: Vector3i = pos[i]
		for zz in range(p.z + 1, maxz + 1):
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var o: int = at.get(Vector3i(p.x + dx, p.y + dy, zz), -1)
					if o >= 0:
						cov_by[i].append(o)
						covers_[o].append(i)
		for dy in [-1, 0, 1]:
			var l: int = at.get(Vector3i(p.x - 2, p.y + dy, p.z), -1)
			if l >= 0:
				lft[i].append(l)
				lft_of[l].append(i)
			var r: int = at.get(Vector3i(p.x + 2, p.y + dy, p.z), -1)
			if r >= 0:
				rgt[i].append(r)
				rgt_of[r].append(i)
	return {"cov_by": cov_by, "covers": covers_, "lft": lft, "rgt": rgt, "lft_of": lft_of, "rgt_of": rgt_of}


# the free test on COUNTS of present neighbours (what an incremental board keeps)
static func free_by_counts(covered: int, left: int, right: int) -> bool:
	return covered == 0 and not (left > 0 and right > 0)


# the free test on a "present" predicate over tile ids (slow path: tests, one-off checks, other modes without counters)
static func is_free(i: int, topo: Dictionary, present: Callable) -> bool:
	for o in topo.cov_by[i]:
		if present.call(o):
			return false
	var l: = false
	for o in topo.lft[i]:
		if present.call(o):
			l = true
			break
	if not l:
		return true
	for o in topo.rgt[i]:
		if present.call(o):
			return false
	return true


# the table position of a cell in tray_board pixels, relative to cell (0, 0, 0)
static func world(p: Vector3i) -> Vector2:
	return Vector2(p.x * UX, p.y * UY) + DZ * p.z
