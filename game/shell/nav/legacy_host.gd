class_name LegacyHost
extends "res://scripts/main.gd"

# LegacyHost (P25 / WP8c): the v10 shell running as the unmigrated part of the v11 shell.
#
# main_v11.tscn's root IS a LegacyHost. It `extends` the frozen v10 main (scripts/main.gd, untouched), so the whole duck-typed
# `main` API the 16 + 45 legacy screens use stays exactly what it was: go / back / android_back / toast / overlay / screen /
# screen_id / refresh_currency / refresh_nav / show_chrome / fly_gems / need_gems / maybe_offer / settings / leave_match /
# CR / W / H / safe_* / busy / trans / topbar / navbar / tab_nodes / SCREENS / history. The reason it is an extension and not a
# re-implementation: 19 legacy sites find the root through `get_tree().current_scene` (G.pull, the tutorial, info cards,
# the playtest runner), 88 `has_method` probes and 103 `main.screen` pokes reach into its internals; a copy would drift
# silently, an extension cannot. Pixel identity of Home (acceptance) follows from the same fact.
#
# What the host adds on top of main.gd:
#   * the v11 plumbing next to the legacy chrome: `ctx` (TWContext: state / clock / bus / screens), `screens` (TWScreens, in the
#     tree, empty until the first v11 screen migrates) and `modals` (ModalStack, LAST child, hidden while empty so the legacy
#     `android_back` child scan never sees it). `ctx.service("legacy_host")` is this node.
#   * `android_back()`: a v11 modal first (ModalStack.handle_back), then the legacy back chain unchanged.
#   * a catalogue of the 61 legacy screen ids (legacy_screens.json) checked against the live SCREENS table: `ids()`,
#     `info(id)`, `catalogue_drift()`; `open(id, args)` / `close()` = go() that returns once the screen is mounted / unmounted.
#   * `--legacy_selftest=1` (suite `legacy_host`): every id opened and closed through the host, errors counted by a Logger.
#
# Default launch stays v10: main.tscn only hands over when `--shell=v11` is a user arg (or ProjectSettings `tw/shell` = "v11",
# which nothing sets), see main.gd `_shell_redirect`.

const CATALOGUE: = "res://shell/nav/legacy_screens.json"
const SELFTEST_SAVE: = "user://legacy_host_selftest.json"

var ctx: TWContext
var tw_screens: TWScreens
var modals: ModalStack
var _catalogue: Dictionary = {}


func _shell_redirect() -> bool:
	return false  # we ARE the v11 scene: never bounce back


func _ready() -> void:
	var uargs: = OS.get_cmdline_user_args()
	var selftest: = "--legacy_selftest=1" in uargs
	var slice: = _slice_mode(uargs) != ""
	if selftest:
		_prepare_selftest_save()
	_load_catalogue()
	super._ready()
	_build_v11()
	if selftest:
		_selftest.call_deferred()
	elif slice:
		TWSlice.run.call_deferred(self)   # P37: --slice=play|goldens|perf (shell/tests/slice_playthrough.gd)
	elif "--legacy_dump=1" in uargs:
		_dump.call_deferred()


# `godot --path game res://shell/main_v11.tscn -- --legacy_dump=1`: the live SCREENS table as catalogue rows (regenerate legacy_screens.json)
func _dump() -> void:
	var rows: = {}
	for id in SCREENS:
		rows[id] = {"script": (SCREENS[id] as Script).resource_path}
	print("LEGACY_DUMP ", JSON.stringify(rows))
	get_tree().quit()


func _prepare_selftest_save() -> void:
	# never touch the player's save; a finished profile so no title card / intro / tutorial gets in the way
	G.save_path = SELFTEST_SAVE
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.tut_done = true
	G.S.unlocked = mini(40, G.LEVELS.size())
	V10Money.set_balance("gems", 12450)
	V10Money.set_balance("coins", 38200)
	G.S.free10 = true
	_v6_opt("v6_story.on", false)  # story scenes before a level wait for a tap


func _slice_mode(uargs: PackedStringArray) -> String:
	for a in uargs:
		if a.begins_with("--slice="):
			return a.substr(8)
	return ""


func _splash() -> void:
	if "--legacy_selftest=1" in OS.get_cmdline_user_args() or _slice_mode(OS.get_cmdline_user_args()) != "":
		return
	await super._splash()


func _build_v11() -> void:
	var clk: = TWClock.new()
	var st: = TWState.new(TWSave.new("user://tw_v11_state.json"), clk, {})
	tw_screens = TWScreens.new()
	tw_screens.name = "TWScreens"
	add_child(tw_screens)
	ctx = TWContext.build(st, clk, TWBus.new(), tw_screens)
	tw_screens.ctx = ctx
	ctx.provide("legacy_host", self)
	modals = ModalStack.new()
	modals.visible = false
	modals.changed.connect(func(d: int) -> void: modals.visible = d > 0)
	add_child(modals)
	modals.bind_screens(tw_screens)
	ctx.provide("modals", modals)
	# v11 screens live next to their spec (shell/screens/<id>/spec.tres): the registry is the directory scan, nothing else
	tw_screens.scan()
	if "--v11_match=1" in OS.get_cmdline_user_args():
		_open_match.call_deferred()


# dev entry (P31): `godot --path game -- --shell=v11 --v11_match=1` opens the v11 match screen on a default board
func _open_match() -> void:
	if tw_screens != null and tw_screens.has_screen("match"):
		tw_screens.go("match", {})


# a v11 modal swallows the press first; with none open this is the v10 chain, byte for byte
func android_back() -> void:
	if modals != null and modals.is_open():
		modals.handle_back()
		return
	super.android_back()


# ── catalogue ────────────────────────────────────────────────────────────────────────────────────────────

func _load_catalogue() -> void:
	_catalogue = {}
	var f: = FileAccess.open(CATALOGUE, FileAccess.READ)
	if f == null:
		push_warning("LegacyHost: %s missing" % CATALOGUE)
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.get("screens") is Dictionary:
		_catalogue = d.screens


func ids() -> PackedStringArray:
	return PackedStringArray(SCREENS.keys())


func info(id: String) -> Dictionary:
	return _catalogue.get(id, {})


# ids in the live SCREENS table that the catalogue does not know, and vice versa; both must stay empty
func catalogue_drift() -> Dictionary:
	var missing: = []
	var stale: = []
	for id in SCREENS:
		if not _catalogue.has(id):
			missing.append(id)
		elif String(_catalogue[id].get("script", "")) != (SCREENS[id] as Script).resource_path:
			stale.append(id)
	for id in _catalogue:
		if not SCREENS.has(id):
			stale.append(id)
	return {"missing": missing, "stale": stale}


# ── open / close (awaitable go) ──────────────────────────────────────────────────────────────────────────

func open(id: String, args: Dictionary = {}) -> bool:
	if not SCREENS.has(id):
		return false
	var a: Dictionary = args if not args.is_empty() else (info(id).get("args", {}) as Dictionary)
	busy = false
	screen_id = ""
	go(id, a, false)
	var guard: = 0
	while busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	return screen_id == id and screen != null and is_instance_valid(screen)


# unmount the current screen (go home), returns true once the old node is gone and the overlay holds no leftovers
func close() -> bool:
	var old: = screen
	busy = false
	screen_id = ""
	go("home", {}, false)
	var guard: = 0
	while busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	return old == null or not is_instance_valid(old) or old == screen


# ── selftest (--legacy_selftest=1) lives in legacy_host_selftest.gd (it probes main.overlay, which no other shell file may touch)

func _selftest() -> void:
	await LegacyHostSelftest.run(self)
