extends Node

# dev bench (not shipped in the hub): generation speed and bot rate


func _ready() -> void:
	var t0: = Time.get_ticks_msec()
	var fails: = 0
	var att: = 0
	for i in 90:
		var tb: = Time.get_ticks_msec()
		var p: = V10MjConnectGen.build(i, 0, false, 0)
		if p.is_empty():
			fails += 1
			continue
		att += int(p.attempt)
		var v: = V10MjConnectGen.verify(p)
		if i % 10 == 0 or v != "" or Time.get_ticks_msec() - tb > 400:
			print("L%d %s %s %dx%d n=%d long=%.2f att=%d lock=%d ice=%d ms=%d verify='%s'" % [i, p.code, p.variant, p.cols, p.rows, p.n, p.long_share, p.attempt, p.lock.size(), p.ice.size(), Time.get_ticks_msec() - tb, v])
	print("total ms ", Time.get_ticks_msec() - t0, " fails ", fails, " attempts ", att)
	for li in [0, 15, 45, 77, 89]:
		var p2: = V10MjConnectGen.build(li, 0)
		var tb2: = Time.get_ticks_msec()
		print("L%d bot rate %.2f ms %d" % [li, V10MjConnectGen.bot_rate(p2, 4), Time.get_ticks_msec() - tb2])
	get_tree().quit()
