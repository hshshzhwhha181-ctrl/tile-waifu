class_name V10Online
extends Node

# V10Online — 0.12.0 network layer (protocol: server/PROTOCOL.md).
# * REST: every call is `await net.request(...)`, an HTTPRequest with a 4 s timeout. A dead / missing server never
#   blocks the game: the call resolves with {ok:false, error:"offline", offline:true} and `online` turns false.
# * PvP: a WebSocketPeer polled in _process, or (no server) the local sparring bot V10OnlineBot that speaks the very
#   same messages, so the PvP screen has one code path. Signals carry the server message dictionaries as is.

signal connected
signal disconnected
signal status_changed(is_online: bool)
signal queued(d: Dictionary)
signal room_created(code: String)
signal match_found(d: Dictionary)
signal opponent_progress(d: Dictionary)
signal sabotage_received(kind: String)
signal emote_received(id: String)
signal match_ended(d: Dictionary)
signal net_error(code: String, msg: String)

const TIMEOUT: = 4.0
const EMOTES: = ["laugh", "angry", "heart", "cool"]
const SABOTAGE: = ["ice", "fog"]
const WS_CONNECT_TIMEOUT: = 4.0

var online: = false
var health: = {}
var mode: = ""            # "" | "ws" | "local"
var ws: WebSocketPeer = null
var ws_open: = false
var bot: V10OnlineBot = null
var _pending: Array = []
var _ws_wait: = 0.0
var _closing: = false


# ── protocol helpers (pure, unit-tested by ONLINE_SELFTEST) ─────────────────────────────────────────────────────

static func encode(t: String, fields: = {}) -> String:
	var d: = fields.duplicate(true)
	d["t"] = t
	return JSON.stringify(d)


static func decode(text: String) -> Dictionary:
	var j: = JSON.new()
	if j.parse(text) != OK:
		return {}
	var v: Variant = j.data
	if not (v is Dictionary) or not (v as Dictionary).has("t"):
		return {}
	return v


static func valid_room_code(code: String) -> bool:
	var c: = code.strip_edges()
	return c.length() == 6 and c.is_valid_int()


static func board_cfg(seed_v: int) -> Dictionary:
	return {"shape": "rect", "cols": 6, "rows": 6, "layers": 3, "fill": 0.66, "faces": 9, "gold": 2, "ice": 0, "seed": seed_v}


static func rand_state() -> String:
	var c: = Crypto.new()
	return c.generate_random_bytes(12).hex_encode()


static func _method_of(m: String) -> int:
	match m.to_upper():
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
	return HTTPClient.METHOD_GET


# ── REST ────────────────────────────────────────────────────────────────────────────────────────────────────────

func _set_online(v: bool) -> void:
	var changed: = v != online
	online = v
	V10OnlineCfg.st().last_status = "online" if v else "offline"
	if changed:
		status_changed.emit(v)


func request(method: String, path: String, body: Variant = null, auth: = true) -> Dictionary:
	if not is_inside_tree():
		return {"ok": false, "error": "offline", "offline": true}
	var http: = HTTPRequest.new()
	http.timeout = TIMEOUT
	http.use_threads = false
	add_child(http)
	var headers: = PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var tok: = V10OnlineCfg.token()
	if auth and tok != "":
		headers.append("Authorization: Bearer " + tok)
	var data: = "" if body == null else JSON.stringify(body)
	var err: = http.request(V10OnlineCfg.url() + path, headers, _method_of(method), data)
	if err != OK:
		http.queue_free()
		_set_online(false)
		return {"ok": false, "error": "offline", "offline": true}
	var res: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	var result: int = int(res[0])
	var code: int = int(res[1])
	var bytes: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_online(false)
		return {"ok": false, "error": "offline", "offline": true}
	_set_online(true)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "bad_json", "http": code}
	var d: Dictionary = parsed
	d["http"] = code
	if not d.has("ok"):
		d["ok"] = code >= 200 and code < 300
	return d


func _take_auth(r: Dictionary) -> Dictionary:
	if bool(r.get("ok", false)) and String(r.get("token", "")) != "":
		var u: Dictionary = r.get("user", {}) if r.get("user") is Dictionary else {}
		V10OnlineCfg.set_session(String(r.token), u)
	elif bool(r.get("ok", false)) and r.get("user") is Dictionary:
		V10OnlineCfg.set_user(r.user)
	return r


func check_health() -> Dictionary:
	var r: = await request("GET", "/api/v1/health", null, false)
	health = r if bool(r.get("ok", false)) else {}
	return r


func guest() -> Dictionary:
	var r: = await request("POST", "/api/v1/auth/guest", {"nick": V10OnlineCfg.nick(), "avatar": V10OnlineCfg.avatar()}, false)
	return _take_auth(r)


# a valid session: the stored token (refreshing /me) or a fresh guest account
func ensure_session() -> Dictionary:
	if V10OnlineCfg.has_session():
		var r: = await me()
		if bool(r.get("ok", false)):
			return r
		if bool(r.get("offline", false)):
			return r
		V10OnlineCfg.clear_session()
	return await guest()


func register(nick: String, email: String, password: String) -> Dictionary:
	var r: = await request("POST", "/api/v1/auth/register", {"nick": nick, "email": email, "password": password})
	return _take_auth(r)


func login(login_s: String, password: String) -> Dictionary:
	var r: = await request("POST", "/api/v1/auth/login", {"login": login_s, "password": password}, false)
	return _take_auth(r)


func logout() -> Dictionary:
	var r: = await request("POST", "/api/v1/auth/logout", {})
	V10OnlineCfg.clear_session()
	return r


func me() -> Dictionary:
	var r: = await request("GET", "/api/v1/me")
	return _take_auth(r)


func patch_me(fields: Dictionary) -> Dictionary:
	var r: = await request("PATCH", "/api/v1/me", fields)
	return _take_auth(r)


func oauth_sandbox(provider: String) -> Dictionary:
	var body: = {"provider": provider, "name": V10OnlineCfg.nick(), "avatar": V10OnlineCfg.avatar()}
	var r: = await request("POST", "/api/v1/auth/oauth/sandbox", body)
	return _take_auth(r)


func oauth_start_url(provider: String, state: String) -> String:
	var u: = "%s/auth/%s/start?state=%s" % [V10OnlineCfg.url(), provider, state.uri_encode()]
	if V10OnlineCfg.has_session():
		u += "&link=" + V10OnlineCfg.token().uri_encode()
	return u


func oauth_poll(state: String) -> Dictionary:
	var r: = await request("GET", "/api/v1/auth/poll?state=" + state.uri_encode(), null, false)
	return _take_auth(r)


func telegram_verify(fields: Dictionary) -> Dictionary:
	var r: = await request("POST", "/auth/telegram/verify", fields)
	return _take_auth(r)


# Яндекс / Google / VK / Telegram: one tap. A local server with the sandbox on links instantly; a real deployment opens
# the provider's consent page in the system browser and polls until the callback lands (up to `max_wait` s).
func link_provider(provider: String, max_wait: = 180.0) -> Dictionary:
	if health.is_empty():
		await check_health()
	if health.is_empty():
		return {"ok": false, "error": "offline", "offline": true}
	if not V10OnlineCfg.has_session():
		var g: = await guest()
		if not bool(g.get("ok", false)):
			return g
	var cfgd: Dictionary = health.get("oauth", {}) if health.get("oauth") is Dictionary else {}
	if bool(health.get("sandbox", false)) and not bool(cfgd.get(provider, false)):
		return await oauth_sandbox(provider)
	if provider == "telegram" and not bool(cfgd.get("telegram", false)):
		return {"ok": false, "error": "provider_not_configured"}
	var state: = rand_state()
	OS.shell_open(oauth_start_url(provider, state))
	var waited: = 0.0
	while waited < max_wait and is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		waited += 2.0
		var r: = await oauth_poll(state)
		if bool(r.get("ok", false)) and not bool(r.get("pending", false)):
			return r
		if bool(r.get("offline", false)):
			return r
	return {"ok": false, "error": "timeout"}


func cloud_push(force: = false) -> Dictionary:
	var S: Dictionary = V10OnlineCfg._S()
	var body: = {"save": V10OnlineCfg.cloud_payload(S), "version": int(V10OnlineCfg.st().save_version), "force": force}
	var r: = await request("PUT", "/api/v1/save", body)
	if bool(r.get("ok", false)):
		var st: = V10OnlineCfg.st()
		st.save_version = int(r.get("version", 0))
		st.last_sync = int(Time.get_unix_time_from_system())
		V10OnlineCfg.persist()
	return r


func cloud_pull() -> Dictionary:
	var r: = await request("GET", "/api/v1/save")
	if bool(r.get("ok", false)) and r.get("save") is Dictionary:
		var S: Dictionary = V10OnlineCfg._S()
		V10OnlineCfg.apply_cloud(S, r.save)
		var st: = V10OnlineCfg.ensure(S)
		st.save_version = int(r.get("version", 0))
		st.last_sync = int(Time.get_unix_time_from_system())
		V10OnlineCfg.persist()
		r["applied"] = true
	return r


func leaderboard(board: = "pvp", limit: = 50) -> Dictionary:
	return await request("GET", "/api/v1/leaderboard?board=%s&limit=%d" % [board, limit], null, V10OnlineCfg.has_session())


func raid_score(stage_idx: int, damage: int) -> Dictionary:
	return await request("POST", "/api/v1/raid/score", {"stage_idx": stage_idx, "damage": damage})


# ── PvP: WebSocket or local sparring bot ────────────────────────────────────────────────────────────────────────

func pvp_connect() -> void:
	pvp_close()
	_closing = false
	if not V10OnlineCfg.has_session():
		start_local()
		return
	mode = "ws"
	ws = WebSocketPeer.new()
	ws_open = false
	_ws_wait = 0.0
	var err: = ws.connect_to_url(V10OnlineCfg.ws_url())
	if err != OK:
		ws = null
		start_local()


func start_local() -> void:
	mode = "local"
	ws = null
	ws_open = false
	bot = V10OnlineBot.new(self)
	connected.emit()


func is_local() -> bool:
	return mode == "local"


func pvp_close() -> void:
	_closing = true
	if ws != null:
		ws.close(1000, "bye")
	ws = null
	ws_open = false
	bot = null
	mode = ""
	_pending.clear()


func send(t: String, fields: = {}) -> void:
	var d: = fields.duplicate(true)
	d["t"] = t
	if mode == "local":
		if bot != null:
			bot.handle(d)
		return
	if ws != null and ws_open:
		ws.send_text(JSON.stringify(d))
	else:
		_pending.append(d)


func matchmake_join() -> void:
	send("matchmake_join")


func matchmake_cancel() -> void:
	send("matchmake_cancel")


func room_create() -> void:
	send("room_create")


func room_join(code: String) -> void:
	send("room_join", {"code": code.strip_edges()})


func send_progress(tiles_left: int, tiles_total: int, score: int, combo: int) -> void:
	send("progress", {"tiles_left": tiles_left, "tiles_total": tiles_total, "score": score, "combo": combo})


func send_sabotage(kind: String) -> void:
	if kind in SABOTAGE:
		send("sabotage", {"kind": kind})


func send_emote(id: String) -> void:
	if id in EMOTES:
		send("emote", {"id": id})


func send_finish(cleared: bool, tiles_left: int, score: int) -> void:
	send("match_finish", {"cleared": cleared, "tiles_left": tiles_left, "score": score})


func leave() -> void:
	send("leave")


func dispatch(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"welcome":
			if d.get("user") is Dictionary:
				V10OnlineCfg.set_user(d.user)
		"queued":
			queued.emit(d)
		"queue_left":
			pass
		"room_created":
			room_created.emit(String(d.get("code", "")))
		"match_start":
			match_found.emit(d)
		"opponent_progress":
			opponent_progress.emit(d)
		"sabotage":
			sabotage_received.emit(String(d.get("kind", "ice")))
		"emote":
			emote_received.emit(String(d.get("id", "heart")))
		"match_end":
			if mode == "ws":
				var u: = V10OnlineCfg.user().duplicate()
				if not u.is_empty():
					u["pvp_elo"] = int(d.get("elo_after", u.get("pvp_elo", 1000)))
					if bool(d.get("you_won", false)):
						u["wins"] = int(u.get("wins", 0)) + 1
					else:
						u["losses"] = int(u.get("losses", 0)) + 1
					V10OnlineCfg.set_user(u)
			match_ended.emit(d)
		"error":
			net_error.emit(String(d.get("code", "error")), String(d.get("msg", "")))


func _process(delta: float) -> void:
	if mode == "local":
		if bot != null:
			bot.tick(delta)
		return
	if ws == null:
		return
	ws.poll()
	var stt: = ws.get_ready_state()
	if stt == WebSocketPeer.STATE_CONNECTING:
		_ws_wait += delta
		if _ws_wait > WS_CONNECT_TIMEOUT:
			_fallback_local("ws_timeout")
		return
	if stt == WebSocketPeer.STATE_OPEN:
		if not ws_open:
			ws_open = true
			_set_online(true)
			connected.emit()
			var q: = _pending.duplicate()
			_pending.clear()
			for m in q:
				ws.send_text(JSON.stringify(m))
		while ws != null and ws.get_available_packet_count() > 0:
			var d: = decode(ws.get_packet().get_string_from_utf8())
			if not d.is_empty():
				dispatch(d)
		return
	if stt == WebSocketPeer.STATE_CLOSED:
		var was_open: = ws_open
		ws = null
		ws_open = false
		if _closing:
			return
		if was_open:
			mode = ""
			disconnected.emit()
		else:
			_fallback_local("ws_failed")


# the server is not reachable: the same session continues against the local sparring bot
func _fallback_local(_why: String) -> void:
	var q: = _pending.duplicate()
	if ws != null:
		ws.close()
	_set_online(false)
	start_local()
	for m in q:
		bot.handle(m)
