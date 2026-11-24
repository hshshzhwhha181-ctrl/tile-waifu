extends Control


var main
var W: = 720.0
var H: = 1280.0
var cur: = "mc"
var stage: Control

const ROW_Y: = V8Header.CONTENT_Y + 6.0
const AV: = 104.0
# outfit strip cards: the name's side padding (frame rim + gap: NAME_PAD on a six-card strip's ~108 px card, growing
# by NAME_PAD_K per px of a wider card, as the rim art and its corner flowers do) and its bottom margin above the
# card edge
const NAME_PAD: = 9.0
const NAME_PAD_K: = 0.3
const NAME_FOOT: = 13.0
const NAME_MIN_FS: = 14
const BODY_Y: = ROW_Y + AV + 14.0

var preview_root: Control

const STAGE_BG: = {"mc": "menu", "rin": "bg_teahouse", "hana": "bg_street", "yue": "bg_palace", "nova": "bg_neon"}

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	cur = args.get("hero", G.S.partner)
	_build()

func _unlocked(h: String) -> bool:
	return G.hero_unlocked(h)

func _build() -> void :
	if stage:
		stage.queue_free()
	stage = Control.new()
	stage.size = size
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	move_child(stage, 0)
	var bg: String = STAGE_BG[cur]
	Common.backdrop(stage, bg, size, 2.2 if bg != "menu" else 0.0, 0.82, Color(1, 0.96, 0.98), Vector2(0.5, 0.5))
	Common.vignette(stage, size, Color(0.3, 0.1, 0.25), 0.55)
	Fx.ambient(stage, "fireflies", size)
	V8Header.make(stage, main, "Гардероб", main.back)
	set_meta("v8_back", main.back)

	var x: = 24.0 + (112.0 - AV) * 0.5
	for h in G.HERO_ORDER:
		var on: bool = h == cur
		var unl: = _unlocked(h)
		var ring: = UI.rbox("pink" if on else ("gold" if unl else "plum"), Rect2(x, ROW_Y, AV, AV), AV * 0.5, 4, 10)
		stage.add_child(ring)
		var av: TextureRect = main._avatar(h, Rect2(x + 7, ROW_Y + 7, AV - 14, AV - 14))
		if not unl:
			(av.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
		stage.add_child(av)
		if not unl:
			stage.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(x + AV * 0.5 - 18, ROW_Y + AV * 0.5 - 18, 36, 36)))
		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(x, ROW_Y)
		hit.size = Vector2(AV, AV)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				# 0.9: V9Feel press (dip + spring, click, haptic) on the tapped ring, never a bare click
				V9Feel.press(ring, "tap")
				if hh != cur:
					cur = hh
					_build())
		stage.add_child(hit)
		if on:
			ring.pivot_offset = Vector2(AV, AV) * 0.5
			UI.punch(ring, 0.12)
		x += 136

	var floor_y: = H - 132 - 250
	var ped: = Sprite2D.new()
	ped.texture = G.fx("glow")
	ped.material = Fx.add_mat()
	ped.position = Vector2(W * 0.34, floor_y)
	ped.scale = Vector2(5.5, 1.2)
	ped.modulate = Color(G.HEROES[cur].color.r, G.HEROES[cur].color.g, G.HEROES[cur].color.b, 0.6)
	stage.add_child(ped)
	var unl: = _unlocked(cur)
	var hero: = Hero.new().setup(cur, min(floor_y - BODY_Y - 10.0, 860.0))
	hero.position = Vector2(W * 0.34, floor_y)
	stage.add_child(hero)
	var oid: = G.equipped(cur)
	if oid != "" and _unlocked(cur):
		var fr: = UI.rbox("gold", Rect2(14, BODY_Y, W - 334, floor_y - BODY_Y - 14), 24, 4, 10)
		stage.add_child(fr)
		Common.living_art(fr, G.art_tex(G.ITEM[oid]), Rect2(6, 6, fr.size.x - 12, fr.size.y - 12), Vector2(0.5, 0.3))
		hero.visible = false
	if not unl:
		hero.mat.set_shader_parameter("silhouette", 0.92)
		hero.interactive = false
	else:
		hero.tapped.connect( func():
			hero.react("happy")
			Fx.burst(stage, V10Layout.local_of(stage, hero.head_global()), "heart", 8)
			Sfx.say(cur, "aff"))
	UI.slide_in(hero, Vector2(-60, 0), 0.0, 0.5)

	var ic: = UI.rbox("glass", Rect2(W - 300, BODY_Y, 280, 400), 28, 4, 12)
	stage.add_child(ic)
	var nm: = UI.title(G.HEROES[cur].name, 32, UI.INK, Color.WHITE)
	nm.position = Vector2(20, 14)
	ic.add_child(nm)
	var tl: = UI.label(G.HEROES[cur].title, 20, Color("b8406c"), Color.WHITE, 3, "body", 900)
	tl.position = Vector2(22, 70)
	ic.add_child(tl)
	ic.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(16, 112, 52, 52)))
	var al: = UI.label(V6Txt.s("coll.aff") % G.aff_level(cur), 22, UI.INK, Color.WHITE, 3, "body", 900)
	al.position = Vector2(74, 116)
	ic.add_child(al)
	Common.progress_bar(ic, Rect2(76, 148, 186, 18), float(int(G.S.aff.get(cur, 0)) % 100) / 100.0, "pink")
	var owned: = 0
	var total: = 0
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			total += 1
			if G.owns(it.id):
				owned += 1
	var ol: = UI.label(V6Txt.s("coll.outfits") % [owned, total], 20, UI.INK)
	ol.position = Vector2(22, 182)
	ic.add_child(ol)
	var perks: = UI.label(V6Txt.s("coll.bonus") % (5 * G.aff_level(cur)), 18, Color("7a4a6a"))
	perks.position = Vector2(22, 214)
	ic.add_child(perks)
	if unl:
		# 0.8: the three actions all draw button art (≥ 60 px: btn/primary or the jade «on» state, then the graphite
		# secondary for «Голос» / «Фишки») — no procedural lavender pills
		var pb: = JButton.make(V6Txt.s("coll.partner_on") if G.S.partner == cur else V6Txt.s("coll.partner"), "pink" if G.S.partner != cur else "mint", Rect2(18, 262, 244, 62), null, 22)
		pb.pressed.connect( func():
			G.S.partner = cur
			G.save()
			Sfx.say(cur, "outfit")
			main.toast(V6Txt.s("coll.partner_toast") % G.HEROES[cur].name, "heart")
			_build())
		ic.add_child(pb)
		var vb: = JButton.make(V6Txt.s("coll.voice"), "graphite", Rect2(18, 332, 118, 60), null, 20)
		vb.pressed.connect( func(): Sfx.say(cur, "greet");hero.react("happy"))
		ic.add_child(vb)
		var tb: = JButton.make(V6Txt.s("coll.skins"), "graphite", Rect2(144, 332, 118, 60), null, 20)
		tb.pressed.connect( func(): Common.skin_picker(main, func(): pass))
		ic.add_child(tb)
	else:
		var lb: = UI.label(V6Txt.s("coll.shards") % [mini(int(G.S.shards.get(cur, 0)), G.SHARDS_NEED), G.SHARDS_NEED], 22, Color("7a4a6a"), Color.WHITE, 3, "body", 900)
		lb.position = Vector2(22, 280)
		ic.add_child(lb)
		var go: = JButton.make(V6Txt.s("coll.to_wish"), "graphite", Rect2(18, 330, 244, 60), null, 22)
		go.pressed.connect( func(): main.go("summon", {"banner": 1 if cur == "nova" else 0}))
		ic.add_child(go)
	UI.slide_in(ic, Vector2(60, 0), 0.1)

	var strip: = UI.rbox("cream", Rect2(14, H - 132 - 236, W - 28, 226), 28, 4, 12)
	strip.set_param("pattern", 1.0)
	stage.add_child(strip)
	# 0.8: the screen header already says «Гардероб»; the strip counts this heroine's outfits
	var n_own: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur and G.owns(x.id)).size()
	var n_all: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var st: = UI.label("Наряды · %d/%d" % [n_own, n_all], 20, UI.INK, Color.WHITE, 3, "body", 900)
	st.position = Vector2(20, 8)
	strip.add_child(st)
	V7AlbumView.collection_button(strip, main, _build)
	var cx: = 10.0
	var n_items: = G.ITEMS.filter( func(x): return x.get("hero", "") == cur).size()
	var cw: = clampf((strip.size.x - 20.0 - (n_items - 1) * 5.0) / maxf(1.0, n_items), 96.0, 118.0)
	# 0.9: one name size for the whole strip — the largest (16 → NAME_MIN_FS) at which every name of this heroine
	# fits its padded box without a break inside a word, so no card has a hyphenated or thinned name and the row
	# reads as one set
	var nw: = cw - _name_pad(cw) * 2.0
	var name_fs: = 16
	for it in G.ITEMS:
		if it.get("hero", "") == cur:
			name_fs = mini(name_fs, _name_fs(String(it.name), nw))
	for it in G.ITEMS:
		if it.get("hero", "") != cur:
			continue
		var own: bool = G.owns(it.id)
		var worn: bool = G.S.outfit.get(cur, "") == it.id or (G.S.outfit.get(cur, "") == "" and it.id in G.BASE_OUTFITS)
		# 0.8: the rarity frame art (frame/card_*) over the outfit; the card node is only a holder
		var csz: = Vector2(cw, 168)
		var card: = Control.new()
		card.position = Vector2(cx, 44)
		card.size = csz
		card.pivot_offset = csz * 0.5
		strip.add_child(card)
		if worn and own:
			# soft gold glow around the worn outfit
			var glow: = UI.rbox("gold", Rect2(2, 2, cw - 4, 164), 12, 0, 10)
			glow.set_param("glow", 1.0).set_param("glow_color", Color("ffe7a6"))
			card.add_child(glow)
		var inner: = Common.card_inner(it.rar, csz)
		var art: = Common.card_art(G.art_tex(it), inner, Vector2(0.5, 0.3), 1.0, Common.card_radius(it.rar, csz))
		var am: ShaderMaterial = art.material
		if not own:
			am.set_shader_parameter("gray", 1.0)
			am.set_shader_parameter("bottom_shade", 0.9)
		am.set_shader_parameter("holo", 0.4 if it.rar == "SSR" and own else 0.0)
		card.add_child(art)
		Common.card_frame(card, it.rar, Rect2(Vector2.ZERO, csz))
		# rarity: a small pill in the top-right corner, clear of the frame's crest and flowers
		var rw: = UI.font("body", 900).get_string_size(it.rar, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
		var rtag: = UI.rbox("graphite", Rect2(cw - rw - 5, inner.position.y + 2, rw, 22), 11, 2, 3)
		rtag.borders(G.rar_color(it.rar).lerp(Color.WHITE, 0.35), G.rar_color(it.rar).darkened(0.45))
		card.add_child(rtag)
		rtag.add_child(UI.center_label(UI.label(it.rar, 16, G.rar_color(it.rar).lerp(Color.WHITE, 0.45), UI.DARK, 2, "body", 900), Rect2(0, -1, rw, 22)))
		if worn and own:
			# 0.9: «надет» is a jade band at the bottom of the art (behind the name) plus a small jade check badge
			# pinned on the frame's top-left corner (mirroring the rarity tag), mostly over the rim — never a pill
			# over her face
			var band_h: = 62.0
			var wb: = UI.rbox("mint", Rect2(inner.position.x + 1, inner.end.y - band_h - 1, inner.size.x - 2, band_h), 10, 0, 2)
			wb.colors(Color(0.12, 0.42, 0.34, 0.0), Color(0.08, 0.34, 0.27, 0.92))
			wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(wb)
			var wk: = UI.rbox("mint", Rect2(-4, -4, 24, 24), 12, 2, 2)
			wk.colors(Color("4fbf9f"), Color("1f6b55")).borders(Color("ffe7a6"), Color("c58a2c"))
			wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wk.tooltip_text = V6Txt.s("coll.worn")
			card.add_child(wk)
			wk.add_child(UI.center_label(UI.label("✓", 16, Color.WHITE, Color(0.05, 0.2, 0.15), 3, "body", 900), Rect2(0, -1, 24, 24)))
		# 0.8: name up to three lines inside the frame; it wraps between words only (0.9: at the strip's common
		# name_fs, 16 px when every name allows it, never below NAME_MIN_FS)
		# 0.9: the name always keeps _name_pad(cw) px clear of the frame on each side (the rim art + a gap; the outline
		# is inside that) and its last line ends NAME_FOOT px above the card's bottom edge, clear of the
		# rim's corner flowers. A word too wide for that box drops to a lighter weight, then is hyphenated
		# (Common.fit_words) — it never grows back over the frame
		var nl: = UI.label(_name_text(String(it.name), nw, name_fs), name_fs, Color.WHITE, Color(0.2, 0.05, 0.2), 4 if name_fs >= 16 else 3, "body", 800)
		Common.fit_words(nl, nw, 3, name_fs)
		nl.position = Vector2((cw - nw) * 0.5, minf(72.0, csz.y - NAME_FOOT - 84.0))
		nl.size = Vector2(nw, 84)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		card.add_child(nl)
		if not own:
			# the padlock sits above the name: a name that wraps to a third line («Хозяйка / после / закрытия»)
			# lifts it by that line, so the lock never sits under the text
			var nls: LabelSettings = nl.label_settings
			var nlh: = nls.font.get_height(nls.font_size) + nls.line_spacing
			var nth: = nls.font.get_multiline_string_size(nl.text, HORIZONTAL_ALIGNMENT_CENTER, nw - nls.outline_size, nls.font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
			var n_lines: = clampi(int(round(nth / nls.font.get_height(nls.font_size))), 1, 3)
			var ly: = minf(62.0, nl.position.y + 84.0 - n_lines * nlh - 42.0)
			card.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(cw * 0.5 - 20, ly, 40, 40)))
		var itc: Dictionary = it
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				# 0.9: an outfit you do not own denies (shake + deny haptic) before saying where to get it
				UI.tap(card, 0.06, "pop" if own else "deny")
				if own:
					_preview(itc)
				else:
					main.toast(V6Txt.s("coll.missing") % itc.name, "wardrobe"))
		UI.pop_in(card, 0.1 + cx / 2000.0, 0.8)
		cx += cw + 5

static func _name_pad(cw: float) -> float:
	return NAME_PAD + maxf(0.0, cw - 108.0) * NAME_PAD_K


# a compound name too wide for one line («Офлайн-выходной») breaks after its own hyphen, never inside a part
static func _name_text(name: String, width: float, fs: int) -> String:
	var f: = UI.font("body", 800)
	var pad: = 4.0 if fs >= 16 else 3.0
	var out: = []
	for wd in name.split(" ", false):
		if wd.contains("-") and f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
			wd = wd.replace("-", "-\n")
		out.append(wd)
	return " ".join(out).replace("\n ", "\n")


# the parts of a name that must each fit one line: its words, compound words split after their hyphens
static func _name_parts(name: String) -> Array:
	var parts: = []
	for wd in name.split(" ", false):
		var bits: = wd.split("-", false)
		for i in bits.size():
			parts.append(bits[i] + ("-" if i < bits.size() - 1 else ""))
	return parts


# the largest size (16 down to NAME_MIN_FS) at which `name` sets in `width` (outline included) in at most three
# lines with every word whole, at the strip's weight
static func _name_fs(name: String, width: float) -> int:
	var f: = UI.font("body", 800)
	for fs in range(16, NAME_MIN_FS - 1, -1):
		var pad: = 4.0 if fs >= 16 else 3.0
		var fits: = true
		for wd in _name_parts(name):
			if f.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
				fits = false
		var h: = f.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, width - pad, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if fits and h <= f.get_height(fs) * 3 + 1.0:
			return fs
	return NAME_MIN_FS

func _preview(it: Dictionary) -> void :
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	preview_root = root
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.1, 0.03, 0.1, 0.85)
	root.add_child(dim)
	# 0.8: the rarity frame art, drawn at most 1.4× its 344×512 source
	var aw: = 344.0 * 1.4
	var ah: = aw * 512.0 / 344.0
	var frr: = Rect2((W - aw) * 0.5, (H - ah) * 0.5 - 30, aw, ah)
	var inner: = Common.card_inner(it.rar, frr.size)
	var art: = Common.card_art(G.art_tex(it), Rect2(frr.position + inner.position, inner.size), Vector2(0.5, 0.5), 1.0, Common.card_radius(it.rar, frr.size))
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.3 if it.rar == "SSR" else 0.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.3)
	# art + frame pop in together (the frame node is scaled, so it is animated through this holder)
	var card: = Control.new()
	card.position = frr.position
	card.size = frr.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	art.position -= frr.position
	card.add_child(art)
	Common.card_frame(card, it.rar, Rect2(Vector2.ZERO, frr.size))
	Common.ribbon(root, it.name, Rect2(50, frr.end.y - 44, W - 100, 76), "pink", 30)
	var worn: bool = G.S.outfit.get(it.hero, "") == it.id or (G.S.outfit.get(it.hero, "") == "" and it.id in G.BASE_OUTFITS)
	var eb: = JButton.make(V6Txt.s("coll.wear_on") if worn else V6Txt.s("coll.wear"), "mint" if worn else "gold", Rect2(W * 0.5 - 160, frr.end.y + 46, 320, 84), null, 32)
	eb.shine_every = 0.0 if worn else 2.0
	eb.pressed.connect( func():
		G.S.outfit[it.hero] = it.id
		G.save()
		Sfx.say(it.hero, "outfit")
		main.toast(V6Txt.s("coll.wear_toast") % [G.HEROES[it.hero].name, it.name], "wardrobe")
		root.queue_free()
		_build())
	root.add_child(eb)
	UI.pop_in(card, 0.0, 0.85)
	Sfx.say(it.hero, "outfit")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			V9Feel.press(null, "tap", "tap")
			root.queue_free())

func handle_back() -> bool:
	if preview_root and is_instance_valid(preview_root) and not preview_root.is_queued_for_deletion():
		V9Feel.press(null, "tap", "tap")
		preview_root.queue_free()
		preview_root = null
		return true
	return false

func dev_act(a: String) -> void :
	if a == "album":
		V7AlbumView.open(main)
		return
	if a == "back":
		main.android_back()
		return
	if a == "preview":
		for it in G.ITEMS:
			if it.get("hero", "") == cur and G.owns(it.id):
				_preview(it)
				return
