class_name TWLegalData
extends RefCounted

# TWLegalData (P108 / MP PM21): loads and validates the 13 Russian legal template documents from data/legal/.
# Lookup order when no custom directory is injected:
#   1. res://data/legal/        (when packaged inside game/ for Android/APK export)
#   2. <repo_root>/data/legal/  (source-of-truth folder in dev / desktop / CI headless runs)
# Pure data loader: no scene-tree dependencies, no res://assets literals, no hardcoded prices/odds.

const EXPECTED_DOC_COUNT: int = 13
const MANIFEST_FILE: String = "manifest.json"
const REQUIRED_DISCLAIMER: String = "шаблон, не юридическая консультация, нужна проверка юристом"
const REQUIRED_REFUND_CLAUSE: String = "не возвращаются, за исключением случаев, предусмотренных законом и правилами магазина"
const REFUND_DOC_IDS: = ["offer", "gacha_rules", "refund_rules"]
const REQUIRED_CONSENT_IDS: = ["offer", "privacy", "pdn_consent", "age_18_full_tier"]

var base_dir: String = ""
var manifest: Dictionary = {}
var _docs_by_id: Dictionary = {}
var _text_cache: Dictionary = {}
var _last_error: String = ""


func _init(p_base_dir: String = "") -> void:
	base_dir = resolve_dir(p_base_dir)
	load_bundle(base_dir)


static func resolve_dir(override_dir: String = "") -> String:
	if override_dir != "":
		return override_dir.trim_suffix("/").trim_suffix("\\")
	if FileAccess.file_exists("res://data/legal/" + MANIFEST_FILE):
		return "res://data/legal"
	var res_abs: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var repo_legal: String = res_abs.get_base_dir().path_join("data/legal")
	if FileAccess.file_exists(repo_legal.path_join(MANIFEST_FILE)):
		return repo_legal
	return "res://data/legal"


func load_bundle(dir_path: String = "") -> bool:
	if dir_path != "":
		base_dir = dir_path.trim_suffix("/").trim_suffix("\\")
	manifest = {}
	_docs_by_id.clear()
	_text_cache.clear()
	_last_error = ""
	var mpath: String = base_dir.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(mpath):
		_last_error = "manifest_missing:" + mpath
		return false
	var raw: String = FileAccess.get_file_as_string(mpath)
	if raw.strip_edges() == "":
		_last_error = "manifest_empty"
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		_last_error = "manifest_bad_json"
		return false
	manifest = parsed as Dictionary
	var docs: Variant = manifest.get("documents", [])
	if docs is Array:
		for item in docs:
			if item is Dictionary:
				var did: String = str((item as Dictionary).get("id", ""))
				if did != "":
					_docs_by_id[did] = item
	return not _docs_by_id.is_empty()


func last_error() -> String:
	return _last_error


func is_loaded() -> bool:
	return not manifest.is_empty() and not _docs_by_id.is_empty()


func offer_version() -> String:
	return str(manifest.get("offer_ver", manifest.get("bundle_ver", "")))


func bundle_version() -> String:
	return str(manifest.get("bundle_ver", ""))


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
	if fname == "":
		return ""
	var fpath: String = base_dir.path_join(fname)
	if not FileAccess.file_exists(fpath):
		return ""
	var txt: String = FileAccess.get_file_as_string(fpath).replace("\r\n", "\n")
	_text_cache[doc_id] = txt
	return txt


func doc_hash_short(doc_id: String) -> String:
	var txt: String = read_doc_text(doc_id)
	if txt == "":
		return ""
	return txt.sha256_text().substr(0, 16)


func validate_bundle() -> Array:
	var errors: Array = []
	if not is_loaded():
		errors.append("bundle_not_loaded:" + _last_error)
		return errors
	var docs: Array = list_docs()
	if docs.size() != EXPECTED_DOC_COUNT:
		errors.append("doc_count:%d!=%d" % [docs.size(), EXPECTED_DOC_COUNT])
	if offer_version() == "":
		errors.append("offer_ver_empty")
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
	for rid in REFUND_DOC_IDS:
		if not seen_ids.has(rid):
			errors.append("missing_refund_doc:" + rid)
	for cid in REQUIRED_CONSENT_IDS:
		if not seen_ids.has(cid):
			errors.append("missing_required_consent_doc:" + cid)
	return errors
