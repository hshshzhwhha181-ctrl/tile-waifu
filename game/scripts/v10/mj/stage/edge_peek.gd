class_name V10MjEdgePeek
extends Control

# V10MjEdgePeek — she steps out from behind an edge, waist-up, for a moment of dead time (docs/MODES.md §3.1–3.2):
# from behind the bottom edge of her band (rising over the table's top edge), or from a side margin wider than
# 48 px (tablets, 9:21), never over the board. In 0.35 s (quint out) — holds ≤ 1.2 s — leaves in 0.3 s.
# The clip box is the zone itself, so not one pixel of her can cross into the sacred zone, even mid-motion.
# The figure is always a painted frame (the one rig of the screen lives in the portrait window).
#
#   peek.play(hero, slot, zone, opts) -> bool     slot: idle | select | win | lose | shy (POSES.md keys, data)
#       zone = {rect: Rect2 (clip, screen px), edge: "bottom" | "left" | "right", big: bool}
#       opts: hold (s, ≤ 1.2; finale up to 1.6), fx ("full" | "mid" | "min")
#   peek.skip()                                   leave now (a tap during the finale)
#   peek.active -> bool, peek.slot, peek.pose_key
# signal finished

signal finished

const IN_T: = 0.35
const HOLD_MAX: = 1.2
const FINALE_HOLD: = 1.6
const OUT_T: = 0.3
const MIN_FADE: = 0.12

var active: = false
var slot: = ""
var pose_key: = ""
var clip: Control
var fig: TextureRect
var _tw: Tween
var _edge: = "bottom"
var _shown_pos: = Vector2.ZERO
var _hidden_pos: = Vector2.ZERO
var _fx: = "full"
var final_rect: = Rect2()  # where she stands at full height (screen px), for the text placement


func _init() -> void:
	name = "EdgePeek"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip = Control.new()
	clip.name = "PeekClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	fig = TextureRect.new()
	fig.name = "PeekFigure"
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fig.stretch_mode = TextureRect.STRETCH_SCALE
	clip.add_child(fig)
	clip.visible = false


func play(hero: String, s: String, zone: Dictionary, opts: = {}) -> bool:
	var r: Rect2 = zone.get("rect", Rect2())
	if r.size.x < 48.0 or r.size.y < 56.0:
		return false
	skip(true)
	slot = s
	pose_key = V10MjStageData.pose_key(hero, s)
	_fx = String(opts.get("fx", V10MjStageData.fx_level()))
	_edge = String(zone.get("edge", "bottom"))
	var big: = bool(zone.get("big", false))
	clip.position = r.position - global_position
	clip.size = r.size
	var tex: Texture2D = load(V10MjStageData.frame_path(hero, s))
	fig.texture = tex
	var ts: = tex.get_size()
	# how much of the waist-up frame shows: chest-up in a 120 px band, to the waist on a 9:20 stage
	var vis: = clampf(r.size.y / 420.0, 0.55, 0.92) if _edge == "bottom" else 0.8
	var s_h: = (r.size.y - 6.0) / (ts.y * vis)
	var s_w: = (r.size.x * (0.92 if _edge == "bottom" else 1.6)) / ts.x
	var sc: = minf(s_h, s_w)
	if big:
		sc = minf(r.size.y * 0.98 / ts.y, r.size.x * 0.9 / ts.x)
	fig.size = ts * sc
	fig.flip_h = _edge == "left"
	var fx_x: float = clampf(float(zone.get("x", 0.5)), 0.0, 1.0)
	match _edge:
		"left":
			# leans in from the left edge: only her front half shows inside a narrow margin
			_shown_pos = Vector2(r.size.x - fig.size.x * 0.62, r.size.y - fig.size.y * 0.96)
			_hidden_pos = Vector2(- fig.size.x - 4.0, _shown_pos.y)
		"right":
			_shown_pos = Vector2(r.size.x - fig.size.x * 0.38, r.size.y - fig.size.y * 0.96)
			_hidden_pos = Vector2(r.size.x + 4.0, _shown_pos.y)
		_:
			var x: = (r.size.x - fig.size.x) * fx_x
			_shown_pos = Vector2(x, r.size.y - fig.size.y * (1.0 if big else vis) + 4.0)
			_hidden_pos = Vector2(x, r.size.y + 2.0)
	final_rect = Rect2(clip.global_position + _shown_pos, fig.size).intersection(clip.get_global_rect())
	clip.visible = true
	active = true
	var hold: = minf(float(opts.get("hold", HOLD_MAX)), FINALE_HOLD if big else HOLD_MAX)
	_tw = create_tween()
	if _fx == "min":
		# no motion: she is simply there (fade 120 ms), then gone
		fig.position = _shown_pos
		fig.modulate.a = 0.0
		V10MjStageFx.step(_tw, fig, "modulate:a", 1.0, MIN_FADE, Tween.TRANS_SINE, Tween.EASE_OUT)
		_tw.tween_interval(hold)
		V10MjStageFx.step(_tw, fig, "modulate:a", 0.0, MIN_FADE, Tween.TRANS_SINE, Tween.EASE_IN)
	else:
		fig.position = _hidden_pos
		fig.modulate.a = 1.0
		V10MjStageFx.step(_tw, fig, "position", _shown_pos, IN_T, Tween.TRANS_QUINT, Tween.EASE_OUT)
		_tw.tween_interval(hold)
		V10MjStageFx.step(_tw, fig, "position", _hidden_pos, OUT_T, Tween.TRANS_SINE, Tween.EASE_IN)
	_tw.tween_callback(_done)
	return true


func _done() -> void:
	clip.visible = false
	active = false
	finished.emit()


func skip(silent: = false) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	if active:
		clip.visible = false
		active = false
		if not silent:
			finished.emit()


# what of her is on screen now (for the sacred-zone audit): the figure clipped by the zone
func visible_rect() -> Rect2:
	if not active or not clip.visible:
		return Rect2()
	var g: = Rect2(clip.global_position + fig.position, fig.size)
	return g.intersection(clip.get_global_rect())
