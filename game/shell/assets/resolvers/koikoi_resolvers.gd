class_name TWKoikoiResolvers
extends RefCounted

# Koi-Koi deck art: the 48 cards + back ("koikoi_card:7", "koikoi_card:back") and the five heroine skins
# ("koikoi_skin:crane"). Paths are the ones of V10MjKoikoiSkins (BASE / BACK / skin_path).


class Card extends TWAssetResolver:
	func _init() -> void:
		family = "koikoi_card"

	func path_of(args: PackedStringArray) -> String:
		if args.size() != 1:
			return ""
		if args[0] == "back":
			return V10MjKoikoiSkins.BACK
		if not args[0].is_valid_int():
			return ""
		var c: int = int(args[0])
		return V10MjKoikoiSkins.base_path(c) if c >= 0 and c < 48 else ""

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for c in range(48):
			if paths.has(V10MjKoikoiSkins.base_path(c)):
				out.append(PackedStringArray([str(c)]))
		if paths.has(V10MjKoikoiSkins.BACK):
			out.append(PackedStringArray(["back"]))
		return out


class DeckSkin extends TWAssetResolver:
	func _init() -> void:
		family = "koikoi_skin"

	func path_of(args: PackedStringArray) -> String:
		if args.size() != 1 or not V10MjKoikoiSkins.HEROINE_LIGHTS.has(args[0]):
			return ""
		return V10MjKoikoiSkins.skin_path(args[0])

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for tg in V10MjKoikoiSkins.HEROINE_LIGHTS:
			if paths.has(V10MjKoikoiSkins.skin_path(String(tg))):
				out.append(PackedStringArray([String(tg)]))
		return out
