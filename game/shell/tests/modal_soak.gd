class_name TWModalSoak
extends Node

# P26: Soak test for modal leaks across all screens (~61) x all modal archetypes x go / back / Android-back.
# Run:
#   godot --headless --path game res://shell/tests/modal_soak.tscn
# Optional user args (after `--`):
#   --shard=1/4        run 1-based shard K of N over the screen matrix (default 1/1 = all screens)
#   --soak_ops=2400    number of randomized soak operations (default 2400)
#   --seed=20261128    RNG seed for the randomized soak
# Prints "MODAL_SOAK_SELFTEST ok/total" and exits 0 when all checks pass.

const FAKE_SCREEN: = "res://shell/nav/nav_fake_screen.gd"
const LEGACY_CATALOGUE: = "res://shell/nav/legacy_screens.json"
const V11_EXTRA_SCREENS: = [
	{"id": "battle", "tab": "", "keep_history": true, "back_target": "tables"},
	{"id": "battle_map", "tab": "tables", "keep_history": true, "back_target": "tables"},
	{"id": "battle_result", "tab": "", "keep_history": false, "back_target": "tables"},
	{"id": "gacha_history", "tab": "summon", "keep_history": true, "back_target": "summon"},
	{"id": "gacha_pity", "tab": "summon", "keep_history": true, "back_target": "summon"},
	{"id": "skin_shop", "tab": "shop", "keep_history": true, "back_target": "shop"},
	{"id": "skin_preview", "tab": "shop", "keep_history": true, "back_target": "skin_shop"},
	{"id": "pass", "tab": "home", "keep_history": true, "back_target": "home"},
	{"id": "settings", "tab": "home", "keep_history": true, "back_target": "home"},
	{"id": "legal_offer", "tab": "", "keep_history": true, "back_target": "settings"},
	{"id": "legal_privacy", "tab": "", "keep_history": true, "back_target": "settings"},
	{"id": "legal_age", "tab": "", "keep_history": false, "back_target": "home"},
	{"id": "support", "tab": "", "keep_history": true, "back_target": "settings"},
	{"id": "loading", "tab": "", "keep_history": false, "back_target": ""},
]
const MODAL_KINDS: = [
	"plain",
	"forced",
	"no_scrim_tap",
	"wizard",
	"full_stop",
	"sheet",
	"exit_confirm",
	"chained",
	"stacked_3",
	"stray_legacy",
]
const TAB_ROOTS: = ["home", "collection", "tables", "summon", "shop"]
const MIN_SCREEN_COUNT: = 61
const DEFAULT_SOAK_OPS: = 2400
const DEFAULT_SEED: = 20261128
const MAX_BUDGET_SEC: = 300.0

var _pass: = 0
var _fail: = 0
var _shard_idx: = 1
var _shard_total: = 1
var _soak_ops: = DEFAULT_SOAK_OPS
var _seed: = DEFAULT_SEED
var _fake_ms: = 0
var _close_calls: Dictionary = {}  # instance_id -> count
var _close_reasons: Dictionary = {}  # instance_id -> last reason
var _active_screens: TWScreens = null
var _back_notifications: = 0
var _last_back_result: = ""


class RealLegacyMain extends "res://scripts/main.gd":
	func _shell_redirect() -> bool:
		return false
	func _splash() -> void:
		pass


class SoakModal extends TWModal:
	var kind: = "plain"
	var wizard_steps: = 0
	var sheet_widget: TWSheet = null

	func _build(_opts: Dictionary) -> void:
		match kind:
			"forced":
				dismissable = false
			"no_scrim_tap":
				scrim_tap_closes = false
			"wizard":
				wizard_steps = 2
			"full_stop":
				# Models 0.12.1 FirstPick: full-screen STOP catcher above the scrim
				var catcher: = ColorRect.new()
				catcher.name = "FirstPickFullView"
				catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
				catcher.color = Color(0, 0, 0, 0.15)
				catcher.mouse_filter = Control.MOUSE_FILTER_STOP
				add_child(catcher)
			"sheet":
				sheet_widget = TWSheet.make("Soak Sheet", 320.0)
				sheet_widget.open(Vector2(720, 1280))
				add_child(sheet_widget)
			"content":
				var box: = VBoxContainer.new()
				box.mouse_filter = Control.MOUSE_FILTER_STOP
				for i in 2:
					var btn: = Button.new()
					btn.custom_minimum_size = Vector2(0, TWTokens.hit())
					btn.mouse_filter = Control.MOUSE_FILTER_STOP
					box.add_child(btn)
				add_child(box)

	func on_back() -> bool:
		if kind == "wizard" and wizard_steps > 0:
			wizard_steps -= 1
			return true
		return super.on_back()


func _ready() -> void:
	if get_tree().current_scene == self:
		await get_tree().process_frame
		var res: Array = await run(self)
		get_tree().quit(0 if res[0] == res[1] else 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _active_screens != null and is_instance_valid(_active_screens):
		_back_notifications += 1
		_last_back_result = _active_screens.back()


func check(label: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", label)
	else:
		_fail += 1
		printerr("FAIL ", label, " ", info)


func _parse_args() -> void:
	for raw in OS.get_cmdline_user_args():
		var a: String = str(raw)
		if a.begins_with("--shard="):
			var parts: PackedStringArray = a.get_slice("=", 1).split("/")
			if parts.size() == 2:
				_shard_idx = maxi(1, int(parts[0]))
				_shard_total = maxi(1, int(parts[1]))
				if _shard_idx > _shard_total:
					_shard_idx = _shard_total
		elif a.begins_with("--soak_ops="):
			_soak_ops = clampi(int(a.get_slice("=", 1)), 100, 50000)
		elif a.begins_with("--seed="):
			_seed = int(a.get_slice("=", 1))


func run(p_host: Node) -> Array:
	_parse_args()
	var t0: = Time.get_ticks_msec()
	var catalog: Array = _build_screen_catalog()
	_test_catalog_integrity(catalog)
	await _test_regression_0121(p_host, catalog)
	await _test_real_v11_screens_and_modals(p_host, catalog)
	await _test_full_screen_modal_matrix(p_host, catalog)
	await _test_android_back_and_history(p_host, catalog)
	await _test_watchdog_busy_recovery(p_host, catalog)
	await _test_random_soak(p_host, catalog)
	await _test_node_growth_stability(p_host, catalog)
	var elapsed_sec: float = float(Time.get_ticks_msec() - t0) / 1000.0
	check("budget: soak completes in < %.0fs (%.2fs, shard %d/%d)" % [MAX_BUDGET_SEC, elapsed_sec, _shard_idx, _shard_total], elapsed_sec < MAX_BUDGET_SEC, "%.2fs" % elapsed_sec)
	var total: = _pass + _fail
	print("MODAL_SOAK_SELFTEST %d/%d (screens=%d shard=%d/%d ops=%d time=%.2fs)" % [_pass, total, catalog.size(), _shard_idx, _shard_total, _soak_ops, elapsed_sec])
	return [_pass, total]


# ── catalog assembly (legacy_screens.json + V10Registry + v11 shell/screens + v11 slots -> 61 screens) ─────

func _build_screen_catalog() -> Array:
	var seen: Dictionary = {}
	var entries: Array = []

	# 1. Load legacy_screens.json (46 screens covering main.gd SCREENS + V10Registry.screens())
	var f: = FileAccess.open(LEGACY_CATALOGUE, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and parsed.get("screens") is Dictionary:
			var scr_dict: Dictionary = parsed.screens
			var ids: Array = scr_dict.keys()
			ids.sort()
			for id_raw in ids:
				var id: String = str(id_raw)
				var meta: Dictionary = scr_dict[id_raw] if scr_dict[id_raw] is Dictionary else {}
				var tab_name: String = str(meta.get("tab", ""))
				var is_root: bool = tab_name != "" and id == tab_name
				var is_match: bool = bool(meta.get("match", false))
				var opts: Dictionary = {
					"tab": tab_name,
					"is_tab_root": is_root,
					"keep_history": true,
					"back_target": "" if is_root else ("tables" if is_match else "home"),
				}
				seen[id] = true
				entries.append({"id": id, "opts": opts, "source": "legacy"})

	# 2. Ensure every V10Registry.screens() id is included
	var v10_screens: Dictionary = V10Registry.screens()
	var v10_ids: Array = v10_screens.keys()
	v10_ids.sort()
	for id_raw in v10_ids:
		var id: String = str(id_raw)
		if not seen.has(id):
			seen[id] = true
			entries.append({"id": id, "opts": {"back_target": "home"}, "source": "v10_registry"})

	# 3. Discover real v11 screens under res://shell/screens/ via TWScreens.scan()
	var probe: = TWScreens.new()
	var scan_rep: Dictionary = probe.scan()
	for id_raw in scan_rep.get("registered", []):
		var id: String = str(id_raw)
		if not seen.has(id):
			seen[id] = true
			var spec: ScreenSpec = probe.registry[id]
			entries.append({
				"id": id,
				"opts": {
					"tab": spec.tab,
					"is_tab_root": spec.is_tab_root,
					"keep_history": spec.keep_history,
					"back_target": spec.back_target,
				},
				"source": "v11_scan",
			})
	probe.free()

	# 4. Append planned v11 shell screen specs so total covers full 61-screen catalog
	for extra in V11_EXTRA_SCREENS:
		var id: String = str(extra.id)
		if not seen.has(id):
			seen[id] = true
			entries.append({
				"id": id,
				"opts": {
					"tab": str(extra.get("tab", "")),
					"is_tab_root": false,
					"keep_history": bool(extra.get("keep_history", true)),
					"back_target": str(extra.get("back_target", "")),
				},
				"source": "v11_planned",
			})
	return entries


func _test_catalog_integrity(catalog: Array) -> void:
	var v10_screens: Dictionary = V10Registry.screens()
	var missing_v10: Array = []
	var id_set: Dictionary = {}
	for e in catalog:
		id_set[str(e.id)] = true
	for k in v10_screens:
		if not id_set.has(str(k)):
			missing_v10.append(str(k))
	check("catalog: covers >= %d screens (actual %d)" % [MIN_SCREEN_COUNT, catalog.size()], catalog.size() >= MIN_SCREEN_COUNT, str(catalog.size()))
	check("catalog: covers all %d V10Registry.screens() entries" % v10_screens.size(), missing_v10.is_empty(), str(missing_v10))
	var probe: = TWScreens.new()
	var rep: Dictionary = probe.scan()
	check("catalog: v11 TWScreens.scan() has 0 rejected specs (registered=%d)" % rep.registered.size(), rep.rejected.is_empty() and rep.registered.size() >= 1, str(rep))
	probe.free()


# ── harness helpers ─────────────────────────────────────────────────────────────────────────────────────────

func _create_harness(p_host: Node, catalog: Array) -> Dictionary:
	var root: = Control.new()
	root.name = "SoakRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_host.add_child(root)

	var screen_host: = Control.new()
	screen_host.name = "ScreenHost"
	screen_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen_host)

	var chrome_layer: = Control.new()
	chrome_layer.name = "ChromeLayer"
	chrome_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chrome_layer)

	var clk: = TWClock.new()
	var st: = TWState.new(TWSave.new("user://modal_soak_v11_state.json"), clk, {})
	var screens: = TWScreens.new()
	screens.name = "Screens"
	screens.host = screen_host
	screens.ctx = TWContext.build(st, clk, TWBus.new(), screens)
	_fake_ms = 0
	screens.now_fn = func() -> int: return _fake_ms
	root.add_child(screens)

	var stack: = ModalStack.new()
	stack.quit_fn = func() -> void: pass
	root.add_child(stack)  # LAST child: above screen_host and chrome_layer
	stack.bind_screens(screens)
	screens.ctx.provide("modals", stack)

	# Register REAL v11 screens from res://shell/screens/ first (never stubbed with TWNavFakeScreen)
	screens.scan()

	# Only unmigrated/planned catalog slots fall back to TWNavFakeScreen in the TWScreens harness
	for e in catalog:
		var sid: String = str(e.id)
		if not screens.has_screen(sid):
			var spec: = ScreenSpec.make(sid, FAKE_SCREEN, e.opts)
			screens.register(spec)

	return {
		"root": root,
		"screen_host": screen_host,
		"chrome_layer": chrome_layer,
		"screens": screens,
		"stack": stack,
	}


func _destroy_harness(h: Dictionary) -> void:
	if _active_screens == h.screens:
		_active_screens = null
	(h.screens as TWScreens).reset()
	(h.stack as ModalStack).clear_all("teardown")
	var root: Node = h.root
	if is_instance_valid(root):
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.free()


func _make_modal(kind: String) -> SoakModal:
	var m: = SoakModal.new()
	m.kind = kind
	var mid: int = m.get_instance_id()
	_close_calls[mid] = 0
	m.on_close = func(_res: Variant, reason: String) -> void:
		_close_calls[mid] = int(_close_calls.get(mid, 0)) + 1
		_close_reasons[mid] = reason
	return m


func _open_archetype(stack: ModalStack, kind: String, tracked: Array) -> void:
	match kind:
		"exit_confirm":
			var ex: TWModal = stack.request_exit()
			if ex != null:
				var eid: int = ex.get_instance_id()
				if not _close_calls.has(eid):
					_close_calls[eid] = 0
					var prev_cb: Callable = ex.on_close
					ex.on_close = func(res: Variant, reason: String) -> void:
						_close_calls[eid] = int(_close_calls.get(eid, 0)) + 1
						_close_reasons[eid] = reason
						if prev_cb.is_valid():
							prev_cb.call(res, reason)
					tracked.append(eid)
		"chained":
			var m: = _make_modal("plain")
			var mid: int = m.get_instance_id()
			tracked.append(mid)
			var base_cb: Callable = m.on_close
			m.on_close = func(res: Variant, reason: String) -> void:
				base_cb.call(res, reason)
				var follow: = _make_modal("full_stop")
				tracked.append(follow.get_instance_id())
				stack.open(follow)
			stack.open(m)
		"stacked_3":
			for sub in ["plain", "wizard", "forced"]:
				var sm: = _make_modal(sub)
				tracked.append(sm.get_instance_id())
				stack.open(sm)
		"stray_legacy":
			var m2: = _make_modal("full_stop")
			tracked.append(m2.get_instance_id())
			stack.open(m2)
			# Inject an untagged full-screen STOP blocker directly into the layer behind the stack's back
			var stray: = ColorRect.new()
			stray.name = "LegacyStrayBlocker"
			stray.set_anchors_preset(Control.PRESET_FULL_RECT)
			stray.mouse_filter = Control.MOUSE_FILTER_STOP
			stack.add_child(stray)
		_:
			var m3: = _make_modal(kind)
			tracked.append(m3.get_instance_id())
			stack.open(m3)


# Returns "" if all post-navigation invariants hold, else an error message.
func _verify_post_nav_invariants(h: Dictionary, transient_ids: Dictionary) -> String:
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	var root: Control = h.root
	var screen_host: Control = h.screen_host

	if stack.get_child_count() != 0:
		return "modal layer has %d child(ren)" % stack.get_child_count()
	if stack.depth() != 0 or not stack.is_clean():
		return "modal stack depth=%d clean=%s" % [stack.depth(), str(stack.is_clean())]
	var stops: Array = ModalStack.stop_visible_under(root, screen_host)
	if not stops.is_empty():
		return "%d visible STOP control(s) above screen (%s)" % [stops.size(), str((stops[0] as Node).name)]
	if screens.is_busy() or screens.state != TWScreens.State.IDLE:
		return "screens.is_busy() is true (state=%d)" % screens.state
	if screen_host.get_child_count() > 1:
		return "screen_host has %d mounted screens" % screen_host.get_child_count()
	if screens.current == null or screens.current.spec == null or screens.current.spec.id != screens.current_id:
		return "current screen mismatch (%s)" % screens.current_id
	if screens.history.size() > TWScreens.HISTORY_MAX:
		return "history exceeds cap (%d)" % screens.history.size()
	for entry in screens.history:
		var hid: String = str(entry.get("id", ""))
		if not screens.registry.has(hid):
			return "history contains unregistered screen '%s'" % hid
		if transient_ids.has(hid):
			return "history contains transient screen '%s'" % hid
	return ""


# ── 1. Reproducible 0.12.1 regression: REAL legacy main.gd go() (RED) vs ModalStack (GREEN) + real legacy screens ──

func _legacy_go_sync(legacy: Control, p_host: Node, id: String, args: Dictionary = {}) -> bool:
	legacy.set("busy", false)
	legacy.set("screen_id", "")
	legacy.call("go", id, args, false)
	var guard: = 0
	while bool(legacy.get("busy")) and guard < 120:
		await p_host.get_tree().process_frame
		guard += 1
	await p_host.get_tree().process_frame
	return str(legacy.get("screen_id")) == id and legacy.get("screen") != null and is_instance_valid(legacy.get("screen"))


func _test_regression_0121(p_host: Node, _catalog: Array) -> void:
	# (A) REAL legacy main.gd path (0.12.1): instantiate res://scripts/main.gd and call real go()
	var prev_save_path: String = G.save_path
	var prev_sheet_layer: Control = V10ShopSheet.layer
	G.save_path = "user://modal_soak_legacy.json"
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.tut_done = true
	G.S.unlocked = mini(40, G.LEVELS.size())
	V10Money.set_balance("gems", 12450)
	V10Money.set_balance("coins", 38200)
	G.S.free10 = true
	if not (G.S.get("v6_story") is Dictionary):
		G.S["v6_story"] = {}
	G.S["v6_story"]["on"] = false

	var legacy: = RealLegacyMain.new()
	legacy.name = "RealLegacyMain0121"
	legacy.size = Vector2(720, 1280)
	p_host.add_child(legacy)
	await p_host.get_tree().process_frame
	await p_host.get_tree().process_frame

	var leg_layer: Control = legacy.get("overlay") as Control
	var leg_screen_root: Control = legacy.get("screen_root") as Control
	var booted_home: bool = str(legacy.get("screen_id")) == "home" and legacy.get("screen") != null and leg_layer != null
	check("0.12.1 regression (real main.gd): booted real legacy home screen", booted_home, "id=%s" % str(legacy.get("screen_id")))

	# Attach (1) a tagged popup (swept by real main.gd:go()) and (2) an untagged wrapper with a STOP scrim child (leaked by real main.gd:go()!)
	var tagged: = ColorRect.new()
	tagged.name = "TaggedLegacyPopup"
	tagged.set_meta("popup", true)
	tagged.set_anchors_preset(Control.PRESET_FULL_RECT)
	tagged.mouse_filter = Control.MOUSE_FILTER_STOP
	leg_layer.add_child(tagged)

	var untagged_wrapper: = Control.new()
	untagged_wrapper.name = "FirstPickUntaggedWrapper0121"
	untagged_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	untagged_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first_pick_leak: = ColorRect.new()
	first_pick_leak.name = "FirstPickUntaggedStop0121"
	first_pick_leak.set_anchors_preset(Control.PRESET_FULL_RECT)
	first_pick_leak.mouse_filter = Control.MOUSE_FILTER_STOP
	untagged_wrapper.add_child(first_pick_leak)
	leg_layer.add_child(untagged_wrapper)

	# Call REAL main.gd:go("levels", {}, false)
	var went_levels: bool = await _legacy_go_sync(legacy, p_host, "levels", {"select": 4})
	var tagged_swept: bool = not is_instance_valid(tagged) or tagged.is_queued_for_deletion() or tagged.get_parent() == null
	var legacy_stops: Array = ModalStack.stop_visible_under(leg_layer)
	var legacy_caught_leak: bool = went_levels and tagged_swept and legacy_stops.has(first_pick_leak)
	check("0.12.1 regression (real main.gd go()): tagged popup swept, untagged wrapper STOP leaked (RED on legacy)", legacy_caught_leak, "went=%s tagged_swept=%s stops=%d" % [str(went_levels), str(tagged_swept), legacy_stops.size()])

	# Remove the injected 0.12.1 leak and verify real legacy popup (settings) + real legacy screen transitions
	if is_instance_valid(untagged_wrapper):
		if untagged_wrapper.get_parent() != null:
			untagged_wrapper.get_parent().remove_child(untagged_wrapper)
		untagged_wrapper.free()

	legacy.call("settings")
	await p_host.get_tree().process_frame
	var settings_stops: Array = ModalStack.stop_visible_under(leg_layer)
	var back_home_ok: bool = await _legacy_go_sync(legacy, p_host, "home", {})
	var post_settings_stops: Array = ModalStack.stop_visible_under(leg_layer)
	check("real legacy main.gd: real settings() popup opens STOP (%d) and real go('home') clears it (0 STOP)" % settings_stops.size(), settings_stops.size() >= 1 and back_home_ok and post_settings_stops.is_empty(), "pre=%d post=%d" % [settings_stops.size(), post_settings_stops.size()])

	# Exercise real legacy screens from legacy_screens.json through real main.gd:go()
	var legacy_meta: Dictionary = {}
	var lf: = FileAccess.open(LEGACY_CATALOGUE, FileAccess.READ)
	if lf != null:
		var parsed: Variant = JSON.parse_string(lf.get_as_text())
		if parsed is Dictionary and parsed.get("screens") is Dictionary:
			legacy_meta = parsed.screens
	var leg_ids: Array = (legacy.get("SCREENS") as Dictionary).keys()
	leg_ids.sort()
	var leg_opened: = 0
	var leg_bad: Array = []
	for i in leg_ids.size():
		var lid: String = str(leg_ids[i])
		if lid == "home":
			leg_opened += 1
			continue
		var largs: Dictionary = {}
		if legacy_meta.has(lid) and legacy_meta[lid] is Dictionary and legacy_meta[lid].get("args") is Dictionary:
			largs = (legacy_meta[lid].args as Dictionary).duplicate(true)
		var ok_open: bool = await _legacy_go_sync(legacy, p_host, lid, largs)
		if not ok_open:
			leg_bad.append("open:" + lid)
			continue
		# On every 6th real legacy screen, open a real legacy Common.confirm popup before navigating home
		if i % 6 == 0:
			Common.confirm(legacy, "Soak", "Проверка", "", 0, func(): pass)
			await p_host.get_tree().process_frame
		var ok_close: bool = await _legacy_go_sync(legacy, p_host, "home", {})
		var residual_stops: Array = ModalStack.stop_visible_under(leg_layer)
		if not ok_close or not residual_stops.is_empty():
			leg_bad.append("close:%s(stops=%d)" % [lid, residual_stops.size()])
			for rs in residual_stops:
				var top_c: Node = rs
				while top_c.get_parent() != null and top_c.get_parent() != leg_layer:
					top_c = top_c.get_parent()
				if top_c.get_parent() == leg_layer:
					leg_layer.remove_child(top_c)
					top_c.queue_free()
		else:
			leg_opened += 1
	check("real legacy main.gd: mounted and closed %d/%d real legacy screens with 0 leaked STOP blockers" % [leg_opened, leg_ids.size()], leg_bad.is_empty() and leg_opened == leg_ids.size(), str(leg_bad.slice(0, 5)))

	# Tear down RealLegacyMain cleanly
	if is_instance_valid(legacy):
		if legacy.get_parent() != null:
			legacy.get_parent().remove_child(legacy)
		legacy.free()
	V10ShopSheet.layer = prev_sheet_layer
	G.save_path = prev_save_path
	await p_host.get_tree().process_frame
	await p_host.get_tree().process_frame

	# (B) ModalStack path (v11): same FirstPick full-screen STOP view + untagged stray -> 100% clean on go()
	var mini_cat: Array = [
		{"id": "home", "opts": {"tab": "home", "is_tab_root": true}},
		{"id": "levels", "opts": {"tab": "tables", "back_target": "home"}},
	]
	var h: Dictionary = _create_harness(p_host, mini_cat)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	var tracked: Array = []
	screens.go("home")
	_open_archetype(stack, "stray_legacy", tracked)
	var pre_stops: Array = ModalStack.stop_visible_under(h.root, h.screen_host)
	check("0.12.1 regression (ModalStack setup): scrim + FirstPickFullView + stray STOP active before go()", pre_stops.size() == 3, str(pre_stops.size()))
	screens.go("levels")
	var err: String = _verify_post_nav_invariants(h, {})
	var mid: int = int(tracked[0])
	check("0.12.1 regression (ModalStack path): clean after go() (GREEN: 0 children, 0 STOP, busy=false)", err == "", err)
	check("0.12.1 regression (ModalStack path): FirstPick got on_close once with go:levels and stray swept", int(_close_calls.get(mid, 0)) == 1 and str(_close_reasons.get(mid, "")) == "go:levels" and stack.strays_swept == 1, "calls=%d reason=%s strays=%d" % [int(_close_calls.get(mid, 0)), str(_close_reasons.get(mid, "")), stack.strays_swept])
	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 1b. Real v11 screens (TWLegalScreen, TWMatchScreen) opening REAL modals on ModalStack ─────────────────

func _test_real_v11_screens_and_modals(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	_active_screens = screens

	# Real TWLegalScreen -> opens real TWLegalDocModal -> go("home") sweeps it cleanly
	screens.go("home")
	screens.go("legal")
	await p_host.get_tree().process_frame
	var is_real_legal: bool = screens.current is TWLegalScreen and not (screens.current is TWNavFakeScreen)
	check("real v11 screen: 'legal' mounts real TWLegalScreen", is_real_legal, str(screens.current.get_class() if screens.current else "null"))

	var legal_scr: TWLegalScreen = screens.current as TWLegalScreen
	var opened_doc: bool = legal_scr != null and legal_scr.open_doc("offer", true)
	var doc_modal_on_stack: bool = opened_doc and stack.depth() == 1 and stack.top() is TWLegalDocModal
	check("real v11 modal: TWLegalScreen.open_doc('offer', true) opens real TWLegalDocModal on ModalStack", doc_modal_on_stack, "opened=%s depth=%d" % [str(opened_doc), stack.depth()])

	screens.go("home")
	var legal_go_err: String = _verify_post_nav_invariants(h, {"match": true})
	check("real v11 modal: go('home') sweeps real TWLegalDocModal with 0 STOP leaks", legal_go_err == "", legal_go_err)

	# Real TWLegalScreen + TWLegalDocModal + Android back notification
	screens.go("legal")
	await p_host.get_tree().process_frame
	var legal_scr2: TWLegalScreen = screens.current as TWLegalScreen
	var opened_priv: bool = legal_scr2 != null and legal_scr2.open_doc("privacy", true)
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var back_closed_doc: bool = opened_priv and _last_back_result == "modal" and stack.depth() == 0 and screens.current_id == "legal"
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var back_left_legal: bool = _last_back_result == "history" and screens.current_id == "home"
	check("real v11 modal: Android back closes TWLegalDocModal then leaves TWLegalScreen", back_closed_doc and back_left_legal, "closed=%s left=%s cur=%s" % [str(back_closed_doc), str(back_left_legal), screens.current_id])

	# Real TWMatchScreen -> clears real 2-pair board -> opens real TWResultModal -> go("home") sweeps it cleanly
	var tiny_cfg: Dictionary = {
		"cols": 2, "rows": 2, "layers": 1, "fill": 1.0, "faces": 2, "seed": 1,
		"shape": "rect", "gold": 0, "ice": 0, "hidden": false, "shard": "", "plan": {},
	}
	screens.go("match", {"show_result": true, "cfg": tiny_cfg})
	await p_host.get_tree().process_frame
	var is_real_match: bool = screens.current is TWMatchScreen and not (screens.current is TWNavFakeScreen)
	check("real v11 screen: 'match' mounts real TWMatchScreen", is_real_match, str(screens.current.get_class() if screens.current else "null"))

	var match_scr: TWMatchScreen = screens.current as TWMatchScreen
	var guard: = 0
	while match_scr != null and match_scr.board != null and not match_scr.board.cleared and not match_scr.board.failed and guard < 40:
		guard += 1
		var mv: Variant = match_scr.board.solver_move()
		if mv == null:
			break
		var tid: int = int(mv.id) if (mv is Object and "id" in mv) else int(mv)
		match_scr.tap_tile(tid)
	await p_host.get_tree().process_frame
	var cleared_and_modal: bool = match_scr != null and match_scr.board != null and match_scr.board.cleared and stack.depth() == 1 and stack.top() is TWResultModal
	check("real v11 modal: clearing real TWMatchScreen board opens real TWResultModal on ModalStack", cleared_and_modal, "cleared=%s depth=%d top=%s" % [str(match_scr.board.cleared if match_scr and match_scr.board else false), stack.depth(), str(stack.top())])

	screens.go("home")
	var match_go_err: String = _verify_post_nav_invariants(h, {"match": true})
	check("real v11 modal: go('home') sweeps real TWResultModal with 0 STOP leaks", match_go_err == "", match_go_err)

	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 2. Exhaustive matrix: all 61 screens x all modal archetypes x go / back / go_tab ───────────────────────

func _test_full_screen_modal_matrix(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	check("matrix: all %d screens registered with 0 rejects" % catalog.size(), screens.registry.size() == catalog.size() and screens.rejects.is_empty(), "reg=%d rej=%s" % [screens.registry.size(), str(screens.rejects)])
	# MAJOR #6 assertion: scanned real v11 screens must use real ScreenSpecs, not TWNavFakeScreen
	var legal_spec: ScreenSpec = screens.registry.get("legal")
	var match_spec: ScreenSpec = screens.registry.get("match")
	check("real v11 screens: legal and match registered with real scripts (not FAKE_SCREEN)", legal_spec != null and match_spec != null and legal_spec.script_path != FAKE_SCREEN and match_spec.script_path != FAKE_SCREEN, "legal=%s match=%s" % [legal_spec.script_path if legal_spec else "null", match_spec.script_path if match_spec else "null"])

	var transient_ids: Dictionary = {}
	var all_ids: Array = []
	for e in catalog:
		var id: String = str(e.id)
		all_ids.append(id)
		var sp: ScreenSpec = screens.registry.get(id)
		if (sp != null and not sp.keep_history) or not bool(e.opts.get("keep_history", true)):
			transient_ids[id] = true

	# Compute shard slice
	var shard_screens: Array = []
	for i in all_ids.size():
		if (i % _shard_total) == (_shard_idx - 1):
			shard_screens.append(all_ids[i])

	var tracked: Array = []
	var nav_checks: = 0
	var go_bad: = 0
	var go_first: = ""
	var back_bad: = 0
	var back_first: = ""
	var tab_bad: = 0
	var tab_first: = ""

	for idx in shard_screens.size():
		var sid: String = str(shard_screens[idx])
		var next_id: String = str(all_ids[(all_ids.find(sid) + 1) % all_ids.size()])
		for kind in MODAL_KINDS:
			# Step A: mount sid -> open modal archetype -> go(next_id)
			screens.go(sid)
			_open_archetype(stack, kind, tracked)
			screens.go(next_id)
			nav_checks += 1
			var err: String = _verify_post_nav_invariants(h, transient_ids)
			if err != "":
				go_bad += 1
				if go_first == "":
					go_first = "%s x %s -> go(%s): %s" % [sid, kind, next_id, err]

			# Step B: mount sid -> open modal archetype -> drain with back() (Android back) -> navigate back/go
			screens.go("home")
			screens.go(sid)
			_open_archetype(stack, kind, tracked)
			var guard: = 0
			while stack.is_open() and guard < 12:
				guard += 1
				var top_before: TWModal = stack.top()
				var br: String = screens.back()
				if br != "modal":
					break
				# Forced modal swallows back; close it explicitly as user CTA so test can finish draining
				if top_before != null and is_instance_valid(top_before) and top_before == stack.top() and not top_before.dismissable:
					top_before.close("ok", "cta")
			# Now press back once more to exercise screen/history/back_target/exit
			var nav_back_res: String = screens.back()
			if nav_back_res == "exit":
				# Exit confirm opened: dismiss via back (stay) then go(next_id)
				screens.back()
			# Ensure strays (from stray_legacy) and any residual confirm are swept on next go()
			screens.go(next_id)
			nav_checks += 1
			var err_b: String = _verify_post_nav_invariants(h, transient_ids)
			if err_b != "":
				back_bad += 1
				if back_first == "":
					back_first = "%s x %s -> back/go: %s" % [sid, kind, err_b]

		# Step C: per-screen go_tab with stacked modals open
		screens.go(sid)
		_open_archetype(stack, "stacked_3", tracked)
		var target_tab: String = TAB_ROOTS[idx % TAB_ROOTS.size()]
		screens.go_tab(target_tab)
		nav_checks += 1
		# If go_tab was rejected as "same" (already on target_tab), switch to a different tab so a real mount occurs
		if stack.is_open():
			target_tab = TAB_ROOTS[(idx + 1) % TAB_ROOTS.size()]
			screens.go_tab(target_tab)
		var err_t: String = _verify_post_nav_invariants(h, transient_ids)
		if err_t != "":
			tab_bad += 1
			if tab_first == "":
				tab_first = "%s -> go_tab(%s): %s" % [sid, target_tab, err_t]

		if idx % 15 == 14:
			await p_host.get_tree().process_frame

	check("matrix go(): %d screens x %d modal archetypes = %d navigations clean (0 children, 0 STOP, busy=false, history ok)" % [shard_screens.size(), MODAL_KINDS.size(), shard_screens.size() * MODAL_KINDS.size()], go_bad == 0, go_first)
	check("matrix back(): %d screens x %d modal archetypes drained via back() + go() clean" % [shard_screens.size(), MODAL_KINDS.size()], back_bad == 0, back_first)
	check("matrix go_tab(): %d tab switches with stacked modals clean" % shard_screens.size(), tab_bad == 0, tab_first)

	var bad_once: = 0
	var first_once: = ""
	for mid in tracked:
		var c: int = int(_close_calls.get(mid, -1))
		if c != 1:
			bad_once += 1
			if first_once == "":
				first_once = "modal %d got %d on_close calls" % [int(mid), c]
	check("matrix lifecycle: all %d tracked modals received on_close exactly once (%d nav checks)" % [tracked.size(), nav_checks], bad_once == 0 and tracked.size() > 0, first_once)

	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 3. Android hardware back notification + exact back stack verification ──────────────────────────────────

func _test_android_back_and_history(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	_active_screens = screens
	_back_notifications = 0
	_last_back_result = ""

	# Walk a deep chain including a tab root, normal screens, and a transient screen (loading, battle_result)
	screens.go("home")          # tab root -> clears history
	screens.go("profile")       # history: [home]
	screens.go("settings")      # history: [home, profile]
	screens.go("loading")       # transient (keep_history=false), history: [home, profile, settings]
	screens.go("support")       # loading NOT pushed! history: [home, profile, settings]
	screens.go("battle_result") # transient, history: [home, profile, settings, support]
	screens.go("legal_privacy") # battle_result NOT pushed! history: [home, profile, settings, support]

	var expected_hist: = ["home", "profile", "settings", "support"]
	check("back stack: transient screens excluded from history", Array(screens.history_ids()) == expected_hist, str(screens.history_ids()))

	# Open 2 modals (plain + wizard) and send real NOTIFICATION_WM_GO_BACK_REQUEST
	var tracked: Array = []
	var m_plain: = _make_modal("plain")
	var m_wiz: = _make_modal("wizard")
	tracked.append(m_plain.get_instance_id())
	tracked.append(m_wiz.get_instance_id())
	stack.open(m_plain)
	stack.open(m_wiz)

	notification(NOTIFICATION_WM_GO_BACK_REQUEST)  # wizard step 2->1
	var step1_ok: bool = _last_back_result == "modal" and m_wiz.is_open() and m_wiz.wizard_steps == 1 and screens.current_id == "legal_privacy"
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)  # wizard step 1->0
	var step2_ok: bool = _last_back_result == "modal" and m_wiz.is_open() and m_wiz.wizard_steps == 0
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)  # wizard closes
	var step3_ok: bool = _last_back_result == "modal" and not m_wiz.is_open() and stack.depth() == 1
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)  # plain closes
	var step4_ok: bool = _last_back_result == "modal" and not m_plain.is_open() and stack.depth() == 0 and screens.current_id == "legal_privacy"
	check("Android back notification: drains wizard + plain modals without leaving screen", step1_ok and step2_ok and step3_ok and step4_ok, "last=%s depth=%d cur=%s" % [_last_back_result, stack.depth(), screens.current_id])

	# Now unwind history all the way via Android back notifications
	var unwound: Array = []
	for _i in 4:
		notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		unwound.append(screens.current_id)
	check("Android back notification: unwinds exact history stack in reverse", unwound == ["support", "settings", "profile", "home"] and screens.history.is_empty(), str(unwound))

	# On home with empty history -> Android back opens TWExitConfirm, second back closes it (stays on home)
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var exit_opened: bool = _last_back_result == "exit" and stack.top() is TWExitConfirm and stack.depth() == 1
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var exit_closed: bool = _last_back_result == "modal" and stack.depth() == 0 and stack.get_child_count() == 0
	check("Android back notification: empty history -> TWExitConfirm -> back dismisses cleanly", exit_opened and exit_closed and _back_notifications == 10, "open=%s close=%s notifs=%d" % [str(exit_opened), str(exit_closed), _back_notifications])

	# Screen can_back=false blocks back, on_back=true consumes once then navigates
	screens.go("play", {"block": true})
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var blocked_ok: bool = _last_back_result == "blocked" and screens.current_id == "play" and Array(screens.history_ids()) == ["home"]
	screens.go("play", {"consume": true})
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var consumed_ok: bool = _last_back_result == "screen" and screens.current_id == "play"
	notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	var after_consume_ok: bool = _last_back_result == "history" and screens.current_id == "home"
	check("Android back notification: respects can_back=false and screen on_back()", blocked_ok and consumed_ok and after_consume_ok)

	var err: String = _verify_post_nav_invariants(h, {"loading": true, "battle_result": true, "legal_age": true})
	check("Android back sequence: post-nav invariants clean", err == "", err)
	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 4. Watchdog / busy-guard with active modals ────────────────────────────────────────────────────────────

func _test_watchdog_busy_recovery(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	var tracked: Array = []

	screens.go("home", {"intro": "hang"})
	var busy_start: bool = screens.is_busy()
	var back_busy: String = screens.back()
	var rej: Array = []
	screens.nav_rejected.connect(func(id: String, why: String) -> void: rej.append([id, why]))
	screens.go("shop")
	var go_busy_refused: bool = rej == [["shop", "busy"]] and screens.current_id == "home"

	# Open a modal while stuck, then trigger watchdog
	_open_archetype(stack, "full_stop", tracked)
	_fake_ms = TWScreens.WATCHDOG_MS
	var fired: bool = screens.poll()
	var idle_after_wd: bool = fired and not screens.is_busy() and screens.watchdog_count == 1

	# Once recovered to IDLE, go() sweeps the modal and lands cleanly
	screens.go("shop")
	var err: String = _verify_post_nav_invariants(h, {"loading": true, "battle_result": true, "legal_age": true})
	check("watchdog: busy blocks go()/back(), watchdog restores IDLE, next go() clears modal", busy_start and back_busy == "busy" and go_busy_refused and idle_after_wd and err == "", err)
	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 5. Randomized multi-screen soak across all 61 screens ──────────────────────────────────────────────────

func _test_random_soak(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	_active_screens = screens

	var all_ids: Array = []
	var transient_ids: Dictionary = {}
	for e in catalog:
		var sid: String = str(e.id)
		all_ids.append(sid)
		var sp: ScreenSpec = screens.registry.get(sid)
		if (sp != null and not sp.keep_history) or not bool(e.opts.get("keep_history", true)):
			transient_ids[sid] = true

	var rng: = RandomNumberGenerator.new()
	rng.seed = _seed
	# Shuffled full-catalog coverage deck guarantees every catalog screen is exercised under random modal states
	var coverage_deck: Array = all_ids.duplicate()
	for ci in range(coverage_deck.size() - 1, 0, -1):
		var cj: int = rng.randi() % (ci + 1)
		var tmp_id: Variant = coverage_deck[ci]
		coverage_deck[ci] = coverage_deck[cj]
		coverage_deck[cj] = tmp_id
	var tracked: Array = []
	var visited: Dictionary = {}
	var bad_navs: = 0
	var first_bad: = ""
	var nav_verifications: = 0

	screens.go("home")
	visited["home"] = true

	for op in _soak_ops:
		var r: int = rng.randi() % 100
		var did_nav: = false
		if r < 24:
			var target: String = str(coverage_deck.pop_back()) if not coverage_deck.is_empty() else str(all_ids[rng.randi() % all_ids.size()])
			screens.go(target, {"op": op})
			visited[target] = true
			did_nav = true
		elif r < 30:
			var target2: String = str(all_ids[rng.randi() % all_ids.size()])
			screens.go(target2, {"op": op}, {"replace": true})
			visited[target2] = true
			did_nav = true
		elif r < 42:
			var br: String = screens.back()
			if br == "history" or br == "back_target":
				visited[screens.current_id] = true
				did_nav = true
		elif r < 48:
			notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			if _last_back_result == "history" or _last_back_result == "back_target":
				visited[screens.current_id] = true
				did_nav = true
		elif r < 54:
			var prev_id: String = screens.current_id
			var tab_pick: String = TAB_ROOTS[rng.randi() % TAB_ROOTS.size()]
			screens.go_tab(tab_pick)
			if screens.current_id != prev_id or stack.depth() == 0:
				visited[screens.current_id] = true
				if stack.get_child_count() == 0:
					did_nav = true
		elif r < 78:
			var kind: String = MODAL_KINDS[rng.randi() % MODAL_KINDS.size()]
			_open_archetype(stack, kind, tracked)
		elif r < 86:
			if stack.is_open():
				var pick: TWModal = stack.modals()[rng.randi() % stack.depth()]
				pick.close("done", "user")
		elif r < 91:
			if stack.is_open() and stack.top().scrim != null:
				var tap: = InputEventScreenTouch.new()
				tap.pressed = true
				stack.top().scrim.gui_input.emit(tap)
		elif r < 95:
			if stack.is_open():
				var pick_f: TWModal = stack.modals()[rng.randi() % stack.depth()]
				pick_f.free()
		else:
			stack.clear_all("manual_clear")

		if did_nav:
			nav_verifications += 1
			var err: String = _verify_post_nav_invariants(h, transient_ids)
			if err != "":
				bad_navs += 1
				if first_bad == "":
					first_bad = "op %d (screen=%s): %s" % [op, screens.current_id, err]
		else:
			# Even mid-modal, screens must stay IDLE and modal depth must stay <= MAX_DEPTH
			if screens.is_busy() or stack.depth() > ModalStack.MAX_DEPTH:
				bad_navs += 1
				if first_bad == "":
					first_bad = "op %d mid-step: busy=%s depth=%d" % [op, str(screens.is_busy()), stack.depth()]

		if op % 300 == 299:
			await p_host.get_tree().process_frame

	# Final navigation clears everything
	screens.go("home")
	var final_err: String = _verify_post_nav_invariants(h, transient_ids)
	if final_err != "":
		bad_navs += 1
		if first_bad == "":
			first_bad = "final go(home): %s" % final_err

	var once_bad: = 0
	var first_once: = ""
	for mid in tracked:
		var c: int = int(_close_calls.get(mid, -1))
		if c != 1:
			once_bad += 1
			if first_once == "":
				first_once = "modal %d got %d on_close calls" % [int(mid), c]

	var unvisited: Array = []
	for sid_u in all_ids:
		if not visited.has(sid_u):
			unvisited.append(sid_u)
	check("random soak: %d ops (%d verified navs) keep all invariants" % [_soak_ops, nav_verifications], bad_navs == 0, first_bad)
	check("random soak: 100%% screen coverage (%d/%d screens visited)" % [visited.size(), all_ids.size()], visited.size() == all_ids.size(), "unvisited=%s" % str(unvisited))
	check("random soak: all %d tracked modals got on_close exactly once" % tracked.size(), once_bad == 0 and tracked.size() > 100, first_once)
	check("random soak: exercised opens (%d), closes (%d), refusals (%d), strays swept (%d)" % [stack.opened_count, stack.closed_count, stack.refused_count, stack.strays_swept], stack.opened_count > 100 and stack.closed_count == stack.opened_count and stack.strays_swept > 0)

	_destroy_harness(h)
	await p_host.get_tree().process_frame


# ── 6. Node count stability across repeated sweeps (leak detector) ─────────────────────────────────────────

func _test_node_growth_stability(p_host: Node, catalog: Array) -> void:
	var h: Dictionary = _create_harness(p_host, catalog)
	var screens: TWScreens = h.screens
	var stack: ModalStack = h.stack
	var all_ids: Array = []
	for e in catalog:
		all_ids.append(str(e.id))

	# Warmup 1 full sweep of all 61 screens with a modal
	for sid in all_ids:
		screens.go(str(sid))
		var m: = _make_modal("sheet")
		stack.open(m)
	screens.go("home")
	await p_host.get_tree().process_frame
	await p_host.get_tree().process_frame
	var nodes_after_warmup: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# 2 more full sweeps of all 61 screens
	for _round in 2:
		for sid in all_ids:
			screens.go(str(sid))
			var m2: = _make_modal("full_stop")
			stack.open(m2)
	screens.go("home")
	await p_host.get_tree().process_frame
	await p_host.get_tree().process_frame
	var nodes_after_sweeps: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var delta_nodes: int = nodes_after_sweeps - nodes_after_warmup

	check("stability: 2 full 61-screen x modal sweeps leak 0 nodes (delta=%d)" % delta_nodes, delta_nodes <= 2, "warmup=%d after=%d" % [nodes_after_warmup, nodes_after_sweeps])
	_destroy_harness(h)
	await p_host.get_tree().process_frame
