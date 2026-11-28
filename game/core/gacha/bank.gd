class_name V10GachaBank
extends RefCounted

# V10GachaBank — what the gacha spends and gives, behind one small interface so the lane works on the 0.9 save
# (G.S keys gems / tickets / petals / coins / owned) today and on V10Wallet (v10-economy) after M1 without changes
# in V10Gacha2. The integrator subclasses it (see README «Хуки») to route through econ.wallet and G.give.
# Spend order of one wish (spec §2.1): tickets → crystals → moonstone.

var S: Dictionary
var give_fn: Callable = Callable()        # optional: G.give(id) -> bool (true when new); default writes S.owned
var live_money: = false
# P09: TWGacha.pull switches this on for the length of one pull and reads `ledger` afterwards: every movement of money through
# the bank as {cur, delta, src} in order (the payment, then the petals / crystals of duplicates). Off: nothing is recorded.
var record: = false
var ledger: Array = []


func _init(state: Dictionary = {}) -> void:
	S = state


func balance(cur: String) -> int:
	if live_money:
		return V10Money.bal(cur)
	return TWWallet.for_state(S).bal(cur)


func _note(cur: String, delta: int) -> void:
	if record and delta != 0:
		ledger.append({"cur": cur, "delta": delta, "src": "gacha"})


func add(cur: String, n: int) -> void:
	_note(cur, n)
	if live_money:
		V10Money.grant({cur: n}, "gacha")
		return
	TWWallet.for_state(S).grant({cur: n}, "gacha")


func spend(cur: String, n: int) -> bool:
	if n <= 0:
		return true
	var done: bool = V10Money.spend({cur: n}, "gacha") if live_money else bool(TWWallet.for_state(S).spend({cur: n}, "gacha").ok)
	if done:
		_note(cur, -n)
	return done


func owns(id: String) -> bool:
	return S.get("owned", {}).has(id)


# grant an item; true when it is new (a duplicate is left to V10Stars and must not pay crystals here)
func give(id: String) -> bool:
	if owns(id):
		return false
	if give_fn.is_valid():
		return bool(give_fn.call(id))
	if not (S.get("owned") is Dictionary):
		S["owned"] = {}
	S.owned[id] = true
	return true


# how n wishes of `cost` each would be paid: {tickets, gems, moon, ok, gems_left}
func split(n: int, cost: int, tickets_ok: bool = true) -> Dictionary:
	var t: = mini(n, balance("tickets")) if tickets_ok else 0
	var rest: = (n - t) * cost
	var g: = mini(rest, balance("gems"))
	var m: = mini(rest - g, balance("moon"))
	return {"tickets": t, "gems": g, "moon": m, "ok": g + m == rest, "gems_left": balance("gems") - g}


func pay(sp: Dictionary) -> bool:
	if not bool(sp.get("ok", false)):
		return false
	spend("tickets", int(sp.tickets))
	spend("gems", int(sp.gems))
	spend("moon", int(sp.moon))
	return true


static func split_text(sp: Dictionary) -> String:
	var parts: = []
	if int(sp.tickets) > 0:
		parts.append("%d %s" % [sp.tickets, plural(int(sp.tickets), "билет", "билета", "билетов")])
	if int(sp.gems) > 0:
		parts.append("%s %s" % [V10Rates.group(int(sp.gems)), plural(int(sp.gems), "кристалл", "кристалла", "кристаллов")])
	if int(sp.get("moon", 0)) > 0:
		parts.append("%s Лунного камня" % V10Rates.group(int(sp.moon)))
	return "Спишется: " + " → ".join(parts) if not parts.is_empty() else ""


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m: = n % 100
	if m >= 11 and m <= 14:
		return many
	match n % 10:
		1: return one
		2, 3, 4: return few
	return many
