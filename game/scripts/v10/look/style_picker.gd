class_name V10StylePicker
extends Control

# V10StylePicker — «Мой стиль» (D1; UX §3.2 moves it to Героини → Стиль): Рамка / Фишки / Стол / Интерфейс, each
# «Авто (как у партнёра)», «Базовый» or a hand pick of what the player owns, with a live preview on top. Locked kit
# elements are not listed (no lock walls, UX §6.4). «Сохранить» writes S.look via V10Look.set_choice.
# One primary on the screen (UX §3.4 П-1): «Сохранить». The preview's button is a still specimen of the skin's
# «Игра» class (no ux_role, no breathing, untappable). Each row of options is one choice control (ux_role
# "option", ux_group = slot); rows scroll sideways by touch, a drag never picks.
#
#   V10StylePicker.make(S, size) -> V10StylePicker         signal done(changed)

signal done(changed: bool)

const PREVIEW_H: = 268.0
const ROW_H: = 184.0
const CHIP: = Vector2(128, 148)
const CAPTION: = 18
const SLOT_NAMES: = {"frame": "Рамка", "tile": "Фишки", "table": "Стол", "hud": "Интерфейс"}

var S: Dictionary
var work: = {}
var own: = {}
var preview_box: Control
var rows: = {}
var cards: = {}   # slot -> {value: _Card}


static func make(save: Dictionary, sz: Vector2) -> V10StylePicker:
	var p: = V10StylePicker.new()
	p.S = save
	p.size = sz
	p.work = V10Look.look_of(save)
	p.own = V10Look.owned_elements(save)
	p._build()
	return p


func _build() -> void:
	var bg: = ColorRect.new()
	bg.color = V10HudSkin.tok("night_700")
	bg.size = size
	add_child(bg)
	var x: = 24.0
	var h1: = V10HudSkin.label("Мой стиль", 44, V10HudSkin.tok("paper_100"), "display", size.x - 48)
	h1.position = Vector2(x, 24)
	h1.size = Vector2(size.x - 48, 60)
	add_child(h1)
	preview_box = Control.new()
	preview_box.position = Vector2(x, 96)
	preview_box.size = Vector2(size.x - 48, PREVIEW_H)
	add_child(preview_box)
	var y: = 96.0 + PREVIEW_H + 20.0
	for slot in ["frame", "tile", "table", "hud"]:
		var row: = Control.new()
		row.position = Vector2(x, y)
		row.size = Vector2(size.x - 48, ROW_H)
		add_child(row)
		rows[slot] = row
		y += ROW_H
	var save_b: = V10HudSkin.button("play", "Сохранить", Rect2((size.x - 440) * 0.5, size.y - 128, 440, 104), _save)
	save_b.name = "Save"
	add_child(save_b)
	var cur: = _effective()
	# the rows are built once (a pick never rebuilds them, so a row scrolled sideways stays where the finger left it)
	for slot in rows:
		_row(slot, rows[slot], cur)
	_refresh()


func _effective() -> Dictionary:
	var tmp: = S.duplicate(true)
	tmp["look"] = work.duplicate()
	return V10Look.current(tmp)


func _refresh() -> void:
	for c in preview_box.get_children():
		c.queue_free()
	var cur: = _effective()
	# live preview «Так выглядит твой стол»: board on the table, the frame, a HUD plate + a still specimen of the
	# skin's «Игра» button (smaller than «Сохранить», untappable, no breathing)
	var board: = V10LookBoard.make(String(cur.tile), String(cur.table), Rect2(0, 0, 380, PREVIEW_H), {"cols": 3, "rows": 2})
	preview_box.add_child(board)
	var keep: = V10HudSkin.active
	var keep_p: = V10HudSkin.palette
	V10HudSkin.use(String(cur.hud), String(cur.palette))
	var fr: = V10FrameView.make(String(cur.frame), _face(), 120.0, {"anim": false})
	fr.position = Vector2(400 + (preview_box.size.x - 400 - 120) * 0.5, 0)
	preview_box.add_child(fr)
	var pl: = V10HudSkin.plate("S", String(V10HudSkinData.skin(String(cur.hud)).name), "", Rect2(400, 140, preview_box.size.x - 400, 48))
	preview_box.add_child(pl)
	var pb: = V10HudSkin.button("play", "Играть", Rect2(412, 204, preview_box.size.x - 424, 56), Callable(), true)
	preview_box.add_child(pb)
	V10HudSkin.use(keep, keep_p)
	_mark()


# the picked option of every row: gold border and gold caption
func _mark() -> void:
	for slot in cards:
		for v in cards[slot]:
			var c: _Card = cards[slot][v]
			c.on = String(work[slot]) == String(v)
			c.queue_redraw()
			var l: Label = c.get_node_or_null("Name")
			if l:
				l.label_settings.font_color = V10HudSkin.tok("gold_300") if c.on else V10HudSkin.tok("paper_300")


func _row(slot: String, row: Control, cur: Dictionary) -> void:
	cards[slot] = {}
	var cap: = V10HudSkin.label(String(SLOT_NAMES[slot]), 15, V10HudSkin.tok("gold_500"))
	cap.uppercase = true
	cap.position = Vector2(0, 0)
	cap.size = Vector2(200, 20)
	row.add_child(cap)
	var opts: = [V10Look.AUTO, V10Look.BASE] + Array(own.get(slot, []))
	var scroll: = ScrollContainer.new()
	scroll.name = "Scroll_" + slot
	scroll.position = Vector2(0, 28)
	scroll.size = Vector2(row.size.x, CHIP.y + 4)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	row.add_child(scroll)
	var hb: = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	scroll.add_child(hb)
	for v in opts:
		var chip: = _chip(slot, String(v), cur)
		hb.add_child(chip)


func _chip(slot: String, v: String, cur: Dictionary) -> Control:
	var c: = _Card.new()
	c.custom_minimum_size = CHIP
	c.size = CHIP
	c.on = String(work[slot]) == v
	var shown: = v
	if v == V10Look.AUTO:
		var tmp: = S.duplicate(true)
		tmp["look"] = V10Look.DEFAULT_LOOK.duplicate()
		shown = String(V10Look.current(tmp)[slot])
	elif v == V10Look.BASE:
		shown = V10Look._base(slot, S)
	var art: Control = null
	var ax: = (CHIP.x - 96.0) * 0.5
	match slot:
		"frame":
			art = V10FrameView.make(shown, _face(), 72.0, {"anim": false, "glow": false})
			art.position = Vector2((CHIP.x - 72.0) * 0.5, 8)
		"tile":
			art = V10TileTheme.thumb(shown if shown != "" else "s_sakura", Vector2(54, 72))
			art.position = Vector2((CHIP.x - 54.0) * 0.5, 8)
		"table":
			var holder: = Control.new()
			holder.size = Vector2(96, 76)
			holder.position = Vector2(ax, 6)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if shown != "":
				holder.add_child(V10TileTheme.table_rect(shown, Rect2(4, 4, 88, 68), {"frame_w": 6.0, "radius": 6.0, "static": true}))
			else:
				var cr: = ColorRect.new()
				cr.color = V10TileTheme.LOCATION_FELT
				cr.position = Vector2(4, 4)
				cr.size = Vector2(88, 68)
				cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(cr)
			art = holder
		"hud":
			var tk: = V10HudSkinData.tokens(shown)
			var sw: = V10KitStrip._Swatch.new()
			sw.cols = [tk.night_800, tk.gold_500, tk.rose_500]
			sw.size = Vector2(96, 72)
			sw.position = Vector2(ax, 8)
			art = sw
	if art:
		c.add_child(art)
	var nm: = "Авто" if v == V10Look.AUTO else ("Базовый" if v == V10Look.BASE else _name(slot, v))
	# Caption 18 (UX §6.3 minimum), two lines at most (§4.1) — «Ледяной павильон» wraps instead of clipping
	var l: = V10HudSkin.label(nm, CAPTION, V10HudSkin.tok("gold_300") if c.on else V10HudSkin.tok("paper_300"))
	l.name = "Name"
	l.position = Vector2(6, 84)
	l.size = Vector2(CHIP.x - 12, 56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.label_settings.line_spacing = -4.0
	c.add_child(l)
	c.set_meta("ux_role", "option")
	c.set_meta("ux_group", slot)
	cards[slot][v] = c
	V10HudSkin.tappable(c, func():
		work[slot] = v
		_refresh())
	return c


# the face inside frame previews: the partner when she is released, else Маджонг-тян
func _face() -> String:
	var h: = String(S.get("partner", "mc"))
	return h if V10ProfileCos.released(h) else "mc"


static func _name(slot: String, id: String) -> String:
	match slot:
		"frame":
			return String(V10ProfileCos.entry(id).get("name", id))
		"tile":
			return String(V10TileTheme.theme(id).name)
		"table":
			return String(V10TileTheme.table(id).get("name", id))
		"hud":
			return String(V10HudSkinData.skin(id).name)
	return id


func _save() -> void:
	var changed: = false
	var before: = V10Look.look_of(S)
	for slot in work:
		if String(before[slot]) != String(work[slot]):
			if V10Look.set_choice(S, slot, String(work[slot])) == "":
				changed = true
	if changed:
		V10Look.notify(S)
	done.emit(changed)


class _Card extends Control:
	var on: = false

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10HudSkin.tok("night_800")
		sb.set_corner_radius_all(4)
		sb.anti_aliasing = true
		if on:
			sb.border_color = V10HudSkin.tok("gold_500")
			sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if not on:
			draw_line(Vector2(12, 0.5), Vector2(size.x - 12, 0.5), Color(V10HudSkin.tok("gold_700"), 0.35), 1.0)
