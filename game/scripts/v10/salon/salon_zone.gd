class_name V10SalonZone
extends Control

# One zone on the salon map: the painted room (ruined art with restored parts revealed by salon_zone.gdshader),
# mist over what is still broken, hanging tags over unrestored tasks, a title plate, and — once the zone is
# finished — her heroine living in it plus a «Сцена» button (spec §Р1 п.3, §Р2 п.1).
# The screen calls set_visible_live(on) from its scroll check: textures, rig and mist only run while visible.

signal task_tapped(zid: String, tid: String)
signal scene_tapped(zid: String)
signal heroine_tapped(zid: String, zone: String)

const ROMAN: = ["I", "II", "III", "IV", "V", "VI"]

var zid: = ""
var z: Dictionary
var art: ColorRect
var mat: ShaderMaterial
var mist: ColorRect
var mist_mat: ShaderMaterial
var tags: = {}  # tid -> V10SalonTag
var tag_layer: Control
var heroine: V10SalonHeroine
var scene_btn: V10SalonButton
var title_box: Control
var prog_lbl: Label
var locked: = false
var hint_tid: = ""
var _idx: = {}  # tid -> [rect indices]
var _rects: = PackedVector4Array()
var _prog: = PackedFloat32Array()
var _jade: = PackedFloat32Array()
var _pop: = PackedVector2Array()
var _glint: = PackedFloat32Array()
var _finale: = 0.0
var _t: = 0.0
var _live: = false
var _loaded: = false


static func height_for(w: float) -> float:
	return roundf(w / V10SalonData.ZONE_ASPECT)


static func make(zid_: String, w: float) -> V10SalonZone:
	var n: = V10SalonZone.new()
	n.zid = zid_
	n.z = V10SalonData.zone(zid_)
	n.size = Vector2(w, height_for(w))
	n.custom_minimum_size = n.size
	n.clip_contents = true
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	n._build()
	return n


func _build() -> void:
	art = ColorRect.new()
	art.size = size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/v10/salon/salon_zone.gdshader")
	art.material = mat
	add_child(art)
	# flatten the task rects back → front
	var ts: Array = z.tasks.duplicate()
	ts.sort_custom(func(a, b): return int(a.layer) < int(b.layer))
	for t in ts:
		_idx[t.id] = []
		for r in t.rects:
			_idx[t.id].append(_rects.size())
			_rects.append(Vector4(r[0], r[1], r[2], r[3]))
	_prog.resize(_rects.size())
	_jade.resize(_rects.size())
	_pop.resize(_rects.size())
	_glint.resize(_rects.size())
	for i in _rects.size():
		_pop[i] = Vector2(0, 1)
	mat.set_shader_parameter("rects", _rects)
	mat.set_shader_parameter("count", _rects.size())
	mist = ColorRect.new()
	mist.size = size
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist_mat = ShaderMaterial.new()
	mist_mat.shader = load("res://scripts/v10/salon/mist.gdshader")
	mist_mat.set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
	mist.material = mist_mat
	add_child(mist)
	tag_layer = Control.new()
	tag_layer.size = size
	tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag_layer)
	_build_title()
	refresh(true)


func load_textures(on: bool) -> void:
	if on == _loaded:
		return
	_loaded = on
	if on:
		mat.set_shader_parameter("broken", load(V10SalonData.ART + zid + "_broken.webp"))
		mat.set_shader_parameter("done", load(V10SalonData.ART + zid + "_done.webp"))
	else:
		mat.set_shader_parameter("broken", null)
		mat.set_shader_parameter("done", null)


func _build_title() -> void:
	# top shade + «ЗОНА II · 4/6» overline + the zone name in Playfair italic, left-aligned (editorial, UX §6.3)
	var shade: = TextureRect.new()
	var g: = Gradient.new()
	g.set_color(0, Color(V10SalonUI.NIGHT_900, 0.82))
	g.set_color(1, Color(V10SalonUI.NIGHT_900, 0.0))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(size.x, 118)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	title_box = Control.new()
	title_box.position = Vector2(32, 14)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_box)
	var i: = V10SalonData.zone_ids().find(zid)
	prog_lbl = V10SalonUI.overline("Зона %s" % ROMAN[i])
	title_box.add_child(prog_lbl)
	var nm: = V10SalonUI.label(str(z.name), 34, V10SalonUI.PAPER_100, "italic", 600, 0.6)
	nm.position = Vector2(0, 20)
	title_box.add_child(nm)


# rebuild tags / uniforms from the save; instant = no animation
func refresh(instant: = false) -> void:
	locked = V10Salon.zone_state(zid) == "locked"
	var p: = V10Salon.progress(zid)
	var st: = V10Salon.zone_state(zid)
	var i: = V10SalonData.zone_ids().find(zid)
	var line: = "Зона %s · %d/%d" % [ROMAN[i], p.x, p.y]
	if st == "jade":
		line += " · Нефрит"
	elif st == "restored":
		line += " · восстановлена"
	prog_lbl.text = line.to_upper()
	prog_lbl.label_settings.font_color = V10SalonUI.JADE_300 if st in ["restored", "jade"] else V10SalonUI.GOLD_500
	for t in z.tasks:
		var v: = V10Salon.task_variant(zid, t.id)
		for k in _idx[t.id]:
			if instant or v == "":
				_prog[k] = 1.0 if v != "" else 0.0
			_jade[k] = 1.0 if v == "jade" else 0.0
	_finale = 1.0 if bool(V10Salon.zone_rec(zid).done) else 0.0
	_push()
	mat.set_shader_parameter("dim", 0.55 if locked else 0.0)
	mat.set_shader_parameter("desat", 0.65 if locked else 0.0)
	mist_mat.set_shader_parameter("amount", _mist_amount())
	_sync_tags()
	_sync_heroine()


func _mist_amount() -> float:
	if locked:
		return 1.0
	var p: = V10Salon.progress(zid)
	return 0.0 if bool(V10Salon.zone_rec(zid).done) else lerpf(0.95, 0.35, float(p.x) / maxf(1.0, p.y))


func _push() -> void:
	mat.set_shader_parameter("prog", _prog)
	mat.set_shader_parameter("jade", _jade)
	mat.set_shader_parameter("pop", _pop)
	mat.set_shader_parameter("glint", _glint)
	mat.set_shader_parameter("finale", _finale)


func _sync_tags() -> void:
	var bank: = V10Salon.bank()
	for t in z.tasks:
		var want: = not locked and not V10Salon.restored(zid, t.id)
		if want and not tags.has(t.id):
			var tag: = V10SalonTag.make(t.id, t.name, int(t.cost))
			tag.tapped.connect(func(tid): task_tapped.emit(zid, tid))
			tag_layer.add_child(tag)
			tags[t.id] = tag
		elif not want and tags.has(t.id):
			tags[t.id].queue_free()
			tags.erase(t.id)
		if tags.has(t.id):
			tags[t.id].affordable = bank >= int(t.cost)
			tags[t.id].hint = t.id == hint_tid
	_layout_tags()


# Tags hang from their objects; plaques that would overlap (or leave the card, or cover the title) are pushed
# to the nearest free spot and the thread stretches to the pin — readable at any width.
func _layout_tags() -> void:
	var order: = []
	for t in z.tasks:
		if tags.has(t.id):
			order.append(t)
	order.sort_custom(func(a, b): return a.anchor.y < b.anchor.y)
	var placed: = []
	var top_min: = 96.0
	for t in order:
		var tag: V10SalonTag = tags[t.id]
		var pinp: = Vector2(t.anchor.x * size.x, t.anchor.y * size.y)
		var base: = pinp - Vector2(tag.size.x * 0.5, V10SalonTag.THREAD + 12.0)
		var w: = tag.size.x
		var cands: = [Vector2.ZERO]
		for k in [1, 2, 3]:
			cands.append_array([Vector2(0, 62 * k), Vector2(0, -62 * k), Vector2(w * 0.5 * k + 8, 0), Vector2(-w * 0.5 * k - 8, 0),
				Vector2(w * 0.4 * k, 62 * k), Vector2(-w * 0.4 * k, 62 * k)])
		var best: = base
		for c in cands:
			var p: Vector2 = base + c
			p.x = clampf(p.x, 8.0, size.x - w - 8.0)
			p.y = clampf(p.y, top_min - V10SalonTag.THREAD, size.y - tag.size.y)
			var r: = Rect2(p + Vector2(w * 0.5 - tag._w * 0.5, V10SalonTag.THREAD), Vector2(tag._w, V10SalonTag.H)).grow(5)
			var hit: = false
			for q in placed:
				if r.intersects(q):
					hit = true
					break
			if not hit:
				best = p
				placed.append(r)
				break
		tag.place(pinp, best)


func _sync_heroine() -> void:
	var done: = bool(V10Salon.zone_rec(zid).done)
	if done and heroine == null:
		var h: = size.y * 0.92
		heroine = V10SalonHeroine.make(str(z.hero), Vector2(size.y * 0.75, h), _live)
		heroine.position = Vector2(_hero_x() - heroine.size.x * 0.5, size.y - h)
		heroine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# under the title shade but over the art and mist
		add_child(heroine)
		move_child(heroine, tag_layer.get_index())
		heroine.set_live(_live)
	if done and scene_btn == null:
		scene_btn = V10SalonButton.make("second", "Сцена", Rect2(size.x - 196, size.y - 92, 172, 68))
		scene_btn.icon = "scene"
		scene_btn.pressed.connect(func(): scene_tapped.emit(zid))
		add_child(scene_btn)


# where she stands in her zone (open floor of each painting)
func _hero_x() -> float:
	return {"z1": 0.7, "z2": 0.52, "z3": 0.36}.get(zid, 0.5) * size.x


func set_visible_live(on: bool) -> void:
	load_textures(on or _loaded)
	if on == _live:
		return
	_live = on
	set_process(on)
	if heroine:
		# a rig is only built for the visible zone (spec: «живой риг только у видимой»)
		if on and heroine.rig == null and V10SalonHeroine.has_rig(str(z.hero)) != "":
			heroine.queue_free()
			heroine = null
			_sync_heroine()
		heroine.set_live(on)
	mist_mat.set_shader_parameter("still", 0.0 if V10SalonUI.full_fx() else 1.0)


func _process(dt: float) -> void:
	_t += dt
	mat.set_shader_parameter("time_s", _t)
	if V10SalonUI.full_fx():
		mist_mat.set_shader_parameter("time_s", _t)


func scroll_impulse(v: float) -> void:
	for k in tags:
		tags[k].impulse(v)


func _gui_input(e: InputEvent) -> void:
	if locked:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if e.position.distance_to(get_meta("down_at", e.position)) > 18.0:
			return
		# her first: a tap on the heroine is hers
		if heroine and heroine.react_at(get_global_transform() * e.position) != "none":
			heroine_tapped.emit(zid, "body")
			accept_event()
			return
		var tid: = task_at(e.position / size)
		if tid != "" and V10Salon.restored(zid, tid):
			V9Feel.press(null, "pop", "tap")
			task_tapped.emit(zid, tid)
			accept_event()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		set_meta("down_at", e.position)


# the front-most task rect under a point (uv of the art)
func task_at(uv: Vector2) -> String:
	var best: = ""
	var best_layer: = -1
	for t in z.tasks:
		for r in t.rects:
			if Rect2(r[0], r[1], r[2], r[3]).has_point(uv) and int(t.layer) > best_layer:
				best = t.id
				best_layer = int(t.layer)
	return best


func task_center(tid: String) -> Vector2:
	var t: = V10SalonData.task(zid, tid)
	return Vector2(t.anchor.x * size.x, t.anchor.y * size.y)


func task_rect(tid: String) -> Rect2:
	var t: = V10SalonData.task(zid, tid)
	var r0: Array = t.rects[0]
	var rr: = Rect2(r0[0], r0[1], r0[2], r0[3])
	for r in t.rects:
		rr = rr.merge(Rect2(r[0], r[1], r[2], r[3]))
	return Rect2(rr.position * size, rr.size * size)


# ── animations ───────────────────────────────────────────────────────────────────────────────────────────────

# the restore beat (spec §Р1 п.5): dust, the object drops 40 px and springs 1.08 → 1.0 in 0.35 s while the
# done art bleeds in from its centre, then a 0.6 s glint and sparkles. Returns after the reveal.
func play_restore(tid: String) -> void:
	var fx: = V10SalonUI.can_fx()
	var ks: Array = _idx[tid]
	if tags.has(tid):
		var tag: V10SalonTag = tags[tid]
		tags.erase(tid)
		var tt: = tag.create_tween()
		tt.tween_property(tag, "scale", Vector2(1.15, 1.15), 0.08)
		tt.tween_property(tag, "scale", Vector2(0.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tt.parallel().tween_property(tag, "modulate:a", 0.0, 0.18)
		tt.tween_callback(tag.queue_free)
	var rr: = task_rect(tid)
	V10SalonFx.dust(self, rr.get_center(), maxf(rr.size.x, rr.size.y) * 0.5)
	V10SalonUI.sound("salon_thud", 1.0, -2.0)
	V10SalonUI.haptic("match")
	var drop: = 40.0 / size.y
	var dur: = 0.55 if fx else 0.12
	var t: = create_tween()
	t.tween_method(func(v: float):
		for k in ks:
			_prog[k] = v
		mat.set_shader_parameter("prog", _prog), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if fx:
		t.parallel().tween_method(func(v: float):
			# v 0..1: fall with a spring (0.35 s), scale 1.08 → 1.0
			var e: = 1.0 - pow(1.0 - v, 3.0)
			var spring: = sin(v * PI * 2.2) * exp(-4.0 * v) * 0.25
			for k in ks:
				_pop[k] = Vector2(-drop * (1.0 - e) + drop * spring * 0.2, 1.08 - 0.08 * e + spring * 0.04)
			mat.set_shader_parameter("pop", _pop), 0.0, 1.0, 0.35)
	await t.finished
	for k in ks:
		_pop[k] = Vector2(0, 1)
	mat.set_shader_parameter("pop", _pop)
	V10SalonUI.sound("sparkle", 1.08, -3.0)
	V10SalonFx.sparkle(self, rr)
	if fx:
		var g: = create_tween()
		g.tween_method(func(v: float):
			for k in ks:
				_glint[k] = v
			mat.set_shader_parameter("glint", _glint), 0.0, 1.0, 0.6)
		g.tween_callback(func():
			for k in ks:
				_glint[k] = 0.0
			mat.set_shader_parameter("glint", _glint))
	mist_mat.set_shader_parameter("amount", _mist_amount() if not bool(V10Salon.zone_rec(zid).done) else 0.35)
	_sync_tags()


# finish crossfade 0.2 s (lacquer ⇄ jade), with green-gold sparkles when jade arrives
func play_finish(tid: String, variant: String) -> void:
	var ks: Array = _idx[tid]
	var to: = 1.0 if variant == "jade" else 0.0
	var from: float = _jade[ks[0]]
	var t: = create_tween()
	t.tween_method(func(v: float):
		for k in ks:
			_jade[k] = v
		mat.set_shader_parameter("jade", _jade), from, to, 0.2)
	if variant == "jade":
		V10SalonFx.sparkle(self, task_rect(tid), Color(0.66, 0.95, 0.8), 18)
		V10SalonUI.sound("sparkle", 1.2, -4.0)
	await t.finished
	refresh()


# zone finale wave: warm light climbs bottom → top in 0.8 s and restores walls, sky, floor (spec §Р1 п.7)
func play_finale() -> void:
	var t: = create_tween()
	var mist_from: float = mist_mat.get_shader_parameter("amount")
	t.tween_method(func(v: float):
		_finale = v
		mat.set_shader_parameter("finale", v)
		mist_mat.set_shader_parameter("amount", mist_from * (1.0 - v)), 0.0, 1.0, 0.8 if V10SalonUI.can_fx() else 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	V10SalonUI.sound("salon_sweep", 1.0, -2.0)
	await t.finished
	if V10SalonUI.can_fx():
		V10SalonFx.sparkle(self, Rect2(Vector2.ZERO, size), Color(1.0, 0.84, 0.55), 40)
	refresh()
