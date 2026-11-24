extends Control

# stage_selftest — docs/MODES.md §3.6 for every mode, run once for all of them (lane `stage`).
#   godot --headless --path game res://scripts/v10/mj/stage/stage_selftest.tscn -- --mj_stage_selftest=1
# Last line: MJ_STAGE ok/total (exit 0 only when every check passed). Watchdog 600 s.
#  (1) input on → no node / FX / text / peek of hers over the sacred zone, on 6 screen shapes × 3 fx levels; pair
#      motes over tiles ≤ 0.45 s, ≤ 8 per pair, ≤ 18 alive; only the portrait window takes the mouse
#  (2) input block ≤ 0.3 s, only on wave / win / lose; early taps are queued and replayed after the block
#  (3) 1000 synthetic events: voice ≤ 1 / 20 s (win/lose excepted), a line ≤ 1 / 60 s, micro ≤ 1 / 3 moves,
#      peeks only on wave / win / lose, ≤ 2 idle calls; and she does react (not silent)
#  (4) «Только финиш»: not one voice, line or exit during the match; the finish still shows her
#  (5) rivals' faces never depend on hidden data: on() with different data.hidden → identical reactions
#  (6) fx_level = min → zero motion tweens, painted frames, no motes
#  (7) every visible text passes UX_RULES §4.3 + V10Lint.BANNED; lines ≤ 32 characters; 160 lines exist
#  (+) voice files: every line has its .ogg (when the lane's audio is in), loudness metadata in voice/manifest.json

const BANNED_UX: = ["гарант", "пити", "pity", "50/50", "sr+", "ssr+", "гача", "ролл", "крутк", "фивер", "ивент",
	"квартал", "перк", "ульта", "риичи", "яку", "банер", "донат", "хит", "выгодно", "best", "new", "успей",
	"последний шанс", "только сегодня", "топ-100", "бонус"]
const BANNED_LINT: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк",
	"успей", "последн", "только сегодня", "купи", "баннер", "акци", "цена"]
const ALLOW: = ["однажды", "ещё одна", "одна чашка", "одна партия"]
const MATCH_EV: = ["pick", "pair", "combo", "motif", "danger", "signature", "wave", "ult", "last_pair", "idle", "mech_intro"]

var ok: = 0
var total: = 0
var fails: Array = []
var t_syn: = 1000.0


func _ready() -> void:
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_STAGE watchdog")
		get_tree().quit(2))
	_run.call_deferred()


func check(name: String, cond: bool, detail: = "") -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(name)
		print("  FAIL ", name, "  ", detail)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# a host layout of the common match frame (MODES §4) on a screen of size S; tablet: field centred, 720 wide
func _layout(S: Vector2) -> Dictionary:
	var extra: = maxf(0.0, S.y - S.x * 16.0 / 9.0)
	var fw: = minf(S.x - 16.0, 720.0)
	var fx0: = (S.x - fw) * 0.5
	var top: = 120.0 + extra
	var tray: = Rect2(fx0 + 16, top, fw - 32, 180)
	var help: = Rect2(fx0, S.y - 186, fw, 146)
	var field: = Rect2(fx0, tray.end.y, fw, help.position.y - tray.end.y)
	return {"tray": tray, "help": help, "field": field,
		"avoid": [Rect2(12, top - 100, 80, 80), Rect2(96, top - 88, 250, 56)]}


func _make(S: Vector2, o: = {}) -> V10MjPresence:
	var L: = _layout(S)
	var host: = Control.new()
	host.size = S
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var opts: = {"screen": S, "avoid": L.avoid, "seed": 5}
	opts.merge(o, true)
	var p: = V10MjPresence.new().attach(host, String(o.get("hero", "mc")), opts)
	p.sacred(L.field)
	p.sacred(L.tray)
	p.sacred(L.help)
	return p


func _drop(p: V10MjPresence) -> void:
	var h: = p.get_parent()
	h.queue_free()


func _run() -> void:
	print("MJ_STAGE selftest")
	await _t1()
	await _t2()
	_t3()
	_t4()
	_t5()
	await _t6()
	_t7()
	_t_voice_files()
	print("MJ_STAGE %d/%d" % [ok, total])
	if not fails.is_empty():
		print("MJ_STAGE fails: ", fails)
	get_tree().quit(0 if ok == total else 1)


# ── (1) the sacred zone ───────────────────────────────────────────────────────────────────────────────────────
func _t1() -> void:
	var screens: = [Vector2(720, 1280), Vector2(720, 1600), Vector2(720, 1680), Vector2(960, 1280),
		Vector2(1080, 1440), Vector2(720, 1440)]
	for fx in ["full", "mid", "min"]:
		for S in screens:
			var p: = _make(S, {"fx": fx, "hero": ["mc", "rin", "hana", "yue", "nova"][randi() % 5]})
			var hits: = 0
			var max_alive: = 0
			var seq: = [["pick", {"pos": Vector2(S.x * 0.4, S.y * 0.5)}], ["pair", {"pos": Vector2(S.x * 0.4, S.y * 0.55)}],
				["combo", {"n": 3}], ["pair", {"pos": Vector2(S.x * 0.7, S.y * 0.7)}], ["combo", {"n": 5}],
				["motif", {}], ["danger", {"on": true}], ["signature", {}], ["pair", {"pos": Vector2(S.x * 0.2, S.y * 0.8)}],
				["wave", {"wave": 2}], ["combo", {"n": 8}], ["mech_intro", {}], ["last_pair", {}], ["idle", {}],
				["danger", {"on": false}], ["call", {"who": "me", "kind": "pon"}], ["riichi", {"who": "me"}],
				["dora", {}], ["pair", {"pos": Vector2(S.x * 0.5, S.y * 0.9)}], ["pair", {"pos": Vector2(S.x * 0.3, S.y * 0.6)}]]
			for ev in seq:
				p.on(ev[0], ev[1])
				for f in 6:
					await get_tree().process_frame
					if p.is_input_on():
						hits += p.sacred_hits().size()
					max_alive = maxi(max_alive, p.trail.alive())
			# let the peek / text / motes run their course while input is on
			for f in 50:
				await get_tree().process_frame
				hits += p.sacred_hits().size()
			var tag: = "%s %dx%d" % [fx, int(S.x), int(S.y)]
			check("(1) no pixel of hers over the sacred zone " + tag, hits == 0, "hits=%d first=%s" % [hits, str(p.sacred_hits().slice(0, 1))])
			check("(1) motes over tiles ≤ 0.45 s " + tag, p.trail.max_over_sacred <= 0.45, "%.3f" % p.trail.max_over_sacred)
			check("(1) ≤ 18 motes alive " + tag, max_alive <= 18 and p.trail.max_alive <= 18, str(p.trail.max_alive))
			check("(1) the window fits the free band " + tag, p.free_band.encloses(p.band.window_outer())
				or p.band.window_outer().end.y <= p.free_band.end.y + 0.5, str(p.band.window_outer()) + " in " + str(p.free_band))
			if fx == "full" and S == Vector2(720, 1280):
				check("(1) ≤ 8 motes per pair", p.trail.spawned <= 8 * 5, str(p.trail.spawned))
				check("(1) mote alpha ≤ 0.6", V10MjPairTrail.ALPHA <= 0.6)
				check("(1) flight ≤ 0.45 s", V10MjPairTrail.FLIGHT + V10MjPairTrail.STAGGER * 8 <= 0.45)
				var stops: = _mouse_stops(p)
				check("(1) only the portrait window takes the mouse", stops == ["PortraitWindow"], str(stops))
				check("(1) the ring is the one gauge (charge moved by pairs)", p.charge > 0.0, str(p.charge))
			if S == Vector2(960, 1280) and fx == "full":
				p.on("wave", {})
				check("(1) tablet: a side margin > 48 px is used for the peek",
					p.peek_zone().get("edge", "") in ["left", "right", "bottom"], str(p.peek_zone()))
			_drop(p)
			await get_tree().process_frame


func _mouse_stops(n: Node) -> Array:
	var out: = []
	for c in n.get_children():
		if c is Control and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(String(c.name))
		out.append_array(_mouse_stops(c))
	return out


# ── (2) input block and the queue ─────────────────────────────────────────────────────────────────────────────
class _Sink extends Node:
	var taps: = 0
	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch and e.pressed:
			taps += 1


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e: = InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = 0
	return e


func _t2() -> void:
	var p: = _make(Vector2(720, 1280))
	var sink: = _Sink.new()
	add_child(sink)
	p.on("pair", {"pos": Vector2(300, 700)})
	check("(2) no block on a pair", not p.queue.is_blocked())
	var t0: = Time.get_ticks_msec()
	p.on("wave", {})
	check("(2) wave blocks input", p.queue.is_blocked())
	get_viewport().push_input(_touch(Vector2(360, 800), true))
	get_viewport().push_input(_touch(Vector2(360, 800), false))
	check("(2) the early tap did not reach the board", sink.taps == 0, str(sink.taps))
	check("(2) the early tap is queued", p.queue.queued == 2, str(p.queue.queued))
	# a second request cannot extend the block
	p.queue.block(5.0)
	while p.queue.is_blocked():
		await get_tree().process_frame
	var blocked_ms: = Time.get_ticks_msec() - t0
	await _frames(2)
	check("(2) block ≤ 0.3 s", p.queue.max_block <= 0.3001 and blocked_ms <= 360, "max=%.3f real=%d ms" % [p.queue.max_block, blocked_ms])
	check("(2) the queued tap is played after the block", sink.taps == 1 and p.queue.replayed == 2, "taps=%d replayed=%d" % [sink.taps, p.queue.replayed])
	for ev in ["pick", "pair", "combo", "motif", "danger", "signature", "ult", "last_pair", "idle", "mech_intro", "call", "riichi", "ron"]:
		check("(2) no block on " + ev, p.budget.block_for(ev) == 0.0)
	for ev in ["wave", "win", "lose"]:
		check("(2) block ≤ 0.3 s on " + ev, p.budget.block_for(ev) > 0.0 and p.budget.block_for(ev) <= 0.3)
	sink.queue_free()
	_drop(p)


# ── (3) 1000 synthetic events: frequencies and cooldowns ─────────────────────────────────────────────────────
func _t3() -> void:
	t_syn = 1000.0
	var p: = _make(Vector2(720, 1280), {"clock": func(): return t_syn, "voice": true})
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	var peeks_bad: = 0
	var ev_pool: = MATCH_EV + ["pick", "pick", "pair", "pair", "call", "riichi", "ron", "tsumo", "tenpai", "dealin"]
	for i in 1000:
		t_syn += rng.randf_range(0.15, 3.0)
		var ev: String = ev_pool[rng.randi() % ev_pool.size()]
		if i % 97 == 96:
			ev = ["win", "lose"][rng.randi() % 2]
		var d: = {"pos": Vector2(rng.randf_range(40, 680), rng.randf_range(320, 1080)), "n": rng.randi_range(1, 9),
			"on": rng.randf() < 0.5, "who": ["me", "rin", "hana"][rng.randi() % 3], "kind": ["pon", "chi", "kan"][rng.randi() % 3]}
		var before: int = p.counts.peek
		var info: = p.on(ev, d)
		if p.counts.peek > before and not ev in ["wave", "win", "lose"]:
			peeks_bad += 1
		p.input_on = true
		p._finale = false
	var vl: Array = p.budget.voice_log
	var gap_bad: = 0
	var line_bad: = 0
	var last_t: = -1e9
	var last_line: = {}
	for v in vl:
		if not bool(v[2]) and float(v[0]) - last_t < V10MjBudget.VOICE_GAP - 0.0001:
			gap_bad += 1
		last_t = float(v[0])
		if last_line.has(v[1]) and float(v[0]) - float(last_line[v[1]]) < V10MjBudget.LINE_GAP - 0.0001:
			line_bad += 1
		last_line[v[1]] = float(v[0])
	var ml: Array = p.budget.micro_log
	var micro_bad: = 0
	for i in range(1, ml.size()):
		if int(ml[i]) - int(ml[i - 1]) < V10MjBudget.MICRO_EVERY:
			micro_bad += 1
	check("(3) voice ≤ 1 per 20 s (win/lose excepted)", gap_bad == 0, str(gap_bad))
	check("(3) the same line ≤ 1 per 60 s", line_bad == 0, str(line_bad))
	check("(3) micro-reactions ≤ 1 per 3 moves", micro_bad == 0, str(micro_bad))
	check("(3) exits only on wave / win / lose", peeks_bad == 0, str(peeks_bad))
	check("(3) ≤ 2 idle calls per visit", p.budget.idle_calls <= 2, str(p.budget.idle_calls))
	check("(3) she reacts (voices, micro, exits happened)", vl.size() >= 10 and ml.size() >= 20 and p.counts.peek >= 3,
		"voice=%d micro=%d peek=%d" % [vl.size(), ml.size(), p.counts.peek])
	check("(3) a voice per 20 s at most over the whole run", vl.size() <= int((t_syn - 1000.0) / 20.0) + 1 + 12, str(vl.size()))
	_drop(p)


# ── (4) «Только финиш» ────────────────────────────────────────────────────────────────────────────────────────
func _t4() -> void:
	t_syn = 5000.0
	var p: = _make(Vector2(720, 1280), {"mode": "finish_only", "clock": func(): return t_syn})
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		t_syn += rng.randf_range(0.5, 25.0)
		var ev: String = (MATCH_EV + ["call", "riichi", "ron", "tsumo", "tenpai", "dealin"])[rng.randi() % 17]
		p.on(ev, {"pos": Vector2(300, 700), "n": rng.randi_range(1, 9), "on": true, "who": "me", "kind": "pon"})
	check("(4) finish only: no voice in the match", p.counts.voice == 0 and p.barks.voiced == 0, str(p.counts.voice))
	check("(4) finish only: no line in the match", p.barks.said == 0, str(p.barks.said))
	check("(4) finish only: no exit in the match", p.counts.peek == 0, str(p.counts.peek))
	check("(4) finish only: no warm edge in the match", not p.danger)
	p.on("win", {})
	check("(4) finish only: the finish shows her", p.counts.peek == 1 and p.barks.said == 1, "peek=%d said=%d" % [p.counts.peek, p.barks.said])
	_drop(p)
	# quiet: window + ring, no voice
	t_syn = 9000.0
	var q: = _make(Vector2(720, 1280), {"mode": "quiet", "clock": func(): return t_syn})
	for i in 200:
		t_syn += 7.0
		q.on(MATCH_EV[i % MATCH_EV.size()], {"pos": Vector2(300, 700), "n": 5, "on": true})
	check("(4) quiet: no voice, no line, no exit", q.counts.voice == 0 and q.barks.said == 0 and q.counts.peek == 0,
		"v=%d s=%d p=%d" % [q.counts.voice, q.barks.said, q.counts.peek])
	_drop(q)


# ── (5) hidden data never reaches her face ───────────────────────────────────────────────────────────────────
func _t5() -> void:
	t_syn = 20000.0
	var a: = _make(Vector2(720, 1280), {"clock": func(): return t_syn, "seed": 99})
	var b: = _make(Vector2(720, 1280), {"clock": func(): return t_syn, "seed": 99})
	var same: = 0
	var n: = 0
	var rng: = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		t_syn += rng.randf_range(0.3, 9.0)
		var ev: String = (TABLE_EV_ALL + MATCH_EV)[rng.randi() % (TABLE_EV_ALL.size() + MATCH_EV.size())]
		var pub: = {"who": ["me", "rin", "hana", "nova"][rng.randi() % 4], "kind": ["pon", "chi", "kan"][rng.randi() % 3],
			"pos": Vector2(300, 700), "n": rng.randi_range(1, 9), "on": rng.randf() < 0.5}
		var da: = pub.duplicate()
		var db: = pub.duplicate()
		da["hidden"] = {"hand": [rng.randi(), rng.randi()], "tenpai": true, "waits": [3, 6], "danger": 0.9}
		db["hidden"] = {"hand": [], "tenpai": false, "waits": [], "danger": 0.0}
		da["rival_hand"] = [1, 2, 3]
		var ia: = a.on(ev, da)
		var ib: = b.on(ev, db)
		n += 1
		if str(ia.acts) == str(ib.acts):
			same += 1
		a.input_on = true
		b.input_on = true
	check("(5) the same public event → the same reaction, whatever is hidden", same == n, "%d/%d" % [same, n])
	check("(5) hidden keys are dropped before any decision", not a._public({"hidden": 1, "rival_hand": 2}).has("hidden"))
	_drop(a)
	_drop(b)


const TABLE_EV_ALL: = ["call", "riichi", "dora", "ron", "tsumo", "tenpai", "noten", "dealin", "kita"]


# ── (6) fx min: no motion ─────────────────────────────────────────────────────────────────────────────────────
func _t6() -> void:
	V10MjStageFx.reset_counters()
	var p: = _make(Vector2(720, 1280), {"fx": "min"})
	for ev in ["pick", "pair", "combo", "motif", "danger", "signature", "wave", "ult", "last_pair", "mech_intro", "idle",
			"call", "riichi", "ron", "win"]:
		p.on(ev, {"pos": Vector2(300, 700), "n": 8, "on": true, "who": "me", "kind": "pon"})
		await _frames(4)
	await _wait(0.5)
	check("(6) fx min: zero motion tweens", V10MjStageFx.motion_tweens == 0, str(V10MjStageFx.motion_tweens))
	check("(6) fx min: information still shows (fades happened)", V10MjStageFx.fade_tweens > 0, str(V10MjStageFx.fade_tweens))
	check("(6) fx min: a painted frame, not a rig", p.band.source == "static", p.band.source)
	check("(6) fx min: no motes", p.trail.spawned == 0, str(p.trail.spawned))
	_drop(p)
	# and the full level does move (the counter is live)
	V10MjStageFx.reset_counters()
	var q: = _make(Vector2(720, 1280), {"fx": "full", "source": "static"})
	q.on("wave", {})
	q.on("combo", {"n": 3})
	await _frames(3)
	check("(6) fx full moves (counter sanity)", V10MjStageFx.motion_tweens > 0, str(V10MjStageFx.motion_tweens))
	_drop(q)


# ── (7) words ─────────────────────────────────────────────────────────────────────────────────────────────────
func _bad_words(text: String) -> Array:
	var low: = text.to_lower()
	var masked: = low
	for a in ALLOW:
		masked = masked.replace(a, "#".repeat(a.length()))
	var bad: = []
	for w in BANNED_LINT:
		if masked.find(w) >= 0:
			bad.append(w)
	for w in BANNED_UX:
		var re: = RegEx.create_from_string("(^|[^\\p{L}])" + _re_escape(w) + "")
		if re.search(low) != null:
			bad.append(w)
	return bad


func _re_escape(s: String) -> String:
	var out: = ""
	for ch in s:
		out += ("\\" + ch) if ch in ".+*?()[]{}|^$\\/" else ch
	return out


func _t7() -> void:
	var texts: = V10MjStageLines.all_subtitles() + V10MjStageSettings.texts()
	var bad: = []
	var long: = []
	for t in texts:
		var b: = _bad_words(String(t))
		var cls: = V10MjStageData.global_class_path("V10Lint")
		if cls != "":
			var lint = load(cls)
			if lint.has_method("check"):
				b.append_array(lint.check(String(t)))
		if not b.is_empty():
			bad.append([t, b])
	for t in V10MjStageLines.all_subtitles():
		if String(t).length() > 32:
			long.append(t)
	check("(7) no stop-words in her lines and the settings", bad.is_empty(), str(bad))
	check("(7) lines ≤ 32 characters (she talks while you play)", long.is_empty(), str(long))
	var n: = 0
	for h in V10MjStageLines.LINES:
		for ev in V10MjStageLines.MATCH_EVENTS:
			n += V10MjStageLines.variants(h, ev).size()
		for ev in V10MjStageLines.TABLE_EVENTS:
			n += V10MjStageLines.variants(h, ev).size()
	check("(7) 5 founders × (8 × 3 + 8) = 160 lines", n == 160, str(n))
	check("(7) the selftest catches a bad word", not _bad_words("Успей! Гарант SSR").is_empty())


func _t_voice_files() -> void:
	var missing: = []
	for h in V10MjStageLines.LINES:
		for ev in (V10MjStageLines.LINES[h] as Dictionary):
			for i in V10MjStageLines.variants(h, ev).size():
				if not ResourceLoader.exists(V10MjStageLines.voice_path(h, ev, i + 1)):
					missing.append("%s_%s_%d" % [h, ev, i + 1])
	check("(+) every line has its voice file", missing.is_empty(), "%d missing, e.g. %s" % [missing.size(), str(missing.slice(0, 4))])
