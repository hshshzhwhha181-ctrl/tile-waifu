class_name V10WishScreen
extends "res://scripts/screens/summon.gd"

# V10WishScreen — «Желания» v2 (spec Г1–Г6, UX_RULES §3.4/§5/§6). It EXTENDS the 0.9 summon screen, so the
# three-stage lantern reveal (lantern → colour climb → cards → SSR showcase) is the same code, only fed by
# V10Gacha2 and dressed in v2 words: A / S / SSR, «Ещё N желаний до SSR», Созвездие ✦, Лепестки, Свеча.
#
# Banner page (magazine cover, UX_RULES §6.8): full-bleed key art, the banner card(s) in the lacquer frame on the
# right, overline + Playfair title on the left, one lacquer sheet with the SSR line, the promise line and the
# candelabra, then «Загадать ×1» (secondary) and «Загадать ×10» (primary, «Игра»). «ⓘ Шансы» in the sheet opens
# V10OddsScreen. Swipe switches banners (≤ 3, page dots). A spend that touches Лунный камень turns the button into
# the «Касса» class with the split, and every such spend (and crystals from 1000) goes through V10PullConfirm.
#
# Integrator: main.SCREENS["summon"] → this script (one line, hook H1 in README); dev acts: see dev_act().

const NAV_H: = 132.0
const SPINE_Y: = 224.0          # top of the page content under the header (the 0.9 tab spine is gone)

var gacha: V10Gacha2
var bank: V10GachaBank
var blist: Array = []
var bsel: = 0
var cur_b: Dictionary = {}
var page: Control
var candles_node: V10Candelabra
var odds_link: Control
var _drag_from: = Vector2.ZERO
var _dragging: = false
var _pull_res: Array = []          # v2 results of the running pull (same order as seq_res)
var _candles_before: = 0
var first_view: Control
var dev_no_first: = false
var dev_first_force: = false
var confirm: V10PullConfirm        # the open purchase confirmation (UX_RULES §5.2.6), if any
var left_steps: Array = []         # «Ещё N желаний до SSR» after each card of the running pull


static func make_gacha_for(state: Dictionary) -> V10Gacha2:
	var bk: = V10GachaBank.new(state)
	if is_same(state, G.S):
		bk.live_money = true
		bk.give_fn = func(id: String) -> bool: return G.give_new(id)
	return V10Gacha2.new(state, G.ITEMS, bk)


static func make_gacha() -> V10Gacha2:
	return make_gacha_for(G.S)


func build(m, args: Dictionary) -> void:
	gacha = make_gacha()
	bank = gacha.bank
	dev_no_first = bool(args.get("no_first", false))
	blist = gacha.banners()
	bsel = clampi(int(args.get("banner", 1 if blist.size() > 2 else 0)), 0, blist.size() - 1)
	if blist.size() > 2 and args.has("bid"):
		for i in blist.size():
			if String(blist[i].id) == String(args.bid):
				bsel = i
	super.build(m, args)
	if (gacha.first_needed() and not dev_no_first) or dev_first_force:
		_open_first_pick()


func _bind_v09_banner() -> void:
	# the 0.9 sequence reads G.BANNERS[banner_i] (voice line, colour); point it at a non-newbie banner of her
	var hero: = String(cur_b.get("hero", "mc"))
	banner_i = 1
	for i in G.BANNERS.size():
		if not G.BANNERS[i].get("newbie", false) and String(G.BANNERS[i].hero) == hero:
			banner_i = i


# ---------------------------------------------------------------- banner page
func _build_banner() -> void:
	if banner_root:
		banner_root.queue_free()
	blist = gacha.banners()
	bsel = clampi(bsel, 0, blist.size() - 1)
	cur_b = blist[bsel]
	_bind_v09_banner()
	banner_root = Control.new()
	banner_root.size = size
	banner_root.mouse_filter = Control.MOUSE_FILTER_PASS
	banner_root.gui_input.connect(_page_input)
	add_child(banner_root)
	circle.visible = false
	page = banner_root
	_art_layer()
	# one entry to the odds: «ⓘ Шансы» next to the wish buttons (С-5); the header keeps only «‹» until the
	# HUD v2 header puts «ⓘ Шансы» in its right slot (README, hook H1)
	var hdr: = V8Header.make(banner_root, main, "Желания", main.back)
	hdr.show_money(["tickets", "gems"])
	set_meta("v8_back", main.back)
	_title_block()
	_sheet()
	_dots()
	_buttons()


func _kind() -> String:
	return String(cur_b.get("kind", "std"))


func _accent() -> Color:
	return Color(String(cur_b.get("color", "e8c47e")))


func _art_layer() -> void:
	var k: = _kind()
	var bg_path: = String(cur_b.get("art", ""))
	if k == "phase":
		bg_path = "res://assets/v10/gacha/key_new_moon.webp" if String(cur_b.get("half", "A")) == "A" else "res://assets/v10/gacha/key_full_moon.webp"
	var focus: = Vector2(0.6, 0.35) if k == "newbie" else Vector2(0.5, 0.4)
	# the heroine's face never sits under the bar and the header (UX_RULES §2.2): her key art starts below them
	var top: = 0.0 if k == "phase" else (SPINE_Y - 40.0 if k == "newbie" else 0.0)
	var br: = V10Layout.bleed_rect(self)
	var bg: = V10GUI.cover(V10GUI.tex_or_null(bg_path), Rect2(Vector2(br.position.x, top), Vector2(br.size.x, br.end.y - top)), focus)
	banner_root.add_child(bg)
	if k == "phase":
		_phase_cards()
	# magazine shades: night from the left (typography) and from the bottom (sheet and buttons), top under the bar
	banner_root.add_child(V10GUI.shade(Rect2(0, 0, W * 0.75, H), Color(V10GUI.NIGHT_900, 0.78), Color(V10GUI.NIGHT_900, 0.0)))
	banner_root.add_child(V10GUI.shade(Rect2(0, H * 0.5, W, H * 0.5), Color(V10GUI.NIGHT_900, 0.0), Color(V10GUI.NIGHT_900, 0.97), true))
	banner_root.add_child(V10GUI.shade(Rect2(0, 0, W, 300), Color(V10GUI.NIGHT_900, 0.85), Color(V10GUI.NIGHT_900, 0.0), true))
	UI.pop_in(bg.get_node_or_null("Img") if bg.get_node_or_null("Img") else bg, 0.0, 0.97)


func _card_rect() -> Rect2:
	var top: = SPINE_Y + 36.0
	var bottom: = H - NAV_H - 360.0
	# the card never takes more than 58 % of the width (the title column keeps ≥ 40 %) and centres in the free band
	var h: = clampf(bottom - top, 380.0, 640.0)
	var w: = minf(h * 0.75, W * 0.58)
	h = w / 0.75
	var y: = top + maxf(0.0, (bottom - top - h) * 0.4)
	return Rect2(W - w - 18.0, y, w, h)


# phase A: one framed card; phase B: two fanned cards, the target in front (tap the back one to switch target)
func _phase_cards() -> void:
	var r: = _card_rect()
	var ssr: Array = cur_b.get("ssr", [])
	var tgt: = String(cur_b.get("target", ssr[0] if not ssr.is_empty() else ""))
	var col: = _accent()
	if V9Feel.can_fx():
		var ry: = Common.rays(banner_root, r.get_center(), r.size.y * 1.9, Color(col.r, col.g, col.b, 0.35), 10, 0.03, 0.45)
		ry.modulate.a = 0.85
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = r.get_center()
	glow.scale = Vector2(r.size.x / 44.0, r.size.y / 48.0)
	glow.modulate = Color(col, 0.55)
	banner_root.add_child(glow)
	if ssr.size() >= 2:
		var other: = String(ssr[1]) if tgt == String(ssr[0]) else String(ssr[0])
		var br: = Rect2(r.position + Vector2(-r.size.x * 0.34, r.size.y * 0.06), r.size * 0.84)
		var back: = _framed_card(other, br, -7.0, true)
		back.mouse_filter = Control.MOUSE_FILTER_STOP
		back.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_set_target(other, back))
		back.set_meta("ux_role", "secondary")
	var front: = _framed_card(tgt, r, 3.0, false)
	# one infinite UI animation on the screen: the card breathes (UX_RULES §6.7)
	if V9Feel.can_fx():
		var bt: = front.create_tween().set_loops()
		bt.tween_property(front, "scale", Vector2(1.012, 1.012), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bt.tween_property(front, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	UI.pop_in(front, 0.05, 0.9)


func _framed_card(id: String, r: Rect2, rot: float, dim: bool) -> Control:
	var it: Dictionary = G.ITEM.get(id, {})
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.rotation = deg_to_rad(rot)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_root.add_child(c)
	var pad: = r.size.x * 0.035
	if not it.is_empty():
		var art: = Common.card_art(G.art_tex(it), Rect2(Vector2(pad, pad), r.size - Vector2(pad, pad) * 2), Vector2(0.5, 0.3), 1.0, 10.0)
		(art.material as ShaderMaterial).set_shader_parameter("holo", 0.18 if not dim else 0.0)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.35)
		c.add_child(art)
	var fr: = V10GUI.icon(V10GUI.tex_or_null("res://assets/v10/gacha/banner_frame.png"), Rect2(Vector2.ZERO, r.size))
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	c.add_child(fr)
	if dim:
		c.modulate = Color(0.62, 0.6, 0.68)
	return c


func _set_target(id: String, node: Control) -> void:
	V9Feel.press(node, "select", "button")
	if not V10Banners.set_target(G.S, cur_b, id):
		return
	G.save()
	main.toast("Цель желания: %s" % _item_title(id), "star")
	_build_banner()


func _item_title(id: String) -> String:
	var it: Dictionary = G.ITEM.get(id, {})
	if it.is_empty():
		return id
	return "%s · %s" % [G.HEROES[it.hero].name, it.name] if it.has("hero") else String(it.name)


# page dots (HUD_V2 §8.4): up to 3 banners, the current one in gold; banners change by swipe. Not tappable, no
# words: the overline of each page says which banner it is (the old name spine cost 6 words and 3 taps on a hub).
func _dots() -> void:
	if blist.size() < 2:
		return
	var by: = H - NAV_H - 24.0 - 112.0
	var y: = by - 214.0 - 22.0
	for i in blist.size():
		var d: = Panel.new()
		var on: = i == bsel
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10GUI.GOLD_300 if on else Color(V10GUI.PAPER_500, 0.55)
		sb.set_corner_radius_all(4)
		d.add_theme_stylebox_override("panel", sb)
		d.size = Vector2(8, 8)
		d.position = Vector2(32 + i * 16, y)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.name = "Dot%d" % i
		banner_root.add_child(d)


func _switch(i: int, dir: = 0) -> void:
	if i < 0 or i >= blist.size() or i == bsel:
		return
	if dir == 0:
		dir = signi(i - bsel)
	bsel = i
	var old: = banner_root
	banner_root = null
	_build_banner()
	# «Тушь»/«Шёлк»: the old page slides out, the new one fades in from the swipe side (240 ms, QUINT OUT)
	if is_instance_valid(old):
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t: = old.create_tween().set_parallel()
		t.tween_property(old, "position:x", -dir * W * 0.25, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(old, "modulate:a", 0.0, 0.24)
		t.chain().tween_callback(old.queue_free)
	banner_root.position.x = dir * W * 0.12
	banner_root.modulate.a = 0.0
	var tn: = banner_root.create_tween().set_parallel()
	tn.tween_property(banner_root, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tn.tween_property(banner_root, "modulate:a", 1.0, 0.24)
	Sfx.play("whoosh", 1.25, -10.0)


func _page_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed:
			_drag_from = e.position
			_dragging = true
		elif _dragging:
			_dragging = false
			var d: Vector2 = e.position - _drag_from
			if absf(d.x) > 90.0 and absf(d.x) > absf(d.y) * 1.5:
				_switch(bsel + (1 if d.x < 0 else -1))


func _title_block() -> void:
	var k: = _kind()
	var x: = 32.0
	var y: = SPINE_Y + 40.0
	var col: = V10GUI.GOLD_500
	var over: = ""
	var title: = String(cur_b.get("name", ""))
	var sub: = String(cur_b.get("sub", ""))
	var t_now: = V10Banners.eff_now(G.S)
	match k:
		"phase":
			over = String(cur_b.name)
			var tid: = String(cur_b.get("target", ""))
			var it: Dictionary = G.ITEM.get(tid, {})
			title = String(it.get("name", cur_b.sub))
			sub = G.HEROES[it.hero].name if it.has("hero") else ""
		"newbie":
			over = "для новых гостей"
			sub = newbie_sub(bool(G.S.get("newbie_ssr", false)))
		_:
			# the overline already says «постоянные желания»: no second line with the same words
			over = "постоянные желания"
			sub = ""
	var ol: = V10GUI.overline(over, col)
	ol.position = Vector2(x, y)
	V10GUI.shadowed(ol, 0.9)
	banner_root.add_child(ol)
	# the newbie heroine's face sits at x ≈ 430–530: the column stays left of it with the 48 px margin (Г-1)
	var maxw: = (_card_rect().position.x - 44.0) if k == "phase" else (340.0 if k == "newbie" else W * 0.62)
	var fs: = 56
	while fs > 34 and UI.longest_word_w(title, fs, "title", 700) > maxw:
		fs -= 2
	var tl: = V10GUI.h1(title, fs)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.size = Vector2(maxw, 10)
	tl.position = Vector2(x - 2, y + 22)
	V10GUI.shadowed(tl, 0.85)
	banner_root.add_child(tl)
	var th: = tl.get_minimum_size().y
	var yy: = y + 26 + th
	if sub != "":
		var sl: = V10GUI.lbl(sub, 24, V10GUI.PAPER_300, "body", 800)
		if k != "phase":
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sl.size = Vector2(maxw, 10)
		sl.position = Vector2(x, yy)
		V10GUI.shadowed(sl, 0.85)
		banner_root.add_child(sl)
		if k == "phase":
			var pill: = V10GUI.rar_pill("SSR", 30)
			pill.position = Vector2(x + sl.get_minimum_size().x + 12, yy + 1)
			banner_root.add_child(pill)
		yy += maxf(40.0, sl.get_minimum_size().y + 8)
	if k == "phase":
		var until: = V10GClock.until_text(int(cur_b.end), t_now)
		var dl: = V10GUI.lbl(until, 18, V10GUI.PAPER_500 if not V10Banners.countdown_visible(cur_b, t_now) else V10GUI.ROSE_300, "body", 700)
		dl.position = Vector2(x, yy)
		V10GUI.shadowed(dl, 0.85)
		banner_root.add_child(dl)
		yy += 34
		if (cur_b.get("ssr", []) as Array).size() >= 2:
			var hint: = V10GUI.lbl("Коснись — сменить цель", 18, V10GUI.GOLD_300, "body", 800)
			hint.position = Vector2(x, yy)
			V10GUI.shadowed(hint, 0.85)
			banner_root.add_child(hint)
	var nodes: = [ol, tl]
	for n in nodes:
		UI.slide_in(n, Vector2(-16, 0), 0.04 * nodes.find(n), 0.24)


# the newbie promise (spec Г4): the SSR outfit is promised once; after it came, only the discount is left
static func newbie_sub(ssr_done: bool) -> String:
	return "Скидка: 120 кристаллов вместо 150" if ssr_done else "SSR-наряд, которого у тебя нет, — до 50-го желания"


func _sheet() -> void:
	var k: = _kind()
	var by: = H - NAV_H - 24.0 - 112.0
	var r: = Rect2(24, by - 214, W - 48, 196)
	var sh: = V10GUI.sheet(r, 0.86)
	banner_root.add_child(sh)
	var left: = gacha.pity_left(cur_b)
	var gold: = left <= 10
	# line 1: «Ещё 23 желания до SSR» (gold from 10 and below) with a thin bar
	var unit: = V10GachaBank.plural(left, "желание", "желания", "желаний")
	var l1: = V10GUI.lbl("Ещё %d %s до SSR" % [left, unit], 24, V10GUI.GOLD_300 if gold else V10GUI.PAPER_100, "body", 900)
	l1.position = Vector2(20, 14)
	sh.add_child(l1)
	var hard: = V10Rates.HARD
	if k == "newbie" and not bool(G.S.get("newbie_ssr", false)):
		hard = mini(hard, gacha.pity(cur_b) + left)
	var bar: = V10GUI.line_bar(Rect2(20, 52, r.size.x * 0.56, 3), 1.0 - float(left) / float(hard), V10GUI.GOLD_500 if gold else V10GUI.JADE_300)
	sh.add_child(bar)
	# line 2: the promise in plain words (UX_RULES §4.2, §9 P0-5)
	var l2t: = ""
	match k:
		"phase":
			l2t = "Следующая SSR — героиня баннера ✓" if gacha.guar(cur_b) else V10Rates.featured_line()
		"newbie":
			l2t = "Осталось %d из 50 по 120 кристаллов" % gacha.newbie_left()
		_:
			l2t = "SSR — не позже 60-го желания"
	if l2t != "":
		var l2: = V10GUI.lbl(l2t, 18, V10GUI.GOLD_300 if gacha.guar(cur_b) and k == "phase" else V10GUI.PAPER_300, "body", 700)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size = Vector2(r.size.x * 0.6, 10)
		l2.position = Vector2(20, 66)
		sh.add_child(l2)
	# candelabra + «Свечи: 137/200» on the right; at 200 the line becomes the quiet «Зажечь Свечу ›»
	var cw: = r.size.x * 0.36
	candles_node = V10Candelabra.new()
	candles_node.size = Vector2(cw, 96)
	candles_node.position = Vector2(r.size.x - cw - 12, 4)
	candles_node.set_count(int(G.S.candles))
	sh.add_child(candles_node)
	if gacha.can_spark():
		var sl: = V10GUI.link("Зажечь Свечу ›", Vector2(0, 100), func(): _open_spark(), V10GUI.GOLD_300, 18)
		sl.position.x = r.size.x - 12 - cw * 0.5 - sl.size.x * 0.5
		sl.name = "SparkLink"
		sh.add_child(sl)
	else:
		var cl: = V10GUI.lbl("Свечи: %d/%d" % [mini(int(G.S.candles), V10Rates.SPARK), V10Rates.SPARK], 18, V10GUI.PAPER_300, "body", 800)
		UI.center_label(cl, Rect2(r.size.x - cw - 12, 100, cw, 26))
		sh.add_child(cl)
	# «ⓘ Шансы» (UX_RULES §5.3.5, С-5): next to the random purchase, one tap to V10OddsScreen
	odds_link = V10GUI.link("ⓘ Шансы", Vector2(8, r.size.y - 84), func(): _open_odds(), V10GUI.GOLD_500, 18)
	sh.add_child(odds_link)
	UI.slide_in(sh, Vector2(0, 24), 0.08, 0.24)


func _buttons() -> void:
	var by: = H - NAV_H - 24.0 - 112.0
	var k: = _kind()
	if k != "newbie":
		pull1_btn = _pull_button(1, Rect2(24, by, 216, 112), "Загадать ×1", "glass")
		pull1_btn.set_meta("ux_role", "secondary")
		banner_root.add_child(pull1_btn)
		UI.slide_in(pull1_btn, Vector2(0, 40), 0.1, 0.24)
	# the primary is ≥ 440 × 104 (UX_RULES §6.1); one blik on the screen (its shine), no pulse: the breathing
	# banner card is the screen's one infinite animation
	var r10: = Rect2(W - 24 - 440, by, 440, 112) if k != "newbie" else Rect2(24, by, W - 48, 112)
	pull10_btn = _pull_button(10, r10, "Загадать ×10", "pink")
	pull10_btn.set_meta("ux_role", "primary")
	banner_root.add_child(pull10_btn)
	UI.slide_in(pull10_btn, Vector2(0, 40), 0.14, 0.24)


# a wish button: «Игра» (pal) while tickets and crystals pay; the «Касса» class with the split as soon as the
# spend touches Лунный камень (UX_RULES §5.3.7). The tap goes through _pull → V10PullConfirm when it must ask.
func _pull_button(n: int, r: Rect2, text: String, pal: String, act: = Callable()) -> JButton:
	var sp: = gacha.split(cur_b, n)
	var b: JButton
	if int(sp.get("moon", 0)) > 0 and bool(sp.get("ok", false)):
		var rest: = spend_text(sp, false)
		b = V10GUI.kassa_button(text, "%s Лунного камня" % V10Rates.group(int(sp.moon)), r, ("+ " + rest) if rest != "" else "")
	else:
		b = JButton.make(text, pal, r, null, 24)
		_cost_line(b, n, sp)
		if pal == "pink":
			b.shine_every = 2.8
	# the quiet button sounds softer than the primary (UX_RULES §7, З-2)
	b.sound = "pop" if pal == "pink" else "tap"
	if not act.is_valid():
		act = func(): _pull(n)
	b.pressed.connect(act)
	# a refused tap runs the same path, which says why (toast); seq is open only on the results screen
	b.set_gate(func(): return gacha.can_pull(cur_b, n), act)
	return b


func _cost_line(btn: JButton, n: int, sp: Dictionary) -> void:
	if int(sp.tickets) >= n:
		btn.set_cost(V8Art.cur("ticket"), n, 20)
	elif int(sp.tickets) > 0:
		btn.set_sub(spend_text(sp), 20)
	else:
		btn.set_cost(V8Art.cur("gem"), gacha.cost(cur_b, n), 20)


# «3 билета + 1 050 кристаллов» (every number with its unit, UX_RULES §4.1.3); moon = false leaves Лунный камень
# out (the «Касса» shows it on its own line)
static func spend_text(sp: Dictionary, moon: = true) -> String:
	var parts: = []
	var t: = int(sp.get("tickets", 0))
	var g: = int(sp.get("gems", 0))
	var m: = int(sp.get("moon", 0))
	if t > 0:
		parts.append("%d %s" % [t, V10GachaBank.plural(t, "билет", "билета", "билетов")])
	if g > 0:
		parts.append("%s %s" % [V10Rates.group(g), V10GachaBank.plural(g, "кристалл", "кристалла", "кристаллов")])
	if moon and m > 0:
		parts.append("%s Лунного камня" % V10Rates.group(m))
	return " + ".join(parts)


# ---------------------------------------------------------------- pulling
func _pull_cost(n: int) -> int:
	return gacha.cost(cur_b, n)


func _can_pull(n: int) -> bool:
	return seq != null or gacha.can_pull(cur_b, n)


func _pull(n: int) -> void:
	if seq != null or (confirm != null and is_instance_valid(confirm) and not confirm.is_queued_for_deletion() and confirm.mouse_filter != Control.MOUSE_FILTER_IGNORE):
		return
	if not gacha.can_pull(cur_b, n):
		V9Feel.deny(pull1_btn if n == 1 and is_instance_valid(pull1_btn) else pull10_btn)
		var sm: = V10ShopHub.model()
		if sm != null and main != null:
			var sp0: = gacha.split(cur_b, n)
			var defc: = maxi(1, (n - int(sp0.tickets)) * gacha.unit_cost(cur_b) - int(sp0.gems) - int(sp0.moon))
			var top_cb: = func() -> void:
				if V10Nav.tab_open("shop"):
					main.go("shop", {"tab": 2})
				else:
					main.toast(V10Nav.tab_lock_text("shop"), "lock")
			V10ShopFlow.need(self, sm, defc, top_cb, V10ShopHub.go_free_cb(main))
		elif main != null:
			main.toast("Не хватает кристаллов: задания дня и Путь дают ещё", "gem")
		return
	var sp: = gacha.split(cur_b, n)
	if V10PullConfirm.needed(sp, G.S):
		confirm = V10PullConfirm.open(_overlay(), {"n": n, "sp": sp, "banner_name": String(cur_b.get("name", "")),
			"title": "Загадать ×%d" % n}, func(): _pull_go(n), func(): _open_odds())
		return
	_pull_go(n)


# playtest / demo: press «Загадать» on an open confirmation sheet (main.gd --pt, README hook H1)
func demo_confirm() -> bool:
	if confirm == null or not is_instance_valid(confirm) or confirm.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	confirm._yes()
	return true


func _pull_go(n: int) -> void:
	if seq != null or not gacha.can_pull(cur_b, n):
		return
	var ctx: = {"pity": gacha.pity(cur_b), "guar": gacha.guar(cur_b), "newbie_left": gacha.newbie_left(),
		"newbie_ssr": bool(G.S.get("newbie_ssr", false)), "skip": V9Summon.can_skip(int(G.S.pulls)),
		"left": gacha.pity_left(cur_b)}
	_candles_before = int(G.S.candles)
	var res: = gacha.pull(cur_b, n)
	if res.is_empty():
		return
	G.save()
	main.refresh_currency(true)
	last_n = n
	_play(res, ctx)


func _play(res: Array, ctx: Dictionary) -> void:
	_pull_res = res
	var r09: = res.map(func(r): return to09(r))
	_sequence(r09, ctx)


static func to09(r: Dictionary) -> Dictionary:
	var it: Dictionary = r.get("item", G.ITEM.get(String(r.get("id", "")), {}))
	var o: Dictionary = it.duplicate()
	o["rar"] = V10Gacha2.rar09(String(r.rar))
	o["new"] = bool(r.get("new", false))
	o["v10"] = r
	return o


func _sequence(res: Array, ctx: = {}) -> void:
	super._sequence(res, ctx)
	# the 0.9 sequence set its pity/guarantee tracks from the 0.9 counters before its first await: replace them
	var p: = int(ctx.get("pity", 0))
	var nl: = int(ctx.get("newbie_left", 0))
	var nssr: = bool(ctx.get("newbie_ssr", true))
	pity_steps = []
	guar_steps = []
	left_steps = []
	for i in res.size():
		var v: Dictionary = res[i].get("v10", {})
		p = int(v.get("pity", p))
		pity_steps.append(p)
		guar_steps.append(bool(v.get("guar", false)))
		# the newbie SSR promise counts down with the wishes left, until its SSR came (spec Г4)
		if String(v.get("rar", "")) == "SSR":
			nssr = true
		var left: = V10Rates.HARD - p
		if _kind() == "newbie" and not nssr:
			left = mini(left, nl - (i + 1))
		left_steps.append(maxi(1, left))


# the guarantee panel (HUD_V2 §8.4, UX_RULES P2-24): hidden during the ritual (lantern, colour climb); it slides
# in with the first turned card and ticks per card from there
func _build_top_hud() -> void:
	top_hud = Control.new()
	top_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud.visible = false
	seq.add_child(top_hud)
	var box: = V10GUI.sheet(Rect2(20, 18, 420, 96), 0.82)
	top_hud.add_child(box)
	var left: = int(seq_ctx.get("left", V10Rates.HARD - int(seq_ctx.get("pity", 0))))
	pity_num = V10GUI.lbl(_left_text(left), 24, V10GUI.PAPER_100, "body", 900)
	pity_num.position = Vector2(14, 6)
	box.add_child(pity_num)
	pity_bar = null
	var bar: = V10GUI.line_bar(Rect2(14, 44, 390, 3), 1.0 - float(left) / V10Rates.HARD, V10GUI.GOLD_500)
	bar.name = "Bar"
	box.add_child(bar)
	guar_lbl = V10GUI.lbl("", 18, V10GUI.PAPER_300, "body", 800)
	guar_lbl.position = Vector2(14, 56)
	box.add_child(guar_lbl)
	if _kind() == "newbie":
		guar_lbl.text = "SSR-наряд — до 50-го желания" if not bool(seq_ctx.get("newbie_ssr", true)) else "120 кристаллов вместо 150"
	elif _kind() == "phase":
		_set_guar(bool(seq_ctx.get("guar", false)))
	else:
		guar_lbl.text = "Пять ветров · все постоянные наряды"


func _show_top_hud() -> void:
	if top_hud == null or not is_instance_valid(top_hud) or top_hud.visible:
		return
	top_hud.visible = true
	UI.slide_in(top_hud, Vector2(0, -30), 0.0)


func _left_text(left: int) -> String:
	return "Ещё %d %s до SSR" % [left, V10GachaBank.plural(left, "желание", "желания", "желаний")]


func _set_guar(g: bool) -> void:
	if guar_lbl == null or not is_instance_valid(guar_lbl) or _kind() != "phase":
		return
	guar_lbl.text = "Следующая SSR — героиня баннера ✓" if g else V10Rates.featured_line()
	guar_lbl.label_settings.font_color = V10GUI.GOLD_300 if g else V10GUI.PAPER_300


func _tick_pity(i: int) -> void:
	if i < 0 or i >= pity_steps.size() or pity_num == null or not is_instance_valid(pity_num):
		return
	_show_top_hud()
	var left: int = left_steps[i] if i < left_steps.size() else V10Rates.HARD - int(pity_steps[i])
	pity_num.text = _left_text(left)
	var bar: Control = pity_num.get_parent().get_node_or_null("Bar")
	var hard: = mini(V10Rates.HARD, int(pity_steps[i]) + left)
	V10GUI.set_bar(bar, 1.0 - float(left) / float(maxi(1, hard)))
	if String(seq_res[i].get("rar", "R")) == "SSR":
		UI.punch(pity_num, 0.3, 0.4)
		Fx.burst(top_hud, Vector2(90, 40), "sparkle", 18, V9Summon.COL.SSR, 0.6)
		_set_guar(guar_steps[i])
	else:
		UI.punch(pity_num, 0.08, 0.2)


const LANTERN_NAME: = {"R": "Нефритовый фонарь", "SR": "Лавандовый фонарь", "SSR": "Золотой фонарь"}
const LANTERN_SUB: = {"R": "Тихий свет · A", "SR": "Редкий свет · S", "SSR": "Сияние · SSR"}

func _show_caption(best: String) -> void:
	super._show_caption(best)
	if is_instance_valid(lantern_cap) and lantern_cap.get_child_count() >= 2:
		(lantern_cap.get_child(1) as Label).text = LANTERN_SUB.get(best, "")


# ---------------------------------------------------------------- cards: A/S/SSR, ✦ and Лепестки
func _card(r: Dictionary, sz: Vector2) -> Control:
	var c: = super._card(r, sz)
	var v: Dictionary = r.get("v10", {})
	var front: Control = c.get_node("Front")
	var rt: = front.get_node_or_null("Rar")
	if rt:
		for ch in rt.get_children():
			if ch is Label:
				(ch as Label).text = V10Gacha2.rar10(String(r.rar))
	# one mark per card (UX_RULES §9 P0-6, §3.6.6): no «НОВОЕ» sticker, no 0.9 «+25» gem tag; a repeat shows only
	# what it became (✦ or Лепестки) and gives up its rarity pill for it (the frame keeps the rarity colour)
	for nm in ["Dup", "New"]:
		var old: = front.get_node_or_null(nm)
		if old:
			front.remove_child(old)
			old.queue_free()
	if v.is_empty() or bool(v.get("new", false)):
		return c
	var small: = sz.x < 200
	var h: = 30.0 if small else 38.0
	var txt: = ""
	var col: = V10GUI.LAV
	var ico: Texture2D = null
	if bool(v.get("star_up", false)):
		txt = "✦%d" % int(v.star)
	elif int(v.get("petals", 0)) > 0:
		txt = "+%d" % int(v.petals)
		col = V10GUI.ROSE_300
		ico = G.fx("petal")
	if txt == "":
		return c
	if rt:
		rt.visible = false
	var f: = UI.font("body", 900)
	var fs: = 18 if small else 22
	var iw: = h * 0.8 if ico else 0.0
	var w: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + h * 0.8 + iw
	var p: = Panel.new()
	p.name = "Dup2"
	p.position = Vector2(-8, -14) if small else Vector2(-12, -12)
	p.size = Vector2(w, h)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(V10GUI.NIGHT_900, 0.92)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.border_color = col
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ico:
		var ic: = V10GUI.icon(ico, Rect2(h * 0.25, h * 0.1, iw, h * 0.8))
		ic.modulate = V10GUI.ROSE_300
		p.add_child(ic)
	var l: = V10GUI.lbl(txt, fs, col, "body", 900)
	UI.center_label(l, Rect2(iw * 0.6, -1, w - iw * 0.6, h))
	p.add_child(l)
	front.add_child(p)
	return c


func _flip(c: Control, r: Dictionary) -> void:
	await super._flip(c, r)
	var v: Dictionary = r.get("v10", {})
	if v.is_empty() or not is_instance_valid(c) or not _alive():
		return
	if bool(v.get("star_up", false)):
		_star_fly(c, int(v.star))
	elif int(v.get("petals", 0)) > 0:
		Fx.burst(seq, c.position + c.size * 0.5, "petal", 10, V10GUI.ROSE_300, 0.6)
		Sfx.play("star1", 1.3, -10.0)


# a lavender ✦ rises out of a duplicate card and lands in its corner badge: the Constellation grows
func _star_fly(c: Control, lv: int) -> void:
	var s: = V10GUI.lbl("✦", 64, V10GUI.LAV, "body", 900, Color(0.2, 0.1, 0.35, 0.9), 6)
	s.size = Vector2(64, 80)
	s.pivot_offset = Vector2(32, 40)
	var from: = c.position + c.size * Vector2(0.5, 0.45) - Vector2(32, 40)
	s.position = from
	seq.add_child(s)
	var badge: Control = c.get_node("Front").get_node_or_null("Dup2")
	var to: = c.position + (badge.position + badge.size * 0.5 if badge else Vector2(20, 0)) - Vector2(32, 40)
	s.scale = Vector2(0.4, 0.4)
	var t: = s.create_tween()
	t.tween_property(s, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "position", from - Vector2(0, 50), 0.18)
	t.tween_property(s, "position", to, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "scale", Vector2(0.45, 0.45), 0.32)
	t.tween_callback(func():
		Sfx.play("star%d" % clampi(lv - 2, 0, 2), 1.0 + 0.08 * lv, -4.0)
		if badge:
			UI.punch(badge, 0.35, 0.3)
		Fx.burst(seq, to + Vector2(32, 40), "sparkle", 12, V10GUI.LAV, 0.5))
	t.tween_property(s, "modulate:a", 0.0, 0.15)
	t.tween_callback(s.queue_free)


func _showcase(r: Dictionary) -> void:
	var v: Dictionary = r.get("v10", {})
	var call_done: = [false]
	_showcase_base(r, call_done)
	var node: = showcase
	if is_instance_valid(node):
		_showcase_extras(node, r, v)
	while not call_done[0] and is_inside_tree():
		await get_tree().process_frame


func _showcase_base(r: Dictionary, done: Array) -> void:
	await super._showcase(r)
	done[0] = true


func _showcase_extras(node: Control, r: Dictionary, v: Dictionary) -> void:
	# 0.10 words: «Ульта» is «Приём» (UX_RULES §4.2)
	var new_t: = V6Txt.s("common.new")
	for l in node.find_children("*", "Label", true, false):
		var lb: = l as Label
		if lb.text.begins_with("Ульта «"):
			lb.text = lb.text.replace("Ульта «", "Приём «")
		elif lb.text == new_t and lb.get_parent() is Control and lb.get_parent() != node:
			# the 0.9 red «НОВОЕ» plate over the showcase (UX_RULES §3.6.6: such stickers are gone)
			(lb.get_parent() as Control).visible = false
	# the hanko: «Сбылось» on the banner's heroine, «Свеча» on a candle exchange, «Твоя» on the first pick
	var seal: = ""
	if bool(v.get("spark", false)):
		seal = "СВЕЧА"
	elif bool(v.get("first", false)):
		seal = "ТВОЯ"
	elif bool(v.get("featured", false)) and String(r.rar) == "SSR":
		seal = "СБЫЛОСЬ"
	if seal != "":
		var tw: = node.create_tween()
		tw.tween_interval(0.75)
		tw.tween_callback(func():
			if is_instance_valid(node):
				V10GUI.hanko(node, Vector2(W - 120, H * 0.42 + 150), seal, 136, -10.0))
	var lv: = int(v.get("star", 0))
	if lv >= 1 and V10Stars.is_outfit(r):
		var row: = _star_row(lv, bool(v.get("star_up", false)))
		row.position = Vector2((W - row.size.x) * 0.5, H - 160)
		node.add_child(row)
		UI.pop_in(row, 0.9, 0.8)


func _star_row(lv: int, up: bool) -> Control:
	var row: = Control.new()
	row.size = Vector2(5 * 44 + 160, 44)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: = V10GUI.lbl("Созвездие", 20, V10GUI.PAPER_300, "body", 800)
	l.position = Vector2(0, 8)
	row.add_child(l)
	for i in 5:
		var on: = i < lv
		var s: = V10GUI.lbl("✦", 34, V10GUI.LAV if on else V10GUI.PAPER_700, "body", 900)
		s.position = Vector2(150 + i * 44, -2)
		row.add_child(s)
		if up and i == lv - 1:
			s.pivot_offset = Vector2(14, 22)
			UI.pop_in(s, 1.2, 2.2)
	return row


func _results(res: Array) -> void:
	results_shown = true
	_show_top_hud()
	var by: = H - 170.0
	var n: = res.size()
	# UX_RULES §5.2.7: after the result «Готово» is the primary (≥ 440 wide), «Ещё ×N» the quiet secondary; a spend
	# that touches Лунный камень is a «Касса» and is confirmed (it goes through _pull)
	var ok: = JButton.make("Готово", "pink", Rect2(W - 464, by, 440, 112), null, 28)
	ok.set_meta("ux_role", "primary")
	ok.pressed.connect(_close_seq)
	seq.add_child(ok)
	blist = gacha.banners()
	var still: = bsel < blist.size() and String(blist[bsel].id) == String(cur_b.id)
	if still:
		# the sequence closes first, so a confirmation sheet opens over the banner, never over the results
		var again: = _pull_button(n, Rect2(24, by, W - 504, 112), "Ещё ×%d" % n, "glass", func():
			_close_seq()
			_pull(n))
		again.set_meta("ux_role", "secondary")
		seq.add_child(again)
		UI.slide_in(again, Vector2(0, 60), 0.08)
	UI.slide_in(ok, Vector2(0, 60), 0.0)
	var ttl: = V10GUI.overline("итог желаний", V10GUI.GOLD_500)
	UI.center_label(ttl, Rect2(0, 130, W, 30))
	seq.add_child(ttl)
	# summary chips: what the duplicates became + the candles, cascading on the pentatonic
	var stars: = 0
	var petals: = 0
	var gems: = 0
	for r in _pull_res:
		if bool(r.get("star_up", false)):
			stars += 1
		petals += int(r.get("petals", 0))
		gems += int(r.get("gems", 0))
	var chips: = []
	if stars > 0:
		chips.append(V10GUI.chip("Созвездие +%d ✦" % stars, null, 40, V10GUI.LAV))
	if petals > 0:
		chips.append(V10GUI.chip("+%d %s" % [petals, V10GachaBank.plural(petals, "Лепесток", "Лепестка", "Лепестков")], null, 40, V10GUI.ROSE_300))
	if gems > 0:
		chips.append(V10GUI.chip("+%d" % gems, V8Art.cur("gem"), 40, V10GUI.GOLD_300))
	# the candles chip is a small live candelabra: the new candles light up in it, one note each
	var cc: = V10GUI.sheet(Rect2(0, 0, 190, 40), 0.9)
	var cd: = V10Candelabra.new()
	cd.size = Vector2(96, 42)
	cd.position = Vector2(6, -6)
	cd.set_count(_candles_before)
	cc.add_child(cd)
	var cl: = V10GUI.lbl("%d/%d" % [mini(int(G.S.candles), V10Rates.SPARK), V10Rates.SPARK], 20, V10GUI.PAPER_300, "body", 900)
	cl.position = Vector2(102, 6)
	cc.add_child(cl)
	chips.append(cc)
	if _candles_before / V10Candelabra.PER < mini(10, int(G.S.candles) / V10Candelabra.PER):
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(cd):
				cd.animate_to(int(G.S.candles)))
	else:
		cd.set_count(int(G.S.candles))
	# one row when it fits the width, otherwise two rows (narrow phones, long numbers)
	var rows: = [[]]
	var rw: = 0.0
	for c in chips:
		if rw + c.size.x > W - 32.0 and not rows[-1].is_empty():
			rows.append([])
			rw = 0.0
		rows[-1].append(c)
		rw += c.size.x + 10
	for ri in rows.size():
		var tw: = 0.0
		for c in rows[ri]:
			tw += c.size.x + 10
		var x: = (W - tw + 10) * 0.5
		for c in rows[ri]:
			c.position = Vector2(x, by - 64 - (rows.size() - 1 - ri) * 52)
			x += c.size.x + 10
			seq.add_child(c)
	V10GUI.cascade(chips, 0.2)


func _close_seq() -> void:
	super._close_seq()
	circle.visible = false
	var st: = V10Banners.state(G.S)
	if bool(st.get("guest_done", false)) and not bool(st.get("guest_seen", false)):
		st["guest_seen"] = true
		G.save()
		V10GuestScene.open(self, main)


# ---------------------------------------------------------------- odds, spark, first pick
func _open_odds() -> void:
	V10OddsScreen.open(_overlay(), gacha, cur_b)


func _overlay() -> Control:
	return main.overlay if main != null and "overlay" in main and main.overlay != null else self


func _open_spark() -> void:
	V10SparkSheet.open(_overlay(), gacha, func(id: String):
		var r: = gacha.spark(id)
		if r.is_empty():
			return
		G.save()
		await _ceremony(to09(r)))


# a showcase outside the pull sequence (Свеча, первая SSR): the chrome steps aside like during a pull
func _ceremony(r09: Dictionary) -> void:
	main.show_chrome(false, false)
	await _showcase(r09)
	main.show_chrome(true, true)
	main.refresh_currency()
	_build_banner()


func _open_first_pick() -> void:
	first_view = V10FirstPickView.open(_overlay(), gacha, func(r: Dictionary):
		G.set_meta("first_ssr_session", true)
		G.save()
		await _ceremony(to09(r))
		_ask_partner(r))


func _ask_partner(r: Dictionary) -> void:
	var it: Dictionary = r.get("item", {})
	if it.is_empty() or not it.has("hero"):
		return
	var hero: = String(it.hero)
	var nm: = String(G.HEROES[hero].name)
	var yes_cb: = func() -> void:
		G.S["partner"] = hero
		G.S["level_partner"] = hero
		if not (G.S.get("outfit") is Dictionary):
			G.S["outfit"] = {}
		G.S.outfit[hero] = String(it.id)
		V10Look.notify()
		V10HudSkin.sync(V10Look.current())
		G.save()
		if main and main.has_method("toast"):
			main.toast("%s — твой партнёр" % nm, "heart")
		if main and main.has_method("go"):
			main.go("collection", {"hero": hero})
	V10AskSheet.open(_overlay(), "Сделать партнёром?", "%s в наряде «%s» будет встречать тебя в Чайной и выходить с тобой за стол." % [nm, it.name],
		"Сделать партнёром", "Позже", yes_cb, Callable(), G.art_tex(it))


# ---------------------------------------------------------------- dev / playtest
# v2 dev acts (main.gd --act=…): v2_ssr10 / v2_sr10 / v2_r10 / v2_ssr1 = preview pull with v2 cards (✦, petals),
# nothing given; b<i> = banner i; odds; spark (gives 200 candles in memory); first = first pick view
func dev_act(a: String) -> void:
	if a.begins_with("v2_"):
		var key: = a.substr(3)
		var nn: = 10 if key.ends_with("10") else 1
		var best: = key.trim_suffix("10").trim_suffix("1").to_upper()
		dev_preview = true
		var fake: = dev_results_v2(nn, best)
		_pull_res = fake
		_candles_before = int(G.S.candles)
		_sequence(fake.map(func(r): return to09(r)), {"pity": 30, "left": 30, "guar": false, "skip": dev_second})
	elif a.begins_with("b") and a.length() <= 3 and a.substr(1).is_valid_int():
		_switch(int(a.substr(1)))
	elif a == "odds":
		_open_odds()
	elif a == "spark":
		_open_spark()
	elif a == "first":
		_open_first_pick()
	else:
		super.dev_act(a)


func dev_results_v2(n: int, best: String) -> Array:
	var base: = V9Summon.dev_results(n, best, G.BANNERS[banner_i])
	var out: = []
	for i in base.size():
		var it: Dictionary = base[i]
		var rar: = V10Gacha2.rar10(String(it.rar))
		var r: = {"rar": rar, "id": String(it.id), "item": G.ITEM.get(String(it.id), it), "new": bool(it.get("new", false)),
			"star": 0, "star_up": false, "petals": 0, "gems": 0, "featured": rar == "SSR", "pity": 30 + i, "guar": false}
		if not r.new:
			if String(it.get("cat", "")) == "outfit":
				r.star = 2 + (i % 3)
				r.star_up = true
			else:
				r.gems = 25
				r.petals = 2 if rar == "A" else 6
		elif String(it.get("cat", "")) == "outfit":
			r.star = 1
		out.append(r)
	return out
