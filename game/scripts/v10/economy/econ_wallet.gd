class_name V10Wallet
extends RefCounted

# V10Wallet — currency balances with an accounting invariant and refund debt.
#
#   bal[c] - debt[c] == earned[c] - spent[c] - revoked[c]      for every currency (audit() checks it)
#
#   add(c, n, src)          credit; pays off refund debt first. Returns what reached the balance.
#   spend(c, n, src)        -> bool, all or nothing
#   spend_premium(n, src)   -> {} or {"crystal": x, "moon": y}: free crystals first, then paid moonstone
#   revoke(c, n, src)       refund clawback: takes what is there, the rest becomes debt (never a negative balance)
#   premium()               crystal + moon (what the UI shows as «кристаллы» for pulls)
#   log                     last LOG_MAX operations [{t, c, d, src}] for support and plausibility checks
#
# Saved state: {"bal": {}, "debt": {}, "earned": {}, "spent": {}, "revoked": {}, "log": []}

signal changed(cur: String)

const LOG_MAX: = 120

var st: Dictionary
var clock: V10Clock


func _init(state: Dictionary = {}, clk: V10Clock = null) -> void:
	st = state
	clock = clk
	ensure()


func ensure() -> void:
	for k in ["bal", "debt", "earned", "spent", "revoked"]:
		var d = st.get(k, {})
		if not (d is Dictionary):
			d = {}
		var nd: = {}
		for c in V10Catalog.CURRENCIES:
			nd[c] = maxi(0, int(d.get(c, 0)))
		st[k] = nd
	if not (st.get("log") is Array):
		st["log"] = []


func balance(c: String) -> int:
	return int(st.bal.get(c, 0))


func debt(c: String) -> int:
	return int(st.debt.get(c, 0))


func premium() -> int:
	return balance("crystal") + balance("moon")


func _t() -> int:
	return clock.now() if clock != null else 0


func _log(c: String, d: int, src: String) -> void:
	st.log.append({"t": _t(), "c": c, "d": d, "src": src})
	while st.log.size() > LOG_MAX:
		st.log.pop_front()


func add(c: String, n: int, src: String = "") -> int:
	if n <= 0 or not st.bal.has(c):
		return 0
	st.earned[c] = int(st.earned[c]) + n
	var pay: = mini(int(st.debt[c]), n)
	st.debt[c] = int(st.debt[c]) - pay
	st.bal[c] = int(st.bal[c]) + n - pay
	_log(c, n, src)
	changed.emit(c)
	return n - pay


func can_spend(c: String, n: int) -> bool:
	return n >= 0 and balance(c) >= n


func spend(c: String, n: int, src: String = "") -> bool:
	if n < 0 or not st.bal.has(c) or balance(c) < n:
		return false
	if n == 0:
		return true
	st.bal[c] = int(st.bal[c]) - n
	st.spent[c] = int(st.spent[c]) + n
	_log(c, -n, src)
	changed.emit(c)
	return true


func spend_premium(n: int, src: String = "") -> Dictionary:
	if n < 0 or premium() < n:
		return {}
	var a: = mini(balance("crystal"), n)
	var b: = n - a
	spend("crystal", a, src)
	spend("moon", b, src)
	return {"crystal": a, "moon": b}


func revoke(c: String, n: int, src: String = "refund") -> int:
	# returns the part that could not be taken and became debt
	if n <= 0 or not st.bal.has(c):
		return 0
	var take: = mini(balance(c), n)
	st.bal[c] = int(st.bal[c]) - take
	st.debt[c] = int(st.debt[c]) + n - take
	st.revoked[c] = int(st.revoked[c]) + n
	_log(c, -n, src)
	changed.emit(c)
	return n - take


func has_debt() -> bool:
	for c in V10Catalog.CURRENCIES:
		if debt(c) > 0:
			return true
	return false


func audit() -> Array:
	var bad: = []
	for c in V10Catalog.CURRENCIES:
		var b: = balance(c)
		if b < 0 or debt(c) < 0:
			bad.append("wallet %s negative" % c)
		var lhs: = b - debt(c)
		var rhs: = int(st.earned[c]) - int(st.spent[c]) - int(st.revoked[c])
		if lhs != rhs:
			bad.append("wallet %s: balance %d - debt %d != earned %d - spent %d - revoked %d" % [c, b, debt(c),
				int(st.earned[c]), int(st.spent[c]), int(st.revoked[c])])
	return bad
