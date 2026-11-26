class_name V10ContractSelftest
extends RefCounted

# --contract_selftest=1 (docs/0.10-spec.md §2.2, docs/INTEGRATION_0.10.md §3.6, §4 W3):
# 1. Single source of ₽ (V10Sku / V10Catalog) and % odds (V10Rates): zero hardcoded ruble or percent numbers in
#    V6Txt, v10/** runtime UI scripts, or game/data/** JSON (outside V10Sku, V10Rates, V10Catalog, V10Odds, and
#    Nova's in-character chat dialogue).
# 2. Spec §2.2 alignment: reference pack 1 190 ₽ = 1 090 moon → ≈ 164 ₽ per wish; every SKU ≤ 3.0×; SSR base 1.6 %,
#    consolidated 2.90 %; V10Rates == V10Catalog == V10Sku.

static var ok: = 0
static var total: = 0
static var fails: Array = []

const ALLOWED_GD: = [
	"res://scripts/v10/core/sku.gd",
	"res://scripts/v10/economy/econ_catalog.gd",
	"res://scripts/v10/economy/econ_odds.gd",
	"res://scripts/v10/gacha/rates.gd",
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
	var co: = V10Odds.consolidated(60)
	_check(absf(float(c2.SSR) - float(co.SSR)) < 0.001 and absf(float(c2.SSR) * 100.0 - 2.90) < 0.02, "consolidated SSR unified ≈ 2.90%")


static func _scan_all() -> void:
	var str_re: = RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var fmt_re: = RegEx.create_from_string("%[-+0 #]*\\d*(?:\\.\\d+)?[dsfxX]")
	var hit_re: = RegEx.create_from_string("\\d[\\d\\s\u00a0,\\.]*\\s*[₽%]|[₽%]\\s*\\d")
	var dig_re: = RegEx.create_from_string("\\d")
	var gd_files: = ["res://scripts/v06/story/txt.gd"]
	_walk("res://scripts/v10", ".gd", gd_files)
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
