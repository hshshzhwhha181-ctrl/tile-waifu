class_name V10MjClassicData
extends RefCounted

# Save and progress of «Классика» (S.v10_mj_classic), modelled on V6ModesData.st(): DEFAULTS + st() that creates and
# repairs the dictionary on first read. SAVE_VER is not touched; the integrator registers the key (README).
#
# Stars per form: ★ win, ★★ win without shuffles, ★★★ «Чистая игра» (no hints, no shuffles).
# Mastery «Знак Классики» I–V by the sum of stars; every rank once pays 30 crystals (5 × 30), ranks I / III / V
# give the frame, the title «Хранительница форм» and the tile back. First win of the day: 20 coins and +1 sympathy.
# The screen never pays: record() returns what the integrator should credit (result.rewards).

const KEY: = "v10_mj_classic"
const DEFAULTS: = {
	"ver": 1,
	"stars": {},          # form id -> 0..3 (best)
	"best_time": {},      # form id -> seconds (best win)
	"hearts": [],         # bookmarked forms
	"wins": 0,
	"plays": 0,
	"ranks_paid": 0,      # mastery ranks already paid (0..5)
	"first_win_day": "",  # MSK date of the last first-win-of-day payout
	"daily": {"date": "", "done": false, "time": 0, "form": ""},
	"memory": {},         # "4x4" -> best moves
	"view": "3d",         # «Объёмный» | "flat" «Плоский»
	"diff": "normal",
	"last_form": "turtle",
	"first_day": "",      # first day the mode was opened: free tiles are lit for 7 days
	"cosmetics": [],      # "frame_classic", "title_keeper", "back_classic"
}

const RANKS: = [5, 12, 21, 32, 45]
const RANK_NAMES: = ["I", "II", "III", "IV", "V"]
const RANK_GEMS: = 30
const RANK_GIFTS: = {1: "frame_classic", 3: "title_keeper", 5: "back_classic"}
const GIFT_NAMES: = {"frame_classic": "Рамка «Знак Классики»", "title_keeper": "Титул «Хранительница форм»",
	"back_classic": "Рубашка «Знак Классики»"}
const DAY_COINS: = 20
const DAY_AFF: = 1
# the hostess of «Раскладка дня» rotates by the MSK date over the heroines in the roster
const HOSTS: = ["mc", "rin", "hana", "yue", "nova"]

static var _mem: = {}  # used when there is no G (selftest without autoload)
static var persist: = true  # the selftest turns disk writes off
static var sandbox = null  # selftest: a Dictionary standing in for G.S


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null


static func st(S_in = null) -> Dictionary:
	var g = _g()
	var S: Dictionary = S_in if S_in is Dictionary else (g.S if g and g.get("S") is Dictionary else _mem)
	if S_in == null and sandbox is Dictionary:
		S = sandbox
	if not S.get(KEY) is Dictionary:
		S[KEY] = DEFAULTS.duplicate(true)
	var d: Dictionary = S[KEY]
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	if not d.view in ["3d", "flat"]:
		d.view = "3d"
	if not d.diff in ["easy", "normal", "master"]:
		d.diff = "normal"
	return d


static func save() -> void:
	if not persist:
		return
	var g = _g()
	if g and g.has_method("save"):
		g.save()


static func _now_unix() -> int:
	if ClassDB.class_exists("V10Meta") or ResourceLoader.exists("res://scripts/v10/meta/meta.gd"):
		return V10Meta.now_unix()
	return 1798761600


# Moscow date (UTC+3, no DST) — «Раскладка дня» is the same for everyone
static func msk_date(unix: = -1.0) -> String:
	var t: float = float(_now_unix()) if unix < 0.0 else unix
	return Time.get_date_string_from_unix_time(int(t) + 3 * 3600)


static func date_seed(date: String) -> int:
	return int(date.replace("-", ""))


static func daily_form(date: String) -> String:
	var forms: Array = V10MjClassicLayouts.classic_forms()
	var h: = hash("classic-daily-" + date)
	return String(forms[posmod(h, forms.size())].id)


# who hosts the layout of the day (she says one line at its start): the same for everyone on that date
static func daily_host(date: String, roster = null) -> String:
	var heroes: Dictionary = roster if roster is Dictionary else V10MjClassicLayouts._roster()
	var pool: Array = HOSTS.filter(func(h): return heroes.is_empty() or heroes.has(h))
	if pool.is_empty():
		pool = ["mc"]
	return String(pool[posmod(hash("classic-host-" + date), pool.size())])


static func stars_of(win: bool, hints: int, shuffles: int) -> int:
	if not win:
		return 0
	if shuffles > 0:
		return 1
	if hints > 0:
		return 2
	return 3


static func star_sum(d: = {}) -> int:
	var s: Dictionary = (d if not d.is_empty() else st()).stars
	var tot: = 0
	for k in s:
		if V10MjClassicLayouts.visible(V10MjClassicLayouts.get_form(k)):
			tot += int(s[k])
	return tot


static func rank_of(sum: int) -> int:
	var r: = 0
	for t in RANKS:
		if sum >= t:
			r += 1
	return r


static func rank_text(r: int) -> String:
	return "Знак Классики %s" % RANK_NAMES[r - 1] if r > 0 else "Знак Классики"


# next threshold for a progress bar: {rank, have, need}
static func rank_progress(d: = {}) -> Dictionary:
	var sum: = star_sum(d)
	var r: = rank_of(sum)
	var need: int = RANKS[r] if r < RANKS.size() else RANKS[-1]
	return {"rank": r, "have": sum, "need": need}


# Apply a finished match to the save; returns the rewards for result.rewards and what changed.
# result: {mode, variant, form, win, stars, time_s, ..., mult}. mult — the Afisha's «Режим дня» multiplier for
# «Раскладка дня» (×2 when Классика is the mode of the day; the integrator passes it in args.mult): it multiplies the
# coins of the daily layout only. Crystals come only from the mastery milestones (5 × 30, once each).
static func record(result: Dictionary, today: = "") -> Dictionary:
	var d: = st()
	var day: = today if today != "" else msk_date()
	var rew: = {"coins": 0, "gems": 0, "petals": 0, "aff": 0}
	var out: = {"rewards": rew, "new_best": false, "rank_up": 0, "gifts": [], "first_today": false}
	d.plays += 1
	if not result.get("win", false):
		save()
		return out
	d.wins += 1
	var variant: String = result.get("variant", "free")
	if variant == "memory":
		var sz: String = result.get("size", "4x4")
		var mv: = int(result.get("moves", 0))
		if not d.memory.has(sz) or mv < int(d.memory[sz]):
			d.memory[sz] = mv
			out.new_best = true
	else:
		var fid: String = result.get("form", "")
		var stars: = int(result.get("stars", 0))
		if stars > int(d.stars.get(fid, 0)):
			d.stars[fid] = stars
			out.new_best = true
		var t: = int(result.get("time_s", 0))
		if t > 0 and (not d.best_time.has(fid) or t < int(d.best_time[fid])):
			d.best_time[fid] = t
		if variant == "daily" and d.daily.get("date", "") == day:
			d.daily.done = true
			if int(d.daily.get("time", 0)) == 0 or t < int(d.daily.time):
				d.daily.time = t
	if d.first_win_day != day:
		d.first_win_day = day
		rew.coins += DAY_COINS
		rew.aff += DAY_AFF
		out.first_today = true
		if variant == "daily":
			rew.coins *= clampi(int(result.get("mult", 1)), 1, 3)
	var r: = rank_of(star_sum(d))
	while int(d.ranks_paid) < r:
		d.ranks_paid += 1
		rew.gems += RANK_GEMS
		out.rank_up = int(d.ranks_paid)
		if RANK_GIFTS.has(int(d.ranks_paid)):
			var gift: String = RANK_GIFTS[int(d.ranks_paid)]
			if not gift in d.cosmetics:
				d.cosmetics.append(gift)
			out.gifts.append(gift)
	save()
	return out


static func toggle_heart(fid: String) -> bool:
	var d: = st()
	if fid in d.hearts:
		d.hearts.erase(fid)
		save()
		return false
	d.hearts.append(fid)
	save()
	return true


# free tiles are lit (closed ones dimmed strongly) during the first 7 days in the mode, then softer
static func light_free(day: = "") -> bool:
	var d: = st()
	var today: = day if day != "" else msk_date()
	if d.first_day == "":
		d.first_day = today
		return true
	var a: = Time.get_unix_time_from_datetime_string(String(d.first_day))
	var b: = Time.get_unix_time_from_datetime_string(today)
	return (b - a) / 86400.0 < 7.0


# «быстрее N % игроков»: a population of casual players simulated by the bot — moves × a lognormal think time —
# the same for everyone on that date. -> percent of that population slower than `time_s`.
static func faster_than(time_s: int, pairs: int, date: String) -> int:
	var rng: = RandomNumberGenerator.new()
	rng.seed = date_seed(date) * 31 + pairs
	var slower: = 0
	var N: = 400
	for i in N:
		var skill: = exp(rng.randfn(0.0, 0.35))
		var per: = 3.4 * skill
		var total: = 0.0
		for m in pairs:
			total += per * exp(rng.randfn(0.0, 0.5))
		total += rng.randf_range(10.0, 60.0) * skill  # stuck moments, shuffles
		if total > time_s:
			slower += 1
	return int(round(100.0 * slower / N))
