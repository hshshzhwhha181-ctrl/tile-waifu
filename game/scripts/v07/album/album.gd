extends Node






const D: = preload("res://scripts/v07/album/album_data.gd")

var dev: = {}

func _ready() -> void :
	get_tree().node_added.connect(_on_node_added)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--album_") and "=" in a:
			var kv: = a.substr(8).split("=", true, 1)
			dev[kv[0]] = kv[1]
	if dev.has("seed"):
		_dev_seed.call_deferred(int(dev.seed))
	if dev.has("open"):
		get_tree().create_timer(float(dev.get("open_at", "1.2"))).timeout.connect( func():
			V7AlbumView.open(get_tree().current_scene, dev.open))


func _dev_seed(n: int) -> void :
	var r: = RandomNumberGenerator.new()
	r.seed = n
	var s: = st()
	for f in 36:
		var cat: = G.face_cat(f)
		var v: = 0
		match cat:
			0: v = r.randi_range(30, 60)
			1: v = r.randi_range(1, 25)
			2: v = r.randi_range(0, 14) if f % 3 else 0
			3: v = r.randi_range(1, 12)
			_: v = r.randi_range(0, 3) if f % 2 else 0
		s.faces[str(f)] = v
	for id in ["s_lemon", "s_night"]:
		G.S.owned[id] = true
	s.claimed["suit0"] = true
	s.new = [3, 17, 24]


func _dev_autoplay(b: TrayBoard) -> void :
	while is_instance_valid(b) and b.is_inside_tree() and not b.input_on:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var guard: = 0
	while is_instance_valid(b) and b.is_inside_tree() and b.board_count() > 0 and guard < 600:
		guard += 1
		var t: Tile = b.solver_move()
		if t:
			b.tap(t)
		await get_tree().create_timer(float(dev.get("tap", "0.22"))).timeout

func st() -> Dictionary:
	if not G.S.has("v7_album") or not (G.S.v7_album is Dictionary):
		G.S["v7_album"] = {}
	var s: Dictionary = G.S.v7_album
	for k in ["faces", "claimed"]:
		if not s.has(k) or not (s[k] is Dictionary):
			s[k] = {}
	for k in ["photos", "new"]:
		if not s.has(k) or not (s[k] is Array):
			s[k] = []
	return s


func _on_node_added(n: Node) -> void :
	if n is TrayBoard:
		n.matched.connect(_on_matched.bind(n))
		_snap.call_deferred(n, 0)


func _snap(b, tries: int) -> void :
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	if b.tiles.is_empty():
		if tries < 3:
			get_tree().process_frame.connect(_snap.bind(b, tries + 1), CONNECT_ONE_SHOT)
		return
	var faces: = []
	var gold: = []
	for t in b.tiles:
		faces.append(t.face)
		gold.append(t.gold)
	b.set_meta("v7_rec", {"faces": faces, "gold": gold, "log": [], "gone": {}, "t0": G.time})
	if dev.get("autoplay", "") == "1" and b.get_parent() is Control:
		_dev_autoplay(b)

func _on_matched(_mid: Vector2, combo: int, gold: bool, _shard: String, b: TrayBoard) -> void :
	if not is_instance_valid(b):
		return
	var f: int = b.last_face
	if f >= 0 and f < 36:
		_count(f)
	if not b.has_meta("v7_rec"):
		return
	var rec: Dictionary = b.get_meta("v7_rec")
	var gone: Dictionary = rec.gone
	var cands: = []
	for i in b.tiles.size():
		var t: Tile = b.tiles[i]
		if t.alive or gone.has(i) or t.face != f or b.tray.has(t):
			continue
		cands.append(i)
	cands.sort_custom( func(x, y): return int(b.tiles[x].pending) > int(b.tiles[y].pending))
	var pair: = cands.slice(0, 2)
	for i in pair:
		gone[i] = true
	rec.log.append({"i": pair, "t": G.time - float(rec.t0), "c": combo, "g": gold})

func _count(f: int) -> void :
	var s: = st()
	var k: = str(f)
	var before: = int(s.faces.get(k, 0))
	s.faces[k] = before + 1
	if D.tier_of(before + 1) > D.tier_of(before) and not s.new.any( func(x): return int(x) == f):
		s.new.append(f)


func take_new() -> Array:
	var s: = st()
	var r: Array = s.new.map( func(x): return int(x))
	s.new.clear()
	return r


func face_pairs(f: int) -> int:
	return int(st().faces.get(str(f), 0))

func face_tier(f: int) -> int:
	return D.tier_of(face_pairs(f))


func suit_tier(i: int) -> int:
	var lo: = 3
	for f in D.suit_faces(D.SUITS[i].cat):
		lo = mini(lo, face_tier(f))
	return lo

func suit_count(i: int) -> Array:
	var faces: = D.suit_faces(D.SUITS[i].cat)
	var n: = 0
	for f in faces:
		if face_tier(f) >= 1:
			n += 1
	return [n, faces.size()]

func skin_set_count(i: int) -> Array:
	var items: Array = D.SKIN_SETS[i].items
	return [items.filter( func(x): return G.owns(x)).size(), items.size()]

func table_unlocked(id: String) -> bool:
	for tb in D.TABLES:
		if tb.id != id:
			continue
		if tb.has("item") and G.owns(tb.item):
			return true
		var u: String = tb.unlock
		if u == "free":
			return true
		if u.begins_with("boss:"):
			var w: = int(u.substr(5))
			for i in G.LEVELS.size():
				var lv: Dictionary = G.LEVELS[i]
				if int(lv.get("loc", -1)) == w and lv.get("boss", false) and G.level_stars(i) > 0:
					return true
		return false
	return false

func tables_count() -> int:
	return D.TABLES.filter( func(t): return table_unlocked(t.id)).size()

func suits_collected() -> int:
	var n: = 0
	for i in D.SUITS.size():
		if suit_tier(i) >= 1:
			n += 1
	return n


func sets() -> Array:
	var r: = []
	var s: = st()
	for i in D.SUITS.size():
		var su: Dictionary = D.SUITS[i]
		r.append({"id": su.id, "name": su.name, "bonus": su.bonus, "key": su.key, "gems": su.gems, 
			"ready": suit_tier(i) >= 1, "claimed": s.claimed.has(su.id)})
		r.append({"id": su.id + "_gold", "name": su.name + " · золото", "bonus": "Золотая рамка набора", "key": "", "gems": su.gold_gems, 
			"ready": suit_tier(i) >= 3, "claimed": s.claimed.has(su.id + "_gold")})
	for i in D.SKIN_SETS.size():
		var ss: Dictionary = D.SKIN_SETS[i]
		var c: = skin_set_count(i)
		r.append({"id": ss.id, "name": ss.name, "bonus": ss.bonus, "key": ss.key, "gems": ss.gems, 
			"ready": c[0] >= c[1], "claimed": s.claimed.has(ss.id)})
	for ts in D.TABLE_SETS:
		r.append({"id": ts.id, "name": ts.name, "bonus": ts.bonus, "key": ts.key, "gems": ts.gems, 
			"ready": tables_count() >= int(ts.need), "claimed": s.claimed.has(ts.id)})
	return r

func claimable() -> int:
	return sets().filter( func(x): return x.ready and not x.claimed).size()

func claim(id: String) -> int:
	for x in sets():
		if x.id == id and x.ready and not x.claimed:
			st().claimed[id] = true
			V10Money.grant({"gems": int(x.gems)}, "album")
			G.save()
			return int(x.gems)
	return 0


func active_keys() -> Array:
	return sets().filter( func(x): return x.claimed and x.key != "").map( func(x): return x.key)


func apply_bonuses(p) -> void :
	for k in active_keys():
		match k:
			"hint": p.hint_n += 1
			"shuffle": p.shuffle_n += 1
			"undo": p.undo_n += 1
			"gems": p.gem_bonus += 0.1
			"gold": p.gold_mult += 1
			"combo":
				if p.board:
					p.board.combo_window += 0.5

func bonus_lines() -> Array:
	return sets().filter( func(x): return x.claimed and x.key != "").map( func(x): return "%s: %s" % [x.name, x.bonus])



func table_for(bg: String) -> String:
	var id: = String(st().get("table", ""))
	if id != "" and table_unlocked(id):
		return id
	return bg

func set_table(id: String) -> void :
	st()["table"] = id
	G.save()

func frame_unlocked(fr: Dictionary) -> bool:
	var u: String = fr.unlock
	if u == "free":
		return true
	if u.begins_with("suits:"):
		return suits_collected() >= int(u.substr(6))
	if u.begins_with("tables:"):
		return tables_count() >= int(u.substr(7))
	return false

func frame_hint(fr: Dictionary) -> String:
	var u: String = fr.unlock
	if u.begins_with("suits:"):
		return "Собери %s масти в альбоме" % u.substr(6)
	if u.begins_with("tables:"):
		return "Открой %s стола" % u.substr(7)
	return ""


func gold_frames() -> Array:
	var r: = []
	for i in D.SUITS.size():
		if st().claimed.has(D.SUITS[i].id + "_gold"):
			r.append({"id": "gold_" + D.SUITS[i].id, "name": "Золото: " + D.SUITS[i].name, "trim": Color("ffd86b"), "deep": Color("2a1c06"), "unlock": "free"})
	return r


func add_photo(path: String) -> void :
	var s: = st()
	s.photos.push_front(path)
	while s.photos.size() > 40:
		s.photos.pop_back()
	G.save()

func photos() -> Array:
	return st().photos.filter( func(p): return FileAccess.file_exists(p))
