class_name V10ChatTransport
extends RefCounted

# The seam between the phone UI and whoever "speaks" for the heroines (spec §Р8 «Код», §11 1.2).
# 0.10 ships one implementation, V10LocalTransport (offline, scripted, this folder). In 1.2 a server transport
# (Nakama) implements the same calls for player chat / server-pushed threads, without touching the UI.
#
# Contract:
#   * every call returns a Dictionary at once. A local transport answers fully ({ok:true, …}).
#     A remote one may answer {ok:true, pending:true, req:<id>} and later emit `answered(req, result)`
#     with the same shape the local one would have returned.
#   * `incoming(msg)` is emitted for anything that arrives without a request (a server push, a new thread);
#     msg = {kind:"thread_opened"|"message", hero, tid?, …}.
#   * results never apply affection; they carry `effects` for V10Bond.gain(h, n, src).
#   * no free text ever goes out (spec §Р8 п.9): only thread pills, reactions and stickers by id.

signal incoming(msg: Dictionary)
signal answered(req: int, result: Dictionary)


func kind() -> String:
	return "none"


# can this transport work right now (local: always; server: logged in and online)
func available() -> bool:
	return false


# day roll / app open: returns {ok, opened:[tid]}
func tick(_ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# a game event (first_win, combo_record, rank_up, comeback, birthday, outfit): returns {ok, opened:[tid]}
func post_event(_ev: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# rows for the Chats tab: {ok, rows:[{hero, tid, title, last, dot, pinned, day}]}
func list(_ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# open a dialog: {ok, view:{tid, hero, title, msgs, choices, done}}; marks it read
func open(_tid: String, _ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# the player taps a pill: {ok, me, msgs, choices, done, effects}
func choose(_tid: String, _i: int, _ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# long-press reaction on her message #idx: {ok, reply}
func react(_tid: String, _idx: int, _rid: String, _ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# a sticker sent outside the pills: {ok, reply}
func sticker(_hero: String, _sid: String, _ctx: Dictionary) -> Dictionary:
	return {"ok": false}


# phone badge part for chats
func unread() -> int:
	return 0
