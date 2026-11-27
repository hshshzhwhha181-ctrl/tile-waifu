class_name V10AdventureVfx
extends RefCounted

# V10AdventureVfx — Omniheroes-grade dynamic combat effects for Wave 3 Monster Battle RPG:
# - Flying curved-arc Bezier energy projectiles (0.38s trail + sparks before impact)
# - Dramatic glowing diagonal anime sword/spirit slashes (_SlashFx, lingering 0.55s)
# - Expanding shockwave rings, 60 ms Hit-Stop & screen shake
# - Living elemental Boss Aura + glowing "БОСС" Crown Emblem + Delayed HP Drain White-Bar
# - Real visible TrayBoard tile debuffs ("Пелена офуда" spirit fog + "Заморозка" crystal ice)
# - Bottom Dock Glowing Gold-Crimson ULT Button + Fullscreen Heroine Ult Cutscene (.ogv video + CG slash banner)
# - Lingering Combo/Crit Banner (0.90s hold) & weighty floating damage numbers

const PROJ_FLIGHT_DUR: = 0.38
const SLASH_HOLD_DUR: = 0.55
const COMBO_HOLD_DUR: = 0.90
const HITSTOP_SEC: = 0.06
const SHIELD_SLOWMO_SEC: = 0.11
const SHIELD_SLOWMO_SCALE: = 0.25
const DEBUFF_META: = "v10_adv_debuff"


class DelayedBar extends Control:
	var cur_frac: = 1.0
	var trail_frac: = 1.0
	var target_frac: = 1.0
	var hold_left: = 0.0
	var flash_t: = 0.0
	var fill_top: = Color("#F25565")
	var fill_bot: = Color("#B5243A")
	var trail_col: = Color(1.0, 0.96, 0.84, 0.96)
	var bg_col: = Color(0.05, 0.03, 0.09, 0.95)
	var border_col: = Color("#D6AC60")
	const HOLD_TIME: = 0.42
	const DRAIN_SPEED: = 1.15

	func setup(r: Rect2, top_c: Color, bot_c: Color, brd_c: Color = Color("#D6AC60")) -> DelayedBar:
		position = r.position
		size = r.size
		fill_top = top_c
		fill_bot = bot_c
		border_col = brd_c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func set_frac(f: float, instant: bool = false) -> void:
		var nf: = clampf(f, 0.0, 1.0)
		if instant:
			cur_frac = nf
			trail_frac = nf
			target_frac = nf
			hold_left = 0.0
			queue_redraw()
			return
		if nf < target_frac - 0.001:
			trail_frac = maxf(trail_frac, cur_frac)
			target_frac = nf
			cur_frac = nf
			hold_left = HOLD_TIME
			flash_t = 0.24
		elif nf > target_frac + 0.001:
			target_frac = nf
			cur_frac = nf
			trail_frac = nf
			hold_left = 0.0
		queue_redraw()

	func step_bar(dt: float) -> void:
		var dirty: = false
		if flash_t > 0.0:
			flash_t = maxf(0.0, flash_t - dt)
			dirty = true
		if trail_frac > cur_frac + 0.0005:
			var rem: = dt
			if hold_left > 0.0:
				var take: = minf(hold_left, rem)
				hold_left -= take
				rem -= take
			if rem > 0.0:
				trail_frac = move_toward(trail_frac, cur_frac, DRAIN_SPEED * rem)
			dirty = true
		if dirty:
			queue_redraw()

	func _process(dt: float) -> void:
		step_bar(dt)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		draw_rect(r, bg_col, true)
		var pad: = 3.0
		var ir: = Rect2(Vector2(pad, pad), Vector2(maxf(0.0, size.x - pad * 2.0), maxf(0.0, size.y - pad * 2.0)))
		if trail_frac > cur_frac + 0.002:
			var tw: = ir.size.x * clampf(trail_frac, 0.0, 1.0)
			draw_rect(Rect2(ir.position, Vector2(tw, ir.size.y)), trail_col, true)
		var cw: = ir.size.x * clampf(cur_frac, 0.0, 1.0)
		if cw > 0.5:
			draw_rect(Rect2(ir.position, Vector2(cw, ir.size.y)), fill_bot, true)
			draw_rect(Rect2(ir.position, Vector2(cw, ir.size.y * 0.48)), fill_top, true)
			draw_rect(Rect2(ir.position + Vector2(0, 1), Vector2(cw, 2.0)), Color(1, 1, 1, 0.28), true)
		for i in range(1, 4):
			var tx: = ir.position.x + ir.size.x * (float(i) * 0.25)
			draw_line(Vector2(tx, ir.position.y), Vector2(tx, ir.end.y), Color(0, 0, 0, 0.32), 1.0)
		var bcol: = border_col.lerp(Color(1.0, 0.96, 0.82), clampf(flash_t * 3.5, 0.0, 1.0))
		draw_rect(r, bcol, false, 2.0)


class BossAura extends Control:
	var accent: = Color("#E85A4F")
	var danger: = false
	var stunned: = false
	var is_boss: = true
	var _t: = 0.0

	func setup(r: Rect2, col: Color, boss_flag: bool) -> BossAura:
		position = r.position
		size = r.size
		accent = col
		is_boss = boss_flag
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _process(dt: float) -> void:
		_t += dt * (2.2 if danger else (0.55 if stunned else 1.15))
		queue_redraw()

	func _draw() -> void:
		var c: = size * 0.5
		var base_r: = minf(size.x, size.y) * 0.44
		var col: = Color("#7CE2FF") if stunned else (Color("#FF3B4E") if danger else accent)
		var pulse: = 0.5 + 0.5 * sin(_t * 2.6)
		draw_circle(c, base_r * (1.06 + 0.06 * pulse), Color(col.r, col.g, col.b, 0.14 + 0.08 * pulse))
		draw_circle(c, base_r * (0.94 + 0.04 * pulse), Color(col.r, col.g, col.b, 0.22 + 0.08 * pulse))
		draw_arc(c, base_r * 0.98, 0.0, TAU, 48, Color(col.lightened(0.28), 0.62), 2.5, true)
		draw_arc(c, base_r * 1.08, _t * 0.8, _t * 0.8 + PI * 0.65, 24, Color(col.lightened(0.45), 0.78), 3.0, true)
		draw_arc(c, base_r * 1.08, _t * 0.8 + PI, _t * 0.8 + PI * 1.65, 24, Color(col.lightened(0.45), 0.78), 3.0, true)
		var pts: = PackedVector2Array()
		var n_pts: = 8 if is_boss else 6
		for i in range(n_pts + 1):
			var a: = _t * 0.55 + float(i) * TAU / float(n_pts)
			var rr: = base_r * (1.03 if i % 2 == 0 else 0.88)
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_polyline(pts, Color(col.lightened(0.35), 0.48), 1.8, true)
		for i in 8:
			var wa: = -_t * 0.9 + float(i) * TAU / 8.0
			var wr: = base_r * (1.02 + 0.07 * sin(_t * 3.0 + float(i) * 1.3))
			var wp: = c + Vector2(cos(wa), sin(wa)) * wr
			draw_circle(wp, 5.5 if i % 2 == 0 else 3.8, Color(col.lightened(0.3), 0.55))
			draw_circle(wp, 2.5, Color(1.0, 0.97, 0.88, 0.90))


class CrownEmblem extends Control:
	var badge_text: = "БОСС"
	var accent: = Color("#F4C86A")
	var _t: = 0.0

	func setup(r: Rect2, txt: String, col: Color) -> CrownEmblem:
		position = r.position
		size = r.size
		badge_text = txt
		accent = col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var glow_a: = 0.22 + 0.12 * sin(_t * 3.2)
		draw_rect(r.grow(3.0), Color(accent.r, accent.g, accent.b, glow_a), true)
		draw_rect(r, Color(0.14, 0.05, 0.16, 0.96), true)
		draw_rect(r, Color("#F6D483"), false, 2.0)
		var cx: = 20.0
		var cy: = size.y * 0.5 + 5.0
		var crown: = PackedVector2Array([
			Vector2(cx - 11, cy),
			Vector2(cx - 13, cy - 12),
			Vector2(cx - 5, cy - 6),
			Vector2(cx, cy - 15),
			Vector2(cx + 5, cy - 6),
			Vector2(cx + 13, cy - 12),
			Vector2(cx + 11, cy),
		])
		draw_colored_polygon(crown, Color("#FFD978"))
		draw_polyline(crown, Color("#FFF6D6"), 1.4, true)
		draw_circle(Vector2(cx, cy - 15), 2.2, Color("#FF4D6D"))
		var f: = UI.font("body", 900)
		draw_string_outline(f, Vector2(34, size.y * 0.5 + 6.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 38.0, 15, 4, Color(0.08, 0.02, 0.10))
		draw_string(f, Vector2(34, size.y * 0.5 + 6.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 38.0, 15, Color("#FFEAB3"))


class EnergyOrb extends Node2D:
	var p0: = Vector2.ZERO
	var p1: = Vector2.ZERO
	var p2: = Vector2.ZERO
	var dur: = PROJ_FLIGHT_DUR
	var delay: = 0.0
	var elapsed: = 0.0
	var col: = Color("#FFB86C")
	var core_col: = Color(1.0, 0.98, 0.88)
	var trail: Array[Vector2] = []
	var on_arrive: Callable
	var _arrived: = false
	var _fade: = 0.0
	var _spark_done: = false

	func setup(from_pt: Vector2, ctrl_pt: Vector2, to_pt: Vector2, c: Color, dly: float, cb: Callable) -> EnergyOrb:
		p0 = from_pt
		p1 = ctrl_pt
		p2 = to_pt
		col = c
		delay = dly
		on_arrive = cb
		position = Vector2.ZERO
		return self

	func cur_head() -> Vector2:
		if trail.is_empty():
			return p0
		return trail.back()

	func _process(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			return
		if _arrived:
			_fade += dt
			queue_redraw()
			if _fade >= 0.12:
				queue_free()
			return
		elapsed += dt
		var u: = clampf(elapsed / maxf(0.05, dur), 0.0, 1.0)
		var ue: = u * u * 0.45 + u * 0.55
		var pos: = p0.lerp(p1, ue).lerp(p1.lerp(p2, ue), ue)
		trail.append(pos)
		if trail.size() > 11:
			trail.pop_front()
		if not _spark_done and u >= 0.48 and get_parent() != null and V9Feel.can_fx():
			_spark_done = true
			Fx.burst(get_parent(), pos, "sparkle", 4, col.lightened(0.25), 0.45)
		queue_redraw()
		if u >= 1.0:
			_arrived = true
			if on_arrive.is_valid():
				on_arrive.call()

	func _draw() -> void:
		if delay > 0.0 or trail.is_empty():
			return
		var fade_k: = clampf(1.0 - _fade / 0.12, 0.0, 1.0)
		var n: = trail.size()
		for i in range(n - 1):
			var k: = float(i + 1) / float(n)
			var w: = lerpf(3.0, 18.0, k) * fade_k
			draw_line(trail[i], trail[i + 1], Color(col.r, col.g, col.b, 0.52 * k * fade_k), w, true)
			draw_line(trail[i], trail[i + 1], Color(core_col.r, core_col.g, core_col.b, 0.88 * k * fade_k), w * 0.38, true)
		if not _arrived:
			var hd: = trail.back()
			draw_circle(hd, 19.0, Color(col.r, col.g, col.b, 0.30 * fade_k))
			draw_circle(hd, 12.0, Color(col.lightened(0.25), 0.72 * fade_k))
			draw_circle(hd, 6.5, Color(core_col, 0.98 * fade_k))
			var ang: = elapsed * 14.0
			for j in 4:
				var d: = Vector2(cos(ang + j * PI * 0.5), sin(ang + j * PI * 0.5)) * 18.0
				draw_line(hd - d, hd + d, Color(core_col, 0.82 * fade_k), 2.2, true)


class SlashFx extends Control:
	var slashes: Array = []
	var dur: = SLASH_HOLD_DUR
	var elapsed: = 0.0

	func setup(center_pt: Vector2, glow_col: Color, count: int = 1, hold: float = SLASH_HOLD_DUR) -> SlashFx:
		var box: = Vector2(280, 280)
		position = center_pt - box * 0.5
		size = box
		dur = hold
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c: = box * 0.5
		var angles: Array = [-0.68, 0.68, -0.22, 1.18, -1.24]
		for i in clampi(count, 1, 5):
			var ang: float = float(angles[i % angles.size()])
			var dir: = Vector2(cos(ang), sin(ang))
			var nrm: = dir.orthogonal()
			var half_l: = 118.0 if count == 1 else (128.0 if i < 2 else 112.0)
			var off: = nrm * (0.0 if i < 2 else float((i % 3) - 1) * 22.0)
			slashes.append({
				"a": c - dir * half_l + off,
				"b": c + dir * half_l + off,
				"bend": (18.0 if i % 2 == 0 else -18.0),
				"delay": float(i) * (0.075 if count <= 2 else 0.065),
				"col": glow_col if i % 2 == 0 else Color("#FF4757").lerp(glow_col, 0.45),
				"width": 16.0 if count <= 2 else 14.0,
			})
		return self

	func _process(dt: float) -> void:
		elapsed += dt
		if elapsed >= dur + 0.25:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for s in slashes:
			var lt: float = elapsed - float(s.delay)
			if lt < 0.0 or lt > dur:
				continue
			var prog: = clampf(lt / 0.09, 0.0, 1.0)
			var alpha: = 1.0
			var width_k: = 1.0
			if lt > 0.36:
				var fo: = clampf((lt - 0.36) / maxf(0.05, dur - 0.36), 0.0, 1.0)
				alpha = 1.0 - fo
				width_k = lerpf(1.0, 0.22, fo)
			else:
				width_k = 1.0 + 0.14 * sin(lt * 26.0)
			var a: Vector2 = s.a
			var b: Vector2 = s.b
			var nrm: = (b - a).normalized().orthogonal()
			var ctrl: = (a + b) * 0.5 + nrm * float(s.bend)
			var segs: = 14
			var col: Color = s.col
			var w0: float = float(s.width) * width_k
			var prev: = a
			var max_i: = maxi(1, int(round(float(segs) * prog)))
			for i in range(1, max_i + 1):
				var u: = float(i) / float(segs)
				var pt: = a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)
				var taper: = sin(clampf(u / maxf(0.05, prog), 0.0, 1.0) * PI)
				var sw: = maxf(1.5, w0 * taper)
				draw_line(prev, pt, Color(col.r, col.g, col.b, 0.42 * alpha), sw * 2.5, true)
				draw_line(prev, pt, Color(col.lightened(0.25), 0.85 * alpha), sw * 1.25, true)
				draw_line(prev, pt, Color(1.0, 0.98, 0.92, 0.98 * alpha), sw * 0.48, true)
				prev = pt
			if prog >= 0.5:
				var mid: = a.lerp(ctrl, 0.5).lerp(ctrl.lerp(b, 0.5), 0.5)
				var fl: = 26.0 * alpha
				draw_line(mid - Vector2(fl, 0), mid + Vector2(fl, 0), Color(1.0, 0.96, 0.84, 0.85 * alpha), 3.0, true)
				draw_line(mid - Vector2(0, fl), mid + Vector2(0, fl), Color(1.0, 0.96, 0.84, 0.85 * alpha), 3.0, true)


class ShockwaveRing extends Node2D:
	var col: = Color("#FFD978")
	var max_r: = 145.0
	var dur: = 0.44
	var elapsed: = 0.0
	var heavy: = false

	func setup(pos: Vector2, c: Color, radius: float = 145.0, is_heavy: bool = false) -> ShockwaveRing:
		position = pos
		col = c
		max_r = radius
		heavy = is_heavy
		return self

	func _process(dt: float) -> void:
		elapsed += dt
		if elapsed >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: = clampf(elapsed / dur, 0.0, 1.0)
		var ue: = 1.0 - pow(1.0 - u, 3.0)
		var a: = 1.0 - u
		var r: = lerpf(18.0, max_r, ue)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.78 * a), lerpf(10.0, 1.5, u), true)
		draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 40, Color(1.0, 0.97, 0.88, 0.65 * a), lerpf(5.0, 1.0, u), true)
		if heavy:
			for i in 10:
				var ang: = float(i) * TAU / 10.0 + 0.2
				var d: = Vector2(cos(ang), sin(ang))
				draw_line(d * (r * 0.55), d * (r * 1.18), Color(1.0, 0.94, 0.76, 0.70 * a), 2.5, true)


class ComboBanner extends Control:
	var title_txt: = ""
	var sub_txt: = ""
	var accent: = Color("#FFD966")
	var elapsed: = 99.0
	const IN_DUR: = 0.14
	const HOLD_DUR: = COMBO_HOLD_DUR
	const OUT_DUR: = 0.28

	func setup(r: Rect2) -> ComboBanner:
		position = r.position
		size = r.size
		pivot_offset = r.size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		return self

	func is_showing() -> bool:
		return visible and elapsed < (IN_DUR + HOLD_DUR + OUT_DUR)

	func trigger(combo: int, crit: bool, mult: float = 1.0) -> void:
		if crit and combo >= 2:
			title_txt = "★ КРИТ · КОМБО ×%d! ★" % combo
			accent = Color("#FFE066")
		elif crit:
			title_txt = "★ ЗОЛОТОЙ КРИТ! ★"
			accent = Color("#FFE066")
		else:
			title_txt = "КОМБО ×%d!" % maxi(2, combo)
			accent = Color("#FF9E5E") if combo < 4 else Color("#FF6B8B")
		sub_txt = "УРОН ×%.2f" % mult if mult > 1.04 else "СОКРУШИТЕЛЬНЫЙ УДАР"
		elapsed = 0.0
		visible = true
		modulate.a = 1.0
		scale = Vector2(0.68, 0.68)
		var tw: = create_tween()
		tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.08)
		queue_redraw()

	func step_banner(dt: float) -> void:
		if not visible:
			return
		elapsed += dt
		var total: = IN_DUR + HOLD_DUR + OUT_DUR
		if elapsed >= total:
			visible = false
			return
		if elapsed > IN_DUR + HOLD_DUR:
			var fo: = (elapsed - IN_DUR - HOLD_DUR) / OUT_DUR
			modulate.a = clampf(1.0 - fo, 0.0, 1.0)
		else:
			modulate.a = 1.0
		queue_redraw()

	func _process(dt: float) -> void:
		step_banner(dt)

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var sl: = 18.0
		var pts: = PackedVector2Array([
			Vector2(sl, 2), Vector2(w - 4, 2), Vector2(w - sl, h - 2), Vector2(4, h - 2)
		])
		draw_colored_polygon(pts, Color(0.14, 0.04, 0.16, 0.94))
		var sheen_x: = lerpf(-80.0, w + 80.0, clampf(elapsed / (IN_DUR + HOLD_DUR), 0.0, 1.0))
		var sx0: = clampf(sheen_x - 32.0, sl, w - sl)
		var sx1: = clampf(sheen_x + 32.0, sl, w - sl)
		if sx1 > sx0 + 2.0:
			draw_rect(Rect2(sx0, 4, sx1 - sx0, h - 8), Color(1.0, 0.94, 0.72, 0.22), true)
		var border_pts: = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_polyline(border_pts, accent, 2.8, true)
		var f: = UI.font("body", 900)
		draw_string_outline(f, Vector2(0, 31), title_txt, HORIZONTAL_ALIGNMENT_CENTER, w, 24, 5, Color(0.08, 0.02, 0.10))
		draw_string(f, Vector2(0, 31), title_txt, HORIZONTAL_ALIGNMENT_CENTER, w, 24, accent.lightened(0.22))
		draw_string_outline(f, Vector2(0, 50), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, w, 13, 3, Color(0.08, 0.02, 0.10))
		draw_string(f, Vector2(0, 50), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color("#FFF0D4"))


class TileDebuffOverlay extends Node2D:
	var kind: = "fog"
	var turns_left: = 3
	var tile_ref: Tile
	var _t: = 0.0

	func setup(t: Tile, debuff_kind: String) -> TileDebuffOverlay:
		tile_ref = t
		kind = debuff_kind
		turns_left = 3
		z_index = 12
		set_meta(DEBUFF_META, kind)
		return self

	func _process(dt: float) -> void:
		_t += dt
		if tile_ref == null or not is_instance_valid(tile_ref) or not tile_ref.alive or tile_ref.pending:
			queue_free()
			return
		if kind == "freeze" and tile_ref.ice <= 0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var hw: = Tile.TW * 0.48
		var hh: = Tile.TH * 0.48
		var r: = Rect2(-hw, -hh, hw * 2.0, hh * 2.0)
		if kind == "freeze":
			draw_rect(r, Color(0.32, 0.82, 1.0, 0.48), true)
			draw_rect(r.grow(-3.0), Color(0.75, 0.96, 1.0, 0.30), true)
			draw_rect(r, Color(0.78, 0.97, 1.0, 0.92), false, 2.6)
			draw_line(Vector2(-hw + 6, -hh + 10), Vector2(hw - 8, hh - 12), Color(1, 1, 1, 0.78), 1.8, true)
			draw_line(Vector2(hw - 10, -hh + 8), Vector2(-4, 6), Color(1, 1, 1, 0.72), 1.6, true)
			for i in 3:
				var a: = float(i) * PI / 3.0 + _t * 0.35
				var d: = Vector2(cos(a), sin(a)) * 15.0
				draw_line(-d, d, Color(0.92, 0.99, 1.0, 0.92), 2.2, true)
		else:
			draw_rect(r, Color(0.11, 0.05, 0.18, 0.88), true)
			for i in 3:
				var ox: = sin(_t * 2.1 + float(i) * 2.1) * 10.0
				var oy: = cos(_t * 1.7 + float(i) * 1.9) * 8.0 + float(i - 1) * 10.0
				draw_circle(Vector2(ox, oy), 22.0, Color(0.46, 0.22, 0.64, 0.50))
			draw_rect(r, Color("#C678FF"), false, 2.2)
			var sw: = sin(_t * 2.8) * 2.5
			var tal: = Rect2(-13.0 + sw, -26.0, 26.0, 52.0)
			draw_rect(tal, Color("#F6E6C4"), true)
			draw_rect(tal, Color("#D64550"), false, 1.8)
			draw_line(tal.position + Vector2(7, 10), tal.position + Vector2(19, 10), Color("#C92A3E"), 2.2)
			draw_line(tal.position + Vector2(13, 10), tal.position + Vector2(13, 42), Color("#C92A3E"), 2.2)
			draw_line(tal.position + Vector2(7, 24), tal.position + Vector2(19, 34), Color("#C92A3E"), 1.8)


class UltButton extends Control:
	signal triggered
	var frac: = 0.0
	var ready_state: = false
	var ult_dmg: = 120
	var ult_title: = "СУПЕРУДАР"
	var accent: = Color("#FFB86C")
	var _t: = 0.0
	var _lock_ms: = 0

	func setup(r: Rect2, title: String, dmg: int, acc: Color) -> UltButton:
		position = r.position
		size = r.size
		pivot_offset = r.size * 0.5
		ult_title = title
		ult_dmg = dmg
		accent = acc
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		return self

	func set_state(f: float, rdy: bool, dmg: int) -> void:
		frac = clampf(f, 0.0, 1.0)
		ready_state = rdy
		ult_dmg = dmg
		queue_redraw()

	func _on_gui_input(e: InputEvent) -> void:
		var ok: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
		if not ok:
			return
		var now_ms: = Time.get_ticks_msec()
		if now_ms - _lock_ms < 220:
			return
		_lock_ms = now_ms
		accept_event()
		if ready_state:
			V9Feel.press(self, "pop", "button")
			triggered.emit()
		else:
			V9Feel.deny(self)

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var pulse: = 0.5 + 0.5 * sin(_t * 4.2)
		if ready_state:
			draw_rect(r.grow(7.0 + 3.0 * pulse), Color(1.0, 0.72, 0.24, 0.24 + 0.16 * pulse), true)
			draw_rect(r.grow(3.0), Color(0.96, 0.26, 0.38, 0.42 + 0.18 * pulse), true)
		draw_rect(r, Color(0.16, 0.05, 0.14, 0.96), true)
		var pad: = 4.0
		var ir: = Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
		var fw: = ir.size.x * (1.0 if ready_state else frac)
		if fw > 1.0:
			var top_c: = Color("#D9384A") if ready_state else Color(0.56, 0.18, 0.30, 0.92)
			var bot_c: = Color("#9E1B32") if ready_state else Color(0.36, 0.10, 0.22, 0.92)
			draw_rect(Rect2(ir.position, Vector2(fw, ir.size.y)), bot_c, true)
			draw_rect(Rect2(ir.position, Vector2(fw, ir.size.y * 0.52)), top_c, true)
			if ready_state:
				var sx: = fmod(_t * 240.0, ir.size.x + 120.0) - 60.0
				var x0: = clampf(sx - 28.0, ir.position.x, ir.end.x)
				var x1: = clampf(sx + 28.0, ir.position.x, ir.end.x)
				if x1 > x0 + 1.0:
					draw_rect(Rect2(x0, ir.position.y, x1 - x0, ir.size.y), Color(1.0, 0.92, 0.62, 0.30), true)
		var brd: = Color("#FFE48F") if ready_state else Color("#B88B4A")
		draw_rect(r, brd, false, 3.0 if ready_state else 2.0)
		var f: = UI.font("body", 900)
		var charge_n: = int(round(frac * 100.0))
		var l1: = "★ СУПЕРУДАР ГОТОВ! ★" if ready_state else ("ЗАРЯД УЛЬТЫ · %d / 100" % charge_n)
		var l2: = ("НАЖМИ · УРОН %d + ОГЛУШЕНИЕ" % ult_dmg) if ready_state else ult_title
		var c1: = Color("#FFF6C4") if ready_state else Color("#F5DFBA")
		var c2: = Color("#FFD670") if ready_state else Color("#D2B49C")
		draw_string_outline(f, Vector2(0, size.y * 0.44), l1, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if ready_state else 18, 5, Color(0.08, 0.02, 0.08))
		draw_string(f, Vector2(0, size.y * 0.44), l1, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if ready_state else 18, c1)
		draw_string_outline(f, Vector2(0, size.y * 0.76), l2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0.08, 0.02, 0.08))
		draw_string(f, Vector2(0, size.y * 0.76), l2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, c2)


class ShieldBar extends Control:
	# «Щит стойкости» under the boss HP: a gold bar; blinks red/gold during ПРОБИТИЕ ×2.
	var cur: = 100
	var cap: = 100
	var broken: = 0
	var trail_frac: = 1.0
	var _t: = 0.0
	var flash_t: = 0.0

	func setup(r: Rect2) -> ShieldBar:
		position = r.position
		size = r.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func set_state(shield: int, shield_max: int, broken_turns: int, instant: bool = false) -> void:
		var old_frac: = float(cur) / float(maxi(1, cap))
		var new_frac: = float(shield) / float(maxi(1, shield_max))
		if instant or new_frac > old_frac + 0.001:
			trail_frac = new_frac
		elif new_frac < old_frac - 0.001:
			trail_frac = maxf(trail_frac, old_frac)
			flash_t = 0.2
		cur = shield
		cap = shield_max
		broken = broken_turns
		queue_redraw()

	func frac() -> float:
		return clampf(float(cur) / float(maxi(1, cap)), 0.0, 1.0)

	func is_blinking() -> bool:
		return broken > 0

	func label_text() -> String:
		if broken > 0:
			return "ПРОБИТИЕ ×2! ещё %d уд." % broken
		return "ЩИТ СТОЙКОСТИ %d / %d" % [cur, cap]

	func _process(dt: float) -> void:
		_t += dt
		if flash_t > 0.0:
			flash_t = maxf(0.0, flash_t - dt)
		var f: = frac()
		if trail_frac > f:
			trail_frac = move_toward(trail_frac, f, dt * 1.4)
		queue_redraw()

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var blink: = 0.5 + 0.5 * sin(_t * 12.0)
		var bg: = Color(0.07, 0.04, 0.03, 0.95)
		var edge: = Color("#F6D483")
		if broken > 0:
			edge = Color("#FF4757").lerp(Color("#FFE066"), blink)
			bg = Color(0.20, 0.03, 0.05, 0.96).lerp(Color(0.25, 0.17, 0.02, 0.96), blink)
		draw_rect(r, bg, true)
		var pad: = 3.0
		var ir: = Rect2(Vector2(pad, pad), Vector2(maxf(0.0, size.x - pad * 2.0), maxf(0.0, size.y - pad * 2.0)))
		var f: = frac()
		if broken > 0:
			var full: = Color("#FF5468").lerp(Color("#FFD86A"), blink)
			draw_rect(ir, full.darkened(0.15), true)
			draw_rect(Rect2(ir.position, Vector2(ir.size.x, ir.size.y * 0.5)), full, true)
		else:
			if trail_frac > f + 0.002:
				draw_rect(Rect2(ir.position, Vector2(ir.size.x * trail_frac, ir.size.y)), Color(1.0, 0.97, 0.80, 0.85), true)
			var fw: = ir.size.x * f
			if fw > 0.5:
				draw_rect(Rect2(ir.position, Vector2(fw, ir.size.y)), Color("#C9921E"), true)
				draw_rect(Rect2(ir.position, Vector2(fw, ir.size.y * 0.5)), Color("#FFD35C"), true)
				draw_rect(Rect2(ir.position + Vector2(0, 1), Vector2(fw, 2.0)), Color(1, 1, 1, 0.32), true)
		var seg_n: = clampi(int(round(float(cap) / 20.0)), 2, 8)
		for i in range(1, seg_n):
			var tx: = ir.position.x + ir.size.x * float(i) / float(seg_n)
			draw_line(Vector2(tx, ir.position.y), Vector2(tx, ir.end.y), Color(0, 0, 0, 0.35), 1.0)
		draw_rect(r, edge.lerp(Color.WHITE, clampf(flash_t * 3.0, 0.0, 1.0)), false, 2.0)
		var f_font: = UI.font("body", 900)
		var txt: = label_text()
		draw_string_outline(f_font, Vector2(0, size.y * 0.5 + 6.0), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0.08, 0.02, 0.06))
		draw_string(f_font, Vector2(0, size.y * 0.5 + 6.0), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color("#FFF6D6"))


class ShardBurst extends Node2D:
	# Golden shield shards flying out of the boss on ПРОБИТИЕ (pure state, stepped by _process).
	var shards: Array = []
	var elapsed: = 0.0
	var dur: = 0.95

	func setup(pos: Vector2, count: int) -> ShardBurst:
		position = pos
		var rng: = RandomNumberGenerator.new()
		rng.seed = 4242 + count
		for i in count:
			var ang: = float(i) / float(count) * TAU + rng.randf_range(-0.2, 0.2)
			var spd: = rng.randf_range(210.0, 470.0)
			shards.append({
				"p": Vector2.ZERO,
				"v": Vector2(cos(ang), sin(ang)) * spd + Vector2(0, -90.0),
				"rot": rng.randf() * TAU,
				"rv": rng.randf_range(-9.0, 9.0),
				"sz": rng.randf_range(9.0, 24.0),
				"gold": rng.randf() > 0.25,
			})
		return self

	func step(dt: float) -> void:
		elapsed += dt
		for s in shards:
			s.v = (s.v as Vector2) + Vector2(0, 760.0) * dt
			s.p = (s.p as Vector2) + (s.v as Vector2) * dt
			s.rot = float(s.rot) + float(s.rv) * dt

	func _process(dt: float) -> void:
		step(dt)
		if elapsed >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a: = clampf(1.0 - elapsed / dur, 0.0, 1.0)
		for s in shards:
			var c: = Color("#FFD35C") if bool(s.gold) else Color("#FFF1B8")
			var sz: float = float(s.sz)
			var rot: float = float(s.rot)
			var pts: = PackedVector2Array()
			for k in 3:
				var an: = rot + float(k) * TAU / 3.0
				var rr: = sz * (1.0 if k != 1 else 0.55)
				pts.append((s.p as Vector2) + Vector2(cos(an), sin(an)) * rr)
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, a))
			pts.append(pts[0])
			draw_polyline(pts, Color(1.0, 0.98, 0.88, a), 1.6, true)


class UltCutscene extends Control:
	signal impact
	signal finished
	var hero_id: = "mc"
	var hero_name: = "Маджонг-тян"
	var ult_title: = "Цветение Тысячи Костей"
	var quote_txt: = ""
	var accent: = Color("#FFB86C")
	var cg_tex: Texture2D
	var vid_player: VideoStreamPlayer
	var hud_overlay: Control
	var use_video: = false
	var elapsed: = 0.0
	var max_dur: = 1.15
	var _impact_sent: = false
	var _done: = false

	func setup(bleed: Rect2, h_id: String, h_name: String, u_title: String, quote: String, acc: Color, vid_path: String, fallback_tex: Texture2D) -> UltCutscene:
		position = bleed.position
		size = bleed.size
		hero_id = h_id
		hero_name = h_name
		ult_title = u_title
		quote_txt = quote
		accent = acc
		cg_tex = fallback_tex
		mouse_filter = Control.MOUSE_FILTER_STOP
		var headless: = DisplayServer.get_name() == "headless"
		if not headless and vid_path != "":
			var st: VideoStream = null
			if ResourceLoader.exists(vid_path):
				st = load(vid_path) as VideoStream
			if st == null:
				var th: = VideoStreamTheora.new()
				th.file = vid_path
				st = th
			if st != null:
				vid_player = VideoStreamPlayer.new()
				vid_player.stream = st
				vid_player.expand = true
				var vr: = V10Layout.cover_rect(Vector2(720, 1280), Rect2(Vector2.ZERO, size))
				vid_player.position = vr.position
				vid_player.size = vr.size
				vid_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vid_player.finished.connect(_finish_now)
				add_child(vid_player)
				use_video = true
				max_dur = 2.45
		hud_overlay = Control.new()
		hud_overlay.size = size
		hud_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_overlay.z_index = 4
		hud_overlay.draw.connect(_draw_hud)
		add_child(hud_overlay)
		if headless:
			max_dur = 0.05
		gui_input.connect(func(e: InputEvent) -> void:
			var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
			if tap and elapsed >= 0.14:
				accept_event()
				_finish_now())
		return self

	func _ready() -> void:
		if vid_player != null and is_instance_valid(vid_player):
			vid_player.play()

	func _process(dt: float) -> void:
		if _done:
			return
		elapsed += dt
		var imp_t: = 0.55 if not use_video else 0.72
		if not _impact_sent and elapsed >= imp_t:
			_impact_sent = true
			impact.emit()
		queue_redraw()
		if hud_overlay != null:
			hud_overlay.queue_redraw()
		if elapsed >= max_dur:
			_finish_now()

	func _finish_now() -> void:
		if _done:
			return
		_done = true
		if not _impact_sent:
			_impact_sent = true
			impact.emit()
		if vid_player != null and is_instance_valid(vid_player):
			vid_player.stop()
		finished.emit()
		queue_free()

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var c: = size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.09, 0.94), true)
		var vid_ok: = use_video and vid_player != null and is_instance_valid(vid_player) and vid_player.get_video_texture() != null
		if not vid_ok:
			for i in 14:
				var a: = elapsed * 1.1 + float(i) * TAU / 14.0
				var d1: = Vector2(cos(a), sin(a))
				var d2: = Vector2(cos(a + 0.11), sin(a + 0.11))
				var beam: = PackedVector2Array([c, c + d1 * h, c + d2 * h])
				draw_colored_polygon(beam, Color(accent.r, accent.g, accent.b, 0.18))
			var bh: = h * 0.54
			var by: = (h - bh) * 0.40
			var band_r: = Rect2(0, by, w, bh)
			draw_rect(band_r, Color(0.14, 0.04, 0.16, 0.96), true)
			if cg_tex != null:
				draw_texture_rect(cg_tex, band_r, false, Color(1, 1, 1, 0.96))
			draw_line(Vector2(0, by), Vector2(w, by - 18), Color("#FFE48F"), 5.0, true)
			draw_line(Vector2(0, by + bh), Vector2(w, by + bh - 18), Color("#FFE48F"), 5.0, true)

	func _draw_hud() -> void:
		var w: = size.x
		var h: = size.y
		var sl_p: = clampf(elapsed / 0.42, 0.0, 1.0)
		if elapsed < 0.75:
			var sa: = clampf(1.0 - elapsed / 0.75, 0.0, 1.0)
			hud_overlay.draw_line(Vector2(0, h * 0.72), Vector2(w * sl_p, h * 0.24), Color(1.0, 0.96, 0.84, 0.75 * sa), 7.0, true)
		var bot_h: = 196.0
		hud_overlay.draw_rect(Rect2(0, h - bot_h, w, bot_h), Color(0.05, 0.02, 0.09, 0.86), true)
		hud_overlay.draw_line(Vector2(24, h - bot_h), Vector2(w - 24, h - bot_h), Color("#FFE48F"), 3.0)
		var f: = UI.font("body", 900)
		hud_overlay.draw_string_outline(f, Vector2(28, h - bot_h + 42), "НЕБЕСНЫЙ ПРИЁМ · %s" % hero_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 18, 4, Color(0.06, 0.02, 0.08))
		hud_overlay.draw_string(f, Vector2(28, h - bot_h + 42), "НЕБЕСНЫЙ ПРИЁМ · %s" % hero_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 18, accent.lightened(0.25))
		hud_overlay.draw_string_outline(f, Vector2(28, h - bot_h + 86), ult_title, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 30, 6, Color(0.06, 0.02, 0.08))
		hud_overlay.draw_string(f, Vector2(28, h - bot_h + 86), ult_title, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 30, Color("#FFF4D2"))
		if quote_txt != "":
			hud_overlay.draw_string_outline(f, Vector2(28, h - bot_h + 130), "«%s»" % quote_txt, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 18, 4, Color(0.06, 0.02, 0.08))
			hud_overlay.draw_string(f, Vector2(28, h - bot_h + 130), "«%s»" % quote_txt, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 18, Color("#F2DCE8"))
		var skip_r: = Rect2(w - 178, 22, 156, 42)
		hud_overlay.draw_rect(skip_r, Color(0.08, 0.03, 0.12, 0.86), true)
		hud_overlay.draw_rect(skip_r, Color("#E8C47E"), false, 1.8)
		hud_overlay.draw_string(f, Vector2(skip_r.position.x, skip_r.position.y + 27), "Пропустить ›", HORIZONTAL_ALIGNMENT_CENTER, skip_r.size.x, 16, Color("#FFEAB3"))


# ── Static Orchestration Helpers ──────────────────────────────────────────────

static func spawn_projectiles(layer: Control, from_pt: Vector2, to_pt: Vector2, count: int, col: Color, on_impact: Callable) -> Array:
	var orbs: Array = []
	if layer == null or not is_instance_valid(layer):
		if on_impact.is_valid():
			on_impact.call()
		return orbs
	var n: = clampi(count, 2, 4)
	var span: = to_pt - from_pt
	var perp: = span.normalized().orthogonal() if span.length() > 1.0 else Vector2(1, 0)
	for i in n:
		var side: = -1.0 if i % 2 == 0 else 1.0
		var mag: = 88.0 + float(i) * 34.0
		var ctrl: = from_pt.lerp(to_pt, 0.46) + perp * (side * mag) + Vector2(0, -42.0)
		var is_last: = (i == n - 1)
		var cb: = on_impact if is_last else Callable()
		var orb: = EnergyOrb.new().setup(from_pt, ctrl, to_pt, col, float(i) * 0.045, cb)
		layer.add_child(orb)
		orbs.append(orb)
	if V9Feel.can_fx():
		Fx.burst(layer, from_pt, "petal", 6, col.lightened(0.3), 0.7)
	return orbs


static func spawn_slash(layer: Control, center_pt: Vector2, col: Color, count: int = 1, hold: float = SLASH_HOLD_DUR) -> SlashFx:
	if layer == null or not is_instance_valid(layer):
		return null
	var fx: = SlashFx.new().setup(center_pt, col, count, hold)
	layer.add_child(fx)
	return fx


static func spawn_shockwave(layer: Control, center_pt: Vector2, col: Color, radius: float = 145.0, heavy: bool = false) -> ShockwaveRing:
	if layer == null or not is_instance_valid(layer):
		return null
	var sw: = ShockwaveRing.new().setup(center_pt, col, radius, heavy)
	layer.add_child(sw)
	return sw


# ПРОБИТИЕ ЩИТА: gold shard burst + 110 ms slow-mo (time_scale 0.25, restored on a real-time timer) + big flash +
# shockwaves + floating «ПРОБИТИЕ! ×2 УРОН». Returns the ShardBurst node (null without a layer).
static func spawn_shield_break(layer: Control, center_pt: Vector2, slowmo: bool = true) -> ShardBurst:
	if layer == null or not is_instance_valid(layer):
		return null
	var burst: = ShardBurst.new().setup(center_pt, 26)
	layer.add_child(burst)
	spawn_shockwave(layer, center_pt, Color("#FFD35C"), 230.0, true)
	spawn_shockwave(layer, center_pt, Color("#FF5468"), 150.0, false)
	if V9Feel.can_fx():
		Fx.burst(layer, center_pt, "sparkle", 24, Color("#FFE48F"), 1.2)
		Fx.flash_glow(layer, center_pt, Color("#FFF4CC"), 3.0, 0.5)
	var tx: = layer.size.x * 0.5 if layer.size.x > 100.0 else center_pt.x
	spawn_float_text(layer, Vector2(tx, center_pt.y - 92.0), "ПРОБИТИЕ! ×2 УРОН", Color("#FFE066"), 40, 1.25)
	spawn_float_text(layer, Vector2(tx, center_pt.y - 40.0), "ЩИТ РАЗБИТ!", Color("#FF6B7A"), 26, 1.05)
	if slowmo and DisplayServer.get_name() != "headless" and layer.is_inside_tree():
		Engine.time_scale = SHIELD_SLOWMO_SCALE
		layer.get_tree().create_timer(SHIELD_SLOWMO_SEC, true, false, true).timeout.connect(func() -> void:
			Engine.time_scale = 1.0)
	return burst


static func spawn_float_text(layer: Control, pos: Vector2, txt: String, col: Color, fs: int, hold_sec: float = 0.88) -> Label:
	if layer == null or not is_instance_valid(layer):
		return null
	var l: = UI.label(txt, fs, col, Color(0.07, 0.02, 0.10), 6, "body", 900)
	var tw_w: = maxf(340.0, UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0)
	l.size = Vector2(tw_w, 56)
	l.position = pos - Vector2(tw_w * 0.5, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(tw_w * 0.5, 28)
	l.scale = Vector2(0.45, 0.45)
	layer.add_child(l)
	var tw: = l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.09)
	tw.parallel().tween_property(l, "position:y", l.position.y - 46.0, hold_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.28)
	tw.tween_callback(l.queue_free)
	return l


static func apply_board_debuff(board: TrayBoard, debuff_kind: String, count: int) -> Array[Tile]:
	var affected: Array[Tile] = []
	if board == null or not is_instance_valid(board):
		return affected
	var cands: Array = board.tiles.filter(func(t: Tile) -> bool:
		return board.on_board(t) and not t.pending and t.shard == "")
	if cands.is_empty():
		return affected
	var free_cands: Array = cands.filter(func(t: Tile) -> bool: return board.is_free(t))
	var rest_cands: Array = cands.filter(func(t: Tile) -> bool: return not board.is_free(t))
	free_cands.shuffle()
	rest_cands.shuffle()
	var pool: Array = free_cands + rest_cands
	var kinds: Array[String] = []
	if debuff_kind == "both":
		for i in maxi(2, count):
			kinds.append("freeze" if i % 2 == 0 else "fog")
	else:
		var k: = "freeze" if debuff_kind == "freeze" else "fog"
		for _i in maxi(1, count):
			kinds.append(k)
	var idx: = 0
	for k_str in kinds:
		while idx < pool.size():
			var t: Tile = pool[idx]
			idx += 1
			var has_existing: = false
			for ch in t.get_children():
				if ch.has_meta(DEBUFF_META):
					has_existing = true
					break
			if has_existing:
				continue
			if k_str == "freeze":
				t.ice = maxi(t.ice, 1)
				t._update_ice()
			var ov: = TileDebuffOverlay.new().setup(t, k_str)
			t.add_child(ov)
			affected.append(t)
			break
	board.reveal_free()
	return affected


static func tick_board_fog(board: TrayBoard) -> void:
	if board == null or not is_instance_valid(board):
		return
	for t in board.tiles:
		if not is_instance_valid(t):
			continue
		for ch in t.get_children():
			if ch is TileDebuffOverlay and (ch as TileDebuffOverlay).kind == "fog":
				var ov: = ch as TileDebuffOverlay
				ov.turns_left -= 1
				if ov.turns_left <= 0:
					ov.queue_free()


static func cleanse_board_debuffs(board: TrayBoard) -> int:
	if board == null or not is_instance_valid(board):
		return 0
	var n: = 0
	for t in board.tiles:
		if not is_instance_valid(t) or not t.alive:
			continue
		if t.ice > 0:
			t.ice = 0
			t._update_ice()
			n += 1
		for ch in t.get_children():
			if ch.has_meta(DEBUFF_META):
				ch.queue_free()
				n += 1
	board.reveal_free()
	return n


static func active_debuff_count(board: TrayBoard) -> int:
	if board == null or not is_instance_valid(board):
		return 0
	var n: = 0
	for t in board.tiles:
		if not is_instance_valid(t) or not t.alive:
			continue
		for ch in t.get_children():
			if ch.has_meta(DEBUFF_META) and not ch.is_queued_for_deletion():
				n += 1
				break
	return n
