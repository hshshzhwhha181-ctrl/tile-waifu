class_name V10StaminaSelftest
extends Node

# Standalone & registry selftest for Thread 4 (economy-monetize):
# Tests V10Stamina (regen math, rank cap scaling, spend/refund, level costs, escalating refills,
# daily kettle windows, HUD pill) and V10AffCurve + G.aff_level (heavy exponential curve Lv 1–20,
# 16+ milestones, boss gift drops, and Shop gift purchases).

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

	_test_stamina_caps_and_regen(t0)
	_test_costs_spend_and_refund(t0)
	_test_escalating_refills(t0)
	_test_kettle_windows()
	_test_affection_curve_and_milestones()
	_test_gifts_and_live_g()
	_test_hud_pill()

	V10Stamina.unbind_root()
	V10AffCurve.unbind_root()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	V10Meta.unbind()

	print("STAMINA_SELFTEST %d/%d" % [ok, total])
	return total - ok


func _test_stamina_caps_and_regen(t0: int) -> void:
	var root: = {"rp": 0, "gems": 1000}
	V10Meta.set_now(t0)
	V10Stamina.bind_root(root)
	var st: Dictionary = root["v10_stamina"]
	for k in ["cur", "max", "last_ts", "refills_today", "refill_day", "kettle_noon_day", "kettle_eve_day"]:
		_check(st.has(k), "v10_stamina has key '%s'" % k)
	_check(V10Stamina.cap() == 120 and V10Stamina.current() == 120, "base cap & initial tea = 120")
	_check(V10Stamina.next_regen_sec() == 0, "full bar has next_regen_sec == 0")

	# Rank tier scaling (+5 per rank tier: Bamboo 3*60 = 180 -> tier 1 Jade -> 125; +3*100 = 480 -> tier 2 Pearl -> 130)
	root["rp"] = 180
	_check(V10Stamina.cap() == 125, "tier 1 rank scales cap to 125")
	root["rp"] = 480
	_check(V10Stamina.cap() == 130, "tier 2 rank scales cap to 130")
	root["rp"] = 0
	st["cur"] = 120
	_check(V10Stamina.cap() == 120, "tier 0 cap = 120")

	# Spend 10 -> starts 360s regen timer
	_check(V10Stamina.spend(10, "test_path"), "spend(10) succeeds")
	_check(V10Stamina.current() == 110, "cur == 110 after spend(10)")
	_check(V10Stamina.next_regen_sec() == 360, "next_regen_sec == 360 immediately after dropping below cap")

	V10Meta.set_now(t0 + 179)
	_check(V10Stamina.current() == 110 and V10Stamina.next_regen_sec() == 181, "at +179s: still 110, 181s left")

	V10Meta.set_now(t0 + 360)
	_check(V10Stamina.current() == 111 and V10Stamina.next_regen_sec() == 360, "at +360s: +1 regenerated -> 111")

	V10Meta.set_now(t0 + 360 * 6 + 90)
	_check(V10Stamina.current() == 116 and V10Stamina.next_regen_sec() == 270, "at +6*360+90s: cur == 116, remainder 270s preserved")

	# Clock rollback never subtracts tea
	V10Meta.set_now(t0)
	_check(V10Stamina.current() == 116, "clock rollback does not lose tea")

	# Full cap stop + overfill preservation
	V10Meta.set_now(t0 + 20000)
	_check(V10Stamina.current() == 120 and V10Stamina.next_regen_sec() == 0, "regen stops cleanly at cap 120")
	_check(V10Stamina.grant(200) == 200 and V10Stamina.current() == 320, "grant(200) overfills to 320")
	V10Meta.set_now(t0 + 25000)
	_check(V10Stamina.current() == 320 and V10Stamina.next_regen_sec() == 0, "overfilled tea is preserved across ticks")


func _test_costs_spend_and_refund(t0: int) -> void:
	V10Meta.set_now(t0)
	var root: = {"rp": 0, "gems": 500}
	V10Stamina.bind_root(root)

	for lv in range(1, 6):
		_check(V10Stamina.cost_for_level(lv) == 0, "onboarding level %d costs 0 tea" % lv)
	for lv in [6, 7, 8, 9, 11, 24]:
		_check(V10Stamina.cost_for_level(lv) == 6, "normal Path level %d costs 6 tea" % lv)
	for lv in [10, 20, 30, 100]:
		_check(V10Stamina.cost_for_level(lv) == 12, "boss Path level %d costs 12 tea" % lv)
	_check(V10Stamina.cost_for_level(1, "adventure") == 15 and V10Stamina.cost_for_adventure_boss() == 15, "Adventure boss costs 15 tea")

	# Adventure boss spend 15 + defeat refund 10 -> net 5 spent
	var before: = V10Stamina.current()
	_check(V10Stamina.spend(V10Stamina.cost_for_adventure_boss(), "adv_boss"), "spend 15 for Adventure boss")
	_check(V10Stamina.current() == before - 15, "tea reduced by 15 on Adventure boss entry")
	V10Stamina.refund_adventure_defeat()
	_check(V10Stamina.current() == before - 5, "defeat refunds +10 tea (net -5)")

	# Insufficient stamina check
	root["v10_stamina"]["cur"] = 5
	_check(not V10Stamina.can_spend(6) and not V10Stamina.spend(6, "normal"), "cannot spend 6 when cur == 5")
	_check(V10Stamina.can_spend(0) and V10Stamina.spend(0, "onboarding"), "onboarding 0-cost always succeeds even at low tea")


func _test_escalating_refills(t0: int) -> void:
	V10Meta.bind({})
	V10Meta.set_tz(180)
	V10Meta.set_now(t0)
	var root: = {"rp": 0, "gems": 450}
	V10Stamina.bind_root(root)
	root["v10_stamina"]["cur"] = 20

	var expected: = [50, 80, 120, 180]
	for i in expected.size():
		_check(V10Stamina.refill_price() == expected[i], "refill #%d price == %d" % [i + 1, expected[i]])
		_check(V10Stamina.buy_refill(), "buy_refill #%d succeeds" % (i + 1))
	_check(int(root["gems"]) == 450 - (50 + 80 + 120 + 180), "4 refills spent exact 430 gems (20 left)")
	_check(V10Stamina.current() == 20 + 80 * 4, "4 refills added +320 tea")
	_check(V10Stamina.refill_price() == 180, "5th refill price clamps at 180")
	_check(not V10Stamina.buy_refill(), "refill fails cleanly when gems (20) < 180")
	_check(V10Stamina.refills_today() == 4, "failed refill does not increment refills_today")

	# Next day at 04:05 resets escalating cost back to 50
	V10Meta.set_now(_lt("2026-11-27T04:05:00"))
	_check(V10Stamina.refills_today() == 0 and V10Stamina.refill_price() == 50, "daily reset returns refill_price to 50")


func _test_kettle_windows() -> void:
	V10Meta.bind({})
	V10Meta.set_tz(180)
	var root: = {"rp": 0, "gems": 100}
	V10Meta.set_now(_lt("2026-11-26T10:30:00"))
	V10Stamina.bind_root(root)
	root["v10_stamina"]["cur"] = 40

	_check(not V10Stamina.kettle_ready() and not V10Stamina.claim_kettle(), "10:30 outside kettle window -> not ready")

	V10Meta.set_now(_lt("2026-11-26T12:15:00"))
	var c_noon: = V10Stamina.current()
	_check(V10Stamina.kettle_ready(), "12:15 noon kettle ready")
	_check(V10Stamina.claim_kettle() and V10Stamina.current() == c_noon + 60, "noon kettle grants +60 tea")
	_check(not V10Stamina.kettle_ready() and not V10Stamina.claim_kettle(), "noon kettle cannot be claimed twice same day")

	V10Meta.set_now(_lt("2026-11-26T16:30:00"))
	_check(not V10Stamina.kettle_ready(), "16:30 between windows -> not ready")

	V10Meta.set_now(_lt("2026-11-26T19:00:00"))
	var c_eve: = V10Stamina.current()
	_check(V10Stamina.kettle_ready(), "19:00 evening kettle ready")
	_check(V10Stamina.claim_kettle() and V10Stamina.current() == c_eve + 60, "evening kettle grants +60 tea")
	_check(not V10Stamina.kettle_ready(), "evening kettle cannot be claimed twice same day")

	V10Meta.set_now(_lt("2026-11-26T23:10:00"))
	_check(not V10Stamina.kettle_ready(), "23:10 after evening window -> not ready")

	V10Meta.set_now(_lt("2026-11-27T12:30:00"))
	_check(V10Stamina.kettle_ready(), "next day 12:30 noon kettle ready again")


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


func _test_hud_pill() -> void:
	var root: = {"rp": 0, "gems": 100}
	V10Stamina.bind_root(root)
	var pill: = V10Stamina.make_pill(null)
	add_child(pill)
	_check(pill != null and pill.size == Vector2(156, 48), "V10Stamina.make_pill builds 156x48 HUD pill")
	pill.queue_free()
