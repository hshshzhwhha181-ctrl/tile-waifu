class_name V10PassScreen
extends Control

# V10PassScreen — «Пропуск сезона» (spec 0.10 Л5, UX §5, HUD_V2 §8.6 header). A horizontal scroll-ribbon over a
# painted makimono (parallax 0.4×), free track above the path, premium below, the season outfit at the end of the
# ribbon. Season end is a CALENDAR date for everyone («до пн, 5 января, 04:00 МСК»); a countdown only in the last 48 h.
# Buying late unlocks every premium tier already reached at once: the reached premium tiles light up in a cascade
# (80 ms step, pentatonic up) — retro-grant. «Забрать всё» is the one rose button when something waits.

signal go_screen(id: String, args: Dictionary)

const COL: = 136.0
const SEASON_OUTFIT_IMG: = "yue_ball"      # spec Л5: in 0.10 the premium tier-30 reward is «Лунный бал»
const SEASON_OUTFIT_NAME: = "Лунный бал"

var m: V10ShopModel
var season_name: = "Лунная тропа"
var vs: = Vector2(720, 1280)
var ribbon: ScrollContainer
var bg: TextureRect
var prem_tiles: = {}
var claim_btn: V10Button
var _top: = 0.0


static func make(model: V10ShopModel, opts: = {}) -> V10PassScreen:
	var s: = V10PassScreen.new()
	s.m = model
	s.season_name = String(opts.get("season_name", s.season_name))
	s.name = "V10PassScreen"
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(build)
	build()


func build() -> void:
	for c in get_children():
		if c is V10ShopSheet:
			continue
		c.queue_free()
	prem_tiles = {}
	vs = get_viewport_rect().size
	size = vs
	var ins: = V10Hud2Util.safe_insets(vs)
	var base: = ColorRect.new()
	base.color = V10DS.NIGHT_900
	base.size = vs
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	V10Header.make(self, "Пропуск сезона", func(): go_screen.emit("back", {}))
	var y: = V10Header.content_y(vs)
	var cx: = (vs.x - minf(vs.x, 720.0)) * 0.5 + 24.0
	var cw: = minf(vs.x, 720.0) - 48.0
	var p: = m.econ.pass_
	var when: = V10ShopTxt.until_msk(int(p.st.end), m.now()) if int(p.st.end) > 0 else "без даты окончания"
	var cap: = V10ShopKit.lbl("Сезон «%s» · %s" % [season_name, when], "ui", 18, V10DS.PAPER_300)
	cap.position = Vector2(cx, y)
	cap.size = Vector2(cw, 26)
	add_child(cap)
	y += 40
	var tier: = p.tier()
	var lv: = V10ShopKit.lbl("Уровень %d" % tier, "num", 40, V10DS.GOLD_300)
	lv.position = Vector2(cx, y)
	lv.size = Vector2(cw * 0.5, 48)
	lv.name = "Level"
	add_child(lv)
	var into: = int(p.st.xp) - tier * V10Catalog.PASS_XP_TIER
	var xp: = V10ShopKit.lbl("%d / %d опыта" % [into, V10Catalog.PASS_XP_TIER] if tier < V10Catalog.PASS_TIERS else "все уровни пройдены", "ui", 18, V10DS.PAPER_300)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp.position = Vector2(cx + cw * 0.5, y + 8)
	xp.size = Vector2(cw * 0.5, 32)
	add_child(xp)
	y += 52
	var bar: = V10ShopW.Bar.new()
	bar.position = Vector2(cx, y)
	bar.size = Vector2(cw, 12)
	bar.k = 1.0 if tier >= V10Catalog.PASS_TIERS else float(into) / float(V10Catalog.PASS_XP_TIER)
	add_child(bar)
	y += 20
	if p.late():
		var lt: = V10ShopKit.lbl("Последние 10 дней сезона: опыт ×2", "ui", 18, V10DS.JADE_300)
		lt.position = Vector2(cx, y)
		lt.size = Vector2(cw, 26)
		add_child(lt)
	y += 32
	# ribbon
	var p_claim: = p.claimable().size() > 0
	var act_h: = (120.0 if p_claim else 0.0) + (40.0 if bool(p.st.prem) else (132.0 if m.cash_visible() else 0.0))
	var bottom_h: = act_h + 32.0 + float(ins.bottom)
	var rh: = maxf(vs.y - y - bottom_h - 16.0, 420.0)
	var band: = Control.new()
	band.position = Vector2(0, y)
	band.size = Vector2(vs.x, rh)
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var bt: = V10ShopKit.tex("bg_pass")
	if bt:
		var bw: = rh * bt.get_size().x / bt.get_size().y
		bg = V10ShopKit.art(bt, Rect2(0, 0, maxf(bw, vs.x * 1.6), rh), true)
		bg.modulate = Color(1, 1, 1, 0.55)
		bg.name = "Parallax"
		band.add_child(bg)
	ribbon = ScrollContainer.new()
	ribbon.name = "Ribbon"
	ribbon.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ribbon.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	ribbon.position = Vector2(0, 0)
	ribbon.size = band.size
	band.add_child(ribbon)
	var row: = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var rows: = m.pass_rows()
	var x0: = 24.0
	var tile_h: = clampf(rh * 0.5 - 96.0, 120.0, 176.0)
	var fy: = maxf(40.0, (rh * 0.5 - 30.0 - tile_h) * 0.5 + 16.0)
	var py: = rh * 0.5 + maxf(60.0, (rh * 0.5 - tile_h) * 0.5 + 8.0)
	var path: = PathLine.new()
	path.position = Vector2(0, rh * 0.5 - 4)
	path.size = Vector2(x0 + rows.size() * COL + 360, 8)
	path.reached_x = x0 + tier * COL - COL * 0.5
	row.add_child(path)
	for r in rows:
		var i: = int(r.tier)
		var x: = x0 + (i - 1) * COL
		row.add_child(_tile(r.free, Rect2(x + 12, fy, COL - 24, tile_h), bool(r.reached), bool(r.free_got), true, "F%d" % i))
		var pt: = _tile(r.prem, Rect2(x + 12, py, COL - 24, tile_h), bool(r.reached), bool(r.prem_got), bool(p.st.prem), "P%d" % i)
		prem_tiles[i] = pt
		row.add_child(pt)
		var md: = Medal.new()
		md.n = i
		md.lit = bool(r.reached)
		md.position = Vector2(x + COL * 0.5 - 24, rh * 0.5 - 24)
		md.size = Vector2(48, 48)
		row.add_child(md)
	# the season outfit at the end of the ribbon
	var ex: = x0 + rows.size() * COL + 24
	var ot: = V10ShopKit.outfit_tex(SEASON_OUTFIT_IMG)
	var oc: = V10ShopW.Lac.new()
	oc.bevel = 12.0
	oc.position = Vector2(ex, 24)
	oc.size = Vector2(300, rh - 48)
	row.add_child(oc)
	if ot:
		oc.add_child(V10Shop2._top_crop(ot, Rect2(4, 4, 292, rh - 48 - 96)))
	var on: = V10ShopKit.lbl("Наряд сезона", "overline", 15, V10DS.GOLD_500)
	on.position = Vector2(16, rh - 48 - 84)
	on.size = Vector2(268, 20)
	oc.add_child(on)
	var onl: = V10ShopKit.lbl("«%s» · 30-й уровень" % SEASON_OUTFIT_NAME, "ui", 18, V10DS.PAPER_100)
	onl.position = Vector2(16, rh - 48 - 58)
	onl.size = Vector2(268, 26)
	oc.add_child(onl)
	var pl: = V10ShopW.Pill.new().setup("SSR", V10ShopKit.rar_color("SSR"))
	pl.position = Vector2(12, 12)
	oc.add_child(pl)
	row.custom_minimum_size = Vector2(ex + 300 + 24, rh)
	ribbon.add_child(row)
	ribbon.get_h_scroll_bar().value_changed.connect(func(v: float):
		if is_instance_valid(bg):
			bg.position.x = -v * 0.4)
	ribbon.set_deferred("scroll_horizontal", int(maxf(0.0, x0 + (tier - 2) * COL)))
	# track labels (fixed, left)
	var fl: = V10ShopKit.lbl("БЕСПЛАТНО", "overline", 15, V10DS.GOLD_500, true)
	fl.position = Vector2(24, y + fy - 28)
	fl.size = Vector2(200, 20)
	add_child(fl)
	var plb: = V10ShopKit.lbl("ПРЕМИУМ", "overline", 15, V10DS.GOLD_500, true)
	plb.position = Vector2(24, y + py - 28)
	plb.size = Vector2(200, 20)
	add_child(plb)
	# bottom actions
	_top = maxf(y + rh + 16, vs.y - bottom_h)
	_actions(cx, cw)


func _tile(g: Dictionary, r: Rect2, reached: bool, got: bool, open: bool, nm: String) -> Control:
	var t: = TierTile.new()
	t.name = nm
	t.position = r.position
	t.size = r.size
	t.reached = reached
	t.got = got
	t.locked = not open
	var icon: = "item_crystal"
	var amount: = 0
	if g.has("items"):
		icon = "item_pass"
	elif int(g.get("wish", 0)) > 0:
		icon = "item_wish"
		amount = int(g.wish)
	elif int(g.get("crystal", 0)) > 0:
		amount = int(g.crystal)
	elif int(g.get("tea", 0)) > 0:
		icon = "item_tea"
		amount = int(g.tea)
	elif int(g.get("coin", 0)) > 0:
		icon = "item_coin"
		amount = int(g.coin)
	var tx: Texture2D = V10ShopKit.tex(icon)
	if tx:
		var a: = V10ShopKit.art(tx, Rect2(16, 10, r.size.x - 32, r.size.y - 52))
		if not open or not reached:
			a.modulate = Color(1, 1, 1, 0.45)
		t.add_child(a)
	var txt: = "наряд" if g.has("items") else V10ShopTxt.num(amount)
	var l: = V10ShopKit.lbl(txt, "num", 22, V10DS.PAPER_100 if open and reached else V10DS.PAPER_500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, r.size.y - 40)
	l.size = Vector2(r.size.x, 32)
	t.add_child(l)
	t.tooltip_text = V10ShopModel.grant_text(g)
	return t


func _actions(cx: float, cw: float) -> void:
	var y: = _top
	var p: = m.econ.pass_
	var n: = p.claimable().size()
	if n > 0:
		claim_btn = V10Button.make("play", "Забрать всё · %d" % n, Vector2(cw, 104))
		claim_btn.name = "ClaimAll"
		claim_btn.position = Vector2(cx, y)
		claim_btn.set_meta("ux_role", "primary")
		claim_btn.pressed.connect(_claim_all)
		add_child(claim_btn)
		y += 120
	if bool(p.st.prem):
		var ok: = V10ShopKit.lbl("Премиум открыт%s" % (" · Пропуск+" if bool(p.st.deluxe) else ""), "ui", 22, V10DS.JADE_300)
		ok.position = Vector2(cx, y)
		ok.size = Vector2(cw, 34)
		add_child(ok)
		return
	if not m.cash_visible():
		return
	var half: = (cw - 16) * 0.5
	var i: = 0
	for sku in ["pass_899", "pass_1490"]:
		var c: = m.card(sku)
		var x: = cx + i * (half + 16)
		var ttl: = V10ShopKit.lbl(String(c.name), "ui_strong", 22, V10DS.PAPER_100)
		ttl.position = Vector2(x, y)
		ttl.size = Vector2(half, 30)
		add_child(ttl)
		var pw: = V10ShopKit.lbl(String(c.per_wish), "ui", 18, V10DS.PAPER_300)
		pw.position = Vector2(x, y + 30)
		pw.size = Vector2(half, 26)
		add_child(pw)
		var cash: = V10ShopW.Cash.new().setup(String(c.price), "", Vector2(half, 72))
		cash.name = "Buy_" + sku
		cash.position = Vector2(x, y + 60)
		cash.enabled = bool(c.available)
		cash._lay()
		var id: String = sku
		cash.pressed.connect(func(): _buy(id))
		add_child(cash)
		i += 1


func _buy(sku: String) -> void:
	var before: = m.econ.pass_.claimable().size()
	var shop: = m.econ.shop
	var once: = {"done": false}
	var on_ok: = func(r: Dictionary) -> void:
		if once.done or not String(r.get("sku", "")).begins_with("pass_"):
			return
		once.done = true
		get_tree().create_timer(0.9 if not V10ShopKit.mute else 0.0).timeout.connect(func(): retro_cascade(before))
	shop.delivered.connect(on_ok, CONNECT_ONE_SHOT)
	var sh: = V10ShopFlow.confirm(self, m, sku)
	if sh:
		sh.closed.connect(func():
			if not once.done and shop.delivered.is_connected(on_ok):
				shop.delivered.disconnect(on_ok))


# premium tiers already reached light up one by one (retro-grant), then the screen rebuilds with «Забрать всё»
func retro_cascade(_before: = 0) -> int:
	if not is_inside_tree():
		return 0
	var tier: = m.econ.pass_.tier()
	var lit: = 0
	var tw: = create_tween()
	for i in range(1, tier + 1):
		var t = prem_tiles.get(i)
		if t == null or not is_instance_valid(t):
			continue
		lit += 1
		var tile: TierTile = t
		var idx: = lit
		tw.tween_callback(func():
			tile.locked = false
			tile.pulse()
			for c in tile.get_children():
				(c as CanvasItem).modulate = Color.WHITE
			if not V10ShopKit.mute:
				V9Feel.sound("pop", V10ShopKit.PENTA[idx % V10ShopKit.PENTA.size()], -6.0))
		tw.tween_interval(0.08 if V10ShopKit.fx_on() else 0.0)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		V10ShopKit.toast(self, "Премиум открыт: %d %s ждут" % [lit, V10ShopTxt.plural(lit, "награда", "награды", "наград")])
		build())
	return lit


func _claim_all() -> void:
	V10ShopKit.press(claim_btn, true)
	var gs: = m.pass_claim_all()
	var sum: = {}
	for g in gs:
		for k in g:
			if k != "items":
				sum[k] = int(sum.get(k, 0)) + int(g[k])
	V10ShopKit.hanko(self, size * Vector2(0.5, 0.45))
	if int(sum.get("crystal", 0)) > 0:
		V10ShopKit.fly(self, claim_btn.position + claim_btn.size * 0.5, Vector2(size.x - 80, 60), V10ShopKit.tex("item_crystal"), 6)
	V10ShopKit.toast(self, "Зачислено: " + V10ShopModel.grant_text(sum))
	build()


func refresh() -> void:
	build()


# ================================================================ inner
class TierTile:
	extends Control
	var reached: = false
	var got: = false
	var locked: = false
	var flash: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func pulse() -> void:
		var tw: = create_tween()
		tw.tween_method(func(v: float):
			flash = v
			queue_redraw(), 1.0, 0.0, 0.5)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		V10Plate.draw_surface(self, r, true, false, reached and not got and not locked, false, false, -1.0,
			V10DS.NIGHT_700 if reached else V10DS.NIGHT_800)
		if flash > 0.0:
			draw_rect(r, Color(V10DS.GOLD_300, 0.18 * flash))
		if got:
			draw_circle(Vector2(size.x - 18, 18), 11, V10DS.JADE_500, true, -1.0, true)
			draw_polyline(PackedVector2Array([Vector2(size.x - 23, 18), Vector2(size.x - 19, 22), Vector2(size.x - 12, 13)]), V10DS.NIGHT_900, 2.5, true)
		elif locked:
			V10Icons.draw(self, "lock_silhouette", Vector2(size.x - 20, 20), 24, V10DS.PAPER_500)


class Medal:
	extends Control
	var n: = 1
	var lit: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: = size * 0.5
		draw_circle(c, 22, V10DS.NIGHT_800 if not lit else V10DS.NIGHT_700, true, -1.0, true)
		draw_arc(c, 22, 0, TAU, 40, V10DS.GOLD_500 if lit else Color(V10DS.GOLD_700, 0.5), 1.5, true)
		var f: = V10Type.font("num")
		var s: = str(n)
		var w: = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, c + Vector2(-w * 0.5, 7), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, V10DS.GOLD_300 if lit else V10DS.PAPER_500)


class PathLine:
	extends Control
	var reached_x: = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 2, size.x, 4), Color(V10DS.NIGHT_600, 0.9))
		draw_rect(Rect2(0, 2, maxf(0.0, reached_x), 4), V10DS.GOLD_500)
