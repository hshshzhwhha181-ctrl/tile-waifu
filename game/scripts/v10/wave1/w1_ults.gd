class_name V10W1Ults
extends RefCounted

# V10W1Ults — the Ultimates of the five wave-1 goddesses (Цубамэ, Миэль, Кохаку, Ширин, Злата) in V9Ults' exact schema
# (docs/HEROINES.md §2, docs/ROSTER_20.md §1.6 and §3.2–3.4 cards, docs/MODES.md §5.5). Pure data + pure helpers, never
# gated here: the facade V10Wave1.released() gates every consumer hook (see HOOKS at the end of this header).
#
# DATA (mirrors scripts/v09/core/ults.gd)
#   V10W1Ults.ULTS[outfit_id] -> {hero, name, lines, palette {main, accent, ink}, ref_img, mod, sfx, fx,
#                                 desc (the visual line of ROSTER, Russian), particles (V10KitData.PARTICLES kind),
#                                 motif (art key of the clip's sparks)}
#       face_rect / alt_rect are NOT in the const: get_ult(id) adds them, read once from data/w1_art_cards.json
#       (art-cards agent) and converted to V9Ults.ART_SIZE (859×1280) art space. A card the JSON does not list yet
#       (sh_sun is pending audit) gets a centred default rect, and rects_measured(id) is false (the selftest flags it).
#   V10W1Ults.CORES[hero]         heroine core, one for all her outfits: {name, desc, rule, target, pairs, …effect params}
#   V10W1Ults.RANKED_CORES[hero]  overrides merged over CORES in ranked play (1 pair-equivalent each, HEROINES §2)
#   V10W1Ults.BASE[hero]          her base outfit (no modifier, start charge 0)
#   V10W1Ults.RAR[outfit_id]      rarity code of ROSTER §3 (A→"R", S→"SR", SSR→"SSR"), for the checks and start charge
#   V10W1Ults.TRIPLES_EFFECT / TRIPLES_DESC[hero]   the core adapted to the Тройки tray (V10MjTriplesUlts.EFFECT schema)
#
# Effect keys of the cores (read by the cast helpers below; every core also carries `pairs`, the pairs it removes
# when its own trick has nothing to work on, so V9UltCast's default branch is a correct fallback):
#   pinned       Цубамэ: only pairs whose tiles are not covered from above; side-pinned ones first
#   joker        Миэль: a cookie waits in the tray; the next tile that comes into the tray leaves at once with its twin
#                from the table (1 pair). One cookie at a time; an empty tray (or a cookie already waiting) = 1 pair.
#   charm        Кохаку: an ofuda on the tray; when the tray would overflow it burns and takes the oldest tray tile with
#   charm_burn   its twin from the table (2 tiles = 1 pair) instead of the loss. One charm at a time; a second cast = 1 pair.
#   fever        Ширин: 1 pair, then fever by the usual rules (play._fever); ranked: fever_charge (+0.06 = half a combo
#   fever_charge step of the 0.12×combo meter) instead
#   melt_line    Злата: the pair, then every ice and lock on the line between its two tiles; ranked: melt 1 (one ice or lock)
#   highlight_pair   lights 1 pair for 3 s (Кохаку, off ranked)
#
# QUERIES
#   has(id) / ids() / is_hero(hero) / is_base(id) / base(hero) / rar(id) / heroes()
#   get_ult(id) -> Dictionary                    entry + face_rect / alt_rect (cached; do not mutate)
#   core(hero, ranked) -> Dictionary             CORES merged with RANKED_CORES when ranked (+ "hero")
#   mod(id, ranked) -> String                    "" in ranked play
#   shown(id, modest) -> {img, face_rect, alt_rect}   V9Ults.shown() for wave-1 art (alt art: wave-1 dir + its rects)
#   rects(id) -> [face_rect, alt_rect, measured]  rects_measured(id) -> bool   reload() re-reads the JSON (tests)
#   pe_removal(hero, ranked) -> float            pair-equivalents a cast removes (ranked: 1.0 for each, ±10 %)
#   triples_core(hero) -> Dictionary             V10MjTriplesUlts.core() shape for the five
#   problems(strict) -> Array[String]            the data checks (empty = pass); strict adds art files + G integration
#
# CAST (called from V9UltCast hooks; `cast` is the V9UltCast node, duck-typed so this file stays data-first)
#   cast_pairs(cast, ps) -> Array          Цубамэ's target set (uncovered pairs, side-pinned first), others unchanged
#   cast_blocked(cast) -> String           the «nothing to do» line, "" when the cast may go
#   cast_auto_pick(cast) -> Dictionary     {pairs: […]} auto-target (Ц: the pair that frees the most; Злата: the most ice)
#   cast_apply(cast, pick, col) -> void    her core on the strong beat (the modifier still runs after, in V9UltCast)
#   cast_expect(hero, ranked, tray_empty, charm_on, joker_on) -> int   pairs the cast removes at once (live selftest)
#   joker_on(board) / charm_on(board) -> bool    a cookie / charm is waiting on this board
#
# CUT-IN: V9Cutin needs nothing new — palette (main = G.HEROES[hero].color, accent per outfit, ink luminance < 0.3),
# ref_img + face_rect (art panel / SSR eye strip), lines, sfx (res://assets/sfx/<sfx>.wav on the strong beat). Its flash is
# flash_color(main): saturation ≥ 0.45, value ≤ V9Ults.FLASH_MAX, ≤ 3 per second across clips — never white, also for
# Кохаку's near-white f3efe9 (problems() checks every palette through V9Cutin.flash_color). The board visuals of the
# cast helpers (smoke row, coins, fire trail, cookie, ofuda) are soft palette marks, no flashes, skipped under the
# strip (V9Cutin.covers) and at fx «min» (V9Feel.can_fx); the cookie and the ofuda are state markers and always show.
#
# HOOKS (the integrator adds them; founders are untouched while V10Wave1.released() is false)
#   scripts/v09/core/ults.gd
#     has():            return ULTS.has(id) or (V10Wave1.released() and V10W1Ults.has(id))
#     get_ult():        if not ULTS.has(id) and V10Wave1.released() and V10W1Ults.has(id): return V10W1Ults.get_ult(id)
#     for_hero():       `ULTS.has(id)` -> `has(id)`; before the BASE fallback:
#                       if V10Wave1.released() and V10W1Ults.is_hero(hero): return V10W1Ults.base(hero)
#     shown():          if not ULTS.has(id) and V10Wave1.released() and V10W1Ults.has(id): return V10W1Ults.shown(id, modest)
#     core():           if not CORES.has(hero) and V10Wave1.released() and V10W1Ults.is_hero(hero): return V10W1Ults.core(hero, ranked)
#     start_charge_for(): base flag `id in G.BASE_OUTFITS or V10W1Ults.is_base(id)`
#   scripts/v09/ult/ult_cast.gd   pairs() / blocked() / auto_pick() / _apply() (a wave-1 hero is a partner only when released)
#   scripts/v10/mj/triples/ults_triples.gd   core(): if not EFFECT.has(hero) and V10Wave1.released() and
#                       V10W1Ults.is_hero(hero): return V10W1Ults.triples_core(hero)
#   The exact lines are in the lane report (and wave1/README.md once the integrator writes it).

const HEROES: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const ART_DIR: = "res://assets/v10/wave1/outfits/"
const CARDS_PATH: = "res://scripts/v10/wave1/data/w1_art_cards.json"
# the wave-1 outfit cards are 850×1280 (founders 859×1280); the JSON's own `size` wins when it is there
const ART_PX: = Vector2(850, 1280)
const FACE_MIN: = 180.0
const FACE_MAX: = 480.0

const BASE: = {"tsubame": "tb_base", "miel": "me_base", "kohaku": "ko_base", "shirin": "sh_base", "zlata": "zl_base"}
# G.HEROES[hero].color = the palette main of every ult (ROSTER §2; Цубамэ and Миэль use their accent so the name
# reads on dark UI)
const HERO_COLOR: = {"tsubame": Color("c8283c"), "miel": Color("e0566f"), "kohaku": Color("f3efe9"),
	"shirin": Color("d9b26f"), "zlata": Color("c3242b")}
# ROSTER §3 ranks in code letters (A→R, S→SR, SSR→SSR); vows are Симпатия 10 «Обет» rewards (nogacha)
const RAR: = {
	"tb_base": "R", "tb_post": "SR", "tb_crimson": "SSR",
	"me_base": "R", "me_parlor": "SR", "me_gala": "SSR",
	"ko_base": "SR", "ko_matsuri": "R", "ko_kyubi": "SSR", "ko_vow": "SSR",
	"sh_base": "SR", "sh_oasis": "R", "sh_sun": "SSR", "sh_night": "SSR",
	"zl_base": "SSR", "zl_fair": "SR", "zl_ember": "SSR", "zl_vow": "SSR",
}
const VOWS: = ["ko_vow", "zl_vow"]

# target: as V9Ults.CORES (pair / swipe / row / tier / none). desc is the short line of «Приём «…»: …» (levels screen,
# ≤ 45 letters); rule is the whole rule for help / glossary cards.
const CORES: = {
	"tsubame": {"name": "Теневой шаг", "desc": "снимает пару, зажатую соседями сбоку",
		"rule": "Снимает пару, у которой фишки зажаты соседями сбоку, но не накрыты сверху. Коснись фишки — вторую она найдёт сама. Если таких пар нет, снимает любую открытую.",
		"target": "pair", "pairs": 1, "pinned": true},
	"miel": {"name": "Печенье-джокер", "desc": "печенье в лотке станет парой следующей фишке",
		"rule": "Кладёт в лоток печенье-джокер: следующая фишка в лотке сразу уходит вместе со своей парой со стола. Печенье в лотке одно. Если лоток пуст, снимает 1 пару.",
		"target": "none", "pairs": 1, "joker": 1},
	"kohaku": {"name": "Лисий оберег", "desc": "оберег на лотке спасёт от переполнения",
		"rule": "Вешает на лоток оберег. Если лоток переполнится, оберег сгорит и унесёт старую фишку лотка вместе с её парой — без проигрыша. Сразу подсвечивает 1 пару. Оберег один: если он уже висит, снимает 1 пару.",
		"target": "none", "pairs": 1, "charm": 1, "charm_burn": 2, "highlight_pair": true},
	"shirin": {"name": "Танец монет", "desc": "снимает 1 пару и зажигает Азарт",
		"rule": "Снимает 1 пару и сразу зажигает Азарт по обычным правилам.",
		"target": "pair", "pairs": 1, "fever": true},
	"zlata": {"name": "Огненный шлейф", "desc": "снимает пару, растапливая лёд на её пути",
		"rule": "Снимает выбранную пару и растапливает весь лёд и замки на линии между двумя её фишками.",
		"target": "pair", "pairs": 1, "melt_line": true},
}
# ranked (duel, Блиц, Сад, турнир недели): 1 pair-equivalent each plus at most one small extra, like the founders
# (Хана: пара + 1 открытие, Рин: лоток + подсветка). Цубамэ and Миэль are 1 pair already (ROSTER: «Рейт.: 1 пара»).
const RANKED_CORES: = {
	"kohaku": {"rule": "Вешает на лоток оберег. Если лоток переполнится, оберег сгорит и унесёт старую фишку лотка вместе с её парой — без проигрыша. Оберег один: если он уже висит, снимает 1 пару.",
		"highlight_pair": false},
	"shirin": {"desc": "снимает 1 пару и копит Азарт",
		"rule": "Снимает 1 пару и добавляет шкале Азарта полступени комбо.", "fever": false, "fever_charge": 0.06},
	"zlata": {"desc": "снимает пару и растапливает 1 лёд",
		"rule": "Снимает выбранную пару и растапливает 1 лёд или замок, сначала на её линии.", "melt_line": false, "melt": 1},
}

const _TB_INK: = Color("1d1b2e")
const _ME_INK: = Color("5a2e1e")
const _KO_INK: = Color("5a1a14")
const _SH_INK: = Color("1a3f3c")
const _ZL_INK: = Color("1b1513")

# ULTS order: per heroine, base first (the mod-repeat rule of V9UltsSelftest walks them in this order)
const ULTS: = {
	# ── Цубамэ: алый c8283c на индиго 1d1b2e, сталь a9b0c2. Ядро: Теневой шаг (зажатая пара). Дым и ласточки.
	"tb_base": {"hero": "tsubame", "name": "Теневой шаг", "lines": ["Теневой шаг.", "Доставлено.", "Тень знает дорогу."],
		"palette": {"main": Color("c8283c"), "accent": Color("a9b0c2"), "ink": _TB_INK},
		"ref_img": "res://assets/v10/wave1/outfits/tb_base.webp", "mod": "", "sfx": "whoosh", "fx": "shadow_step",
		"desc": "Силуэт проходит сквозь ряд", "particles": "dust", "motif": "smoke"},
	"tb_post": {"hero": "tsubame", "name": "Срочная доставка", "lines": ["Срочная доставка!", "Лично в руки.", "Доставлено."],
		"palette": {"main": Color("c8283c"), "accent": Color("e6d3a8"), "ink": _TB_INK},
		"ref_img": "res://assets/v10/wave1/outfits/tb_post.webp", "mod": "П", "sfx": "flip", "fx": "envelope_fly",
		"desc": "Конверт уносит пару", "particles": "dust", "motif": "letters"},
	"tb_crimson": {"hero": "tsubame", "name": "Танец ласточек", "lines": ["Танец ласточек.", "Стая, за мной!", "Доставлено."],
		"palette": {"main": Color("c8283c"), "accent": Color("f0c9c4"), "ink": _TB_INK},
		"ref_img": "res://assets/v10/wave1/outfits/tb_crimson.webp", "mod": "Л", "sfx": "reveal_ssr", "fx": "swallow_flock",
		"desc": "Стая ласточек сносит пару", "particles": "feathers", "motif": "swallows"},
	# ── Миэль: малина e0566f, крем f6e7cf, карамель c98a4b. Ядро: Печенье-джокер. Сахар и торт.
	"me_base": {"hero": "miel", "name": "Печенье-джокер", "lines": ["Попробуй!", "Печенье-джокер!", "С пылу с жару~"],
		"palette": {"main": Color("e0566f"), "accent": Color("e9b45a"), "ink": _ME_INK},
		"ref_img": "res://assets/v10/wave1/outfits/me_base.webp", "mod": "", "sfx": "gem", "fx": "joker_cookie",
		"desc": "Золотое печенье прыгает в лоток", "particles": "sparks", "motif": "sugar"},
	"me_parlor": {"hero": "miel", "name": "Чайная пара", "lines": ["Чайная пара!", "К чаю — сладкое.", "Попробуй!"],
		"palette": {"main": Color("e0566f"), "accent": Color("c98a4b"), "ink": _ME_INK},
		"ref_img": "res://assets/v10/wave1/outfits/me_parlor.webp", "mod": "В", "sfx": "clack0", "fx": "tea_tray",
		"desc": "Пара уплывает на подносе", "particles": "sparks", "motif": "sugar"},
	"me_gala": {"hero": "miel", "name": "Многоярусный торт", "lines": ["Многоярусный торт!", "Ярус за ярусом~", "Попробуй!"],
		"palette": {"main": Color("e0566f"), "accent": Color("f6e7cf"), "ink": _ME_INK},
		"ref_img": "res://assets/v10/wave1/outfits/me_gala.webp", "mod": "О", "sfx": "win", "fx": "cake_tiers",
		"desc": "Фишки становятся ярусами торта и тают", "particles": "sparks", "motif": "cake"},
	# ── Кохаку: снег f3efe9, киноварь d63a2a, янтарь e2a23d. Ядро: Лисий оберег. Лисий огонь.
	"ko_base": {"hero": "kohaku", "name": "Лисий оберег", "lines": ["Удача любит меня.", "Лисий оберег!", "Так и быть, присмотрю."],
		"palette": {"main": Color("f3efe9"), "accent": Color("d63a2a"), "ink": _KO_INK},
		"ref_img": "res://assets/v10/wave1/outfits/ko_base.webp", "mod": "", "sfx": "reveal_sr", "fx": "fox_ofuda",
		"desc": "Офуда вспыхивает на лотке", "particles": "embers", "motif": "foxfire"},
	"ko_matsuri": {"hero": "kohaku", "name": "Огни мацури", "lines": ["Огни мацури!", "Загадай желание~", "Удача любит меня."],
		"palette": {"main": Color("f3efe9"), "accent": Color("e2a23d"), "ink": _KO_INK},
		"ref_img": "res://assets/v10/wave1/outfits/ko_matsuri.webp", "mod": "В", "sfx": "sparkle", "fx": "matsuri_lanterns",
		"desc": "Фонарики уносят пару", "particles": "embers", "motif": "lanterns"},
	"ko_kyubi": {"hero": "kohaku", "name": "Девять огней", "lines": ["Девять огней!", "Узри мой облик.", "Удача любит меня."],
		"palette": {"main": Color("f3efe9"), "accent": Color("f2c14e"), "ink": _KO_INK},
		"ref_img": "res://assets/v10/wave1/outfits/ko_kyubi.webp", "mod": "Л", "sfx": "summon_boom", "fx": "nine_foxfires",
		"desc": "Огни сходятся на паре", "particles": "embers", "motif": "foxfire"},
	"ko_vow": {"hero": "kohaku", "name": "Солнечный дождь", "lines": ["Солнечный дождь~", "Лисья свадьба идёт.", "Удача любит нас."],
		"palette": {"main": Color("f3efe9"), "accent": Color("f6cf7a"), "ink": _KO_INK},
		"ref_img": "res://assets/v10/wave1/outfits/ko_vow.webp", "mod": "С", "sfx": "reveal_ssr", "fx": "sun_shower",
		"desc": "Капли уносят пару", "particles": "pearls", "motif": "rain"},
	# ── Ширин: песок d9b26f, бирюза 1f8f8a, золото c08a1e. Ядро: Танец монет. Монеты и песок.
	"sh_base": {"hero": "shirin", "name": "Танец монет", "lines": ["Танец монет!", "Звёзды не лгут.", "Слышишь звон?"],
		"palette": {"main": Color("d9b26f"), "accent": Color("1f8f8a"), "ink": _SH_INK},
		"ref_img": "res://assets/v10/wave1/outfits/sh_base.webp", "mod": "", "sfx": "gem", "fx": "coin_dance",
		"desc": "Монеты кружат и уносят пару", "particles": "sparks", "motif": "coins"},
	"sh_oasis": {"hero": "shirin", "name": "Мираж", "lines": ["Мираж…", "Пески переменчивы.", "Было — и нет."],
		"palette": {"main": Color("d9b26f"), "accent": Color("8fd8c8"), "ink": _SH_INK},
		"ref_img": "res://assets/v10/wave1/outfits/sh_oasis.webp", "mod": "П", "sfx": "whoosh", "fx": "mirage_haze",
		"desc": "Пара тает в мареве", "particles": "dust", "motif": "sand"},
	"sh_sun": {"hero": "shirin", "name": "Солнечный диск", "lines": ["Солнечный диск!", "Полдень в зените.", "Звёзды не лгут."],
		"palette": {"main": Color("d9b26f"), "accent": Color("f0b43c"), "ink": _SH_INK},
		"ref_img": "res://assets/v10/wave1/outfits/sh_sun.webp", "mod": "О", "sfx": "summon_boom", "fx": "sun_disc",
		"desc": "Диск раскрывает и сжигает пару", "particles": "embers", "motif": "sun"},
	"sh_night": {"hero": "shirin", "name": "Звёздный шатёр", "lines": ["Звёздный шатёр.", "Звёзды подскажут.", "Звёзды не лгут."],
		"palette": {"main": Color("d9b26f"), "accent": Color("8fa0ff"), "ink": _SH_INK},
		"ref_img": "res://assets/v10/wave1/outfits/sh_night.webp", "mod": "Ц", "sfx": "reveal_ssr", "fx": "star_tent",
		"desc": "Созвездие наводит на лучшую пару", "particles": "sparks", "motif": "stars"},
	# ── Злата: алый c3242b, золото e8b23a, лак 1b1513. Ядро: Огненный шлейф. Перья жар-птицы и пламя.
	"zl_base": {"hero": "zlata", "name": "Огненный шлейф", "lines": ["Огненный шлейф!", "Весна пришла!", "Гори ясно!"],
		"palette": {"main": Color("c3242b"), "accent": Color("e8b23a"), "ink": _ZL_INK},
		"ref_img": "res://assets/v10/wave1/outfits/zl_base.webp", "mod": "", "sfx": "summon_boom", "fx": "fire_trail",
		"desc": "Огонь бежит от фишки к фишке", "particles": "feathers", "motif": "flame"},
	"zl_fair": {"hero": "zlata", "name": "Блинное солнце", "lines": ["Блинное солнце!", "Широкая Масленица!", "Угощайся!"],
		"palette": {"main": Color("c3242b"), "accent": Color("f5d58a"), "ink": _ZL_INK},
		"ref_img": "res://assets/v10/wave1/outfits/zl_fair.webp", "mod": "В", "sfx": "win", "fx": "pancake_sun",
		"desc": "Солнце-блин уносит фишку", "particles": "sparks", "motif": "pancakes"},
	"zl_ember": {"hero": "zlata", "name": "Купальский костёр", "lines": ["Купальский костёр!", "Пламя, светлее!", "Пепел — только начало."],
		"palette": {"main": Color("c3242b"), "accent": Color("ff7a2a"), "ink": _ZL_INK},
		"ref_img": "res://assets/v10/wave1/outfits/zl_ember.webp", "mod": "П", "sfx": "reveal_ssr", "fx": "kupala_fire",
		"desc": "Огонь освещает пару", "particles": "embers", "motif": "flame"},
	"zl_vow": {"hero": "zlata", "name": "Перо на счастье", "lines": ["Перо на счастье.", "Весна пришла!", "Это перо — тебе."],
		"palette": {"main": Color("c3242b"), "accent": Color("f3e6c8"), "ink": _ZL_INK},
		"ref_img": "res://assets/v10/wave1/outfits/zl_vow.webp", "mod": "С", "sfx": "sparkle", "fx": "lucky_feather",
		"desc": "Перо находит пару старейшей фишке", "particles": "feathers", "motif": "feathers"},
}

# Тройки (docs/MODES.md §5.5, V10MjTriplesUlts.EFFECT schema: triples / prefer / return / empty_triples / reveal_all).
# The tray-7 rules have no ice, jokers or fever, so each core keeps its pair-equivalent: 1 triple, or Кохаку's tray
# relief (2 tiles back to the table; an empty tray takes a triple).
const TRIPLES_EFFECT: = {
	"tsubame": {"triples": 1, "prefer": "tray"},
	"miel": {"triples": 1, "prefer": "tray"},
	"kohaku": {"return": 2, "empty_triples": 1},
	"shirin": {"triples": 1, "prefer": "tray"},
	"zlata": {"triples": 1, "prefer": "tray"},
}
const TRIPLES_DESC: = {
	"tsubame": "снимает 1 тройку",
	"miel": "достраивает тройку к фишкам лотка",
	"kohaku": "возвращает 2 фишки из лотка на стол",
	"shirin": "снимает 1 тройку",
	"zlata": "снимает 1 тройку",
}

# «nothing to do» lines (V9UltCast.blocked: said on her card with a deny)
const BLOCKED: = {
	"tsubame": "Здесь нечего доставлять. Позови чуть позже.",
	"miel": "Лоток пуст, и снять нечего. Испеку чуть позже!",
	"miel_wait": "Печенье уже ждёт в лотке. Позови чуть позже.",
	"kohaku": "Оберег уже висит, а снять нечего. Позови позже.",
	"shirin": "Звёзды пока молчат. Позови меня чуть позже.",
	"zlata": "Огню сейчас нечего взять. Чуть позже!",
}

# red lines of HEROINES §4 on top of V10Lint.BANNED (the letters selftest list)
const RED_LINES: = ["учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр",
	"вино", "пиво", "алкогол", "раздев", "бельё", "белье"]
const AIM_TARGETS: = ["pair", "swipe", "row", "tier", "none"]
const TRIPLES_KEYS: = ["triples", "prefer", "return", "empty_triples", "reveal_all"]
const META_JOKER: = "w1_joker"
const META_JOKER_CB: = "w1_joker_cb"
const META_CHARM: = "w1_charm"
const META_CHARM_CB: = "w1_charm_cb"
const COOKIE: = Color("e9b45a")
const OFUDA_PAPER: = Color("f3efe9")
const OFUDA_RED: = Color("d63a2a")

static var _cards: = {}
static var _cards_read: = false
static var _built: = {}


# ── queries ────────────────────────────────────────────────────────────────

static func has(id: String) -> bool:
	return ULTS.has(id)


static func ids() -> Array:
	return ULTS.keys()


static func heroes() -> Array:
	return HEROES.duplicate()


static func is_hero(hero: String) -> bool:
	return BASE.has(hero)


static func is_base(id: String) -> bool:
	return id in BASE.values()


static func base(hero: String) -> String:
	return String(BASE.get(hero, ""))


static func rar(id: String) -> String:
	return String(RAR.get(id, "R"))


# the entry with its rects (art space 859×1280, read once from w1_art_cards.json); {} for an unknown id
static func get_ult(id: String) -> Dictionary:
	if not ULTS.has(id):
		return {}
	if not _built.has(id):
		var u: Dictionary = (ULTS[id] as Dictionary).duplicate()
		var r: = rects(id)
		u["face_rect"] = r[0]
		u["alt_rect"] = r[1]
		_built[id] = u
	return _built[id]


static func core(hero: String, ranked: = false) -> Dictionary:
	var c: Dictionary = (CORES.get(hero, CORES.tsubame) as Dictionary).duplicate()
	if ranked and RANKED_CORES.has(hero):
		c.merge(RANKED_CORES[hero], true)
	c["hero"] = hero
	return c


static func mod(id: String, ranked: = false) -> String:
	if ranked:
		return ""
	return String(ULTS.get(id, {}).get("mod", ""))


static func outfits_of(hero: String) -> Array:
	var out: = []
	for id in ULTS:
		if String(ULTS[id].hero) == hero:
			out.append(id)
	return out


# V9Ults.shown() for a wave-1 outfit: a retired (hidden) or, in modest mode, a bold outfit shows its `alt` art — a
# wave-1 alt is looked up in the wave-1 dir with its own rects (V9Ults.shown would build res://assets/outfits/<alt>)
static func shown(id: String, modest = null) -> Dictionary:
	var u: = get_ult(id)
	var img: String = String(u.get("ref_img", ART_DIR + id + ".webp"))
	var fr: Rect2 = u.get("face_rect", _default_face())
	var ar: Rect2 = u.get("alt_rect", _default_alt(_default_face()))
	var it: Dictionary = _item(id)
	if modest == null:
		var g: = _g()
		var st = g.get("S") if g != null else null
		modest = bool((st as Dictionary).get("modest", false)) if st is Dictionary else false
	var alt: = ""
	if it.has("alt") and (bool(it.get("hidden", false)) or (bool(modest) and bool(it.get("bold", false)))):
		alt = String(it.alt)
	if alt != "" and alt != id:
		if ULTS.has(alt):
			var a: = get_ult(alt)
			return {"img": String(a.ref_img), "face_rect": a.face_rect, "alt_rect": a.alt_rect}
		if ResourceLoader.exists(ART_DIR + alt + ".webp"):
			var r: = rects(alt)
			return {"img": ART_DIR + alt + ".webp", "face_rect": r[0], "alt_rect": r[1]}
		# a founder art as alt (not expected): the founders' dir; V9Ults.RECTS knows its rects
		var key: = alt
		var rr: Array = V9Ults.RECTS.get(key, [fr, ar])
		return {"img": ("res://assets/outfits/%s.webp" % alt).simplify_path(), "face_rect": rr[0], "alt_rect": rr[1]}
	return {"img": img, "face_rect": fr, "alt_rect": ar}


static func _item(id: String) -> Dictionary:
	var g: = _g()
	var items = g.get("ITEM") if g != null else null
	return (items as Dictionary).get(id, {}) if items is Dictionary else {}


# the G / Sfx autoloads through the tree (no bare autoload names: the file stays parse-clean in --check-only runs)
static func _g() -> Node:
	return _autoload("G")


static func _autoload(nm: String) -> Node:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(nm) if tree != null else null


static func _sfx(nm: String, pitch: = 1.0, db: = 0.0) -> void:
	var sfx: = _autoload("Sfx")
	if sfx != null:
		sfx.call("play", nm, pitch, db)


# ── art rects (data/w1_art_cards.json, cached) ─────────────────────────────

static func cards() -> Dictionary:
	if not _cards_read:
		_cards_read = true
		_cards = {}
		var f: FileAccess = FileAccess.open(CARDS_PATH, FileAccess.READ) if FileAccess.file_exists(CARDS_PATH) else null
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cards = d
	return _cards


# forget the cached JSON and entries (tests; a fresh art drop in a dev session)
static func reload() -> void:
	_cards_read = false
	_cards = {}
	_built.clear()


static func _card(id: String) -> Dictionary:
	var o = cards().get("outfits", {})
	if o is Dictionary and (o as Dictionary).get(id) is Dictionary:
		return o[id]
	return {}


static func rects_measured(id: String) -> bool:
	var c: = _card(id)
	return _rect_of(c.get("face_rect")).size.x > 0.0


# [face_rect, alt_rect, measured] in V9Ults.ART_SIZE space. The face square keeps its centre and takes one scale
# (the height ratio), so it stays square in art space (V9Ults.rect_px maps it back to the 850-wide texture within 1 %);
# its side is held in 180–480. A missing or broken alt_rect is derived from the face (founders' framing).
static func rects(id: String) -> Array:
	var c: = _card(id)
	var px: = ART_PX
	var sz = c.get("size")
	if sz is Array and (sz as Array).size() >= 2 and float(sz[0]) > 0.0 and float(sz[1]) > 0.0:
		px = Vector2(float(sz[0]), float(sz[1]))
	var k: = V9Ults.ART_SIZE / px
	var f_in: = _rect_of(c.get("face_rect"))
	var measured: = f_in.size.x > 0.0 and f_in.size.y > 0.0
	var face: = _default_face()
	if measured:
		var side: = clampf(roundf((f_in.size.x * k.x + f_in.size.y * k.y) * 0.5), FACE_MIN, FACE_MAX)
		var cen: = (f_in.position + f_in.size * 0.5) * k
		face = _inside(Rect2(roundf(cen.x - side * 0.5), roundf(cen.y - side * 0.5), side, side))
	var a_in: = _rect_of(c.get("alt_rect"))
	var alt: = Rect2()
	if a_in.size.x > 0.0 and a_in.size.y > 0.0:
		alt = _inside(Rect2((a_in.position * k).round(), (a_in.size * k).round()))
	if alt.size.x <= 0.0 or not alt.has_point(face.get_center()) or alt.size.y <= face.size.y:
		alt = _default_alt(face)
	return [face, alt, measured]


static func _rect_of(v) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and (v as Array).size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("x"):
			return Rect2(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("w", d.get("width", 0))), float(d.get("h", d.get("height", 0))))
	return Rect2()


# a head-and-shoulders square centred on the card, face at ~19 % height (the founders' median framing)
static func _default_face() -> Rect2:
	return Rect2(roundf((V9Ults.ART_SIZE.x - 260.0) * 0.5), 110.0, 260.0, 260.0)


# head to waist around a face square (founders: ≈1.54 × 1.92 of the face side, 0.2 side above it)
static func _default_alt(face: Rect2) -> Rect2:
	var s: = face.size.x
	var w: = roundf(s * 1.54)
	var h: = roundf(s * 1.92)
	var c: = face.get_center()
	return _inside(Rect2(roundf(c.x - w * 0.5), roundf(face.position.y - s * 0.2), w, h))


static func _inside(r: Rect2) -> Rect2:
	var art: = V9Ults.ART_SIZE
	var s: = Vector2(minf(r.size.x, art.x), minf(r.size.y, art.y))
	var p: = Vector2(clampf(r.position.x, 0.0, art.x - s.x), clampf(r.position.y, 0.0, art.y - s.y))
	return Rect2(p, s)


# ── balance ────────────────────────────────────────────────────────────────

# pair-equivalents a cast removes (HEROINES §2 levelling): pairs, Миэль's cookie (1 pair), Кохаку's charm
# (charm_burn tiles / 2). Extras (highlight, melt, fever charge) are the «one small extra» founders also carry.
static func pe_removal(hero: String, ranked: = false) -> float:
	var c: = core(hero, ranked)
	if int(c.get("joker", 0)) > 0:
		return float(c.get("joker", 0))
	if int(c.get("charm", 0)) > 0:
		return float(c.get("charm_burn", 2)) * 0.5
	return float(c.get("pairs", 0))


static func ranked_extras(hero: String) -> Array:
	var c: = core(hero, true)
	var out: = []
	for k in ["highlight_pair", "melt_line", "fever", "reveal_all"]:
		if bool(c.get(k, false)):
			out.append(k)
	for k in ["melt", "reveal", "fever_charge"]:
		if float(c.get(k, 0)) > 0.0:
			out.append(k)
	return out


# ── Тройки (V10MjTriplesUlts.core shape) ───────────────────────────────────

static func triples_core(hero: String) -> Dictionary:
	var h: = hero if TRIPLES_EFFECT.has(hero) else "tsubame"
	var e: Dictionary = (TRIPLES_EFFECT[h] as Dictionary).duplicate()
	e["name"] = String(core(h).get("name", "Приём"))
	e["desc"] = String(TRIPLES_DESC[h])
	e["hero"] = h
	return e


# ── the cast (V9UltCast hooks) ─────────────────────────────────────────────

static func joker_on(bd) -> bool:
	return bd != null and is_instance_valid(bd) and bd.has_meta(META_JOKER)


static func charm_on(bd) -> bool:
	return bd != null and is_instance_valid(bd) and bd.has_meta(META_CHARM)


static func uncovered(bd, t) -> bool:
	if bd.opened.has(t):
		return true
	for o in bd.cov.get(t, []):
		if bd.on_board(o):
			return false
	return true


# not covered from above, but held by a neighbour on each side (V9: TrayBoard._free_if)
static func pinned(bd, t) -> bool:
	return uncovered(bd, t) and not bd.is_free(t)


# Цубамэ aims only at pairs whose tiles are not covered from above, side-pinned ones first (the pair the player
# cannot take by hand); none such — every pair stays a target, so the cast is never wasted
static func cast_pairs(cast, ps: Array) -> Array:
	if String(cast.hero) != "tsubame" or not bool(cast.core.get("pinned", false)):
		return ps
	var bd = cast._board()
	if bd == null:
		return ps
	var open: = ps.filter( func(p): return uncovered(bd, p[0]) and uncovered(bd, p[1]))
	if open.is_empty():
		return ps
	var sc: = {}
	for p in open:
		sc[p] = int(pinned(bd, p[0])) + int(pinned(bd, p[1]))
	open.sort_custom( func(x, y): return int(sc[x]) > int(sc[y]) or (int(sc[x]) == int(sc[y]) and mini(x[0].step, x[1].step) < mini(y[0].step, y[1].step)))
	return open


static func cast_blocked(cast) -> String:
	var bd = cast._board()
	if bd == null:
		return "…"
	var h: = String(cast.hero)
	var c: Dictionary = cast.core
	var none: = (cast.pairs() as Array).is_empty()
	match h:
		"miel":
			if int(c.get("joker", 0)) > 0 and not bd.tray.is_empty() and not joker_on(bd):
				return ""
			if none:
				return String(BLOCKED.miel_wait if joker_on(bd) else BLOCKED.miel)
			return ""
		"kohaku":
			if int(c.get("charm", 0)) > 0 and not charm_on(bd):
				return ""
			return String(BLOCKED.kohaku) if none else ""
	return String(BLOCKED.get(h, "Сейчас мне нечего снять. Чуть позже!")) if none else ""


static func cast_auto_pick(cast) -> Dictionary:
	var c: Dictionary = cast.core
	var n: = int(c.get("pairs", 1))
	if String(cast.mod) == "Ц":
		return {"pairs": cast.best_pairs(n)}
	var ps: Array = (cast.pairs() as Array).duplicate()
	if String(cast.hero) == "zlata" and (bool(c.get("melt_line", false)) or int(c.get("melt", 0)) > 0):
		var bd = cast._board()
		var sc: = {}
		for p in ps:
			sc[p] = line_tiles(bd, p[0], p[1]).size()
		ps.sort_custom( func(x, y): return int(sc[x]) > int(sc[y]) or (int(sc[x]) == int(sc[y]) and mini(x[0].step, x[1].step) < mini(y[0].step, y[1].step)))
	return {"pairs": ps.slice(0, n)}


# pairs the cast removes at once (V9UltSelftest «from_ult pairs = core» for the five)
static func cast_expect(hero: String, ranked: = false, tray_empty: = true, charm_was_on: = false, joker_was_on: = false) -> int:
	match hero:
		"miel":
			return 1 if tray_empty or joker_was_on else 0
		"kohaku":
			return 1 if charm_was_on else 0
	return int(core(hero, ranked).get("pairs", 1))


# her core on the strong beat; V9UltCast runs the outfit modifier right after
static func cast_apply(cast, pick: Dictionary, col: Color) -> void:
	var bd = cast._board()
	if bd == null:
		return
	cast._clear_aim_fx(0.0)
	var c: Dictionary = cast.core
	var pal: Dictionary = cast.palette()
	match String(cast.hero):
		"tsubame":
			for pr in _pairs_of(cast, pick):
				_smoke_row(cast, pr, pal)
				cast._take(pr, col)
		"miel":
			if int(c.get("joker", 0)) > 0 and not bd.tray.is_empty() and not joker_on(bd):
				joker_place(cast, pal)
			else:
				for pr in _pairs_of(cast, pick):
					cast._take(pr, col)
		"kohaku":
			if int(c.get("charm", 0)) > 0 and not charm_on(bd):
				charm_hang(cast, pal)
			else:
				for pr in _pairs_of(cast, pick):
					cast._take(pr, col)
			if bool(c.get("highlight_pair", false)) and cast._alive():
				cast._hint_pair(3.0)
		"shirin":
			for pr in _pairs_of(cast, pick):
				_coins(cast, pr, pal)
				cast._take(pr, col)
			_fever(cast, c)
		"zlata":
			for pr in _pairs_of(cast, pick):
				var line: Array = []
				if _pair_ok(bd, pr):
					line = line_tiles(bd, pr[0], pr[1])
					_fire_trail(cast, pr, pal)
				cast._take(pr, col)
				if not cast._alive():
					return
				if bool(c.get("melt_line", false)):
					for t in line:
						_melt(cast, bd, t, col)
				elif int(c.get("melt", 0)) > 0:
					var left: = int(c.get("melt", 0))
					for t in line:
						if left > 0 and _melt(cast, bd, t, col):
							left -= 1
					while left > 0 and cast._melt_one(col):
						left -= 1
		_:
			for pr in _pairs_of(cast, pick):
				cast._take(pr, col)


static func _pairs_of(cast, pick: Dictionary) -> Array:
	var prs: Array = pick.get("pairs", [])
	if prs.is_empty():
		prs = (cast.pairs() as Array).slice(0, int(cast.core.get("pairs", 1)))
	return prs


static func _pair_ok(bd, pr: Array) -> bool:
	return pr.size() == 2 and is_instance_valid(pr[0]) and is_instance_valid(pr[1]) and bd.on_board(pr[0]) and bd.on_board(pr[1])


# ice and closed locks whose centre lies within half a tile of the segment between the pair's two tiles
static func line_tiles(bd, a, b) -> Array:
	if bd == null or not is_instance_valid(a) or not is_instance_valid(b) or not a.is_inside_tree() or not b.is_inside_tree():
		return []
	var pa: = V9UltCast.pos_of(a)
	var pb: = V9UltCast.pos_of(b)
	var reach: = Tile.TW * absf(float(bd.scale.x)) * 0.5
	var spec = bd.get("spec")
	var out: = []
	for t in bd.tiles:
		if t == a or t == b or not bd.on_board(t) or t.pending:
			continue
		if t.ice <= 0 and not _locked(spec, t):
			continue
		var p: = V9UltCast.pos_of(t)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pa, pb)) <= reach:
			out.append(t)
	return out


static func _locked(spec, t) -> bool:
	if not (spec is Dictionary) or not (spec as Dictionary).has(t):
		return false
	var s: Dictionary = spec[t]
	return String(s.get("kind", "")) == "lock" and not bool(s.get("open", true))


# melts one tile's ice and / or opens its lock (as V9UltCast._melt_one does), with her mark
static func _melt(cast, bd, t, col: Color) -> bool:
	if not is_instance_valid(t) or not t.alive:
		return false
	var done: = false
	if t.ice > 0:
		t.ice = 0
		t._update_ice()
		done = true
	var spec = bd.get("spec")
	if _locked(spec, t):
		var s: Dictionary = spec[t]
		s.open = true
		if bd.has_method("_release"):
			bd._release(t)
		done = true
	if done:
		bd.reveal_free()
		if t.is_inside_tree():
			cast._mark(cast._fx_layer(), V9UltCast.pos_of(t), col, 0.9)
	return done


static func _fever(cast, c: Dictionary) -> void:
	var play = cast.play
	if play == null or not is_instance_valid(play):
		return
	if bool(c.get("fever", false)):
		if play.has_method("_fever") and float(play.now()) >= float(play.fever_until) and play.get("fever_pending") != true:
			play._fever()
	elif float(c.get("fever_charge", 0.0)) > 0.0 and play.get("charge") != null:
		play.charge = minf(1.0, float(play.charge) + float(c.get("fever_charge", 0.0)))


# ── Миэль: the cookie ──────────────────────────────────────────────────────

static func joker_place(cast, pal: Dictionary) -> void:
	var bd = cast._board()
	var play = cast.play
	if bd == null or joker_on(bd) or bd.slot_pos.is_empty():
		return
	var node: = _cookie(play, float(bd.slot_size), pal)
	node.position = _slot_at(bd, bd.display.size())
	_pop_in(node)
	var state: = {"node": node, "seen": bd.tray.duplicate(), "play": play, "col": Color(pal.main)}
	var cb: = func(): _joker_check(bd, state)
	bd.set_meta(META_JOKER, state)
	bd.set_meta(META_JOKER_CB, cb)
	bd.tray_changed.connect(cb)
	_free_with(bd, node)
	_sfx("gem", 1.25, -6.0)


static func _joker_clear(bd) -> void:
	if not is_instance_valid(bd):
		return
	if bd.has_meta(META_JOKER_CB):
		var cb: Callable = bd.get_meta(META_JOKER_CB)
		if bd.tray_changed.is_connected(cb):
			bd.tray_changed.disconnect(cb)
		bd.remove_meta(META_JOKER_CB)
	if bd.has_meta(META_JOKER):
		bd.remove_meta(META_JOKER)


# runs inside TrayBoard.tap (tray_changed is emitted before the overflow check), so a tile the cookie takes never
# fills the tray: the fail check right after sees the tray without it
static func _joker_check(bd, state: Dictionary) -> void:
	if not is_instance_valid(bd) or not bd.has_meta(META_JOKER):
		return
	var seen: Array = state.seen
	var fresh = null
	for t in bd.tray:
		if not seen.has(t) and is_instance_valid(t) and not t.pending:
			fresh = t
	state.seen = bd.tray.duplicate()
	var node = state.node
	if fresh == null or _special(bd, fresh):
		_follow(node, _slot_at(bd, bd.display.size()))
		return
	var twin = _twin_on_board(bd, fresh)
	if twin == null:
		_follow(node, _slot_at(bd, bd.display.size()))
		return
	_joker_clear(bd)
	var at: Vector2 = node.position if is_instance_valid(node) else Vector2.ZERO
	_ult_pair(bd, state.get("play"), fresh, twin, Color(state.col))
	if is_instance_valid(node):
		_spend(node, at, Color(COOKIE))
	_sfx("gem", 1.15, -4.0)


# ── Кохаку: the charm ──────────────────────────────────────────────────────

static func charm_hang(cast, pal: Dictionary) -> void:
	var bd = cast._board()
	var play = cast.play
	if bd == null or charm_on(bd) or bd.slot_pos.is_empty():
		return
	var s: = float(bd.slot_size)
	var node: = _ofuda(play, s, pal)
	node.position = bd.slot_pos[0] + Vector2(- s * 0.42, - s * 0.46)
	_pop_in(node)
	var state: = {"node": node, "play": play, "col": Color(pal.main)}
	var cb: = func(): _charm_check(bd, state)
	bd.set_meta(META_CHARM, state)
	bd.set_meta(META_CHARM_CB, cb)
	bd.tray_changed.connect(cb)
	_free_with(bd, node)
	_sfx("reveal_sr", 1.3, -8.0)


static func _charm_clear(bd) -> void:
	if not is_instance_valid(bd):
		return
	if bd.has_meta(META_CHARM_CB):
		var cb: Callable = bd.get_meta(META_CHARM_CB)
		if bd.tray_changed.is_connected(cb):
			bd.tray_changed.disconnect(cb)
		bd.remove_meta(META_CHARM_CB)
	if bd.has_meta(META_CHARM):
		bd.remove_meta(META_CHARM)


# the tray just filled (the fail check of TrayBoard.tap runs right after this signal): the charm burns and takes the
# oldest tray tile that has a twin on the table, with that twin (1 pair). Nothing to pair: 2 tiles go back to the table.
static func _charm_check(bd, state: Dictionary) -> void:
	if not is_instance_valid(bd) or not bd.has_meta(META_CHARM) or bd.tray.size() < int(bd.slots):
		return
	var o = null
	var twin = null
	for plain_only in [true, false]:
		for t in bd.tray:
			if o != null or not is_instance_valid(t) or t.pending or (plain_only and _special(bd, t)):
				continue
			var tw = _twin_on_board(bd, t)
			if tw != null:
				o = t
				twin = tw
	_charm_clear(bd)
	var node = state.node
	var at: Vector2 = node.position if is_instance_valid(node) else Vector2.ZERO
	if o != null:
		_ult_pair(bd, state.get("play"), o, twin, Color(state.col))
	else:
		bd.return_tray(2)
	if is_instance_valid(node):
		_spend(node, at, OFUDA_RED)
	_sfx("reveal_sr", 1.15, -4.0)


# ── shared tray helpers ────────────────────────────────────────────────────

# tile `t` leaves the tray together with its `twin` on the table as an ult pair (from_ult: no charge, no combo)
static func _ult_pair(bd, play, t, twin, col: Color) -> void:
	bd.tray.erase(t)
	bd.history.erase(t)
	bd.display.erase(t)
	var p_ok: bool = play != null and is_instance_valid(play) and play.get("v9_from_ult") != null
	if p_ok:
		play.v9_from_ult = true
	var keep: Color = bd.vanish_tint
	bd.vanish_tint = V9Cutin.flash_color(col)
	bd._vanish_pair(t, twin)
	bd.vanish_tint = keep
	if p_ok:
		play.v9_from_ult = false
	bd._layout_tray()
	bd.tray_changed.emit()
	bd._check_clear()


# special-board tiles (locks, chains, bombs, jokers) keep their own pair logic: the cookie waits for a plain tile
static func _special(bd, t) -> bool:
	if int(t.face) >= 300 or String(t.shard) != "" or bool(t.gift):
		return true
	var spec = bd.get("spec")
	return spec is Dictionary and (spec as Dictionary).has(t)


static func _twin_on_board(bd, t):
	var best = null
	for o in bd.tiles:
		if o == t or not bd.on_board(o) or o.pending or o.face != t.face:
			continue
		if o.step == t.step:
			return o
		if best == null or (o.ice <= 0 and best.ice > 0):
			best = o
	return best


# the token leaves with its board (a new deal, the screen closing); the lambda holds the id, never the node
static func _free_with(bd, node: Node) -> void:
	var nid: = node.get_instance_id()
	bd.tree_exiting.connect( func():
		var o = instance_from_id(nid)
		if o is Node and is_instance_valid(o):
			(o as Node).queue_free(), Object.CONNECT_ONE_SHOT)


static func _slot_at(bd, i: int) -> Vector2:
	var n: int = bd.slot_pos.size()
	if n == 0:
		return Vector2.ZERO
	return bd.slot_pos[clampi(i, 0, mini(n, int(bd.slots)) - 1)]


# ── board marks (soft, palette-coloured, never a flash) ────────────────────

static func _smoke_row(cast, pr: Array, pal: Dictionary) -> void:
	var bd = cast._board()
	if not V9Feel.can_fx() or bd == null or not _pair_ok(bd, pr):
		return
	var br: Rect2 = cast.play.board_rect
	var lay: Node2D = cast._fx_layer()
	var ink: Color = pal.ink
	var main: Color = pal.main
	var rows: = {}
	for t in pr:
		rows[snappedf(V9UltCast.pos_of(t).y, 4.0)] = true
	for y in rows:
		if V9Cutin.covers(Vector2(br.get_center().x, float(y))):
			continue
		var ln: = Line2D.new()
		ln.points = PackedVector2Array([Vector2(br.position.x - 16.0, float(y)), Vector2(br.end.x + 16.0, float(y))])
		ln.width = Tile.TH * absf(float(bd.scale.y)) * 0.5
		var g: = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
		g.colors = PackedColorArray([Color(ink, 0.0), Color(ink, 0.5), Color(main.darkened(0.35), 0.4), Color(ink, 0.0)])
		ln.gradient = g
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		lay.add_child(ln)
		var tw: = ln.create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(ln.queue_free)


static func _coins(cast, pr: Array, pal: Dictionary) -> void:
	var bd = cast._board()
	if not V9Feel.can_fx() or bd == null or not _pair_ok(bd, pr):
		return
	var mid: = (V9UltCast.pos_of(pr[0]) + V9UltCast.pos_of(pr[1])) * 0.5
	if V9Cutin.covers(mid):
		return
	var lay: Node2D = cast._fx_layer()
	var gold: = V9Cutin.flash_color(Color("c08a1e"))
	Fx.ring(lay, mid, Color(gold, 0.7), 1.1, 0.4)
	var n: = int(12 * V9Feel.fx_scale())
	if n > 0:
		Fx.burst(lay, mid, "sparkle", n, Color(pal.accent).lightened(0.25), 0.8)


static func _fire_trail(cast, pr: Array, pal: Dictionary) -> void:
	var bd = cast._board()
	if not V9Feel.can_fx() or bd == null or not _pair_ok(bd, pr):
		return
	var pa: = V9UltCast.pos_of(pr[0])
	var pb: = V9UltCast.pos_of(pr[1])
	if V9Cutin.covers((pa + pb) * 0.5):
		return
	var lay: Node2D = cast._fx_layer()
	var ln: = Line2D.new()
	ln.points = PackedVector2Array([pa, pb])
	ln.width = 12.0
	var g: = Gradient.new()
	g.colors = PackedColorArray([Color(V9Cutin.flash_color(pal.main), 0.75), Color(V9Cutin.flash_color(pal.accent), 0.75)])
	ln.gradient = g
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	lay.add_child(ln)
	var tw: = ln.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(ln, "modulate:a", 0.0, 0.32)
	tw.tween_callback(ln.queue_free)


# ── tokens: the cookie and the ofuda (state markers on the tray) ───────────

static func _circle(r: float, n: = 28, c: = Vector2.ZERO) -> PackedVector2Array:
	var out: = PackedVector2Array()
	for i in n:
		var a: = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _cookie(play, slot: float, pal: Dictionary) -> Node2D:
	var n: = Node2D.new()
	n.name = "W1Cookie"
	n.z_index = 225
	var r: = maxf(14.0, slot * 0.28)
	var ink: Color = pal.ink
	var glow_tex = _g().fx("glow") if _g() != null else null
	if V9Feel.can_fx() and glow_tex is Texture2D:
		var gl: = Sprite2D.new()
		gl.texture = glow_tex
		gl.modulate = Color(V9Cutin.flash_color(COOKIE), 0.32)
		var gs: Vector2 = gl.texture.get_size()
		gl.scale = Vector2(r * 3.2 / gs.x, r * 3.2 / gs.y)
		n.add_child(gl)
	var shade: = Polygon2D.new()
	shade.polygon = _circle(r, 32, Vector2(0, 3))
	shade.color = Color(ink, 0.45)
	shade.antialiased = true
	n.add_child(shade)
	var body: = Polygon2D.new()
	body.polygon = _circle(r, 32)
	body.color = COOKIE
	body.antialiased = true
	n.add_child(body)
	var rim: = Line2D.new()
	var pts: = _circle(r - 1.5, 32)
	pts.append(pts[0])
	rim.points = pts
	rim.width = 2.5
	rim.default_color = COOKIE.darkened(0.3)
	rim.antialiased = true
	n.add_child(rim)
	for p in [Vector2(-0.38, -0.3), Vector2(0.32, -0.36), Vector2(0.05, 0.08), Vector2(-0.3, 0.38), Vector2(0.4, 0.3)]:
		var chip: = Polygon2D.new()
		chip.polygon = _circle(r * 0.11, 10, p * r)
		chip.color = ink.lightened(0.08)
		chip.antialiased = true
		n.add_child(chip)
	play.add_child(n)
	if V9Feel.can_fx():
		var tw: = body.create_tween().set_loops()
		tw.tween_property(n, "rotation", 0.08, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(n, "rotation", -0.08, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return n


static func _ofuda(play, slot: float, pal: Dictionary) -> Node2D:
	var n: = Node2D.new()
	n.name = "W1Ofuda"
	n.z_index = 225
	var w: = maxf(16.0, slot * 0.22)
	var h: = w * 2.3
	var ink: Color = pal.ink
	var cord: = Line2D.new()
	cord.points = PackedVector2Array([Vector2(0, - h * 0.5 - 9.0), Vector2(0, - h * 0.5)])
	cord.width = 2.0
	cord.default_color = OFUDA_RED.darkened(0.2)
	n.add_child(cord)
	var shade: = Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(- w * 0.5 + 2, - h * 0.5 + 3), Vector2(w * 0.5 + 2, - h * 0.5 + 3), Vector2(w * 0.5 + 2, h * 0.5 + 3), Vector2(- w * 0.5 + 2, h * 0.5 + 3)])
	shade.color = Color(ink, 0.4)
	n.add_child(shade)
	var paper: = Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2(- w * 0.5, - h * 0.5), Vector2(w * 0.5, - h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(- w * 0.5, h * 0.5)])
	paper.color = OFUDA_PAPER.darkened(0.04)
	paper.antialiased = true
	n.add_child(paper)
	var frame: = Line2D.new()
	var inset: = 2.5
	frame.points = PackedVector2Array([Vector2(- w * 0.5 + inset, - h * 0.5 + inset), Vector2(w * 0.5 - inset, - h * 0.5 + inset),
		Vector2(w * 0.5 - inset, h * 0.5 - inset), Vector2(- w * 0.5 + inset, h * 0.5 - inset), Vector2(- w * 0.5 + inset, - h * 0.5 + inset)])
	frame.width = 1.6
	frame.default_color = OFUDA_RED
	n.add_child(frame)
	var seal: = Polygon2D.new()
	seal.polygon = _circle(w * 0.26, 18, Vector2(0, - h * 0.12))
	seal.color = OFUDA_RED
	seal.antialiased = true
	n.add_child(seal)
	for y in [h * 0.12, h * 0.24]:
		var st: = Line2D.new()
		st.points = PackedVector2Array([Vector2(- w * 0.22, y), Vector2(w * 0.22, y)])
		st.width = 1.6
		st.default_color = ink
		n.add_child(st)
	n.rotation = -0.1
	play.add_child(n)
	if V9Feel.can_fx():
		var tw: = paper.create_tween().set_loops()
		tw.tween_property(n, "rotation", 0.02, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(n, "rotation", -0.12, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return n


static func _pop_in(n: Node2D) -> void:
	n.scale = Vector2(0.4, 0.4)
	n.modulate.a = 0.0
	var tw: = n.create_tween().set_parallel()
	tw.tween_property(n, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 1.0, 0.14)


static func _follow(n, to: Vector2) -> void:
	if n == null or not is_instance_valid(n) or (n as Node2D).position.is_equal_approx(to):
		return
	(n as Node2D).create_tween().tween_property(n, "position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _spend(n, at: Vector2, col: Color) -> void:
	if n == null or not is_instance_valid(n):
		return
	if V9Feel.can_fx() and n.get_parent() != null:
		var k: = int(10 * V9Feel.fx_scale())
		if k > 0:
			Fx.burst(n.get_parent(), at, "sparkle", k, V9Cutin.flash_color(col).lightened(0.2), 0.7)
	var tw: = (n as Node2D).create_tween().set_parallel()
	tw.tween_property(n, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(n.queue_free)


# ── checks (the wave-1 selftest calls problems(); V9UltsSelftest._table mirrored + wave-1 rules) ──

static func _cyr(s: String) -> bool:
	for ch in s:
		var c: = ch.unicode_at(0)
		if c >= 0x0410 and c <= 0x044f:
			return true
	return false


static func _latin(s: String) -> bool:
	for ch in s.to_lower():
		if ch >= "a" and ch <= "z":
			return true
	return false


# banned fragments in a heroine string: V10Lint.BANNED (+ «бесплатн» next to a price) and the HEROINES §4 red lines
static func banned(text: String) -> Array:
	var bad: Array = V10Lint.check(text)
	for u in V10Lint.ui_check(text):
		if not (u in bad):
			bad.append(u)
	var low: = text.to_lower()
	for w in RED_LINES:
		if low.find(w) >= 0:
			bad.append(w)
	return bad


# G.HEROES as the game sees it (the integrator may merge wave 1 through a function or V10Wave1.heroes() rather than the const)
static func _heroes_table() -> Dictionary:
	var g: = _g()
	if g != null and g.has_method("heroes"):
		var hs = g.call("heroes")
		if hs is Dictionary:
			return hs
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "V10Wave1":
			var w1 = load(String(c.path))
			if w1 != null and bool(w1.call("is_installed")):
				var wh = w1.call("heroes")
				if wh is Dictionary and not wh.is_empty():
					return wh
			break
	if g != null:
		var h0 = g.get("HEROES")
		if h0 is Dictionary:
			return h0
	return {}


static func texts() -> Array:
	var out: = []
	for id in ULTS:
		var u: Dictionary = ULTS[id]
		out.append(String(u.name))
		out.append(String(u.desc))
		out.append_array(u.lines)
	for h in CORES:
		for c in [CORES[h], RANKED_CORES.get(h, {})]:
			for k in ["name", "desc", "rule"]:
				if (c as Dictionary).has(k):
					out.append(String(c[k]))
	out.append_array(TRIPLES_DESC.values())
	out.append_array(BLOCKED.values())
	return out


# every problem as a line (empty = pass). strict: art files on disk, every card measured in w1_art_cards.json, and
# — once the integrator merged wave 1 into G — G.HEROES colours and G.ITEM rarities / img keys.
static func problems(strict: = false) -> Array:
	var bad: = []
	var want: = RAR.keys()
	if ULTS.size() != 18 or want.size() != 18:
		bad.append("18 outfits: ULTS %d RAR %d" % [ULTS.size(), want.size()])
	for id in want:
		if not ULTS.has(id):
			bad.append("%s missing in ULTS" % id)
	for h in HEROES:
		if not CORES.has(h):
			bad.append("core missing for %s" % h)
		if not ULTS.has(base(h)) or String(ULTS.get(base(h), {}).get("hero", "")) != h:
			bad.append("base ult for %s" % h)
	var fx_seen: = {}
	var art: = Rect2(Vector2.ZERO, V9Ults.ART_SIZE)
	var mods_by_hero: = {}
	for id in ULTS:
		var u: Dictionary = ULTS[id]
		var h: = String(u.get("hero", ""))
		if not h in HEROES:
			bad.append("%s hero %s" % [id, h])
			continue
		if not RAR.has(id):
			bad.append("%s has no rarity" % id)
		var nm: = String(u.get("name", ""))
		if not _cyr(nm) or nm.length() > 24:
			bad.append("%s name «%s»" % [id, nm])
		var lines: Array = u.get("lines", [])
		if lines.size() < 2 or lines.size() > 3:
			bad.append("%s %d lines" % [id, lines.size()])
		for ln in lines:
			if not _cyr(String(ln)) or String(ln).length() > 28 or _latin(String(ln)):
				bad.append("%s line «%s»" % [id, ln])
		if not _cyr(String(u.get("desc", ""))):
			bad.append("%s desc" % id)
		var pal: Dictionary = u.get("palette", {})
		if not (pal.get("main") is Color) or not (pal.main as Color).is_equal_approx(HERO_COLOR[h]):
			bad.append("%s palette main is not the heroine colour" % id)
		if not (pal.get("accent") is Color) or not (pal.get("ink") is Color) or (pal.ink as Color).get_luminance() >= 0.3:
			bad.append("%s palette accent / ink" % id)
		else:
			for k in ["main", "accent"]:
				var fc: = V9Cutin.flash_color(pal[k])
				if fc.v > V9Ults.FLASH_MAX + 0.001 or fc.s < 0.449:
					bad.append("%s %s flashes white or too bright" % [id, k])
		var img: = String(u.get("ref_img", ""))
		if img != ART_DIR + id + ".webp":
			bad.append("%s ref_img %s" % [id, img])
		if strict and not ResourceLoader.exists(img):
			bad.append("%s ref_img missing on disk" % id)
		var e: = get_ult(id)
		var fr: Rect2 = e.get("face_rect", Rect2())
		var ar: Rect2 = e.get("alt_rect", Rect2())
		if not (art.encloses(fr) and fr.size.x >= FACE_MIN and fr.size.x <= FACE_MAX and is_equal_approx(fr.size.x, fr.size.y)):
			bad.append("%s face_rect %s" % [id, fr])
		if not (art.encloses(ar) and ar.has_point(fr.get_center()) and ar.size.y > fr.size.y):
			bad.append("%s alt_rect %s" % [id, ar])
		if fr.get_center().y >= 640.0:
			bad.append("%s face not in the upper half" % id)
		if strict and not rects_measured(id):
			bad.append("%s rects not measured in w1_art_cards.json" % id)
		var m: = String(u.get("mod", "?"))
		var seen: Array = mods_by_hero.get(h, [])
		if is_base(id):
			if m != "":
				bad.append("%s base outfit has mod %s" % [id, m])
		else:
			if not V9Ults.MODS.has(m):
				bad.append("%s mod «%s»" % [id, m])
			for s in seen:
				if s == m:
					bad.append("%s mod %s repeats within %s" % [id, m, h])
		seen.append(m)
		mods_by_hero[h] = seen
		if is_base(id) and RAR.get(id, "") != {"tsubame": "R", "miel": "R", "kohaku": "SR", "shirin": "SR", "zlata": "SSR"}[h]:
			bad.append("%s base rarity is not the heroine rank" % id)
		var sfx: = String(u.get("sfx", ""))
		if not ResourceLoader.exists("res://assets/sfx/%s.wav" % sfx):
			bad.append("%s sfx %s" % [id, sfx])
		var fx: = String(u.get("fx", ""))
		if fx == "" or fx_seen.has(fx):
			bad.append("%s fx key «%s»" % [id, fx])
		fx_seen[fx] = true
		if not String(u.get("particles", "")) in V10KitData.PARTICLES:
			bad.append("%s particles %s" % [id, u.get("particles", "")])
		if String(u.get("motif", "")) == "":
			bad.append("%s motif" % id)
		if strict:
			var it: = _item(id)
			if it.is_empty():
				bad.append("%s not in G.ITEM" % id)
			else:
				if String(it.get("cat", "")) != "outfit" or String(it.get("hero", "")) != h:
					bad.append("%s G.ITEM cat / hero" % id)
				if String(it.get("rar", "")) != rar(id):
					bad.append("%s G.ITEM rar %s != %s" % [id, it.get("rar", ""), rar(id)])
				if String(it.get("img", "")) != id:
					bad.append("%s G.ITEM img %s" % [id, it.get("img", "")])
				if id in VOWS and not bool(it.get("nogacha", false)):
					bad.append("%s vow outfit is in the gacha pool" % id)
	for h in HEROES:
		if (mods_by_hero.get(h, []) as Array).size() != outfits_of(h).size():
			bad.append("%s outfits / mods count" % h)
		var c: = core(h)
		var rc: = core(h, true)
		if not _cyr(String(c.get("name", ""))) or not _cyr(String(c.get("desc", ""))) or not _cyr(String(c.get("rule", ""))):
			bad.append("%s core texts" % h)
		if String(c.get("desc", "")).length() > 45 or String(rc.get("desc", "")).length() > 45:
			bad.append("%s core desc longer than 45" % h)
		if not String(c.get("target", "")) in AIM_TARGETS:
			bad.append("%s core target %s" % [h, c.get("target", "")])
		if int(c.get("pairs", 0)) != 1 or int(rc.get("pairs", 0)) != 1:
			bad.append("%s core fallback pairs" % h)
		if not is_equal_approx(pe_removal(h, true), 1.0):
			bad.append("%s ranked core %.2f pair-equivalents" % [h, pe_removal(h, true)])
		if ranked_extras(h).size() > 1 or bool(rc.get("reveal_all", false)) or bool(rc.get("fever", false)):
			bad.append("%s ranked core extras %s" % [h, ranked_extras(h)])
		if not is_equal_approx(pe_removal(h), 1.0):
			bad.append("%s core %.2f pair-equivalents off ranked" % [h, pe_removal(h)])
		if not TRIPLES_EFFECT.has(h) or not _cyr(String(TRIPLES_DESC.get(h, ""))):
			bad.append("%s triples" % h)
		else:
			for k in TRIPLES_EFFECT[h]:
				if not k in TRIPLES_KEYS:
					bad.append("%s triples key %s" % [h, k])
		if strict:
			var hs: Dictionary = _heroes_table()
			if not hs.has(h):
				bad.append("%s not in G.HEROES" % h)
			elif not (hs[h].get("color", Color.BLACK) as Color).is_equal_approx(HERO_COLOR[h]):
				bad.append("%s G.HEROES colour != palette main" % h)
	for s in texts():
		var b: = banned(String(s))
		if not b.is_empty():
			bad.append("banned %s in «%s»" % [b, s])
		if _latin(String(s)):
			bad.append("latin letters in «%s»" % s)
	return bad
