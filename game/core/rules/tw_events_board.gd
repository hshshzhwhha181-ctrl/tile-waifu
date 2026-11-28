class_name TWBoardEvents
extends RefCounted

# TWBoardEvents (P16 / WP5): the events TWBoard.tap() and friends return. An event is a plain Dictionary with a "t"
# (type) key plus the fields listed below; tile ids are the integer ids of the board (index into TWBoard.pos). The board
# never plays a sound or an animation: the view (TWBoardView, later) consumes the list in order and animates it.
#
#   MATCH       a, b, face, combo, gold, shard (hero id or ""), gift, mid (Vector2 on the table)   a pair left the table
#   TO_TRAY     id, slot, face                                                                      a tile went to the tray
#   TRAY_WARN   left                                                                                one slot is left
#   TRAY_FULL   tray (ids)                                                                          the round is lost
#   CLEARED                                                                                         the table is empty
#   DENY        id, why ("covered")                                                                 a covered tile was tapped
#   BLOCKED     id, kind ("lock" | "chain")                                                         a free lock/chain tile
#   ICE_CRACK   id, left                                                                            an ice tile was flipped
#   REVEAL      id                                                                                  a hidden tile became free
#   JOKER       id, face                                                                            a joker took a face
#   UNLOCK      group, ids                                                                          a key pair opened locks
#   UNCHAIN     id                                                                                  a chain tile lost its chain
#   UNSTICK     (none)                                                                              nothing was takeable: all locks/chains opened
#   GIFT        a, b                                                                                a gift pair left the table
#   BLAST       at (ids), pairs ([[a, b], ..]), mid                                                 a bomb pair took nearby pairs
#   UNDO        id                                                                                  the last tray tile went back
#   RETURN      ids                                                                                 tray tiles went back (rescue)
#   SHUFFLE     ids                                                                                 faces were dealt again
#   VANISH      a, b                                                                                an ult/skill removed a pair
#   MOONLIGHT   revealed (ids), thawed (ids)                                                        every secret shown, every ice melted

const MATCH: = "MATCH"
const TO_TRAY: = "TO_TRAY"
const TRAY_WARN: = "TRAY_WARN"
const TRAY_FULL: = "TRAY_FULL"
const CLEARED: = "CLEARED"
const DENY: = "DENY"
const BLOCKED: = "BLOCKED"
const ICE_CRACK: = "ICE_CRACK"
const REVEAL: = "REVEAL"
const JOKER: = "JOKER"
const UNLOCK: = "UNLOCK"
const UNCHAIN: = "UNCHAIN"
const UNSTICK: = "UNSTICK"
const GIFT: = "GIFT"
const BLAST: = "BLAST"
const UNDO: = "UNDO"
const RETURN: = "RETURN"
const SHUFFLE: = "SHUFFLE"
const VANISH: = "VANISH"
const MOONLIGHT: = "MOONLIGHT"

const ALL: = [MATCH, TO_TRAY, TRAY_WARN, TRAY_FULL, CLEARED, DENY, BLOCKED, ICE_CRACK, REVEAL, JOKER, UNLOCK, UNCHAIN, UNSTICK,
	GIFT, BLAST, UNDO, RETURN, SHUFFLE, VANISH, MOONLIGHT]


static func make(type: String, data: Dictionary = {}) -> Dictionary:
	var e: = data.duplicate()
	e["t"] = type
	return e


static func type_of(e: Dictionary) -> String:
	return str(e.get("t", ""))


static func has(events: Array, type: String) -> bool:
	for e in events:
		if (e as Dictionary).get("t", "") == type:
			return true
	return false


static func count(events: Array, type: String) -> int:
	var c: = 0
	for e in events:
		if (e as Dictionary).get("t", "") == type:
			c += 1
	return c


static func of_type(events: Array, type: String) -> Array:
	var out: = []
	for e in events:
		if (e as Dictionary).get("t", "") == type:
			out.append(e)
	return out


# the types of a list in order (compact assertions in tests, replay logs)
static func types(events: Array) -> PackedStringArray:
	var out: = PackedStringArray()
	for e in events:
		out.append(str((e as Dictionary).get("t", "")))
	return out
