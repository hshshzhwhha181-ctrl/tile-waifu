extends Node

# --salon_selftest=1 (spec §Р1 «Самотест», §Р2 «Самотест») — run by salon_runner.gd, or by the integrator's
# --v10_selftest=all via V10Registry (README). Prints «SALON_SELFTEST ok/total» and every failed check.

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена"]
const UI_BANNED: = ["гарант", "пити", "pity", "гача", "ролл", "крутка", "фивер", "ивент", "ульта", "донат", "шаффл"]

const MIN_CHECKS: = 196

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
	check(h.label == "z1 · 0/5" and not h.dot, "hub info fresh")
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
	texts.append_array([V10SalonData.INTRO_NEW, V10SalonData.INTRO_OLD])
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
