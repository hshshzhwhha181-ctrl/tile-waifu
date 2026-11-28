class_name LegacyHostSelftest
extends RefCounted

# LEGACY_HOST_SELFTEST ok/total (suite `legacy_host`, run as `godot --path game res://shell/main_v11.tscn -- --legacy_selftest=1`).
# Lives apart from legacy_host.gd because it probes `main.overlay` (the legacy popup layer), which tools/lint_modal_only_via_stack.py
# lets no other file under game/shell touch (this one is on SHELL_ALLOWED like modal_selftest.gd).
#
#   1. shell wired: the host is current_scene, ctx/ModalStack/TWScreens exist, Home is up
#   2. the duck-typed `main` API the legacy screens call (methods and members) is all there
#   3. legacy_screens.json == the live SCREENS table
#   4. every catalogued screen is opened and closed through the host: it mounts, it frees, the modal layer is clean,
#      overlay does not grow, 0 SCRIPT ERROR and 0 engine ERROR (except the teardown noise below)
#   5. a v11 modal takes android_back before the legacy chain

const DWELL: = 0.45  # seconds a screen lives before it is closed, and the grace after (tweens / timers of the old screen fire)

# Engine ERRORs a legacy screen raises when it is freed under a running tween / timer (a lambda that captured the freed screen; a
# sound started on a node that just left the tree). The v10 shell does exactly the same on every go(); counted and printed, not failed.
const TEARDOWN_NOISE: = ["Lambda capture at index", "Playback can only happen when a node is inside the scene tree"]

const API_METHODS: = ["go", "back", "android_back", "toast", "show_chrome", "refresh_currency", "refresh_nav", "fly_gems", "need_gems",
	"maybe_offer", "settings", "leave_match", "rank_ladder", "toggle_master_mute", "is_audio_on", "_select_tab", "_top_popup", "art_icon", "gem_target"]
const API_MEMBERS: = ["screen", "overlay", "screen_root", "CR", "W", "H", "safe_top", "safe_bottom", "trans", "topbar", "navbar", "tab_nodes",
	"SCREENS", "history", "finger"]

var h: LegacyHost
var log_: Variant = null
var ok: = 0
var total: = 0
var fails: Array = []
var teardown_noise: = 0


static func run(host: LegacyHost) -> void:
	var t: = LegacyHostSelftest.new()
	t.h = host
	await t._run()


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		printerr("FAIL legacy_host: " + what)


func _errs() -> int:
	if log_ == null:
		return 0
	var n: int = log_.script_errors.size()
	var noise: = 0
	for e in log_.errors:
		var is_noise: = false
		for k in TEARDOWN_NOISE:
			if k in String(e):
				is_noise = true
		if is_noise:
			noise += 1
		else:
			n += 1
	teardown_noise = noise
	return n


func _run() -> void:
	log_ = V8Playtest.ErrLog.new()
	OS.add_logger(log_)
	var tree: = h.get_tree()
	await tree.process_frame
	# 1. shell
	check(tree.current_scene == h, "current_scene is the host")
	check(h.ctx != null and h.ctx.service("legacy_host") == h and h.ctx.screens == h.tw_screens, "ctx wired")
	check(h.modals != null and h.modals.get_index() == h.get_child_count() - 1 and not h.modals.visible, "ModalStack last child, hidden while empty")
	check(h.screen_id == "home" and h.screen != null, "boots into the v10 Home")
	# 2. main API
	for m in API_METHODS:
		check(h.has_method(m), "API method " + m)
	for p in API_MEMBERS:
		check(h.get(p) != null, "API member " + p)
	check(h.get("busy") is bool and h.get("screen_id") is String, "API busy / screen_id")
	# 3. catalogue
	var drift: = h.catalogue_drift()
	check(drift.missing.is_empty(), "catalogue covers every screen: missing %s" % [drift.missing])
	check(drift.stale.is_empty(), "catalogue has no stale entry: %s" % [drift.stale])
	check(h.ids().size() >= 40 and h.ids().size() == h.SCREENS.size(), "catalogue size %d" % h.ids().size())
	# 4. every screen opens and closes
	for id in h.ids():
		if id == "home":
			continue
		var e0: int = _errs()
		var opened: bool = await h.open(id)
		check(opened, "open " + id)
		await tree.create_timer(DWELL).timeout
		var n_ov: int = h.overlay.get_child_count()
		var s: Node = h.screen
		var closed: bool = await h.close()
		check(closed and h.screen_id == "home", "close " + id)
		await tree.create_timer(DWELL).timeout
		check(h.modals.is_clean() and h.modals.depth() == 0, "modal layer clean after " + id)
		check(h.overlay.get_child_count() <= n_ov, "overlay did not grow on close " + id)
		check(s == null or not is_instance_valid(s) or s.is_queued_for_deletion(), "screen node freed " + id)
		var de: int = _errs() - e0
		check(de == 0, "no script error in %s (%d)" % [id, de])
		if de > 0:
			for m2 in (log_.script_errors + log_.errors).slice(-3):
				printerr("  err: " + String(m2).left(300))
		# whatever a screen left over home is swept so the next one starts clean
		for c in h.overlay.get_children():
			if not c.has_meta("v8_toast") and c is Control and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				c.queue_free()
	# 5. v11 modal back first
	var m: = TWModal.new()
	h.modals.open(m)
	check(h.modals.is_open() and h.modals.visible, "v11 modal opens and shows the layer")
	h.android_back()
	await tree.process_frame
	check(not h.modals.is_open() and not h.modals.visible, "android_back closes the v11 modal first")
	_errs()
	print("LEGACY_HOST_SELFTEST %d/%d  (screens %d, legacy teardown noise %d)" % [ok, total, h.ids().size(), teardown_noise])
	for f in fails:
		print("  FAIL ", f)
	tree.quit()
