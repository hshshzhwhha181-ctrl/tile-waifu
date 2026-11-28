class_name TWBoardView
extends Control

# TWBoardView (P31 / WP10a): the match view of the v11 shell. It READS the events TWBoard returns (TWBoardEvents) and plays an
# animation timeline for them; it contains no rule. The core resolves a move instantly and the view only paints that outcome
# late, so nothing the timeline does can change a game (tested: 100 games with and without a view end in the same state).
#
#   v.bind(board)                     mirror the board as it is now (a game in progress is fine); the view never calls a board
#                                     operation that changes it (it only reads is_free / takeable / arrays), tools lint that
#   v.configure(vs, insets)           pure layout (compute()) for a viewport: field >= 94% of the width and 62% of the height,
#                                     the tray below it, tile 56 / 64 / 72 / 80 px at base 720 (S / M / L / XL)
#   v.play(events) -> float           schedule the animation of an event list (seconds until it is over); the logical mirror
#                                     (which tile is on the table / in the tray) changes at once, only the pictures lag
#   v.advance(dt)                     the timeline clock (the node drives it from _process unless `manual`)
#   v.finish()                        end every animation now (the mirror is then exactly the board)
#   tile_tapped(id)                   a tap on a free-looking tile; the SCREEN decides what the tap means
#
# Timeline (GDD 9.7): press lift 6 px at once, a tapped tile lifts 90 ms then the pair flies together 180 ms (EXPO OUT, sparks
# 6 / 12 / 18 by combo), a tile flies into the tray on an arc 160 ms, neighbours that lost their cover settle 2 px in 40 ms,
# a tap on a covered tile shakes it 120 ms without red.  Every one of the 20 core events has a picture (EVENT_ANIM).
#
# Draw: one CanvasItem, no child nodes, textures only through TWAssets ids (tiles.NN_name), colours only from TWTokens/TWSkin.

signal tile_tapped(id: int)
signal idle
signal played(types: PackedStringArray, duration: float)

const SIZE_KEYS: = ["S", "M", "L", "XL"]
const SIZE_PX: = {"S": 56, "M": 64, "L": 72, "XL": 80}     # tile width at base 720 (GDD 7.2)
const FIELD_W: = 0.94                                       # field width / screen width (>= 92%)
const FIELD_H: = 0.62                                       # field height / screen height (>= 60%)
const PRESS_LIFT: = 6.0                                     # px at base 720, same frame as the press
const T_LIFT: = 0.09
const T_FLY: = 0.18
const T_TRAY: = 0.16
const T_SETTLE: = 0.04
const T_SHAKE: = 0.12
const T_FLASH: = 0.12
const T_LIT: = 0.08
const SETTLE_PX: = 2.0
const ASPECT: = TWFree.TH / TWFree.TW                       # tile height / width
const BLOCKED_MIX: = 0.5                                    # PAPER_300 -> PAPER_500 (brightness ~0.72 of a free tile)
const FACE_IDS_PREFIX: = "tiles."

# every core event type has an animation; the value says which picture it is (selftest: 20/20, 0 unknown)
const EVENT_ANIM: = {
	"MATCH": "lift 90 ms, then the pair flies together 180 ms, sparks by combo, neighbours settle",
	"TO_TRAY": "arc into the slot 160 ms, landing pulse",
	"TRAY_WARN": "the last free slot pulses until the tray has room again (the visual stand-in of the heartbeat)",
	"TRAY_FULL": "tray tiles shake, tray tints ember, field dims",
	"CLEARED": "gold sweep over the field and a spark burst",
	"DENY": "shake 120 ms, no red",
	"BLOCKED": "shake 120 ms with a gold flash",
	"ICE_CRACK": "crack flash and shake 120 ms, frost layer drops",
	"REVEAL": "flip from the back to the face 160 ms",
	"JOKER": "face swap with a flash",
	"UNLOCK": "lock badges open with a gold ring",
	"UNCHAIN": "chain badge drops with a gold ring",
	"UNSTICK": "jade shimmer sweep over the field",
	"GIFT": "gold sparks at the pair",
	"BLAST": "neighbouring pairs fade out with a ring",
	"UNDO": "arc from the tray back to its place 160 ms",
	"RETURN": "tray tiles arc back, staggered",
	"SHUFFLE": "every dealt tile flips to its new face",
	"VANISH": "pair dissolves in a glow with sparks",
	"MOONLIGHT": "secret tiles flip, ice melts, jade wash",
}

static var _face_ids: Dictionary = {}       # face number -> TWAssets id, filled once

# ---- layout (set by configure) ----
var size_key: = "M"
var slots: = 4
var field: = Rect2()
var tray_rect: = Rect2()
var tile_w: = 64.0
var tile_h: = 64.0 * ASPECT
var wscale: = 1.0                           # world (TWFree pixels) -> screen
var origin: = Vector2.ZERO
var fits: = true
var tray_scale: = 1.0                       # tray tile width / table tile width
var accent: Color = TWTokens.GOLD_300       # spark tint (hero tag)
var input_enabled: = true
var manual: = false                         # tests drive advance() themselves

# ---- the board and the mirror ----
var board: TWBoard = null
var n: = 0
var m_where: = PackedByteArray()            # 0 table, 1 tray, 2 gone: the LOGICAL mirror (changes in play())
var m_tray: Array = []                      # tile ids, slot order
var v_face: = PackedInt32Array()            # what is drawn (changes when the picture does)
var v_ice: = PackedByteArray()
var v_sec: = PackedByteArray()
var v_kind: = PackedByteArray()
var gold: = PackedByteArray()
var shard: = PackedByteArray()
var vis: = PackedByteArray()
var hi: = PackedByteArray()                 # drawn on top (flying)
var p_cur: = PackedVector2Array()           # centre
var p_off: = PackedVector2Array()           # shake / settle / lift
var p_scl: = PackedFloat32Array()           # width factor relative to a table tile
var p_alp: = PackedFloat32Array()
var p_flip: = PackedFloat32Array()
var p_flash: = PackedFloat32Array()
var v_lit: = PackedFloat32Array()
var lit_goal: = PackedByteArray()
var _table: = PackedVector2Array()
var _slotc: = PackedVector2Array()
var _pos: Array = []
var _slot_of: Dictionary = {}               # tile id -> the tray slot its last move was scheduled to

# ---- timeline ----
var _t: = 0.0
var _seq: = 0
var _pending: Array = []
var _active: Array = []
var _fx: Array = []
var _owner: Dictionary = {}                 # "mv:<id>" / "off:<id>" -> the clip that owns that channel
var _dim: = 0.0
var _tray_tint: = 0.0
var _warn: = false
var _warn_t: = 0.0
var _hint: Array = []
var _hint_t: = 0.0
var _pressed: = -1
var last_clips: = 0                         # clips + ops + fx the last play() scheduled
var last_type_clips: Dictionary = {}        # event type -> clips its handler scheduled in the last play()
var last_draw_us: = 0                       # script time of the last _draw (the draw list, not the GPU)
var draws: = 0                              # _draw calls (the perf test checks the frames really drew)
var last_unknown: PackedStringArray = PackedStringArray()
var stats: = {"clips": 0, "frames": 0, "plays": 0}

var _unit_rr: = PackedVector2Array()
var _unit_rr_closed: = PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_unit_rr = TWDraw.rr_pts(Rect2(0, 0, 1, 1), 0.15, 4)
	_unit_rr_closed = _unit_rr.duplicate()
	_unit_rr_closed.append(_unit_rr[0])


func _ready() -> void:
	set_process(not manual)


func _process(delta: float) -> void:
	if manual:
		return
	var live: = not idle_now() or _warn or not _hint.is_empty()
	if live:
		advance(delta)


# =================================================================== layout (pure)

static func tile_px(key: String, vs_w: float) -> float:
	return float(SIZE_PX.get(key, SIZE_PX["M"])) * vs_w / float(TWTokens.BASE_WIDTH)


# The geometry of a viewport: where the field and the tray are and how big a tile is. A pure function of its arguments.
#   positions       the tile cells of the board (Vector3i, TWBoard.pos)
#   top_reserved    px (screen) a HUD keeps free above the field
static func compute(vs: Vector2, insets: Dictionary, positions: Array, p_slots: int, key: String, top_reserved: float = 0.0) -> Dictionary:
	var k: = vs.x / float(TWTokens.BASE_WIDTH)
	var gap: = float(TWTokens.GRID) * k
	var top: = float(insets.get("top", 0.0)) + top_reserved + gap
	var fw: = vs.x * FIELD_W
	var fh: = vs.y * FIELD_H
	var fr: = Rect2((vs.x - fw) * 0.5, top, fw, fh)
	var tray_h: = float(TWTokens.TRAY_H) * k
	var tr: = Rect2(fr.position.x, fr.end.y + gap, fw, tray_h)
	# the world bounding box of the tiles (tile rect + the thickness the draw adds)
	var bb: = Rect2()
	var first: = true
	for p in positions:
		var c: = TWFree.world(p)
		var r: = Rect2(c - Vector2(TWFree.TW, TWFree.TH) * 0.5, Vector2(TWFree.TW * 1.06, TWFree.TH * 1.08))
		bb = r if first else bb.merge(r)
		first = false
	if first:
		bb = Rect2(Vector2.ZERO, Vector2(TWFree.TW, TWFree.TH))
	var want: = tile_px(key, vs.x) / TWFree.TW
	var fit: = minf(fr.size.x / bb.size.x, fr.size.y / bb.size.y)
	var s: = minf(want, fit)
	var org: = fr.get_center() - bb.get_center() * s
	# tray: slots in one row, tiles sized by the slot and the tray height
	var pitch: = minf(tr.size.x / float(maxi(1, p_slots)), tr.size.y * 1.15)
	var tw_t: = minf(pitch * 0.88, tr.size.y * 0.88 / ASPECT)
	var slot_c: = PackedVector2Array()
	var x0: = tr.get_center().x - pitch * float(p_slots) * 0.5
	for i in p_slots:
		slot_c.append(Vector2(x0 + pitch * (float(i) + 0.5), tr.get_center().y))
	var tiles: = PackedVector2Array()
	for p in positions:
		tiles.append(org + TWFree.world(p) * s)
	return {"field": fr, "tray": tr, "scale": s, "tile_w": TWFree.TW * s, "tile_h": TWFree.TH * s, "origin": org,
		"fits": want <= fit + 0.0001, "tray_tile_w": tw_t, "tray_scale": tw_t / maxf(1.0, TWFree.TW * s),
		"slot_centers": slot_c, "tile_centers": tiles, "board_px": Rect2(bb.position * s + org, bb.size * s), "pitch": pitch}


static func face_id(face: int) -> String:
	if _face_ids.is_empty():
		for id in TWAssets.ids():
			if id.begins_with(FACE_IDS_PREFIX):
				var rest: = id.substr(FACE_IDS_PREFIX.length())
				if rest.length() > 3 and rest[2] == "_" and rest.substr(0, 2).is_valid_int():
					_face_ids[int(rest.substr(0, 2))] = id
	return str(_face_ids.get(face, ""))


# =================================================================== bind / configure

func bind(b: TWBoard, key: String = "") -> void:
	board = b
	n = b.n
	_pos = b.pos
	slots = b.slots
	if key != "":
		size_key = key
	_clear_timeline()
	_alloc()
	_slot_of.clear()
	_mirror_from_board()
	if size.x > 0.0 and size.y > 0.0:
		configure(size, TWDraw.safe_insets(size))
	else:
		_layout(compute(Vector2(TWTokens.BASE_WIDTH, 1280), {}, _pos, slots, size_key))
	queue_redraw()


func unbind() -> void:
	board = null
	n = 0
	_clear_timeline()
	_alloc()


func configure(vs: Vector2, insets: Dictionary = {}, top_reserved: float = 0.0) -> void:
	_layout(compute(vs, insets, _pos, slots, size_key, top_reserved))
	queue_redraw()


func set_size_key(key: String, vs: Vector2 = Vector2.ZERO) -> void:
	size_key = key if SIZE_PX.has(key) else "M"
	var v: = vs if vs != Vector2.ZERO else (size if size.x > 0.0 else Vector2(TWTokens.BASE_WIDTH, 1280))
	configure(v, TWDraw.safe_insets(v))


func _layout(g: Dictionary) -> void:
	field = g.field
	tray_rect = g.tray
	tile_w = g.tile_w
	tile_h = g.tile_h
	wscale = g.scale
	origin = g.origin
	fits = g.fits
	tray_scale = g.tray_scale
	_table = g.tile_centers
	_slotc = g.slot_centers
	# tiles at rest follow the new layout; flying ones are left alone
	for i in n:
		if _owner.has("mv:%d" % i):
			continue
		p_cur[i] = _home(i)
		p_scl[i] = tray_scale if m_where[i] == 1 else 1.0


func _alloc() -> void:
	m_where = PackedByteArray()
	m_where.resize(n)
	m_where.fill(0)
	m_tray = []
	v_face = PackedInt32Array()
	v_face.resize(n)
	v_face.fill(0)
	v_ice = _bytes(n, 0)
	v_sec = _bytes(n, 0)
	v_kind = _bytes(n, 0)
	gold = _bytes(n, 0)
	shard = _bytes(n, 0)
	vis = _bytes(n, 0)
	hi = _bytes(n, 0)
	lit_goal = _bytes(n, 1)
	p_cur = PackedVector2Array()
	p_cur.resize(n)
	p_off = PackedVector2Array()
	p_off.resize(n)
	p_scl = _floats(n, 1.0)
	p_alp = _floats(n, 1.0)
	p_flip = _floats(n, 1.0)
	p_flash = _floats(n, 0.0)
	v_lit = _floats(n, 1.0)


static func _bytes(count: int, v: int) -> PackedByteArray:
	var a: = PackedByteArray()
	a.resize(count)
	a.fill(v)
	return a


static func _floats(count: int, v: float) -> PackedFloat32Array:
	var a: = PackedFloat32Array()
	a.resize(count)
	a.fill(v)
	return a


# the mirror of the board as it is now: the start of a round, or a round restored in the middle
func _mirror_from_board() -> void:
	var b: = board
	m_tray = []
	for t in b.tray:
		_slot_of[int(t)] = m_tray.size()
		m_tray.append(int(t))
	for i in n:
		if b.present[i] == 1:
			m_where[i] = 0
		elif b.tray.has(i):
			m_where[i] = 1
		else:
			m_where[i] = 2
		v_face[i] = b.face[i]
		v_ice[i] = b.ice[i]
		v_sec[i] = b.sec[i]
		v_kind[i] = _badge_of(i)
		gold[i] = 1 if b.gold[i] == 1 else 0
		shard[i] = b.shard_f[i]
		vis[i] = 1 if m_where[i] != 2 else 0
		p_alp[i] = 1.0
		p_scl[i] = 1.0
		p_flip[i] = 1.0
		p_flash[i] = 0.0
		p_off[i] = Vector2.ZERO
		hi[i] = 0
		lit_goal[i] = 1 if (m_where[i] == 0 and _lit_of(i)) or m_where[i] != 0 else 0
		v_lit[i] = float(lit_goal[i])
	_warn = b.tray.size() >= b.slots - 1 and b.slots >= 4 and not b.failed
	_dim = 1.0 if b.failed else 0.0
	_tray_tint = 1.0 if b.failed else 0.0


# the badge a tile shows: a lock / chain that has opened shows none (the board keeps the kind, takeable() says it is open)
func _badge_of(i: int) -> int:
	var k: int = board.kind_now[i]
	if (k == TWBoard.K_LOCK or k == TWBoard.K_CHAIN) and board.takeable(i):
		return 0
	return k


func _lit_of(i: int) -> bool:
	if board == null:
		return true
	return board.is_free(i) and board.takeable(i)


func _home(i: int) -> Vector2:
	if i < 0 or i >= n:
		return Vector2.ZERO
	if m_where[i] == 1:
		var s: = m_tray.find(i)
		if s >= 0 and s < _slotc.size():
			return _slotc[s]
	return _table[i] if i < _table.size() else Vector2.ZERO


func slot_center(slot: int) -> Vector2:
	return _slotc[slot] if slot >= 0 and slot < _slotc.size() else Vector2.ZERO


func _clear_timeline() -> void:
	_pending.clear()
	_active.clear()
	_fx.clear()
	_owner.clear()
	_dim = 0.0
	_tray_tint = 0.0
	_warn = false
	_hint.clear()
	_pressed = -1


# =================================================================== queries (tests, bots, HUD)

func idle_now() -> bool:
	return _pending.is_empty() and _active.is_empty() and _fx.is_empty()


func tile_rect(i: int) -> Rect2:
	var sc: float = p_scl[i]
	var w: = tile_w * sc
	var h: = tile_h * sc
	return Rect2(p_cur[i] + p_off[i] - Vector2(w, h) * 0.5, Vector2(w, h))


func tile_center(i: int) -> Vector2:
	return p_cur[i] + p_off[i]


func visible_table() -> PackedInt32Array:
	var out: = PackedInt32Array()
	for i in n:
		if m_where[i] == 0 and vis[i] == 1:
			out.append(i)
	return out


func is_lit(i: int) -> bool:
	return v_lit[i] > 0.5


# the topmost table tile under a point (view coordinates), -1 when none
func pick(local: Vector2) -> int:
	var best: = -1
	for i in range(n - 1, -1, -1):
		if m_where[i] != 0 or vis[i] == 0 or p_alp[i] < 0.5:
			continue
		var r: = Rect2(_table[i] - Vector2(tile_w, tile_h) * 0.5, Vector2(tile_w, tile_h))
		if r.has_point(local):
			best = i
			break
	return best


func face_name(i: int) -> String:
	return face_id(v_face[i])


# the picture state, compact: used to compare "after the timeline" with the board
func mirror_matches_board() -> Array:
	var bad: Array = []
	if board == null:
		return bad
	var b: = board
	for i in n:
		var want: = 2
		if b.present[i] == 1:
			want = 0
		elif b.tray.has(i):
			want = 1
		if m_where[i] != want:
			bad.append("where %d: %d != %d" % [i, m_where[i], want])
			continue
		if want == 2:
			if vis[i] != 0:
				bad.append("visible gone tile %d" % i)
			continue
		if vis[i] != 1:
			bad.append("hidden live tile %d" % i)
		if v_face[i] != b.face[i]:
			bad.append("face %d: %d != %d" % [i, v_face[i], b.face[i]])
		if v_ice[i] != b.ice[i]:
			bad.append("ice %d" % i)
		if v_sec[i] != b.sec[i]:
			bad.append("secret %d" % i)
		if v_kind[i] != _badge_of(i):
			bad.append("kind %d" % i)
		if want == 0 and (lit_goal[i] == 1) != _lit_of(i):
			bad.append("lit %d" % i)
		if want == 0 and p_cur[i].distance_to(_table[i]) > 0.5:
			bad.append("not home %d" % i)
		if want == 1 and p_cur[i].distance_to(_home(i)) > 0.5:
			bad.append("tray not home %d" % i)
	if b.tray.size() != m_tray.size():
		bad.append("tray size")
	else:
		for k in m_tray.size():
			if m_tray[k] != b.tray[k]:
				bad.append("tray order")
				break
	return bad


# =================================================================== input

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: = event as InputEventMouseButton
		if mb.pressed:
			var id: = pick(mb.position)
			if id >= 0:
				_press(id)
			accept_event()
		else:
			var id2: = pick(mb.position)
			var was: = _pressed
			_release()
			if was >= 0 and id2 == was:
				tile_tapped.emit(id2)
			accept_event()


func _press(id: int) -> void:
	_release()
	_pressed = id
	p_off[id] = Vector2(0.0, -PRESS_LIFT * (size.x / float(TWTokens.BASE_WIDTH) if size.x > 0.0 else 1.0))
	hi[id] = 1
	queue_redraw()


func _release() -> void:
	if _pressed >= 0:
		p_off[_pressed] = Vector2.ZERO
		hi[_pressed] = 0
		_pressed = -1
		queue_redraw()


# a tap as a bot or a test makes it: same path as a finger
func tap_at(id: int) -> bool:
	if id < 0 or id >= n or m_where[id] != 0:
		return false
	tile_tapped.emit(id)
	return true


func show_hint(ids: Array) -> void:
	_hint = ids.duplicate()
	_hint_t = 0.0
	queue_redraw()


func clear_hint() -> void:
	_hint.clear()
	queue_redraw()


# =================================================================== timeline core

func now_t() -> float:
	return _t


func _add(it: Dictionary) -> Dictionary:
	_seq += 1
	it["seq"] = _seq
	var lo: = 0
	var hi_i: = _pending.size()
	while lo < hi_i:
		var mid: = (lo + hi_i) >> 1
		if float(_pending[mid].t0) <= float(it.t0):
			lo = mid + 1
		else:
			hi_i = mid
	_pending.insert(lo, it)
	last_clips += 1
	stats.clips += 1
	return it


func _op(at: float, fn: Callable) -> void:
	_add({"k": "op", "t0": at, "d": 0.0, "fn": fn})


func _fx_add(kind: String, at: float, d: float, data: Dictionary = {}) -> void:
	var f: = data.duplicate()
	f["k"] = kind
	f["t0"] = at
	f["d"] = d
	_fx.append(f)
	last_clips += 1
	stats.clips += 1


func advance(dt: float) -> void:
	var target: = _t + maxf(dt, 0.0)
	stats.frames += 1
	var guard: = 0
	while guard < 100000:
		guard += 1
		var next_start: = INF
		if not _pending.is_empty():
			next_start = float(_pending[0].t0)
		var lim: = minf(next_start, target)
		var k: = 0
		while k < _active.size():
			var a: Dictionary = _active[k]
			if float(a.t0) + float(a.d) <= lim:
				_t = maxf(_t, float(a.t0) + float(a.d))
				_step(a, 1.0)
				_finish(a)
				_active.remove_at(k)
			else:
				k += 1
		if next_start <= target and not _pending.is_empty():
			var it: Dictionary = _pending.pop_front()
			_t = maxf(_t, float(it.t0))
			_start(it)
			continue
		break
	_t = target
	for a in _active:
		var d: float = maxf(float(a.d), 0.0001)
		_step(a, clampf((_t - float(a.t0)) / d, 0.0, 1.0))
	var j: = 0
	while j < _fx.size():
		if _t >= float(_fx[j].t0) + float(_fx[j].d):
			_fx.remove_at(j)
		else:
			j += 1
	if _warn:
		_warn_t += dt
	if not _hint.is_empty():
		_hint_t += dt
	queue_redraw()
	if idle_now() and stats.get("was_busy", false):
		stats["was_busy"] = false
		idle.emit()


# seconds from now until everything scheduled is over
func horizon() -> float:
	var e: = _t
	for it in _pending:
		e = maxf(e, float(it.t0) + float(it.d))
	for it in _active:
		e = maxf(e, float(it.t0) + float(it.d))
	for f in _fx:
		e = maxf(e, float(f.t0) + float(f.d))
	return e - _t


func finish() -> void:
	# ops may schedule more (sparks at the end of a flight): repeat until nothing is left
	var guard: = 0
	while not idle_now() and guard < 8:
		guard += 1
		advance(horizon() + 0.001)
	for i in n:
		if p_off[i] != Vector2.ZERO and i != _pressed:
			p_off[i] = Vector2.ZERO


func _start(it: Dictionary) -> void:
	match str(it.k):
		"op":
			(it.fn as Callable).call()
		"move":
			var id: int = it.id
			if int(it.w) != int(m_where[id]):
				return      # the tile went elsewhere since this move was scheduled: a later clip owns it
			it["from"] = p_cur[id]
			it["s0"] = p_scl[id]
			it["a0"] = p_alp[id]
			_owner["mv:%d" % id] = it
			hi[id] = 1
			_active.append(it)
		"pair":
			var a: int = it.a
			var b: int = it.b
			it["fa"] = p_cur[a]
			it["fb"] = p_cur[b]
			it["sa"] = p_scl[a]
			it["sb"] = p_scl[b]
			it["meet"] = (p_cur[a] + p_cur[b]) * 0.5
			_owner["mv:%d" % a] = it
			_owner["mv:%d" % b] = it
			hi[a] = 1
			hi[b] = 1
			_active.append(it)
		"prop":
			var pid: int = it.id
			if pid >= 0 and str(it.p) in ["off_x", "off_y", "off_both"]:
				_owner["off:%d" % pid] = it
			_active.append(it)
		_:
			_active.append(it)


func _ease_out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


func _ease_expo(p: float) -> float:
	return 1.0 if p >= 1.0 else 1.0 - pow(2.0, -10.0 * p)


func _step(it: Dictionary, p: float) -> void:
	match str(it.k):
		"move":
			var id: int = it.id
			if _owner.get("mv:%d" % id) != it:
				return
			var e: = _ease_out(p) if str(it.get("ease", "out")) == "out" else _ease_expo(p)
			var from: Vector2 = it.from
			var to: Vector2 = it.to
			var pos: = from.lerp(to, e)
			var arc: float = it.get("arc", 0.0)
			if arc != 0.0:
				var ctrl: = (from + to) * 0.5 + Vector2(0.0, -arc)
				pos = from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
			p_cur[id] = pos
			p_scl[id] = lerpf(float(it.s0), float(it.get("s1", it.s0)), e) * (1.0 + float(it.get("bulge", 0.0)) * sin(e * PI))
			p_alp[id] = lerpf(float(it.a0), float(it.get("a1", 1.0)), e)
		"pair":
			var a: int = it.a
			var b: int = it.b
			var e2: = _ease_expo(p)
			var meet: Vector2 = it.meet
			if _owner.get("mv:%d" % a) == it:
				p_cur[a] = (it.fa as Vector2).lerp(meet, e2)
				p_scl[a] = lerpf(float(it.sa), float(it.sa) * 0.7, e2)
				p_alp[a] = 1.0 - smoothstep(0.55, 1.0, p)
			if _owner.get("mv:%d" % b) == it:
				p_cur[b] = (it.fb as Vector2).lerp(meet, e2)
				p_scl[b] = lerpf(float(it.sb), float(it.sb) * 0.7, e2)
				p_alp[b] = 1.0 - smoothstep(0.55, 1.0, p)
		"prop":
			_step_prop(it, p)


func _step_prop(it: Dictionary, p: float) -> void:
	var id: int = it.id
	var amp: float = it.get("amp", 1.0)
	match str(it.p):
		"shake":
			if _owner.get("off:%d" % id) == it:
				p_off[id] = Vector2(amp * sin(p * TAU * 3.0) * (1.0 - p), 0.0)
		"settle":
			if _owner.get("off:%d" % id) == it:
				p_off[id] = Vector2(0.0, -amp * (1.0 - _ease_out(p)))
		"flash":
			p_flash[id] = maxf(p_flash[id] if str(it.get("mode", "")) == "max" else 0.0, amp * (1.0 - p))
		"flip":
			p_flip[id] = absf(cos(p * PI))
		"lit":
			v_lit[id] = lerpf(float(it.l0), float(it.l1), p)
		"pop":
			p_alp[id] = _ease_out(p)
			p_scl[id] = lerpf(0.6 * float(it.base), float(it.base), _ease_out(p))
		"dim":
			_dim = lerpf(float(it.l0), float(it.l1), p)
		"tint":
			_tray_tint = lerpf(float(it.l0), float(it.l1), p)


func _finish(it: Dictionary) -> void:
	match str(it.k):
		"move":
			var id: int = it.id
			if _owner.get("mv:%d" % id) == it:
				_owner.erase("mv:%d" % id)
				p_cur[id] = it.to
				p_scl[id] = float(it.get("s1", it.s0))
				p_alp[id] = float(it.get("a1", 1.0))
				hi[id] = 0
				if bool(it.get("hide", false)):
					vis[id] = 0
		"pair":
			for id in [it.a, it.b]:
				if _owner.get("mv:%d" % id) == it:
					_owner.erase("mv:%d" % id)
					p_cur[id] = it.meet
					p_alp[id] = 0.0
					hi[id] = 0
					vis[id] = 0
		"prop":
			var id2: int = it.id
			match str(it.p):
				"shake", "settle":
					if _owner.get("off:%d" % id2) == it:
						_owner.erase("off:%d" % id2)
						p_off[id2] = Vector2.ZERO
				"flash":
					p_flash[id2] = 0.0
				"flip":
					p_flip[id2] = 1.0
				"lit":
					v_lit[id2] = float(it.l1)
				"pop":
					p_alp[id2] = 1.0
					p_scl[id2] = float(it.base)
				"dim":
					_dim = float(it.l1)
				"tint":
					_tray_tint = float(it.l1)


func fx_full() -> bool:
	return TWDraw.fx_level() == "full"


# =================================================================== events -> timeline

# Schedule the pictures of an event list; returns the seconds until they are over. The LOGICAL mirror (m_where, m_tray) is
# updated at once, so a tap that arrives while the last one is still flying starts from where the tiles are.
func play(events: Array) -> float:
	last_clips = 0
	last_type_clips = {}
	last_unknown = PackedStringArray()
	if board == null or events.is_empty():
		return 0.0
	stats.plays += 1
	stats["was_busy"] = true
	var t0: = _t
	var end: = t0
	var leave: = t0
	var types: = PackedStringArray()
	_clear_hint_on_play()
	for e in events:
		var d: Dictionary = e
		var ty: = TWBoardEvents.type_of(d)
		types.append(ty)
		var c0: = last_clips
		match ty:
			TWBoardEvents.MATCH:
				var r: = _ev_match(d, t0)
				end = maxf(end, r)
				leave = t0 + T_LIFT
			TWBoardEvents.TO_TRAY:
				end = maxf(end, _ev_to_tray(d, t0))
				leave = t0
			TWBoardEvents.TRAY_WARN:
				end = maxf(end, _ev_warn(t0 + T_TRAY))
			TWBoardEvents.TRAY_FULL:
				end = maxf(end, _ev_full(d, t0 + T_TRAY))
			TWBoardEvents.CLEARED:
				end = maxf(end, _ev_cleared(maxf(end, t0 + T_LIFT + T_FLY)))
			TWBoardEvents.DENY:
				end = maxf(end, _shake(int(d.id), t0, T_SHAKE, 3.0))
			TWBoardEvents.BLOCKED:
				_flash(int(d.id), t0, T_FLASH, 0.5)
				end = maxf(end, _shake(int(d.id), t0, T_SHAKE, 3.0))
			TWBoardEvents.ICE_CRACK:
				end = maxf(end, _ev_ice(d, t0))
			TWBoardEvents.REVEAL:
				end = maxf(end, _flip_to(int(d.id), t0, T_TRAY, {"sec": 0}))
			TWBoardEvents.JOKER:
				end = maxf(end, _ev_joker(d, t0))
			TWBoardEvents.UNLOCK:
				end = maxf(end, _ev_unlock(d.get("ids", []), t0, "ids"))
			TWBoardEvents.UNCHAIN:
				end = maxf(end, _ev_unlock([int(d.id)], t0, "one"))
			TWBoardEvents.UNSTICK:
				_fx_add("sweep", t0, 0.5, {"col": "JADE_300", "a": 0.35})
				end = maxf(end, t0 + 0.5)
			TWBoardEvents.GIFT:
				end = maxf(end, _ev_gift(d, t0))
			TWBoardEvents.BLAST:
				end = maxf(end, _ev_blast(d, t0 + T_LIFT + T_FLY))
			TWBoardEvents.UNDO:
				end = maxf(end, _ev_back([int(d.id)], t0, 0.0))
				leave = t0
			TWBoardEvents.RETURN:
				end = maxf(end, _ev_back(d.get("ids", []), t0, 0.04))
			TWBoardEvents.SHUFFLE:
				end = maxf(end, _ev_shuffle(d.get("ids", []), t0))
			TWBoardEvents.VANISH:
				end = maxf(end, _ev_vanish(d, t0))
				leave = t0
			TWBoardEvents.MOONLIGHT:
				end = maxf(end, _ev_moon(d, t0))
			_:
				last_unknown.append(ty)
		last_type_clips[ty] = int(last_type_clips.get(ty, 0)) + last_clips - c0
	_after_events(types, leave, end)
	played.emit(types, end - t0)
	return end - t0


func _clear_hint_on_play() -> void:
	_hint.clear()


# the lit goals and the warning flag after a batch; neighbours that lost their cover settle
func _after_events(types: PackedStringArray, leave: float, end: float) -> void:
	if board == null:
		return
	for i in n:
		if m_where[i] != 0:
			continue
		var goal: = 1 if _lit_of(i) else 0
		if goal != lit_goal[i]:
			lit_goal[i] = goal
			var l0: float = v_lit[i]
			_add({"k": "prop", "p": "lit", "id": i, "t0": leave, "d": T_LIT, "l0": l0, "l1": float(goal)})
			if goal == 1:
				_add({"k": "prop", "p": "settle", "id": i, "t0": leave, "d": T_SETTLE, "amp": SETTLE_PX * _k()})
	# a lock / chain that opened without an event of its own (a chain opens by count, a blast can jump over the count)
	for i in n:
		if m_where[i] != 2 and (v_kind[i] == TWBoard.K_LOCK or v_kind[i] == TWBoard.K_CHAIN) and _badge_of(i) == 0:
			var ii: = i
			_flash(ii, leave, T_FLASH * 2.0, 0.5)
			_op(leave + T_FLASH, func() -> void: v_kind[ii] = 0)
			_fx_add("ring", leave, T_FLASH * 2.5, {"pos": _table[ii], "col": _col("GOLD_500"), "r": 44.0 * _k()})
	var sl: = board.slots
	_warn = board.tray.size() >= sl - 1 and sl >= 4 and not board.failed and board.tray.size() < sl
	if not board.failed and (_dim > 0.0 or _tray_tint > 0.0):
		_add({"k": "prop", "p": "dim", "id": -1, "t0": end, "d": T_TRAY, "l0": _dim, "l1": 0.0})
		_add({"k": "prop", "p": "tint", "id": -1, "t0": end, "d": T_TRAY, "l0": _tray_tint, "l1": 0.0})


func _k() -> float:
	return (size.x if size.x > 0.0 else float(TWTokens.BASE_WIDTH)) / float(TWTokens.BASE_WIDTH)


func _col(token: String, a: float = 1.0) -> Color:
	return Color(TWSkin.c(token), a)


func _move(id: int, to: Vector2, t0: float, d: float, opt: Dictionary = {}) -> float:
	var it: = {"k": "move", "id": id, "to": to, "t0": t0, "d": d, "w": int(m_where[id])}
	for k in opt:
		it[k] = opt[k]
	_add(it)
	return t0 + d


func _shake(id: int, t0: float, d: float, amp_px: float) -> float:
	_add({"k": "prop", "p": "shake", "id": id, "t0": t0, "d": d, "amp": amp_px * _k()})
	return t0 + d


func _flash(id: int, t0: float, d: float, amp: float) -> void:
	_add({"k": "prop", "p": "flash", "id": id, "t0": t0, "d": d, "amp": amp, "mode": "max"})


# flip a tile (scale x 1 -> 0 -> 1) and apply `change` ({"face": f, "sec": 0, "ice": n}) at the half
func _flip_to(id: int, t0: float, d: float, change: Dictionary) -> float:
	_add({"k": "prop", "p": "flip", "id": id, "t0": t0, "d": d})
	_op(t0 + d * 0.5, func() -> void: _apply_change(id, change))
	return t0 + d


func _apply_change(id: int, ch: Dictionary) -> void:
	if ch.has("face"):
		v_face[id] = int(ch.face)
	if ch.has("sec"):
		v_sec[id] = int(ch.sec)
	if ch.has("ice"):
		v_ice[id] = int(ch.ice)
	if ch.has("kind"):
		v_kind[id] = int(ch.kind)


func _sparks(at: Vector2, t0: float, n_sparks: int, col: Color, radius: float, d: float = 0.3) -> void:
	_fx_add("spark", t0, d, {"pos": at, "n": n_sparks, "col": col, "r": radius * _k(), "seed": float(_seq) * 0.7})


func _spark_count(combo: int) -> int:
	var base: = 6
	if combo >= 10:
		base = 18
	elif combo >= 5:
		base = 12
	return base if fx_full() else mini(base, 6)


func _reflow(t0: float) -> void:
	for s in m_tray.size():
		var id: int = m_tray[s]
		if m_where[id] == 1 and _slotc.size() > s and int(_slot_of.get(id, -1)) != s:
			_slot_of[id] = s
			_move(id, _slotc[s], t0, T_TRAY, {"s1": tray_scale})


func _ev_match(e: Dictionary, t0: float) -> float:
	var a: int = e.a
	var b: int = e.b
	var gold_pair: bool = e.get("gold", false)
	m_tray.erase(a)
	m_where[a] = 2
	m_where[b] = 2
	# the tapped tile lifts, then both fly together
	var lift_to: = _table[b] + Vector2(0.0, -PRESS_LIFT * _k())
	_move(b, lift_to, t0, T_LIFT, {"s1": 1.06})
	var t1: = t0 + T_LIFT
	_add({"k": "pair", "a": a, "b": b, "t0": t1, "d": T_FLY})
	var meet: = (p_cur[a] + _table[b]) * 0.5
	var t2: = t1 + T_FLY
	var combo: int = e.get("combo", 1)
	var col: = accent if not gold_pair else _col("GOLD_500")
	_op(t1, func() -> void: _sparks((p_cur[a] + p_cur[b]) * 0.5, t1 + T_FLY * 0.5, _spark_count(combo), col, 34.0))
	if combo >= 5:
		_fx_add("ring", t1, T_FLY + 0.12, {"pos": meet, "col": col, "r": 56.0 * _k()})
	if e.get("gift", false) or str(e.get("shard", "")) != "":
		_fx_add("ring", t1, T_FLY + 0.2, {"pos": meet, "col": _col("GOLD_500"), "r": 70.0 * _k()})
	_reflow(t2)
	return t2


func _ev_to_tray(e: Dictionary, t0: float) -> float:
	var id: int = e.id
	m_tray.append(id)
	m_where[id] = 1
	var slot: int = mini(int(e.get("slot", m_tray.size() - 1)), maxi(0, _slotc.size() - 1))
	var to: = _slotc[slot] if _slotc.size() > slot else p_cur[id]
	_slot_of[id] = slot
	var f: int = e.get("face", v_face[id])
	v_face[id] = f
	var arc: = tile_h * 1.1
	_move(id, to, t0, T_TRAY, {"s1": tray_scale, "arc": arc, "bulge": 0.12})
	_flash(id, t0 + T_TRAY, T_SETTLE * 1.5, 0.35)
	return t0 + T_TRAY + T_SETTLE * 1.5


func _ev_warn(at: float) -> float:
	_warn = true
	var slot: int = mini(m_tray.size(), _slotc.size() - 1)
	if slot >= 0 and _slotc.size() > 0:
		_fx_add("slot_pulse", at, 0.6, {"slot": slot})
	return at + 0.6


func _ev_full(e: Dictionary, at: float) -> float:
	_warn = false
	for id in e.get("tray", []):
		_shake(int(id), at, 0.3, 4.0)
	_add({"k": "prop", "p": "tint", "id": -1, "t0": at, "d": 0.3, "l0": _tray_tint, "l1": 1.0})
	_add({"k": "prop", "p": "dim", "id": -1, "t0": at, "d": 0.3, "l0": _dim, "l1": 1.0})
	return at + 0.3


func _ev_cleared(at: float) -> float:
	_fx_add("sweep", at, 0.6, {"col": "GOLD_300", "a": 0.5})
	_sparks(field.get_center(), at + 0.1, 18 if fx_full() else 8, _col("GOLD_300"), 120.0, 0.6)
	_warn = false
	return at + 0.7


func _ev_ice(e: Dictionary, t0: float) -> float:
	var id: int = e.id
	var left: int = e.get("left", 0)
	_flash(id, t0, T_FLASH, 0.55)
	_shake(id, t0, T_SHAKE, 2.0)
	_op(t0 + T_FLASH * 0.5, func() -> void: v_ice[id] = left)
	_fx_add("crack", t0, T_FLASH * 1.5, {"id": id})
	if left == 0:
		_sparks(_table[id], t0 + T_FLASH * 0.5, 6, _col("JADE_300"), 30.0, 0.25)
	return t0 + T_FLASH * 1.5


func _ev_joker(e: Dictionary, t0: float) -> float:
	var id: int = e.id
	var f: int = e.get("face", v_face[id])
	var kd: = _badge_of(id)
	_flash(id, t0, T_FLASH * 1.5, 0.6)
	_op(t0 + T_FLASH * 0.4, func() -> void:
		v_face[id] = f
		v_kind[id] = kd)
	return t0 + T_FLASH * 1.5


func _ev_unlock(ids: Array, t0: float, _mode: String) -> float:
	var end: = t0
	if ids.is_empty():
		_fx_add("wash", t0, 0.3, {"col": "GOLD_300", "a": 0.12})
		return t0 + 0.3
	for id in ids:
		var i: int = int(id)
		_flash(i, t0, T_FLASH * 2.0, 0.5)
		_op(t0 + T_FLASH, func() -> void: v_kind[i] = 0)
		_fx_add("ring", t0, T_FLASH * 2.5, {"pos": _table[i], "col": _col("GOLD_500"), "r": 44.0 * _k()})
		end = maxf(end, t0 + T_FLASH * 2.5)
	return end


func _ev_gift(e: Dictionary, t0: float) -> float:
	var mid: = (p_cur[int(e.a)] + _table[int(e.b)]) * 0.5
	_sparks(mid, t0 + T_LIFT, 12 if fx_full() else 6, _col("GOLD_500"), 50.0, 0.4)
	return t0 + T_LIFT + 0.4


func _ev_blast(e: Dictionary, at: float) -> float:
	var end: = at
	var mid: Vector2 = e.get("mid", Vector2.ZERO)
	var screen_mid: = origin + mid * wscale
	_fx_add("ring", at, 0.3, {"pos": screen_mid, "col": _col("GOLD_300"), "r": TWFree.TW * 1.75 * wscale})
	var k: = 0
	for pr in e.get("pairs", []):
		for id in pr:
			var i: int = int(id)
			m_tray.erase(i)
			m_where[i] = 2
			var from_tray: bool = p_cur[i].distance_to(_table[i]) > 1.0
			var t: = at + 0.04 * float(k)
			_move(i, p_cur[i] if from_tray else _table[i], t, 0.24, {"s1": 1.25, "a1": 0.0, "hide": true, "ease": "out"})
			_sparks(_table[i], t + 0.1, 4, _col("GOLD_300"), 28.0, 0.25)
			end = maxf(end, t + 0.24)
		k += 1
	_reflow(end)
	return end


func _ev_back(ids: Array, t0: float, stagger: float) -> float:
	var end: = t0
	var k: = 0
	for id in ids:
		var i: int = int(id)
		m_tray.erase(i)
		m_where[i] = 0
		var t: = t0 + stagger * float(k)
		_move(i, _table[i], t, T_TRAY, {"s1": 1.0, "arc": tile_h * 0.8, "bulge": 0.1})
		end = maxf(end, t + T_TRAY)
		k += 1
	_reflow(t0 + T_TRAY * 0.5)
	_add({"k": "prop", "p": "dim", "id": -1, "t0": t0, "d": T_TRAY, "l0": _dim, "l1": 0.0})
	_add({"k": "prop", "p": "tint", "id": -1, "t0": t0, "d": T_TRAY, "l0": _tray_tint, "l1": 0.0})
	return end


func _ev_shuffle(ids: Array, t0: float) -> float:
	var end: = t0
	var k: = 0
	var cap: = maxf(1.0, float(ids.size()))
	for id in ids:
		var i: int = int(id)
		var nf: int = board.face[i]
		var t: = t0 + (float(k) / cap) * 0.2
		_flip_to(i, t, T_TRAY, {"face": nf})
		end = maxf(end, t + T_TRAY)
		k += 1
	return end


func _ev_vanish(e: Dictionary, t0: float) -> float:
	var a: int = e.a
	var b: int = e.b
	m_tray.erase(a)
	m_tray.erase(b)
	m_where[a] = 2
	m_where[b] = 2
	for id in [a, b]:
		_move(id, p_cur[id], t0, 0.24, {"s1": 1.2, "a1": 0.0, "hide": true})
		_flash(id, t0, 0.24, 0.7)
	var mid: = (p_cur[a] + p_cur[b]) * 0.5
	_sparks(mid, t0 + 0.05, 12 if fx_full() else 6, _col("GOLD_300"), 46.0, 0.3)
	_reflow(t0 + 0.24)
	return t0 + 0.3


func _ev_moon(e: Dictionary, t0: float) -> float:
	var end: = t0
	for id in e.get("revealed", []):
		end = maxf(end, _flip_to(int(id), t0, T_TRAY, {"sec": 0}))
	for id in e.get("thawed", []):
		var i: int = int(id)
		_op(t0 + T_FLASH, func() -> void: v_ice[i] = 0)
		_sparks(_table[i], t0 + T_FLASH, 4, _col("JADE_300"), 26.0, 0.25)
		end = maxf(end, t0 + T_FLASH + 0.25)
	_fx_add("wash", t0, 0.6, {"col": "JADE_300", "a": 0.3})
	return maxf(end, t0 + 0.6)


# a fresh deal: tiles pop in, layer by layer (GDD T_IN 240 ms, T_IN_STEP 40 ms)
func deal_in() -> float:
	var end: = _t
	for i in n:
		if m_where[i] != 0:
			continue
		var z: int = (_pos[i] as Vector3i).z
		var t: = _t + float(z) * TWTokens.T_IN_STEP + minf(float(i) * 0.004, 0.2)
		p_alp[i] = 0.0
		p_scl[i] = 0.6
		_add({"k": "prop", "p": "pop", "id": i, "t0": t, "d": TWTokens.T_IN, "base": 1.0})
		end = maxf(end, t + TWTokens.T_IN)
	stats["was_busy"] = true
	return end - _t


# =================================================================== draw

func _draw() -> void:
	var t_us: = Time.get_ticks_usec()
	_draw_all()
	last_draw_us = Time.get_ticks_usec() - t_us


func _draw_all() -> void:
	draws += 1
	if board == null or n == 0:
		return
	_draw_tray()
	for pass_i in 2:
		for i in n:
			if vis[i] == 0 or hi[i] != pass_i:
				continue
			_draw_tile(i)
	_draw_fx()
	if _dim > 0.001:
		draw_rect(field.grow(float(TWTokens.GRID) * _k()), _col("NIGHT_900", 0.45 * _dim))
	_draw_hint()


func _draw_tray() -> void:
	var k: = _k()
	var tint: = _tray_tint
	for s in _slotc.size():
		var c: = _slotc[s]
		var w: = tile_w * tray_scale * 1.04
		var r: = Rect2(c - Vector2(w, w * ASPECT) * 0.5, Vector2(w, w * ASPECT))
		draw_set_transform(r.position, 0.0, r.size)
		draw_colored_polygon(_unit_rr, _col("NIGHT_900", 0.35))
		var rim: = _col("EMBER", 0.9) if tint > 0.5 else _col("PLATE_RIM", 0.55)
		draw_polyline(_unit_rr_closed, rim.lerp(_col("EMBER", 0.9), tint), 1.5 * k / maxf(w, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _warn and board != null and board.tray.size() < board.slots:
		var slot: = mini(m_tray.size(), _slotc.size() - 1)
		_draw_slot_glow(slot, 0.35 + 0.35 * sin(_warn_t * TAU / 1.2))


func _draw_slot_glow(slot: int, a: float) -> void:
	if slot < 0 or slot >= _slotc.size():
		return
	var w: = tile_w * tray_scale * 1.1
	var r: = Rect2(_slotc[slot] - Vector2(w, w * ASPECT) * 0.5, Vector2(w, w * ASPECT))
	draw_set_transform(r.position, 0.0, r.size)
	draw_colored_polygon(_unit_rr, _col("ROSE_500", 0.18 * a))
	draw_polyline(_unit_rr_closed, _col("ROSE_300", a), 3.0 * _k() / maxf(w, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tile(i: int) -> void:
	var a: float = p_alp[i]
	if a <= 0.003:
		return
	var sc: float = p_scl[i]
	var fl: float = absf(p_flip[i])
	var w: = tile_w * sc * maxf(fl, 0.02)
	var h: = tile_h * sc
	var c: = p_cur[i] + p_off[i]
	var r: = Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var th: = Vector2(w * 0.05, h * 0.07)
	var lit: float = v_lit[i]
	var inv: = 1.0 / maxf(w, 1.0)
	# shadow and side (thickness)
	draw_set_transform(r.position + th * 1.9, 0.0, r.size)
	draw_colored_polygon(_unit_rr, _col("SHADOW", 0.32 * a))
	draw_set_transform(r.position + th, 0.0, r.size)
	draw_colored_polygon(_unit_rr, _col("PAPER_700", a))
	draw_set_transform(r.position, 0.0, r.size)
	var blocked: = TWSkin.c("PAPER_300").lerp(TWSkin.c("PAPER_500"), BLOCKED_MIX)
	var mod: = Color.WHITE.lerp(blocked, 1.0 - lit)
	mod.a = a
	var back: = v_sec[i] == 1 or (p_flip[i] < 0.5 and v_sec[i] == 1)
	if back:
		draw_colored_polygon(_unit_rr, _col("NIGHT_600", a))
		draw_polyline(_unit_rr_closed, _col("GOLD_700", a), 2.0 * inv)
		var d: = PackedVector2Array([Vector2(0.5, 0.22), Vector2(0.78, 0.5), Vector2(0.5, 0.78), Vector2(0.22, 0.5)])
		draw_colored_polygon(d, _col("GOLD_700", 0.55 * a))
	else:
		_draw_face(i, mod, a)
	# ice
	if v_ice[i] > 0 and not back:
		var ia: = 0.42 if v_ice[i] >= 2 else 0.26
		draw_colored_polygon(_unit_rr, _col("JADE_300", ia * a))
		draw_polyline(_unit_rr_closed, _col("JADE_300", 0.9 * a), 2.0 * inv)
		if v_ice[i] == 1:
			draw_polyline(PackedVector2Array([Vector2(0.25, 0.2), Vector2(0.4, 0.45), Vector2(0.33, 0.6), Vector2(0.55, 0.8)]), _col("PAPER_100", 0.9 * a), 2.0 * inv)
			draw_polyline(PackedVector2Array([Vector2(0.4, 0.45), Vector2(0.7, 0.38), Vector2(0.82, 0.55)]), _col("PAPER_100", 0.8 * a), 2.0 * inv)
	# gold rim, free rim
	if gold[i] == 1:
		draw_polyline(_unit_rr_closed, _col("GOLD_500", a), 3.0 * inv)
	elif lit > 0.5:
		draw_polyline(_unit_rr_closed, _col("GOLD_300", 0.55 * a * lit), 1.5 * inv)
	if v_kind[i] != 0 and not back:
		_draw_badge(int(v_kind[i]), a, inv)
	if p_flash[i] > 0.002:
		draw_colored_polygon(_unit_rr, _col("PAPER_100", clampf(p_flash[i], 0.0, 1.0) * 0.75 * a))
	if i == _pressed:
		draw_polyline(_unit_rr_closed, _col("ROSE_300", a), 3.0 * inv)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_face(i: int, mod: Color, a: float) -> void:
	var f: int = v_face[i]
	var id: = face_id(f)
	if id != "":
		var tex: = TWAssets.tex(id)
		if tex != null:
			draw_texture_rect(tex, Rect2(0, 0, 1, 1), false, mod)
			return
	# no texture for this face: a drawn plate (shard gem, joker star, unknown)
	draw_colored_polygon(_unit_rr, _col("PAPER_100", a) * mod)
	if shard[i] == 1 or f == TWBoard.SHARD_FACE:
		draw_colored_polygon(PackedVector2Array([Vector2(0.5, 0.16), Vector2(0.78, 0.42), Vector2(0.5, 0.86), Vector2(0.22, 0.42)]), _col("ROSE_500", a) * mod)
		draw_polyline(PackedVector2Array([Vector2(0.22, 0.42), Vector2(0.78, 0.42)]), _col("PAPER_100", a), 0.03)
	elif f == TWBoard.JOKER:
		var pts: = PackedVector2Array()
		for q in 10:
			var rr: = 0.34 if q % 2 == 0 else 0.15
			var ang: = -PI * 0.5 + TAU * float(q) / 10.0
			pts.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, _col("GOLD_500", a) * mod)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.7, 0.7), Vector2(0.3, 0.7)]), _col("PAPER_500", a))


func _draw_badge(kd: int, a: float, inv: float) -> void:
	var col: = _col("GOLD_700", a)
	var ink: = _col("NIGHT_900", a)
	match kd:
		TWBoard.K_LOCK:
			draw_colored_polygon(PackedVector2Array([Vector2(0.66, 0.2), Vector2(0.92, 0.2), Vector2(0.92, 0.42), Vector2(0.66, 0.42)]), col)
			draw_polyline(PackedVector2Array([Vector2(0.7, 0.2), Vector2(0.7, 0.1), Vector2(0.88, 0.1), Vector2(0.88, 0.2)]), ink, 2.0 * inv)
		TWBoard.K_CHAIN:
			draw_arc(Vector2(0.72, 0.2), 0.08, 0.0, TAU, 12, col, 3.0 * inv)
			draw_arc(Vector2(0.84, 0.2), 0.08, 0.0, TAU, 12, col, 3.0 * inv)
		TWBoard.K_KEY:
			draw_arc(Vector2(0.72, 0.18), 0.07, 0.0, TAU, 12, col, 3.0 * inv)
			draw_line(Vector2(0.79, 0.18), Vector2(0.92, 0.18), col, 3.0 * inv)
		TWBoard.K_BOMB:
			draw_circle(Vector2(0.78, 0.22), 0.1, ink)
			draw_circle(Vector2(0.82, 0.14), 0.025, _col("EMBER", a))
		TWBoard.K_GIFT:
			draw_colored_polygon(PackedVector2Array([Vector2(0.66, 0.14), Vector2(0.9, 0.14), Vector2(0.9, 0.36), Vector2(0.66, 0.36)]), _col("ROSE_500", a))
			draw_line(Vector2(0.78, 0.14), Vector2(0.78, 0.36), _col("PAPER_100", a), 2.0 * inv)


func _draw_fx() -> void:
	for f in _fx:
		var t0: float = f.t0
		if _t < t0:
			continue
		var p: = clampf((_t - t0) / maxf(float(f.d), 0.0001), 0.0, 1.0)
		match str(f.k):
			"spark":
				var cnt: int = f.n
				var col: Color = f.col
				var e: = _ease_out(p)
				for q in cnt:
					var ang: float = float(f.seed) + TAU * float(q) / float(cnt) + 0.35 * sin(float(q) * 1.7)
					var dist: float = float(f.r) * e * (0.6 + 0.4 * fposmod(float(q) * 0.618, 1.0))
					var rad: = maxf(1.0, (2.6 - 1.6 * p) * _k())
					draw_circle((f.pos as Vector2) + Vector2(cos(ang), sin(ang)) * dist, rad, Color(col, 1.0 - p))
			"ring":
				var col2: Color = f.col
				draw_arc(f.pos, float(f.r) * _ease_out(p), 0.0, TAU, 28, Color(col2, 0.9 * (1.0 - p)), 3.0 * _k())
			"sweep":
				var band: = field.size.x * 0.3
				var x: = lerpf(field.position.x - band, field.end.x + band, _ease_out(p))
				var tok: String = f.col
				var al: float = float(f.a) * sin(p * PI)
				var pts: = PackedVector2Array([Vector2(x - band * 0.5, field.position.y), Vector2(x + band * 0.5, field.position.y), Vector2(x + band * 0.2, field.end.y), Vector2(x - band * 0.8, field.end.y)])
				draw_colored_polygon(pts, _col(tok, al))
			"wash":
				var tok2: String = f.col
				draw_rect(field, _col(tok2, float(f.a) * sin(p * PI)))
			"slot_pulse":
				_draw_slot_glow(int(f.slot), sin(p * PI))
			"crack":
				var id: int = f.id
				var c: = _table[id]
				draw_line(c + Vector2(-tile_w * 0.2, -tile_h * 0.25), c + Vector2(tile_w * 0.05, tile_h * 0.1), _col("PAPER_100", 1.0 - p), 2.0 * _k())
				draw_line(c + Vector2(tile_w * 0.05, tile_h * 0.1), c + Vector2(tile_w * 0.25, tile_h * 0.28), _col("PAPER_100", 1.0 - p), 2.0 * _k())


func _draw_hint() -> void:
	if _hint.is_empty():
		return
	var al: = 0.5 + 0.5 * sin(_hint_t * TAU / 0.9)
	for id in _hint:
		var i: int = int(id)
		if i < 0 or i >= n or vis[i] == 0:
			continue
		var r: = tile_rect(i).grow(2.0 * _k())
		draw_set_transform(r.position, 0.0, r.size)
		draw_polyline(_unit_rr_closed, _col("GOLD_300", 0.4 + 0.6 * al), 4.0 / maxf(r.size.x, 1.0) * _k())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
