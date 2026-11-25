extends Node

# --salon_selftest=1 (spec §Р1 «Самотест», §Р2 «Самотест») — run by salon_runner.gd, or by the integrator's
# --v10_selftest=all via V10Registry (README). Prints «SALON_SELFTEST ok/total» and every failed check.

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена"]
const UI_BANNED: = ["гарант", "пити", "pity", "гача", "ролл", "крутка", "фивер", "ивент", "ульта", "донат", "шаффл"]

const MIN_CHECKS: = 290

var ok: = 0
var total: = 0
var fails: = []


func check(cond: bool, name: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(name)
		print("  FAIL ", name)


func fixture(stars: int) -> Dictionary:
	var S: Dictionary = {"gems": 0, "stars": {}, "aff": {"mc": 0, "rin": 0}, "unlocked": 1}
	for i in stars / 3:
		S.stars[str(i)] = 3
	if stars % 3 > 0:
		S.stars[str(stars / 3)] = stars % 3
	return S


func use(S: Dictionary) -> Dictionary:
	V10Salon.state_override = S
	V10Salon.reset_cache()
	V10Salon.ensure(S)
	return S


func run() -> bool:
	V10Salon.grant_cb = Callable()
	V10Salon.bond_cb = Callable()
	V10Salon.letter_cb = Callable()
	V10Salon.season_cb = Callable()
	_data()
	_bank()
	_restore()
	_finish()
	_chest_scene_lobby()
	_goal_hub()
	_lines()
	_contract_grep()
	await _scene_nodes()
	await _screen_builds()
	await _ux()
	V10Salon.state_override = null
	# a script error aborts a section silently: the count of checks must be complete
	check(total >= MIN_CHECKS, "all sections ran (%d checks, want ≥ %d)" % [total, MIN_CHECKS])
	print("SALON_SELFTEST %d/%d" % [ok, total])
	if not fails.is_empty():
		print("SALON_SELFTEST FAILS ", fails)
	return fails.is_empty()


func _data() -> void:
	check(V10SalonData.zone_total("z1") == 25, "z1 sum 25")
	check(V10SalonData.zone_total("z2") == 40, "z2 sum 40")
	check(V10SalonData.zone_total("z3") == 55, "z3 sum 55")
	for z in V10SalonData.ZONES:
		for f in ["_broken.webp", "_done.webp"]:
			check(ResourceLoader.exists(V10SalonData.ART + z.id + f), "art " + z.id + f)
		check(ResourceLoader.exists(V10SalonData.ART + str(z.lobby)), "lobby art " + z.id)
		check(ResourceLoader.exists(V10SalonData.ART + str(z.scene_bg)), "scene art " + z.id)
		check(V10SalonData.CHESTS.has(z.chest), "chest def " + z.id)
		var ids: = {}
		var layers: = {}
		for t in z.tasks:
			check(not ids.has(t.id), "unique task id %s/%s" % [z.id, t.id])
			ids[t.id] = true
			check(not layers.has(int(t.layer)), "unique layer %s/%s" % [z.id, t.id])
			layers[int(t.layer)] = true
			var a: Vector2 = t.anchor
			check(a.x >= 0 and a.x <= 1 and a.y >= 0 and a.y <= 1, "anchor in art %s/%s" % [z.id, t.id])
			for r in t.rects:
				check(r[0] >= 0 and r[1] >= 0 and r[0] + r[2] <= 1.001 and r[1] + r[3] <= 1.001 and r[2] > 0 and r[3] > 0, "rect in art %s/%s" % [z.id, t.id])
	check(V10SalonData.jade_cost(3) == 2 and V10SalonData.jade_cost(10) == 5 and V10SalonData.jade_cost(7) == 4, "jade = ceil(½)")


func _bank() -> void:
	var S: = use(fixture(40))
	check(V10Salon.stars_total() == 40, "total 40")
	check(V10Salon.bank() == 40, "migration 40★ → bank 40")
	check(V10Salon.intro_text().contains("40"), "intro mentions 40★")
	S[V10Salon.KEY].spent = 12
	check(V10Salon.bank() == 28, "bank = total − spent")
	# 2★ → 3★ on a level gives +1
	S.stars["99"] = 2
	V10Salon.notify_stars(2)
	var b: = V10Salon.bank()
	S.stars["99"] = 3
	V10Salon.notify_stars(1)
	check(V10Salon.bank() == b + 1, "2★→3★ gives +1")
	# a replay with fewer stars changes nothing (best result only)
	check(V10Salon.stars_total() == 43, "best stars only")
	# spent > total is repaired
	S[V10Salon.KEY].spent = 999
	check(V10Salon.repair() and int(S[V10Salon.KEY].spent) == V10Salon.stars_total(), "spent>total repaired")
	check(V10Salon.bank() == 0, "bank 0 after repair")
	# idempotent ensure
	var before: = JSON.stringify(S[V10Salon.KEY])
	V10Salon.ensure(S)
	check(JSON.stringify(S[V10Salon.KEY]) == before, "ensure idempotent")


func _restore() -> void:
	var S: = use(fixture(2))
	var r: = V10Salon.restore("z1", "t1")
	check(not r.ok and r.reason == "stars" and int(S[V10Salon.KEY].spent) == 0 and not V10Salon.restored("z1", "t1"), "restore without stars does nothing")
	check(V10Salon.zone_state("z1") == "ruined", "state ruined")
	check(V10Salon.zone_state("z2") == "locked", "z2 locked")
	S = use(fixture(25))
	check(V10Salon.restore("z2", "t1").reason == "locked", "locked zone refuses")
	r = V10Salon.restore("z1", "t1")
	check(r.ok and V10Salon.bank() == 22 and V10Salon.task_variant("z1", "t1") == "lacquer", "restore spends and lacquers")
	check(V10Salon.restore("z1", "t1").reason == "done", "no double restore")
	check(V10Salon.zone_state("z1") == "restoring", "state restoring")
	for tid in ["t2", "t3", "t4"]:
		V10Salon.restore("z1", tid)
	r = V10Salon.restore("z1", "t5")
	check(r.ok and r.zone_done and bool(V10Salon.zone_rec("z1").done), "last task finishes zone")
	check(V10Salon.bank() == 0, "25★ spent exactly")
	check(V10Salon.zone_state("z1") == "restored", "state restored")
	check(V10Salon.zone_open("z2") and V10Salon.zone_state("z2") == "ruined", "z2 opens after z1")
	check(V10Salon.current_zone() == "z2", "current zone moves on")


func _finish() -> void:
	var S: = use(fixture(25 + 30))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	var b: = V10Salon.bank()
	check(V10Salon.set_finish("z1", "t5", "jade").paid == 4 and V10Salon.bank() == b - 4, "jade on 7★ costs 4")
	check(V10Salon.set_finish("z1", "t5", "lacquer").ok and V10Salon.task_variant("z1", "t5") == "lacquer", "back to lacquer free")
	b = V10Salon.bank()
	check(V10Salon.set_finish("z1", "t5", "jade").paid == 0 and V10Salon.bank() == b, "jade again free once paid")
	var sr: = V10Salon.set_finish("z1", "t1", "season")
	check(not sr.ok and sr.reason == "season" and V10Salon.task_variant("z1", "t1") == "lacquer", "season closed without pass")
	V10Salon.season_cb = func(): return true
	check(V10Salon.set_finish("z1", "t1", "season").ok, "season with pass")
	V10Salon.season_cb = Callable()
	check(V10Salon.set_finish("z2", "t1", "jade").reason == "not_restored", "finish needs restore")
	# all jade → «Нефрит»
	S[V10Salon.KEY].spent = 0
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.set_finish("z1", t.id, "jade")
	check(V10Salon.zone_state("z1") == "jade", "all jade → state jade")
	var poor: = use(fixture(25))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	var jr: = V10Salon.set_finish("z1", "t1", "jade")
	check(not jr.ok and jr.reason == "stars" and not V10Salon.jade_paid("z1", "t1"), "jade without stars refused")


func _chest_scene_lobby() -> void:
	var S: = use(fixture(25))
	check(V10Salon.claim_chest("z1").is_empty(), "no chest before done")
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	var r: = V10Salon.claim_chest("z1")
	check(int(r.get("gems", 0)) == 100 and int(S.gems) == 100 and int(S[V10Salon.KEY].inv.get("hint", 0)) == 1, "chest z1 pays 100 + hint")
	check(V10Salon.claim_chest("z1").is_empty() and int(S.gems) == 100, "chest once")
	var got: = []
	V10Salon.grant_cb = func(rw, src): got.append([rw, src])
	S = use(fixture(25 + 40))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	V10Salon.claim_chest("z1")
	check(got.size() == 1 and got[0][1] == "salon_z1", "grant hook used")
	V10Salon.grant_cb = Callable()
	# scene: +20 once (hard source) and a letter
	var bonds: = []
	var letters: = []
	V10Salon.bond_cb = func(h, n, src): bonds.append([h, n, src])
	V10Salon.letter_cb = func(h, k): letters.append([h, k])
	check(not V10Salon.mark_scene_seen("z2"), "no scene before done")
	check(V10Salon.mark_scene_seen("z1") and bonds.size() == 1 and bonds[0] == ["mc", 20, "salon_scene"], "+20 on first scene")
	check(not V10Salon.mark_scene_seen("z1") and bonds.size() == 1, "+20 only once")
	check(letters.size() == 1 and letters[0][0] == "mc", "letter queued")
	V10Salon.bond_cb = Callable()
	V10Salon.letter_cb = Callable()
	# no V10Bond yet → queued for the integrator (never G.add_aff directly)
	S = use(fixture(25))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	V10Salon.mark_scene_seen("z1")
	var pend = S[V10Salon.KEY].get("bond_pending", [])
	check(V10Salon.global_class("V10Bond") != null or (pend is Array and pend.size() == 1), "bond queued without V10Bond")
	# lobby
	check(not V10Salon.set_lobby("z2"), "lobby only from done zone")
	check(V10Salon.set_lobby("z1") and V10Salon.lobby_texture().ends_with("z1_lobby.webp"), "lobby set")


func _goal_hub() -> void:
	use(fixture(2))
	var g: = V10Salon.next_goal()
	check(g.tid == "t1" and g.cost == 3 and g.need == 1, "next goal cheapest (Вывеска 3, need 1)")
	check(not V10Salon.can_restore_any(), "nothing restorable at 2★")
	var h: = V10Salon.hub_info()
	check(h.label == "Зона I · 0/5" and not h.dot, "hub info fresh (no raw zone id)")
	use(fixture(3))
	check(V10Salon.can_restore_any() and V10Salon.hub_info().dot, "dot at 3★")
	var S: = use(fixture(120))
	for zid in ["z1", "z2", "z3"]:
		for t in V10SalonData.zone(zid).tasks:
			V10Salon.restore(zid, t.id)
	check(V10Salon.all_released_done() and V10Salon.next_goal().is_empty(), "all zones done → no goal")
	check(V10Salon.hub_info().label == "Салон восстановлен", "hub all done")
	check(V10Salon.bank() == 0, "120★ = 25+40+55")


func _lines() -> void:
	var S: = use(fixture(0))
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	var prev: = ""
	var rep: = false
	for i in 40:
		var l: = V10Salon.next_line("rin", rng)
		if l == prev:
			rep = true
		prev = l
	check(not rep, "no line twice in a row")
	check(V10SalonData.LINES.rin[0].has(prev), "tier 0 at aff 0")
	S.aff.rin = 950
	check(V10SalonData.LINES.rin[3].has(V10Salon.next_line("rin", rng)), "tier 3 at level 10")
	S.aff.rin = 520
	check(V10SalonData.LINES.rin[2].has(V10Salon.next_line("rin", rng)), "tier 2 at level 6")
	for h in V10SalonData.LINES:
		check(V10SalonData.LINES[h].size() == 4, "4 tiers " + h)
		for tier in V10SalonData.LINES[h]:
			check(tier.size() == 3, "3 lines per tier " + h)
	# every visible string of the lane passes the stop-words (V10Lint.BANNED + UX jargon)
	var texts: = []
	for z in V10SalonData.ZONES:
		texts.append_array([z.name, z.scene, z.intro, z.finale_line])
		for t in z.tasks:
			texts.append(t.name)
	for h in V10SalonData.LINES:
		for tier in V10SalonData.LINES[h]:
			texts.append_array(tier)
	texts.append_array([V10SalonData.INTRO_NEW, V10SalonData.INTRO_OLD, V10SalonData.HELP])
	for e in V10SalonData.GLOSSARY:
		texts.append_array([e.name, e.why, e.how])
		# V10Glossary limits (NAME_MAX 26, WHY_MAX 74, HOW_MAX 92) so the entries drop into the «Словарь» as is
		check(e.name.length() <= 26 and e.why.length() <= 74 and e.how.length() <= 92 and e.has("cat"), "glossary entry fits V10Glossary: " + e.id)
	for h in V10SalonData.NEUTRAL:
		texts.append(V10SalonData.NEUTRAL[h])
	for f in ["salon_screen.gd", "salon_sheet.gd", "salon_finale.gd", "zone_scene.gd", "photo_mode.gd", "hub_card.gd", "win_bar.gd"]:
		var src: = FileAccess.get_file_as_string("res://scripts/v10/salon/" + f)
		var re: = RegEx.create_from_string("\"([^\"\\n]*[А-Яа-яЁё][^\"\\n]*)\"")
		for m in re.search_all(src):
			texts.append(m.get_string(1))
	var bad: = []
	for s in texts:
		var low: = str(s).to_lower()
		for w in BANNED + UI_BANNED:
			# stems match at the start of a word («сцена» is not «цена»)
			var at: = low.find(w)
			while at >= 0:
				var pch: = low.substr(at - 1, 1) if at > 0 else " "
				if not (pch.to_upper() != pch.to_lower()):
					bad.append("%s ← %s" % [w, s])
					break
				at = low.find(w, at + 1)
	check(bad.is_empty(), "stop-words clean %s" % [bad])


func _contract_grep() -> void:
	# §2.4/§2.5: no direct clock or affinity calls outside meta/bond
	var hits: = []
	var d: = DirAccess.open("res://scripts/v10/salon")
	for f in d.get_files():
		if not f.ends_with(".gd") or f == "salon_selftest.gd":
			continue
		var src: = FileAccess.get_file_as_string("res://scripts/v10/salon/" + f)
		for pat in ["Time.get_unix_time_from_system", "Time.get_date_string_from_system", "G.add_aff", "S.gems +="]:
			if src.contains(pat):
				hits.append(f + ": " + pat)
	check(hits.is_empty(), "contract grep %s" % [hits])


func _scene_nodes() -> void:
	var S: = use(fixture(120))
	for zid in ["z1", "z2", "z3"]:
		for t in V10SalonData.zone(zid).tasks:
			V10Salon.restore(zid, t.id)
	var tree: = get_tree()
	for fx in ["full", "min"]:
		G.S["fx_level"] = fx
		for zid in ["z1", "z2", "z3"]:
			var sc: = Control.new()
			sc.set_script(load("res://scripts/v10/salon/zone_scene.gd"))
			sc.size = Vector2(720, 1280)
			tree.root.add_child(sc)
			sc.build(null, {"zone": zid})
			await tree.process_frame
			var n: Dictionary = sc.live_counts()
			var hero: String = V10SalonData.zone(zid).hero
			var want_rig: = V10SalonHeroine.has_rig(hero) != ""
			check((n.rig > 0) == want_rig and (want_rig or sc.scene_mat != null or sc.heroine != null), "scene %s has rig or still (%s)" % [zid, fx])
			check(n.video == 0, "no video player at fx %s (%s)" % [fx, zid])
			sc.queue_free()
			await tree.process_frame
			await tree.process_frame
			check(not is_instance_valid(sc), "scene freed " + zid)
	# after leaving: no live rig anywhere under root (except what other code made)
	var left: = 0
	var stack: Array = [tree.root]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is V10LiveRig or c is VideoStreamPlayer:
			left += 1
		stack.append_array(c.get_children())
	check(left == 0, "no rig/video left after exit")
	G.S["fx_level"] = "full"
	# first view gives +20 through the screen too
	S = use(fixture(25))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	var bonds: = []
	V10Salon.bond_cb = func(h, n2, src): bonds.append(n2)
	var sc2: = Control.new()
	sc2.set_script(load("res://scripts/v10/salon/zone_scene.gd"))
	sc2.size = Vector2(720, 1280)
	tree.root.add_child(sc2)
	sc2.build(null, {"zone": "z1"})
	check(sc2.first_view and bonds == [20], "scene screen +20 first view")
	sc2.queue_free()
	V10Salon.bond_cb = Callable()
	await tree.process_frame


func _screen_builds() -> void:
	# the salon screen builds at phone, tall phone and tablet sizes; zones fit the width; bottom never overlaps
	var tree: = get_tree()
	for sz in [Vector2(720, 1280), Vector2(720, 1600), Vector2(960, 1280)]:
		use(fixture(30))
		var sc: = Control.new()
		sc.set_script(load("res://scripts/v10/salon/salon_screen.gd"))
		sc.size = sz
		tree.root.add_child(sc)
		sc.build(null, {})
		await tree.process_frame
		await tree.process_frame
		check(sc.zones.has("z1"), "salon builds %s" % sz)
		var zn: V10SalonZone = sc.zones["z1"]
		check(zn.size.x <= sz.x and zn.size.y == V10SalonZone.height_for(zn.size.x), "zone fits %s" % sz)
		check(sc.play_btn.position.y + sc.play_btn.size.y <= sz.y - 16, "play button on screen %s" % sz)
		check(sc.play_btn.size.y >= 80 and sc.bank_box.size.y >= 80, "touch ≥ 80 %s" % sz)
		var locked_n: = 0
		for zid in sc.zones:
			if V10Salon.zone_state(zid) == "locked":
				locked_n += 1
		check(locked_n <= 1, "≤ one locked teaser %s" % sz)
		sc.queue_free()
		await tree.process_frame


# ── UX_RULES §10 checks the future --ux_selftest will make (П-1, П-2, П-6, В-6, В-7, С-8, Г-1, §8.2) ────────────

func _all(root: Node) -> Array:
	var out: = []
	var stack: = [root]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		out.append(c)
		stack.append_array(c.get_children())
	return out


# is this control really visible: in the tree, on screen and — for map content — not under the header / bottom bands
func _seen(c: Control, sc: Control) -> bool:
	if not c.is_visible_in_tree() or c.modulate.a < 0.05:
		return false
	var r: = c.get_global_rect()
	var mid: = r.get_center()
	if not Rect2(Vector2.ZERO, sc.size).has_point(mid):
		return false
	var scroll = sc.get("scroll")
	if scroll is ScrollContainer and (scroll as ScrollContainer).is_ancestor_of(c):
		return mid.y > float(sc.get("_header_h")) and mid.y < sc.size.y - float(sc.get("_bottom_h"))
	return true


func _roles(layer: Node, sc: Control) -> Dictionary:
	var n: = {"primary": 0, "secondary": 0, "tertiary": 0, "tappable": 0}
	for c in _all(layer):
		if not (c is Control) or not _seen(c, sc):
			continue
		var r: = str(c.get_meta("ux_role", ""))
		if n.has(r):
			n[r] += 1
		if c is V10SalonButton or c is V10SalonTag or c is V10SalonHub:
			n.tappable += 1
	return n


# font sizes of what is on screen (Labels, buttons, tags); her voice line (Voice 30 italic) is not interface
func _sizes(layer: Node, sc: Control) -> Array:
	var sz: = {}
	for c in _all(layer):
		if not (c is Control) or not _seen(c, sc):
			continue
		if c is Label and (c as Label).text.strip_edges() != "" and (c as Label).label_settings:
			var ls: LabelSettings = (c as Label).label_settings
			if ls.font_size == 30:
				continue
			sz[ls.font_size] = true
		elif c is V10SalonButton:
			var b: V10SalonButton = c
			if b.text != "" or b.kind in ["game", "second", "chip"]:
				sz[{"game": 32, "second": 22, "chip": 22, "quiet": 18}.get(b.kind, 18)] = true
		elif c is V10SalonTag:
			sz[V10SalonTag.FS] = true
	var keys: = sz.keys()
	keys.sort()
	return keys


func _hits_ok(layer: Node, sc: Control) -> Array:
	var bad: = []
	for c in _all(layer):
		if (c is V10SalonButton or c is V10SalonTag) and _seen(c, sc):
			var s2: Vector2 = (c as Control).size
			if s2.x < 80.0 or s2.y < 80.0:
				bad.append("%s %s" % [c.get("text") if c is V10SalonButton else c.get("title"), s2])
	return bad


func _ux() -> void:
	var tree: = get_tree()
	for sz in [Vector2(720, 1280), Vector2(720, 1600)]:
		var tag: = "%dx%d" % [int(sz.x), int(sz.y)]
		# map states: fresh with 3★ (restorable), short (2★), z2 open with plenty, all done
		for st in [["fresh3", 3, 0], ["short", 2, 0], ["z2", 68, 1], ["z3", 120, 2], ["all", 120, 3]]:
			var S: = use(fixture(int(st[1])))
			for k in int(st[2]):
				var zid: String = ["z1", "z2", "z3"][k]
				for t in V10SalonData.zone(zid).tasks:
					V10Salon.restore(zid, t.id)
					V10Salon.zone_rec(zid).chest = true
			S[V10Salon.KEY].intro = true
			var sc: = Control.new()
			sc.set_script(load("res://scripts/v10/salon/salon_screen.gd"))
			sc.size = sz
			tree.root.add_child(sc)
			sc.build(null, {})
			# after the «Вдох» entrance (≤ 0.4 s)
			await tree.create_timer(0.5).timeout
			var n: = _roles(sc, sc)
			var nm: = "%s %s" % [st[0], tag]
			check(n.primary == 1 and n.secondary <= 2 and n.tertiary <= 2, "П-1 map roles %s %s" % [nm, n])
			check(n.tappable <= 10, "П-2 map tappable ≤ 10 %s (%d)" % [nm, n.tappable])
			var fs: = _sizes(sc, sc)
			check(fs.size() <= 4, "П-2 map font sizes ≤ 4 %s %s" % [nm, fs])
			var hb: = _hits_ok(sc, sc)
			check(hb.is_empty(), "В-6 hit zones ≥ 80 %s %s" % [nm, hb])
			var g: = V10Salon.next_goal()
			var want_restore: bool = not g.is_empty() and int(g.need) == 0
			check((sc.play_btn.text == "Восстановить" and sc.play_btn.stars == int(g.get("cost", -1))) if want_restore else sc.play_btn.text.begins_with("Играть"),
				"§3.4 main action = Восстановить when affordable, else Играть %s («%s»)" % [nm, sc.play_btn.text])
			check(sc.play_btn.position.y + sc.play_btn.size.y > sz.y * 2.0 / 3.0, "В-6 main button in the bottom third %s" % nm)
			# the interface is still: after the one-shot hop the tags hang still (no endless hop / pulse / sway)
			await tree.create_timer(0.6).timeout
			var moving: = 0
			for zid in sc.zones:
				for k2 in sc.zones[zid].tags:
					var tg: V10SalonTag = sc.zones[zid].tags[k2]
					if tg._hop != 0.0 or tg.rotation != 0.0 or tg._hop_t >= 0.0:
						moving += 1
			check(moving == 0, "В-7 tags at rest %s (%d moving)" % [nm, moving])
			# the task sheet: one sheet, its own hierarchy, its main button fully on screen
			if st[0] in ["fresh3", "short", "all"]:
				var zid2: = "z1"
				var tid2: = "t1"
				sc._on_task(zid2, tid2)
				await tree.create_timer(0.45).timeout
				var sh: V10SalonSheet = sc.sheet
				var m: = _roles(sh, sc)
				check(m.primary == 1 and m.secondary <= 2 and m.tertiary <= 2, "П-1 sheet roles %s %s" % [nm, m])
				check(_sizes(sh, sc).size() <= 4, "П-2 sheet font sizes %s %s" % [nm, _sizes(sh, sc)])
				var mb: Control = sh.play_btn if sh.play_btn else sh.main_btn
				check(mb.get_global_rect().end.y <= sz.y - 24.0, "sheet main button on screen %s (%.0f)" % [nm, mb.get_global_rect().end.y])
				check(_hits_ok(sh, sc).is_empty(), "В-6 sheet hit zones %s %s" % [nm, _hits_ok(sh, sc)])
				sc._on_task(zid2, tid2)
				var sheets: = 0
				for c in sc.get_children():
					if c is V10SalonSheet:
						sheets += 1
				check(sheets == 1, "П-6 no sheet over a sheet %s" % nm)
				sh.close(true)
				await tree.create_timer(0.3).timeout
			sc.queue_free()
			await tree.process_frame
		# the finale ceremony layer
		use(fixture(25))
		for t in V10SalonData.zone("z1").tasks:
			V10Salon.restore("z1", t.id)
		var sc2: = Control.new()
		sc2.set_script(load("res://scripts/v10/salon/salon_screen.gd"))
		sc2.size = sz
		tree.root.add_child(sc2)
		sc2.build(null, {})
		await tree.process_frame
		var fin: = V10SalonFinale.open(sc2, "z3", V10SalonData.CHESTS.c3)
		sc2.finale = fin
		await tree.create_timer(4.0).timeout
		var fr: = _roles(fin, sc2)
		check(fr.primary == 1 and fr.secondary <= 2 and fr.tertiary <= 2, "П-1 finale roles %s %s" % [tag, fr])
		check(_sizes(fin, sc2).size() <= 4, "П-2 finale font sizes %s %s" % [tag, _sizes(fin, sc2)])
		check(_hits_ok(fin, sc2).is_empty(), "В-6 finale hit zones %s" % tag)
		var floor_ok: = false
		for c in fin.get_children():
			if c is ColorRect and (c as ColorRect).position.y > 0 and (c as ColorRect).get_global_rect().end.y >= sz.y:
				floor_ok = true
		check(floor_ok, "finale floor reaches the screen edge %s" % tag)
		sc2._back()
		await tree.create_timer(0.4).timeout
		check(not is_instance_valid(fin), "«назад» closes the finale first %s" % tag)
		sc2.queue_free()
		await tree.process_frame
		# the scene: «Реплика» main, «Фон лобби» and «Фото» secondary, «назад» quiet
		use(fixture(120))
		for zid in ["z1", "z2"]:
			for t in V10SalonData.zone(zid).tasks:
				V10Salon.restore(zid, t.id)
		for zid in ["z1", "z2"]:
			var sn: = Control.new()
			sn.set_script(load("res://scripts/v10/salon/zone_scene.gd"))
			sn.size = sz
			tree.root.add_child(sn)
			sn.build(null, {"zone": zid})
			await tree.create_timer(0.5).timeout
			var r3: = _roles(sn.ui, sn)
			check(r3.primary == 1 and r3.secondary == 2 and r3.tertiary == 1, "П-1 scene roles %s %s %s" % [zid, tag, r3])
			check(_sizes(sn, sn).size() <= 3, "П-2 scene font sizes %s %s %s" % [zid, tag, _sizes(sn, sn)])
			check(_hits_ok(sn.ui, sn).is_empty(), "В-6 scene hit zones %s %s" % [zid, tag])
			sn.dev_act("photo")
			await tree.create_timer(0.5).timeout
			var pr: = _roles(sn.photo, sn)
			check(pr.primary == 1 and pr.secondary <= 2 and pr.tertiary <= 2, "П-1 photo roles %s %s %s" % [zid, tag, pr])
			check(_hits_ok(sn.photo, sn).is_empty(), "В-6 photo hit zones %s %s" % [zid, tag])
			sn.queue_free()
			await tree.process_frame
	# a tap on her torso / outfit is only a neutral glance (UX §8.2); head gives a line of her tier
	use(fixture(0))
	check(V10Salon.tap_line("rin", "outfit") == V10SalonData.NEUTRAL.rin and V10Salon.tap_line("mc", "bg") == V10SalonData.NEUTRAL.mc, "§8.2 outfit / bg → neutral")
	check(V10SalonData.LINES.rin[0].has(V10Salon.tap_line("rin", "head")), "head → her line")
	# hub card: one still dot, no endless redraw (badges never pulse)
	use(fixture(3))
	var hub: = V10SalonHub.make(Rect2(0, 0, 656, 168), Callable())
	tree.root.add_child(hub)
	await tree.process_frame
	check(bool(hub.info.dot) and not hub.is_processing(), "С-8 hub dot still (no pulse)")
	hub.queue_free()
	# particles: one burst ≤ 18 (UX §8.5)
	var host: = Node2D.new()
	tree.root.add_child(host)
	V10SalonFx.sparkle(host, Rect2(0, 0, 100, 100), Color.WHITE, 40)
	V10SalonFx.dust(host, Vector2.ZERO, 50.0)
	var pmax: = 0
	for c in host.get_children():
		if c is CPUParticles2D:
			pmax = maxi(pmax, (c as CPUParticles2D).amount)
	check(pmax > 0 and pmax <= V10SalonFx.MAX_PARTICLES, "particles ≤ 18 per burst (%d)" % pmax)
	host.queue_free()
	await _history_loop()


# «назад» from a zone scene must return to the map WITHOUT remembering the scene: then the map's «назад» goes home
# (a stub with main.gd's go/back history rules)
class MainStub extends Node:
	var history: = []
	var screen_id: = ""
	var screen: Control
	var cur_args: = {}
	var went_home: = false

	func go(id: String, args: = {}, _animate: = true, remember: = true) -> void:
		if remember and screen_id != "" and screen_id != id:
			history.append([screen_id, cur_args])
		cur_args = args
		if screen:
			screen.queue_free()
		screen_id = id
		screen = Control.new()
		screen.set_script(load({"v10salon": "res://scripts/v10/salon/salon_screen.gd", "v10scene": "res://scripts/v10/salon/zone_scene.gd"}[id]))
		screen.size = Vector2(720, 1280)
		add_child(screen)
		screen.call("build", self, args)

	func back() -> void:
		while not history.is_empty():
			var e: Array = history.pop_back()
			if e[0] == screen_id:
				continue
			if e[0] == "home":
				break
			go(e[0], e[1], true, false)
			return
		went_home = true
		screen_id = "home"


func _history_loop() -> void:
	var S: = use(fixture(30))
	for t in V10SalonData.zone("z1").tasks:
		V10Salon.restore("z1", t.id)
	S[V10Salon.KEY].intro = true
	var m: = MainStub.new()
	get_tree().root.add_child(m)
	m.history.append(["home", {}])
	m.go("v10salon", {})
	await get_tree().process_frame
	m.screen.call("_open_scene", "z1")
	await get_tree().process_frame
	check(m.screen_id == "v10scene", "map → scene")
	m.screen.call("_back")
	await get_tree().process_frame
	check(m.screen_id == "v10salon", "scene «назад» → map")
	m.screen.call("_back")
	await get_tree().process_frame
	check(m.went_home, "map «назад» → home, no salon ↔ scene loop (history %s)" % [m.history])
	m.queue_free()
	await get_tree().process_frame
