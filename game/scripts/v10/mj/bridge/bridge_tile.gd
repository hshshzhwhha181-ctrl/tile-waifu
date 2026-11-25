class_name V10MjBridgeTile
extends Control

# Одна фишка риичи моста (assets/v08/table/t00–t33). Размер узла = размер фишки (144:200).
# Состояния: lift (поднята в руке), sel (выбрана — золотая кромка), dim (закрыта сверху — притушена), hint (мягкое
# золотое свечение «эту»), mark (ember-точка: этот сброс уже пробовали), best (зелёная кромка правильного ответа),
# face_tint из args.look (материал дорожки look: {"face_tint": Color}), depth — слой пирамиды (тень длиннее).

const ASPECT: = 200.0 / 144.0

static var look: = {}

var kind: = 0
var lift: = 0.0
var sel: = false
var dim: = false
var hint: = 0.0
var mark: = false
var best: = false
var depth: = 0
var shadow: = true


static func make(k: int, w: float) -> V10MjBridgeTile:
	var t: = V10MjBridgeTile.new()
	t.kind = k
	t.size = Vector2(w, w * ASPECT)
	t.pivot_offset = t.size * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func set_w(w: float) -> void:
	size = Vector2(w, w * ASPECT)
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var w: = size.x
	var h: = size.y
	var r: = Rect2(Vector2(0, -lift), size)
	if shadow:
		var off: = Vector2(w * 0.05, h * 0.045) * (1.0 + depth * 0.35)
		draw_rect(Rect2(r.position + off, size * Vector2(0.98, 0.99)), Color(0, 0, 0, 0.30 + depth * 0.04))
	if hint > 0.0:
		var g: = Color(V10MjBridgeLook.TOK.gold300, 0.5 * hint)
		draw_rect(r.grow(w * 0.07), Color(g, g.a * 0.35))
		draw_rect(r.grow(w * 0.04), g, false, maxf(2.0, w * 0.04))
	var t: = V10MjBridgeTiles.tex(kind)
	var mod: Color = look.get("face_tint", Color.WHITE)
	if dim:
		mod = mod.darkened(0.42)
	if t:
		draw_texture_rect(t, r, false, mod)
	else:
		draw_rect(r, Color("f5ead8"))
		draw_string(ThemeDB.fallback_font, r.position + Vector2(4, h * 0.5), V8Mj.short_ru(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, int(w * 0.35), Color.BLACK)
	if sel:
		draw_rect(r.grow(1.5), V10MjBridgeLook.TOK.gold500, false, maxf(2.5, w * 0.05))
	if best:
		draw_rect(r.grow(1.5), V10MjBridgeLook.TOK.jade300, false, maxf(2.5, w * 0.05))
	if mark:
		draw_circle(Vector2(w * 0.82, -lift + h * 0.12), maxf(4.0, w * 0.09), V10MjBridgeLook.TOK.ember)
