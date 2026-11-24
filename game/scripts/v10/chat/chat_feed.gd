class_name V10ChatFeed
extends RefCounted

# 0.10 «Телефон» → Лента (docs/0.10-spec.md §Р9), pure logic over data/v10/chat/feed.json.
# Evergreen pool: posts open two a week (every 3, then 4 days) from the day the feed first opened, only for heroines
# the player has. Each post's day is fixed in the state the moment it opens (`at`), so a heroine pulled later only
# adds her posts to the queue — posts already shown never move or disappear. When every owned heroine's posts are out
# the rhythm pauses (`next` = -1) and resumes on the day a new heroine brings new posts.
# Like: once per post, +1 (soft). Reply: once per post, one of 2 pills, her answer, +2 (soft).
# Effects go to V10Bond.gain like the chat's.
#
# state = {liked:{post_id:day}, replied:{post_id:pick}, at:{post_id:day}, next:int, seen_max:int}

const D: = preload("res://scripts/v10/chat/chat_data.gd")
const C: = preload("res://scripts/v10/chat/chat.gd")

const LIKE_AFF: = 1
const REPLY_AFF: = 2
const MAX_VISIBLE: = 40


static func default_state() -> Dictionary:
	return {"liked": {}, "replied": {}, "at": {}, "next": -1, "seen_max": -1}


# idempotent; numbers come back from the JSON save as floats and are cast to int (never reset)
static func ensure(st: Dictionary) -> Dictionary:
	var d: = default_state()
	for k in d:
		if st.has(k) and typeof(d[k]) == TYPE_INT and typeof(st[k]) in [TYPE_INT, TYPE_FLOAT]:
			st[k] = int(st[k])
		elif not st.has(k) or typeof(st[k]) != typeof(d[k]):
			st[k] = d[k]
	return st


# day offset at which evergreen post #k opens: 0, 3, 7, 10, 14, … (two a week)
static func open_offset(k: int) -> int:
	return (k / 2) * 7 + (k % 2) * 3


# opens due posts: the next owned post of the pool takes the slot `next`, then the slot moves 3 / 4 days on
static func _advance(st: Dictionary, day: int, owned: Array) -> void:
	if int(st.next) < 0:
		st.next = day
	var guard: = 0
	while int(st.next) <= day and guard < 256:
		guard += 1
		var pick: = ""
		for p in D.feed():
			if p.hero in owned and not st.at.has(p.id):
				pick = p.id
				break
		if pick == "":
			st.next = -1
			return
		st.at[pick] = int(st.next)
		st.next = int(st.next) + open_offset(st.at.size()) - open_offset(st.at.size() - 1)


# newest first; each item = post + {day, liked, replied}
static func visible(st: Dictionary, ctx: Dictionary) -> Array:
	ensure(st)
	var day: = int(ctx.get("day", 0))
	_advance(st, day, ctx.get("owned", []))
	var out: = []
	for p in D.feed():
		if not st.at.has(p.id) or int(st.at[p.id]) > day:
			continue
		var o: Dictionary = p.duplicate(true)
		o.day = int(st.at[p.id])
		o.liked = st.liked.has(p.id)
		o.replied = int(st.replied.get(p.id, -1))
		out.push_front(o)
	out.sort_custom(func(a, b): return int(a.day) > int(b.day))
	return out.slice(0, MAX_VISIBLE)


# badge: posts newer than what the player has seen
static func unseen(st: Dictionary, ctx: Dictionary) -> int:
	var n: = 0
	for p in visible(st, ctx):
		if int(p.day) > int(st.seen_max):
			n += 1
	return n


static func mark_seen(st: Dictionary, ctx: Dictionary) -> void:
	for p in visible(st, ctx):
		st.seen_max = maxi(int(st.seen_max), int(p.day))


static func _post(id: String) -> Dictionary:
	for p in D.feed():
		if p.id == id:
			return p
	return {}


static func like(st: Dictionary, id: String, ctx: Dictionary) -> Dictionary:
	ensure(st)
	var p: = _post(id)
	if p.is_empty() or st.liked.has(id):
		return {"ok": false, "effects": []}
	st.liked[id] = int(ctx.get("day", 0))
	return {"ok": true, "effects": [{"hero": p.hero, "n": LIKE_AFF, "src": "feed_like"}]}


static func reply(st: Dictionary, id: String, i: int, ctx: Dictionary) -> Dictionary:
	ensure(st)
	var p: = _post(id)
	if p.is_empty() or st.replied.has(id) or i < 0 or i >= p.get("replies", []).size():
		return {"ok": false, "effects": []}
	st.replied[id] = i
	var r: Dictionary = p.replies[i]
	return {"ok": true, "me": C.format(str(r.t), {}, ctx), "answer": C.format(str(r.a), {}, ctx),
		"effects": [{"hero": p.hero, "n": REPLY_AFF, "src": "feed_reply"}]}

