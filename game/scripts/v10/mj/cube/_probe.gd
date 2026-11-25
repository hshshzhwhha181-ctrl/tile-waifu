extends SceneTree
func _init():
	var t0 = Time.get_ticks_msec()
	for i in range(1, 41):
		var lv = V10MjCubeGen.build(i)
		var ok = V10MjCubeGen.certificate_ok(lv)
		print("%2d %-16s %-8s n=%3d dims=%s core=%d kinds=%d ok=%s cert=%s hidden=%.2f" % [i, lv.name, lv.kind, lv.n, str(lv.dims), (lv.core as Array).size(), lv.kinds, lv.ok, ok, float(lv.get("hidden0", 0))])
	print("ms ", Time.get_ticks_msec() - t0)
	quit()
