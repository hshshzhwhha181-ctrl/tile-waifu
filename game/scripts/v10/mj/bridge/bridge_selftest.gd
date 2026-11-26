extends Node

var args: = {}

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	await get_tree().process_frame
	if args.has("bridge_gen"):
		var t0: = Time.get_ticks_msec()
		var n: = int(args.bridge_gen)
		var d: = V10MjBridgeDaily.generate(n, func(it, tries): print("gen %d %s tries=%d sh=%d uke=%d best=%s" % [it.n, it.kind, tries, it.sh, it.uke, str(it.best)]))
		print("gen ms=", Time.get_ticks_msec() - t0, " tries=", d.tries)
		if n == 365:
			V10MjBridgeDaily.write(V10MjBridgeDaily.DATA_PATH, d)
	if args.has("bridge_bake"):
		var t0: = Time.get_ticks_msec()
		V10MjBridgeLevels.bake(V10MjBridgeLevels.BAKE_PATH, func(e): print(JSON.stringify(e)))
		print("bake ms=", Time.get_ticks_msec() - t0)
	if args.has("bridge_compile"):
		for f in ["bridge_tiles", "bridge_daily", "bridge_hand", "bridge_levels", "bridge_save", "bridge_info", "bridge_look", "bridge_icon", "bridge_tile", "bridge_presence", "bridge_daily_screen", "bridge_hand_screen"]:
			var sc: = load("res://scripts/v10/mj/bridge/%s.gd" % f)
			print("compile ", f, " ", sc != null and sc.can_instantiate())
	if args.has("bridge_probe"):
		var from: = int(args.get("from", "1"))
		var to: = int(args.get("to", "60"))
		for i in range(from, to + 1):
			var t0: = Time.get_ticks_msec()
			var lv: = V10MjBridgeLevels.build(i)
			var t1: = Time.get_ticks_msec()
			var sv: = V10MjBridgeLevels.solve(lv, int(args.get("budget", "6000")))
			var t2: = Time.get_ticks_msec()
			print("L%d n=%d req=%d digs=%d att=%d target=%s mult=%d build=%dms solve=%s nodes=%d %dms" % [i, lv.n, lv.req, lv.digs, lv.attempt, str(lv.target), V10MjBridgeHand.combos(lv.target).mult, t1 - t0, sv.ok, sv.nodes, t2 - t1])
	get_tree().quit(0)
