class_name V8Starter
extends RefCounted

# 0.8 Stream E: «Набор первого гостя» (starter pack).
# Shown once, after the 3rd win on the Path; the offer then lasts 72 hours. The flag lives in the save
# (S.starter = {shown_at: unix, bought: bool}). Only what the pack really gives is listed: crystals and
# the SSR outfit (0.7 promised «10 билетов», which were never granted, so that line is gone).
# For other screens (shop / home): V8Starter.active() -> bool, V8Starter.left_text() -> String.

const WINS: = 3
const HOURS: = 72
const ITEM: = "o_dragon"
const GEMS: = 1200

const T: = {
	"title": "Для новых гостей",
	"name": "Набор первого гостя",
	"gems": "1 200 кристаллов",
	"outfit": "«Императрица дракона» · SSR",
	"left": "Ещё %s",
	"info": "Предложим один раз.\nНапоминать не будем.",
	"buy": "149 ₽ (тест)",
	"got": "Набор твой. Это тест, деньги не списаны",
}


static func st() -> Dictionary:
	var d = G.S.get("starter")
	if not (d is Dictionary):
		d = {}
		G.S["starter"] = d
	d["shown_at"] = int(d.get("shown_at", 0))
	d["bought"] = bool(d.get("bought", false))
	return d

static func now() -> int:
	return V10Meta.now_unix()

# Path wins: the per-mode stats (0.8) or, for a 0.7 save without stats, the cleared Path levels.
static func path_wins() -> int:
	var cleared: = 0
	var stars = G.S.get("stars", {})
	if stars is Dictionary:
		for k in stars:
			if int(stars[k]) > 0:
				cleared += 1
	return maxi(int(G.stats_of("path").wins), cleared)

static func owned() -> bool:
	return G.owns(ITEM) or bool(st().bought)

# 0.10 (UX §3.5, С-2, О-3): no «₽» before L8 — the offer waits until the Лавка tab is open (after the boss of chapter 1)
static func eligible() -> bool:
	return not G.demo and not owned() and int(st().shown_at) == 0 and path_wins() >= WINS and V10Nav.tab_open("shop")

static func left_secs() -> int:
	var s: = int(st().shown_at)
	if s <= 0:
		return HOURS * 3600
	return maxi(0, s + HOURS * 3600 - now())

static func active() -> bool:
	return int(st().shown_at) > 0 and not owned() and left_secs() > 0

static func left_text() -> String:
	var secs: = left_secs()
	var h: = secs / 3600
	if h >= 24:
		return "%d д %d ч" % [h / 24, h % 24]
	return "%d ч %d мин" % [h, (secs % 3600) / 60]

# called after every Path win: asks the home screen to show the offer once
static func on_path_win() -> void:
	if eligible():
		G.set_meta("pending_offer", true)

static func _forced() -> bool:
	return "--v8_offer=1" in OS.get_cmdline_user_args()

# main.maybe_offer() -> here. Returns true if the popup was opened.
static func maybe_show(main) -> bool:
	if _forced():
		popup(main)
		return true
	if G.offer_shown or not eligible():
		return false
	G.offer_shown = true
	var s: = st()
	if int(s.shown_at) == 0:
		s.shown_at = now()
		G.save()
	popup(main)
	return true

static func popup(main) -> RBox:
	var p: = Common.popup(main, T.title, 620, "lav")
	var art: = Common.card_art(G.art_tex(G.ITEM[ITEM]), Rect2(30, 60, 260, 380), Vector2(0.5, 0.3), 1.0, 20)
	(art.material as ShaderMaterial).set_shader_parameter("holo", 0.35)
	p.add_child(art)
	var t: = UI.title(T.name, 32, Color.WHITE, Color("3f2a7a"))
	t.position = Vector2(310, 66)
	t.size = Vector2(330, 50)
	p.add_child(t)
	var lines: = [["gem", T.gems], ["wardrobe", T.outfit], ["calendar", T.left % left_text()]]
	for i in lines.size():
		Common.chip(p, Common.ui_icon(lines[i][0]), lines[i][1], Rect2(310, 140 + i * 74, 320, 56), "glass", 18)
	var info: = UI.label(T.info, 17, UI.MUTED)
	info.position = Vector2(312, 370)
	p.add_child(info)
	var buy: = JButton.make(T.buy, "gold", Rect2(60, 470, 540, 96), null, 34)
	buy.shine_every = 2.0
	buy.pressed.connect( func():
		if owned():
			Common.close_popup(p)
			return
		V10Money.grant({"gems": GEMS}, "starter")
		G.give(ITEM)
		st().bought = true
		G.save()
		if main.has_method("fly_gems"):
			main.fly_gems(buy.get_global_rect().get_center(), 8)
		if main.has_method("refresh_currency"):
			main.refresh_currency(true)
		main.toast(T.got, "gift")
		Common.close_popup(p))
	p.add_child(buy)
	return p
