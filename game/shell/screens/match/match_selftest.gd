class_name TWResultSelftest
extends RefCounted

# P33 / WP10c selftest of the victory screen (TWResultChain + TWResultModal + the hook in TWMatchScreen):
#   godot --path game res://shell/screens/match/match_selftest.tscn      prints "TWRESULT_SELFTEST ok/total" (renders: tools/tw_test.py runs it under xvfb)
#   A plan       milestones (first win, chapter boss, first 3-star of a chapter, every 10th win), the kind (fast / chain / none), FTUE = the
#                truncated chain, a 400-facts property run
#   B timeline   fast: 120 ms of silence, a star every 120 ms, button at <= 3.0 s, the short sting only; chain: 3 panels, 400 ms of silence, the
#                9.3 s sting, the one Confirm at <= 20 s; cues in order
#   C run        the state machine: first tap settles the panel, the second goes on, Skip, the sting is cut by a tap, 500 random tap sequences
#                (the button is always reachable in time, time never goes back, every cue at most once)
#   D modal      real nodes on a ModalStack: the primary / secondary / Skip rects are THE SAME in every frame and in both shapes, hit >= 96 px,
#                one primary button, <= 2 secondaries, Skip always visible in the chain, close / back / clear_all (on_close once), 0 banned words
#   E real time  the fast path in real frames: «Поле чисто» to the button <= 3.0 s by the wall clock; a tap settles it
#   F render     720 x 1280 pixels: the button is on the screen and is not the scrim colour; every state is drawn
#   G screen     a solver game through TWMatchScreen on a ModalStack opens the modal once, pays the wallet once, `next` / `map` come out
#   H lint       no «осталось» / sale / interstitial words in the victory code and in everything the modal showed

const FRAME: = 1.0 / 60.0
const BANNED: = ["остал", "сегодня", "лимит", "купи", "купить", "скидк", "акци", "магазин", "рекл", "₽", "до конца"]
const BANNED_CODE: = ["interstitial", "show_ad", "rewarded", "shop", "store", "purchase", "iap", "daily_left", "left_today", "remaining"]
const SIZES: = [Vector2(720, 1280), Vector2(720, 1600), Vector2(1536, 2048)]

var checks: = 0
var fails: = 0
var _host: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWRESULT FAIL: ", what)


func note(s: String) -> void:
	print("TWRESULT ", s)


func run(host: Node) -> Array:
	_host = host
	TWAssets.quiet = true
	TWDraw.sim_insets = {"top": 0, "bottom": 0}
	_plan()
	_timeline()
	_run_machine()
	await _modal()
	await _real_time()
	await _render()
	await _screen()
	_lint()
	TWDraw.sim_insets = {}
	print("TWRESULT_SELFTEST %d/%d" % [checks - fails, checks])
	return [checks - fails, checks]


# a won TWRoundResult with n currencies of rewards
static func make_result(stars: int = 3, rows: int = 2, bond: int = 10, xp: int = 100, win: bool = true) -> TWRoundResult:
	var r: = TWRoundResult.new()
	r.mode = ""
	r.win = win
	r.outcome = "win" if win else "lose"
	r.stars = stars if win else 0
	var curs: = ["gems", "coins", "tickets", "petals"]
	for i in rows:
		r.grant(String(curs[i % 4]), 20 + 10 * i, "play")
	if bond > 0:
		r.bond.append({"hero": "rin", "n": bond, "src": "level_win"})
	r.pass_xp = xp
	r.xp = 40
	r.reward = 60
	return r


# ------------------------------------------------------------------ A plan

func _plan() -> void:
	var r: = make_result()
	ok(TWResultChain.milestones(r, {"wins_before": 5}).is_empty(), "an ordinary win (5 wins before) has no milestone")
	ok(TWResultChain.milestones(r, {}).is_empty(), "no history at all is not a milestone")
	ok(TWResultChain.milestones(r, {"wins_before": 0}) == [TWResultChain.M_FIRST_WIN], "the first win of a life")
	ok(TWResultChain.milestones(r, {"wins_before": 5, "is_boss": true}) == [TWResultChain.M_BOSS], "a chapter boss")
	ok(TWResultChain.milestones(r, {"wins_before": 5, "chapter_has_3star": false}) == [TWResultChain.M_FIRST_3STAR], "the first 3-star of a chapter")
	ok(TWResultChain.milestones(make_result(2), {"wins_before": 5, "chapter_has_3star": false}).is_empty(), "2 stars are not the first 3-star")
	ok(TWResultChain.milestones(r, {"wins_before": 5, "chapter_has_3star": true}).is_empty(), "a later 3-star of the chapter is not a milestone")
	for n in [9, 19, 29, 99]:
		ok(TWResultChain.milestones(r, {"wins_before": n}) == [TWResultChain.M_TENTH], "win %d is every 10th" % (n + 1))
	for n in [8, 10, 11, 18]:
		ok(TWResultChain.milestones(r, {"wins_before": n}).is_empty(), "win %d is not every 10th" % (n + 1))
	ok(TWResultChain.milestones(make_result(3, 1, 10, 100, false), {"wins_before": 0, "is_boss": true}).is_empty(), "a lost round has no milestone")
	ok(TWResultChain.plan(make_result(3, 1, 10, 100, false), {"wins_before": 0}).kind == TWResultChain.KIND_NONE, "a lost round has no victory screen (kind none)")
	ok(TWResultChain.plan(r, {"wins_before": 5}).kind == TWResultChain.KIND_FAST, "an ordinary win is the fast path")
	ok(TWResultChain.plan(r, {"wins_before": 9}).kind == TWResultChain.KIND_CHAIN, "the 10th win is the chain")
	var ft: = TWResultChain.plan(r, {"wins_before": 0, "ftue": true})
	ok(ft.kind == TWResultChain.KIND_FAST and ft.ftue and ft.sting == TWResultChain.STING_SHORT and ft.milestones == [TWResultChain.M_FIRST_WIN],
		"FTUE: the first win of a life is the truncated chain (fast shape, short sting)")
	ok(TWResultChain.plan(r, {"wins_before": 0}).kind == TWResultChain.KIND_CHAIN, "the first win outside the FTUE levels is the full chain")
	ok(TWResultChain.milestone_text(TWResultChain.M_TENTH, 19) == "20-я победа", "the tenth-win caption counts the win")
	# a property run: the kind follows the milestones
	var rng: = RandomNumberGenerator.new()
	rng.seed = 33
	var bad: = 0
	for i in 400:
		var f: = {"wins_before": rng.randi_range(0, 60), "is_boss": rng.randf() < 0.1, "chapter_has_3star": rng.randf() < 0.5, "ftue": rng.randf() < 0.2}
		var rr: = make_result(rng.randi_range(1, 3), rng.randi_range(0, 4), rng.randi_range(0, 10), rng.randi_range(0, 100))
		var ms: = TWResultChain.milestones(rr, f)
		var want: = TWResultChain.KIND_CHAIN if (not ms.is_empty() and not f.ftue) else TWResultChain.KIND_FAST
		var p: = TWResultChain.plan(rr, f)
		if p.kind != want or (p.kind == TWResultChain.KIND_CHAIN and p.sting != TWResultChain.STING_LONG) or (p.kind == TWResultChain.KIND_FAST and p.sting != TWResultChain.STING_SHORT):
			bad += 1
	ok(bad == 0, "400 random facts: kind and sting follow the milestones (%d wrong)" % bad)
	# the view carries what was earned, merged per currency
	var two: = TWRoundResult.new()
	two.win = true
	two.outcome = "win"
	two.stars = 3
	two.grant("gems", 20, "a")
	two.grant("gems", 15, "b")
	two.grant("coins", 5, "c")
	var v: = TWResultChain.view_of(two, {"partner": "hana"})
	ok(v.rows.size() == 2 and int(v.rows[0].n) == 35 and v.hero == "hana", "grants are merged per currency, the hero comes from the facts")
	var keys: = TWRoundResult.KEYS
	var banned_key: = false
	for k in keys:
		var ks: = String(k).to_lower()
		if ks.contains("left") or ks.contains("remain") or ks.contains("limit"):
			banned_key = true
	for k in v.keys():
		var ks2: = String(k).to_lower()
		if ks2.contains("left") or ks2.contains("remain") or ks2.contains("limit"):
			banned_key = true
	ok(not banned_key, "neither TWRoundResult nor the victory view has a left / remaining / limit field")


# ------------------------------------------------------------------ B timeline

func _first_cue(tl: Dictionary, name: String) -> float:
	for c in tl.cues:
		if String(c.name) == name:
			return float(c.t)
	return -1.0


func _timeline() -> void:
	for rows in [0, 1, 2, 4]:
		var v: = TWResultChain.view_of(make_result(3, rows), {})
		var f: = TWResultChain.timeline(TWResultChain.KIND_FAST, v)
		ok(float(f.cta_t) <= TWResultChain.FAST_MAX_S and float(f.total) <= TWResultChain.FAST_MAX_S, "fast (%d reward rows): the button at %.2f s and settled at %.2f s, both <= 3.0" % [rows, f.cta_t, f.total])
		var c: = TWResultChain.timeline(TWResultChain.KIND_CHAIN, v)
		ok(float(c.cta_t) <= TWResultChain.CHAIN_MAX_S and float(c.total) <= TWResultChain.CHAIN_MAX_S, "chain (%d reward rows): the Confirm at %.2f s, nominal end %.2f s, both <= 20" % [rows, c.cta_t, c.total])
	var v3: = TWResultChain.view_of(make_result(3, 2), {})
	var f3: = TWResultChain.timeline(TWResultChain.KIND_FAST, v3)
	var c3: = TWResultChain.timeline(TWResultChain.KIND_CHAIN, v3)
	ok((f3.panels as Array).size() == 1 and (c3.panels as Array).size() == 3, "fast = 1 panel, chain = 3 panels")
	ok(absf(_first_cue(f3, "title") - 0.12) < 1e-6 and absf(float(f3.silence) - 0.12) < 1e-6, "fast: «Поле чисто» after 120 ms of silence")
	ok(absf(_first_cue(c3, "title") - 0.4) < 1e-6 and absf(float(c3.silence) - 0.4) < 1e-6, "chain: «Поле чисто» after 400 ms of silence")
	var star_t: Array = []
	for c in f3.cues:
		if String(c.name) == "star":
			star_t.append(float(c.t))
	ok(star_t.size() == 3 and absf(star_t[1] - star_t[0] - 0.12) < 1e-6 and absf(star_t[2] - star_t[1] - 0.12) < 1e-6, "fast: a star every 120 ms %s" % str(star_t))
	ok(_first_cue(f3, TWResultChain.STING_SHORT) >= 0.0 and _first_cue(f3, TWResultChain.STING_LONG) < 0.0 and float(f3.sting_len) <= 1.3, "fast: only the short sting (~1.2 s), never the 9.3 s one")
	ok(absf(_first_cue(c3, TWResultChain.STING_LONG) - 0.4) < 1e-6 and float(c3.sting_len) > 9.0 and _first_cue(c3, TWResultChain.STING_SHORT) < 0.0, "chain: the 9.3 s sting starts after the 400 ms of silence")
	ok(_first_cue(f3, "gem_fly") > 0.0 and _first_cue(f3, "coin_fly") > 0.0, "fast: the gem and coin icons fly")
	for tl in [f3, c3]:
		var last: = -1.0
		var sorted: = true
		for c in tl.cues:
			if float(c.t) < last:
				sorted = false
			last = float(c.t)
		ok(sorted, "%s: cues are in time order" % tl.kind)
		var pn: Array = tl.panels
		var chain_ok: = true
		for i in pn.size():
			var p: Dictionary = pn[i]
			if float(p.settle) < float(p.t0) or (i + 1 < pn.size() and (float(p.end) != float(pn[i + 1].t0) or float(p.settle) >= float(p.end))):
				chain_ok = false
		ok(chain_ok, "%s: each panel settles before the next starts" % tl.kind)
	ok(float(c3.panels[1].t0) - float(c3.panels[0].t0) <= 6.0 + 1e-6 and float(c3.panels[2].t0) == 12.0, "chain: panels of about 6 s")
	ok(float(c3.cta_t) >= float(c3.panels[2].t0) and float(c3.cta_t) < float(c3.total), "chain: the one Confirm comes in on the last panel")


# ------------------------------------------------------------------ C run

func _make_run(kind: String, rows: int = 2) -> TWResultChain.Run:
	return TWResultChain.Run.new(TWResultChain.timeline(kind, TWResultChain.view_of(make_result(3, rows), {})))


func _step(r: TWResultChain.Run, secs: float) -> void:
	var n: = int(round(secs / FRAME))
	for i in n:
		r.advance(FRAME)


func _run_machine() -> void:
	# fast: time alone
	var r: = _make_run(TWResultChain.KIND_FAST)
	ok(not r.cta_ready() and r.panel == 0, "fast: the button is not ready at 0")
	_step(r, 1.0)
	ok(not r.cta_ready(), "fast: not ready at 1.0 s")
	_step(r, 0.45)
	ok(r.cta_ready() and r.t <= 3.0, "fast: ready at %.2f s" % r.t)
	# fast: a tap settles at once
	var r2: = _make_run(TWResultChain.KIND_FAST)
	_step(r2, 0.2)
	ok(r2.tap() == "accel" and r2.cta_ready() and r2.t < 1.8 and r2.t - 0.2 > 1.0, "fast: a tap at 0.2 s jumps to the end of the animation (t=%.2f)" % r2.t)
	ok(r2.tap() == "none", "fast: a tap on a settled panel does nothing by itself (the button is the way on)")
	var tl2: Dictionary = r2.tl
	ok(r2.skipped.has("star") or r2.fired.has("star"), "fast: cues were passed or fired")
	# chain: tap 1 settles, tap 2 goes on
	var c: = _make_run(TWResultChain.KIND_CHAIN)
	_step(c, 0.1)
	ok(c.panel == 0 and not c.sting_playing(), "chain: 100 ms in, still silence, no sting")
	_step(c, 0.5)
	ok(c.sting_playing(), "chain: the sting plays after 400 ms")
	ok(c.tap() == "accel" and c.panel == 0 and c.settled() and absf(c.t - 3.4) < 1e-6, "chain: tap 1 settles panel 1 (t=%.2f)" % c.t)
	ok(c.sting_cut and c.fired.has("sting_stop") and not c.sting_playing(), "chain: the first tap cuts the sting")
	ok(c.tap() == "next" and c.panel == 1 and absf(c.t - 6.0) < 1e-6, "chain: tap 2 goes to panel 2 (t=%.2f)" % c.t)
	ok(c.tap() == "accel" and c.panel == 1 and absf(c.t - 9.0) < 1e-6, "chain: tap 3 settles panel 2")
	ok(c.tap() == "next" and c.panel == 2 and not c.cta_ready(), "chain: tap 4 goes to panel 3, the Confirm not there yet")
	ok(c.tap() == "accel" and c.cta_ready() and c.panel == 2, "chain: tap 5 settles panel 3: the Confirm is ready at t=%.2f" % c.t)
	ok(c.tap() == "none", "chain: after the last panel a stage tap does nothing")
	ok(c.accels == 3 and c.nexts == 2, "chain: 3 accelerations and 2 advances were counted")
	# chain by time alone: panels advance on their own, ready by 15 s, never later than 20 s
	var ca: = _make_run(TWResultChain.KIND_CHAIN)
	var seen_panels: Array = [0]
	var ready_at: = -1.0
	for i in int(21.0 / FRAME):
		ca.advance(FRAME)
		if not seen_panels.has(ca.panel):
			seen_panels.append(ca.panel)
		if ready_at < 0.0 and ca.cta_ready():
			ready_at = ca.t
	ok(seen_panels == [0, 1, 2] and ready_at > 0.0 and ready_at <= 20.0, "chain by time alone: panels 0,1,2 and the Confirm at %.2f s (<= 20)" % ready_at)
	# Skip
	var cs: = _make_run(TWResultChain.KIND_CHAIN)
	_step(cs, 1.0)
	cs.skip()
	ok(cs.cta_ready() and cs.panel == 2 and cs.skip_used and cs.fired.has("sting_stop"), "chain: Skip lands on the last panel with the button ready and cuts the sting")
	ok(cs.skipped.has("star") or cs.skipped.has(TWResultChain.STING_LONG) or cs.skipped.has("gem_fly"), "chain: sounds that were jumped over are marked skipped")
	# a property run: random taps / skips / time
	var rng: = RandomNumberGenerator.new()
	rng.seed = 3333
	var bad_time: = 0
	var bad_cta: = 0
	var bad_cue: = 0
	var bad_panel: = 0
	for seq in 500:
		var kind: = TWResultChain.KIND_CHAIN if seq % 2 == 0 else TWResultChain.KIND_FAST
		var rn: = _make_run(kind, rng.randi_range(0, 4))
		var last_t: = 0.0
		var elapsed: = 0.0
		var steps: = rng.randi_range(20, 200)
		for s in steps:
			var pick: = rng.randf()
			if pick < 0.65:
				var dt: = rng.randf_range(0.0, 0.5)
				rn.advance(dt)
				elapsed += dt
			elif pick < 0.97:
				rn.tap()
			else:
				rn.skip()
			if rn.t < last_t - 1e-9:
				bad_time += 1
			last_t = rn.t
			if rn.panel < 0 or rn.panel >= rn.n_panels():
				bad_panel += 1
		# whatever happened, 20 s later (fast: 3 s) of plain time the button is there
		var limit: = TWResultChain.CHAIN_MAX_S if kind == TWResultChain.KIND_CHAIN else TWResultChain.FAST_MAX_S
		var remaining: = maxf(0.0, limit - rn.t)
		rn.advance(remaining + 0.001)
		if not rn.cta_ready():
			bad_cta += 1
		var uniq: = {}
		for nm in rn.fired:
			if nm in ["title", "cta", "milestone", "hero", "fill", TWResultChain.STING_LONG, TWResultChain.STING_SHORT, "sting_stop"]:
				if uniq.has(nm):
					bad_cue += 1
				uniq[nm] = true
	ok(bad_time == 0 and bad_panel == 0, "500 random sequences: time never goes back, the panel is always valid (%d / %d)" % [bad_time, bad_panel])
	ok(bad_cta == 0, "500 random sequences: the button is ready by the limit whatever was tapped (%d late)" % bad_cta)
	ok(bad_cue == 0, "500 random sequences: no one-shot cue fired twice (%d)" % bad_cue)


# ------------------------------------------------------------------ D modal

class _Audio extends RefCounted:
	var played: Array = []
	var stopped: Array = []

	func play_cue(nm: String, _data: Dictionary = {}) -> void:
		played.append(nm)

	func stop_cue(nm: String) -> void:
		stopped.append(nm)


func _stack_in(vs: Vector2, parent: Node) -> Array:
	var vp: = SubViewport.new()
	vp.size = Vector2i(vs)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var st: = ModalStack.new()
	vp.add_child(st)
	return [vp, st]


func _rect_of(c: Control) -> Rect2:
	return Rect2(c.position, c.size)


func _modal() -> void:
	for vs in SIZES:
		var ins: = TWDraw.safe_insets(vs)
		var lf: = TWResultModal.layout(vs, ins, TWResultChain.KIND_FAST)
		var lc: = TWResultModal.layout(vs, ins, TWResultChain.KIND_CHAIN)
		ok(lf.cta == lc.cta and lf.map == lc.map and lf.share == lc.share, "%s: the button rects are the same in the fast path and the chain" % str(vs))
		for key in ["cta", "map", "share", "skip"]:
			var r: Rect2 = lc[key]
			ok(r.size.y >= float(TWTokens.HIT_TARGET_MIN) - 0.01, "%s: %s is %.0f px tall (>= 96)" % [str(vs), key, r.size.y])
			ok(r.position.x >= 0.0 and r.end.x <= vs.x + 0.01 and r.position.y >= 0.0 and r.end.y <= vs.y - float(ins.bottom) + 0.01, "%s: %s is on screen" % [str(vs), key])
		ok(not (lc.cta as Rect2).intersects(lc.map) and not (lc.map as Rect2).intersects(lc.share) and not (lc.skip as Rect2).intersects(lc.region), "%s: buttons do not overlap each other or the content" % str(vs))
		ok(TWResultModal.layout(vs, ins, TWResultChain.KIND_FAST).hash() == lf.hash(), "%s: layout is pure" % str(vs))
	var banned_hits: Array = []
	for kind in [TWResultChain.KIND_FAST, TWResultChain.KIND_CHAIN]:
		var vs: = Vector2(720, 1280)
		var pair: = _stack_in(vs, _host)
		var vp: SubViewport = pair[0]
		var st: ModalStack = pair[1]
		var aud: = _Audio.new()
		var facts: = {"wins_before": 9, "partner": "rin", "chapter_has_3star": true} if kind == TWResultChain.KIND_CHAIN else {"wins_before": 4, "partner": "rin"}
		var m: = TWResultModal.make(make_result(3, 3), facts, {"audio": aud, "manual": true})
		var closed: Array = []
		m.on_close = func(res: Variant, why: String) -> void: closed.append([res, why])
		st.open(m)
		await _host.get_tree().process_frame
		ok(m.plan.kind == kind and m.is_open() and st.depth() == 1, "%s: the modal is open on the stack" % kind)
		ok(m.get_child(0) == m.scrim and m.scrim_alpha > 0.5, "%s: the scrim is the modal's child 0" % kind)
		var cta_rect: = _rect_of(m.cta)
		var map_rect: = _rect_of(m.sec_map)
		var share_rect: = _rect_of(m.sec_share)
		var skip_rect: = _rect_of(m.skip_btn)
		var moved: = 0
		var skip_hidden: = 0
		var cta_early: = 0
		var cta_live_t: = -1.0
		var primaries: = 0
		var t: = 0.0
		var limit: = 21.0 if kind == TWResultChain.KIND_CHAIN else 3.5
		while t < limit:
			if _rect_of(m.cta) != cta_rect or _rect_of(m.sec_map) != map_rect or _rect_of(m.sec_share) != share_rect or _rect_of(m.skip_btn) != skip_rect:
				moved += 1
			if kind == TWResultChain.KIND_CHAIN and not m.skip_btn.visible:
				skip_hidden += 1
			if m.cta.visible and cta_live_t < 0.0:
				cta_live_t = t
				if not m.cta_ready():
					cta_early += 1
			if not m.cta.visible and m.cta_ready() and m.run.panel == m.run.n_panels() - 1:
				cta_early += 1
			for ch in m.get_children():
				if ch is TWButton and (ch as TWButton).visible and (ch as TWButton).kind == "play":
					primaries = maxi(primaries, 1)
			m.advance(0.05)
			t += 0.05
		ok(moved == 0, "%s: the cta / secondary / Skip rects never move over %.0f s (%d frames moved)" % [kind, t, moved])
		ok(skip_hidden == 0 and (kind == TWResultChain.KIND_FAST or m.skip_btn.visible), "%s: Skip is visible in every frame of the chain" % kind)
		ok(cta_live_t > 0.0 and cta_early == 0 and cta_live_t <= (3.0 if kind == TWResultChain.KIND_FAST else 20.0), "%s: the primary button shows at %.2f s, exactly when the run says ready" % [kind, cta_live_t])
		ok(primaries == 1, "%s: one primary (play) button" % kind)
		var visible_btns: = 0
		var secondaries: = 0
		for ch in m.get_children():
			if ch is TWButton and (ch as TWButton).visible:
				visible_btns += 1
				if (ch as TWButton).kind == "secondary" and ch != m.skip_btn:
					secondaries += 1
		ok(secondaries <= 2, "%s: at most 2 secondary buttons beside the primary (%d)" % [kind, secondaries])
		ok(m.cta.text == "Ещё уровень" and m.sec_map.text == "На карту" and m.sec_share.text == "Поделиться", "%s: the button texts" % kind)
		ok(aud.played.has(String(m.plan.sting)) and (kind == TWResultChain.KIND_CHAIN or not aud.played.has(TWResultChain.STING_LONG)), "%s: the sting that played is %s" % [kind, m.plan.sting])
		ok(aud.played.count("star") == 3, "%s: 3 star sounds (%d)" % [kind, aud.played.count("star")])
		for txt in m.texts_seen.keys():
			for w in BANNED:
				if String(txt).to_lower().contains(w):
					banned_hits.append(txt)
		ok(m.texts_seen.size() >= 4, "%s: the modal showed %d different texts" % [kind, m.texts_seen.size()])
		# the buttons work
		var shared: Array = []
		m.share_requested.connect(func() -> void: shared.append(1))
		m.sec_share.pressed.emit()
		ok(shared.size() == 1 and m.is_open() and closed.is_empty(), "%s: Поделиться asks and keeps the screen open" % kind)
		m.cta.pressed.emit()
		ok(closed.size() == 1 and closed[0][0] is Dictionary and closed[0][0].action == "next" and closed[0][1] == "next" and st.depth() == 0, "%s: «Ещё уровень» closes once with action next, the layer is empty" % kind)
		ok(closed[0][0].kind == kind and closed[0][0].stars == 3, "%s: the result says kind and stars" % kind)
		m.cta.pressed.emit()
		m._press("next")
		ok(closed.size() == 1, "%s: a second press after close does nothing" % kind)
		vp.queue_free()
		await _host.get_tree().process_frame
	ok(banned_hits.is_empty(), "no banned word in anything the modal showed: %s" % str(banned_hits))
	# the button is not live before it is ready; a stray press does nothing
	var pair2: = _stack_in(Vector2(720, 1280), _host)
	var st2: ModalStack = pair2[1]
	var m2: = TWResultModal.make(make_result(2, 1), {"wins_before": 3}, {"manual": true})
	var cl2: Array = []
	m2.on_close = func(res: Variant, why: String) -> void: cl2.append([res, why])
	st2.open(m2)
	await _host.get_tree().process_frame
	m2.advance(0.3)
	ok(not m2.cta.visible, "fast: the button is hidden at 0.3 s")
	m2._press("next")
	ok(cl2.is_empty() and m2.is_open(), "fast: a «next» before the button is ready is ignored")
	ok(m2.stage_tap() == "accel" and m2.cta.visible, "fast: a stage tap shows the button at once")
	ok(m2.on_back() == true and cl2.size() == 1 and cl2[0][0].action == "map", "fast: Android back with the button ready = «На карту», closed once")
	# chain: first back = Skip, second = map
	var m3: = TWResultModal.make(make_result(3, 2), {"wins_before": 9}, {"manual": true})
	var cl3: Array = []
	m3.on_close = func(res: Variant, why: String) -> void: cl3.append([res, why])
	st2.open(m3)
	await _host.get_tree().process_frame
	m3.advance(1.0)
	ok(st2.handle_back() == true and cl3.is_empty() and m3.cta_ready(), "chain: the first back press = Skip (the screen stays, the Confirm is ready)")
	ok(st2.handle_back() == true and cl3.size() == 1 and cl3[0][0].action == "map", "chain: the second back press leaves to the map")
	# a screen change (clear_all) closes it with a null result and on_close runs once
	var m4: = TWResultModal.make(make_result(3, 2), {"wins_before": 2}, {"manual": true})
	var cl4: Array = []
	m4.on_close = func(res: Variant, why: String) -> void: cl4.append([res, why])
	st2.open(m4)
	await _host.get_tree().process_frame
	st2.clear_all("go:test")
	ok(cl4.size() == 1 and cl4[0][0] == null and st2.depth() == 0, "clear_all closes the victory modal once with a null result (%s)" % str(cl4))
	# a scrim tap / back never discards it by accident
	var m5: = TWResultModal.make(make_result(3, 2), {"wins_before": 2}, {"manual": true})
	var cl5: Array = []
	m5.on_close = func(res: Variant, why: String) -> void: cl5.append([res, why])
	st2.open(m5)
	await _host.get_tree().process_frame
	var ev: = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	m5.scrim.gui_input.emit(ev)
	ok(cl5.is_empty() and m5.is_open(), "a tap on the scrim does not close the victory modal")
	st2.clear_all("end")
	(pair2[0] as Node).queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ E real time

func _real_time() -> void:
	var pair: = _stack_in(Vector2(720, 1280), _host)
	var vp: SubViewport = pair[0]
	var st: ModalStack = pair[1]
	var m: = TWResultModal.make(make_result(3, 2), {"wins_before": 4, "partner": "rin"}, {})
	st.open(m)
	var t0: = Time.get_ticks_msec()
	var shown: = -1
	var guard: = 0
	while shown < 0 and guard < 600:
		guard += 1
		await _host.get_tree().process_frame
		if m.cta.visible and m.cta.modulate.a > 0.0:
			shown = Time.get_ticks_msec() - t0
	ok(shown > 0 and shown <= 3000, "real frames: from «Поле чисто» to «Ещё уровень» in %d ms (<= 3000)" % shown)
	ok(m.cta.size.y >= 96.0 and m.cta.is_visible_in_tree(), "real frames: the button is on the tree and >= 96 px")
	m.close(null, "test")
	# a tap during the animation shows it at once
	var m2: = TWResultModal.make(make_result(3, 2), {"wins_before": 4}, {})
	st.open(m2)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var ev: = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(360, 400)
	m2.stage._gui_input(ev)
	await _host.get_tree().process_frame
	ok(m2.cta.visible and m2.run.t < 3.0, "real frames: a tap on the stage settles the animation (button visible at run t=%.2f)" % m2.run.t)
	st.clear_all("end")
	vp.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ F render

func _avg(img: Image, p: Vector2) -> Color:
	var acc: = Color(0, 0, 0, 0)
	var n: = 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var x: = clampi(int(p.x) + dx, 0, img.get_width() - 1)
			var y: = clampi(int(p.y) + dy, 0, img.get_height() - 1)
			acc += img.get_pixel(x, y)
			n += 1
	return acc / float(n)


func _shot(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await _host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _render() -> void:
	var vs: = Vector2(720, 1280)
	for kind in [TWResultChain.KIND_FAST, TWResultChain.KIND_CHAIN]:
		var pair: = _stack_in(vs, _host)
		var vp: SubViewport = pair[0]
		var st: ModalStack = pair[1]
		var bgc: = ColorRect.new()
		bgc.color = TWSkin.c("FELT_HI")
		bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.add_child(bgc)
		vp.move_child(bgc, 0)
		var m: = TWResultModal.make(make_result(3, 2), {"wins_before": 9 if kind == TWResultChain.KIND_CHAIN else 4, "partner": "rin"}, {"manual": true})
		st.open(m)
		var times: Array = [0.05, 0.6, 1.8] if kind == TWResultChain.KIND_FAST else [1.0, 3.5, 7.0, 10.0, 13.0, 16.0]
		var prev_img: Image = null
		var states_differ: = 0
		var imgs: = 0
		var cta_ok: = false
		for tt in times:
			var dt: float = float(tt) - m.run.t
			if dt > 0.0:
				m.advance(dt)
			var img: = await _shot(vp)
			if img == null or img.get_width() != int(vs.x):
				ok(false, "%s t=%.2f: the modal renders to a 720x1280 image (display needed)" % [kind, tt])
				continue
			imgs += 1
			if prev_img != null and prev_img.get_data() != img.get_data():
				states_differ += 1
			prev_img = img
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--shots="):
					var dir: String = a.substr(8)
					DirAccess.make_dir_recursive_absolute(dir)
					img.save_png(dir.path_join("result_%s_%02d.png" % [kind, int(float(tt) * 10.0)]))
			if m.cta_ready() and m.cta_alpha() >= 1.0:
				var cr: Rect2 = m.lay.cta
				var inside: = _avg(img, cr.position + Vector2(cr.size.x * 0.5, cr.size.y * 0.5))
				var outside: = _avg(img, Vector2(cr.position.x - 14.0, cr.position.y + cr.size.y * 0.5))
				cta_ok = absf(inside.get_luminance() - outside.get_luminance()) > 0.04 or (absf(inside.r - outside.r) + absf(inside.g - outside.g) + absf(inside.b - outside.b)) > 0.08
		ok(imgs == times.size(), "%s: %d states rendered" % [kind, imgs])
		ok(states_differ >= times.size() - 2, "%s: the picture changes between states (%d of %d differ)" % [kind, states_differ, times.size() - 1])
		ok(cta_ok, "%s: the primary button is drawn on the screen once ready (pixels differ from the scrim)" % kind)
		st.clear_all("end")
		vp.queue_free()
		await _host.get_tree().process_frame


# ------------------------------------------------------------------ G screen

func _screen() -> void:
	var ctx: = TWContext.for_tests("user://tw_result_selftest/")
	_host.add_child(ctx.screens)
	var stack: = ModalStack.new()
	_host.add_child(stack)
	stack.bind_screens(ctx.screens)
	ctx.provide("modals", stack)
	ctx.screens.scan()
	var cfg: = TWBoardViewSelftest._cfg(51, {"plan": {}, "ice": 0, "hidden": false})
	var facts: = {"wins_before": 0, "partner": "rin", "ftue": true}
	await ctx.screens.go("match", {"cfg": cfg, "tile_size": "L", "result_facts": facts, "round_state": {"partner": "rin"}})
	var m: = ctx.screens.current as TWMatchScreen
	ok(m != null and m.result_modal == null and stack.depth() == 0, "the match screen starts with no victory modal")
	if m == null:
		return
	m.view.manual = true
	var acts: Array = []
	m.result_action.connect(func(a: String, info: Dictionary) -> void: acts.append([a, info]))
	var guard: = 0
	while not m.ended and guard < 400:
		guard += 1
		var id: = m.board.solver_move()
		if id < 0:
			break
		m.tap_tile(id)
		m.view.advance(0.05)
	m.view.finish()
	ok(m.board.cleared and m.round_result != null and m.round_result.win and m.round_result.stars >= 1, "the solver cleared the board and TWRound.resolve gave a win with %d stars" % (m.round_result.stars if m.round_result != null else -1))
	ok(m.result_modal != null and stack.depth() == 1 and stack.top() == m.result_modal, "the victory modal is open on the ModalStack, once")
	ok(m.result_modal.plan.kind == TWResultChain.KIND_FAST and m.result_modal.plan.ftue and m.result_modal.plan.milestones == [TWResultChain.M_FIRST_WIN], "FTUE first win: the fast shape with the first-win milestone")
	var before: int = stack.opened_count
	m.tap_tile(0)
	ok(stack.opened_count == before and stack.depth() == 1, "a finished round opens no second modal")
	m.result_modal.advance(1.6)
	ok(m.result_modal.cta.visible, "the button is there 1.6 s after the board cleared")
	m.result_modal.cta.pressed.emit()
	await _host.get_tree().process_frame
	ok(acts.size() == 1 and acts[0][0] == "next" and stack.depth() == 0 and m.result_modal == null, "«Ещё уровень» comes out as result_action(next); the layer is empty")
	# a chain game (10th win) through the screen, then «На карту»
	var facts2: = {"wins_before": 9, "partner": "rin"}
	await ctx.screens.go("match", {"cfg": TWBoardViewSelftest._cfg(52, {"plan": {}, "ice": 0, "hidden": false}), "result_facts": facts2})
	var m2: = ctx.screens.current as TWMatchScreen
	m2.view.manual = true
	var acts2: Array = []
	m2.result_action.connect(func(a: String, info: Dictionary) -> void: acts2.append([a, info]))
	guard = 0
	while not m2.ended and guard < 400:
		guard += 1
		var id2: = m2.board.solver_move()
		if id2 < 0:
			break
		m2.tap_tile(id2)
	ok(m2.result_modal != null and m2.result_modal.plan.kind == TWResultChain.KIND_CHAIN and m2.result_modal.plan.milestones == [TWResultChain.M_TENTH], "the 10th win opens the chain")
	m2.result_modal.skip()
	ok(m2.result_modal.cta_ready(), "Skip reaches the Confirm")
	m2.result_modal.sec_map.pressed.emit()
	await _host.get_tree().process_frame
	ok(acts2.size() == 1 and acts2[0][0] == "map" and acts2[0][1].kind == TWResultChain.KIND_CHAIN, "«На карту» comes out as result_action(map)")
	# a lost round opens nothing
	await ctx.screens.go("match", {"cfg": TWBoardViewSelftest._cfg(52, {"plan": {}}), "result_facts": facts2})
	var m3: = ctx.screens.current as TWMatchScreen
	m3.view.manual = true
	var tries: = 0
	while not m3.ended and tries < 200:
		tries += 1
		var pick: = -1
		for t in m3.board.free_tiles():
			if m3.board.tray_twin(t) < 0:
				pick = t
				break
		if pick < 0:
			break
		m3.tap_tile(pick)
	ok(m3.board.failed and m3.result_modal == null and stack.depth() == 0, "a failed round opens no victory modal")
	# no stack in the context: the screen works as before
	var ctx2: = TWContext.for_tests("user://tw_result_selftest2/")
	_host.add_child(ctx2.screens)
	ctx2.screens.scan()
	await ctx2.screens.go("match", {"cfg": TWBoardViewSelftest._cfg(51, {"plan": {}, "ice": 0, "hidden": false})})
	var m4: = ctx2.screens.current as TWMatchScreen
	m4.view.manual = true
	guard = 0
	while not m4.ended and guard < 400:
		guard += 1
		var id4: = m4.board.solver_move()
		if id4 < 0:
			break
		m4.tap_tile(id4)
	ok(m4.board.cleared and m4.result_modal == null and m4.round_result == null, "without a ModalStack in the context nothing is opened (P31 behaviour)")
	# a wallet service is paid once
	ctx.screens.queue_free()
	ctx2.screens.queue_free()
	stack.queue_free()
	await _host.get_tree().process_frame


# ------------------------------------------------------------------ H lint

func _code_only(src: String) -> String:
	var out: PackedStringArray = []
	for line in src.split("\n"):
		var q: = ""
		var res: = ""
		var i: = 0
		while i < line.length():
			var ch: = line[i]
			if q != "":
				if ch == "\\":
					i += 2
					continue
				if ch == q:
					q = ""
			elif ch == "\"" or ch == "'":
				q = ch
			elif ch == "#":
				break
			else:
				res += ch
			i += 1
		out.append(res)
	return "\n".join(out)


func _lint() -> void:
	for path in ["res://shell/screens/match/result_modal.gd", "res://shell/screens/match/result_chain.gd"]:
		var f: = FileAccess.open(path, FileAccess.READ)
		ok(f != null, "%s is readable" % path)
		if f == null:
			continue
		var src: = f.get_as_text()
		var code: = _code_only(src).to_lower()
		var hit: Array = []
		for w in BANNED_CODE:
			if code.contains(w):
				hit.append(w)
		ok(hit.is_empty(), "%s: no sale / interstitial / counter identifier in code %s" % [path.get_file(), str(hit)])
		var lits: Array = []
		var re: = RegEx.new()
		re.compile("\"([^\"\\\\]|\\\\.)*\"")
		for mt in re.search_all(src):
			lits.append(mt.get_string().to_lower())
		var bad: Array = []
		for s in lits:
			for w in BANNED:
				if (s as String).contains(w):
					bad.append(s)
		ok(bad.is_empty(), "%s: no «осталось» / sale word in any string literal %s" % [path.get_file(), str(bad)])
		ok(not src.contains("res://assets") and not src.contains("Input."), "%s: no res://assets literal, no Input" % path.get_file())
	for v in TWResultChain.TEXT.values():
		for w in BANNED:
			if String(v).to_lower().contains(w):
				ok(false, "TEXT contains %s" % w)
	ok(true, "TWResultChain.TEXT scanned (%d entries)" % TWResultChain.TEXT.size())
