class_name V10DS
extends RefCounted

# V10DS — design tokens of HUD v2 (docs/HUD_V2.md §2.2, §3.1, §5; UX_RULES §6.2).
# This is the hud2 copy of the future `DS` class (`v10/design/tokens.gd`): when that lands, alias these
# constants to it and keep the names. Hex literals live ONLY here (selftest greps the hud2 code for others).

# --- colour (UX §6.2) ---
const NIGHT_900: = Color("#121014")  # background, text on «Игра»
const NIGHT_800: = Color("#1B171C")  # plate surface
const NIGHT_700: = Color("#26212A")  # sheet, «Касса»
const NIGHT_600: = Color("#332C36")  # pressed, dividers, progress track
const PAPER_100: = Color("#F5EAD8")  # text.primary
const PAPER_300: = Color("#DDD2C4")  # text.secondary
const PAPER_500: = Color("#B3A89C")  # text.caption, inactive icon
const PAPER_700: = Color("#7E756D")  # text.disabled
const GOLD_300: = Color("#F1D9A0")  # num.reward, active icon, selected
const GOLD_500: = Color("#E8C47E")  # line.focus, «Касса» border, overline
const GOLD_700: = Color("#A87B3A")  # line.hair (always at HAIR_A)
const ROSE_300: = Color("#ECC0C9")  # «new» dot
const ROSE_500: = Color("#D796A5")  # fill.primary — only «Игра»
const ROSE_700: = Color("#9A4F66")  # «Игра» pressed
const JADE_300: = Color("#A9D9C4")  # progress
const JADE_500: = Color("#5B9580")
const EMBER: = Color("#E07A7A")  # danger: last tray slot
const FELT_HI: = Color("#1C4A3B")  # table felt, centre (no frame around it, §9.2)
const FELT_LO: = Color("#0B211B")  # table felt, edge
const SHADOW: = Color("#121014")  # text shadow on art (α SHADOW_A)
const TINT_SCENE: = Color("#8C8594")  # backdrop dimming in the match scene
const TINT_HOME: = Color("#9E94A3")  # backdrop dimming at home
const TINT_VICTORY: = Color("#807887")  # backdrop dimming on the victory beat

const HAIR_A: = 0.35  # hairline gold.700 alpha
const LACQUER_A: = 0.05  # paper.100 lacquer gradient alpha (top 40 %)
const BOTTOM_TONE_A: = 0.6  # 1 px night.900 inside the bottom edge
const ON_ART_A: = 0.92  # plate fill alpha over art
const SHADOW_A: = 0.55

# --- metrics (base 720 px) ---
const GRID: = 8
const RADIUS: = 4
const PLATE_H: = {"S": 48, "M": 80, "L": 160}
const TRAY_H: = 104  # the one height exception (cell = tile 80x96 + 4)
const PLATE_WIDTHS: = {"S": [96, 144, 192, 216, 240, 288], "M": [200, 328, 656, 672], "L": [328, 656, 672]}
const PLATE_PAD: = {"S": 16, "M": 24, "L": 24}
const HIT_MIN: = 80
const HAIR_INSET: = 12
const HAIR_FADE: = 24

# --- type scale (closed; §3) ---
const DISPLAY_SIZES: = [64, 44, 32, 28, 26]  # 28/26 only as fit() steps of 32
const UI_SIZES: = [26, 22, 20, 18, 15]  # 20 only as a fit() step of 22; 15 = overline
const NUM_SIZES: = [40, 32, 28, 22]  # 32 only as a fit() step of 40

# --- motion (§6) ---
const T_IN: = 0.24
const T_IN_STEP: = 0.04
const T_OUT: = 0.16
const T_ROLL: = 0.32
const T_PROGRESS: = 0.40
const T_COMBO: = 0.60
const T_BANNER: = 0.80

# --- heroine accents (accent / glow / deep; ≤ 10 % of pixels) and showcase element ---
const HEROES: = {
	"mc": {"name": "Маджонг-тян", "accent": Color("#F2A7BF"), "glow": Color("#FFD3E0"), "deep": Color("#8E3F5C"), "element": "petal"},
	"rin": {"name": "Рин", "accent": Color("#7FCFB0"), "glow": Color("#CDEFE0"), "deep": Color("#2E6B57"), "element": "leaf"},
	"hana": {"name": "Хана", "accent": Color("#FFB25A"), "glow": Color("#FFE0B0"), "deep": Color("#A3521C"), "element": "spark"},
	"yue": {"name": "Юэ", "accent": Color("#C9B2F0"), "glow": Color("#EEE6FF"), "deep": Color("#5A4690"), "element": "dust"},
	"nova": {"name": "Нова", "accent": Color("#6FE6F2"), "glow": Color("#D2FAFF"), "deep": Color("#7A2E8E"), "element": "glitch"},
}


static func hero(id: String) -> Dictionary:
	return HEROES.get(id, HEROES.mc)


static func hair() -> Color:
	return Color(GOLD_700, HAIR_A)


static func snap(v: float) -> float:
	return roundf(v / GRID) * GRID


static func plate_width(size_class: String, w: float) -> int:
	# nearest module width of the family (§2.1): plates never take arbitrary widths
	var best: int = PLATE_WIDTHS[size_class][0]
	for m in PLATE_WIDTHS[size_class]:
		if absf(m - w) < absf(best - w):
			best = m
	return best
