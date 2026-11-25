class_name V10Rank
extends RefCounted

# V10Rank — the ONE rarity vocabulary (docs/0.10-spec.md M1 Ф3, UX_RULES §4.2): A / S / SSR.
# The data keeps the 0.9 codes (G.ITEMS rar "R" | "SR" | "SSR"); everything the player sees goes through here.
#   V10Rank.label("SR") -> "S"         V10Rank.color("SSR") -> Color      V10Rank.hint() -> one line for «?»
#   V10Rank.hero_rank("rin") -> "S"    V10Rank.outfit_rank("o_dragon") -> "SSR"   (look kit_data, profile)

const CODES: = ["A", "S", "SSR"]
const OF_LEGACY: = {"R": "A", "N": "A", "A": "A", "SR": "S", "S": "S", "SSR": "SSR"}
# full saturation only on the rarity pill and at a reveal (UX §6.2)
const COLORS: = {"A": Color("6fdcae"), "S": Color("c99bff"), "SSR": Color("ffcf4a")}
const GLOW: = {"A": Color("a9f0d0"), "S": Color("e6e0ff"), "SSR": Color("fff0b0")}
const NAMES: = {"A": "Редкость A", "S": "Редкость S", "SSR": "Редкость SSR"}
const HINT: = "Редкость — это сколько косметики у наряда, силы в рейтинге она не даёт"


static func code(rar: String) -> String:
	return str(OF_LEGACY.get(rar.strip_edges().to_upper(), "A"))


static func label(rar: String) -> String:
	return code(rar)


static func color(rar: String) -> Color:
	return COLORS[code(rar)]


static func glow(rar: String) -> Color:
	return GLOW[code(rar)]


static func hint() -> String:
	return HINT


static func order(rar: String) -> int:
	return CODES.find(code(rar))


static func outfit_rank(outfit: String) -> String:
	var g = _g()
	if g == null or not g.ITEM.has(outfit):
		return ""  # not a G item: V10KitData resolves its EXTRA_OUTFITS itself
	return code(str(g.ITEM[outfit].get("rar", "R")))


# a heroine's rank is her roster rank (ROSTER_20 §1.1, the kits of V10KitData carry it); unknown → A
static func hero_rank(hero: String) -> String:
	var k = V10KitData.KITS.get(hero)
	return code(str(k.get("rank", "A"))) if k is Dictionary else "A"


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null
