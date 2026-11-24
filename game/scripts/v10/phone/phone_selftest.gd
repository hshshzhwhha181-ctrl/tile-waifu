class_name V10PhoneSelftest
extends RefCounted

# --phone_selftest=1 (docs/0.10-spec.md §Р8 «Самотест» + §Р9 feed checks), UI half of the phone; the chat logic has
# its own CHAT SELFTEST (v10/chat). run(host) needs a node in the tree (bubble timing, UI smoke).
# Returns [ok, total]; prints every failure.

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")
const NAMES: = preload("res://scripts/v10/phone/names.gd")
const C: = preload("res://scripts/v10/chat/chat.gd")
const D: = preload("res://scripts/v10/chat/chat_data.gd")
const FEED: = preload("res://scripts/v10/chat/chat_feed.gd")
const L: = preload("res://scripts/v10/chat/chat_log.gd")
const V: = preload("res://scripts/v10/chat/chat_validate.gd")
const BUB: = preload("res://scripts/v10/phone/bubble.gd")

const DIR: = "res://scripts/v10/phone/"

static var ok: = 0
static var total: = 0


static func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		print("PHONE FAIL: ", what)


static func _ctx(day: int, levels: = 3, nm: = "", g: = "m") -> Dictionary:
	var lv: = {}
	for h in D.HEROES:
		lv[h] = levels
	var r: = NAMES.record(nm, g)
	return {"day": day, "md": "03-03", "partner": "mc", "owned": D.HEROES.duplicate(), "levels": lv,
		"name": r.nom, "name_voc": r.voc, "gender": r.g}


static func run(host: Node) -> Array:
	ok = 0
	total = 0
	_names()
	_data()
	_rhythm()
	_format()
	_typing()
	_history()
	_bond()
	_feed()
	_stickers()
	_grep()
	_lint()
	await _ui(host)
	return [ok, total]


static func _names() -> void:
	check(NAMES.count() == 120, "120 names (got %d)" % NAMES.count())
	var seen: = {}
	var bad: = 0
	for r in NAMES.NAMES:
		if str(r[1]) == "" or not str(r[2]) in ["m", "f"] or seen.has(r[0]):
			bad += 1
		seen[r[0]] = true
	check(bad == 0, "every name has a vocative, a gender and is unique (%d bad)" % bad)
	check(NAMES.voc("Саша") == "Саш" and NAMES.voc("Аня") == "Ань" and NAMES.voc("Александр") == "Александр", "vocative forms")
	check(NAMES.record("").nom == "" and NAMES.by_gender("f").size() + NAMES.by_gender("m").size() == 120, "«Не называть» record + gender split")


static func _data() -> void:
	var errs: Array = V.run()
	check(errs.is_empty(), "chat data valid (%d errors: %s)" % [errs.size(), str(errs.slice(0, 3))])
	var dead: = 0
	for t in D.all_threads():
		for k in t.nodes:
			var n: Dictionary = t.nodes[k]
			if n.has("choices"):
				if n.choices.size() < 2 or n.choices.size() > 3:
					dead += 1
				for ch in n.choices:
					if not t.nodes.has(str(ch.next)):
						dead += 1
			elif n.has("next") and not t.nodes.has(str(n.next)):
				dead += 1
			elif not n.has("next") and not n.has("end") and not n.has("choices"):
				dead += 1
	check(dead == 0, "threads: next exists, no dead ends, 2–3 pills (%d issues)" % dead)


static func _rhythm() -> void:
	var st: = C.default_state()
	var worst_daily: = 0
	var worst_new: = 0
	for day in range(100, 130):
		var ctx: = _ctx(day, 7)
		var opened: Array = C.tick(st, ctx)
		var daily: = 0
		for tid in opened:
			if str(D.thread(tid).get("trigger", "")) == "daily":
				daily += 1
		worst_daily = maxi(worst_daily, daily)
		worst_new = maxi(worst_new, opened.size())
		# the player answers everything the same day
		for tid in C.open_threads(st):
			var g: = 0
			while C.awaiting(st, tid) and g < 20:
				g += 1
				C.choose(st, tid, 0, ctx)
	check(worst_daily <= 1, "≤1 daily thread a day (worst %d)" % worst_daily)
	check(worst_new <= C.MAX_NEW_PER_DAY, "≤%d new threads a day (worst %d)" % [C.MAX_NEW_PER_DAY, worst_new])


static func _format() -> void:
	var c1: = _ctx(1, 3, "Саша")
	check(C.format("{name_voc}, привет!", {}, c1) == "Саш, привет!", "{name_voc} → «Саш»")
	check(C.format("Привет, {name}", {}, c1) == "Привет, Саша", "{name} → «Саша»")
	var c0: = _ctx(1, 3, "")
	check(C.format("{name_voc}, привет!", {}, c0) == "Мастер стола, привет!", "no name → «Мастер стола»")
	var cf: = _ctx(1, 3, "Аня")
	check(C.format("ты {g:пришёл|пришла}", {}, cf) == "ты пришла", "{g:} follows a female name")
	check(C.format("ты {g:пришёл|пришла}", {}, c1) == "ты пришёл", "{g:} follows a male name")


static func _typing() -> void:
	var lo: = 99999
	var hi: = 0
	for n in range(0, 300, 7):
		var ms: = C.typing_ms("а".repeat(n))
		lo = mini(lo, ms)
		hi = maxi(hi, ms)
	check(lo >= 400 and hi <= 2200 and lo == 400 and hi == 2200, "«печатает» 0.4–2.2 s (%d…%d)" % [lo, hi])


static func _history() -> void:
	var log: = []
	for i in 100:
		log = L.append(log, [{"who": "h", "k": "text", "t": str(i)}])
	check(log.size() == 60 and str(log[0].t) == "40", "history trimmed to the newest 60")


static func _bond() -> void:
	var calls: = []
	P.bond_sink = func(h, n, src):
		calls.append([h, n, src])
		return n
	var g: = P.gain([{"hero": "rin", "n": 3, "src": "chat"}, {"hero": "rin", "n": 1, "src": "feed_like"}])
	check(g == 4 and calls.size() == 2 and calls[0][2] == "chat_branch" and calls[1][2] == "feed_like", "effects → bond with source names of §2.4")
	# soft cap 25 through V10Bond when the meta lane is merged
	var b = P.bond()
	if b != null:
		P.bond_sink = Callable()
		var given: = 0
		for i in 12:
			given += P.gain([{"hero": "yue", "n": 3, "src": "chat"}])
		check(given <= 25, "+3 per branch stops at the soft cap 25 (%d)" % given)
	else:
		# without V10Bond the phone never touches affection directly
		P.bond_sink = Callable()
		var before: int = int(G.S.aff.get("yue", 0))
		P.gain([{"hero": "yue", "n": 3, "src": "chat"}])
		check(int(G.S.aff.get("yue", 0)) == before, "no V10Bond → no direct affection change")
	P.bond_sink = Callable()


static func _feed() -> void:
	var st: = FEED.default_state()
	var ctx: = _ctx(200)
	FEED.visible(st, ctx)
	ctx.day = 230
	var posts: = FEED.visible(st, ctx)
	check(posts.size() >= 8 and posts.size() <= 40, "a month of feed: two posts a week (%d)" % posts.size())
	var bad: = 0
	for p in posts:
		if str(p.t).length() > 280 or ("outfits/" + str(p.img).get_file()) in D.PHOTO_DENY or D.photo_path(str(p.img)) == "":
			bad += 1
	check(bad == 0, "posts ≤280, sfw, image exists")
	var id: = str(posts[0].id)
	var a: = FEED.like(st, id, ctx)
	var b: = FEED.like(st, id, ctx)
	check(a.ok and not b.ok and int(a.effects[0].n) == 1, "like once, +1")
	var r1: = FEED.reply(st, id, 0, ctx)
	var r2: = FEED.reply(st, id, 1, ctx)
	check(r1.ok and not r2.ok and int(r1.effects[0].n) == 2, "reply once, +2")
	var u: = FEED.unseen(st, ctx)
	FEED.mark_seen(st, ctx)
	check(u > 0 and FEED.unseen(st, ctx) == 0, "feed badge counts unseen posts, clears on view")


static func _stickers() -> void:
	var all: Dictionary = D.stickers()
	var miss: = []
	var wrong: = 0
	for k in ["common"] + D.HEROES:
		for s in all.get(k, []):
			var t: = P.sticker_tex(str(s.id))
			if t == null:
				miss.append(s.id)
			elif t.get_width() != 512 or t.get_height() != 512:
				wrong += 1
	check(miss.is_empty(), "every sticker has art (%d missing: %s)" % [miss.size(), str(miss.slice(0, 4))])
	check(wrong == 0, "stickers are 512×512")
	var low: = C.stickers_for(_ctx(1, 1))
	var high: = C.stickers_for(_ctx(1, 6))
	check(low.size() == 8 + 5 * 6 and high.size() == 8 + 5 * 8, "level-5 stickers open with affection (%d / %d)" % [low.size(), high.size()])
	for s in ["msg_in", "msg_out", "typing", "sticker_pop", "like_pop", "comment_in", "react", "tab", "phone_open", "phone_close"]:
		check(ResourceLoader.exists(PUI.SFX_DIR + s + ".wav"), "sound %s" % s)


static func _src_files() -> Array:
	var out: = []
	var d: = DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") and f != "phone_selftest.gd":
			out.append(DIR + f)
	return out


static func _grep() -> void:
	var hits: = []
	for f in _src_files():
		var s: = FileAccess.get_file_as_string(f)
		for bad in ["G.add_aff", "Time.get_unix_time_from_system", "Time.get_date_string_from_system", "S.gems +="]:
			if s.contains(bad):
				hits.append("%s: %s" % [f.get_file(), bad])
	check(hits.is_empty(), "no direct affection / clock / currency calls in v10/phone (%s)" % str(hits))


# every string literal the phone shows passes the stop-word list (§2.7); no prices in the phone
static func _lint() -> void:
	var re: = RegEx.new()
	re.compile("\"([^\"\\\\]|\\\\.)*\"")
	var hits: = []
	for f in _src_files():
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			var t: = m.get_string().to_lower()
			for w in D.BANNED:
				if t.contains(w):
					hits.append("%s: %s" % [f.get_file(), m.get_string()])
	check(hits.is_empty(), "UI strings pass the stop-words (%s)" % str(hits.slice(0, 3)))


static func _ui(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		check(false, "UI checks need a host in the tree")
		return
	# 80 bubbles: build + layout under 12 ms
	var box: = VBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 0)
	host.add_child(box)
	# glyph atlas warm-up once (on a device the fonts are warm after the first screen), then 3 runs with fresh
	# texts (no shaping cache hits); the best run counts
	var best: = 1e9
	var nodes: = 0
	for run in 4:
		for c in box.get_children():
			box.remove_child(c)
			c.free()
		var msgs: = []
		for i in 80:
			msgs.append({"who": "h" if i % 2 == 0 else "me", "k": "text", "t": "Сообщение %d-%d: чай заварен, фишки ждут, а я жду тебя за столом." % [run, i]})
		var t0: = Time.get_ticks_usec()
		for m in msgs:
			box.add_child(BUB.make(m, 440.0, Color("ff8fb8")))
		var dt: = (Time.get_ticks_usec() - t0) / 1000.0
		if run > 0:
			best = minf(best, dt)
		nodes = box.get_child_count()
		await host.get_tree().process_frame
	check(best < 12.0, "80 bubbles in %.2f ms (< 12)" % best)
	check(nodes == 80, "one node per text bubble (%d)" % nodes)
	box.queue_free()
	# smoke: a seeded save, phone overlay, every tab, a chat
	var pre_aff: Dictionary = G.S.aff.duplicate()
	P.ensure()
	G.S.shards["rin"] = 5
	P.tick()
	P.event({"kind": "first_win"})
	var parts: = P.badge_parts()
	check(P.badge() == int(parts.mail) + int(parts.chats) + int(parts.feed), "badge = letters + chats + posts")
	check(int(parts.mail) == V9Letters.badge_count() and int(parts.chats) == P.transport().unread(), "badge parts come from V9Letters and the chat transport")
	P.set_player_name("Аня")
	var ph: Control = P.open(host, {"tab": "chats"})
	await host.get_tree().create_timer(0.5).timeout
	check(is_instance_valid(ph) and ph.frame != null, "phone opens as an overlay")
	var fr: Rect2 = ph.layout_rect()
	check(fr.size.x <= ph.size.x - 24 and fr.position.x >= 12 and fr.end.y <= ph.size.y, "frame fits the screen")
	for k in ["feed", "mail", "chats"]:
		ph.select(k)
		await host.get_tree().create_timer(0.1).timeout
		check(ph.pages.has(k) and ph.pages[k].visible, "tab %s shows" % k)
	var rows: Array = ph.pages.chats.rows()
	check(not rows.is_empty() and rows[0].pinned, "chat list: partner pinned first")
	ph.open_chat(str(rows[0].hero), str(rows[0].tid))
	await host.get_tree().create_timer(0.2).timeout
	ph.chat.skip = true
	var bubbles: = 0
	for c in ph.chat.list.get_children():
		if c is V10Bubble:
			bubbles += 1
	check(bubbles <= 62, "chat view keeps ≤ 62 bubbles (%d)" % bubbles)
	check(_count(ph.chat) < 400, "chat view node count bounded (%d)" % _count(ph.chat))
	ph.back()
	await host.get_tree().create_timer(0.4).timeout
	ph.back()
	await host.get_tree().create_timer(0.5).timeout
	check(not is_instance_valid(ph), "«назад» closes chat, then the phone")
	G.S.aff = pre_aff


static func _count(n: Node) -> int:
	var k: = 1
	for c in n.get_children():
		k += _count(c)
	return k
