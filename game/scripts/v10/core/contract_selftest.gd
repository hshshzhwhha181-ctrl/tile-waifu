class_name V10ContractSelftest
extends RefCounted

# --contract_selftest=1 (docs/0.10-spec.md §2.2, docs/INTEGRATION_0.10.md §3.6, §4 W3):
# 1. Single source of ₽ (V10Sku / V10Catalog) and % odds (V10Rates): zero hardcoded ruble or percent numbers in
#    V6Txt, v10/** runtime UI scripts, or game/data/** JSON (outside V10Sku, V10Rates, V10Catalog and
#    Nova's in-character chat dialogue).
# 2. Spec §2.2 alignment: reference pack 1 190 ₽ = 1 090 moon → ≈ 164 ₽ per wish; every SKU ≤ 3.0×; SSR base 1.6 %,
#    consolidated 2.90 %; V10Rates == V10Catalog == V10Sku.

static var ok: = 0
static var total: = 0
static var fails: Array = []

const ALLOWED_GD: = [
	"res://core/base/sku.gd",
	"res://core/economy/econ_catalog.gd",
	"res://core/gacha/rates.gd",
]
const ALLOWED_JSON: = [
	"res://data/v10/chat/reactions.json",
	"res://data/v10/chat/threads_nova.json",
]


static func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


static func run() -> int:
	ok = 0
	total = 0
	fails = []
	_numbers()
	_scan_all()
	_parity_invariants()
	print("CONTRACT_SELFTEST %d/%d" % [ok, total])
	return total - ok


static func _numbers() -> void:
	var ref: = V10Sku.ref_rub_per_pull()
	_check(absf(ref - 1190.0 / 1090.0 * 150.0) < 0.001, "ref_rub_per_pull = 1190/1090*150 (%.2f)" % ref)
	_check(int(round(ref)) == 164, "rounded reference = 164 ₽ per wish")
	_check(absf(V10Rates.ref_rub_per_pull() - ref) < 0.0001, "V10Rates.ref_rub_per_pull == V10Sku.ref_rub_per_pull")
	_check(absf(V10Catalog.base_rub_per_pull() - ref) < 0.0001, "V10Catalog.base_rub_per_pull == V10Sku.ref_rub_per_pull")
	_check(V10Catalog.validate().is_empty(), "V10Catalog.validate() clean")
	for s in V10Catalog.SKUS:
		_check(V10Sku.ratio(s, false) <= V10Catalog.LADDER_MAX + 0.0001, "%s ratio ≤ 3.0×" % s.id)
		if String(s.kind) == "currency":
			_check(V10Sku.ratio(s, true) <= V10Catalog.LADDER_MAX + 0.0001, "%s first ratio ≤ 3.0×" % s.id)
	_check(absf(V10Catalog.SSR_BASE - float(V10Rates.SSR_BASE[2])) < 1e-9, "SSR base unified at 1.6%")
	_check(absf(V10Catalog.S_BASE - float(V10Rates.S_BASE[2])) < 1e-9, "S base unified at 13%")
	var c2: = V10Rates.consolidated(2)
	_check(absf(float(c2.SSR) - 1.0 / V10Rates.mean_ssr_wishes(2)) < 0.001 and absf(float(c2.SSR) * 100.0 - 2.90) < 0.02, "consolidated SSR unified ≈ 2.90%")


static func _scan_all() -> void:
	var str_re: = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var fmt_re: = RegEx.create_from_string("%[-+0 #]*\\d*(?:\\.\\d+)?[dsfxX]")
	var hit_re: = RegEx.create_from_string("\\d[\\d\\s\u00a0,\\.]*\\s*[₽%]|[₽%]\\s*\\d")
	var dig_re: = RegEx.create_from_string("\\d")
	var gd_files: = ["res://core/v06/story/txt.gd"]
	_walk("res://scripts/v10", ".gd", gd_files)
	for d0 in DirAccess.get_directories_at("res://core"):  # WP3: v10 logic moved to core (core/v06..v09 were never scanned here)
		if not d0.begins_with("v0"):
			_walk("res://core/" + d0, ".gd", gd_files)
	var bad_gd: = []
	for p in gd_files:
		if p in ALLOWED_GD or _skip_path(p):
			continue
		var txt: = FileAccess.get_file_as_string(p)
		var ln: = 0
		for raw in txt.split("\n"):
			ln += 1
			var code: = _strip_comment(raw)
			for m in str_re.search_all(code):
				var s: = m.get_string(1).replace("\\u00a0", " ").replace("%%", "")
				s = fmt_re.sub(s, "", true)
				if hit_re.search(s) != null or ("₽" in s and dig_re.search(s) != null):
					bad_gd.append("%s:%d «%s»" % [p, ln, s])
	_check(bad_gd.is_empty(), "0 hardcoded ₽/%% numbers in V6Txt + v10/** UI scripts: %s" % [str(bad_gd)])

	var json_files: = []
	_walk("res://data", ".json", json_files)
	var bad_json: = []
	for p in json_files:
		if p in ALLOWED_JSON or "levels_bake" in p:
			continue
		var txt: = FileAccess.get_file_as_string(p)
		var ln: = 0
		for raw in txt.split("\n"):
			ln += 1
			if hit_re.search(raw) != null:
				bad_json.append("%s:%d" % [p, ln])
	_check(bad_json.is_empty(), "0 hardcoded ₽/%% numbers in res://data/**/*.json: %s" % [str(bad_json)])


static func _skip_path(p: String) -> bool:
	for k in ["selftest", "demo", "runner", "/tools/"]:
		if k in p:
			return true
	return false


static func _strip_comment(line: String) -> String:
	var in_q: = false
	var esc: = false
	for i in line.length():
		var c: = line[i]
		if esc:
			esc = false
			continue
		if c == "\\":
			esc = true
			continue
		if c == "\"":
			in_q = not in_q
		elif c == "#" and not in_q:
			return line.substr(0, i)
	return line


static func _walk(dir_path: String, ext: String, out: Array) -> void:
	var d: = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: = d.get_next()
	while n != "":
		if not n.begins_with("."):
			var full: = dir_path.path_join(n)
			if d.current_is_dir():
				_walk(full, ext, out)
			elif n.ends_with(ext):
				out.append(full)
		n = d.get_next()
	d.list_dir_end()


static func _parity_invariants() -> void:
	# 1. V6SpecialBoard synchronous Joker mate conversion on tap (prevents 0.24s async orphan-tile race)
	var tree: = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var b: = V6SpecialBoard.new()
		tree.root.add_child(b)
		var cfg: Dictionary = TWLevels.at(min(14, G.LEVELS.size() - 1)).duplicate(true)
		b.setup(cfg)
		b.slot_pos = [Vector2(100, 900), Vector2(200, 900), Vector2(300, 900), Vector2(400, 900), Vector2(500, 900)]
		b.slot_size = 80.0
		b.apply_specials({"joker": 1})
		b.input_on = true
		var jokers: Array = []
		for t in b.tiles:
			if t.face == V6SpecialBoard.JOKER:
				jokers.append(t)
		if jokers.size() == 2:
			var j1: Tile = jokers[0]
			var j2: Tile = jokers[1]
			var reg: Tile = null
			for t in b.tiles:
				if t != j1 and t != j2 and t.face != V6SpecialBoard.JOKER and b.is_free(t) and b.takeable(t):
					reg = t
					break
			if reg != null:
				b.open_tile(j1)
				var reg_face: int = reg.face
				b.tap(reg)
				b.tap(j1)
				_check(j2.face == reg_face and j2.face != V6SpecialBoard.JOKER, "V6SpecialBoard Joker mate converts synchronously on tap")
				b.shuffle_board()
				var counts: = {}
				for t in b.tiles:
					if t.alive and not t.pending:
						counts[t.face] = int(counts.get(t.face, 0)) + 1
				var orphans: = 0
				for f in counts:
					if int(counts[f]) % 2 != 0:
						orphans += 1
				_check(orphans == 0, "0 orphan tiles after synchronous Joker tap + immediate shuffle_board()")
			else:
				_check(false, "found free regular tile for Joker parity test")
		else:
			_check(jokers.size() == 2, "V6SpecialBoard deals exactly 2 Jokers when specials.joker=1")
		b.free()
	# 2. V10TowerRules 'gust' trick never mutates Joker face or breaks tile parity
	if tree != null and tree.root != null:
		var tb: = V6SpecialBoard.new()
		tree.root.add_child(tb)
		var tcfg: Dictionary = TWLevels.at(min(14, G.LEVELS.size() - 1)).duplicate(true)
		tb.setup(tcfg)
		tb.apply_specials({"joker": 1})
		var j_before: Array = []
		for t in tb.tiles:
			if t.face == V6SpecialBoard.JOKER:
				j_before.append(t)
				tb.open_tile(t)
		var tr: = V10TowerRules.new()
		var dummy_play: = _FakePlay.new(tb)
		tr.apply_op(dummy_play, {"op": "gust", "n": 12})
		var j_intact: = true
		for j in j_before:
			if (j as Tile).face != V6SpecialBoard.JOKER:
				j_intact = false
		_check(j_intact, "V10TowerRules gust keeps Joker tiles intact")
		var tcounts: = {}
		for t in tb.tiles:
			if t.alive:
				tcounts[t.face] = int(tcounts.get(t.face, 0)) + 1
		var torphans: = 0
		for f in tcounts:
			if int(tcounts[f]) % 2 != 0:
				torphans += 1
		_check(torphans == 0, "0 orphan tiles after V10TowerRules gust")
		dummy_play.free()
		tb.free()
	# 3. Path 1000 representative sample parity (regular, hard, boss, peak)
	var sample_ok: = true
	for idx in [0, 7, 15, 29, 47, 99, 250, 500, 999]:
		var pc: Dictionary = V10LevelGen.level(idx)
		var nt: = int(pc.get("tiles", 0))
		if nt <= 0 or nt % 2 != 0:
			sample_ok = false
			break
	_check(sample_ok, "Path 1000 sample levels (0..999 incl. bosses/peaks) have even tile counts")


class _FakePlay:
	extends Node
	var board: TrayBoard

	func _init(b: TrayBoard) -> void:
		board = b
