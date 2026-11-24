class_name V10SevenPanel
extends Control

# V10SevenPanel — «Семь встреч» (spec Г4) as a card for the morning tray (V10Tray provider) and as a standalone
# panel: seven ivory tiles, one per day of coming in; ready ones glow, claimed ones carry a small cinnabar seal.
# «Забрать всё» claims every ready day (cascade, pentatonic up).
#   var p: = V10SevenPanel.make(G.S, Rect2(24, 300, 672, 330), give)    give(reward: Dictionary) grants it

var S: Dictionary
var give: Callable
var tiles: = []
var btn: JButton


static func make(state: Dictionary, r: Rect2, give_fn: Callable) -> V10SevenPanel:
	var p: = V10SevenPanel.new()
	p.S = state
	p.give = give_fn
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p._build()
	return p


static func icon_of(r: Dictionary) -> Texture2D:
	match String(r.icon):
		"gem": return V8Art.cur("gem")
		"ticket": return V8Art.cur("ticket")
		"coin": return V8Art.cur("coin")
	return G.tile_tex(20)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	tiles.clear()
	add_child(V10GUI.sheet(Rect2(Vector2.ZERO, size), 0.9))
	var ol: = V10GUI.overline("семь встреч", V10GUI.GOLD_500)
	ol.position = Vector2(20, 16)
	add_child(ol)
	var st: = V10Seven.st(S)
	var t: = V10GUI.lbl("День %d из 7 · дни не обязательно подряд" % st.days.size(), 20, V10GUI.PAPER_300, "body", 800)
	t.position = Vector2(20, 40)
	add_child(t)
	var n: = 7
	var gap: = 8.0
	var tw: = (size.x - 40 - gap * (n - 1)) / n
	var th: = tw * 1.38
	var ready: = V10Seven.claimable(S)
	for i in n:
		var r: Dictionary = V10Seven.REWARDS[i]
		var tile: = Control.new()
		tile.position = Vector2(20 + i * (tw + gap), 80)
		tile.size = Vector2(tw, th)
		tile.pivot_offset = tile.size * 0.5
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var claimed: bool = st.claimed[i]
		var is_ready: = i in ready
		var p: = Panel.new()
		p.size = tile.size
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("efe6d2") if not claimed else Color("8d8578")
		sb.set_corner_radius_all(8)
		sb.border_color = V10GUI.GOLD_300 if is_ready else Color("c9a45a", 0.6)
		sb.set_border_width_all(3 if is_ready else 1)
		if is_ready:
			sb.shadow_color = Color(1.0, 0.8, 0.4, 0.5)
			sb.shadow_size = 10
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(p)
		var d: = V10GUI.lbl(str(i + 1), 18, Color("6b5a3c"), "title", 700)
		d.position = Vector2(8, 2)
		tile.add_child(d)
		var ic: = V10GUI.icon(icon_of(r), Rect2(tw * 0.18, th * 0.28, tw * 0.64, tw * 0.64))
		tile.add_child(ic)
		var amt: = "" if r.kind == "item" else ("×%d" % int(r.n) if r.kind == "tickets" else str(int(r.n)))
		var al: = V10GUI.lbl(amt, 16, Color("3d3020"), "body", 900)
		al.position = Vector2(0, th - 28)
		al.size = Vector2(tw, 10)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(al)
		if claimed:
			tile.modulate = Color(0.85, 0.82, 0.8)
			var seal: = V10GUI.HankoSeal.new()
			seal.text = "✓"
			seal.ink = 1.0
			seal.size = Vector2(tw * 0.6, tw * 0.6)
			seal.position = Vector2(tw * 0.36, th * 0.52)
			seal.rotation = deg_to_rad(-10)
			seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(seal)
		elif i >= st.days.size():
			tile.modulate = Color(0.55, 0.52, 0.5, 0.85)
		add_child(tile)
		tiles.append(tile)
	var by: = 80 + th + 20
	if not ready.is_empty():
		btn = JButton.make("Забрать всё", "pink", Rect2(20, by, size.x - 40, 96), null, 30)
		btn.set_meta("ux_role", "primary")
		btn.pulse = true
		btn.pressed.connect(_claim_all)
		add_child(btn)
	else:
		var nx: = V10GUI.lbl("Завтра — следующая встреча" if not V10Seven.done(S) else "Все семь встреч позади", 20, V10GUI.PAPER_500, "body", 700)
		nx.position = Vector2(20, by + 30)
		add_child(nx)


func _claim_all() -> void:
	var ready: = V10Seven.claimable(S)
	var chips: = []
	for k in ready.size():
		var i: int = ready[k]
		var r: = V10Seven.claim(S, i, give)
		if r.is_empty():
			continue
		var tile: Control = tiles[i]
		UI.punch(tile, 0.2, 0.3)
		var c: = V10GUI.chip(String(r.text), icon_of(r), 44, V10GUI.GOLD_300)
		c.position = Vector2(20, -56 - 52 * k)
		add_child(c)
		chips.append(c)
	V10GUI.hanko(self, Vector2(size.x - 80, 60), "ВСТРЕЧА", 110, -8)
	V10GUI.cascade(chips, 0.1)
	G.save()
	var t: = create_tween()
	t.tween_interval(1.6)
	t.tween_callback(func():
		for c in chips:
			c.queue_free()
		_build())
