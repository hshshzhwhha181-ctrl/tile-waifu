class_name V6SpecialBoard
extends TrayBoard










signal special(kind: String, data: Dictionary)

const JOKER: = 300

var spec: = {}
var icons: = {}
var pairs_done: = 0
var plan: = {}




func _ok_tile(t: Tile) -> bool:
	return t.shard == "" and not t.gold and t.ice <= 0 and not t.gift and t.face < 36 and not spec.has(t)\
	and not bool(t.get_meta("v6_nospecial", false))

func apply_specials(p: Dictionary) -> void :
	plan = p
	spec.clear()
	icons.clear()
	pairs_done = 0
	var by: = {}
	for t in tiles:
		by[t.step] = by.get(t.step, []) + [t]
	var steps: Array = by.keys().filter( func(k): return by[k].size() == 2 and _ok_tile(by[k][0]) and _ok_tile(by[k][1]))
	steps.sort()
	var npairs: = tiles.size() / 2
	if npairs < 8 or steps.size() < 6:
		return
	var budget: = maxi(1, npairs / 3)
	var used: = {}
	var pick: = func(lo: float, hi: float, min_step: = 0) -> int:
		var c: Array = steps.filter( func(k): return not used.has(k) and k >= min_step and k >= int(lo * npairs) and k <= int(hi * npairs))
		if c.is_empty():
			return -1
		var k: int = c[randi() % c.size()]
		used[k] = true
		return k
	var put: = func(k: int, d: Dictionary) -> void :
		for t in by[k]:
			spec[t] = d.duplicate()
		spec[by[k][0]].mate = by[k][1]
		spec[by[k][1]].mate = by[k][0]

	for g in int(p.get("lock", 0)):
		if budget < 2:
			break
		var kk: int = pick.call(0.05, 0.45)
		if kk < 0:
			break
		put.call(kk, {"kind": "key", "group": g})
		budget -= 1
		for j in maxi(1, int(p.get("lock_n", 1))):
			var lk: int = pick.call(0.0, 0.95, kk + 3)
			if lk < 0:
				break
			put.call(lk, {"kind": "lock", "group": g, "open": false})
			budget -= 1
	for i in int(p.get("chain", 0)):
		if budget < 1:
			break
		var ck: int = pick.call(0.25, 0.9, 6)
		if ck < 0:
			break
		put.call(ck, {"kind": "chain", "n": clampi(int(ck * 0.5), 3, mini(ck - 2, 9))})
		budget -= 1
	for i in int(p.get("joker", 0)):
		if budget < 1:
			break
		for k in steps:
			if by[k][0].secret or by[k][1].secret:
				used[k] = true
		var jk: int = pick.call(0.2, 0.8)
		for k in steps:
			if (by[k][0].secret or by[k][1].secret) and k != jk and not spec.has(by[k][0]):
				used.erase(k)
		if jk < 0:
			break
		put.call(jk, {"kind": "joker"})
		for t in by[jk]:
			t.face = JOKER
			t.face_spr.visible = false
		budget -= 1
	for i in int(p.get("bomb", 0)):
		if budget < 1:
			break
		var bk: int = pick.call(0.1, 0.7)
		if bk < 0:
			break
		put.call(bk, {"kind": "bomb"})
		budget -= 1
	for i in int(p.get("gift", 0)):
		if budget < 1:
			break
		var gk: int = pick.call(0.1, 0.95)
		if gk < 0:
			break
		put.call(gk, {"kind": "gift"})
		budget -= 1
	for t in spec:
		_add_icon(t)

func _add_icon(t: Tile) -> void :
	var s: Dictionary = spec[t]
	var col: = V6SpecIcon.group_color(int(s.get("group", 0)))
	var ic: = V6SpecIcon.new(s.kind, col, int(s.get("n", 0)))
	t.add_child(ic)
	icons[t] = ic

func kinds() -> Array:
	var out: = []
	for t in spec:
		var k: String = spec[t].kind
		if k == "key":
			k = "lock"
		if not out.has(k):
			out.append(k)
	return out


func takeable(t: Tile) -> bool:
	var s = spec.get(t)
	if s == null:
		return true
	if s.kind == "lock":
		return s.open
	if s.kind == "chain":
		return int(s.n) <= 0
	return true

func free_tiles() -> Array:
	return super.free_tiles().filter( func(t): return takeable(t))

func best_move() -> Tile:

	if not tray.is_empty():
		for t in free_tiles():
			if t.face == JOKER:
				return t
	return super.best_move()

func tap(t: Tile) -> void :
	if not on_board(t) or t.pending:
		return
	if is_free(t) and not takeable(t):
		t.deny()
		# 0.9: the shared deny (sound + deny haptic) — this board opts out of V7Haptics, so it must buzz itself.
		# `denied` is not emitted: «blocked» below explains the lock/chain, and a deny would break the streak
		V9Feel.tile_tap(false)
		Sfx.play("clack2", 0.7, -6)
		if icons.has(t):
			var ic: V6SpecIcon = icons[t]
			var tw: = ic.create_tween()
			tw.tween_property(ic, "rotation", 0.12, 0.05)
			tw.tween_property(ic, "rotation", -0.12, 0.08)
			tw.tween_property(ic, "rotation", 0.0, 0.06)
		special.emit("blocked", {"tile": t, "kind": spec[t].kind})
		return
	var joker_pair: Array = []
	if is_free(t) and t.ice <= 0:
		if t.face == JOKER:
			for x in tray:
				if x.face != JOKER:
					t.face = x.face
					joker_pair = [t, x]
					break
		elif not tray.any( func(x): return x.face == t.face):
			for x in tray:
				if x.face == JOKER:
					x.face = t.face
					joker_pair = [x, t]
					break
	super.tap(t)
	# 0.10 parity guard: convert the mate joker SYNCHRONOUSLY on tap (before the 0.24s _match_later delay)
	# so rapid taps or shuffle_board() during flight can never leave an orphan tile without a twin.
	if joker_pair.size() == 2 and not t.alive:
		var j: Tile = joker_pair[0]
		var o: Tile = joker_pair[1]
		if spec.has(j) and spec[j].kind == "joker" and not (spec.has(o) and spec[o].kind == "joker"):
			var mate: Tile = spec[j].get("mate")
			if mate and mate.alive and mate.face == JOKER:
				_joker_turn(mate, o)
	if is_instance_valid(t) and tray.has(t) and not t.pending and tray.size() < slots:
		unstick()

func _match(a: Tile, b: Tile) -> void :
	_pair_gone(a, b, true)
	super._match(a, b)
	unstick()



func unstick() -> bool:
	if board_count() == 0 or not super.free_tiles().filter( func(t): return takeable(t)).is_empty():
		return false
	var any: = false
	for t in spec:
		var s: Dictionary = spec[t]
		if s.kind == "lock" and not s.open:
			s.open = true
			any = true
		elif s.kind == "chain" and int(s.n) > 0:
			s.n = 0
			any = true
		if any and icons.has(t) and s.kind in ["lock", "chain"]:
			_release(t)
	if any:
		special.emit("unstick", {})
	return any

func _vanish_pair(a: Tile, b: Tile) -> void :
	_pair_gone(a, b, false)
	super._vanish_pair(a, b)


func _pair_gone(a: Tile, b: Tile, by_match: bool) -> void :
	pairs_done += 1
	var mid: = tile_layer.get_global_transform_with_canvas() * ((a.position + b.position) * 0.5)

	for pr in [[a, b], [b, a]]:
		var j: Tile = pr[0]
		var o: Tile = pr[1]
		if spec.has(j) and spec[j].kind == "joker" and not (spec.has(o) and spec[o].kind == "joker"):
			var mate: Tile = spec[j].get("mate")
			if mate and mate.alive and mate.face == JOKER:
				_joker_turn(mate, o)
	for t in [a, b]:
		if not spec.has(t):
			continue
		var s: Dictionary = spec[t]
		match s.kind:
			"key":
				if t == a or not spec.has(a) or spec[a].kind != "key":
					_open_locks(int(s.group), mid)
			"gift":
				if t == a or not spec.has(a) or spec[a].kind != "gift":
					special.emit("gift", {"pos": mid})
			"bomb":
				if by_match and (t == a or not spec.has(a) or spec[a].kind != "bomb"):
					_blast([a.home, b.home], mid)

	for t in spec:
		var s: Dictionary = spec[t]
		if s.kind == "chain" and int(s.n) > 0 and t.alive and t != a and t != b:
			s.n = int(s.n) - 1
			if icons.has(t) and is_instance_valid(icons[t]):
				if s.n <= 0:
					_release(t)
					special.emit("unchain", {"pos": tile_layer.get_global_transform_with_canvas() * t.position})
				else:
					(icons[t] as V6SpecIcon).set_count(s.n)
	for t in [a, b]:
		if spec.has(t) and spec[t].kind in ["lock", "chain"] and icons.has(t):
			_release(t)

func _release(t: Tile) -> void :
	if icons.has(t) and is_instance_valid(icons[t]):
		(icons[t] as V6SpecIcon).release()
	icons.erase(t)

func _open_locks(g: int, from: Vector2) -> void :
	var n: = 0
	for t in spec:
		var s: Dictionary = spec[t]
		if s.kind == "lock" and int(s.group) == g and not s.open:
			s.open = true
			n += 1
			if t.alive and icons.has(t):
				var ic: V6SpecIcon = icons[t]
				icons.erase(t)
				var delay: = 0.25 + 0.12 * n
				get_tree().create_timer(delay).timeout.connect( func():
					if is_instance_valid(ic):
						ic.release()
					if is_instance_valid(t):
						Fx.burst(tile_layer, t.position, "sparkle", 18, V6SpecIcon.group_color(g), 0.6)
						Fx.ring(tile_layer, t.position, V6SpecIcon.group_color(g), 1.0, 0.4)
						Sfx.play("sparkle", 1.4, -4))
	if n > 0:
		special.emit("unlock", {"pos": from, "group": g, "n": n})

func _joker_turn(j: Tile, like: Tile) -> void :
	j.face = like.face
	j.step = like.step
	spec.erase(j)
	var ic: V6SpecIcon = icons.get(j)
	icons.erase(j)
	if like.shard != "":
		# 0.8: a joker that copies a portrait-shard tile becomes that shard tile (face 100 has no tile texture)
		j.set_shard(like.shard)
	else:
		j.set_face(like.face)
	j.face_spr.visible = true
	if ic and is_instance_valid(ic):
		ic.release()
	var tw: = j.create_tween()
	tw.tween_method( func(v): j.mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.5)
	if j.alive and not tray.has(j):
		Fx.burst(tile_layer, j.position, "sparkle", 20, Color(1, 0.85, 1.0), 0.6)
	special.emit("joker", {"tile": j})


func _blast(homes: Array, mid: Vector2) -> void :
	var cand: = []
	for t in tiles:
		if not on_board(t) or t.pending or t.shard != "":
			continue
		var d: = 99999.0
		for h in homes:
			d = minf(d, (t.home - h).length())
		if d < Tile.TW * 1.75:
			cand.append([d - t.gz * 30.0, t])
	cand.sort_custom( func(x, y): return x[0] < y[0])
	var taken: = {}
	var pairs: = []
	for c in cand:
		if pairs.size() >= 3:
			break
		var t: Tile = c[1]
		if taken.has(t):
			continue
		var twin: Tile = null
		for o in tiles:
			if o != t and o.alive and not o.pending and o.step == t.step and o.face == t.face and not taken.has(o):
				twin = o
				break
		if twin == null:
			continue
		taken[t] = true
		taken[twin] = true
		pairs.append([t, twin])
	var bpos: Array = homes.map( func(h): return tile_layer.get_global_transform_with_canvas() * h)
	special.emit("blast", {"pos": mid, "at": bpos, "pairs": pairs.size()})
	for pr in pairs:
		for t in pr:
			if tray.has(t):
				tray.erase(t)
				history.erase(t)
				display.erase(t)
			t.alive = false
			t.kill_move()
			t.hint(false)
			t.z_index = 160
			var tw: Tween = t.create_tween()
			var away: Vector2 = t.position + (t.position - homes[0]).normalized() * 40.0 + Vector2(0, -50)
			tw.tween_interval(0.12)
			tw.tween_property(t, "position", away, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "rotation", randf_range(-0.6, 0.6), 0.2)
			tw.parallel().tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.2)
			tw.tween_property(t, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(t, "modulate:a", 0.0, 0.16)
			tw.tween_callback(t.hide)
		_pair_gone_quiet(pr[0], pr[1])
	if not pairs.is_empty():
		_layout_tray()
		reveal_free()
		tray_changed.emit()


func _pair_gone_quiet(a: Tile, b: Tile) -> void :
	pairs_done += 1
	for t in [a, b]:
		if not spec.has(t):
			continue
		var s: Dictionary = spec[t]
		if s.kind == "key" and t == a:
			_open_locks(int(s.group), tile_layer.get_global_transform_with_canvas() * a.home)
		if s.kind == "gift" and t == a:
			special.emit("gift", {"pos": tile_layer.get_global_transform_with_canvas() * a.home})
		if icons.has(t):
			_release(t)
	for t in spec:
		var s: Dictionary = spec[t]
		if s.kind == "chain" and int(s.n) > 0 and t.alive:
			s.n = int(s.n) - 1
			if icons.has(t):
				if s.n <= 0:
					_release(t)
				else:
					(icons[t] as V6SpecIcon).set_count(s.n)


func shuffle_board() -> void :

	var ts: = tiles.filter( func(t): return on_board(t) and t.shard == "" and t.face != JOKER)
	reassign_faces(ts)
	for i in ts.size():
		var t: Tile = ts[i]
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "scale", Vector2(0.0, 1.0), 0.12).set_delay(randf() * 0.2)
		tw.tween_property(t, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", 1.1)


func free_pairs(n: int, exclude_special: = true) -> Array:
	var by: = {}
	for t in tiles:
		if on_board(t) and not t.pending and t.shard == "" and t.face < 36 and not (exclude_special and spec.has(t)):
			by[t.step] = by.get(t.step, []) + [t]
	var out: = []
	for k in by:
		if by[k].size() == 2:
			out.append(by[k])
	out.shuffle()

	out.sort_custom( func(x, y): return int(is_free(x[0]) or is_free(x[1])) > int(is_free(y[0]) or is_free(y[1])))
	return out.slice(0, n)

func make_gift(pr: Array) -> void :
	for t in pr:
		spec[t] = {"kind": "gift", "mate": pr[1] if t == pr[0] else pr[0]}
		_add_icon(t)
		var ic: V6SpecIcon = icons[t]
		ic.scale = Vector2(0.2, 0.2)
		ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func make_gold(pr: Array) -> void :
	for t in pr:
		t.gold = true
		t.mat.set_shader_parameter("gold", 1.0)
		t.shine(0.0)
