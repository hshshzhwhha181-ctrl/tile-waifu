class_name V9Letters
extends RefCounted

# 0.9 «Письма» (docs/0.9-spec.md §C): 1–2 letters a day from the heroines, written after game events.
#
#   V9Letters.install()          once at start (home.build calls it): hooks G.rank_changed and the play screen's
#                                max_combo, checks «давно не заходил» (2+ days since the last visit)
#   V9Letters.tick() -> Array    turns today's events into letters (cap MAX_PER_DAY a day, one letter per event
#                                kind a day); returns the new letters. Home and the letters screen call it.
#   V9Letters.queue(ev, vars)    report an event: "first_win" | "combo" {combo} | "rank" {rank} | "comeback" {days}
#   V9Letters.list()             letters, newest first (Dictionaries: id, h, ev, k, t, read, reply, vars)
#   V9Letters.view(l)            {subj, body, emo, replies, answers, sign, ps} with placeholders filled
#   V9Letters.unread() / needs_reply() / badge_count()   (badge = unread letters + legacy notes)
#   V9Letters.mark_read(id), V9Letters.reply(id, i) -> String (her answer; +REPLY_AFF affection once)
#   Legacy «Письма» of 0.7/0.8 (date notes, «открыта сцена»): legacy_entries(), legacy_unread(), mark_legacy_seen()
# State: G.S.v9_letters (a Dictionary; missing or broken = fresh).

const MAX_PER_DAY: = 2
const KEEP: = 30
const REPLY_AFF: = 5
const COMBO_MIN: = 5
const COMEBACK_DAYS: = 2
# when more events than the daily cap come in, the stronger story wins
const PRIORITY: = {"bday": -2, "ask_bday": -1, "comeback": 0, "while_away": 0, "week": 1, "salon_scene": 1, "rank": 2, "combo": 3, "first_win": 4}
const EVENTS: = ["first_win", "combo", "rank", "comeback"]
const EXTRA_EVENTS: = ["bday", "week", "ask_bday", "while_away", "salon_scene"]
const EV_TAG: = {"first_win": "Первая победа дня", "combo": "Рекорд комбо", "rank": "Новый ранг", "comeback": "С возвращением",
	"bday": "День рождения", "week": "Письмо недели", "ask_bday": "Вопрос от неё", "while_away": "Пока тебя не было", "salon_scene": "Салон"}
const PLAY_SCRIPT: = "res://scripts/screens/play.gd"

static var _installed: = false
static var _rp_frame: = -1


static func st() -> Dictionary:
	var d = G.S.get("v9_letters")
	if not (d is Dictionary):
		d = {}
		G.S["v9_letters"] = d
	if not (d.get("list") is Array):
		d["list"] = []
	if not (d.get("pending") is Array):
		d["pending"] = []
	if not (d.get("evs") is Array):
		d["evs"] = []
	if not (d.get("lastk") is Dictionary):
		d["lastk"] = {}
	for k in ["seq", "n", "wins0", "best_combo"]:
		d[k] = int(d.get(k, 0))
	for k in ["day", "wins_day", "last_day", "win_day"]:
		d[k] = str(d.get(k, ""))
	return d


# ------------------------------------------------------------------ hooks

static func install() -> void:
	var s: = st()
	_roll_day(s)
	if not _installed:
		_installed = true
		if not G.rank_changed.is_connected(_on_rank):
			G.rank_changed.connect(_on_rank)
		if not G.rp_changed.is_connected(_on_rp):
			G.rp_changed.connect(_on_rp)
		var tree: = Engine.get_main_loop() as SceneTree
		if tree and not tree.node_added.is_connected(_on_node):
			tree.node_added.connect(_on_node)
		check_comeback()
		if "--letters_demo=1" in OS.get_cmdline_user_args():
			demo()
	s.last_day = G.today()


# «давно не заходил»: 2+ days since the last visit (a 0.8 save only has Sfx's v8_last_day) -> a comeback letter
static func check_comeback() -> int:
	var s: = st()
	var last: String = s.last_day
	if last == "":
		last = str(G.S.get("v8_last_day", ""))
	var gap: = G.days_between(last, G.today()) if last != "" else 0
	if gap >= COMEBACK_DAYS and gap < 9999:
		queue("comeback", {"days": gap})
		return gap
	return 0


# a rank up is news only when points were just earned (G.add_rp emits rp_changed, then rank_changed in the same
# frame); a restored save (V8Recovery.import_code) emits rank_changed alone and writes no letter
static func _on_rp(_old: int, _new: int) -> void:
	_rp_frame = Engine.get_process_frames()


static func _on_rank(before: int, after: int) -> void:
	if after > before and _rp_frame == Engine.get_process_frames():
		queue("rank", {"rank": G.rank_of(int(G.S.get("rp", 0))).title})


static func _on_node(n: Node) -> void:
	if not (n is Control):
		return
	var sc = n.get_script()
	if sc is Script and _is_play(sc) and not n.has_meta("v9_letters"):
		n.set_meta("v9_letters", true)
		n.tree_exiting.connect(_on_play_exit.bind(n), CONNECT_ONE_SHOT)


# play.gd itself or any screen built on it (arena mode_play, event / tourney event_play)
static func _is_play(sc: Script) -> bool:
	var k: = 0
	while sc != null and k < 8:
		if sc.resource_path == PLAY_SCRIPT:
			return true
		sc = sc.get_base_script()
		k += 1
	return false


# G.record_game calls this on a win: the day of the win is stored where it happens, so a match that ends past
# midnight (or any win before the first home visit of the day) still makes «Первая победа дня»
static func note_win() -> void:
	st().win_day = G.today()


static func _on_play_exit(n: Node) -> void:
	if not is_instance_valid(n) or G.demo:
		return
	note_combo(int(n.get("max_combo") if n.get("max_combo") != null else 0))


# a finished match reports its best combo: a new personal record (from COMBO_MIN) becomes a letter
static func note_combo(c: int) -> bool:
	var s: = st()
	if c <= s.best_combo:
		return false
	s.best_combo = c
	if c >= COMBO_MIN:
		queue("combo", {"combo": c})
		return true
	return false


static func total_wins() -> int:
	var n: = 0
	var stats = G.S.get("stats", {})
	if stats is Dictionary:
		for k in stats:
			if stats[k] is Dictionary:
				n += int(stats[k].get("wins", 0))
	return n


static func queue(ev: String, vars: = {}) -> void:
	if not (ev in EVENTS or ev in EXTRA_EVENTS):
		push_warning("V9Letters.queue: unknown event '%s'" % ev)
		return
	var s: = st()
	for p in s.pending:
		if p is Dictionary and str(p.get("ev", "")) == ev and str(p.get("day", "")) == G.today():
			# the same event again today: keep the bigger news (a higher combo, the newest rank)
			if ev != "combo" or int(vars.get("combo", 0)) > int(p.get("vars", {}).get("combo", 0)):
				p["vars"] = vars.duplicate()
			return
	s.pending.append({"ev": ev, "day": G.today(), "vars": vars.duplicate()})


static func _roll_day(s: Dictionary) -> void:
	var today: = G.today()
	if s.day != today:
		s.day = today
		s.n = 0
		s.evs = []
	if s.wins_day != today:
		s.wins_day = today
		s.wins0 = total_wins()


# ------------------------------------------------------------------ generator

static func tick() -> Array:
	var s: = st()
	_roll_day(s)
	s.last_day = G.today()
	if (total_wins() > s.wins0 or s.win_day == G.today()) and not "first_win" in s.evs:
		queue("first_win")
	var today: = G.today()
	var todo: Array = s.pending.filter(func(p): return p is Dictionary and str(p.get("day", "")) == today and not str(p.get("ev", "")) in s.evs)
	todo.sort_custom(func(a, b): return int(PRIORITY.get(a.ev, 9)) < int(PRIORITY.get(b.ev, 9)))
	var made: = []
	for p in todo:
		if s.n >= MAX_PER_DAY:
			break
		var l: = _make(str(p.ev), p.get("vars", {}))
		if not l.is_empty():
			made.append(l)
	# everything not written today is dropped: a letter is news, not a backlog
	s.pending = []
	return made


static func _pick_hero(s: Dictionary) -> String:
	var partner: = str(G.S.get("partner", "mc"))
	var wrote: = {}
	for l in s.list:
		if l is Dictionary and str(l.get("day", "")) == G.today():
			wrote[str(l.h)] = true
	if not wrote.has(partner) and V9LetterText.LETTERS.has(partner):
		return partner
	var pool: = []
	for h in G.HERO_ORDER:
		if h != partner and G.hero_unlocked(h) and not wrote.has(h):
			pool.append(h)
	if pool.is_empty():
		return partner if V9LetterText.LETTERS.has(partner) else "mc"
	return pool[randi() % pool.size()]


static func _make(ev: String, vars: Dictionary, h: = "") -> Dictionary:
	var s: = st()
	if h == "" and vars.has("hero"):
		h = str(vars.hero)
	if h == "":
		h = _pick_hero(s)
	if ev in ["salon_scene", "ask_bday"]:
		return _make_custom(ev, vars, h)
	var vs: = V9LetterText.variants(h, ev)
	if vs.is_empty():
		return {}
	var key: = h + ":" + ev
	var k: = randi() % vs.size()
	if vs.size() > 1 and int(s.lastk.get(key, -1)) == k:
		k = (k + 1) % vs.size()
	s.lastk[key] = k
	s.seq += 1
	var l: = {"id": s.seq, "h": h, "ev": ev, "k": k, "t": V10Meta.now_unix(), "day": G.today(),
		"read": false, "reply": -1, "vars": vars.duplicate()}
	s.list.push_front(l)
	while s.list.size() > KEEP:
		s.list.pop_back()
	s.n += 1
	s.evs.append(ev)
	return l


static func _make_custom(ev: String, _vars: Dictionary, h: String) -> Dictionary:
	var s: = st()
	s.seq += 1
	var custom: Dictionary
	if ev == "ask_bday":
		custom = {
			"subj": "Когда у тебя праздник?", "emo": "shy",
			"body": V10RitLines.pick("ask_bday", h, 0),
			"replies": ["Рассказать", "Не хочу говорить"],
			"answers": ["Записала! В этот день чайная будет особенно тёплой.", "Хорошо, тогда просто будем праздновать каждый хороший вечер."],
			"sign": V9LetterText.SIGN.get(h, V10RitBridge.short_name(h)), "ps": "", "tag": EV_TAG.ask_bday,
		}
	else:
		custom = {
			"subj": "Спасибо за вечер в салоне", "emo": "happy",
			"body": "Вчерашний вечер в обновлённом зале до сих пор греет. Я оставила для тебя твоё любимое место у лампы — заходи в любое время.",
			"replies": ["Обязательно загляну сегодня.", "Мне там тоже очень уютно."],
			"answers": ["Тогда ставлю чайник заранее~", "Значит, мы всё сделали не зря."],
			"sign": V9LetterText.SIGN.get(h, V10RitBridge.short_name(h)), "ps": V9LetterText.PS.get(h, ""), "tag": EV_TAG.salon_scene,
		}
	var l: = {"id": s.seq, "h": h, "ev": ev, "k": 0, "t": V10Meta.now_unix(), "day": G.today(),
		"read": false, "reply": -1, "vars": {}, "custom": custom}
	s.list.push_front(l)
	while s.list.size() > KEEP:
		s.list.pop_back()
	s.n += 1
	s.evs.append(ev)
	return l


# 0.10 W2 (rituals H5): deliver pre-composed ritual letters (bday, week, while_away) idempotently once per day.
static func push_ritual(d: Dictionary) -> Dictionary:
	var s: = st()
	var ev: = str(d.get("ev", d.get("kind", "week")))
	var h: = str(d.get("h", d.get("hero", G.S.get("partner", "mc"))))
	if not G.HEROES.has(h):
		h = "mc"
	var today: = G.today()
	for old in s.list:
		if old is Dictionary and str(old.get("day", "")) == today and str(old.get("ev", "")) == ev and str(old.get("h", "")) == h:
			return {}
	var body_txt: = str(d.get("body", ""))
	if body_txt == "" and d.has("open"):
		var lines: = [str(d.get("open", ""))]
		for f in d.get("facts", []):
			lines.append("• " + str(f))
		if str(d.get("close", "")) != "":
			lines.append(str(d.get("close", "")))
		body_txt = "\n".join(lines)
	var custom: = {
		"subj": str(d.get("subj", EV_TAG.get(ev, "Письмо"))),
		"body": body_txt, "emo": str(d.get("emo", "happy")),
		"replies": d.get("replies", ["Спасибо за письмо!", "Скоро загляну за стол."]),
		"answers": d.get("answers", ["Всегда рада написать тебе~", "Чай уже ждёт!"]),
		"sign": str(d.get("sign", V9LetterText.SIGN.get(h, G.HEROES[h].name))),
		"ps": str(d.get("ps", "")), "tag": str(EV_TAG.get(ev, "Письмо")),
	}
	if ev == "week" and d.has("open"):
		custom["week_doc"] = d.duplicate(true)
	s.seq += 1
	var l: = {"id": s.seq, "h": h, "ev": ev, "k": 0, "t": V10Meta.now_unix(), "day": today,
		"read": false, "reply": -1, "vars": {}, "custom": custom}
	s.list.push_front(l)
	while s.list.size() > KEEP:
		s.list.pop_back()
	return l


# dev (--letters_demo=1): one letter of every kind from different heroines, for screenshots
static func demo() -> void:
	var s: = st()
	if s.list.size() >= 4:
		return
	var hs: = ["nova", "rin", "hana", "mc"]
	var evs: = ["comeback", "combo", "rank", "first_win"]
	var vars: = [{"days": 3}, {"combo": 9}, {"rank": "Нефрит II"}, {}]
	for i in 4:
		var l: = _make(evs[i], vars[i], hs[i])
		if not l.is_empty():
			l.t -= (4 - i) * 5400
	s.n = 0
	s.evs = []


# ------------------------------------------------------------------ reading

static func list() -> Array:
	return st().list.filter(func(l): return l is Dictionary and (l.has("custom") or V9LetterText.LETTERS.has(str(l.get("h", "")))))


static func find(id: int) -> Dictionary:
	for l in list():
		if int(l.id) == id:
			return l
	return {}


static func view(l: Dictionary) -> Dictionary:
	if l.get("custom") is Dictionary:
		return (l.custom as Dictionary).duplicate(true)
	var vs: = V9LetterText.variants(str(l.get("h", "mc")), str(l.get("ev", "")))
	if vs.is_empty():
		return {}
	var v: Dictionary = vs[clampi(int(l.get("k", 0)), 0, vs.size() - 1)]
	var vars: Dictionary = l.get("vars", {}) if l.get("vars") is Dictionary else {}
	var h: = str(l.h)
	return {
		"subj": V9LetterText.fill(v.subj, vars), "body": V9LetterText.fill(v.body, vars), "emo": str(v.get("emo", "happy")),
		"replies": (v.replies as Array).map(func(x): return V9LetterText.fill(x, vars)),
		"answers": (v.answers as Array).map(func(x): return V9LetterText.fill(x, vars)),
		"sign": V9LetterText.SIGN.get(h, ""), "ps": V9LetterText.PS.get(h, ""), "tag": EV_TAG.get(str(l.ev), ""),
	}


static func unread() -> int:
	return list().filter(func(l): return not bool(l.get("read", false))).size()


static func needs_reply() -> int:
	return list().filter(func(l): return int(l.get("reply", -1)) < 0).size()


static func mark_read(id: int) -> void:
	var l: = find(id)
	if not l.is_empty():
		l["read"] = true


# the player's answer: her reply line; affection only for the first answer to a letter
static func reply(id: int, i: int) -> String:
	var l: = find(id)
	if l.is_empty():
		return ""
	var v: = view(l)
	i = clampi(i, 0, 1)
	if int(l.get("reply", -1)) < 0:
		l["reply"] = i
		l["read"] = true
		V10Bond.gain(str(l.h), REPLY_AFF, "letter_reply")
		G.save()
	return str(v.answers[int(l.reply)])


static func badge_count() -> int:
	return unread() + legacy_unread()


static func ago(t: int) -> String:
	if t <= 0:
		return ""
	var d: = V10Meta.now_unix() - t
	if d < 3600:
		return "только что"
	if d < 86400:
		return "%d ч назад" % (d / 3600)
	return "%d д назад" % (d / 86400)


# ------------------------------------------------------------------ legacy notes (0.7 dates mail + scene notices)

static func _notice_seen() -> Dictionary:
	var d = G.S.get("v8_mail_seen")
	if not (d is Dictionary):
		d = {}
		G.S["v8_mail_seen"] = d
	return d


static func legacy_entries() -> Array:
	var out: Array = []
	for h in G.HERO_ORDER:
		if not G.hero_unlocked(h):
			continue
		for id in V7RoomData.fresh_scenes(h):
			out.append({"h": h, "text": "Открыта сцена «%s». Загляни ко мне в комнату." % V7RoomScenes.SCENES[id].title,
				"sub": "Комната", "new": not _notice_seen().has(str(id))})
	var mail: Array = V7RoomData.mail()
	for i in range(mail.size() - 1, -1, -1):
		var e = mail[i]
		if e is Dictionary and G.HEROES.has(str(e.get("h", ""))):
			out.append({"h": str(e.h), "text": "«%s»" % str(e.text), "sub": ago(int(e.get("t", 0))), "new": not bool(e.get("read", false))})
	return out.slice(0, 8)


static func legacy_unread() -> int:
	var n: = V7RoomData.unread_mail()
	var seen: = _notice_seen()
	for h in G.HERO_ORDER:
		if G.hero_unlocked(h):
			for id in V7RoomData.fresh_scenes(h):
				if not seen.has(str(id)):
					n += 1
	return n


static func mark_legacy_seen() -> void:
	V7RoomData.mark_mail_read()
	var seen: = _notice_seen()
	for h in G.HERO_ORDER:
		if G.hero_unlocked(h):
			for id in V7RoomData.fresh_scenes(h):
				seen[str(id)] = true
