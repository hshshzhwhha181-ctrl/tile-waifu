class_name V10TilePicker
extends Control

# V10TilePicker — Героини → «Фишки и столы» (D3): a grid of live 3×2 previews (real tiles on the theme's table).
# Owned themes are pickable; of the locked ones only ONE teaser is shown («Откроется: …», UX §6.4).
#
#   V10TilePicker.make(S, size, opts) -> V10TilePicker     opts: ranked (shows the «стандартные лица» plate)
#   signal picked(theme_id)

signal picked(theme_id: String)

const CELL: = Vector2(328, 268)
const GAP: = 16.0

var S: Dictionary
var ranked: = false


static func make(save: Dictionary, sz: Vector2, opts: = {}) -> V10TilePicker:
	var p: = V10TilePicker.new()
	p.S = save
	p.size = sz
	p.ranked = bool(opts.get("ranked", false))
	p._build()
	return p


func _build() -> void:
	var bg: = ColorRect.new()
	bg.color = V10HudSkin.tok("night_900")
	bg.size = size
	add_child(bg)
	var h1: = V10HudSkin.label("Фишки и столы", 44, V10HudSkin.tok("paper_100"), "display", size.x - 48)
	h1.position = Vector2(24, 24)
	h1.size = Vector2(size.x - 48, 60)
	add_child(h1)
	var y0: = 96.0
	if ranked:
		var pl: = V10HudSkin.plate("S", "Рейтинг: лица фишек стандартные", "", Rect2(24, y0, 432, 48))
		add_child(pl)
		y0 += 64.0
	var own: Array = V10Look.owned_elements(S).tile
	var cur: = V10Look.current(S)
	var list: = []
	var teaser: = ""
	for id in V10TileTheme.THEMES:
		var hidden: = not V10ProfileCos.released(String(V10TileTheme.THEMES[id].owner)) and not V10Look.dev_reveal.has(String(V10TileTheme.THEMES[id].owner))
		if id in own:
			list.append(id)
		elif teaser == "" and not hidden:
			teaser = id
	if teaser != "":
		list.append(teaser)
	var x0: = (size.x - (CELL.x * 2 + GAP)) * 0.5
	for i in list.size():
		var id: String = list[i]
		var pos: = Vector2(x0 + (i % 2) * (CELL.x + GAP), y0 + (i / 2) * (CELL.y + GAP))
		if pos.y + CELL.y > size.y:
			break
		_cell(id, Rect2(pos, CELL), id in own, String(cur.tile) == id)


func _cell(id: String, r: Rect2, owned: bool, on: bool) -> void:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	var th: = V10TileTheme.theme(id)
	var board: = V10LookBoard.make(id, String(th.get("table", "")), Rect2(0, 0, r.size.x, 196), {"ranked": ranked, "pad": 18.0})
	c.add_child(board)
	var nm: = V10HudSkin.label(String(th.name), 22, V10HudSkin.tok("gold_300") if on else V10HudSkin.tok("paper_100"))
	nm.position = Vector2(4, 204)
	nm.size = Vector2(r.size.x - 8, 30)
	c.add_child(nm)
	var sub: = ""
	if owned:
		sub = "Выбрано" if on else V10ProfileCos.hero_name(String(th.owner))
	else:
		sub = "Откроется: %s (%s)" % [V10ProfileCos.hero_name(String(th.owner)), th.tier]
		board.modulate = Color(0.45, 0.42, 0.45, 1.0)
	var sl: = V10HudSkin.label(sub, 18, V10HudSkin.tok("paper_500"))
	sl.position = Vector2(4, 236)
	sl.size = Vector2(r.size.x - 8, 26)
	c.add_child(sl)
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			var g_ok: = get_tree().root.get_node_or_null("G") != null
			if owned:
				if g_ok:
					V9Feel.press(c)
				picked.emit(id)
			elif g_ok:
				V9Feel.deny(c))
