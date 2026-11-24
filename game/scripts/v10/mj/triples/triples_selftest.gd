extends Node

# Тройки: самотест / запекание / пробы. См. README.
#   --mj_triples_selftest=1            итог MJ_TRIPLES ok/total, код выхода 0 только при 100 %
#   --triples_bake=1                   подбор сидов ботом → game/data/mj/triples/bake.json
#   --triples_probe=1 --from= --to= --x=0,0.5   пробы долей бота (разработка)

var args: = {}

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_TRIPLES watchdog: 600 s")
		get_tree().quit(2))
	await get_tree().process_frame
	if args.has("triples_probe"):
		_probe()
		get_tree().quit(0)
	elif args.has("triples_bake"):
		_bake()
	else:
		get_tree().quit(1)


func _probe() -> void:
	var from: = int(args.get("from", "1"))
	var to: = int(args.get("to", "10"))
	var t0: = Time.get_ticks_msec()
	if args.has("x"):
		for xs in String(args.x).split(","):
			for i in range(from, to + 1):
				var lv: = V10MjTriplesGen.build(i, float(xs), 0)
				var ok: = V10MjTriplesGen.certificate_ok(lv)
				print("i=%d x=%s n=%d kinds=%d hold=%d ok=%s rate=%.2f" % [i, xs, lv.n, lv.kinds, lv.hold, ok, V10MjTriplesGen.bot_rate(lv)])
	else:
		for i in range(from, to + 1):
			print(JSON.stringify(V10MjTriplesGen.calibrate(i)))
	print("ms=", Time.get_ticks_msec() - t0)


func _bake() -> void:
	var t0: = Time.get_ticks_msec()
	var d: = V10MjTriplesGen.bake(V10MjTriplesGen.BAKE_PATH, func(e): print(JSON.stringify(e)))
	print("TRIPLES_BAKE miss=%d ms=%d" % [int(d.miss), Time.get_ticks_msec() - t0])
	get_tree().quit(0)
