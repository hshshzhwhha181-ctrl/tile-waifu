class_name V9Summon
extends RefCounted

# V9Summon — 0.9 three-stage summon (docs/0.9-spec.md §E), the pure rules the summon screen plays by.
#
#   1. LANTERN   a lantern drops in on a gold cord, unlit; a tap (or AUTO_LIGHT seconds) lights it
#   2. COLOUR    it lights jade and climbs to the best rarity of the pull: jade R → lavender SR → gold SSR.
#                The music changes with it (suspense loop → rarity pitch), then the lantern opens
#   3. CARDS     cards fly out of the lantern and flip in their rarity frames; SSR gets a longer build and the
#                full-screen showcase
#   The SSR pity counter and the banner guarantee sit at the top of the whole sequence and tick per flipped card.
#   «Пропустить» appears from the player's second summon on (can_skip).
#
# API (static, no state):
#   V9Summon.best_rar(res) -> "R" | "SR" | "SSR"          best rarity in a pull result
#   V9Summon.steps(best) -> Array                          lantern colour climb: ["R"], ["R","SR"], ["R","SR","SSR"]
#   V9Summon.rank(rar) -> int                              0 R, 1 SR, 2 SSR
#   V9Summon.lantern_tex(rar) -> Texture2D | null          lantern art when the file exists (code lantern otherwise)
#   V9Summon.can_skip(pulls_before) -> bool                skip from the second summon on
#   V9Summon.pity_track(pity_before, res) -> Array[int]    S.pity after each card (mirrors the pity of V10Gacha2 / TWGacha.pull)
#   V9Summon.guar_track(guar_before, res, item, newbie)    S.guar after each card (50/50 lost → guaranteed next)
#   V9Summon.left(pity) -> int                             wishes left to the hard SSR guarantee
#   V9Summon.climb_time(best) -> float                     seconds from lighting to the lantern opening
#   V9Summon.dev_results(n, best, banner) -> Array         a fake pull for screenshots (nothing given, nothing spent)

const ORDER: = ["R", "SR", "SSR"]
const PITY_MAX: = 60
# lantern light colours (spec: R jade, SR lavender, SSR gold)
const COL: = {"R": Color("6fdcae"), "SR": Color("c99bff"), "SSR": Color("ffcf4a")}
const NAME: = {"R": "Нефритовый фонарь", "SR": "Лавандовый фонарь", "SSR": "Золотой фонарь"}
const SUB: = {"R": "Тихий свет · R", "SR": "Редкий свет · SR", "SSR": "Сияние · SSR"}
const IMG: = "res://assets/v09/summon/lantern_%s.png"
# music: a slow, low suspense loop while the lantern is dark, then the summon loop at the rarity's pitch
const SUSPENSE_PITCH: = 0.82
const SUSPENSE_DB: = -15.0
const MUSIC_PITCH: = {"R": 1.0, "SR": 1.06, "SSR": 1.12}
const MUSIC_DB: = {"R": -10.0, "SR": -9.0, "SSR": -7.5}
# timing (s)
const DROP: = 0.8                                  # lantern drop-in
const AUTO_LIGHT: = 2.4                            # an untouched lantern lights itself
const LIGHT: = 0.55                                # jade light-up hold
const STEP: = {"SR": 0.65, "SSR": 0.95}            # each colour step after jade (SSR has the longer build)
const HOLD: = {"R": 0.55, "SR": 0.75, "SSR": 0.95} # final colour held before the lantern opens
const SSR_BUILD: = 0.9                             # SSR card: gold pillar before the flip
const SSR_BUILD_HURRY: = 0.5


static func rank(rar: String) -> int:
	return maxi(0, ORDER.find(rar))


static func best_rar(res: Array) -> String:
	var b: = 0
	for r in res:
		b = maxi(b, rank(String(r.get("rar", "R"))))
	return ORDER[b]


static func steps(best: String) -> Array:
	return ORDER.slice(0, rank(best) + 1)


static func lantern_tex(rar: String) -> Texture2D:
	var p: = IMG % rar.to_lower()
	if ResourceLoader.exists(p):
		return load(p)
	return null


static func can_skip(pulls_before: int) -> bool:
	return pulls_before > 0


static func left(pity: int) -> int:
	return maxi(0, PITY_MAX - pity)


static func pity_track(pity_before: int, res: Array) -> Array:
	var out: = []
	var p: = pity_before
	for r in res:
		p += 1
		if String(r.get("rar", "R")) == "SSR":
			p = 0
		out.append(p)
	return out


static func guar_track(guar_before: bool, res: Array, item: String, newbie: = false) -> Array:
	var out: = []
	var g: = guar_before
	for r in res:
		if not newbie and String(r.get("rar", "R")) == "SSR":
			g = String(r.get("id", "")) != item
		out.append(g)
	return out


static func climb_time(best: String) -> float:
	var t: float = LIGHT + float(HOLD[best])
	for s in steps(best).slice(1):
		t += float(STEP[s])
	return t


# a deterministic fake pull for dev screenshots: best rarity at a fixed slot, never given, never paid for
static func dev_results(n: int, best: String, banner: Dictionary) -> Array:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 9091 + n * 7 + rank(best)
	var pools: = {}
	for rar in ORDER:
		pools[rar] = G.ITEMS.filter( func(x): return x.rar == rar and not x.get("start", false) and not x.get("nogacha", false) and not x.get("hidden", false))
	var plan: = []
	for i in n:
		plan.append("R")
	if n == 1:
		plan[0] = best
	else:
		if rank(best) >= 1:
			plan[2] = "SR"
			plan[8 if n > 8 else n - 1] = "SR"
		if best == "SSR":
			plan[6 if n > 6 else 0] = "SSR"
	var out: = []
	var used: = {}
	for i in n:
		var rar: String = plan[i]
		var it: Dictionary
		if rar == "SSR" and banner.has("item") and G.ITEM.has(banner.item):
			it = G.ITEM[banner.item]
		else:
			var pool: Array = pools[rar].filter( func(x): return not used.has(x.id))
			if pool.is_empty():
				for x in pools[rar]:
					used.erase(x.id)
				pool = pools[rar]
			it = pool[rng.randi() % pool.size()]
		used[it.id] = true
		var r: Dictionary = it.duplicate()
		r["new"] = rar != "R" or i % 3 == 0
		out.append(r)
	return out
