class_name V10Lint
extends RefCounted

# V10Lint — the one stop-word list of 0.10 (docs/0.10-spec.md §2.7) and the UI jargon list (docs/UX_RULES.md §4.2,
# §4.3, checklist С-1). Every heroine-facing string (notifications, letters, chats, feed, scenes) goes through
# check() before it can be shown. The heroine never guilts the player and never talks about money: no «скучала»,
# «вернись», prices, discounts, «успей», «только сегодня»…
#
#   V10Lint.check(text) -> Array      heroine text: the banned fragments found (empty = clean)     ok(text) -> bool
#   V10Lint.scan(texts: Array) -> Array    [{text, bad:[…]}] for every dirty heroine string (selftests)
#   V10Lint.ui_check(text) -> Array   any VISIBLE UI string: gacha jargon (§4.3) and the old names (§4.2 «было»)
#   V10Lint.ui_ok(text) -> bool       ui_scan(texts) -> [{text, bad}]
#
# Heroine list: lower-case substring match, so «скуча» catches «скучала» / «заскучала». Four short stems would hit
# ordinary words, so they are matched by word: «одна» only as a whole word (not «однако», «модная», «свободна»),
# «цена», «акци», «купи» only at a word start (not «сцена», «реакция»). «бесплатн» is banned only next to a price
# («бесплатно» alone is fine in a reward caption, «бесплатно, а потом 79 ₽» is not): see PRICE_MARKS.
# Owner: lane meta (the spec puts it at v10/core/lint.gd — the integrator may move the file, the class name stays).

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк",
	"успей", "последн", "только сегодня", "купи", "баннер", "акци", "цена"]
# stems of BANNED matched by word instead of as a bare substring
const WHOLE_WORD: = ["одна"]
const WORD_START: = ["цена", "акци", "купи"]
# allowed phrases that contain a banned fragment (lower case)
const ALLOW: = ["однажды", "ещё одна", "одна чашка", "одна партия"]
const PRICE_NEAR: = "бесплатн"
const PRICE_MARKS: = ["₽", "руб", "цен", "стоит", "%"]

# ── UI jargon (UX_RULES §4.3) and the old names (§4.2 «было»). Kinds:
#   "start"  lower case, at a word start (inflections pass: «ульта» → «ульты»)   "word"  lower case, whole word
#   "sub"    lower case substring                                                 "case"  exact case, whole word
#   "exact"  the whole caption equals it (old tab names: «Режимы» is fine inside a sentence, not as a tab)
#   "re"     a regular expression on the lower-case text
const UI_BANNED: = [
	# §4.3
	["гарант", "start"], ["пити", "word"], ["pity", "word"], ["50/50", "sub"], ["SR", "case"], ["SR+", "sub_case"],
	["SSR+", "sub_case"], ["R", "case"], ["гач", "start"], ["ролл", "start"], ["крутк", "start"],
	["фивер", "start"], ["ивент", "start"], ["квартал", "start"], ["перк", "word"], ["перки", "word"], ["перка", "word"], ["перков", "word"],
	["ульт", "start"], ["риичи", "start"], ["яку", "word"], ["банер", "start"], ["донат", "start"], ["ХИТ", "case"],
	["ВЫГОДНО", "case"], ["BEST", "case"], ["NEW", "case"], ["[−-]\\s?\\d+\\s?%", "re"], ["\\+\\s?\\d+\\s?%", "re"],
	["x2 только сегодня", "sub"], ["×2 только сегодня", "sub"], ["успей", "start"], ["последний шанс", "sub"],
	["осталось\\s+\\d+\\s+шт", "re"], ["топ-100", "sub"], ["ID", "case"],
	# §4.1 п.7: «ещё N сегодня» turns affection into a duty
	["ещё\\s+\\d+\\s+сегодня", "re"],
	# §4.2 «было»
	["Гардероб", "exact"], ["Партия", "exact"], ["Режимы", "exact"], ["Камни", "exact"], ["Фишки", "exact"],
	["сесть за стол", "sub"], ["следующая партия", "sub"], ["поручени", "start"], ["визиты", "word"],
	["рядом с тобой", "sub"], ["богин", "start"], ["обмен", "word"], ["звезда наряда", "sub"], ["лихорадк", "start"],
	["каскад", "start"], ["небесный поток", "sub"], ["ЦЕЛЬ", "case"], ["пятый ветер", "sub"], ["лунная лестница", "sub"],
	["чайный абонемент", "sub"], ["осколок портрета", "sub"], ["марки альбома", "sub"], ["капли росы", "sub"],
	["лунные капли", "sub"], ["тайник", "start"], ["кто за столом", "sub"],
]
# fragments allowed although they start like a banned one
const UI_ALLOW: = ["ультрамарин"]

static var _re_cache: = {}


static func _is_letter(c: String) -> bool:
	return c != "" and (c.to_lower() != c.to_upper() or c.is_valid_int())


# every index of `w` in `low` that is a word (whole = both sides) or a word start (whole = false)
static func _word_hit(low: String, w: String, whole: bool) -> bool:
	var i: = low.find(w)
	while i >= 0:
		var before: = low.substr(i - 1, 1) if i > 0 else ""
		var after: = low.substr(i + w.length(), 1)
		if not _is_letter(before) and (not whole or not _is_letter(after)):
			return true
		i = low.find(w, i + 1)
	return false


static func check(text: String) -> Array:
	var low: = text.to_lower()
	var masked: = low
	for a in ALLOW:
		masked = masked.replace(a, "#".repeat(a.length()))
	var bad: = []
	for w in BANNED:
		var hit: bool
		if w in WHOLE_WORD:
			hit = _word_hit(masked, w, true)
		elif w in WORD_START:
			hit = _word_hit(masked, w, false)
		else:
			hit = masked.find(w) >= 0
		if hit:
			bad.append(w)
	if low.find(PRICE_NEAR) >= 0:
		for m in PRICE_MARKS:
			if low.find(m) >= 0:
				bad.append(PRICE_NEAR)
				break
	return bad


static func ok(text: String) -> bool:
	return check(text).is_empty()


static func scan(texts: Array) -> Array:
	var out: = []
	for t in texts:
		var b: = check(str(t))
		if not b.is_empty():
			out.append({"text": str(t), "bad": b})
	return out


# ── UI strings ─────────────────────────────────────────────────────────────────────────────────────────────────

static func _re(p: String) -> RegEx:
	if not _re_cache.has(p):
		_re_cache[p] = RegEx.create_from_string(p)
	return _re_cache[p]


static func ui_check(text: String) -> Array:
	var low: = text.to_lower()
	for a in UI_ALLOW:
		low = low.replace(a, "#".repeat(a.length()))
	var bad: = []
	for e in UI_BANNED:
		var w: String = e[0]
		var hit: = false
		match str(e[1]):
			"start":
				hit = _word_hit(low, w, false)
			"word":
				hit = _word_hit(low, w, true)
			"sub":
				hit = low.find(w) >= 0
			"sub_case":
				hit = text.find(w) >= 0
			"case":
				# whole word in its exact case: «SR» is not inside «SSR», «R» is not the R of «RuStore»
				hit = _word_hit(text, w, true)
			"exact":
				hit = text.strip_edges() == w
			"re":
				hit = _re(w).search(low) != null
		if hit:
			bad.append(w)
	return bad


static func ui_ok(text: String) -> bool:
	return ui_check(text).is_empty()


static func ui_scan(texts: Array) -> Array:
	var out: = []
	for t in texts:
		var b: = ui_check(str(t))
		if not b.is_empty():
			out.append({"text": str(t), "bad": b})
	return out
