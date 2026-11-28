class_name V10WalletGoldenSelftest
extends RefCounted

# Part of RECOVERY_SELFTEST (lives outside game/core because it drives the live autoload G, which core files must not touch).
# P10: the wallet of every golden save (v4..v8, game/tests/fixtures/saves) through the LIVE load path, then a fixed sequence of money
# operations, a save and a reload. game/tests/fixtures/saves/wallet_golden.json was recorded from the code BEFORE P10 (V10Money with the
# mirrors and _absorb, commit e21d382): the wallet, its earned / spent / log, S.gems / S.coins / S.tickets / S.petals and the sealed file
# must come out identical.
static func run(_check: Callable) -> void:
	var fx_dir: = "res://tests/fixtures/saves/"
	var want = JSON.parse_string(FileAccess.get_file_as_string(fx_dir + "wallet_golden.json"))
	_check.call("wallet golden: wallet_golden.json present (5 saves)", want is Dictionary and (want as Dictionary).size() == 5)
	if not (want is Dictionary):
		return
	var dw0: = TWWallet.direct_writes
	for name in ["v4", "v5", "v6", "v7", "v8"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string(fx_dir + name + ".json"))
		var r: = {}
		r["apply"] = G.apply_state(d)
		r["after_load"] = _wsnap()
		V10Money.grant({"gems": 10, "coins": 5, "tickets": 2, "petals": 3}, "golden")
		r["spend_ok"] = V10Money.spend({"gems": 100, "coins": 7}, "golden")
		r["spend_too_much"] = V10Money.spend({"gems": 10000000}, "golden")
		r["can_all"] = V10Money.can({"gems": 1, "coins": 1})
		r["pull_split"] = V10Money.pull_split(10, 150)
		G.save()
		r["after_ops"] = _wsnap()
		var disk = G.read_save_file(G.save_path)
		r["disk"] = {"gems": disk.gems, "coins": disk.coins, "has_tickets": disk.has("tickets"), "tickets": disk.get("tickets", -1),
			"petals": disk.get("petals", -1), "sealed": V10Econ.verify(disk.econ)}
		G.load_game()
		r["reloaded"] = _wsnap()
		var got = JSON.parse_string(JSON.stringify(r))
		_check.call("wallet golden %s: wallet, snapshot, ops, sealed file and reload equal the pre-P10 code" % name, got == want.get(name), "")
		_check.call("wallet golden %s: balances are the 0.9 ones, invariant holds, no direct write seen" % name,
			(G.econ.audit() as Array).is_empty() and TWWallet.direct_writes == dw0, str(G.econ.audit()))


static func _wsnap() -> Dictionary:
	var w: Dictionary = G.econ.wallet.st
	var lg: = []
	for e in w.log:
		lg.append([e.c, e.d, e.src])
	return {"gems": G.S.get("gems"), "coins": G.S.get("coins"), "tickets": G.S.get("tickets", "-"), "petals": G.S.get("petals", "-"),
		"moon": G.S.get("moon", "-"), "bal": w.bal.duplicate(), "earned": w.earned.duplicate(), "spent": w.spent.duplicate(),
		"debt": w.debt.duplicate(), "revoked": w.revoked.duplicate(), "log": lg, "audit": G.econ.audit()}
