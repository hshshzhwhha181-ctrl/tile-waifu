class_name V10TutSelftest
extends RefCounted

# V10TutSelftest — data and state checks of the tutorial (headless). The scene test/tut_test.tscn runs these and
# then the whole first run on the real screens with real touch events (README «Самотест»).
#   static checks: every step / chapter / tip is well formed, every predicate and dynamic target exists, every
#   forced step has an exit (done predicate + timeout), no line is too long, art and portraits exist, the shop
#   tip does not come from a heroine (spec §1.2), no banned words in her lines (spec §2.7);
#   references: every prop the data reads exists on the real screen script (play.gd, home.gd, summon.gd,
#   collection.gd, main.gd), every target resolves on a mock screen set that carries the declared hooks;
#   state: ensure() idempotent, 0.9 tut_done migration, skip / replay / tips / one-time gift.

const MODES: = ["tap", "do", "wait"]
const EMOS: = ["happy", "shy", "surprised", "pout", "sad"]
const SCREEN_SCRIPTS: = {
	"play": "res://scripts/screens/play.gd", "home": "res://scripts/screens/home.gd",
	"summon": "res://scripts/screens/summon.gd", "collection": "res://scripts/screens/collection.gd",
}
const MAIN_SCRIPT: = "res://scripts/main.gd"
const BANNED: = ["₽", "%", "купи", "скидк", "успей", "только сегодня", "акци", "скуча", "почему ты", "бросил", "вернись", "забыл?"]

var ok: = 0
var total: = 0
var fails: = []


func check(name: String, cond: bool, info: = "") -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(name + (" — " + info if info != "" else ""))
		printerr("V10TUT FAIL ", name, " ", info)


func run_all(tree: SceneTree) -> Dictionary:
	V10Tutorial.register_dyn_all()
	data_checks()
	reference_checks()
	await mock_checks(tree)
	state_checks()
	return {"ok": ok, "total": total, "fails": fails}


# ── data ─────────────────────────────────────────────────────────────────────────────────────────────────────

func _preds_of(d: Dictionary) -> Array:
	var out: = []
	for k in ["done", "when", "skip_if", "need"]:
		var v: = String(d.get(k, ""))
		if v != "":
			out.append(v)
	return out


func _pred_known(p: String) -> bool:
	return p in V10Tutorial.PREDICATES or p.begins_with("screen:")


func data_checks() -> void:
	var ids: = {}
	for c in V10TutSteps.CHAPTERS:
		check("chapter %s has steps" % c.id, (c.steps as Array).size() > 0)
		check("chapter %s has a screen" % c.id, String(c.get("screen", "")) != "")
		for p in _preds_of(c):
			check("chapter %s predicate %s known" % [c.id, p], _pred_known(p))
		var vis: = 0
		var cids: = {}
		for s in c.steps:
			cids[s.id] = true
		for e in c.get("entry", []) + c.steps:
			var sid: = String(e.get("id", ""))
			check("step id present", sid != "")
			check("step id %s unique" % sid, not ids.has(sid))
			ids[sid] = true
			var m: = String(e.get("mode", "tap"))
			check("%s mode valid" % sid, m in MODES, m)
			for p in _preds_of(e):
				check("%s predicate %s known" % [sid, p], _pred_known(p))
			if m == "wait":
				check("%s wait has done (exit)" % sid, String(e.get("done", "")) != "")
				continue
			vis += 1
			var txt: = String(e.get("text", ""))
			var lines: = txt.split("\n")
			check("%s text 1–3 lines" % sid, txt != "" and lines.size() <= 3, str(lines.size()))
			for ln in lines:
				check("%s line short" % sid, ln.length() <= 72, "%d: %s" % [ln.length(), ln])
			for w in BANNED:
				check("%s no «%s»" % [sid, w], not (w in txt.to_lower()))
			check("%s emo valid" % sid, String(e.get("emo", "happy")) in EMOS)
			check("%s portrait exists" % sid, ResourceLoader.exists("res://assets/v08/emotions/mc_%s.webp" % String(e.get("emo", "happy"))))
			if m == "do":
				check("%s forced step has done" % sid, String(e.get("done", "")) != "")
				var entry: = (c.get("entry", []) as Array).has(e)
				check("%s forced step has timeout or is a screen bridge" % sid, float(e.get("timeout", 0.0)) > 0.0 or entry)
				check("%s forced step has a target" % sid, e.get("target", []) is Array and (e.target as Array).size() > 0)
			var r: = String(e.get("resume", ""))
			if r != "":
				check("%s resume %s in chapter" % [sid, r], cids.has(r))
			for spec in e.get("target", []):
				_spec_check(sid, spec)
		check("chapter %s has a visible step" % c.id, vis > 0)
	# tips
	var tids: = {}
	var cats: = {}
	for c in V10TutTips.CATS:
		cats[c[0]] = true
	for tp in V10TutTips.TOPICS:
		var id: = String(tp.id)
		check("tip %s unique" % id, not tids.has(id))
		tids[id] = true
		check("tip %s title" % id, String(tp.get("title", "")) != "")
		check("tip %s help" % id, String(tp.get("help", "")).length() > 40)
		check("tip %s cat" % id, cats.has(String(tp.get("cat", ""))))
		check("tip %s art" % id, ResourceLoader.exists(V10TutTips.icon_path(tp)), V10TutTips.icon_path(tp))
		var tip: = String(tp.get("tip", ""))
		if tip != "":
			check("tip %s 1–3 lines" % id, tip.split("\n").size() <= 3)
			for ln in tip.split("\n"):
				check("tip %s line short" % id, ln.length() <= 72, ln)
			check("tip %s has a trigger" % id, (tp.get("screens", []) as Array).size() > 0 or (tp.get("events", []) as Array).size() > 0)
			if String(tp.get("speaker", "mc")) == "mc":
				for w in BANNED:
					check("tip %s no «%s»" % [id, w], not (w in tip.to_lower()))
		var rp: = String(tp.get("replay", ""))
		if rp != "":
			check("tip %s replay chapter %s" % [id, rp], not V10TutSteps.chapter(rp).is_empty())
		for spec in tp.get("target", []):
			_spec_check("tip " + id, spec)
	# the shop is never presented by a heroine (spec §1.2: she never talks about purchases)
	check("shop tip speaker is the neutral guide", String(V10TutTips.topic("shop").get("speaker", "mc")) == "guide")
	# every feature the owner listed has a topic
	for need in ["path", "salon", "phone", "gacha", "shop", "profile", "tile_themes", "pagoda", "journey", "palm", "duels",
			"modes", "rituals", "leagues", "events", "room", "settings", "basics", "tray", "combo", "helpers", "victory", "home", "wardrobe"]:
		check("topic %s exists" % need, tids.has(need))


func _spec_check(owner: String, spec) -> void:
	if spec is Dictionary and spec.has("union"):
		for s in spec.union:
			_spec_check(owner, s)
		return
	check("%s target is a dictionary" % owner, spec is Dictionary)
	if not (spec is Dictionary):
		return
	var kinds: = ["meta", "prop", "path", "text", "tex", "dyn", "rect", "px"].filter(func(k): return spec.has(k))
	check("%s target has one kind" % owner, kinds.size() == 1, str(spec))
	if spec.has("dyn"):
		check("%s dyn %s registered" % [owner, spec.dyn], V10TutTarget.DYN.has(String(spec.dyn)))
	if spec.has("rect"):
		var a: Array = spec.rect
		check("%s rect within the screen" % owner, a.size() == 4 and float(a[0]) >= 0 and float(a[1]) >= 0 and float(a[0]) + float(a[2]) <= 1.001 and float(a[1]) + float(a[3]) <= 1.001)


# ── references against the real scripts ─────────────────────────────────────────────────────────────────────

static func _props_of(path: String) -> Dictionary:
	var out: = {}
	var s: Script = load(path)
	while s:
		for p in s.get_script_property_list():
			out[String(p.name)] = true
		s = s.get_base_script()
	return out


func reference_checks() -> void:
	var main_props: = _props_of(MAIN_SCRIPT)
	var per: = {}
	for k in SCREEN_SCRIPTS:
		per[k] = _props_of(SCREEN_SCRIPTS[k])
	for c in V10TutSteps.CHAPTERS:
		for e in c.get("entry", []) + c.steps:
			var scr: = String(e.get("screen", c.screen))
			for spec in _flat(e.get("target", [])):
				if spec.has("prop"):
					var root: = String(spec.prop).split(".")[0]
					if spec.get("from", "") == "main":
						check("%s main.%s exists" % [e.id, root], main_props.has(root))
					elif per.has(scr):
						check("%s %s.%s exists" % [e.id, scr, root], per[scr].has(root))
	# the props the predicates / dyn resolvers read
	for p in ["board", "board_rect", "victory_next_btn", "skill_ready", "ult", "stage", "lvl", "mode", "tray_box", "btn_hint", "btn_undo", "btn_shuffle"]:
		check("play.%s exists" % p, per.play.has(p))
	for p in ["seq", "showcase", "flipping", "pull1_btn", "pull10_btn", "pity_lbl"]:
		check("summon.%s exists" % p, per.summon.has(p))
	for p in ["play_btn", "modes_btn", "side_btns"]:
		check("home.%s exists" % p, per.home.has(p))
	for p in ["screen", "screen_id", "overlay", "busy", "tab_nodes", "navbar", "prof_root"]:
		check("main.%s exists" % p, main_props.has(p))
	check("TrayBoard API", ClassDB.class_exists("Node2D") and TrayBoard.new().has_method("free_tiles"))


func _flat(specs) -> Array:
	var out: = []
	if specs is Dictionary:
		specs = [specs]
	for s in specs:
		if s is Dictionary and s.has("union"):
			out.append_array(_flat(s.union))
		elif s is Dictionary:
			out.append(s)
	return out


# ── mock screen set: every target resolves when its declared hook is on screen ───────────────────────────────

class MockScreen extends Control:
	var props: = {}
	func _get(p: StringName):
		return props.get(String(p))


class MockMain extends Control:
	var screen: Control
	var screen_id: = ""
	var overlay: Control
	var busy: = false
	var tab_nodes: = {}
	var navbar: Control
	var prof_root: Control


func _box(parent: Control, r: Rect2) -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	parent.add_child(c)
	return c


func mock_checks(tree: SceneTree) -> void:
	var root: = tree.root
	var m: = MockMain.new()
	m.size = Vector2(720, 1280)
	root.add_child(m)
	m.overlay = _box(m, Rect2(0, 0, 720, 1280))
	m.navbar = _box(m, Rect2(0, 1160, 720, 120))
	m.prof_root = _box(m, Rect2(8, 20, 360, 90))
	for k in ["home", "collection", "levels", "summon", "shop"]:
		m.tab_nodes[k] = _box(m.navbar, Rect2(144 * ["home", "collection", "levels", "summon", "shop"].find(k), 0, 144, 120))
	var ctx_of: = func(s): return {"main": m, "screen": s}
	var n: = 0
	# every step: build the hooks its specs declare on a fresh mock of its screen; the FIRST entry must resolve
	# (that is the hook a lane is expected to provide) and the whole list must resolve
	var entries: = []
	for c in V10TutSteps.CHAPTERS:
		for e in c.get("entry", []) + c.steps:
			if String(e.get("mode", "tap")) != "wait" and (e.get("target", []) as Array).size() > 0:
				entries.append(["step " + String(e.id), e.target])
	for tp in V10TutTips.TOPICS:
		if (tp.get("target", []) as Array).size() > 0:
			entries.append(["tip " + String(tp.id), tp.target])
	for en in entries:
		var s: = MockScreen.new()
		s.size = Vector2(720, 1280)
		m.add_child(s)
		m.screen = s
		var first_dyn: = false
		for spec in _flat(en[1]):
			_provide(s, m, spec)
		var first = en[1][0]
		if first is Dictionary and first.has("dyn"):
			first_dyn = true
		await tree.process_frame
		if _flat(en[1]).all(func(x): return x.has("dyn")):
			# board tiles / victory parts: only the real run (test/tut_test.gd) has them
			s.queue_free()
			continue
		var r: = V10TutTarget.resolve(en[1], ctx_of.call(s))
		check("%s resolves on the mock" % en[0], r.ok)
		if not first_dyn:
			var r0: = V10TutTarget.resolve([first], ctx_of.call(s))
			check("%s first hook resolves" % en[0], r0.ok, str(first))
		check("%s rect on screen" % en[0], Rect2(-40, -40, 800, 1360).encloses(r.rect), str(r.rect))
		s.queue_free()
		n += 1
	# fallbacks: with NO hooks at all, a target list that ends in rect / px still resolves (never an empty hole)
	var bare: = MockScreen.new()
	bare.size = Vector2(720, 1280)
	m.add_child(bare)
	m.screen = bare
	for en in entries:
		var last = (en[1] as Array).back()
		if last is Dictionary and (last.has("rect") or last.has("px")):
			check("%s fallback resolves bare" % en[0], V10TutTarget.resolve(en[1], ctx_of.call(bare)).ok)
	# re-resolve on resize: a px from the bottom follows the new height
	var r1: = V10TutTarget.resolve({"px": [0, -120, 720, 120], "pad": 0}, {"vp": Vector2(720, 1280)})
	var r2: = V10TutTarget.resolve({"px": [0, -120, 720, 120], "pad": 0}, {"vp": Vector2(720, 1600)})
	check("px from bottom follows the aspect", r1.rect.position.y == 1160.0 and r2.rect.position.y == 1480.0, "%s %s" % [r1.rect, r2.rect])
	# a hidden node is never a target
	var hid: = _box(bare, Rect2(10, 10, 50, 50))
	hid.set_meta("tut_id", "x.hidden")
	hid.visible = false
	await tree.process_frame
	check("hidden node not targeted", not V10TutTarget.resolve({"meta": "x.hidden"}, ctx_of.call(bare)).ok)
	m.queue_free()
	await tree.process_frame


func _provide(s: MockScreen, m: MockMain, spec: Dictionary) -> void:
	if spec.has("meta"):
		var c: = _box(s, Rect2(100, 300, 200, 90))
		c.set_meta("tut_id", String(spec.meta))
	elif spec.has("prop") and spec.get("from", "") != "main":
		var parts: = String(spec.prop).split(".")
		if parts.size() == 1:
			if parts[0] == "board_rect":
				s.props[parts[0]] = Rect2(10, 318, 700, 700)
			else:
				s.props[parts[0]] = _box(s, Rect2(200, 600, 160, 110))
		else:
			var d: Dictionary = s.props.get(parts[0], {})
			d[parts[1]] = _box(s, Rect2(16, 140 + 124 * d.size(), 84, 84))
			s.props[parts[0]] = d
	elif spec.has("text"):
		var l: = UI.label(String(spec.text), 22)
		l.position = Vector2(80, 900)
		l.size = Vector2(300, 40)
		s.add_child(l)
	elif spec.has("tex"):
		var tr: = TextureRect.new()
		tr.texture = V8Art.star(false)
		tr.position = Vector2(200, 400)
		tr.size = Vector2(100, 100)
		s.add_child(tr)


# ── state ────────────────────────────────────────────────────────────────────────────────────────────────────

func state_checks() -> void:
	var s: = {"gems": 100, "tut_done": false}
	V10TutState.override_s = s
	var d: = V10TutState.ensure(s)
	check("ensure adds the block", s.has(V10TutState.KEY) and d.has("chapters") and d.has("tips"))
	d.chapters["home1"] = true
	d.tips["salon"] = "x"
	var before: = str(s)
	V10TutState.ensure(s)
	V10TutState.ensure(s)
	check("ensure idempotent", str(s) == before)
	s[V10TutState.KEY].tips = "broken"
	V10TutState.ensure(s)
	check("ensure repairs a wrong type", s[V10TutState.KEY].tips is Dictionary)
	V10TutState.mark_tip("salon")
	var old: = {"tut_done": true}
	V10TutState.ensure(old)
	check("0.9 player (tut_done) skips the first match", bool(old[V10TutState.KEY].chapters.get("match1", false)))
	V10TutState.set_step("m_twin")
	check("step saved", V10TutState.step() == "m_twin")
	V10TutState.finish_chapter("match1")
	check("finish chapter clears step and sets tut_done", V10TutState.step() == "" and bool(s.tut_done) and V10TutState.chapter_done("match1"))
	V10TutState.skip_all()
	check("skip all", V10TutState.skipped())
	V10TutState.replay()
	check("replay brings chapters back", not V10TutState.skipped() and not V10TutState.chapter_done("home1"))
	check("tips survive replay", V10TutState.tip_seen("salon"))
	V10TutState.reset_tips()
	check("reset tips", not V10TutState.tip_seen("salon"))
	var g0: = int(s.gems)
	var a: = V10Tutorial.grant("first_wish")
	var b: = V10Tutorial.grant("first_wish")
	check("first wish granted once", a and not b and int(s.gems) == g0 + int(G.PULL_COST), "%d→%d" % [g0, int(s.gems)])
	var s2: = {"tickets": 0}
	V10TutState.override_s = s2
	V10Tutorial.grant("first_wish")
	check("first wish is a ticket in the 0.10 wallet", int(s2.tickets) == 1 and not s2.has("gems"))
	V10TutState.set_large(true)
	check("large text scales", V10TutState.text_scale() > 1.1)
	s2["text_large"] = false
	V10TutState.set_large(false)
	check("text_large off → 1.0", is_equal_approx(V10TutState.text_scale(), 1.0))
	check("{slots} plural", V10Tutorial.fill("всего {slots} места") == "всего 4 места")
	V10TutState.override_s = null
