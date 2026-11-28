class_name TWDraw
extends RefCounted

# TWDraw (P28 / WP9b): the vector "lacquer" drawing kit shared by every TW widget (moved out of V10Button/V10Plate, which keep
# thin forwarding statics for their legacy callers). Pure functions of a CanvasItem + a rect; colours only via TWSkin/TWTokens.
# Also: closed-scale text helpers (fit steps are TWTokens.TYPE_* only) and the safe-area bridge until TWLayout lands.

static var sim_insets: Dictionary = {}   # tests: {"top": 48, "bottom": 24}; empty -> the real insets (legacy bridge)
static var overflow: Array = []          # strings that needed an ellipsis (selftest: must stay empty for real HUD strings)


# ------------------------------------------------------------------ geometry

static func rr_pts(r: Rect2, rad: float, segs: = 8) -> PackedVector2Array:
	var rr: = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var pts: = PackedVector2Array()
	var corners: = [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5, 0.0],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0, PI * 0.5],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5, PI],
		[Vector2(r.position.x + rr, r.position.y + rr), PI, PI * 1.5],
	]
	for c in corners:
		var ctr: Vector2 = c[0]
		var a0: float = c[1]
		var a1: float = c[2]
		for i in segs + 1:
			var a: = lerpf(a0, a1, float(i) / float(segs))
			pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts


static func grad_cols(pts: PackedVector2Array, y0: float, y1: float, stops: Array) -> PackedColorArray:
	var out: = PackedColorArray()
	var span: = maxf(0.001, y1 - y0)
	var last: = stops.size() - 1
	for p in pts:
		var t: = clampf((p.y - y0) / span, 0.0, 1.0)
		var col: Color = stops[last][1]
		if t <= float(stops[0][0]):
			col = stops[0][1]
		else:
			for i in last:
				var t0: float = stops[i][0]
				var t1: float = stops[i + 1][0]
				if t <= t1:
					var k: = clampf((t - t0) / maxf(0.0001, t1 - t0), 0.0, 1.0)
					col = (stops[i][1] as Color).lerp(stops[i + 1][1] as Color, k)
					break
		out.append(col)
	return out


static func hairline(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var f: = minf(float(TWTokens.HAIR_FADE), (x1 - x0) * 0.3)
	var c0: = Color(col, 0.0)
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + f, y), Vector2(x1 - f, y), Vector2(x1, y)]),
			PackedColorArray([c0, col, col, c0]), 1.0)


# ------------------------------------------------------------------ surfaces

static func lacquer(ci: CanvasItem, r: Rect2, rad: float, c_top: Color, c_mid: Color, c_bot: Color, rim_a: = 1.0, sheen_col: = Color.TRANSPARENT, sheen_a: = 0.16) -> void:
	# the gold-bezel lacquer slab (journey CTAs, ult badges): shadow, bezel, groove, 3-stop body, glass sheen, filigree, gleam
	var sc: = sheen_col if sheen_col.a > 0.0 else TWSkin.c("PAPER_100")
	var rr: = clampf(rad, 4.0, minf(r.size.x, r.size.y) * 0.5)
	ci.draw_colored_polygon(rr_pts(Rect2(r.position + Vector2(0, 5), r.size).grow(1.5), rr + 1.5, 8), Color(TWSkin.c("NIGHT_900"), 0.52 * rim_a))
	var op: = rr_pts(r, rr, 10)
	ci.draw_polygon(op, grad_cols(op, r.position.y, r.end.y, [
		[0.0, Color(TWSkin.c("PLATE_SPARK"), rim_a)],
		[0.45, Color(TWSkin.c("GOLD_500"), rim_a)],
		[1.0, Color(TWSkin.c("GOLD_700"), rim_a)],
	]))
	ci.draw_colored_polygon(rr_pts(r.grow(-2.5), maxf(2.0, rr - 2.5), 10), TWSkin.c("NIGHT_900"))
	var r3: = r.grow(-3.8)
	var p3: = rr_pts(r3, maxf(2.0, rr - 3.8), 10)
	ci.draw_polygon(p3, grad_cols(p3, r3.position.y, r3.end.y, [[0.0, c_top], [0.5, c_mid], [1.0, c_bot]]))
	var sr: = Rect2(r3.position.x + 4.0, r3.position.y + 1.5, r3.size.x - 8.0, r3.size.y * 0.44)
	if sr.size.x > 8.0 and sr.size.y > 4.0:
		var sp: = rr_pts(sr, maxf(2.0, rr - 5.5), 8)
		ci.draw_polygon(sp, grad_cols(sp, sr.position.y, sr.end.y, [[0.0, Color(sc, sheen_a)], [1.0, Color(sc, 0.0)]]))
	var p4: = rr_pts(r.grow(-6.5), maxf(2.0, rr - 6.5), 10)
	p4.append(p4[0])
	ci.draw_polyline(p4, Color(TWSkin.c("GOLD_300"), 0.55 * rim_a), 1.2, true)
	hairline(ci, r.position.x + rr + 4.0, r.end.x - rr - 4.0, r.position.y + 1.2, Color(TWSkin.c("PLATE_SPARK"), 0.85 * rim_a))


static func plate_surface(ci: CanvasItem, r: Rect2, over_art: = true, down: = false, sel: = false, dis: = false, foc: = false, flash: = -1.0, fill_override: = Color.TRANSPARENT) -> void:
	# the one plate surface (HUD v2 §2.2, "expensive lacquer"): warm gradient, thin antique-gold rim with an inner highlight,
	# champagne corner studs, exactly ONE top hairline (two when focused). Shared by plates, chips, sheets, toasts, the tab bar.
	var rad: = float(TWTokens.R_MD) * 0.625   # 10 px
	var a_fill: = TWTokens.ON_ART_A if over_art else 1.0
	var top_c: Color = TWSkin.c("PLATE_SEL_TOP") if sel else TWSkin.c("PLATE_TOP")
	var bot_c: Color = TWSkin.c("PLATE_SEL_BOT") if sel else TWSkin.c("PLATE_BOT")
	if down:
		top_c = TWSkin.c("NIGHT_600")
		bot_c = TWSkin.c("NIGHT_700")
	if fill_override.a > 0.0:
		top_c = fill_override
		bot_c = fill_override.darkened(0.25)
	var op: = rr_pts(r, rad, 8)
	var rim_a: = 0.2 if dis else (1.0 if (sel or foc) else (0.9 if down else 0.6))
	ci.draw_polygon(op, grad_cols(op, r.position.y, r.end.y, [[0.0, Color(TWSkin.c("PLATE_SPARK"), rim_a)], [0.5, Color(TWSkin.c("PLATE_RIM"), rim_a)], [1.0, Color(TWSkin.c("GOLD_700"), rim_a)]]))
	var r2: = r.grow(-1.5)
	var ip: = rr_pts(r2, rad - 1.5, 8)
	ci.draw_polygon(ip, grad_cols(ip, r2.position.y, r2.end.y, [[0.0, Color(top_c, a_fill)], [1.0, Color(bot_c, a_fill)]]))
	var lh: = r.size.y * 0.45
	var lac: = Color(TWSkin.c("PAPER_100"), TWTokens.LACQUER_A)
	var clear: = Color(TWSkin.c("PAPER_100"), 0.0)
	ci.draw_polygon(PackedVector2Array([r.position + Vector2(rad * 0.6, 2.5), r.position + Vector2(r.size.x - rad * 0.6, 2.5),
			r.position + Vector2(r.size.x - 3, lh), r.position + Vector2(3, lh)]), PackedColorArray([lac, lac, clear, clear]))
	var hp: = rr_pts(r.grow(-4.0), rad - 4.0, 8)
	hp.append(hp[0])
	ci.draw_polyline(hp, Color(TWSkin.c("GOLD_500"), 0.10 if dis else 0.26), 1.0, true)
	ci.draw_line(r.position + Vector2(rad, r.size.y - 2.5), r.position + Vector2(r.size.x - rad, r.size.y - 2.5),
			Color(TWSkin.c("NIGHT_900"), TWTokens.BOTTOM_TONE_A), 1.5)
	if not dis:
		for cxy in [Vector2(r.position.x + 7, r.position.y + 7), Vector2(r.end.x - 7, r.position.y + 7), Vector2(r.position.x + 7, r.end.y - 7), Vector2(r.end.x - 7, r.end.y - 7)]:
			ci.draw_colored_polygon(PackedVector2Array([cxy + Vector2(0, -2.6), cxy + Vector2(2.6, 0), cxy + Vector2(0, 2.6), cxy + Vector2(-2.6, 0)]), Color(TWSkin.c("PLATE_SPARK"), 0.8))
	var la: = TWTokens.HAIR_A
	var lc: = TWSkin.c("GOLD_700")
	if dis:
		la = 0.15
	if down:
		lc = TWSkin.c("GOLD_500")
		la = 0.6
	if sel or foc:
		lc = TWSkin.c("GOLD_500")
		la = 1.0
	hairline(ci, r.position.x + TWTokens.HAIR_INSET, r.end.x - TWTokens.HAIR_INSET, r.position.y + 0.5, Color(lc, la))
	if foc:
		hairline(ci, r.position.x + TWTokens.HAIR_INSET, r.end.x - TWTokens.HAIR_INSET, r.end.y - 1.5, Color(lc, la))
	if flash >= 0.0:
		var fx: = lerpf(r.position.x + TWTokens.HAIR_INSET, r.end.x - TWTokens.HAIR_INSET, flash)
		for i in 8:
			var k: = 1.0 - i / 8.0
			ci.draw_line(Vector2(fx - 32.0 * k, r.position.y + 0.5), Vector2(fx + 32.0 * k, r.position.y + 0.5),
					Color(TWSkin.c("GOLD_300"), 0.12), 1.0)


# ------------------------------------------------------------------ text (closed type scale)

static func settings(role: String, size: int, color: Color, on_art: = false) -> LabelSettings:
	return V10Type.settings(role, size, color, on_art)   # fonts: V10Type until TWType lands; outline 0, shadow only on art


static func label(text: String, role: String, size: int, color: Color, on_art: = false) -> Label:
	return V10Type.label(text, role, size, color, on_art)


static func text_w(text: String, role: String, size: int) -> float:
	return V10Type.text_w(text, role, size)


static func fit(l: Label, text: String, role: String, sizes: Array, max_w: float, color: Color, on_art: = false, max_lines: = 1) -> int:
	# first size of `sizes` (TWTokens.TYPE_*, descending) whose text fits max_w (max_lines lines); else the last size + ellipsis
	var chosen: int = sizes[sizes.size() - 1]
	var ok: = false
	for s in sizes:
		if max_lines <= 1:
			if text_w(text, role, s) <= max_w:
				chosen = s
				ok = true
				break
		elif V10Type.lines_needed(text, role, s, max_w) <= max_lines:
			chosen = s
			ok = true
			break
	if not ok:
		overflow.append({"text": text, "max_w": max_w, "role": role})
	l.text = text
	l.label_settings = settings(role, chosen, color, on_art)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if max_lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = max_lines
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.set_meta("tw_fit_ok", ok)
	return chosen


static func line_h(size: int) -> int:
	return V10Type.line_h(size)


static func label_h(l: Label, role: String, size: int, lines: = 1) -> float:
	# box_h, but never below what THIS label's text really needs (fallback-font glyphs such as no. / rouble / dashes are taller than the main font)
	var extra: = maxf(0.0, l.get_minimum_size().y - ceilf(V10Type.font(role).get_height(size)))
	return box_h(role, size, lines) + extra


static func box_h(role: String, size: int, lines: = 1) -> float:
	# the height a Label of this role/size/line count really needs: the natural font height for the first line (a Label's minimum size),
	# plus the closed line height for every further line. Boxes smaller than this get silently grown by the Label.
	return ceilf(V10Type.font(role).get_height(size)) + float(maxi(0, lines - 1) * V10Type.line_h(size))


# ------------------------------------------------------------------ env bridges

static func safe_insets(vs: Vector2) -> Dictionary:
	if not sim_insets.is_empty():
		var out: = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
		for k in sim_insets:
			out[k] = float(sim_insets[k])
		return out
	return V10Hud2Util.safe_insets(vs)


static func fx_level() -> String:
	return V10Hud2Util.fx_level()


static func feedback(from: Node, denied: = false) -> void:
	# tap sound + haptic through the autoloads that exist (soft node lookups: no hard dependency on legacy classes)
	if from == null or not from.is_inside_tree():
		return
	var root: = from.get_tree().root
	var sfx: = root.get_node_or_null("Sfx")
	if sfx != null and sfx.has_method("play"):
		if denied:
			sfx.call("play", "deny", 1.0, -4.0)
		else:
			sfx.call("play", "tap", randf_range(0.96, 1.04), -4.0)
	var hp: = root.get_node_or_null("V7Haptics")
	if hp != null and hp.has_method("kind"):
		hp.call("kind", "deny" if denied else "button")
