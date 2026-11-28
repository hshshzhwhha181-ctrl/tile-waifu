class_name TrayFx
extends RefCounted

# The pictures of the tray board (P18): tweens, sprites and the table layout of the tile nodes. The board node asks, this
# animates; nothing here decides a rule (that is TWBoard) and nothing here waits on a timer except the deal's click sounds.


# the tile nodes on the table (home positions, faces, shadows); returns the bounds of the table in board pixels
static func dress(board: TrayBoard) -> Rect2:
	var tiles: Array[Tile] = board.tiles
	var minx: = 999
	var miny: = 999
	var maxx: = -999
	var maxy: = -999
	var maxz: = 0
	for t in tiles:
		minx = mini(minx, t.gx)
		miny = mini(miny, t.gy)
		maxx = maxi(maxx, t.gx)
		maxy = maxi(maxy, t.gy)
		maxz = maxi(maxz, t.gz)
	var w: = (maxx - minx) * TrayBoard.UX + Tile.TW
	var h: = (maxy - miny) * TrayBoard.UY + Tile.TH
	var dz: = TrayBoard.DZ
	var off: = Vector2( - w * 0.5 + Tile.TW * 0.5, - h * 0.5 + Tile.TH * 0.5) - dz * maxz * 0.5
	for t in tiles:
		t.home = off + Vector2((t.gx - minx) * TrayBoard.UX, (t.gy - miny) * TrayBoard.UY) + dz * t.gz
		t.position = t.home
		t.build(board.look)
		V10TileMarks.attach(t)  # v10-clarity hook: suit mark / back badge
		if t.shard != "":
			t.set_shard(t.shard)
		t.mat.set_shader_parameter("dim", 0.0)
		board.tile_layer.add_child(t)
		if t.gz == 0:
			var s: = Sprite2D.new()
			s.texture = G.fx("tile_shadow")
			s.scale = Vector2(Tile.S, Tile.S) * 1.25
			s.position = t.home + Vector2(16, 26)
			s.modulate = Color(0.35, 0.1, 0.25, 0.6)
			board.floor_layer.add_child(s)
	return Rect2(off - Vector2(Tile.TW, Tile.TH) * 0.5 + dz * maxz, Vector2(w, h) - dz * maxz + Vector2(14, 22))


# a pair of the tray settles: the two tiles squeeze together and pop
static func pair_pop(a: Tile, b: Tile) -> void :
	var mid: = (a.position + b.position) * 0.5
	for t in [a, b]:
		t.kill_move()
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", mid + (t.position - mid).normalized() * 14.0, 0.08)
		tw.tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.05)
		tw.tween_property(t, "scale", t.scale * 1.25, 0.05)
		tw.tween_property(t, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.14)
		tw.tween_callback(t.hide)


# a pair removed without a tray match (ult / skill): the glow follows the cut-in palette, the shader caps it so the face stays readable
static func vanish(a: Tile, b: Tile, tint: Color) -> void :
	for t in [a, b]:
		t.kill_move()
		t.z_index = 150
		if t.mat:
			t.mat.set_shader_parameter("flash_col", Vector3(tint.r, tint.g, tint.b))
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", t.position + Vector2(0, -30), 0.15).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.15)
		tw.tween_property(t, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.18)
		tw.tween_callback(t.hide)


static func fly_home(t: Tile) -> void :
	t.kill_move()
	var tw: Tween = t.create_tween().set_parallel()
	tw.tween_property(t, "position", t.home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2.ONE, 0.28)
	tw.chain().tween_callback( func():
		t.z_index = 0
		t.shadow.visible = true)


static func shuffle_wave(ts: Array) -> void :
	for t in ts:
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "scale", Vector2(0.0, 1.0), 0.12).set_delay(randf() * 0.2)
		tw.tween_property(t, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", 1.1)


# the deal: every tile drops from 60 px above its home and fades in, lower layers first. fast = the luck-card deal (the whole
# table down in ~0.75 s). Returns the seconds until the last tile has landed (its drop + a beat); the tweens are kept in tws.
static func deal_in(board: TrayBoard, fast: bool, gen: int, tws: Array[Tween]) -> float:
	var n: = board.tiles.size()
	var step: = minf(0.004, 0.32 / maxf(1.0, n)) if fast else 0.012
	var zk: = 0.05 if fast else 0.12
	var drop: = 0.26 if fast else 0.32
	var last: = 0.0
	for i in n:
		var t: Tile = board.tiles[i]
		t.position = t.home + Vector2(0, -60)
		t.modulate.a = 0.0
		var d: = step * i + t.gz * zk
		last = maxf(last, d)
		var tw: Tween = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.home, drop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		tw.tween_property(t, "modulate:a", 1.0, drop * 0.56).set_delay(d)
		tws.append(tw)
		if i % (8 if fast else 6) == 0:
			board.get_tree().create_timer(d + drop * 0.62).timeout.connect( func():
				if is_instance_valid(board) and gen == board._deal_gen:
					Sfx.play("clack%d" % (randi() % 3), randf_range(0.9, 1.1), -8))
	return last + drop + 0.12


# a tap during the deal lands every tile still in flight in 0.14 s
static func deal_land(board: TrayBoard) -> void :
	for t in board.tiles:
		if not is_instance_valid(t) or not board.on_board(t):
			continue
		if t.position.is_equal_approx(t.home) and t.modulate.a >= 0.999:
			continue
		var tw: Tween = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.home, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "modulate:a", 1.0, 0.1)


# a deal-skipping tap must land on the table (its tile bounds + a margin), not anywhere on the screen
static func deal_hit(board: TrayBoard, gp: Vector2) -> bool:
	if board.tile_layer == null:
		return false
	var lp: = board.tile_layer.to_local(gp)
	var r: = Rect2()
	var first: = true
	for t in board.tiles:
		if not board.on_board(t):
			continue
		var tr: = Rect2(t.home - Vector2(Tile.TW, Tile.TH) * 0.5, Vector2(Tile.TW, Tile.TH))
		r = tr if first else r.merge(tr)
		first = false
	return not first and r.grow(24.0).has_point(lp)


# where tray position i of n sits (the display squeezes together when it holds more than the slots)
static func slot_at(b: TrayBoard, i: int, n: int) -> Vector2:
	if n <= b.slots:
		return b._slot_local(i)
	return b._slot_local(0).lerp(b._slot_local(b.slots - 1), float(i) / float(n - 1))


# the displayed tray tiles fly to their slots; the arriving one takes the longer arc
static func layout_tray(b: TrayBoard, arriving: Tile) -> void :
	var s: = b._tray_scale()
	var n: = b.display.size()
	for i in n:
		var t: Tile = b.display[i]
		var sc: = s * (1.0 if n <= b.slots else float(b.slots) / n * 1.05)
		if t == arriving:
			t.fly_to(slot_at(b, i, n), sc, 0.26, true)
		else:
			t.fly_to(slot_at(b, i, n), sc, 0.16, false)


# a tap on the table while the deal lands: the tile under the finger glints, a clack and a light haptic answer it
static func deal_tap(b: TrayBoard, gp: Vector2) -> bool:
	if not deal_hit(b, gp):
		return false
	var dt: = b.tile_at(gp)
	if dt:
		dt.press_glint()
	V9Feel.haptic("tap")
	V9Feel.sound("clack%d" % (randi() % 3), randf_range(1.05, 1.15), -6.0)
	return true
