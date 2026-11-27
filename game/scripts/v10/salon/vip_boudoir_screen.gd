class_name V10VipBoudoirScreen
extends Control

# Screen "v10boudoir" — VIP-Будуары Салона (HUD_V2 "Тишина и лак" full-bleed 16+ showcase).
# 10 bespoke suites (all 5 founders + all 5 Wave-1 goddesses) with full-bleed top-anchored 16+ CG,
# compact uniform goddess selector pills, airy NIGHT_900 bottom sheet, JP voice lines, gifts, and branching dates.

const VIP_DIR: = "res://assets/v10/salon_vip/"
const CG_DIR: = "res://assets/v10/cg_16/"

const SUITES: Array[Dictionary] = [
	{
		"id": "mc",
		"hero": "mc",
		"name": "Алый будуар хозяйки",
		"sub": "Бархат, свечи и закрытый стол на двоих",
		"bg": "boudoir_mc.webp",
		"cg": "intro_mc_table.webp",
		"accent": Color("#F6B464"),
		"lines": [
			"Запирай дверь на засов. После полуночи здесь действуют только мои правила~",
			"Шёлковые чулки чуть жмут… подашь мне бокал чая и сядешь поближе?",
			"Если выдержишь мой взгляд, покажу тебе тайный расклад хозяйки.",
		],
	},
	{
		"id": "rin",
		"hero": "rin",
		"name": "Полуночный бар Рин",
		"sub": "Нефритовый свет, редкий улун и приватная стойка",
		"bg": "teabar_rin.webp",
		"cg": "date_rin_16.webp",
		"accent": Color("#FF799A"),
		"lines": [
			"Гости уже разошлись. Я оставила для тебя самое тёплое место у стойки.",
			"Не отводи глаз… мой наряд сегодня и правда чуть смелее обычного.",
			"Выпьешь со мной за закрытыми ставнями? Очки снимать я не буду.",
		],
	},
	{
		"id": "yue",
		"hero": "yue",
		"name": "Лунные купальни Юэ",
		"sub": "Серебряный пар, лепестки и шёлковая вуаль",
		"bg": "moonbath_yue.webp",
		"cg": "intro_yue_moon.webp",
		"accent": Color("#C7A6FF"),
		"lines": [
			"Вода сегодня тёплая, как лунный свет. Осторожнее — шёлк легко соскальзывает.",
			"Шепни мне желание, пока лепестки касаются воды… я никому не расскажу.",
			"Твои пальцы дрожат, когда ты берёшь кость. Позволь согреть тебя.",
		],
	},
	{
		"id": "nova",
		"hero": "nova",
		"name": "Пентхаус Новы",
		"sub": "Неоновая панорама города и приватный диван",
		"bg": "penthouse_nova.webp",
		"cg": "date_nova_16.webp",
		"accent": Color("#6EE7FF"),
		"lines": [
			"Весь мегаполис внизу, а сигнал камер я уже отключила. Мы одни.",
			"Любишь этот блестящий костюм? Задержись — покажу ещё пару ракурсов.",
			"Забудь про статистику на час. Сейчас моя единственная цель — ты.",
		],
	},
	{
		"id": "kohaku",
		"hero": "kohaku",
		"name": "Святилище белой лисы",
		"sub": "Алые тории, лунные фонари и тёплый хвост",
		"bg": "kohaku_shrine.webp",
		"bg_fb": "moonbath_yue.webp",
		"cg": "kohaku_16.webp",
		"pfx": "ko",
		"accent": Color("#FFB3C7"),
		"lines": [
			"Хвост сам тянется к тебе… не смотри так, я же лиса, а не кошка!",
			"В святилище тихо. Можешь остаться до рассвета — если осмелишься.",
			"Дай руку. Лисий огонь согревает лучше любого чая~",
		],
	},
	{
		"id": "shirin",
		"hero": "shirin",
		"name": "Шатёр семи колодцев",
		"sub": "Шёлковые подушки, кальян и звон браслетов",
		"bg": "shirin_tent.webp",
		"bg_fb": "teabar_rin.webp",
		"cg": "shirin_16.webp",
		"pfx": "sh",
		"accent": Color("#FFC66B"),
		"lines": [
			"Пустыня ночью холодна. Подвинься ближе — шатёр у меня один.",
			"Браслеты звенят, когда я танцую. Хочешь услышать вблизи?",
			"Семь колодцев — семь желаний. Первое я уже загадала про тебя.",
		],
	},
	{
		"id": "tsubame",
		"hero": "tsubame",
		"name": "Балкон ночной ласточки",
		"sub": "Алый шёлк, ветер с крыш и горящий город",
		"bg": "tsubame_balcony.webp",
		"bg_fb": "penthouse_nova.webp",
		"cg": "tsubame_16.webp",
		"pfx": "tb",
		"accent": Color("#FF7A8E"),
		"lines": [
			"Ветер с крыш холодный, но ты почему-то горячее всего вокруг.",
			"Ласточки летают быстро, а я — только к тебе. Не отпускай.",
			"Закрой глаза. Сегодня я веду, а ты просто доверься.",
		],
	},
	{
		"id": "zlata",
		"hero": "zlata",
		"name": "Трон Жар-птицы",
		"sub": "Расплавленное золото, угли и огненные перья",
		"bg": "zlata_throne.webp",
		"bg_fb": "boudoir_mc.webp",
		"cg": "zlata_16.webp",
		"pfx": "zl",
		"accent": Color("#FFA24A"),
		"lines": [
			"На трон садятся лишь по моему слову. Тебе — позволено.",
			"Перья греют, но обжигают только тех, кто лжёт. Ты ведь честный?",
			"Склонись ближе, смертный. Хочу рассмотреть, кто так красиво смущается.",
		],
	},
	{
		"id": "hana",
		"hero": "hana",
		"name": "Тёплая гостиная Ханы",
		"sub": "Уютный свитер, тёплый плед и поздний ужин на двоих",
		"bg": "boudoir_hana.webp",
		"bg_fb": "boudoir_mc.webp",
		"cg": "date_hana_16.webp",
		"accent": Color("#FFB25A"),
		"lines": [
			"Свитер опять сполз с плеча… нет, не поправляй. Мне нравится, как ты смотришь.",
			"Дверь уже закрыта на ключ. Иди ко мне под плед — сегодня никуда не спешим~",
			"Ты такой внимательный за столом… интересно, в полумраке ты такой же смелый?",
		],
	},
	{
		"id": "miel",
		"hero": "miel",
		"name": "Ночная кондитерская Миэль",
		"sub": "Тёплая карамель, сливки и стол после закрытия",
		"bg": "boudoir_miel.webp",
		"bg_fb": "teabar_rin.webp",
		"cg": "cg_miel_16.webp",
		"pfx": "me",
		"accent": Color("#E0566F"),
		"lines": [
			"Витрина уже закрыта, но самый сладкий десерт остался на стойке… попробуешь?",
			"На губах капля крема? Ну так не стой далеко — убери сам, если не стесняешься~",
			"Фартук и чулки пахнут ванилью. Сегодня ночью весь салон «Мёд и пар» только для тебя.",
		],
	},
]

const FALLBACK_NAMES: = {"hana": "Хана", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "tsubame": "Цубамэ", "zlata": "Злата"}
const GIFT_SHORT: = {"gift_tea_set": "Чай", "gift_silk_fan": "Веер", "gift_jade_pin": "Заколка"}

const OATH_KEY: = "v10_oaths"
const OATH_FREE_AFF: = 4
const OATH_COST_GEMS: = 500
const PANEL_H: = 248.0
const TAB_W: = 132.0
const TAB_H: = 56.0
const TAB_GAP: = 8.0

const OATH_WHISPERS: = {
	"mc": "Кольцо тёплое от твоих пальцев… Теперь и я, и весь салон принадлежим только тебе. Не смей снимать его даже ночью~",
	"rin": "На безымянном пальце оно блестит ярче любого нефрита… Сегодня я сварю чай только для нас двоих — до самого утра.",
	"yue": "Даже полная луна меркнет рядом с этим кольцом… Клянусь шёлком и лунным светом: моё сердце отныне твоё навеки.",
	"nova": "Протокол вечной связи активирован… Шучу. Просто обними меня крепче — с этим кольцом я больше никуда не исчезну.",
	"hana": "Правда мне?! У меня так колотится сердце… Иди сюда скорее, хочу почувствовать твои руки и запомнить эту ночь навсегда~",
	"kohaku": "Девятьсот лет я ждала того, кто наденет мне кольцо обета… Теперь лиса твоя целиком — от ушек до кончика хвоста~",
	"shirin": "Звёзды пустыни шептали об этой ночи… Кольцо на моей руке звенит нежнее браслетов. Останься со мной в шатре навсегда.",
	"tsubame": "Я носила чужие клятвы сквозь сотни миров, а свою отдаю лишь тебе… Мои крылья нашли дом в твоих объятиях.",
	"zlata": "Золото к золоту, пламя к пламени… Ты покорил Жар-птицу, мой суженый. Отныне мой жар согревает только тебя.",
	"miel": "Слаще любого медового десерта… Смотри, как идеально село! Сегодня кондитерская закрыта до утра — празднуем вдвоём~",
}

var main
var W: = 720.0
var H: = 1280.0
var _idx: = 0
var _line_i: = 0
var _ui_hidden: = false
var _t: = 0.0

var _stage_clip: Control
var _bg_tex: TextureRect
var _cg_tex: TextureRect
var _cg_rim: Panel
var _cg_mat: ShaderMaterial
var _cg_shadow: Panel
var _safe_top: = 0.0
var _safe_bot: = 0.0
var _ui_layer: Control
var _tabs_box: Control
var _tabs_scroll: ScrollContainer
var _tab_dragged: = false
var _tab_press_x: = 0
var _date_btn: Panel
var _date_dot: Control
var _date_win: Control
var _oath_btn: Panel
var _oath_lbl: Label
var _oath_ring_ic: Control
var _oath_crest: Control
var _ult_btn: Panel
var _name_pl: Panel
var _tab_btns: Array[Control] = []
var _suite_title: Label
var _suite_sub: Label
var _hero_name_lbl: Label
var _dlg_lbl: Label
var _aff_lbl: Label
var _aff_bar_fill: ColorRect
var _aff_bar_w: = 360.0
var _mile_lbl: Label
var _gift_tray: Control
var _gift_btns: Array[Control] = []
var _hide_btn: Panel
var _hide_lbl: Label
var _fx_layer: Control


static func is_oath(hero: String) -> bool:
	if hero == "" or not (G.S.get(OATH_KEY) is Dictionary):
		return false
	return int((G.S[OATH_KEY] as Dictionary).get(hero, 0)) > 0


static func oath_count() -> int:
	if not (G.S.get(OATH_KEY) is Dictionary):
		return 0
	var d: Dictionary = G.S[OATH_KEY]
	var n: = 0
	for k in d:
		if int(d[k]) > 0:
			n += 1
	return n


static func pledge_oath(hero: String) -> Dictionary:
	if hero == "":
		return {"ok": false, "reason": "invalid", "free": false}
	if is_oath(hero):
		return {"ok": false, "reason": "already", "free": false}
	var free: bool = G.aff_level(hero) >= OATH_FREE_AFF
	if not free:
		if not V10Money.spend({"gems": OATH_COST_GEMS}, "oath"):
			return {"ok": false, "reason": "gems", "free": false}
	if not (G.S.get(OATH_KEY) is Dictionary):
		G.S[OATH_KEY] = {}
	(G.S[OATH_KEY] as Dictionary)[hero] = maxi(1, int(V10Meta.now_unix()))
	G.save()
	return {"ok": true, "reason": "", "free": free}


static func ult_name_of(h: String, oid: String = "") -> String:
	if oid != "":
		if V9Ults.ULTS.has(oid):
			return String(V9Ults.ULTS[oid].get("name", ""))
		if V10W1Ults.ULTS.has(oid):
			return String(V10W1Ults.ULTS[oid].get("name", ""))
	if V10W1Ults.CORES.has(h):
		return String(V10W1Ults.CORES[h].get("name", "Умение"))
	return String(G.SKILLS.get(h, {}).get("name", "Умение"))


static func make_oath_crest(sz: float = 28.0) -> Control:
	var crest: = Panel.new()
	crest.name = "OathCrest"
	crest.size = Vector2(sz, sz)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.tooltip_text = "Обет скреплён · +10 к силе"
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(V10DS.NIGHT_700, 0.96)
	sb.border_color = V10DS.GOLD_500
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(roundf(sz * 0.5)))
	crest.add_theme_stylebox_override("panel", sb)
	var ic: = _OathRingIcon.new()
	ic.position = Vector2(2.0, 2.0)
	ic.size = Vector2(sz - 4.0, sz - 4.0)
	crest.add_child(ic)
	return crest


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	var ins: = V10Layout.safe_insets(size)
	_safe_top = maxf(0.0, float(ins.get("top", 0.0)) - position.y)
	_safe_bot = maxf(0.0, float(ins.get("bottom", 0.0)) - (maxf(0.0, get_viewport_rect().size.y - (position.y + size.y)) if is_inside_tree() else 0.0))
	Sfx.music("menu")

	var req_h: = String(args.get("hero", G.S.get("partner", "mc")))
	for i in SUITES.size():
		if String(SUITES[i].hero) == req_h or String(SUITES[i].id) == req_h:
			_idx = i
			break

	var br: = V10Layout.bleed_rect(self)
	var base: = ColorRect.new()
	base.color = V10DS.NIGHT_900
	base.position = br.position
	base.size = br.size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	# Full-bleed edge-to-edge cinematic stage (eliminates tacky double-framed box-in-box!)
	_stage_clip = Control.new()
	_stage_clip.position = br.position
	_stage_clip.size = br.size
	_stage_clip.clip_contents = true
	_stage_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage_clip)

	_bg_tex = TextureRect.new()
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex.position = Vector2(-12.0, -12.0)
	_bg_tex.size = br.size + Vector2(24.0, 24.0)
	_bg_tex.pivot_offset = _bg_tex.size * 0.5
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_clip.add_child(_bg_tex)

	_cg_tex = TextureRect.new()
	_cg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cg_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cg_tex.position = Vector2.ZERO
	_cg_tex.size = br.size
	_cg_tex.pivot_offset = br.size * 0.5
	_cg_tex.visible = false
	_cg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_clip.add_child(_cg_tex)

	var vig: = Common.vignette(self, size, V10DS.NIGHT_900, 0.24)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE

	Fx.ambient(self, "petals", size)

	_fx_layer = Control.new()
	_fx_layer.size = size
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 40
	add_child(_fx_layer)

	_ui_layer = Control.new()
	_ui_layer.size = size
	_ui_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.z_index = 20
	add_child(_ui_layer)

	# Smooth top & bottom dark-lacquer gradients inside _ui_layer (vanish cleanly in Art full-screen mode!)
	var py: = H - PANEL_H - 12.0 - _safe_bot
	_add_grad(_ui_layer, Rect2(br.position.x, br.position.y, br.size.x, (148.0 + _safe_top) - br.position.y),
		Color(V10DS.NIGHT_900, 0.80), Color(V10DS.NIGHT_900, 0.0))
	_add_grad(_ui_layer, Rect2(br.position.x, py - 116.0, br.size.x, br.end.y - (py - 116.0)),
		Color(V10DS.NIGHT_900, 0.0), Color(V10DS.NIGHT_900, 0.92))

	_build_header()
	_build_suite_tabs()
	_build_bottom_panel()

	# Always-on Art full-screen toggle pill in top-right (visible even when UI is hidden)
	_hide_btn = _lacquer_panel(Rect2(W - 106.0, 12.0 + _safe_top, 92.0, 40.0), Color(V10DS.NIGHT_800, 0.88), Color(V10DS.GOLD_500, 0.65), 10, 1)
	_hide_btn.z_index = 60
	_hide_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_lbl = _lbl("Арт", "ui_strong", 15, V10DS.GOLD_300, false)
	_hide_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hide_lbl.size = Vector2(92.0, 40.0)
	_hide_btn.add_child(_hide_lbl)
	_hide_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_hide_btn.accept_event()
			V9Feel.press(_hide_btn, "tap")
			_toggle_ui())
	add_child(_hide_btn)

	gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			if _ui_hidden:
				_toggle_ui()
			else:
				_next_line(true))

	set_meta("v8_back", _back)
	_apply_suite(false)
	if String(args.get("mode", "")) == "date":
		_open_date.call_deferred()


func _process(dt: float) -> void:
	_t += dt
	if _cg_tex != null and is_instance_valid(_cg_tex) and _cg_tex.visible:
		var csc: = 1.008 + sin(_t * 0.55) * 0.008
		_cg_tex.scale = Vector2(csc, csc)
	elif _bg_tex != null and is_instance_valid(_bg_tex):
		var sc: = 1.012 + sin(_t * 0.50) * 0.008
		_bg_tex.scale = Vector2(sc, sc)


func _build_header() -> void:
	var back_b: = _lacquer_panel(Rect2(14.0, 10.0 + _safe_top, 44.0, 44.0), Color(V10DS.NIGHT_800, 0.88), Color(V10DS.GOLD_700, 0.55), 10, 1)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	var bl: = _lbl("‹", "ui_strong", 26, V10DS.PAPER_100, false)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.position = Vector2(0.0, -2.0)
	bl.size = Vector2(44.0, 44.0)
	back_b.add_child(bl)
	back_b.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			back_b.accept_event()
			V9Feel.press(back_b, "tap")
			_back())
	_ui_layer.add_child(back_b)

	var map_x: = W - 208.0
	var ttl_w: = maxf(160.0, map_x - 76.0)
	_suite_title = _lbl("", "display", 24, V10DS.PAPER_100, true)
	_suite_title.position = Vector2(68.0, 12.0 + _safe_top)
	_suite_title.size = Vector2(ttl_w, 40.0)
	_ui_layer.add_child(_suite_title)

	_suite_sub = _lbl("", "ui", 14, V10DS.GOLD_300, true)
	_suite_sub.visible = false
	_ui_layer.add_child(_suite_sub)

	var map_b: = _lacquer_panel(Rect2(map_x, 12.0 + _safe_top, 94.0, 40.0), Color(V10DS.NIGHT_800, 0.88), Color(V10DS.GOLD_700, 0.50), 10, 1)
	map_b.mouse_filter = Control.MOUSE_FILTER_STOP
	var ml: = _lbl("Салон ›", "ui_strong", 15, V10DS.PAPER_100, false)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.size = Vector2(94.0, 40.0)
	map_b.add_child(ml)
	map_b.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			map_b.accept_event()
			V9Feel.press(map_b, "tap")
			if main != null and main.has_method("go"):
				main.go("v10salon"))
	_ui_layer.add_child(map_b)


func _build_suite_tabs() -> void:
	# Compact uniform 132x56 lacquer pills with 40px circular avatar + clipped name + level (zero overflow!)
	_tabs_scroll = ScrollContainer.new()
	_tabs_scroll.position = Vector2(14.0, 60.0 + _safe_top)
	_tabs_scroll.size = Vector2(W - 28.0, TAB_H + 4.0)
	_tabs_scroll.clip_contents = true
	_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui_layer.add_child(_tabs_scroll)

	_tabs_box = Control.new()
	_tabs_box.custom_minimum_size = Vector2(float(SUITES.size()) * TAB_W + float(maxi(0, SUITES.size() - 1)) * TAB_GAP + 4.0, TAB_H + 4.0)
	_tabs_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_tabs_scroll.add_child(_tabs_box)
	_tabs_scroll.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_tabs_scroll.scroll_horizontal -= int((e as InputEventMouseMotion).relative.x)
			_tab_dragged = true)

	_tab_btns.clear()
	for i in SUITES.size():
		var s: Dictionary = SUITES[i]
		var idx: = i
		var px: = 2.0 + float(i) * (TAB_W + TAB_GAP)
		var p: = _lacquer_panel(Rect2(px, 2.0, TAB_W, TAB_H), Color(V10DS.NIGHT_800, 0.86), Color(V10DS.GOLD_700, 0.45), 14, 1)
		p.clip_contents = true
		p.mouse_filter = Control.MOUSE_FILTER_PASS

		var hid_t: = String(s.hero)
		var hname: = _hero_name(hid_t)

		# Crisp 40x40 circular avatar on left
		var ring: = _lacquer_panel(Rect2(8.0, 8.0, 40.0, 40.0), Color(V10DS.NIGHT_700, 1.0), Color(V10DS.GOLD_500, 0.72), 20, 1)
		ring.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		p.add_child(ring)

		var av_t: Texture2D = _portrait_tex(hid_t)
		if av_t != null:
			var av: = TextureRect.new()
			av.texture = av_t
			av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			av.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			av.position = Vector2.ZERO
			av.size = Vector2(40.0, 40.0)
			av.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.add_child(av)

		var short_nm: = "Хозяйка" if hid_t == "mc" else hname
		var txt_w: = TAB_W - 60.0
		var nl: = _lbl(short_nm, "ui_strong", 15, V10DS.PAPER_100, false)
		nl.name = "NameLbl"
		nl.position = Vector2(54.0, 7.0)
		nl.size = Vector2(txt_w, 21.0)
		_fit_one(nl, txt_w, [15, 14, 13], "ui_strong")
		p.add_child(nl)

		var sl: = _lbl("Ур. %d" % G.aff_level(hid_t), "ui", 13, V10DS.GOLD_300, false)
		sl.name = "LvLbl"
		sl.position = Vector2(54.0, 28.0)
		sl.size = Vector2(txt_w, 19.0)
		_fit_one(sl, txt_w, [13, 12], "ui")
		p.add_child(sl)

		p.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton or e is InputEventScreenTouch:
				var pressed_now: bool = (e as InputEventMouseButton).pressed if e is InputEventMouseButton else (e as InputEventScreenTouch).pressed
				if pressed_now:
					_tab_dragged = false
					_tab_press_x = _tabs_scroll.scroll_horizontal
				elif absi(_tabs_scroll.scroll_horizontal - _tab_press_x) < 10 and not _tab_dragged:
					_idx = idx
					_line_i = 0
					V9Feel.press(p, "tap")
					_apply_suite(true))
		_tabs_box.add_child(p)
		_tab_btns.append(p)


func _build_bottom_panel() -> void:
	# Airy, minimal NIGHT_900 alpha 0.88 translucent sheet (~20% of 20:9 screen — 4 clean rows, zero box bloat!)
	var py: = H - PANEL_H - 12.0 - _safe_bot
	var box_w: = W - 28.0
	var box: = _lacquer_panel(Rect2(14.0, py, box_w, PANEL_H), Color(V10DS.NIGHT_900, 0.88), Color(V10DS.GOLD_700, 0.44), 14, 1)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_top_sheen(box, box_w, 0.45)
	_ui_layer.add_child(box)

	# ── Line 1: Her Name + Oath Crest + Slim Affection Progress Bar on ONE clean row ──
	_oath_crest = make_oath_crest(24.0)
	_oath_crest.position = Vector2(16.0, 15.0)
	_oath_crest.visible = false
	box.add_child(_oath_crest)

	_hero_name_lbl = _lbl("", "display", 24, V10DS.PAPER_100, false)
	_hero_name_lbl.position = Vector2(16.0, 10.0)
	_hero_name_lbl.size = Vector2(246.0, 34.0)
	box.add_child(_hero_name_lbl)

	var aff_x: = minf(296.0, box_w * 0.44)
	_aff_bar_w = maxf(180.0, box_w - aff_x - 16.0)

	_aff_lbl = _lbl("", "ui_strong", 15, V10DS.GOLD_300, false)
	_aff_lbl.position = Vector2(aff_x, 11.0)
	_aff_lbl.size = Vector2(_aff_bar_w * 0.62, 22.0)
	box.add_child(_aff_lbl)

	_mile_lbl = _lbl("", "num", 13, V10DS.PAPER_500, false)
	_mile_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mile_lbl.position = Vector2(aff_x + _aff_bar_w * 0.58, 11.0)
	_mile_lbl.size = Vector2(_aff_bar_w * 0.42, 22.0)
	box.add_child(_mile_lbl)

	var bar_bg: = ColorRect.new()
	bar_bg.color = V10DS.NIGHT_600
	bar_bg.position = Vector2(aff_x, 36.0)
	bar_bg.size = Vector2(_aff_bar_w, 5.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_bg)

	_aff_bar_fill = ColorRect.new()
	_aff_bar_fill.color = V10DS.ROSE_500
	_aff_bar_fill.position = Vector2(aff_x, 36.0)
	_aff_bar_fill.size = Vector2(0.0, 5.0)
	_aff_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_aff_bar_fill)

	# ── Line 2: Intimate Dialogue Line (max 2 lines, crisp, tap to hear next voice line) ──
	_dlg_lbl = _lbl("", "ui", 18, V10DS.PAPER_100, false)
	_dlg_lbl.position = Vector2(16.0, 48.0)
	_dlg_lbl.size = Vector2(box_w - 32.0, 54.0)
	_dlg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_lbl.max_lines_visible = 2
	_dlg_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_dlg_lbl.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_dlg_lbl.accept_event()
			_next_line(true))
	box.add_child(_dlg_lbl)

	# ── Line 3: ONE Clean 3-Button Action Row (Свидание 16+ ♥ | Приём 16+ ▶ | Обет) ──
	var row_y: = 110.0
	var row_h: = 48.0
	var row_w: = box_w - 32.0
	var gap_b: = 8.0
	var date_w: = roundf(row_w * 0.37)
	var ult_w: = roundf((row_w - date_w - gap_b * 2.0) * 0.48)
	var oath_w: = row_w - date_w - ult_w - gap_b * 2.0

	_build_date_button(box, Rect2(16.0, row_y, date_w, row_h))

	_ult_btn = _lacquer_panel(Rect2(16.0 + date_w + gap_b, row_y, ult_w, row_h), Color(V10DS.NIGHT_700, 0.96), Color(V10DS.GOLD_500, 0.72), 10, 1)
	_ult_btn.name = "UltCinemaBtn"
	_ult_btn.clip_contents = true
	_ult_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_ult_btn.pivot_offset = Vector2(ult_w * 0.5, row_h * 0.5)
	_add_top_sheen(_ult_btn, ult_w, 0.55)
	var ult_lbl: = _lbl("Приём 16+ ▶", "ui_strong", 16, V10DS.GOLD_300, false)
	ult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_lbl.position = Vector2(8.0, 0.0)
	ult_lbl.size = Vector2(ult_w - 16.0, row_h)
	_fit_one(ult_lbl, ult_w - 16.0, [16, 15, 14], "ui_strong")
	_ult_btn.add_child(ult_lbl)
	_ult_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_ult_btn.accept_event()
			V9Feel.press(_ult_btn, "tap")
			_play_ult_cinema())
	box.add_child(_ult_btn)

	_oath_btn = _lacquer_panel(Rect2(16.0 + date_w + gap_b + ult_w + gap_b, row_y, oath_w, row_h), Color(V10DS.NIGHT_700, 0.96), Color(V10DS.GOLD_500, 0.72), 10, 1)
	_oath_btn.name = "OathBtn"
	_oath_btn.clip_contents = true
	_oath_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_oath_btn.pivot_offset = Vector2(oath_w * 0.5, row_h * 0.5)
	_add_top_sheen(_oath_btn, oath_w, 0.55)
	_oath_ring_ic = _OathRingIcon.new()
	_oath_ring_ic.position = Vector2(10.0, 13.0)
	_oath_ring_ic.size = Vector2(22.0, 22.0)
	_oath_btn.add_child(_oath_ring_ic)
	_oath_lbl = _lbl("Обет", "ui_strong", 16, V10DS.GOLD_300, false)
	_oath_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_oath_lbl.position = Vector2(34.0, 0.0)
	_oath_lbl.size = Vector2(oath_w - 42.0, row_h)
	_oath_btn.add_child(_oath_lbl)
	_oath_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_oath_btn.accept_event()
			V9Feel.press(_oath_btn, "tap")
			_on_oath_tap())
	box.add_child(_oath_btn)

	# ── Line 4: Compact Sleek 3-Gift Row (Чай +40, Веер +120, Заколка +300 — zero box-within-box!) ──
	_gift_tray = Control.new()
	_gift_tray.position = Vector2(16.0, 168.0)
	_gift_tray.size = Vector2(row_w, 66.0)
	box.add_child(_gift_tray)
	_build_gift_cards()


func _build_date_button(box: Panel, r: Rect2) -> void:
	# Primary rose-gold HUD_V2 pill with readiness dot cleanly INSIDE the pill (never sticking out!)
	_date_btn = _lacquer_panel(r, V10DS.ROSE_500, Color(V10DS.PLATE_SPARK, 0.65), int(roundf(r.size.y * 0.5)), 1)
	_date_btn.name = "DateBtn"
	_date_btn.clip_contents = true
	_date_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_date_btn.pivot_offset = r.size * 0.5
	_add_top_sheen(_date_btn, r.size.x, 0.72)

	var dot: = Panel.new()
	dot.name = "DateDot"
	dot.position = Vector2(r.size.x - 18.0, (r.size.y - 8.0) * 0.5)
	dot.size = Vector2(8.0, 8.0)
	var dsb: = StyleBoxFlat.new()
	dsb.bg_color = V10DS.PLATE_SPARK
	dsb.border_color = V10DS.NIGHT_900
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", dsb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_date_btn.add_child(dot)
	_date_dot = dot

	var dl: = _lbl("Свидание 16+ ♥", "ui_strong", 16, V10DS.NIGHT_900, false)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.position = Vector2(12.0, 0.0)
	dl.size = Vector2(r.size.x - 32.0, r.size.y)
	_fit_one(dl, r.size.x - 32.0, [17, 16, 15, 14], "ui_strong")
	_date_btn.add_child(dl)

	_date_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_date_btn.accept_event()
			V9Feel.press(_date_btn, "tap")
			_open_date())
	box.add_child(_date_btn)


func _build_gift_cards() -> void:
	for c in _gift_tray.get_children():
		c.queue_free()
	_gift_btns.clear()
	var gifts: Array = V10AffCurve.GIFTS
	var gap: = 8.0
	var cw: = (_gift_tray.size.x - gap * float(gifts.size() - 1)) / float(gifts.size())
	var ch: = 64.0
	for i in gifts.size():
		var gd: Dictionary = gifts[i]
		var gid: = String(gd.id)
		var inv_n: = V10AffCurve.gift_count(gid)
		var rim_c: = Color(V10DS.GOLD_500, 0.72) if inv_n > 0 else Color(V10DS.GOLD_700, 0.42)
		var card: = _lacquer_panel(Rect2(float(i) * (cw + gap), 0.0, cw, ch), Color(V10DS.NIGHT_800, 0.92), rim_c, 10, 1)
		card.clip_contents = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.pivot_offset = Vector2(cw * 0.5, ch * 0.5)
		_add_top_sheen(card, cw, 0.42)

		var short_g: = String(GIFT_SHORT.get(gid, String(gd.name)))
		var top_s: = "%s +%d ♥" % [short_g, int(gd.aff)]
		var nm_l: = _lbl(top_s, "ui_strong", 15, V10DS.PAPER_100, false)
		nm_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm_l.position = Vector2(6.0, 6.0)
		nm_l.size = Vector2(cw - 12.0, 26.0)
		_fit_one(nm_l, cw - 12.0, [15, 14, 13], "ui_strong")
		card.add_child(nm_l)

		var div: = ColorRect.new()
		div.color = Color(V10DS.NIGHT_600, 0.85)
		div.position = Vector2(12.0, 34.0)
		div.size = Vector2(cw - 24.0, 1.0)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(div)

		var price_s: = ("В сумке: %d" % inv_n) if inv_n > 0 else ("%d %s" % [int(gd.price), "монет" if String(gd.cur) == "coins" else "крист."])
		var pr_l: = _lbl(price_s, "ui", 13, V10DS.GOLD_300 if inv_n > 0 else V10DS.PAPER_300, false)
		pr_l.name = "PriceLbl"
		pr_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pr_l.position = Vector2(6.0, 36.0)
		pr_l.size = Vector2(cw - 12.0, 24.0)
		_fit_one(pr_l, cw - 12.0, [13, 12], "ui")
		card.add_child(pr_l)

		card.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				card.accept_event()
				V9Feel.press(card, "tap")
				_give_gift(gid, card.get_global_rect().get_center()))
		_gift_tray.add_child(card)
		_gift_btns.append(card)


func _apply_suite(play_voice: bool) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var bg_p: = VIP_DIR + String(s.bg)
	var tex: Texture2D = _load_tex(bg_p)
	_bg_tex.modulate = Color.WHITE
	if tex == null and s.has("bg_fb"):
		tex = _load_tex(VIP_DIR + String(s.bg_fb))
		_bg_tex.modulate = Color.WHITE.lerp(s.accent, 0.32)
	if tex != null:
		_bg_tex.texture = tex

	var hid: = String(s.hero)
	var cg_t: Texture2D = cg_texture(hid)
	if _cg_tex != null:
		if cg_t != null:
			_cg_tex.texture = cg_t
			_cg_tex.visible = true
			_layout_cg(_ui_hidden, false)
		else:
			_cg_tex.visible = false

	_suite_title.text = String(s.name)
	_fit_one(_suite_title, _suite_title.size.x, [24, 22, 20, 18], "display")
	_suite_sub.text = String(s.sub)
	_hero_name_lbl.text = _hero_name(hid)
	_play_hero_motif(hid)

	if _tabs_scroll != null:
		_scroll_to_tab.call_deferred(_idx)
	for i in _tab_btns.size():
		var sel: bool = (i == _idx)
		var sb: = _tab_btns[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = V10DS.GOLD_500 if sel else Color(V10DS.GOLD_700, 0.38)
			sb.set_border_width_all(2 if sel else 1)
			sb.bg_color = Color(V10DS.NIGHT_700, 0.95) if sel else Color(V10DS.NIGHT_800, 0.82)
		var nm_n: = _tab_btns[i].get_node_or_null("NameLbl") as Label
		if nm_n != null and nm_n.label_settings != null:
			nm_n.label_settings = V10Type.settings("ui_strong", nm_n.label_settings.font_size, V10DS.GOLD_300 if sel else V10DS.PAPER_100, false)
		var th: = String(SUITES[i].hero)
		var lv_n: = _tab_btns[i].get_node_or_null("LvLbl") as Label
		if lv_n != null:
			lv_n.text = ("Ур. %d · ✦" if is_oath(th) else "Ур. %d") % G.aff_level(th)
			_fit_one(lv_n, TAB_W - 60.0, [13, 12], "ui")
	_refresh_aff()
	_refresh_date_dot()
	_next_line(play_voice)


func _refresh_aff() -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var info: Dictionary = V10AffCurve.hero_progress(hid)
	var lv: = int(info.get("level", 1))
	var into: = int(info.get("into", 0))
	var need: = int(info.get("need", 120))
	var ratio: = float(info.get("ratio", 0.0))
	_aff_lbl.text = "♥ Симпатия · Ур. %d" % lv
	_fit_one(_aff_lbl, _aff_lbl.size.x, [15, 14, 13], "ui_strong")
	_aff_bar_fill.size.x = _aff_bar_w * clampf(ratio, 0.0, 1.0)
	_mile_lbl.text = "Макс." if bool(info.get("is_max", false)) else "%d / %d" % [into, need]
	_refresh_oath_ui(hid)
	_build_gift_cards()


func _play_hero_motif(hid: String) -> void:
	if V10Registry.wired("audio") and bool(G.S.get("music", true)):
		if hid in V10Music.HEROES:
			V10Music.motif(hid)
		elif V10Music.current().begins_with("motif_"):
			V10Music.play_screen("salon")


func _refresh_oath_ui(hid: String) -> void:
	var oathed: = is_oath(hid)
	var free_ready: = G.aff_level(hid) >= OATH_FREE_AFF
	if _oath_crest != null:
		_oath_crest.visible = oathed
	if _hero_name_lbl != null:
		var nx: = 46.0 if oathed else 16.0
		var nw: = 224.0 if oathed else 254.0
		_hero_name_lbl.position.x = nx
		_hero_name_lbl.size.x = nw
		_fit_one(_hero_name_lbl, nw, [24, 22, 20, 18], "display")
	if _oath_btn != null and _oath_lbl != null:
		var osb: = _oath_btn.get_theme_stylebox("panel") as StyleBoxFlat
		if oathed:
			if osb != null:
				osb.bg_color = Color(V10DS.NIGHT_700, 0.98)
				osb.border_color = V10DS.GOLD_300
				osb.set_border_width_all(2)
			_oath_lbl.text = "Обет · +10 к силе"
		elif free_ready:
			if osb != null:
				osb.bg_color = Color(V10DS.NIGHT_700, 0.98)
				osb.border_color = V10DS.GOLD_500
				osb.set_border_width_all(2)
			_oath_lbl.text = "Принести Обет"
		else:
			if osb != null:
				osb.bg_color = Color(V10DS.NIGHT_700, 0.96)
				osb.border_color = Color(V10DS.GOLD_500, 0.65)
				osb.set_border_width_all(1)
			_oath_lbl.text = "Обет"
		_fit_one(_oath_lbl, _oath_btn.size.x - 42.0, [16, 15, 14, 13], "ui_strong")
	for i in _tab_btns.size():
		var th: = String(SUITES[i].hero)
		var lv_n: = _tab_btns[i].get_node_or_null("LvLbl") as Label
		if lv_n != null:
			lv_n.text = ("Ур. %d · ✦" if is_oath(th) else "Ур. %d") % G.aff_level(th)
			_fit_one(lv_n, TAB_W - 60.0, [13, 12], "ui")


func _on_oath_tap() -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	if is_oath(hid):
		_play_oath_ceremony(hid, false)
		return
	var res: = pledge_oath(hid)
	if not bool(res.get("ok", false)):
		V9Feel.deny(_oath_btn)
		if main != null and main.has_method("toast"):
			main.toast("Нужен Ур. 4 симпатии (бесплатно) или 500 кристаллов", "lock")
		return
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	_refresh_oath_ui(hid)
	_play_oath_ceremony(hid, true)


func _play_oath_ceremony(hid: String, first_time: bool) -> void:
	var whisper: = String(OATH_WHISPERS.get(hid, OATH_WHISPERS.mc))
	if _dlg_lbl != null:
		_set_dialogue_text(whisper)
	Sfx.play("reveal_ssr" if first_time else "sparkle", 1.05, -4.0)
	Sfx.say(hid, "aff")
	if _fx_layer != null and is_instance_valid(_fx_layer):
		var cpos: = Vector2(W * 0.5, H * 0.42)
		if _oath_btn != null and is_inside_tree():
			Fx.burst(_fx_layer, _oath_btn.get_global_rect().get_center() - global_position, "sparkle", 18)
		Fx.flash_glow(_fx_layer, cpos, Color(1.0, 0.86, 0.52), 3.6 if first_time else 2.4, 0.65)
		Fx.burst(_fx_layer, cpos, "sparkle", 18 if first_time else 14)
		Fx.burst(_fx_layer, cpos, "heart", 16 if first_time else 10)
		var ring_fx: = Panel.new()
		ring_fx.size = Vector2(120.0, 120.0)
		ring_fx.position = cpos - Vector2(60.0, 60.0)
		ring_fx.pivot_offset = Vector2(60.0, 60.0)
		ring_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb: = StyleBoxFlat.new()
		rsb.draw_center = false
		rsb.border_color = V10DS.GOLD_300
		rsb.set_border_width_all(3)
		rsb.set_corner_radius_all(60)
		ring_fx.add_theme_stylebox_override("panel", rsb)
		_fx_layer.add_child(ring_fx)
		if is_inside_tree():
			ring_fx.scale = Vector2(0.35, 0.35)
			var tw: = create_tween().set_parallel(true)
			tw.tween_property(ring_fx, "scale", Vector2(2.6, 2.6), 0.58).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.tween_property(ring_fx, "modulate:a", 0.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(ring_fx.queue_free)
		else:
			ring_fx.queue_free()
	if first_time and main != null and main.has_method("toast"):
		main.toast("Обет скреплён с %s · +10 к силе!" % _hero_name(hid), "star")


func _worn_outfit_of(hid: String) -> String:
	var eq: = G.equipped(hid)
	if eq != "":
		return eq
	if hid == "yue" and G.owns("y_queen"):
		return "y_queen"
	if hid == "nova" and G.owns("n_ssr"):
		return "n_ssr"
	var raw: = String(G.S.get("outfit", {}).get(hid, "")) if G.S.get("outfit") is Dictionary else ""
	if raw != "" and G.ITEM.has(raw):
		return raw
	if V10W1Core.is_wave1_hero(hid):
		return V10W1Core.base_of(hid)
	var fb: = {"mc": "o_base", "rin": "r_base", "hana": "h_base", "yue": "y_base", "nova": "n_base"}
	return String(fb.get(hid, ""))


func _play_ult_cinema() -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var worn: = _worn_outfit_of(hid)
	V10UltVideo.play(self, hid, worn, ult_name_of(hid, worn))


func _set_dialogue_text(txt: String) -> void:
	if _dlg_lbl == null:
		return
	var max_w: = _dlg_lbl.size.x
	var chosen: = 16
	for s in [18, 17, 16]:
		if V10Type.lines_needed(txt, "ui", s, max_w) <= 2:
			chosen = s
			break
	_dlg_lbl.text = txt
	_dlg_lbl.label_settings = V10Type.settings("ui", chosen, V10DS.PAPER_100, false)


func _next_line(play_voice: bool) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var lines: Array = s.lines
	var txt: = String(lines[_line_i % lines.size()])
	_line_i += 1
	_set_dialogue_text(txt)
	if play_voice:
		Sfx.say(String(s.hero), "greet")


func _give_gift(gid: String, from_pos: Vector2) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var res: Dictionary = V10AffCurve.buy_and_give_gift(gid, hid)
	if not bool(res.get("ok", false)):
		if main != null and main.has_method("toast"):
			main.toast("Не хватает валюты для подарка", "lock")
		return
	G.save()
	Sfx.play("win", 1.15, -6.0)
	Sfx.say(hid, "win")
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	Fx.burst(_fx_layer, from_pos, "heart", 14)
	var ms: Dictionary = res.get("milestone", {})
	if not ms.is_empty() and main != null and main.has_method("toast"):
		main.toast("Новый рубеж: %s!" % String(ms.get("title", "")), "star")
	elif main != null and main.has_method("toast"):
		main.toast("+%d симпатии (%s)" % [int(res.get("aff", 0)), String(G.HEROES.get(hid, {}).get("name", hid))], "heart")
	_refresh_aff()


func _layout_cg(_full_bleed: bool, animate: bool) -> void:
	if _cg_tex == null or not is_instance_valid(_cg_tex) or not _cg_tex.visible or _cg_tex.texture == null:
		return
	var br: = V10Layout.bleed_rect(self)
	if _stage_clip != null and is_instance_valid(_stage_clip):
		_stage_clip.position = br.position
		_stage_clip.size = br.size
	var stage_sz: = br.size + Vector2(18.0, 18.0)
	var tsz: = _cg_tex.texture.get_size()
	var sc: = maxf(stage_sz.x / maxf(1.0, tsz.x), stage_sz.y / maxf(1.0, tsz.y))
	var draw_sz: = tsz * sc
	# Anchor top-center (0.12 vertical bias) so her head & face stay cleanly in the upper third on 20:9, 9:16, and 3:4!
	var pos: = Vector2((br.size.x - draw_sz.x) * 0.5, -maxf(0.0, draw_sz.y - br.size.y) * 0.12 - 4.0)
	_cg_tex.pivot_offset = draw_sz * 0.5
	if animate and is_inside_tree():
		var tw: = create_tween().set_parallel(true)
		tw.tween_property(_cg_tex, "position", pos, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(_cg_tex, "size", draw_sz, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		_cg_tex.position = pos
		_cg_tex.size = draw_sz


func _toggle_ui() -> void:
	_ui_hidden = not _ui_hidden
	_ui_layer.visible = not _ui_hidden
	_hide_lbl.text = "Показать" if _ui_hidden else "Арт"
	_fit_one(_hide_lbl, 82.0, [15, 14, 13], "ui_strong")
	_layout_cg(_ui_hidden, true)


func _back() -> void:
	if has_node("V10UltVideo"):
		var uv: = get_node("V10UltVideo")
		if uv.has_method("skip"):
			uv.skip()
		return
	if _ui_hidden:
		_toggle_ui()
		return
	if main != null and main.has_method("back"):
		main.back()


func _open_date() -> void:
	if _date_win != null and is_instance_valid(_date_win):
		return
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var win: = V10VipDateWindow.new()
	_date_win = win
	add_child(win)
	win.open(hid, size, G.aff_level(hid))
	win.closed.connect(func(rewarded: bool) -> void:
		if rewarded:
			if main != null and main.has_method("refresh_currency"):
				main.refresh_currency(true)
			_refresh_aff()
			_refresh_date_dot())


func _refresh_date_dot() -> void:
	if _date_dot != null:
		var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
		_date_dot.visible = V10VipDate.reward_available(String(s.hero))


func dev_act(act: String) -> void:
	if act == "date":
		_open_date()
	elif act.begins_with("pick"):
		if _date_win != null and is_instance_valid(_date_win):
			_date_win._pick(int(act.substr(4)))
	elif act == "end":
		if _date_win != null and is_instance_valid(_date_win):
			_date_win._start()
			_date_win._set_spark(88, false)
			_date_win.step = 3
			_date_win._finish()
	elif act == "start":
		if _date_win != null and is_instance_valid(_date_win):
			_date_win._start()
	elif act.begins_with("suite"):
		_idx = clampi(int(act.substr(5)), 0, SUITES.size() - 1)
		_apply_suite(false)
	elif act == "oath":
		_on_oath_tap()
	elif act == "ult":
		_play_ult_cinema()


static func wrap_size(l: Label, sz: Vector2) -> void:
	var ls: = l.label_settings
	var font: Font = ls.font if ls != null and ls.font != null else ThemeDB.fallback_font
	var fs: int = ls.font_size if ls != null else 16
	var out: Array = []
	for para in l.text.split("\n"):
		var line: = ""
		for w in para.split(" "):
			var cand: String = w if line == "" else line + " " + w
			if line != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > sz.x - 8.0:
				out.append(line)
				line = w
			else:
				line = cand
		out.append(line)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text = "\n".join(PackedStringArray(out))
	l.size = sz


static func _hero_name(hid: String) -> String:
	var nm: = String(G.HEROES.get(hid, {}).get("name", ""))
	return nm if nm != "" else String(FALLBACK_NAMES.get(hid, hid))


static func _suite_of(hid: String) -> Dictionary:
	for s in SUITES:
		if String(s.hero) == hid or String(s.id) == hid:
			return s
	return SUITES[0]


static var _avatar_cache: Dictionary = {}

static func _portrait_tex(hid: String) -> Texture2D:
	if _avatar_cache.has(hid):
		return _avatar_cache[hid]
	var cands: Array = []
	if V8Art.has_emotion(hid, "happy"):
		cands.append(V8Art.emotion_path(hid, "happy"))
	cands.append("res://assets/v10/wave1/emotions/%s_happy.webp" % hid)
	cands.append(V10W1Core.hero_png(hid))
	var src: Texture2D = null
	for c in cands:
		var t: = _load_tex(String(c))
		if t != null:
			src = t
			break
	if src == null:
		return null
	var im: = src.get_image()
	if im == null or im.is_empty():
		return src
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var iw: = im.get_width()
	var ih: = im.get_height()
	var top_y: = 0
	var found_top: = false
	for y in range(0, ih, 4):
		for x in range(0, iw, 8):
			if im.get_pixel(x, y).a > 0.25:
				top_y = maxi(0, y - 6)
				found_top = true
				break
		if found_top:
			break
	var side: = mini(iw, int(roundf(float(ih - top_y) * 0.54)))
	side = clampi(side, 64, mini(iw, ih - top_y))
	var cx_i: = clampi((iw - side) / 2, 0, maxi(0, iw - side))
	var cy_i: = clampi(top_y, 0, maxi(0, ih - side))
	var sub: = im.get_region(Rect2i(cx_i, cy_i, side, side))
	sub.resize(120, 120, Image.INTERPOLATE_LANCZOS)
	sub.generate_mipmaps()
	var out_t: = ImageTexture.create_from_image(sub)
	_avatar_cache[hid] = out_t
	return out_t


static func cg_texture(hid: String) -> Texture2D:
	var s: = _suite_of(hid)
	var cands: Array = [CG_DIR + "cg_%s_16.webp" % hid, CG_DIR + "date_%s_16.webp" % hid, CG_DIR + String(s.cg)]
	if s.has("pfx"):
		cands.append("res://assets/v10/wave1/outfits/%s_base.webp" % String(s.pfx))
	cands.append(VIP_DIR + String(s.bg))
	cands.append(VIP_DIR + "boudoir_mc.webp")
	for c in cands:
		var t: = _load_tex(String(c))
		if t != null:
			return t
	return null


func _scroll_to_tab(i: int) -> void:
	if _tabs_scroll == null or not is_instance_valid(_tabs_scroll):
		return
	var step_x: = TAB_W + TAB_GAP
	var target: = int(2.0 + float(i) * step_x - (_tabs_scroll.size.x - TAB_W) * 0.5)
	var tw: = create_tween()
	tw.tween_property(_tabs_scroll, "scroll_horizontal", maxi(0, target), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		var t: = load(p) as Texture2D
		if t != null:
			return t
	var gp: = ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(gp):
		var im: = Image.load_from_file(gp)
		if im != null and not im.is_empty():
			return ImageTexture.create_from_image(im)
	return null


static func _pill(r: Rect2, bg: Color, border: Color, rad: int) -> Panel:
	return _lacquer_panel(r, bg, border, rad, 1)


static func _lacquer_panel(r: Rect2, bg: Color, border: Color, rad: int, bw: int = 1) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _add_top_sheen(parent: Control, w: float, a: float) -> void:
	var sh: = ColorRect.new()
	sh.color = Color(V10DS.PLATE_SPARK, a)
	sh.position = Vector2(12.0, 1.0)
	sh.size = Vector2(maxf(4.0, w - 24.0), 1.0)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sh)


static func _add_grad(parent: Control, r: Rect2, c0: Color, c1: Color) -> void:
	var g: = Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 8
	gt.height = 64
	var tr: = TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


static func _lbl(txt: String, role: String, sz: int, col: Color, on_art: bool) -> Label:
	var l: = Label.new()
	l.text = txt
	l.label_settings = V10Type.settings(role, sz, col, on_art)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _fit_one(l: Label, max_w: float, sizes: Array, role: String) -> int:
	var ls: LabelSettings = l.label_settings
	var chosen: int = int(sizes[sizes.size() - 1])
	for s in sizes:
		if V10Type.text_w(l.text, role, int(s)) <= max_w:
			chosen = int(s)
			break
	if ls != null:
		l.label_settings = V10Type.settings(role, chosen, ls.font_color, ls.shadow_size > 0)
	return chosen


static func _is_tap(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)


class _OathRingIcon:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x if size.x > 0.0 else 22.0
		var h: = size.y if size.y > 0.0 else 22.0
		var s: = minf(w, h)
		var c: = Vector2(w * 0.5, h * 0.60)
		var rad: = s * 0.27
		draw_arc(c, rad, 0.0, TAU, 28, V10DS.GOLD_700, maxf(2.0, s * 0.11), true)
		draw_arc(c, rad, 0.0, TAU, 28, V10DS.GOLD_300, maxf(1.1, s * 0.055), true)
		var gc: = Vector2(w * 0.5, c.y - rad - s * 0.05)
		var gd: = s * 0.17
		var gem_pts: = PackedVector2Array([
			gc + Vector2(0.0, -gd * 0.95),
			gc + Vector2(gd * 0.92, -gd * 0.18),
			gc + Vector2(gd * 0.52, gd * 0.68),
			gc + Vector2(-gd * 0.52, gd * 0.68),
			gc + Vector2(-gd * 0.92, -gd * 0.18),
		])
		draw_colored_polygon(gem_pts, V10DS.ROSE_300)
		for i in gem_pts.size():
			draw_line(gem_pts[i], gem_pts[(i + 1) % gem_pts.size()], V10DS.GOLD_300, 1.1, true)
