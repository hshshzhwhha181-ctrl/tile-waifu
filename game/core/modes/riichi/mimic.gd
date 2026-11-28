class_name V10MjRiichiMimic
extends RefCounted

# «Честный стол»: the rivals' faces react only to public events (the said stream and its public data).
# Nothing here can see a hand: the API takes (actor, what, public data) and returns faces. The selftest feeds two
# tables with the same public stream and different hidden hands and expects identical faces.

const HOLD: = 1.8

var base: = ["neutral", "neutral", "neutral", "neutral"]
var face: = ["neutral", "neutral", "neutral", "neutral"]
var until: = [0.0, 0.0, 0.0, 0.0]
var log: = []

# face of `viewer` when `actor` did `what` (public). "" = no change.
static func react(viewer: int, actor: int, what: String, data: Dictionary) -> String:
	if viewer == actor:
		match what:
			"call":
				return "happy"
			"riichi":
				return "shy"
			"ron", "tsumo":
				return "happy"
			"dealin":
				return "sad"
			"tenpai":
				return "shy"
			"noten":
				return "pout"
			"dora":
				return "surprised"
		return ""
	match what:
		"riichi":
			return "surprised"
		"ron", "tsumo":
			return "surprised" if data.get("yakuman", false) else "pout"
	return ""

func reset_hand() -> void:
	base = ["neutral", "neutral", "neutral", "neutral"]
	for s in 4:
		face[s] = base[s]
		until[s] = 0.0

# returns {seat: face} for the faces that changed; t = current time (s)
func on_said(actor: int, what: String, data: Dictionary, t: float, seats: Array = [0, 1, 2, 3]) -> Dictionary:
	var out: = {}
	if what == "riichi":
		base[actor] = "shy"
	for v in seats:
		var f: = react(v, actor, what, data)
		if f == "":
			continue
		face[v] = f
		until[v] = t + HOLD
		out[v] = f
	log.append([actor, what, out.duplicate()])
	return out

# back to the base face once the hold is over
func tick(t: float) -> Dictionary:
	var out: = {}
	for s in 4:
		if until[s] > 0.0 and t >= until[s]:
			until[s] = 0.0
			if face[s] != base[s]:
				face[s] = base[s]
				out[s] = base[s]
	return out
