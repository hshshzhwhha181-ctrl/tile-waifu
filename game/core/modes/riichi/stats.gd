class_name V10MjRiichiStats
extends RefCounted

# Table statistics for the profile card: average place, win %, deal-in %, riichi %, best combination.
# Lives in G.S.v10_mj_riichi.stats; fed by the screen (hand-level) and by the match end.

const ZERO: = {"matches": 0, "place_sum": 0, "places": [0, 0, 0, 0], "hands": 0, "wins": 0, "dealins": 0, "riichi": 0,
	"best": {"pts": 0, "name": "", "han": 0, "limit": ""}}

static func get_stats(d: Dictionary = {}) -> Dictionary:
	if d.is_empty():
		d = V10MjRiichiData.st()
	var s = d.get("stats")
	if not (s is Dictionary):
		s = {}
		d["stats"] = s
	for k in ZERO:
		if not s.has(k) or typeof(s[k]) != typeof(ZERO[k]):
			s[k] = ZERO[k].duplicate(true) if ZERO[k] is Dictionary or ZERO[k] is Array else ZERO[k]
	return s

# one hand finished. me = player's seat. res = V8Round win/draw_end result. riichi_declared: did the player declare.
static func add_hand(s: Dictionary, res: Dictionary, me: int, riichi_declared: bool) -> void:
	s.hands = int(s.hands) + 1
	if riichi_declared:
		s.riichi = int(s.riichi) + 1
	if res.get("ev", "") != "win":
		return
	if int(res.seat) == me:
		s.wins = int(s.wins) + 1
		var ev: Dictionary = res.get("eval", {})
		var pts: int = int(res.delta[me])
		if pts > int(s.best.pts):
			var top: = ""
			var topv: = -1
			for y in ev.get("yaku", []):
				if int(y[1]) > topv:
					topv = int(y[1])
					top = String(y[0])
			s.best = {"pts": pts, "name": V10MjRiichiData.combo_name(top) if top != "" else "", "han": int(ev.get("han", 0)),
				"limit": V10MjRiichiData.limit_ru(String(ev.get("limit", "")))}
	elif int(res.get("from", -1)) == me:
		s.dealins = int(s.dealins) + 1

static func add_match(s: Dictionary, place: int) -> void:
	s.matches = int(s.matches) + 1
	s.place_sum = int(s.place_sum) + place
	s.places[clampi(place - 1, 0, 3)] = int(s.places[clampi(place - 1, 0, 3)]) + 1

# profile card rows: [label, value]
static func card(s: Dictionary = {}) -> Array:
	if s.is_empty():
		s = get_stats()
	var h: = maxi(1, int(s.hands))
	var m: = int(s.matches)
	var avg: = "—" if m == 0 else ("%.2f" % (float(s.place_sum) / m)).replace(".", ",")
	var best: String = String(s.best.get("name", ""))
	if String(s.best.get("limit", "")) != "":
		best = String(s.best.limit) + (" · " + best if best != "" else "")
	return [
		["Средняя позиция", avg],
		["Победы", _pct(int(s.wins), h)],
		["Наброс", _pct(int(s.dealins), h)],
		["Готовность", _pct(int(s.riichi), h)],
		["Лучшая комбинация", best if best != "" else "—"],
	]

static func _pct(a: int, b: int) -> String:
	return "%d%%" % roundi(100.0 * a / maxi(1, b))
