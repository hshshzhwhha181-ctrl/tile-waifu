class_name V10Money
extends RefCounted

# V10Money — the ONE money facade of the game (docs/INTEGRATION_0.10.md §3.1), a thin layer over TWWallet (P10 / WP6). The truth is the
# economy wallet G.econ.wallet (V10Econ, saved as S.econ with an HMAC seal: refunds, debt, audit). S.gems / S.coins / S.tickets /
# S.petals / S.moon are a DERIVED SNAPSHOT kept in the save for older builds and recovery: only TWWallet writes them, nothing reads them as
# input, and a direct write is undone and counted (TWWallet.direct_writes), never turned into money (the old _absorb path is gone).
#
#   V10Money.bal("gems") -> int                         keys of the glossary (spec §2.1): gems coins moon tickets petals
#   V10Money.can({"gems": 30}) -> bool
#   V10Money.spend({"gems": 30, "coins": 5}, src) -> bool    all or nothing
#   V10Money.grant({"gems": 15}, src, from = Vector2(-1, -1))   a negative amount is an error (TWWallet.last_error), not a clamp
#   V10Money.set_balance("gems", 12450, src)             fixtures / dev args / shots: the balance becomes n through wallet operations
#   V10Money.pull_split(n, each) -> {tickets, gems, moon, ok}  how an n-wish price is paid (tickets → crystals → moon)
#   V10Money.attach(S)                                   G: after every load/import (builds G.econ, writes the snapshot)
#   V10Money.sync(S)                                     G.save(): the snapshot is rewritten from the wallet (a direct write is undone)
# A grant of "items" passes through to the economy inventory (V10Econ.grant).

static var _attaching: = false


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null


static func econ() -> V10Econ:
	var g = _g()
	if g == null:
		return null
	var e = g.get("econ")
	# G.S was swapped (selftests, an import outside load_game): rebuild the wallet from the state that is live now
	if e is V10Econ and not is_same(g.S.get("econ"), (e as V10Econ).st) and not _attaching:
		attach(g.S)
		e = g.get("econ")
	return e as V10Econ if e is V10Econ else null


# the live wallet (null before G has one)
static func _tw() -> TWWallet:
	var e: = econ()
	var g = _g()
	if e == null or g == null:
		return null
	return TWWallet.live_of(g.S, e.wallet)


static func _wkey(key: String) -> String:
	return TWWallet.wkey(key)


static func bal(key: String) -> int:
	var t: = _tw()
	if t:
		return t.bal(key)
	var g = _g()
	return int(g.S.get(key, 0)) if g else 0


static func can(cost: Dictionary) -> bool:
	var t: = _tw()
	if t:
		return t.can(cost)
	for k in cost:
		if int(cost[k]) > 0 and bal(k) < int(cost[k]):
			return false
	return true


static func spend(cost: Dictionary, src: = "") -> bool:
	var t: = _tw()
	if t == null:
		return false
	return bool(t.spend(cost, src).ok)


static func grant(d: Dictionary, src: = "", _from: = Vector2(-1, -1)) -> void:
	var t: = _tw()
	if t == null:
		return
	var cur: = {}
	for k in d:
		if k == "items":
			var e: = econ()
			if e:
				e.grant({"items": d[k]}, src)
		else:
			cur[k] = d[k]
	t.grant(cur, src)


static func set_balance(key: String, n: int, src: = "dev") -> void:
	var t: = _tw()
	if t:
		t.set_balance(key, n, src)


# n wishes at `each` crystals: tickets first, then crystals, then moonstone (spec §2.1, UX §5.3)
static func pull_split(n: int, each: int) -> Dictionary:
	var t: = mini(n, bal("tickets"))
	var rest: = (n - t) * each
	var gm: = mini(rest, bal("gems"))
	var mn: = rest - gm
	return {"tickets": t, "gems": gm, "moon": mn, "ok": mn <= bal("moon")}


# ── wiring (G) ─────────────────────────────────────────────────────────────────────────────────────────────────

static func attach(S: Dictionary) -> void:
	var g = _g()
	if g == null:
		return
	_attaching = true
	var ed = S.get("econ")
	if not (ed is Dictionary) or (ed as Dictionary).is_empty() or not ((ed as Dictionary).get("wallet") is Dictionary):
		ed = V10Econ.from_legacy(S, V10Meta.now_unix())
		S["econ"] = ed
	var cur = g.get("econ")
	var e: V10Econ
	if cur is V10Econ and is_same(ed, (cur as V10Econ).st):
		e = cur as V10Econ
	else:
		e = V10Econ.load_dict(ed)
		e.season_outfit = "y_ball"
		e.item_granted.connect(func(id: String, _src: String) -> void:
			var gg = _g()
			if gg == null:
				return
			if gg.ITEM.has(id):
				gg.give_new(id)
			else:
				V10ProfileCos.grant(gg.S, id))
		e.changed.connect(func() -> void:
			if not _attaching:
				_write_mirrors())
	e.shop.set_provider(V10ShopPay.make_provider())
	e.owns = func(id: String) -> bool: return g.owns(id)
	S["econ"] = e.st
	g.set("econ", e)
	# the day's grants (month card) and store receipts; NOT e.tick(): it pays «Воск» for ended banners (spec: no wax)
	e.shop.reconcile()
	TWWallet.forget()          # the snapshot is rewritten from the wallet below: whatever S.gems held on load is not input
	_attaching = false
	_write_mirrors()


static func on_resumed() -> void:
	var e: = econ()
	if e == null:
		return
	e.clock.resume()
	e.shop.reconcile()
	_write_mirrors()


static func sync(S: Dictionary) -> void:
	var e: = econ()
	if e == null or not is_same(S.get("econ"), e.st):
		return
	TWWallet.live_of(S, e.wallet).sync()


static func _write_mirrors() -> void:
	var t: = _tw()
	if t:
		t.sync()
