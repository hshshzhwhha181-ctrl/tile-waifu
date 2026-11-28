class_name TWMatchScreen
extends TWScreen

# TWMatchScreen (P31 / WP10a): the v11 match screen, board-first. It owns a TWBoard (the rules) and a TWBoardView (the pictures):
#
#   a tap on the view  ->  events = board.tap(id)  ->  view.play(events)  +  ctx.bus.publish_all(events)
#
# Nothing here decides a rule and nothing waits for an animation: the board has already resolved the move when the view starts to
# paint it. The HUD (P32), the result modal (P33) and TWPresence (P34) sit around this screen and listen to the same bus.
#
# params: {"board": TWBoard} | {"level": Dictionary (a Path level with lv.v10)} | {"cfg": Dictionary (TWBoard.from_cfg)}; none -> a
#         default 6 x 8 x 3 board. Optional: "tile_size" ("S" | "M" | "L" | "XL"), "accent" (Color of the sparks).
# signals: round_ended(result)  result = {"state": "cleared" | "failed", "moves", "pairs", "combo_max"}
#          back_requested       a back press during a round: whoever draws the confirmation connects here; with no listener the
#                               press is not consumed and the manager navigates away as usual

signal round_ended(result: Dictionary)
signal back_requested
signal result_action(action: String, info: Dictionary)   # the victory modal closed: "next" | "map" (P33); with no listener "next" restarts a default board

const DEFAULT_CFG: = {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 1, "shape": "rect", "gold": 3, "ice": 2,
	"hidden": true, "shard": "", "plan": {}}

var board: TWBoard = null
var view: TWBoardView = null
var combo_max: = 0
var ended: = false
# P33 / WP10c: the victory modal. params: show_result (default true; needs a ModalStack in ctx), result_facts (TWResultChain facts), round_mode,
# round_cfg, round_state (TWRound.resolve inputs), boosters_used. The modal is opened ONCE when the board is cleared; with a "wallet" service
# in ctx the grants of the TWRoundResult are paid exactly once.
var show_result: = true
var result_facts: Dictionary = {}
var round_mode: = ""
var round_cfg: Dictionary = {}
var round_state: Dictionary = {}
var round_result: TWRoundResult = null
var result_modal: TWResultModal = null
var _boosters_used: = 0
var _t0: = 0.0
var _paid: = false
var _cfg_in: Dictionary = {}


func enter(p: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var b = p.get("board", null)
	if b is TWBoard:
		board = b
	elif p.get("level") is Dictionary:
		board = TWBoard.from_level(p.level)
	else:
		board = TWBoard.from_cfg(p.get("cfg", DEFAULT_CFG))
	if ctx != null and ctx.clock != null and not board.clock.is_valid():
		var clk: = ctx.clock
		board.clock = func() -> float: return float(clk.mono_msec()) / 1000.0
	show_result = bool(p.get("show_result", true))
	result_facts = p.get("result_facts", {})
	round_mode = String(p.get("round_mode", ""))
	round_cfg = p.get("round_cfg", {})
	round_state = p.get("round_state", {})
	_boosters_used = int(p.get("boosters_used", 0))
	_cfg_in = p.get("cfg", {}) if p.get("cfg") is Dictionary else {}
	_t0 = board.now()
	view = TWBoardView.new()
	view.name = "BoardView"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	if p.get("accent") is Color:
		view.accent = p.accent
	view.tile_tapped.connect(_on_tile_tapped)
	add_child(view)
	view.bind(board, str(p.get("tile_size", "M")))
	_layout()
	resized.connect(_layout)
	ended = board.cleared or board.failed


func exit() -> void:
	if view != null and is_instance_valid(view):
		view.input_enabled = false


func _layout() -> void:
	if view != null and size.x > 0.0 and size.y > 0.0:
		view.configure(size, TWDraw.safe_insets(size))
	queue_redraw()


func _draw() -> void:
	# the stage under the field: one vertical felt gradient, no seam (the hero strip and the HUD sit on top of it)
	var r: = Rect2(Vector2.ZERO, size)
	var pts: = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([TWTokens.FELT_HI, TWTokens.FELT_HI, TWTokens.FELT_LO, TWTokens.FELT_LO]))


# ---- the one move path (a finger, a bot, a test) --------------------------------------------------------------------------

func _on_tile_tapped(id: int) -> void:
	tap_tile(id)


func tap_tile(id: int) -> Array:
	if board == null or ended:
		return []
	return _commit(board.tap(id))


func undo() -> Array:
	if board == null or board.cleared:
		return []
	return _commit(board.undo())


func shuffle() -> Array:
	if board == null or ended:
		return []
	return _commit(board.shuffle())


func hint() -> Array:
	if board == null or ended:
		return []
	var h: Array = board.hint()
	if view != null:
		view.show_hint(h)
	return h


func _commit(events: Array) -> Array:
	if events.is_empty():
		return events
	if view != null:
		view.play(events)
	if ctx != null and ctx.bus != null:
		ctx.bus.publish_all(events)
	for e in events:
		if TWBoardEvents.type_of(e) == TWBoardEvents.MATCH:
			combo_max = maxi(combo_max, int(e.get("combo", 0)))
	if board.failed:
		ended = true
		round_ended.emit(result())
	elif board.cleared:
		ended = true
		round_ended.emit(result())
		_show_result()
	else:
		ended = false
	return events


func result() -> Dictionary:
	var st: = "playing"
	if board != null and board.cleared:
		st = "cleared"
	elif board != null and board.failed:
		st = "failed"
	return {"state": st, "moves": board.moves if board != null else 0, "pairs": board.pairs_done if board != null else 0, "combo_max": combo_max}


# the FTUE targets by stable id (the coach never uses node paths)
func tut_rect(tut_id: String) -> Rect2:
	if view == null:
		return Rect2()
	match tut_id:
		"match_field":
			return view.field
		"match_tray":
			return view.tray_rect
		"match_free_tile":
			var t: = board.free_tiles() if board != null else PackedInt32Array()
			return view.tile_rect(t[0]) if t.size() > 0 else Rect2()
	return Rect2()


# ---- navigation -----------------------------------------------------------------------------------------------------------

func on_back() -> bool:
	if board == null or ended:
		return false
	if get_signal_connection_list("back_requested").is_empty():
		return false
	back_requested.emit()
	return true


# ---- the victory screen (P33) --------------------------------------------------------------------------------------------

func _modal_stack() -> ModalStack:
	if ctx == null:
		return null
	var m = ctx.service("modals")
	if m is ModalStack:
		return m
	if ctx.screens != null and ctx.screens.modals is ModalStack:
		return ctx.screens.modals
	return null


func _round_stats() -> Dictionary:
	return {"event": "clear", "win": true, "level": int(round_cfg.get("level", 0)), "seed": board.deal_seed, "hero": String(result_facts.get("partner", "")),
		"secs": maxf(0.0, board.now() - _t0), "tiles": board.n, "fails": 0, "boosters_used": _boosters_used, "max_combo": combo_max,
		"last_combo": board.combo, "denies": 0, "max_tray": board.max_tray}


func _show_result() -> void:
	var stack: = _modal_stack()
	if not show_result or stack == null or result_modal != null or round_result != null:
		return
	var st: = round_state.duplicate()
	if not st.has("partner"):
		st["partner"] = String(result_facts.get("partner", ""))
	round_result = TWRound.resolve(st, round_mode, round_cfg, _round_stats())
	if not TWResultChain.is_win(round_result):
		return
	var w = ctx.service("wallet")
	if w is TWWallet and not _paid:
		_paid = true
		round_result.pay(w)
	var m: = TWResultModal.make(round_result, result_facts, {"audio": ctx.service("audio")})
	m.on_close = _on_result_closed
	result_modal = m
	stack.open(m)


func _on_result_closed(res: Variant, _reason: String) -> void:
	result_modal = null
	var act: = ""
	if res is Dictionary:
		act = String(res.get("action", ""))
	if act == "":
		return                                     # cleared by a screen change: nothing to do
	var info: Dictionary = res
	if get_signal_connection_list("result_action").is_empty():
		if act == "next" and ctx != null and ctx.screens != null:
			var cfg: = (_cfg_in if not _cfg_in.is_empty() else DEFAULT_CFG).duplicate()
			cfg["seed"] = int(cfg.get("seed", 1)) + 1
			ctx.screens.go.call_deferred("match", {"cfg": cfg, "result_facts": result_facts})
		return
	result_action.emit(act, info)
