class_name TWNavSelftest
extends RefCounted

# Selftest of the P23 shell skeleton: ScreenSpec, TWScreen, TWScreens, TWContext, TWBus. Prints "TWNAV_SELFTEST ok/total", every
# check is a PASS / FAIL line. 12 fake screens (TWNavFakeScreen) drive go / back / history / tabs; the watchdog is measured on a fake
# clock (exact threshold) and once in real time (3.0 +- 0.2 s). Nothing here touches G or the real save.

const FAKE: = "res://shell/nav/nav_fake_screen.gd"
const FIX: = "res://tests/fixtures/screens"
const IDS: = ["home", "map", "play", "result", "wish", "shop", "pass", "profile", "modes", "koikoi", "tower", "settings"]

var host: Node
var _pass: = 0
var _fail: = 0
var _fake_ms: = 0


func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


func run(p_host: Node) -> Array:
	host = p_host
	_spec()
	_registry()
	_scan()
	_navigation()
	_tabs_and_back()
	_modals_and_gates()
	_soak()
	_watchdog_fake()
	await _frames_and_await()
	await _watchdog_real()
	_bus()
	_context()
	_autoloads()
	var total: = _pass + _fail
	print("TWNAV_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


# ── helpers ─────────────────────────────────────────────────────────────────────────────────────────────────

func _mgr(register_all: bool = true) -> TWScreens:
	var m: = TWScreens.new()
	m.ctx = TWContext.build(null, null, TWBus.new(), m)
	host.add_child(m)
	_fake_ms = 0
	m.now_fn = func(): return _fake_ms
	if register_all:
		for i in IDS.size():
			var opts: = {}
			match IDS[i]:
				"home":
					opts = {"tab": "main", "is_tab_root": true, "chrome": PackedStringArray(["header", "tabbar"])}
				"map":
					opts = {"tab": "main", "back_target": "home"}
				"result":
					opts = {"keep_history": false}
				"wish":
					opts = {"tab": "wish", "is_tab_root": true}
				"shop":
					opts = {"tab": "wish"}
				"settings":
					opts = {"unlock_rule": "settings_open"}
			m.register(ScreenSpec.make(IDS[i], FAKE, opts))
	return m


func _drop(m: TWScreens) -> void:
	m.reset()
	m.queue_free()


func _flush_log() -> void:
	TWNavFakeScreen.log.clear()


func _count(prefix: String) -> int:
	var n: = 0
	for l in TWNavFakeScreen.log:
		if str(l).begins_with(prefix):
			n += 1
	return n


# ── ScreenSpec ──────────────────────────────────────────────────────────────────────────────────────────────

func _spec() -> void:
	var ok: = ScreenSpec.make("home", FAKE, {"tab": "main", "is_tab_root": true, "chrome": PackedStringArray(["header", "back"])})
	check("spec: a good spec validates", ok.validate() == "", ok.validate())
	check("spec: analytics_name defaults to id", ok.name_for_analytics() == "home")
	check("spec: has_chrome", ok.has_chrome("header") and not ok.has_chrome("currency"))
	check("spec: empty id rejected", ScreenSpec.make("", FAKE).validate().begins_with("id:"))
	check("spec: CamelCase id rejected", ScreenSpec.make("Home", FAKE).validate().begins_with("id:"))
	check("spec: id with a dash rejected", ScreenSpec.make("a-b", FAKE).validate().begins_with("id:"))
	check("spec: no scene and no script rejected", ScreenSpec.make("x", "").validate().begins_with("source:"))
	check("spec: missing script rejected", ScreenSpec.make("x", "res://nope/none.gd").validate().begins_with("source:"))
	check("spec: script that is not a TWScreen rejected", ScreenSpec.make("x", "res://shell/tw_bus.gd").validate().begins_with("source:"))
	var sc: = ScreenSpec.new()
	sc.id = "x"
	sc.scene = "res://nope/none.tscn"
	check("spec: missing scene rejected", sc.validate().begins_with("source:"))
	check("spec: unknown chrome flag rejected", ScreenSpec.make("x", FAKE, {"chrome": PackedStringArray(["glitter"])}).validate().begins_with("chrome:"))
	check("spec: back_target == id rejected", ScreenSpec.make("x", FAKE, {"back_target": "x"}).validate().begins_with("back_target:"))
	check("spec: tab root without a tab rejected", ScreenSpec.make("x", FAKE, {"is_tab_root": true}).validate().begins_with("tab:"))
	check("spec: tut id with a space rejected", ScreenSpec.make("x", FAKE, {"tut_ids": PackedStringArray(["a b"])}).validate().begins_with("tut_ids:"))
	check("spec: stable tut ids accepted", ScreenSpec.make("x", FAKE, {"tut_ids": PackedStringArray(["x.cta", "x.tab"])}).validate() == "")


# ── registry ────────────────────────────────────────────────────────────────────────────────────────────────

func _registry() -> void:
	var m: = _mgr()
	check("registry: 12 fake screens registered", m.registry.size() == 12 and m.rejects.is_empty(), str(m.rejects))
	check("registry: duplicate id refused", not m.register(ScreenSpec.make("home", FAKE)) and m.registry.size() == 12)
	check("registry: the same spec twice is not a duplicate", m.register(m.registry["home"]))
	check("registry: null refused with SCREEN_HAS_SPEC", not m.register(null) and str(m.rejects[-1].reason).begins_with("SCREEN_HAS_SPEC"))
	check("registry: an invalid spec is refused and recorded", not m.register(ScreenSpec.make("bad id", FAKE)) and m.rejects[-1].id == "bad id")
	check("registry: has_screen", m.has_screen("tower") and not m.has_screen("nope"))
	check("registry: tabs() = main + wish", Array(m.tabs()) == ["main", "wish"], str(m.tabs()))
	check("registry: tab_root", m.tab_root("main") == "home" and m.tab_root("wish") == "wish" and m.tab_root("none") == "")
	_drop(m)


func _scan() -> void:
	var m: = _mgr(false)
	var rep: = m.scan(FIX)
	check("scan: alpha, beta, scened (valid spec.tres) registered", Array(rep.registered) == ["alpha", "beta", "scened"], str(rep))
	var why: = {}
	for r in rep.rejected:
		why[str(r.dir).get_file()] = r.reason
	check("scan: nospec (screen.gd, no spec.tres) refused as SCREEN_HAS_SPEC", str(why.get("nospec", "")).begins_with("SCREEN_HAS_SPEC"), str(why))
	check("scan: badspec (spec points at a missing script) refused", why.has("badspec") and str(why.badspec).begins_with("source:"), str(why))
	check("scan: dupid (id already registered) refused", why.has("dupid") and str(why.dupid).contains("already registered"), str(why))
	check("scan: exactly 3 refusals", rep.rejected.size() == 3, str(rep.rejected.size()))
	check("scan: a screen without a spec is not navigable", not m.has_screen("nospec") and not m.has_screen("badspec"))
	var spec: ScreenSpec = m.registry["alpha"]
	check("scan: spec.tres fields loaded (tab, chrome, tut_ids)", spec.tab == "main" and spec.is_tab_root and spec.has_chrome("tabbar") and Array(spec.tut_ids) == ["alpha.cta"])
	check("scan: a folder tree that does not exist is an empty report", m.scan("res://shell/screens_nope").registered.is_empty())
	m.go("alpha")
	check("scan: a scanned screen mounts (script_path from spec.tres)", m.current_id == "alpha" and m.current is TWScreen and m.current.spec == spec)
	m.go("scened")
	check("scan: a scene-based screen mounts (scene from spec.tres)", m.current_id == "scened" and m.current is TWNavFakeScreen and m.current.spec.id == "scened")
	_drop(m)


# ── navigation over 12 screens ──────────────────────────────────────────────────────────────────────────────

func _navigation() -> void:
	_flush_log()
	var m: = _mgr()
	var changes: Array = []
	m.screen_changed.connect(func(id, from): changes.append([from, id]))
	check("nav: starts IDLE with no screen", m.state == TWScreens.State.IDLE and m.current == null and m.current_id == "" and m.history.is_empty())
	# a linear walk home -> map -> play -> result(transient) -> wish -> shop -> pass -> profile -> modes -> koikoi -> tower
	var walk: = ["home", "map", "play", "result", "wish", "shop", "pass", "profile", "modes", "koikoi", "tower"]
	for id in walk:
		m.go(id, {"n": id})
		check("nav: go(%s) lands IDLE on it" % id, m.state == TWScreens.State.IDLE and m.current_id == id and m.current.params.n == id)
	check("nav: exactly one screen node mounted", m.get_child_count() == 1, str(m.get_child_count()))
	check("nav: screen_changed fired for each move with the right `from`", changes.size() == 11 and changes[0] == ["", "home"] and changes[10] == ["koikoi", "tower"])
	# history: tab roots clear it (home, wish), transient `result` is never pushed
	check("nav: history after the walk (wish root cleared it, result skipped)", Array(m.history_ids()) == ["wish", "shop", "pass", "profile", "modes", "koikoi"], str(m.history_ids()))
	check("nav: lifecycle - every left screen got exit()", _count("exit:") == 10, str(_count("exit:")))
	check("nav: lifecycle - every screen got enter()", _count("enter:") == 11)
	check("nav: the TWScreen got its ctx slot and spec", m.current.spec == m.registry["tower"] and m.current.ctx == m.ctx)
	# back all the way
	var seen: Array = []
	var guard: = 0
	while guard < 20:
		var r: = m.back()
		if r != "history":
			seen.append(r)
			break
		seen.append(m.current_id)
		guard += 1
	check("nav: back() walks the history in reverse", seen == ["koikoi", "modes", "profile", "pass", "shop", "wish", "exit"], str(seen))
	check("nav: history empty at the end", m.history.is_empty() and m.current_id == "wish")
	# the same id again is a refresh, not a push
	m.go("map")
	m.go("map", {"v": 2})
	check("nav: go(same id) refreshes params without a history push", m.current.params.v == 2 and Array(m.history_ids()) == ["wish"], str(m.history_ids()))
	m.go("play", {}, {"replace": true})
	check("nav: opts.replace does not push", Array(m.history_ids()) == ["wish"] and m.current_id == "play")
	# bounded history
	m.go("home")
	for i in 80:
		m.go(["profile", "modes"][i % 2])
	check("nav: history is capped at HISTORY_MAX", m.history.size() == TWScreens.HISTORY_MAX, str(m.history.size()))
	# unknown / locked / etc
	var rej: Array = []
	m.nav_rejected.connect(func(id, why): rej.append([id, why]))
	var before: = m.current_id
	m.go("nope")
	check("nav: unknown id rejected, screen untouched", m.current_id == before and rej == [["nope", "unknown"]])
	check("nav: still exactly one screen after 90 moves", m.get_child_count() == 1 and m.state == TWScreens.State.IDLE)
	var sig: Signal = m.go("nope")
	check("nav: go() always returns a Signal", sig is Signal and not sig.is_null())
	_drop(m)


func _tabs_and_back() -> void:
	_flush_log()
	var m: = _mgr()
	m.go("home")
	m.go("map")
	check("tabs: map belongs to main", m.tab == "main")
	check("back: map has back_target home but history has home -> history", m.back() == "history" and m.current_id == "home")
	m.go("map")
	m.reset()
	m.go("map")
	check("back: empty history + back_target -> back_target", m.back() == "back_target" and m.current_id == "home")
	check("back: empty history, no target -> exit_requested", _exit_probe(m))
	m.go("wish")
	m.go("shop")
	m.go_tab("main")
	check("tabs: go_tab(main) -> remembered screen of the tab (home was last)", m.current_id == "home" and m.tab == "main" and m.history.is_empty(), "%s %s" % [m.current_id, str(m.history_ids())])
	m.go("map")
	m.go_tab("wish")
	check("tabs: go_tab(wish) -> remembered shop", m.current_id == "shop" and m.history.is_empty(), m.current_id)
	m.go_tab("main")
	check("tabs: back to main -> remembered map", m.current_id == "map")
	var rej: Array = []
	m.nav_rejected.connect(func(id, why): rej.append(why))
	m.go_tab("main")
	check("tabs: go_tab on the current tab = no-op 'same'", rej == ["same"] and m.current_id == "map")
	m.go_tab("nope")
	check("tabs: unknown tab rejected", rej == ["same", "unknown"])
	m.go("home")
	m.go("shop")
	m.go("home")
	check("tabs: entering a tab root clears the history", m.history.is_empty())
	# on_back / can_back
	m.go("play", {"consume": true})
	check("back: on_back consumes the first press", m.back() == "screen" and m.current_id == "play")
	check("back: the second press navigates (history empty -> exit)", m.back() in ["history", "back_target", "exit"] and TWNavFakeScreen.log.has("consumed:play"))
	m.go("home")
	m.go("play", {"block": true})
	check("back: can_back() false -> blocked, nothing moves", m.back() == "blocked" and m.current_id == "play" and Array(m.history_ids()) == ["home"])
	_drop(m)


func _exit_probe(m: TWScreens) -> bool:
	var hit: Array = [0]
	m.exit_requested.connect(func(): hit[0] += 1)
	var r: = m.back()
	return r == "exit" and hit[0] == 1


class FakeModals extends RefCounted:
	var cleared: Array = []
	var open: = 0

	func clear_all(reason: String) -> void:
		cleared.append(reason)
		open = 0

	func handle_back() -> bool:
		if open > 0:
			open -= 1
			return true
		return false


func _modals_and_gates() -> void:
	var m: = _mgr()
	var fm: = FakeModals.new()
	m.modals = fm
	m.go("home")
	m.go("map")
	check("modals: clear_all runs before every mount with the target id", fm.cleared == ["go:home", "go:map"], str(fm.cleared))
	fm.open = 2
	check("modals: back closes the top modal first (1/2)", m.back() == "modal" and m.current_id == "map")
	check("modals: back closes the top modal first (2/2)", m.back() == "modal" and m.current_id == "map")
	check("modals: with no modal left back navigates", m.back() == "history" and m.current_id == "home")
	var allow: Array = [false]
	m.unlock_check = func(rule): return allow[0] and rule == "settings_open"
	var rej: Array = []
	m.nav_rejected.connect(func(id, why): rej.append([id, why]))
	m.go("settings")
	check("gate: a locked screen is refused (unlock_rule)", rej == [["settings", "locked"]] and m.current_id == "home")
	allow[0] = true
	m.go("settings")
	check("gate: the same screen opens once the rule passes", m.current_id == "settings")
	m.unlock_check = Callable()
	check("gate: no checker injected = open", m.go("play") != Signal() and m.current_id == "play")
	_drop(m)


# seeded random go / back / go_tab / refused moves over the 12 screens: the invariants of the manager never break
func _soak() -> void:
	_flush_log()
	var m: = _mgr()
	var fm: = FakeModals.new()
	m.modals = fm
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261128
	var bad: = 0
	var first_bad: = ""
	for i in 3000:
		var r: = rng.randi() % 100
		if r < 55:
			m.go(IDS[rng.randi() % IDS.size()], {"i": i})
		elif r < 80:
			m.back()
		elif r < 88:
			m.go_tab(["main", "wish", "nope"][rng.randi() % 3])
		elif r < 93:
			fm.open = rng.randi() % 3
		else:
			m.go(IDS[rng.randi() % IDS.size()], {"i": i}, {"replace": true})
		var why: = ""
		if m.get_child_count() > 1:
			why = "screens mounted: %d" % m.get_child_count()
		elif m.state != TWScreens.State.IDLE:
			why = "not idle"
		elif m.history.size() > TWScreens.HISTORY_MAX:
			why = "history over cap"
		elif m.current != null and (m.current.spec == null or m.current.spec.id != m.current_id):
			why = "spec mismatch"
		elif m.current == null and m.current_id != "":
			why = "id without screen"
		for e in m.history:
			if not m.registry.has(e.id) or str(e.id) == "result":
				why = "history entry %s" % e.id
		if why != "" and bad == 0:
			first_bad = "step %d: %s" % [i, why]
		bad += 1 if why != "" else 0
	check("soak: 3000 random go/back/tab/modal moves keep every invariant", bad == 0, first_bad)
	check("soak: enter/exit balanced (every left screen was exited)", _count("enter:") - _count("exit:") == 1, "%d %d" % [_count("enter:"), _count("exit:")])
	_drop(m)
	check("soak: reset leaves no screen node", _count("enter:") == _count("exit:"))


# ── watchdog ────────────────────────────────────────────────────────────────────────────────────────────────

func _watchdog_fake() -> void:
	_flush_log()
	var m: = _mgr()
	var fired: Array = []
	var fin: Array = []
	m.watchdog_fired.connect(func(id): fired.append(id))
	m.transition_finished.connect(func(id, forced): fin.append([id, forced]))
	m.go("home", {"intro": "hang"})
	check("watchdog: a hanging intro leaves the manager TRANSITIONING", m.state == TWScreens.State.TRANSITIONING and m.is_busy())
	check("watchdog: the screen is mounted and entered while busy", m.current_id == "home" and _count("enter:home") == 1)
	_fake_ms = 1000
	check("watchdog: no fire at 1.0 s", not m.poll() and m.is_busy())
	_fake_ms = 2999
	check("watchdog: no fire at 2.999 s", not m.poll() and m.is_busy() and fired.is_empty())
	var rej: Array = []
	m.nav_rejected.connect(func(id, why): rej.append(why))
	m.go("map")
	check("watchdog: go() while TRANSITIONING is refused as busy", rej == ["busy"] and m.current_id == "home")
	check("watchdog: back() while TRANSITIONING is ignored", m.back() == "busy")
	_fake_ms = 3000
	check("watchdog: fires at exactly 3.000 s", m.poll() and fired == ["home"])
	check("watchdog: state back to IDLE, finished with forced=true", m.state == TWScreens.State.IDLE and fin == [["home", true]])
	check("watchdog: the screen got intro_forced()", TWNavFakeScreen.last.forced and _count("forced:home") == 1)
	check("watchdog: counted", m.watchdog_count == 1)
	TWNavFakeScreen.last.never.emit()
	check("watchdog: a late intro signal after the force is ignored", fin.size() == 1 and m.state == TWScreens.State.IDLE)
	m.go("map")
	check("watchdog: navigation works again after a forced finish", m.current_id == "map" and m.state == TWScreens.State.IDLE)
	# a normal animation that ends in time never trips the watchdog
	fired.clear()
	fin.clear()
	_fake_ms = 10_000
	m.go("play", {"intro": "late"})
	_fake_ms = 10_500
	check("watchdog: a 'late' intro is still TRANSITIONING at 0.5 s", not m.poll() and m.is_busy())
	TWNavFakeScreen.last.late_signal.emit()
	check("watchdog: the intro signal finishes it normally (forced=false)", m.state == TWScreens.State.IDLE and fin == [["play", false]])
	_fake_ms = 20_000
	check("watchdog: poll() while IDLE does nothing", not m.poll() and fired.is_empty())
	# stale generation: intro of screen A must not finish screen B's transition
	m.go("shop", {"intro": "hang"})
	var first: TWNavFakeScreen = TWNavFakeScreen.last
	_fake_ms = 23_000
	m.poll()
	m.go("pass", {"intro": "hang"})
	first.never.emit()
	check("watchdog: a stale intro of a previous screen does not finish the current transition", m.is_busy() and m.current_id == "pass")
	_fake_ms = 26_000
	check("watchdog: and the current one is still force-finished at +3.0 s", m.poll() and m.state == TWScreens.State.IDLE)
	# reset() during a transition
	m.go("home", {"intro": "hang"})
	m.reset()
	check("reset: drops the screen and returns to IDLE", m.state == TWScreens.State.IDLE and m.current == null and m.get_child_count() == 0)
	_drop(m)


func _frames_and_await() -> void:
	var m: = _mgr()
	var res: Array = []
	m.go("home").connect(func(ok, why): res.append([ok, why]))
	check("await: the done Signal is NOT emitted synchronously", res.is_empty())
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check("await: the done Signal fires on a later frame with ok=true", res == [[true, ""]], str(res))
	# `await screens.go()` on an instant transition must not hang
	var t0: = Time.get_ticks_msec()
	var out: Array = await m.go("map")
	check("await: `await screens.go(..)` returns on an instant transition", Time.get_ticks_msec() - t0 < 500 and m.current_id == "map", str(out))
	var rej: Array = []
	var s2: = m.go("nope")
	s2.connect(func(ok, why): rej.append([ok, why]))
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check("await: a rejected go() also completes its Signal (ok=false, reason)", rej == [[false, "unknown"]], str(rej))
	_drop(m)


func _watchdog_real() -> void:
	var m: = _mgr()
	m.now_fn = Callable()          # real engine ticks
	var done: Array = [-1]
	var t0: = Time.get_ticks_msec()
	m.watchdog_fired.connect(func(_id): done[0] = Time.get_ticks_msec() - t0)
	m.go("home", {"intro": "hang"})
	var guard: = 0
	while done[0] < 0 and guard < 600:
		await host.get_tree().process_frame
		guard += 1
	var secs: float = done[0] / 1000.0
	check("watchdog (real time): force-finished in 3.0 +- 0.2 s", done[0] >= 0 and absf(secs - 3.0) <= 0.2, "%.3f s" % secs)
	print("INFO watchdog real time %.3f s" % secs)
	check("watchdog (real time): IDLE afterwards", m.state == TWScreens.State.IDLE)
	_drop(m)


# ── TWBus ───────────────────────────────────────────────────────────────────────────────────────────────────

class Probe extends RefCounted:
	var got: Array = []

	func on_ev(ev: Dictionary) -> void:
		got.append(ev.get("t", ""))


func _bus() -> void:
	var b: = TWBus.new()
	var log: Array = []
	var t1: = b.subscribe("MATCH", func(ev): log.append("a:" + ev.t))
	b.subscribe("MATCH", func(ev): log.append("b:" + ev.t))
	b.subscribe("*", func(ev): log.append("*:" + ev.t))
	b.publish({"t": "MATCH", "a": 1})
	b.publish({"t": "DENY"})
	check("bus: exact-kind subscribers run in order, then '*'", log == ["a:MATCH", "b:MATCH", "*:MATCH", "*:DENY"], str(log))
	check("bus: kind_of reads 't' and 'kind'", TWBus.kind_of({"t": "X"}) == "X" and TWBus.kind_of({"kind": "Y"}) == "Y" and TWBus.kind_of(5) == "")
	b.unsubscribe(t1)
	log.clear()
	b.publish({"t": "MATCH"})
	check("bus: unsubscribe(token) stops delivery", log == ["b:MATCH", "*:MATCH"], str(log))
	# synchronous delivery of a list, in order
	log.clear()
	b.publish_all([{"t": "TO_TRAY"}, {"t": "MATCH"}, "junk", {"t": "CLEARED"}])
	check("bus: publish_all is ordered and skips non-events", log == ["*:TO_TRAY", "b:MATCH", "*:MATCH", "*:CLEARED"], str(log))
	# re-entrancy: an event published in a handler is queued behind the current one
	var b2: = TWBus.new()
	var order: Array = []
	b2.subscribe("A", func(ev): order.append("A1"); b2.publish({"t": "B"}); order.append("A1-end"))
	b2.subscribe("A", func(ev): order.append("A2"))
	b2.subscribe("B", func(ev): order.append("B"))
	b2.publish({"t": "A"})
	check("bus: a nested publish is queued, delivered after the current event", order == ["A1", "A1-end", "A2", "B"], str(order))
	# signal
	var sig: Array = []
	b2.event.connect(func(ev): sig.append(ev.t))
	b2.publish({"t": "Z"})
	check("bus: signal `event` mirrors every event", sig == ["Z"])
	# ring
	var b3: = TWBus.new()
	for i in 100:
		b3.publish({"t": "E", "i": i})
	check("bus: recent() keeps the last RING events", b3.recent().size() == TWBus.RING and b3.recent(3)[2].i == 99 and b3.recent(3)[0].i == 97)
	check("bus: published counted", b3.published == 100)
	# freed target is dropped
	var b4: = TWBus.new()
	var pr: = Probe.new()
	b4.subscribe("E", pr.on_ev)
	b4.publish({"t": "E"})
	check("bus: method subscriber receives", pr.got == ["E"])
	var holder: Node = Node.new()
	var hits: Array = [0]
	host.add_child(holder)
	b4.subscribe("E", func(_ev): hits[0] += 1, holder)
	check("bus: owner subscription counted", b4.subscriber_count("E") == 2)
	host.remove_child(holder)       # tree_exiting
	holder.free()
	b4.publish({"t": "E"})
	check("bus: a Node owner leaving the tree drops its subscriptions", hits[0] == 0 and b4.subscriber_count("E") == 1, "%d %d" % [hits[0], b4.subscriber_count("E")])
	var holder2: Node = Node.new()
	b4.subscribe("E", func(_ev): hits[0] += 10, holder2)
	check("bus: unsubscribe_owner", b4.unsubscribe_owner(holder2) == 1 and b4.subscriber_count("E") == 1)
	holder2.free()
	# a handler that unsubscribes a later handler of the same event
	var b5: = TWBus.new()
	var tok: Array = [0]
	var got: Array = []
	b5.subscribe("E", func(_ev): got.append("x"); b5.unsubscribe(tok[0]))
	tok[0] = b5.subscribe("E", func(_ev): got.append("y"))
	b5.publish({"t": "E"})
	check("bus: unsubscribing a later handler mid-dispatch skips it", got == ["x"], str(got))
	# runaway
	var b6: = TWBus.new()
	b6.subscribe("L", func(_ev): b6.publish({"t": "L"}))
	b6.publish({"t": "L"})
	check("bus: a publish loop is cut at MAX_QUEUE and does not hang", b6.dropped >= 1 and b6.published == TWBus.MAX_QUEUE, "%d %d" % [b6.dropped, b6.published])


# ── TWContext ───────────────────────────────────────────────────────────────────────────────────────────────

func _context() -> void:
	var c: = TWContext.for_tests("user://tw_nav_selftest/")
	check("ctx: built context has state, clock, bus, screens", c.state != null and c.clock != null and c.bus != null and c.screens != null)
	check("ctx: screens point back at the context", c.screens.ctx == c)
	check("ctx: the state is a fresh TWState on a scratch path", c.state.status == "fresh" and c.state.data is Dictionary)
	var o: = Node.new()
	check("ctx: provide() accepts a known service", c.provide("audio", o) and c.has_service("audio") and c.service("audio") == o)
	check("ctx: provide() refuses an unknown name (no `main` smuggling)", not c.provide("main", o) and not c.has_service("main"))
	check("ctx: a missing service is null, not an error", c.service("wallet") == null and not c.has_service("wallet"))
	o.free()
	check("ctx: a freed service reads as missing", c.service("audio") == null and not c.has_service("audio"))
	check("ctx: provide(null) removes", c.provide("assets", Node.new()) and c.provide("assets", null) and not c.has_service("assets"))
	# a screen sees the same context
	host.add_child(c.screens)
	c.screens.register(ScreenSpec.make("home", FAKE))
	c.screens.go("home")
	check("ctx: the mounted screen holds the very same TWContext", c.screens.current.ctx == c)
	var seen: Array = []
	c.bus.subscribe("PING", func(ev): seen.append(ev.t), c.screens.current)
	c.bus.publish({"t": "PING"})
	c.screens.reset()
	c.bus.publish({"t": "PING"})
	check("ctx: a screen's bus subscription dies with the screen", seen == ["PING"] and c.bus.subscriber_count("PING") == 0, "%s %d" % [str(seen), c.bus.subscriber_count("PING")])
	c.screens.queue_free()
	TWSave.new("user://tw_nav_selftest/save.json").remove_all()


func _autoloads() -> void:
	var n: = 0
	for p in ProjectSettings.get_property_list():
		if str(p.name).begins_with("autoload/"):
			n += 1
	check("autoloads: not more than 11 + 1 at this stage (currently %d)" % n, n >= 1 and n <= 12, str(n))
	check("autoloads: no class_name collides with an autoload name", not _collides())


func _collides() -> bool:
	var names: Array = []
	for p in ProjectSettings.get_property_list():
		if str(p.name).begins_with("autoload/"):
			names.append(str(p.name).trim_prefix("autoload/"))
	for cn in ["TWScreens", "TWScreen", "ScreenSpec", "TWContext", "TWBus"]:
		if names.has(cn):
			return true
	return false
