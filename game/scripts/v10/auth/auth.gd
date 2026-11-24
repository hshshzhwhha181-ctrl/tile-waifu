class_name V10Auth
extends RefCounted

# V10Auth — sign-in, sessions and the player's account record (0.10 lane «auth», README.md next to this file).
#
# Three places hold the identity, on purpose (so no single damaged file can cost progress):
#   G.S.v10_auth                  account record inside the main save (see defaults()); progress lives in G.S anyway
#   user://v10_session.json       the current session: provider + token + expiry + integrity hash. Disposable:
#                                 missing / damaged / expired → silent fall back to a guest session of the SAME player
#   user://v10_device.json        install id (random, rotated by account deletion). Never personal data.
#   user://v10_auth_outbox.json   requests for the future server (account deletion) — sent when the server exists
#
# Boot (see V10AuthFlow): needs_login() ? login screen : await restore()  → welcome toast.
# Every public call is safe headless and idempotent.

const SAVE_KEY: = "v10_auth"
const VER: = 1
const DOC_VER: = "2026-11"           # version of the terms / privacy texts the consent refers to
const GUEST_DAYS: = 365              # guest session: sliding, refreshed on every launch
const PROVIDER_DAYS: = 30            # provider session (stub until the server issues real tokens)
const DAY: = 86400
const SALT: = "tw-auth-v1-5f2c9e"
const ID_ALPHABET: = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford base32: no I, L, O, U

# which sign-in buttons each build flavor shows (guest is always there; yagames signs in by itself)
const FLAVOR_BUTTONS: = {
	"rustore": ["vkid", "yandex"],
	"gplay": ["google"],
	"yagames": [],
	"dev": ["vkid", "yandex", "google"],
}

static var root: = "user://"          # tests point this at user://auth_test/
static var now_override: = -1         # tests: fixed clock
static var flavor_override: = ""      # tests / dev: --flavor=<id>
static var age_gate_override: Variant = null   # tests: a script with static ensure(host)
static var last_boot: = {}            # result of the last restore(), for the UI
static var _install: = ""
static var _providers: = {}
static var _globals: = {}


# ── clock / globals ──────────────────────────────────────────────────────────────────────────────────────────

static func now() -> int:
	if now_override >= 0:
		return now_override
	# 0.10 contract §2.5: one time source. V10Meta (meta lane) owns it; until it is merged, the system clock.
	var meta = _global("V10Meta")
	if meta != null and _has_static(meta, "now_unix"):
		return int(meta.call("now_unix"))
	return int(Time.get_unix_time_from_system())


static func _global(cname: String) -> Variant:
	if _globals.has(cname):
		return _globals[cname]
	var scr = null
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == cname:
			scr = load(str(c.path))
			break
	_globals[cname] = scr
	return scr


static func _has_static(scr, method: String) -> bool:
	if scr == null or not (scr is Script):
		return false
	for m in (scr as Script).get_script_method_list():
		if str(m.get("name", "")) == method:
			return true
	return false


static func set_root(dir: String) -> void :
	root = dir if dir.ends_with("/") else dir + "/"
	_install = ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))


# ── save record ──────────────────────────────────────────────────────────────────────────────────────────────

static func defaults() -> Dictionary:
	return {
		"ver": VER,
		"player_id": "",            # TW-XXXX-XXXX-XXXX-XXXX, minted once, survives provider changes
		"provider": "",             # current sign-in method ("" = never signed in)
		"linked": {},               # provider id -> {"sub", "name", "at"}
		"created_at": 0,
		"last_login": 0,
		"login_count": 0,
		"onboarded": false,         # passed the login screen (or was migrated silently)
		"logged_out": false,        # «Выйти» in settings → login screen on next boot
		"consent": {"pd152": false, "at": 0, "doc": ""},
		"deletion": {},             # {"requested_at", "player_id"} after «Удалить аккаунт»
		"migrated_from": "",        # "0.9" when an old save got its account silently
	}


# idempotent: creates / repairs G.S.v10_auth (wrong types → defaults, JSON floats → ints). Returns the record.
static func ensure(S = null) -> Dictionary:
	if S == null:
		S = G.S
	var st = S.get(SAVE_KEY)
	if not (st is Dictionary):
		st = {}
		S[SAVE_KEY] = st
	var d: = defaults()
	for k in d:
		var v = d[k]
		if not st.has(k):
			st[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
		elif typeof(v) == TYPE_INT:
			var cur = st[k]
			st[k] = int(cur) if (cur is int or cur is float) else v
		elif typeof(st[k]) != typeof(v):
			st[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	var c: Dictionary = st.consent
	c.pd152 = bool(c.get("pd152", false))
	c.at = int(c.get("at", 0)) if (c.get("at") is int or c.get("at") is float) else 0
	c.doc = str(c.get("doc", ""))
	for pid in st.linked.keys():
		if not (st.linked[pid] is Dictionary):
			st.linked.erase(pid)
	if str(st.player_id) != "" and not valid_player_id(str(st.player_id)):
		st.player_id = ""
	st.ver = VER
	return st


static func state() -> Dictionary:
	return ensure()


static func player_id() -> String:
	return str(state().player_id)


static func current_provider() -> String:
	return str(state().provider)


static func is_guest() -> bool:
	return current_provider() in ["", "guest"]


static func is_legacy_player(S = null) -> bool:
	if S == null:
		S = G.S
	return bool(S.get("profile_done", false)) or bool(S.get("intro_done", false)) or int(S.get("unlocked", 1)) > 1


# ── ids ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func random_hex(nbytes: int) -> String:
	return Crypto.new().generate_random_bytes(nbytes).hex_encode()


static func new_player_id() -> String:
	var b: = Crypto.new().generate_random_bytes(16)
	var s: = ""
	for i in 16:
		s += ID_ALPHABET[b[i] & 31]
	return "TW-%s-%s-%s-%s" % [s.substr(0, 4), s.substr(4, 4), s.substr(8, 4), s.substr(12, 4)]


static func valid_player_id(pid: String) -> bool:
	if pid.length() != 22 or not pid.begins_with("TW-"):
		return false
	var parts: = pid.substr(3).split("-")
	if parts.size() != 4:
		return false
	for p in parts:
		if p.length() != 4:
			return false
		for ch in p:
			if not (ch in ID_ALPHABET):
				return false
	return true


static func install_id() -> String:
	if _install != "":
		return _install
	var d = _read_json(root + "v10_device.json")
	if d is Dictionary and str(d.get("install_id", "")).length() == 32:
		_install = str(d.install_id)
		return _install
	_install = random_hex(16)
	_write_json(root + "v10_device.json", {"install_id": _install, "created_at": now()})
	return _install


# ── flavor ───────────────────────────────────────────────────────────────────────────────────────────────────

static func flavor() -> String:
	if flavor_override != "":
		return flavor_override
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flavor="):
			var f: = a.substr(9)
			if FLAVOR_BUTTONS.has(f):
				return f
	if OS.has_feature("web") or OS.has_feature("yagames"):
		return "yagames"
	for f in ["rustore", "gplay"]:
		if OS.has_feature(f):
			return f
	var ps: = str(ProjectSettings.get_setting("tile_waifu/flavor", ""))
	if FLAVOR_BUTTONS.has(ps):
		return ps
	if OS.has_feature("android"):
		return "rustore"
	return "dev"


static func login_buttons(fl: = "") -> Array:
	return (FLAVOR_BUTTONS.get(fl if fl != "" else flavor(), []) as Array).duplicate()


static func provider(id: String) -> V10AuthProvider:
	if not _providers.has(id):
		var p: = V10AuthProviders.make(id)
		if p == null:
			return null
		_providers[id] = p
	return _providers[id]


# ── consent (152-ФЗ) ─────────────────────────────────────────────────────────────────────────────────────────

static func has_consent() -> bool:
	var c: Dictionary = state().consent
	return bool(c.pd152) and str(c.doc) == DOC_VER


static func set_consent(on: bool) -> void :
	var st: = state()
	st.consent = {"pd152": on, "at": now(), "doc": DOC_VER if on else ""}
	# withdrawing consent stops processing: provider accounts are unlinked, the player keeps playing as a guest
	if not on and not is_guest():
		for k in st.linked.keys():
			var p: = provider(str(k))
			if p:
				p.sign_out()
		st.linked = {}
		_guest_session(st)
	G.save()


# ── login screen decision ────────────────────────────────────────────────────────────────────────────────────

static func needs_login() -> bool:
	if flavor() == "yagames":
		return false
	var st: = state()
	if bool(st.logged_out):
		return true
	if bool(st.onboarded):
		return false
	return not is_legacy_player()


# ── sessions ─────────────────────────────────────────────────────────────────────────────────────────────────

static func _session_path() -> String:
	return root + "v10_session.json"


static func _sig(d: Dictionary) -> String:
	var src: = "%s|%s|%s|%s|%s|%d|%d" % [SALT, install_id(), str(d.get("player_id", "")), str(d.get("provider", "")),
		str(d.get("token", "")), int(d.get("issued_at", 0)), int(d.get("expires_at", 0))]
	return src.sha256_text().substr(0, 32)


# {} = no session; {"_corrupt": true} = unreadable / tampered / wrong install
static func read_session() -> Dictionary:
	var p: = _session_path()
	if not FileAccess.file_exists(p):
		return {}
	var d = _read_json(p)
	if not (d is Dictionary):
		return {"_corrupt": true}
	for k in ["player_id", "provider", "token", "issued_at", "expires_at", "sig"]:
		if not d.has(k):
			return {"_corrupt": true}
	d.issued_at = int(d.issued_at)
	d.expires_at = int(d.expires_at)
	if str(d.sig) != _sig(d) or not valid_player_id(str(d.player_id)):
		return {"_corrupt": true}
	return d


static func write_session(pid: String, prov: String, token: String, days: int) -> Dictionary:
	var t: = now()
	var d: = {"v": 1, "player_id": pid, "provider": prov, "token": token, "issued_at": t, "expires_at": t + days * DAY}
	d.sig = _sig(d)
	_write_json(_session_path(), d)
	return d


static func clear_session() -> void :
	var p: = _session_path()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func _mint(st: Dictionary) -> void :
	if str(st.player_id) == "":
		st.player_id = new_player_id()
		st.created_at = now()


static func _touch(st: Dictionary) -> void :
	st.last_login = now()
	st.login_count = int(st.login_count) + 1
	st.onboarded = true
	st.logged_out = false
	st.deletion = {}


static func _guest_session(st: Dictionary) -> void :
	_mint(st)
	st.provider = "guest"
	write_session(str(st.player_id), "guest", random_hex(16), GUEST_DAYS)


# «Играть как гость»: works offline, instantly. Re-entering as a guest after «Выйти» continues the same player.
static func sign_in_guest() -> Dictionary:
	var st: = state()
	_mint(st)
	_guest_session(st)
	_touch(st)
	G.save()
	return {"ok": true, "code": "ok", "player_id": st.player_id, "provider": "guest"}


# A provider button. Never loses progress: a failed sign-in changes nothing, a successful one is linked to the
# current player (or mints one). Result codes: see V10AuthProvider.
static func sign_in(id: String, ctx: = {}) -> Dictionary:
	var p: = provider(id)
	if p == null:
		return V10AuthProvider.fail("unknown")
	if id == "guest":
		return sign_in_guest()
	if p.needs_consent and not has_consent():
		return V10AuthProvider.fail("consent_required")
	var r: Dictionary = await p.sign_in(ctx)
	if not bool(r.get("ok", false)):
		return r
	_apply_account(id, r)
	return r


# «Привязать аккаунт» in the profile / account sheet: same as sign_in, keeps the player and the progress.
static func link(id: String) -> Dictionary:
	return await sign_in(id, {"link": true})


static func _apply_account(id: String, r: Dictionary) -> void :
	var st: = state()
	_mint(st)
	var acc: Dictionary = r.get("account", {})
	st.linked[id] = {"sub": str(acc.get("sub", "")), "name": str(acc.get("name", "")), "at": now()}
	st.provider = id
	var tok: = str(r.get("token", ""))
	var days: = maxi(1, int(r.get("expires_in", 0)) / DAY) if int(r.get("expires_in", 0)) > 0 else PROVIDER_DAYS
	write_session(str(st.player_id), id, tok if tok != "" else random_hex(16), days)
	_touch(st)
	G.save()


# Automatic sign-in on launch. Never shows UI and never loses progress. Result:
#   {"status": "ok" | "migrated" | "recovered" | "fallback", "provider": id, "toast": String ("" = only welcome)}
#   ok        session valid (guest sessions slide forward)
#   migrated  a 0.9 save without an account: a guest account was created silently
#   recovered the session file was missing or damaged: a new guest session for the same player
#   fallback  a provider session expired and could not be refreshed: guest session, linked accounts kept
static func restore() -> Dictionary:
	var st: = state()
	var sess: = read_session()
	var res: = {"status": "ok", "provider": "", "toast": ""}
	var was: = str(st.provider)
	if flavor() == "yagames" and str(st.provider) in ["", "guest", "yagames"]:
		# Yandex Games signs the player in itself; until the JS bridge is wired this stays a guest session
		var yg: = provider("yagames")
		var r: Dictionary = await yg.sign_in({"silent": true})
		if bool(r.get("ok", false)):
			_apply_account("yagames", r)
			res.provider = "yagames"
			last_boot = res
			return res
	if sess.has("_corrupt"):
		_guest_session(st)
		res.status = "recovered" if was in ["", "guest"] else "fallback"
		res.toast = V10AuthText.s("toast.restored") if res.status == "recovered" else V10AuthText.s("toast.expired", V10AuthText.provider_name(was))
	elif sess.is_empty():
		if str(st.player_id) == "" and not bool(st.onboarded):
			st.migrated_from = "0.9" if is_legacy_player() else ""
			res.status = "migrated"
		else:
			res.status = "recovered"
			if not (was in ["", "guest"]):
				res.status = "fallback"
				res.toast = V10AuthText.s("toast.expired", V10AuthText.provider_name(was))
		_guest_session(st)
	else:
		if str(st.player_id) == "":
			st.player_id = str(sess.player_id)
			if int(st.created_at) == 0:
				st.created_at = int(sess.issued_at)
		elif str(sess.player_id) != str(st.player_id):
			# the save was restored from a backup or replaced: the save's player wins, the session is re-issued
			_guest_session(st)
			res.status = "recovered"
		if res.status == "ok":
			var prov: = str(sess.provider)
			var expired: = now() >= int(sess.expires_at)
			if prov == "guest":
				_guest_session(st)
			else:
				var p: = provider(prov)
				var r: Dictionary = V10AuthProvider.fail("unknown")
				if p:
					r = await p.restore(sess)
				if bool(r.get("ok", false)):
					_apply_account(prov, r)
				elif expired or p == null:
					_guest_session(st)
					res.status = "fallback"
					res.toast = V10AuthText.s("toast.expired", V10AuthText.provider_name(prov))
				else:
					# offline / SDK not wired: the stored session stays valid until it expires
					st.provider = prov
	res.provider = str(st.provider)
	_touch(st)
	G.save()
	last_boot = res
	return res


# «Выйти»: the session is dropped, the progress stays in the save; the next boot shows the login screen.
static func sign_out() -> void :
	var st: = state()
	var p: = provider(str(st.provider)) if str(st.provider) != "" else null
	if p:
		p.sign_out()
	clear_session()
	st.logged_out = true
	G.save()


# «Удалить аккаунт» (RuStore / Google Play requirement: in-app deletion). Queues the server request, wipes the
# local progress (save, its backups, the session, the install id, 0.10 logs) and starts from a clean state.
static func request_deletion() -> Dictionary:
	var st: = state()
	var old: = str(st.player_id)
	var req: = {"type": "delete_account", "player_id": old, "provider": str(st.provider),
		"linked": st.linked.duplicate(true), "requested_at": now(), "install_id": install_id()}
	var ob = _read_json(root + "v10_auth_outbox.json")
	var q: Array = ob.get("queue", []) if ob is Dictionary and ob.get("queue") is Array else []
	q.append(req)
	_write_json(root + "v10_auth_outbox.json", {"queue": q})
	for k in st.linked.keys():
		var p: = provider(str(k))
		if p:
			p.sign_out()
	clear_session()
	_remove(root + "v10_device.json")
	_install = ""
	_wipe_dir(root + "v10_logs/")
	# the old progress must not survive in the save's backup: remove main, backup and temp before the fresh save
	var base: = G.save_path.get_basename()
	for f in [G.save_path, base + ".bak.json", base + ".tmp.json"]:
		_remove(f)
	G.S = G.default_state()
	var nst: = ensure()
	nst.deletion = {"requested_at": int(req.requested_at), "player_id": old}
	G.save()
	if G.has_signal("profile_changed"):
		G.profile_changed.emit()
	return {"ok": true, "player_id": old}


static func outbox() -> Array:
	var ob = _read_json(root + "v10_auth_outbox.json")
	return ob.get("queue", []) if ob is Dictionary and ob.get("queue") is Array else []


# ── age gate hook (owned by the shop lane: «Мне есть 18») ────────────────────────────────────────────────────

# Calls V10AgeGate.ensure(host) when that class exists (any lane may add it); no-op otherwise.
static func age_gate(host: Node) -> void :
	var gate = age_gate_override if age_gate_override != null else _global("V10AgeGate")
	if gate == null or not _has_static(gate, "ensure"):
		return
	await Callable(gate, "ensure").call(host)


# ── greeting ─────────────────────────────────────────────────────────────────────────────────────────────────

static func greet_hero() -> String:
	var h: = str(G.profile().get("avatar", G.S.get("partner", "mc")))
	return h if G.HEROES.has(h) else "mc"


static func welcome_text() -> String:
	return V10AuthText.greet(greet_hero(), G.nick())


# ── files ────────────────────────────────────────────────────────────────────────────────────────────────────

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt: = f.get_as_text()
	f.close()
	var j: = JSON.new()
	if j.parse(txt) != OK:
		return null
	return j.data


static func _write_json(path: String, d: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return G.write_atomic(path, JSON.stringify(d), false)


static func _remove(path: String) -> void :
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _wipe_dir(dir: String) -> void :
	var da: = DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
