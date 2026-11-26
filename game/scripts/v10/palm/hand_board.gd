class_name V10HandBoard
extends TrayBoard

# «Чтение руки» — the table: a TrayBoard whose pairs are PLANNED (the day's entry) and whose faces are riichi tiles.
#
#   var b := V10HandBoard.new(); host.add_child(b)
#   b.setup(V10HandGen.board_cfg(entry))      # layout + planned pairs in step order + deal seed
#   b.kind_taken.connect(func(k): session.reveal(k))   # every pair taken (tray match, or vanish by a help)
#   b.failed → «Стол закрыт» (session.close_table()); the guess stays available
#
# _assign(cfg) is TrayBoard._assign with two changes: the random walk over free tiles uses its own generator seeded
# with cfg.deal_seed (never the global randi), and pair k gets cfg.pairs[k] (the planned kind) instead of a random
# face. The walk is the same, so the board is solvable by the step order exactly like a normal deal; V10HandGen.deal()
# is the same walk as a pure model (the selftest compares both tile by tile).
# Faces: Tile.face = riichi kind 0..33 (pairs compare faces, as always). Tile.build / set_face load G.tile_tex(face);
# skin() swaps every face sprite to the baked riichi face (assets/v10/palm/faces/fNN.png, 185×192 like a game face,
# so the porcelain shader and its bevel fit) after setup and after reassign_faces (shuffle). No secret / ice / gold /
# shard tiles exist on this board, so no flip ever reverts a face. The clarity suit mark (V10Marks) is removed: it
# describes the game's own 36 faces, not riichi kinds.

signal kind_taken(kind: int)

const FACE_DIR: = "res://assets/v10/palm/faces/f%02d.png"
const RIICHI_ART: = "res://assets/v08/table/t%02d.png"
const SLOTS_HAND: = 5   # recommended tray size for this mode (the screen sets slot_pos / slots)

static var _tex: = {}

var plan: Array = []
var deal_seed: = 1


func _ready() -> void:
	super._ready()
	matched.connect(func(_mid, _combo, _gold, _shard): kind_taken.emit(last_face))


static func face_tex(kind: int) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var p: = FACE_DIR % kind
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if t == null and ResourceLoader.exists(RIICHI_ART % kind):
		t = load(RIICHI_ART % kind)
	_tex[kind] = t
	return t


func setup(cfg: Dictionary) -> void:
	plan = (cfg.get("pairs", []) as Array).duplicate()
	deal_seed = int(cfg.get("deal_seed", 1))
	super.setup(cfg)
	skin()


func _assign(cfg: Dictionary) -> void:
	var r: = RandomNumberGenerator.new()
	r.seed = int(cfg.get("deal_seed", deal_seed))
	var pairs: Array = cfg.get("pairs", plan)
	var left: Array = tiles.duplicate()
	var order: = []
	var gone: = {}
	while not left.is_empty():
		var fr: = left.filter(func(t): return _free_if(t, func(o): return not gone.has(o)))
		var pick: Tile = fr[r.randi() % fr.size()]
		order.append(pick)
		left.erase(pick)
		gone[pick] = true
	var npairs: = order.size() / 2
	if pairs.size() != npairs:
		push_warning("V10HandBoard: %d planned pairs for a layout of %d pairs" % [pairs.size(), npairs])
	for k in npairs:
		var a: Tile = order[2 * k]
		var b: Tile = order[2 * k + 1]
		a.face = int(pairs[k]) if k < pairs.size() else int(pairs[k % maxi(1, pairs.size())])
		b.face = a.face
		a.step = k
		b.step = k
		a.gold = false
		b.gold = false
		a.ice = 0
		b.ice = 0
		a.shard = ""
		b.shard = ""
		a.secret = false
		b.secret = false


# riichi faces on every tile (call again after anything that sets faces through Tile.set_face)
func skin() -> void:
	for t in tiles:
		if not is_instance_valid(t) or t.face_spr == null:
			continue
		var m: = t.get_node_or_null("V10Marks")
		if m:
			t.remove_child(m)
			m.queue_free()
		var tx: = face_tex(t.face)
		if tx:
			t.face_spr.texture = tx
			if tx.get_width() != 185:
				# fallback art 144×200: same height as the face, centred, no stretch
				var s: = (Tile.TH / float(tx.get_height()))
				t.face_spr.scale = Vector2(s, s)


func reassign_faces(ts: Array) -> void:
	super.reassign_faces(ts)
	skin()


# the clarity long-press bubble (V10TileInfo) explains the game's own faces, not riichi kinds: taps go straight to
# the board; the deal-skip path of TrayBoard is kept
func _unhandled_input(e: InputEvent) -> void:
	if not input_on or not (e is InputEventScreenTouch and e.pressed):
		super._unhandled_input(e)
		return
	var t: = tile_at(e.position)
	if t:
		tap(t)
		get_viewport().set_input_as_handled()


# kinds and their copies on the table right now (not taken yet)
func on_board_counts() -> Array:
	var c: = []
	c.resize(34)
	c.fill(0)
	for t in tiles:
		if on_board(t) and t.face >= 0 and t.face < 34:
			c[t.face] += 1
	return c
