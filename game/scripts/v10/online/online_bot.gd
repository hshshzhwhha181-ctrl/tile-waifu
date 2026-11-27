class_name V10OnlineBot
extends RefCounted

# V10OnlineBot — the offline sparring opponent. It answers the PvP messages exactly like the server's bot
# (server/PROTOCOL.md): queued → match_start → opponent_progress / sabotage / emote → match_end, so the PvP screen
# never knows whether a real server is there. Local results move the local rating (V10OnlineCfg.apply_local_result).

const NICKS: = ["Сакура-бот", "Лунная Лиса", "Тихий Дракон", "Нефритовая Тень", "Ветер Сакуры", "Алая Лилия"]
const AVATARS: = ["rin", "hana", "yue", "nova", "mc"]
const DURATION: = 180.0
const MIN_FINISH: = 45.0

var net = null
var phase: = "idle"       # idle | queue | room | match | over
var wait: = 0.0
var elapsed: = 0.0
var seed_v: = 0
var me_elo: = 1000
var opp: = {}
var total: = 64
var bot_left: = 64
var bot_score: = 0
var bot_combo: = 0
var my_left: = 64
var my_score: = 0
var next_pair: = 2.0
var next_sab: = 30.0
var next_emote: = 14.0
var slow_until: = 0.0
var rng: = RandomNumberGenerator.new()
var mode_s: = "ranked"


func _init(n = null) -> void:
	net = n
	rng.randomize()


func _emit(d: Dictionary) -> void:
	if net != null:
		net.dispatch(d)


func handle(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"ping":
			_emit({"t": "pong"})
		"matchmake_join":
			phase = "queue"
			mode_s = "ranked"
			wait = rng.randf_range(1.2, 2.2)
			_emit({"t": "queued", "elo": V10OnlineCfg.elo(), "eta_s": 2})
		"matchmake_cancel", "leave":
			if phase == "match":
				_end(false, "forfeit")
			phase = "idle"
			_emit({"t": "queue_left"})
		"room_create":
			phase = "room"
			mode_s = "room"
			wait = 3.0
			_emit({"t": "room_created", "code": "%06d" % rng.randi_range(100000, 999999)})
		"room_join":
			if not V10Online.valid_room_code(String(d.get("code", ""))):
				_emit({"t": "error", "code": "room_not_found", "msg": "Комната не найдена"})
				return
			mode_s = "room"
			_start()
		"progress":
			total = maxi(2, int(d.get("tiles_total", total)))
			my_left = int(d.get("tiles_left", my_left))
			my_score = int(d.get("score", my_score))
		"sabotage":
			if phase == "match":
				slow_until = elapsed + (5.0 if String(d.get("kind", "")) == "ice" else 7.0)
				next_pair += 2.5
		"emote":
			if phase == "match" and rng.randf() < 0.6:
				next_emote = minf(next_emote, 1.2)
		"match_finish":
			if phase == "match":
				my_left = int(d.get("tiles_left", my_left))
				my_score = int(d.get("score", my_score))
				_end(bool(d.get("cleared", false)), "cleared" if bool(d.get("cleared", false)) else "overflow")


func _start() -> void:
	phase = "match"
	elapsed = 0.0
	seed_v = rng.randi_range(1000, 999999)
	me_elo = V10OnlineCfg.elo()
	var nick: String = NICKS[rng.randi() % NICKS.size()]
	opp = {"id": -1, "nick": nick, "avatar": AVATARS[rng.randi() % AVATARS.size()], "pvp_elo": me_elo + rng.randi_range(-40, 40), "bot": true}
	bot_left = total
	bot_score = 0
	bot_combo = 0
	next_pair = rng.randf_range(2.0, 3.0)
	next_sab = rng.randf_range(25.0, 40.0)
	next_emote = rng.randf_range(8.0, 16.0)
	var you: = {"id": int(V10OnlineCfg.user().get("id", 0)), "nick": V10OnlineCfg.nick(), "avatar": V10OnlineCfg.avatar(), "pvp_elo": me_elo}
	_emit({"t": "match_start", "match_id": "local-%d" % seed_v, "seed": seed_v, "board_cfg": V10Online.board_cfg(seed_v),
		"duration_s": int(DURATION), "you": you, "opponent": opp, "mode": mode_s, "local": true})


func _pair_interval() -> float:
	var skill: = clampf(float(int(opp.get("pvp_elo", 1000)) - 1000) / 1000.0, -0.4, 0.6)
	var t: = rng.randf_range(1.6, 3.4) * (1.0 - skill * 0.5)
	if elapsed < slow_until:
		t *= 1.8
	return t


func tick(dt: float) -> void:
	match phase:
		"queue", "room":
			wait -= dt
			if wait <= 0.0:
				_start()
		"match":
			elapsed += dt
			next_pair -= dt
			if next_pair <= 0.0:
				var burst: = 2 if rng.randf() < 0.18 else 1
				bot_combo = bot_combo + burst if rng.randf() < 0.55 else burst
				for _i in burst:
					bot_left = maxi(0 if elapsed >= MIN_FINISH else 2, bot_left - 2)
					bot_score += 100 * maxi(1, bot_combo)
				next_pair = _pair_interval()
				_emit({"t": "opponent_progress", "tiles_left": bot_left, "tiles_total": total, "score": bot_score, "combo": bot_combo})
				if bot_left <= 0:
					_end(false, "cleared")
					return
			next_sab -= dt
			if next_sab <= 0.0:
				next_sab = rng.randf_range(25.0, 40.0)
				_emit({"t": "sabotage", "kind": "ice" if rng.randf() < 0.5 else "fog", "from": opp.get("id", -1)})
			next_emote -= dt
			if next_emote <= 0.0:
				next_emote = rng.randf_range(14.0, 26.0)
				_emit({"t": "emote", "id": V10Online.EMOTES[rng.randi() % V10Online.EMOTES.size()], "from": opp.get("id", -1)})
			if elapsed >= DURATION:
				var won: = my_left < bot_left or (my_left == bot_left and my_score >= bot_score)
				_end(won, "timeout")


func _end(won: bool, reason: String) -> void:
	if phase != "match":
		return
	phase = "over"
	var r: = V10OnlineCfg.apply_local_result(won, int(opp.get("pvp_elo", 1000)))
	_emit({"t": "match_end", "match_id": "local-%d" % seed_v, "winner_id": 0 if won else -1, "you_won": won, "reason": reason,
		"your_score": my_score, "opp_score": bot_score, "elo_before": r.elo_before, "elo_after": r.elo_after,
		"elo_delta": r.elo_delta, "local": true})
