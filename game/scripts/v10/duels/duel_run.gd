class_name V10DuelRun
extends V6Duel

# V10DuelRun — the heroine-rival in a match of «Дуэли 2.0» (spec R6). Replaces V6Duel on the play screen.
#
#   Her pace is her form's (V10DuelForms.run_params): in ranked it never reads your wins (no 0.6 rubber band);
#   friendly keeps it. Before a take her two tiles shimmer in her colour for the form's telegraph (0,7–1,2 s);
#   take one of them first and her move fails («Перехват!»). The pair she takes flies to her portrait, the
#   portrait answers with her emotions, haptics tick in her rhythm (mark → tap, take → select, trick → skill).
#   Her «подлость» charges from her pairs and plays at most trick_n times (≤ 2, shown on her gauge).
#   «ИИ · ГЕРОИНЯ» badge on her name plate. Seeded: her choices and pace jitter come from the deal's seed.
#
#   adopt(play, rebuild = true) -> V10DuelRun   swap a running V6Duel for this node (works on today's play.gd
#                       with no edits: cfg from V10DuelCfg, the seed, 4 slots in ranked, the helps, the specials)
#   launch(main, args) -> V10DuelRun            await main.go("play", args) + adopt (the zero-hook route)
#   normalize(play)                             the fair table: no gifts / streak / events, ranked helps 1/0/0,
#                                               no outfit passives in ranked, never a price on a help button
#   signal result_ready(res)                    the end beat: res = V10Duel.finish(...) (README «Итог партии»)
#   static var ceremony: Callable               func(play, res): the UI lane's result ceremony, called 1,2 s
#                                               after the end beat; unset → a plain result sheet (fallback)
#   static var back_to: String                  where «Дальше» and the exit go ("" = "duels" → "modes" → "home")
#   leave(play)                                 go there (for the ceremony's own button)
#   static var auto_gap: float                  selftest / demo bot (taps every auto_gap s; 0 = off), auto_notice

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const C: = preload("res://scripts/v10/duels/duel_cfg.gd")
const D: = preload("res://scripts/v10/duels/duel_state.gd")

signal result_ready(res: Dictionary)

static var ceremony: Callable = Callable()
static var back_to: = ""
static var auto_gap: = 0.0
static var auto_notice: = 0.6

const SPRINT_K: = 2.2
const BADGE: = "ИИ · ГЕРОИНЯ"

var args: = {}
var duel_id: = ""
var kind: = "ranked"
var form_n: = 3
var fm: = {}
var tele: = 0.95
var need: = 5
var trick_n: = 1
var tricks: = 0
var start_sprint: = 0.0
var rng: RandomNumberGenerator
var res: = {}
var hud: Control
var badge: Control
var her_col: = Color.WHITE
var my_col: = Color.WHITE
var _left: = false
var _gained_base: = 0
var _bot_t: = 1.0
var _bot_gap: = 0.0
var _bot_rng: RandomNumberGenerator
var _bars: = {}


# ---------------------------------------------------------------- setup

func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--duel_auto="):
			_bot_gap = float(a.substr(12))
	if auto_gap > 0.0:
		_bot_gap = auto_gap
	if _auto:
		_bot_gap = _auto_gap


func setup(p, rival_id: String) -> void:
	play = p
	board = p.board
	args = p.args0 if (p.args0 is Dictionary) else {}
	rival = rival_id if G.HEROES.has(rival_id) else "rin"
	kind = String(args.get("kind", "ranked"))
	form_n = clampi(int(args.get("form", 3)), 1, F.FORMS)
	duel_id = String(args.get("duel_id", ""))
	fm = F.run_params(rival, form_n, kind, int(args.get("wins_vs", 0)))
	pace = float(fm.pace)
	tele = float(fm.telegraph)
	need = int(fm.need)
	trick_n = int(fm.trick_n)
	start_sprint = float(fm.get("start_sprint", 0.0))
	her = int(fm.get("her_start", 0))
	var tk: = F.trick(rival)
	rv = {"skill": tk.kind, "skill_name": tk.name, "skill_desc": tk.desc, "pace": pace}
	var sd: = int(p.cfg.get("seed", 1))
	rng = U.rng(sd, "her|" + rival + "|" + str(form_n))
	_bot_rng = U.rng(sd, "bot")
	her_col = _accent(rival)
	my_col = _accent(String(p.partner))
	p.riichi_offered = true
	if duel_id != "":
		D.live_id = duel_id
	var W: float = p.W
	stage = V6HeroStage.new().setup(rival, Rect2(W - 250, 66, 242, 240), {"tag": "Форма %s" % F.roman(form_n)})
	stage.gauge_lbl.text = ""
	p.add_child(stage)
	stage.pressed.connect(func():
		V9Feel.press(stage, "pop", "tap")
		stage.flash_emotion("happy" if her >= me else "pout")
		stage.say_text(V6Heroines.line(rival, "lead" if her >= me else "behind")))
	_badge()
	_build_panel(W)
	p.move_child(p.stage, -1)
	t_next = pace + 1.0
	_gained_base = int(p.gained)
	normalize(p)
	_leave_hooks()
	_update_score()


static func _accent(h: String) -> Color:
	if V10DS.HEROES.has(h):
		return V10DS.hero(h).accent
	return U.hero_color(h)


# «ИИ · ГЕРОИНЯ» on her name plate (below her face, never over it)
func _badge() -> void:
	var cnt: Control = stage.counter
	if cnt == null:
		return
	var bw: = ceilf(V10Type.text_w(BADGE, "overline", 15)) + 16.0
	for c in cnt.get_children():
		if c is Label:
			(c as Label).size.x = cnt.size.x - 24.0 - bw - 6.0
			break
	badge = Control.new()
	badge.name = "V10DuelAiBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(cnt.size.x - bw - 10.0, 3.0)
	badge.size = Vector2(bw, 22)
	badge.set_meta("ux_role", "badge")
	cnt.add_child(badge)
	var bg: = ColorRect.new()
	bg.color = Color(V10DS.NIGHT_900, 0.72)
	bg.size = badge.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(bg)
	var l: = V10Type.label(BADGE, "overline", 15, V10DS.GOLD_500)
	l.position = Vector2(8, 1)
	l.size = Vector2(bw - 16, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.name = "Text"
	badge.add_child(l)


class Surface extends Control:
	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size))


# the score plate over the match name plate: you · pairs · her, and the tug bar of the race
func _build_panel(W: float) -> void:
	var r: = Rect2(92, 16, W - 92 - 258, 104)
	hud = Surface.new()
	hud.name = "V10DuelScore"
	hud.position = r.position
	hud.size = r.size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(hud)
	var pw: = r.size.x
	var x0: = 108.0
	var l1: = V10Type.label("ТЫ", "overline", 15, V10DS.PAPER_500)
	l1.position = Vector2(x0, 6)
	l1.size = Vector2(80, 20)
	hud.add_child(l1)
	score_me = V10Type.label("0", "num", 40, V10DS.PAPER_100)
	score_me.position = Vector2(x0, 24)
	score_me.size = Vector2(80, 46)
	score_me.pivot_offset = Vector2(20, 23)
	hud.add_child(score_me)
	var vs: = V10Type.label("ПАРЫ", "overline", 15, V10DS.PAPER_500)
	vs.position = Vector2(x0, 38)
	vs.size = Vector2(pw - x0 - 14, 20)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(vs)
	var l2: = V10Type.label(U.hero_name(rival).to_upper(), "overline", 15, her_col)
	l2.position = Vector2(pw - 160, 6)
	l2.size = Vector2(146, 20)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(l2)
	score_her = V10Type.label("0", "num", 40, her_col)
	score_her.position = Vector2(pw - 94, 24)
	score_her.size = Vector2(80, 46)
	score_her.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_her.pivot_offset = Vector2(60, 23)
	hud.add_child(score_her)
	var track: = ColorRect.new()
	track.color = Color(her_col, 0.55)
	track.position = Vector2(x0, 80)
	track.size = Vector2(pw - x0 - 14, 10)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(track)
	bar_w = track.size.x
	var fill: = ColorRect.new()
	fill.color = my_col
	fill.size = Vector2(bar_w * 0.5, 10)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	_bars = {"track": track, "fill": fill}
	her_gauge = stage.gauge
	her_gauge_w = stage.gauge_w


func _update_score() -> void:
	if score_me == null or not is_instance_valid(score_me):
		return
	score_me.text = str(me)
	score_her.text = str(her)
	var tot: = me + her
	var f: = 0.5 if tot == 0 else clampf(float(me) / tot, 0.06, 0.94)
	var fill: ColorRect = _bars.get("fill")
	if fill and is_instance_valid(fill):
		var dur: = V10DS.T_PROGRESS if V9Feel.can_fx() else 0.12
		fill.create_tween().tween_property(fill, "size:x", bar_w * f, dur).set_trans(Tween.TRANS_QUAD)
	if her_gauge and is_instance_valid(her_gauge):
		var left: = trick_n - tricks
		var k: = 1.0 if left <= 0 else float(mini(gauge, need)) / float(maxi(1, need))
		her_gauge.create_tween().tween_property(her_gauge, "size:x", maxf(8.0, her_gauge_w * k), 0.25)
		stage.gauge_lbl.text = "%s · %s" % [String(fm.trick_name), U.times_text(maxi(0, left))]


# ---------------------------------------------------------------- the fair table (both routes)

static func normalize(p) -> void:
	var a: Dictionary = p.args0 if (p.args0 is Dictionary) else {}
	_strip_specials(p)
	if C.normalized(a):
		var hp: = C.helps_for(a)
		p.hint_n = int(hp.hint)
		p.undo_n = int(hp.undo)
		p.shuffle_n = int(hp.shuffle)
		p.gem_bonus = 0.0
		p.gold_mult = 1
		if p.board:
			p.board.combo_window = 5.0
			p.board.slots = C.SLOTS
		var pr: Node = p.get_node_or_null("V7PassiveRun")
		if pr:
			pr.set_process(false)
			pr.name = "V7PassiveRunOff"
			pr.queue_free()
	else:
		_unrank_ult(p)
	_gate_helps(p)
	if p.has_method("_refresh") and p.board and p.tiles_lbl:
		p._refresh()
	_help_captions(p)


# «Честный стол»: no gift tiles, no lucky streak rewards, no table events (they pay outside the duel caps)
static func _strip_specials(p) -> void:
	var b = p.board
	if b is V6SpecialBoard:
		for t in b.icons:
			if is_instance_valid(b.icons[t]):
				b.icons[t].queue_free()
		b.icons.clear()
		b.spec.clear()
	var sp: Node = p.get_node_or_null("V6Specials")
	if sp:
		sp.set("plan", {"streak": false})
		sp.set("event_done", true)


# friendly / weekly: your outfit's Приём works as off ranked (ranked keeps V9's ranked core: start 0, need 6)
static func _unrank_ult(p) -> void:
	var u = p.get("ult")
	if u == null or not is_instance_valid(u) or not bool(u.get("ranked")):
		return
	u.ranked = false
	u.core = V9Ults.core(String(u.hero), false)
	u.mod = V9Ults.mod(String(u.id), false)
	p.SKILL_NEED = u.need()
	if not p.skill_ready:
		p.skill_charge = u.start_charge()


static func _gate_helps(p) -> void:
	for k in ["hint", "undo", "shuffle"]:
		var b: JButton = p.get("btn_" + k)
		if b == null or not is_instance_valid(b) or b.has_meta("v10_duel_gate"):
			continue
		b.set_meta("v10_duel_gate", true)
		b.set_meta("ux_role", "secondary")
		for c in b.denied.get_connections():
			b.denied.disconnect(c.callable)
		var kk: String = k
		b.set_gate(func(): return bool(p._help_ok(kk)) and int(p.get(kk + "_n")) > 0, func(): _help_denied(p, kk))


const T_HELP_RANKED: = {
	"hint": "Подсказка в рейтинговой дуэли — 1 раз за партию",
	"undo": "В рейтинговой дуэли без отмены хода: стол у всех равный",
	"shuffle": "В рейтинговой дуэли без перемешивания: стол у всех равный",
}
const T_HELP_OUT: = {
	"hint": "Подсказки этой партии закончились",
	"undo": "Отмены хода этой партии закончились",
	"shuffle": "Перемешивания этой партии закончились",
}

static func _help_denied(p, k: String) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	if int(p.get(k + "_n")) <= 0:
		var t: String = T_HELP_RANKED[k] if C.normalized(p.args0) else T_HELP_OUT[k]
		p.main.toast(t, "lock")
		return
	# the help is there but the table refuses it (deal, nothing to undo…): the play handler says why
	p.call("_" + k)


# a help with nothing left reads «Подсказка · 0» and is greyed (never «· 30 кр.»: no prices in a duel)
static func _help_captions(p) -> void:
	for k in ["hint", "undo", "shuffle"]:
		var b: JButton = p.get("btn_" + k)
		if b == null or not is_instance_valid(b):
			continue
		var n: = int(p.get(k + "_n"))
		var cap: Label = b.get_node_or_null("Cap")
		if cap:
			var want: = "%s · %d" % [String(cap.get_meta("base", cap.text)), maxi(0, n)]
			if cap.text != want:
				cap.text = want
		var off: bool = n <= 0 or bool(p.get("riichi"))
		if b.disabled != off:
			b.disabled = off


# ---------------------------------------------------------------- leaving = loss

func _leave_hooks() -> void:
	play.set_meta("v8_back", Callable(self, "ask_leave"))
	for c in play.get_children():
		if c is JButton and (c as JButton).position == Vector2(12, 22) and (c as JButton).size == Vector2(70, 70):
			var hb: JButton = c
			for cn in hb.pressed.get_connections():
				hb.pressed.disconnect(cn.callable)
			hb.pressed.connect(ask_leave)
			hb.set_meta("ux_role", "quiet")
			break


func leave_text() -> String:
	return D.leave_text()


func ask_leave() -> void:
	if not is_instance_valid(play) or play.main == null:
		return
	if finished or _left:
		leave(play)
		return
	Common.confirm(play.main, "Выйти из партии?", D.leave_text(), "", 0, func():
		_exit_now()
		leave(play), {"yes_text": "Выйти", "no_text": "Играть"})


func _exit_now() -> void:
	if finished or _left:
		return
	_left = true
	finished = true
	_clear_marks()
	if duel_id != "":
		res = D.abandon(duel_id, me, her)
	if is_instance_valid(play):
		play._v8_saved = true


static func back_screen(main) -> String:
	var sc = main.get("SCREENS")
	var has: = func(id: String) -> bool: return sc is Dictionary and (sc as Dictionary).has(id)
	if back_to != "" and has.call(back_to):
		return back_to
	for id in ["duels", "modes"]:
		if has.call(id):
			return id
	return "home"


static func leave(p) -> void:
	if p == null or not is_instance_valid(p) or p.main == null:
		return
	p.main.go(back_screen(p.main))


func _exit_tree() -> void:
	if not finished and not _left and duel_id != "":
		_left = true
		var counted: = is_instance_valid(play) and bool(play.get("_v8_loss_done"))
		res = D.abandon(duel_id, me, her, counted)
	if D.live_id == duel_id:
		D.live_id = ""


# ---------------------------------------------------------------- her play

func _process(dt: float) -> void:
	if is_instance_valid(play):
		_help_captions(play)
		if play.board != board and is_instance_valid(play.board):
			board = play.board
	if finished or board == null or not is_instance_valid(board):
		return
	taunt_cd -= dt
	if not board.input_on or casting or play.get_meta("v6_casting", false):
		return
	if _bot_gap > 0.0:
		_bot_t -= dt
		if _bot_t <= 0.0:
			_bot_t = _bot_gap
			_bot_move()
	if not started:
		started = true
		stage.say_text(V6Heroines.line(rival, "start"), 2.8)
		if start_sprint > 0.0:
			sprint_until = G.time + start_sprint
	t_next -= dt * (SPRINT_K if G.time < sprint_until else 1.0)
	if target.is_empty():
		if t_next <= tele:
			_pick()
		return
	var a: Tile = target[0]
	var b: Tile = target[1]
	if not (board.on_board(a) and board.on_board(b)) or a.pending or b.pending:
		_stolen(a if not board.on_board(a) else b)
	elif t_next <= 0.0:
		if board.is_free(a) and board.is_free(b) and a.ice <= 0 and b.ice <= 0:
			_take([a, b], true)
		else:
			# the table changed under her pair (a tile came back on top): she looks again, no steal counted
			_clear_marks()
			target = []
			t_next = tele + 0.2


# the selftest / demo player: grabs her shimmering pair first with auto_notice, else the board solver's move
func _bot_move() -> void:
	if not target.is_empty() and _bot_rng.randf() < auto_notice:
		for t in target:
			var tt: Tile = t
			if board.on_board(tt) and board.is_free(tt) and not tt.pending and tt.ice <= 0 and not tt.flipping:
				var twin: = board.tray.any(func(x): return x.face == tt.face)
				if twin or board.tray.size() <= board.slots - 2:
					board.tap(tt)
					return
	var mv: Tile = board.solver_move()
	if mv:
		board.tap(mv)


func _candidates() -> Array:
	return _her_pairs(float(fm.soft_steal))


# her pairs: two free face-up tiles of a face; faces you hold in the tray only with her form's soft_steal
func _her_pairs(soft: float) -> Array:
	var by: = {}
	for t in board.free_tiles():
		if t.pending or t.ice > 0 or t.secret or t.shard != "" or t.flipping or t.back_spr != null or t.has_meta("v10_veil"):
			continue
		by[t.face] = by.get(t.face, []) + [t]
	var held: = {}
	for t in board.tray:
		held[t.face] = true
	var out: = []
	var soft_l: = []
	var faces: = by.keys()
	faces.sort()
	for f in faces:
		var arr: Array = by[f]
		if arr.size() < 2:
			continue
		var pair: = [arr[0], arr[1]]
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				if arr[i].step == arr[j].step:
					pair = [arr[i], arr[j]]
		if held.has(f):
			soft_l.append(pair)
		else:
			out.append(pair)
	if out.is_empty() or rng.randf() < soft:
		out.append_array(soft_l)
	U.shuffle(out, rng)
	return out


func _pick() -> void:
	var c: = _candidates()
	if c.is_empty():
		t_next = 1.2 + tele
		if taunt_cd <= 0.0 and rng.randf() < 0.3:
			stage.emote("dots")
			taunt_cd = 4.0
		return
	target = c[0]
	t_next = tele
	for t in target:
		_mark(t)
	stage.react("match")
	V10SfxBank.play("tile_select", {"pitch": 0.82, "db": -6.0})
	V9Feel.haptic("tap")


# her shimmer: a glow in her colour that breathes, a ring that closes in over the telegraph (fx min: a still tint)
func _mark(t: Tile) -> void:
	var g: = Sprite2D.new()
	g.texture = G.fx("tile_glow")
	g.material = Fx.add_mat()
	g.scale = Vector2(Tile.S, Tile.S) * 1.12
	g.z_index = 1
	t.add_child(g)
	marks.append(g)
	if not V9Feel.can_fx():
		g.modulate = Color(her_col, 0.85)
		return
	g.modulate = Color(her_col, 0.0)
	var r: = Sprite2D.new()
	r.texture = G.fx("ring")
	r.material = Fx.add_mat()
	r.modulate = Color(her_col, 0.9)
	r.scale = Vector2(0.9, 0.9)
	r.z_index = 2
	t.add_child(r)
	marks.append(r)
	var tw: = g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 1.0, 0.22)
	tw.tween_property(g, "modulate:a", 0.45, 0.22)
	r.create_tween().tween_property(r, "scale", Vector2(0.35, 0.35), tele).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _stolen(at: Tile) -> void:
	_clear_marks()
	target = []
	steals += 1
	t_next = pace * float(fm.steal_recover)
	stage.react("deny")
	stage.flash_emotion("pout")
	V9Feel.haptic("match")
	V10SfxBank.play("star", {"db": -6.0})
	if taunt_cd <= 0.0:
		taunt_cd = 3.0
		stage.say_text(V6Heroines.line(rival, "steal"))
	if is_instance_valid(at):
		Fx.float_text(play.fx_layer, V6Skills._pos(at) + Vector2(0, -60), "Перехват!", V10DS.JADE_300, 32, V10DS.NIGHT_900)


func _take(pair: Array, talk: bool) -> void:
	_clear_marks()
	target = []
	var booth: = stage.get_global_transform_with_canvas() * Vector2(stage.size.x * 0.5, stage.size.y * 0.45)
	var mid: Vector2 = (V6Skills._pos(pair[0]) + V6Skills._pos(pair[1])) * 0.5
	var full: = V9Feel.can_fx()
	for t in pair:
		var tile: Tile = t
		tile.alive = false
		tile.kill_move()
		tile.hint(false)
		tile.z_index = 150
		var tw: Tween = tile.create_tween()
		if full:
			var to: Vector2 = tile.get_parent().get_global_transform_with_canvas().affine_inverse() * booth
			var from: Vector2 = tile.position
			var ctrl: = from.lerp(to, 0.5) + Vector2(0, -120)
			var s0: float = tile.scale.x
			tw.tween_property(tile, "modulate", Color(her_col.lightened(0.35), 1.0), 0.12)
			tw.tween_method(func(v: float):
				tile.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v)
				tile.scale = Vector2.ONE * lerpf(s0, 0.35, v), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(tile, "modulate:a", 0.0, 0.08)
		else:
			tw.tween_property(tile, "modulate:a", 0.0, 0.12)
		tw.tween_callback(tile.hide)
	her += 1
	gauge += 1
	board.reveal_free()
	board.tray_changed.emit()
	if full:
		Fx.burst(play.fx_layer, mid, "sparkle", 14, her_col.lightened(0.3), 1.0)
	V10SfxBank.play("match_2", {"pitch": 0.9, "db": -3.0})
	V9Feel.haptic("select")
	t_next = pace * (1.0 + float(fm.jitter) * (rng.randf() * 2.0 - 1.0))
	get_tree().create_timer(0.5 if full else 0.12).timeout.connect(func():
		if finished or not is_instance_valid(stage):
			return
		stage.react("smug")
		if her - me >= 2 or rng.randf() < 0.3:
			stage.flash_emotion("happy")
		if full:
			UI.punch(score_her, 0.35)
		_update_score())
	if talk and taunt_cd <= 0.0 and rng.randf() < 0.45:
		taunt_cd = 4.0
		stage.say_text(V6Heroines.line(rival, "take" if her - me < 3 else "lead"))
	board._check_clear()
	if gauge >= need and tricks < trick_n:
		gauge = 0
		await get_tree().create_timer(0.7).timeout
		if not finished and is_inside_tree():
			_skill()


# her «подлость», at most trick_n times a match (≤ 2)
func _skill() -> void:
	if finished or tricks >= trick_n or tricks >= F.TRICK_CAP:
		return
	casting = true
	tricks += 1
	var tk: = F.trick(rival)
	var k: = String(tk.kind)
	var chosen: = []
	var targets: = []
	match k:
		"double":
			chosen = _her_pairs(1.0).slice(0, 2)
			for p2 in chosen:
				targets.append(V6Skills._pos(p2[0]))
				targets.append(V6Skills._pos(p2[1]))
		"veil", "frost", "gust":
			var fr: = board.free_tiles().filter(_trick_ok)
			U.shuffle(fr, rng)
			chosen = fr.slice(0, int(tk.n))
			for t in chosen:
				targets.append(V6Skills._pos(t))
	stage.say_text(V6Heroines.line(rival, "skill"), 2.2)
	V9Feel.haptic("skill")
	V10SfxBank.play("cutin_whoosh")
	await stage.cast(String(tk.name), targets, String(tk.desc))
	casting = false
	if finished or not is_inside_tree():
		return
	match k:
		"double":
			for p2 in chosen:
				if board.on_board(p2[0]) and board.on_board(p2[1]) and not p2[0].pending and not p2[1].pending:
					await _take(p2, false)
					await get_tree().create_timer(0.2).timeout
		"sprint":
			sprint_until = G.time + float(tk.secs)
			t_next = minf(t_next, 1.0)
			Fx.float_text(play.fx_layer, stage.position + Vector2(stage.size.x * 0.5, stage.size.y + 30), "Вдвое быстрее · 7 секунд", her_col.lightened(0.3), 26, V10DS.NIGHT_900)
		"veil":
			for t in chosen:
				if is_instance_valid(t) and board.on_board(t):
					_veil(t)
		"frost":
			for t in chosen:
				if is_instance_valid(t) and board.on_board(t) and not t.pending:
					t.ice = 1
					t._update_ice()
			board.reveal_free()
		"gust":
			var ok: = chosen.filter(func(t): return is_instance_valid(t) and board.on_board(t) and not t.pending)
			board.reassign_faces(ok)
			if V9Feel.can_fx():
				for t in ok:
					var tw: Tween = t.create_tween()
					tw.tween_property(t, "scale", Vector2(0.0, 1.0), 0.12).set_delay(rng.randf() * 0.2)
					tw.tween_property(t, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_score()


func _trick_ok(t: Tile) -> bool:
	return not t.pending and not t.secret and t.ice <= 0 and not t.flipping and t.shard == "" and t.back_spr == null


# her veil: the face under a night plate with her moon for 5 s (the tile stays playable)
func _veil(t: Tile) -> void:
	var secs: = float(F.TRICKS.veil.secs)
	var v: = Node2D.new()
	v.z_index = 3
	t.add_child(v)
	t.set_meta("v10_veil", true)
	var m: = Sprite2D.new()
	m.texture = G.fx("tile_mask")
	m.scale = Vector2(Tile.S, Tile.S) * 0.96
	m.modulate = V10DS.NIGHT_700
	v.add_child(m)
	var moon: = Sprite2D.new()
	moon.texture = G.fx("sparkle")
	moon.material = Fx.add_mat()
	moon.scale = Vector2(0.4, 0.4)
	moon.modulate = her_col
	v.add_child(moon)
	v.modulate.a = 0.0
	var fade: = 0.25 if V9Feel.can_fx() else 0.12
	var tw: = v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, fade)
	tw.tween_interval(secs)
	tw.tween_property(v, "modulate:a", 0.0, fade)
	tw.tween_callback(func():
		if is_instance_valid(t):
			t.remove_meta("v10_veil")
		v.queue_free())


# ---------------------------------------------------------------- your pairs, the overflow, the end

func on_player_pair(_mid: Vector2) -> void:
	_refund_pair()
	if finished:
		return
	me += 1
	if V9Feel.can_fx():
		UI.punch(score_me, 0.3)
	_update_score()
	if taunt_cd <= 0.0 and me - her == 3:
		taunt_cd = 5.0
		stage.react("deny")
		stage.flash_emotion("sad")
		stage.say_text(V6Heroines.line(rival, "behind"))


# Дуэли 2.0 pay only at the end (caps of V10Duel): the crystals play.gd adds per pair go back, with their «+N»
func _refund_pair() -> void:
	if not is_instance_valid(play):
		return
	var extra: = int(play.gained) - _gained_base
	if extra == 0:
		return
	G.S.gems = int(G.S.gems) - extra
	play.gained = _gained_base
	if play.fx_layer:
		for i in range(play.fx_layer.get_child_count() - 1, -1, -1):
			var c: Node = play.fx_layer.get_child(i)
			if c is Label and String((c as Label).text).begins_with("+"):
				c.queue_free()
				break


func on_overflow() -> void:
	if finished:
		return
	her += 1
	stage.react("smug")
	stage.flash_emotion("happy")
	Fx.float_text(play.fx_layer, Vector2(play.W * 0.5, 330), "Лоток полон: пара сопернице", V10DS.ROSE_300, 28, V10DS.NIGHT_900)
	_update_score()


func finish() -> void:
	if finished:
		return
	finished = true
	_clear_marks()
	if is_instance_valid(board):
		board.input_on = false
	var win: = me > her
	var draw: = me == her
	_end_line = V6Heroines.line(rival, "lose" if win else ("draw" if draw else "win"))
	if duel_id != "":
		res = D.finish(duel_id, me, her, {"steals": steals, "tricks": tricks, "line": _end_line})
	if res.is_empty():
		# a dev run without V10Duel.start (no pending): the bare result, nothing paid
		res = {"id": duel_id, "kind": kind, "kind_name": C.kind_name(kind), "rival": rival, "rival_name": U.hero_name(rival),
			"form": form_n, "roman": F.roman(form_n), "win": win, "draw": draw, "exit": false, "me": me, "her": her,
			"steals": steals, "tricks": tricks, "line": _end_line, "partner": String(play.partner), "rewards": {}, "rows": [],
			"rating": {}, "weekly": {}, "title": "Победа" if win else ("Ничья" if draw else "Победа за ней")}
	_left = true
	play._v8_saved = true
	play.set_meta("v6_duel_result", {"win": win, "me": me, "her": her})
	play.set_meta("v10_duel_result", res)
	stage.react("deny" if win else "win")
	stage.say_text(_end_line, 3.0)
	play.stage.react("win" if win else "fail")
	stage.flash_emotion("surprised" if draw else ("pout" if win else "happy"))
	play.stage.flash_emotion("surprised" if draw else (V8Art.win_emotion(play.partner) if win else "sad"))
	V10SfxBank.play("rank_up" if win else "reward_pop")
	V9Feel.haptic("clear" if win else "fail")
	print("DUEL2 %s %d:%d %s form %d seed %d" % ["WIN" if win else ("DRAW" if draw else "LOSE"), me, her, rival, form_n, int(play.cfg.get("seed", 0))])
	result_ready.emit(res)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree() or not is_instance_valid(play) or not play.is_inside_tree():
		return
	_result(win, draw, 0, false)


# never the 0.8 result window: the UI lane's ceremony, or the plain sheet below
func _result(_win: bool, _draw: bool, _gems: int, _shard: bool) -> void:
	if ceremony.is_valid():
		ceremony.call(play, res)
		return
	sheet(play, res)


# ---------------------------------------------------------------- the plain result sheet (fallback)

static func sheet(p, r: Dictionary) -> Control:
	if p.has_method("_v8_end_overlays"):
		p._v8_end_overlays()
	var W: float = p.size.x
	var root: = Control.new()
	root.name = "V10DuelSheet"
	root.size = p.size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 300
	p.add_child(root)
	var dim: = ColorRect.new()
	var br: Rect2 = V10Layout.bleed_rect(p)
	dim.position = br.position
	dim.size = br.size
	dim.color = Color(V10DS.NIGHT_900, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var pw: = 672.0
	var plate: = Surface.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2((W - pw) * 0.5, 0)
	root.add_child(plate)
	var st: = {"y": 32.0, "w": pw}
	var col: = func(n, h, gap) -> void:
		_put(plate, n, st, float(h), float(gap))
	var win: = bool(r.get("win", false))
	var draw: = bool(r.get("draw", false))
	var rival_id: = String(r.get("rival", "rin"))
	var partner: = String(r.get("partner", "mc"))
	var ov: = V10Type.label(String(r.get("kind_name", "")).to_upper() + " · ФОРМА " + String(r.get("roman", "")), "overline", 15, V10DS.GOLD_500)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.call(ov, 20, 6)
	var tl: = V10Type.label(String(r.get("title", "")), "display", 44, V10DS.PAPER_100)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.call(tl, 52, 16)
	# both faces show the outcome; the score sits between them
	var my_emo: = "surprised" if draw else (V8Art.win_emotion(partner) if win else "sad")
	var her_emo: = "surprised" if draw else ("pout" if win else "happy")
	var row: = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.call(row, 150, 8.0)
	row.add_child(V8Art.emotion_avatar(partner, my_emo, Rect2(8, 0, 120, 120), "gold" if win else "pink"))
	row.add_child(V8Art.emotion_avatar(rival_id, her_emo, Rect2(pw - 48 - 128, 0, 120, 120), "pink" if win else "gold"))
	var n1: = V10Type.label("ТЫ", "overline", 15, V10DS.PAPER_500)
	n1.position = Vector2(8, 126)
	n1.size = Vector2(120, 20)
	n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(n1)
	var n2: = V10Type.label(String(r.get("rival_name", "")).to_upper(), "overline", 15, _accent(rival_id))
	n2.position = Vector2(pw - 48 - 148, 126)
	n2.size = Vector2(160, 20)
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(n2)
	var sc: = V10Type.label("%d : %d" % [int(r.get("me", 0)), int(r.get("her", 0))], "num", 40, V10DS.PAPER_100)
	sc.position = Vector2(140, 26)
	sc.size = Vector2(pw - 48 - 280, 48)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(sc)
	var pairs: = maxi(int(r.get("me", 0)), int(r.get("her", 0)))
	var pc: = V10Type.label(U.plural(pairs, "пара", "пары", "пар"), "ui", 18, V10DS.PAPER_500)
	pc.position = Vector2(140, 76)
	pc.size = Vector2(pw - 48 - 280, 26)
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(pc)
	if String(r.get("line", "")) != "":
		var q: = V10Type.label("«%s»" % String(r.line), "ui", 20, _accent(rival_id))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.clip_text = false
		col.call(q, 56, 12)
	var rt: Dictionary = r.get("rating", {})
	if not rt.is_empty():
		var rl: = HBoxContainer.new()
		rl.alignment = BoxContainer.ALIGNMENT_CENTER
		rl.add_theme_constant_override("separation", 16)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.call(rl, 44, 2)
		rl.add_child(V10Type.label(String(rt.get("text", "")), "num", 28, V10DS.PAPER_100))
		var dl: = int(rt.get("delta", 0))
		rl.add_child(V10Type.label(String(rt.get("delta_text", "")), "num", 28, V10DS.JADE_300 if dl > 0 else (V10DS.EMBER if dl < 0 else V10DS.PAPER_500)))
		var tier_t: = "%s · %s" % [String(rt.get("tier_name", "")), String(rt.get("caption", ""))]
		if bool(rt.get("tier_up", false)):
			tier_t = "Новая ступень: " + String(rt.get("tier_name", ""))
		var tc: = V10Type.label(tier_t, "ui", 18, V10DS.GOLD_300 if bool(rt.get("tier_up", false)) else V10DS.PAPER_300)
		tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.call(tc, 26, 12)
	var wk: Dictionary = r.get("weekly", {})
	if not wk.is_empty():
		var wl: = V10Type.label("Дуэль недели · " + String(wk.get("progress_text", "")), "ui", 20, V10DS.PAPER_300)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.call(wl, 28, 10)
	for row_r in r.get("rows", []):
		var rr: = V10Type.label(String(row_r.text), "ui", 22, V10DS.GOLD_300)
		rr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.call(rr, 32, 4)
	if (r.get("rows", []) as Array).is_empty() and win and r.has("caps"):
		var cl: = V10Type.label(String(r.caps.get("ranked_text" if String(r.get("kind", "")) == "ranked" else "friendly_text", "")), "ui", 18, V10DS.PAPER_500)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.call(cl, 26, 4)
	var y: float = float(st.y) + 20.0
	var b: = V10Button.make("play", "Дальше", Vector2(560, 104))
	b.name = "Next"
	b.set_meta("ux_role", "primary")
	b.position = Vector2((pw - 560) * 0.5, y)
	plate.add_child(b)
	y += 104.0 + 28.0
	b.pressed.connect(func():
		V9Feel.press(b)
		leave(p))
	plate.size = Vector2(pw, y)
	plate.position.y = maxf(24.0, (p.size.y - y) * 0.5)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, V10DS.T_IN if V9Feel.can_fx() else 0.12)
	return root


static func _put(plate: Control, n: Control, st: Dictionary, h: float, gap: float) -> void:
	n.position = Vector2(24, float(st.y))
	n.size = Vector2(float(st.w) - 48, h)
	plate.add_child(n)
	st.y = float(st.y) + h + gap


# ---------------------------------------------------------------- the swap (zero-hook route)

# take over a running play screen built by today's play.gd for args {mode "duel", duel2 true, …}: the V6Duel
# goes, the table is dealt again from V10DuelCfg (fixed seed; ranked: 4 slots), the helps are normalized.
# Call it before the deal lands (play._intro waits 1,1 s, so right after main.go returns).
static func adopt(p, rebuild: = true) -> V10DuelRun:
	var old = p.duel
	if old is V10DuelRun:
		return old
	if old != null and is_instance_valid(old):
		old.finished = true
		for k in ["stage", "panel"]:
			var n = old.get(k)
			if n != null and is_instance_valid(n):
				n.queue_free()
		old.queue_free()
	p.duel = null
	var a: Dictionary = p.args0
	if rebuild:
		var old_cfg: Dictionary = p.cfg
		p.cfg = C.cfg_for(a, String(p.partner))
		if C.normalized(a) and p.slot_rects.size() != C.SLOTS:
			_rebuild_tray(p, C.SLOTS)
		seed(int(p.cfg.seed))
		p._make_board()
		if C.normalized(a):
			p.board.slots = C.SLOTS
		p.board.visible = false
		_retitle(p, old_cfg)
		var ti: Node = p.get_node_or_null("V10TileInfo")
		if ti:
			ti.set("board", p.board)
	var r: = V10DuelRun.new()
	r.name = "V10DuelRun"
	p.add_child(r)
	p.duel = r
	r.setup(p, String(a.get("rival", "rin")))
	return r


static func launch(main, a: Dictionary) -> V10DuelRun:
	await main.go("play", a)
	if main.screen == null or not is_instance_valid(main.screen) or not main.screen.has_method("_make_board"):
		return null
	return adopt(main.screen)


# the tray of play._build_hud for n slots (duel row: the rival card takes the right 258 px)
static func _rebuild_tray(p, ns: int) -> void:
	var old: Control = p.tray_box
	var W: float = p.W
	var gap: = 10.0
	var tray_room: = W - 12 - 258.0
	var sw: = minf(108.0, (tray_room - 28 - (ns - 1) * gap) / ns)
	var tw: = ns * sw + (ns - 1) * gap + 28
	var tb: RBox = UI.rbox("plum", Rect2(12 + (tray_room - tw) * 0.5, 172, tw, 128), 28, 4, 12)
	V6HudStyle.tray(tb, V7Album.table_for(String(p.cfg.get("bg", ""))))
	p.add_child(tb)
	if old and is_instance_valid(old):
		p.move_child(tb, old.get_index())
		old.queue_free()
	p.tray_box = tb
	p.slot_rects.clear()
	for i in ns:
		var r: = Rect2(14 + i * (sw + gap), 10, sw, 108)
		var sl: = UI.rbox("plum", r, 18, 2, 4)
		V6HudStyle.slot(sl, i)
		tb.add_child(sl)
		p.slot_rects.append(Rect2(tb.position + r.position, r.size))


# the intro ribbon was drawn from the old cfg: give it the duel's name and goal
static func _retitle(p, old_cfg: Dictionary) -> void:
	var rib: Node = p.get_node_or_null("V8LevelRibbon")
	if rib == null:
		return
	var swap: = {String(old_cfg.get("name", "")): String(p.cfg.name), String(old_cfg.get("goal", "")): String(p.cfg.goal)}
	for n in rib.find_children("*", "Label", true, false):
		var l: Label = n
		if swap.has(l.text):
			l.text = swap[l.text]
