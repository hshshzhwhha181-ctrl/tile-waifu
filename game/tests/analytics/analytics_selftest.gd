class_name TWAnalyticsSelftest
extends Node

# P106: Selftest for pure core analytics (TWAnalyticsSchema + TWAnalyticsBuffer).
# Run:
#   godot --headless --path game res://tests/analytics/analytics_selftest.tscn
# Prints "ANALYTICS_SELFTEST ok/total" and exits 0 when all checks pass.

var _pass: = 0
var _fail: = 0


func _ready() -> void:
	if get_tree().current_scene == self:
		await get_tree().process_frame
		var r: Array = run()
		get_tree().quit(0 if r[0] == r[1] else 1)


func check(label: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", label)
	else:
		_fail += 1
		printerr("FAIL ", label, " ", info)


func run() -> Array:
	_test_all_catalog_events()
	_test_envelope_and_enum_rejections()
	_test_pii_and_ethics_guards()
	_test_buffer_consent_and_batching()
	_test_econ_bucketing_and_determinism()
	var total: = _pass + _fail
	print("ANALYTICS_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


func _mk_buf(consent: bool = true) -> TWAnalyticsBuffer:
	var b: = TWAnalyticsBuffer.new()
	b.configure_session("u_pseudo_001", "sess_001", {
		"app_ver": "0.12.0",
		"build": "rustore",
		"lang": "ru",
		"tier": "standard",
		"age_ok": true,
		"conn": "wifi",
		"analytics_consent": consent,
	})
	return b


func _sample_params() -> Dictionary:
	return {
		"app_open": {"src": "organic"},
		"session_start": {"src": "organic"},
		"session_end": {"dur_s": 420},
		"age_gate_result": {"ok": true, "birth_year_bucket": "1995_1999", "tier_toggle": "standard"},
		"account_link": {"provider": "vk"},
		"ftue_step": {"step": "first_win", "t_s": 42},
		"level_end": {"mode": "path", "level": 5, "win": true, "dur_s": 55, "pairs": 18},
		"wish_banner_view": {"banner_id": "first_guest", "family": "standard", "k": 10, "g": 0, "c": 0},
		"odds_open": {"banner_id": "first_guest", "odds_hash": "sha256_abc"},
		"history_open": {"banner_id": "first_guest", "odds_hash": "sha256_abc"},
		"preview_open": {"skin_id": "akari_silk", "from": "banner"},
		"wish_confirm_open": {"banner_id": "first_guest", "n": 10, "cost": 1500, "pay_from": "gems", "limit_left": 5000},
		"wish_pull": {
			"banner_id": "first_guest",
			"family": "standard",
			"idx": 1,
			"k_before": 29,
			"g_before": 0,
			"c_before": 0,
			"result": "ssr",
			"item_id": "akari_silk",
			"featured": true,
			"candle": false,
			"cost_cur": "gems",
			"cost_amt": 150,
			"odds_hash": "sha256_abc",
			"seed_commit": "commit_01",
		},
		"wish_series_end": {"n": 10, "ssr_count": 1, "spent_rub_equiv": 380},
		"store_open": {"section": "main"},
		"sku_view": {"section": "packs", "sku_id": "jade_pass_199", "price_rub": 199, "wishes_equiv": 5},
		"purchase_start": {"sku_id": "jade_pass_199", "price_rub": 199, "method": "sbp", "purchase_id": "p_001"},
		"purchase_ok": {"sku_id": "jade_pass_199", "price_rub": 199, "method": "sbp", "purchase_id": "p_001"},
		"purchase_fail": {"sku_id": "jade_pass_199", "price_rub": 199, "method": "sbp", "purchase_id": "p_002", "err": "sdk_timeout"},
		"purchase_cancel": {"sku_id": "jade_pass_199", "price_rub": 199, "method": "card", "purchase_id": "p_003"},
		"purchase_pending": {"sku_id": "jade_pass_199", "price_rub": 199, "method": "sberpay", "purchase_id": "p_004"},
		"purchase_refund": {"sku_id": "jade_pass_199", "amount": 199, "debt_after": 0, "days_since": 2},
		"moon_balance_audit": {"ok": true, "delta": 0},
		"limit_choice_shown": {"type": "monthly_rub"},
		"limit_set": {"value": 3000, "prev": 0, "type": "monthly_rub"},
		"limit_hit": {"value": 3000, "type": "monthly_rub"},
		"pause_set": {"value": 7, "type": "days"},
		"cooldown_prompt": {"type": "spend_spike"},
		"cooldown_accept": {"type": "spend_spike"},
		"rank_up": {"from": 1, "to": 2},
		"pass_view": {"season": "s1"},
		"pass_buy": {"season": "s1", "line": "prem"},
		"pass_step_claim": {"season": "s1", "line": "free", "step": 10},
		"fund_buy": {"fund_id": "path_fund_1"},
		"fund_claim": {"fund_id": "path_fund_1", "milestone": 20},
		"skin_equip": {"skin_id": "akari_silk", "tier": "ssr", "hud_level": 2},
		"skin_dye": {"skin_id": "akari_silk", "tier": "ssr"},
		"star_up": {"skin_id": "akari_silk", "star": 2},
		"ult_play": {"skin_id": "akari_silk", "variant": "full"},
		"direct_sale_open": {"skin_id": "akari_silk", "day": 14},
		"bond_level_up": {"hero": "akari", "lv": 5},
		"ad_offer": {"placement": "daily_bonus"},
		"ad_watch": {"placement": "daily_bonus"},
		"ad_reward": {"placement": "daily_bonus", "ecpm_bucket": "200_300"},
		"ad_complaint": {"placement": "daily_bonus"},
		"event_shop_buy": {"event_id": "lantern_fest", "cur": "tokens", "amt": 50},
		"event_points": {"event_id": "lantern_fest", "cur": "points", "amt": 120},
		"econ_snapshot": {"gems": "500_1499", "tickets": "1_99", "moon": "0", "petals": "1_99", "coins": "1500_4999"},
		"crash": {"stack_hash": "deadbeef01"},
		"anr": {"stack_hash": "deadbeef02"},
	}


func _test_all_catalog_events() -> void:
	var names: PackedStringArray = TWAnalyticsSchema.all_event_names()
	var samples: Dictionary = _sample_params()
	check("catalog: covers >= 45 MP §7.4 events (actual %d)" % names.size(), names.size() >= 45 and samples.size() == names.size(), "names=%d samples=%d" % [names.size(), samples.size()])

	var buf: = _mk_buf(true)
	var bad: Array = []
	var ts: int = 1764300000000
	for n in names:
		var ev_name: String = str(n)
		if not TWAnalyticsSchema.is_snake_case(ev_name):
			bad.append("not_snake:" + ev_name)
		var res: Dictionary = buf.record(ev_name, samples.get(ev_name, {}), ts)
		ts += 1000
		if not bool(res.ok):
			bad.append("%s:%s" % [ev_name, str(res.errors)])
	check("catalog: every MP §7.4 event validates and enqueues cleanly", bad.is_empty(), str(bad))
	check("catalog: schema_export matches event count", int(TWAnalyticsSchema.schema_export().event_count) == names.size())


func _test_envelope_and_enum_rejections() -> void:
	var buf: = _mk_buf(true)
	var ts: int = 1764300100000

	# Unknown event
	var r_unk: Dictionary = buf.record("totally_fake_event", {}, ts)
	check("reject: unknown event refused", not bool(r_unk.ok) and str(r_unk.errors[0]).begins_with("UNKNOWN_EVENT"), str(r_unk.errors))

	# Non-snake_case event
	var r_camel: Dictionary = buf.record("AppOpen", {"src": "organic"}, ts)
	check("reject: non-snake_case event name refused", not bool(r_camel.ok) and str(r_camel.errors[0]).begins_with("BAD_EVENT_NAME"), str(r_camel.errors))

	# Missing required param
	var r_miss: Dictionary = buf.record("purchase_ok", {"sku_id": "x"}, ts)
	check("reject: missing required params refused", not bool(r_miss.ok) and r_miss.errors.has("MISSING_PARAM:purchase_ok.price_rub"), str(r_miss.errors))

	# Bad enum values
	var r_enum: Dictionary = buf.record("purchase_ok", {"sku_id": "x", "price_rub": 199, "method": "crypto", "purchase_id": "p1"}, ts)
	check("reject: invalid payment method enum refused", not bool(r_enum.ok) and str(r_enum.errors[0]).begins_with("BAD_ENUM"), str(r_enum.errors))

	var r_wish_enum: Dictionary = buf.record("wish_pull", {
		"banner_id": "b1", "family": "std", "idx": 1, "k_before": 0, "g_before": 0, "c_before": 0,
		"result": "ultra_secret", "item_id": "i1", "featured": false, "candle": false,
		"cost_cur": "gems", "cost_amt": 150, "odds_hash": "h", "seed_commit": "s",
	}, ts)
	check("reject: invalid wish_pull.result enum refused", not bool(r_wish_enum.ok) and str(r_wish_enum.errors[0]).begins_with("BAD_ENUM"), str(r_wish_enum.errors))

	# Bad envelope: invalid tier / ev_ver / ts <= 0
	var bad_ev: Dictionary = buf.build_event("app_open", {"src": "organic"}, 0)
	bad_ev["tier"] = "nsfw"
	bad_ev["ev_ver"] = 99
	var v_bad: Dictionary = TWAnalyticsSchema.validate_event(bad_ev)
	check("reject: bad ts/tier/ev_ver caught", not bool(v_bad.ok) and v_bad.errors.has("BAD_TS") and v_bad.errors.has("BAD_TIER:nsfw") and v_bad.errors.has("BAD_EV_VER:99"), str(v_bad.errors))


func _test_pii_and_ethics_guards() -> void:
	var buf: = _mk_buf(true)
	var ts: int = 1764300200000

	# PII keys must be rejected
	var r_email: Dictionary = buf.record("app_open", {"src": "organic", "email": "user@example.ru"}, ts)
	check("pii: email key rejected", not bool(r_email.ok) and r_email.errors.has("PII_FORBIDDEN:params.email"), str(r_email.errors))

	var r_nick: Dictionary = buf.record("app_open", {"src": "organic", "nick": "Player123"}, ts)
	check("pii: nick key rejected", not bool(r_nick.ok) and r_nick.errors.has("PII_FORBIDDEN:params.nick"), str(r_nick.errors))

	var r_dob: Dictionary = buf.record("age_gate_result", {"ok": true, "birth_year_bucket": "1996-05-14", "tier_toggle": "standard"}, ts)
	check("pii: exact birth date in birth_year_bucket rejected", not bool(r_dob.ok) and r_dob.errors.has("PII_EXACT_BIRTH_DATE:age_gate_result.birth_year_bucket"), str(r_dob.errors))

	var r_email_val: Dictionary = buf.record("app_open", {"src": "alice@mail.ru"}, ts)
	check("pii: email address embedded in string value rejected", not bool(r_email_val.ok) and r_email_val.errors.has("PII_EMAIL_VALUE:params.src"), str(r_email_val.errors))

	# rank_up must NOT contain RUB
	var r_rank_rub: Dictionary = buf.record("rank_up", {"from": 1, "to": 2, "spent_rub": 5000}, ts)
	check("privacy/mp7.4: rank_up forbids spent_rub", not bool(r_rank_rub.ok) and r_rank_rub.errors.has("FORBIDDEN_PARAM:rank_up.spent_rub"), str(r_rank_rub.errors))

	# Ethics guard: NO personalized discounts by spend profile
	var r_disc: Dictionary = buf.record("sku_view", {
		"section": "packs", "sku_id": "pack_1", "price_rub": 499, "wishes_equiv": 13,
		"personal_discount": 20,
	}, ts)
	check("ethics: personal_discount key rejected", not bool(r_disc.ok) and r_disc.errors.has("ETHICS_FORBIDDEN:params.personal_discount"), str(r_disc.errors))

	var r_whale: Dictionary = buf.record("store_open", {"section": "vip", "spend_profile_offer": "whale_9990"}, ts)
	check("ethics: spend_profile_offer key rejected", not bool(r_whale.ok) and r_whale.errors.has("ETHICS_FORBIDDEN:params.spend_profile_offer"), str(r_whale.errors))


func _test_buffer_consent_and_batching() -> void:
	var ts: int = 1764300300000
	var b: = _mk_buf(false)
	var r0: Dictionary = b.record("app_open", {"src": "organic"}, ts)
	check("consent: events dropped when analytics_consent=false", not bool(r0.ok) and r0.status == "no_consent" and b.pending_count() == 0 and b.dropped_no_consent == 1)

	b.set_consent(true)
	b.max_queue = 3
	for i in 5:
		b.record("ftue_step", {"step": "s%d" % i, "t_s": i * 5}, ts + i * 1000)
	check("buffer: bounded ring caps queue at max_queue and tracks overflow", b.pending_count() == 3 and b.dropped_overflow == 2 and b.accepted_count == 5, str(b.snapshot_stats()))

	var peeked: Array = b.peek_batch(2)
	check("buffer: peek_batch keeps FIFO oldest remaining items without removing", peeked.size() == 2 and str(peeked[0].params.step) == "s2" and b.pending_count() == 3)

	var acked: int = b.ack_batch(2)
	check("buffer: ack_batch removes acknowledged items", acked == 2 and b.pending_count() == 1)

	var drained: Array = b.drain_batch(10)
	check("buffer: drain_batch returns remaining and empties queue", drained.size() == 1 and str(drained[0].params.step) == "s4" and b.pending_count() == 0)

	# Revoking consent clears buffered events
	b.record("app_open", {"src": "organic"}, ts + 9000)
	b.set_consent(false)
	check("consent: revoking consent clears pending queue immediately", b.pending_count() == 0)


func _test_econ_bucketing_and_determinism() -> void:
	check("bucket: econ_snapshot buckets cover boundaries",
		TWAnalyticsSchema.bucket_econ_value(0) == "0"
		and TWAnalyticsSchema.bucket_econ_value(50) == "1_99"
		and TWAnalyticsSchema.bucket_econ_value(499) == "100_499"
		and TWAnalyticsSchema.bucket_econ_value(1200) == "500_1499"
		and TWAnalyticsSchema.bucket_econ_value(4999) == "1500_4999"
		and TWAnalyticsSchema.bucket_econ_value(9999) == "5000_14999"
		and TWAnalyticsSchema.bucket_econ_value(25000) == "15000_plus")

	var b1: = _mk_buf(true)
	var b2: = _mk_buf(true)
	var r1: Dictionary = b1.record_econ_snapshot(1250, 12, 300, 45, 18000, 1764300500000)
	var r2: Dictionary = b2.record_econ_snapshot(1250, 12, 300, 45, 18000, 1764300500000)
	check("determinism: identical inputs produce byte-identical event JSON", bool(r1.ok) and JSON.stringify(r1.event) == JSON.stringify(r2.event))
