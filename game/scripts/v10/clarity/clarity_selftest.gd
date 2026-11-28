class_name V10ClaritySelftest
extends Node

# Selftest of the clarity lane: every label the game data can show has a glossary entry with a clear name and a
# non-empty «за что», texts fit their limits, clear names never repeat (one concept — one word), no kana in a main
# label, every old name maps back to its entry, icon specs are valid, and the tile bubble tells the right reason.
# Run:  godot --headless --path game res://scripts/v10/clarity/clarity_selftest.tscn   → «V10 CLARITY SELFTEST n/n»
# (V10Clarity's screenshot tour runs it too.)

var ok: = 0
var total: = 0
var fails: = []

func _ready() -> void:
	await get_tree().process_frame
	var r: = run(self)
	print("V10 CLARITY SELFTEST %d/%d" % [r.ok, r.total])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--v10_dump="):
			dump(a.substr(11))
	for f in r.fails:
		print("  FAIL: ", f)
	get_tree().quit(0 if r.ok == r.total else 1)

# the glossary as a Markdown table (GLOSSARY.md next to this file is generated with --v10_dump=<abs path>)
static func dump(path: String) -> void:
	var out: = PackedStringArray()
	out.append("# Словарь Tile Waifu (сгенерировано из V10Glossary, не править руками)\n")
	for c in V10Glossary.CATS:
		var es: = V10Glossary.entries(c[0])
		if es.is_empty():
			continue
		out.append("\n## %s\n" % c[1])
		out.append("| id | Имя | Подпись | За что | Как получить снова | Награда | Было в игре |")
		out.append("|---|---|---|---|---|---|---|")
		for e in es:
			out.append("| `%s` | %s | %s | %s | %s | %s | %s |" % [e.id, e.name, e.sub, e.why, e.how, e.reward, ", ".join(PackedStringArray(e.was))])
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(out) + "\n")
		print("GLOSSARY DUMP ", path)

func _t(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)

static func run(host: Node) -> Dictionary:
	var s: = V10ClaritySelftest.new()
	s._all(host)
	var out: = {"ok": s.ok, "total": s.total, "fails": s.fails}
	s.free()
	return out

func _need(id: String, src: String) -> void:
	_t(V10Glossary.has(id), "%s: no glossary entry %s" % [src, id])

func _all(host: Node) -> void:
	# 1. every table the audit scanned → an entry
	for k in G.YAKU:
		_need("bonus.%s" % k, "G.YAKU")
	for c in G.CATS.size():
		_need("set.%d" % c, "set:N")
		_need("suit.%d" % c, "G.CATS")
	for f in G.FORTUNES:
		_need("fortune.%s" % f.id, "G.FORTUNES")
	for k in V6Specials.NAMES:
		_need("special.%s" % k, "V6Specials.NAMES")
	for k in V6Specials.EVENTS:
		_need("event.%s" % k, "V6Specials.EVENTS")
	for t in V7Combo.TIERS:
		_need("combo.%d" % int(t[0]), "V7Combo.TIERS")
	for i in V7AlbumData.FACE_NAMES.size():
		_need("face.%d" % i, "FACE_NAMES")
	_t(V7AlbumData.FACE_NAMES.size() == G.TILE_NAMES.size(), "FACE_NAMES matches TILE_NAMES")
	for i in G.RANKS.size():
		_need("rank.%d" % i, "G.RANKS")
	for i in V7Ladder.LEAGUES.size():
		_need("league.%d" % i, "V7Ladder.LEAGUES")
	for k in V9Ults.MODS:
		_need("mod.%s" % k, "V9Ults.MODS")
	for k in V7Lines.EGG_NAMES:
		_need("egg.%s" % k, "V7Lines.EGG_NAMES")
	for id in ["win.base", "win.stars", "win.gems", "win.affinity", "win.rank", "win.week", "win.season", "win.album", "win.shard",
			"win.item", "win.helps", "win.overflow", "combo.what", "combo.fever", "combo.streak", "event.box_star", "event.jackpot",
			"state.free", "state.blocked", "state.pair", "state.tray", "state.gold", "state.flip", "state.secret", "state.shard", "state.mark", "ult.meter"]:
		_need(id, "victory / tile labels")
	# 2. every old in-game name maps back to an entry (the selftest of «one concept — one word»)
	var old: = []
	for k in G.YAKU:
		old.append(String(G.YAKU[k].name))
	for c in G.CATS:
		old.append(String(c[2]))
	for f in G.FORTUNES:
		old.append(String(f.name))
	for k in V6Specials.NAMES:
		old.append(String(V6Specials.NAMES[k][0]))
	for k in V6Specials.EVENTS:
		old.append(String(V6Specials.EVENTS[k][0]))
	for t in V7Combo.TIERS:
		old.append(String(t[1]))
	for k in V7Lines.EGG_NAMES:
		old.append(String(V7Lines.EGG_NAMES[k]))
	for k in V9Ults.MODS:
		old.append(String(V9Ults.MODS[k].name))
	for n in ["Полнолуние ×2", "Лихорадка", "Счастливая серия", "Звёздный миг", "Риичи", "Осколок портрета", "Альбом", "Квартал", "Победа"]:
		old.append(n)
	for n in old:
		_t(not V10Glossary.find_by_name(n).is_empty(), "old name «%s» maps to no entry" % n)
	# 3. entry quality
	var names: = {}
	var kana: = RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{4e00}-\\x{9fff}]")
	var kinds: = ["art", "cur", "rank", "league", "tile", "suit", "state", "spec", "combo", "glyph"]
	for id in V10Glossary.all_ids():
		var e: = V10Glossary.get_entry(id)
		var nm: String = e.name
		_t(nm.strip_edges() != "", "%s: empty name" % id)
		_t(String(e.why).strip_edges() != "", "%s: empty why" % id)
		_t(nm.length() <= V10Glossary.NAME_MAX, "%s: name too long (%d) «%s»" % [id, nm.length(), nm])
		_t(String(e.get("sub", "")).length() <= V10Glossary.SUB_MAX, "%s: sub too long «%s»" % [id, e.sub])
		_t(String(e.why).length() <= V10Glossary.WHY_MAX, "%s: why too long (%d) «%s»" % [id, String(e.why).length(), e.why])
		_t(String(e.how).length() <= V10Glossary.HOW_MAX, "%s: how too long (%d)" % [id, String(e.how).length()])
		_t(String(e.reward).length() <= V10Glossary.REWARD_MAX, "%s: reward too long (%d) «%s»" % [id, String(e.reward).length(), e.reward])
		_t(kana.search(nm) == null, "%s: kana/kanji in the main label «%s»" % [id, nm])
		_t(not names.has(nm.to_lower()), "%s: name «%s» repeats %s" % [id, nm, names.get(nm.to_lower(), "")])
		names[nm.to_lower()] = id
		_t(e.cat in V10Glossary.CATS.map(func(c): return c[0]), "%s: unknown cat %s" % [id, e.cat])
		var k: String = String(e.icon).split("|")[0].split(":")[0]
		_t(k in kinds, "%s: bad icon spec %s" % [id, e.icon])
		# every visible field, not only «за что» (the «перевёртыш · «лёд»» sub slipped through before)
		var vis: = ("%s|%s|%s|%s|%s" % [nm, e.sub, e.why, e.how, e.reward]).to_lower()
		_t(not ("лёд" in vis or "льд" in vis), "%s: says «лёд» (the tile is «Рубашка»)" % id)
		_t(not ("риичи" in vis), "%s: says «риичи» (one name: «Ва-банк»)" % id)
		_t(not ("№" in vis), "%s: shows a picture number (players paired by digits)" % id)
		if not (String(id).begins_with("face.") or String(id).begins_with("suit.")):
			_t(not ("бант" in vis), "%s: says «бант» (Бант is a picture; the gift is «с коробочкой»)" % id)
		for oldn in ["букет", "небосвод", "сладкоежк", "сокровищниц", "зверинец", "квартал", "осколок", "ульта", "марки", "марок"]:
			_t(not (oldn in vis), "%s: shows the old name «%s» (one concept — one word)" % [id, oldn])
	# 4. suits / faces helpers
	for f in 36:
		var c: = V10Glossary.suit_of(f)
		_t(c >= 0 and c < 5, "face %d has a suit" % f)
		_t(V10Glossary.face_index(f) >= 1 and V10Glossary.face_index(f) <= 8, "face %d index 1..8" % f)
	_t(V10Glossary.suit_of(100) == -1 and V10Glossary.suit_of(300) == -1, "shard / joker have no suit")
	var glyphs: = {}
	for c in 5:
		glyphs[V10Glossary.suit_glyph(c)] = true
	_t(glyphs.size() == 5, "5 different suit shapes (colour-blind safe)")
	# 5. pairing rule: identical faces only (TrayBoard.tap: x.face == t.face) — no flower/season groups
	var b: = TrayBoard.new()
	host.add_child(b)
	var cfg: Dictionary = TWLevels.at(min(8, G.LEVELS.size() - 1)).duplicate(true)
	b.setup(cfg)
	var by_face: = {}
	for t in b.tiles:
		by_face[t.face] = int(by_face.get(t.face, 0)) + 1
	var even: = true
	for f in by_face:
		if int(by_face[f]) % 2 != 0:
			even = false
	_t(even, "every face comes in pairs on a dealt board")
	# 6. the blocked reason is exact: covered → «Сверху», side-locked → «бок»
	var top_ok: = false
	var side_ok: = false
	for t in b.tiles:
		var covered: = false
		for o in b.cov[t]:
			if b.on_board(o):
				covered = true
		var r: = V10Glossary.blocked_reason(b, t)
		if covered and r.begins_with("Сверху"):
			top_ok = true
		if not covered and not b.is_free(t) and "бок" in r:
			side_ok = true
		if b.is_free(t):
			_t(r == "", "free tile has no blocked reason")
		var d: = V10TileInfo.describe(b, t)
		_t(String(d.title) != "" and String(d.status) != "", "bubble text for tile %d" % t.face)
		var dtx: = ("%s %s %s" % [d.sub, " ".join(PackedStringArray(d.lines)), d.status]).to_lower()
		_t(not ("№" in dtx) and not ("бант" in dtx and t.face != 23), "bubble of tile %d: no number, no «бант» for the gift" % t.face)
	_t(top_ok, "a covered tile says «Сверху лежит…»")
	_t(side_ok or b.tiles.all(func(t): return b.is_free(t) or not b.cov[t].filter(func(o): return b.on_board(o)).is_empty()), "a side-locked tile says «…бок»")
	b.queue_free()
	# 7. victory lines
	_t(V10Glossary.star_rule().length() <= 60, "star rule fits one line")
	_t(V10Glossary.stats_line(72, 1, 0) == "Время 1:12 · Подсказок 1 · Лоток переполнялся 0", "stats line")
	_t(V10Glossary.bonus_id("set:2") == "set.2" and V10Glossary.bonus_id("clean") == "bonus.clean", "bonus ids")
	_t(V10Glossary.tip("bonus.calm").begins_with("Аккуратный лоток — "), "tutorial tip line")
	# 8. one name on the table and the victory screen: «Ва-банк», never «Риичи» (the real mahjong mode keeps it)
	for k in ["play.riichi", "play.win_riichi", "play.riichi_locked", "play.riichi_burnt", "play.no_yaku", "play.shard"]:
		var tx: = V6Txt.s(k).to_lower()
		_t(not ("риичи" in tx or "осколок" in tx), "V6Txt %s still says «%s»" % [k, V6Txt.s(k)])
	_t(String(G.YAKU.riichi.name) == "Ва-банк", "G.YAKU.riichi is «Ва-банк»")
	_t(not ("вартал" in V8PlayRules.T.quarter), "the season line says «Сезон»")
	# 9. «Почему так?» crystals ALWAYS add up to the big number (reward + gained, what play._victory rolls)
	for c in [[180, 3, false, 0], [180, 3, true, 0], [180, 2, true, 40], [120, 1, false, 75], [0, 0, false, 30]]:
		var base: int = c[0]
		var st: int = c[1]
		var rch: bool = c[2]
		var gn: int = c[3]
		var reward: = base + st * 20
		if rch:
			reward = reward * 2 + gn
		var fake: = {"gained": gn, "riichi": rch, "mode": "" if base > 0 else "trial", "cfg": {"reward": {"gems": base}}}
		var cm: = V10Breakdown.crystal_math(fake, st, reward)
		_t(int(cm.total) == reward + gn and int(cm.sum) == reward + gn, "crystals add up: %s → %d = %s" % [str(c), reward + gn, cm.text])
		_t(("%d" % (reward + gn)) in String(cm.text) or reward + gn == 0, "crystal formula ends with the total %d: %s" % [reward + gn, cm.text])
	# 10. one word per suit
	_t(V10Glossary.SUIT_LOOK.all(func(l): return String(l.name).to_lower() == String(l.short)), "each suit has ONE name (name == short)")
