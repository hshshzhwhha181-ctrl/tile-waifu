extends Control

# ONLINE_SELFTEST — 0.12.0 online layer: config, PvP protocol serialisation, offline fallback (no server must never
# hang the game), local sparring bot, and both screens built on 20:9 (720×1600) and 9:16 (720×1280) without overlaps.
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/online/online_selftest.tscn
#   (windowed) … online_selftest.tscn --resolution 450x1000 -- --online_shots=<dir>   → account / pvp lobby / match PNGs
#   … -- --online_live=http://127.0.0.1:8787   also runs the REST/WS checks against a live server

var ok: = 0
var total: = 0
var fails: Array = []
var shots_dir: = ""
var live_url: = ""


func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--online_shots="):
			shots_dir = a.substr(15)
		elif a.begins_with("--online_live="):
			live_url = a.substr(14)
	await get_tree().process_frame
	var keep_url: = V10OnlineCfg.url()
	_cfg_tests()
	_protocol_tests()
	_bot_tests()
	await _offline_tests()
	await _screen_tests(Vector2(720, 1600))
	await _screen_tests(Vector2(720, 1280))
	await _pvp_match_tests()
	if live_url != "":
		await _live_tests()
	if shots_dir != "":
		await _shots()
	V10OnlineCfg.st().url = keep_url
	print("ONLINE_SELFTEST %d/%d %s" % [ok, total, "PASS" if ok == total else "FAIL"])
	get_tree().quit(0 if ok == total else 1)


func _cfg_tests() -> void:
	var S: = {}
	var st: = V10OnlineCfg.ensure(S)
	_check(String(st.url) == V10OnlineCfg.DEFAULT_URL, "default url 127.0.0.1:8787")
	_check(V10OnlineCfg.normalize_url("example.com/") == "http://example.com", "normalize adds scheme, strips slash")
	_check(V10OnlineCfg.normalize_url("") == V10OnlineCfg.DEFAULT_URL, "empty url -> default")
	var cur: = V10OnlineCfg.url()
	V10OnlineCfg.st().url = "https://tw.example.ru"
	_check(V10OnlineCfg.ws_url("abc").begins_with("wss://tw.example.ru/ws?token=abc"), "https -> wss ws_url")
	V10OnlineCfg.st().url = "http://10.0.0.2:8787"
	_check(V10OnlineCfg.ws_url("t").begins_with("ws://10.0.0.2:8787/ws?token=t"), "http -> ws ws_url")
	V10OnlineCfg.st().url = cur
	var S2: = {"coins": 5, "v10_online": {"token": "secret"}}
	var pl: = V10OnlineCfg.cloud_payload(S2)
	_check(not pl.has("v10_online") and int(pl.coins) == 5, "cloud payload strips local online block (token)")
	V10OnlineCfg.apply_cloud(S2, {"coins": 99, "gems": 3, "v10_online": {"token": "evil"}})
	_check(int(S2.coins) == 99 and int(S2.gems) == 3 and String(S2.v10_online.token) == "secret", "apply_cloud keeps local token")
	_check(V10OnlineCfg.elo_delta(1000, 1000, true) == 16 and V10OnlineCfg.elo_delta(1000, 1000, false) == -16, "ELO K32 even match ±16")
	_check(V10OnlineCfg.elo_delta(1200, 1000, true) < 16, "favourite gains less")
	_check(V10OnlineCfg.PROVIDERS.size() == 4 and "telegram" in V10OnlineCfg.PROVIDERS, "4 providers")


func _protocol_tests() -> void:
	var msgs: = [
		["matchmake_join", {}], ["room_create", {}], ["room_join", {"code": "123456"}],
		["progress", {"tiles_left": 40, "tiles_total": 72, "score": 900, "combo": 3}],
		["sabotage", {"kind": "ice"}], ["emote", {"id": "heart"}],
		["match_finish", {"cleared": true, "tiles_left": 0, "score": 4200}],
	]
	for m in msgs:
		var s: = V10Online.encode(m[0], m[1])
		var d: = V10Online.decode(s)
		var same: bool = String(d.get("t", "")) == m[0]
		for k in (m[1] as Dictionary):
			var a: Variant = d.get(k)
			var b: Variant = m[1][k]
			if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
				same = same and absf(float(a) - float(b)) < 0.0001
			else:
				same = same and str(a) == str(b)
		_check(same, "protocol roundtrip " + String(m[0]))
	_check(V10Online.decode("not json").is_empty() and V10Online.decode("{\"a\":1}").is_empty(), "decode rejects garbage / no type")
	_check(V10Online.valid_room_code("004213") and not V10Online.valid_room_code("12345") and not V10Online.valid_room_code("12a456"), "room code = 6 digits")
	var bc: = V10Online.board_cfg(77)
	_check(int(bc.seed) == 77 and int(bc.cols) >= 5, "board cfg carries seed")
	_check(V10Online.rand_state().length() == 24, "oauth state nonce")


class _Sink:
	extends RefCounted
	var got: Array = []
	func dispatch(d: Dictionary) -> void:
		got.append(d)
	func types() -> Array:
		return got.map(func(x): return String(x.t))


func _bot_tests() -> void:
	var sink: = _Sink.new()
	var b: = V10OnlineBot.new(sink)
	b.handle({"t": "matchmake_join"})
	_check("queued" in sink.types(), "bot: queued")
	for i in 40:
		b.tick(0.1)
	_check("match_start" in sink.types(), "bot: match_start after short queue")
	var ms: Dictionary = sink.got.filter(func(x): return String(x.t) == "match_start")[0]
	_check(bool(ms.opponent.bot) and int(ms.seed) > 0 and ms.board_cfg is Dictionary, "bot match_start shape")
	b.handle({"t": "progress", "tiles_left": 70, "tiles_total": 72, "score": 0, "combo": 0})
	for i in 300:
		b.tick(0.1)
	_check("opponent_progress" in sink.types(), "bot sends opponent_progress")
	var before: = V10OnlineCfg.elo()
	b.handle({"t": "match_finish", "cleared": true, "tiles_left": 0, "score": 5000})
	var ends: Array = sink.got.filter(func(x): return String(x.t) == "match_end")
	_check(ends.size() == 1 and bool(ends[0].you_won) and int(ends[0].elo_delta) > 0, "bot match_end: win gives +ELO")
	_check(V10OnlineCfg.elo() >= before or V10OnlineCfg.has_session(), "local ELO stored")
	var b2: = V10OnlineBot.new(sink)
	b2.handle({"t": "room_join", "code": "12"})
	_check(String(sink.got[-1].t) == "error", "bot: bad room code -> error")


func _offline_tests() -> void:
	var keep: = V10OnlineCfg.url()
	var keep_tok: = V10OnlineCfg.token()
	V10OnlineCfg.st().url = "http://127.0.0.1:9"
	var net: = V10Online.new()
	add_child(net)
	var t0: = Time.get_ticks_msec()
	var h: = await net.check_health()
	var dt: = Time.get_ticks_msec() - t0
	_check(not bool(h.ok) and bool(h.get("offline", false)), "dead server -> offline result")
	_check(dt < 5000, "offline answer within the 4 s timeout (%d ms)" % dt)
	_check(not net.online, "net.online false")
	var s: = await net.cloud_push()
	_check(not bool(s.ok), "cloud push offline fails gracefully")
	var l: = await net.link_provider("yandex")
	_check(not bool(l.ok) and bool(l.get("offline", false)), "link provider offline fails gracefully")
	# PvP with no server: WS falls back to the local sparring bot
	V10OnlineCfg.st().token = "dead-token"
	net.pvp_connect()
	var got: = {"m": false}
	net.match_found.connect(func(_d): got.m = true)
	net.matchmake_join()
	var t1: = Time.get_ticks_msec()
	while not got.m and Time.get_ticks_msec() - t1 < 9000:
		await get_tree().process_frame
	_check(got.m and net.is_local(), "WS unreachable -> local bot match found")
	net.pvp_close()
	net.queue_free()
	V10OnlineCfg.st().token = keep_tok
	V10OnlineCfg.st().url = keep


func _host(vs: Vector2) -> Control:
	var host: = Control.new()
	host.size = vs
	add_child(host)
	return host


func _labels_inside(root: Control, area: Rect2) -> Array:
	var bad: = []
	var stack: Array = [[root, false]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		var in_scroll: bool = e[1] or n is ScrollContainer
		for c in n.get_children():
			stack.append([c, in_scroll])
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text != "":
			var r: = (n as Label).get_global_rect()
			var out_x: = r.position.x < area.position.x - 1 or r.end.x > area.end.x + 1
			var out_y: = r.position.y < area.position.y - 1 or r.end.y > area.end.y + 1
			if out_x or (out_y and not in_scroll):
				bad.append("%s@%s" % [(n as Label).text, str(r)])
	return bad


func _screen_tests(vs: Vector2) -> void:
	var tag: = "%dx%d" % [vs.x, vs.y]
	V10OnlineCfg.st().url = "http://127.0.0.1:9"
	var h1: = _host(vs)
	var acc: = Control.new()
	acc.set_script(load("res://scripts/v10/online/account_screen.gd"))
	acc.size = vs
	h1.add_child(acc)
	acc.call("build", null, {})
	for i in 10:
		await get_tree().process_frame
	_check(acc.get_child_count() > 5, "account screen builds " + tag)
	var pb: Dictionary = acc.get("provider_buttons")
	_check(pb.size() == 4, "account: 4 provider buttons " + tag)
	var rects: = []
	for k in pb:
		rects.append((pb[k] as Control).get_global_rect())
	var overlap: = false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlap = true
	_check(not overlap, "account: provider buttons do not overlap " + tag)
	var bad: = _labels_inside(acc, Rect2(Vector2.ZERO, vs))
	_check(bad.is_empty(), "account: all labels inside the screen %s %s" % [tag, str(bad)])
	await get_tree().create_timer(4.6).timeout
	_check(not bool(acc.call("busy")), "account: offline boot never hangs " + tag)
	h1.queue_free()
	var h2: = _host(vs)
	var pvp: = V10PvpOnlineScreen.new()
	pvp.size = vs
	h2.add_child(pvp)
	pvp.build(null, {"no_net": true})
	await get_tree().process_frame
	_check(pvp.tab_btns.size() == 3 and pvp.phase == "lobby", "pvp lobby with 3 tabs " + tag)
	for t in 3:
		pvp.select_tab(t)
		await get_tree().process_frame
		await get_tree().process_frame
		var b2: = _labels_inside(pvp, Rect2(Vector2.ZERO, vs))
		_check(b2.is_empty(), "pvp tab %d labels inside %s %s" % [t, tag, str(b2)])
	h2.queue_free()
	await get_tree().process_frame


func _pvp_match_tests() -> void:
	var vs: = Vector2(720, 1600)
	var h: = _host(vs)
	var pvp: = V10PvpOnlineScreen.new()
	pvp.size = vs
	h.add_child(pvp)
	pvp.build(null, {"no_net": true})
	await get_tree().process_frame
	pvp.start_local_match()
	for i in 6:
		await get_tree().process_frame
	_check(pvp.phase == "match" and pvp.board != null and pvp.tiles_left() > 0, "local match starts with a board")
	_check(pvp.tiles_total % 2 == 0, "board has even tiles")
	var b3: = _labels_inside(pvp, Rect2(Vector2.ZERO, vs))
	_check(b3.is_empty(), "match HUD labels inside 20:9 %s" % str(b3))
	_check(not pvp.use_sabotage("ice"), "sabotage locked without charge")
	pvp.charge = V10PvpOnlineScreen.CHARGE_PAIRS
	_check(pvp.use_sabotage("fog") and pvp.charge == 0, "charged sabotage fires")
	pvp.apply_sabotage("ice")
	_check(V10AdventureVfx.active_debuff_count(pvp.board) > 0, "incoming ice freezes tiles")
	pvp._on_emote("laugh")
	_check(pvp.emotes_seen == 1, "emote received")
	pvp._on_opp_progress({"tiles_left": 10, "score": 3000, "combo": 4})
	_check(pvp.opp_left == 10, "opponent progress applied")
	pvp.surrender()
	for i in 4:
		await get_tree().process_frame
	_check(pvp.phase == "result" and not bool(pvp.last_result.get("you_won", true)), "surrender -> result (loss)")
	_check(pvp.result_root != null and is_instance_valid(pvp.result_root), "result panel shown")
	h.queue_free()
	await get_tree().process_frame


func _live_tests() -> void:
	var keep: = V10OnlineCfg.url()
	V10OnlineCfg.st().url = live_url
	V10OnlineCfg.clear_session()
	var net: = V10Online.new()
	add_child(net)
	var h: = await net.check_health()
	_check(bool(h.get("ok", false)) and String(h.get("version", "")) == "0.12.0", "live: health 0.12.0")
	var g: = await net.ensure_session()
	_check(bool(g.get("ok", false)) and V10OnlineCfg.has_session(), "live: guest session")
	for p in V10OnlineCfg.PROVIDERS:
		var r: = await net.link_provider(p)
		_check(bool(r.get("ok", false)), "live: link " + p)
	_check(V10OnlineCfg.providers().size() == 4, "live: 4 providers linked")
	var pu: = await net.cloud_push(true)
	_check(bool(pu.get("ok", false)), "live: cloud push")
	var pl: = await net.cloud_pull()
	_check(bool(pl.get("ok", false)), "live: cloud pull")
	var lb: = await net.leaderboard("pvp")
	_check(bool(lb.get("ok", false)), "live: leaderboard")
	net.pvp_connect()
	var got: = {"m": false}
	net.match_found.connect(func(_d): got.m = true)
	net.matchmake_join()
	var t1: = Time.get_ticks_msec()
	while not got.m and Time.get_ticks_msec() - t1 < 10000:
		await get_tree().process_frame
	_check(got.m and net.mode == "ws", "live: WS matchmaking -> server bot match")
	net.pvp_close()
	net.queue_free()
	V10OnlineCfg.st().url = keep


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var p: = shots_dir.path_join(name + ".png")
	img.save_png(p)
	print("SHOT ", p)


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var vs: = get_viewport_rect().size
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	var h1: = _host(vs)
	var acc: = Control.new()
	acc.set_script(load("res://scripts/v10/online/account_screen.gd"))
	acc.size = vs
	h1.add_child(acc)
	acc.call("build", null, {})
	await get_tree().create_timer(2.5).timeout
	await _snap("online_account")
	h1.queue_free()
	var h2: = _host(vs)
	var pvp: = V10PvpOnlineScreen.new()
	pvp.size = vs
	h2.add_child(pvp)
	pvp.build(null, {})
	await get_tree().create_timer(2.0).timeout
	await _snap("online_pvp_lobby")
	pvp.select_tab(1)
	await get_tree().create_timer(0.6).timeout
	await _snap("online_pvp_room")
	pvp.select_tab(2)
	await get_tree().create_timer(2.0).timeout
	await _snap("online_pvp_top")
	pvp.select_tab(0)
	pvp.start_matchmaking()
	await get_tree().create_timer(0.8).timeout
	await _snap("online_pvp_search")
	var t0: = Time.get_ticks_msec()
	while pvp.phase != "match" and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	pvp.charge = 4
	pvp._refresh_match_hud()
	pvp._on_emote("cool")
	await get_tree().create_timer(0.4).timeout
	await _snap("online_pvp_match")
	pvp.surrender()
	await get_tree().create_timer(1.5).timeout
	await _snap("online_pvp_result")
	h2.queue_free()
