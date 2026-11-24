class_name V10MjStageData
extends RefCounted

# V10MjStageData — data the presence director reads: pose keys (docs/POSES.md §0.5), which painted frame stands
# for a pose until her rig has it, design tokens (UX_RULES §6.2, «Тишина и лак»; the DS class is not in the tree
# yet — when it lands, TOK maps 1:1 onto DS), and her accent (UX §6.2: accent / glow / deep, ≤ 10 % of pixels).

# POSES.md §0.5 silhouette keys of the five founders, slots used in a match
const POSE_KEYS: = {
	"mc": {"idle": "table-hip-lean-tile-twirl", "select": "wide-side-stance-tile-flick", "win": "table-slam-flourish",
		"lose": "arms-crossed-tile-fist-turnaway", "shy": "sleeve-tug-twin-tail-wind"},
	"rin": {"idle": "tall-stool-cross-hooked-foot", "select": "high-pour-between-shelves", "win": "formal-half-bow-parallel",
		"lose": "fogged-lenses-push-up", "shy": "ladder-rung-knuckle-glasses"},
	"hana": {"idle": "one-leg-quad-stretch", "select": "lunge-high-five", "win": "airborne-fist-knee-tuck",
		"lose": "hands-on-knee-panting-point", "shy": "triceps-stretch-hide"},
	"yue": {"idle": "fan-at-lips-s-curve", "select": "water-sleeve-spiral", "win": "seated-on-crescent-moon",
		"lose": "lean-in-hands-behind-curious", "shy": "full-fan-face-shield"},
	"nova": {"idle": "air-typing-slouch", "select": "bike-sidesaddle-knees-together", "win": "mic-drop-tile",
		"lose": "side-crouch-poke-cable", "shy": "popup-panic-swipe"},
}

# waist-up painted frames (assets/v08/emotions/<hero>_<frame>.webp, adult cut-outs already in the game) standing
# for a slot until her rig has the pose. Chosen by what the frame reads as at 140 px:
# happy = open wave (serving a wave, the win), surprised = «ах!» hands up (signature, ×8), pout = arms crossed
# (danger: bites her lip), sad = hands clasped, soft (the warm «почти» after a loss), shy = finger at the cheek (rest).
const FRAME_OF: = {"idle": "shy", "rest": "shy", "select": "surprised", "win": "happy", "lose": "sad", "shy": "shy",
	"danger": "pout", "wave": "happy", "smile": "happy", "ah": "surprised"}
const EMO_DIR: = "res://assets/v08/emotions/"

# design tokens (UX_RULES §6.2)
const TOK: = {
	"night900": Color("121014"), "night800": Color("1b171c"), "night700": Color("26212a"), "night600": Color("332c36"),
	"paper100": Color("f5ead8"), "paper300": Color("ddd2c4"), "paper500": Color("b3a89c"), "paper700": Color("7e756d"),
	"gold300": Color("f1d9a0"), "gold500": Color("e8c47e"), "gold700": Color("a87b3a"),
	"rose500": Color("d796a5"), "jade300": Color("a9d9c4"), "ember": Color("e07a7a"),
}
const FALLBACK_ACCENT: = {"mc": "ff8fb8", "rin": "4fbf9f", "hana": "ffb35c", "yue": "c8b6ff", "nova": "4fe3ff",
	"tsubame": "7fa7ff", "miel": "ffb3c7", "kohaku": "ff9b54", "shirin": "e8c47e", "zlata": "ff7a45"}


static func pose_key(hero: String, slot: String) -> String:
	var h: String = hero if POSE_KEYS.has(hero) else "mc"
	return String((POSE_KEYS[h] as Dictionary).get(slot, ""))


static func frame_path(hero: String, slot: String) -> String:
	var f: String = FRAME_OF.get(slot, slot)
	var p: = EMO_DIR + "%s_%s.webp" % [hero, f]
	if ResourceLoader.exists(p):
		return p
	return EMO_DIR + "mc_%s.webp" % f


static func accent(hero: String) -> Color:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g and g.get("HEROES") is Dictionary and (g.HEROES as Dictionary).has(hero):
		return g.HEROES[hero].color
	return Color(String(FALLBACK_ACCENT.get(hero, "ff8fb8")))


static func glow(hero: String) -> Color:
	return accent(hero).lightened(0.35)


static func deep(hero: String) -> Color:
	return accent(hero).darkened(0.55)


# the global class registry (no hard dependency on lanes that may not be merged yet)
static func global_class_path(cls: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			return String(c.get("path", ""))
	return ""


static func fx_level() -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g and g.has_method("fx_level"):
		return String(g.fx_level())
	return "full"
