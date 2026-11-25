class_name V10ShopData
extends RefCounted

# V10ShopData — the few shop-UI numbers that V10Catalog (branch v10-economy) does not hold yet. Every one of them is
# listed in README «Хуки» as a move into V10Catalog/economy.json at integration; UI code reads them only from here.
# Rubles, moonstone amounts, wishes, the 3× rule and spend caps are NOT here: they come from V10Catalog.

# ---- starter ladder by progress (spec 0.10 Л3): order, art, level gates (Path level, no calendar dates)
# from/to: visible while from <= level < to (to = 0 means no upper gate)
const LADDER: = [
	{"sku": "first_79", "name": "Первая чашка", "art": "set_cup", "from": 0, "to": 60},
	{"sku": "guest_149", "name": "Набор первого гостя", "art": "set_guest", "from": 0, "to": 60},
	{"sku": "newbie_499", "name": "Набор новичка", "art": "set_novice", "from": 0, "to": 60},
	{"sku": "traveler_199", "name": "Набор путника", "art": "set_traveler", "from": 30, "to": 0},
	{"sku": "growth_1490", "name": "Рост", "art": "set_growth", "from": 60, "to": 120},
]
# «Набор путника» (spec Л3) is not in V10Catalog yet: added through V10Shop.extra_skus (the integrator hook that
# already exists) with the same fields as catalog starters. Boosters are items ids of the 0.10 boosters lane.
const EXTRA_SKUS: = [
	{"id": "traveler_199", "kind": "starter", "name": "Набор путника", "rub": 199,
		"grant": {"moon": 150, "items": ["boost_lantern", "boost_lantern", "boost_wind", "boost_wind", "boost_scroll", "boost_scroll"]},
		"once": true, "requires_server": true, "boost_value": 60},
]

# ---- Лавка · Витрина «Подарок дня» (Л6) and rewarded ads (Л8)
const GIFT_DAILY: = {"crystal": 50}
const GIFT_AD_MULT: = 2
const ADS_DAY_MAX: = 6
const AD_SLOTS: = {"gift": 1, "chest": 3, "event": 2}   # per day, inside ADS_DAY_MAX
const AD_STUB_SEC: = 2.0

# ---- Лавка · Наряды: price in Лепестки (Л6). Crystal prices stay in G.ITEMS[].shop (0.8 data) until V10Catalog.
const PETAL_PRICE: = {"A": 80, "S": 160, "SSR": 0}       # SSR is never sold for petals
const RAR_MAP: = {"R": "A", "SR": "S", "SSR": "SSR", "A": "A", "S": "S"}
const CRYSTAL_CONFIRM_FROM: = 1000                      # UX §5.2.6

# ---- moonstone pack art by catalog order (6 packs)
const PACK_ART: = ["moon_1", "moon_2", "moon_3", "moon_4", "moon_5", "moon_6"]

# ---- age and spend (Л2). Caps for 18+ unverified and own limits come from V10Spend/V10Catalog.
const MIN_AGE_STORE: = 18          # RuStore build is 18+ (HANDOFF §1)
const MIN_AGE_GP: = 16             # a 16+ flavour keeps the 16–17 band with the caps below
const TEEN_MONTH_RUB: = 1500
const TEEN_ONE_RUB: = 499
const BIG_BUY_ASK_RUB: = 1490      # «Сделать паузу покупок на 24 часа?» once after a purchase this big
const OWN_LIMITS: = [0, 1000, 3000, 5000, 10000]
const PAUSE_DAYS: = [1, 7, 30]

# ---- offer popup cadence (Л3, UX §5.2.4)
const POPUP_QUIET_SEC: = 600
const POPUP_FROM_LEVEL: = 8

# ---- shop opens after L8 (UX §3.5); before that no Label with «₽» (С-2)
const SHOP_FROM_LEVEL: = 8

# ---- «Словарь» articles of the shop terms (UX §4.4, checklist П-4). V10Glossary (branch v10-clarity) has no shop
# section yet: the integrator adds ["shop", "Лавка"] to V10Glossary.CATS and appends these to V10Glossary.BASE (hook 15).
# Same fields and limits as V10Glossary (name ≤ 26, why ≤ 74, how ≤ 92); no numbers that the catalog may change.
const GLOSSARY: = [
	{"id": "shop.moon", "cat": "shop", "name": "Лунный камень", "icon": "art:moon_1",
		"why": "Те же кристаллы, только купленные за рубли. Тратится после бесплатных",
		"how": "Лавка → Пополнить. Перед каждой тратой камня мы спросим"},
	{"id": "shop.month", "cat": "shop", "name": "Лунный абонемент", "icon": "art:item_month",
		"why": "30 дней: камень сразу и кристаллы каждый день в утреннем подносе",
		"how": "Лавка → Витрина. Не подписка, сам не продлевается"},
	{"id": "shop.pass", "cat": "shop", "name": "Пропуск сезона", "icon": "art:item_pass",
		"why": "Награды за уровни сезона: бесплатная дорожка и премиум",
		"how": "Опыт сезона — за победы и задания дня. Премиум — Лавка → Витрина"},
	{"id": "shop.gift", "cat": "shop", "name": "Подарок дня", "icon": "art:item_gift",
		"why": "Бесплатные кристаллы в Лавке раз в день",
		"how": "Лавка → Витрина → Забрать. Завтра — новый"},
	{"id": "shop.petal", "cat": "shop", "name": "Лепестки", "icon": "art:item_petal",
		"why": "Приходят за повторный наряд из Желаний",
		"how": "Тратятся в Лавке → Наряды → за лепестки"},
]
