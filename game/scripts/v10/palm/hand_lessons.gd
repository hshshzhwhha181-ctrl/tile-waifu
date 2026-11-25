class_name V10HandLessons
extends RefCounted

# «Разбор ожиданий» (spec R4 «Школа ожиданий», shown under another name: HEROINES red lines forbid a school theme).
# 7 разборов × 3 hands ≈ 2 minutes each, on the shelf «Столы». Hands come from the same generator (V10HandGen.
# lesson_hand), without a board: all 13 cards open, or — разбор 7 «Рукав» — 2 closed cards whose answer is unique
# given the kinds listed «Не у неё». No rewards (the daily budget lives in the hand of the day).
#
#   V10HandLessons.LESSONS[n - 1] -> {n, form, hidden, title, line}
#   V10HandLessons.task(n, i) -> {hand, sleeve, waits, form, notin}    (i = 0..TASKS-1, deterministic)
#   V10HandLessons.check(n, i, picked: Array) -> {ok, missing, extra, text}   ok iff picked == waits (as sets)
#   V10HandLessons.mark(n, i, ok) / solved(n, i) / done(n) / is_open(n) / lock_text(n) / progress() -> [0..3 ×7]

const U: = preload("res://scripts/v10/palm/hand_util.gd")
const GEN: = preload("res://scripts/v10/palm/hand_gen.gd")
const ST: = preload("res://scripts/v10/palm/hand_state.gd")
const T: = preload("res://scripts/v10/palm/hand_text.gd")

const TASKS: = 3
const LESSONS: = [
	{"n": 1, "form": "ryanmen", "hidden": 0, "title": "С двух сторон", "line": "Две соседние карты ждут фишку слева или справа: 4-5 ждут 3 и 6."},
	{"n": 2, "form": "kanchan", "hidden": 0, "title": "В середину", "line": "Карты через одну ждут ту, что между ними: 3 и 5 ждут 4."},
	{"n": 3, "form": "penchan", "hidden": 0, "title": "С края", "line": "1-2 ждут только 3, а 8-9 ждут только 7."},
	{"n": 4, "form": "tanki", "hidden": 0, "title": "Пара", "line": "Когда четыре тройки или ряда собраны, лишняя карта ждёт себе пару."},
	{"n": 5, "form": "nobetan", "hidden": 0, "title": "Ряд из четырёх", "line": "Ряд 2-3-4-5 ждёт пару с любого конца: 2 или 5."},
	{"n": 6, "form": "sanmen", "hidden": 0, "title": "Три стороны", "line": "Ряд из пяти ждёт три фишки: 3-4-5-6-7 ждёт 2, 5 и 8."},
	{"n": 7, "form": "ryanmen", "hidden": 2, "title": "Рукав", "line": "Закрытые карты лежат по порядку: их место в ряду подсказывает, что там."},
]

static var _cache: = {}


static func lesson(n: int) -> Dictionary:
	return LESSONS[clampi(n, 1, LESSONS.size()) - 1]


static func task(n: int, i: int) -> Dictionary:
	var k: = "%d|%d" % [n, i]
	if not _cache.has(k):
		var l: = lesson(n)
		_cache[k] = GEN.lesson_hand(String(l.form), 7000 + n * 31 + i, int(l.hidden))
	return _cache[k]


static func check(n: int, i: int, picked: Array) -> Dictionary:
	var t: = task(n, i)
	var want: Array = t.get("waits", [])
	var missing: = []
	var extra: = []
	for w in want:
		if not (int(w) in picked):
			missing.append(int(w))
	for p in picked:
		if not (int(p) in want) and not (int(p) in extra):
			extra.append(int(p))
	var ok: = missing.is_empty() and extra.is_empty() and not want.is_empty()
	var text: = T.LESSON_RIGHT
	if not ok:
		var parts: = []
		if not missing.is_empty():
			parts.append(T.LESSON_MISS % ("ещё " + GEN.kinds_text(missing)))
		if not extra.is_empty():
			parts.append(T.LESSON_EXTRA % GEN.kinds_text(extra))
		text = ". ".join(parts)
	return {"ok": ok, "missing": missing, "extra": extra, "text": text, "explanation": GEN.explain(t.hand, want) if ok else ""}


static func _mask(n: int) -> int:
	return int((ST.st().lessons as Dictionary).get(str(n), 0))


static func mark(n: int, i: int, ok: bool) -> void:
	if not ok:
		return
	var l: Dictionary = ST.st().lessons
	l[str(n)] = _mask(n) | (1 << clampi(i, 0, TASKS - 1))


static func solved(n: int, i: int) -> bool:
	return (_mask(n) >> i) & 1 == 1


static func done(n: int) -> bool:
	return _mask(n) == (1 << TASKS) - 1


static func is_open(n: int) -> bool:
	return n <= 1 or done(n - 1)


static func lock_text(n: int) -> String:
	return "" if is_open(n) else T.LESSON_LOCK % (n - 1)


static func progress() -> Array:
	var out: = []
	for l in LESSONS:
		var c: = 0
		for i in TASKS:
			if solved(int(l.n), i):
				c += 1
		out.append(c)
	return out


static func all_strings() -> Array:
	var out: = []
	for l in LESSONS:
		out.append(String(l.title))
		out.append(String(l.line))
		out.append(T.LESSON_N % int(l.n) + " · " + String(l.title))
	return out
