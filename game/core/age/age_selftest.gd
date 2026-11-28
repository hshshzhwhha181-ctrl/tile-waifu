class_name TWAgeSelftest
extends RefCounted

# TWAgeSelftest (P22): pure core selftest (>= 60 checks) for TWAge, TWConsent, TWSpendLimit, and PullHistory.
# Covers:
#   - Exact DOB & MSK timezone edge cases (18 years minus 1 day / 1 sec, Feb 29 on leap & non-leap years,
#     1900 boundary & 1900-02-29 invalid, 2000-02-29 valid, future dates, invalid months/days).
#   - Minor lockout (BLOCKED_MINOR 30 days on TWClock.fake, support override, no full DOB persisted).
#   - Full-tier toggle guard (off by default, blocked for minor, NOT blocked by spend pause / self-exclusion C14).
#   - Account link gate (first purchase without link returns DENY_LINK; vk/yandex/email link).
#   - TWConsent (required bundle, separate analytics toggle, offer_ver reconsent, revocation, SAVE_VER=8 persistence).
#   - TWSpendLimit (default 5000 rub/30d, rolling 30d window, lower immediate, raise/remove 24h delay,
#     pause 1/7/30d, irreversible self-exclusion 30/90/180d, C13 emergency threshold 10k/24h & 30k/30d, refund).
#   - PullHistory (>=365 days retention, exact 365d boundary, prune >365d, filtering/pagination, text export + hash).
# Marker: "TWAGE_SELFTEST ok/total OK|FAILED"

const TEST_SAVE_DIR: String = "user://tw_age_selftest/"

var checks: int = 0
var fails: int = 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("TWAGE FAIL: ", what)


static func _utc(y: int, m: int, d: int, hh: int = 0, mm: int = 0, ss: int = 0) -> int:
	return Time.get_unix_time_from_datetime_dict({
		"year": y,
		"month": m,
		"day": d,
		"hour": hh,
		"minute": mm,
		"second": ss,
	})


func run() -> Array:
	checks = 0
	fails = 0
	_test_dob_and_msk()
	_test_minor_lockout_and_full_tier()
	_test_account_link_and_consent()
	_test_spend_limit_and_pause()
	_test_emergency_threshold_and_self_exclusion()
	_test_pull_history_365d()
	_test_twstate_persistence_save_ver_8()
	_test_round1_core_regressions()
	_wipe_dir(TEST_SAVE_DIR)
	print("TWAGE_SELFTEST %d/%d %s" % [checks - fails, checks, "OK" if fails == 0 else "FAILED"])
	return [checks - fails, checks]


func _test_dob_and_msk() -> void:
	# Reference time: 2026-05-15 00:00:00 MSK == 2026-05-14 21:00:00 UTC
	var msk_midnight: int = _utc(2026, 5, 14, 21, 0, 0)
	var msk_before_midnight: int = _utc(2026, 5, 14, 20, 59, 59) # 2026-05-14 23:59:59 MSK

	# 1. Exact MSK timezone boundary checks
	var d_mid: Dictionary = TWAge.msk_date_of(msk_midnight)
	ok(int(d_mid["year"]) == 2026 and int(d_mid["month"]) == 5 and int(d_mid["day"]) == 15,
		"2026-05-14 21:00:00 UTC maps to 2026-05-15 MSK")
	var d_pre: Dictionary = TWAge.msk_date_of(msk_before_midnight)
	ok(int(d_pre["year"]) == 2026 and int(d_pre["month"]) == 5 and int(d_pre["day"]) == 14,
		"2026-05-14 20:59:59 UTC maps to 2026-05-14 MSK")

	# 2. Exact 18th birthday vs 18 years minus 1 second / minus 1 day in MSK
	ok(TWAge.compute_age_msk(2008, 5, 15, msk_midnight) == 18,
		"born 2008-05-15 is 18 at 2026-05-15 00:00:00 MSK")
	ok(TWAge.compute_age_msk(2008, 5, 15, msk_before_midnight) == 17,
		"born 2008-05-15 is still 17 at 2026-05-14 23:59:59 MSK (1 sec before birthday)")
	ok(TWAge.compute_age_msk(2008, 5, 16, msk_midnight) == 17,
		"born 2008-05-16 is 17 on 2026-05-15 MSK (18 years minus 1 day)")
	ok(TWAge.compute_age_msk(2008, 5, 14, msk_midnight) == 18,
		"born 2008-05-14 is 18 on 2026-05-15 MSK (18 years plus 1 day)")

	var clk_pre: TWClock = TWClock.fake(msk_before_midnight, 180)
	var age_pre: TWAge = TWAge.new(clk_pre)
	var r_pre: Dictionary = age_pre.submit_dob(2008, 5, 15)
	ok(not bool(r_pre["ok"]) and str(r_pre["code"]) == "DENY_MINOR",
		"submit_dob 1 sec before 18th birthday MSK returns DENY_MINOR")

	var clk_exact: TWClock = TWClock.fake(msk_midnight, 180)
	var age_exact: TWAge = TWAge.new(clk_exact)
	var r_exact: Dictionary = age_exact.submit_dob(2008, 5, 15)
	ok(bool(r_exact["ok"]) and int(r_exact["age"]) == 18 and age_exact.is_adult(),
		"submit_dob on exact 18th birthday MSK succeeds")

	var clk_minus1d: TWClock = TWClock.fake(msk_midnight, 180)
	var age_m1: TWAge = TWAge.new(clk_minus1d)
	var r_m1: Dictionary = age_m1.submit_dob(2008, 5, 16)
	ok(not bool(r_m1["ok"]) and str(r_m1["code"]) == "DENY_MINOR" and int(r_m1["age"]) == 17,
		"submit_dob 18 years minus 1 day returns DENY_MINOR")

	# 3. Leap day Feb 29 edge cases (non-leap year 2026, leap year 2024, century 2000 & 1900)
	ok(TWAge.is_leap_year(2000) and TWAge.is_leap_year(2008) and TWAge.is_leap_year(2024),
		"2000, 2008, 2024 are leap years")
	ok(not TWAge.is_leap_year(1900) and not TWAge.is_leap_year(2007) and not TWAge.is_leap_year(2026),
		"1900, 2007, 2026 are NOT leap years")

	var feb28_2026_msk: int = _utc(2026, 2, 28, 12, 0, 0) # 15:00 MSK
	var mar01_2026_msk: int = _utc(2026, 2, 28, 21, 0, 0) # 2026-03-01 00:00 MSK
	ok(TWAge.compute_age_msk(2008, 2, 29, feb28_2026_msk) == 17,
		"born 2008-02-29 is still 17 on 2026-02-28 MSK (non-leap year)")
	ok(TWAge.compute_age_msk(2008, 2, 29, mar01_2026_msk) == 18,
		"born 2008-02-29 turns 18 on 2026-03-01 00:00 MSK (non-leap year)")

	var age_feb28: TWAge = TWAge.new(TWClock.fake(feb28_2026_msk, 180))
	ok(str(age_feb28.submit_dob(2008, 2, 29)["code"]) == "DENY_MINOR",
		"2008-02-29 denied on 2026-02-28 MSK")
	var age_mar01: TWAge = TWAge.new(TWClock.fake(mar01_2026_msk, 180))
	ok(bool(age_mar01.submit_dob(2008, 2, 29)["ok"]),
		"2008-02-29 allowed on 2026-03-01 MSK")

	var feb28_2024_msk: int = _utc(2024, 2, 28, 12, 0, 0)
	var feb29_2024_msk: int = _utc(2024, 2, 28, 21, 0, 0) # 2024-02-29 00:00 MSK
	ok(TWAge.compute_age_msk(2004, 2, 29, feb28_2024_msk) == 19,
		"born 2004-02-29 is 19 on 2024-02-28 MSK")
	ok(TWAge.compute_age_msk(2004, 2, 29, feb29_2024_msk) == 20,
		"born 2004-02-29 is 20 on 2024-02-29 MSK")

	ok(bool(TWAge.validate_dob(2000, 2, 29, msk_midnight)["ok"]),
		"2000-02-29 is a valid leap date (divisible by 400)")
	ok(str(TWAge.validate_dob(1900, 2, 29, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"1900-02-29 rejected as invalid calendar date (1900 not leap)")
	ok(str(TWAge.validate_dob(2007, 2, 29, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"2007-02-29 rejected as invalid calendar date")

	# 4. 1900 boundary (MAX_AGE=120 rejects age 126), below 1900, future dates, invalid calendar dates
	var v1900: Dictionary = TWAge.validate_dob(1900, 1, 1, msk_midnight)
	ok(not bool(v1900["ok"]) and str(v1900["code"]) == "DENY_DOB_RANGE",
		"1900-01-01 (age 126 > MAX_AGE) rejected with DENY_DOB_RANGE")
	var v1906: Dictionary = TWAge.validate_dob(1906, 5, 15, msk_midnight)
	ok(bool(v1906["ok"]) and int(v1906["age"]) == 120,
		"1906-05-15 accepted at MAX_AGE boundary (age 120)")
	ok(str(TWAge.validate_dob(1899, 12, 31, msk_midnight)["code"]) == "DENY_DOB_RANGE",
		"1899-12-31 rejected with DENY_DOB_RANGE")
	ok(str(TWAge.validate_dob(0, 1, 1, msk_midnight)["code"]) == "DENY_DOB_RANGE",
		"year 0 rejected with DENY_DOB_RANGE")
	ok(str(TWAge.validate_dob(2026, 5, 16, msk_midnight)["code"]) == "DENY_DOB_FUTURE",
		"tomorrow MSK (2026-05-16) rejected with DENY_DOB_FUTURE")
	ok(str(TWAge.validate_dob(2030, 1, 1, msk_midnight)["code"]) == "DENY_DOB_FUTURE",
		"future year 2030 rejected with DENY_DOB_FUTURE")
	ok(str(TWAge.validate_dob(2000, 0, 10, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"month 0 rejected with DENY_DOB_INVALID")
	ok(str(TWAge.validate_dob(2000, 13, 10, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"month 13 rejected with DENY_DOB_INVALID")
	ok(str(TWAge.validate_dob(2000, 4, 31, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"April 31 rejected with DENY_DOB_INVALID")
	ok(str(TWAge.validate_dob(2000, 1, 0, msk_midnight)["code"]) == "DENY_DOB_INVALID",
		"day 0 rejected with DENY_DOB_INVALID")


func _test_minor_lockout_and_full_tier() -> void:
	var start_u: int = _utc(2026, 6, 1, 10, 0, 0)
	var clk: TWClock = TWClock.fake(start_u, 180)
	var store: Dictionary = {}
	var age: TWAge = TWAge.new(clk, null, store)

	ok(age.current_state() == TWAge.STATE_UNSET and age.needs_gate(),
		"fresh TWAge starts in UNSET and needs_gate()")
	ok(not age.can_toggle_full_tier() and not bool(age.set_full_tier(true)["ok"]),
		"UNSET user cannot enable Full tier")

	# Minor submission -> BLOCKED_MINOR for 30 days
	var r1: Dictionary = age.submit_dob(2012, 3, 10)
	ok(not bool(r1["ok"]) and str(r1["code"]) == "DENY_MINOR",
		"minor DOB sets BLOCKED_MINOR")
	ok(age.current_state() == TWAge.STATE_BLOCKED_MINOR and age.is_minor_blocked(),
		"is_minor_blocked() true immediately after minor DOB")
	ok(not bool(age.set_full_tier(true)["ok"]) and not age.is_full_tier_enabled(),
		"BLOCKED_MINOR cannot enable Full tier")

	# Privacy (C15): full DOB month/day are NOT persisted
	var persisted: Dictionary = store[TWAge.STATE_KEY]
	ok(not persisted.has("month") and not persisted.has("day") and not persisted.has("dob"),
		"persisted state does NOT store full DOB month/day (C15)")
	ok(int(persisted.get("birth_year", 0)) == 2012,
		"persisted state stores birth_year")

	# Trying to cheat with adult DOB during 30-day lockout is rejected
	clk.advance(15.0 * 86400.0)
	var cheat: Dictionary = age.submit_dob(1995, 1, 1)
	ok(not bool(cheat["ok"]) and str(cheat["code"]) == "DENY_MINOR_LOCKED",
		"adult DOB refused during 30-day minor lockout (DENY_MINOR_LOCKED)")

	# Support override requires configured support verifier and valid ticket/token
	var sup_unconf: Dictionary = age.clear_minor_block_by_support()
	ok(not bool(sup_unconf["ok"]) and str(sup_unconf["code"]) == "DENY_SUPPORT_UNCONFIGURED" and age.is_minor_blocked(),
		"clear_minor_block_by_support without verifier fails closed")
	age.set_support_verifier(func(ticket_id: String, tok: String) -> bool:
		return ticket_id == "SUP-42" and tok == "signed-ok-token"
	)
	var sup_bad: Dictionary = age.clear_minor_block_by_support("SUP-42", "wrong-token")
	ok(not bool(sup_bad["ok"]) and str(sup_bad["code"]) == "DENY_SUPPORT_AUTH" and age.is_minor_blocked(),
		"clear_minor_block_by_support with bad token fails closed")
	var sup_ok: Dictionary = age.clear_minor_block_by_support("SUP-42", "signed-ok-token")
	ok(bool(sup_ok["ok"]) and age.current_state() == TWAge.STATE_UNSET and not age.is_minor_blocked(),
		"authenticated support override clears BLOCKED_MINOR")

	# Re-block and let full 30 days expire on fake clock
	age.submit_dob(2011, 5, 5)
	ok(age.is_minor_blocked(), "minor re-blocked")
	clk.advance(30.0 * 86400.0 - 1.0)
	ok(age.is_minor_blocked(), "still blocked 1 second before 30-day expiry")
	clk.advance(1.0)
	ok(not age.is_minor_blocked(), "30-day block expires on TWClock.fake")

	# Adult declaration: Full tier stays OFF by default until explicitly enabled
	var r_adult: Dictionary = age.submit_dob(1996, 8, 20)
	ok(bool(r_adult["ok"]) and age.is_adult() and not age.needs_gate(),
		"adult DOB succeeds after block expiry")
	ok(not age.is_full_tier_enabled(),
		"Full tier is OFF by default after 18+ declaration")
	ok(bool(age.set_full_tier(true)["ok"]) and age.is_full_tier_enabled(),
		"adult can opt-in to Full tier")

	# Revoking age disables Full tier
	age.revoke_age()
	ok(not age.is_adult() and not age.is_full_tier_enabled(),
		"revoke_age resets adult status and disables Full tier")


func _test_account_link_and_consent() -> void:
	var clk: TWClock = TWClock.fake(_utc(2026, 7, 1, 12, 0, 0), 180)
	var age: TWAge = TWAge.new(clk)
	var consent: TWConsent = TWConsent.new(clk)
	var lim: TWSpendLimit = TWSpendLimit.new(clk)

	# Unset age -> DENY_AGE
	ok(str(age.can_purchase()["code"]) == "DENY_AGE",
		"purchase before age gate returns DENY_AGE")

	# Adult without linked account -> DENY_LINK!
	age.submit_dob(1998, 4, 12)
	ok(not age.is_linked(), "fresh adult account is unlinked")
	var cp_unlinked: Dictionary = age.can_purchase()
	ok(not bool(cp_unlinked["ok"]) and str(cp_unlinked["code"]) == "DENY_LINK",
		"first purchase without account link returns DENY_LINK (TWAge)")
	var lim_unlinked: Dictionary = lim.check_purchase(499, age, consent, "1.0")
	ok(not bool(lim_unlinked["ok"]) and str(lim_unlinked["code"]) == "DENY_LINK",
		"TWSpendLimit.check_purchase without account link returns DENY_LINK")

	# Invalid provider / uid / unverified token rejected
	ok(str(age.link_account("telegram_unlisted", "u1", "tok")["code"]) == "DENY_PROVIDER",
		"unsupported link provider rejected")
	ok(str(age.link_account("vk", "", "tok")["code"]) == "DENY_UID",
		"empty uid rejected on link_account")
	ok(str(age.link_account("email", "not-an-email", "tok")["code"]) == "DENY_UID",
		"malformed email rejected on link_account")
	ok(str(age.link_account("vk", "vk_user_42", "tok")["code"]) == "DENY_LINK_UNCONFIGURED",
		"link_account without link_verifier fails closed")

	# Configure verifier and link with vk / yandex / email
	age.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool:
		return tok == "verified-oauth-proof"
	)
	ok(str(age.link_account("vk", "vk_user_42", "bad-proof")["code"]) == "DENY_LINK_UNVERIFIED",
		"link_account with rejected verification token fails closed")
	ok(bool(age.link_account("vk", "vk_user_42", "verified-oauth-proof")["ok"]) and age.is_linked() and age.linked_provider() == "vk",
		"verified link_account('vk') succeeds")
	ok(bool(age.can_purchase()["ok"]),
		"can_purchase() OK after adult + verified link")

	# Consent check before accepting offer -> DENY_CONSENT
	ok(str(lim.check_purchase(499, age, consent, "1.0")["code"]) == "DENY_CONSENT",
		"check_purchase without consent returns DENY_CONSENT")

	# Accept required consents (offer, privacy, pdn, age_18) + analytics off
	var rec: Array = consent.accept_required("1.0", false, "s02", age)
	ok(rec.size() == 5 and consent.has_required_consents("1.0"),
		"TWConsent.accept_required records 4 required + 1 analytics entry")
	ok(not consent.analytics_enabled(), "analytics starts disabled when false")
	ok(consent.accepted_offer_version() == "1.0", "accepted_offer_version == '1.0'")
	ok(consent.needs_reconsent(TWConsent.KIND_OFFER, "2.0"),
		"offer version bump triggers needs_reconsent")
	ok(bool(lim.check_purchase(499, age, consent, "1.0")["ok"]),
		"check_purchase OK after adult + link + consent")
	ok(str(lim.check_purchase(499, age, consent, "1.0", false)["code"]) == "DENY_PAYMENTS_DISABLED",
		"check_purchase returns DENY_PAYMENTS_DISABLED when real_payments_enabled=false")

	# Separate analytics toggle & revocation
	consent.set_analytics(true, "1.0", "settings")
	ok(consent.analytics_enabled(), "separate analytics consent toggles ON")
	consent.revoke(TWConsent.KIND_ANALYTICS, "1.0", "settings")
	ok(not consent.analytics_enabled() and consent.has_required_consents("1.0"),
		"revoking analytics keeps required consents intact")
	ok(consent.export_text().contains("Журнал согласий") and consent.export_text().contains("1.0"),
		"TWConsent.export_text() outputs journal with offer version")

	# Unlinking restores DENY_LINK
	age.unlink_account()
	ok(str(age.can_purchase()["code"]) == "DENY_LINK",
		"unlink_account restores DENY_LINK")
	ok(bool(age.link_account("yandex", "ya_99", "verified-oauth-proof")["ok"]) and bool(age.link_account("email", "player@tilewaifu.invalid", "verified-oauth-proof")["ok"]),
		"verified yandex and email providers accepted")


func _test_spend_limit_and_pause() -> void:
	var clk: TWClock = TWClock.fake(_utc(2026, 8, 1, 12, 0, 0), 180)
	var age: TWAge = TWAge.new(clk)
	age.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool: return tok == "ok-tok")
	age.submit_dob(1992, 10, 5)
	age.set_full_tier(true)
	age.link_account("vk", "u_lim", "ok-tok")
	var consent: TWConsent = TWConsent.new(clk)
	consent.accept_required("1.0", false, "s02", age)
	var lim: TWSpendLimit = TWSpendLimit.new(clk)

	# 1. Default 5000 rub/month cap
	ok(lim.current_limit() == 5000, "default monthly limit is 5000 rub")
	ok(lim.room() == 5000 and lim.spent_30d() == 0, "fresh room is 5000, spent_30d is 0")
	ok(str(lim.check_purchase(5001, age, consent, "1.0")["code"]) == "DENY_LIMIT",
		"single purchase > 5000 denied by default limit")
	ok(bool(lim.check_purchase(3000, age, consent, "1.0")["ok"]), "3000 within 5000 allowed")
	lim.record_purchase(3000, "ord_1")
	ok(lim.spent_30d() == 3000 and lim.room() == 2000, "spent_30d=3000, room=2000")
	ok(bool(lim.check_purchase(2000, age, consent, "1.0")["ok"]), "3000 + 2000 == 5000 allowed")
	lim.record_purchase(2000, "ord_2")
	ok(lim.spent_30d() == 5000 and lim.room() == 0, "spent_30d=5000, room=0")
	ok(str(lim.check_purchase(1, age, consent, "1.0")["code"]) == "DENY_LIMIT",
		"5000 + 1 denied with DENY_LIMIT")

	# 2. Refund restores room
	ok(lim.mark_refunded("ord_2") and lim.spent_30d() == 3000 and lim.room() == 2000,
		"refunded order excluded from spent_30d")
	ok(bool(lim.check_purchase(2000, age, consent, "1.0")["ok"]), "purchase succeeds after refund restores room")

	# 3. Rolling 30-day window on fake clock
	clk.advance(29.0 * 86400.0)
	ok(lim.spent_30d() == 3000, "purchase still counted after 29 days")
	clk.advance(86400.0 + 1.0)
	ok(lim.spent_30d() == 0 and lim.room() == 5000,
		"purchase expires after 30 days on TWClock.fake")

	# 4. Lowering immediate; raising delayed 24h
	var r_low: Dictionary = lim.set_limit(3000)
	ok(bool(r_low["ok"]) and bool(r_low["immediate"]) and lim.current_limit() == 3000,
		"lowering limit 5000 -> 3000 applies immediately")
	var r_raise: Dictionary = lim.set_limit(10000)
	ok(bool(r_raise["ok"]) and str(r_raise["code"]) == "PENDING_24H" and lim.current_limit() == 3000,
		"raising limit 3000 -> 10000 is pending 24h")
	clk.advance(23.0 * 3600.0 + 59.0 * 60.0)
	ok(lim.current_limit() == 3000 and lim.pending_limit() == 10000,
		"raise still pending at 23h59m")
	clk.advance(60.0)
	ok(lim.current_limit() == 10000 and lim.pending_limit() == -1,
		"raise activates at exact 24h00m")

	# 5. Removing limit requires confirm_unlimited=true and 24h delay
	ok(str(lim.set_limit(0, false)["code"]) == "DENY_UNLIMITED_CONFIRM",
		"setting unlimited (0) without confirmation rejected")
	ok(str(lim.set_limit(0, true)["code"]) == "PENDING_24H",
		"setting unlimited (0) with confirmation enters 24h pending")
	clk.advance(86400.0)
	ok(lim.current_limit() == 0 and lim.room() == -1,
		"unlimited activates after 24h")

	# 6. Voluntary pauses: 1, 7, 30 days on TWClock.fake + C14 check
	ok(str(lim.set_pause(2)["code"]) == "DENY_INVALID_PAUSE_DAYS",
		"unsupported pause duration (2 days) rejected")
	for days in [1, 7, 30]:
		var rp: Dictionary = lim.set_pause(days)
		ok(bool(rp["ok"]) and lim.is_paused(), "set_pause(%d) activates pause" % days)
		ok(str(lim.check_purchase(100, age, consent, "1.0")["code"]) == "DENY_PAUSED",
			"purchase blocked during %d-day pause" % days)
		ok(lim.blocks_prices_and_wishes() and not lim.blocks_full_tier() and age.is_full_tier_enabled(),
			"C14: %d-day pause blocks prices/wishes but NOT Full tier" % days)
		clk.advance(float(days) * 86400.0 - 1.0)
		ok(lim.is_paused(), "still paused 1 sec before %d-day expiry" % days)
		clk.advance(1.0)
		ok(not lim.is_paused() and bool(lim.check_purchase(100, age, consent, "1.0")["ok"]),
			"%d-day pause lifts automatically on TWClock.fake" % days)


func _test_emergency_threshold_and_self_exclusion() -> void:
	var clk: TWClock = TWClock.fake(_utc(2026, 9, 1, 10, 0, 0), 180)
	var age: TWAge = TWAge.new(clk)
	age.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool: return tok == "ok-tok")
	age.submit_dob(1990, 2, 14)
	age.set_full_tier(true)
	age.link_account("yandex", "ya_whale", "ok-tok")
	var consent: TWConsent = TWConsent.new(clk)
	consent.accept_required("1.0", false, "s02", age)
	var lim: TWSpendLimit = TWSpendLimit.new(clk)

	# Switch to "No own limit" (0) to verify C13 emergency threshold still fires
	lim.set_limit(0, true)
	clk.advance(86400.0)
	ok(lim.current_limit() == 0, "limit is unlimited before C13 emergency test")

	# 24h emergency threshold (>= 10000 in 24h)
	var r_em: Dictionary = lim.record_purchase(10000, "big_1")
	ok(bool(r_em["emergency_triggered"]) and lim.is_emergency_paused(),
		"C13: >= 10000 rub in 24h triggers emergency pause even with no limit")
	ok(str(lim.check_purchase(100, age, consent, "1.0")["code"]) == "DENY_EMERGENCY_PAUSE",
		"purchase blocked during 24h emergency pause")
	ok(str(lim.acknowledge_emergency_pause()["code"]) == "DENY_EMERGENCY_WAIT",
		"cannot acknowledge emergency pause before 24h elapses")
	clk.advance(86400.0)
	ok(str(lim.check_purchase(100, age, consent, "1.0")["code"]) == "DENY_EMERGENCY_PAUSE",
		"after 24h still blocked until user explicitly acknowledges (C13)")
	ok(bool(lim.acknowledge_emergency_pause()["ok"]) and bool(lim.check_purchase(100, age, consent, "1.0")["ok"]),
		"user ack after 24h lifts emergency pause")

	# 30d emergency threshold (>= 30000 in 30d across separate days)
	clk.advance(2.0 * 86400.0)
	lim.record_purchase(9500, "big_2")
	clk.advance(2.0 * 86400.0)
	lim.record_purchase(9500, "big_3")
	ok(not lim.is_emergency_paused(), "29000 over 30d does not yet hit 30000 threshold")
	clk.advance(2.0 * 86400.0)
	var r_em30: Dictionary = lim.record_purchase(1000, "big_4")
	ok(bool(r_em30["emergency_triggered"]) and lim.spent_30d() == 30000,
		"C13: >= 30000 rub in 30d triggers emergency pause")
	clk.advance(86400.0)
	lim.acknowledge_emergency_pause()

	# Irreversible self-exclusion: 30 / 90 / 180 days
	ok(str(lim.set_self_exclusion(15)["code"]) == "DENY_INVALID_EXCLUDE_DAYS",
		"invalid self-exclusion duration (15d) rejected")
	ok(bool(lim.set_self_exclusion(90)["ok"]) and lim.is_self_excluded(),
		"90-day self-exclusion activates")
	var prev_ex: int = lim.exclude_until()
	lim.set_self_exclusion(30)
	ok(lim.exclude_until() == prev_ex, "self-exclusion cannot be shortened from 90d to 30d")
	ok(str(lim.check_purchase(100, age, consent, "1.0")["code"]) == "DENY_SELF_EXCLUDED",
		"purchase blocked during self-exclusion")
	ok(not lim.blocks_full_tier() and age.is_full_tier_enabled(),
		"C14: self-exclusion does NOT block Full tier")
	clk.advance(90.0 * 86400.0)
	ok(not lim.is_self_excluded() and bool(lim.check_purchase(100, age, consent, "1.0")["ok"]),
		"self-exclusion lifts after full 90 days")


func _test_pull_history_365d() -> void:
	var start_u: int = _utc(2026, 1, 1, 9, 0, 0) # 12:00 MSK
	var clk: TWClock = TWClock.fake(start_u, 180)
	var hist: PullHistory = PullHistory.new(clk)

	ok(hist.count() == 0, "fresh PullHistory is empty")
	var e1: Dictionary = hist.record_pull({
		"banner_id": "b_moon_a",
		"family": "outfit",
		"rarity": "SSR+",
		"item_id": "mc_ssrp_dragonnight",
		"featured": true,
		"candle": false,
		"k_before": 61,
		"g_before": 0,
		"c_before": 61,
		"cost_cur": "gems",
		"cost_amt": 150,
		"odds_hash": "a1b2c3d4",
		"seed_commit": "feedface",
	})
	ok(int(e1["id"]) == 1 and hist.count() == 1, "record_pull stores entry #1")

	# Advance 180 days, record another pull on a different banner
	clk.advance(180.0 * 86400.0)
	hist.record_pull({
		"banner_id": "b_guest_first",
		"family": "first_guest",
		"rarity": "SSR",
		"item_id": "yue_ssr_scalearmor",
		"featured": true,
		"candle": false,
		"k_before": 29,
		"g_before": 0,
		"c_before": 29,
		"cost_cur": "ticket",
		"cost_amt": 1,
		"odds_hash": "11223344",
	})
	ok(hist.count() == 2 and hist.count("b_moon_a") == 1 and hist.count("b_guest_first") == 1,
		"PullHistory filters count by banner_id")

	# Advance to EXACTLY 365 days from entry #1: entry #1 MUST still be kept (>= 365 days!)
	clk.advance(185.0 * 86400.0)
	var removed_at_365: int = hist.prune()
	ok(removed_at_365 == 0 and hist.count() == 2,
		"PullHistory retains entry at exact 365-day boundary (0 pruned)")
	hist.record_pull({
		"banner_id": "b_moon_a",
		"family": "outfit",
		"rarity": "S",
		"item_id": "rin_s_tea",
		"featured": false,
		"candle": true,
		"k_before": 0,
		"g_before": 1,
		"c_before": 119,
		"cost_cur": "moon",
		"cost_amt": 150,
		"odds_hash": "a1b2c3d4",
	})
	ok(hist.count() == 3 and hist.span_days() == 365,
		"span_days() == 365 with entry #1 and entry #3 preserved")

	# Export text + deterministic hash
	var txt: String = hist.export_text()
	ok(txt.contains("История желаний") and txt.contains("mc_ssrp_dragonnight") and txt.contains("a1b2c3d4"),
		"export_text() contains header, item_id, and odds_hash")
	ok(txt.contains("МСК") and txt.contains("свеча"),
		"export_text() formats MSK timestamp and candle marker")
	ok(hist.export_hash() == hist.export_text().sha256_text(),
		"export_hash() matches SHA-256 of export_text()")
	var only_moon: Array = hist.list_entries("b_moon_a", 1, 0, true)
	ok(only_moon.size() == 1 and str(only_moon[0]["item_id"]) == "rin_s_tea",
		"list_entries supports banner filter, newest_first, and pagination")

	# Advance 1 second past 365 days -> entry #1 now pruned, entries #2 and #3 kept
	clk.advance(1.0)
	var removed_after: int = hist.prune()
	ok(removed_after == 1 and hist.count() == 2,
		"prune() removes entry strictly older than 365 days while keeping newer entries")


func _test_twstate_persistence_save_ver_8() -> void:
	_wipe_dir(TEST_SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path: String = TEST_SAVE_DIR.path_join("save.json")
	var clk: TWClock = TWClock.fake(_utc(2026, 10, 1, 10, 0, 0), 180)
	var mig_ctx: Dictionary = {
		"defaults": func() -> Dictionary:
			return {"ver": 8, "gems": 0, "unlocked": 1, "stars": {}, "owned": {}},
		"modules": false,
		"now": clk.now(),
	}
	var st: TWState = TWState.new(TWSave.new(save_path), clk, mig_ctx)
	var age: TWAge = TWAge.new(clk, st)
	var consent: TWConsent = TWConsent.new(clk, st)
	var lim: TWSpendLimit = TWSpendLimit.new(clk, st)
	var hist: PullHistory = PullHistory.new(clk, st)

	age.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool: return tok == "ok-tok")
	age.submit_dob(1994, 11, 22)
	age.set_full_tier(true)
	age.link_account("email", "player@tilewaifu.invalid", "ok-tok")
	consent.accept_required("1.0", true, "s02", age)
	lim.record_purchase(1490, "ord_persist")
	hist.record_pull({"banner_id": "b_moon_a", "rarity": "SSR", "item_id": "hana_ssr_beach", "odds_hash": "99887766"})

	ok(TWState.SAVE_VER == 8 and st.flush(true), "TWState.flush() succeeds with SAVE_VER == 8")
	ok(int(st.data.get("ver", 0)) == 8, "persisted save ver remains 8")

	var st2: TWState = TWState.new(TWSave.new(save_path), clk, mig_ctx)
	ok(st2.load_game() == "loaded" and int(st2.data.get("ver", 0)) == 8,
		"reloaded TWState status == loaded with SAVE_VER == 8")
	var age2: TWAge = TWAge.new(clk, st2)
	var consent2: TWConsent = TWConsent.new(clk, st2)
	var lim2: TWSpendLimit = TWSpendLimit.new(clk, st2)
	var hist2: PullHistory = PullHistory.new(clk, st2)

	ok(age2.is_adult() and age2.is_linked() and age2.is_full_tier_enabled(),
		"reloaded TWAge retains adult, link, and Full tier")
	ok(consent2.has_required_consents("1.0") and consent2.analytics_enabled(),
		"reloaded TWConsent retains required consents and analytics")
	ok(lim2.spent_30d() == 1490 and lim2.current_limit() == 5000,
		"reloaded TWSpendLimit retains spent_30d and default cap")
	ok(hist2.count() == 1 and hist2.export_text().contains("hana_ssr_beach"),
		"reloaded PullHistory retains pull entry")


func _test_round1_core_regressions() -> void:
	# [M1] revoke_age() must NOT bypass BLOCKED_MINOR; clear_minor_block_by_support() must fail closed without auth
	var t0: int = _utc(2026, 6, 1, 10, 0, 0)
	var clk1: TWClock = TWClock.fake(t0, 180)
	var age1: TWAge = TWAge.new(clk1)
	age1.submit_dob(2012, 3, 10)
	ok(age1.is_minor_blocked(), "[M1] minor DOB enters BLOCKED_MINOR")
	age1.revoke_age()
	ok(age1.current_state() == TWAge.STATE_BLOCKED_MINOR and age1.is_minor_blocked(),
		"[M1] revoke_age() does NOT unlock active BLOCKED_MINOR")
	var bypass_try: Dictionary = age1.submit_dob(1995, 1, 1)
	ok(not bool(bypass_try["ok"]) and str(bypass_try["code"]) == "DENY_MINOR_LOCKED",
		"[M1] submit_dob after revoke_age() during lock still returns DENY_MINOR_LOCKED")
	age1.clear_minor_block_by_support()
	ok(age1.current_state() == TWAge.STATE_BLOCKED_MINOR and age1.is_minor_blocked(),
		"[M1] unauthenticated clear_minor_block_by_support() fails closed and keeps BLOCKED_MINOR")

	# [M2] TWSpendLimit.check_purchase() must FAIL CLOSED when age/consent/required_offer_ver are omitted
	var clk2: TWClock = TWClock.fake(t0, 180)
	var age2: TWAge = TWAge.new(clk2)
	age2.set_link_verifier(func(_p: String, _u: String, tok: String) -> bool: return tok == "ok-tok")
	age2.submit_dob(1995, 5, 5)
	age2.link_account("vk", "vk_m2_user", "ok-tok")
	var consent2: TWConsent = TWConsent.new(clk2)
	var lim2: TWSpendLimit = TWSpendLimit.new(clk2)
	ok(not bool(lim2.check_purchase(499)["ok"]),
		"[M2] check_purchase(499) with null age/consent fails closed")
	ok(not bool(lim2.check_purchase(499, age2)["ok"]),
		"[M2] check_purchase(499, age) with null consent fails closed")
	ok(not bool(lim2.check_purchase(499, age2, consent2, "")["ok"]),
		"[M2] check_purchase(499, age, consent, '') with empty offer_ver fails closed")

	# [M7] PullHistory.prune() must resist phone clock forward jump + record_pull ignores caller ts
	var clk7: TWClock = TWClock.fake(t0, 180)
	var ph7: PullHistory = PullHistory.new(clk7)
	var r7: Dictionary = ph7.record_pull({
		"ts": t0 - 500 * 86400,
		"banner_id": "b_moon_a",
		"family": "outfit",
		"rarity": "SSR",
		"item_id": "hana_ssr",
		"cost_cur": "gems",
		"cost_amt": 150,
		"odds_hash": "abcd1234",
	})
	ok(int(r7["ts"]) == t0,
		"[M7] record_pull ignores caller-supplied ts and stamps clock time")
	# Simulate phone clock moved forward 400 days (wall clock jump without monotonic passage)
	clk7.set_wall(t0 + 400 * 86400)
	ph7.record_pull({
		"banner_id": "b_moon_a",
		"family": "outfit",
		"rarity": "S",
		"item_id": "rin_s",
		"cost_cur": "gems",
		"cost_amt": 150,
		"odds_hash": "abcd1234",
	})
	ok(ph7.count() == 2,
		"[M7] forward phone clock jump (>365d) does NOT wipe PullHistory")

	# [m1] 512-entry cap must preserve founding required consents and keep seq strictly unique/increasing
	var clk_m1: TWClock = TWClock.fake(t0, 180)
	var c_m1: TWConsent = TWConsent.new(clk_m1)
	c_m1.accept_required("1.0", false, "gate")
	for i in range(560):
		clk_m1.advance(1.0)
		c_m1.set_analytics((i % 2) == 0, "1.0", "settings")
	ok(c_m1.has_required_consents("1.0"),
		"[m1] founding required consents survive >512 analytics toggles")
	var seqs: Dictionary = {}
	var dup_seq: bool = false
	var prev_seq: int = 0
	var mono_seq: bool = true
	for e in c_m1.entries():
		var sq: int = int(e.get("seq", 0))
		if seqs.has(sq):
			dup_seq = true
		seqs[sq] = true
		if sq <= prev_seq:
			mono_seq = false
		prev_seq = sq
	ok(not dup_seq and mono_seq and prev_seq > TWConsent.MAX_ENTRIES,
		"[m1] consent seq stays unique and monotonically increasing past 512 (last=%d)" % prev_seq)

	# [m2] record_purchase idempotency on order_id + out-of-order 366d pruning
	var clk_m2: TWClock = TWClock.fake(t0, 180)
	var lim_m2: TWSpendLimit = TWSpendLimit.new(clk_m2)
	lim_m2.record_purchase(3000, "ord_idem_1")
	lim_m2.record_purchase(3000, "ord_idem_1")
	ok(lim_m2.spent_30d() == 3000,
		"[m2] duplicate record_purchase(ord_idem_1) is idempotent (spent=%d)" % lim_m2.spent_30d())
	# Out-of-order older entry behind a newer entry should still be pruned after 366d
	var st_m2: Dictionary = {}
	var clk_m2b: TWClock = TWClock.fake(t0 + 400 * 86400, 180)
	var lim_m2b: TWSpendLimit = TWSpendLimit.new(clk_m2b, null, st_m2)
	st_m2[TWSpendLimit.STATE_KEY]["hist"] = [
		{"t": t0 + 390 * 86400, "rub": 500, "oid": "ord_new", "refunded": false},
		{"t": t0, "rub": 900, "oid": "ord_ancient", "refunded": false},
	]
	lim_m2b.record_purchase(100, "ord_trigger_prune")
	var hist_m2b: Array = st_m2[TWSpendLimit.STATE_KEY]["hist"]
	var has_ancient: bool = false
	for h in hist_m2b:
		if str((h as Dictionary).get("oid", "")) == "ord_ancient":
			has_ancient = true
	ok(not has_ancient and hist_m2b.size() == 2,
		"[m2] out-of-order entry >366d old is pruned without dropping newer entry")

	# [m3] PullHistory.record_pull must NOT fabricate cost 150 gems or rarity 'gift' when omitted
	var clk_m3: TWClock = TWClock.fake(t0, 180)
	var ph_m3: PullHistory = PullHistory.new(clk_m3)
	var r_m3: Dictionary = ph_m3.record_pull({"banner_id": "b_test", "item_id": "item_1"})
	ok(str(r_m3.get("cost_cur", "")) == "" and int(r_m3.get("cost_amt", -1)) == 0,
		"[m3] omitted cost does NOT fabricate 150 gems (got %s %s)" % [str(r_m3.get("cost_amt")), str(r_m3.get("cost_cur"))])
	ok(str(r_m3.get("rarity", "")) == "",
		"[m3] omitted rarity does NOT fabricate 'gift' (got '%s')" % str(r_m3.get("rarity")))

	# [m4] TWConsent must not allow backdating ts via phone clock reversal
	var clk_m4: TWClock = TWClock.fake(t0, 180)
	clk_m4.tick()
	var c_m4: TWConsent = TWConsent.new(clk_m4)
	var e1_m4: Dictionary = c_m4.record("offer", "1.0", "1.0", true, "gate")
	clk_m4.set_wall(t0 - 30 * 86400)
	var e2_m4: Dictionary = c_m4.record("privacy", "1.0", "1.0", true, "gate")
	ok(int(e2_m4["ts"]) >= int(e1_m4["ts"]),
		"[m4] consent ts cannot be backdated when phone clock moves backward")

	# [m7] Vladivostok 18th birthday midnight (UTC+10), 1900 DOB age 126 rejected, unverified link_account rejected
	# 2026-05-15 00:30:00 VLAT (UTC+10, bias=600) == 2026-05-14 14:30:00 UTC (17:30 MSK, still May 14 in MSK!)
	var vlat_bday: int = _utc(2026, 5, 14, 14, 30, 0)
	var clk_vlat: TWClock = TWClock.fake(vlat_bday, 600)
	var age_vlat: TWAge = TWAge.new(clk_vlat)
	var r_vlat: Dictionary = age_vlat.submit_dob(2008, 5, 15)
	ok(bool(r_vlat["ok"]) and age_vlat.is_adult(),
		"[m7] Vladivostok user at 00:30 local on 18th birthday is accepted (not hard-blocked for 30d)")

	var v1900_rej: Dictionary = TWAge.validate_dob(1900, 1, 1, _utc(2026, 5, 14, 21, 0, 0))
	ok(not bool(v1900_rej["ok"]) and str(v1900_rej["code"]) == "DENY_DOB_RANGE",
		"[m7] 1900-01-01 (age 126 > MAX_AGE) rejected with DENY_DOB_RANGE")

	var age_unv: TWAge = TWAge.new(TWClock.fake(t0, 180))
	age_unv.submit_dob(1995, 1, 1)
	var r_link_unv: Dictionary = age_unv.link_account("vk", "arbitrary_unverified_uid")
	ok(not bool(r_link_unv["ok"]) and not age_unv.is_linked(),
		"[m7] unverified link_account without verifier/token fails closed")


static func _wipe_dir(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n != "." and n != "..":
			var p: String = dir_path.path_join(n)
			if d.current_is_dir():
				_wipe_dir(p)
				DirAccess.remove_absolute(p)
			else:
				DirAccess.remove_absolute(p)
		n = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir_path)
