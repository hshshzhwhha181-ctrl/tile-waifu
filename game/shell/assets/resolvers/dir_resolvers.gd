class_name TWDirResolvers
extends RefCounted

# "A folder of files addressed by name": family:<name relative to the folder, no extension, '/' kept>. One table, one class.
# These families exist so that files that no script names literally (the loader composes the name, or a tool does) are still
# reachable by id and enumerable. Add a row when a v11 screen needs a new folder; the selftest loads every row.

const IMG: PackedStringArray = ["png", "webp"]
const SND: PackedStringArray = ["ogg", "wav", "mp3"]

# family -> [folder under res://assets/, extensions tried in order]
const TABLE: Dictionary = {
	"map_icon": ["v06/map/", IMG],
	"ui_icon": ["v08/ui/", IMG],
	"path_icon": ["v10/path/", IMG],
	"hf_ui": ["v10/hf_ui/", IMG],
	"hudfx_particle": ["v10/hudfx/particles/", IMG],
	"hudfx_item": ["v10/hudfx/items/", IMG],
	"hudfx_card": ["v10/hudfx/card/", IMG],
	"sticker": ["v10/phone/stickers/", IMG],
	"phone_sfx": ["v10/phone/sfx/", SND],
	"mj_sfx": ["v10/mj/look/sfx/", SND],
	"mj_stage_sfx": ["v10/mj/stage/sfx/", SND],
	"ritual_sfx": ["v10/rituals/sfx/", SND],
	"voice_v10": ["v10/audio/voice/", SND],
	"voice_wave1": ["v10/wave1/audio/voice/", SND],
	"rig_layer": ["v10/rig/", IMG],
	"salon_art": ["v10/salon/", IMG],
	"shop_bg": ["v10/shop/", IMG],
	"cg": ["v10/cg_16/", IMG],
	"ui_art": ["ui/", IMG],
}


class DirFamily extends TWAssetResolver:
	var folder: String = ""
	var exts: PackedStringArray = PackedStringArray()

	func path_of(args: PackedStringArray) -> String:
		if args.size() != 1 or args[0] == "" or args[0].contains("..") or args[0].begins_with("/"):
			return ""
		for e in exts:
			var p: String = "res://assets/" + folder + args[0] + "." + e
			if known.is_empty() or known.has(p):
				return p
		return "res://assets/" + folder + args[0] + "." + exts[0]

	func enumerate(paths: PackedStringArray) -> Array:
		var out: Array = []
		var seen: Dictionary = {}
		for n in TWAssetResolver.under(paths, "res://assets/" + folder, exts):
			if not seen.has(n):
				seen[n] = true
				out.append(PackedStringArray([n]))
		return out


static func all() -> Array:
	var out: Array = []
	for fam in TABLE:
		var row: Array = TABLE[fam]
		var d: DirFamily = DirFamily.new()
		d.family = String(fam)
		d.folder = String(row[0])
		d.exts = row[1]
		out.append(d)
	return out
