class_name V10ChatSelftest
extends RefCounted

# --chat_selftest=1 (headless). Validates all chat data (V10ChatValidate: ids, branches, reachability, no dead ends,
# no cycles, 2–3 pills, lengths, stop-words, tokens, photos exist and are sfw, stickers, reactions, feed) and the
# pure logic: rhythm (≤2 new threads/day, ≤1 daily, ≤1 per heroine, ≤3 open), events, partner priority, level gates,
# birthdays, queue TTL, choose/transcript/replay, affection effects vs the soft cap 25, save round-trip through JSON,
# reactions ~30%, stickers (unlock, 3 answers/day), feed (2 a week, like/reply once), history trim 60, transports.
# Touches no save: everything runs on local dictionaries; history files go to user://v10_logs_selftest/.
#
# Run standalone:  flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game -s res://scripts/v10/chat/chat_selftest_cli.gd
# From main.gd (integrator):  if "--chat_selftest=1" in args: V10ChatSelftest.run_and_quit()

const D: = preload("res://core/chat/chat_data.gd")
const C: = preload("res://core/chat/chat.gd")
const F: = preload("res://core/chat/chat_feed.gd")
const L: = preload("res://core/chat/chat_log.gd")
const V: = preload("res://core/chat/chat_validate.gd")
const T: = preload("res://core/chat/chat_transport.gd")
const LT: = preload("res://core/chat/local_transport.gd")

static var ok: = 0
static var bad: = 0


static func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		printerr("CHAT FAIL: " + what)


static func run_and_quit() -> void:
	var r: = run()
	(Engine.get_main_loop() as SceneTree).quit(0 if r[0] == r[1] else 1)


# returns [ok, total]
static func run() -> Array:
	ok = 0
	bad = 0
	_data()
	_text()
	_events()
	_rhythm()
	_sim()
	_choose()
	_save()
	_react_stickers()
	_feed()
	_log()
	_transport()
	_perf()
	printerr("CHAT SELFTEST %d/%d" % [ok, ok + bad])
	return [ok, ok + bad]


static func _ctx(day: int = 100, owned: Array = D.HEROES, partner: String = "mc", lv: int = 10) -> Dictionary:
	var levels: = {}
	for h in owned:
		levels[h] = lv
	return {"day": day, "md": "01-20", "partner": partner, "owned": owned, "levels": levels, "name": "", "name_voc": "", "gender": "m"}


# --- data ------------------------------------------------------------------------

static func _data() -> void:
	var errs: = V.run()
	for e in errs:
		printerr("  data: " + str(e))
	check(errs.is_empty(), "chat data valid (%d errors)" % errs.size())
	for h in D.HEROES:
		check(D.threads(h).size() >= 12, "%s has ≥12 threads" % h)
	check(D.all_threads().size() >= 60, "≥60 threads total")
	check(not D.lint("Я так скучала").is_empty(), "lint catches «скуча»")
	check(not D.lint("Сцена").is_empty(), "lint is substring-strict (сцена ⊃ цена)")
	check(D.lint("Позволь налить тебе чаю.").is_empty(), "clean line passes lint")
	check(D.photo_path("outfits/mc_cafe") != "", "photo path resolves")
	check(D.photo_path("outfits/nope") == "", "missing photo detected")
	# a broken thread must be caught by the validator
	V.errs = []
	V._thread({"id": "mc_x", "hero": "mc", "trigger": "daily", "level": 1, "title": "x", "start": "a",
		"nodes": {"a": {"msgs": [{"k": "text", "t": "раз"}], "choices": [{"t": "да", "next": "b"}]},
			"b": {"msgs": [], "next": "a"}, "z": {"msgs": [], "end": true}}}, "mc", {}, {}, {})
	var joined: = "\n".join(V.errs)
	check(joined.contains("choices must be 2–3"), "validator: 1 pill rejected")
	check(joined.contains("cycle"), "validator: cycle rejected")
	check(joined.contains("unreachable node z"), "validator: unreachable node rejected")
	V.errs = []


static func _text() -> void:
	check(C.typing_ms("") == 400, "typing min 0.4 s")
	check(C.typing_ms("x".repeat(200)) == 2200, "typing max 2.2 s")
	check(C.typing_ms("x".repeat(20)) == 1100, "typing 20 chars = 1.1 s")
	check(C.days_word(1) == "1 день" and C.days_word(3) == "3 дня" and C.days_word(5) == "5 дней", "days 1/3/5")
	check(C.days_word(11) == "11 дней" and C.days_word(21) == "21 день" and C.days_word(14) == "14 дней", "days 11/21/14")
	var ctx: = _ctx()
	check(C.format("{name_voc}, привет", {}, ctx) == "Мастер стола, привет", "no name → «мастер стола», capitalised")
	check(C.format("Привет, {name_voc}!", {}, ctx) == "Привет, мастер стола!", "fallback mid-sentence lower case")
	check(C.format("привет. я нова.", {}, ctx) == "привет. я нова.", "her own lowercase style is kept")
	ctx.name = "Саша"
	ctx.name_voc = "Саш"
	check(C.format("{name_voc}, ты {name}", {}, ctx) == "Саш, ты Саша", "name + vocative")
	check(C.format("ты видел{g:|а}", {}, ctx) == "ты видел", "gender m")
	ctx.gender = "f"
	check(C.format("ты видел{g:|а} и рад{g:|а}", {}, ctx) == "ты видела и рада", "gender f, two tokens")
	check(C.format("×{combo} «{rank}» {days}", {"combo": 7, "rank": "Нефрит", "days": 3}, ctx) == "×7 «Нефрит» 3 дня", "event vars")


# --- events & rhythm ------------------------------------------------------------------

static func _events() -> void:
	var st: = C.ensure({})
	var ctx: = _ctx(10)
	var o: = C.on_event(st, {"kind": "first_win"}, ctx)
	check(o == ["mc_ev_first_win"], "first_win → partner's thread opens at once (%s)" % str(o))
	check(C.on_event(st, {"kind": "first_win"}, ctx).is_empty(), "second first_win the same day → nothing")
	check(C.unread(st) == 1, "badge counts the new thread")
	# the event threads are once: finishing it and winning tomorrow opens nothing new for that event
	_finish_thread(st, "mc_ev_first_win", ctx)
	check(not C.awaiting(st, "mc_ev_first_win") and C.unread(st) == 0, "done thread leaves the badge")
	var ctx2: = _ctx(11)
	check(C.on_event(st, {"kind": "first_win"}, ctx2).is_empty(), "first_win thread is once")
	# outfit goes to the outfit's heroine even if she is not the partner
	o = C.on_event(st, {"kind": "outfit", "outfit": "y_ball", "outfit_name": "Лунный бал"}, ctx2)
	check(o == ["yue_ev_outfit_ball"], "outfit → its heroine (%s)" % str(o))
	check(C.on_event(st, {"kind": "outfit", "outfit": "o_base"}, ctx2).is_empty(), "outfit without thread → nothing")
	check(C.on_event(st, {"kind": "nonsense"}, ctx2).is_empty(), "unknown event ignored")
	# not owned heroine never writes
	var st3: = C.ensure({})
	var c3: = _ctx(5, ["mc"])
	check(C.on_event(st3, {"kind": "outfit", "outfit": "n_offline"}, c3).is_empty(), "outfit of a heroine not owned → nothing")
	check(C.on_event(st3, {"kind": "birthday", "hero": "rin"}, c3).is_empty(), "birthday of a heroine not owned → nothing")
	# combo vars are kept and shown
	o = C.on_event(st3, {"kind": "combo_record", "combo": 12}, c3)
	check(o == ["mc_ev_combo"], "combo record opens")
	var v: = C.view(st3, "mc_ev_combo", c3)
	check(str(v.title) == "Комбо ×12!" and str(v.msgs[0].t).contains("×12"), "combo value in bubble")
	# birthday via tick on the date; repeat after ≥300 days, not before
	var st4: = C.ensure({})
	var c4: = _ctx(200)
	c4.md = "11-30"
	o = C.tick(st4, c4)
	check("rin_ev_bday" in o, "11-30 → Rin's birthday thread (%s)" % str(o))
	_finish_thread(st4, "rin_ev_bday", c4)
	c4.day = 210
	check(not "rin_ev_bday" in C.tick(st4, c4), "birthday not again 10 days later")
	c4.day = 200 + 365
	check("rin_ev_bday" in C.tick(st4, c4), "birthday again next year")
	# bday_window from V10Bday works too
	var st5: = C.ensure({})
	var c5: = _ctx(50)
	c5.bday_window = ["nova"]
	check("nova_ev_bday" in C.tick(st5, c5), "bday_window opens her birthday thread")
	# level gate: daily ladder respects affection level
	var st6: = C.ensure({})
	var c6: = _ctx(1, ["hana"], "hana", 1)
	var opened: = C.tick(st6, c6)
	check(opened == ["hana_d1_hello"], "level 1 → first ladder thread (%s)" % str(opened))
	_finish_thread(st6, "hana_d1_hello", c6)
	c6.day = 2
	check(C.tick(st6, c6).is_empty(), "level 1 → no level-2 thread next day")
	c6.levels.hana = 2
	check(C.tick(st6, c6) == ["hana_d2_morning"], "level 2 unlocks the next")


static func _rhythm() -> void:
	# partner priority for the daily thread
	var st: = C.ensure({})
	var ctx: = _ctx(30, D.HEROES, "rin")
	check(C.tick(st, ctx) == ["rin_d1_hello"], "daily: partner first")
	check(C.tick(st, ctx).is_empty(), "daily: one per day")
	# 4 events the same day → only the cap opens, priority order, one per heroine
	var st2: = C.ensure({})
	var c2: = _ctx(40)
	var all: = []
	all.append_array(C.on_event(st2, {"kind": "first_win"}, c2))
	all.append_array(C.on_event(st2, {"kind": "outfit", "outfit": "r_agent"}, c2))
	all.append_array(C.on_event(st2, {"kind": "outfit", "outfit": "h_winter"}, c2))
	all.append_array(C.on_event(st2, {"kind": "rank_up", "rank": "Нефрит I"}, c2))
	check(all.size() == C.MAX_NEW_PER_DAY, "≤2 new threads a day (%d)" % all.size())
	check(st2.queue.size() == 2, "the rest waits in the queue (%d)" % st2.queue.size())
	all.append_array(C.tick(st2, c2))
	check(all.size() == 2, "tick the same day adds nothing")
	c2.day = 41
	var next: = C.tick(st2, c2)
	check(next.size() >= 1, "queued event opens the next day (%s)" % str(next))
	check(C.open_threads(st2).size() <= C.MAX_OPEN, "never more than 3 open")
	# open cap: 3 unanswered threads block new ones
	var st3: = C.ensure({})
	var c3: = _ctx(60)
	C.on_event(st3, {"kind": "first_win"}, c3)
	C.on_event(st3, {"kind": "outfit", "outfit": "r_agent"}, c3)
	c3.day = 61
	C.on_event(st3, {"kind": "outfit", "outfit": "h_winter"}, c3)
	check(C.open_threads(st3).size() == 3, "3 open threads")
	C.on_event(st3, {"kind": "outfit", "outfit": "y_queen"}, c3)
	check(C.open_threads(st3).size() == 3 and st3.queue.size() == 1, "4th waits while 3 are unanswered")
	# queue TTL: unanswered for 3+ days → the queued event quietly drops
	c3.day = 61 + C.QUEUE_TTL
	C.tick(st3, c3)
	check(st3.queue.is_empty(), "queued event expires after %d days" % C.QUEUE_TTL)
	# the comeback thread repeats only after 30 days
	var st4: = C.ensure({})
	var c4: = _ctx(100, ["nova"], "nova")
	check(C.on_event(st4, {"kind": "comeback", "days": 4}, c4) == ["nova_ev_comeback"], "comeback opens")
	check(str(C.view(st4, "nova_ev_comeback", c4).msgs[2].t).contains("переписала"), "comeback text")
	_finish_thread(st4, "nova_ev_comeback", c4)
	c4.day = 110
	check(C.on_event(st4, {"kind": "comeback", "days": 3}, c4).is_empty(), "comeback not again within 30 days")
	c4.day = 131
	check(C.on_event(st4, {"kind": "comeback", "days": 5}, c4) == ["nova_ev_comeback"], "comeback again after 30 days")
	check(C.view(st4, "nova_ev_comeback", c4).msgs.size() == 3 and st4.chats.nova_ev_comeback.picks.is_empty(), "repeat restarts the thread")


# 180 days of play with random events and a player who answers ~70% of days
static func _sim() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261124
	var st: = C.ensure({})
	var events: = ["first_win", "combo_record", "rank_up", "comeback", "outfit"]
	var outfits: = ["o_cafe", "o_dragon", "r_yukata", "r_agent", "h_winter", "h_street", "y_queen", "y_ball", "n_offline", "n_ssr"]
	var max_new: = 0
	var max_daily: = 0
	var max_open: = 0
	var per_hero_day_ok: = true
	var twice: = false
	var opened_ever: = {}
	var bond: = {}
	var bond_ok: = true
	for day in range(1000, 1180):
		var lv: = 1 + (day - 1000) / 15
		var ctx: = _ctx(day, D.HEROES, ["mc", "rin", "hana", "yue", "nova"][(day / 40) % 5], lv)
		var md: = "%02d-%02d" % [1 + ((day - 1000) / 28) % 12, 1 + (day - 1000) % 28]
		ctx.md = md
		var today: = C.tick(st, ctx)
		for i in rng.randi_range(0, 3):
			var ev: = {"kind": events[rng.randi() % events.size()], "combo": rng.randi_range(5, 30), "rank": "Нефрит", "days": 3}
			if ev.kind == "outfit":
				ev.outfit = outfits[rng.randi() % outfits.size()]
			today.append_array(C.on_event(st, ev, ctx))
		var heroes: = {}
		for tid in today:
			var h: = D.hero_of(tid)
			if heroes.has(h) and D.thread(tid).trigger != "birthday":
				per_hero_day_ok = false
			heroes[h] = true
			var t: = D.thread(tid)
			if opened_ever.has(tid) and int(t.get("repeat", 0)) == 0:
				twice = true
			opened_ever[tid] = true
		max_new = maxi(max_new, int(st.new_n))
		max_daily = maxi(max_daily, int(st.new_daily))
		max_open = maxi(max_open, C.open_threads(st).size())
		if rng.randf() < 0.7:
			for tid in C.open_threads(st):
				var guard: = 0
				while C.awaiting(st, tid) and guard < 8:
					guard += 1
					var n: int = C.view(st, tid, ctx).choices.size()
					var r: = C.choose(st, tid, rng.randi() % n, ctx)
					for e in r.get("effects", []):
						bond_ok = _bond_gain(bond, e.hero, e.n, day) and bond_ok
	check(max_new <= C.MAX_NEW_PER_DAY, "sim: ≤2 new a day (max %d)" % max_new)
	check(max_daily <= C.MAX_DAILY_PER_DAY, "sim: ≤1 daily a day (max %d)" % max_daily)
	check(max_open <= C.MAX_OPEN, "sim: ≤3 open (max %d)" % max_open)
	check(per_hero_day_ok, "sim: ≤1 new thread per heroine a day")
	check(not twice, "sim: once-threads never reopen")
	check(opened_ever.size() >= 55, "sim: most content reachable in 180 days (%d threads)" % opened_ever.size())
	check(bond_ok, "sim: soft cap 25 a heroine a day holds")
	var daily_seen: = 0
	for tid in opened_ever:
		if D.thread(tid).trigger == "daily":
			daily_seen += 1
	check(daily_seen >= 30, "sim: the daily ladder progresses (%d)" % daily_seen)


# a fake V10Bond: soft gains capped at 25 per heroine per day; returns false if the cap was ever exceeded
static func _bond_gain(bond: Dictionary, hero: String, n: int, day: int) -> bool:
	var k: = "%s:%d" % [hero, day]
	bond[k] = mini(25, int(bond.get(k, 0)) + n)
	return int(bond[k]) <= 25


static func _finish_thread(st: Dictionary, tid: String, ctx: Dictionary, pick: int = 0) -> Array:
	var eff: = []
	var guard: = 0
	while C.awaiting(st, tid) and guard < 10:
		guard += 1
		var r: = C.choose(st, tid, pick, ctx)
		eff.append_array(r.get("effects", []))
	return eff


# --- conversation ----------------------------------------------------------------------

static func _choose() -> void:
	var ctx: = _ctx(300)
	var max_aff: = 0
	var all_ok: = true
	var replay_ok: = true
	for t in D.all_threads():
		for pick in [0, 1, 2]:
			var st: = C.ensure({})
			C._open(st, t.id, {"combo": 9, "rank": "Нефрит", "days": 3}, ctx)
			var shown: Array = C.view(st, t.id, ctx).msgs
			var eff: = 0
			var guard: = 0
			while C.awaiting(st, t.id) and guard < 10:
				guard += 1
				var n: int = C.view(st, t.id, ctx).choices.size()
				var r: = C.choose(st, t.id, mini(pick, n - 1), ctx)
				if not r.ok:
					all_ok = false
					break
				shown.append(r.me)
				shown.append_array(r.msgs)
				for e in r.effects:
					eff += int(e.n)
					if e.hero != t.hero or e.src != "chat":
						all_ok = false
			if not st.chats[t.id].done:
				all_ok = false
			max_aff = maxi(max_aff, eff)
			if JSON.stringify(shown) != JSON.stringify(C.transcript(st, t.id, ctx)):
				replay_ok = false
	check(all_ok, "every thread completes by any pill, effects go to her")
	check(max_aff <= D.MAX_THREAD_AFF and max_aff >= D.DONE_AFF, "thread affection 3..5 (max %d)" % max_aff)
	check(replay_ok, "transcript rebuilt from picks == what was shown")
	var st: = C.ensure({})
	C._open(st, "rin_d1_hello", {}, ctx)
	check(not C.choose(st, "rin_d1_hello", 7, ctx).ok, "bad pill index rejected")
	check(not C.choose(st, "nope", 0, ctx).ok, "unknown thread rejected")
	var r: = C.choose(st, "rin_d1_hello", 0, ctx)
	check(r.done and r.choices.is_empty() and r.effects.size() == 2, "rin_d1 pill 0: +1 bonus and +3 done")
	check(not C.choose(st, "rin_d1_hello", 0, ctx).ok, "done thread takes no more picks")
	check(C.view(st, "rin_d1_hello", ctx).choices.is_empty(), "done view has no pills")
	# flags and rows
	var rows: = C.rows(st, ctx)
	check(rows.size() == 1 and rows[0].hero == "rin" and not rows[0].dot, "rows: one row, read")
	check(str(rows[0].last) != "", "rows: last line")


# --- save -------------------------------------------------------------------------------

static func _save() -> void:
	check(C.ensure({}).keys().size() == C.default_state().keys().size(), "ensure fills defaults")
	var st: = C.ensure({"chats": {"x": 1}, "queue": "broken"})
	check(st.chats.has("x") and st.queue is Array, "ensure keeps data and repairs types")
	var a: = C.ensure({})
	var ctx: = _ctx(500)
	C.tick(a, ctx)
	C.on_event(a, {"kind": "combo_record", "combo": 14}, ctx)
	var tid: String = C.open_threads(a)[0]
	C.choose(a, tid, 1, ctx)
	var b: Dictionary = JSON.parse_string(JSON.stringify(a))
	C.ensure(b)
	check(JSON.stringify(C.transcript(a, tid, ctx)) == JSON.stringify(C.transcript(b, tid, ctx)), "JSON round-trip keeps the conversation")
	var b2: = b.duplicate(true)
	C.ensure(b2)
	check(JSON.stringify(b2) == JSON.stringify(b), "ensure is idempotent")
	# continue after the round-trip (floats from JSON)
	var tids: = C.open_threads(b)
	var cont: = true
	for t in tids:
		while C.awaiting(b, t):
			if not C.choose(b, t, 0, ctx).ok:
				cont = false
				break
	check(cont, "picks continue after JSON round-trip")
	ctx.day = 501
	check(C.tick(b, ctx).size() <= C.MAX_NEW_PER_DAY, "tick after round-trip")
	check(JSON.stringify(b).length() < 8000, "save stays small (%d bytes)" % JSON.stringify(b).length())
	# review fix: the game save is JSON, ints come back as floats — an app restart must not reset today's counters
	var r: = C.ensure({})
	var rc: = _ctx(700)
	var got: = 0
	for i in 5:
		for t2 in C.tick(r, rc):
			got += 1
			while C.awaiting(r, t2):
				C.choose(r, t2, 0, rc)
		r = C.ensure(JSON.parse_string(JSON.stringify(r)))
	check(got <= C.MAX_DAILY_PER_DAY, "restarts on one day keep the daily limit (%d)" % got)
	check(typeof(r.new_key) == TYPE_INT and int(r.new_key) == 700, "ensure casts JSON floats back to int")
	# review fix: a thread/node removed by a content update must not stay «open» and jam MAX_OPEN
	var o: = C.ensure({"chats": {"gone_thread": {"pos": "a", "done": false, "picks": [], "day": 5}}})
	check(C.open_threads(o).is_empty(), "orphaned thread is closed by ensure")


# --- reactions & stickers ------------------------------------------------------------------

static func _react_stickers() -> void:
	var ctx: = _ctx(700)
	var st: = C.ensure({})
	check(not C.react(st, "mc_d1_hello", 0, "kiss", ctx).ok, "unknown reaction rejected")
	check(not C.react(st, "nope", 0, "heart", ctx).ok, "reaction on unknown thread rejected")
	var replies: = 0
	var n: = 0
	for t in D.all_threads():
		for i in 6:
			n += 1
			var r: = C.react(st, t.id, i, ["heart", "laugh", "wow", "sad", "fire", "tea"][i], ctx)
			if str(r.get("reply", "")) != "":
				replies += 1
	var pct: = 100.0 * replies / n
	check(pct > 20.0 and pct < 40.0, "she answers ~30%% of reactions (%.1f%%)" % pct)
	check(str(C.react(st, "mc_d1_hello", 0, "fire", ctx).reply) == "", "re-reacting never answers twice")
	# stickers
	check(C.stickers_for(_ctx(1, [])).size() == 8, "8 common stickers for everyone")
	check(C.stickers_for(_ctx(1, ["mc"], "mc", 1)).size() == 14, "own heroine: 6 at level 1")
	check(C.stickers_for(_ctx(1, ["mc"], "mc", 5)).size() == 16, "own heroine: all 8 at level 5")
	var s2: = C.ensure({})
	var c1: = _ctx(800, ["mc"], "mc", 1)
	check(not C.send_sticker(s2, "mc", "mc_heart", c1).ok, "locked sticker can't be sent")
	check(not C.send_sticker(s2, "rin", "c_heart", c1).ok, "can't send to a heroine not owned")
	var answered: = 0
	for i in 5:
		var r: = C.send_sticker(s2, "mc", "c_laugh", c1)
		if str(r.get("reply", "")) != "":
			answered += 1
	check(answered == C.STICKER_REPLIES_PER_DAY, "sticker answers capped at 3 a day (%d)" % answered)
	c1.day = 801
	check(str(C.send_sticker(s2, "mc", "c_laugh", c1).reply) != "", "sticker answers reset next day")


# --- feed ---------------------------------------------------------------------------------

static func _feed() -> void:
	var st: = F.ensure({})
	var ctx: = _ctx(1000)
	check(F.visible(st, ctx).size() == 1, "feed: day 0 → 1 post")
	ctx.day = 1003
	check(F.visible(st, ctx).size() == 2, "feed: day 3 → 2 posts")
	ctx.day = 1007
	check(F.visible(st, ctx).size() == 3, "feed: day 7 → 3 posts (two a week)")
	ctx.day = 1070
	var v: = F.visible(st, ctx)
	check(v.size() == 20 and int(v[0].day) >= int(v[1].day), "feed: all 20 after 10 weeks, newest first")
	check(F.unseen(st, ctx) == 20, "feed badge: 20 unseen")
	F.mark_seen(st, ctx)
	check(F.unseen(st, ctx) == 0, "feed badge cleared")
	var id: String = v[0].id
	var l1: = F.like(st, id, ctx)
	check(l1.ok and l1.effects[0].n == 1, "like +1")
	check(not F.like(st, id, ctx).ok, "like once")
	var r1: = F.reply(st, id, 1, ctx)
	check(r1.ok and r1.effects[0].n == 2 and str(r1.answer) != "", "reply +2 with her answer")
	check(not F.reply(st, id, 0, ctx).ok, "reply once")
	check(not F.reply(st, v[1].id, 5, ctx).ok, "bad reply index")
	var only: = F.ensure({})
	var c2: = _ctx(1070, ["rin"])
	var vr: = F.visible(only, c2)
	var all_rin: = true
	for p in vr:
		all_rin = all_rin and p.hero == "rin"
	check(all_rin and vr.size() == 1, "feed: only owned heroines, schedule per player (%d)" % vr.size())
	# review fix: pulling a new heroine adds her posts, never moves or hides posts already shown
	var fs: = F.ensure({})
	var fc: = _ctx(2000, ["mc"])
	F.visible(fs, fc)
	fc.day = 2010
	var before: = F.visible(fs, fc).map(func(p): return p.id)
	fc.owned = ["mc", "hana"]
	var after: = F.visible(fs, fc).map(func(p): return p.id)
	var kept: = true
	for id2 in before:
		kept = kept and id2 in after
	check(before.size() == 4 and kept, "feed: shown posts stay after a new heroine (%d → %d)" % [before.size(), after.size()])
	fc.day = 2030
	var n30: = F.visible(fs, fc).size()
	fs = F.ensure(JSON.parse_string(JSON.stringify(fs)))
	check(F.visible(fs, fc).size() == n30 and typeof(fs.next) == TYPE_INT, "feed survives the JSON save round-trip")
	var ex: = F.ensure({})
	var ec: = _ctx(3000, ["nova"])
	F.visible(ex, ec)
	ec.day = 3100
	check(F.visible(ex, ec).size() == 4 and int(ex.next) == -1, "feed: pool exhausted → rhythm pauses")
	ec.owned = ["nova", "yue"]
	var ey: = F.visible(ex, ec)
	check(ey[0].hero == "yue" and int(ey[0].day) == 3100, "feed: new heroine's first post opens the day she arrives")


# --- history log ----------------------------------------------------------------------------

static func _log() -> void:
	var log: = []
	for i in 75:
		log = L.append(log, [{"who": "h", "k": "text", "t": str(i)}])
	check(log.size() == 60 and log[0].t == "15" and log[59].t == "74", "history trimmed to the newest 60")
	var dir: = "user://v10_logs_selftest/"
	check(L.write("mc", log, dir), "history file written")
	var back: = L.read("mc", dir)
	check(back.size() == 60 and back[59].t == "74", "history file read back")
	check(L.read("nobody", dir).is_empty(), "missing history → empty")
	DirAccess.remove_absolute(dir + "chat_mc.json")
	DirAccess.remove_absolute(dir)


# --- transports -------------------------------------------------------------------------------

static func _transport() -> void:
	var base: = T.new()
	check(not base.available() and not base.choose("x", 0, {}).ok, "base transport is an interface")
	var save: = {}
	var tr: = LT.new(save, "user://v10_logs_selftest/")
	check(tr.kind() == "local" and tr.available(), "local transport")
	var got: = []
	tr.incoming.connect(func(m): got.append(m))
	var ctx: = _ctx(900, D.HEROES, "hana")
	var r: = tr.post_event({"kind": "first_win"}, ctx)
	check(r.ok and r.opened == ["hana_ev_first_win"], "transport: event opens")
	check(got.size() == 1 and got[0].hero == "hana", "transport: incoming signal")
	check(tr.unread() == 1, "transport: unread")
	var o: = tr.open("hana_ev_first_win", ctx)
	check(o.ok and o.view.choices.size() == 2, "transport: open view")
	var c: = tr.choose("hana_ev_first_win", 0, ctx)
	check(c.ok and c.me.k == "sticker" and c.done, "transport: sticker pill, thread done")
	check(save.chats.has("hana_ev_first_win"), "transport writes into the given save dict")
	check(L.read("hana", "user://v10_logs_selftest/").size() >= 4, "transport mirrors bubbles to history")
	check(tr.list(ctx).rows.size() == 1, "transport: list rows")
	check(tr.sticker("hana", "c_heart", ctx).ok, "transport: sticker")
	DirAccess.remove_absolute("user://v10_logs_selftest/chat_hana.json")
	DirAccess.remove_absolute("user://v10_logs_selftest/")


static func _perf() -> void:
	var ctx: = _ctx(1)
	var st: = C.ensure({})
	for t in D.all_threads():
		C._open(st, t.id, {}, ctx)
		_finish_thread(st, t.id, ctx, 1)
	var t0: = Time.get_ticks_usec()
	var n: = 0
	for t in D.all_threads():
		n += C.transcript(st, t.id, ctx).size()
	var ms: = (Time.get_ticks_usec() - t0) / 1000.0
	check(ms < 60.0, "rebuild all %d threads (%d bubbles) in %.1f ms" % [D.all_threads().size(), n, ms])
	t0 = Time.get_ticks_usec()
	C.rows(st, ctx)
	C.unread(st)
	ms = (Time.get_ticks_usec() - t0) / 1000.0
	check(ms < 12.0, "chat list + badge in %.1f ms" % ms)
