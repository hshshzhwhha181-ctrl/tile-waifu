class_name TWAssets
extends RefCounted

# TWAssets (P29 / WP9c): the one door to a runtime asset. Screens of the v11 shell never write "res://assets/..."; they ask for
# an id and get a resource:  TWAssets.tex("bg.bg_festival"), TWAssets.stream("sfx.tile_clack"), TWAssets.video("v10.ult_video.mc_base").
#
# IDS
#   direct     the manifest id of game/assets/manifest/assets.json (tools/assets/gen_manifest.py): "bg.bg_festival", "v10.rig.mc_gown.rig"
#   composite  "family:arg[:arg]" for files that a loader names by composing a string (hero art by hero id, emotion by hero + mood,
#              Koi-Koi cards, deck skins, rig layers, voice lines ...). Each family is a resolver (resolvers/*.gd) that maps the args
#              to ONE manifest record and enumerates every id it can produce, so liveness is a list, not a dir scan.
#              "hero_png:rin"  "outfit:hana_beach"  "emotion:miel:happy"  "koikoi_card:7"  "koikoi_skin:crane"  "rig_layer:mc_gown/body"
#
# STATUS GATE (the approved-assets manifest, ARCH WP9)
#   release mode  an id whose record is not status "approved", an unknown id, a composite that expands to no manifest file, a wrong
#                 kind, an unloadable file: tex()/stream()/video()/font()/scene() return null, push_error() is called and the call
#                 is logged in `problems` (code + id). Nothing is substituted: a broken id must show up in QA, not on a phone.
#   dev mode      the same request returns a FLAGGED PLACEHOLDER: tex() a magenta/black hatch with a red "!" badge in the corner,
#                 stream() a silent clip, video() an empty stream; every placeholder carries meta "tw_placeholder" = the reason,
#                 and TWAssets.is_placeholder(res) tells. The call is logged in `problems` too.
#   mode          AUTO (default): release when the build has the "release" feature or the user arg --assets=release is given, dev
#                 otherwise. TWAssets.mode = TWAssets.Mode.RELEASE/DEV forces it (tests, "preview as release" in the dev menu).
#
# Static class (no autoload: project.godot is not touched by this package); state lives in static vars. For tests:
#   TWAssets.install_manifest(dict) swaps the manifest, TWAssets.reset() reloads from disk and forgets caches and problems.

enum Mode { AUTO, DEV, RELEASE }

const MANIFEST_PATH: String = "res://assets/manifest/assets.json"
const APPROVED: String = "approved"
const META: String = "tw_placeholder"

# error codes of resolve()
const E_UNKNOWN_ID: String = "UNKNOWN_ID"
const E_UNKNOWN_FAMILY: String = "UNKNOWN_FAMILY"
const E_BAD_ARGS: String = "BAD_ARGS"
const E_NO_FILE: String = "NOT_IN_MANIFEST"      # composite expanded to a path that has no manifest record
const E_NOT_APPROVED: String = "NOT_APPROVED"
const E_WRONG_KIND: String = "WRONG_KIND"
const E_LOAD: String = "LOAD_FAILED"

static var mode: int = Mode.AUTO
static var quiet: bool = false                  # no push_error (selftests)
static var problems: Array = []                 # [{id, code, mode, kind}] one per refused / substituted request
static var placeholders_served: int = 0

static var _loaded: bool = false
static var _by_id: Dictionary = {}              # manifest id -> record
static var _by_path: Dictionary = {}            # res:// path -> record
static var _resolvers: Dictionary = {}          # family -> TWAssetResolver
static var _cache: Dictionary = {}              # res:// path -> Resource
static var _ph_tex: Texture2D = null
static var _ph_audio: AudioStream = null


# ------------------------------------------------------------------ mode

static func is_release() -> bool:
	if mode == Mode.RELEASE:
		return true
	if mode == Mode.DEV:
		return false
	return OS.has_feature("release") or OS.get_cmdline_user_args().has("--assets=release")


# ------------------------------------------------------------------ manifest + resolvers

static func reset() -> void:
	_loaded = false
	_by_id = {}
	_by_path = {}
	_resolvers = {}
	_cache = {}
	problems = []
	placeholders_served = 0
	_ph_tex = null
	_ph_audio = null
	mode = Mode.AUTO
	_ensure()


# swap the manifest for a dictionary of the same schema ({"assets": [records]}); resolvers are kept
static func install_manifest(m: Dictionary) -> void:
	_by_id = {}
	_by_path = {}
	_cache = {}
	_loaded = true
	for r in (m.get("assets", []) as Array):
		var rec: Dictionary = r
		_by_id[String(rec.get("id", ""))] = rec
		_by_path[String(rec.get("path", ""))] = rec
	var prev: Dictionary = _resolvers.duplicate()
	_register_builtin()
	for f in prev:
		if not _resolvers.has(f):
			register_resolver(prev[f])


static func _ensure() -> void:
	if _loaded:
		return
	var txt: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(txt) if txt != "" else null
	install_manifest(parsed if parsed is Dictionary else {})


static func _register_builtin() -> void:
	_resolvers = {}
	var all: Array = [TWHeroResolvers.HeroPng.new(), TWHeroResolvers.Outfit.new(), TWHeroResolvers.Emotion.new(), TWHeroResolvers.Pose.new(),
			TWKoikoiResolvers.Card.new(), TWKoikoiResolvers.DeckSkin.new()]
	all.append_array(TWDirResolvers.all())
	for r in all:
		register_resolver(r)


static func register_resolver(r: TWAssetResolver) -> void:
	r.known = _by_path
	_resolvers[r.family] = r


static func families() -> PackedStringArray:
	_ensure()
	var out: PackedStringArray = PackedStringArray()
	for f in _resolvers:
		out.append(String(f))
	out.sort()
	return out


static func record(manifest_id: String) -> Dictionary:
	_ensure()
	return _by_id.get(manifest_id, {})


# every direct manifest id, sorted
static func ids() -> PackedStringArray:
	_ensure()
	var out: PackedStringArray = PackedStringArray()
	for k in _by_id:
		out.append(String(k))
	out.sort()
	return out


# every composite id the resolvers can produce from the manifest ("family:a:b"), sorted; family "" = all families
static func composite_ids(family: String = "") -> PackedStringArray:
	_ensure()
	var paths: PackedStringArray = PackedStringArray()
	for p in _by_path:
		paths.append(String(p))
	var out: PackedStringArray = PackedStringArray()
	for f in _resolvers:
		if family != "" and f != family:
			continue
		var r: TWAssetResolver = _resolvers[f]
		for args in r.enumerate(paths):
			out.append(String(f) + ":" + ":".join(args as PackedStringArray))
	out.sort()
	return out


# ------------------------------------------------------------------ resolve

# -> {ok, request, id (manifest id), path, kind, status, error, message}; ok == false means "do not use"; the record is still
# filled when the id was found (a not-approved asset reports its status). Does not log and does not load.
static func resolve(request: String) -> Dictionary:
	_ensure()
	var out: Dictionary = {"ok": false, "request": request, "id": "", "path": "", "kind": "", "status": "", "error": "", "message": ""}
	var rec: Dictionary = {}
	if request.contains(":"):
		var parts: PackedStringArray = request.split(":")
		var r: TWAssetResolver = _resolvers.get(parts[0], null)
		if r == null:
			return _err(out, E_UNKNOWN_FAMILY, "no resolver for family '%s'" % parts[0])
		var path: String = r.path_of(parts.slice(1))
		if path == "":
			return _err(out, E_BAD_ARGS, "'%s' are not valid args of family '%s'" % [":".join(parts.slice(1)), parts[0]])
		if not _by_path.has(path):
			out["path"] = path
			return _err(out, E_NO_FILE, "'%s' expands to %s, which is not in the manifest" % [request, path])
		rec = _by_path[path]
	else:
		if not _by_id.has(request):
			return _err(out, E_UNKNOWN_ID, "no asset '%s' in the manifest" % request)
		rec = _by_id[request]
	out["id"] = String(rec.get("id", ""))
	out["path"] = String(rec.get("path", ""))
	out["kind"] = String(rec.get("kind", ""))
	out["status"] = String(rec.get("status", ""))
	if out["status"] != APPROVED:
		return _err(out, E_NOT_APPROVED, "'%s' has status '%s', only 'approved' ships" % [out["id"], out["status"]])
	out["ok"] = true
	return out


static func _err(out: Dictionary, code: String, msg: String) -> Dictionary:
	out["ok"] = false
	out["error"] = code
	out["message"] = msg
	return out


static func has(request: String) -> bool:
	return bool(resolve(request)["ok"])


# ------------------------------------------------------------------ typed access

static func tex(request: String) -> Texture2D:
	return _load(request, "image", "texture") as Texture2D


static func stream(request: String) -> AudioStream:
	return _load(request, "audio", "audio") as AudioStream


static func video(request: String) -> VideoStream:
	return _load(request, "video", "video") as VideoStream


static func font(request: String) -> Font:
	return _load(request, "font", "font") as Font


# a scene / script / resource file of kind "other" (rig.tscn, rig.scn), or any approved asset as a Resource
static func res(request: String) -> Resource:
	return _load(request, "", "other") as Resource


static func is_placeholder(r: Resource) -> bool:
	return r != null and r.has_meta(META)


static func _load(request: String, want_kind: String, ph_kind: String) -> Resource:
	var info: Dictionary = resolve(request)
	var code: String = String(info["error"])
	if code == "" and want_kind != "" and info["kind"] != want_kind:
		code = E_WRONG_KIND
		_err(info, code, "'%s' is a %s, not a %s" % [request, info["kind"], want_kind])
	if code == "":
		var path: String = String(info["path"])
		if _cache.has(path):
			return _cache[path]
		var loaded: Resource = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
		if loaded != null:
			_cache[path] = loaded
			return loaded
		code = E_LOAD
		_err(info, code, "%s is in the manifest but does not load" % path)
	return _refuse(request, info, ph_kind)


static func _refuse(request: String, info: Dictionary, ph_kind: String) -> Resource:
	var rel: bool = is_release()
	problems.append({"id": request, "code": info["error"], "mode": "release" if rel else "dev", "kind": ph_kind})
	if not quiet:
		push_error("TWAssets[%s] %s: %s" % ["release" if rel else "dev", info["error"], info["message"]])
	if rel:
		return null
	placeholders_served += 1
	var r: Resource = _placeholder(ph_kind)
	if r != null:
		r.set_meta(META, "%s %s" % [info["error"], request])
	return r


# ------------------------------------------------------------------ placeholders (dev only)

static func _placeholder(kind: String) -> Resource:
	match kind:
		"texture":
			if _ph_tex == null:
				_ph_tex = _make_badge_texture()
			return _ph_tex
		"audio":
			if _ph_audio == null:
				var w: AudioStreamWAV = AudioStreamWAV.new()
				w.format = AudioStreamWAV.FORMAT_8_BITS
				w.mix_rate = 8000
				var silence: PackedByteArray = PackedByteArray()
				silence.resize(800)
				w.data = silence
				_ph_audio = w
			return _ph_audio
		"video":
			return VideoStreamTheora.new()
	return null


# 128x128: magenta / black diagonal hatch with a red square and a white "!" in the top-left corner: visible on any background,
# readable at 24 px, and not a colour the art uses
static func _make_badge_texture() -> Texture2D:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a: Color = Color(1.0, 0.0, 0.85, 1.0)
	var b: Color = Color(0.1, 0.1, 0.1, 1.0)
	for y in n:
		for x in n:
			img.set_pixel(x, y, a if int((x + y) / 16) % 2 == 0 else b)
	img.fill_rect(Rect2i(0, 0, 44, 44), Color(0.85, 0.05, 0.05, 1.0))
	img.fill_rect(Rect2i(19, 8, 7, 20), Color.WHITE)
	img.fill_rect(Rect2i(19, 32, 7, 7), Color.WHITE)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ audit (QA)

# {assets, approved, composite_ids, composite_missing: [id], composite_not_approved: [id], reachable_only_by_composite,
#  unreferenced_total, unreferenced_covered}: the numbers of the "715 files only through composed ids" risk
static func audit() -> Dictionary:
	_ensure()
	var covered: Dictionary = {}
	var missing: Array = []
	var gated: Array = []
	var comp: PackedStringArray = composite_ids()
	for cid in comp:
		var r: Dictionary = resolve(cid)
		if r["error"] == E_NO_FILE or r["error"] == E_BAD_ARGS or r["error"] == E_UNKNOWN_FAMILY:
			missing.append(cid)
		elif r["error"] == E_NOT_APPROVED:
			gated.append(cid)
		if r["id"] != "":
			covered[r["id"]] = true
	var approved: int = 0
	var unref: int = 0
	var unref_cov: int = 0
	for k in _by_id:
		var rec: Dictionary = _by_id[k]
		if rec.get("status", "") == APPROVED:
			approved += 1
		if (rec.get("referenced_by", []) as Array).is_empty():
			unref += 1
			if covered.has(k):
				unref_cov += 1
	return {"assets": _by_id.size(), "approved": approved, "composite_ids": comp.size(), "composite_missing": missing,
			"composite_not_approved": gated, "unreferenced_total": unref, "unreferenced_covered": unref_cov, "covered": covered.size()}
