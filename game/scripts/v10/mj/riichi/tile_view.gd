class_name V10MjRiichiTile
extends Control

# One riichi tile drawn from assets/v08/table/t00–t36 (+ back). rot = 0/90/180/270 (the control's size is the
# rotated bounding box). Material from args.look: {"face_tint": Color, "body_tint": Color, "back": path}.
# States: lifted (hand), hint glow (training hall best discard), dim (forbidden / riichi choice), called (taken from
# the pond), danger dot (training hall only), fresh (last discard ring).

const DIR: = "res://assets/v08/table/"

static var _tex: = {}
static var look: = {}

var tile: = -1           # 0..135, -1 = back
var back_path: = ""
var rot: = 0
var lift: = 0.0
var glow: = Color(0, 0, 0, 0)
var dim: = false
var called: = false
var danger: = false
var fresh: = false
var shadow: = true
var pressed: = false

static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var p: = name if name.begins_with("res://") else DIR + name + ".png"
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex[name] = t
	return t

static func face_tex(t: int) -> Texture2D:
	return tex("t%02d" % V8Mj.face(t))

static func make(t: int, sz: Vector2, r: int = 0) -> V10MjRiichiTile:
	var v: = V10MjRiichiTile.new()
	v.tile = t
	v.rot = r
	v.size = sz
	v.custom_minimum_size = sz
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func set_lift(v: float) -> void:
	lift = v
	queue_redraw()

func _draw() -> void:
	var c: = size * 0.5
	var portrait: = rot % 180 == 0
	var tw: float = size.x if portrait else size.y
	var th: float = size.y if portrait else size.x
	draw_set_transform(c + Vector2(0, -lift), deg_to_rad(rot), Vector2.ONE)
	var r: = Rect2(-tw * 0.5, -th * 0.5, tw, th)
	if shadow:
		var sr: = r
		sr.position += Vector2(0, th * 0.05) if rot == 0 else Vector2.ZERO
		draw_rect(Rect2(sr.position + Vector2(tw * 0.04, th * 0.04), sr.size * Vector2(0.96, 0.98)), Color(0, 0, 0, 0.32 if lift <= 0.0 else 0.22))
	if glow.a > 0.0:
		var g: = tex("glow")
		if g:
			draw_texture_rect(g, r.grow(tw * 0.14), false, glow)
	var t: Texture2D
	var mod: = Color.WHITE
	if tile < 0:
		t = tex(back_path) if back_path != "" else tex("back")
		if look.has("body_tint"):
			mod = look.body_tint
	else:
		t = face_tex(tile)
		if look.has("face_tint"):
			mod = look.face_tint
	if dim:
		mod = mod.darkened(0.45)
	if called:
		mod.a = 0.42
	if t:
		draw_texture_rect(t, r, false, mod)
	if fresh:
		draw_rect(r.grow(1.5), Color("e8c47e"), false, 2.0)
	if danger:
		draw_circle(Vector2(r.end.x - tw * 0.16, r.position.y + th * 0.13), maxf(3.0, tw * 0.09), Color("e07a7a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
