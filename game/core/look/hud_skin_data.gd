class_name V10HudSkinData
extends RefCounted

# V10HudSkinData — HUD skins of SSR goddesses (docs/0.10-spec.md D7, UX_RULES §6, HUD_V2 §2.4).
# A skin = tokens (the «Тишина и лак» palette names of V10DS, lowercase), 11 nine roles, press / open effects,
# menu background, loading screen, sting, SFX, palettes (SSR-outfit presets: token overrides + texture tint).
#
# `five_winds` is the base HUD (МТ's «Пять ветров» = HUD v2 «Тишина и лак»): vector roles only and the skin
# framework never touches a node while it is active (selftest: snapshot of a tree before/after is identical).
# `zlata` («Лаковая сказка»): black lacquer and gold folk ornament (Higgsfield art, assets/v10/look/zlata),
# hidden until her banner (1.0); test builds open it with `--skin=zlata`.

const NINE_ROLES: = ["header", "plate_s", "plate_m", "plate_l", "window", "btn_play", "btn_cash", "btn_secondary",
	"btn_quiet", "tab", "currency"]
# the 4 button classes of UX_RULES §6.5 every skin must define
const BUTTON_CLASSES: = {"play": "btn_play", "cash": "btn_cash", "secondary": "btn_secondary", "quiet": "btn_quiet"}
# role -> [text token, fill token] for the ≥ 4,5:1 contrast check (fill = average of the texture centre when textured)
const TEXT_ON: = {"header": "paper_100", "plate_s": "paper_100", "plate_m": "paper_100", "plate_l": "paper_100",
	"window": "paper_100", "btn_play": "text_on_primary", "btn_cash": "paper_100", "btn_secondary": "paper_100",
	"btn_quiet": "paper_100", "tab": "paper_100", "currency": "gold_300"}
const ROLE_H: = {"plate_s": 48, "plate_m": 80, "plate_l": 160, "btn_play": 104, "btn_cash": 80, "btn_secondary": 80,
	"btn_quiet": 80, "tab": 96, "currency": 56, "header": 120}

const BASE_TOKENS: = {
	"night_900": Color("#121014"), "night_800": Color("#1B171C"), "night_700": Color("#26212A"), "night_600": Color("#332C36"),
	"paper_100": Color("#F5EAD8"), "paper_300": Color("#DDD2C4"), "paper_500": Color("#B3A89C"), "paper_700": Color("#7E756D"),
	"gold_300": Color("#F1D9A0"), "gold_500": Color("#E8C47E"), "gold_700": Color("#A87B3A"),
	"rose_300": Color("#ECC0C9"), "rose_500": Color("#D796A5"), "rose_700": Color("#9A4F66"),
	"jade_300": Color("#A9D9C4"), "jade_500": Color("#5B9580"), "ember": Color("#E07A7A"), "cinnabar": Color("#C8463C"),
	"text_on_primary": Color("#121014"),
}

const ZL: = "res://assets/v10/look/zlata/"

const SKINS: = {
	"five_winds": {
		"name": "Пять ветров", "hero": "mc", "hidden": false,
		"tokens": {},
		# vector roles (HUD_V2 §2.2): fill token, hairline on top, radius
		"nine": {
			"header": {"fill": "night_900", "alpha": 0.0, "hair": false},
			"plate_s": {"fill": "night_800", "hair": true}, "plate_m": {"fill": "night_800", "hair": true},
			"plate_l": {"fill": "night_800", "hair": true}, "window": {"fill": "night_700", "hair": false},
			"btn_play": {"fill": "rose_500", "pill": true}, "btn_cash": {"fill": "night_700", "border": "gold_500"},
			"btn_secondary": {"fill": "night_800", "hair": true}, "btn_quiet": {"fill": "night_800", "alpha": 0.9, "circle": true},
			"tab": {"fill": "night_900", "alpha": 0.0, "text_bg": "night_900"}, "currency": {"fill": "night_800", "hair": true},
		},
		"press_fx": "spring", "open_fx": "silk", "menu_bg": "", "loading": "",
		"sting": "", "sfx": {"press": "pop", "open": "swoosh", "tab": "pop", "confirm": "sparkle", "deny": "deny"},
		"palettes": {},
	},
	"zlata": {
		"name": "Лаковая сказка", "hero": "zlata", "hidden": true,
		# black lacquer, cream paper, firebird gold; «Игра» is scarlet lacquer with cream text
		"tokens": {
			"night_900": Color("#0B0706"), "night_800": Color("#1B1513"), "night_700": Color("#231A16"), "night_600": Color("#3A2A21"),
			"paper_100": Color("#F8EAD2"), "paper_300": Color("#E8D5B2"), "paper_500": Color("#C4AC86"), "paper_700": Color("#85705A"),
			"gold_300": Color("#FFD98A"), "gold_500": Color("#E8B23A"), "gold_700": Color("#A8741C"),
			"rose_500": Color("#C3242B"), "rose_700": Color("#8E1A14"), "rose_300": Color("#FF9A6A"),
			"jade_300": Color("#FFC36A"), "text_on_primary": Color("#F8EAD2"),
		},
		"nine": {
			"header": {"tex": ZL + "header.webp", "mode": "strip_bottom", "fill": "night_900", "h": 144},
			"plate_s": {"tex": ZL + "plate_s.png", "m": [27, 47, 27, 47]},
			"plate_m": {"tex": ZL + "plate_m.png", "m": [45, 79, 45, 79]},
			"plate_l": {"tex": ZL + "plate_l.png", "m": [90, 159, 90, 159]},
			"window": {"tex": ZL + "window.png", "m": [104, 104, 104, 104]},
			"btn_play": {"tex": ZL + "btn_play.png", "m": [104, 103, 104, 103]},
			"btn_cash": {"tex": ZL + "btn_cash.png", "m": [48, 79, 48, 79]},
			"btn_secondary": {"tex": ZL + "plate_m.png", "m": [45, 79, 45, 79]},
			"btn_quiet": {"tex": ZL + "medallion.png", "mode": "fit"},
			"tab": {"tex": ZL + "feather.png", "mode": "fit", "text_bg": "night_900"},
			"currency": {"tex": ZL + "currency.png", "m": [94, 63, 94, 63]},
		},
		"corner": ZL + "corner.png",
		"press_fx": "glint", "open_fx": "pen", "menu_bg": ZL + "menu_bg.webp", "loading": ZL + "loading.webp",
		"sting": "zlata", "sfx": {"press": "pop", "open": "swoosh", "tab": "pop", "confirm": "sparkle", "deny": "deny"},
		# SSR-outfit presets (ROSTER §1.3): token overrides + texture tint, no new art
		"palettes": {
			"firebird": {"name": "Жар-птица", "tint": Color(1, 1, 1), "tokens": {}},
			"ember": {"name": "Царица-пламя", "tint": Color(1.0, 0.9, 0.82),
				"tokens": {"gold_500": Color("#F09A3A"), "gold_300": Color("#FFC98A"), "rose_500": Color("#B0201A")}},
			"dawn": {"name": "Обет · рассвет", "tint": Color(1.0, 0.95, 0.97),
				"tokens": {"gold_500": Color("#F2C7A0"), "gold_300": Color("#FFE6CC"), "rose_500": Color("#A3313D"),
					"paper_100": Color("#FFF4EA")}},
		},
	},
}


static func has(id: String) -> bool:
	return SKINS.has(id)


static func skin(id: String) -> Dictionary:
	return SKINS.get(id, SKINS.five_winds)


static func ids(include_hidden: = true) -> Array:
	var out: = []
	for k in SKINS:
		if include_hidden or not bool(SKINS[k].get("hidden", false)):
			out.append(k)
	return out


static func tokens(id: String, palette: = "") -> Dictionary:
	var t: = BASE_TOKENS.duplicate()
	var sk: = skin(id)
	t.merge(sk.get("tokens", {}), true)
	var pal: Dictionary = sk.get("palettes", {}).get(palette, {})
	t.merge(pal.get("tokens", {}), true)
	return t


static func tint(id: String, palette: = "") -> Color:
	return Color(skin(id).get("palettes", {}).get(palette, {}).get("tint", Color.WHITE))
