class_name V10TowerRules
extends RefCounted

# The play-screen adapter of the tower track: turns V10Mods data ops into calls on the live table. It is the
# strategy object the spec's R0 «V10Rules» asks for (hook_cfg / hook_start / hook_pair / hook_overflow /
# hook_end), duck-typed on the play screen so it works with today's play.gd / mode_play.gd and with V10Rules
# later. The integrator adds one call per hook (see README.md); this file never edits the play screen.
#
# Fields read / written on `play` (all exist in screens/play.gd 0.9): board (TrayBoard), partner, hint_n,
# undo_n, shuffle_n, gold_mult, skill_charge, SKILL_NEED. Methods used only if present: _skill_ready(), _refresh().

const U: = preload("res://scripts/v10/tower/tower_util.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")
const P: = preload("res://scripts/v10/tower/pagoda.gd")
const J: = preload("res://scripts/v10/tower/journey.gd")

var mode: = "pagoda"      # pagoda | journey | practice
var run: Dictionary
var rules: Dictionary
var fl: = {}              # per-floor state: shield use
var pairs: = 0
var total_pairs: = 0
var clock: = 0.0          # hourglass seconds left (0 = no clock)
var clock_full: = 0.0
var fog_left: = 0
var veils: = {}           # Tile -> Node2D overlay (fog / boss veil)
var cfg: = {}             # the cfg of the current floor (hook_cfg)

static func for_run(r: Dictionary) -> RefCounted:
	var x = load("res://scripts/v10/tower/tower_rules.gd").new()
	x.run = r
	x.mode = String(r.get("mode", "pagoda"))
	x.rules = x._resolve()
	return x

func _resolve() -> Dictionary:
	return P.floor_rules(run) if mode == "pagoda" else J.board_rules(run)

func is_journey() -> bool:
	return mode != "pagoda"

# ---- R0 hook 1: the board cfg (seed locked: retry gives the same table)
func hook_cfg() -> Dictionary:
	rules = _resolve()
	cfg = P.floor_cfg(run) if mode == "pagoda" else J.board_cfg(run)
	return cfg

# tray size: the run's own number (Journey is normalized: no outfit passives)
func slot_count(base_with_passives: int) -> int:
	if is_journey():
		return int(rules.slots)
	return clampi(int(rules.slots) + (base_with_passives - M.BASE_SLOTS), 3, 6)

# ---- R0 hook 2: after the deal (board.setup) and before input
func hook_start(play) -> Array:
	rules = _resolve()
	fl = {}
	pairs = 0
	fog_left = 0
	_clear_veils()
	var board: TrayBoard = play.board
	total_pairs = board.tiles.size() / 2
	var h: = P.helps(run) if mode == "pagoda" else J.helps(run)
	play.hint_n = int(h.hint)
	play.undo_n = int(h.undo)
	play.shuffle_n = int(h.shuffle)
	board.combo_window += float(rules.combo_window)
	if float(rules.gold_mult) > 1.0:
		play.gold_mult = int(round(float(play.gold_mult) * float(rules.gold_mult)))
	if float(rules.ult_need_mult) < 1.0 and not rules.ult_off:
		play.SKILL_NEED = maxi(2, int(ceil(float(play.SKILL_NEED) * float(rules.ult_need_mult))))
	clock_full = float(M.floor_time(rules, board.tiles.size()))
	clock = clock_full
	if cfg.is_empty():
		cfg = {"seed": 1}
	var ops: = M.on_start(rules, cfg, describe(board))
	for op in ops:
		apply_op(play, op)
	return ops

static func describe(board: TrayBoard) -> Array:
	var out: = []
	for i in board.tiles.size():
		var t: Tile = board.tiles[i]
		out.append({"i": i, "step": t.step, "free": board.is_free(t), "covered": not (board.cov[t] as Array).is_empty(),
			"secret": t.secret, "x": t.gx, "y": t.gy})
	return out

func apply_op(play, op: Dictionary) -> void:
	var board: TrayBoard = play.board
	match String(op.op):
		"auto_pairs":
			board.auto_pairs(int(op.n))
		"open":
			for i in op.tiles:
				board.open_tile(board.tiles[int(i)])
			board.reveal_free()
		"shroud":
			for i in op.tiles:
				var t: Tile = board.tiles[int(i)]
				if t.alive and not t.secret and t.ice <= 0:
					t.secret = true
					t._make_back()
		"fog":
			fog_left = int(op.lift)
			for i in op.tiles:
				_veil(board.tiles[int(i)], Color(0.62, 0.6, 0.72), -1.0)
		"fog_lift":
			_clear_veils()
		"peek":
			for t in board.tiles:
				if t.alive and t.secret and t.back_spr:
					t.back_spr.visible = false
					t.face_spr.visible = true
			board.get_tree().create_timer(float(op.secs)).timeout.connect(func():
				if not is_instance_valid(board):
					return
				for t in board.tiles:
					if is_instance_valid(t) and t.alive and t.secret and t.back_spr:
						t.back_spr.visible = true
						t.face_spr.visible = false)
		"hint":
			board.hint()
		"ult_charge":
			if rules.ult_off:
				return
			if op.has("frac"):
				play.skill_charge = maxi(int(play.skill_charge), int(ceil(float(play.SKILL_NEED) * float(op.frac))))
			else:
				play.skill_charge = mini(int(play.skill_charge) + int(op.get("n", 1)), int(play.SKILL_NEED))
			if int(play.skill_charge) >= int(play.SKILL_NEED) and play.has_method("_skill_ready"):
				play._skill_ready()
		# ---- boss tricks (Journey board 5); the screen shows the cut-in first, then calls apply_op
		"veil":
			var fr: = board.free_tiles().filter(func(t): return not t.pending and not t.secret and not veils.has(t))
			fr.sort_custom(func(a, b): return a.step < b.step)
			for t in fr.slice(0, int(op.n)):
				_veil(t, Color(0.32, 0.26, 0.55), float(op.secs))
		"frost":
			var fr2: = board.free_tiles().filter(func(t): return not t.pending and t.ice <= 0 and t.shard == "")
			fr2.sort_custom(func(a, b): return a.step > b.step)
			for t in fr2.slice(0, int(op.n)):
				t.ice = 1
				t._update_ice()
		"gust":
			var fr3: = board.free_tiles().filter(func(t): return not t.pending and t.shard == "")
			fr3.sort_custom(func(a, b): return a.step < b.step)
			board.reassign_faces(fr3.slice(0, int(op.n)))
		"smoke":
			fog_left = pairs + int(op.pairs)
			var d: = describe(board).filter(func(x): return board.on_board(board.tiles[int(x.i)]))
			for i in M.fog_tiles({"seed": int(cfg.get("seed", 7)) + pairs}, d, float(op.share)):
				_veil(board.tiles[int(i)], Color(0.45, 0.45, 0.5), -1.0)
	if play.has_method("_refresh"):
		play._refresh()

# a face veil over a tile (the look of V6Duel._veil); secs < 0 = until lifted
func _veil(t: Tile, col: Color, secs: float) -> void:
	if veils.has(t) or not t.alive:
		return
	var v: = Node2D.new()
	v.z_index = 3
	t.add_child(v)
	var m: = Sprite2D.new()
	m.texture = G.fx("tile_mask")
	m.scale = Vector2(Tile.S, Tile.S) * 0.96
	m.modulate = col
	v.add_child(m)
	v.modulate.a = 0.0
	var tw: = v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.25)
	veils[t] = v
	if secs > 0.0:
		tw.tween_interval(secs)
		tw.tween_property(v, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func():
			veils.erase(t)
			v.queue_free())

func _clear_veils() -> void:
	for t in veils.keys():
		var v: Node2D = veils[t]
		if is_instance_valid(v):
			var tw: = v.create_tween()
			tw.tween_property(v, "modulate:a", 0.0, 0.3)
			tw.tween_callback(v.queue_free)
	veils.clear()

# a tile that left the table takes its veil with it (call from play._refresh / tray_changed)
func on_tray_changed(play) -> void:
	var board: TrayBoard = play.board
	for t in veils.keys():
		if not is_instance_valid(t) or not board.on_board(t):
			var v = veils[t]
			if is_instance_valid(v):
				v.queue_free()
			veils.erase(t)

func is_veiled(t: Tile) -> bool:
	return veils.has(t)

# ---- R0 hook 3: every pair the player takes (play._on_match). Returns boss tricks to show (cut-in first).
func hook_pair(play) -> Array:
	pairs += 1
	for op in M.on_pair(rules, pairs):
		apply_op(play, op)
	if fog_left > 0 and pairs >= fog_left:
		fog_left = 0
		_clear_veils()
	if mode != "pagoda":
		return J.boss_tricks(run, pairs, total_pairs)
	return []

# ---- R0 hook 4: the tray overflowed (play._on_fail).
# Pagoda: {lose_life, return_n, run_over, lives} — the floor goes on (board.return_tray(return_n)).
# Journey: {lose_life, restart, run_over, hearts} — restart = the same table from the start.
func hook_overflow(play) -> Dictionary:
	if mode == "pagoda":
		return P.on_overflow(run, fl)
	return J.on_overflow(run, fl)

# hourglass: call every frame from play._process; returns "timeout" once when the clock runs out
func tick(dt: float) -> String:
	if clock_full <= 0.0 or clock <= 0.0:
		return ""
	clock -= dt
	if clock <= 0.0:
		clock = 0.0
		return "timeout"
	return ""

func on_timeout() -> Dictionary:
	var res: = P.on_timeout(run) if mode == "pagoda" else J.on_timeout(run)
	if not bool(res.run_over) and mode == "pagoda":
		clock = clock_full * float(res.get("refill", 0.5))
	return res

func clock_text() -> String:
	if clock_full <= 0.0:
		return ""
	var s: = int(ceil(clock))
	return "%d:%02d" % [s / 60, s % 60]

# help buttons: a curse turns a help off (the grey button says why); never a paid help in these modes
func help_ok(kind: String) -> bool:
	match kind:
		"hint":
			return not rules.hint_off
		"undo":
			return not rules.undo_off
		"shuffle":
			return not rules.shuffle_off
		"ult":
			return not rules.ult_off
	return true

func help_off_text(kind: String) -> String:
	var names: = {"hint": "Без подсказок", "undo": "Без отмен", "shuffle": "Без смешиваний", "ult": "Без ульты"}
	return "Проклятие «%s»" % String(names.get(kind, kind))

func paid_help() -> bool:
	return false

# ---- R0 hook 5: the floor / board is cleared. res = {secs, max_combo, pairs}
func hook_clear(res: Dictionary) -> Dictionary:
	_clear_veils()
	return P.floor_clear(run, res) if mode == "pagoda" else J.board_clear(run, res)
