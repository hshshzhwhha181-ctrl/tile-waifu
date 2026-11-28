class_name TWAnalyticsSchema
extends RefCounted

# P106: Pure core analytics event schema (MONETIZATION_PLAN.md §7.4).
# 100% deterministic, zero Node/UI/network/time/random/G. dependencies.
# Enforces:
#   - snake_case event names and ev_ver
#   - common envelope fields without PII
#   - per-event required parameters and closed enum values
#   - 152-FZ privacy denylist (no birth date, nick, email, phone, IP, device IDs)
#   - monetization ethics guard (no spend-profile personalized discounts / dynamic pricing)

const EV_VER: = 1
const MIN_TS_MS: = 1577836800000 # 2020-01-01T00:00:00Z
const MAX_TS_MS: = 4102444800000 # 2100-01-01T00:00:00Z
const MAX_STR_LEN: = 256
const MAX_SCAN_DEPTH: = 6

const NUMERIC_PARAMS: = [
	"dur_s", "t_s", "level", "pairs", "k", "g", "c", "n", "cost", "limit_left",
	"idx", "k_before", "g_before", "c_before", "cost_amt", "ssr_count", "spent_rub_equiv",
	"price_rub", "wishes_equiv", "amount", "debt_after", "days_since", "delta",
	"value", "prev", "from", "to", "step", "milestone", "hud_level", "star", "day", "lv", "amt",
]

const ENVELOPE_REQUIRED: = [
	"event",
	"ts",
	"uid",
	"sess",
	"app_ver",
	"build",
	"lang",
	"tier",
	"age_ok",
	"conn",
	"ev_ver",
]

const ALLOWED_TIERS: = ["neutral", "standard", "full"]
const ALLOWED_CONNS: = ["wifi", "mobile", "offline"]
const ALLOWED_BUILDS: = ["rustore", "dev", "staging"]
const ALLOWED_PROVIDERS: = ["vk", "yandex", "email"]
const ALLOWED_PAY_FROM: = ["ticket", "gems", "moon"]
const ALLOWED_WISH_RESULTS: = ["gift", "s", "ssr"]
const ALLOWED_PAY_METHODS: = ["sbp", "card", "sberpay"]
const ALLOWED_PASS_LINES: = ["free", "prem", "lux"]
const ALLOWED_ULT_VARIANTS: = ["short", "full", "director"]

# Hard PII denylist (152-FZ, MP §7.4: no birth date, nick, email, raw device ids, IP)
const FORBIDDEN_PII_KEYS: = [
	"birth_date",
	"birthdate",
	"dob",
	"birthday",
	"birth_day",
	"email",
	"e_mail",
	"email_address",
	"emailaddress",
	"nick",
	"nickname",
	"username",
	"full_name",
	"fullname",
	"real_name",
	"realname",
	"phone",
	"phone_number",
	"phonenumber",
	"ip",
	"ip_address",
	"ipaddress",
	"device_id",
	"deviceid",
	"imei",
	"idfa",
	"gaid",
	"advertising_id",
	"advertisingid",
	"passport",
	"card_number",
	"cardnumber",
]

# Hard ethics denylist (MP §1.5, §7.3 DB-10, §7.5: no personalized discounts by spend profile)
const FORBIDDEN_ETHICS_KEYS: = [
	"personal_discount",
	"personalized_discount",
	"spend_profile_discount",
	"spend_profile_offer",
	"whale_discount",
	"whale_offer",
	"whale_nudge",
	"dynamic_price",
	"dynamic_price_rub",
	"targeted_price_rub",
	"nudge_tier",
	"p2w_bonus",
]

# Complete MP §7.4 event catalog: event_name -> {req: [required params], enums: {param: [allowed]}, forbid: [extra forbidden]}
const EVENTS: = {
	# Session & funnel
	"app_open": {"req": ["src"], "opt": ["dur_s"]},
	"session_start": {"req": ["src"], "opt": ["dur_s"]},
	"session_end": {"req": ["dur_s"], "opt": ["src"]},
	# Age gate & account
	"age_gate_result": {"req": ["ok", "birth_year_bucket", "tier_toggle"]},
	"account_link": {"req": ["provider"], "enums": {"provider": ALLOWED_PROVIDERS}},
	# FTUE & gameplay
	"ftue_step": {"req": ["step", "t_s"]},
	"level_end": {"req": ["mode", "level", "win", "dur_s", "pairs"]},
	# Gacha / wishes
	"wish_banner_view": {"req": ["banner_id", "family", "k", "g", "c"]},
	"odds_open": {"req": ["banner_id", "odds_hash"]},
	"history_open": {"req": ["banner_id", "odds_hash"]},
	"preview_open": {"req": ["skin_id", "from"]},
	"wish_confirm_open": {"req": ["banner_id", "n", "cost", "pay_from", "limit_left"], "enums": {"pay_from": ALLOWED_PAY_FROM}},
	"wish_pull": {
		"req": ["banner_id", "family", "idx", "k_before", "g_before", "c_before", "result", "item_id", "featured", "candle", "cost_cur", "cost_amt", "odds_hash", "seed_commit"],
		"enums": {"result": ALLOWED_WISH_RESULTS},
	},
	"wish_series_end": {"req": ["n", "ssr_count", "spent_rub_equiv"]},
	# Store & payments
	"store_open": {"req": ["section"], "opt": ["sku_id", "price_rub", "wishes_equiv"]},
	"sku_view": {"req": ["section", "sku_id", "price_rub", "wishes_equiv"]},
	"purchase_start": {"req": ["sku_id", "price_rub", "method", "purchase_id"], "enums": {"method": ALLOWED_PAY_METHODS}, "opt": ["err"]},
	"purchase_ok": {"req": ["sku_id", "price_rub", "method", "purchase_id"], "enums": {"method": ALLOWED_PAY_METHODS}, "opt": ["err", "n", "category"]},
	"purchase_fail": {"req": ["sku_id", "price_rub", "method", "purchase_id", "err"], "enums": {"method": ALLOWED_PAY_METHODS}},
	"purchase_cancel": {"req": ["sku_id", "price_rub", "method", "purchase_id"], "enums": {"method": ALLOWED_PAY_METHODS}, "opt": ["err"]},
	"purchase_pending": {"req": ["sku_id", "price_rub", "method", "purchase_id"], "enums": {"method": ALLOWED_PAY_METHODS}, "opt": ["err"]},
	"purchase_refund": {"req": ["sku_id", "amount", "debt_after", "days_since"]},
	"moon_balance_audit": {"req": ["ok", "delta"]},
	# Limits & responsible play
	"limit_choice_shown": {"req": ["type"], "opt": ["value", "prev"]},
	"limit_set": {"req": ["value", "prev", "type"]},
	"limit_hit": {"req": ["value", "type"], "opt": ["prev"]},
	"pause_set": {"req": ["value", "type"], "opt": ["prev"]},
	"cooldown_prompt": {"req": ["type"], "opt": ["value", "prev"]},
	"cooldown_accept": {"req": ["type"], "opt": ["value", "prev"]},
	# Circle rank (MP §7.4: from, to — strictly without RUB!)
	"rank_up": {"req": ["from", "to"], "forbid": ["rub", "price_rub", "spent_rub", "spend_rub", "amount_rub"]},
	# Season pass & funds
	"pass_view": {"req": ["season"], "opt": ["line", "step"]},
	"pass_buy": {"req": ["season", "line"], "enums": {"line": ALLOWED_PASS_LINES}, "opt": ["step"]},
	"pass_step_claim": {"req": ["season", "line", "step"], "enums": {"line": ALLOWED_PASS_LINES}},
	"fund_buy": {"req": ["fund_id"], "opt": ["milestone"]},
	"fund_claim": {"req": ["fund_id", "milestone"]},
	# Cosmetics & bond
	"skin_equip": {"req": ["skin_id", "tier", "hud_level"], "opt": ["star", "variant"]},
	"skin_dye": {"req": ["skin_id", "tier"], "opt": ["hud_level", "star", "variant"]},
	"star_up": {"req": ["skin_id", "star"], "opt": ["tier", "hud_level", "variant"]},
	"ult_play": {"req": ["skin_id", "variant"], "enums": {"variant": ALLOWED_ULT_VARIANTS}, "opt": ["tier", "hud_level", "star"]},
	"direct_sale_open": {"req": ["skin_id", "day"]},
	"bond_level_up": {"req": ["hero", "lv"]},
	# Ads (rewarded only)
	"ad_offer": {"req": ["placement"], "opt": ["ecpm_bucket"]},
	"ad_watch": {"req": ["placement"], "opt": ["ecpm_bucket"]},
	"ad_reward": {"req": ["placement", "ecpm_bucket"]},
	"ad_complaint": {"req": ["placement"], "opt": ["ecpm_bucket", "reason"]},
	# Liveops events
	"event_shop_buy": {"req": ["event_id", "cur", "amt"]},
	"event_points": {"req": ["event_id", "cur", "amt"]},
	# Daily economy snapshot (buckets, not raw balances)
	"econ_snapshot": {"req": ["gems", "tickets", "moon", "petals", "coins"]},
	# Stability
	"crash": {"req": ["stack_hash"]},
	"anr": {"req": ["stack_hash"]},
}


static func all_event_names() -> PackedStringArray:
	var out: = PackedStringArray()
	var keys: Array = EVENTS.keys()
	keys.sort()
	for k in keys:
		out.append(str(k))
	return out


static func has_event(event_name: String) -> bool:
	return EVENTS.has(event_name)


static func is_snake_case(s: String) -> bool:
	if s.is_empty():
		return false
	for i in s.length():
		var c: int = s.unicode_at(i)
		var is_lower: bool = c >= 97 and c <= 122
		var is_digit: bool = c >= 48 and c <= 57
		var is_under: bool = c == 95
		if i == 0 and not is_lower:
			return false
		if not (is_lower or is_digit or is_under):
			return false
	return true


# Buckets a currency quantity for econ_snapshot (MP §7.4).
static func bucket_econ_value(amount: int) -> String:
	if amount <= 0:
		return "0"
	if amount < 100:
		return "1_99"
	if amount < 500:
		return "100_499"
	if amount < 1500:
		return "500_1499"
	if amount < 5000:
		return "1500_4999"
	if amount < 15000:
		return "5000_14999"
	return "15000_plus"


static func _looks_like_exact_date(val: String) -> bool:
	var s: String = val.strip_edges()
	# Reject YYYY-MM-DD, YYYY/MM/DD, DD.MM.YYYY, DD/MM/YYYY
	if s.length() == 10:
		var c4: String = s.substr(4, 1)
		var c7: String = s.substr(7, 1)
		if (c4 == "-" or c4 == "/" or c4 == ".") and c4 == c7:
			return true
		var c2: String = s.substr(2, 1)
		var c5: String = s.substr(5, 1)
		if (c2 == "." or c2 == "/" or c2 == "-") and c2 == c5:
			return true
	return false


static func _looks_like_email(val: String) -> bool:
	var at_idx: int = val.find("@")
	if at_idx <= 0:
		return false
	var dot_idx: int = val.find(".", at_idx + 1)
	return dot_idx > at_idx + 1 and dot_idx < val.length() - 1


static func _normalize_key(raw: String) -> String:
	var low: String = raw.to_lower()
	var out: String = ""
	for i in low.length():
		var c: int = low.unicode_at(i)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			out += low.substr(i, 1)
	return out


static func _is_forbidden_key(k: String, list: Array) -> bool:
	if list.has(k):
		return true
	var kn: String = _normalize_key(k)
	for fk in list:
		if _normalize_key(str(fk)) == kn:
			return true
	return false


static func _scan_forbidden_value(v: Variant, full: String, k: String, errors: Array, depth: int) -> void:
	if depth > MAX_SCAN_DEPTH:
		errors.append("NESTING_TOO_DEEP:" + full)
		return
	if v is Dictionary:
		_scan_forbidden_keys(v, full, errors, depth + 1)
	elif v is Array:
		var arr: Array = v
		for i in arr.size():
			_scan_forbidden_value(arr[i], "%s[%d]" % [full, i], "", errors, depth + 1)
	elif v is String:
		var s: String = str(v)
		if not full.is_empty() and s.length() > MAX_STR_LEN:
			errors.append("PARAM_TOO_LONG:" + full)
		if k != "stack_hash" and _looks_like_email(s):
			errors.append("PII_EMAIL_VALUE:" + full)


static func _scan_forbidden_keys(d: Dictionary, prefix: String, errors: Array, depth: int = 0) -> void:
	if depth > MAX_SCAN_DEPTH:
		errors.append("NESTING_TOO_DEEP:" + prefix)
		return
	for k_raw in d:
		var k: String = str(k_raw).to_lower()
		var full: String = k if prefix.is_empty() else (prefix + "." + k)
		if _is_forbidden_key(k, FORBIDDEN_PII_KEYS):
			errors.append("PII_FORBIDDEN:" + full)
		elif _is_forbidden_key(k, FORBIDDEN_ETHICS_KEYS):
			errors.append("ETHICS_FORBIDDEN:" + full)
		_scan_forbidden_value(d[k_raw], full, k, errors, depth)


static func validate_event(ev: Dictionary) -> Dictionary:
	var errors: Array = []

	# 1. Privacy & ethics scan over the whole event payload
	_scan_forbidden_keys(ev, "", errors)

	# 2. Envelope presence & types
	for req_key in ENVELOPE_REQUIRED:
		if not ev.has(req_key):
			errors.append("MISSING_ENVELOPE:" + req_key)

	var ev_name: String = str(ev.get("event", ""))
	if not is_snake_case(ev_name):
		errors.append("BAD_EVENT_NAME:" + ev_name)
	elif not EVENTS.has(ev_name):
		errors.append("UNKNOWN_EVENT:" + ev_name)

	if ev.has("ts"):
		var ts_v: Variant = ev.get("ts")
		if not (ts_v is int or ts_v is float) or int(ts_v) < MIN_TS_MS or int(ts_v) > MAX_TS_MS:
			errors.append("BAD_TS")

	if ev.has("ev_ver") and int(ev.get("ev_ver", -1)) != EV_VER:
		errors.append("BAD_EV_VER:" + str(ev.get("ev_ver")))

	if ev.has("uid") and str(ev.get("uid", "")).strip_edges().is_empty():
		errors.append("EMPTY_UID")

	if ev.has("sess") and str(ev.get("sess", "")).strip_edges().is_empty():
		errors.append("EMPTY_SESS")

	if ev.has("tier") and not ALLOWED_TIERS.has(str(ev.get("tier", ""))):
		errors.append("BAD_TIER:" + str(ev.get("tier")))

	if ev.has("conn") and not ALLOWED_CONNS.has(str(ev.get("conn", ""))):
		errors.append("BAD_CONN:" + str(ev.get("conn")))

	if ev.has("build") and not ALLOWED_BUILDS.has(str(ev.get("build", ""))):
		errors.append("BAD_BUILD:" + str(ev.get("build")))

	if ev.has("age_ok") and not (ev.get("age_ok") is bool):
		errors.append("BAD_AGE_OK")

	var params: Variant = ev.get("params", {})
	if not (params is Dictionary):
		errors.append("BAD_PARAMS_TYPE")
		return {"ok": errors.is_empty(), "errors": errors}
	var p: Dictionary = params

	# 3. Event-specific schema checks
	if EVENTS.has(ev_name):
		var spec: Dictionary = EVENTS[ev_name]
		var req_list: Array = spec.get("req", [])
		for rk in req_list:
			if not p.has(rk):
				errors.append("MISSING_PARAM:%s.%s" % [ev_name, str(rk)])
		var enum_map: Dictionary = spec.get("enums", {})
		for ek in enum_map:
			if p.has(ek):
				var allowed: Array = enum_map[ek]
				var got: String = str(p[ek])
				if not allowed.has(got):
					errors.append("BAD_ENUM:%s.%s=%s" % [ev_name, str(ek), got])
		var forbid_list: Array = spec.get("forbid", [])
		for fk in forbid_list:
			if p.has(fk):
				errors.append("FORBIDDEN_PARAM:%s.%s" % [ev_name, str(fk)])

		# Numeric param type enforcement (matches server validator)
		for nk in NUMERIC_PARAMS:
			if p.has(nk) and not (ev_name == "preview_open" and nk == "from") and not (ev_name == "ftue_step" and nk == "step"):
				var nv: Variant = p[nk]
				if not (nv is int or nv is float) or nv is bool:
					errors.append("BAD_PARAM_TYPE:%s.%s" % [ev_name, str(nk)])

		# Extra MP §7.4 privacy checks
		if ev_name == "age_gate_result" and p.has("birth_year_bucket"):
			if _looks_like_exact_date(str(p.get("birth_year_bucket", ""))):
				errors.append("PII_EXACT_BIRTH_DATE:age_gate_result.birth_year_bucket")

	return {"ok": errors.is_empty(), "errors": errors}


static func schema_export() -> Dictionary:
	return {
		"ev_ver": EV_VER,
		"envelope_required": ENVELOPE_REQUIRED,
		"event_count": EVENTS.size(),
		"events": EVENTS,
		"forbidden_pii_keys": FORBIDDEN_PII_KEYS,
		"forbidden_ethics_keys": FORBIDDEN_ETHICS_KEYS,
	}
