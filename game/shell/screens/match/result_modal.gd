class_name TWResultModal
extends TWModal

# TWResultModal (P33 / WP10c): the victory screen of a won round, a TWModal on the ModalStack that shows a TWRoundResult.
#
#   var m := TWResultModal.make(round_result, {"wins_before": 12, "is_boss": false, ...}, {"audio": audio_or_null})
#   stack.open(m)            # on_close(result, reason): result = {"action": "next" | "map", "kind", "milestones", "stars", "t"}
#
# The content and timing come from TWResultChain (pure, tested on its own): `fast` = one panel, the primary button «Ещё уровень» within
# 3 s; `chain` = three panels on a milestone, the one Confirm within 20 s. This node only paints the state of a TWResultChain.Run and owns
# the buttons. The primary button, the secondaries and Skip have ONE fixed rect per screen size (`layout()`), whatever panel is showing, so
# a thumb that learned the place never has to look for it.
#
# Taps: a tap on the stage (anything that is not a button) goes to Run.tap(): the first one settles the current panel at once, the next
# one (chain) goes to the next panel. It never leaves the screen by itself: the result is already paid, a stray tap must not throw away
# a reward picture, and the Confirm / «Ещё уровень» is always the same place. Skip (chain, always visible) jumps to the end. Android back
# is the same: first press = Skip, once the button is ready = «На карту».
#
# The modal advances itself in _process; a test sets `manual = true` and calls advance(dt). It holds no rule and no counter of what is
# left: there is no such text anywhere (TWResultChain.TEXT is the only copy; the selftest greps it and every Label this node makes).

signal share_requested
signal action(name: String)

const CTA_W: = 560
const CTA_H: = 104
const SEC_W: = 264
const SEC_H: = 96
const SKIP_W: = 272
const BTN_GAP: = 16
const BOTTOM_PAD: = 32
const STAR_PX: = 132
const STAR_GAP: = 24
const STAR_PX_CHAIN: = 168
const FLY_FROM_TO: = 0.5
const ICON_PX: = 56

var res: TWRoundResult = null
var facts: Dictionary = {}
var plan: Dictionary = {}
var run: TWResultChain.Run = null
var audio: Object = null
var manual: = false
var cue_log: Array = []                  # [[t, name, skipped]]
var texts_seen: Dictionary = {}          # every string a Label of this modal ever showed (the lint reads it)

var stage: Control = null
var cta: TWButton = null
var sec_map: TWButton = null
var sec_share: TWButton = null
var skip_btn: TWButton = null
var lb_title: Label = null
var lb_caption: Label = null
var lb_bond: Label = null
var lb_xp: Label = null
var lb_hero: Label = null
var lb_rewards: Label = null
var lb_rank: Label = null
var lb_rows: Array = []
var lay: Dictionary = {}
var _vs: = Vector2.ZERO
var _insets: Dictionary = {}
var _art: Texture2D = null
var _ready_done: = false


static func make(p_res: TWRoundResult, p_facts: Dictionary = {}, opts: Dictionary = {}) -> TWResultModal:
	var m: = TWResultModal.new()
	m.res = p_res
	m.facts = p_facts
	m.plan = TWResultChain.plan(p_res, p_facts)
	m.audio = opts.get("audio", null)
	m.manual = bool(opts.get("manual", false))
	m.dismissable = false                       # back / scrim never discard the screen; on_back() below steps it
	m.scrim_tap_closes = false
	m.scrim_alpha = 0.74
	return m


# ── layout: pure, one rect per element and screen size ─────────────────────────────────────────────────────────────────────

static func layout(vs: Vector2, insets: Dictionary, kind: String) -> Dictionary:
	var k: = clampf(vs.x / float(TWTokens.BASE_WIDTH), 0.5, 3.0)
	var top: = float(insets.get("top", 0.0))
	var bot: = float(insets.get("bottom", 0.0))
	var cta_w: = minf(float(CTA_W) * k, vs.x - 2.0 * TWTokens.SAFE_MARGIN * k)
	var cta_h: = maxf(float(CTA_H) * k, float(TWTokens.HIT_TARGET_MIN))
	var cta_r: = Rect2(Vector2((vs.x - cta_w) * 0.5, vs.y - bot - float(BOTTOM_PAD) * k - cta_h), Vector2(cta_w, cta_h))
	var sec_h: = maxf(float(SEC_H) * k, float(TWTokens.HIT_TARGET_MIN))
	var sec_w: = (cta_w - float(BTN_GAP) * k) * 0.5
	var sec_y: = cta_r.position.y - float(BTN_GAP) * k - sec_h
	var map_r: = Rect2(Vector2(cta_r.position.x, sec_y), Vector2(sec_w, sec_h))
	var share_r: = Rect2(Vector2(cta_r.position.x + sec_w + float(BTN_GAP) * k, sec_y), Vector2(sec_w, sec_h))
	var skip_h: = float(TWTokens.HIT_TARGET_MIN)
	var skip_r: = Rect2(Vector2(vs.x - float(TWTokens.SAFE_MARGIN) * k - float(SKIP_W) * k, top + 8.0 * k), Vector2(float(SKIP_W) * k, skip_h))
	var r_top: = top + (skip_h + 16.0 * k if kind == TWResultChain.KIND_CHAIN else 48.0 * k)
	var region: = Rect2(Vector2(0.0, r_top), Vector2(vs.x, maxf(200.0, sec_y - 24.0 * k - r_top)))
	var cx: = vs.x * 0.5
	var out: = {"k": k, "cta": cta_r, "map": map_r, "share": share_r, "skip": skip_r, "region": region}
	var rh: = region.size.y
	var ry: = region.position.y
	var title_h: = 88.0 * k
	var px: = float(STAR_PX_CHAIN if kind == TWResultChain.KIND_CHAIN else STAR_PX) * k
	var bar_w: = minf(560.0 * k, vs.x - 2.0 * TWTokens.SAFE_MARGIN * k)
	if kind == TWResultChain.KIND_CHAIN:
		out["title"] = Rect2(Vector2(0.0, ry + rh * 0.12), Vector2(vs.x, title_h))
		out["stars_c"] = Vector2(cx, ry + rh * 0.38)
		out["caption"] = Rect2(Vector2(TWTokens.SAFE_MARGIN * k, ry + rh * 0.58), Vector2(vs.x - 2.0 * TWTokens.SAFE_MARGIN * k, 120.0 * k))
		out["hero"] = Rect2(Vector2(cx - 220.0 * k, ry + rh * 0.02), Vector2(440.0 * k, rh * 0.58))
		out["bond_label"] = Rect2(Vector2(cx - bar_w * 0.5, ry + rh * 0.64), Vector2(bar_w, 48.0 * k))
		out["bond_bar"] = Rect2(Vector2(cx - bar_w * 0.5, ry + rh * 0.64 + 52.0 * k), Vector2(bar_w, 24.0 * k))
		out["ring_c"] = Vector2(cx - bar_w * 0.5 + 56.0 * k, ry + rh * 0.86)
		out["ring_label"] = Rect2(Vector2(cx - bar_w * 0.5 + 140.0 * k, ry + rh * 0.86 - 24.0 * k), Vector2(bar_w - 140.0 * k, 48.0 * k))
		var rows: Array = []
		for i in 4:
			rows.append(Rect2(Vector2(cx - bar_w * 0.5, ry + rh * (0.20 + 0.15 * i)), Vector2(bar_w, 96.0 * k)))
		out["rows"] = rows
		out["rewards_title"] = Rect2(Vector2(0.0, ry + rh * 0.04), Vector2(vs.x, 64.0 * k))
	else:
		out["title"] = Rect2(Vector2(0.0, ry + rh * 0.06), Vector2(vs.x, title_h))
		out["stars_c"] = Vector2(cx, ry + rh * 0.30)
		out["caption"] = Rect2(Vector2(TWTokens.SAFE_MARGIN * k, ry + rh * 0.44), Vector2(vs.x - 2.0 * TWTokens.SAFE_MARGIN * k, 56.0 * k))
		out["hero"] = Rect2()
		var rows2: Array = []
		for i in 4:
			var w: = bar_w * 0.5
			rows2.append(Rect2(Vector2(cx - bar_w * 0.5 + (i % 2) * w, ry + rh * 0.50 + (i / 2) * 84.0 * k), Vector2(w, 80.0 * k)))
		out["rows"] = rows2
		out["bond_label"] = Rect2(Vector2(cx - bar_w * 0.5, ry + rh * 0.70), Vector2(bar_w, 48.0 * k))
		out["bond_bar"] = Rect2(Vector2(cx - bar_w * 0.5, ry + rh * 0.70 + 52.0 * k), Vector2(bar_w, 24.0 * k))
		out["ring_c"] = Vector2(cx - bar_w * 0.5 + 56.0 * k, ry + rh * 0.90)
		out["ring_label"] = Rect2(Vector2(cx - bar_w * 0.5 + 140.0 * k, ry + rh * 0.90 - 24.0 * k), Vector2(bar_w - 140.0 * k, 48.0 * k))
		out["rewards_title"] = Rect2()
	out["star_px"] = px
	out["fly_to"] = Vector2(vs.x - 96.0 * k, top + 48.0 * k)     # the currency chips of the chrome
	return out


# ── build ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _build(_opts: Dictionary) -> void:
	_vs = _viewport_size()
	_insets = TWDraw.safe_insets(_vs)
	var kind: String = String(plan.kind)
	lay = layout(_vs, _insets, kind)
	var k: float = lay.k
	stage = _Stage.new()
	stage.name = "Stage"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.modal = self
	add_child(stage)
	lb_title = _label(TWResultChain.TEXT.clear, TWTokens.TYPE_DISPLAY, TWSkin.c("GOLD_300"), lay.title, k)
	lb_caption = _label("", TWTokens.TYPE_H2, TWSkin.c("PAPER_100"), lay.caption, k)
	lb_bond = _label("", TWTokens.TYPE_CAPTION, TWSkin.c("PAPER_100"), lay.bond_label, k)
	lb_xp = _label("", TWTokens.TYPE_CAPTION, TWSkin.c("PAPER_100"), lay.ring_label, k)
	lb_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb_hero = _label("", TWTokens.TYPE_H2, TWSkin.c("PAPER_100"), Rect2(), k)
	lb_rewards = _label("", TWTokens.TYPE_H1, TWSkin.c("GOLD_300"), lay.rewards_title, k)
	var rk: Rect2 = lay.caption
	lb_rank = _label("", TWTokens.TYPE_BODY, TWSkin.c("PAPER_100"), Rect2(rk.position.x, lay.region.position.y + lay.region.size.y * 0.82, rk.size.x, 56.0 * k), k)
	for i in 4:
		var l: = _label("", TWTokens.TYPE_H2, TWSkin.c("PAPER_100"), lay.rows[i], k)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.position.x += float(ICON_PX) * k * 1.4
		l.size.x -= float(ICON_PX) * k * 1.4
		lb_rows.append(l)
	cta = _button("play", TWResultChain.TEXT.next, lay.cta)
	cta.pressed.connect(func() -> void: _press("next"))
	sec_map = _button("secondary", TWResultChain.TEXT.map, lay.map)
	sec_map.pressed.connect(func() -> void: _press("map"))
	sec_share = _button("secondary", TWResultChain.TEXT.share, lay.share)
	sec_share.pressed.connect(func() -> void:
		share_requested.emit()
		action.emit("share"))
	skip_btn = _button("secondary", TWResultChain.TEXT.skip, lay.skip)
	skip_btn.name = "Skip"
	skip_btn.pressed.connect(skip)
	skip_btn.visible = kind == TWResultChain.KIND_CHAIN
	run = TWResultChain.Run.new(plan.timeline)
	run.cue_sink = _on_cue
	_load_art()
	_ready_done = true
	set_process(not manual)
	_sync()


func _viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		return get_viewport().get_visible_rect().size
	return Vector2(720, 1280)


func _label(text: String, size: int, col: Color, r: Rect2, k: float) -> Label:
	var l: = TWDraw.label(text, "display" if size >= TWTokens.TYPE_H1 else "ui", TWTokens.font(size, minf(k, 1.5)), col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = r.position
	l.size = r.size
	l.visible = false
	add_child(l)
	return l


func _button(kind: String, text: String, r: Rect2) -> TWButton:
	var b: = TWButton.make(kind, text, r.size)
	b.position = r.position
	b.size = r.size
	b.visible = false
	add_child(b)
	return b


func _load_art() -> void:
	var hero: String = String(plan.view.hero)
	if hero == "":
		return
	var id: = "emotion:%s:happy" % hero
	if TWAssets.has(id):
		_art = TWAssets.tex(id)


# ── time ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	advance(delta)


func advance(dt: float) -> void:
	if run == null or life != Life.OPEN:
		return
	run.advance(dt)
	_sync()


func stage_tap() -> String:
	if run == null or life != Life.OPEN:
		return "none"
	var r: = run.tap()
	_sync()
	return r


func skip() -> void:
	if run == null or life != Life.OPEN:
		return
	run.skip()
	_sync()


func cta_ready() -> bool:
	return run != null and run.cta_ready()


func cta_alpha() -> float:
	if run == null:
		return 0.0
	var d: = float(TWResultChain.F_CTA_IN)
	return clampf((run.t - float(run.tl.cta_t)) / d, 0.0, 1.0)


func _on_cue(nm: String, data: Dictionary, skipped: bool) -> void:
	cue_log.append([run.t, nm, skipped])
	if skipped or audio == null:
		return
	if nm == "sting_stop" and audio.has_method("stop_cue"):
		audio.call("stop_cue", String(run.tl.sting))
	elif nm in [TWResultChain.STING_SHORT, TWResultChain.STING_LONG, "gem_fly", "coin_fly", "star"] and audio.has_method("play_cue"):
		audio.call("play_cue", nm, data)


func _closed(_r: Variant, _reason: String) -> void:
	if run != null and run.sting_playing() and audio != null and audio.has_method("stop_cue"):
		audio.call("stop_cue", String(run.tl.sting))


# ── buttons / back ─────────────────────────────────────────────────────────────────────────────────────────────────────────

func result_dict(act: String) -> Dictionary:
	return {"action": act, "kind": plan.kind, "milestones": plan.milestones, "stars": plan.stars, "t": run.t if run != null else 0.0}


func _press(act: String) -> void:
	if life != Life.OPEN or run == null:
		return
	if act == "next" and not run.cta_ready():
		return
	action.emit(act)
	close(result_dict(act), act)


func on_back() -> bool:
	if life != Life.OPEN or run == null:
		return true
	if not run.cta_ready():
		skip()
		return true
	_press("map")
	return true


# ── state -> nodes ──────────────────────────────────────────────────────────────────────────────────────────────────────────

func _sync() -> void:
	if not _ready_done or run == null:
		return
	var ready: = run.cta_ready()
	var a: = cta_alpha()
	var chain: bool = plan.kind == TWResultChain.KIND_CHAIN
	var last: = run.panel == run.n_panels() - 1
	var show_end: = ready and (last or not chain)
	cta.visible = show_end
	cta.modulate.a = a
	sec_map.visible = show_end
	sec_map.modulate.a = a
	sec_share.visible = show_end
	sec_share.modulate.a = a
	skip_btn.visible = chain
	_labels()
	if stage != null:
		stage.queue_redraw()


func _put(l: Label, text: String, alpha: float) -> void:
	l.visible = alpha > 0.01 and text != ""
	if l.text != text:
		l.text = text
		if text != "":
			texts_seen[text] = true
	l.modulate.a = alpha


static func ease_out(x: float) -> float:
	var c: = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


static func ease_back(x: float) -> float:
	var c: = clampf(x, 0.0, 1.0)
	var s: = 1.70158
	return 1.0 + (s + 1.0) * pow(c - 1.0, 3.0) + s * pow(c - 1.0, 2.0)


# alpha of panel i of the chain: in 0.24 s at its start, out 0.16 s before the next starts; the fast path has one panel
func panel_alpha(i: int) -> float:
	var p: Dictionary = run.tl.panels[i]
	var t: = run.t
	var t0: = float(p.t0)
	var tin: = TWTokens.T_IN if i > 0 else 0.0
	var a: = 1.0 if tin <= 0.0 else clampf((t - t0) / tin, 0.0, 1.0)
	var end: = float(p.end)
	if end < INF:
		a = minf(a, clampf((end - t) / TWTokens.T_OUT, 0.0, 1.0))
	return a if t >= t0 else 0.0


func fill_frac(from: float, to: float) -> float:
	var t0: = float(TWResultChain.F_FILL0) if plan.kind == TWResultChain.KIND_FAST else float(TWResultChain.C_PANEL * 2.0 + TWResultChain.C_FILL0)
	var ln: = float(TWResultChain.F_FILL_LEN) if plan.kind == TWResultChain.KIND_FAST else float(TWResultChain.C_FILL_LEN)
	return lerpf(from, to, ease_out((run.t - t0) / ln))


func fill_started() -> bool:
	var t0: = float(TWResultChain.F_FILL0) if plan.kind == TWResultChain.KIND_FAST else float(TWResultChain.C_PANEL * 2.0 + TWResultChain.C_FILL0)
	return run.t >= t0


func star_k(i: int) -> float:
	if plan.kind == TWResultChain.KIND_FAST:
		return ease_back((run.t - (TWResultChain.F_STAR0 + TWResultChain.F_STAR_STEP * i)) / TWResultChain.F_STAR_POP)
	return ease_back((run.t - (TWResultChain.C_STAR0 + TWResultChain.C_STAR_STEP * i)) / 0.4)


func row_k(i: int) -> float:
	if plan.kind == TWResultChain.KIND_FAST:
		return ease_out((run.t - (TWResultChain.F_FLY0 + TWResultChain.F_FLY_STEP * i)) / 0.2)
	return ease_out((run.t - (TWResultChain.C_PANEL + TWResultChain.C_ROW0 + TWResultChain.C_ROW_STEP * i)) / 0.3)


# the number a reward row has counted up to
func row_value(i: int) -> int:
	var n: int = int(plan.view.rows[i].n)
	if plan.kind == TWResultChain.KIND_FAST:
		return int(round(n * ease_out((run.t - (TWResultChain.F_FLY0 + TWResultChain.F_FLY_STEP * i)) / TWResultChain.F_FLY_LEN)))
	return int(round(n * ease_out((run.t - (TWResultChain.C_PANEL + TWResultChain.C_ROW0 + TWResultChain.C_ROW_STEP * i)) / TWResultChain.C_ROW_ROLL)))


func fly_k(i: int) -> float:
	if plan.kind != TWResultChain.KIND_FAST:
		return -1.0
	var k: = (run.t - (TWResultChain.F_FLY0 + TWResultChain.F_FLY_STEP * i)) / TWResultChain.F_FLY_LEN
	return k if k >= 0.0 and k < 1.0 else -1.0


func _labels() -> void:
	var v: Dictionary = plan.view
	var chain: bool = plan.kind == TWResultChain.KIND_CHAIN
	var t: = run.t
	var rows: Array = v.rows
	# title + milestone caption
	var title_a: = 0.0
	var cap_a: = 0.0
	var cap: = ""
	var ms: Array = plan.milestones
	if chain:
		title_a = ease_out((t - TWResultChain.C_SILENCE) / TWResultChain.F_TITLE_IN) * panel_alpha(0)
		cap_a = ease_out((t - TWResultChain.C_MILESTONE) / 0.3) * panel_alpha(0)
	else:
		title_a = ease_out((t - TWResultChain.F_SILENCE) / TWResultChain.F_TITLE_IN)
		cap_a = title_a if not ms.is_empty() else 0.0
	if not ms.is_empty():
		cap = TWResultChain.milestone_text(String(ms[0]), int(plan.wins_before))
	_put(lb_title, TWResultChain.TEXT.clear, title_a)
	if cap == "" and String(v.rank_title) != "":
		cap = TWResultChain.TEXT.rank_up % String(v.rank_title)
		cap_a = title_a
	_put(lb_caption, cap, cap_a)
	_put(lb_rewards, TWResultChain.TEXT.rewards if chain else "", panel_alpha(1) if chain else 0.0)
	_put(lb_rank, (TWResultChain.TEXT.rp % int(v.rp_gain)) if chain and int(v.rp_gain) > 0 else "", panel_alpha(1) if chain else 0.0)
	# reward rows (the fast path: a chip row under the stars; the chain: the list of panel 2)
	var ra: = 1.0 if not chain else panel_alpha(1)
	for i in 4:
		if i < rows.size() and ra > 0.0:
			var kk: = row_k(i)
			_put(lb_rows[i], "+%d" % row_value(i), ra * kk)
		else:
			_put(lb_rows[i], "", 0.0)
	# bond and Season XP
	var ba: = 1.0 if not chain else panel_alpha(2)
	var started: = fill_started()
	_put(lb_bond, (TWResultChain.TEXT.bond % int(v.bond_n)) if int(v.bond_n) > 0 and started else "", ba)
	_put(lb_xp, (TWResultChain.TEXT.xp % int(v.xp_n)) if int(v.xp_n) > 0 and started else "", ba)
	# the name of the heroine under her art (only when the art is a stand-in)
	if chain and _art == null and String(v.hero) != "":
		var r: Rect2 = lay.hero
		lb_hero.position = Vector2(r.position.x, r.position.y + r.size.y * 0.5 - 40.0)
		lb_hero.size = Vector2(r.size.x, 80.0)
		_put(lb_hero, String(TWTokens.hero(String(v.hero)).name), panel_alpha(2))
	else:
		_put(lb_hero, "", 0.0)


# ── paint ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

func paint(ci: CanvasItem) -> void:
	if run == null:
		return
	var v: Dictionary = plan.view
	var chain: bool = plan.kind == TWResultChain.KIND_CHAIN
	var k: float = lay.k
	var px: float = lay.star_px
	# stars (panel 1 of the chain, the one panel of the fast path)
	var sa: = panel_alpha(0)
	if sa > 0.0 and run.t >= (TWResultChain.C_SILENCE if chain else TWResultChain.F_SILENCE):
		var c: Vector2 = lay.stars_c
		var step: = px + float(STAR_GAP) * k
		for i in 3:
			var cc: = Vector2(c.x + (i - 1) * step, c.y)
			var earned: = i < int(v.stars)
			var kk: = star_k(i) if earned else ease_out((run.t - (TWResultChain.C_SILENCE if chain else TWResultChain.F_SILENCE)) / 0.3)
			_star(ci, cc, px * 0.5 * clampf(kk, 0.0, 1.4), earned, sa)
	# reward chips (fast) / list (chain panel 2)
	var rows: Array = v.rows
	var ra: = 1.0 if not chain else panel_alpha(1)
	for i in mini(rows.size(), 4):
		var r: Rect2 = lay.rows[i]
		var kk2: = row_k(i)
		if ra * kk2 <= 0.0:
			continue
		var ic: = Vector2(r.position.x + float(ICON_PX) * k * 0.6, r.position.y + r.size.y * 0.5)
		_icon(ci, String(rows[i].cur), ic, float(ICON_PX) * k * 0.5, ra * kk2)
		var f: = fly_k(i)
		if f >= 0.0:
			var p: = ic.lerp(lay.fly_to, ease_out(f))
			_icon(ci, String(rows[i].cur), p, float(ICON_PX) * k * 0.4 * (1.0 - 0.4 * f), 1.0 - f * f)
	# hero win-art (chain panel 3)
	if chain:
		var ha: = panel_alpha(2) * ease_out((run.t - (TWResultChain.C_PANEL * 2.0 + TWResultChain.C_HERO_IN)) / 0.6)
		if ha > 0.0:
			var hr: Rect2 = lay.hero
			if _art != null:
				var ts: = _art.get_size()
				var sc: = minf(hr.size.x / ts.x, hr.size.y / ts.y)
				var dr: = Rect2(hr.position + (hr.size - ts * sc) * 0.5, ts * sc)
				ci.draw_texture_rect(_art, dr, false, Color(1, 1, 1, ha))
			else:
				var acc: Color = TWTokens.hero(String(v.hero)).accent
				TWDraw.lacquer(ci, hr, float(TWTokens.R_LG), Color(acc, 0.55 * ha), Color(acc.darkened(0.3), 0.55 * ha), Color(acc.darkened(0.6), 0.6 * ha), ha)
	# bond bar and Season XP ring
	var ba: = 1.0 if not chain else panel_alpha(2)
	if ba > 0.0 and (int(v.bond_n) > 0 or int(v.xp_n) > 0):
		var br: Rect2 = lay.bond_bar
		var t0: = fill_started()
		if int(v.bond_n) > 0 and t0:
			_bar(ci, br, fill_frac(float(v.bond_from), float(v.bond_to)), float(v.bond_from), ba)
		if int(v.xp_n) > 0 and t0:
			_ring(ci, lay.ring_c, 40.0 * k, fill_frac(float(v.xp_from), float(v.xp_to)), ba)


func _star(ci: CanvasItem, c: Vector2, r: float, earned: bool, a: float) -> void:
	if r <= 1.0:
		return
	var pts: = PackedVector2Array()
	for i in 10:
		var ang: = -PI * 0.5 + TAU * i / 10.0
		var rr: = r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	if earned:
		var cols: = PackedColorArray()
		for p in pts:
			cols.append(Color(TWSkin.c("GOLD_300").lerp(TWSkin.c("GOLD_500"), clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)), a))
		ci.draw_polygon(pts, cols)
		var closed: = pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(TWSkin.c("GOLD_700"), a), 2.0, true)
	else:
		var closed2: = pts.duplicate()
		closed2.append(pts[0])
		ci.draw_polyline(closed2, Color(TWSkin.c("PAPER_700"), 0.7 * a), 3.0, true)


func _icon(ci: CanvasItem, cur: String, c: Vector2, r: float, a: float) -> void:
	if a <= 0.0:
		return
	match cur:
		"gems":
			var pts: = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
			ci.draw_polygon(pts, PackedColorArray([Color(TWSkin.c("ROSE_300"), a), Color(TWSkin.c("ROSE_500"), a), Color(TWSkin.c("ROSE_700"), a), Color(TWSkin.c("ROSE_500"), a)]))
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(TWSkin.c("GOLD_500"), a), 2.0, true)
		"tickets":
			var rr: = Rect2(c - Vector2(r, r * 0.65), Vector2(r * 2.0, r * 1.3))
			ci.draw_rect(rr, Color(TWSkin.c("JADE_500"), a))
			ci.draw_rect(rr, Color(TWSkin.c("JADE_300"), a), false, 2.0)
		_:
			ci.draw_circle(c, r, Color(TWSkin.c("GOLD_500"), a))
			ci.draw_arc(c, r * 0.72, 0.0, TAU, 24, Color(TWSkin.c("GOLD_700"), a), 2.0, true)


func _bar(ci: CanvasItem, r: Rect2, frac: float, base: float, a: float) -> void:
	ci.draw_rect(r, Color(TWSkin.c("NIGHT_700"), 0.9 * a))
	var w: = r.size.x * clampf(frac, 0.0, 1.0)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * base, r.size.y)), Color(TWSkin.c("ROSE_700"), a))
	if w > r.size.x * base:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x * base, 0), Vector2(w - r.size.x * base, r.size.y)), Color(TWSkin.c("ROSE_300"), a))
	ci.draw_rect(r, Color(TWSkin.c("GOLD_700"), 0.8 * a), false, 2.0)


func _ring(ci: CanvasItem, c: Vector2, r: float, frac: float, a: float) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(TWSkin.c("NIGHT_600"), a), 10.0, true)
	if frac > 0.0:
		ci.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 48, Color(TWSkin.c("JADE_300"), a), 10.0, true)


# the full-rect catcher under the buttons: a press that is not on a button is a stage tap
class _Stage extends Control:
	var modal: TWResultModal = null

	func _gui_input(e: InputEvent) -> void:
		var tap: = false
		if e is InputEventMouseButton:
			tap = (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		elif e is InputEventScreenTouch:
			tap = (e as InputEventScreenTouch).pressed
		if tap and modal != null:
			modal.stage_tap()
			accept_event()

	func _draw() -> void:
		if modal != null:
			modal.paint(self)
