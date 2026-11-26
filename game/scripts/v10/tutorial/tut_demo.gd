class_name V10TutDemo
extends RefCounted
# HUD v2 screen hosts (Чайная / Партия / Столы / Победа) tagged with README §3 `tut_id` metadata.
# Used by V10TutSelftest across aspect ratios (720×1280, 720×1600, 1536×2048) and for `--tut_shots=<dir>`.

const TILE_DIR: = "res://assets/v08/table/"


class DarkBg extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		size = get_viewport_rect().size
		get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), V10DS.NIGHT_900)


static func make_home(parent: Node, cfg: = {}) -> V10HudHome:
	var h: = V10HudHome.new()
	h.configure({
		"hero": String(cfg.get("hero", "mc")),
		"nick": String(cfg.get("nick", "Гость")),
		"level": String(cfg.get("level", "1-4")),
		"path": String(cfg.get("path", "Чайный сад")),
		"affinity": int(cfg.get("affinity", 2)),
		"lit": cfg.get("lit", [true, true, true]),
		"shown": cfg.get("shown", [true, true, true]),
	})
	parent.add_child(h)
	h.layout_now()
	h.play_b.set_meta("tut_id", "home.play")
	h.phone_b.set_meta("tut_id", "home.phone")
	h.partner.set_meta("tut_id", "home.partner")
	var ids: = ["lantern.today", "lantern.salon", "lantern.streak"]
	for i in mini(3, h.lantern_tr.size()):
		h.lantern_tr[i].set_meta("tut_id", ids[i])
		h.lantern_tr[i].set_meta("tut_radius", 12.0)
	var nav_ids: = ["nav.teahouse", "nav.heroines", "nav.tables", "nav.wishes", "nav.shop"]
	for i in mini(5, h.tab_ls.size()):
		h.tab_ls[i].set_meta("tut_id", nav_ids[i])
	if h.rig != null:
		h.rig.set_meta("tut_id", "home.hero")
		h.rig.set_meta("tut_size", Vector2(240, 480))
	return h


static func make_tables(parent: Node) -> Control:
	var bg: = DarkBg.new()
	parent.add_child(bg)
	var vs: = bg.get_viewport_rect().size
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	V10Header.make(bg, "Столы", Callable(), V10Help.on_help(bg, "tables"))
	var y: = V10Header.content_y(vs) + 16.0
	var scroll_p: = V10Plate.make("L", 656, "Путь · Чайный сад", "Стол 1-5 · ★ 12")
	scroll_p.position = Vector2(cx + 32, y)
	scroll_p.set_meta("ux_role", "secondary")
	bg.add_child(scroll_p)
	y += 160.0 + 32.0
	var pb: = V10Button.make("play", "Играть · 1-5", Vector2(440, 104))
	pb.overline = "Путь · Чайный сад"
	pb.position = Vector2(cx + 140, y)
	pb.set_meta("ux_role", "primary")
	pb.set_meta("tut_id", "tables.play")
	bg.add_child(pb)
	y += 104.0 + 32.0
	var modes: = [
		["tables.mode.triples", "Тройки", "Три одинаковые в лотке"],
		["tables.mode.riichi", "Стол на четверых", "Против трёх героинь"],
		["tables.mode.koikoi", "Коикои", "Карты месяцев"],
		["tables.mode.duels", "Дуэли", "Гонка на общем столе"],
		["tables.mode.journey", "Странствие", "Недельный забег"],
		["tables.mode.pagoda", "Пагода", "Этаж за этажом"],
	]
	for i in modes.size():
		var m: Array = modes[i]
		var pl: = V10Plate.make("M", 328, m[1], m[2])
		pl.interactive = true
		pl.position = Vector2(cx + 32 + (i % 2) * 328.0, y + int(i / 2) * 88.0)
		pl.set_meta("tut_id", m[0])
		bg.add_child(pl)
	y += ceilf(modes.size() / 2.0) * 88.0 + 8.0
	var tp: = V10Plate.make("M", 656, "Турнир недели", "Твоя группа недели")
	tp.interactive = true
	tp.position = Vector2(cx + 32, y)
	tp.set_meta("tut_id", "tables.tourney")
	bg.add_child(tp)
	return bg


static func make_match(parent: Node, cfg: = {}) -> V10HudMatch:
	var hud: = V10HudMatch.new()
	parent.add_child(hud)
	hud.configure({
		"hero": String(cfg.get("hero", "mc")),
		"level": String(cfg.get("level", "1-1")),
		"total": int(cfg.get("total", 30)),
		"left": int(cfg.get("left", 28)),
		"helpers": cfg.get("helpers", {"undo": 2, "hint": 3, "shuffle": 1}),
		"stake_offer": bool(cfg.get("stake_offer", false)),
	})
	hud.help_row.visible = bool(cfg.get("show_help", false))
	hud.set_ult(float(cfg.get("ult", 0.25)))
	hud.layout_now()
	var tw: = 76.0
	var th: = 106.0
	var x0: = (688.0 - 7 * tw) * 0.5
	var y0: = 120.0
	var tile_a: Control = null
	var tile_b: Control = null
	for li in 2:
		var cols: = 7 - li * 2
		var rows: = 5 - li * 2
		for r in rows:
			for c in cols:
				var tr: = TextureRect.new()
				var tidx: = 5 if (li == 1 and r == 0 and c in [1, 3]) else ((r * 7 + c + li * 3) % 34)
				tr.texture = load(TILE_DIR + "t%02d.png" % tidx)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.size = Vector2(tw, th)
				tr.position = Vector2(x0 + c * tw + li * (tw - 4.0), y0 + r * 92.0 + li * 85.0)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hud.board_layer.add_child(tr)
				if li == 1 and r == 0 and c == 1:
					tile_a = tr
				elif li == 1 and r == 0 and c == 3:
					tile_b = tr
	if tile_a != null:
		tile_a.set_meta("tut_id", "match.tile_a")
	if tile_b != null:
		tile_b.set_meta("tut_id", "match.tile_b")
	hud.tray.set_meta("tut_id", "match.tray")
	hud.board_layer.set_meta("tut_id", "match.board")
	hud.status_l.set_meta("tut_id", "match.status")
	hud.pause_btn.set_meta("tut_id", "match.pause")
	hud.stake.set_meta("tut_id", "match.stake")
	hud.combo_l.set_meta("tut_id", "match.combo")
	if hud.discs.has("hint"):
		(hud.discs["hint"] as Node).set_meta("tut_id", "match.hint")
	var mh: = Control.new()
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hf: Rect2 = hud.hero_face_global()
	var hv: Rect2 = hud.L.get("hero_view", Rect2(0, 896, 720, 384))
	mh.position = Vector2(maxf(hv.position.x + 16.0, hf.get_center().x - 140.0), maxf(hv.position.y + 4.0, hf.position.y - 16.0))
	mh.size = Vector2(280.0, minf(300.0, hv.end.y - mh.position.y - 12.0))
	mh.set_meta("tut_id", "match.hero")
	mh.set_meta("tut_radius", 16.0)
	hud.add_child(mh)
	return hud


static func make_victory(parent: Node, cfg: = {}) -> V10HudVictory:
	var v: = V10HudVictory.new()
	parent.add_child(v)
	v.configure({
		"hero": String(cfg.get("hero", "mc")),
		"level": String(cfg.get("level", "1-1 · Чайный сад")),
		"stars": int(cfg.get("stars", 3)),
		"next": int(cfg.get("next", 2)),
	})
	v.layout_now()
	v.stars_c.set_meta("tut_id", "win.stars")
	v.caption_l.set_meta("tut_id", "win.rewards")
	v.play_b.set_meta("tut_id", "win.next")
	v.home_b.set_meta("tut_id", "win.home")
	return v
