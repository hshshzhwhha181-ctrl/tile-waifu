class_name V10Hand
extends RefCounted

# «Чтение руки» — one day's hand as the screen drives it (spec 0.10 R4).
#
#   var s := V10Hand.today()                    # the day of V10Meta.day_key(); progress restored from the save
#   s.status() -> {state: open | done | locked, text, sub}
#   board.setup(s.board_cfg())                  # V10HandBoard; board.kind_taken → s.reveal(kind)
#   s.reveal(kind) -> {kind, in_hand, positions, strip, hidden, mult}   flip every copy of kind in her hand (never
#                                               the sleeve) or send it to «Не у неё»
#   s.hand[i] / s.is_open_pos(i) / s.sleeve     what the HUD row of 13 shows (sorted: ман, пин, со, honours)
#   s.hidden_count() / s.mult()                 closed cards / boldness ×1 ×2 ×3 right now
#   s.shutter() -> 34 rows {kind, name, dim, notin, mine, cand}   the «Сделать догадку» sheet
#   s.guess(kind) -> result (see below)         once a day; applies the rewards through V10HandUtil.grant
#   s.explain() / s.form() / s.school_form() / s.candidates() / s.share_text() / s.close_table()
#
# guess(kind) result: {ok, correct, kind, kind_name, waits, wait_names, mult, hidden, gems, bond, rewards, applied,
#   cos_new, explanation, form, form_title, streak, total_correct, share, say, stamp, hero, hand}
#   or {ok: false, reason: done | locked | kind, text}
# `waits` is the answer: the screen must not show it (nor anything derived from it, but candidates() in the
# «С подсказкой» week) before the guess.

const U: = preload("res://scripts/v10/palm/hand_util.gd")
const GEN: = preload("res://scripts/v10/palm/hand_gen.gd")
const ST: = preload("res://scripts/v10/palm/hand_state.gd")
const T: = preload("res://scripts/v10/palm/hand_text.gd")

var key: = ""
var day_idx: = 0
var entry: Dictionary = {}
var hero: = "mc"
var hand: Array = []
var sleeve: Array = []
var waits: Array = []
var decoys: Array = []
var board: Array = []           # 34 counts of the whole planned table (all its tiles lie face up)
var flipped: Dictionary = {}    # position -> true
var taken: Array = []           # kinds of the pairs taken, in order (a doubled decoy appears twice)
var strip: Array = []           # «Не у неё», in order of taking
var closed: = false             # «Стол закрыт» (tray overflow): no more pairs today, the guess stays
var school: = false             # «С подсказкой»: the first 7 played days
var persist: = true             # false: demos and lessons (no save, no rewards)
var result: Dictionary = {}
var _cand: Array = []


static func today() -> V10Hand:
	return for_key(ST.today_key())


static func for_key(k: String, keep: = true) -> V10Hand:
	var h: = V10Hand.new()
	h.key = k
	h.day_idx = U.day_index(k)
	h.persist = keep
	h._load(GEN.entry_for(h.day_idx), U.hero_for_day(h.day_idx))
	h.school = ST.school_on()
	if keep:
		h._restore()
	return h


# demos / tests: any entry, nothing saved
static func for_entry(e: Dictionary, h_id: String = "mc", school_on: = false) -> V10Hand:
	var h: = V10Hand.new()
	h.key = String(e.get("key", U.key_of_index(int(e.get("i", 0)))))
	h.day_idx = int(e.get("i", 0))
	h.persist = false
	h._load(e, h_id)
	h.school = school_on
	return h


func _load(e: Dictionary, h_id: String) -> void:
	entry = e
	hero = h_id
	hand = (e.get("hand", []) as Array).duplicate()
	sleeve = (e.get("sleeve", []) as Array).duplicate()
	waits = (e.get("waits", []) as Array).duplicate()
	decoys = (e.get("decoys", []) as Array).duplicate()
	board = GEN.board_counts(e.get("open", []), decoys, e.get("doubles", []))


func _restore() -> void:
	var td: = ST.today_state(key)
	for k in (td.taken as Array).duplicate():
		_apply(int(k))
	closed = bool(td.closed)
	var s: = ST.st()
	if String(s.day) == key and bool(s.done):
		var right: = bool(s.correct)
		result = {"ok": true, "restored": true, "correct": right, "kind": int(s.kind), "mult": int(s.mult),
			"hidden": int(s.hidden_at_guess), "gems": int(s.gems), "streak": int(s.streak)}
		result.merge(_reveal_words(right))


func status() -> Dictionary:
	if not persist:
		return {"state": "done" if not result.is_empty() else "open", "key": key, "text": "", "sub": ""}
	return ST.status(key)


func board_cfg() -> Dictionary:
	return GEN.board_cfg(entry)


func hero_name() -> String:
	return U.hero_name(hero)


func hero_color() -> Color:
	return U.hero_color(hero)


# ---------------------------------------------------------------- the table

func _apply(kind: int) -> Dictionary:
	var pos: = []
	if kind in entry.get("open", []):
		for i in hand.size():
			if int(hand[i]) == kind and not (i in sleeve) and not flipped.has(i):
				flipped[i] = true
				pos.append(i)
	var to_strip: = false
	if kind in decoys and not (kind in strip):
		strip.append(kind)
		to_strip = true
	taken.append(kind)
	return {"kind": kind, "in_hand": kind in entry.get("open", []), "positions": pos, "strip": to_strip,
		"hidden": hidden_count(), "mult": mult()}


# a pair of `kind` left the table (board.kind_taken)
func reveal(kind: int) -> Dictionary:
	if closed or kind < 0 or kind > 33:
		return {"kind": kind, "in_hand": false, "positions": [], "strip": false, "hidden": hidden_count(), "mult": mult()}
	var r: = _apply(kind)
	if persist:
		(ST.today_state(key).taken as Array).append(kind)
	return r


func close_table() -> void:
	closed = true
	if persist:
		ST.today_state(key).closed = true


func is_open_pos(i: int) -> bool:
	return flipped.has(i)


func hidden_count() -> int:
	return hand.size() - flipped.size()


func mult() -> int:
	return ST.mult_for(hidden_count())


# copies the player can see: every tile of the table (it lies face up) + the copies flipped in her hand
func visible(kind: int) -> int:
	var n: = int(board[kind])
	for i in flipped:
		if int(hand[i]) == kind:
			n += 1
	return n


func impossible(kind: int) -> bool:
	return visible(kind) >= 4


# the 34 rows of the guess sheet, in kind order (ман, пин, со, honours)
func shutter() -> Array:
	var out: = []
	var cand: = candidates() if school else []
	for k in 34:
		var mine: = 0
		for i in flipped:
			if int(hand[i]) == k:
				mine += 1
		out.append({"kind": k, "name": GEN.name(k), "dim": impossible(k), "notin": k in strip, "mine": mine,
			"cand": k in cand})
	return out


# ---------------------------------------------------------------- «С подсказкой»

func form() -> Dictionary:
	return GEN.classify(hand, waits)


# the positions of her hand that make the wait (highlighted in the first week, open or closed) + the form title
func school_form() -> Dictionary:
	var c: = form()
	var pos: = []
	for k in c.partial:
		for i in hand.size():
			if int(hand[i]) == int(k) and not (i in pos):
				pos.append(i)
				break
	pos.sort()
	return {"form": c.form, "title": c.title, "positions": pos}


# 4–6 kinds lit in the guess sheet during the first week: the waits and their nearest plausible neighbours
func candidates() -> Array:
	if not _cand.is_empty():
		return _cand
	var want: = maxi(4 + posmod(day_idx, 3), waits.size() + 1)
	var near: Array = (form().partial as Array).duplicate()
	if near.is_empty():
		near = waits.duplicate()
	# nearest first: the same suit within 3 steps of the cards that make the wait (a kind on the table a little
	# later); then the kinds she holds (a pair wait could be any of them); then anything still possible
	var held: = {}
	for t in hand:
		held[int(t)] = true
	var scored: = []
	for k in 34:
		if k in waits or impossible(k) or int(board[k]) >= 4:
			continue
		var best: = 99
		for p in near + waits:
			if GEN.suit(k) == GEN.suit(int(p)) and GEN.suit(k) < 3:
				best = mini(best, absi(k - int(p)))
			elif k == int(p):
				best = 0
		var tier: = best * 100 if best <= 3 else (400 if held.has(k) else 500)
		if int(board[k]) > 0:
			tier += 50
		scored.append([tier + U.h32("%d|%d" % [day_idx, k]) % 47, k])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: = waits.duplicate()
	for s in scored:
		if out.size() >= want:
			break
		out.append(s[1])
	out.sort()
	_cand = out
	return out


# ---------------------------------------------------------------- the guess

func can_guess() -> bool:
	return result.is_empty() and (not persist or ST.can_guess(key))


func guess(kind: int, apply: = true) -> Dictionary:
	if not result.is_empty():
		return {"ok": false, "reason": "done", "text": T.DONE_TODAY}
	if kind < 0 or kind > 33:
		return {"ok": false, "reason": "kind", "text": ""}
	if persist:
		var stt: = ST.status(key)
		if String(stt.state) != "open":
			return {"ok": false, "reason": String(stt.state), "text": String(stt.text)}
	var hidden: = hidden_count()
	var m: = ST.mult_for(hidden)
	var right: = kind in waits
	var gems: = ST.gems_for(right, m)
	var bond: = int(U.econ("hand.bond"))
	var rewards: = {"gems": gems, "aff": {hero: bond}}
	var cos_new: = []
	if persist:
		cos_new = ST.record(key, right, kind, hidden, m, gems, hero)
	if not cos_new.is_empty():
		rewards["cos"] = cos_new
	var applied: = []
	if apply and persist:
		applied = U.grant(rewards, "hand")
	var s: = ST.st() if persist else {"streak": 1 if right else 0, "total_correct": 1 if right else 0}
	result = {"ok": true, "correct": right, "kind": kind, "kind_name": GEN.name(kind), "mult": m, "hidden": hidden,
		"gems": gems, "bond": bond, "rewards": rewards, "applied": applied, "cos_new": cos_new,
		"streak": int(s.streak), "total_correct": int(s.total_correct), "hero": hero, "hand": hand.duplicate()}
	result.merge(_reveal_words(right))
	return result


func _reveal_words(right: bool) -> Dictionary:
	var c: = form()
	var hidden: = int(result.get("hidden", hidden_count()))
	var streak: = int(result.get("streak", 0))
	return {"waits": waits.duplicate(), "wait_names": GEN.kinds_text(waits), "explanation": explain(),
		"form": c.form, "form_title": c.title, "say": T.say(hero, right), "stamp": T.STAMP if right else "",
		"share": ST.share_text(key, right, hidden, streak)}


func explain() -> String:
	return GEN.explain(hand, waits)


func share_text() -> String:
	if result.is_empty():
		return ""
	return ST.share_text(key, bool(result.correct), int(result.hidden), int(result.get("streak", 0)))
