class_name V10LevelBoard
extends V6SpecialBoard

# 0.10: the play board for generated Path levels. Same visuals and rules as V6SpecialBoard; the only difference is
# that faces / steps / ice / secret / gold / shard and the specials come from the level's precomputed payload
# (V10LevelGen.build(i).v10) instead of the unseeded random deal — so the board the player sees is exactly the one
# the verifier proved solvable and the bot measured. Falls back to the old random deal if the payload does not fit.

var v10: = {}
var v10_used: = false


func _assign(cfg: Dictionary) -> void :
	v10 = cfg.get("v10", {})
	v10_used = false
	if v10.is_empty() or int(v10.get("n", -1)) != tiles.size() or not _same_layout(v10.get("pos", PackedInt32Array())):
		if not v10.is_empty():
			push_warning("V10LevelBoard: payload does not match the layout of %s, falling back to a random deal" % str(cfg.get("code", "?")))
		super._assign(cfg)
		return
	v10_used = true
	var sh: String = cfg.get("shard", "")
	for i in tiles.size():
		var t: Tile = tiles[i]
		t.face = int(v10.face[i])
		t.step = int(v10.step[i])
		t.gold = int(v10.gold[i]) == 1
		t.ice = int(v10.ice[i])
		t.secret = int(v10.secret[i]) == 1
		if int(v10.shard[i]) == 1 and sh != "":
			t.shard = sh
			t.face = 100


func _same_layout(p) -> bool:
	if p.size() != tiles.size() * 3:
		return false
	for i in tiles.size():
		var t: Tile = tiles[i]
		if t.gx != int(p[3 * i]) or t.gy != int(p[3 * i + 1]) or t.gz != int(p[3 * i + 2]):
			return false
	return true


func apply_specials(p: Dictionary) -> void :
	if not v10_used:
		super.apply_specials(p)
		return
	plan = p
	spec.clear()
	icons.clear()
	pairs_done = 0
	const KINDS: = ["", "key", "lock", "chain", "joker", "bomb", "gift"]
	for e in v10.get("spec", []):
		var a: Tile = tiles[int(e[0])]
		var b: Tile = tiles[int(e[1])]
		var kind: String = KINDS[int(e[2])]
		var d: = {"kind": kind}
		if kind == "key" or kind == "lock":
			d["group"] = int(e[3])
		if kind == "lock":
			d["open"] = false
		if kind == "chain":
			d["n"] = int(e[3])
		spec[a] = d.duplicate()
		spec[b] = d.duplicate()
		spec[a].mate = b
		spec[b].mate = a
		if kind == "joker":
			for t in [a, b]:
				t.face = JOKER
				t.face_spr.visible = false
	for t in spec:
		_add_icon(t)


# Softlock guard: V6SpecialBoard.unstick() runs only after a pair. If the tile just put in the tray (no pair) was the
# last free takeable one and every other free tile is locked/chained, the player had no move and no fail. Open them
# here too (the sim mirrors this rule). A full tray is the fail path and is left alone.
func tap(t: Tile) -> void :
	super.tap(t)
	if v10_used and is_instance_valid(t) and tray.has(t) and not t.pending and tray.size() < slots:
		unstick()


# auto-play (playtest, fuzz, demo): the twin of a tray tile, else the next tile of the verified take order.
# (Pairing by face alone can swap twins between pairs of one face and overfill the tray later.)
func solver_move() -> Tile:
	if not v10_used:
		return super.solver_move()
	var fr: = free_tiles()
	for x in tray:
		for t in fr:
			if t.face == x.face and t.step == x.step:
				return t
	for idx in v10.get("cert", PackedInt32Array()):
		var t: Tile = tiles[int(idx)]
		if on_board(t) and not t.pending:
			if fr.has(t):
				return t
			break
	return super.solver_move()
