extends Control


var main
var W: = 720.0
var H: = 1280.0
var banner_i: = 0
var banner_root: Control
var pull1_btn: JButton
var pull10_btn: JButton
var circle: ColorRect
var circle_mat: ShaderMaterial
var seq: Control
var showcase: Control
var flipping: = false
var results_shown: = false
var cards: Array = []
var pity_lbl: Label
var trial_btn: JButton
var last_n: = 10

const TABS_Y: = V8Header.CONTENT_Y + 8.0
const TOP: = TABS_Y + 60.0 + 12.0

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	banner_i = int(args.get("banner", 0))
	main.show_chrome(true, true)
	Sfx.music("summon")
	Common.backdrop(self, "summon", size, 0.0, 1.0)
	Fx.ambient(self, "stars", Vector2(W, H * 0.5))
	Fx.ambient(self, "petals", size)
	circle = ColorRect.new()
	circle.size = Vector2(620, 620)
	circle.position = Vector2(W * 0.5 - 310, H - 132 - 330)
	circle.pivot_offset = Vector2(310, 310)
	circle.scale = Vector2(1.0, 0.36)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_mat = ShaderMaterial.new()
	circle_mat.shader = preload("res://shaders/circle.gdshader")
	circle_mat.set_shader_parameter("color", Color(0.65, 0.85, 1.0, 0.9))
	circle_mat.set_shader_parameter("power", 0.25)
	circle.material = circle_mat
	add_child(circle)
	_build_banner()

func _build_banner() -> void :
	if banner_root:
		banner_root.queue_free()
	if G.BANNERS[banner_i].get("newbie", false) and int(G.S.newbie_left) <= 0:
		banner_i = 1
	banner_root = Control.new()
	banner_root.size = size
	banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_root)
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)
	V8Header.make(banner_root, main, "Желания", main.back)
	set_meta("v8_back", main.back)

	var shown: Array = []
	for i in G.BANNERS.size():
		if G.BANNERS[i].get("newbie", false) and int(G.S.newbie_left) <= 0:
			continue
		shown.append(i)
	var tw: = (W - 48 - (shown.size() - 1) * 10) / shown.size()
	for k in shown.size():
		var i: int = shown[k]
		var bb: Dictionary = G.BANNERS[i]
		var tfs: = 22
		while tfs > 16 and UI.font("body", 900).get_string_size(bb.name, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > tw - 28:
			tfs -= 1
		var tb: = JButton.make(bb.name, "pink" if i == banner_i else "glass", Rect2(24 + k * (tw + 10), TABS_Y, tw, 60), null, tfs, -1.0, false)
		Common.tab_paint(tb, i == banner_i)
		tb.pressed.connect( func():
			if i != banner_i:
				banner_i = i
				_build_banner())
		banner_root.add_child(tb)
		if bb.get("newbie", false):
			var sale: = UI.rbox("red", Rect2(tw - 62, -14, 70, 28), 12, 2, 4)
			tb.add_child(sale)
			sale.add_child(UI.center_label(UI.label("−20%", 16, Color.WHITE, Color("6a1020"), 3), Rect2(0, 0, 70, 28)))

	var cr: = Rect2(24, TOP, W - 48, H - 132 - TOP - 196)
	var frame: = UI.rbox("gold", cr, 30, 6, 16)
	banner_root.add_child(frame)
	var it: Dictionary = G.ITEM[b.item]
	var art: = Common.card_art(G.art_tex(it), Rect2(cr.position + Vector2(8, 8), cr.size - Vector2(16, 16)), Vector2(0.5, 0.36), 1.0, 24)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.9)
	banner_root.add_child(art)
	Common.rays(banner_root, cr.position + Vector2(cr.size.x * 0.75, 120), 520, Color(1, 0.95, 0.8, 0.35), 8, 0.04, 0.4)
	var tag: = UI.rbox("pink" if not newbie else "red", Rect2(cr.position.x - 10, cr.position.y + 22, 230, 44), 14, 3, 10)
	banner_root.add_child(tag)
	tag.add_child(UI.center_label(UI.label(V6Txt.s("summon.rate_up") if not newbie else V6Txt.s("summon.newbie_tag"), 21, Color.WHITE, Color("7a2346"), 5, "body", 900), Rect2(0, 0, 230, 44)))
	if not newbie:
		var trial: = JButton.make(V6Txt.s("summon.trial"), "lav", Rect2(cr.end.x - 250, cr.position.y + 18, 236, 62), V8Art.icon("star"), 21)
		trial.shine_every = 3.0
		trial.pressed.connect( func(): main.go("play", {"trial": b.hero}))
		banner_root.add_child(trial)
		trial_btn = trial

	var info_y: = cr.end.y - 192
	var t1: = UI.title(b.name, 50, Color.WHITE, Color("3f2a7a"))
	t1.position = Vector2(cr.position.x + 26, info_y - 128)
	banner_root.add_child(t1)
	var t2: = UI.label((V6Txt.s("summon.ssr_line") % [G.HEROES[it.hero].name, it.name]) if not newbie else V6Txt.s("summon.newbie_line"), 21, Color("ffe7a6"), Color("3f2a7a"), 5, "body", 900)
	t2.position = Vector2(cr.position.x + 28, info_y - 58)
	banner_root.add_child(t2)

	var ip: = UI.rbox("plum", Rect2(cr.position.x + 16, info_y, cr.size.x - 32, 178), 24, 3, 10)
	ip.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	banner_root.add_child(ip)
	var pw: = ip.size.x
	var left: = 60 - int(G.S.pity)
	var pl: = UI.label(V6Txt.s("summon.pity"), 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 3, "body", 900)
	pl.position = Vector2(18, 10)
	ip.add_child(pl)
	pity_lbl = UI.title(str(left), 44, Color.WHITE, Color("7a4a0c"))
	pity_lbl.position = Vector2(18, 30)
	ip.add_child(pity_lbl)
	var pn: = UI.label(V6Txt.s("summon.pity_unit"), 17, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	pn.position = Vector2(20 + pity_lbl.get_minimum_size().x + 6, 52)
	ip.add_child(pn)
	Common.progress_bar(ip, Rect2(18, 96, 300, 18), float(G.S.pity) / 60.0, "gold")
	var rules: = V6Txt.s("summon.rules")
	var g_text: = V6Txt.s("summon.guar_on") if G.S.guar else V6Txt.s("summon.guar_off")
	if newbie:
		g_text = V6Txt.s("summon.newbie_left") % int(G.S.newbie_left)
	var rl: = UI.label(rules + "\n" + g_text, 16, Color("f4e6ff"), Color(0.2, 0.05, 0.2), 2)
	rl.position = Vector2(18, 124)
	ip.add_child(rl)
	if not newbie:
		var ex: = int(G.S.ex)
		var el: = UI.label(V6Txt.s("summon.exchange"), 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 3, "body", 900)
		el.position = Vector2(pw - 250, 10)
		ip.add_child(el)
		var ev: = UI.label("%d / %d" % [mini(ex, G.EXCHANGE_COST), G.EXCHANGE_COST], 24, Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
		ev.position = Vector2(pw - 250, 32)
		ip.add_child(ev)
		var xb: = JButton.make(V6Txt.s("summon.exchange_btn") % G.EXCHANGE_COST, "gold" if ex >= G.EXCHANGE_COST else "glass", Rect2(pw - 250, 72, 232, 50), null, 19)
		xb.pressed.connect( func(): _exchange(xb))
		# 0.9: a refused exchange answers with the deny alone (JButton gate), then _exchange says why
		xb.set_gate( func(): return int(G.S.ex) >= G.EXCHANGE_COST and not G.owns(b.item), func(): _exchange(xb))
		ip.add_child(xb)
	UI.pop_in(frame, 0.0, 0.92)
	UI.pop_in(art, 0.0, 0.92)

	var by: = H - 132 - 170
	var free: bool = G.S.free10 and not newbie
	if not newbie:
		pull1_btn = JButton.make(V6Txt.s("summon.pull1"), "lav", Rect2(24, by, 320, 124), null, 30)
		pull1_btn.set_cost(V8Art.cur("gem"), G.PULL_COST, 22)
		pull1_btn.pressed.connect( func(): _pull(1))
		pull1_btn.set_gate( func(): return _can_pull(1), func(): _pull(1))
		banner_root.add_child(pull1_btn)
		UI.slide_in(pull1_btn, Vector2(0, 60), 0.1)
	var r10: = Rect2(W - 344, by, 320, 124) if not newbie else Rect2(W * 0.5 - 220, by, 440, 124)
	pull10_btn = JButton.make(V6Txt.s("summon.pull10"), "gold", r10, null, 30)
	if free:
		pull10_btn.set_sub(V6Txt.s("summon.free"), 20)
	else:
		pull10_btn.set_cost(V8Art.cur("gem"), G.NEWBIE_COST if newbie else G.PULL_COST * 10, 22)
	pull10_btn.shine_every = 2.0
	pull10_btn.pulse = free or newbie
	pull10_btn.pressed.connect( func(): _pull(10))
	pull10_btn.set_gate( func(): return _can_pull(10), func(): _pull(10))
	banner_root.add_child(pull10_btn)
	if free:
		Common.badge(pull10_btn, 0, Vector2(r10.size.x - 26, -10))
	elif newbie:
		var sale: = UI.rbox("red", Rect2(r10.end.x - 100, by - 16, 100, 34), 14, 3, 6)
		banner_root.add_child(sale)
		sale.add_child(UI.center_label(UI.label("−20%", 19, Color.WHITE, Color("6a1020"), 4), Rect2(0, 0, 100, 34)))
	UI.slide_in(pull10_btn, Vector2(0, 60), 0.15)


func _exchange(btn: CanvasItem = null) -> void :
	var b: Dictionary = G.BANNERS[banner_i]
	# 0.9: a refusal denies (shake, deny sound and haptic) before the toast, never the success press alone
	if int(G.S.ex) < G.EXCHANGE_COST:
		V9Feel.deny(btn)
		main.toast(V6Txt.s("summon.ex_toast") % [int(G.S.ex), G.EXCHANGE_COST], "ticket")
		return
	if G.owns(b.item):
		V9Feel.deny(btn)
		main.toast(V6Txt.s("summon.have") % G.ITEM[b.item].name, "wardrobe")
		return
	# 0.8: no currency is spent without a question (spec «Общие правила кода»)
	Common.confirm(main, V6Txt.s("summon.exchange"), "Обменять %d звёзд обмена на «%s»?" % [G.EXCHANGE_COST, G.ITEM[b.item].name], "ticket", G.EXCHANGE_COST, func(): _exchange_do(b), {"balance_check": false, "yes_text": "Обменять"})

func _exchange_do(b: Dictionary) -> void :
	if int(G.S.ex) < G.EXCHANGE_COST or G.owns(b.item):
		return
	G.S.ex = int(G.S.ex) - G.EXCHANGE_COST
	G.give(b.item)
	G.save()
	var r: Dictionary = G.ITEM[b.item].duplicate()
	r["new"] = true
	await _showcase(r)
	_build_banner()

func _pull_cost(n: int) -> int:
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)
	var free: bool = n == 10 and G.S.free10 and not newbie
	return 0 if free else (G.NEWBIE_COST if newbie else G.PULL_COST * n)

# the pull buttons' gate: false only for a real refusal (not enough gems); a pull already running stays silent
func _can_pull(n: int) -> bool:
	return seq != null or int(G.S.gems) >= _pull_cost(n)

func _pull(n: int) -> void :
	if seq != null:
		return
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)
	var free: bool = n == 10 and G.S.free10 and not newbie
	var cost: = _pull_cost(n)
	if G.S.gems < cost:
		V9Feel.deny(pull1_btn if n == 1 else pull10_btn)
		main.toast(V6Txt.s("summon.no_gems"), "gem")
		return
	if free:
		G.S.free10 = false
	G.S.gems -= cost
	main.refresh_currency(true)
	# 0.9: the pity counter and guarantee are replayed card by card during the sequence, from their pre-pull values
	var ctx: = {"pity": int(G.S.pity), "guar": bool(G.S.guar), "newbie_left": int(G.S.get("newbie_left", 0)),
		"skip": V9Summon.can_skip(int(G.S.pulls))}
	var res: = G.pull(n, b, free)
	last_n = n
	_sequence(res, ctx)


# ---- 0.9 §E: the three-stage summon (lantern → colour → cards). Rules and timings: scripts/v09/summon/summon_rules.gd
var skipping: = false
var hurry: = false
var stage: = ""
var tapped: = false
var lantern: V9Lantern
var lantern_cap: Control
var hint_lbl: Label
var skip_btn: JButton
var top_hud: Control
var pity_num: Label
var pity_bar: RBox
var guar_lbl: Label
var mus: AudioStreamPlayer
var seq_res: Array = []
var seq_ctx: Dictionary = {}
var pity_steps: Array = []
var guar_steps: Array = []
var flipped: Dictionary = {}
var showcased: Dictionary = {}
var dealt: = false
var seq_fx: Array = []
var dev_preview: = false

const LANTERN_H: = 470.0
const LANTERN_Y: = 176.0
const FLOOR_Y: = 846.0
const PITY_BAR: = Rect2(16, 38, 284, 12)

func _alive() -> bool:
	return is_inside_tree() and seq != null and is_instance_valid(seq)

# a wait that ends early when the player skips (callers check `skipping` after it)
func _wait(t: float) -> void :
	var end: = Time.get_ticks_msec() + int(t * 1000.0)
	while _alive() and not skipping and Time.get_ticks_msec() < end:
		await get_tree().process_frame

# (a tap during the lantern's drop counts: `tapped` is cleared when the sequence starts, not here)
func _wait_tap(t: float) -> void :
	var end: = Time.get_ticks_msec() + int(t * 1000.0)
	while _alive() and not skipping and not tapped and Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _seq_input(e: InputEvent) -> void :
	if not (e is InputEventMouseButton and e.pressed):
		return
	tapped = true
	if stage == "deal":
		hurry = true

# own music player on the Music bus: the summon loop slowed down while the lantern is dark, then at the
# rarity's pitch once it has its colour (Sfx ducking still works on it)
func _mus(pitch: float, db: float, fade: = 0.6) -> void :
	if not G.S.get("music", true):
		return
	if mus == null:
		mus = AudioStreamPlayer.new()
		mus.bus = Sfx.MUSIC_BUS if AudioServer.get_bus_index(Sfx.MUSIC_BUS) >= 0 else "Master"
		add_child(mus)
	if not mus.playing:
		var st: AudioStream = load(V7DayNight.music_path("summon"))
		if st == null:
			return
		st = st.duplicate()
		if st is AudioStreamOggVorbis:
			st.loop = true
		mus.stream = st
		mus.volume_db = -40.0
		mus.pitch_scale = pitch
		mus.play()
	var tw: = mus.create_tween().set_parallel()
	tw.tween_property(mus, "volume_db", db, fade)
	tw.tween_property(mus, "pitch_scale", pitch, fade * 0.6)

func _mus_stop(fade: = 0.5) -> void :
	if mus and mus.playing:
		var m: = mus
		mus = null
		var tw: = m.create_tween()
		tw.tween_property(m, "volume_db", -40.0, fade)
		tw.tween_callback(m.queue_free)

func _fx_node(n: Node) -> Node:
	seq_fx.append(n)
	return n

func _sequence(res: Array, ctx: = {}) -> void :
	results_shown = false
	flipping = true
	tapped = false
	skipping = false
	hurry = false
	dealt = false
	flipped = {}
	showcased = {}
	seq_fx = []
	seq_res = res
	seq_ctx = ctx
	var b: Dictionary = G.BANNERS[banner_i]
	pity_steps = V9Summon.pity_track(int(ctx.get("pity", G.S.pity)), res)
	guar_steps = V9Summon.guar_track(bool(ctx.get("guar", G.S.guar)), res, String(b.get("item", "")), b.get("newbie", false))
	main.show_chrome(false, false)
	banner_root.visible = false
	var best: = V9Summon.best_rar(res)
	seq = Control.new()
	seq.size = size
	seq.mouse_filter = Control.MOUSE_FILTER_STOP
	seq.gui_input.connect(_seq_input)
	add_child(seq)
	# night falls: a dim plus a radial vignette, so the lantern is the only light on screen
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.04, 0.02, 0.08, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seq.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, 0.6)
	var vg: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.38)
	gt.fill_to = Vector2(1.15, 1.0)
	var gr: = Gradient.new()
	gr.set_color(0, Color(0.03, 0.01, 0.06, 0.0))
	gr.set_color(1, Color(0.03, 0.01, 0.06, 0.85))
	gt.gradient = gr
	gt.width = 256
	gt.height = 256
	vg.texture = gt
	vg.size = size
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vg.modulate.a = 0.0
	seq.add_child(vg)
	vg.create_tween().tween_property(vg, "modulate:a", 1.0, 0.8)
	# 0.9: one magic circle on the lantern stage — the lit floor under the lantern; the circle painted into the
	# backdrop's bottom edge sinks into the night (it fades back with the other stage effects when the cards deal)
	var ff: = Common.floor_fade(seq, FLOOR_Y + 196.0, H, Color(0.03, 0.01, 0.06), 0.97)
	ff.modulate.a = 0.0
	ff.create_tween().tween_property(ff, "modulate:a", 1.0, 0.8)
	seq_fx.append(ff)
	Sfx.music("")
	_mus(V9Summon.SUSPENSE_PITCH, V9Summon.SUSPENSE_DB, 1.2)
	Sfx.say(b.hero, "gacha")
	_build_top_hud()
	if ctx.get("skip", false):
		var holder: = Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seq.add_child(holder)
		skip_btn = JButton.make("Пропустить", "glass", Rect2(W - 214, 22, 190, 58), null, 20)
		skip_btn.pressed.connect(_skip)
		holder.add_child(skip_btn)
		UI.slide_in(skip_btn, Vector2(40, 0), 0.4)
	# the magic circle becomes the lit floor under the lantern
	move_child(circle, get_child_count() - 1)
	var ct: = create_tween().set_parallel()
	ct.tween_property(circle, "position:y", FLOOR_Y - 310, 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	ct.tween_property(circle, "scale", Vector2(0.86, 0.3), 0.9)
	ct.tween_method( func(v): circle_mat.set_shader_parameter("power", v), 0.25, 0.55, 0.9)
	move_child(seq, get_child_count() - 1)

	# ---- stage 1: the lantern drops in, unlit
	stage = "lantern"
	lantern = V9Lantern.new()
	lantern.setup(LANTERN_H, "R", dev_code)
	lantern.position.x = W * 0.5 - lantern.size.x * 0.5
	seq.add_child(lantern)
	# the counter stays above the lantern's cord
	seq.move_child(top_hud, -1)
	lantern.drop_in(-LANTERN_H - 80, LANTERN_Y, V9Summon.DROP)
	Sfx.play("whoosh", 0.8, -6)
	hint_lbl = UI.center_label(UI.label("Коснись фонаря, чтобы зажечь", 22, Color(1, 0.96, 0.88, 0.95), Color(0.12, 0.04, 0.16), 5), Rect2(0, FLOOR_Y + 150, W, 40))
	hint_lbl.modulate.a = 0.0
	seq.add_child(hint_lbl)
	var ht: = hint_lbl.create_tween()
	ht.tween_interval(V9Summon.DROP)
	ht.tween_property(hint_lbl, "modulate:a", 1.0, 0.3)
	ht.tween_callback( func():
		if is_instance_valid(hint_lbl):
			var hl: = hint_lbl.create_tween().set_loops()
			hl.tween_property(hint_lbl, "modulate:a", 0.45, 0.7)
			hl.tween_property(hint_lbl, "modulate:a", 1.0, 0.7))
	await _wait(V9Summon.DROP * 0.7)
	await _wait_tap(V9Summon.AUTO_LIGHT)
	if skipping:
		return
	if not _alive():
		return

	# ---- stage 2: the colour climbs to the best rarity; the music changes with it
	stage = "climb"
	if is_instance_valid(hint_lbl):
		var hf: = hint_lbl.create_tween()
		hf.tween_property(hint_lbl, "modulate:a", 0.0, 0.2)
		hf.tween_callback(hint_lbl.queue_free)
	lantern.light(0.4)
	Sfx.play("sparkle", 0.85, -2)
	V9Feel.haptic("tap")
	_circle_to(V9Summon.COL.R, 0.5)
	await _wait(V9Summon.LIGHT)
	for rar in V9Summon.steps(best).slice(1):
		if skipping or not _alive():
			break
		if rar == "SSR":
			# the long build: the lantern trembles, light streams in, a rising charge
			lantern.charge(true)
			Sfx.play("summon_charge", 1.0, -2)
			_stream_in(V9Summon.COL.SSR, float(V9Summon.STEP.SSR))
			await _wait(float(V9Summon.STEP.SSR) * 0.85)
			if skipping or not _alive():
				break
			lantern.charge(false)
			lantern.morph("SSR", 0.3)
			Sfx.duck(-10, 1.6)
			Sfx.play("reveal_ssr")
			_flash(V9Summon.COL.SSR, 0.5)
			if V9Feel.can_shake():
				Fx.shake(seq, 7, 0.45)
			_circle_to(V9Summon.COL.SSR, 0.3)
			if V9Feel.can_fx():
				var ry: = Common.rays(seq, lantern.centre(), 1300, Color(1, 0.84, 0.4, 0.55), 14, 0.04, 0.8)
				seq.move_child(ry, lantern.get_index())
				ry.modulate.a = 0.0
				ry.create_tween().tween_property(ry, "modulate:a", 1.0, 0.4)
				_fx_node(ry)
			Fx.burst(seq, lantern.centre(), "sparkle", 50, V9Summon.COL.SSR, 1.8)
		else:
			await _wait(float(V9Summon.STEP[rar]) * 0.6)
			if skipping or not _alive():
				break
			lantern.morph(rar, 0.3)
			Sfx.play("reveal_sr", 1.0, -2)
			Fx.burst(seq, lantern.centre(), "sparkle", 30, V9Summon.COL[rar], 1.2)
			_circle_to(V9Summon.COL[rar], 0.3)
			await _wait(float(V9Summon.STEP[rar]) * 0.4)
	if skipping or not _alive():
		return
	_mus(V9Summon.MUSIC_PITCH[best], V9Summon.MUSIC_DB[best], 0.8)
	_show_caption(best)
	await _wait(V9Summon.HOLD[best])
	if skipping or not _alive():
		return

	# ---- the lantern opens: the cards come out of its light
	Sfx.play("summon_boom", 1.0 if best == "SSR" else 1.12, 0.0 if best == "SSR" else -4.0)
	var lc: = lantern.centre()
	lantern.open(0.45)
	_flash(V9Summon.COL[best], 0.35 if best != "SSR" else 0.55)
	Fx.burst(seq, lc, "sparkle", 70 if best == "SSR" else 40, V9Summon.COL[best], 2.0)
	if is_instance_valid(lantern_cap):
		var cf: = lantern_cap.create_tween()
		cf.tween_property(lantern_cap, "modulate:a", 0.0, 0.3)
	var cc: = create_tween()
	cc.tween_property(circle, "modulate:a", 0.0, 0.5)
	await _wait(0.25)
	if skipping or not _alive():
		return
	_deal_cards(res, lc)

func _circle_to(c: Color, dur: float) -> void :
	var from: Color = circle_mat.get_shader_parameter("color")
	create_tween().tween_method( func(v): circle_mat.set_shader_parameter("color", v), from, Color(c.r, c.g, c.b, 0.95), dur)

# light streaming into the lantern from the whole screen (SSR build-up)
func _stream_in(col: Color, dur: float) -> void :
	var n: = Fx.scaled(80)
	if n <= 0:
		return
	var p: = Fx.particles("glow", n, 0.9)
	p.material = Fx.add_mat()
	p.position = lantern.centre()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 420
	p.spread = 0
	p.initial_velocity_max = 0
	p.radial_accel_min = -900
	p.radial_accel_max = -700
	p.tangential_accel_min = 160
	p.tangential_accel_max = 260
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.26
	p.color = col
	seq.add_child(p)
	_fx_node(p)
	get_tree().create_timer(dur).timeout.connect( func():
		if is_instance_valid(p):
			p.emitting = false
			get_tree().create_timer(1.0).timeout.connect( func():
				if is_instance_valid(p):
					p.queue_free()))

# a soft flash in the rarity colour (never white); none at «минимум», gentler at «умеренные»
func _flash(col: Color, a: float) -> void :
	if not V9Feel.can_fx() or not _alive():
		return
	if not V9Feel.can_edge_flash():
		a *= 0.5
	var f: = ColorRect.new()
	f.size = size
	f.color = Color(col.lerp(Color(1, 0.95, 0.85), 0.2), a)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seq.add_child(f)
	var ft: = f.create_tween()
	ft.tween_property(f, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.tween_callback(f.queue_free)

func _show_caption(best: String) -> void :
	if is_instance_valid(lantern_cap):
		lantern_cap.queue_free()
	var col: Color = V9Summon.COL[best]
	lantern_cap = Control.new()
	lantern_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lantern_cap.position = Vector2(0, LANTERN_Y + LANTERN_H + 14)
	lantern_cap.size = Vector2(W, 100)
	lantern_cap.pivot_offset = Vector2(W * 0.5, 30)
	seq.add_child(lantern_cap)
	var t1: = UI.center_label(UI.title(V9Summon.NAME[best], 40 if best == "SSR" else 36, col.lerp(Color.WHITE, 0.55), col.darkened(0.6)), Rect2(0, 0, W, 56))
	lantern_cap.add_child(t1)
	var t2: = UI.center_label(UI.label(V9Summon.SUB[best], 20, col.lerp(Color.WHITE, 0.3), Color(0.1, 0.03, 0.14), 4, "body", 900), Rect2(0, 56, W, 32))
	lantern_cap.add_child(t2)
	UI.pop_in(lantern_cap, 0.0, 0.7)

# the pity counter and the banner guarantee, visible for the whole sequence; ticks per flipped card
func _build_top_hud() -> void :
	var b: Dictionary = G.BANNERS[banner_i]
	var newbie: bool = b.get("newbie", false)
	top_hud = Control.new()
	top_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seq.add_child(top_hud)
	# left of the lantern's cord (x = W/2), the skip button sits on the right
	var box: = UI.rbox("plum", Rect2(20, 18, 316, 86), 22, 2, 8)
	box.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud.add_child(box)
	var l1: = UI.label("До гаранта SSR", 17, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 3, "body", 900)
	l1.position = Vector2(16, 8)
	box.add_child(l1)
	pity_num = UI.label(str(V9Summon.left(int(seq_ctx.get("pity", G.S.pity)))), 26, Color.WHITE, Color("7a4a0c"), 4, "body", 900)
	pity_num.position = Vector2(16 + l1.get_minimum_size().x + 8, 1)
	box.add_child(pity_num)
	pity_bar = Common.progress_bar(box, PITY_BAR, float(seq_ctx.get("pity", G.S.pity)) / float(V9Summon.PITY_MAX), "gold")
	guar_lbl = UI.label("", 16, Color("f4e6ff"), Color(0.2, 0.05, 0.2), 3, "body", 800)
	guar_lbl.position = Vector2(16, 54)
	box.add_child(guar_lbl)
	if newbie:
		guar_lbl.text = "SSR-наряд в первых 20 желаниях"
	else:
		_set_guar(bool(seq_ctx.get("guar", G.S.guar)))
	UI.slide_in(top_hud, Vector2(0, -40), 0.2)

func _set_guar(g: bool) -> void :
	if guar_lbl == null or not is_instance_valid(guar_lbl) or G.BANNERS[banner_i].get("newbie", false):
		return
	guar_lbl.text = "Следующая SSR — с баннера ✓" if g else "Следующая SSR: 50/50 на баннер"
	guar_lbl.label_settings.font_color = Color("ffe7a6") if g else Color("f4e6ff")

func _tick_pity(i: int) -> void :
	if i < 0 or i >= pity_steps.size() or pity_num == null or not is_instance_valid(pity_num):
		return
	var p: int = pity_steps[i]
	pity_num.text = str(V9Summon.left(p))
	if is_instance_valid(pity_bar):
		pity_bar.queue_free()
	pity_bar = Common.progress_bar(pity_num.get_parent(), PITY_BAR, float(p) / float(V9Summon.PITY_MAX), "gold")
	if String(seq_res[i].get("rar", "R")) == "SSR":
		UI.punch(pity_num, 0.4, 0.4)
		Fx.burst(top_hud, Vector2(80, 40), "sparkle", 18, V9Summon.COL.SSR, 0.6)
		_set_guar(guar_steps[i])
	else:
		UI.punch(pity_num, 0.12, 0.2)

func _skip() -> void :
	if skipping or results_shown or not _alive():
		return
	skipping = true
	if is_instance_valid(skip_btn):
		skip_btn.get_parent().queue_free()
	skip_btn = null
	_finish_skipped()

# skip: everything left is shown at once (cards face up, counter final), then each SSR still gets its showcase
func _finish_skipped() -> void :
	await get_tree().process_frame
	if not _alive():
		return
	stage = "deal"
	if is_instance_valid(lantern):
		lantern.queue_free()
	if is_instance_valid(lantern_cap):
		lantern_cap.queue_free()
	if is_instance_valid(hint_lbl):
		hint_lbl.queue_free()
	for n in seq_fx:
		if is_instance_valid(n):
			n.queue_free()
	seq_fx.clear()
	circle.visible = false
	var best: = V9Summon.best_rar(seq_res)
	_mus(V9Summon.MUSIC_PITCH[best], V9Summon.MUSIC_DB[best], 0.4)
	if not dealt:
		_layout_cards(seq_res, Vector2(W * 0.5, H * 0.4), true)
	Sfx.play("flip")
	for i in cards.size():
		if not flipped.has(i):
			flipped[i] = true
			var c: Control = cards[i]
			c.get_node("Back").visible = false
			c.get_node("Front").visible = true
	_settle_cards()
	# tweens already running on a card (deal, flip, the SSR lift and shake) end within a second: settle again after
	get_tree().create_timer(1.0).timeout.connect(_settle_cards)
	if pity_steps.size() > 0:
		_tick_pity(pity_steps.size() - 1)
		_set_guar(guar_steps[guar_steps.size() - 1])
	for i in seq_res.size():
		var r: Dictionary = seq_res[i]
		if r.rar == "SSR" and not showcased.has(i):
			showcased[i] = true
			await _showcase(r)
			if not _alive():
				return
	flipping = false
	stage = "results"
	_results(seq_res)

func _settle_cards() -> void :
	for c in cards:
		if not is_instance_valid(c):
			continue
		c.position = c.get_meta("slot", c.position)
		c.scale = Vector2.ONE
		c.rotation = 0.0
		c.modulate = Color.WHITE
		if c.has_meta("shake_base"):
			c.remove_meta("shake_base")

func _layout_cards(res: Array, from: Vector2, instant: = false) -> void :
	cards.clear()
	dealt = true
	var n: = res.size()
	# 0.8: a 10-pull is dealt 3-4-3 at 160×240 (was 2×5 at 124×186) and centred between the «Результаты» ribbon
	# and the button row, so the cards read and the screen has no dead band above the buttons
	var cw: = 160.0 if n > 1 else 300.0
	var ch: = cw * 1.5
	var gap: = 14.0
	var vgap: = 22.0
	var row_n: = [3, 4, 3] if n == 10 else ([n] if n <= 5 else [5, n - 5])
	var slots: = []
	var top: = 190.0
	var bottom: = H - 190.0
	var grid_h: = row_n.size() * ch + (row_n.size() - 1) * vgap
	var y0: = top + (bottom - top - grid_h) * 0.5 if n > 1 else H * 0.5 - ch * 0.5 - 30
	for ri in row_n.size():
		var rn: int = row_n[ri]
		var rw: = rn * cw + (rn - 1) * gap
		for ci in rn:
			slots.append(Vector2((W - rw) * 0.5 + ci * (cw + gap), y0 + ri * (ch + vgap)))
	for i in n:
		var r: Dictionary = res[i]
		var pos: Vector2 = slots[i]
		var c: = _card(r, Vector2(cw, ch))
		c.set_meta("slot", pos)
		seq.add_child(c)
		cards.append(c)
		if instant:
			c.position = pos
			continue
		c.position = from - Vector2(cw, ch) * 0.5
		c.scale = Vector2(0.15, 0.15)
		c.rotation = randf_range(-0.8, 0.8)
		var d: = i * 0.06
		var t: Tween = c.create_tween().set_parallel()
		t.tween_property(c, "position", pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		t.tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		t.tween_property(c, "rotation", 0.0, 0.5).set_delay(d)
		get_tree().create_timer(d).timeout.connect( func(): Sfx.play("flip", randf_range(0.9, 1.1), -3))

func _deal_cards(res: Array, from: = Vector2(-1, -1)) -> void :
	if from.x < 0:
		from = Vector2(W * 0.5, H * 0.45)
	stage = "deal"
	for fx in seq_fx:
		if is_instance_valid(fx) and fx is CanvasItem:
			var ft: = (fx as CanvasItem).create_tween()
			ft.tween_property(fx, "modulate:a", 0.0, 0.8)
	_layout_cards(res, from)
	var n: = res.size()
	await _wait(0.65 + n * 0.06)
	for i in n:
		if skipping or not _alive():
			return
		var c: Control = cards[i]
		var r: Dictionary = res[i]
		if r.rar == "SSR":
			# the grand reveal: the card rises in a gold pillar, trembles, then flips into the showcase
			await _ssr_build(c)
			if skipping or not _alive():
				return
		flipped[i] = true
		await _flip(c, r)
		_tick_pity(i)
		if skipping or not _alive():
			return
		if r.rar == "SSR":
			showcased[i] = true
			await _showcase(r)
			if not _alive():
				return
			_ssr_return(c)
			await _wait(0.35)
		elif not hurry:
			await _wait(0.1 if r.rar == "R" else 0.3)
	if skipping or not _alive():
		return
	if is_instance_valid(skip_btn):
		skip_btn.get_parent().queue_free()
		skip_btn = null
	flipping = false
	stage = "results"
	_results(res)

# the SSR card leaves the grid for the centre of the screen, the rest of the pull dims, a gold pillar rises behind
# it and it trembles; the flip happens there, then the showcase, then the card settles back into its slot
func _ssr_build(c: Control) -> void :
	var col: Color = V9Summon.COL.SSR
	seq.move_child(c, seq.get_child_count() - 1)
	var dur: = V9Summon.SSR_BUILD_HURRY if hurry else V9Summon.SSR_BUILD
	var move: = 0.3 if hurry else 0.4
	var k: = 1.0 if cards.size() == 1 else 1.55
	var target: = Vector2(W * 0.5, H * 0.47) - c.size * 0.5
	for o in cards:
		if o != c:
			o.create_tween().tween_property(o, "modulate", Color(0.5, 0.47, 0.56), move)
	var mt: = c.create_tween().set_parallel()
	mt.tween_property(c, "position", target, move).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	mt.tween_property(c, "scale", Vector2(k, k), move).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", 1.1, -4)
	# wait for the tween itself (not the clock): the shake below must start from the card's final place
	while _alive() and not skipping and mt.is_running():
		await get_tree().process_frame
	if skipping or not _alive():
		return
	var center: = target + c.size * 0.5
	if V9Feel.can_fx():
		var ry: = Common.rays(seq, center, 1200, Color(col.r, col.g, col.b, 0.8), 12, 0.08, 1.0)
		seq.move_child(ry, c.get_index())
		ry.scale = Vector2(0.3, 0.3)
		var rt: = ry.create_tween()
		rt.tween_property(ry, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		rt.tween_property(ry, "modulate:a", 0.0, 0.6)
		rt.tween_callback(ry.queue_free)
		_fx_node(ry)
	Fx.flash_glow(seq, center, Color(1, 0.85, 0.4), 6.0, dur)
	Sfx.play("summon_charge", 1.25, -4)
	if V9Feel.can_shake():
		Fx.shake(c, 5, dur * 0.9)
	await _wait(dur)
	c.remove_meta("shake_base")

func _ssr_return(c: Control) -> void :
	if not is_instance_valid(c):
		return
	var t: = c.create_tween().set_parallel()
	t.tween_property(c, "position", c.get_meta("slot", c.position), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for o in cards:
		if o != c and is_instance_valid(o):
			o.create_tween().tween_property(o, "modulate", Color.WHITE, 0.4)

func _card(r: Dictionary, sz: Vector2) -> Control:
	var c: = Control.new()
	c.size = sz
	c.pivot_offset = sz * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: = G.rar_color(r.rar)
	if r.rar != "R":
		var aura: = Sprite2D.new()
		aura.texture = G.fx("glow")
		aura.material = Fx.add_mat()
		aura.modulate = Color(col.r, col.g, col.b, 0.85)
		aura.position = sz * 0.5
		aura.scale = Vector2(sz.x / 50.0, sz.y / 55.0)
		c.add_child(aura)
		var at: Tween = aura.create_tween().set_loops()
		at.tween_property(aura, "modulate:a", 0.45, 0.5)
		at.tween_property(aura, "modulate:a", 0.85, 0.5)
	var back: = UI.tex(load("res://assets/ui/card_back.webp"), Rect2(Vector2.ZERO, sz), false)
	back.name = "Back"
	var bm: = ShaderMaterial.new()
	bm.shader = preload("res://shaders/card.gdshader")
	bm.set_shader_parameter("size", sz)
	bm.set_shader_parameter("radius", 12.0)
	bm.set_shader_parameter("tex_size", Vector2(424, 632))
	bm.set_shader_parameter("focus", Vector2(0.5, 0.5))
	bm.set_shader_parameter("bottom_shade", 0.0)
	back.material = bm
	c.add_child(back)
	var front: = Control.new()
	front.name = "Front"
	front.size = sz
	front.visible = false
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(front)
	# 0.8: the front is the rarity frame art (frame/card_r|sr|ssr) over the item picture
	var tex: = G.art_tex(r)
	var focus: = Vector2(0.5, 0.28) if r.cat == "outfit" else Vector2(0.5, 0.5)
	var inner: = Common.card_inner(r.rar, sz)
	var art: = Common.card_art(tex, inner, focus, 1.0 if r.cat != "skin" else 0.75, Common.card_radius(r.rar, sz))
	var am: ShaderMaterial = art.material
	am.set_shader_parameter("holo", 0.6 if r.rar == "SSR" else 0.0)
	am.set_shader_parameter("bottom_shade", 0.8)
	front.add_child(art)
	Common.card_frame(front, r.rar, Rect2(Vector2.ZERO, sz))
	var small: = sz.x < 200
	var fs: = (16 if sz.x < 150 else 18) if small else 26
	# rarity tag: a pill in the top-right corner, inside the frame and clear of its crest and flowers
	var rfs: = 16 if small else 24
	var rw: = UI.font("body", 900).get_string_size(r.rar, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x + (14.0 if small else 22.0)
	var rh: = 24.0 if small else 36.0
	var rr: = Rect2(sz.x - rw - (8.0 if small else 18.0), inner.position.y + (4.0 if small else 10.0), rw, rh)
	var rtag: = UI.rbox("graphite", rr, rh * 0.5, 2, 4)
	rtag.borders(col.lerp(Color.WHITE, 0.35), col.darkened(0.45))
	rtag.name = "Rar"
	front.add_child(rtag)
	rtag.add_child(UI.center_label(UI.label(r.rar, rfs, col.lerp(Color.WHITE, 0.45), UI.DARK, 3, "body", 900), Rect2(0, -1, rw, rh)))
	var nl: = UI.label(r.name, fs, Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
	# 0.8: the name is fitted to the card (16 px floor, lighter weight / hyphenation / «…» past that) and its box
	# grows UP from the frame's bottom rim by the wrapped height, so a third line («Фон» / «Чайный» / «сад»») stays
	# inside the card instead of running below its bottom edge
	var nw: = sz.x - 12.0
	var lines: = 3 if small else 2
	Common.fit_words(nl, nw, lines, 16)
	var ls: LabelSettings = nl.label_settings
	var pad: = float(ls.outline_size)
	var th: = ls.font.get_multiline_string_size(nl.text, HORIZONTAL_ALIGNMENT_CENTER, nw - pad, ls.font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	var lh: = ls.font.get_height(ls.font_size)
	th = minf(th, lh * lines)
	var nl_n: = int(round(th / lh))
	var nh: = maxf(46.0 if small else 70.0, th + ls.line_spacing * maxf(0.0, nl_n - 1) + 4.0)
	nl.position = Vector2((sz.x - nw) * 0.5, sz.y - 8.0 - nh if small else sz.y - 16.0 - nh)
	nl.size = Vector2(nw, nh)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	front.add_child(nl)
	if not r.get("new", false) and r.has("id"):
		# 0.8: a repeat says what it turned into («+25» crystals, G.give) and steps back a little, so the new
		# pieces and the SSR stand out in a 10-pull
		var dr: = Rect2(-8, -14, 78, 28) if small else Rect2(-12, -12, 120, 38)
		var db: = UI.rbox("graphite", dr, dr.size.y * 0.5, 2, 4)
		db.borders(Color("ffe7a6"), Color("c58a2c"))
		db.name = "Dup"
		front.add_child(db)
		var gsz: = dr.size.y + 4.0
		db.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(-2, -2, gsz, gsz)))
		db.add_child(UI.center_label(UI.label("+%d" % G.DUP_GEMS, 16 if small else 22, Color("ffe7a6"), UI.DARK, 3, "body", 900), Rect2(gsz - 6, 0, dr.size.x - gsz, dr.size.y)))
		art.modulate = Color(0.8, 0.78, 0.84)
	if r.get("new", false):
		# 0.8: «НОВОЕ» hangs off the top-left corner; the rarity tag is top-right, so they never overlap
		var nr: = Rect2(-8, -14, 76, 26) if small else Rect2(-12, -12, 110, 34)
		var nb: = UI.rbox("red", nr, nr.size.y * 0.5, 2, 4)
		nb.name = "New"
		front.add_child(nb)
		nb.add_child(UI.center_label(UI.label(V6Txt.s("common.new"), 16 if small else 20, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(Vector2.ZERO, nr.size)))
	return c

func _flip(c: Control, r: Dictionary) -> void :
	# flips around the card's current scale (the SSR card flips enlarged at the centre)
	var k: = c.scale.x
	var t: Tween = c.create_tween()
	t.tween_property(c, "scale", Vector2(0.0, 1.08 * k), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		c.get_node("Back").visible = false
		c.get_node("Front").visible = true)
	t.tween_property(c, "scale", Vector2(1.08 * k, 1.08 * k), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2(k, k), 0.12)
	Sfx.play("flip")
	await t.finished
	var center: = c.position + c.size * 0.5
	match r.rar:
		"SSR":
			Sfx.play("reveal_ssr")
		"SR":
			Sfx.play("reveal_sr")
			Fx.burst(seq, center, "sparkle", 26, V9Summon.COL.SR, 1.0)
			Fx.ring(seq, center, V9Summon.COL.SR, 1.4)
		_:
			Sfx.play("reveal_r", randf_range(0.95, 1.1), -4)

func _showcase(r: Dictionary) -> void :
	showcase = Control.new()
	showcase.size = size
	showcase.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(showcase)
	var bg: = ColorRect.new()
	bg.size = size
	# 0.9: opaque enough that the result grid underneath never ghosts through around the card
	bg.color = Color(0.06, 0.02, 0.1, 0.985)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(bg)
	# 0.9: the showcase opens in the gold of the lantern: a warm veil that settles into the night backdrop
	var veil: = ColorRect.new()
	veil.size = size
	veil.color = Color(V9Summon.COL.SSR, 0.22 if V9Feel.can_fx() else 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(veil)
	veil.create_tween().tween_property(veil, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if V9Feel.can_fx():
		Common.rays(showcase, Vector2(W * 0.5, H * 0.42), 1500, Color(1, 0.82, 0.35, 0.8), 18, 0.05, 1.0)
		Common.rays(showcase, Vector2(W * 0.5, H * 0.42), 900, Color(1, 0.6, 0.85, 0.5), 9, -0.08, 0.7)
	# 0.9: the reveal's particles (petals, gold dust) live on this layer, behind the card and the name ribbon
	var parts: = Control.new()
	parts.size = size
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(parts)
	# 0.8: the frame art is drawn at most 1.4× its 344×512 source (larger turns soft)
	var aw: = 344.0 * 1.4
	var ah: = aw * 512.0 / 344.0
	var fr: = Rect2((W - aw) * 0.5, H * 0.42 - ah * 0.5, aw, ah)
	var inner: = Common.card_inner(r.rar, fr.size)
	# art + frame zoom in together through one holder (the frame node itself is scaled down to its size)
	var card: = Control.new()
	card.position = fr.position
	card.size = fr.size
	card.pivot_offset = fr.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(card)
	var art: = Common.card_art(G.art_tex(r), inner, Vector2(0.5, 0.45), 1.0, Common.card_radius(r.rar, fr.size))
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.45)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.6)
	card.add_child(art)
	Common.card_frame(card, r.rar, Rect2(Vector2.ZERO, fr.size))
	card.scale = Vector2(1.6, 1.6)
	card.modulate.a = 0
	var ct0: Tween = card.create_tween().set_parallel()
	ct0.tween_property(card, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ct0.tween_property(card, "modulate:a", 1.0, 0.25)
	# a slow breath on the card while it is on show
	ct0.chain().tween_callback( func():
		if is_instance_valid(card):
			var br: = card.create_tween().set_loops()
			br.tween_property(card, "scale", Vector2(1.02, 1.02), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			br.tween_property(card, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	var ssr: = UI.title("SSR", 120, Color("fff1b8"), Color("c0661a"))
	ssr.position = Vector2(30, H * 0.42 - ah * 0.5 - 70)
	ssr.rotation = deg_to_rad(-8)
	showcase.add_child(ssr)
	UI.pop_in(ssr, 0.35, 3.0)
	var rib: = Common.ribbon(showcase, r.name, Rect2(40, H * 0.42 + ah * 0.5 - 30, W - 80, 86), "pink", 34)
	UI.slide_in(rib, Vector2(0, 80), 0.45)
	if r.has("hero"):
		var hl: = UI.center_label(UI.label(G.HEROES[r.hero].name + " · " + G.HEROES[r.hero].title, 24, Color("ffe7a6"), Color(0.2, 0.05, 0.2), 5, "body", 900), Rect2(0, 86, W - 80, 36))
		rib.add_child(hl)
	if r.has("id") and V9Ults.has(String(r.id)):
		# 0.9: an outfit SSR names its ult (HEROINES.md §5), so the reveal says what the outfit does in a match
		var un: String = V9Ults.get_ult(String(r.id)).get("name", "")
		if un != "":
			var ul: = UI.center_label(UI.label("Ульта «%s»" % un, 20, Color("f4e6ff"), Color(0.2, 0.05, 0.2), 4, "body", 800), Rect2(0, 122, W - 80, 30))
			rib.add_child(ul)
	if r.get("new", false):
		var nb: = UI.rbox("red", Rect2(W - 40 - 150, H * 0.42 - ah * 0.5 - 22, 132, 42), 21, 2, 4)
		showcase.add_child(nb)
		nb.add_child(UI.center_label(UI.label(V6Txt.s("common.new"), 22, Color.WHITE, Color("6a1020"), 3, "body", 900), Rect2(0, 0, 132, 42)))
		UI.pop_in(nb, 0.6, 1.8)
	Fx.burst(parts, Vector2(W * 0.5, H * 0.42), "sparkle", 90, Color(1, 0.85, 0.45), 2.2)
	# sakura petals and gold dust (not flat confetti), from behind the card, never over the name plate
	Fx.burst(parts, Vector2(W * 0.5, H * 0.36), "petal", 36, Color(1, 0.8, 0.88), 1.6)
	Fx.burst(parts, Vector2(W * 0.5, H * 0.36), "sparkle", 40, Color(1, 0.86, 0.5), 1.5)
	Fx.ambient(showcase, "stars", size)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	Sfx.duck(-7, 2.2)
	Sfx.say(r.get("hero", "mc"), "ssr")
	var tap: = UI.center_label(UI.label(V6Txt.s("summon.tap"), 22, Color(1, 1, 1, 0.85), Color(0.2, 0.05, 0.2), 4), Rect2(0, H - 90, W, 40))
	showcase.add_child(tap)
	var tt: Tween = tap.create_tween().set_loops()
	tt.tween_property(tap, "modulate:a", 0.3, 0.6)
	tt.tween_property(tap, "modulate:a", 1.0, 0.6)
	# 0.8: a tap anywhere continues (the backdrop and art used to swallow the tap, found by the --pt playtest)
	for c in showcase.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var done: = [false]
	showcase.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			done[0] = true)
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
	var ct: Tween = showcase.create_tween()
	ct.tween_property(showcase, "modulate:a", 0.0, 0.25)
	ct.tween_callback(showcase.queue_free)
	showcase = null
	if seq == null:
		Sfx.music("summon")

func _results(res: Array) -> void :
	results_shown = true
	var by: = H - 170
	var nb: bool = G.BANNERS[banner_i].get("newbie", false)
	if nb and int(G.S.newbie_left) <= 0:
		banner_i = 1
		nb = false
	# 0.8: «Ещё ×N» is the one primary; «Готово» is the quiet graphite secondary
	var again: = JButton.make(V6Txt.s("summon.more") % res.size(), "pink", Rect2(30, by, 320, 110), null, 32)
	again.set_cost(V8Art.cur("gem"), G.NEWBIE_COST if nb and res.size() == 10 else G.PULL_COST * res.size(), 22)
	again.shine_every = 2.4
	again.pressed.connect( func():
		_close_seq()
		_pull(res.size()))
	seq.add_child(again)
	var ok: = JButton.make(V6Txt.s("common.done"), "graphite", Rect2(W - 350, by, 320, 110), null, 34)
	ok.pressed.connect(_close_seq)
	seq.add_child(ok)
	UI.slide_in(again, Vector2(0, 80), 0.0)
	UI.slide_in(ok, Vector2(0, 80), 0.08)
	var ttl: = Common.ribbon(seq, V6Txt.s("summon.results"), Rect2(W * 0.5 - 270, 112, 540, 84), "lav", 36)
	UI.pop_in(ttl, 0.0)

func _close_seq() -> void :
	if seq:
		seq.queue_free()
		seq = null
	stage = ""
	skipping = false
	hurry = false
	lantern = null
	skip_btn = null
	_mus_stop(0.4)
	circle.visible = true
	circle.modulate.a = 1.0
	circle.position = Vector2(W * 0.5 - 310, H - 132 - 330)
	circle.scale = Vector2(1.0, 0.36)
	circle_mat.set_shader_parameter("power", 0.25)
	circle_mat.set_shader_parameter("spin", 0.2)
	circle_mat.set_shader_parameter("color", Color(0.65, 0.85, 1.0, 0.9))
	main.show_chrome(true, true)
	main.refresh_currency()
	Sfx.music("summon")
	_build_banner()

# Android «назад» during the pull sequence: close the results when they are shown, skip when skipping is allowed,
# otherwise ignore.
func handle_back() -> bool:
	if seq and is_instance_valid(seq):
		if results_shown and not flipping:
			_close_seq()
		elif skip_btn and is_instance_valid(skip_btn) and showcase == null:
			_skip()
		return true
	return false

func demo_skip() -> bool:
	if showcase:
		var ev: = InputEventMouseButton.new()
		ev.pressed = true
		ev.button_index = MOUSE_BUTTON_LEFT
		showcase.gui_input.emit(ev)
		return true
	if stage == "lantern":
		tapped = true
	return flipping

# dev (main.gd --act=…): pull10 = a real 10-pull with a forced SSR (G.demo_force_ssr);
# r1 / sr1 / ssr1 / r10 / sr10 / ssr10 = a preview pull with that best rarity (nothing given, nothing spent);
# second = previews behave like a second summon (skip shown); code = code-drawn lantern; tap = a tap on the
# sequence; skip = the skip button; fx_full / fx_mid / fx_min = effects level; selftest = summon rules selftest
var dev_second: = false
var dev_code: = false

func dev_act(a: String) -> void :
	if a == "pull10":
		G.demo_force_ssr = true
		_pull(10)
	elif a in ["r1", "sr1", "ssr1", "r10", "sr10", "ssr10"]:
		if seq != null:
			return
		var n: = 10 if a.ends_with("10") else 1
		var best: = a.trim_suffix("10").trim_suffix("1").to_upper()
		dev_preview = true
		var ctx: = {"pity": int(G.S.pity), "guar": bool(G.S.guar), "skip": dev_second}
		_sequence(V9Summon.dev_results(n, best, G.BANNERS[banner_i]), ctx)
	elif a == "second":
		dev_second = true
	elif a == "code":
		dev_code = true
	elif a.begins_with("fx_"):
		# dev only: not saved (the level is put back when the screen closes), so a preview never changes the save
		if not has_meta("dev_fx_keep"):
			set_meta("dev_fx_keep", G.fx_level())
			tree_exiting.connect( func(): G.S.fx_level = get_meta("dev_fx_keep"))
		G.S.fx_level = a.substr(3)
	elif a == "tap":
		var ev: = InputEventMouseButton.new()
		ev.pressed = true
		ev.button_index = MOUSE_BUTTON_LEFT
		if showcase:
			showcase.gui_input.emit(ev)
		elif seq:
			_seq_input(ev)
	elif a == "skip":
		if skip_btn and is_instance_valid(skip_btn):
			_skip()
		else:
			demo_skip()
	elif a == "selftest":
		V9SummonSelftest.run(self)
	elif a.begins_with("b"):
		banner_i = int(a.substr(1))
		_build_banner()
