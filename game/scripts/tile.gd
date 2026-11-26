class_name Tile
extends Node2D


const TW: = 84.0
const FACE_W: = 185.0
const S: = TW / FACE_W
const TH: = 192.0 * S

var gx: = 0
var gy: = 0
var gz: = 0
var face: = 0
var alive: = true
var ice: = 0
var gold: = false
var step: = 0
var free: = false
var selected: = false

var shadow: Sprite2D
var side_j: Sprite2D
var side_i: Sprite2D
var face_spr: Sprite2D
var glow: Sprite2D
var mat: ShaderMaterial
var home: = Vector2.ZERO
var _hint_tw: Tween

var secret: = false
var pending: = false
var gift: = false
var _mv: Tween

func kill_move() -> void :
	if _mv and _mv.is_valid():
		_mv.kill()
	_mv = null
	_finish_flip()


func fly_to(target: Vector2, sc: float, dur: float, arc: bool) -> void :
	kill_move()
	var from: = position
	var s0: = scale.x
	if not arc:
		_mv = create_tween().set_parallel()
		_mv.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_mv.tween_property(self, "scale", Vector2(sc, sc), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	var ctrl: = (from + target) * 0.5 + Vector2(0, -90)
	_mv = create_tween()
	_mv.tween_method( func(v: float):
		var p: = from.lerp(ctrl, v).lerp(ctrl.lerp(target, v), v)
		position = p
		var k: = lerpf(s0, sc, v) * (1.0 + 0.18 * sin(v * PI))
		scale = Vector2(k, k), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mv.tween_property(self, "scale", Vector2(sc * 1.08, sc * 0.92), 0.05)
	_mv.tween_property(self, "scale", Vector2(sc, sc), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
var back_spr: Node2D
var look: = {}


func build(lk = {}) -> void :
	var skin_neon: = false
	if lk is bool:
		skin_neon = lk
		look = G.SKIN_LOOK.s_neon if lk else G.SKIN_LOOK.s_mint
	else:
		look = lk if not lk.is_empty() else G.SKIN_LOOK.s_mint
		skin_neon = look.get("neon", false)
	shadow = Sprite2D.new()
	shadow.texture = G.fx("tile_shadow")
	shadow.scale = Vector2(S, S) * 1.02
	shadow.position = Vector2(9, 15)
	shadow.modulate = Color(1, 1, 1, 0.75)
	add_child(shadow)
	side_j = Sprite2D.new()
	side_j.texture = G.fx("tile_mask")
	side_j.scale = Vector2(S, S)
	side_j.position = Vector2(4.5, 10.5)
	side_j.modulate = look.side
	add_child(side_j)
	side_i = Sprite2D.new()
	side_i.texture = G.fx("tile_mask")
	side_i.scale = Vector2(S, S)
	side_i.position = Vector2(2.0, 4.5)
	side_i.modulate = look.rim
	add_child(side_i)
	glow = Sprite2D.new()
	glow.texture = G.fx("tile_glow")
	glow.scale = Vector2(S, S) * 1.05
	glow.material = Fx.add_mat()
	glow.modulate = Color(1.0, 0.82, 0.3, 0.0)
	add_child(glow)
	face_spr = Sprite2D.new()
	face_spr.texture = G.tile_tex(face if face < 36 else 0)
	face_spr.scale = Vector2(S, S)
	face_spr.self_modulate = look.get("tint", Color.WHITE)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/tile.gdshader")
	face_spr.material = mat
	mat.set_shader_parameter("shade", 0.9 + 0.035 * gz)
	mat.set_shader_parameter("neon", 1.0 if skin_neon else 0.0)
	add_child(face_spr)
	if gold:
		mat.set_shader_parameter("gold", 1.0)
	V6TileLook.dress(self)
	_dress_v10()
	_update_ice()
	if secret:
		_make_back()



func _dress_v10() -> void :
	var v10_tt = load("res://scripts/v10/look/tile_themes.gd")
	if v10_tt:
		v10_tt.dress(self)

const V6Back: = preload("res://scripts/v06/flip/tile_back.gd")
var flipping: = false
var _flip_tw: Tween
var _flip_swapped: = true

func _make_back() -> void :
	if back_spr:
		return
	var b: = V6Back.new()
	b.build(look)
	add_child(b)
	back_spr = b
	face_spr.visible = false


func set_flip_ready(on: bool) -> void :
	if back_spr and back_spr.has_method("set_ready"):
		back_spr.call("set_ready", on)

func reveal() -> void :
	if not secret:
		return
	secret = false
	if ice > 0:
		return
	flip_up(false)

func crack() -> void :
	if ice <= 0:
		return
	ice -= 1
	if ice <= 0 and not secret:
		flip_up(true)



func flip_up(big: = true) -> void :
	if back_spr == null:
		face_spr.visible = true
		return
	if _flip_tw and _flip_tw.is_valid():
		_flip_tw.kill()
	flipping = true
	_flip_swapped = false
	set_flip_ready(false)
	z_index = maxi(z_index, 60)
	var base: = home if not pending else position
	var lift: = Vector2(0, -14 if big else -6)
	_flip_tw = create_tween()
	_flip_tw.tween_property(self, "position", base + lift, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flip_tw.parallel().tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
	_flip_tw.tween_property(self, "scale", Vector2(0.0, 1.12), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tw.parallel().tween_property(self, "skew", 0.22, 0.1)
	_flip_tw.parallel().tween_method(_back_flash, 0.0, 0.7, 0.1)
	_flip_tw.tween_callback(_swap_to_face)
	_flip_tw.parallel().tween_property(self, "skew", -0.12, 0.0)
	_flip_tw.tween_property(self, "scale", Vector2(1.1, 1.02), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tw.parallel().tween_property(self, "skew", 0.0, 0.13)
	_flip_tw.parallel().tween_method( func(v): mat.set_shader_parameter("flash", v), 0.8, 0.0, 0.3)
	_flip_tw.tween_property(self, "position", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
	_flip_tw.tween_callback( func():
		flipping = false
		z_index = 0 if not pending else z_index
		shine(0.0))
	if big:
		Sfx.play("flip", randf_range(0.95, 1.08), -2)
		get_tree().create_timer(0.18).timeout.connect( func():
			if is_inside_tree() and get_parent() and get_parent().get_parent():
				Fx.burst(get_parent().get_parent(), position, "sparkle", 12, Color(1.0, 0.86, 0.5), 0.8)
				Sfx.play("sparkle", 1.25, -10))
	else:
		Sfx.play("flip", 1.2, -8)

func _back_flash(v: float) -> void :
	if back_spr:
		back_spr.call("set_flash", v)

func _swap_to_face() -> void :
	if _flip_swapped:
		return
	_flip_swapped = true
	if back_spr:
		back_spr.queue_free()
		back_spr = null
	face_spr.visible = true
	mat.set_shader_parameter("flash", 0.8)


func _finish_flip() -> void :
	if not flipping:
		return
	if _flip_tw and _flip_tw.is_valid():
		_flip_tw.kill()
	_flip_tw = null
	_swap_to_face()
	mat.set_shader_parameter("flash", 0.0)
	skew = 0.0
	flipping = false


func set_face(f: int) -> void :
	face = f
	face_spr.texture = G.tile_tex(f)

func _update_ice() -> void :

	mat.set_shader_parameter("ice", 0.0)
	if ice > 0:
		_make_back()
	elif back_spr and not secret and not flipping:
		flip_up(true)

func melt() -> void :
	if ice > 0:
		ice -= 1
		_update_ice()

var _free_init: = false
func set_free(f: bool, animate: = true) -> void :
	if f == free and _free_init:
		return
	_free_init = true
	free = f
	var target: = 0.0 if f else 1.0
	if animate:
		create_tween().tween_method( func(v): mat.set_shader_parameter("dim", v), 1.0 - target, target, 0.3)
		if f:
			shine(0.05)
	else:
		mat.set_shader_parameter("dim", target)

func shine(delay: = 0.0) -> void :
	var t: = create_tween()
	t.tween_interval(delay)
	t.tween_method( func(v): mat.set_shader_parameter("shine", v), -0.4, 1.9, 0.45)

func set_selected(s: bool) -> void :
	selected = s
	var t: = create_tween().set_parallel()
	if s:
		t.tween_property(self, "position", home + Vector2(0, -9), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", Vector2(1.07, 1.07), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(glow, "modulate:a", 1.0, 0.12)
		t.tween_property(shadow, "position", Vector2(14, 24), 0.14)
		t.tween_method( func(v): mat.set_shader_parameter("sel", v), 0.0, 1.0, 0.12)
	else:
		t.tween_property(self, "position", home, 0.16).set_trans(Tween.TRANS_QUAD)
		t.tween_property(self, "scale", Vector2.ONE, 0.16)
		t.tween_property(glow, "modulate:a", 0.0, 0.16)
		t.tween_property(shadow, "position", Vector2(9, 15), 0.16)
		t.tween_method( func(v): mat.set_shader_parameter("sel", v), 1.0, 0.0, 0.16)

# 0.9: the instant answer to a good tap (before the flight to the tray): a short warm light on the face, so the
# finger sees «taken» on the very frame it lands. Sound and haptic come from V9Feel.tile_tap (the board calls it).
var _glint_tw: Tween
func press_glint() -> void :
	if mat == null:
		return
	if _glint_tw and _glint_tw.is_valid():
		_glint_tw.kill()
	_glint_tw = create_tween()
	_glint_tw.tween_method( func(v): mat.set_shader_parameter("flash", v), 0.42, 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func deny() -> void :
	var t: = create_tween()
	for i in 4:
		t.tween_property(self, "position", home + Vector2(7 if i % 2 == 0 else -7, 0), 0.04)
	t.tween_property(self, "position", home, 0.04)
	var c: = create_tween()
	c.tween_property(face_spr, "modulate", Color(1, 0.6, 0.6), 0.06)
	c.tween_property(face_spr, "modulate", Color.WHITE, 0.25)

func hint(on: bool) -> void :
	var was: = _hint_tw != null
	if _hint_tw:
		_hint_tw.kill()
		_hint_tw = null
	if on:
		glow.modulate = Color(0.55, 1.0, 0.85, 0.0)
		_hint_tw = create_tween().set_loops()
		_hint_tw.tween_property(glow, "modulate:a", 1.0, 0.35)
		_hint_tw.parallel().tween_property(self, "position", home + Vector2(0, -6), 0.35).set_trans(Tween.TRANS_SINE)
		_hint_tw.tween_property(glow, "modulate:a", 0.25, 0.35)
		_hint_tw.parallel().tween_property(self, "position", home, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		glow.modulate = Color(1.0, 0.82, 0.3, 0.0)
		if was:
			position = home

func hit(local: Vector2) -> bool:
	var p: = local - position
	return abs(p.x) <= TW * 0.5 + 2 and abs(p.y) <= TH * 0.5 + 2

var shard: = ""

func set_shard(h: String) -> void :
	shard = h
	var rig: Dictionary = Hero.RIGS[h]
	var r: float = rig.head_r * 1.15
	var at: = AtlasTexture.new()
	at.atlas = load("res://assets/hero/%s.png" % h)
	# the redrawn mc / hana have the head near the top edge of the art: keep the region inside the texture
	at.region = Rect2(rig.head_c.x - r, maxf(0.0, rig.head_c.y - r * 1.05), r * 2, r * 2)
	# 0.8: an ivory face (like every other tile) with the portrait in a gold-ringed circle, a shard glyph in the
	# corner and a slow shimmer (shaders/shard_face.gdshader); the old flat pale-yellow square read as a placeholder
	var bg: = Sprite2D.new()
	bg.texture = G.fx("tile_mask")
	bg.scale = Vector2(S, S)
	bg.modulate = Color("fbf3e2")
	add_child(bg)
	move_child(bg, face_spr.get_index())
	face_spr.texture = at
	var sc: = (TW * 0.9) / (r * 2)
	face_spr.scale = Vector2(sc, sc)
	face_spr.self_modulate = Color.WHITE
	var old: ShaderMaterial = mat
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/shard_face.gdshader")
	var asz: = Vector2(at.atlas.get_width(), at.atlas.get_height())
	mat.set_shader_parameter("region", Vector4(at.region.position.x / asz.x, at.region.position.y / asz.y, at.region.size.x / asz.x, at.region.size.y / asz.y))
	for pn in ["dim", "sel", "flash", "shine", "ice", "shade"]:
		var v = old.get_shader_parameter(pn)
		if v != null:
			mat.set_shader_parameter(pn, v)
	mat.set_shader_parameter("gold", 1.0)
	face_spr.material = mat
