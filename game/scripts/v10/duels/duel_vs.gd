class_name V10DuelVs
extends Control

# V10DuelVs — диагональная заставка перед дуэлью (spec 0.10 R6, UX_RULES §3.4):
# полная один раз за сессию (1,15 с), дальше короткая 0,5 с (V10Duel.vs_plan); тап пропускает сразу.
# В режиме «Спокойный экран» (fx_level == "min") — тихое проявление 0,16 с без вспышек.

signal done

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const D: = preload("res://scripts/v10/duels/duel_state.gd")

const FULL_SECS: = 1.15
const MIN_SECS: = 0.16
const AI_BADGE: = "ИИ · героиня"

var _finished: = false
var _left_col: = V10DS.ROSE_500
var _right_col: = V10DS.GOLD_500


static func play_over(host: Node, match_args: Dictionary) -> void:
	if host == null or not host.is_inside_tree():
		D.mark_vs_seen()
		return
	var vs_node: = V10DuelVs.new()
	vs_node.name = "V10DuelVs"
	var vr: = host.get_viewport().get_visible_rect().size
	vs_node.size = vr if vr.x > 0.0 else Vector2(720, 1280)
	var parent: Node = host.get("overlay") if (host.get("overlay") is Control) else host
	parent.add_child(vs_node)
	vs_node.setup(match_args)
	await vs_node.done
	if is_instance_valid(vs_node):
		vs_node.queue_free()


func setup(match_args: Dictionary) -> V10DuelVs:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("ux_tap", true)
	var partner: = String(match_args.get("partner", "mc"))
	var rival: = String(match_args.get("rival", "rin"))
	var form_n: = clampi(int(match_args.get("form", 3)), 1, F.FORMS)
	_left_col = V10DS.hero(partner).accent if V10DS.HEROES.has(partner) else U.hero_color(partner)
	_right_col = V10DS.hero(rival).accent if V10DS.HEROES.has(rival) else U.hero_color(rival)

	var vs: = size if size.x > 0.0 else Vector2(720, 1280)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))

	var you_lbl: = V10Type.label("Ты · %s" % U.hero_name(partner), "display", 32, V10DS.PAPER_100)
	you_lbl.position = Vector2(cx + 40.0, vs.y * 0.24)
	you_lbl.size = Vector2(640.0, 48.0)
	add_child(you_lbl)

	var mid_lbl: = V10Type.label("Дуэль", "display", 44, V10DS.GOLD_300)
	mid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_lbl.position = Vector2(cx + 40.0, vs.y * 0.46)
	mid_lbl.size = Vector2(640.0, 58.0)
	add_child(mid_lbl)

	var riv_lbl: = V10Type.label("%s · Форма %s" % [U.hero_name(rival), F.roman(form_n)], "display", 32, V10DS.PAPER_100)
	riv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	riv_lbl.position = Vector2(cx + 40.0, vs.y * 0.64)
	riv_lbl.size = Vector2(640.0, 48.0)
	add_child(riv_lbl)

	var b_lbl: = V10Type.label("%s · %s" % [AI_BADGE, F.trick_text(rival, form_n)], "ui", 22, V10DS.GOLD_300)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b_lbl.position = Vector2(cx + 40.0, vs.y * 0.64 + 54.0)
	b_lbl.size = Vector2(640.0, 34.0)
	add_child(b_lbl)

	var d_lbl: = V10Type.label(String(F.trick(rival).desc), "ui", 18, V10DS.PAPER_300)
	d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d_lbl.position = Vector2(cx + 40.0, vs.y * 0.64 + 92.0)
	d_lbl.size = Vector2(640.0, 28.0)
	add_child(d_lbl)

	var plan: = D.vs_plan()
	D.mark_vs_seen()
	var hold: = FULL_SECS if bool(plan.get("full", true)) else float(plan.get("secs", 0.5))
	if not V9Feel.can_fx():
		hold = MIN_SECS
	modulate.a = 0.0
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, minf(0.16, hold * 0.35))
	tw.tween_interval(maxf(0.05, hold))
	tw.tween_callback(finish_vs)
	return self


func finish_vs() -> void:
	if _finished:
		return
	_finished = true
	done.emit()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		V9Feel.press(self, "tick", "tap")
		accept_event()
		finish_vs()


func _draw() -> void:
	var w: = size.x
	var h: = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(V10DS.NIGHT_900, 0.94))
	var y_l: = h * 0.54
	var y_r: = h * 0.44
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, y_r), Vector2(0, y_l)]),
		PackedColorArray([Color(_left_col, 0.22), Color(V10DS.NIGHT_800, 0.85), Color(V10DS.NIGHT_800, 0.85), Color(_left_col, 0.14)])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, y_l), Vector2(w, y_r), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(_right_col, 0.14), Color(_right_col, 0.24), Color(V10DS.NIGHT_900, 0.95), Color(V10DS.NIGHT_900, 0.95)])
	)
	draw_line(Vector2(0, y_l), Vector2(w, y_r), V10DS.GOLD_500, 2.0, true)