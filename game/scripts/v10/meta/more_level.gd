class_name V10MoreLevel
extends RefCounted

# «Ещё уровень» (docs/0.10-spec.md M1 Ф5): one tap from the victory window straight into the next table.
#
#   V10MoreLevel.next_index(cur, stars, count, was_done) -> int
#       the level the button starts, or -1 at the limit:
#       · a FIRST win (the level had no stars before) → the first level after `cur` that is not passed yet
#         (levels passed out of order are skipped);
#       · a REPLAY of an old level (was_done) → simply the next one in order (cur + 1);
#       · past V10Levels.count() → -1: no «Ещё уровень»; the victory panel makes «В чайную» the primary action and
#         says «Все столы арки пройдены · новая уже в пути» as a caption (no dead grey button, UX_RULES §3.5).
#       stars: S.stars ({"<index>": n}); count: V10LevelGen.count() once the 1000-level path is in, G.LEVELS.size() now.
#   V10MoreLevel.state(ctx) -> {next, text, enabled, hint}       for the victory panel (at the limit: text = T_SOON
#                                                                caption, enabled = false, hint = T_SOON_HINT)
#   V10MoreLevel.label_of: Callable(index) -> String             level caption on the button (default index + 1)
#   V10MoreLevel.wipe(parent, on_cover, dur = 0.4)               the 0.4 s curtain between victory and the new table:
#       a night-lacquer diagonal sweep with gold.500 edges; on_cover() runs when the screen is fully covered (start
#       the level there), then the curtain slides away on whatever screen is now under it (CanvasLayer 90).
#       fx_level=min: no sweep — a plain night.900 cover fades in and out in 120 ms (UX §6.7).

const T_MORE: = "Ещё уровень · %s"
const T_SOON: = "Все столы арки пройдены · новая уже в пути"
const T_SOON_HINT: = "Все столы этой арки пройдены. Новая арка уже в пути"
const WIPE_DUR: = 0.4

static var label_of: Callable = Callable()


static func _passed(stars: Dictionary, i: int) -> bool:
	return int(stars.get(str(i), 0)) > 0


static func next_index(cur: int, stars: Dictionary, count: int, was_done: bool) -> int:
	if cur < 0 or count <= 0:
		return -1
	var n: = cur + 1
	if not was_done:
		while n < count and _passed(stars, n):
			n += 1
	return n if n < count else -1


static func level_label(i: int) -> String:
	if label_of.is_valid():
		return str(label_of.call(i))
	return str(i + 1)


static func state(ctx: Dictionary) -> Dictionary:
	var count: = int(ctx.get("count", 0))
	if count <= 0:
		count = G.LEVELS.size()
	var stars: Dictionary = ctx.stars_map if ctx.get("stars_map") is Dictionary else G.S.get("stars", {})
	var nx: = next_index(int(ctx.get("level", -1)), stars, count, bool(ctx.get("was_done", false)))
	if nx < 0:
		return {"next": -1, "text": T_SOON, "enabled": false, "hint": T_SOON_HINT}
	return {"next": nx, "text": T_MORE % level_label(nx), "enabled": true, "hint": ""}


static func wipe(parent: Node, on_cover: Callable, dur: float = WIPE_DUR) -> CanvasLayer:
	var tree: = parent.get_tree()
	var vs: Vector2 = parent.get_viewport().get_visible_rect().size
	var layer: = CanvasLayer.new()
	layer.layer = 90
	tree.root.add_child(layer)
	if not V9Feel.can_fx():
		var cover: = ColorRect.new()
		cover.color = V10MetaUI.NIGHT_900
		cover.size = vs
		cover.mouse_filter = Control.MOUSE_FILTER_STOP
		cover.modulate.a = 0.0
		layer.add_child(cover)
		var ft: = layer.create_tween()
		ft.tween_property(cover, "modulate:a", 1.0, 0.12)
		ft.tween_callback(func():
			if on_cover.is_valid():
				on_cover.call())
		ft.tween_property(cover, "modulate:a", 0.0, 0.12)
		ft.tween_callback(layer.queue_free)
		return layer
	var w: = vs.x
	var h: = vs.y
	var slant: = h * 0.35
	var poly: = Polygon2D.new()
	# a slanted band wider than the screen; sweeps from the right edge to the left
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w + slant, 0), Vector2(w, h), Vector2(-slant, h)])
	poly.vertex_colors = PackedColorArray([V10MetaUI.NIGHT_700, V10MetaUI.NIGHT_800, V10MetaUI.NIGHT_900, V10MetaUI.NIGHT_900])
	var edge: = Line2D.new()
	edge.points = PackedVector2Array([Vector2(-slant, h), Vector2(0, 0)])
	edge.width = 6.0
	edge.default_color = V10MetaUI.GOLD_500
	edge.antialiased = true
	var edge2: = Line2D.new()
	edge2.points = PackedVector2Array([Vector2(w, h), Vector2(w + slant, 0)])
	edge2.width = 6.0
	edge2.default_color = V10MetaUI.GOLD_500
	edge2.antialiased = true
	var band: = Node2D.new()
	band.add_child(poly)
	band.add_child(edge)
	band.add_child(edge2)
	band.position = Vector2(w + slant + 20, 0)
	layer.add_child(band)
	V9Feel.sound("whoosh", 1.1, -4.0)
	var t: = layer.create_tween()
	t.tween_property(band, "position:x", 0.0, dur * 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		V9Feel.haptic("button")
		if on_cover.is_valid():
			on_cover.call())
	t.tween_interval(0.04)
	t.tween_property(band, "position:x", -(w + slant + 20), dur * 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(layer.queue_free)
	return layer
