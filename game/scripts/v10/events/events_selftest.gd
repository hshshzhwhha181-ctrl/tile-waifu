class_name V10EventsSelftest
extends Node

# EVENTS_SELFTEST (0.12.0): Welcome-7 (days 1..7, one claim per day, SSR -> 1600 crystals), Lucky Wheel (free/paid spins,
# 8 sectors, daily limit) and the 16+ boudoir dates (8 goddesses, branching, daily reward limit) + UI smoke builds.

var ok: = 0
var total: = 0
var fails: Array = []
var _day: = 0
const T0: = 1796000000


func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL: ", what)


func _ready() -> void:
	run_all()
	get_tree().quit(0 if ok == total else 1)


func _set_day(k: int) -> void:
	_day = k
	V10Meta.set_now(T0 + k * 86400)


func _fresh() -> void:
	G.S = G.default_state()
	V10Meta.bind({})
	V10Meta.set_tz(180)
	_set_day(0)


func run_all() -> int:
	ok = 0
	total = 0
	fails.clear()
	_test_welcome7()
	_test_wheel()
	_test_dates()
	_test_ui()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	V10Meta.unbind()
	print("EVENTS_SELFTEST %d/%d" % [ok, total])
	return total - ok


func _test_welcome7() -> void:
	_fresh()
	_check(V10Welcome7Screen.can_claim_today() and V10Welcome7Screen.is_active(), "w7: new player can claim day 1")
	var g0: = V10Money.bal("gems")
	var t0: = V10Money.bal("tickets")
	var tea0: = V10Stamina.current()
	var r1: = V10Welcome7Screen.claim_today()
	_check(bool(r1.ok) and int(r1.day) == 1 and V10Money.bal("tickets") == t0 + 10, "w7: day 1 = +10 wish tickets")
	var r1b: = V10Welcome7Screen.claim_today()
	_check(not bool(r1b.ok) and not V10Welcome7Screen.can_claim_today() and V10Money.bal("tickets") == t0 + 10, "w7: second claim the same day is refused")
	_set_day(1)
	var r2: = V10Welcome7Screen.claim_today()
	_check(bool(r2.ok) and V10Money.bal("gems") == g0 + 300 and V10Stamina.current() >= tea0 + 200, "w7: day 2 = +200 tea +300 crystals")
	_set_day(2)
	V10Welcome7Screen.claim_today()
	_check(V10AffCurve.gift_count("gift_silk_fan") == 1, "w7: day 3 = Silk Fan gift")
	_set_day(3)
	V10Welcome7Screen.claim_today()
	_check(V10Money.bal("gems") == g0 + 800, "w7: day 4 = +500 crystals")
	_set_day(4)
	V10Welcome7Screen.claim_today()
	_check(V10Money.bal("tickets") == t0 + 15, "w7: day 5 = +5 wish tickets")
	_set_day(5)
	V10Welcome7Screen.claim_today()
	_check(V10AffCurve.gift_count("gift_jade_pin") == 1, "w7: day 6 = Jade Hairpin gift")
	_check(not G.owns("o_dragon"), "w7: SSR not given before day 7")
	_set_day(6)
	var r7: = V10Welcome7Screen.claim_today()
	_check(bool(r7.ok) and int(r7.day) == 7 and G.owns("o_dragon") and not bool(r7.converted), "w7: day 7 = SSR outfit Dragon Empress")
	_check(not V10Welcome7Screen.is_active() and V10Welcome7Screen.days_claimed() == 7, "w7: all 7 claimed -> inactive")
	_set_day(7)
	_check(not V10Welcome7Screen.can_claim_today() and not bool(V10Welcome7Screen.claim_today().ok), "w7: nothing to claim after day 7")
	var st: = V10Welcome7Screen.state()
	_check(str(st.start_day_key) != "" and str(st.last_day_key) != "", "w7: save has start_day_key and last_day_key")
	# SSR already owned -> 1600 crystals
	_fresh()
	G.S.owned["o_dragon"] = true
	V10Welcome7Screen.state()["days_claimed"] = 6
	var gg: = V10Money.bal("gems")
	var rc: = V10Welcome7Screen.claim_today()
	_check(bool(rc.ok) and bool(rc.converted) and V10Money.bal("gems") == gg + 1600, "w7: owned SSR converts to 1600 crystals")


func _test_wheel() -> void:
	_fresh()
	V10Money.grant({"gems": 1000}, "test")
	_check(V10LuckyWheelScreen.SECTORS.size() == 8, "wheel: 8 sectors")
	_check(V10LuckyWheelScreen.free_spin_ready() and V10LuckyWheelScreen.next_cost() == 0, "wheel: free spin ready, cost 0")
	var c0: = V10Money.bal("coins")
	var r: = V10LuckyWheelScreen.spin(5)
	_check(bool(r.ok) and bool(r.free) and V10Money.bal("coins") == c0 + 1500 and int(r.cost) == 0, "wheel: free spin pays sector 6 (1 500 coins)")
	_check(not V10LuckyWheelScreen.free_spin_ready() and V10LuckyWheelScreen.next_cost() == 80, "wheel: next spin costs 80")
	var g1: = V10Money.bal("gems")
	var rp: = V10LuckyWheelScreen.spin(0)
	_check(bool(rp.ok) and not bool(rp.free) and V10Money.bal("gems") == g1 - 80 + 300, "wheel: paid spin -80 +300 crystals")
	for i in 4:
		V10LuckyWheelScreen.spin(4)
	_check(V10LuckyWheelScreen.paid_left() == 0, "wheel: 5 paid spins used")
	var rl: = V10LuckyWheelScreen.spin(0)
	_check(not bool(rl.ok) and str(rl.reason) == "limit" and not V10LuckyWheelScreen.can_spin(), "wheel: daily paid limit blocks the 6th")
	_set_day(1)
	_check(V10LuckyWheelScreen.free_spin_ready() and V10LuckyWheelScreen.paid_left() == 5, "wheel: next day resets free spin and limit")
	# poor player cannot pay
	_fresh()
	G.S["gems"] = 10
	V10LuckyWheelScreen.spin(2)
	var rg: = V10LuckyWheelScreen.spin(2)
	_check(not bool(rg.ok) and str(rg.reason) == "gems", "wheel: not enough crystals refused")
	# distribution over the 8 sectors (evenly spaced r = exact weights)
	var counts: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var n: = 9800
	for i in n:
		counts[V10LuckyWheelScreen.pick_sector((float(i) + 0.5) / float(n))] += 1
	var all_hit: = true
	for c in counts:
		if int(c) <= 0:
			all_hit = false
	_check(all_hit, "wheel: all 8 sectors reachable " + str(counts))
	_check(int(counts[5]) > int(counts[4]) and int(counts[4]) > int(counts[0]) and int(counts[7]) < int(counts[1]), "wheel: weights ordered (coins > 150 > 300, jackpot rarest)")
	var jp: = V10LuckyWheelScreen.SECTORS[7]
	_check(bool(jp.get("jackpot", false)) and int(jp.gems) == 800, "wheel: sector 8 is the 800 crystal jackpot")
	# every sector pays what its label says
	_fresh()
	var g2: = V10Money.bal("gems")
	var tk: = V10Money.bal("tickets")
	var tea: = V10Stamina.current()
	V10LuckyWheelScreen.apply_reward(0)
	V10LuckyWheelScreen.apply_reward(1)
	V10LuckyWheelScreen.apply_reward(2)
	V10LuckyWheelScreen.apply_reward(3)
	V10LuckyWheelScreen.apply_reward(4)
	V10LuckyWheelScreen.apply_reward(6)
	V10LuckyWheelScreen.apply_reward(7)
	_check(V10Money.bal("gems") == g2 + 300 + 150 + 800 and V10Money.bal("tickets") == tk + 2 and V10Stamina.current() >= tea + 80, "wheel: crystals / tickets / tea sectors pay")
	_check(V10AffCurve.gift_count("gift_silk_fan") == 1 and V10AffCurve.gift_count("gift_jade_pin") == 1, "wheel: gift sectors pay")


func _test_dates() -> void:
	_fresh()
	var S: Array = V10VipBoudoirScreen.SUITES
	_check(S.size() == 10, "dates: 10 goddess suites")
	var ids: = {}
	var complete: = true
	for s in S:
		ids[String(s.hero)] = true
		var h: = String(s.hero)
		if not (V10VipDate.PREF.has(h) and V10VipDate.PLACE.has(h) and V10VipDate.REACT.has(h)):
			complete = false
		if V10VipBoudoirScreen.cg_texture(h) == null:
			complete = false
	_check(ids.size() == 10 and complete, "dates: 10 unique heroes, each with prefs/reactions/CG fallback")
	for h in ["kohaku", "shirin", "tsubame", "zlata", "hana", "miel"]:
		_check(ids.has(h), "dates: goddess " + h)
	_check(V10VipDate.unlocked_levels(1) == [1] and V10VipDate.unlocked_levels(6) == [1, 2, 4, 6] and V10VipDate.unlocked_levels(4) == [1, 2, 4], "dates: levels 1/2/4/6 unlock by affection")
	var texts_ok: = true
	for lvn in [1, 2, 4, 6]:
		for step in 3:
			for fp in [0, 2]:
				var b: = V10VipDate.build_step(lvn, step, "kohaku", "Кохаку", 50, fp)
				if String(b.prompt) == "" or "{" in String(b.prompt) or b.choices.size() != 3:
					texts_ok = false
				for c in b.choices:
					if String(c.text) == "":
						texts_ok = false
	_check(texts_ok, "dates: all 4 levels x 3 steps have prompts and 3 choices")
	var best: = V10VipDate.simulate("zlata", 1, ["bold", "sweet", "bold"])
	var worst: = V10VipDate.simulate("zlata", 1, ["tease", "tease", "tease"])
	_check(int(best.spark) >= 74 and int(best.rank) >= 1 and int(worst.rank) == 0 and int(best.spark) > int(worst.spark), "dates: choices change the spark and the ending rank")
	var top: = V10VipDate.simulate("mc", 6, ["bold", "bold", "bold"])
	_check(int(top.spark) == 100 and int(top.rank) == 2, "dates: perfect date = spark 100, rank 2")
	var warm: = V10VipDate.simulate("rin", 2, ["tease", "sweet", "sweet"])
	var cold: = V10VipDate.simulate("rin", 2, ["bold", "sweet", "sweet"])
	_check(String(warm.nodes[1]) == "s2w" and String(cold.nodes[1]) == "s2c" and String(warm.nodes[2]).ends_with(":hot") and not String(cold.nodes[2]).ends_with(":hot"), "dates: branching (warm/cool step 2, hot/cool step 3)")
	# daily reward limit per heroine
	var a0: = int(G.S.aff.get("kohaku", 0))
	var g0: = V10Money.bal("gems")
	var c1: = V10VipDate.claim("kohaku", 1, 80)
	_check(bool(c1.ok) and int(G.S.aff.get("kohaku", 0)) == a0 + 60 and V10Money.bal("gems") == g0 + 30, "dates: reward = +60 affection +30 crystals")
	_check(V10AffCurve.gift_count("gift_tea_set") == 1, "dates: rank-3 teaser also gives a Tea Set")
	var c2: = V10VipDate.claim("kohaku", 1, 80)
	_check(not bool(c2.ok) and int(G.S.aff.get("kohaku", 0)) == a0 + 60 and not V10VipDate.reward_available("kohaku"), "dates: second reward the same day is refused")
	_check(V10VipDate.reward_available("shirin") and bool(V10VipDate.claim("shirin", 4, 10).ok) and V10AffCurve.gift_count("gift_silk_fan") == 1, "dates: other heroine still pays; level 4 gives Silk Fan")
	_set_day(1)
	_check(V10VipDate.reward_available("kohaku"), "dates: reward resets the next day")


func _test_ui() -> void:
	_fresh()
	G.S["aff"]["kohaku"] = 4000
	var scr: = V10VipBoudoirScreen.new()
	scr.size = Vector2(720, 1600)
	add_child(scr)
	scr.build(null, {"hero": "kohaku"})
	var has_scroll: = false
	for n in scr.find_children("*", "ScrollContainer", true, false):
		has_scroll = true
	_check(has_scroll and scr._tab_btns.size() == 10 and scr._idx == 4, "ui: boudoir has 10 tabs in a ScrollContainer, opens on the requested goddess")
	_check(scr._cg_tex != null and scr._cg_tex.visible and scr._cg_tex.texture != null, "ui: boudoir shows the heroine 16+ CG")
	_check(scr._date_btn != null and scr._date_btn.get_parent() != null, "ui: boudoir has the Date 16+ button")
	scr._open_date()
	var win: V10VipDateWindow = scr._date_win
	_check(win != null and win.phase == "select" and win.lv == 6, "ui: date window opens on the highest unlocked level")
	win._start()
	for i in 3:
		win._pick(1)
		win._after_react()
	_check(win.phase == "end" and win.spark > 0 and win.step == 3, "ui: 3 picks end the date")
	var rl: Label = Label.new()
	win._claim(rl)
	_check(not V10VipDate.reward_available("kohaku") and rl.text.begins_with("Получено"), "ui: finale claims the reward once")
	rl.free()
	scr.queue_free()
	var w7: = V10Welcome7Screen.new()
	w7.size = Vector2(720, 1600)
	add_child(w7)
	w7.build(null, {})
	_check(w7._cards.size() == 7 and w7._day_state(1) == "today", "ui: welcome7 shows 7 cards, day 1 is today")
	w7._do_claim()
	_check(w7._day_state(1) == "claimed" and not V10Welcome7Screen.can_claim_today(), "ui: welcome7 claim marks day 1 claimed")
	w7.queue_free()
	var wh: = V10LuckyWheelScreen.new()
	wh.size = Vector2(720, 1600)
	add_child(wh)
	wh.build(null, {})
	wh._on_spin()
	_check(wh._spinning and not V10LuckyWheelScreen.free_spin_ready(), "ui: wheel spins and consumes the free spin")
	wh.queue_free()
