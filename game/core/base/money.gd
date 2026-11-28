class_name V10Money
extends RefCounted

# V10Money — the ONE money facade of the game (docs/INTEGRATION_0.10.md §3.1). The truth is the economy wallet
# G.econ.wallet (V10Econ, saved as S.econ with an HMAC seal: refunds, debt, audit). The 0.9 top-level fields
# S.gems / S.coins / S.tickets / S.petals / S.moon stay as MIRRORS for the old UI: only this file writes them.
#
#   V10Money.bal("gems") -> int                         keys of the glossary (spec §2.1): gems coins moon tickets petals
#   V10Money.can({"gems": 30}) -> bool
#   V10Money.spend({"gems": 30, "coins": 5}, src) -> bool    all or nothing
#   V10Money.grant({"gems": 15}, src, from = Vector2(-1, -1))
#   V10Money.pull_split(n, each) -> {tickets, gems, moon, ok}  how an n-wish price is paid (tickets → crystals → moon)
#   V10Money.attach(S)                                   G: after every load/import (builds G.econ, mirrors)
#   V10Money.sync(S)                                     G.save(): a leftover direct write of a mirror becomes a
#                                                        wallet operation (src "legacy"), then the mirrors are rewritten
# A grant of "items" passes through to the economy inventory (V10Econ.grant).

const WALLET_KEY: = {"gems": "crystal", "moon": "moon", "coins": "coin", "tickets": "wish", "petals": "petal"}
const MIRRORS: = ["gems", "coins", "moon", "tickets", "petals"]

static var _mirror: = {}   # what the mirrors read after our last write (a difference = someone wrote S.gems directly)
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
	if e is V10Econ and not _attaching:
		_absorb(e, g.S)
	return e as V10Econ if e is V10Econ else null


# a direct write of a mirror (old code, dev args, selftests) since our last write becomes a wallet operation
static func _absorb(e: V10Econ, S: Dictionary) -> void:
	for k in MIRRORS:
		if not _mirror.has(k) or not S.has(k):
			continue
		var d: = int(S[k]) - int(_mirror[k])
		if d == 0:
			continue
		_mirror[k] = int(S[k])
		if d > 0:
			e.wallet.add(_wkey(k), d, "legacy")
		else:
			e.wallet.spend(_wkey(k), mini(-d, e.wallet.balance(_wkey(k))), "legacy")


static func _wkey(key: String) -> String:
	return str(WALLET_KEY.get(key, key))


static func bal(key: String) -> int:
	var e: = econ()
	if e:
		return e.wallet.balance(_wkey(key))
	var g = _g()
	return int(g.S.get(key, 0)) if g else 0


static func can(cost: Dictionary) -> bool:
	for k in cost:
		if int(cost[k]) > 0 and bal(k) < int(cost[k]):
			return false
	return true


static func spend(cost: Dictionary, src: = "") -> bool:
	if not can(cost):
		return false
	var e: = econ()
	var g = _g()
	for k in cost:
		var n: = int(cost[k])
		if n <= 0:
			continue
		if e:
			e.wallet.spend(_wkey(k), n, src)
		elif g:
			g.S[k] = int(g.S.get(k, 0)) - n
	_write_mirrors()
	return true


static func grant(d: Dictionary, src: = "", _from: = Vector2(-1, -1)) -> void:
	var e: = econ()
	var g = _g()
	for k in d:
		if k == "items":
			if e:
				e.grant({"items": d[k]}, src)
			continue
		var n: = int(d[k])
		if n == 0:
			continue
		if n < 0:
			# a negative grant is a correction (dev tools, a refund in the old code): take what is there
			if e:
				e.wallet.spend(_wkey(k), mini(-n, e.wallet.balance(_wkey(k))), src)
			elif g:
				g.S[k] = maxi(0, int(g.S.get(k, 0)) + n)
			continue
		if e:
			e.wallet.add(_wkey(k), n, src)
		elif g:
			g.S[k] = int(g.S.get(k, 0)) + n
	_write_mirrors()


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
	_mirror.clear()
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
	var e: = econ()   # absorbs a direct write of the mirrors
	if e == null or not is_same(S.get("econ"), e.st):
		return
	_write_mirrors()


static func _write_mirrors() -> void:
	var g = _g()
	var e: = econ()
	if g == null or e == null:
		return
	for k in MIRRORS:
		var v: = e.wallet.balance(_wkey(k))
		# tickets/petals/moon appear in the save only once they exist (old readers never saw them)
		if k in ["gems", "coins"] or v != 0 or g.S.has(k):
			g.S[k] = v
			_mirror[k] = v
