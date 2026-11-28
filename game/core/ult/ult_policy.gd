class_name TWUltPolicy
extends RefCounted

# TWUltPolicy (P87 / BATTLE_ULT_SPEC §5.11, §7.6, AT-U09):
# Pure, deterministic presentation-mode policy for ultimate cutscenes.
# Decides whether an ultimate plays as "full" (cinematic), "assist" (0.9 s / <=0.6 s table clip),
# or "off" (effect + 0.25 s ring pulse), plus skip-button lock duration (1.0 s on first-ever view).
# Core never animates or sleeps: the shell passes (seen, settings, last_full_age_s, context) here.

const FIRST_VIEW_LOCK_S: = 1.0
const REPEAT_COOLDOWN_S: = 30.0
const FAVORITE_COOLDOWN_S: = 20.0
const ASSIST_CLIP_S: = 0.9
const TABLE_SHORT_S: = 0.6
const TABLE_SSRP_HIGHLIGHT_S: = 1.5

const CUTIN_SETTINGS: = ["full", "short", "off"]
const REPEAT_SETTINGS: = ["first_per_fight", "all", "none", "favorite"]
const MODES: = ["full", "assist", "off"]
const FAVORITE_TIERS: = ["SSR", "SSRP"]


static func _to_nonneg_int(v: Variant) -> int:
	if v is int:
		return maxi(0, v)
	if v is float and is_finite(v):
		return maxi(0, int(v))
	return 0


# Pure decision function matching BATTLE_ULT_SPEC §5.11 & Appendix R W5:
#   seen:             Dictionary {ult_id: int} (S.ult_seen)
#   settings:         Dictionary {ult_cutin: "full"|"short"|"off", ult_repeat: "first_per_fight"|"all"|"none"|"favorite"}
#   last_full_age_s:  float seconds since the previous full cutscene in this fight (< 0.0 means none yet)
#   context:          Dictionary {
#                       ult_id: String, tier: "BASE"|"VOW"|"S"|"SSR"|"SSRP",
#                       hero_casts_in_fight: int (0 = first cast of this heroine in fight),
#                       is_gallery: bool, is_ranked: bool, is_auto: bool,
#                       first_today_outfit: bool, hero_full_today: bool, is_table: bool
#                     }
# Returns: {mode: "full"|"assist"|"off", skip_lock_s: float, reason: String, counts_as_full: bool, clip_max_s: float}
static func choose(seen: Dictionary, settings: Dictionary, last_full_age_s: float, context: Dictionary) -> Dictionary:
	if is_nan(last_full_age_s):
		last_full_age_s = 0.0
	var ult_id: String = str(context.get("ult_id", ""))
	var tier: String = str(context.get("tier", "BASE"))
	var is_gallery: bool = bool(context.get("is_gallery", false))
	var is_ranked: bool = bool(context.get("is_ranked", false))
	var is_auto: bool = bool(context.get("is_auto", false))
	var is_table: bool = bool(context.get("is_table", false))
	var hero_casts: int = _to_nonneg_int(context.get("hero_casts_in_fight", 0))
	var first_today: bool = bool(context.get("first_today_outfit", false))
	var hero_full_today: bool = bool(context.get("hero_full_today", false))

	var cutin: String = str(settings.get("ult_cutin", "full"))
	if not (cutin in CUTIN_SETTINGS):
		cutin = "full"
	var repeat: String = str(settings.get("ult_repeat", "first_per_fight"))
	if not (repeat in REPEAT_SETTINGS):
		repeat = "first_per_fight"

	var assist_cap: float = TABLE_SHORT_S if is_table else ASSIST_CLIP_S
	# Appendix R W5: outside ranked/duels on the table, SSR+ non-short repeat plays a 1.0-1.5 s highlight instead of 0.6 s.
	var repeat_cap: float = TABLE_SSRP_HIGHLIGHT_S if (is_table and tier == "SSRP" and not is_ranked and not is_auto) else assist_cap
	var seen_n: int = _to_nonneg_int(seen.get(ult_id, 0)) if ult_id != "" else 0

	# 1. Gallery always plays the full scene, skippable from frame 0, regardless of ult_cutin/ult_repeat.
	if is_gallery:
		return _res("full", 0.0, "gallery", true, 0.0)

	# 2. Setting "off" -> effect + 0.25 s ring pulse, no scene.
	if cutin == "off":
		return _res("off", 0.0, "setting_off", false, 0.0)

	# 3. Setting "short" ("пропускать все") -> always assist (or <=0.6 s table clip).
	if cutin == "short":
		return _res("assist", 0.0, "setting_short", false, assist_cap)

	# 4. Auto-ult / auto-battle / sweep -> assist (never stalls hands-off play).
	if is_auto:
		return _res("assist", 0.0, "auto", false, assist_cap)

	# 5. Ranked / Duels -> assist (competitive fairness; §5.11 explicitly excludes Duels/Ranked from favorite full).
	if is_ranked:
		return _res("assist", 0.0, "ranked", false, assist_cap)

	# 6. First view ever of this ult_id (seen == 0, cutin == full) -> full scene with 1.0 s skip lock.
	if seen_n == 0:
		return _res("full", FIRST_VIEW_LOCK_S, "first_view", true, 0.0)

	# 7. GDD §4.3: "First ult of the day in this outfit" -> full regardless of repeat, max 1/day per heroine.
	if first_today and not hero_full_today:
		return _res("full", 0.0, "first_today", true, 0.0)

	# 8. Repeat policies (seen > 0, manual non-ranked fight, cutin == full).
	match repeat:
		"none":
			return _res("assist", 0.0, "repeat_none", false, repeat_cap)
		"all":
			return _res("full", 0.0, "repeat_all", true, 0.0)
		"favorite":
			if tier in FAVORITE_TIERS:
				if last_full_age_s < 0.0 or last_full_age_s >= FAVORITE_COOLDOWN_S:
					return _res("full", 0.0, "favorite", true, 0.0)
				return _res("assist", 0.0, "favorite_cooldown", false, repeat_cap)
			# Non-SSR/SSR+ under "favorite" follows the standard first_per_fight rule.
			return _first_per_fight(hero_casts, last_full_age_s, repeat_cap)
		_:
			return _first_per_fight(hero_casts, last_full_age_s, repeat_cap)


static func _first_per_fight(hero_casts: int, last_full_age_s: float, assist_cap: float) -> Dictionary:
	if hero_casts > 0:
		return _res("assist", 0.0, "repeat_in_fight", false, assist_cap)
	if last_full_age_s >= 0.0 and last_full_age_s < REPEAT_COOLDOWN_S:
		return _res("assist", 0.0, "cooldown_30s", false, assist_cap)
	return _res("full", 0.0, "first_per_fight", true, 0.0)


static func _res(mode: String, skip_lock_s: float, reason: String, counts_as_full: bool, clip_max_s: float) -> Dictionary:
	return {
		"mode": mode,
		"skip_lock_s": skip_lock_s,
		"reason": reason,
		"counts_as_full": counts_as_full,
		"clip_max_s": clip_max_s,
	}


# Record a viewed (or tap-skipped) ultimate into S.ult_seen without touching SAVE_VER.
static func record_seen(S: Dictionary, ult_id: String) -> int:
	if ult_id == "":
		return 0
	if not (S.get("ult_seen") is Dictionary):
		S["ult_seen"] = {}
	var seen: Dictionary = S["ult_seen"]
	var next_n: int = _to_nonneg_int(seen.get(ult_id, 0)) + 1
	seen[ult_id] = next_n
	return next_n


static func seen_count(S: Dictionary, ult_id: String) -> int:
	if ult_id == "" or not (S.get("ult_seen") is Dictionary):
		return 0
	return _to_nonneg_int((S["ult_seen"] as Dictionary).get(ult_id, 0))
