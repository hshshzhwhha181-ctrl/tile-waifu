class_name V6Duel
extends Node





var play
var board: TrayBoard
var rival: = "rin"
var rv: Dictionary
var stage: V6HeroStage
var me: = 0
var her: = 0
var steals: = 0
var t_next: = 0.0
var pace: = 6.0
var target: Array = []
var marks: Array = []
var gauge: = 0
var sprint_until: = -1.0
var finished: = false
var started: = false
var casting: = false
var taunt_cd: = 0.0
var panel: RBox
var score_me: Label
var score_her: Label
var bar_fill: RBox
var bar_w: = 100.0
var her_gauge: RBox
var her_gauge_w: = 100.0
var _auto: = "--v6duel_auto=1" in OS.get_cmdline_user_args()
var _auto_t: = 1.0
var _auto_gap: = 0.55

func _ready() -> void :
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--v6duel_tap="):
			_auto_gap = float(a.substr(13))

func setup(p, rival_id: String) -> void :
	play = p
	board = p.board
	rival = rival_id if V6Heroines.RIVALS.has(rival_id) else "rin"
	rv = V6Heroines.RIVALS[rival]
	pace = V6Heroines.rival_pace(rival)
	p.riichi_offered = true
	var W: float = p.W
	stage = V6HeroStage.new().setup(rival, Rect2(W - 250, 66, 242, 240), {"tag": "соперница · побед %d" % V6Heroines.duel_wins(rival)})
	stage.gauge_lbl.text = ""
	p.add_child(stage)
	stage.pressed.connect( func():
		stage.react("smug")
		stage.say_text(V6Heroines.line(rival, "lead" if her >= me else "behind")))
	_build_panel(W)
	p.move_child(p.stage, -1)
	t_next = pace + 1.0
	_update_score()

func _build_panel(W: float) -> void :
	panel = UI.rbox("cream", Rect2(92, 16, W - 92 - 258, 104), 26, 4, 12)
	panel.borders(Color("ffe7a6"), Color("c58a2c"))
	play.add_child(panel)
	var pw: = panel.size.x
	var pc: Color = G.HEROES[play.partner].color
	var rc: Color = G.HEROES[rival].color
	var l1: = UI.label("ТЫ", 13, Color("cbb5dc"), Color(0.1, 0.05, 0.2), 2, "body", 900)
	l1.position = Vector2(108, 6)
	panel.add_child(l1)
	score_me = UI.label("0", 40, Color.WHITE, Color(0.1, 0.05, 0.2), 5, "title", 900)
	score_me.position = Vector2(106, 16)
	score_me.size = Vector2(80, 50)
	score_me.pivot_offset = Vector2(20, 25)
	panel.add_child(score_me)
	var vs: = UI.label("пары", 13, Color("cbb5dc"), Color(0.1, 0.05, 0.2), 2, "body", 900)
	vs.position = Vector2(pw * 0.5 + 30, 30)
	panel.add_child(vs)
	var l2: = UI.label(G.HEROES[rival].name.to_upper(), 13, rc.lightened(0.3), Color(0.1, 0.05, 0.2), 2, "body", 900)
	l2.position = Vector2(pw - 150, 6)
	l2.size = Vector2(136, 20)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(l2)
	score_her = UI.label("0", 40, rc.lightened(0.45), Color(0.1, 0.05, 0.2), 5, "title", 900)
	score_her.position = Vector2(pw - 94, 16)
	score_her.size = Vector2(80, 50)
	score_her.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_her.pivot_offset = Vector2(60, 25)
	panel.add_child(score_her)

	var bb: = UI.rbox("plum", Rect2(106, 72, pw - 120, 16), 8, 1, 2)
	bb.colors(rc.darkened(0.15), rc.darkened(0.45)).set_param("shadow_color", Color(0, 0, 0, 0))
	panel.add_child(bb)
	bar_w = bb.size.x - 4
	bar_fill = UI.rbox("gold", Rect2(2, 2, bar_w * 0.5, 12), 6, 0, 1)
	bar_fill.colors(pc.lightened(0.35), pc).set_param("shadow_color", Color(0, 0, 0, 0))
	bb.add_child(bar_fill)

	var gl: = UI.label(rv.skill_name, 12, Color("ffd98a"), Color(0.1, 0.05, 0.2), 2, "body", 900)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.gauge.get_parent().add_child(gl)
	gl.position = Vector2(0, -3)
	gl.size = stage.gauge.get_parent().size
	her_gauge = stage.gauge
	her_gauge_w = stage.gauge_w

func _update_score() -> void :
	score_me.text = str(me)
	score_her.text = str(her)
	var tot: = me + her
	var f: = 0.5 if tot == 0 else clampf(float(me) / tot, 0.06, 0.94)
	bar_fill.create_tween().tween_property(bar_fill, "size:x", bar_w * f, 0.3).set_trans(Tween.TRANS_QUAD)
	her_gauge.create_tween().tween_property(her_gauge, "size:x", maxf(8.0, her_gauge_w * float(gauge) / V6Heroines.RIVAL_SKILL_NEED), 0.25)

func _process(dt: float) -> void :
	if finished or board == null or not is_instance_valid(board):
		return
	taunt_cd -= dt
	if not board.input_on or casting or play.get_meta("v6_casting", false):
		return
	if _auto:
		_auto_t -= dt
		if _auto_t <= 0.0:
			_auto_t = _auto_gap
			var mv: = board.solver_move()
			if mv:
				board.tap(mv)
	if not started:
		started = true
		stage.say_text(V6Heroines.line(rival, "start"), 2.8)
	t_next -= dt * (2.2 if G.time < sprint_until else 1.0)
	if target.is_empty():
		if t_next <= V6Heroines.TELEGRAPH:
			_pick()
		return
	var a: Tile = target[0]
	var b: Tile = target[1]
	if not (board.on_board(a) and board.on_board(b)) or a.pending or b.pending:
		_stolen(a if not board.on_board(a) else b)
	elif t_next <= 0.0:
		_take([a, b], true)


func _candidates() -> Array:
	var by: = {}
	for t in board.free_tiles():
		if t.pending or t.ice > 0 or t.secret or t.shard != "":
			continue
		by[t.face] = by.get(t.face, []) + [t]
	var held: = {}
	for t in board.tray:
		held[t.face] = true
	var out: = []
	var soft: = []
	for f in by:
		var arr: Array = by[f]
		if arr.size() < 2:
			continue
		var pair: = [arr[0], arr[1]]
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				if arr[i].step == arr[j].step:
					pair = [arr[i], arr[j]]
		if held.has(f):
			soft.append(pair)
		else:
			out.append(pair)
	if out.is_empty() or randf() < 0.25:
		out.append_array(soft)
	out.shuffle()
	return out

func _pick() -> void :
	var c: = _candidates()
	if c.is_empty():
		t_next = 1.2 + V6Heroines.TELEGRAPH
		if taunt_cd <= 0.0 and randf() < 0.3:
			stage.emote("dots")
			taunt_cd = 4.0
		return
	target = c[0]
	t_next = V6Heroines.TELEGRAPH
	for t in target:
		_mark(t)
	stage.react("match")
	Sfx.play("select", 0.75, -8)

func _mark(t: Tile) -> void :
	var col: Color = G.HEROES[rival].color
	var g: = Sprite2D.new()
	g.texture = G.fx("tile_glow")
	g.material = Fx.add_mat()
	g.scale = Vector2(Tile.S, Tile.S) * 1.12
	g.modulate = Color(col.r, col.g, col.b, 0.0)
	g.z_index = 1
	t.add_child(g)
	var r: = Sprite2D.new()
	r.texture = G.fx("ring")
	r.material = Fx.add_mat()
	r.modulate = col.lightened(0.3)
	r.scale = Vector2(0.9, 0.9)
	r.z_index = 2
	t.add_child(r)
	var tw: = g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 1.0, 0.25)
	tw.tween_property(g, "modulate:a", 0.45, 0.25)
	var rt: = r.create_tween()
	rt.tween_property(r, "scale", Vector2(0.35, 0.35), V6Heroines.TELEGRAPH).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	marks.append(g)
	marks.append(r)

func _clear_marks() -> void :
	for m in marks:
		if is_instance_valid(m):
			m.queue_free()
	marks.clear()

func _stolen(at: Tile) -> void :
	_clear_marks()
	target = []
	steals += 1
	t_next = pace * 0.75
	stage.react("anger")
	if taunt_cd <= 0.0:
		taunt_cd = 3.0
		stage.say_text(V6Heroines.line(rival, "steal"))
	Fx.float_text(play.fx_layer, V6Skills._pos(at) + Vector2(0, -60), "Перехват!", Color("9fe8d0"), 32)


func _take(pair: Array, talk: bool) -> void :
	_clear_marks()
	target = []
	var booth: = stage.get_global_transform_with_canvas() * Vector2(stage.size.x * 0.5, stage.size.y * 0.45)
	var mid: = (V6Skills._pos(pair[0]) + V6Skills._pos(pair[1])) * 0.5
	for t in pair:
		t.alive = false
		t.kill_move()
		t.hint(false)
		t.z_index = 150
		var to: Vector2 = t.get_parent().get_global_transform_with_canvas().affine_inverse() * booth
		var from: Vector2 = t.position
		var ctrl: = from.lerp(to, 0.5) + Vector2(0, -120)
		var s0: float = t.scale.x
		var tw: Tween = t.create_tween()
		tw.tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 0.8, 0.12)
		tw.tween_method( func(v: float):
			t.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v)
			t.scale = Vector2.ONE * lerpf(s0, 0.35, v), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "modulate:a", 0.0, 0.08)
		tw.tween_callback(t.hide)
	her += 1
	gauge += 1
	board.reveal_free()
	board.tray_changed.emit()
	var col: Color = G.HEROES[rival].color
	Fx.burst(play.fx_layer, mid, "sparkle", 18, col.lightened(0.3), 1.0)
	Sfx.play("match0", 0.85)
	Sfx.play("clack0", 1.0, -4)
	t_next = pace * randf_range(0.85, 1.15)
	get_tree().create_timer(0.5).timeout.connect( func():
		if finished:
			return
		stage.react("smug")
		UI.punch(score_her, 0.35)
		_update_score())
	if talk and taunt_cd <= 0.0 and randf() < 0.45:
		taunt_cd = 4.0
		stage.say_text(V6Heroines.line(rival, "take" if her - me < 3 else "lead"))
	board._check_clear()
	if gauge >= V6Heroines.RIVAL_SKILL_NEED:
		gauge = 0
		await get_tree().create_timer(0.7).timeout
		if not finished and is_inside_tree():
			_skill()

func _skill() -> void :
	casting = true
	var kind: String = rv.skill
	var pairs: Array = []
	var targets: Array = []
	var veil: Array = []
	match kind:
		"double":
			var c: = _candidates()
			pairs = c.slice(0, 2)
			for p in pairs:
				targets.append(V6Skills._pos(p[0]))
				targets.append(V6Skills._pos(p[1]))
		"veil":
			var fr: = board.free_tiles().filter( func(t): return not t.pending and not t.secret)
			fr.shuffle()
			veil = fr.slice(0, 4)
			for t in veil:
				targets.append(V6Skills._pos(t))
	stage.say_text(V6Heroines.line(rival, "skill"), 2.2)
	await stage.cast(rv.skill_name, targets, rv.skill_desc)
	casting = false
	if finished or not is_inside_tree():
		return
	match kind:
		"double":
			for p in pairs:
				if board.on_board(p[0]) and board.on_board(p[1]) and not p[0].pending and not p[1].pending:
					await _take(p, false)
					await get_tree().create_timer(0.2).timeout
		"sprint":
			sprint_until = G.time + 7.0
			t_next = minf(t_next, 1.0)
			Fx.float_text(play.fx_layer, stage.position + Vector2(stage.size.x * 0.5, stage.size.y + 30), "Спринт ×2", G.HEROES[rival].color.lightened(0.4), 30)
		"veil":
			for t in veil:
				if is_instance_valid(t) and board.on_board(t):
					_veil(t)
	_update_score()


func _veil(t: Tile) -> void :
	var v: = Node2D.new()
	v.z_index = 3
	t.add_child(v)
	var m: = Sprite2D.new()
	m.texture = G.fx("tile_mask")
	m.scale = Vector2(Tile.S, Tile.S) * 0.96
	m.modulate = Color(0.32, 0.26, 0.55)
	v.add_child(m)
	var moon: = Sprite2D.new()
	moon.texture = G.fx("sparkle")
	moon.material = Fx.add_mat()
	moon.scale = Vector2(0.4, 0.4)
	moon.modulate = Color("e6dcff")
	v.add_child(moon)
	v.modulate.a = 0.0
	var tw: = v.create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_property(v, "modulate:a", 0.0, 0.35)
	tw.tween_callback(v.queue_free)


func on_player_pair(_mid: Vector2) -> void :
	if finished:
		return
	me += 1
	UI.punch(score_me, 0.3)
	_update_score()
	if taunt_cd <= 0.0 and me - her == 3:
		taunt_cd = 5.0
		stage.react("deny")
		stage.say_text(V6Heroines.line(rival, "behind"))

func on_overflow() -> void :
	her += 1
	stage.react("smug")
	Fx.float_text(play.fx_layer, Vector2(play.W * 0.5, 330), "Лоток полон: пара сопернице", Color("ff8a9a"), 30)
	_update_score()

func finish() -> void :
	if finished:
		return
	finished = true
	_clear_marks()
	board.input_on = false
	var win: = me > her
	var draw: = me == her
	var d: = V6Heroines.save_data()
	var gems: = 60 if win else (30 if draw else 15)
	var shard: = false
	if win:
		if V6Heroines.duel_wins(rival) == 0:
			gems += 100
		d.duel_wins[rival] = V6Heroines.duel_wins(rival) + 1
		if not G.hero_unlocked(rival) and String(d.duel_day.get(rival, "")) != G.today():
			d.duel_day[rival] = G.today()
			G.S.shards[rival] = int(G.S.shards.get(rival, 0)) + 1
			shard = true
	G.S.gems += gems
	G.add_aff(rival, 20 if win else (10 if draw else 5))
	G.add_aff(play.partner, 10)
	G.add_pass_xp(60)
	G.save()
	stage.react("deny" if win else "win")
	stage.say_text(V6Heroines.line(rival, "lose" if win else "win"), 3.0)
	play.stage.react("win" if win else "fail")
	Sfx.play("win" if win or draw else "deny", 1.0 if win else 0.8)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	_result(win, draw, gems, shard)

func _result(win: bool, draw: bool, gems: int, shard: bool) -> void :
	var main = play.main
	var title: = "Победа!" if win else ("Ничья" if draw else "Победа за ней")
	var p: = Common.popup(main, title, 560, "cream", 660.0, false)
	if win:
		Fx.burst(p, Vector2(330, 80), "confetti", 60, Color.WHITE, 1.1)
	var rc: Color = G.HEROES[rival].color
	p.add_child(Common.avatar(play.partner, Rect2(60, 70, 130, 130), "gold" if win else "pink"))
	p.add_child(Common.avatar(rival, Rect2(470, 70, 130, 130), "pink" if win else "gold"))
	p.add_child(UI.center_label(UI.title("%d : %d" % [me, her], 64, Color("ffe7a6"), Color("5a1a6a")), Rect2(190, 90, 280, 90)))
	var q: = UI.label("«%s»" % V6Heroines.line(rival, "lose" if win else "win"), 20, rc.lightened(0.5), Color(0.1, 0.05, 0.2), 3, "body", 800)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.position = Vector2(40, 214)
	q.size = Vector2(580, 56)
	p.add_child(q)
	var rew: = "+%d кристаллов · ♥ %s" % [gems, G.HEROES[rival].name]
	if steals > 0:
		rew += " · перехватов: %d" % steals
	p.add_child(UI.center_label(UI.label(rew, 21, UI.INK), Rect2(0, 278, 660, 30)))
	if shard:
		var have: = mini(int(G.S.shards.get(rival, 0)), G.SHARDS_NEED)
		Common.chip(p, null, "Осколок %s: %d/%d%s" % [G.HEROES[rival].name, have, G.SHARDS_NEED, " · она с тобой!" if have >= G.SHARDS_NEED else ""], Rect2(60, 318, 540, 36), "gold", 18)
	var again: = JButton.make("Реванш", "pink", Rect2(40, 380, 280, 92), null, 30)
	again.shine_every = 2.0
	again.pressed.connect( func(): main.go("play", {"mode": "duel", "rival": rival, "partner": play.partner, "retry": randi()}))
	p.add_child(again)
	var back: = JButton.make("Режимы", "glass", Rect2(340, 380, 280, 92), null, 28)
	back.pressed.connect( func(): main.go("modes" if main.SCREENS.has("modes") else "home"))
	p.add_child(back)
	play.set_meta("v6_duel_result", {"win": win, "me": me, "her": her})
	print("DUEL %s %d:%d" % ["WIN" if win else ("DRAW" if draw else "LOSE"), me, her])
