class_name TWUltSelftest
extends RefCounted

# TWUltSelftest (P87 / BATTLE_ULT_SPEC §7.3, §7.8, AT-U01, AT-U02, AT-U09, AT-U12):
# Pure core selftest for TWUltRegistry, TWUltPolicy, ult_catalogue.json (58 ids), and ult_seen save migration.
# Prints:
#   ULT COVERAGE ids=58 covered=58
#   TWULT_SELFTEST ok/total

static var _pass: = 0
static var _fail: = 0


static func _default_check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


static func run() -> Array:
	_pass = 0
	_fail = 0
	var cov: Dictionary = run_checks(_default_check)
	print("ULT COVERAGE ids=%d covered=%d" % [int(cov.get("ids", 0)), int(cov.get("covered", 0))])
	var total: = _pass + _fail
	print("TWULT_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


# Reusable entry point so --ults_selftest=1 (V9UltsSelftest) can run the exact same checks without duplicating logic.
static func run_checks(chk: Callable, items: Dictionary = {}) -> Dictionary:
	TWUltRegistry.reload_catalogue()
	var cov: Dictionary = _test_catalogue_and_schema(chk, items)
	_test_negative_schema_guards(chk)
	_test_equipped_and_legacy(chk)
	_test_voice_picker_and_limits(chk)
	_test_policy_30_cases(chk)
	_test_save_ult_seen_and_downgrade(chk)
	return cov


# ── AT-U01 & AT-U02: 58-id bidirectional catalogue parity & U01..U04/U16/U17 schema ─────────────────────────

static func _test_catalogue_and_schema(chk: Callable, items: Dictionary) -> Dictionary:
	var raw_txt: String = FileAccess.get_file_as_string(TWUltRegistry.CATALOGUE_PATH)
	var parsed = JSON.parse_string(raw_txt)
	chk.call("AT-U01: ult_catalogue.json parses as Dictionary", parsed is Dictionary)
	var expected_ids: Array = []
	if parsed is Dictionary and parsed.get("ults") is Array:
		for u in parsed.ults:
			expected_ids.append(str(u.id))
	var reg_ids: PackedStringArray = TWUltRegistry.ids()
	chk.call("AT-U01: catalogue has 58 entries", expected_ids.size() == 58 and reg_ids.size() == 58,
		"json=%d reg=%d" % [expected_ids.size(), reg_ids.size()])
	var cov: Dictionary = TWUltRegistry.coverage_report(expected_ids, items)
	chk.call("AT-U01: bidirectional 100% parity (0 missing, 0 extra)",
		(cov.missing_in_registry as Array).is_empty() and (cov.extra_in_registry as Array).is_empty(),
		"missing=%s extra=%s" % [str(cov.missing_in_registry), str(cov.extra_in_registry)])
	chk.call("U17: all 10 heroines present with _base and _vow",
		TWUltRegistry.heroes().size() == 10 and (cov.missing_base_vow as Array).is_empty(),
		str(cov.missing_base_vow))
	# Check every single one of the 58 ids through schema_errors()
	for uid in reg_ids:
		var errs: Array = TWUltRegistry.schema_errors(uid)
		chk.call("AT-U02 schema[%s]" % uid, errs.is_empty(), "; ".join(errs))
	chk.call("AT-U02: 100% catalogue coverage (ids == covered == 58)",
		int(cov.ids) == 58 and int(cov.covered) == 58,
		"ids=%d covered=%d" % [int(cov.ids), int(cov.covered)])
	if not items.is_empty():
		chk.call("U12: every G.ITEM outfit is known to TWUltRegistry",
			(cov.unmapped_items as Array).is_empty(),
			"unmapped=%s" % str(cov.unmapped_items))
	return cov


static func _test_negative_schema_guards(chk: Callable) -> void:
	# U04 / SL-ULT-09 palette token grammar rejects forbidden tokens and accepts valid PALETTE_LOCK tokens
	for good_tok in ["mc.H500", "zlata.H300", "JADE.T2", "EMBER.T3", "NEON.T5", "NIGHT_900", "PAPER_100"]:
		chk.call("U04 valid token '%s'" % good_tok, TWUltRegistry.valid_vfx_token(good_tok))
	for bad_tok in ["#ff00ff", "GOLD_500", "GOLD_300", "CINNABAR", "EMBER", "unknown.H500", "mc.H200", "BOGUS.T1", "JADE.T9", ""]:
		chk.call("U04 rejects forbidden token '%s'" % bad_tok, not TWUltRegistry.valid_vfx_token(bad_tok))
	# Synthetic broken catalogue entry must be rejected by schema_errors()
	var orig: Dictionary = TWUltRegistry.catalogue()
	var bad_doc: Dictionary = {
		"trigger_s": 0.8, "release_s": 0.5,
		"tiers": {"BASE": {"len": 3.0, "beats": 8, "poses": 4, "plates": 1, "voice": 3, "impact": 1}},
		"heroes": {"mc": {"ru": "МТ"}},
		"ults": [{
			"id": "bad_ult", "hero": "mc", "tier": "BASE", "slot": "base",
			"name_ru": "LatinOnly", "name_jp": "", "status": "launch", "legacy_outfit": "",
			"hem_class": "upskirt", "cutscene_s": 9.9, "trigger_s": 0.8, "release_s": 0.5,
			"beats_n": 2, "poses_n": 1, "plates_n": 0, "impact_events_max": 9,
			"voice_cues": ["only_one"], "voice": ["TooLong".repeat(8)], "sfx_cues": [],
			"vfx": ["GOLD_500", "#123456"], "twist": "T99",
			"atk_pct_star0": 0.0, "atk_pct_per_star": 0.0, "skin_pack": "", "assets": [],
		}]
	}
	TWUltRegistry.install_catalogue(bad_doc)
	var errs: Array = TWUltRegistry.schema_errors("bad_ult")
	TWUltRegistry.install_catalogue(orig)
	chk.call("U01-U16 negative guard catches broken catalogue entry (%d errors)" % errs.size(), errs.size() >= 10, str(errs))


# ── U11: equipped() fallback, legacy() bidirectional map, injected legacy source ────────────────────────────

static func _test_equipped_and_legacy(chk: Callable) -> void:
	# Canonical lookup + legacy lookup + fallback to <hero>_base
	chk.call("U11 equipped canonical SSR+", TWUltRegistry.equipped("mc", "mc_ssrp_dragonnight") == "mc_ssrp_dragonnight")
	chk.call("U11 equipped legacy o_dragon -> mc_ssrp_dragonnight", TWUltRegistry.equipped("mc", "o_dragon") == "mc_ssrp_dragonnight")
	chk.call("U11 equipped legacy tb_crimson -> tsubame_ssr_ninjarose", TWUltRegistry.equipped("tsubame", "tb_crimson") == "tsubame_ssr_ninjarose")
	chk.call("U11 equipped unmapped outfit o_cozy -> mc_base fallback", TWUltRegistry.equipped("mc", "o_cozy") == "mc_base")
	chk.call("U11 equipped empty outfit -> <hero>_base for all 10 heroines",
		TWUltRegistry.equipped("rin", "") == "rin_base" and TWUltRegistry.equipped("zlata", "") == "zlata_base" and TWUltRegistry.equipped("kohaku", "") == "kohaku_base")
	chk.call("U11 equipped wrong-hero outfit falls back to requested hero's _base",
		TWUltRegistry.equipped("hana", "o_dragon") == "hana_base")
	chk.call("U11 legacy() bidirectional canonical <-> legacy",
		TWUltRegistry.legacy("mc_ssrp_dragonnight") == "o_dragon" and TWUltRegistry.legacy("o_dragon") == "mc_ssrp_dragonnight")
	chk.call("U11 for_hero() returns hero's catalogue entries",
		TWUltRegistry.for_hero("mc").size() == 7 and TWUltRegistry.for_hero("zlata").size() == 6)
	chk.call("U11 core() works for founders and wave-1",
		not TWUltRegistry.core("mc").is_empty() and not TWUltRegistry.core("tsubame").is_empty())
	# Legacy source injection without shell import (and reload_catalogue must preserve registered sources)
	TWUltRegistry.register_legacy_source("synth_test", {"synth_outfit": {"hero": "mc", "name": "Тест"}}, {"synth_hero": {"name": "Ядро"}}, {}, {})
	TWUltRegistry.reload_catalogue()
	chk.call("registry: injected legacy source visible across reload_catalogue via has/legacy_entry/core",
		TWUltRegistry.has("synth_outfit") and str(TWUltRegistry.legacy_entry("synth_outfit").get("name", "")) == "Тест" and str(TWUltRegistry.core("synth_hero").get("name", "")) == "Ядро")
	TWUltRegistry.unregister_legacy_source("synth_test")
	chk.call("registry: unregister removes synthetic legacy source", not TWUltRegistry.has("synth_outfit"))


static func _test_voice_picker_and_limits(chk: Callable) -> void:
	# U03: deterministic non-repeating picker across 40 draws for ALL 58 catalogue ids + globally unique voice_cues
	var rng: = TWRng.make(20261128, 87)
	var bad_ids: Array = []
	var seen_cues: Dictionary = {}
	var dup_cues: Array = []
	for uid in TWUltRegistry.ids():
		var u: Dictionary = TWUltRegistry.entry(uid)
		var cues: Array = u.get("voice_cues", [])
		for c in cues:
			var cs: String = str(c)
			if seen_cues.has(cs):
				dup_cues.append(cs)
			seen_cues[cs] = uid
		var last: = -1
		var ok_id: = true
		for i in 40:
			var idx: = TWUltRegistry.pick_voice_idx(uid, last, rng)
			if idx < 0 or idx >= cues.size() or idx == last:
				ok_id = false
				break
			last = idx
		if not ok_id:
			bad_ids.append(uid)
	chk.call("U03: 40 deterministic voice picks never repeat last across all 58 ids", bad_ids.is_empty(), str(bad_ids))
	chk.call("U03: all voice_cues globally unique across 58 catalogue entries (%d)" % seen_cues.size(), dup_cues.is_empty(), str(dup_cues))
	# U13: cutin safety limits
	chk.call("U13: MAX_FLASHES_PER_S <= 3 and FLASH_MAX <= 0.7",
		V9Ults.MAX_FLASHES_PER_S <= 3 and V9Ults.FLASH_MAX <= 0.7)


# ── AT-U09 / U09: 30-case decision table covering BATTLE_ULT_SPEC §5.11 ─────────────────────────────────────

static func _test_policy_30_cases(chk: Callable) -> void:
	var cases: Array = [
		# [name, seen, settings, last_full_age_s, context, want_mode, want_lock]
		["01 gallery overrides cutin=off & repeat=none", {"mc_base": 5}, {"ult_cutin": "off", "ult_repeat": "none"}, 5.0,
			{"ult_id": "mc_base", "tier": "BASE", "is_gallery": true}, "full", 0.0],
		["02 gallery on first view has 0s skip lock", {}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, -1.0,
			{"ult_id": "mc_base", "tier": "BASE", "is_gallery": true}, "full", 0.0],
		["03 cutin=off on first view -> off", {}, {"ult_cutin": "off", "ult_repeat": "all"}, -1.0,
			{"ult_id": "mc_base", "tier": "SSRP"}, "off", 0.0],
		["04 cutin=off on repeat -> off", {"mc_base": 3}, {"ult_cutin": "off", "ult_repeat": "favorite"}, 100.0,
			{"ult_id": "mc_base", "tier": "SSR"}, "off", 0.0],
		["05 cutin=short on first view -> assist", {}, {"ult_cutin": "short", "ult_repeat": "all"}, -1.0,
			{"ult_id": "mc_base", "tier": "SSRP"}, "assist", 0.0],
		["06 cutin=short on table caps clip <= 0.6s", {"mc_base": 2}, {"ult_cutin": "short"}, 60.0,
			{"ult_id": "mc_base", "tier": "BASE", "is_table": true}, "assist", 0.0],
		["07 first view (seen=0, manual, cutin=full) -> full with 1.0s lock", {}, {"ult_cutin": "full", "ult_repeat": "none"}, 5.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "hero_casts_in_fight": 2}, "full", 1.0],
		["08 first view when seen[id]=0 explicit -> full with 1.0s lock", {"mc_base": 0}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, 10.0,
			{"ult_id": "mc_base", "tier": "BASE"}, "full", 1.0],
		["09 first view in auto-battle -> assist", {}, {"ult_cutin": "full", "ult_repeat": "all"}, -1.0,
			{"ult_id": "mc_base", "tier": "BASE", "is_auto": true}, "assist", 0.0],
		["10 repeat in auto-battle -> assist", {"mc_base": 2}, {"ult_cutin": "full", "ult_repeat": "all"}, 100.0,
			{"ult_id": "mc_base", "tier": "SSRP", "is_auto": true}, "assist", 0.0],
		["11 ranked/duel on first view -> assist", {}, {"ult_cutin": "full", "ult_repeat": "favorite"}, -1.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "is_ranked": true}, "assist", 0.0],
		["12 ranked/duel on favorite SSR+ -> assist", {"mc_ssrp_dragonnight": 2}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 100.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "is_ranked": true}, "assist", 0.0],
		["13 ranked/duel on repeat=all -> assist", {"rin_base": 1}, {"ult_cutin": "full", "ult_repeat": "all"}, 100.0,
			{"ult_id": "rin_base", "tier": "BASE", "is_ranked": true}, "assist", 0.0],
		["14 first_per_fight: 1st cast in fight, no prior full (-1s) -> full", {"rin_base": 1}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, -1.0,
			{"ult_id": "rin_base", "tier": "BASE", "hero_casts_in_fight": 0}, "full", 0.0],
		["15 first_per_fight: 1st cast in fight, 30.0s since last full -> full", {"rin_base": 1}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, 30.0,
			{"ult_id": "rin_base", "tier": "BASE", "hero_casts_in_fight": 0}, "full", 0.0],
		["16 first_per_fight: 1st cast in fight, 29.9s since last full -> assist", {"rin_base": 1}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, 29.9,
			{"ult_id": "rin_base", "tier": "BASE", "hero_casts_in_fight": 0}, "assist", 0.0],
		["17 first_per_fight: 2nd cast of same hero even at 60s -> assist", {"rin_base": 1}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, 60.0,
			{"ult_id": "rin_base", "tier": "BASE", "hero_casts_in_fight": 1}, "assist", 0.0],
		["18 first_per_fight: 1st cast at 0.0s since last full -> assist", {"hana_base": 2}, {"ult_cutin": "full", "ult_repeat": "first_per_fight"}, 0.0,
			{"ult_id": "hana_base", "tier": "BASE", "hero_casts_in_fight": 0}, "assist", 0.0],
		["19 repeat=none: 1st cast in fight, 120s since last full -> assist", {"yue_base": 1}, {"ult_cutin": "full", "ult_repeat": "none"}, 120.0,
			{"ult_id": "yue_base", "tier": "BASE", "hero_casts_in_fight": 0}, "assist", 0.0],
		["20 repeat=all: 2nd cast in fight at 5s -> full", {"nova_base": 4}, {"ult_cutin": "full", "ult_repeat": "all"}, 5.0,
			{"ult_id": "nova_base", "tier": "BASE", "hero_casts_in_fight": 3}, "full", 0.0],
		["21 favorite: SSR 2nd cast in fight at 20.0s -> full", {"rin_ssr_bunnytea": 5}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 20.0,
			{"ult_id": "rin_ssr_bunnytea", "tier": "SSR", "hero_casts_in_fight": 1}, "full", 0.0],
		["22 favorite: SSR 2nd cast in fight at 19.9s -> assist", {"rin_ssr_bunnytea": 5}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 19.9,
			{"ult_id": "rin_ssr_bunnytea", "tier": "SSR", "hero_casts_in_fight": 1}, "assist", 0.0],
		["23 favorite: SSR+ 3rd cast in fight with no prior full -> full", {"mc_ssrp_dragonnight": 8}, {"ult_cutin": "full", "ult_repeat": "favorite"}, -1.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "hero_casts_in_fight": 2}, "full", 0.0],
		["24 favorite: BASE 1st cast at 30.0s falls back to first_per_fight -> full", {"mc_base": 2}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 30.0,
			{"ult_id": "mc_base", "tier": "BASE", "hero_casts_in_fight": 0}, "full", 0.0],
		["25 favorite: BASE 2nd cast at 25.0s falls back to first_per_fight -> assist", {"mc_base": 2}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 25.0,
			{"ult_id": "mc_base", "tier": "BASE", "hero_casts_in_fight": 1}, "assist", 0.0],
		["26 favorite: S-tier 1st cast at 25.0s (<30s) -> assist", {"mc_s_tea": 2}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 25.0,
			{"ult_id": "mc_s_tea", "tier": "S", "hero_casts_in_fight": 0}, "assist", 0.0],
		["27 first_today_outfit overrides repeat=none (hero not full today) -> full", {"mc_s_tea": 4}, {"ult_cutin": "full", "ult_repeat": "none"}, 5.0,
			{"ult_id": "mc_s_tea", "tier": "S", "hero_casts_in_fight": 2, "first_today_outfit": true, "hero_full_today": false}, "full", 0.0],
		["28 first_today_outfit capped at 1/day per heroine -> assist", {"mc_s_tea": 4}, {"ult_cutin": "full", "ult_repeat": "none"}, 5.0,
			{"ult_id": "mc_s_tea", "tier": "S", "hero_casts_in_fight": 2, "first_today_outfit": true, "hero_full_today": true}, "assist", 0.0],
		["29 invalid settings fall back to full + first_per_fight", {"zlata_base": 1}, {"ult_cutin": "bogus", "ult_repeat": "weird"}, 35.0,
			{"ult_id": "zlata_base", "tier": "BASE", "hero_casts_in_fight": 0}, "full", 0.0],
		["30 first_today_outfit does NOT override ranked -> assist", {"mc_s_tea": 4}, {"ult_cutin": "full", "ult_repeat": "none"}, 60.0,
			{"ult_id": "mc_s_tea", "tier": "S", "is_ranked": true, "first_today_outfit": true, "hero_full_today": false}, "assist", 0.0],
		["31 W5 table SSR+ repeat (non-ranked) -> assist highlight 1.5s", {"mc_ssrp_dragonnight": 3}, {"ult_cutin": "full", "ult_repeat": "none"}, 10.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "is_table": true, "is_ranked": false}, "assist", 0.0],
		["32 W5 table SSR+ ranked -> assist short <= 0.6s", {"mc_ssrp_dragonnight": 3}, {"ult_cutin": "full", "ult_repeat": "favorite"}, 60.0,
			{"ult_id": "mc_ssrp_dragonnight", "tier": "SSRP", "is_table": true, "is_ranked": true}, "assist", 0.0],
	]
	chk.call("AT-U09: policy decision table has >= 30 cases", cases.size() >= 30, str(cases.size()))
	for c in cases:
		var got: Dictionary = TWUltPolicy.choose(c[1], c[2], float(c[3]), c[4])
		var ok: bool = str(got.mode) == str(c[5]) and is_equal_approx(float(got.skip_lock_s), float(c[6]))
		if str(c[0]).begins_with("06 ") or str(c[0]).begins_with("32 "):
			ok = ok and float(got.clip_max_s) <= 0.6
		elif str(c[0]).begins_with("31 "):
			ok = ok and is_equal_approx(float(got.clip_max_s), TWUltPolicy.TABLE_SSRP_HIGHLIGHT_S)
		chk.call("AT-U09 [%s]" % str(c[0]), ok, "got=%s want=(%s, %.1f)" % [str(got), str(c[5]), float(c[6])])
	# Defensive check: corrupt seen[id] = null / string must not throw
	var safe_got: Dictionary = TWUltPolicy.choose({"mc_base": null}, {"ult_cutin": "full"}, -1.0, {"ult_id": "mc_base", "tier": "BASE"})
	chk.call("AT-U09: corrupt null seen value treated safely as unseen (first_view)",
		str(safe_got.mode) == "full" and is_equal_approx(float(safe_got.skip_lock_s), 1.0), str(safe_got))


# ── AT-U12 / T17: modular ult_seen + ult_repeat migration (SAVE_VER stays 8, downgrade-safe) ────────────────

static func _test_save_ult_seen_and_downgrade(chk: Callable) -> void:
	var s: Dictionary = {"gems": 500, "unlocked": 10, "stars": {}, "owned": {}, "ver": TWMigrate.SAVE_VER}
	var rep1: Dictionary = TWUltRegistry.ensure_save(s)
	chk.call("AT-U12: ensure_save adds ult_seen, ult_repeat, mod_ver.battle without bumping SAVE_VER",
		int(s.ver) == 8 and s.ult_seen is Dictionary and str(s.ult_repeat) == "first_per_fight" and int(s.mod_ver.battle) == 1 and (rep1.added as Array).size() == 3,
		str(rep1))
	var rep2: Dictionary = TWUltRegistry.ensure_save(s)
	chk.call("AT-U12: ensure_save is idempotent", (rep2.added as Array).is_empty(), str(rep2))
	var n1: int = TWUltPolicy.record_seen(s, "mc_ssrp_dragonnight")
	var n2: int = TWUltPolicy.record_seen(s, "mc_ssrp_dragonnight")
	chk.call("AT-U12: record_seen increments ult_seen counter", n1 == 1 and n2 == 2 and TWUltPolicy.seen_count(s, "mc_ssrp_dragonnight") == 2)
	# Repair corrupt values while keeping valid entries (including null mod_ver.battle)
	s["ult_seen"]["bad_entry"] = "not_a_num"
	s["ult_seen"]["neg_entry"] = -5
	s["ult_seen"]["null_entry"] = null
	s["ult_repeat"] = "invalid_mode"
	s["mod_ver"]["battle"] = null
	TWUltRegistry.ensure_save(s)
	chk.call("AT-U12: ensure_save repairs invalid ult_seen/ult_repeat/mod_ver while preserving valid counts",
		not s.ult_seen.has("bad_entry") and not s.ult_seen.has("null_entry") and int(s.ult_seen.neg_entry) == 0 and int(s.ult_seen.mc_ssrp_dragonnight) == 2 and str(s.ult_repeat) == "first_per_fight" and int(s.mod_ver.battle) == 1)
	# T17 downgrade check: an older client checking SAVE_VER=8 accepts the save (not "future")
	var mc: Dictionary = TWMigrate.check(s)
	chk.call("T17 downgrade: save with ult_seen/mod_ver.battle passes TWMigrate.check (SAVE_VER=8)",
		bool(mc.ok) and int(mc.ver) == 8, str(mc))
