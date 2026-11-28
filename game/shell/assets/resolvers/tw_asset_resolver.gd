class_name TWAssetResolver
extends RefCounted

# A composite-id resolver (P29 / WP9c). A composite id is "family:arg[:arg...]" ("hero_png:rin", "emotion:miel:happy").
# The resolver turns the args into the res:// path of ONE manifest asset (path_of) and lists every arg tuple that exists in
# the manifest (enumerate), so "which files can be reached only by a composed name" is a checkable list instead of a dir
# listing at runtime. TWAssets maps the path back to the manifest record and applies the status gate there.
#
# A resolver owns no files and no state. It may call the legacy path helpers (V10W1Core.hero_png ...) so that the id and the
# old call site can never disagree; the selftest compares both sides for every enumerated id.

var family: String = ""
# res:// path -> manifest record, the same Dictionary TWAssets holds (set by TWAssets at registration); a resolver may use it to
# pick among extensions
var known: Dictionary = {}


# the res:// path for args, "" when the args do not form a valid id of this family
func path_of(_args: PackedStringArray) -> String:
	return ""


# every arg tuple (PackedStringArray) of this family that has a file in the manifest; `paths` = all manifest paths
func enumerate(_paths: PackedStringArray) -> Array:
	return []


# ---- helpers for enumerate() -------------------------------------------------------------------

# the part of each path under `prefix` ("res://assets/hero/") with the extension cut off, for paths that end in one of `exts`
static func under(paths: PackedStringArray, prefix: String, exts: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p in paths:
		if not p.begins_with(prefix):
			continue
		var ext: String = p.get_extension().to_lower()
		if not exts.has(ext):
			continue
		out.append(p.substr(prefix.length(), p.length() - prefix.length() - ext.length() - 1))
	return out
