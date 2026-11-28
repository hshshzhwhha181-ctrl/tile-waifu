class_name V10LocalTransport
extends "res://core/chat/chat_transport.gd"

# Offline transport: scripted threads from res://data/v10/chat/ driven by V10Chat over a state Dictionary that
# lives in the save (S.v10_phone.chat). Optionally mirrors bubbles into the per-heroine history log.
#   var tr := V10LocalTransport.new(G.S.v10_phone.chat)
#   tr.post_event({kind = "first_win"}, ctx)   # from V10Hooks.game_ended
#   var r := tr.choose(tid, 1, ctx); for e in r.effects: V10Bond.gain(e.hero, e.n, e.src)

const C: = preload("res://core/chat/chat.gd")
const D: = preload("res://core/chat/chat_data.gd")
const L: = preload("res://core/chat/chat_log.gd")

var state: Dictionary
var log_dir: = ""          # "" → no history files (tests); "user://v10_logs/" in the game


func _init(chat_state: Dictionary, history_dir: String = "") -> void:
	state = C.ensure(chat_state)
	log_dir = history_dir


func kind() -> String:
	return "local"


func available() -> bool:
	return true


func _log(hero: String, entries: Array) -> void:
	if log_dir == "" or entries.is_empty():
		return
	L.write(hero, L.append(L.read(hero, log_dir), entries), log_dir)


func _opened(tids: Array, ctx: Dictionary) -> Dictionary:
	for tid in tids:
		var v: = C.view(state, tid, ctx)
		_log(v.hero, v.msgs)
		incoming.emit({"kind": "thread_opened", "hero": v.hero, "tid": tid})
	return {"ok": true, "opened": tids}


func tick(ctx: Dictionary) -> Dictionary:
	return _opened(C.tick(state, ctx), ctx)


func post_event(ev: Dictionary, ctx: Dictionary) -> Dictionary:
	return _opened(C.on_event(state, ev, ctx), ctx)


func list(ctx: Dictionary) -> Dictionary:
	return {"ok": true, "rows": C.rows(state, ctx)}


func open(tid: String, ctx: Dictionary) -> Dictionary:
	var v: = C.view(state, tid, ctx)
	if v.is_empty():
		return {"ok": false}
	C.mark_read(state, tid)
	return {"ok": true, "view": v}


func choose(tid: String, i: int, ctx: Dictionary) -> Dictionary:
	var r: = C.choose(state, tid, i, ctx)
	if r.get("ok", false):
		_log(D.hero_of(tid), [r.me] + r.msgs)
	return r


func react(tid: String, idx: int, rid: String, ctx: Dictionary) -> Dictionary:
	var r: = C.react(state, tid, idx, rid, ctx)
	if str(r.get("reply", "")) != "":
		_log(D.hero_of(tid), [{"who": "h", "k": "text", "t": r.reply}])
	return r


func sticker(hero: String, sid: String, ctx: Dictionary) -> Dictionary:
	var r: = C.send_sticker(state, hero, sid, ctx)
	if r.get("ok", false):
		var e: = [{"who": "me", "k": "sticker", "id": sid}]
		if str(r.get("reply", "")) != "":
			e.append({"who": "h", "k": "text", "t": r.reply})
		_log(hero, e)
	return r


func unread() -> int:
	return C.unread(state)
