class_name V10Lint
extends RefCounted

# V10Lint — the one stop-word list of 0.10 (docs/0.10-spec.md §2.7). Every heroine-facing string (notifications,
# letters, chats, feed, scenes) goes through check() before it can be shown. The heroine never guilts the player
# and never talks about money: no «скучала», «вернись», prices, discounts, «успей», «только сегодня»…
#
#   V10Lint.check(text) -> Array   the banned fragments found (empty = clean)
#   V10Lint.ok(text) -> bool
#   V10Lint.scan(texts: Array) -> Array    [{text, bad:[…]}] for every dirty string (selftests)
#
# Matching is by lower-case substring, so «скуча» catches «скучала» / «скучаю». «бесплатн» is banned only next to
# a price («бесплатно» alone is fine in a reward caption, «бесплатно, а потом 79 ₽» is not): see PRICE_MARKS.
# Owner: lane meta (the spec puts it at v10/core/lint.gd — the integrator may move the file, the class name stays).

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк",
	"успей", "последн", "только сегодня", "купи", "баннер", "акци", "цена"]
# allowed words that contain a banned fragment (lower case): «однажды» is not «одна»
const ALLOW: = ["однажды", "ещё одна", "одна чашка", "одна партия"]
const PRICE_NEAR: = "бесплатн"
const PRICE_MARKS: = ["₽", "руб", "цен", "стоит", "%"]


static func check(text: String) -> Array:
	var low: = text.to_lower()
	var masked: = low
	for a in ALLOW:
		masked = masked.replace(a, "#".repeat(a.length()))
	var bad: = []
	for w in BANNED:
		if masked.find(w) >= 0:
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
