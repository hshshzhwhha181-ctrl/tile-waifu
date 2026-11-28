class_name TWLegalData
extends RefCounted

# TWLegalData (P108 / MP PM21): loads and validates the 13 Russian legal template documents.
# Lookup order when no custom directory is injected:
#   1. res://data/legal/        (packaged JSON resources inside game/ — auto-exported under all_resources)
#   2. <repo_root>/data/legal/  (source-of-truth folder fallback for desktop/dev runs)
# Security & integrity:
#   - Rejects any manifest filename with path traversal ('..', '/', '\\', ':').
#   - Automatically runs validate_bundle() on load_bundle() so runtime screens can fail closed on tampering.
#   - Reads manifest.real_payments_enabled and blocks enabling real payments while '[ЗАПОЛНИТЬ' placeholders remain.
# Pure data loader: no scene-tree dependencies, no res://assets literals, no hardcoded prices/odds.

const EXPECTED_DOC_COUNT: int = 13
const MANIFEST_FILE: String = "manifest.json"
const BUNDLE_FILE: String = "legal_bundle.json"
const PLACEHOLDER_MARKER: String = "[ЗАПОЛНИТЬ"
const REQUIRED_DISCLAIMER: String = "шаблон, не юридическая консультация, нужна проверка юристом"
const REQUIRED_REFUND_CLAUSE: String = "не возвращаются, за исключением случаев, предусмотренных законом и правилами магазина"
const REFUND_DOC_IDS: = ["offer", "gacha_rules", "refund_rules"]
const REQUIRED_CONSENT_IDS: = ["offer", "privacy", "pdn_consent", "age_18_full_tier"]

var base_dir: String = ""
var manifest: Dictionary = {}
var _docs_by_id: Dictionary = {}
var _bundle_docs: Dictionary = {}
var _text_cache: Dictionary = {}
var _validation_errors: Array = []
var _last_error: String = ""


func _init(p_base_dir: String = "") -> void:
	base_dir = resolve_dir(p_base_dir)
	load_bundle(base_dir)


static func is_safe_rel_filename(fname: String) -> bool:
	var f: String = fname.strip_edges()
	if f == "" or f != fname:
		return false
	if f.contains("..") or f.contains("/") or f.contains("\\") or f.contains(":") or f.begins_with("."):
		return false
	return true


static func resolve_dir(override_dir: String = "") -> String:
	if override_dir != "":
		return override_dir.trim_suffix("/").trim_suffix("\\")
	if FileAccess.file_exists("res://data/legal/" + MANIFEST_FILE) or ResourceLoader.exists("res://data/legal/" + MANIFEST_FILE):
		return "res://data/legal"
	var res_abs: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var repo_legal: String = res_abs.get_base_dir().path_join("data/legal")
	if FileAccess.file_exists(repo_legal.path_join(MANIFEST_FILE)):
		return repo_legal
	return "res://data/legal"


static func _read_json_dict(path: String) -> Variant:
	if FileAccess.file_exists(path):
		var raw: String = FileAccess.get_file_as_string(path)
		if raw.strip_edges() != "":
			return JSON.parse_string(raw)
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is JSON:
			return (res as JSON).data
	return null


func load_bundle(dir_path: String = "") -> bool:
	if dir_path != "":
		base_dir = dir_path.trim_suffix("/").trim_suffix("\\")
	manifest = {}
	_docs_by_id.clear()
	_bundle_docs.clear()
	_text_cache.clear()
	_validation_errors.clear()
	_last_error = ""
	var mpath: String = base_dir.path_join(MANIFEST_FILE)
	var parsed: Variant = _read_json_dict(mpath)
	if parsed == null:
		_last_error = "manifest_missing_or_empty:" + mpath
		_validation_errors = ["bundle_not_loaded:" + _last_error]
		return false
	if not (parsed is Dictionary):
		_last_error = "manifest_bad_json"
		_validation_errors = ["bundle_not_loaded:" + _last_error]
		return false
	manifest = parsed as Dictionary
	var docs: Variant = manifest.get("documents", [])
	if docs is Array:
		for item in docs:
			if item is Dictionary:
				var did: String = str((item as Dictionary).get("id", ""))
				if did != "":
					_docs_by_id[did] = item
	var bpath: String = base_dir.path_join(BUNDLE_FILE)
	var bparsed: Variant = _read_json_dict(bpath)
	if bparsed is Dictionary:
		var bdocs: Variant = (bparsed as Dictionary).get("documents", {})
		if bdocs is Dictionary:
			_bundle_docs = bdocs as Dictionary
	_validation_errors = validate_bundle()
	return not _docs_by_id.is_empty()


func last_error() -> String:
	return _last_error


func is_loaded() -> bool:
	return not manifest.is_empty() and not _docs_by_id.is_empty()


func is_valid() -> bool:
	return is_loaded() and _validation_errors.is_empty()


func validation_errors() -> Array:
	return _validation_errors.duplicate()


func is_packaged_in_res() -> bool:
	return (
		(FileAccess.file_exists("res://data/legal/" + MANIFEST_FILE) or ResourceLoader.exists("res://data/legal/" + MANIFEST_FILE))
		and (FileAccess.file_exists("res://data/legal/" + BUNDLE_FILE) or ResourceLoader.exists("res://data/legal/" + BUNDLE_FILE))
	)


func offer_version() -> String:
	return str(manifest.get("offer_ver", manifest.get("bundle_ver", "")))


func bundle_version() -> String:
	return str(manifest.get("bundle_ver", ""))


func real_payments_enabled() -> bool:
	return bool(manifest.get("real_payments_enabled", false))


func disclaimer_text() -> String:
	var d: String = str(manifest.get("template_disclaimer", ""))
	return d if d != "" else REQUIRED_DISCLAIMER


func list_docs() -> Array:
	var docs: Variant = manifest.get("documents", [])
	if not (docs is Array):
		return []
	var out: Array = []
	for item in docs:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	return out


func doc_count() -> int:
	return list_docs().size()


func find_doc(doc_id: String) -> Dictionary:
	if _docs_by_id.has(doc_id):
		return (_docs_by_id[doc_id] as Dictionary).duplicate(true)
	return {}


func has_doc(doc_id: String) -> bool:
	return _docs_by_id.has(doc_id)


func read_doc_text(doc_id: String) -> String:
	if _text_cache.has(doc_id):
		return str(_text_cache[doc_id])
	var meta: Dictionary = find_doc(doc_id)
	if meta.is_empty():
		return ""
	var fname: String = str(meta.get("file", ""))
	if not is_safe_rel_filename(fname):
		return ""
	var fpath: String = base_dir.path_join(fname)
	var txt: String = ""
	if FileAccess.file_exists(fpath):
		txt = FileAccess.get_file_as_string(fpath).replace("\r\n", "\n")
	elif _bundle_docs.has(doc_id):
		txt = str(_bundle_docs[doc_id]).replace("\r\n", "\n")
	else:
		return ""
	_text_cache[doc_id] = txt
	return txt


func doc_hash_short(doc_id: String) -> String:
	var txt: String = read_doc_text(doc_id)
	if txt == "":
		return ""
	return txt.sha256_text().substr(0, 16)


func unfilled_placeholder_docs() -> Array:
	var out: Array = []
	for d in list_docs():
		var did: String = str(d.get("id", ""))
		if did != "" and read_doc_text(did).contains(PLACEHOLDER_MARKER):
			out.append(did)
	return out


func has_unfilled_placeholders() -> bool:
	return not unfilled_placeholder_docs().is_empty()


func can_enable_real_payments() -> Dictionary:
	if not is_valid():
		return {"ok": false, "code": "DENY_BUNDLE_INVALID", "errors": validation_errors()}
	if not real_payments_enabled():
		return {"ok": false, "code": "DENY_PAYMENTS_DISABLED"}
	var unfilled: Array = unfilled_placeholder_docs()
	if not unfilled.is_empty():
		return {"ok": false, "code": "DENY_UNFILLED_PLACEHOLDERS", "docs": unfilled}
	return {"ok": true, "code": "OK"}


func validate_bundle() -> Array:
	var errors: Array = []
	if not is_loaded():
		errors.append("bundle_not_loaded:" + _last_error)
		_validation_errors = errors.duplicate()
		return errors
	var docs: Array = list_docs()
	if docs.size() != EXPECTED_DOC_COUNT:
		errors.append("doc_count:%d!=%d" % [docs.size(), EXPECTED_DOC_COUNT])
	if offer_version() == "":
		errors.append("offer_ver_empty")
	var payments_on: bool = real_payments_enabled()
	var seen_ids: Dictionary = {}
	var seen_files: Dictionary = {}
	for d in docs:
		var did: String = str(d.get("id", ""))
		var fname: String = str(d.get("file", ""))
		var title: String = str(d.get("title", ""))
		var ver: String = str(d.get("version", ""))
		var want_sha: String = str(d.get("sha256", ""))
		if did == "" or seen_ids.has(did):
			errors.append("bad_or_dup_id:" + did)
		seen_ids[did] = true
		if fname == "" or seen_files.has(fname):
			errors.append("bad_or_dup_file:" + fname)
		seen_files[fname] = true
		if not is_safe_rel_filename(fname):
			errors.append("unsafe_file_path:" + fname)
		if title.strip_edges() == "":
			errors.append("empty_title:" + did)
		if ver.strip_edges() == "":
			errors.append("empty_version:" + did)
		var txt: String = read_doc_text(did)
		if txt.strip_edges() == "":
			errors.append("missing_or_empty_text:" + did)
			continue
		if not txt.contains(REQUIRED_DISCLAIMER):
			errors.append("missing_template_disclaimer:" + did)
		if want_sha != "":
			var got_sha: String = txt.sha256_text()
			if got_sha != want_sha:
				errors.append("sha256_mismatch:" + did)
		if REFUND_DOC_IDS.has(did) or bool(d.get("has_refund_clause", false)):
			if not txt.contains(REQUIRED_REFUND_CLAUSE):
				errors.append("missing_refund_clause:" + did)
		if payments_on and txt.contains(PLACEHOLDER_MARKER):
			errors.append("unfilled_placeholders_with_payments_enabled:" + did)
	for rid in REFUND_DOC_IDS:
		if not seen_ids.has(rid):
			errors.append("missing_refund_doc:" + rid)
	for cid in REQUIRED_CONSENT_IDS:
		if not seen_ids.has(cid):
			errors.append("missing_required_consent_doc:" + cid)
	_validation_errors = errors.duplicate()
	return errors
