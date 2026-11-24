class_name V10Pass
extends RefCounted

# V10Pass — season pass «Пропуск сезона» 899 / 1490 ₽ (CEO_PLAN №15, IDEAS §3.3 «Пропуск без обиды»).
#
#   30 tiers × 100 XP. Free and premium tracks (V10Catalog.pass_free / pass_prem); premium tier 30 = the season's
#   exclusive SSR outfit (an outfit, never an SSR heroine — ROSTER_20 §1.4).
#   XP ×2 in the last 10 days of the season. Buying late unlocks every premium tier already reached (retro).
#   Deluxe (1490 ₽) = premium + 10 tiers of XP + moonstone.
#   Season end: rewards reached but not claimed are granted automatically (rollover), nothing is lost.
#   Seasons are calendar dates, the same for everyone (no personal timers).
#
# Saved state: {"season": id, "start": unix, "end": unix, "xp": int, "prem": bool, "deluxe": bool,
#   "cf": claimed free bitmask, "cp": claimed premium bitmask, "oid": order id of the premium purchase}

var st: Dictionary
var clock: V10Clock


func _init(state: Dictionary = {}, clk: V10Clock = null) -> void:
	st = state
	clock = clk
	ensure()


func ensure() -> void:
	st["season"] = String(st.get("season", ""))
	st["start"] = int(st.get("start", 0))
	st["end"] = int(st.get("end", 0))
	st["xp"] = clampi(int(st.get("xp", 0)), 0, V10Catalog.PASS_TIERS * V10Catalog.PASS_XP_TIER)
	st["prem"] = bool(st.get("prem", false))
	st["deluxe"] = bool(st.get("deluxe", false))
	st["cf"] = int(st.get("cf", 0))
	st["cp"] = int(st.get("cp", 0))
	st["oid"] = String(st.get("oid", ""))


func tier() -> int:
	return mini(V10Catalog.PASS_TIERS, int(st.xp) / V10Catalog.PASS_XP_TIER)


func late() -> bool:
	return int(st.end) > 0 and clock.now() >= int(st.end) - V10Catalog.PASS_LATE_DAYS * V10Catalog.DAY


func active() -> bool:
	var t: = clock.now()
	return st.season != "" and t >= int(st.start) and (int(st.end) == 0 or t < int(st.end))


func add_xp(n: int) -> int:
	if n <= 0 or not active():
		return 0
	var k: = n * 2 if late() else n
	var mx: = V10Catalog.PASS_TIERS * V10Catalog.PASS_XP_TIER
	var before: = int(st.xp)
	st.xp = mini(mx, before + k)
	return int(st.xp) - before


static func _bit(i: int) -> int:
	return 1 << (i - 1)


func claimable() -> Array:
	var out: = []
	for i in range(1, tier() + 1):
		if (int(st.cf) & _bit(i)) == 0:
			out.append({"tier": i, "track": "free", "grant": V10Catalog.pass_free(i)})
		if bool(st.prem) and (int(st.cp) & _bit(i)) == 0:
			out.append({"tier": i, "track": "prem", "grant": V10Catalog.pass_prem(i)})
	return out


# marks one reward claimed and returns its grant ({} if not claimable)
func claim(i: int, track: String) -> Dictionary:
	if i < 1 or i > tier():
		return {}
	if track == "free" and (int(st.cf) & _bit(i)) == 0:
		st.cf = int(st.cf) | _bit(i)
		return V10Catalog.pass_free(i)
	if track == "prem" and bool(st.prem) and (int(st.cp) & _bit(i)) == 0:
		st.cp = int(st.cp) | _bit(i)
		return V10Catalog.pass_prem(i)
	return {}


func claim_all() -> Array:
	var out: = []
	for c in claimable():
		var g: = claim(int(c.tier), String(c.track))
		if not g.is_empty():
			out.append(g)
	return out


func unlock(deluxe: bool, oid: String) -> void:
	st.prem = true
	st.oid = oid
	if deluxe and not bool(st.deluxe):
		st.deluxe = true
		st.xp = mini(V10Catalog.PASS_TIERS * V10Catalog.PASS_XP_TIER, int(st.xp) + V10Catalog.PASS_XP_TIER * 10)


# refund: premium off; returns the premium rewards already claimed (to claw back)
func revoke() -> Array:
	var got: = []
	for i in range(1, V10Catalog.PASS_TIERS + 1):
		if (int(st.cp) & _bit(i)) != 0:
			got.append(V10Catalog.pass_prem(i))
	st.prem = false
	st.deluxe = false
	st.cp = 0
	st.oid = ""
	return got


# start a new season; everything reached and unclaimed in the old one is returned for automatic delivery
func rollover(season: String, start: int, end: int) -> Array:
	var left: = claim_all() if st.season != "" else []
	st.season = season
	st.start = start
	st.end = end
	st.xp = 0
	st.prem = false
	st.deluxe = false
	st.cf = 0
	st.cp = 0
	st.oid = ""
	return left
