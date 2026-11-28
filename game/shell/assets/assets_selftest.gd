class_name TWAssetsSelftest
extends RefCounted

# Selftest of P29 (WP9c): TWAssets registry, composite-id resolvers, the approved-only gate. Prints "TWASSETS_SELFTEST ok/total".
#   * every manifest asset that a runtime loader can open is requested BY ID and loaded: 0 missing
#   * every composite id of every resolver resolves to a manifest record and loads: 0 missing; resolver paths == the legacy helpers
#   * release mode: a not-approved / unknown / wrong-kind / not-in-manifest id returns null + an error code (nothing substituted)
#   * dev mode: the same requests return a flagged placeholder (hatch + red "!" badge, meta tw_placeholder)
# Runs in the real project (needs the import cache), touches no save and no autoload state.

const REAL_IMG: String = "res://assets/ui/logo.webp"
const REAL_SND: String = "res://assets/sfx/clack0.wav"

var _pass: int = 0
var _fail: int = 0
var summary: Dictionary = {}


func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


func run() -> Array:
	TWAssets.quiet = true
	TWAssets.reset()
	_manifest()
	_direct_ids()
	_composites()
	_audit()
	_gate()
	_placeholders()
	TWAssets.reset()
	TWAssets.quiet = false
	var total: int = _pass + _fail
	print("TWASSETS_SELFTEST %d/%d" % [_pass, total])
	print("TWASSETS_SUMMARY ", JSON.stringify(summary))
	return [_pass, total]


func _rec(id: String, path: String, kind: String, status: String) -> Dictionary:
	return {"id": id, "path": path, "kind": kind, "status": status, "referenced_by": []}


# ------------------------------------------------------------------ the real manifest

func _manifest() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(TWAssets.MANIFEST_PATH))
	check("manifest: parses and TWAssets sees every record", raw is Dictionary and TWAssets.ids().size() == (raw["assets"] as Array).size() and TWAssets.ids().size() > 1000,
			str(TWAssets.ids().size()))
	var missing: Array = []
	for id in TWAssets.ids():
		var rec: Dictionary = TWAssets.record(id)
		var p: String = String(rec["path"])
		if not FileAccess.file_exists(p) and not ResourceLoader.exists(p):
			missing.append(p)
	summary["manifest_files_missing"] = missing.size()
	check("manifest: every record's file exists (0 missing)", missing.is_empty(), str(missing.slice(0, 3)))
	var bad_status: int = 0
	for id in TWAssets.ids():
		if not ["approved", "generated", "pending", "rejected"].has(String(TWAssets.record(id)["status"])):
			bad_status += 1
	check("manifest: every status is one of approved/generated/pending/rejected", bad_status == 0)
	var colon: int = 0
	for id in TWAssets.ids():
		if id.contains(":"):
			colon += 1
	check("manifest: no direct id contains ':' (the composite separator)", colon == 0)
	check("TWAssets.mode AUTO is dev in the editor/debug build", not TWAssets.is_release())


# ------------------------------------------------------------------ direct ids

func _direct_ids() -> void:
	var loaded: int = 0
	var missing: Array = []
	var by_kind: Dictionary = {}
	var n: int = 0
	for id in TWAssets.ids():
		var rec: Dictionary = TWAssets.record(id)
		var kind: String = String(rec["kind"])
		var ext: String = String(rec["path"]).get_extension()
		var r: Resource = null
		match kind:
			"image":
				r = TWAssets.tex(id)
			"audio":
				r = TWAssets.stream(id)
			"video":
				r = TWAssets.video(id)
			"font":
				r = TWAssets.font(id)
			"other":
				if ext == "tscn" or ext == "scn":
					r = TWAssets.res(id)
				else:
					continue
			_:
				continue
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		if r == null or TWAssets.is_placeholder(r):
			missing.append(id)
		else:
			loaded += 1
		n += 1
		if n % 40 == 0:
			TWAssets._cache.clear()        # do not keep 1600 textures alive
	TWAssets._cache.clear()
	summary["direct_loaded"] = loaded
	summary["direct_missing"] = missing.size()
	summary["direct_by_kind"] = by_kind
	check("direct ids: %d loadable manifest assets requested by id, all loaded (0 missing)" % loaded, missing.is_empty() and loaded > 1000, str(missing.slice(0, 5)))
	check("direct ids: no problem was logged while loading them", TWAssets.problems.is_empty(), str(TWAssets.problems.slice(0, 3)))


# ------------------------------------------------------------------ composite ids

func _composites() -> void:
	var fams: PackedStringArray = TWAssets.families()
	for f in ["hero_png", "outfit", "emotion", "pose", "koikoi_card", "koikoi_skin", "rig_layer", "sticker", "mj_sfx", "hudfx_particle"]:
		check("family registered: " + f, fams.has(f))
	var ids: PackedStringArray = TWAssets.composite_ids()
	var missing: Array = []
	var loaded: int = 0
	var per_family: Dictionary = {}
	var n: int = 0
	for cid in ids:
		var r: Dictionary = TWAssets.resolve(cid)
		var fam: String = cid.get_slice(":", 0)
		per_family[fam] = int(per_family.get(fam, 0)) + 1
		if not r["ok"]:
			missing.append("%s %s" % [cid, r["error"]])
			continue
		var res: Resource = null
		match String(r["kind"]):
			"image":
				res = TWAssets.tex(cid)
			"audio":
				res = TWAssets.stream(cid)
			_:
				res = TWAssets.res(cid)
		if res == null or TWAssets.is_placeholder(res):
			missing.append(cid + " load")
		else:
			loaded += 1
		n += 1
		if n % 40 == 0:
			TWAssets._cache.clear()
	TWAssets._cache.clear()
	summary["composite_ids"] = ids.size()
	summary["composite_loaded"] = loaded
	summary["composite_missing"] = missing.size()
	summary["composite_per_family"] = per_family
	check("composite ids: %d ids over %d families, every one resolves and loads (0 missing)" % [ids.size(), per_family.size()], missing.is_empty() and ids.size() > 400, str(missing.slice(0, 5)))
	# ids are unique and two ids may share a file only deliberately (none do today)
	var seen: Dictionary = {}
	var dup: int = 0
	for cid in ids:
		if seen.has(cid):
			dup += 1
		seen[cid] = true
	check("composite ids: enumeration has no duplicates", dup == 0)
	# the resolvers agree with the legacy helpers they replace
	check("hero_png:rin == V10W1Core.hero_png(rin)", TWAssets.resolve("hero_png:rin")["path"] == V10W1Core.hero_png("rin"))
	check("hero_png:zlata (wave 1) == V10W1Core.hero_png(zlata)", TWAssets.resolve("hero_png:zlata")["path"] == V10W1Core.hero_png("zlata"))
	check("outfit:hana_beach == V10W1Core.outfit_webp", TWAssets.resolve("outfit:hana_beach")["path"] == V10W1Core.outfit_webp("hana_beach"))
	check("emotion:miel:happy == V10W1Core.emotion_webp", TWAssets.resolve("emotion:miel:happy")["path"] == V10W1Core.emotion_webp("miel", "happy"))
	check("emotion:rin:shy (founder) == V10W1Core.emotion_webp", TWAssets.resolve("emotion:rin:shy")["path"] == V10W1Core.emotion_webp("rin", "shy"))
	check("koikoi_skin:crane == V10MjKoikoiSkins.skin_path", TWAssets.resolve("koikoi_skin:crane")["path"] == V10MjKoikoiSkins.skin_path("crane"))
	check("koikoi_card:7 / back == V10MjKoikoiSkins", TWAssets.resolve("koikoi_card:7")["path"] == V10MjKoikoiSkins.base_path(7) and TWAssets.resolve("koikoi_card:back")["path"] == V10MjKoikoiSkins.BACK)
	for bad in ["hero_png:", "hero_png:rin:extra", "koikoi_card:99", "koikoi_card:x", "koikoi_skin:nope", "sticker:../../g", "nofamily:x", "rig_layer:mc_gown/does_not_exist"]:
		check("composite refused: " + bad, not TWAssets.resolve(bad)["ok"] and String(TWAssets.resolve(bad)["error"]) != "", str(TWAssets.resolve(bad)))
	check("hero_png:ghost expands but has no manifest file -> NOT_IN_MANIFEST", TWAssets.resolve("hero_png:ghost")["error"] == TWAssets.E_NO_FILE)


func _audit() -> void:
	var a: Dictionary = TWAssets.audit()
	summary["audit"] = {"assets": a["assets"], "approved": a["approved"], "composite_ids": a["composite_ids"],
			"unreferenced_total": a["unreferenced_total"], "unreferenced_covered": a["unreferenced_covered"], "covered_by_composite": a["covered"]}
	check("audit: 0 composite ids missing, 0 gated", (a["composite_missing"] as Array).is_empty() and (a["composite_not_approved"] as Array).is_empty(), str(a["composite_missing"].slice(0, 3)))
	check("audit: composite families cover %d of the %d files no script names literally" % [a["unreferenced_covered"], a["unreferenced_total"]],
			int(a["unreferenced_covered"]) >= 350, str(a))


# ------------------------------------------------------------------ the gate

func _gated_manifest() -> Dictionary:
	return {"assets": [
		_rec("t.ok", REAL_IMG, "image", "approved"),
		_rec("t.generated", REAL_IMG, "image", "generated"),
		_rec("t.pending", REAL_IMG, "image", "pending"),
		_rec("t.rejected", REAL_IMG, "image", "rejected"),
		_rec("t.snd_ok", REAL_SND, "audio", "approved"),
		_rec("t.snd_gen", REAL_SND, "audio", "generated"),
		_rec("t.gone", "res://assets/does/not/exist.png", "image", "approved"),
		_rec("t.vid_gen", "res://assets/v09/ult/none.ogv", "video", "generated"),
	]}


func _gate() -> void:
	TWAssets.install_manifest(_gated_manifest())
	TWAssets.problems = []
	TWAssets.mode = TWAssets.Mode.RELEASE
	check("release: is_release() true", TWAssets.is_release())
	var ok: Texture2D = TWAssets.tex("t.ok")
	check("release: an approved id loads", ok != null and not TWAssets.is_placeholder(ok))
	for st in ["generated", "pending", "rejected"]:
		var r: Dictionary = TWAssets.resolve("t." + st)
		check("release: resolve(%s) -> ok=false, NOT_APPROVED, status reported" % st, not r["ok"] and r["error"] == TWAssets.E_NOT_APPROVED and r["status"] == st, str(r))
		check("release: tex(%s) returns null (no substitute)" % st, TWAssets.tex("t." + st) == null)
	check("release: stream(not approved) returns null", TWAssets.stream("t.snd_gen") == null)
	check("release: video(not approved) returns null", TWAssets.video("t.vid_gen") == null)
	check("release: unknown id returns null", TWAssets.tex("t.never") == null and TWAssets.resolve("t.never")["error"] == TWAssets.E_UNKNOWN_ID)
	check("release: wrong kind (stream of an image) returns null", TWAssets.stream("t.ok") == null)
	check("release: approved record whose file is gone returns null (LOAD_FAILED)", TWAssets.tex("t.gone") == null)
	check("release: a composite whose file is not in the manifest returns null", TWAssets.tex("hero_png:rin") == null)
	check("release: nothing was substituted", TWAssets.placeholders_served == 0)
	var codes: Array = []
	for p in TWAssets.problems:
		codes.append(String(p["code"]))
	check("release: every refusal is logged with its code (%d entries)" % codes.size(), codes.size() == 9 and codes.count(TWAssets.E_NOT_APPROVED) == 5 and codes.has(TWAssets.E_UNKNOWN_ID) and codes.has(TWAssets.E_WRONG_KIND) and codes.has(TWAssets.E_LOAD) and codes.has(TWAssets.E_NO_FILE), str(codes))
	check("release: has() is false for the gated id and true for the approved one", not TWAssets.has("t.generated") and TWAssets.has("t.ok"))
	TWAssets.mode = TWAssets.Mode.AUTO


func _placeholders() -> void:
	TWAssets.install_manifest(_gated_manifest())
	TWAssets.problems = []
	TWAssets.placeholders_served = 0
	TWAssets.mode = TWAssets.Mode.DEV
	var ph: Texture2D = TWAssets.tex("t.generated")
	check("dev: a not-approved id returns a placeholder texture", ph != null and TWAssets.is_placeholder(ph))
	check("dev: the placeholder says why (meta)", ph != null and String(ph.get_meta(TWAssets.META)).begins_with(TWAssets.E_NOT_APPROVED) and String(ph.get_meta(TWAssets.META)).contains("t.generated"))
	var real: Texture2D = TWAssets.tex("t.ok")
	check("dev: an approved id still returns the real art, not the placeholder", real != null and not TWAssets.is_placeholder(real) and real != ph)
	check("dev: unknown id -> placeholder", TWAssets.is_placeholder(TWAssets.tex("t.never")))
	check("dev: file gone -> placeholder", TWAssets.is_placeholder(TWAssets.tex("t.gone")))
	check("dev: wrong kind -> placeholder", TWAssets.is_placeholder(TWAssets.tex("t.snd_ok")))
	var s: AudioStream = TWAssets.stream("t.snd_gen")
	check("dev: a not-approved sound returns a flagged silent clip", s != null and TWAssets.is_placeholder(s) and s is AudioStreamWAV)
	var v: VideoStream = TWAssets.video("t.vid_gen")
	check("dev: a not-approved video returns a flagged empty stream", v != null and TWAssets.is_placeholder(v))
	# the "screen test": the badge is really in the pixels, and a placeholder can not be mistaken for art
	var img: Image = ph.get_image() if ph != null else null
	check("dev: placeholder is 128x128 RGBA", img != null and img.get_width() == 128 and img.get_height() == 128)
	if img != null:
		var badge: Color = img.get_pixel(4, 4)
		var mark: Color = img.get_pixel(21, 12)
		check("dev: red badge square in the corner with a white '!'", badge.r > 0.7 and badge.g < 0.2 and badge.b < 0.2 and mark.r > 0.9 and mark.g > 0.9 and mark.b > 0.9, "%s %s" % [badge, mark])
		var hatch_a: Color = img.get_pixel(100, 60)
		var hatch_b: Color = img.get_pixel(116, 60)
		check("dev: magenta / black hatch outside the badge", hatch_a != hatch_b and (hatch_a.r > 0.9 or hatch_b.r > 0.9) and (hatch_a.g < 0.2 and hatch_b.g < 0.2))
		var dir: String = ProjectSettings.globalize_path("user://")
		var saved: int = img.save_png("user://twassets_placeholder.png")
		check("dev: placeholder saves as a PNG for the visual check (%s)" % dir, saved == OK)
	check("dev: placeholders_served counted %d" % TWAssets.placeholders_served, TWAssets.placeholders_served == 6)
	check("dev: problems log kept the dev requests", TWAssets.problems.size() == 6 and String(TWAssets.problems[0]["mode"]) == "dev")
	TWAssets.mode = TWAssets.Mode.AUTO
	TWAssets.reset()
	check("reset(): real manifest is back, no problems, mode AUTO", TWAssets.ids().size() > 1000 and TWAssets.problems.is_empty() and TWAssets.mode == TWAssets.Mode.AUTO)
