class_name V10MjSanmaAI
extends RefCounted

# ИИ санмы: обёртка над V8AI (стили основательниц те же).
#  - kita всегда, кроме случая, когда Север нужен руке как тройка (3+ северов в руке)
#    или когда в риичи вытянут не Север (тогда кита по правилам нельзя);
#  - чи ИИ никогда не предлагается (call_options санмы его не даёт) и не объявляется;
#  - остальное — V8AI.turn / V8AI.decide_call.

const NORTH: = 30

static func keep_north(r, s: int) -> bool:
	var n: = 0
	for t in r.hands[s]:
		if t >> 2 == NORTH:
			n += 1
	return n >= 3

static func want_kita(r, s: int, o: Dictionary) -> bool:
	if not o.get("kita", false):
		return false
	return not keep_north(r, s)

static func turn(r, s: int, o: Dictionary) -> Dictionary:
	if o.get("tsumo", false):
		return {"a": "tsumo"}
	if want_kita(r, s, o):
		return {"a": "kita"}
	return V8AI.turn(r, s, o)

static func decide_call(r, s: int, opts: Dictionary) -> Dictionary:
	var o: = opts.duplicate()
	o.chi = []
	var a: Dictionary = V8AI.decide_call(r, s, o)
	if a.get("a", "") == "chi":
		return {"a": "pass"}
	return a

# Подсказка «что сбросить» для Учебного зала (как V8AI.coach, но с кита).
static func coach(r, s: int) -> Dictionary:
	var o: Dictionary = r.turn_options(s)
	if want_kita(r, s, o):
		return {"a": "kita"}
	var pick: = V8AI.choose_discard(r, s, V8AI.STYLES.coach, o.forbidden)
	return {"a": "discard", "t": pick.t, "shanten": pick.shanten}
