class_name V9LettersSelftest
extends RefCounted

# --letters_selftest=1 (dispatched by home.build): letters + live-heroine rules, headless.
#   texts: every heroine × event has variants with subject, body, valid emotion, 2 replies + 2 answers, placeholders
#   resolve, no red-line words; touch lines: every zone, voiced lines resolve to existing mp3s; plural days;
#   generator: first win, combo record, rank, comeback, daily cap, one letter per kind a day, day rollover,
#   reply affection once; zones: head / hand / outfit / body / room on every rig, the video and a painting;
#   tap rules: line cooldown, affection gap and the daily cap of 3, spam.
# Works on a copy of the save (G.S restored, nothing written: G.demo is set while it runs).

const BANNED: = ["учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр",
	"вино", "пиво", "алкогол", "раздев", "бельё", "белье"]

static var ok: = 0
static var bad: = 0


static func check(cond: bool, what: String) -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		printerr("LETTERS FAIL: " + what)


static func _clean(t: String, where: String) -> void:
	var lo: = t.to_lower()
	for w in BANNED:
		check(not lo.contains(w), "%s: red-line word «%s»" % [where, w])


static func run(main) -> void:
	var tree: = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	ok = 0
	bad = 0
	var saved: Dictionary = G.S
	var demo_was: bool = G.demo
	G.S = G.S.duplicate(true)
	G.demo = true
	_texts()
	_touch_lines()
	_generator()
	_midnight()
	_zones()
	_taps()
	G.S = saved
	G.demo = demo_was
	printerr("LETTERS SELFTEST %d/%d" % [ok, ok + bad])
	tree.quit(1 if bad > 0 else 0)


static func _texts() -> void:
	check(V9LetterText.days_word(1) == "1 день", "days 1")
	check(V9LetterText.days_word(3) == "3 дня", "days 3")
	check(V9LetterText.days_word(5) == "5 дней", "days 5")
	check(V9LetterText.days_word(11) == "11 дней", "days 11")
	check(V9LetterText.days_word(21) == "21 день", "days 21")
	check(V9LetterText.days_word(22) == "22 дня", "days 22")
	check(V9LetterText.days_word(112) == "112 дней", "days 112")
	var vars: = {"combo": 9, "rank": "Нефрит II", "days": 3}
	for h in G.HERO_ORDER:
		check(V9LetterText.SIGN.has(h) and V9LetterText.PS.has(h), "%s sign / ps" % h)
		for ev in V9Letters.EVENTS:
			var vs: = V9LetterText.variants(h, ev)
			check(vs.size() >= 2, "%s %s: 2+ variants" % [h, ev])
			for k in vs.size():
				var v: Dictionary = vs[k]
				var where: = "%s %s #%d" % [h, ev, k]
				check(str(v.get("subj", "")) != "" and str(v.get("body", "")).length() > 60, where + " subject / body")
				check(str(v.get("emo", "")) in V8Art.EMOTIONS, where + " emotion")
				check(V8Art.has_emotion(h, str(v.get("emo", ""))), where + " emotion art")
				check(v.get("replies", []).size() == 2 and v.get("answers", []).size() == 2, where + " 2 replies + 2 answers")
				var all: = str(v.subj) + " " + str(v.body) + " " + " ".join(v.replies) + " " + " ".join(v.answers)
				var filled: = V9LetterText.fill(all, vars)
				check(not filled.contains("{") and not filled.contains("}"), where + " placeholders resolve")
				_clean(all, where)
				for r in v.replies:
					check(UI.font("body", 900).get_string_size(str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x < 560.0, where + " reply fits its button: " + str(r))
				for a in v.answers:
					var ah: = UI.font("body", 800).get_multiline_string_size(str(a), HORIZONTAL_ALIGNMENT_LEFT, 456, 20, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
					check(ah <= 88.0, where + " answer fits its bubble (%d px): %s" % [int(ah), str(a)])
				check(UI.font("title", 800).get_string_size(V9LetterText.fill(str(v.subj), vars), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x < 500.0, where + " subject fits a card")


static func _touch_lines() -> void:
	for h in G.HERO_ORDER:
		for z in ["head", "hand", "outfit", "bg", "spam", "idle"]:
			var p: = V9TouchLines.pool(h, z)
			check(p.size() >= 2, "%s %s: 2+ lines" % [h, z])
			for i in p.size():
				var e: = V9TouchLines.entry(h, z, i)
				var where: = "%s %s #%d" % [h, z, i]
				check(not e.is_empty() and str(e.text) != "", where + " resolves")
				if e.is_empty():
					continue
				check(str(e.emo) in V8Art.EMOTIONS and V8Art.has_emotion(h, str(e.emo)), where + " emotion")
				if (p[i] as Dictionary).has("v"):
					check(str(e.voice) != "" and ResourceLoader.exists(str(e.voice)), where + " voice file")
				check(str(e.text).length() <= 64, where + " short enough for the bubble")
				_clean(str(e.text), where)


static func _date(days_ago: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - days_ago * 86400)


# home on day D, the match ends after midnight: the win is recorded before the first tick of D+1 (whose rollover
# snapshots wins0 with that win already counted) — the stored win day still makes «Первая победа дня»
static func _midnight() -> void:
	G.S.erase("v9_letters")
	G.S.stats = {}
	var s: = V9Letters.st()
	s.day = _date(1)
	s.wins_day = _date(1)
	s.last_day = _date(1)
	G.record_game("path", true)
	var made: = V9Letters.tick()
	check(made.size() == 1 and str(made[0].ev) == "first_win", "a win past midnight still makes the first-win letter")
	check(V9Letters._is_play(load("res://scripts/v06/modes/mode_play.gd")) and V9Letters._is_play(load("res://scripts/v07/event/event_play.gd")), "arena and event matches report their combo")


static func _generator() -> void:
	G.S.erase("v9_letters")
	G.S.stats = {}
	G.S.partner = "mc"
	var s: = V9Letters.st()
	check(V9Letters.tick().is_empty(), "nothing happened -> no letter")
	# first win of the day
	G.record_game("path", true)
	var made: = V9Letters.tick()
	check(made.size() == 1 and str(made[0].ev) == "first_win" and str(made[0].h) == "mc", "first win -> a letter from the partner")
	check(V9Letters.tick().is_empty(), "first win: once a day")
	G.record_game("path", true)
	check(V9Letters.tick().is_empty(), "second win: no second first-win letter")
	# combo record
	check(not V9Letters.note_combo(3), "combo 3 is below the record threshold")
	check(V9Letters.note_combo(7), "combo 7 is a record")
	check(not V9Letters.note_combo(6), "combo 6 is not a record any more")
	made = V9Letters.tick()
	check(made.size() == 1 and str(made[0].ev) == "combo" and int(made[0].vars.combo) == 7, "combo record letter")
	check(made.size() == 1 and str(made[0].h) != "mc" or not _others_unlocked(), "the second letter of the day comes from another heroine")
	# daily cap
	V9Letters.queue("rank", {"rank": "Нефрит II"})
	check(V9Letters.tick().is_empty(), "daily cap of %d" % V9Letters.MAX_PER_DAY)
	check(s.pending.is_empty(), "events over the cap are dropped")
	# next day (rollover): rank + comeback, comeback first
	s.day = _date(1)
	s.wins_day = _date(1)
	s.win_day = _date(1)
	s.last_day = _date(3)
	check(V9Letters.check_comeback() == 3, "3 days away -> comeback")
	V9Letters.queue("rank", {"rank": "Нефрит II"})
	V9Letters.queue("combo", {"combo": 8})
	made = V9Letters.tick()
	check(made.size() == 2, "a new day: two more letters (%d)" % made.size())
	if made.size() == 2:
		check(str(made[0].ev) == "comeback" and str(made[1].ev) == "rank", "priority: comeback, rank before combo")
		var v: = V9Letters.view(made[0])
		check(str(v.body).contains("3 дня"), "comeback names the days")
		v = V9Letters.view(made[1])
		check(str(v.subj).contains("Нефрит II") or str(v.body).contains("Нефрит II"), "rank letter names the rank")
	s.last_day = _date(1)
	check(V9Letters.check_comeback() == 0, "1 day away is not a comeback")
	# reading + reply
	check(V9Letters.unread() == V9Letters.list().size(), "all unread")
	var l: Dictionary = V9Letters.list()[0]
	V9Letters.mark_read(int(l.id))
	check(V9Letters.unread() == V9Letters.list().size() - 1, "mark read")
	var h: = str(l.h)
	var a0: = int(G.S.aff.get(h, 0))
	var ans: = V9Letters.reply(int(l.id), 1)
	check(ans != "" and ans == str(V9Letters.view(l).answers[1]), "reply returns her answer")
	check(int(G.S.aff.get(h, 0)) == a0 + V9Letters.REPLY_AFF, "reply: +%d affection" % V9Letters.REPLY_AFF)
	V9Letters.reply(int(l.id), 0)
	check(int(G.S.aff.get(h, 0)) == a0 + V9Letters.REPLY_AFF and int(l.reply) == 1, "a letter is answered once")
	# rank up: only from points just earned, never from a restored save
	s.pending = []
	G.rank_changed.emit(0, 6)
	check(s.pending.is_empty(), "a restored save's rank change writes no letter")
	G.S.rp = 0
	G.add_rp(int(G.RANKS[0].per) + 5, "path")
	check(s.pending.any(func(p): return str(p.ev) == "rank"), "rank up from earned points -> rank letter queued")
	s.pending = []
	# storage bound
	for i in 40:
		V9Letters._make("first_win", {}, "rin")
	check(V9Letters.list().size() == V9Letters.KEEP, "keeps the newest %d" % V9Letters.KEEP)
	# a broken save part does not crash
	G.S["v9_letters"] = "junk"
	check(V9Letters.list().is_empty() and V9Letters.tick() is Array, "broken state -> fresh")


static func _others_unlocked() -> bool:
	for h in G.HERO_ORDER:
		if h != "mc" and G.hero_unlocked(h):
			return true
	return false


static func _zones() -> void:
	for h in G.HERO_ORDER:
		var g: = V9Touch.rig_geom(h)
		check(V9Touch.classify(g, g.head) == "head", "%s rig: head" % h)
		check(V9Touch.classify(g, g.hand) == "hand", "%s rig: hand" % h)
		var by: Vector2 = g.band_y
		var bd: Vector2 = g.band_dx
		check(V9Touch.classify(g, Vector2(float(g.cx) - (bd.x + bd.y) * 0.5, (by.x + by.y) * 0.5)) in ["outfit", "hand"], "%s rig: outfit band" % h)
		var rig: Dictionary = Hero.RIGS[h]
		check(V9Touch.classify(g, rig.chest_c) == "body", "%s rig: the chest is not a zone" % h)
		check(V9Touch.classify(g, Vector2(float(rig.feet.x), float(rig.waist_y) + 120.0)) == "body", "%s rig: hips are not a zone" % h)
		check(V9Touch.classify(g, Vector2(float(rig.feet.x), float(rig.feet.y) - 200.0)) == "body", "%s rig: legs are not a zone" % h)
		check(V9Touch.classify(g, Vector2(-300, 600)) == "bg", "%s rig: the room" % h)
		# 0.9 fix: the chest sides and the hips never react, whatever hand / band circle is near
		var cc: Vector2 = rig.chest_c
		var crx: float = (rig.chest_r as Vector2).x
		var sides_ok: = true
		for p in [cc, cc + Vector2(crx * 0.6, 0), cc - Vector2(crx * 0.6, 0), Vector2(cc.x, float(rig.waist_y) + 60.0)]:
			if V9Touch.classify(g, p) != "body":
				sides_ok = false
		check(sides_ok, "%s rig: chest sides and hips are body" % h)
	var vg: = V9Touch.video_geom()
	check(V9Touch.classify(vg, Vector2(373, 316)) == "head", "video: head")
	check(V9Touch.classify(vg, Vector2(505, 398)) == "hand", "video: hand (the tile)")
	check(V9Touch.classify(vg, Vector2(268, 480)) == "outfit", "video: sleeve")
	check(V9Touch.classify(vg, Vector2(378, 520)) == "body", "video: chest is not a zone")
	check(V9Touch.classify(vg, Vector2(640, 800)) == "bg", "video: room")
	var ag: = V9Touch.art_geom(Rect2(300, 100, 260, 260))
	check(V9Touch.classify(ag, ag.head) == "head", "painting: head")
	check(V9Touch.classify(ag, Vector2(430, 500)) == "body", "painting: the middle of the torso is not a zone")
	check(V9Touch.classify(ag, Vector2(430 - 170, 450)) == "outfit", "painting: shoulder / sleeve")
	check(not ag.has("hand"), "painting: no hand zone")
	# every outfit painting: the chest and the hips / thighs below the shoulder band are «body», never «outfit»
	var bad: = []
	for key in V9Ults.RECTS:
		var fr: Rect2 = V9Ults.RECTS[key][0]
		var pg: = V9Touch.art_geom(fr, key)
		var sq: = fr.size.x
		var cx: float = pg.cx
		for p in [Vector2(cx, fr.end.y + sq * 0.4), Vector2(cx - sq * 0.3, fr.end.y + sq * 0.4), Vector2(cx + sq * 0.3, fr.end.y + sq * 0.4),
				Vector2(cx, fr.end.y + sq * 1.6), Vector2(cx - sq * 0.5, fr.end.y + sq * 1.6), Vector2(cx + sq * 0.5, fr.end.y + sq * 1.6)]:
			if V9Touch.classify(pg, p) != "body":
				bad.append(key)
				break
	check(bad.is_empty(), "paintings: chest and hips are body (%s)" % ", ".join(bad))


static func _taps() -> void:
	G.S.pet = {"day": G.today(), "n": 0}
	G.S.partner = "rin"
	var t: = V9Touch.new()
	var d: = t.decide("head", 10.0)
	check(d.kind == "react" and d.line and d.aff and int(d.i) >= 0, "first head tap: line + affection")
	V9Touch.commit_aff("rin")
	d = t.decide("hand", 10.5)
	check(d.kind == "react" and not d.line and not d.aff, "0.5 s later: no new line, no affection")
	d = t.decide("outfit", 12.0)
	check(d.aff and not d.line, "after the gap: affection again, line still cooling down")
	V9Touch.commit_aff("rin")
	d = t.decide("hand", 13.5)
	check(d.line and d.aff, "after %.1f s: a new line" % V9Touch.TALK_CD)
	V9Touch.commit_aff("rin")
	check(G.pet_left() == 0, "3 touches a day")
	var a: = int(G.S.aff.rin)
	V9Touch.commit_aff("rin")
	check(int(G.S.aff.rin) == a, "no affection past the daily cap")
	d = t.decide("head", 30.0)
	check(not d.aff, "cap reached: no affection flag")
	var t2: = V9Touch.new()
	d = t2.decide("bg", 1.0)
	check(d.kind == "react" and d.line and not d.aff, "the room: a line, never affection")
	d = t2.decide("body", 1.2)
	check(d.kind == "quiet", "body: quiet bounce only")
	# 0.9: repeated pokes on «body» never add up to the spam reaction (no flinch, pout or line)
	var tb: = V9Touch.new()
	var body_quiet: = true
	for i in 10:
		body_quiet = body_quiet and tb.decide("body", 80.0 + i * 0.25).kind == "quiet"
	check(body_quiet, "10 body taps in 3 s: all quiet, no spam line")
	var t3: = V9Touch.new()
	var spam: = false
	for i in V9Touch.SPAM_N:
		d = t3.decide("head", 50.0 + i * 0.3)
		spam = spam or d.kind == "spam"
	check(spam, "%d quick taps -> spam reaction" % V9Touch.SPAM_N)
	d = t3.decide("head", 51.8)
	check(d.kind == "quiet", "after spam: quiet for %.0f s" % V9Touch.SPAM_CD)
	d = t3.decide("head", 50.0 + 1.2 + V9Touch.SPAM_CD + 0.5)
	check(d.kind == "react", "spam cooldown ends")
