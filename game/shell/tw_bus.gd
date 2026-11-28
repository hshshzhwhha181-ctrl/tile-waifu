class_name TWBus
extends RefCounted

# TWBus (P23 / WP8a): the shell side of the event contract. Core returns a list of typed events (plain Dictionaries with a
# "t" type key, see TWBoardEvents) from a command; the shell hands that list to publish_all() and every subscriber animates
# it. One-way: core never sees the bus (CORE_PURITY), a handler never writes state or saves.
#
#   subscribe(kind, cb, owner = null) -> int   kind "*" = every event; cb(ev: Dictionary). Returns a token. When `owner` is a
#                                              Node the subscription dies with it (tree_exiting); a freed cb target is dropped
#   unsubscribe(token) / unsubscribe_owner(owner)
#   publish(ev) / publish_all(events)          synchronous, in order. An event published from inside a handler is queued and
#                                              delivered after the current event reached every subscriber (FIFO, no re-entrancy)
#   recent(n) -> Array                         the last n events (ring of RING), for tests and the bug-report dump
#   signal event(ev)                           every event, for code that prefers a signal
#
# Subscribers of one kind run in subscription order, "*" ones after the exact-kind ones of the same event.

signal event(ev: Dictionary)

const RING: = 64
const MAX_QUEUE: = 4096        # events one publish() call may deliver (nested ones included); a handler loop is cut here

var _subs: Dictionary = {}     # kind -> Array of token
var _by_token: Dictionary = {} # token -> {kind, cb, owner, owner_id}
var _owner_exits: Dictionary = {} # owner_id -> {node, cb, count}
var _next_token: = 1
var _queue: Array = []
var _dispatching: = false
var _ring: Array = []
var dropped: = 0               # events cut by MAX_QUEUE
var published: = 0


func subscribe(kind: String, cb: Callable, owner: Object = null) -> int:
	var tok: = _next_token
	_next_token += 1
	var oid: int = owner.get_instance_id() if owner != null else 0
	_by_token[tok] = {"kind": kind, "cb": cb, "owner": owner, "owner_id": oid}
	if not _subs.has(kind):
		_subs[kind] = []
	(_subs[kind] as Array).append(tok)
	if owner is Node:
		var node: Node = owner as Node
		if not _owner_exits.has(oid):
			var exit_cb: Callable = _on_owner_exiting.bind(oid)
			node.tree_exiting.connect(exit_cb, CONNECT_ONE_SHOT)
			_owner_exits[oid] = {"node": node, "cb": exit_cb, "count": 1}
		else:
			_owner_exits[oid].count += 1
	return tok


func _on_owner_exiting(oid: int) -> void:
	_owner_exits.erase(oid)
	for tok in _by_token.keys():
		if int(_by_token[tok].owner_id) == oid:
			unsubscribe(tok)


func unsubscribe(tok: int) -> void:
	var rec = _by_token.get(tok)
	if rec == null:
		return
	_by_token.erase(tok)
	var arr: Array = _subs.get(rec.kind, [])
	arr.erase(tok)
	if arr.is_empty():
		_subs.erase(rec.kind)
	var oid: int = int(rec.owner_id)
	if oid != 0 and _owner_exits.has(oid):
		var oe: Dictionary = _owner_exits[oid]
		oe.count -= 1
		if int(oe.count) <= 0:
			_owner_exits.erase(oid)
			var node = oe.node
			if node != null and is_instance_valid(node) and (node as Node).tree_exiting.is_connected(oe.cb):
				(node as Node).tree_exiting.disconnect(oe.cb)


func unsubscribe_owner(owner: Object) -> int:
	var n: = 0
	var target_id: int = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	for tok in _by_token.keys():
		var rec: Dictionary = _by_token[tok]
		var rec_owner = rec.owner
		if rec_owner != null and not is_instance_valid(rec_owner):
			unsubscribe(tok)
			continue
		if target_id != 0 and int(rec.owner_id) == target_id:
			unsubscribe(tok)
			n += 1
	return n


func subscriber_count(kind: String = "") -> int:
	if kind == "":
		return _by_token.size()
	return (_subs.get(kind, []) as Array).size()


static func kind_of(ev) -> String:
	if ev is Dictionary:
		return str(ev.get("t", ev.get("kind", "")))
	return ""


func publish(ev: Dictionary) -> void:
	if _queue.size() >= MAX_QUEUE:
		dropped += 1
		return
	_queue.append(ev)
	if not _dispatching:
		_drain()


func publish_all(events: Array) -> void:
	var any: = false
	for ev in events:
		if ev is Dictionary:
			if _queue.size() >= MAX_QUEUE:
				dropped += 1
			else:
				_queue.append(ev)
				any = true
	if any and not _dispatching:
		_drain()


func _drain() -> void:
	_dispatching = true
	var n: = 0
	while not _queue.is_empty():
		n += 1
		if n > MAX_QUEUE:                # a handler loop that re-publishes forever: cut it
			dropped += _queue.size()
			_queue.clear()
			break
		_deliver(_queue.pop_front())
	_dispatching = false


func recent(n: int = RING) -> Array:
	return _ring.slice(maxi(0, _ring.size() - n))


func clear_ring() -> void:
	_ring.clear()


func _deliver(ev: Dictionary) -> void:
	published += 1
	_ring.append(ev)
	if _ring.size() > RING:
		_ring.pop_front()
	var kind: = kind_of(ev)
	var toks: Array = (_subs.get(kind, []) as Array).duplicate()
	if kind != "*":
		toks.append_array((_subs.get("*", []) as Array).duplicate())
	for tok in toks:
		var rec = _by_token.get(tok)
		if rec == null:
			continue                    # unsubscribed by an earlier handler of this very event
		if rec.owner != null and not is_instance_valid(rec.owner):
			unsubscribe(tok)            # owner freed without exiting tree
			continue
		var cb: Callable = rec.cb
		if not cb.is_valid():
			unsubscribe(tok)            # target freed
			continue
		cb.call(ev)
	event.emit(ev)
