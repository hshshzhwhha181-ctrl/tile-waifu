class_name V10Layout
extends RefCounted

# 0.10 M0 «responsive»: one place that knows the screen shape.
#
# The project renders with stretch mode canvas_items + aspect expand on a 720×1280 base:
#   * phones taller than 9:16 keep width 720 and get a taller viewport (1080×2400 -> 720×1600),
#   * tablets wider than 9:16 keep height 1280 and get a wider viewport (1536×2048 -> 960×1280).
# Every screen is laid out for a 720 px wide column, so on wide viewports the content column stays 720 px and is
# centred, while backgrounds, vignettes and the chrome plates bleed to the real edges (no pillar bars, no
# stretched art). On phones with a camera cut-out (the app draws edge to edge in immersive mode) the column also
# starts below the cut-out: content_rect() is the safe column, bleed_rect() the whole viewport.
#
#   V10Layout.content_rect(vs, insets = live) the column screens are built in (main.go sizes screens to it)
#   V10Layout.safe_insets(vs) -> Dictionary  {top, bottom, left, right} in viewport px
#   V10Layout.bleed_rect(ctrl) -> Rect2      the whole viewport in ctrl's local coordinates
#   V10Layout.cover_rect(tex, area, focus)   aspect-preserving «cover» rect of a texture over an area
#   V10Layout.contain_rect(tex, area)        aspect-preserving «contain» rect
#   V10Layout.is_wide(vs) / is_tall(vs)      tablet-like / taller than 9:16
#
# Dev: --safe=T,B[,L,R] simulates a cut-out in WINDOW pixels (e.g. --safe=120,60 on a 1080×2400 window);
#      --notch=1 also draws a camera pill there (screenshots), see V10LayoutShots.

const BASE: = Vector2(720, 1280)
# the content column never gets wider than this (all screens are designed for it)
const COL_MAX: = 720.0
# a cut-out deeper than this (viewport px) is clamped: the HUD would lose too much height otherwise
const SAFE_MAX_TOP: = 110.0
const SAFE_MAX_BOTTOM: = 80.0

static var _cache_key: = Vector2.ZERO
static var _cache: = {}
static var _override: = PackedFloat32Array()
static var _override_read: = false


# window pixels per viewport pixel (canvas_items stretch, aspect expand: uniform)
static func px_scale(vs: Vector2) -> float:
	var win: = Vector2(DisplayServer.window_get_size())
	if vs.x <= 0.0 or vs.y <= 0.0 or win.x <= 0.0 or win.y <= 0.0:
		return 1.0
	return minf(win.x / vs.x, win.y / vs.y)


static func _read_override() -> void:
	if _override_read:
		return
	_override_read = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--safe="):
			var parts: = a.substr(7).split(",")
			var v: = PackedFloat32Array([0, 0, 0, 0])
			for i in mini(parts.size(), 4):
				v[i] = maxf(0.0, float(parts[i]))
			_override = v


# Cut-out / system bar insets in viewport px. On desktop (and under xvfb) the display safe area describes the
# monitor (task bars), not our window, so only mobile builds read it; --safe= overrides everywhere.
static func safe_insets(vs: Vector2) -> Dictionary:
	_read_override()
	var key: = vs + Vector2(DisplayServer.window_get_size()) * 10000.0
	if key == _cache_key and not _cache.is_empty():
		return _cache
	var s: = px_scale(vs)
	var top: = 0.0
	var bottom: = 0.0
	var left: = 0.0
	var right: = 0.0
	if _override.size() == 4:
		top = _override[0]
		bottom = _override[1]
		left = _override[2]
		right = _override[3]
	elif OS.has_feature("mobile"):
		var sa: = DisplayServer.get_display_safe_area()
		var scr: = Vector2(DisplayServer.screen_get_size())
		var win: = Vector2(DisplayServer.window_get_size())
		# fullscreen window: screen == window. Otherwise (split screen) we cannot place the cut-out: no inset.
		if sa.size.x > 0 and sa.size.y > 0 and absf(scr.x - win.x) < 2.0 and absf(scr.y - win.y) < 2.0:
			top = float(sa.position.y)
			left = float(sa.position.x)
			bottom = maxf(0.0, scr.y - float(sa.end.y))
			right = maxf(0.0, scr.x - float(sa.end.x))
	_cache = {
		"top": minf(SAFE_MAX_TOP, top / s),
		"bottom": minf(SAFE_MAX_BOTTOM, bottom / s),
		"left": minf(60.0, left / s),
		"right": minf(60.0, right / s),
	}
	_cache_key = key
	return _cache


static func is_wide(vs: Vector2) -> bool:
	return vs.x > COL_MAX + 0.5


static func is_tall(vs: Vector2) -> bool:
	return vs.y > BASE.y + 0.5


# the rect every screen is built in: a column ≤ COL_MAX wide, centred, between the safe insets
static func content_rect(vs: Vector2, insets: = {}) -> Rect2:
	var ins: Dictionary = insets if not insets.is_empty() else safe_insets(vs)
	var x0: float = ins.left
	var x1: float = vs.x - float(ins.right)
	var w: = minf(COL_MAX, x1 - x0)
	var x: = x0 + ((x1 - x0) - w) * 0.5
	var y: float = ins.top
	var h: float = vs.y - float(ins.top) - float(ins.bottom)
	return Rect2(roundf(x), roundf(y), roundf(w), roundf(h))


# the whole viewport in `ctrl`'s local coordinates (for backgrounds that must bleed past the column)
static func bleed_rect(ctrl: Control) -> Rect2:
	if ctrl == null or not ctrl.is_inside_tree():
		return Rect2(Vector2.ZERO, ctrl.size if ctrl else BASE)
	var vs: = ctrl.get_viewport_rect().size
	var inv: = ctrl.get_global_transform().affine_inverse()
	var a: = inv * Vector2.ZERO
	var b: = inv * vs
	return Rect2(a, b - a).abs()


# how far `ctrl`'s own rect is from the viewport edges (left, top, right, bottom), in its local units
static func bleed_margins(ctrl: Control) -> Vector4:
	var r: = bleed_rect(ctrl)
	return Vector4(-r.position.x, -r.position.y, r.end.x - ctrl.size.x, r.end.y - ctrl.size.y)


# texture of `tex` px drawn to cover `area` without distortion; `focus` (0..1 in the texture) stays in view
static func cover_rect(tex: Vector2, area: Rect2, focus: = Vector2(0.5, 0.5)) -> Rect2:
	if tex.x <= 0.0 or tex.y <= 0.0:
		return area
	var k: = maxf(area.size.x / tex.x, area.size.y / tex.y)
	var sz: = tex * k
	var pos: = area.position + area.size * 0.5 - sz * focus
	# keep the covered area filled: clamp so no edge of the texture comes inside the area
	pos.x = clampf(pos.x, area.end.x - sz.x, area.position.x)
	pos.y = clampf(pos.y, area.end.y - sz.y, area.position.y)
	return Rect2(pos, sz)


static func contain_rect(tex: Vector2, area: Rect2) -> Rect2:
	if tex.x <= 0.0 or tex.y <= 0.0:
		return area
	var k: = minf(area.size.x / tex.x, area.size.y / tex.y)
	var sz: = tex * k
	return Rect2(area.position + (area.size - sz) * 0.5, sz)


# stretch a full-width decoration (ColorRect / TextureRect / gradient band) of `ctrl`'s parent column out to the
# viewport's left and right edges (tablets): keeps its y and height
static func bleed_x(n: Control) -> void:
	if n == null or n.get_parent() == null or not (n.get_parent() is Control):
		return
	var p: Control = n.get_parent()
	if not p.is_inside_tree():
		return
	var r: = bleed_rect(p)
	if r.size.x <= p.size.x + 0.5:
		return
	n.position.x = r.position.x
	n.size.x = r.size.x


# a viewport point (what get_global_transform_with_canvas(), get_global_rect(), input events and signals like
# TrayBoard.matched give) in `n`'s local coordinates. Screens sit in the content column, not at the viewport origin
# (tablets: x 120 / 40; phones with a cut-out: y = the inset), so an effect drawn into a screen or one of its layers
# at a viewport point must be converted, and a screen-local point must go back through `to_canvas` before it is
# handed to main (main.fly_gems, toasts) or compared with an input position.
static func local_of(n: CanvasItem, canvas_pt: Vector2) -> Vector2:
	if n == null or not n.is_inside_tree():
		return canvas_pt
	return n.get_global_transform_with_canvas().affine_inverse() * canvas_pt


static func to_canvas(n: CanvasItem, local_pt: Vector2) -> Vector2:
	if n == null or not n.is_inside_tree():
		return local_pt
	return n.get_global_transform_with_canvas() * local_pt


static func dump(vs: Vector2) -> String:
	var ins: = safe_insets(vs)
	return "vp=%dx%d win=%s px=%.3f safe=t%.0f b%.0f l%.0f r%.0f content=%s" % [vs.x, vs.y,
		str(DisplayServer.window_get_size()), px_scale(vs), ins.top, ins.bottom, ins.left, ins.right,
		str(content_rect(vs))]
