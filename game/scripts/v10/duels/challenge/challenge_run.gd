class_name V10ChallengeRun
extends Control

# «Вызов по коду»: the run node on the play screen (play.args.challenge). It draws the pace strip «автор · 1:42»
# with the author's ghost marker, and at the end opens the result sheet «Ты против <ник>: −3,0 с» with
# «Реванш» / «Ещё раз». The result and the reward (+5 crystals for beating the author of someone else's code,
# at most 3 a day, never for the player's own code) go through V10ChallengeState.finish().
#
# play.gd hooks (challenge_play.gd carries them until the integrator moves them into play.gd, README §Хуки):
#   build():      elif args.has("challenge"): mode = "challenge"; cfg = V10ChallengeRun.play_cfg(args.challenge).cfg
#                 … at the end: if mode == "challenge": V10ChallengeRun.attach(self, args.challenge)
#   _on_clear():  if mode == "challenge": … V10ChallengeRun.of(self).on_clear(secs, stars); return
#   _on_fail():   if mode == "challenge": fails += 1; … V10ChallengeRun.of(self).on_fail(); return
#
#   play_cfg(ch) -> {ok, err_text, cfg, deal}     attach(play, ch) -> V10ChallengeRun     of(play)
#   ctx_from_play(play, secs, stars) -> ctx       (the win screen's «⋯ → Вызов»; V10ChallengeScreen.open_throw)
#   pace(elapsed, pairs_done, pairs_total, author_secs) -> {me, ghost, ahead}

signal finished(res: Dictionary)

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")
const C: = preload("res://scripts/v10/duels/challenge/challenge_code.gd")
const D: = preload("res://scripts/v10/duels/challenge/challenge_deal.gd")
const ST: = preload("res://scripts/v10/duels/challenge/challenge_state.gd")
const UI2: = preload("res://scripts/v10/duels/challenge/challenge_ui.gd")

const STRIP_LEGACY: = Rect2(14, 124, 436, 46)  # the crystal pill of the 0.9 HUD (no currency in a match)
const STRIP_HUD2_DY: = 70.0  # under the hud2 top bar

var play
var ch: = {}
var deal: = {}
var author_secs: = 1.0
var pairs_total: = 1
var pairs_done: = 0
var result: = {}
var strip: _Strip
var _rescue_used: = false

# ---------------------------------------------------------------- setup

static func play_cfg(c: Dictionary) -> Dictionary:
	var p: = {"mode": int(c.get("mode", 0)), "gen": int(c.get("gen", -1)), "key": int(c.get("key", 0))}
	var r: = D.resolve(p)
	if not r.ok:
		return {"ok": false, "err_text": String(r.err_text), "cfg": {}, "deal": r}
	var cfg: Dictionary = (r.cfg as Dictionary).duplicate(true)
	cfg.name = "Вызов · %s" % String(r.table)
	cfg.reward = {"gems": 0}
	var who: = String(c.get("nick", ""))
	cfg.goal = "Быстрее %s: %s" % [("автора" if who == "" else who), U.fmt_time(int(c.get("tenths", 0)))]
	cfg.intro = "Тот же стол, что у автора. Время пошло с первой фишки."
	cfg.erase("boss")
	return {"ok": true, "err_text": "", "cfg": cfg, "deal": r}


static func attach(p, c: Dictionary) -> V10ChallengeRun:
	var old = of(p)
	if old:
		old.queue_free()
	var n: = V10ChallengeRun.new()
	n.name = "V10ChallengeRun"
	n.play = p
	n.ch = c.duplicate(true)
	p.add_child(n)
	n._setup()
	return n


static func of(p) -> V10ChallengeRun:
	if p == null or not is_instance_valid(p):
		return null
	return p.get_node_or_null("V10ChallengeRun") as V10ChallengeRun


# the author's side: a finished table → the ctx of the «Бросить вызов» sheet ({ok:false, err_text} when this table
# cannot be a challenge: tutorial, blitz, a journey board reshaped by blessings…)
static func ctx_from_play(p, secs: float, stars: int) -> Dictionary:
	var pl: = D.payload_from_play(p)
	if not pl.ok:
		return {"ok": false, "err_text": String(pl.err_text)}
	var pay: = {"mode": int(pl.mode), "gen": int(pl.gen), "key": int(pl.key),
		"tenths": clampi(roundi(secs * 10.0), 1, C.TIME_MAX), "stars": clampi(stars, 1, 3)}
	var r: = D.resolve({"mode": pay.mode, "gen": pay.gen, "key": pay.key})
	if not r.ok:
		return {"ok": false, "err_text": String(r.err_text)}
	var hero: = String(p.get("partner"))
	var outfit: = ""
	var gg: = U.g()
	if gg and gg.has_method("equipped"):
		outfit = String(gg.call("equipped", hero))
	return {"ok": true, "p": pay, "deal": r, "hero": hero, "outfit": outfit, "nick": U.my_nick()}


# where the player and the author's ghost are on the strip (0…1); the ghost walks the author's average pace
static func pace(elapsed: float, done: int, total: int, a_secs: float) -> Dictionary:
	var me: = clampf(float(done) / maxf(1.0, float(total)), 0.0, 1.0)
	var ghost: = clampf(elapsed / maxf(0.1, a_secs), 0.0, 1.0)
	return {"me": me, "ghost": ghost, "ahead": me >= ghost}


func _setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	author_secs = maxf(0.1, int(ch.get("tenths", 10)) / 10.0)
	var r: = play_cfg(ch)
	deal = r.deal if r.ok else {}
	var b = play.get("board")
	pairs_total = maxi(1, int(b.tiles.size()) / 2) if b else maxi(1, int(deal.get("pairs", 1)))
	if b:
		b.matched.connect(func(_m, _c, _g, _s): pairs_done += 1)
	z_index = 60
	position = Vector2.ZERO
	size = Vector2(play.size)
	strip = _Strip.new()
	strip.run = self
	strip.name = "PaceStrip"
	var r2: = strip_rect()
	strip.position = r2.position
	strip.size = r2.size
	add_child(strip)
	_hide_currency()
	U.silk_in(strip, Vector2(0, -8), 0.22, 1.2)
	ST.record_taken(ch, {"title": String(ch.get("title", deal.get("table", "")))})


func strip_rect() -> Rect2:
	if play.has_node("V10HudMatch"):
		var vs: Vector2 = play.size
		var cx: = UI2.col_x(vs)
		var T: = float(V10Hud2Util.safe_insets(vs).top)
		return Rect2(cx + 104, T + STRIP_HUD2_DY, 496, 46)
	return STRIP_LEGACY


# no currency in a match (UX §6.6): the 0.9 crystal pill gives its place to the strip
func _hide_currency() -> void:
	var gl = play.get("gems_lbl")
	if gl is Label and is_instance_valid(gl) and (gl as Label).get_parent() is Control:
		((gl as Label).get_parent() as Control).visible = false


func elapsed() -> float:
	var st: = float(play.get("start_t"))
	if st <= 0.0:
		return 0.0
	if not result.is_empty():
		return float(result.get("my_t", 0)) / 10.0
	return maxf(0.0, float(play.call("now")) - st)


func _process(_dt: float) -> void:
	if strip:
		strip.queue_redraw()
		strip.refresh()

# ---------------------------------------------------------------- the end

func on_clear(secs: float, stars: int) -> Dictionary:
	var my_t: = clampi(roundi(secs * 10.0), 1, C.TIME_MAX)
	result = ST.finish(ch, my_t, stars)
	result.nick = String(ch.get("nick", ""))
	result.own = ST.is_own(String(ch.get("core", "")))
	U.music("sting", ["sting_victory" if result.won else "sting_defeat"])
	show_result()
	finished.emit(result)
	return result


func title_text(res: Dictionary) -> String:
	var who: = "себя" if bool(res.get("own", false)) else (String(res.get("nick", "")) if String(res.get("nick", "")) != "" else "автора")
	return "Ты против %s: %s" % [who, U.fmt_delta(int(res.delta))]


func verdict_text(res: Dictionary) -> String:
	if res.won:
		return "Победа: быстрее и не меньше звёзд"
	if int(res.my_t) < int(res.author_t):
		return "Быстрее, но звёзд меньше: помощь стоит звезду"
	if int(res.my_t) == int(res.author_t):
		return "Ничья по времени: нужно быстрее хотя бы на 0,1 с"
	return "Не хватило %s" % U.fmt_delta(int(res.delta)).substr(1)


func show_result() -> UI2.Sheet:
	var res: = result
	var s: = UI2.Sheet.open(play, "", {"tap_out": false, "close_btn": true, "dim": 0.5})
	s.name = "ResultSheet"
	s.on_close = func(): _to_list()
	var y: = 36.0
	var t: = UI2.text(title_text(res), "display", 32, V10DS.PAPER_100, UI2.W - 2 * UI2.M - 88)
	t.name = "ResultTitle"
	t.position = Vector2(UI2.M, y)
	s.body.add_child(t)
	y += 56
	var v: = UI2.text(verdict_text(res), "ui", 22, V10DS.JADE_300 if res.won else V10DS.PAPER_300, UI2.W - 2 * UI2.M)
	v.position = Vector2(UI2.M, y)
	s.body.add_child(v)
	y += 48
	var who: = "Автор" if String(res.get("nick", "")) == "" or bool(res.get("own", false)) else String(res.nick)
	for row in [["Ты", int(res.my_t), int(res.my_stars), res.won], [who, int(res.author_t), int(res.author_stars), not res.won]]:
		var plate: = UI2.Plate.new(V10DS.NIGHT_700 if row[3] else V10DS.NIGHT_800)
		plate.position = Vector2(UI2.M, y)
		plate.size = Vector2(UI2.W - 2 * UI2.M, 72)
		if row[3]:
			plate.accent = V10DS.JADE_300 if row[0] == "Ты" else V10DS.GOLD_500
		s.body.add_child(plate)
		var nl: = UI2.text(String(row[0]), "ui", 22, V10DS.PAPER_100, 260)
		nl.position = Vector2(24, 20)
		plate.add_child(nl)
		var tl: = UI2.text(U.fmt_time_full(int(row[1])), "num", 32, V10DS.PAPER_100, 190)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl.position = Vector2(plate.size.x - 24 - 124 - 16 - 190, 16)
		plate.add_child(tl)
		var stv: = UI2.Stars.new(int(row[2]), 3, 18.0)
		stv.position = Vector2(plate.size.x - 24 - 124, 18)
		plate.add_child(stv)
		y += 80
	y += 8
	var rw: Dictionary = res.get("reward", {})
	if int(rw.get("gems", 0)) > 0:
		var gl: = UI2.text("+%s за победу над автором" % U.gems_text(int(rw.gems)), "ui", 22, V10DS.GOLD_300, UI2.W - 2 * UI2.M - 56)
		gl.name = "RewardLine"
		var ic: = TextureRect.new()
		ic.texture = V8Art.cur("gem")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(40, 40)
		ic.position = Vector2(UI2.M, y - 4)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.body.add_child(ic)
		gl.position = Vector2(UI2.M + 52, y)
		s.body.add_child(gl)
		U.silk_in(gl, Vector2(0, 8), 0.24, 0.3)
		U.silk_in(ic, Vector2(0, 8), 0.24, 0.3)
		U.sfx("gem_fly")
		y += 48
	elif res.won and String(res.reason) != "":
		var nl2: = UI2.text(String(ST.REASON_TEXT.get(res.reason, "")), "ui", 18, V10DS.PAPER_500, UI2.W - 2 * UI2.M, 2)
		nl2.name = "ReasonLine"
		nl2.position = Vector2(UI2.M, y)
		s.body.add_child(nl2)
		y += 52
	y += 32
	var b1: V10Button
	var b2: V10Button
	if res.won:
		b1 = UI2.btn("play", "Реванш", Vector2(560, 104), revenge)
		b1.overline = "Ответный вызов автору"
		b2 = UI2.btn("secondary", "Ещё раз", Vector2(560, 80), retry)
	else:
		b1 = UI2.btn("play", "Ещё раз", Vector2(560, 104), retry)
		b2 = UI2.btn("secondary", "К вызовам", Vector2(560, 80), func(): s.close())
	b1.position = Vector2((UI2.W - 560) * 0.5, y)
	s.body.add_child(b1)
	b2.position = Vector2((UI2.W - 560) * 0.5, y + 104 + 8)
	s.body.add_child(b2)
	s.finish(y + 104 + 8 + 80 + 24)
	return s


# «Реванш» after a win: the player's own time on the same table goes back as a new code («Бросить вызов»)
func revenge() -> void:
	var p: = {"mode": int(ch.mode), "gen": int(ch.gen), "key": int(ch.key), "tenths": int(result.my_t), "stars": int(result.my_stars)}
	var hero: = String(play.get("partner"))
	var gg: = U.g()
	var ctx: = {"p": p, "deal": deal, "hero": hero, "outfit": String(gg.call("equipped", hero)) if gg and gg.has_method("equipped") else "",
		"nick": U.my_nick()}
	var cur: = UI2.Sheet.current
	if cur:
		cur.on_close = Callable()
	var s: = V10ChallengeScreen.open_throw(play, ctx)
	if s:
		s.on_close = func(): _to_list()


func retry() -> void:
	var m = play.get("main")
	var cur: = UI2.Sheet.current
	if cur:
		cur.on_close = Callable()
		cur.close(true)
	var a: Dictionary = (play.get("args0") as Dictionary).duplicate(true)
	a["retry"] = randi()
	if m:
		U.go_play(m, a)


func _to_list() -> void:
	var m = play.get("main") if is_instance_valid(play) else null
	if m:
		U.go_challenge(m, {})


# the tray overflowed: one free «Вернуть 3 фишки» (a help: the table counts for one star at most after an
# overflow), else «Ещё раз». Nothing is sold here.
func on_fail() -> UI2.Sheet:
	var s: = UI2.Sheet.open(play, "Лоток полон", {"tap_out": false, "close_btn": false, "dim": 0.5})
	s.name = "FailSheet"
	var y: = 96.0
	var cap: = UI2.text("После полного лотка стол — не больше одной звезды. Время идёт.", "ui", 22, V10DS.PAPER_300, UI2.W - 2 * UI2.M, 2)
	cap.position = Vector2(UI2.M, y)
	s.body.add_child(cap)
	y += 96
	var b1: V10Button
	var b2: V10Button
	if not _rescue_used:
		b1 = UI2.btn("play", "Вернуть 3 фишки", Vector2(560, 104), func():
			_rescue_used = true
			s.close()
			play.call("ch_rescue"))
		b2 = UI2.btn("secondary", "Ещё раз", Vector2(560, 80), retry)
	else:
		b1 = UI2.btn("play", "Ещё раз", Vector2(560, 104), retry)
		b2 = UI2.btn("secondary", "К вызовам", Vector2(560, 80), func():
			s.close()
			_to_list())
	b1.breathing = false
	b1.position = Vector2((UI2.W - 560) * 0.5, y)
	s.body.add_child(b1)
	b2.position = Vector2((UI2.W - 560) * 0.5, y + 112)
	s.body.add_child(b2)
	s.finish(y + 112 + 80 + 24)
	return s

# ---------------------------------------------------------------- the pace strip

class _Strip:
	extends Control
	var run: V10ChallengeRun
	var cap: Label
	var me_l: Label
	var _was_ahead: = true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap = V10Type.label("", "ui", 18, V10DS.PAPER_300)
		cap.position = Vector2(14, 2)
		cap.size = Vector2(size.x - 120, 24)
		add_child(cap)
		me_l = V10Type.label("0:00", "num", 22, V10DS.PAPER_100)
		me_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		me_l.position = Vector2(size.x - 104, 0)
		me_l.size = Vector2(90, 26)
		add_child(me_l)
		refresh()

	func refresh() -> void:
		if run == null or cap == null:
			return
		var who: = String(run.ch.get("nick", ""))
		cap.text = "%s · %s" % [who if who != "" else "автор", U.fmt_time(int(run.ch.get("tenths", 0)))]
		var e: = run.elapsed()
		me_l.text = U.fmt_time(int(e * 10.0))
		var over: = e > run.author_secs
		me_l.label_settings = V10Type.settings("num", 22, V10DS.EMBER if over else V10DS.PAPER_100)

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(V10DS.NIGHT_900, 0.78)
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if run == null:
			return
		var pc: = V10ChallengeRun.pace(run.elapsed(), run.pairs_done, run.pairs_total, run.author_secs)
		var x0: = 16.0
		var x1: = size.x - 16.0
		var ty: = size.y - 11.0
		draw_line(Vector2(x0, ty), Vector2(x1, ty), V10DS.NIGHT_600, 4.0, true)
		var mx: = lerpf(x0, x1, float(pc.me))
		var gx: = lerpf(x0, x1, float(pc.ghost))
		draw_line(Vector2(x0, ty), Vector2(mx, ty), V10DS.JADE_300 if pc.ahead else V10DS.PAPER_300, 4.0, true)
		# the author's ghost: a gold ring; the player: a filled dot
		draw_arc(Vector2(gx, ty), 7.0, 0.0, TAU, 24, V10DS.GOLD_300, 2.0, true)
		draw_circle(Vector2(mx, ty), 6.0, V10DS.JADE_300 if pc.ahead else V10DS.PAPER_100, true, -1.0, true)
