class_name V10JuiceSelftest
extends RefCounted

# V10Juice self-test (headless-safe): level gates, particle budget, «минимум» fallbacks (no particles, fountain
# callbacks fire at once, transition is a short fade), milestones, sound and shader files.
#   godot --headless --path game res://scripts/v10/juice/demo/juice_demo.tscn -- --juice_selftest=1
# prints «JUICE SELFTEST ok/total» and quits (exit code 1 on a failure).

static var ok: = 0
static var total: = 0
static var fails: Array = []


static func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("JUICE FAIL: ", what)


static func run(host: Node) -> void:
	var tree: = host.get_tree()
	# levels
	V10Juice.forced_level = "full"
	check(V10Juice.n(10) == 10, "full n(10) == 10")
	check(V10Juice.can_shake(), "full can_shake")
	V10Juice.forced_level = "mid"
	check(V10Juice.n(10) == 6, "mid n(10) == 6")
	check(not V10Juice.can_shake() and V10Juice.can_fx(), "mid: fx without shake")
	V10Juice.forced_level = "min"
	check(V10Juice.n(10) == 0, "min n(10) == 0")
	check(V10Juice.burst(host, Vector2(100, 100), "star4", 20) == null, "min: no burst")
	check(V10Juice.idle_sparkle(host as Control if host is Control else null) == null, "min: no idle sparkle")
	var calls: = [0, 0]
	V10Juice.fountain(Vector2(10, 10), Vector2(300, 10), "coin", 7, func(_i): calls[0] += 1, func(): calls[1] += 1)
	check(calls[0] == 7 and calls[1] == 1, "min: fountain callbacks fire at once (7 + done)")
	var t0: = Time.get_ticks_msec()
	await V10Juice.cover("ink", 0.34)
	var dt: = Time.get_ticks_msec() - t0
	check(dt < 400, "min: cover is a short fade (%d ms)" % dt)
	check(V10JuiceTransition.inst.style == "fade", "min: cover style is fade")
	await V10Juice.reveal()
	check(V10JuiceTransition.inst.state == "idle" and not V10JuiceTransition.inst.rect.visible, "reveal → idle, hidden")
	check(V10JuiceTransition.inst.rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "reveal frees the taps")
	# full: budget
	V10Juice.forced_level = "full"
	await tree.process_frame
	for i in 40:
		V10Juice.burst(host, Vector2(200, 200), "spark", 20)
	check(V10Juice.live_emitters <= V10Juice.budget("emitters"), "emitter cap (%d ≤ %d)" % [V10Juice.live_emitters, V10Juice.budget("emitters")])
	check(V10Juice.live_particles <= V10Juice.budget("particles"), "particle cap (%d ≤ %d)" % [V10Juice.live_particles, V10Juice.budget("particles")])
	t0 = Time.get_ticks_msec()
	await V10Juice.cover("petal", 0.3)
	check(V10JuiceTransition.inst.state == "covered" and V10JuiceTransition.inst.style == "petal", "full: petal cover reaches covered")
	check(V10JuiceTransition.inst.rect.mouse_filter == Control.MOUSE_FILTER_STOP, "cover swallows taps")
	await V10Juice.reveal(0.2)
	check(V10JuiceTransition.inst.state == "idle", "full: reveal → idle")
	check(V10Juice.style_for("home") == "lantern" and V10Juice.style_for("levels") == "ink" and V10Juice.style_for("collection") == "petal", "tab styles")
	# milestones
	check(not V10Juice.combo_milestone(7), "×7 is not a milestone")
	check(V10Juice.combo_milestone(10, Rect2(0, 100, 720, 120)), "×10 shows a banner")
	check(V10JuiceBanner.current != null, "banner exists")
	# files
	for snd in V10Juice.SOUND_FALLBACK:
		if snd == "twinkle":
			continue
		check(ResourceLoader.exists(V10Juice.SFX % snd), "sound file " + snd)
	for sh in ["juice_ink_wipe", "juice_iris", "juice_petal_wipe", "juice_dissolve", "juice_glint", "juice_outline_glow",
			"juice_bloom_fake", "juice_frame_aura", "juice_godrays", "juice_ring", "juice_ink_splat", "juice_brush_band",
			"juice_seal", "juice_sweep_rr"]:
		check(V10Juice.shader(sh) != null, "shader " + sh)
	# suits
	check(V10Juice.suit_of(0) == 0 and V10Juice.suit_of(35) == 4 and V10Juice.suit_of(-1) == -1, "suit_of")
	# wait for the one-shots to finish: counters must return to zero (no leak)
	await tree.create_timer(2.6).timeout
	check(V10Juice.live_emitters == 0 and V10Juice.live_particles == 0, "no leaked emitters (%d / %d)" % [V10Juice.live_emitters, V10Juice.live_particles])
	V10Juice.forced_level = ""
	print("JUICE SELFTEST %d/%d" % [ok, total])
	tree.quit(0 if ok == total else 1)
