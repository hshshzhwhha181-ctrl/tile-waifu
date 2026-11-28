class_name V10ChatValidate
extends RefCounted

# Static validation of every chat data file (threads, stickers, reactions, feed, meta). Returns a list of
# human-readable errors; empty = shippable. Used by the selftest and usable by a build script / CI.

const D: = preload("res://core/chat/chat_data.gd")
const C: = preload("res://core/chat/chat.gd")

const MIN_THREADS: = 12
const MIN_DAILY: = 5
const MOODS: = ["warm", "fun", "tease", "tired", "win"]
const MSG_KINDS: = ["text", "photo", "sticker", "voice"]
const TOKENS: = ["name", "name_voc", "combo", "rank", "days", "outfit"]
const TOKEN_TRIGGER: = {"combo": "combo_record", "rank": "rank_up", "days": "comeback"}
const OUTFIT_PREFIX: = {"mc": "o_", "rin": "r_", "hana": "h_", "yue": "y_", "nova": "n_"}
# G.ITEMS outfits of the founders (g.gd); the validator also cross-checks G when it is loaded
const OUTFITS: = ["o_base", "o_tutor", "o_cafe", "o_dragon", "o_cozy", "r_base", "r_maid", "r_after", "r_agent", "r_idol",
	"r_yukata", "h_base", "h_street", "h_beach", "h_gym", "h_winter", "y_base", "y_duel", "y_queen", "y_ball",
	"n_base", "n_ssr", "n_offline"]

static var errs: Array = []


static func _e(where: String, what: String) -> void:
	errs.append("%s: %s" % [where, what])


static func run() -> Array:
	errs = []
	D.reload()
	_meta()
	_stickers()
	_reactions()
	_feed()
	_threads()
	return errs


# --- text checks -------------------------------------------------------------------

static func _text(where: String, t: Variant, maxlen: int, trig: String = "") -> void:
	if not t is String or str(t).strip_edges() == "":
		_e(where, "empty text")
		return
	var s: String = t
	for w in D.lint(s):
		_e(where, "stop-word «%s» in «%s»" % [w, s])
	var i: = s.find("{")
	while i >= 0:
		var j: = s.find("}", i)
		if j < 0:
			_e(where, "unclosed token")
			break
		var tok: = s.substr(i + 1, j - i - 1)
		if tok.begins_with("g:"):
			if tok.substr(2).split("|").size() != 2:
				_e(where, "gender token needs male|female: {%s}" % tok)
		elif not tok in TOKENS:
			_e(where, "unknown token {%s}" % tok)
		elif TOKEN_TRIGGER.has(tok) and trig != "" and TOKEN_TRIGGER[tok] != trig:
			_e(where, "{%s} outside a %s thread" % [tok, TOKEN_TRIGGER[tok]])
		i = s.find("{", j)
	# worst case length: long name + long rank/combo, both genders
	var vars: = {"combo": 99, "rank": "Нефритовый мастер III", "days": 12, "outfit_name": "Императрица дракона"}
	for g in ["m", "f"]:
		var out: = C.format(s, vars, {"name": "Константин", "name_voc": "Константин", "gender": g})
		if out.length() > maxlen:
			_e(where, "too long %d > %d: «%s»" % [out.length(), maxlen, out])
		if out.contains("{") or out.contains("}"):
			_e(where, "unresolved token in «%s»" % out)


static func _photo(where: String, img: Variant) -> void:
	if not img is String or D.photo_path(str(img)) == "":
		_e(where, "photo art not found: %s" % str(img))
	elif str(img) in D.PHOTO_DENY:
		_e(where, "photo is not sfw: %s" % str(img))


# --- meta / stickers / reactions / feed ---------------------------------------------

static func _meta() -> void:
	var m: = D.meta()
	if m.is_empty():
		_e("meta.json", "missing or invalid")
		return
	for h in D.HEROES:
		var b: = D.birthday(h)
		var p: = b.split("-")
		if p.size() != 2 or int(p[0]) < 1 or int(p[0]) > 12 or int(p[1]) < 1 or int(p[1]) > 31:
			_e("meta.json", "bad birthday for %s: %s" % [h, b])
	var ids: = []
	for r in m.get("reactions", []):
		ids.append(r.get("id", ""))
		if str(r.get("label", "")) == "":
			_e("meta.json", "reaction without label")
	if ids.size() != 6:
		_e("meta.json", "need 6 reactions, got %d" % ids.size())


static func _stickers() -> void:
	var s: = D.stickers()
	if s.is_empty():
		_e("stickers.json", "missing or invalid")
		return
	var seen: = {}
	for group in ["common"] + D.HEROES:
		var arr: Array = s.get(group, [])
		if arr.size() != 8:
			_e("stickers.json", "%s needs 8 stickers, has %d" % [group, arr.size()])
		var hi: = 0
		for st in arr:
			var id: String = str(st.get("id", ""))
			var w: = "stickers.json/" + id
			if seen.has(id):
				_e(w, "duplicate id")
			seen[id] = true
			if group != "common" and not id.begins_with(group + "_"):
				_e(w, "id must start with %s_" % group)
			if not str(st.get("mood", "")) in MOODS:
				_e(w, "bad mood")
			if str(st.get("label", "")) == "" or str(st.get("glyph", "")) == "":
				_e(w, "needs label and glyph (code fallback until art)")
			if not str(st.get("img", "")).begins_with("res://assets/v10/stickers/"):
				_e(w, "img must live under res://assets/v10/stickers/")
			var lv: = int(st.get("level", 1))
			if lv < 1 or lv > 10:
				_e(w, "bad level")
			if lv >= 5:
				hi += 1
		if group != "common" and (hi < 1 or hi > 4):
			_e("stickers.json", "%s: 1–4 stickers should open at affection 5 (has %d)" % [group, hi])


static func _reactions() -> void:
	var r: = D.reactions()
	var rset: Array = r.get("set", [])
	var meta_ids: = []
	for m in D.meta().get("reactions", []):
		meta_ids.append(m.id)
	if rset != meta_ids:
		_e("reactions.json", "set must equal meta reactions %s" % str(meta_ids))
	for h in D.HEROES:
		var hr: Dictionary = r.get(h, {})
		var keys: Array = rset.duplicate()
		for m in MOODS:
			keys.append("sticker_" + m)
		for k in keys:
			var lines: Array = hr.get(k, [])
			if lines.size() < 2:
				_e("reactions.json/%s" % h, "%s needs ≥2 lines" % k)
			for l in lines:
				_text("reactions.json/%s/%s" % [h, k], l, D.MAX_REACT_LINE)


static func _feed() -> void:
	var posts: = D.feed()
	if posts.size() < 20:
		_e("feed.json", "need ≥20 evergreen posts, has %d" % posts.size())
	var seen: = {}
	var per: = {}
	for p in posts:
		var id: String = str(p.get("id", ""))
		var w: = "feed.json/" + id
		if seen.has(id) or id == "":
			_e(w, "duplicate or empty id")
		seen[id] = true
		var h: String = str(p.get("hero", ""))
		if not h in D.HEROES:
			_e(w, "unknown hero")
		per[h] = int(per.get(h, 0)) + 1
		_photo(w, p.get("img"))
		_text(w, p.get("t"), D.MAX_FEED)
		var cm: Array = p.get("comments", [])
		if cm.size() > 2:
			_e(w, "max 2 comments")
		for c in cm:
			if not str(c.get("hero", "")) in D.HEROES:
				_e(w, "comment by unknown hero")
			_text(w + "/comment", c.get("t"), D.MAX_COMMENT)
		var rp: Array = p.get("replies", [])
		if rp.size() != 2:
			_e(w, "needs exactly 2 reply pills")
		for x in rp:
			_text(w + "/reply", x.get("t"), D.MAX_CHOICE)
			_text(w + "/answer", x.get("a"), D.MAX_COMMENT)
	for h in D.HEROES:
		if int(per.get(h, 0)) < 3:
			_e("feed.json", "%s needs ≥3 posts" % h)


# --- threads -------------------------------------------------------------------------

static func _threads() -> void:
	var ids: = {}
	var sticker_ids: = {}
	for s in D.stickers().get("common", []):
		sticker_ids[s.id] = "common"
	for h in D.HEROES:
		for s in D.stickers().get(h, []):
			sticker_ids[s.id] = h
	var g_items: = {}
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("G"):
		for it in tree.root.get_node("G").ITEMS:
			g_items[it.id] = it
	for h in D.HEROES:
		var f: = D.hero_file(h)
		if f.is_empty():
			_e("threads_%s.json" % h, "missing or invalid")
			continue
		if f.get("hero", "") != h:
			_e("threads_%s.json" % h, "hero field mismatch")
		var list: Array = f.get("threads", [])
		if list.size() < MIN_THREADS:
			_e("threads_%s.json" % h, "needs ≥%d threads, has %d" % [MIN_THREADS, list.size()])
		var by_trig: = {}
		var flags_set: = {}
		for t in list:
			for n in t.get("nodes", {}).values():
				for c in n.get("choices", []):
					if c.has("set"):
						flags_set[c["set"]] = true
		for t in list:
			var id: String = str(t.get("id", ""))
			if ids.has(id):
				_e(id, "duplicate thread id")
			ids[id] = true
			by_trig[t.get("trigger", "")] = int(by_trig.get(t.get("trigger", ""), 0)) + 1
			_thread(t, h, sticker_ids, flags_set, g_items)
		for trig in D.EVENT_TRIGGERS:
			if not by_trig.has(trig):
				_e("threads_%s.json" % h, "no thread for event %s" % trig)
		if int(by_trig.get("daily", 0)) < MIN_DAILY:
			_e("threads_%s.json" % h, "needs ≥%d daily threads" % MIN_DAILY)


static func _thread(t: Dictionary, h: String, sticker_ids: Dictionary, flags_set: Dictionary, g_items: Dictionary) -> void:
	var id: String = str(t.get("id", ""))
	var w: = id
	var rx: = RegEx.create_from_string("^[a-z0-9_]+$")
	if rx.search(id) == null or not id.begins_with(h + "_"):
		_e(w, "id must be [a-z0-9_] and start with %s_" % h)
	if t.get("hero", "") != h:
		_e(w, "hero mismatch")
	var trig: String = str(t.get("trigger", ""))
	if not trig in D.TRIGGERS:
		_e(w, "unknown trigger %s" % trig)
	var lv: = int(t.get("level", 0))
	if lv < 1 or lv > 10:
		_e(w, "level must be 1..10")
	_text(w + "/title", t.get("title"), D.MAX_TITLE, trig)
	if trig == "outfit":
		var o: String = str(t.get("outfit", ""))
		if not o in OUTFITS or not o.begins_with(OUTFIT_PREFIX[h]):
			_e(w, "outfit %s is not one of %s's" % [o, h])
		if not g_items.is_empty() and not g_items.has(o):
			_e(w, "outfit %s not in G.ITEMS" % o)
	elif t.has("outfit"):
		_e(w, "outfit field only for trigger outfit")
	if t.has("need") and not flags_set.has(t.need):
		_e(w, "needs flag %s that no choice sets" % t.need)
	if trig in ["comeback", "birthday"] and int(t.get("repeat", 0)) < 28:
		_e(w, "%s threads must be repeatable (repeat ≥28 days)" % trig)
	var nodes: Dictionary = t.get("nodes", {})
	var start: String = str(t.get("start", ""))
	if not nodes.has(start):
		_e(w, "start node missing")
		return
	for name in nodes:
		var n: Dictionary = nodes[name]
		var wn: = "%s:%s" % [id, name]
		var outs: = int(n.has("choices")) + int(n.has("next")) + int(bool(n.get("end", false)))
		if outs != 1:
			_e(wn, "needs exactly one of choices / next / end (dead end or ambiguity)")
		if n.has("next") and not nodes.has(str(n.next)):
			_e(wn, "next → missing node %s" % n.next)
		if n.has("choices"):
			var ch: Array = n.choices
			if ch.size() < 2 or ch.size() > 3:
				_e(wn, "choices must be 2–3, has %d" % ch.size())
			for c in ch:
				if not nodes.has(str(c.get("next", ""))):
					_e(wn, "choice → missing node %s" % c.get("next", ""))
				if c.has("sticker"):
					var sown: String = str(sticker_ids.get(c.sticker, ""))
					if sown != h and sown != "common":
						_e(wn, "player pill sticker %s must be common or %s's" % [c.sticker, h])
					elif int(D.sticker(c.sticker).get("level", 1)) > int(t.get("level", 1)):
						_e(wn, "player pill sticker %s unlocks later than the thread" % c.sticker)
				else:
					_text(wn + "/choice", c.get("t"), D.MAX_CHOICE, trig)
				var a: = int(c.get("aff", 0))
				if a < 0 or a > 2:
					_e(wn, "choice aff must be 0..2")
		for m in n.get("msgs", []):
			var k: String = str(m.get("k", ""))
			if not k in MSG_KINDS:
				_e(wn, "unknown msg kind %s" % k)
			elif k == "text":
				_text(wn, m.get("t"), D.MAX_BUBBLE, trig)
			elif k == "photo":
				_photo(wn, m.get("img"))
				if m.has("t"):
					_text(wn + "/caption", m.t, D.MAX_CAPTION, trig)
			elif k == "sticker":
				var owner: String = str(sticker_ids.get(m.get("id", ""), ""))
				if owner != h and owner != "common":
					_e(wn, "she can only send her own or common stickers: %s" % m.get("id", ""))
			elif k == "voice":
				var sec: = int(m.get("sec", 0))
				if sec < 2 or sec > 4:
					_e(wn, "voice must be 2–4 s")
				_text(wn + "/voice", m.get("t"), D.MAX_BUBBLE, trig)
	# reachability + no cycles + every path ends; path stats
	var reach: = {}
	var stats: = {"paths": 0, "min": 999, "max": 0, "aff": 0, "cycle": false}
	_walk(t, start, [], 0, 0, reach, stats)
	if stats.cycle:
		_e(w, "cycle in the dialogue graph")
	for name in nodes:
		if not reach.has(name):
			_e(w, "unreachable node %s" % name)
	if stats.paths == 0:
		_e(w, "no path reaches an end")
	if stats.min < D.MIN_MSGS:
		_e(w, "shortest path has %d heroine messages (< %d)" % [stats.min, D.MIN_MSGS])
	if stats.max > D.MAX_MSGS:
		_e(w, "longest path has %d heroine messages (> %d)" % [stats.max, D.MAX_MSGS])
	if stats.aff + D.DONE_AFF > D.MAX_THREAD_AFF:
		_e(w, "a path gives %d affection (> %d)" % [stats.aff + D.DONE_AFF, D.MAX_THREAD_AFF])


static func _walk(t: Dictionary, name: String, stack: Array, msgs: int, aff: int, reach: Dictionary, stats: Dictionary) -> void:
	if name in stack:
		stats.cycle = true
		return
	if stack.size() > 64:
		stats.cycle = true
		return
	reach[name] = true
	var n: Dictionary = t.nodes.get(name, {})
	var m: int = msgs + n.get("msgs", []).size()
	var st2: = stack + [name]
	if n.get("end", false):
		stats.paths += 1
		stats.min = mini(stats.min, m)
		stats.max = maxi(stats.max, m)
		stats.aff = maxi(stats.aff, aff)
		return
	if n.has("next"):
		if t.nodes.has(str(n.next)):
			_walk(t, str(n.next), st2, m, aff, reach, stats)
		return
	for c in n.get("choices", []):
		if t.nodes.has(str(c.get("next", ""))):
			_walk(t, str(c.next), st2, m, aff + int(c.get("aff", 0)), reach, stats)
