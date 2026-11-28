class_name V10AffectionSelftest
extends Node

# Standalone & registry selftest: V10AffCurve + G.aff_level (heavy exponential curve Lv 1–20,
# 16+ milestones, boss gift drops, and Shop gift purchases). (The energy / «Чашки чая» tests were
# removed in P08: there is no energy in 1.1.)

var ok: = 0
var total: = 0
var fails: Array = []


func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL: ", what)


func _lt(iso: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(iso)) - V10Meta.tz_bias_min() * 60


func _ready() -> void:
	run_all()
	get_tree().quit(0 if ok == total else 1)


func run_all() -> int:
	ok = 0
	total = 0
	fails.clear()

	V10Meta.bind({})
	V10Meta.set_tz(180)
	var t0: = _lt("2026-11-26T09:00:00")
	V10Meta.set_now(t0)

	_test_affection_curve_and_milestones()
	_test_gifts_and_live_g()

	V10AffCurve.unbind_root()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	V10Meta.unbind()

	print("AFFECTION_SELFTEST %d/%d" % [ok, total])
	return total - ok


func _test_affection_curve_and_milestones() -> void:
	var head10: = [120, 260, 480, 800, 1300, 2000, 3000, 4400, 6200, 8500]
	for i in head10.size():
		_check(V10AffCurve.need_for_level(i + 1) == head10[i], "need_for_level(%d) == %d" % [i + 1, head10[i]])
	var mono: = true
	for lv in range(2, V10AffCurve.MAX_LEVEL + 1):
		if V10AffCurve.need_for_level(lv) <= V10AffCurve.need_for_level(lv - 1):
			mono = false
	_check(mono, "heavy curve strictly increases across levels 1..20")

	_check(V10AffCurve.level_for_xp(0) == 1 and V10AffCurve.level_for_xp(119) == 1, "0..119 XP stays Level 1")
	_check(V10AffCurve.level_for_xp(120) == 2 and V10AffCurve.level_for_xp(379) == 2, "120..379 XP is Level 2")
	_check(V10AffCurve.level_for_xp(380) == 3, "380 XP (120+260) reaches Level 3")
	_check(V10AffCurve.level_for_xp(V10AffCurve.total_xp_for_level(10)) == 10, "total_xp_for_level(10) reaches Level 10")
	_check(V10AffCurve.level_for_xp(V10AffCurve.total_xp_for_level(20) + 5000) == 20, "caps cleanly at Level 20")

	for mlv in [2, 4, 6, 8, 10]:
		_check(V10AffCurve.MILESTONES.has(mlv), "milestone defined at Level %d" % mlv)
	_check(bool(V10AffCurve.milestone_at(2).get("tag_16", false)) and bool(V10AffCurve.milestone_at(6).get("tag_16", false)) and bool(V10AffCurve.milestone_at(10).get("tag_16", false)),
		"16+ intimate milestones active at Levels 2, 6, and 10")
	var b10: = V10AffCurve.bonuses_for_level(10)
	_check(float(b10.atk_bonus) > 0.25 and float(b10.crit_bonus) > 0.10 and float(b10.ult_haste) > 0.05,
		"Level 10 cumulative Adventure/Ult bonuses active")


func _test_gifts_and_live_g() -> void:
	var root: = {"coins": 2000, "gems": 500, "aff": {"mc": 0, "yue": 0}}
	V10AffCurve.bind_root(root)

	_check(V10AffCurve.GIFTS.size() == 3, "3 affection gift tiers registered")
	var dropped: = V10AffCurve.award_boss_gift(2)
	_check(dropped == "gift_silk_fan" and V10AffCurve.gift_count("gift_silk_fan") == 1, "boss tier 2 awards Silk Fan (+120)")

	var r_inv: = V10AffCurve.buy_and_give_gift("gift_silk_fan", "mc")
	_check(bool(r_inv.ok) and String(r_inv.source) == "inventory" and int(r_inv.new_level) == 2,
		"giving owned Silk Fan (+120) reaches Level 2 without spending currency")
	_check(int(r_inv.milestone.get("level", 0)) == 2, "Level 2 milestone returned on level-up")

	var r_coin: = V10AffCurve.buy_and_give_gift("gift_tea_set", "yue")
	_check(bool(r_coin.ok) and int(root.coins) == 1200 and V10AffCurve.hero_xp("yue") == 40,
		"Tea Set spends 800 coins and grants +40 affection")

	var r_jade: = V10AffCurve.buy_and_give_gift("gift_jade_pin", "yue")
	_check(bool(r_jade.ok) and int(root.gems) == 300 and V10AffCurve.hero_xp("yue") == 340 and V10AffCurve.hero_level("yue") == 2,
		"Jade Hairpin spends 200 gems and grants +300 affection (-> 340 XP, Lv 2)")

	# Verify live G.aff_level delegates to V10AffCurve
	V10AffCurve.unbind_root()
	if G != null and G.get("S") is Dictionary:
		var prev_aff: = int(G.S.aff.get("mc", 0))
		G.S.aff["mc"] = 380
		_check(G.aff_level("mc") == 3, "G.aff_level('mc') uses heavy V10AffCurve (380 XP -> Lv 3)")
		G.S.aff["mc"] = prev_aff

