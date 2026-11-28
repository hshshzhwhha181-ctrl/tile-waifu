class_name TWWallet
extends RefCounted

# TWWallet (P10 / WP6): the ONE typed way to move currency. The truth is the V10Wallet inside the save (S.econ.wallet: balances,
# debt, earned / spent / revoked, HMAC seal on S.econ). The top-level fields S.gems / S.coins (+ S.tickets / S.petals / S.moon once
# they exist) are NOT a second ledger any more: they are a derived snapshot that only this class writes, kept in the save so that
# an older build, the recovery code (TWMigrate.check wants S.gems) and the cloud copy still read the balances they know.
# Nothing in the game reads them as input and nothing but this file writes them (tools/lint_no_direct_wallet.py).
#
#   TWWallet.for_state(S) -> TWWallet            the wallet of a state dictionary. The live G.S gets the live economy's wallet (so
#                                                its signals fire); any other dictionary (a selftest, a module lane) gets one built over
#                                                S.econ.wallet, created from the 0.9 balances the first time (V10Econ.from_legacy)
#   w.bal(key) -> int                            keys of the glossary: gems coins moon tickets petals (wallet keys crystal coin ... too)
#   w.can(cost) -> bool                          cost = {"gems": 30, "coins": 5}
#   w.spend(cost, src) -> Result                 all or nothing
#   w.grant(cost, src) -> Result                 a NEGATIVE amount or an unknown currency is an ERROR (push_error, last_error, nothing
#                                                changes), not a silent clamp. Zero is a no-op.
#   w.set_balance(key, n, src) -> Result         dev / selftest fixtures: moves the balance to n through wallet operations (so the
#                                                invariant keeps holding), never by writing the field
#   w.sync() -> int                              a leftover direct write of a mirror is UNDONE (and counted in direct_writes), then the
#                                                snapshot is rewritten from the wallet. Returns how many mirrors were corrected
#
# Result: {"ok": bool, "error": String, "events": Array}. events are WALLET_CHANGED dictionaries
#   {"type": "WALLET_CHANGED", "cur": "gems", "delta": +/-n, "bal": balance after, "src": src}   (GDD 3.5 event vocabulary)
# error: "" | "insufficient" | "negative_amount" | "unknown_currency"

const WALLET_KEY: = {"gems": "crystal", "moon": "moon", "coins": "coin", "tickets": "wish", "petals": "petal"}
const MIRRORS: = ["gems", "coins", "moon", "tickets", "petals"]
const IGNORED_KEYS: = ["tea"]       # legacy reward keys that carry nothing (there is no energy)

static var last_error: = ""         # the last refused grant / spend with a programming error (not "insufficient")
static var errors: = 0
static var direct_writes: = 0       # direct writes of a mirror found and undone since start (must stay 0)

static var _plain: TWWallet = null  # the last wallet built for a non-live state (selftests call it in loops)

var root: Dictionary                # the state whose mirrors this wallet writes
var w: V10Wallet
var _seen: = {}                     # what the mirrors read after our last write


func _init(state: Dictionary, wallet: V10Wallet) -> void:
	root = state
	w = wallet


# ── construction ───────────────────────────────────────────────────────────────────────────────────────────────

static func for_state(S: Dictionary) -> TWWallet:
	var live: = _live_econ()
	if live != null and is_same(S.get("econ"), live.st):
		return live_of(S, live.wallet)
	var cur = S.get("econ")
	if _plain != null and is_same(_plain.root, S) and cur is Dictionary and is_same(cur, _plain._econ_st) and is_same(_plain.w.st, (cur as Dictionary).get("wallet")):
		return _plain
	if not (S.get("econ") is Dictionary) or not ((S.econ as Dictionary).get("wallet") is Dictionary):
		S["econ"] = V10Econ.from_legacy(S, V10Meta.now_unix())
		_carry_extra(S, S.econ)
	var ec: Dictionary = S.econ
	if not (ec.get("clock") is Dictionary):
		ec["clock"] = {}
	var t: = TWWallet.new(S, V10Wallet.new(ec.wallet, V10Clock.new(ec.clock)))
	t._econ_st = ec
	t.write_mirrors()
	_plain = t
	return t


static var _live: TWWallet = null


# a plain state (selftest, module lane) that carries tickets / petals / moon of its own: they open the wallet too, once. V10Econ.from_legacy
# (the real 0.9 -> 0.10 migration) is left exactly as it was: it opens crystals and coins only
static func _carry_extra(S: Dictionary, ec: Dictionary) -> void:
	var wl: Dictionary = ec.wallet
	for k in ["tickets", "petals", "moon"]:
		var n: = maxi(0, int(S.get(k, 0)))
		if n == 0:
			continue
		var c: = wkey(k)
		for sec in ["bal", "earned"]:
			if not (wl.get(sec) is Dictionary):
				wl[sec] = {}
			wl[sec][c] = int(wl[sec].get(c, 0)) + n


# V10Money builds the wallet of the live G.S over G.econ.wallet
static func live_of(S: Dictionary, wallet: V10Wallet) -> TWWallet:
	if _live != null and is_same(_live.root, S) and _live.w == wallet:
		return _live
	_live = TWWallet.new(S, wallet)
	return _live


static func forget() -> void:
	_plain = null
	_live = null


# the live economy (G.econ), registered by V10Money.attach; null in a headless core run
static var live_econ: V10Econ = null


static func _live_econ() -> V10Econ:
	return live_econ


var _econ_st: Dictionary = {}


# ── reads ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func wkey(key: String) -> String:
	return str(WALLET_KEY.get(key, key))


static func glossary(wallet_key: String) -> String:
	for k in WALLET_KEY:
		if WALLET_KEY[k] == wallet_key:
			return k
	return wallet_key


func bal(key: String) -> int:
	_guard()
	return w.balance(wkey(key))


func can(cost: Dictionary) -> bool:
	_guard()
	for k in cost:
		var n: = int(cost[k])
		if n > 0 and w.balance(wkey(str(k))) < n:
			return false
	return true


func audit() -> Array:
	return w.audit()


# ── operations ─────────────────────────────────────────────────────────────────────────────────────────────────

func spend(cost: Dictionary, src: String = "") -> Dictionary:
	_guard()
	var plan: = _plan(cost, "spend")
	if not plan.error.is_empty():
		return _fail(plan.error, "spend %s" % str(cost))
	for k in plan.items:
		if w.balance(wkey(k)) < int(plan.items[k]):
			return {"ok": false, "error": "insufficient", "events": []}
	var ev: = []
	for k in plan.items:
		var n: int = plan.items[k]
		w.spend(wkey(k), n, src)
		ev.append(_event(k, -n, src))
	write_mirrors()
	return {"ok": true, "error": "", "events": ev}


func grant(cost: Dictionary, src: String = "") -> Dictionary:
	_guard()
	var plan: = _plan(cost, "grant")
	if not plan.error.is_empty():
		return _fail(plan.error, "grant %s (%s)" % [str(cost), src])
	var ev: = []
	for k in plan.items:
		var n: int = plan.items[k]
		w.add(wkey(k), n, src)
		ev.append(_event(k, n, src))
	write_mirrors()
	return {"ok": true, "error": "", "events": ev}


# the balance of `key` becomes n: a grant of the difference, or a spend of it. Fixtures only (shots, selftests, dev args)
func set_balance(key: String, n: int, src: String = "dev") -> Dictionary:
	_guard()
	var d: = n - w.balance(wkey(key))
	if n < 0:
		return _fail("negative_amount", "set_balance %s %d" % [key, n])
	if d > 0:
		return grant({key: d}, src)
	if d < 0:
		return spend({key: -d}, src)
	return {"ok": true, "error": "", "events": []}


# validates a whole bundle first: either every line is fine or nothing is applied
func _plan(cost: Dictionary, what: String) -> Dictionary:
	var items: = {}
	for k in cost:
		var key: = str(k)
		if key in IGNORED_KEYS or key == "items":
			continue
		var n: = int(cost[k])
		if not w.st.bal.has(wkey(key)):
			return {"error": "unknown_currency", "items": {}}
		if n < 0:
			return {"error": "negative_amount", "items": {}}
		if n > 0:
			items[key] = n
	return {"error": "", "items": items}


func _fail(code: String, what: String) -> Dictionary:
	errors += 1
	last_error = "%s: %s" % [code, what]
	push_error("TWWallet: " + last_error)
	return {"ok": false, "error": code, "events": []}


func _event(key: String, delta: int, src: String) -> Dictionary:
	return {"type": "WALLET_CHANGED", "cur": key, "delta": delta, "bal": w.balance(wkey(key)), "src": src}


# ── the derived snapshot ───────────────────────────────────────────────────────────────────────────────────────

# a direct write of a mirror since our last write is undone: the wallet is the truth
func _guard() -> int:
	var n: = 0
	for k in MIRRORS:
		if _seen.has(k) and root.has(k) and int(root[k]) != int(_seen[k]):
			n += 1
			direct_writes += 1
			push_error("TWWallet: a direct write of S.%s (%d -> %d) was undone; use TWWallet.grant / spend" % [k, int(_seen[k]), int(root[k])])
			root[k] = int(_seen[k])
	return n


# type-normalises snapshot keys of a state that may not have a wallet yet (a loaded save, a fresh default): present and integer. The values
# are NOT input: attach / for_state rewrite them from the wallet
static func ensure_keys(S: Dictionary, keys: Array) -> void:
	for k in keys:
		if k in MIRRORS:
			S[k] = int(S.get(k, 0))


func sync() -> int:
	var n: = _guard()
	write_mirrors()
	return n


func forget_mirrors() -> void:
	_seen.clear()


# tickets / petals / moon appear in the save only once they exist (old readers never saw them)
func write_mirrors() -> void:
	for k in MIRRORS:
		var v: = w.balance(wkey(k))
		if k in ["gems", "coins"] or v != 0 or root.has(k):
			root[k] = v
			_seen[k] = v
