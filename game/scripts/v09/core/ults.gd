class_name V9Ults
extends RefCounted

# V9Ults — 0.9 ultimate data table and charge rules (docs/HEROINES.md §2, §5; docs/0.9-spec.md §B).
# Pure data + pure functions: nothing here touches the board, the scene tree or the save, so the cast code (play,
# hero stage, cut-in) and the selftest (--ults_selftest=1, scripts/v09/core/ults_selftest.gd) share one truth.
#
# DATA
#   V9Ults.ULTS[outfit_id] -> {
#     hero:      "mc" | "rin" | "hana" | "yue" | "nova"
#     name:      ult name, Russian (HEROINES.md §5)
#     lines:     2–3 short Russian shouts; pick with V9Ults.line() (no repeat of the last one)
#     palette:   {main: heroine signature colour, accent: outfit accent, ink: dark outline/text colour}
#     ref_img:   the outfit's OWN art (res://assets/outfits/<img>.webp; event outfits res://assets/v07/event/cg_*_card.webp). To draw, call V9Ults.shown(id), which
#                swaps retired (hidden) and, in modest mode, bold outfits to their "alt" art with that art's rects.
#     face_rect: Rect2 in 859×1280 art space: head-and-shoulders square, face at ~45 % height (close-up / eye strip:
#                SSR clips open on the top half of it). Scale to the real texture with V9Ults.rect_px().
#     alt_rect:  Rect2 in 859×1280 art space: head to waist (modest mode crop, HEROINES.md §2 «Скромный режим»).
#     mod:       "П" | "О" | "Л" | "В" | "Ц" | "С", or "" for the five base outfits (see MODS)
#     sfx:       name of the hit sound in res://assets/sfx (Sfx.play(sfx)) played on the strong beat
#     fx:        short key of the board visual from the §5 table (the cut-in / fx stream maps it to an effect)
#   }
#   V9Ults.CORES[hero]          heroine core, one for all her outfits: {name, desc, target, ...effect params}
#   V9Ults.RANKED_CORES[hero]   overrides merged over CORES in ranked play (pair-equivalent levelling)
#   V9Ults.MODS[letter]         {name, desc} of each outfit modifier
#
# QUERIES
#   V9Ults.has(id) -> bool                      every outfit in G.ITEM has an entry (selftest enforces)
#   V9Ults.get_ult(id) -> Dictionary            entry or {} (a duplicate is NOT made: do not mutate)
#   V9Ults.for_hero(hero) -> String             outfit id whose ult the heroine casts now (equipped or her base)
#   V9Ults.shown(id, modest = G modest) -> {img, face_rect, alt_rect}   art that is actually drawn + its rects
#   V9Ults.rect_px(r, tex_size) -> Rect2        art-space rect (859×1280) -> pixel rect of a texture of tex_size
#   V9Ults.line(id, last = -1) -> int           index of the shout to say (never `last` when there are 2+)
#   V9Ults.palette(id, gold = false) -> Dictionary    gold variant (fever / affection 7) shifts palette only
#   V9Ults.gold_variant(fever, aff_level) -> bool
#   V9Ults.core(hero, ranked) -> Dictionary     CORES merged with RANKED_CORES when ranked
#   V9Ults.mod(id, ranked) -> String            "" in ranked play (modifiers off)
#
# CHARGE RULES (pure)
#   V9Ults.need(aff_level, ranked) -> int       pairs to fill: 8, falling to 5 with affection (levels 4/7/10) off
#                                               ranked; always 6 in ranked
#   V9Ults.start_charge(rar, ranked, base) -> int   SR +2 / SSR +3 off ranked; base outfits and ranked start at 0
#   V9Ults.start_charge_for(id, ranked) -> int  same, from the outfit id (rarity from G.ITEM)
#   V9Ults.gain(from_ult) -> int                +1 per pair; pairs removed by an ult (from_ult) give 0
#   V9Ults.add(charge, need, from_ult) -> int   new charge, capped at need
#   V9Ults.is_ready(charge, need) -> bool
#   V9Ults.auto_cast_allowed(ranked) -> bool    smart auto-cast exists only off ranked
#   V9Ults.TARGET_TIME                          2 s to pick a target before the auto-target fires
#
# CUT-IN RULES (pure)
#   V9Ults.cutin_mode(setting, ranked, first_today, album = false) -> "full" | "short" | "off"
#       album always "full"; setting "off" -> "off"; ranked -> "short" (never full); setting "short" -> "short";
#       setting "full" -> "full" on the first ult of the day in this outfit (or the first wear), else "short".
#   V9Ults.beats(rar, hero) -> int              R/SR 4, SSR 6; Юэ waltzes: 3 (R/SR) / 6 (SSR, two bars of 3/4)
#   V9Ults.beat_len(rar, hero) -> float         seconds per beat (R/SR ≈1.33 s total, SSR ≈2 s)
#   V9Ults.clip_len(rar, hero, mode) -> float   full: beats × beat_len; short: SHORT_LEN (≤0.6 s); off: 0
#   Limits for the cut-in: MAX_FLASHES_PER_S = 3, FLASH_MAX = 0.7 (no white, never brighter than 70 %),
#   DIM = 0.6 (board dimmed to 60 %), TALK_CD = 4 s (a line is not repeated within 4 s).

const ART_SIZE: = Vector2(859, 1280)
const TARGET_TIME: = 2.0
const SHORT_LEN: = 0.6
const MAX_FLASHES_PER_S: = 3
const FLASH_MAX: = 0.7
const DIM: = 0.6
const TALK_CD: = 4.0

const NEED: = 8
const NEED_MIN: = 5
const NEED_RANKED: = 6
const START: = {"R": 0, "SR": 2, "SSR": 3}

const BASE: = {"mc": "o_base", "rin": "r_base", "hana": "h_base", "yue": "y_base", "nova": "n_base"}

const MODS: = {
	"П": {"name": "Подсказка", "desc": "подсвечивает 1 пару на 3 секунды"},
	"О": {"name": "Открытие", "desc": "открывает 1 закрытую фишку"},
	"Л": {"name": "Лёд", "desc": "растапливает 1 лёд или замок; без льда открывает фишку"},
	"В": {"name": "Возврат", "desc": "возвращает 1 фишку из лотка (у Рин +1 чашка пассивки)"},
	"Ц": {"name": "Цель", "desc": "видимая автоцель: пара, которая освобождает больше всего фишек"},
	"С": {"name": "Старшая", "desc": "подсвечивает пару для самой старой фишки в лотке"},
}

# target: how the player aims during TARGET_TIME — pair (tap a pair), swipe (direction of the dash),
# row (drag a beam along a row), tier (tap a layer), none (instant). auto_wait: when the smart auto-cast waits.
const CORES: = {
	"mc": {"name": "Снять пару", "desc": "снимает 1 пару", "target": "pair", "pairs": 1},
	"rin": {"name": "Вернуть лоток", "desc": "возвращает лоток на стол; если он пуст, снимает 1 пару", "target": "none",
		"return_tray": true, "empty_tray_pairs": 1, "auto_wait": "tray>=3"},
	"hana": {"name": "Рывок", "desc": "снимает 2 пары подряд", "target": "swipe", "pairs": 2},
	"yue": {"name": "Лунный свет", "desc": "открывает закрытые фишки и показывает пару", "target": "row",
		"reveal_all": true, "show_pair": true, "auto_wait": "closed_or_ice"},
	"nova": {"name": "Взлом", "desc": "снимает самую глубокую пару", "target": "tier", "pairs": 1, "deepest": true},
}
# ranked play levels the cores in pair-equivalents (spread ≤10 %, HEROINES.md §2)
const RANKED_CORES: = {
	"hana": {"desc": "снимает 1 пару и открывает 1 фишку", "pairs": 1, "reveal": 1},
	"rin": {"desc": "возвращает лоток на стол и подсвечивает пару", "highlight_pair": true},
	# ranked boards (blitz / zen / duel) have no secrets or ice, so «reveal everything» would be worth 0 there and
	# every secret + ice tile on a weekly tourney table: ranked Yue takes the pair nearest her beam + opens 1 tile
	"yue": {"desc": "снимает пару у луча и открывает 1 закрытую фишку", "reveal_all": false, "show_pair": false,
		"pairs": 1, "reveal": 1},
}

const _HANA_INK: = Color("7a3a0c")
const _MC_INK: = Color("6a1f45")
const _RIN_INK: = Color("16514a")
const _YUE_INK: = Color("3f2f7a")
const _NOVA_INK: = Color("0f3a5a")

# face / waist crops measured on the art (859×1280 space; 720×1073 files are the same framing scaled)
const RECTS: = {
	"hana_base": [Rect2(296, 95, 286, 286), Rect2(246, 37, 386, 483)],
	"hana_beach": [Rect2(229, 149, 286, 286), Rect2(184, 91, 375, 469)],
	"hana_gym": [Rect2(294, 125, 286, 286), Rect2(256, 67, 362, 453)],
	"hana_street": [Rect2(380, 121, 260, 260), Rect2(313, 68, 394, 492)],
	"hana_winter": [Rect2(282, 140, 286, 286), Rect2(242, 82, 366, 458)],
	"mc_base": [Rect2(297, 48, 260, 260), Rect2(219, 0, 416, 520)],
	"mc_cafe": [Rect2(322, 75, 260, 260), Rect2(261, 22, 382, 478)],
	"mc_cozy": [Rect2(322, 48, 260, 260), Rect2(244, 0, 416, 520)],
	"mc_dragon": [Rect2(287, 119, 286, 286), Rect2(230, 61, 399, 499)],
	"mc_tutor": [Rect2(222, 75, 260, 260), Rect2(145, 22, 414, 518)],
	"nova_base": [Rect2(338, 126, 260, 260), Rect2(273, 73, 390, 487)],
	"nova_offline": [Rect2(322, 125, 260, 260), Rect2(257, 72, 390, 488)],
	"nova_ssr": [Rect2(320, 209, 221, 221), Rect2(256, 164, 349, 436)],
	"rin_after": [Rect2(276, 108, 299, 299), Rect2(237, 48, 378, 472)],
	"rin_agent": [Rect2(317, 104, 286, 286), Rect2(254, 46, 411, 514)],
	"rin_base": [Rect2(291, 123, 286, 286), Rect2(236, 65, 396, 495)],
	"rin_idol": [Rect2(285, 149, 286, 286), Rect2(240, 91, 375, 469)],
	"rin_maid": [Rect2(312, 195, 260, 260), Rect2(275, 142, 334, 418)],
	"rin_yukata": [Rect2(292, 150, 260, 260), Rect2(237, 97, 370, 463)],
	"yue_ball": [Rect2(311, 120, 260, 260), Rect2(244, 67, 394, 493)],
	"yue_base": [Rect2(280, 137, 260, 260), Rect2(220, 84, 381, 476)],
	"yue_duel": [Rect2(299, 135, 260, 260), Rect2(222, 82, 414, 518)],
	"yue_queen": [Rect2(313, 151, 260, 260), Rect2(234, 98, 418, 522)],
	# event outfits (V7EventData.limited_items): close-up cards, faces are larger
	"cg_mc_card": [Rect2(168, 175, 468, 468), Rect2(74, 80, 656, 820)],
	"cg_rin_card": [Rect2(449, 140, 390, 390), Rect2(308, 61, 551, 689)],
	"cg_hana_card": [Rect2(417, 145, 442, 442), Rect2(163, 55, 696, 870)],
	"cg_yue_card": [Rect2(136, 117, 338, 338), Rect2(66, 48, 478, 597)],
	"cg_nova_card": [Rect2(559, 148, 234, 234), Rect2(491, 100, 368, 460)],
}

const ULTS: = {
	# ── Маджонг-тян: сакура ff8fb8 + нефрит. Ядро: снимает 1 пару.
	"o_base": {"hero": "mc", "name": "Восточный ветер", "lines": ["Восточный ветер!", "Партия окончена~", "Лови 東!"],
		"palette": {"main": Color("ff8fb8"), "accent": Color("5fcf9f"), "ink": _MC_INK},
		"ref_img": "res://assets/outfits/mc_base.webp", "face_rect": Rect2(297, 48, 260, 260), "alt_rect": Rect2(219, 0, 416, 520),
		"mod": "", "sfx": "whoosh", "fx": "east_heart"},
	"o_tutor": {"hero": "mc", "name": "Разбор партии", "lines": ["Разбор партии!", "Запиши этот яку."],
		"palette": {"main": Color("ff8fb8"), "accent": Color("f2e6c8"), "ink": _MC_INK},
		"ref_img": "res://assets/outfits/mc_tutor.webp", "face_rect": Rect2(222, 75, 260, 260), "alt_rect": Rect2(145, 22, 414, 518),
		"mod": "П", "sfx": "sparkle", "fx": "chalk_circle"},
	"o_cafe": {"hero": "mc", "name": "Комплимент от заведения", "lines": ["Комплимент от заведения!", "Чай подан~", "За счёт салона!"],
		"palette": {"main": Color("ff8fb8"), "accent": Color("8fd6b8"), "ink": _MC_INK},
		"ref_img": "res://assets/outfits/mc_cafe.webp", "face_rect": Rect2(322, 75, 260, 260), "alt_rect": Rect2(261, 22, 382, 478),
		"mod": "В", "sfx": "whoosh", "fx": "tea_stream"},
	"o_cozy": {"hero": "mc", "name": "Тёплый плед", "lines": ["Тёплый плед!", "Не мёрзни~", "Посидим ещё?"],
		"palette": {"main": Color("ff8fb8"), "accent": Color("f2b48a"), "ink": _MC_INK},
		"ref_img": "res://assets/outfits/mc_cozy.webp", "face_rect": Rect2(322, 48, 260, 260), "alt_rect": Rect2(244, 0, 416, 520),
		"mod": "О", "sfx": "sparkle", "fx": "knit_heart"},
	"o_dragon": {"hero": "mc", "name": "Пробуждение дракона", "lines": ["Пробудись, дракон!", "Партия окончена~", "Нефрит и пламя!"],
		"palette": {"main": Color("ff8fb8"), "accent": Color("ffc93c"), "ink": Color("6a1020")},
		"ref_img": "res://assets/outfits/mc_dragon.webp", "face_rect": Rect2(287, 119, 286, 286), "alt_rect": Rect2(230, 61, 399, 499),
		# 0.9: until mc_dragon is redrawn in the v2 direction (its face reads rounder / younger than her base art),
		# the SSR eye close-up crops her base painting's mature face instead (eye_img / eye_rect, cutin.gd)
		"eye_img": "res://assets/outfits/mc_base.webp", "eye_rect": Rect2(297, 48, 260, 260),
		"mod": "Л", "sfx": "summon_boom", "fx": "jade_dragon"},
	# ── Рин: нефрит 4fbf9f, золотые очки. Ядро: возвращает лоток (пуст — снимает пару).
	"r_base": {"hero": "rin", "name": "Чайная пауза", "lines": ["Позволь.", "Чайная пауза.", "Не торопись."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("e8d9a8"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_base.webp", "face_rect": Rect2(291, 123, 286, 286), "alt_rect": Rect2(236, 65, 396, 495),
		"mod": "", "sfx": "whoosh", "fx": "tea_stream"},
	"r_maid": {"hero": "rin", "name": "Безупречный сервис", "lines": ["Позволь, гость.", "Безупречно.", "Всё на своих местах."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("c9f2df"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_maid.webp", "face_rect": Rect2(312, 195, 260, 260), "alt_rect": Rect2(275, 142, 334, 418),
		"mod": "Л", "sfx": "clack0", "fx": "cloche_line"},
	"r_after": {"hero": "rin", "name": "Последняя чашка", "lines": ["Зови меня просто Рин.", "Последняя чашка.", "Позволь."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("d9a55a"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_after.webp", "face_rect": Rect2(276, 108, 299, 299), "alt_rect": Rect2(237, 48, 378, 472),
		"mod": "В", "sfx": "sparkle", "fx": "last_cup"},
	"r_yukata": {"hero": "rin", "name": "Ханаби", "lines": ["Ханаби!", "Смотри, огни…", "Позволь."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("ff9a8a"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_yukata.webp", "face_rect": Rect2(292, 150, 260, 260), "alt_rect": Rect2(237, 97, 370, 463),
		"mod": "О", "sfx": "sparkle", "fx": "lantern_return"},
	"r_agent": {"hero": "rin", "name": "Чистая операция", "lines": ["Чистая операция.", "Цель в прицеле.", "Позволь."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("ff4fa8"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_agent.webp", "face_rect": Rect2(317, 104, 286, 286), "alt_rect": Rect2(254, 46, 411, 514),
		"mod": "П", "sfx": "reveal_sr", "fx": "laser_grid"},
	"r_idol": {"hero": "rin", "name": "Бис!", "lines": ["Бис!", "Свет на сцену!", "Это для тебя."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("ffd76a"), "ink": _RIN_INK},
		"ref_img": "res://assets/outfits/rin_idol.webp", "face_rect": Rect2(285, 149, 286, 286), "alt_rect": Rect2(240, 91, 375, 469),
		"mod": "Ц", "sfx": "reveal_ssr", "fx": "spotlight_stars"},
	# ── Хана: ffb35c, подсолнух. Ядро: снимает 2 пары подряд.
	"h_base": {"hero": "hana", "name": "Рывок", "lines": ["На старт!", "Рывок!", "Не отставай!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("ff7a5c"), "ink": _HANA_INK},
		"ref_img": "res://assets/outfits/hana_base.webp", "face_rect": Rect2(296, 95, 286, 286), "alt_rect": Rect2(246, 37, 386, 483),
		"mod": "", "sfx": "whoosh", "fx": "orange_trail"},
	"h_street": {"hero": "hana", "name": "Граффити-спринт", "lines": ["Граффити-спринт!", "На старт!", "Догоняй!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("9b7bff"), "ink": _HANA_INK},
		"ref_img": "res://assets/outfits/hana_street.webp", "face_rect": Rect2(380, 121, 260, 260), "alt_rect": Rect2(313, 68, 394, 492),
		"mod": "Ц", "sfx": "whoosh", "fx": "spray_arrow"},
	"h_beach": {"hero": "hana", "name": "Подача на вылет", "lines": ["Лови, если сможешь!", "Подача!", "На старт!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("5fd8e8"), "ink": _HANA_INK},
		"ref_img": "res://assets/outfits/hana_beach.webp", "face_rect": Rect2(229, 149, 286, 286), "alt_rect": Rect2(184, 91, 375, 469),
		"mod": "О", "sfx": "clack1", "fx": "serve_ball"},
	"h_winter": {"hero": "hana", "name": "Тройной аксель", "lines": ["Тройной аксель!", "Держи равновесие!", "На старт!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("9fe0ff"), "ink": _HANA_INK},
		"ref_img": "res://assets/outfits/hana_winter.webp", "face_rect": Rect2(282, 140, 286, 286), "alt_rect": Rect2(242, 82, 366, 458),
		"mod": "Л", "sfx": "sparkle", "fx": "ice_arc"},
	"h_gym": {"hero": "hana", "name": "Рекорд зала", "lines": ["Рекорд зала!", "Дай пять!", "На старт!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("ffd84f"), "ink": _HANA_INK},
		"ref_img": "res://assets/outfits/hana_gym.webp", "face_rect": Rect2(294, 125, 286, 286), "alt_rect": Rect2(256, 67, 362, 453),
		"mod": "С", "sfx": "win", "fx": "confetti_five"},
	# ── Юэ: c8b6ff, рожки и тиара. Ядро: открывает закрытые фишки и показывает пару.
	"y_base": {"hero": "yue", "name": "Лунный свет", "lines": ["Лунный свет.", "Любопытно…", "Смотри внимательно."],
		"palette": {"main": Color("c8b6ff"), "accent": Color("e9e4ff"), "ink": _YUE_INK},
		"ref_img": "res://assets/outfits/yue_base.webp", "face_rect": Rect2(280, 137, 260, 260), "alt_rect": Rect2(220, 84, 381, 476),
		"mod": "", "sfx": "reveal_sr", "fx": "silver_wave"},
	"y_duel": {"hero": "yue", "name": "Выпад полумесяца", "lines": ["Выпад полумесяца!", "Любопытно…", "Защищайся."],
		"palette": {"main": Color("c8b6ff"), "accent": Color("5b7bff"), "ink": _YUE_INK},
		"ref_img": "res://assets/outfits/yue_duel.webp", "face_rect": Rect2(299, 135, 260, 260), "alt_rect": Rect2(222, 82, 414, 518),
		"mod": "Ц", "sfx": "whoosh", "fx": "crescent_slash"},
	"y_queen": {"hero": "yue", "name": "Затмение", "lines": ["Затмение.", "Любопытно…", "Звёзды, свяжитесь."],
		"palette": {"main": Color("c8b6ff"), "accent": Color("3b3f9f"), "ink": _YUE_INK},
		"ref_img": "res://assets/outfits/yue_queen.webp", "face_rect": Rect2(313, 151, 260, 260), "alt_rect": Rect2(234, 98, 418, 522),
		"mod": "П", "sfx": "reveal_ssr", "fx": "constellation"},
	"y_ball": {"hero": "yue", "name": "Последний вальс", "lines": ["Последний вальс.", "Раз, два, три…", "Любопытно…"],
		"palette": {"main": Color("c8b6ff"), "accent": Color("b8c2d6"), "ink": _YUE_INK},
		"ref_img": "res://assets/outfits/yue_ball.webp", "face_rect": Rect2(311, 120, 260, 260), "alt_rect": Rect2(244, 67, 394, 493),
		"mod": "В", "sfx": "reveal_ssr", "fx": "waltz"},
	# ── Нова: 4fe3ff + ff6fd8, наушники и визор. Ядро: снимает самую глубокую пару.
	"n_base": {"hero": "nova", "name": "Взлом", "lines": ["Скачано.", "Взлом!", "Доступ получен."],
		"palette": {"main": Color("4fe3ff"), "accent": Color("ff6fd8"), "ink": _NOVA_INK},
		"ref_img": "res://assets/outfits/nova_base.webp", "face_rect": Rect2(338, 126, 260, 260), "alt_rect": Rect2(273, 73, 390, 487),
		"mod": "", "sfx": "gem", "fx": "neon_thread"},
	"n_ssr": {"hero": "nova", "name": "Форсаж", "lines": ["Форсаж!", "Скачано.", "Газ в пол!"],
		"palette": {"main": Color("4fe3ff"), "accent": Color("c86fff"), "ink": _NOVA_INK},
		"ref_img": "res://assets/outfits/nova_ssr.webp", "face_rect": Rect2(320, 209, 221, 221), "alt_rect": Rect2(256, 164, 349, 436),
		"mod": "О", "sfx": "summon_boom", "fx": "neon_drift"},
	"n_offline": {"hero": "nova", "name": "Режим офлайн", "lines": ["…давай просто посидим.", "Режим офлайн.", "Скачано. Шучу."],
		"palette": {"main": Color("4fe3ff"), "accent": Color("ffb8e6"), "ink": _NOVA_INK},
		"ref_img": "res://assets/outfits/nova_offline.webp", "face_rect": Rect2(322, 125, 260, 260), "alt_rect": Rect2(257, 72, 390, 488),
		"mod": "В", "sfx": "sparkle", "fx": "offline"},
	# ── event outfits (SSR, limited; not in the §5 tables — names in the same voice). From a heroine's 6th outfit a
	# modifier may repeat if it came from another rarity (§2); the §5 slots of future outfits are left free.
	"ev_mc": {"hero": "mc", "name": "Последний гость", "lines": ["Табличка «закрыто»!", "Только для своих~", "Партия окончена~"],
		"palette": {"main": Color("ff8fb8"), "accent": Color("ffcf8a"), "ink": _MC_INK},
		"ref_img": "res://assets/v07/event/cg_mc_card.webp", "face_rect": Rect2(168, 175, 468, 468), "alt_rect": Rect2(74, 80, 656, 820),
		"mod": "В", "sfx": "sparkle", "fx": "lamp_dim"},
	"ev_rin": {"hero": "rin", "name": "Рой светлячков", "lines": ["Позволь.", "Светлячки, ко мне.", "Посидим у пруда."],
		"palette": {"main": Color("4fbf9f"), "accent": Color("fff0a0"), "ink": _RIN_INK},
		"ref_img": "res://assets/v07/event/cg_rin_card.webp", "face_rect": Rect2(449, 140, 390, 390), "alt_rect": Rect2(308, 61, 551, 689),
		"mod": "С", "sfx": "sparkle", "fx": "fireflies"},
	"ev_hana": {"hero": "hana", "name": "Финиш на закате", "lines": ["На старт!", "До заката!", "Бежим вместе!"],
		"palette": {"main": Color("ffb35c"), "accent": Color("ff7a8a"), "ink": _HANA_INK},
		"ref_img": "res://assets/v07/event/cg_hana_card.webp", "face_rect": Rect2(417, 145, 442, 442), "alt_rect": Rect2(163, 55, 696, 870),
		"mod": "Ц", "sfx": "whoosh", "fx": "sunset_lane"},
	"ev_yue": {"hero": "yue", "name": "Роса полнолуния", "lines": ["Любопытно…", "Полнолуние.", "Роса, проснись."],
		"palette": {"main": Color("c8b6ff"), "accent": Color("9fd8ff"), "ink": _YUE_INK},
		"ref_img": "res://assets/v07/event/cg_yue_card.webp", "face_rect": Rect2(136, 117, 338, 338), "alt_rect": Rect2(66, 48, 478, 597),
		"mod": "О", "sfx": "reveal_sr", "fx": "moon_dew"},
	"ev_nova": {"hero": "nova", "name": "Зелёная волна", "lines": ["Скачано.", "Все светофоры мои!", "Догоняй."],
		"palette": {"main": Color("4fe3ff"), "accent": Color("ff6fd8"), "ink": _NOVA_INK},
		"ref_img": "res://assets/v07/event/cg_nova_card.webp", "face_rect": Rect2(559, 148, 234, 234), "alt_rect": Rect2(491, 100, 368, 460),
		"mod": "Ц", "sfx": "gem", "fx": "green_wave"},
}


static func has(id: String) -> bool:
	return ULTS.has(id)


static func get_ult(id: String) -> Dictionary:
	return ULTS.get(id, {})


# the outfit whose ult the heroine casts: the equipped one, or her base outfit (G.equipped() returns "" for a base)
static func for_hero(hero: String) -> String:
	var id: String = G.equipped(hero) if G.S is Dictionary and G.S.has("outfit") else ""
	if id != "" and ULTS.has(id):
		return id
	return String(BASE.get(hero, "o_base"))


# the art actually drawn for this outfit and its rects: a retired (hidden) outfit and, in modest mode, a bold one
# show their "alt" art (same rules as G.item_img / G.art_tex)
static func shown(id: String, modest = null) -> Dictionary:
	var u: = get_ult(id)
	var img: String = u.get("ref_img", "")
	var it: Dictionary = G.ITEM.get(id, {})
	if modest == null:
		modest = bool(G.S.get("modest", false)) if G.S is Dictionary else false
	var alt: = ""
	if it.has("alt") and (it.get("hidden", false) or (modest and it.get("bold", false))):
		alt = String(it.alt)
	if alt != "":
		img = ("res://assets/outfits/%s.webp" % alt).simplify_path()
	var key: = img.get_file().get_basename()
	var r: Array = RECTS.get(key, [u.get("face_rect", Rect2(Vector2.ZERO, ART_SIZE)), u.get("alt_rect", Rect2(Vector2.ZERO, ART_SIZE))])
	return {"img": img, "face_rect": r[0], "alt_rect": r[1]}


static func rect_px(r: Rect2, tex_size: Vector2) -> Rect2:
	var k: = tex_size / ART_SIZE
	return Rect2(r.position * k, r.size * k)


static func line(id: String, last: = -1) -> int:
	var n: int = get_ult(id).get("lines", []).size()
	if n <= 0:
		return -1
	var i: = randi() % n
	if n > 1 and i == last:
		i = (i + 1) % n
	return i


static func gold_variant(fever: bool, aff_level: int) -> bool:
	return fever or aff_level >= 7


static func palette(id: String, gold: = false) -> Dictionary:
	var p: Dictionary = get_ult(id).get("palette", {"main": Color.WHITE, "accent": Color.WHITE, "ink": Color.BLACK})
	if not gold:
		return p
	var g: = Color("ffc93c")
	return {"main": p.main.lerp(g, 0.45), "accent": g, "ink": p.ink}


static func core(hero: String, ranked: = false) -> Dictionary:
	var c: Dictionary = CORES.get(hero, CORES.mc).duplicate()
	if ranked and RANKED_CORES.has(hero):
		c.merge(RANKED_CORES[hero], true)
	c["hero"] = hero
	return c


static func mod(id: String, ranked: = false) -> String:
	if ranked:
		return ""
	return String(get_ult(id).get("mod", ""))


# ── charge rules ─────────────────────────────────────────────────────────────

static func need(aff_level: int, ranked: = false) -> int:
	if ranked:
		return NEED_RANKED
	return maxi(NEED_MIN, NEED - mini(NEED - NEED_MIN, maxi(0, aff_level - 1) / 3))


static func start_charge(rar: String, ranked: = false, base: = false) -> int:
	if ranked or base:
		return 0
	return int(START.get(rar, 0))


static func start_charge_for(id: String, ranked: = false) -> int:
	var it: Dictionary = G.ITEM.get(id, {})
	return start_charge(String(it.get("rar", "R")), ranked, id in G.BASE_OUTFITS)


static func gain(from_ult: bool) -> int:
	return 0 if from_ult else 1


static func add(charge: int, need_n: int, from_ult: = false) -> int:
	return clampi(charge + gain(from_ult), 0, need_n)


static func is_ready(charge: int, need_n: int) -> bool:
	return need_n > 0 and charge >= need_n


static func auto_cast_allowed(ranked: bool) -> bool:
	return not ranked


# ── cut-in rules ─────────────────────────────────────────────────────────────

static func cutin_mode(setting: String, ranked: bool, first_today: bool, album: = false) -> String:
	if album:
		return "full"
	if setting == "off":
		return "off"
	if ranked or setting == "short":
		return "short"
	return "full" if first_today else "short"


static func beats(rar: String, hero: = "") -> int:
	if rar == "SSR":
		return 6
	return 3 if hero == "yue" else 4


static func beat_len(rar: String, hero: = "") -> float:
	if hero == "yue" and rar != "SSR":
		return 4.0 / 9.0
	return 1.0 / 3.0


static func clip_len(rar: String, hero: = "", mode: = "full") -> float:
	match mode:
		"off":
			return 0.0
		"short":
			return SHORT_LEN
	return beats(rar, hero) * beat_len(rar, hero)
