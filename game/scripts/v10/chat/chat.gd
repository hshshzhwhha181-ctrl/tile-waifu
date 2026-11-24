class_name V10Chat
extends RefCounted

# 0.10 «Телефон» → Чаты: the pure-logic core (docs/0.10-spec.md §Р8). No nodes, no clock, no G, no files:
# every call takes the chat state (a JSON-safe Dictionary that lives in the save) and a ctx, and returns plain data.
# Affection is never applied here: results carry `effects` = [{hero, n, src:"chat"}] for V10Bond.gain(h, n, src),
# which owns the soft cap of 25 per heroine per day (§2.4).
#
# ctx = {day:int (V10Meta.day_key as a day number, rolls at 04:00), md:"MM-DD", partner:"mc",
#        owned:["mc", …] (heroines the player has), levels:{hero: affection level 1..10},
#        name:"", name_voc:"" (from names.gd; empty → «мастер стола»), gender:"m"|"f",
#        bday_window:[hero, …] (optional, V10Bday.window_hero; else exact md match)}
#
# Rhythm (no spam): at most MAX_NEW_PER_DAY new threads a day in total, of them at most one «daily» ladder thread
# (partner first); at most one new thread per heroine a day; never more than MAX_OPEN unanswered threads at once;
# event threads wait in a queue for QUEUE_TTL days and then quietly drop. Nothing is ever lost by not playing.

const D: = preload("res://scripts/v10/chat/chat_data.gd")

const VER: = 1
const MAX_NEW_PER_DAY: = 2
const MAX_DAILY_PER_DAY: = 1
const MAX_OPEN: = 3
const QUEUE_TTL: = 3
const STICKER_REPLIES_PER_DAY: = 3
const REACT_REPLY_PCT: = 30
const NAME_FALLBACK: = "мастер стола"
const PRIORITY: = {"birthday": 5, "comeback": 4, "outfit": 3, "rank_up": 2, "combo_record": 1, "first_win": 0}


# --- save -------------------------------------------------------------------

static func default_state() -> Dictionary:
	return {"v": VER, "chats": {}, "queue": [], "new_key": -1, "new_n": 0, "new_daily": 0, "last": {},
		"flags": {}, "fired": {}, "react": {}, "st_key": -1, "st_n": {}}


# idempotent: fills missing keys (old saves, partial dicts), never drops data
static func ensure(st: Dictionary) -> Dictionary:
	var d: = default_state()
	for k in d:
		if not st.has(k) or typeof(st[k]) != typeof(d[k]):
			st[k] = d[k]
	st.v = VER
	return st


# --- text ---------------------------------------------------------------------

static func days_word(n: int) -> String:
	var m10: = n % 10
	var m100: = n % 100
	var w: = "дней"
	if m10 == 1 and m100 != 11:
		w = "день"
	elif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		w = "дня"
	return "%d %s" % [n, w]


static func format(text: String, vars: Dictionary, ctx: Dictionary) -> String:
	var name: String = str(ctx.get("name", ""))
	var voc: String = str(ctx.get("name_voc", ""))
	if name == "":
		name = NAME_FALLBACK
	if voc == "":
		voc = name if str(ctx.get("name", "")) != "" else NAME_FALLBACK
	var t: = text.replace("{name_voc}", voc).replace("{name}", name)
	t = t.replace("{combo}", str(vars.get("combo", ""))).replace("{rank}", str(vars.get("rank", "")))
	t = t.replace("{outfit}", str(vars.get("outfit_name", vars.get("outfit", ""))))
	if t.contains("{days}"):
		t = t.replace("{days}", days_word(int(vars.get("days", 2))))
	var female: bool = str(ctx.get("gender", "m")) == "f"
	var i: = t.find("{g:")
	while i >= 0:
		var j: = t.find("}", i)
		if j < 0:
			break
		var parts: = t.substr(i + 3, j - i - 3).split("|")
		var pick: String = parts[1] if female and parts.size() > 1 else parts[0]
		t = t.substr(0, i) + pick + t.substr(j + 1)
		i = t.find("{g:", i + pick.length())
	# a token at the very start («{name_voc}, привет») is capitalised; her own casing is kept (Nova writes lowercase)
	if text.begins_with("{") and t.length() > 0:
		t = t[0].to_upper() + t.substr(1)
	return t


# «печатает…» 0.4 s + 35 ms a character, never longer than 2.2 s (tap skips)
static func typing_ms(text: String) -> int:
	return clampi(400 + 35 * text.length(), 400, 2200)


# --- queries ------------------------------------------------------------------

static func _level(ctx: Dictionary, hero: String) -> int:
	return int(ctx.get("levels", {}).get(hero, 1))


static func _owned(ctx: Dictionary, hero: String) -> bool:
	return hero in ctx.get("owned", [])


static func _is_open(st: Dictionary, tid: String) -> bool:
	var c: Dictionary = st.chats.get(tid, {})
	return not c.is_empty() and not bool(c.get("done", false))


static func open_threads(st: Dictionary) -> Array:
	var out: = []
	for tid in st.chats:
		if _is_open(st, tid):
			out.append(tid)
	out.sort_custom(func(a, b): return int(st.chats[a].get("day", 0)) > int(st.chats[b].get("day", 0)))
	return out


static func awaiting(st: Dictionary, tid: String) -> bool:
	if not _is_open(st, tid):
		return false
	var node: Dictionary = D.thread(tid).get("nodes", {}).get(str(st.chats[tid].pos), {})
	return node.has("choices")


# phone badge contribution: unread chats + chats waiting for the player's answer (each thread counted once)
static func unread(st: Dictionary) -> int:
	var n: = 0
	for tid in st.chats:
		var c: Dictionary = st.chats[tid]
		if int(c.get("unread", 0)) > 0 or awaiting(st, tid):
			n += 1
	return n


static func mark_read(st: Dictionary, tid: String) -> void:
	if st.chats.has(tid):
		st.chats[tid].unread = 0


# list for the Chats tab: one row per heroine with her newest thread, partner pinned first
static func rows(st: Dictionary, ctx: Dictionary) -> Array:
	var best: = {}
	for tid in st.chats:
		var h: = D.hero_of(tid)
		if h == "" or not _owned(ctx, h):
			continue
		var c: Dictionary = st.chats[tid]
		var key: = int(c.get("day", 0)) * 2 + (1 if _is_open(st, tid) else 0)
		if not best.has(h) or key > best[h].key:
			best[h] = {"hero": h, "tid": tid, "key": key}
	var out: = []
	for h in best:
		var tid: String = best[h].tid
		var tr: = transcript(st, tid, ctx)
		var last: = ""
		for m in tr:
			if m.k == "text" or m.k == "voice":
				last = m.t
			elif m.k == "photo":
				last = "Фото"
			elif m.k == "sticker":
				last = "Стикер"
		out.append({"hero": h, "tid": tid, "title": format(str(D.thread(tid).get("title", "")), st.chats[tid].get("vars", {}), ctx), "last": last,
			"dot": int(st.chats[tid].get("unread", 0)) > 0 or awaiting(st, tid),
			"pinned": h == str(ctx.get("partner", "")), "day": int(st.chats[tid].get("day", 0))})
	out.sort_custom(func(a, b):
		if a.pinned != b.pinned:
			return a.pinned
		return a.day > b.day)
	return out


# --- eligibility ----------------------------------------------------------------

static func _eligible(st: Dictionary, t: Dictionary, ctx: Dictionary) -> bool:
	var h: String = t.hero
	if not _owned(ctx, h) or _level(ctx, h) < int(t.get("level", 1)):
		return false
	if t.has("need") and not st.flags.has(str(t.need)):
		return false
	var c: Dictionary = st.chats.get(t.id, {})
	if c.is_empty():
		return true
	if not bool(c.get("done", false)):
		return false
	var rep: = int(t.get("repeat", 0))
	return rep > 0 and int(ctx.get("day", 0)) - int(c.get("done_day", 0)) >= rep


static func _queued(st: Dictionary, tid: String) -> bool:
	for q in st.queue:
		if q.tid == tid:
			return true
	return false


# --- scheduler ------------------------------------------------------------------

static func _roll(st: Dictionary, ctx: Dictionary) -> void:
	var day: = int(ctx.get("day", 0))
	if int(st.new_key) == day:
		return
	st.new_key = day
	st.new_n = 0
	st.new_daily = 0
	var keep: = []
	for q in st.queue:
		if day - int(q.day) < QUEUE_TTL:
			keep.append(q)
	st.queue = keep
	for k in st.fired.keys():
		if day - int(st.fired[k]) > 400:
			st.fired.erase(k)


# A game event happened. Queues her thread for it (if any is eligible) and opens what the rhythm allows.
# ev = {kind, hero?, outfit?, outfit_name?, combo?, rank?, days?}; returns the thread ids opened right now.
static func on_event(st: Dictionary, ev: Dictionary, ctx: Dictionary) -> Array:
	ensure(st)
	_roll(st, ctx)
	var kind: String = str(ev.get("kind", ""))
	if not kind in D.EVENT_TRIGGERS:
		return []
	var day: = int(ctx.get("day", 0))
	var hero: String = str(ev.get("hero", ""))
	if hero == "":
		hero = str(ctx.get("partner", ""))
	if kind == "outfit":
		hero = ""
		for t in D.all_threads():
			if t.trigger == "outfit" and str(t.get("outfit", "")) == str(ev.get("outfit", "")):
				hero = t.hero
	var fkey: = "%s:%s:%s" % [kind, hero, str(ev.get("outfit", ""))]
	if st.fired.has(fkey) and int(st.fired[fkey]) == day:
		return []
	var cand: Dictionary = {}
	for t in D.threads(hero):
		if t.trigger != kind:
			continue
		if kind == "outfit" and str(t.get("outfit", "")) != str(ev.get("outfit", "")):
			continue
		if _eligible(st, t, ctx) and not _queued(st, t.id):
			if cand.is_empty() or int(t.get("level", 1)) > int(cand.get("level", 1)):
				cand = t
	if cand.is_empty():
		return []
	st.fired[fkey] = day
	var vars: = {}
	for k in ["combo", "rank", "days", "outfit", "outfit_name"]:
		if ev.has(k):
			vars[k] = ev[k]
	st.queue.append({"tid": cand.id, "day": day, "kind": kind, "vars": vars})
	return _fill(st, ctx, false)


# Day roll / app open / phone open. Fires the birthday event and fills today's slots.
static func tick(st: Dictionary, ctx: Dictionary) -> Array:
	ensure(st)
	_roll(st, ctx)
	var opened: = []
	var win: Array = ctx.get("bday_window", [])
	for h in D.HEROES:
		if h in win or D.birthday(h) == str(ctx.get("md", "")):
			opened.append_array(on_event(st, {"kind": "birthday", "hero": h}, ctx))
	opened.append_array(_fill(st, ctx, true))
	return opened


static func _heroes_today(st: Dictionary, day: int) -> Array:
	var out: = []
	for h in st.last:
		if int(st.last[h]) == day:
			out.append(h)
	return out


# events first (by priority), then — only from tick, never right after an event — the daily ladder thread
static func _fill(st: Dictionary, ctx: Dictionary, daily: bool) -> Array:
	var day: = int(ctx.get("day", 0))
	var opened: = []
	while int(st.new_n) < MAX_NEW_PER_DAY and open_threads(st).size() < MAX_OPEN:
		var today: = _heroes_today(st, day)
		var qi: = -1
		for i in st.queue.size():
			var q: Dictionary = st.queue[i]
			var t: = D.thread(q.tid)
			if t.is_empty() or not _eligible(st, t, ctx):
				continue
			if t.hero in today and q.kind != "birthday":
				continue
			if qi < 0 or PRIORITY.get(q.kind, 0) > PRIORITY.get(st.queue[qi].kind, 0):
				qi = i
		if qi >= 0:
			var q: Dictionary = st.queue[qi]
			st.queue.remove_at(qi)
			_open(st, q.tid, q.get("vars", {}), ctx)
			opened.append(q.tid)
			continue
		if not daily or int(st.new_daily) >= MAX_DAILY_PER_DAY:
			break
		var tid: = _pick_daily(st, ctx, today)
		if tid == "":
			break
		st.new_daily = int(st.new_daily) + 1
		_open(st, tid, {}, ctx)
		opened.append(tid)
	return opened


# partner first; then the owned heroine who wrote least recently; her lowest-level unread ladder thread
static func _pick_daily(st: Dictionary, ctx: Dictionary, today: Array) -> String:
	var order: Array = []
	for h in D.HEROES:
		if _owned(ctx, h) and not h in today:
			order.append(h)
	var partner: = str(ctx.get("partner", ""))
	order.sort_custom(func(a, b):
		if (a == partner) != (b == partner):
			return a == partner
		return int(st.last.get(a, -999999)) < int(st.last.get(b, -999999)))
	for h in order:
		var open_h: = false
		for tid in open_threads(st):
			if D.hero_of(tid) == h:
				open_h = true
		if open_h:
			continue
		var best: Dictionary = {}
		for t in D.threads(h):
			if t.trigger == "daily" and _eligible(st, t, ctx):
				if best.is_empty() or int(t.get("level", 1)) < int(best.get("level", 1)):
					best = t
		if not best.is_empty():
			return best.id
	return ""


static func _open(st: Dictionary, tid: String, vars: Dictionary, ctx: Dictionary) -> void:
	var t: = D.thread(tid)
	var day: = int(ctx.get("day", 0))
	st.chats[tid] = {"pos": t.start, "done": false, "picks": [], "day": day, "vars": vars, "unread": 0}
	st.new_n = int(st.new_n) + 1
	st.last[t.hero] = day
	var run: = _run(t, str(t.start))
	st.chats[tid].pos = run.pos
	st.chats[tid].unread = run.msgs.size()
	if run.end:
		_finish(st, tid, ctx)


# --- conversation ------------------------------------------------------------------

# follows `next` links from a node, collecting heroine messages, until a node with choices or an end
static func _run(t: Dictionary, from: String) -> Dictionary:
	var msgs: = []
	var pos: = from
	var guard: = 0
	while guard < 64:
		guard += 1
		var n: Dictionary = t.nodes.get(pos, {})
		msgs.append_array(n.get("msgs", []))
		if n.has("choices") or n.get("end", false) or not n.has("next"):
			return {"msgs": msgs, "pos": pos, "end": n.get("end", false) or (not n.has("choices") and not n.has("next"))}
		pos = str(n.next)
	return {"msgs": msgs, "pos": pos, "end": true}


static func _fmt_msgs(msgs: Array, who: String, vars: Dictionary, ctx: Dictionary) -> Array:
	var out: = []
	for m in msgs:
		var o: Dictionary = m.duplicate()
		o.who = who
		if o.has("t"):
			o.t = format(str(o.t), vars, ctx)
		out.append(o)
	return out


static func _choices_of(t: Dictionary, pos: String, vars: Dictionary, ctx: Dictionary) -> Array:
	var out: = []
	for c in t.nodes.get(pos, {}).get("choices", []):
		var o: Dictionary = {"next": c.next}
		if c.has("sticker"):
			o.sticker = c.sticker
		else:
			o.t = format(str(c.t), vars, ctx)
		out.append(o)
	return out


# full conversation of a thread rebuilt from the picks (the save keeps picks, not text): [{who:"h"|"me", k, t|img|id}]
static func transcript(st: Dictionary, tid: String, ctx: Dictionary) -> Array:
	var t: = D.thread(tid)
	var c: Dictionary = st.chats.get(tid, {})
	if t.is_empty() or c.is_empty():
		return []
	var vars: Dictionary = c.get("vars", {})
	var out: = []
	var run: = _run(t, str(t.start))
	out.append_array(_fmt_msgs(run.msgs, "h", vars, ctx))
	for p in c.get("picks", []):
		var ch: Array = t.nodes.get(run.pos, {}).get("choices", [])
		var i: = int(p)
		if i < 0 or i >= ch.size():
			break
		var me: Dictionary = {"who": "me"}
		if ch[i].has("sticker"):
			me.k = "sticker"
			me.id = ch[i].sticker
		else:
			me.k = "text"
			me.t = format(str(ch[i].t), vars, ctx)
		out.append(me)
		run = _run(t, str(ch[i].next))
		out.append_array(_fmt_msgs(run.msgs, "h", vars, ctx))
	return out


# what the dialog shows now: transcript + the pills (empty when done)
static func view(st: Dictionary, tid: String, ctx: Dictionary) -> Dictionary:
	var t: = D.thread(tid)
	var c: Dictionary = st.chats.get(tid, {})
	if t.is_empty() or c.is_empty():
		return {}
	var done: = bool(c.get("done", false))
	return {"tid": tid, "hero": t.hero, "title": format(str(t.title), c.get("vars", {}), ctx), "msgs": transcript(st, tid, ctx), "done": done,
		"choices": [] if done else _choices_of(t, str(c.pos), c.get("vars", {}), ctx)}


# the player taps pill i. Returns {ok, me, msgs (her answer, formatted), choices, done, effects}
static func choose(st: Dictionary, tid: String, i: int, ctx: Dictionary) -> Dictionary:
	var t: = D.thread(tid)
	if t.is_empty() or not _is_open(st, tid):
		return {"ok": false}
	var c: Dictionary = st.chats[tid]
	var ch: Array = t.nodes.get(str(c.pos), {}).get("choices", [])
	if i < 0 or i >= ch.size():
		return {"ok": false}
	var pick: Dictionary = ch[i]
	var vars: Dictionary = c.get("vars", {})
	c.picks.append(i)
	var effects: = []
	if int(pick.get("aff", 0)) > 0:
		effects.append({"hero": t.hero, "n": int(pick.aff), "src": "chat"})
	if pick.has("set"):
		st.flags[str(pick["set"])] = int(ctx.get("day", 0))
	var me: Dictionary = {"who": "me"}
	if pick.has("sticker"):
		me.k = "sticker"
		me.id = pick.sticker
	else:
		me.k = "text"
		me.t = format(str(pick.t), vars, ctx)
	var run: = _run(t, str(pick.next))
	c.pos = run.pos
	c.unread = 0
	var res: = {"ok": true, "me": me, "msgs": _fmt_msgs(run.msgs, "h", vars, ctx), "done": false,
		"choices": _choices_of(t, run.pos, vars, ctx), "effects": effects}
	if run.end:
		effects.append_array(_finish(st, tid, ctx))
		res.done = true
		res.choices = []
	return res


static func _finish(st: Dictionary, tid: String, ctx: Dictionary) -> Array:
	var c: Dictionary = st.chats[tid]
	c.done = true
	c.done_day = int(ctx.get("day", 0))
	return [{"hero": D.hero_of(tid), "n": D.DONE_AFF, "src": "chat"}]


# --- reactions & stickers -----------------------------------------------------------

static func _hash_pct(s: String) -> int:
	return absi(s.hash()) % 100


# long-press reaction on her message #idx of thread tid. She answers ~30% of the time (deterministic per message).
static func react(st: Dictionary, tid: String, idx: int, rid: String, ctx: Dictionary) -> Dictionary:
	if not rid in D.reactions().get("set", []) or D.thread(tid).is_empty() or idx < 0:
		return {"ok": false}
	var key: = "%s#%d" % [tid, idx]
	var first: bool = not st.react.has(key)
	st.react[key] = rid
	if not first:
		return {"ok": true, "reply": ""}
	var h: = D.hero_of(tid)
	var lines: Array = D.reactions().get(h, {}).get(rid, [])
	if lines.is_empty() or _hash_pct("%s|%s|%d" % [key, rid, int(ctx.get("day", 0))]) >= REACT_REPLY_PCT:
		return {"ok": true, "reply": ""}
	var line: String = lines[absi(key.hash()) % lines.size()]
	return {"ok": true, "reply": format(line, {}, ctx)}


# stickers the player can send now: 8 common + 8 per owned heroine (some open at affection level 5)
static func stickers_for(ctx: Dictionary) -> Array:
	var all: = D.stickers()
	var out: Array = all.get("common", []).duplicate()
	for h in D.HEROES:
		if not _owned(ctx, h):
			continue
		for s in all.get(h, []):
			if _level(ctx, h) >= int(s.get("level", 1)):
				out.append(s)
	return out


# the player sends a sticker to her outside a thread's pills; she answers up to 3 times a day, no affection (no farming)
static func send_sticker(st: Dictionary, hero: String, sid: String, ctx: Dictionary) -> Dictionary:
	ensure(st)
	var ok: = false
	for s in stickers_for(ctx):
		if s.id == sid:
			ok = true
	if not ok or not _owned(ctx, hero):
		return {"ok": false}
	var day: = int(ctx.get("day", 0))
	if int(st.st_key) != day:
		st.st_key = day
		st.st_n = {}
	var n: = int(st.st_n.get(hero, 0))
	if n >= STICKER_REPLIES_PER_DAY:
		return {"ok": true, "reply": ""}
	st.st_n[hero] = n + 1
	var mood: String = str(D.sticker(sid).get("mood", "warm"))
	var lines: Array = D.reactions().get(hero, {}).get("sticker_" + mood, [])
	if lines.is_empty():
		return {"ok": true, "reply": ""}
	return {"ok": true, "reply": format(lines[absi(("%s%d%d" % [sid, day, n]).hash()) % lines.size()], {}, ctx)}
