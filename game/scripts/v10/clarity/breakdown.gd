class_name V10Breakdown
extends RefCounted

# The victory breakdown «За что очки» (replaces play._v8_yaku_chips; hook in play._victory, see README):
#   a header «ЗА ЧТО ОЧКИ» + a «Почему так?» pill (the summary card: stars, rank points, crystals of THIS match);
#   rows: icon · clear name · one small line «за что» · +N. The first row is «Стол пройден +N» (6 + 4/★ + 8 сложность),
#   then the bonuses, biggest first. Rows that do not fit (720×1280: 3 bonuses) fold into «Ещё N бонусов ›», which
#   opens the full list in the summary card. A tap on any row opens its card «За что / Как получить снова».
#   The first time a bonus is ever earned: ONE «НОВОЕ» badge on the biggest new row (+ «ещё N впервые» when more are
#   new) and a soft gold glow on every new row — no floating tooltip over the list (it covered the header and «Почему так?»).
# Rows are stamped one per beat from play._v9_yaku_at (the same rhythm as the 0.9 chips): drop from 1.12×, land with
# a click a semitone higher each, a sheen across the row.
#
#   V10Breakdown.build(play, plate, x, y, w, stars, reward) -> float  (the y under the block)
#   V10Breakdown.tap_reward(play, row, stars, reward)                    the crystal row opens «из чего сумма»

const ROW_H: = 58.0
const ROW_GAP: = 6.0
const BEAT: = 0.22

static func rows_for(play) -> Array:
	var out: = []
	var ysum: = 0
	var bon: = []
	for yk in play.yaku_list:
		var p: = V10Glossary.bonus_points(yk)
		ysum += p
		bon.append({"id": V10Glossary.bonus_id(yk), "yaku": yk, "pts": p})
	bon.sort_custom(func(a, b): return int(a.pts) > int(b.pts))
	var base: int = int(play.rp_gain) - mini(ysum, V8PlayRules.PATH_YAKU_CAP)
	if base > 0:
		out.append({"id": "win.base", "yaku": "", "pts": base, "why": base_why(play)})
	out.append_array(bon)
	return out

static func base_why(play) -> String:
	var st: = V8PlayRules.story_stars(int(play.fails), int(play.boosters_used))
	if G.demo:
		st = 3
	var hard: int = int(play.cfg.get("hard", 0)) if String(play.mode) == "" else 0
	var s: = "6 за победу + %d за %d★" % [st * 4, st]
	if hard > 0:
		s += " + %d за сложный стол" % (hard * 8)
	return s

static func build(play, plate: Control, x: float, y: float, w: float, stars: int, reward: int) -> float:
	var rows: = rows_for(play)
	# header
	var hd: = UI.label("ОЧКИ РАНГА · ЗА ЧТО", 17, Color("ffd98a"), UI.DARK, 2, "body", 900)
	hd.position = Vector2(x + 6, y + 4)
	plate.add_child(hd)
	var why_pill: = UI.rbox("plum", Rect2(x + w - 214, y - 2, 214, 36), 18, 2, 4)
	why_pill.borders(Color("ffe7a6"), Color("8a6a3a"))
	why_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.add_child(why_pill)
	why_pill.add_child(UI.center_label(UI.label("Почему так?  ›", 17, Color("ffe7a6"), UI.DARK, 2, "body", 900), Rect2(0, 0, 214, 36)))
	_tappable(why_pill, func(): summary(play, stars, reward))
	y += 42.0
	if rows.is_empty():
		var nl: = UI.label("Бонусов нет. Сыграй без подсказок — будет больше", 17, UI.MUTED)
		nl.position = Vector2(x + 6, y)
		nl.size = Vector2(w - 12, 26)
		nl.clip_text = true
		plate.add_child(nl)
		return y + 28.0
	var vh: float = play.size.y
	# a short screen (720×1280) keeps the panel about as tall as the 0.9 chips (her bust still fits under it):
	# «Стол пройден», the biggest bonus and «Ещё N» with the icons of the rest
	var compact: = vh < 1400.0
	var rh: = 50.0 if compact else ROW_H
	var fit: = 3 if compact else clampi(int((vh - 1280.0) / (ROW_H + ROW_GAP)) + 4, 4, 10)
	var shown: = rows.size()
	if rows.size() > fit:
		shown = fit - 1
	var t0: float = float(play.get("_v9_yaku_at")) if play.get("_v9_yaku_at") != null else 1.3
	# one «НОВОЕ» badge only (on the biggest new bonus shown); the rest say «ещё N впервые» on that badge
	var n_new: = 0
	for r in rows:
		if _is_new(r):
			n_new += 1
	var badge_done: = false
	for i in shown:
		var r: Dictionary = rows[i]
		var is_new: = _is_new(r)
		var badge: = -1
		if is_new and not badge_done:
			badge_done = true
			badge = n_new - 1
		var row: = _row(plate, Rect2(x, y, w, rh), r, is_new, play, badge)
		row.modulate.a = 0.0
		var tw: = row.create_tween()
		tw.tween_interval(t0 + i * BEAT)
		tw.tween_callback(_stamp.bind(row, i, is_new))
		y += rh + ROW_GAP
	if shown < rows.size():
		var more: = rows.size() - shown
		var mp: = UI.rbox("glass", Rect2(x, y, w, 40), 20, 2, 4)
		mp.borders(Color(1.0, 0.9, 0.7, 0.35), Color(0, 0, 0, 0.35))
		mp.mouse_filter = Control.MOUSE_FILTER_STOP
		plate.add_child(mp)
		var sum: = 0
		for i in range(shown, rows.size()):
			sum += int(rows[i].pts)
		var ml: = UI.label("Ещё %d %s" % [more, V8PlayRules.plural(more, "бонус", "бонуса", "бонусов")], 18, Color("ffe7a6"), UI.DARK, 2, "body", 900)
		ml.position = Vector2(16, 0)
		ml.size = Vector2(150, 40)
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp.add_child(ml)
		var ix: = 160.0
		for i in range(shown, rows.size()):
			if ix > w - 130.0:
				break
			mp.add_child(V10ClarityIcon.make(String(V10Glossary.get_entry(rows[i].id).get("icon", "art:trophy")), 30, Vector2(ix, 5)))
			ix += 33.0
		var sl: = UI.label("+%d  ›" % sum, 20, Color("ffd98a"), UI.DARK, 3, "body", 900)
		sl.position = Vector2(w - 110, 0)
		sl.size = Vector2(98, 40)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp.add_child(sl)
		_tappable(mp, func(): summary(play, stars, reward, true))
		mp.modulate.a = 0.0
		mp.create_tween().tween_property(mp, "modulate:a", 1.0, 0.25).set_delay(t0 + shown * BEAT)
		y += 46.0
	# mark everything seen now (the NEW tag shows on this screen only)
	for r in rows:
		if r.id != "win.base":
			V10ClarityState.mark_seen(r.id)
	return y

# ONE counter for «НОВОЕ», the card's «Получено уже N раз» and the glossary's «×N»: G.S.yaku_seen for G.YAKU bonuses
# (play._on_clear has already counted this match), the clarity «seen» marks for «Тройка: …» (set:N)
static func count_for(id: String, yk: String) -> int:
	if yk != "" and not yk.begins_with("set"):
		return int(G.S.get("yaku_seen", {}).get(yk, 0))
	return V10ClarityState.seen_count(id)

static func _is_new(r: Dictionary) -> bool:
	if r.id == "win.base":
		return false
	var yk: String = r.yaku
	if yk != "" and not yk.begins_with("set:"):
		return count_for(r.id, yk) <= 1 and V10ClarityState.seen_count(r.id) == 0
	return V10ClarityState.seen_count(r.id) == 0

static func _row(plate: Control, rr: Rect2, r: Dictionary, is_new: bool, play, badge: = -1) -> RBox:
	var e: = V10Glossary.get_entry(r.id)
	var row: = UI.rbox("plum", rr, 20, 2, 4)
	row.borders(Color("ffe7a6") if is_new else Color(1.0, 0.9, 0.7, 0.45), Color("c58a2c") if is_new else Color(0, 0, 0, 0.35))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.add_child(row)
	row.add_child(V10ClarityIcon.make(String(e.get("icon", "art:trophy")), rr.size.y - 10.0, Vector2(8, 5)))
	var nm: = UI.label(String(e.get("name", r.id)), 20, Color("fff2d2"), UI.DARK, 3, "body", 900)
	nm.position = Vector2(64, 4 if rr.size.y >= 56.0 else 1)
	nm.size = Vector2(rr.size.x - 64 - 86, 28)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nm)
	var why_t: String = String(r.get("why", e.get("why", "")))
	var wl: = UI.label(why_t, 15 if rr.size.y >= 56.0 else 14, Color("cfc2b4"), UI.DARK, 2, "body", 800)
	wl.position = Vector2(64, rr.size.y - 28.0)
	wl.size = Vector2(rr.size.x - 64 - 86, 22)
	wl.clip_text = true
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(wl)
	var pl: = UI.label("+%d" % int(r.pts), 26, Color("ffd98a"), Color("5a1a6a"), 4, "body", 900)
	pl.position = Vector2(rr.size.x - 84, 0)
	pl.size = Vector2(74, rr.size.y)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pl)
	if badge >= 0:
		var bt: = "НОВОЕ" if badge == 0 else "НОВОЕ · ещё %d впервые" % badge
		var bw: = UI.font("body", 900).get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0
		var nb: = UI.rbox("red", Rect2(rr.size.x - 88 - bw, -10, bw, 22), 11, 2, 3)
		row.add_child(nb)
		nb.add_child(UI.center_label(UI.label(bt, 13, Color.WHITE, UI.DARK, 2, "body", 900), Rect2(0, 0, bw, 22)))
	var id: String = r.id
	var pts: int = int(r.pts)
	var yk: String = r.yaku
	_tappable(row, func():
		var cnt: = count_for(id, yk)
		var extra: = {"points": "+%d %s ранга" % [pts, V8PlayRules.points_word(pts)] + (" и +15 кристаллов" if yk.begins_with("set:") else ""), "new": is_new}
		if id != "win.base":
			extra["count"] = cnt
		V10InfoCard.open(play, id, extra))
	row.pivot_offset = Vector2(rr.size.x * 0.5, rr.size.y * 0.5)
	return row

# a press feel + tap (release inside, small movement); also fires on a long press
static func _tappable(c: Control, cb: Callable) -> void:
	var st: = {"down": false, "at": Vector2.ZERO}
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.down = true
				st.at = e.position
				V9Feel.press_down(c)
			elif st.down:
				st.down = false
				var ok: bool = Rect2(Vector2.ZERO, c.size).has_point(e.position) and e.position.distance_to(st.at) < 24.0
				V9Feel.press_up(c, ok, "tap")
				if ok:
					cb.call())

static func _stamp(row: Control, i: int, is_new: bool) -> void:
	if not is_instance_valid(row) or not row.is_inside_tree():
		return
	row.modulate.a = 1.0
	row.scale = Vector2(1.12, 1.12)
	var t: = row.create_tween()
	t.tween_property(row, "scale", Vector2(0.98, 0.98), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pop", pow(2.0, i / 12.0), -6)
	V9Feel.haptic("tap")
	if row is RBox:
		(row as RBox).shine(0.08, 0.6)
		if is_new:
			(row as RBox).set_param("glow", 1.0).set_param("glow_color", Color(1.0, 0.82, 0.4))
			var g: = row.create_tween().set_loops(3)
			g.tween_method(func(v): (row as RBox).set_param("glow", v), 1.0, 0.35, 0.6)
			g.tween_method(func(v): (row as RBox).set_param("glow", v), 0.35, 1.0, 0.6)
			Fx.burst(row, Vector2(row.size.x - 110, 4), "sparkle", 12, Color(1, 0.88, 0.5), 0.8)

# «Почему так?»: stars of THIS match, the rank points as a sum, the crystals and (all=true) every bonus row
static func summary(play, stars: int, reward: int, all: = false) -> void:
	var helps: int = int(play.boosters_used)
	var fails: int = int(play.fails)
	var lines: = []
	var star_why: = "3★: ни подсказок, ни переполнений" if stars >= 3 else ("2★: до 2 подсказок без переполнений" if stars == 2 else "1★: победа (подсказок %d, переполнений %d)" % [helps, fails])
	lines.append(["Звёзды · %d★" % stars, "%s. Правило: 1★ победа · 2★ до 2 подсказок · 3★ без помощи" % star_why])
	var rows: = rows_for(play)
	var parts: = []
	var total: = 0
	for r in rows:
		total += int(r.pts)
		if all or parts.size() < 6:
			parts.append("%s +%d" % [V10Glossary.label(r.id), int(r.pts)])
	if not rows.is_empty():
		var tail: = "" if all or rows.size() <= 6 else " …"
		lines.append(["Очки ранга · +%d" % int(play.rp_gain), " · ".join(parts) + tail + (". Бонусы дают не больше %d за стол" % V8PlayRules.PATH_YAKU_CAP if total > int(play.rp_gain) else "")])
	var cm: = crystal_math(play, stars, reward)
	lines.append(["Кристаллы · +%d" % int(cm.total), String(cm.text)])
	V10InfoCard.open_text(play, "Почему такие награды?", "разбор этой партии", "art:trophy", lines, "", false, "win")

# the crystal line of «Почему так?»: ALWAYS adds up to the big number on the victory screen (reward + play.gained,
# play._victory rolls exactly that). play._on_clear: reward = (стол + 20/★) [× 2 + gained with ва-банк], and the
# crystals of the match (play.gained) were already paid during it — so ва-банк doubles them too.
static func crystal_math(play, stars: int, reward: int) -> Dictionary:
	var gained: int = int(play.gained)
	var total: = reward + gained
	var riichi: = bool(play.riichi)
	var base_g: = 0
	var star_g: = 0
	var parts: = []
	if String(play.mode) in ["", "daily"]:
		base_g = int(play.cfg.get("reward", {}).get("gems", 0))
		star_g = stars * 20
		parts.append("стол %d" % base_g)
		parts.append("звёзды %d×20" % stars)
	if gained > 0:
		parts.append("собрано в партии %d" % gained)
	var sum: = base_g + star_g + gained
	if riichi:
		sum *= 2
	var text: = ""
	if parts.is_empty():
		text = "За эту партию кристаллов нет"
	elif riichi:
		text = "(%s) × 2 за ва-банк = %d" % [" + ".join(parts), sum]
	else:
		text = "%s = %d" % [" + ".join(parts), sum]
	if sum != total:
		# any other source (a mode's own prize): named, so the line still adds up to the big number
		text += "; ещё %+d — награда режима" % (total - sum)
	return {"total": total, "text": text, "sum": sum}

static func tap_reward(play, row: Control, stars: int, reward: int) -> void:
	if row == null:
		return
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_tappable(row, func(): summary(play, stars, reward))
