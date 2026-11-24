class_name V10MetaSelftest
extends RefCounted

# Selftest of lane «meta» (M1 Ф1, Ф5, Ф6, Ф7, SAVE_VER 8). Pure logic, no screen: runs under --headless.
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/meta/meta_runner.tscn \
#     -- --meta_selftest=1 --save=user://meta_runner.json [--meta_grep_strict=1]
# Prints «META_SELFTEST ok/total» with a per-module breakdown and every failure. Covers the spec's
# --meta_selftest, --winbar_selftest, --afisha_selftest, --v10_save_selftest and the store-guard check.
# The real shop screen check (store build shows 0 ₽ buttons) runs in meta_runner (needs the scene tree).

static var ok: = 0
static var total: = 0
static var fails: Array = []
static var mods: = {}
static var _mod: = ""
static var info: Array = []


static func check(cond: bool, what: String) -> void:
	total += 1
	if not mods.has(_mod):
		mods[_mod] = [0, 0]
	mods[_mod][1] += 1
	if cond:
		ok += 1
		mods[_mod][0] += 1
	else:
		fails.append("[%s] %s" % [_mod, what])


static func _lt(s: String) -> int:
	# local phone time «YYYY-MM-DDTHH:MM:SS» → unix, with the test time zone (V10Meta.set_tz)
	return int(Time.get_unix_time_from_datetime_string(s)) - V10Meta.tz_bias_min() * 60


static func run(strict_grep: = false) -> int:
	ok = 0
	total = 0
	fails = []
	mods = {}
	info = []
	V10Meta.set_tz(180)
	V10Notify.log_path = "user://v10_logs/notify_selftest.json"
	V10Notify.clear_log()
	_meta()
	_bond()
	_notify()
	_entry()
	_lint()
	_save()
	_win()
	_more()
	_afisha()
	_shop_logic()
	_grep(strict_grep)
	V10Meta.clear_now()
	V10Meta.clear_tz()
	V10Meta.unbind()
	V10Afisha.unbind()
	V10Bond.sink = Callable()
	V10WinStack.clear()
	V10ShopGuard.unforce()
	V10EntryQueue.new_launch()
	V10Notify.log_path = "user://v10_logs/notify.json"
	V10Notify._log_loaded = false
	var parts: = []
	for m in mods:
		parts.append("%s %d/%d" % [m, mods[m][0], mods[m][1]])
	for f in fails:
		print("META_FAIL ", f)
	for i in info:
		print("META_INFO ", i)
	print("META_SELFTEST %d/%d (%s)" % [ok, total, ", ".join(parts)])
	return total - ok


# ── Ф1 time, day, clock ────────────────────────────────────────────────────────────────────────────────────────
static func _meta() -> void:
	_mod = "meta"
	V10Meta.bind({})
	var t359: = _lt("2026-11-24T03:59:00")
	var t400: = _lt("2026-11-24T04:00:00")
	check(V10Meta.key_of(t359) == "2026-11-23", "03:59 belongs to the previous day")
	check(V10Meta.key_of(t400) == "2026-11-24", "04:00 starts the new day")
	check(V10Meta.key_of(t359) != V10Meta.key_of(t400), "03:59 and 04:00 are different days")
	V10Meta.set_now(t359)
	check(V10Meta.secs_to_rollover() == 60, "secs_to_rollover at 03:59 = 60 (got %d)" % V10Meta.secs_to_rollover())
	# an update installed at 01:30 after 0.9 already counted the new date: the day does not roll back
	var st: = V10Meta.st()
	st.last_key = "2026-11-25"
	V10Meta.set_now(_lt("2026-11-25T01:30:00"))
	check(V10Meta.key_of(V10Meta.now_unix()) == "2026-11-24", "raw key at 01:30 is the previous day")
	check(V10Meta.day_key() == "2026-11-25", "day_key never goes below last_key (update at 01:30)")
	V10Meta.set_now(_lt("2026-11-26T04:00:00"))
	check(V10Meta.day_key() == "2026-11-26", "day_key moves on at the next 04:00")
	# clock guard
	V10Meta.bind({})
	st = V10Meta.st()
	var T: = _lt("2026-11-24T12:00:00")
	st.max_unix = T
	var got: = [0]
	V10Meta.on("streak", func(d): got[0] += int(d.get("n", 1)))
	V10Meta.set_now(T - 2 * 3600)
	check(not V10Meta.clock_ok(), "clock moved back 2 h → clock_ok() false")
	check(not V10Meta.grant_dated("streak", {"n": 1}), "dated grant with a bad clock is not applied now")
	check(V10Meta.pending_count() == 1 and got[0] == 0, "…it waits in pending (not lost)")
	V10Meta.tick()
	check(V10Meta.pending_count() == 1 and int(st.max_unix) == T, "tick with a bad clock keeps pending and max_unix")
	V10Meta.set_now(T + 60)
	V10Meta.tick()
	check(got[0] == 1 and V10Meta.pending_count() == 0, "clock back → pending applied once")
	check(int(st.max_unix) == T + 60, "max_unix follows the clock")
	V10Meta.set_now(T + 60 - 30 * 60)
	check(V10Meta.clock_ok(), "clock moved back 30 min → still ok")
	check(V10Meta.grant_dated("streak", {"n": 2}) and got[0] == 3, "dated grant with a good clock applies at once")
	check(not V10Meta.grant_dated("nobody", {}) and V10Meta.pending_count() == 1, "a grant with no handler yet waits")
	V10Meta.on("nobody", func(_d): got[0] += 100)
	V10Meta.set_now(T + 120)
	V10Meta.tick()
	check(got[0] == 103 and V10Meta.pending_count() == 0, "a late handler receives the waiting grant")
	V10Meta.off("streak")
	V10Meta.off("nobody")
	# day_rolled
	var rolled: = []
	var cb: = func(a, b): rolled.append([a, b])
	V10Meta.bus().day_rolled.connect(cb)
	V10Meta.set_now(_lt("2026-11-24T23:00:00"))
	V10Meta.tick()
	V10Meta.set_now(_lt("2026-11-25T04:00:30"))
	V10Meta.tick()
	V10Meta.tick()
	check(rolled.size() == 1 and rolled[0] == ["2026-11-24", "2026-11-25"], "day_rolled fires once at 04:00 (%s)" % str(rolled))
	V10Meta.bus().day_rolled.disconnect(cb)
	var ds: = int(st.days_seen)
	check(ds >= 1, "days_seen counts new days")
	# shared calendar day: 04:00 Moscow for everyone, whatever the phone zone
	V10Meta.set_tz(-300)
	var u330: = int(Time.get_unix_time_from_datetime_string("2026-11-24T00:30:00"))
	var u400: = int(Time.get_unix_time_from_datetime_string("2026-11-24T01:00:00"))
	check(V10Meta.cal_key(u330) == "2026-11-23" and V10Meta.cal_key(u400) == "2026-11-24", "cal_key flips at 04:00 MSK")
	check(V10Meta.fmt_msk(u400).ends_with("04:00 МСК") and V10Meta.fmt_msk(u400).begins_with("вт, 24 ноября"),
		"fmt_msk «вт, 24 ноября, 04:00 МСК» (%s)" % V10Meta.fmt_msk(u400))
	V10Meta.set_tz(180)
	check(V10Meta.fmt_when(_lt("2026-11-26T18:30:00")) == "чт 18:30", "fmt_when «чт 18:30»")
	# --v10_now / --v10_dayshift parse (no args in the test run → the system clock)
	V10Meta.clear_now()
	check(absi(V10Meta.now_unix() - int(Time.get_unix_time_from_system())) <= 2, "unforced clock = system clock")


# ── Ф1 / §2.4 affection ────────────────────────────────────────────────────────────────────────────────────────
static func _bond() -> void:
	_mod = "bond"
	V10Meta.bind({})
	V10Meta.set_now(_lt("2026-11-24T12:00:00"))
	var aff: = {}
	V10Bond.sink = func(h, n): aff[h] = int(aff.get(h, 0)) + n
	var given: = 0
	for i in 30:
		given += V10Bond.gain("rin", 1, "feed_like")
	check(given == 25 and int(aff.rin) == 25, "30 soft +1 → exactly 25 (got %d)" % given)
	check(V10Bond.gain("rin", 3, "chat_branch") == 0, "at the cap a soft gain gives 0")
	check(V10Bond.capped("rin") and V10Bond.today_text("rin") == V10Bond.T_HAPPY, "at the cap: «На сегодня она уже счастлива»")
	check(V10Bond.gain("rin", 10, "gift") == 10 and int(aff.rin) == 35, "hard source (gift) passes the cap")
	check(V10Bond.gain("rin", 50, "bday") == 50, "hard source (bday) passes the cap")
	var t: = 0
	for i in 5:
		t += V10Bond.gain("hana", 1, "touch")
	check(t == 3 and V10Bond.touch_left("hana") == 0, "touch sub-limit 3/day")
	V10Bond.gain("yue", 22, "letter_reply")
	check(V10Bond.today_text("yue") == "сегодня 22/25", "«сегодня 22/25» from 20 (%s)" % V10Bond.today_text("yue"))
	V10Bond.gain("nova", 5, "hand")
	check(V10Bond.today_text("nova") == "", "no counter below 20")
	check(V10Bond.gain("nova", 4, "chat_branch") == 4 and V10Bond.chip_text(3) == "+3", "chip «+3»")
	check(V10Bond.gain("nova", 3, "hand") == 3 and V10Bond.soft_today("nova") == 12, "soft sources share one counter")
	V10Meta.set_now(_lt("2026-11-25T04:00:01"))
	check(V10Bond.soft_today("rin") == 0 and V10Bond.gain("rin", 1, "feed_like") == 1, "a new day resets the soft cap")
	V10Meta.set_now(_lt("2026-11-25T03:59:00"))
	check(V10Bond.soft_today("rin") == 1, "the bond day follows day_key (no reset back at 03:59)")
	check(V10Bond.gain("mc", 0, "touch") == 0 and V10Bond.gain("", 1, "touch") == 0, "zero / empty hero → nothing")
	V10Bond.sink = Callable()


# ── Ф1 notification plan ───────────────────────────────────────────────────────────────────────────────────────
static func _notify() -> void:
	_mod = "notify"
	V10Meta.bind({})
	var t0: = _lt("2026-11-24T14:00:00")
	V10Meta.set_now(t0)
	check(V10Notify.request("salon", t0).is_empty(), "no consent → nothing planned")
	check(V10Notify.can_ask(t0), "can ask before the first answer")
	V10Notify.set_consent(false)
	check(not V10Notify.can_ask(t0 + 86400) and V10Notify.can_ask(t0 + 31 * 86400), "after «Не сейчас» re-ask in ≥30 days")
	V10Notify.set_consent(true)
	check(V10Notify.cat_on("bday") and V10Notify.cat_on("salon") and V10Notify.cat_on("feed"), "consent turns bday/salon/feed on")
	check(not V10Notify.cat_on("comeback"), "Возвращение stays OFF by default")
	check(V10Notify.request("comeback", t0, "rin").is_empty(), "comeback switched off → skipped")
	var p1: = V10Notify.request("salon", t0)
	check(not p1.is_empty() and int(p1.at) == t0, "salon planned at 14:00")
	check(V10Notify.request("feed", t0, "hana").is_empty(), "a 2nd request within the budget is dropped")
	var p2: = V10Notify.request("bday", t0 + 3600, "yue")
	check(not p2.is_empty() and str(V10Meta.st().notify.queued.cat) == "bday", "bday displaces the queued salon")
	check(V10Notify.request("salon", t0 + 7200).is_empty(), "lower priority does not displace bday")
	# three requests within 72 h → one notification
	var sent: = []
	var q: = V10Notify.advance(t0 + 3600 + 1)
	if not q.is_empty():
		sent.append(q)
	for k in [1, 2]:
		V10Meta.set_now(t0 + k * 20 * 3600)
		V10Notify.request("feed", V10Meta.now_unix(), "rin")
		var q2: = V10Notify.advance(t0 + 72 * 3600 - 1)
		if not q2.is_empty():
			sent.append(q2)
	check(sent.size() == 1, "3 requests in 72 h → 1 sent (got %d)" % sent.size())
	var nx: = V10Notify.next_allowed(t0 + 3600)
	check(nx >= int(sent[0].at) + V10Notify.BUDGET_SECS if not sent.is_empty() else false, "next allowed ≥ last + 72 h")
	check(V10Notify.next_text(t0).begins_with("Следующее уведомление не раньше: "), "next_text caption")
	# quiet hours
	V10Meta.bind({})
	V10Notify.set_consent(true)
	var t2310: = _lt("2026-11-24T23:10:00")
	V10Meta.set_now(t2310)
	var pq: = V10Notify.request("feed", t2310, "mc")
	var lo: = _lt("2026-11-25T10:00:00")
	check(not pq.is_empty() and int(pq.at) >= lo and int(pq.at) <= lo + 40 * 60, "23:10 → 10:00–10:40 next day")
	V10Meta.bind({})
	V10Notify.set_consent(true)
	var t0800: = _lt("2026-11-25T08:00:00")
	V10Meta.set_now(t0800)
	var pm: = V10Notify.request("salon", t0800)
	var lo2: = _lt("2026-11-25T10:00:00")
	check(int(pm.get("at", 0)) >= lo2 and int(pm.get("at", 0)) <= lo2 + 40 * 60, "08:00 → 10:00–10:40 same day")
	check(V10Notify.quiet_shift(_lt("2026-11-25T21:59:00")) == _lt("2026-11-25T21:59:00"), "21:59 is not quiet")
	check(not V10Notify.in_quiet(_lt("2026-11-25T10:00:00")) and V10Notify.in_quiet(_lt("2026-11-25T22:00:00")), "quiet = 22:00–10:00")
	var bad: = V10Lint.scan(V10NotifyText.all_lines())
	check(bad.is_empty(), "every notification line passes V10Lint %s" % str(bad))
	var plan_has_price: = false
	for c in V10Notify.CATS:
		for id in V10NotifyText.ids(c):
			if V10NotifyText.text(id, "rin").find("₽") >= 0:
				plan_has_price = true
	check(not plan_has_price, "no price in any notification")
	var ents: = V10Notify.log_entries()
	check(ents.size() > 5 and FileAccess.file_exists(V10Notify.log_path), "plan log written to user://v10_logs (%d)" % ents.size())


# ── Ф1 entry queue ─────────────────────────────────────────────────────────────────────────────────────────────
static func _entry() -> void:
	_mod = "entry"
	V10Meta.bind({})
	V10EntryQueue.new_launch()
	var shown: = []
	V10EntryQueue.offer("table_style", "night", func(): shown.append("table_style"))
	V10EntryQueue.offer("hero_bday", "rin-2026", func(): shown.append("hero_bday"))
	V10EntryQueue.offer("banner_phase", "b3", func(): shown.append("banner_phase"))
	V10EntryQueue.offer("rules_note", "r1", func(): shown.append("rules_note"))
	check(V10EntryQueue.run() and shown == ["hero_bday"], "one scene: the heroine birthday wins (%s)" % str(shown))
	check(V10EntryQueue.take().is_empty() and not V10EntryQueue.run(), "no 2nd full-screen scene this launch")
	check(not V10EntryQueue.offer("comeback", "c1"), "offers after the take are refused")
	V10EntryQueue.done("hero_bday", "rin-2026")
	V10EntryQueue.new_launch()
	check(not V10EntryQueue.offer("hero_bday", "rin-2026"), "a seen scene is not offered again")
	V10EntryQueue.offer("banner_phase", "b3")
	V10EntryQueue.offer("comeback", "c1")
	V10EntryQueue.offer("player_bday", "2026")
	check(str(V10EntryQueue.take().get("kind", "")) == "comeback", "comeback > player birthday > banner")
	V10EntryQueue.new_launch()
	V10EntryQueue.offer("player_bday", "2026")
	V10EntryQueue.offer("hero_bday", "hana-2026")
	check(str(V10EntryQueue.take().get("kind", "")) == "player_bday", "player birthday > heroine birthday")
	V10EntryQueue.new_launch()
	check(not V10EntryQueue.offer("popup_sale", "x"), "unknown kinds are refused")


static func _lint() -> void:
	_mod = "lint"
	check(not V10Lint.ok("Я так скучала без тебя"), "«скучала» is banned")
	check(not V10Lint.ok("Вернись скорее"), "«вернись» is banned")
	check(not V10Lint.ok("Успей забрать скидку"), "«успей», «скидк» are banned")
	check(V10Lint.ok("Однажды мы заварим этот чай вместе"), "«однажды» is allowed")
	check(V10Lint.ok("Награда бесплатно за вход"), "«бесплатно» alone is allowed")
	check(not V10Lint.ok("Сейчас бесплатно, потом 79 ₽"), "«бесплатно» next to a price is banned")
	check(not V10Lint.ok("Новый баннер уже здесь"), "«баннер» is banned in heroine text")


# ── SAVE_VER 8 ─────────────────────────────────────────────────────────────────────────────────────────────────
static func _fixture09() -> Dictionary:
	var s: Dictionary = G.default_state().duplicate(true)
	s.ver = 7
	s.login = {"n": 12, "last": "2026-11-25"}
	s.daily_day = "2026-11-25"
	s.tasks = {"day": "2026-11-25", "pairs": 30, "levels": 2, "combo5": 1, "claimed": [true, false, false]}
	s.pet = {"day": "2026-11-25", "n": 2}
	s.aff = {"mc": 220, "rin": 140, "hana": 30, "yue": 5, "nova": 0}
	s.stars = {"0": 3, "1": 2, "2": 3}
	s.unlocked = 4
	s["v9_letters"] = {"day": "2026-11-25", "n": 1, "list": []}
	return s


static func _save() -> void:
	_mod = "save"
	V10Meta.unbind()
	V10Meta.set_now(_lt("2026-11-25T01:30:00"))
	var s: = _fixture09()
	var before: = JSON.stringify(s)
	var old: Dictionary = JSON.parse_string(before)
	var calls: = [0]
	V10Save.register("v10_test", {"a": 1, "b": {"c": 2}})
	V10Save.register_migrator("test", func(S, _now):
		calls[0] += 1
		S["v10_test_mig"] = true)
	var rep: = V10Save.migrate(s)
	check(int(s.ver) == 8 and int(rep.from) == 7 and int(rep.to) == 8, "ver 7 → 8")
	var lost: = []
	var after: Dictionary = JSON.parse_string(JSON.stringify(s))
	for k in old:
		if k == "ver":
			continue
		if not after.has(k) or JSON.stringify(after[k]) != JSON.stringify(old[k]):
			lost.append(k)
	check(lost.is_empty(), "every 0.9 key kept with its value %s" % str(lost))
	check(s.v10_meta is Dictionary and s.v10_afisha is Dictionary and s.v10_test is Dictionary, "v10 keys added")
	check(int(s.v10_meta.days_seen) == 12 and int(s.v10_meta.max_unix) == V10Meta.now_unix(), "days_seen = login.n, max_unix = now")
	check(str(s.v10_meta.last_key) == "2026-11-25", "last_key = the 0.9 day already counted (%s)" % s.v10_meta.last_key)
	V10Meta.bind(s.v10_meta)
	check(V10Meta.day_key() == "2026-11-25", "update at 01:30: day_key not rolled back → no 2nd daily")
	check(calls[0] == 1 and bool(s.get("v10_test_mig", false)), "module migrator ran once")
	var once: = JSON.stringify(s)
	var rep2: = V10Save.migrate(s)
	check(JSON.stringify(s) == once and calls[0] == 1 and (rep2.added as Array).is_empty(), "2nd migration changes nothing")
	# a save round-trips through JSON (ints become floats) and ensure() adds nothing
	var back: Dictionary = JSON.parse_string(once)
	check(V10Save.ensure(back).is_empty(), "ensure() after a JSON round trip adds nothing")
	V10Meta.bind(back.v10_meta)
	check(V10Meta.day_key() == "2026-11-25" and V10Meta.clock_ok(), "meta state works after the round trip")
	# a late module adds its key on load without a version bump
	V10Save.register("v10_late", {"x": 0})
	var added: = V10Save.ensure(back)
	check(added == ["v10_late"] and int(back.ver) == 8, "late keys arrive without a new bump")
	# a damaged future date in the 0.9 save never freezes the day
	var s2: = _fixture09()
	s2.daily_day = "2031-01-01"
	V10Save.migrate(s2)
	check(str(s2.v10_meta.last_key) == "2026-11-25", "a damaged date is ignored")
	var s3: = _fixture09()
	s3.erase("login")
	V10Save.migrate(s3)
	check(int(s3.v10_meta.days_seen) == 0 and int(s3.ver) == 8, "a save without login migrates")
	V10Save._defaults.erase("v10_test")
	V10Save._defaults.erase("v10_late")
	V10Save._migrators.clear()
	V10Meta.unbind()


# ── Ф5 victory stack ───────────────────────────────────────────────────────────────────────────────────────────
static func _win() -> void:
	_mod = "winbar"
	V10WinStack.clear()
	var mk: = func(id: String):
		return func(_c, w):
			var c: = Control.new()
			c.name = id
			c.size = Vector2(w, 80)
			return c
	V10WinStack.add_bar("pass", V10WinStack.PRIO_PASS, mk.call("pass"))
	V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, mk.call("salon"), {"modes": ["path"]})
	V10WinStack.add_bar("mastery", V10WinStack.PRIO_MASTERY, mk.call("mastery"))
	V10WinStack.add_bar("extra", 50, mk.call("extra"))
	var ids: = func(arr: Array): return arr.map(func(e): return str(e.id))
	check(ids.call(V10WinStack.pick({"mode": "path"})) == ["salon", "mastery"], "path: salon > mastery, ≤2 bars")
	check(ids.call(V10WinStack.pick({"mode": "blitz"})) == ["mastery", "pass"], "non-path: no salon bar")
	check(ids.call(V10WinStack.pick({"mode": "daily"})).find("salon") < 0, "daily: no salon bar")
	var built: = V10WinStack.build_bars({"mode": "path"}, 600.0)
	check(built.size() == 2, "build_bars → 2 controls")
	for b in built:
		(b as Node).free()
	V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, func(_c, _w): return null, {"modes": ["path"]})
	var b2: = V10WinStack.build_bars({"mode": "path"}, 600.0)
	check(b2.size() == 2 and str(b2[0].name) == "mastery" and str(b2[1].name) == "pass", "an empty salon bar gives its place")
	for b in b2:
		(b as Node).free()
	V10WinStack.add_bar("gated", 999, mk.call("gated"), {"when": func(c): return bool(c.get("first", false))})
	check(ids.call(V10WinStack.pick({"mode": "path"}))[0] == "salon", "when() false → bar skipped")
	check(ids.call(V10WinStack.pick({"mode": "path", "first": true}))[0] == "gated", "when() true → bar shown")
	V10WinStack.add_tick("flame", func(_c): return {"icon": "gift", "text": "Огонёк 2"}, {"order": 1})
	V10WinStack.add_tick("streak", func(_c): return {"icon": "heart", "text": "Серия 4"}, {"order": 0})
	V10WinStack.add_tick("none", func(_c): return {})
	var tk: = V10WinStack.ticks({"mode": "path"})
	check(tk.size() == 2 and tk[0].id == "streak" and tk[1].id == "flame", "ticks: ordered, empty ones skipped")
	# a full panel never shows more than 2 bars
	for i in 6:
		V10WinStack.add_bar("b%d" % i, 150 + i, mk.call("b%d" % i))
	var p: = V10WinPanel.make({"mode": "path", "level": 3, "count": 10, "stars_map": {"0": 3, "1": 3, "2": 3}}, 620.0)
	var nbars: = 0
	for c in p.get_children():
		if c.has_meta("v10_bar_id"):
			nbars += 1
	check(nbars == 2, "the panel shows ≤ 2 bars with 9 registered (%d)" % nbars)
	check(p.more_btn != null and p.more_btn.lbl.text == "Ещё уровень · 5", "panel button «Ещё уровень · 5» (%s)" % (p.more_btn.lbl.text if p.more_btn else "-"))
	check(p.alt_btn != null and p.alt_btn.lbl.text == "Домой", "no salon → small «Домой»")
	p.free()
	var p2: = V10WinPanel.make({"mode": "blitz"}, 620.0)
	check(p2.more_btn == null, "non-path: no «Ещё уровень» row")
	p2.free()
	V10WinStack.clear()


static func _more() -> void:
	_mod = "more"
	var stars: = {"0": 3, "1": 3, "2": 2, "3": 3, "5": 1}
	check(V10MoreLevel.next_index(3, stars, 10, false) == 4, "first win on 3 → 4")
	check(V10MoreLevel.next_index(4, stars.merged({"4": 2}), 10, false) == 6, "passed-out-of-order 5 is skipped → 6")
	check(V10MoreLevel.next_index(1, stars, 10, true) == 2, "replay of an old level → the next in order")
	check(V10MoreLevel.next_index(9, stars, 10, false) == -1, "past the last level → -1")
	check(V10MoreLevel.next_index(8, {"9": 3}, 10, false) == -1, "only passed levels after → -1")
	var st: = V10MoreLevel.state({"level": 56, "count": 100, "stars_map": {}})
	check(st.enabled and st.text == "Ещё уровень · 58" and int(st.next) == 57, "button «Ещё уровень · 58»")
	var st2: = V10MoreLevel.state({"level": 99, "count": 100, "stars_map": {}})
	check(not st2.enabled and st2.text == "Скоро новая арка", "at the limit: «Скоро новая арка» grey")
	V10MoreLevel.label_of = func(i): return "Путь %d" % (i + 1)
	check(V10MoreLevel.state({"level": 0, "count": 5, "stars_map": {}}).text == "Ещё уровень · Путь 2", "label_of hook")
	V10MoreLevel.label_of = Callable()


# ── Ф6 Афиша дня ───────────────────────────────────────────────────────────────────────────────────────────────
static func _afisha() -> void:
	_mod = "afisha"
	V10Meta.bind({})
	V10Afisha.bind({})
	var base: = V10Meta.day_index("2026-11-24")
	var k0: = Time.get_date_string_from_unix_time(base * 86400)
	check(V10Afisha.mode_of_day(k0) == V10Afisha.mode_of_day(k0), "mode of the day is deterministic")
	var worst: = 99
	for s in 60:
		var cnt: = {}
		for d in 35:
			var m: = V10Afisha.mode_of_day(Time.get_date_string_from_unix_time((base + s + d) * 86400))
			cnt[m] = int(cnt.get(m, 0)) + 1
		for m in V10Afisha.MODES:
			worst = mini(worst, int(cnt.get(m, 0)))
	check(worst >= 5, "any 35 days: each of 5 modes ≥5 times (min %d)" % worst)
	var rep: = 0
	for d in 400:
		var a: = V10Afisha.mode_of_day(Time.get_date_string_from_unix_time((base + d) * 86400))
		var b: = V10Afisha.mode_of_day(Time.get_date_string_from_unix_time((base + d + 1) * 86400))
		if a == b:
			rep += 1
	check(rep == 0, "never the same mode two days running (%d repeats in 400 days)" % rep)
	V10Meta.set_now(_lt("2026-11-24T12:00:00"))
	var today: = V10Afisha.mode_of_day()
	var gem_x2: = false
	for m in V10Afisha.MODES:
		if V10Afisha.mult(m, "gems") != 1:
			gem_x2 = true
	check(not gem_x2, "×2 never touches crystals")
	check(V10Afisha.mult(today, "coins") == 2 and V10Afisha.mult(today, "rank") == 2, "today's mode: ×2 coins and rank")
	var other: String = V10Afisha.MODES[(V10Afisha.MODES.find(today) + 1) % 5]
	check(V10Afisha.mult(other, "coins") == 1, "other modes ×1")
	# fresh save: every row is there, closed rows say «откроется …»
	V10Afisha.set_provider("mode_open", func(_id): return false)
	V10Afisha.set_provider("lock_text", func(id): return "Откроется на ранге Бронза II" if id != "" else "")
	var rows: = V10Afisha.rows()
	check(rows.size() == 4, "4 rows (daily, salon, mode ×2, week)")
	var unl: = []
	for r in rows:
		if not bool(r.open) and str(r.lock) == "":
			unl.append(r.id)
	check(unl.is_empty(), "every closed row carries its «откроется …» caption %s" % str(unl))
	var mrow: Dictionary = rows[2]
	check(str(mrow.lock).begins_with("Откроется на ранге"), "the mode row: «Откроется на ранге …»")
	check(bool(rows[0].open) and rows[0].sub == V10Afisha.T_REFRESH, "Партия дня open, «обновится в 04:00»")
	V10Afisha.set_provider("mode_open", Callable())
	V10Afisha.set_provider("lock_text", Callable())
	# real gates from V6ModesData with a fresh 0.9 save (rank 0)
	var keep_rp = G.S.get("rp", 0)
	G.S.rp = 0
	var real: = V10Afisha.rows()
	var lk: = ""
	for r in real:
		if r.id == "mode" and not bool(r.open):
			lk = str(r.lock)
	check(lk == "" or lk.begins_with("Откроется на ранге"), "fresh save: V6ModesData gate caption (%s)" % lk)
	G.S.rp = keep_rp
	# played marks
	check(V10Afisha.on_game_ended({"mode": today}).has("mode") and V10Afisha.played("mode"), "playing the mode of the day marks it")
	check(not V10Afisha.mark("mode"), "a row is marked once")
	check(V10Afisha.on_game_ended({"mode": "daily"}) == ["daily"], "Раскладка marks Партия дня")
	V10Afisha.set_provider("hand", func(): return true)
	check((V10Afisha.rows()[0].tabs as Array).size() == 2, "with Чтение руки the daily row has 2 tabs")
	V10Afisha.set_provider("hand", Callable())
	check(V10Afisha.done_count() == 2, "2 rows played")
	V10Meta.set_now(_lt("2026-11-25T04:00:10"))
	check(V10Afisha.done_count() == 0 and not V10Afisha.played("daily"), "04:00 resets the board")
	V10Afisha.set_provider("salon", func(): return {"open": true, "sub": "Фонари у входа · ★ 12"})
	V10Afisha.set_provider("week", func(): return {"open": true, "title": "Пагода Луны", "sub": "этаж 7"})
	var full: = V10Afisha.rows()
	check(bool(full[1].open) and bool(full[3].open) and full[3].title == "Пагода Луны", "providers open salon and week rows")
	V10Afisha.set_provider("salon", Callable())
	V10Afisha.set_provider("week", Callable())
	V10Afisha.unbind()


# ── Ф7 store fuse (logic; the real shop screen is checked in meta_runner) ──────────────────────────────────────
static func _shop_logic() -> void:
	_mod = "shop"
	V10ShopGuard.force("store")
	check(not V10ShopGuard.can_buy() and not V10ShopGuard.rub_allowed(), "store build: no buying")
	V10ShopGuard.force("test")
	check(V10ShopGuard.can_buy(), "test build: buying stays (with ТЕСТ)")
	V10ShopGuard.unforce()
	check(V10ShopGuard.build() == "test", "an editor/debug run counts as test")
	check(V10ShopGuard.is_rub("79 ₽") and V10ShopGuard.is_rub("1 190 ₽") and V10ShopGuard.is_rub("449 руб."), "₽ captions detected")
	check(not V10ShopGuard.is_rub("1 090 кристаллов") and not V10ShopGuard.is_rub("Рубин"), "non-price captions ignored")
	var root: = Control.new()
	var card: = Control.new()
	card.size = Vector2(200, 300)
	root.add_child(card)
	var b1: = JButton.make("79 ₽", "gold", Rect2(10, 200, 180, 60), null, 24)
	card.add_child(b1)
	var b2: = JButton.make("Купить", "gold", Rect2(10, 10, 180, 60), null, 24)
	root.add_child(b2)
	var b3: = JButton.make("Набор", "gold", Rect2(10, 90, 180, 60), null, 24)
	b3.set_sub("149 ₽")
	root.add_child(b3)
	V10ShopGuard.force("store")
	check(V10ShopGuard.rub_buttons(root).size() == 2, "two ₽ buttons found (caption and sub)")
	check(V10ShopGuard.guard(root) == 2, "store: guard touches 2")
	var vis: = 0
	for b in [b1, b3]:
		if (b as Control).visible:
			vis += 1
	check(vis == 0 and b2.visible and card.visible, "store: ₽ buttons hidden, other buttons and cards stay")
	var soon: = card.get_node_or_null("V10Soon") as JButton
	check(soon != null and soon.disabled and soon.lbl.text == "Скоро" and V10ShopGuard.visible_rub(root).is_empty(),
		"store: a grey «Скоро» stands in place of the ₽ button")
	check(V10ShopGuard.guard(root) == 0, "guard is idempotent")
	root.free()
	var root2: = Control.new()
	var b4: = JButton.make("379 ₽", "gold", Rect2(10, 10, 180, 60), null, 24)
	root2.add_child(b4)
	V10ShopGuard.force("test")
	V10ShopGuard.guard(root2)
	check(b4.visible and b4.get_node_or_null("V10TestPlaque") != null, "test: ₽ button keeps a «ТЕСТ» plaque")
	root2.free()
	V10ShopGuard.unforce()


# ── §2.4–2.5 grep: time and affection have one source each ─────────────────────────────────────────────────────
static func _grep(strict: bool) -> void:
	_mod = "grep"
	var files: = []
	_list("res://scripts", files)
	var time_hits: = []
	var aff_hits: = []
	var own_bad: = []
	for f in files:
		var p: String = f
		if p.ends_with("meta_selftest.gd"):
			continue
		var txt: = FileAccess.get_file_as_string(p)
		var is_meta: = p.find("/v10/meta/") >= 0
		var tcount: = txt.count("Time.get_unix_time_from_system") + txt.count("Time.get_date_string_from_system")
		if tcount > 0 and not p.ends_with("/v10/meta/meta.gd"):
			time_hits.append("%s×%d" % [p.get_file(), tcount])
			if is_meta:
				own_bad.append(p)
		var acount: = txt.count("G.add_aff(")
		if acount > 0 and not p.ends_with("/v10/meta/bond.gd"):
			aff_hits.append("%s×%d" % [p.get_file(), acount])
			if is_meta:
				own_bad.append(p)
	check(own_bad.is_empty(), "lane meta: time only in meta.gd, G.add_aff only in bond.gd %s" % str(own_bad))
	if strict:
		check(time_hits.is_empty(), "strict: no direct time reads outside V10Meta %s" % str(time_hits))
		check(aff_hits.is_empty(), "strict: no G.add_aff outside V10Bond %s" % str(aff_hits))
	else:
		info.append("to integrate (time → V10Meta): %s" % ", ".join(time_hits))
		info.append("to integrate (G.add_aff → V10Bond.gain): %s" % ", ".join(aff_hits))


static func _list(dir: String, out: Array) -> void:
	var d: = DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n: = d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_list(dir + "/" + n, out)
		elif n.ends_with(".gd"):
			out.append(dir + "/" + n)
		n = d.get_next()
	d.list_dir_end()
