class_name TWUltRegistry
extends RefCounted

# TWUltRegistry (P87 / BATTLE_ULT_SPEC §7.3, §7.8):
# Single pure-core registry unifying the 58-entry canonical catalogue (data/ult_catalogue.json),
# legacy founder definitions (V9Ults), and optional injected legacy sources (e.g. V10W1Ults from shell
# via register_legacy_source, keeping game/core 100% free of shell dependencies / CORE_PURITY).
#
# API:
#   ids() -> PackedStringArray                  all 58 canonical catalogue ids (in catalogue order)
#   all_ids() -> PackedStringArray              canonical ids + unmapped legacy outfit ids
#   has(id) -> bool                             true for canonical id or mapped/registered legacy outfit id
#   has_catalogue(id) -> bool                   true strictly for canonical 58-id catalogue entries
#   entry(id) / get_ult(id) -> Dictionary       canonical entry (or legacy fallback); {} if unknown
#   legacy_entry(id) -> Dictionary              legacy table record (rects / mod / sfx / fx) if present
#   for_hero(hero) -> Array                     canonical catalogue ids belonging to `hero`
#   equipped(hero, outfit_id = "") -> String    canonical ult id for equipped outfit, fallback `<hero>_base`
#   legacy(id) -> String                        bidirectional alias: canonical <-> legacy_outfit
#   core(hero, ranked = false) -> Dictionary    heroine core (founders + injected wave-1 + catalogue fallback)
#   schema_errors(id) -> Array                  schema + U01..U04 + U13 + U16 errors for a catalogue id ([] = valid)
#   coverage_report(items = {}) -> Dictionary   bidirectional coverage & per-hero BASE+VOW check (U12, U17)
#   ensure_save(S) -> Dictionary                modular save init for ult_seen + ult_repeat (SAVE_VER stays 8)

const CATALOGUE_PATH: = "res://core/ult/data/ult_catalogue.json"
const SAVE_MOD_KEY: = "battle"
const SAVE_MOD_VER: = 1
const DEFAULT_REPEAT: = "first_per_fight"

const REQUIRED_FIELDS: = [
	"id", "hero", "tier", "slot", "name_ru", "name_jp", "status", "legacy_outfit",
	"hem_class", "cutscene_s", "trigger_s", "release_s", "beats_n", "poses_n",
	"plates_n", "impact_events_max", "voice_cues", "sfx_cues", "vfx", "twist",
	"atk_pct_star0", "atk_pct_per_star", "skin_pack", "assets",
]
const HEM_CLASSES: = ["long", "knee", "mini", "pants", "swim"]
const VALID_STATUSES: = ["launch", "m6", "m12"]
const VALID_TWISTS: = ["", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8"]
const VALID_THEMES: = ["EMBER", "GILT", "INK", "JADE", "MOON", "NEON", "SAKURA", "TIDE"]
const VALID_HERO_STEPS: = ["H100", "H300", "H500", "H700", "H900"]
const VALID_NIGHT_TOKENS: = ["NIGHT_400", "NIGHT_500", "NIGHT_600", "NIGHT_700", "NIGHT_800", "NIGHT_900"]
const VALID_PAPER_TOKENS: = ["PAPER_100", "PAPER_300", "PAPER_500", "PAPER_700"]

static var _loaded: = false
static var _raw: Dictionary = {}
static var _by_id: Dictionary = {}              # canonical ult_id -> Dictionary
static var _order: PackedStringArray = PackedStringArray()
static var _cat_to_legacy: Dictionary = {}      # canonical ult_id -> legacy_outfit
static var _legacy_to_cat: Dictionary = {}      # legacy_outfit -> first canonical ult_id
static var _by_hero: Dictionary = {}            # hero -> Array[String]
static var _legacy_sources: Dictionary = {}     # source_name -> {ults, cores, ranked_cores, bases}


# ── load / reload / injection ────────────────────────────────────────────────

static func _ensure() -> void:
	if _loaded:
		return
	var txt: String = FileAccess.get_file_as_string(CATALOGUE_PATH) if FileAccess.file_exists(CATALOGUE_PATH) else ""
	var parsed: Variant = JSON.parse_string(txt) if txt != "" else null
	install_catalogue(parsed if parsed is Dictionary else {})


static func reload_catalogue() -> void:
	_loaded = false
	_raw = {}
	_by_id = {}
	_order = PackedStringArray()
	_cat_to_legacy = {}
	_legacy_to_cat = {}
	_by_hero = {}
	_ensure()


static func reset_all() -> void:
	_legacy_sources.clear()
	reload_catalogue()


static func install_catalogue(doc: Dictionary) -> void:
	_loaded = true
	_raw = doc
	_by_id = {}
	_order = PackedStringArray()
	_cat_to_legacy = {}
	_legacy_to_cat = {}
	_by_hero = {}
	var ults = doc.get("ults", [])
	if ults is Array:
		for item in ults:
			if not (item is Dictionary):
				continue
			var u: Dictionary = item
			var uid: String = str(u.get("id", ""))
			if uid == "":
				continue
			_by_id[uid] = u
			_order.append(uid)
			var hero: String = str(u.get("hero", ""))
			if hero != "":
				if not _by_hero.has(hero):
					_by_hero[hero] = []
				(_by_hero[hero] as Array).append(uid)
			var leg: String = str(u.get("legacy_outfit", ""))
			if leg != "":
				_cat_to_legacy[uid] = leg
				if not _legacy_to_cat.has(leg):
					_legacy_to_cat[leg] = uid


# Inject a shell/module legacy table (e.g. V10W1Ults) without core importing shell scripts.
static func register_legacy_source(source_name: String, ults: Dictionary, cores: Dictionary = {}, ranked_cores: Dictionary = {}, bases: Dictionary = {}) -> void:
	_legacy_sources[source_name] = {
		"ults": ults,
		"cores": cores,
		"ranked_cores": ranked_cores,
		"bases": bases,
	}


static func unregister_legacy_source(source_name: String) -> void:
	_legacy_sources.erase(source_name)


# ── queries ──────────────────────────────────────────────────────────────────

static func catalogue() -> Dictionary:
	_ensure()
	return _raw


static func tiers() -> Dictionary:
	_ensure()
	var t = _raw.get("tiers", {})
	return t if t is Dictionary else {}


static func heroes() -> PackedStringArray:
	_ensure()
	var out: = PackedStringArray()
	var hs = _raw.get("heroes", {})
	if hs is Dictionary:
		for h in hs:
			out.append(str(h))
	return out


static func ids() -> PackedStringArray:
	_ensure()
	return _order.duplicate()


static func all_ids() -> PackedStringArray:
	_ensure()
	var seen: Dictionary = {}
	var out: = PackedStringArray()
	for uid in _order:
		seen[uid] = true
		out.append(uid)
	for lid in V9Ults.ULTS:
		var s: String = str(lid)
		if not seen.has(s):
			seen[s] = true
			out.append(s)
	for sn in _legacy_sources:
		var ults: Dictionary = _legacy_sources[sn].ults
		for lid in ults:
			var s: String = str(lid)
			if not seen.has(s):
				seen[s] = true
				out.append(s)
	return out


static func has_catalogue(id: String) -> bool:
	_ensure()
	return _by_id.has(id)


static func has(id: String) -> bool:
	_ensure()
	if _by_id.has(id) or _legacy_to_cat.has(id) or V9Ults.has(id):
		return true
	for sn in _legacy_sources:
		if (_legacy_sources[sn].ults as Dictionary).has(id):
			return true
	return false


static func entry(id: String) -> Dictionary:
	_ensure()
	if _by_id.has(id):
		return _by_id[id]
	if _legacy_to_cat.has(id):
		return _by_id[_legacy_to_cat[id]]
	return legacy_entry(id)


static func get_ult(id: String) -> Dictionary:
	return entry(id)


static func legacy_entry(id: String) -> Dictionary:
	_ensure()
	var lid: String = str(_cat_to_legacy.get(id, id))
	if V9Ults.has(lid):
		return V9Ults.get_ult(lid)
	for sn in _legacy_sources:
		var ults: Dictionary = _legacy_sources[sn].ults
		if ults.has(lid):
			return ults[lid]
	return {}


static func for_hero(hero: String) -> Array:
	_ensure()
	var arr = _by_hero.get(hero, [])
	return (arr as Array).duplicate()


# Bidirectional mapping between canonical 58-catalogue id and legacy outfit id.
static func legacy(id: String) -> String:
	_ensure()
	if _cat_to_legacy.has(id):
		return str(_cat_to_legacy[id])
	if _legacy_to_cat.has(id):
		return str(_legacy_to_cat[id])
	return ""


static func catalogue_to_legacy(cat_id: String) -> String:
	_ensure()
	return str(_cat_to_legacy.get(cat_id, ""))


static func legacy_to_catalogue(legacy_id: String) -> String:
	_ensure()
	return str(_legacy_to_cat.get(legacy_id, ""))


# Resolve equipped outfit (canonical or legacy) to canonical ult id; falls back to `<hero>_base`.
static func equipped(hero: String, outfit_id: String = "") -> String:
	_ensure()
	if outfit_id != "":
		if _by_id.has(outfit_id) and str(_by_id[outfit_id].get("hero", "")) == hero:
			return outfit_id
		if _legacy_to_cat.has(outfit_id):
			var cid: String = str(_legacy_to_cat[outfit_id])
			if str(_by_id[cid].get("hero", "")) == hero:
				return cid
	var base_id: String = hero + "_base"
	if _by_id.has(base_id):
		return base_id
	return ""


static func core(hero: String, ranked: bool = false) -> Dictionary:
	_ensure()
	if V9Ults.CORES.has(hero):
		return V9Ults.core(hero, ranked)
	for sn in _legacy_sources:
		var src: Dictionary = _legacy_sources[sn]
		var cs: Dictionary = src.cores
		if cs.has(hero):
			var c: Dictionary = (cs[hero] as Dictionary).duplicate()
			var rcs: Dictionary = src.ranked_cores
			if ranked and rcs.has(hero):
				c.merge(rcs[hero], true)
			c["hero"] = hero
			return c
	var hs: Dictionary = _raw.get("heroes", {})
	if hs.has(hero) and hs[hero] is Dictionary:
		var hrec: Dictionary = hs[hero]
		return {
			"hero": hero,
			"name": str(hrec.get("ru", hero)),
			"desc": str(hrec.get("table_core", "")),
			"battle_effect": str(hrec.get("battle_effect", "")),
		}
	return {}


# Deterministic non-repeating voice line index picker (uses injected TWRng; never repeats `last` when n >= 2).
static func pick_voice_idx(id: String, last: int, rng: TWRng) -> int:
	var u: Dictionary = entry(id)
	var cues = u.get("voice_cues", u.get("lines", []))
	var n: int = (cues as Array).size() if cues is Array else 0
	if n <= 0:
		return -1
	var idx: int = rng.below(n) if rng != null else 0
	if n > 1 and idx == last:
		idx = (idx + 1) % n
	return idx


# ── schema validation (U01..U04, U13, U16, U17) ──────────────────────────────

static func _has_cyrillic(s: String) -> bool:
	for i in s.length():
		var c: int = s.unicode_at(i)
		if (c >= 0x0410 and c <= 0x044F) or c == 0x0401 or c == 0x0451:
			return true
	return false


static func _is_num(v: Variant) -> bool:
	return v is int or (v is float and is_finite(v))


# SL-ULT-09 / U04: PALETTE_LOCK token grammar for ult VFX.
# Allowed: <hero>.H100|300|500|700|900, <THEME>.T1..T5, NIGHT_400..900, PAPER_100|300|500|700.
# Forbidden: raw #hex, GOLD_*, CINNABAR, standalone semantic EMBER.
static func valid_vfx_token(tok: String) -> bool:
	_ensure()
	if tok == "" or tok.begins_with("#") or tok.begins_with("GOLD_") or tok == "CINNABAR" or tok == "EMBER":
		return false
	if tok in VALID_NIGHT_TOKENS or tok in VALID_PAPER_TOKENS:
		return true
	var dot: int = tok.find(".")
	if dot <= 0 or dot >= tok.length() - 1:
		return false
	var head: String = tok.substr(0, dot)
	var tail: String = tok.substr(dot + 1)
	var hs: Dictionary = _raw.get("heroes", {})
	if hs.has(head) and tail in VALID_HERO_STEPS:
		return true
	if head in VALID_THEMES and tail.length() == 2 and tail[0] == "T" and tail[1] >= "1" and tail[1] <= "5":
		return true
	return false


static func schema_errors(id: String) -> Array:
	_ensure()
	var errs: Array = []
	if not _by_id.has(id):
		return ["unknown catalogue id: " + id]
	var u: Dictionary = _by_id[id]
	# U01: required fields present
	for k in REQUIRED_FIELDS:
		if not u.has(k):
			errs.append("U01 missing field: " + k)
	if not errs.is_empty():
		return errs
	# Hero and tier validity
	var hero: String = str(u.hero)
	var hs: Dictionary = _raw.get("heroes", {})
	if not hs.has(hero):
		errs.append("U01 unknown hero: " + hero)
	var tier: String = str(u.tier)
	var ts: Dictionary = tiers()
	if not ts.has(tier):
		errs.append("U01 unknown tier: " + tier)
	else:
		var ti: Dictionary = ts[tier]
		if not _is_num(u.cutscene_s) or absf(float(u.cutscene_s) - float(ti.get("len", -1.0))) > 0.02:
			errs.append("U01 cutscene_s mismatch: %s vs tier %s" % [str(u.cutscene_s), str(ti.get("len"))])
		if int(u.beats_n) != int(ti.get("beats", -1)):
			errs.append("U01 beats_n mismatch: %s vs %s" % [str(u.beats_n), str(ti.get("beats"))])
		if int(u.poses_n) != int(ti.get("poses", -1)):
			errs.append("U01 poses_n mismatch: %s vs %s" % [str(u.poses_n), str(ti.get("poses"))])
		if int(u.plates_n) != int(ti.get("plates", -1)):
			errs.append("U01 plates_n mismatch: %s vs %s" % [str(u.plates_n), str(ti.get("plates"))])
		if int(u.impact_events_max) != int(ti.get("impact", -1)):
			errs.append("U01 impact_events_max mismatch: %s vs %s" % [str(u.impact_events_max), str(ti.get("impact"))])
		var want_vc: int = int(ti.get("voice", 0))
		if not (u.voice_cues is Array) or (u.voice_cues as Array).size() != want_vc:
			errs.append("U03 voice_cues count %d != tier %d" % [(u.voice_cues as Array).size() if u.voice_cues is Array else -1, want_vc])
	if not _is_num(u.trigger_s) or absf(float(u.trigger_s) - float(_raw.get("trigger_s", 0.8))) > 0.02:
		errs.append("U01 trigger_s mismatch: " + str(u.trigger_s))
	if not _is_num(u.release_s) or absf(float(u.release_s) - float(_raw.get("release_s", 0.5))) > 0.02:
		errs.append("U01 release_s mismatch: " + str(u.release_s))
	var status: String = str(u.status)
	if not (status in VALID_STATUSES):
		errs.append("U01 invalid status: " + status)
	# U02: name_ru Cyrillic; name_jp non-empty for launch
	if not _has_cyrillic(str(u.name_ru)):
		errs.append("U02 name_ru lacks Cyrillic: " + str(u.name_ru))
	if status == "launch" and str(u.name_jp).strip_edges() == "":
		errs.append("U02 name_jp empty for launch")
	# U03: voice_cues 2..4, RU voice lines <= 28 chars & Cyrillic (launch requires >= 2 lines)
	if u.voice_cues is Array:
		var vc: Array = u.voice_cues
		if vc.size() < 2 or vc.size() > 4:
			errs.append("U03 voice_cues size out of 2..4: %d" % vc.size())
		for c in vc:
			if str(c).strip_edges() == "":
				errs.append("U03 empty voice_cue")
	if u.has("voice") and u.voice is Array:
		var vl: Array = u.voice
		if status == "launch" and vl.size() < 2:
			errs.append("U03 launch entry has <2 RU voice lines: %d" % vl.size())
		for ln in vl:
			var s: String = str(ln)
			if not _has_cyrillic(s) or s.length() > 28:
				errs.append("U03 invalid RU voice line (len %d): %s" % [s.length(), s])
	# U04: PALETTE_LOCK tokens on vfx[]
	if not (u.vfx is Array) or (u.vfx as Array).is_empty():
		errs.append("U04 empty vfx tokens")
	else:
		for tok in u.vfx:
			if not valid_vfx_token(str(tok)):
				errs.append("U04 invalid PALETTE_LOCK token: " + str(tok))
	# U06 / hem_class
	if not (str(u.hem_class) in HEM_CLASSES):
		errs.append("U06 invalid hem_class: " + str(u.hem_class))
	# U16 / twist
	if not (str(u.twist) in VALID_TWISTS):
		errs.append("U16 invalid twist: " + str(u.twist))
	if not _is_num(u.atk_pct_star0) or not _is_num(u.atk_pct_per_star):
		errs.append("U01 non-numeric atk_pct fields")
	if str(u.skin_pack).strip_edges() == "":
		errs.append("U01 empty skin_pack")
	if not (u.assets is Array) or (u.assets as Array).is_empty():
		errs.append("U01 empty assets list")
	if not (u.sfx_cues is Array):
		errs.append("U01 sfx_cues not an array")
	else:
		var sc: Array = u.sfx_cues
		# Quiet VOW cutscenes intentionally omit combat SFX cues (sfx_cues: []); all other tiers require >= 1 cue.
		if tier != "VOW" and sc.is_empty():
			errs.append("U01 empty sfx_cues list")
		for cue in sc:
			if str(cue).strip_edges() == "":
				errs.append("U01 empty sfx_cue item")
	return errs


static func coverage_report(expected_ids: Array = [], items: Dictionary = {}) -> Dictionary:
	_ensure()
	var reg_ids: PackedStringArray = ids()
	var missing_in_reg: Array = []
	var extra_in_reg: Array = []
	var exp_set: Dictionary = {}
	if expected_ids.is_empty():
		for rid in reg_ids:
			exp_set[rid] = true
	else:
		for eid in expected_ids:
			var s: String = str(eid)
			exp_set[s] = true
			if not _by_id.has(s):
				missing_in_reg.append(s)
		for rid in reg_ids:
			if not exp_set.has(rid):
				extra_in_reg.append(rid)
	var bad_schema: Dictionary = {}
	var covered: = 0
	for rid in reg_ids:
		var se: Array = schema_errors(rid)
		if se.is_empty():
			covered += 1
		else:
			bad_schema[rid] = se
	var missing_base_vow: Array = []
	for h in heroes():
		if not _by_id.has(h + "_base"):
			missing_base_vow.append(h + "_base")
		if not _by_id.has(h + "_vow"):
			missing_base_vow.append(h + "_vow")
	var unmapped_items: Array = []
	for item_id in items:
		var it = items[item_id]
		if it is Dictionary and str((it as Dictionary).get("cat", "")) == "outfit":
			if not has(str(item_id)):
				unmapped_items.append(str(item_id))
	return {
		"ids": reg_ids.size(),
		"covered": covered,
		"missing_in_registry": missing_in_reg,
		"extra_in_registry": extra_in_reg,
		"schema_errors": bad_schema,
		"missing_base_vow": missing_base_vow,
		"unmapped_items": unmapped_items,
	}


# ── modular save helper (BATTLE_ULT_SPEC §7.3 & Прил. R T17: SAVE_VER stays 8) ─

static func ensure_save(S: Dictionary) -> Dictionary:
	var added: Array = []
	if not (S.get("ult_seen") is Dictionary):
		S["ult_seen"] = {}
		added.append("ult_seen")
	else:
		var seen: Dictionary = S["ult_seen"]
		var drop: Array = []
		for k in seen:
			var v = seen[k]
			if v is int:
				seen[k] = maxi(0, v)
			elif v is float and is_finite(v):
				seen[k] = maxi(0, int(v))
			else:
				drop.append(k)
		for k in drop:
			seen.erase(k)
	var rep: String = str(S.get("ult_repeat", ""))
	if not (rep in TWUltPolicy.REPEAT_SETTINGS):
		S["ult_repeat"] = DEFAULT_REPEAT
		added.append("ult_repeat")
	if not (S.get("mod_ver") is Dictionary):
		S["mod_ver"] = {}
	var mv: Dictionary = S["mod_ver"]
	var cur_mv_raw = mv.get(SAVE_MOD_KEY, 0)
	var cur_mv: int = int(cur_mv_raw) if _is_num(cur_mv_raw) else 0
	if cur_mv < SAVE_MOD_VER:
		mv[SAVE_MOD_KEY] = SAVE_MOD_VER
		added.append("mod_ver." + SAVE_MOD_KEY)
	return {"added": added, "mod_ver": int(mv[SAVE_MOD_KEY])}
