class_name V10MjStackCache
extends Node2D

# V10MjStackCache — renders a big static stack (Classic/Shanghai 144, Cube faces, Garden) cheaply.
# Each layer z is baked once into a SubViewport (shadows of that layer + its bodies + faces, at the screen's pixel
# density), shown as one quad. Only what moves stays live: the faces of free tiles (breathing, accent outline) are
# drawn on top of their layer's bake with the same shared materials. Re-bake after a move with refresh().
# Tiles must sit on a grid where faces do not overlap (pitch ≥ the face size, e.g. V10MjTileView.TW × 88 px), so a
# live face never covers a neighbour.
#
#   var sc := V10MjStackCache.new(); board.add_child(sc)
#   sc.build(tiles)            # V10MjTileView nodes (not in the tree yet, or children of `board`): they move inside
#   sc.refresh()               # after removing a tile or changing free/closed states
#   sc.remove_tile(t)          # takes a tile out (e.g. a matched pair flies away live) and re-bakes its layer
# fx_level=min: the live faces still exist (they just do not breathe); nothing else changes.

var layers: = {}        # z -> {vp, root, spr, rect}
var tiles: Array = []
var live: = {}          # tile -> Sprite2D
var light: = {}
var px: = 1.0
const PAD: = Vector2(70, 80)


func build(ts: Array, lt: = {}) -> void:
	tiles = ts.duplicate()
	light = lt
	px = 1.0
	if is_inside_tree():
		px = maxf(get_viewport().get_final_transform().get_scale().x * get_global_transform().get_scale().x, 0.5)
	var by_z: = {}
	for t in tiles:
		if not by_z.has(t.z):
			by_z[t.z] = []
		by_z[t.z].append(t)
	for z in by_z:
		var r: = Rect2()
		var first: = true
		for t in by_z[z]:
			var tr: = Rect2(t.position - PAD * t.scale, PAD * 2.0 * t.scale + Vector2(20, 30) * t.scale)
			r = tr if first else r.merge(tr)
			first = false
		var vp: = SubViewport.new()
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.size = Vector2i(ceili(r.size.x * px), ceili(r.size.y * px))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		add_child(vp)
		var root: = Node2D.new()
		root.scale = Vector2.ONE * px
		root.position = -r.position * px
		vp.add_child(root)
		var lt_local: = _local_light(r)
		for t in by_z[z]:
			if t.get_parent():
				t.get_parent().remove_child(t)
			root.add_child(t)
			t.set_light(lt_local)
		var spr: = Sprite2D.new()
		spr.texture = vp.get_texture()
		spr.centered = false
		spr.position = r.position
		spr.scale = Vector2.ONE / px
		spr.z_index = int(z) * 200
		# the bake holds premultiplied colour (soft shadows over a transparent background)
		var pm: = CanvasItemMaterial.new()
		pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		spr.material = pm
		add_child(spr)
		layers[z] = {"vp": vp, "root": root, "spr": spr, "rect": r}
	_live_faces()


func _local_light(r: Rect2) -> Dictionary:
	var l: = light.duplicate()
	if l.has("lamp"):
		l.lamp = (Vector2(l.lamp) - r.position) * px
	return l


func _live_faces() -> void:
	for t in live:
		if is_instance_valid(live[t]):
			live[t].queue_free()
	live.clear()
	if V10MjTileMaterial.fx_level() == "min" and not bool(V10MjTileMaterial.st().get("hl_free", false)):
		return   # nothing would move: the bake is the whole picture
	var hl: = bool(V10MjTileMaterial.st().get("hl_free", false))
	for t in tiles:
		if not is_instance_valid(t) or not t.is_open or t.closed:
			continue
		var f: = Sprite2D.new()
		f.texture = t.face_spr.texture
		f.self_modulate = t.face_spr.self_modulate
		f.material = V10MjTileView.shared_material("face", t.material_id, light, true, false, hl, t.accent)
		f.scale = t.face_spr.scale * t.scale
		f.position = t.position
		f.z_index = int(t.z) * 200 + 199
		add_child(f)
		live[t] = f


func refresh() -> void:
	for z in layers:
		layers[z].vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_live_faces()


func remove_tile(t: V10MjTileView) -> void:
	tiles.erase(t)
	if live.has(t):
		live[t].queue_free()
		live.erase(t)
	if is_instance_valid(t):
		t.queue_free()
	refresh()


func live_count() -> int:
	return live.size()
