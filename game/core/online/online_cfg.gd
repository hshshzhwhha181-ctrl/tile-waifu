class_name V10OnlineCfg
extends RefCounted

# V10OnlineCfg — 0.12.0 «Онлайн»: where the game server lives and who we are on it.
# Everything persists in G.S["v10_online"] (the token never goes into the cloud save itself, see cloud_payload()).
#
#   V10OnlineCfg.url() / set_url(u)        REST base, default http://127.0.0.1:8787 (switchable in the account screen)
#   V10OnlineCfg.ws_url()                  ws(s)://host/ws?token=…
#   V10OnlineCfg.token() / set_session(token, user) / clear_session()
#   V10OnlineCfg.user() / nick() / elo() / is_linked(provider)
#   V10OnlineCfg.cloud_payload(S) / apply_cloud(S, save)   strip / keep the local-only online block

const KEY: = "v10_online"
const DEFAULT_URL: = "http://127.0.0.1:8787"
const VERSION: = "0.12.0"
const PROVIDERS: = ["yandex", "google", "vk", "telegram"]
const PROVIDER_TITLES: = {"yandex": "Яндекс ID", "google": "Google", "vk": "VK ID", "telegram": "Telegram"}
const HEROES: = ["mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"]
const LOCAL_KEYS: = ["v10_online"]

# a dictionary used when G (autoload) is not there (pure unit tests)
static var _fallback: = {}


static func defaults() -> Dictionary:
	return {
		"url": DEFAULT_URL,
		"token": "",
		"user": {},
		"save_version": 0,
		"last_sync": 0,
		"local_elo": 1000,
		"local_wins": 0,
		"local_losses": 0,
		"last_status": "unknown",
	}


static func _S() -> Dictionary:
	var g: = Engine.get_main_loop() as SceneTree
	if g != null and g.root != null and g.root.has_node("G"):
		var gn: Node = g.root.get_node("G")
		var s: Variant = gn.get("S")
		if s is Dictionary:
			return s
	return _fallback


static func ensure(S = null) -> Dictionary:
	var src: Dictionary = S if S is Dictionary else _S()
	if not (src.get(KEY) is Dictionary):
		src[KEY] = defaults()
	var st: Dictionary = src[KEY]
	var d: = defaults()
	for k in d:
		if not st.has(k):
			st[k] = d[k]
	if String(st.url).strip_edges() == "":
		st.url = DEFAULT_URL
	if not (st.user is Dictionary):
		st.user = {}
	return st


static func st() -> Dictionary:
	return ensure()


static func persist() -> void:
	var g: = Engine.get_main_loop() as SceneTree
	if g != null and g.root != null and g.root.has_node("G"):
		var gn: Node = g.root.get_node("G")
		if gn.has_method("save"):
			gn.call("save")


static func normalize_url(u: String) -> String:
	var s: = u.strip_edges()
	if s == "":
		return DEFAULT_URL
	if not (s.begins_with("http://") or s.begins_with("https://")):
		s = "http://" + s
	while s.ends_with("/"):
		s = s.substr(0, s.length() - 1)
	return s


static func url() -> String:
	return normalize_url(String(st().url))


static func set_url(u: String) -> void:
	st().url = normalize_url(u)
	persist()


static func ws_url(tok: = "") -> String:
	var base: = url()
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	var t: = tok if tok != "" else token()
	return base + "/ws?token=" + t.uri_encode()


static func token() -> String:
	return String(st().token)


static func has_session() -> bool:
	return token() != ""


static func set_session(tok: String, u: Dictionary) -> void:
	var s: = st()
	s.token = tok
	if not u.is_empty():
		s.user = u.duplicate(true)
	persist()


static func set_user(u: Dictionary) -> void:
	if u.is_empty():
		return
	st().user = u.duplicate(true)
	persist()


static func clear_session() -> void:
	var s: = st()
	s.token = ""
	s.user = {}
	s.save_version = 0
	persist()


static func user() -> Dictionary:
	return st().user


static func nick() -> String:
	var n: = String(user().get("nick", "")).strip_edges()
	if n != "":
		return n
	var s: = _S()
	if s.get("profile") is Dictionary:
		var pn: = String((s.profile as Dictionary).get("nick", "")).strip_edges()
		if pn != "":
			return pn
	var g: = Engine.get_main_loop() as SceneTree
	if g != null and g.root != null and g.root.has_node("G"):
		var gn: Node = g.root.get_node("G")
		if gn.has_method("nick"):
			var gn_nick: = String(gn.call("nick")).strip_edges()
			if gn_nick != "" and gn_nick != "Гость":
				return gn_nick
	var fn: = String(s.get("nick", s.get("name", ""))).strip_edges()
	return fn if fn != "" else "Игрок"


static func valid_avatar(id: String, fallback: = "mc") -> String:
	return id if id in HEROES else fallback


static func avatar() -> String:
	var a: = String(user().get("avatar", ""))
	if a in HEROES:
		return a
	var s: = _S()
	var pa: = ""
	if s.get("profile") is Dictionary:
		pa = String((s.profile as Dictionary).get("avatar", ""))
	if pa in HEROES and pa != "mc":
		return pa
	var p: = String(s.get("partner", ""))
	if p in HEROES:
		return p
	return pa if pa in HEROES else "mc"


static func elo() -> int:
	var u: = user()
	if u.has("pvp_elo"):
		return int(u.pvp_elo)
	return int(st().local_elo)


static func wins() -> int:
	var u: = user()
	return int(u.get("wins", st().local_wins))


static func losses() -> int:
	var u: = user()
	return int(u.get("losses", st().local_losses))


static func providers() -> Array:
	var p: Variant = user().get("providers", [])
	return p if p is Array else []


static func is_linked(provider: String) -> bool:
	return provider in providers()


static func is_guest() -> bool:
	return bool(user().get("guest", true))


static func title_of(provider: String) -> String:
	return String(PROVIDER_TITLES.get(provider, provider))


# offline sparring result: the local rating moves like the server one (K = 16 against a bot)
static func apply_local_result(won: bool, opp_elo: int) -> Dictionary:
	var s: = st()
	var before: = int(s.local_elo)
	var after: = before + elo_delta(before, opp_elo, won, 16)
	s.local_elo = after
	if won:
		s.local_wins = int(s.local_wins) + 1
	else:
		s.local_losses = int(s.local_losses) + 1
	persist()
	return {"elo_before": before, "elo_after": after, "elo_delta": after - before}


static func elo_delta(ra: int, rb: int, won: bool, k: = 32) -> int:
	var expected: = 1.0 / (1.0 + pow(10.0, float(rb - ra) / 400.0))
	return int(round(float(k) * ((1.0 if won else 0.0) - expected)))


# the save that goes to the cloud: everything except the device-local online block (token, server url)
static func cloud_payload(S: Dictionary) -> Dictionary:
	var out: = {}
	for k in S:
		if String(k) in LOCAL_KEYS:
			continue
		out[k] = S[k]
	return out.duplicate(true)


# replace the local save with a cloud one, keeping the device-local online block
static func apply_cloud(S: Dictionary, save: Dictionary) -> void:
	var keep: = {}
	for k in LOCAL_KEYS:
		if S.has(k):
			keep[k] = S[k]
	for k in S.keys():
		if not (String(k) in LOCAL_KEYS):
			S.erase(k)
	for k in save:
		if String(k) in LOCAL_KEYS:
			continue
		S[k] = save[k]
	for k in keep:
		S[k] = keep[k]
