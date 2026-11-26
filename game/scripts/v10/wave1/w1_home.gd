class_name V10W1Home
extends RefCounted

# 0.10 wave 1 (docs/ROSTER_20.md §3.2–3.4): the home side of Цубамэ, Миэль, Кохаку, Ширин and Злата — touch lines,
# eggs and day/night greetings, barks, «Письма», her arrival in the salon, her room (gifts, dates, scenes).
# Pure data + small static helpers, NOT gated here: V10Wave1 merges every table into its founders' consumer only while
# V10Wave1.released() (the hooks list is in merges() and in the lane report), so the founders play exactly as before.
#
# The text lives in V10W1HomeLines (w1_home_lines.gd); this file holds the non-text tables and the helpers:
#   ROOMS, PREFS, FAV            -> V7RoomData.ROOMS / PREFS / FAV        her room backdrop, gift taste, favourite place
#   HAND, HAND_R                 -> V9Touch.RIG_HAND / RIG_HAND_R         the prop hand on her cut-out (art px)
#   COURIER                      «Письма» delivered by Цубамэ (0.9-spec §C, ROSTER tsubame «Кто»)
#   merges()                     [consumer, wave-1 table, nested] — what V10Wave1 merges when released
#   pending_arrival(seen, G.hero_unlocked) / arrival_play(h) her arrival scene (story schema, or the room-scene runner form)
#   self_check() -> Array        [] = every table complete, in schema, within the founders' line lengths, clean
#
# Lengths: LIMITS / BARK_LIMITS are the founders' longest string per field on this branch (chars, measured with
# Godot over V9TouchLines / V7Lines / V9LetterText / V6Txt / V7RoomData / V7RoomScenes / V6Scenes); wave 1 stays ≤.

const IDS: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]

# ------------------------------------------------------------------ V7RoomData.ROOMS / PREFS / FAV
# backdrops that exist in the game today (wave 1 has no room art of its own): the roof at dusk for the courier, the
# pink tea-and-sweets interior for the pastry shop, the torii shrine for the fox, the lantern canal for the caravan,
# Злата's own black-lacquer firebird panel (v10 look lane) for her terem
const ROOMS: = {
	"tsubame": {"bg": "res://assets/bg/bg_rooftop.webp", "name": "Крыша гильдии", "fx": "mist", "focus": Vector2(0.55, 0.5)},
	"miel": {"bg": "res://assets/bg/menu.webp", "name": "«Мёд и пар»", "fx": "petals", "focus": Vector2(0.5, 0.42)},
	"kohaku": {"bg": "res://assets/bg/bg_shrine.webp", "name": "Тысяча врат", "fx": "embers", "focus": Vector2(0.45, 0.5)},
	"shirin": {"bg": "res://assets/bg/bg_festival.webp", "name": "Стоянка каравана", "fx": "stars", "focus": Vector2(0.5, 0.5)},
	"zlata": {"bg": "res://assets/v10/look/zlata/menu_bg.webp", "name": "Лаковый терем", "fx": "embers", "focus": Vector2(0.5, 0.45)},
}

# gift ids of V7RoomData.GIFTS: love 3, like 3–4 (as the founders)
const PREFS: = {
	"tsubame": {"love": ["bow", "windchime", "dango"], "like": ["matcha", "lantern", "moon"]},
	"miel": {"love": ["matcha", "bow", "sakura"], "like": ["cake", "bubbletea", "dango", "butterfly"]},
	"kohaku": {"love": ["lantern", "windchime", "dango"], "like": ["sakura", "matcha", "butterfly"]},
	"shirin": {"love": ["lantern", "diamond", "moon"], "like": ["butterfly", "bubbletea", "windchime"]},
	"zlata": {"love": ["sakura", "cake", "butterfly"], "like": ["lantern", "bow", "dango", "diamond"]},
}

# V7RoomData.PLACES key she likes most (a date there counts as her favourite)
const FAV: = {"tsubame": "rooftop", "miel": "street", "kohaku": "shrine", "shirin": "palace", "zlata": "festival"}

# ------------------------------------------------------------------ V9Touch.RIG_HAND / RIG_HAND_R
# the hand with her prop, measured on the cut-outs game/assets/v10/wave1/hero/<id>.png (848×1264, this branch):
# Цубамэ the envelope held out to the right, Миэль the cupcake on her palm, Ширин her open right palm (arm spread),
# Злата the glowing braid tip in both hands. Кохаку keeps her hands in her sleeves at the waist: no hand zone (as
# Юэ's fan, V9Touch). The chest / hip guard of V9Touch.classify still runs first.
const HAND: = {"tsubame": Vector2(780, 215), "miel": Vector2(618, 410), "shirin": Vector2(775, 335), "zlata": Vector2(433, 502)}
const HAND_R: = {"tsubame": 58.0, "miel": 46.0, "shirin": 55.0, "zlata": 44.0}
const ART_SIZE: = Vector2(848, 1264)

# ------------------------------------------------------------------ «Письма»: Цубамэ delivers them
# a short courier line for a new letter from someone else (%s = the sender's name); a toast / the letters screen
# header may show it (optional hook). Her own letters carry her signature instead.
const COURIER: = ["Письмо от %s. Печать цела. Доставлено.", "%s просила передать лично. Держи.",
	"Почта. Отправитель — %s. Лично в руки.", "От %s. Срочно, но бережно. Доставлено."]

# ------------------------------------------------------------------ arrival scene (V6Scenes schema, played once)
const ARRIVAL_BG: = "res://assets/bg/play.webp"

# her outfits (G.ITEM ids, V10W1Core.ITEMS): room-scene photos must be one of these
const OUTFITS: = {
	"tsubame": ["tb_base", "tb_post", "tb_crimson"],
	"miel": ["me_base", "me_parlor", "me_gala"],
	"kohaku": ["ko_base", "ko_matsuri", "ko_kyubi", "ko_vow"],
	"shirin": ["sh_base", "sh_oasis", "sh_sun", "sh_night"],
	"zlata": ["zl_base", "zl_fair", "zl_ember", "zl_vow"],
}

# ------------------------------------------------------------------ schema + limits (self_check)
const ZONES: = ["head", "hand", "outfit", "bg", "spam", "idle"]
const ZONE_COUNT: = {"head": 4, "hand": 3, "outfit": 3, "bg": 3, "spam": 2, "idle": 3}
const PHASES: = ["morning", "day", "evening", "night"]
const EVENTS: = ["first_win", "combo", "rank", "comeback"]
const SCENE_LV: = [2, 4, 7, 10]
const SCENE_AFF: = {2: [8, 5], 4: [8, 6], 7: [10, 6], 10: [15, 10]}
const AMBIENT: = ["petals", "snow", "lanterns", "fireflies", "mist", "rain", "embers", "stars"]
const STORY_EMO: = ["", "happy", "big", "sad", "tap", "shy", "pout", "surprised"]
const ROOM_EMO: = ["", "happy", "big", "sad", "tap", "shy"]
const PLACEHOLDERS: = ["{nick}", "{combo}", "{rank}", "{days}"]

const LIMITS: = {
	"touch.head": 57, "touch.hand": 60, "touch.outfit": 53, "touch.bg": 52, "touch.spam": 52, "touch.idle": 49,
	"eggs.greet": 61, "eggs.clock": 68, "eggs.date": 77, "eggs.tickle": 58, "eggs.star": 85, "eggs.cameo": 63,
	"eggs.cameo_locked": 59, "eggs.peek": 41,
	"letter.subj": 24, "letter.body": 235, "letter.reply": 34, "letter.answer": 73, "letter.sign": 11, "letter.ps": 47,
	"room.name": 20, "room.gift": 66, "room.line": 79, "room.opener": 96, "room.moment_q": 73, "room.moment_pick": 58,
	"room.moment_reply": 74, "room.ending": 83,
	"rscene.title": 19, "rscene.narr": 117, "rscene.say": 132, "rscene.pick": 37, "rscene.reply": 76, "rscene.black": 117,
	"rscene.cap": 19,
	"story.narr": 128, "story.say": 130, "story.pick": 34, "story.reply": 96, "story.title": 26,
	"courier": 47,
}
const BARK_LIMITS: = {"greet": 68, "match": 28, "combo": 49, "fever": 45, "win": 52, "lose": 46, "gacha": 33, "ssr": 34,
	"outfit": 53, "aff": 70, "hint": 34, "yaku": 48, "riichi": 48, "rankup": 40, "tap": 47, "start": 44, "boss": 60,
	"tray_warn": 51, "skill_ready": 47, "skill": 38, "ice": 35, "flip": 26, "gift": 48, "shard": 49, "idle": 45, "last": 42,
	"blitz_end": 47}

# on top of V10Lint.BANNED: the 0.9 red-line list (letters_selftest / chat_data) and the UX jargon (UX_RULES §4.2–4.3)
const EXTRA_BANNED: = ["бесплатн", "руб.", "рубл", "донат", "призыв", "учител", "ученик", "урок", "школ", "за парт",
	"куда смотришь", "колен", "грудь", "бёдр", "бедр", "вино", "пиво", "алкогол", "раздев", "бельё", "белье",
	"гарант", "пити", "гача", "крутк", "фивер", "ивент", "ульт", "квартал", "перк", "богин", "визит", "лихорадк",
	"риичи", "яку", "гардероб", "поручени", "сесть за стол", "следующая партия", "осколок портрета"]
# Latin allowed in heroine text: the rarity name and «P.S.» (founders write both)
const LATIN_OK: = ["SSR", "P.S."]


# ------------------------------------------------------------------ lookups

static func has(h: String) -> bool:
	return h in IDS


static func touch_pool(h: String, zone: String) -> Array:
	return V10W1HomeLines.TOUCH.get(h, {}).get(zone, [])


# the prop hand on her cut-out (Vector2.ZERO = no hand zone)
static func hand(h: String) -> Vector2:
	return HAND.get(h, Vector2.ZERO)


static func hand_r(h: String) -> float:
	return float(HAND_R.get(h, 50.0))


static func greet(h: String, phase: String) -> Array:
	return V10W1HomeLines.TIME_GREET.get(h, {}).get(phase, [])


# her override of a V7Lines.CLOCK / DATES line, else `fallback`
static func clock_line(hm: String, h: String, fallback: = "") -> String:
	return String(V10W1HomeLines.CLOCK.get(hm, {}).get(h, fallback))


static func date_line(md: String, h: String, fallback: = "") -> String:
	return String(V10W1HomeLines.DATES.get(md, {}).get(h, fallback))


# kind: tickle | star | cameo | cameo_locked | peek
static func egg(kind: String, h: String) -> String:
	var t: Dictionary = {"tickle": V10W1HomeLines.TICKLE, "star": V10W1HomeLines.STAR, "cameo": V10W1HomeLines.CAMEO,
		"cameo_locked": V10W1HomeLines.CAMEO_LOCKED, "peek": V10W1HomeLines.PEEK_PLAY}.get(kind, {})
	return String(t.get(h, ""))


static func barks(h: String, kind: String) -> Array:
	return V10W1HomeLines.BARKS.get(h, {}).get(kind, [])


static func letters(h: String, ev: String) -> Array:
	return V10W1HomeLines.LETTERS.get(h, {}).get(ev, [])


static func courier_line(sender_name: String, i: = -1) -> String:
	var k: = i if i >= 0 else randi() % COURIER.size()
	return String(COURIER[posmod(k, COURIER.size())]) % sender_name


static func arrival_id(h: String) -> String:
	return "arrive_" + h


# the first wave-1 heroine the player has whose arrival was never played ("" = none);
# `seen` = V6Story.st().seen, `unlocked` = G.hero_unlocked (passed in: autoloads are out of scope here)
static func pending_arrival(seen: Dictionary, unlocked: Callable) -> String:
	for h in IDS:
		if bool(unlocked.call(h)) and not seen.has(arrival_id(h)):
			return h
	return ""


# the arrival in the V7RoomScene.run form (no story-scene hook needed): {bg_path, fx, focus, title, cast, lines}
static func arrival_play(h: String) -> Dictionary:
	var id: = arrival_id(h)
	var d: Dictionary = V10W1HomeLines.ARRIVALS.get(id, {})
	if d.is_empty():
		return {}
	return {"bg_path": ARRIVAL_BG, "fx": String(d.get("fx", "")), "focus": Vector2(0.5, 0.45),
		"title": String(V10W1HomeLines.ARRIVAL_TITLES.get(id, "")), "cast": d.cast, "lines": d.lines}


static func scene_ids(h: String) -> Array:
	var out: = []
	for lv in SCENE_LV:
		var id: = "%s_%d" % [h, lv]
		if V10W1HomeLines.ROOM_SCENES.has(id):
			out.append(id)
	return out


# ------------------------------------------------------------------ merges (V10Wave1 applies them when released)
# [consumer table, wave-1 table, nested]. nested = the consumer is keyed by minute / day first (V7Lines.CLOCK, DATES):
# merge per key, never replace the founders' «*» line. The consumers' `const` tables become `static var` (hooks).
static func merges() -> Array:
	return [
		["V9TouchLines.LINES", V10W1HomeLines.TOUCH, false],
		["V9Touch.RIG_HAND", HAND, false],
		["V9Touch.RIG_HAND_R", HAND_R, false],
		["V7Lines.TIME_GREET", V10W1HomeLines.TIME_GREET, false],
		["V7Lines.CLOCK", V10W1HomeLines.CLOCK, true],
		["V7Lines.DATES", V10W1HomeLines.DATES, true],
		["V7Lines.TICKLE", V10W1HomeLines.TICKLE, false],
		["V7Lines.STAR", V10W1HomeLines.STAR, false],
		["V7Lines.CAMEO", V10W1HomeLines.CAMEO, false],
		["V7Lines.CAMEO_LOCKED", V10W1HomeLines.CAMEO_LOCKED, false],
		["V7Lines.PEEK_PLAY", V10W1HomeLines.PEEK_PLAY, false],
		["V6Txt.LINES", V10W1HomeLines.BARKS, false],
		["V9LetterText.SIGN", V10W1HomeLines.SIGN, false],
		["V9LetterText.PS", V10W1HomeLines.PS, false],
		["V9LetterText.LETTERS", V10W1HomeLines.LETTERS, false],
		["V6Scenes.SCENES", V10W1HomeLines.ARRIVALS, false],
		["V6Scenes.TITLES", V10W1HomeLines.ARRIVAL_TITLES, false],
		["V7RoomData.ROOMS", ROOMS, false],
		["V7RoomData.PREFS", PREFS, false],
		["V7RoomData.FAV", FAV, false],
		["V7RoomData.GIFT_LINES", V10W1HomeLines.GIFT_LINES, false],
		["V7RoomData.ROOM_LINES", V10W1HomeLines.ROOM_LINES, false],
		["V7RoomData.OPENERS", V10W1HomeLines.OPENERS, false],
		["V7RoomData.MOMENTS", V10W1HomeLines.MOMENTS, false],
		["V7RoomData.ENDINGS", V10W1HomeLines.ENDINGS, false],
		["V7RoomScenes.SCENES", V10W1HomeLines.ROOM_SCENES, false],
	]


# merge one wave-1 table into its (mutable) consumer table; founders' keys are never overwritten
static func merge_into(dst: Dictionary, src: Dictionary, nested: = false) -> void:
	for k in src:
		if nested:
			if not dst.has(k):
				dst[k] = {}
			var sub: Dictionary = dst[k]
			for h in src[k]:
				if not sub.has(h):
					sub[h] = src[k][h]
		elif not dst.has(k):
			dst[k] = src[k]


# ------------------------------------------------------------------ every visible string (lint, shots)
# [field, text, where]; field keys LIMITS / "bark.<kind>"
static func strings() -> Array:
	var out: = []
	var L: = V10W1HomeLines
	for h in IDS:
		for z in L.TOUCH.get(h, {}):
			for e in L.TOUCH[h][z]:
				out.append(["touch." + z, String(e.get("t", "")), "%s touch.%s" % [h, z]])
		for p in L.TIME_GREET.get(h, {}):
			for s in L.TIME_GREET[h][p]:
				out.append(["eggs.greet", String(s), "%s greet.%s" % [h, p]])
		for k in ["tickle", "star", "cameo", "cameo_locked", "peek"]:
			out.append(["eggs." + k, egg(k, h), "%s egg.%s" % [h, k]])
		for kind in L.BARKS.get(h, {}):
			for s in L.BARKS[h][kind]:
				out.append(["bark." + kind, String(s), "%s bark.%s" % [h, kind]])
		out.append(["letter.sign", String(L.SIGN.get(h, "")), h + " sign"])
		out.append(["letter.ps", String(L.PS.get(h, "")), h + " ps"])
		for ev in L.LETTERS.get(h, {}):
			for i in L.LETTERS[h][ev].size():
				var v: Dictionary = L.LETTERS[h][ev][i]
				var w: = "%s letter.%s#%d" % [h, ev, i]
				out.append(["letter.subj", String(v.get("subj", "")), w])
				out.append(["letter.body", String(v.get("body", "")), w])
				for r in v.get("replies", []):
					out.append(["letter.reply", String(r), w])
				for a in v.get("answers", []):
					out.append(["letter.answer", String(a), w])
		if ROOMS.has(h):
			out.append(["room.name", String(ROOMS[h].name), h + " room"])
		for t in L.GIFT_LINES.get(h, {}):
			for s in L.GIFT_LINES[h][t]:
				out.append(["room.gift", String(s), "%s gift.%s" % [h, t]])
		for tier in L.ROOM_LINES.get(h, []):
			for s in tier:
				out.append(["room.line", String(s), h + " room_line"])
		for p in L.OPENERS.get(h, {}):
			out.append(["room.opener", String(L.OPENERS[h][p]), "%s opener.%s" % [h, p]])
		for m in L.MOMENTS.get(h, []):
			out.append(["room.moment_q", String(m.q), h + " moment"])
			for a in m.a:
				out.append(["room.moment_pick", String(a[0]), h + " moment"])
				out.append(["room.moment_reply", String(a[1]), h + " moment"])
		for s in L.ENDINGS.get(h, []):
			out.append(["room.ending", String(s), h + " ending"])
		for id in scene_ids(h):
			_scene_strings(out, "rscene", L.ROOM_SCENES[id], id)
			out.append(["rscene.title", String(L.ROOM_SCENES[id].title), id])
		var aid: = arrival_id(h)
		if L.ARRIVALS.has(aid):
			_scene_strings(out, "story", L.ARRIVALS[aid], aid)
			out.append(["story.title", String(L.ARRIVAL_TITLES.get(aid, "")), aid])
	for hm in L.CLOCK:
		for h in L.CLOCK[hm]:
			out.append(["eggs.clock", String(L.CLOCK[hm][h]), "%s clock %s" % [h, hm]])
	for md in L.DATES:
		for h in L.DATES[md]:
			out.append(["eggs.date", String(L.DATES[md][h]), "%s date %s" % [h, md]])
	for c in COURIER:
		out.append(["courier", String(c) % "Маджонг-тян", "courier"])
	return out


static func _scene_strings(out: Array, kind: String, d: Dictionary, id: String) -> void:
	for e in d.lines:
		if e is Array:
			out.append([kind + (".narr" if String(e[0]) == "" else ".say"), String(e[1]), id])
		elif e is Dictionary and e.has("ask"):
			for o in e.ask:
				out.append([kind + ".pick", String(o[0]), id])
				out.append([kind + ".reply", String(o[1]), id])
		elif e is Dictionary and e.has("black"):
			out.append([kind + ".black", String(e.black), id])
		elif e is Dictionary and e.has("cap"):
			out.append([kind + ".cap", String(e.cap), id])


# the banned fragments in one string (V10Lint.BANNED with its ALLOW list, plus EXTRA_BANNED)
static func lint(text: String) -> Array:
	var bad: = V10Lint.check(text)
	for u in V10Lint.ui_check(text):
		if not (u in bad):
			bad.append(u)
	var low: = text.to_lower()
	for w in EXTRA_BANNED:
		if low.find(w) >= 0 and not (w in bad):
			bad.append(w)
	return bad


static func _latin(text: String) -> bool:
	var t: = text
	for p in PLACEHOLDERS + LATIN_OK:
		t = t.replace(p, "")
	for i in t.length():
		var c: = t.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return true
	return false


# ------------------------------------------------------------------ self check ([] = all good)
static func self_check() -> Array:
	var bad: = []
	var L: = V10W1HomeLines
	var tables: = {"TOUCH": L.TOUCH, "TIME_GREET": L.TIME_GREET, "TICKLE": L.TICKLE, "STAR": L.STAR, "CAMEO": L.CAMEO,
		"CAMEO_LOCKED": L.CAMEO_LOCKED, "PEEK_PLAY": L.PEEK_PLAY, "BARKS": L.BARKS, "SIGN": L.SIGN, "PS": L.PS,
		"LETTERS": L.LETTERS, "GIFT_LINES": L.GIFT_LINES, "ROOM_LINES": L.ROOM_LINES, "OPENERS": L.OPENERS,
		"MOMENTS": L.MOMENTS, "ENDINGS": L.ENDINGS, "ROOMS": ROOMS, "PREFS": PREFS, "FAV": FAV}
	for tn in tables:
		var t: Dictionary = tables[tn]
		if t.size() != IDS.size():
			bad.append("%s: %d entries, want %d" % [tn, t.size(), IDS.size()])
		for h in IDS:
			if not t.has(h):
				bad.append("%s: no %s" % [tn, h])
		for h in FOUNDERS:
			if t.has(h):
				bad.append("%s: overrides founder %s" % [tn, h])
	if not bad.is_empty():
		return bad
	# room data / art consts read off their scripts: both name the G autoload, which --check-only cannot see
	var rd: = _consts("res://scripts/v07/room/room_data.gd")
	var gift_ids: Array = (rd.get("GIFTS", []) as Array).map(func(g): return String(g.id))
	var places: Array = (rd.get("PLACES", {}) as Dictionary).keys()
	var emotions: Array = _consts("res://scripts/v08/hud/art.gd").get("EMOTIONS", [])
	for h in IDS:
		# touch: every zone, Маджонг-тян's counts, emotions with art
		for z in ZONES:
			var p: Array = L.TOUCH[h].get(z, [])
			if p.size() != int(ZONE_COUNT[z]):
				bad.append("%s touch.%s: %d lines, want %d" % [h, z, p.size(), ZONE_COUNT[z]])
			for e in p:
				if String(e.get("t", "")) == "" or not (String(e.get("e", "")) in emotions):
					bad.append("%s touch.%s: entry %s" % [h, z, str(e)])
		for ph in PHASES:
			if (L.TIME_GREET[h].get(ph, []) as Array).size() != 2:
				bad.append("%s greet.%s: want 2" % [h, ph])
		var own_clock: = 0
		for hm in L.CLOCK:
			if L.CLOCK[hm].has(h):
				own_clock += 1
		var own_date: = 0
		for md in L.DATES:
			if L.DATES[md].has(h):
				own_date += 1
		if own_clock < 1 or own_date < 1:
			bad.append("%s: no special minute / day line" % h)
		# barks: every kind of the founders, at least Маджонг-тян's count
		for kind in V6Txt.LINES.mc:
			var a: Array = L.BARKS[h].get(kind, [])
			if a.size() < (V6Txt.LINES.mc[kind] as Array).size():
				bad.append("%s bark.%s: %d lines, founders %d" % [h, kind, a.size(), (V6Txt.LINES.mc[kind] as Array).size()])
		var ret: = 0
		for s in L.BARKS[h].greet:
			for m in _return_marks():
				if String(s).contains(m):
					ret += 1
					break
		if ret < 1 or ret >= (L.BARKS[h].greet as Array).size():
			bad.append("%s bark.greet: needs both «return» and fresh greetings" % h)
		# letters
		for ev in EVENTS:
			var vs: Array = L.LETTERS[h].get(ev, [])
			if vs.size() != 2:
				bad.append("%s letter.%s: %d variants, want 2" % [h, ev, vs.size()])
			for v in vs:
				if String(v.get("subj", "")) == "" or String(v.get("body", "")).length() <= 60:
					bad.append("%s letter.%s: subject / body" % [h, ev])
				if not (String(v.get("emo", "")) in emotions):
					bad.append("%s letter.%s: emo" % [h, ev])
				if (v.get("replies", []) as Array).size() != 2 or (v.get("answers", []) as Array).size() != 2:
					bad.append("%s letter.%s: 2 replies + 2 answers" % [h, ev])
				var all: = String(v.subj) + " " + String(v.body) + " " + " ".join(v.replies) + " " + " ".join(v.answers)
				for p in PLACEHOLDERS:
					all = all.replace(p, "")
				if all.contains("{") or all.contains("}"):
					bad.append("%s letter.%s: unknown placeholder" % [h, ev])
		# arrival
		var aid: = arrival_id(h)
		var ad: Dictionary = L.ARRIVALS.get(aid, {})
		if ad.is_empty() or not (h in ad.get("cast", [])) or not L.ARRIVAL_TITLES.has(aid):
			bad.append("%s: arrival scene" % h)
		else:
			bad.append_array(_scene_check(aid, ad, STORY_EMO, true))
			if aid.substr(0, 1) == "w" and aid.substr(1, 1).is_valid_int():
				bad.append("%s: id would get a world prefix" % aid)
			if not (String(ad.get("fx", "")) in AMBIENT):
				bad.append("%s: fx" % aid)
		# room
		if not ResourceLoader.exists(String(ROOMS[h].bg)):
			bad.append("%s room: no backdrop %s" % [h, ROOMS[h].bg])
		if not (String(ROOMS[h].fx) in AMBIENT) or not (ROOMS[h].focus is Vector2):
			bad.append("%s room: fx / focus" % h)
		if (PREFS[h].love as Array).size() != 3 or (PREFS[h].like as Array).size() < 3:
			bad.append("%s prefs: love 3, like 3+" % h)
		for g in PREFS[h].love + PREFS[h].like:
			if not (g in gift_ids):
				bad.append("%s prefs: unknown gift %s" % [h, g])
		if not (FAV[h] in places):
			bad.append("%s fav: unknown place %s" % [h, FAV[h]])
		for t in ["love", "like", "plain"]:
			if (L.GIFT_LINES[h].get(t, []) as Array).size() != 2:
				bad.append("%s gift_lines.%s: want 2" % [h, t])
		if (L.ROOM_LINES[h] as Array).size() != 3:
			bad.append("%s room_lines: want 3 tiers" % h)
		else:
			for tier in L.ROOM_LINES[h]:
				if (tier as Array).size() != 2:
					bad.append("%s room_lines: want 2 per tier" % h)
		for p in places:
			if not L.OPENERS[h].has(p):
				bad.append("%s opener: no %s" % [h, p])
		if (L.MOMENTS[h] as Array).size() != 5:
			bad.append("%s moments: want 5" % h)
		for m in L.MOMENTS[h]:
			var grades: = []
			for a in m.a:
				grades.append(int(a[2]))
			grades.sort()
			if String(m.get("q", "")) == "" or grades != [0, 1, 2]:
				bad.append("%s moment «%s»: 3 answers graded 2 / 1 / 0" % [h, m.get("q", "")])
		if (L.ENDINGS[h] as Array).size() != 3:
			bad.append("%s endings: want 3" % h)
		var ids: = scene_ids(h)
		if ids.size() != SCENE_LV.size():
			bad.append("%s room scenes: %d, want %d" % [h, ids.size(), SCENE_LV.size()])
		for id in ids:
			var sd: Dictionary = L.ROOM_SCENES[id]
			if String(sd.get("hero", "")) != h or not (int(sd.get("lv", 0)) in SCENE_LV) or "%s_%d" % [h, int(sd.lv)] != id:
				bad.append("%s: hero / lv" % id)
			if not (String(sd.get("bg", "")) == "room" or String(sd.get("bg", "")) in places):
				bad.append("%s: bg %s" % [id, sd.get("bg", "")])
			bad.append_array(_scene_check(id, sd, ROOM_EMO, false))
			var photo: = ""
			var black: = false
			for e in sd.lines:
				if e is Dictionary and e.has("photo"):
					photo = String(e.photo)
				if e is Dictionary and e.has("black"):
					black = true
				if e is Dictionary and e.has("ask"):
					var affs: = []
					for o in e.ask:
						affs.append(int(o[2]))
					if affs != SCENE_AFF[int(sd.lv)]:
						bad.append("%s: ask affection %s, founders %s" % [id, str(affs), str(SCENE_AFF[int(sd.lv)])])
			if int(sd.lv) >= 4 and not (photo in OUTFITS[h]):
				bad.append("%s: photo «%s» is not her outfit" % [id, photo])
			if int(sd.lv) == 10 and not black:
				bad.append("%s: the Симпатия 10 scene ends on a «black» beat" % id)
		if HAND.has(h):
			var p: Vector2 = HAND[h]
			if p.x < 0 or p.y < 0 or p.x > ART_SIZE.x or p.y > ART_SIZE.y or not HAND_R.has(h):
				bad.append("%s: hand point" % h)
	# every visible string: length within the founders', stop-words, quotes, no Latin
	for s in strings():
		var field: String = s[0]
		var text: String = s[1]
		var lim: = int(BARK_LIMITS.get(field.substr(5), 0)) if field.begins_with("bark.") else int(LIMITS.get(field, 0))
		if text.strip_edges() == "":
			bad.append("%s: empty %s" % [s[2], field])
			continue
		if lim <= 0:
			bad.append("%s: no limit for %s" % [s[2], field])
		elif text.length() > lim:
			bad.append("%s %s: %d chars > founders' %d «%s»" % [s[2], field, text.length(), lim, text])
		var lb: = lint(text)
		if not lb.is_empty():
			bad.append("%s %s: stop-word %s «%s»" % [s[2], field, str(lb), text])
		if text.count("«") != text.count("»"):
			bad.append("%s %s: unbalanced «» «%s»" % [s[2], field, text])
		if text.contains("\"") or text.contains("'"):
			bad.append("%s %s: straight quotes «%s»" % [s[2], field, text])
		if _latin(text):
			bad.append("%s %s: Latin letters «%s»" % [s[2], field, text])
	return bad


# Sfx.RETURN_MARKS read off the script (the Sfx autoload is out of scope in a RefCounted / --check-only)
static func _return_marks() -> Array:
	return _consts("res://scripts/sfx.gd").get("RETURN_MARKS", [])


# a script's consts without a compile-time dependency on it
static func _consts(path: String) -> Dictionary:
	var sc: = load(path) as GDScript
	return sc.get_script_constant_map() if sc else {}


static func _scene_check(id: String, d: Dictionary, emos: Array, story: bool) -> Array:
	var bad: = []
	var cast: Array = d.get("cast", [d.get("hero", "")])
	var asks: = 0
	for e in d.get("lines", []):
		if e is Array:
			var who: = String(e[0])
			if who != "" and not (who in cast):
				bad.append("%s: speaker %s is not in the cast" % [id, who])
			if e.size() > 2 and not (String(e[2]) in emos):
				bad.append("%s: emotion tag %s" % [id, e[2]])
		elif e is Dictionary and e.has("ask"):
			asks += 1
			if not (String(e.get("who", "")) in cast) or (e.ask as Array).size() != 2:
				bad.append("%s: ask" % id)
			for o in e.ask:
				if (o as Array).size() != 3 or int(o[2]) <= 0:
					bad.append("%s: ask option %s" % [id, str(o)])
		elif e is Dictionary and story:
			bad.append("%s: story scenes take only lines and asks" % id)
	if asks != 1:
		bad.append("%s: %d choices, want 1" % [id, asks])
	return bad
