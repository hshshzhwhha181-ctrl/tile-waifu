class_name TWHeroResolvers
extends RefCounted

# The hero-art families: founders live under assets/hero|outfits|v08/emotions, wave-1 goddesses under assets/v10/wave1/**.
# Paths come from V10W1Core (the one place that knows the split), so a composite id and the legacy call site agree.

const IMG: PackedStringArray = ["png", "webp"]


class HeroPng extends TWAssetResolver:
	func _init() -> void:
		family = "hero_png"

	func path_of(args: PackedStringArray) -> String:
		return V10W1Core.hero_png(args[0]) if args.size() == 1 and args[0] != "" else ""

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for pre in ["res://assets/hero/", "res://assets/v10/wave1/hero/"]:
			for n in TWAssetResolver.under(paths, pre, IMG):
				out.append(PackedStringArray([n]))
		return out


class Outfit extends TWAssetResolver:
	func _init() -> void:
		family = "outfit"

	func path_of(args: PackedStringArray) -> String:
		return V10W1Core.outfit_webp(args[0]) if args.size() == 1 and args[0] != "" else ""

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for pre in ["res://assets/outfits/", "res://assets/v10/wave1/outfits/"]:
			for n in TWAssetResolver.under(paths, pre, IMG):
				out.append(PackedStringArray([n]))
		return out


class Emotion extends TWAssetResolver:
	func _init() -> void:
		family = "emotion"

	func path_of(args: PackedStringArray) -> String:
		return V10W1Core.emotion_webp(args[0], args[1]) if args.size() == 2 and args[0] != "" and args[1] != "" else ""

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for pre in ["res://assets/v08/emotions/", "res://assets/v10/wave1/emotions/"]:
			for n in TWAssetResolver.under(paths, pre, IMG):
				var i: int = n.find("_")
				if i > 0:
					out.append(PackedStringArray([n.substr(0, i), n.substr(i + 1)]))
		return out


class Pose extends TWAssetResolver:
	func _init() -> void:
		family = "pose"

	func path_of(args: PackedStringArray) -> String:
		return V10W1Core.pose_path(args[0], args[1]) if args.size() == 2 and args[0] != "" and args[1] != "" else ""

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		for n in TWAssetResolver.under(paths, "res://assets/v10/wave1/poses/", IMG):
			var i: int = n.find("_")
			if i > 0:
				out.append(PackedStringArray([n.substr(0, i), n.substr(i + 1)]))
		return out
