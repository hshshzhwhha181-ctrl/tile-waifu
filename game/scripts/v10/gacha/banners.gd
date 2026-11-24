class_name V10Banners
extends RefCounted

# V10Banners — banner rhythm 3+3 (spec Г6) and the banner list of the Wishes screen (Г1, Г4).
# Phase A «Новая луна» (21 days): one SSR (half the SSRs are hers, a miss promises the next) + 3 S of the banner.
# Phase B «Полнолуние» (21 days): two earlier SSRs and the «Цель желания» switch (free, keeps the promise).
# Phases start at 04:00 MSK, back to back from `anchor` (data/banners.json). When the schedule runs out (a late
# release) a fallback loop of B phases from already released SSRs keeps the calendar without holes.
# Time comes only from V10GClock; a rolled-back clock never brings back an ended phase (high-water mark `hw`).
#
#   V10Banners.data() -> Dictionary                   parsed banners.json (cached)
#   V10Banners.phase_at(t) -> Dictionary              the phase running at unix t: {id, kind:"phase", half, name, sub,
#                                                     ssr:[], s_up:[], start, end, idx, fallback?}
#   V10Banners.current(S) -> Dictionary               phase at max(now, S.v10_gacha.hw); updates hw
#   V10Banners.next_phase(S) -> Dictionary            the phase after the current one
#   V10Banners.shown(S) -> Array                      banners of the Wishes screen: [newbie?] + phase + std
#   V10Banners.target(S, phase) / set_target(S, phase, id) -> bool
#   V10Banners.countdown_visible(phase, t) -> bool    only in the last 48 h
#   V10Banners.schedule(from_t, weeks) -> Array       every phase covering [from_t, from_t + weeks]

const PATH: = "res://scripts/v10/gacha/data/banners.json"

static var _data: = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f: = FileAccess.open(PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func phase_len() -> int:
	return int(data().get("phase_days", 21)) * V10GClock.DAY


static func anchor_t() -> int:
	var a: = String(data().get("anchor", "2026-11-23")).split("-")
	return V10GClock.msk_at(int(a[0]), int(a[1]), int(a[2]))


static func std() -> Dictionary:
	var b: Dictionary = data().get("std", {}).duplicate(true)
	b["ssr"] = []
	b["s_up"] = []
	return b


static func newbie() -> Dictionary:
	var b: Dictionary = data().get("newbie", {}).duplicate(true)
	b["ssr"] = []
	b["s_up"] = []
	return b


static func phase_at(t: int) -> Dictionary:
	var list: Array = data().get("phases", [])
	var a: = anchor_t()
	var L: = phase_len()
	var i: = int(floor(float(t - a) / L))
	i = maxi(i, 0)
	var p: Dictionary
	if i < list.size():
		p = (list[i] as Dictionary).duplicate(true)
	else:
		p = _fallback(i - list.size())
	p["idx"] = i
	p["start"] = a + i * L
	p["end"] = a + (i + 1) * L
	return p


# B phases cycling the SSRs that already had a phase: (ssr0, ssr1), (ssr2, ssr3) …, s_up from the released list
static func _fallback(k: int) -> Dictionary:
	var released: = []
	var s_ups: = []
	for p in data().get("phases", []):
		for id in p.ssr:
			if not (id in released):
				released.append(id)
		for id in p.s_up:
			if not (id in s_ups):
				s_ups.append(id)
	var n: = released.size()
	var a: String = released[(2 * k) % n]
	var b: String = released[(2 * k + 1) % n]
	if b == a:
		b = released[(2 * k + 2) % n]
	var s: = []
	for j in 3:
		s.append(s_ups[(3 * k + j) % s_ups.size()])
	return {"id": "fm_loop_%d" % k, "kind": "phase", "half": "B", "name": "Полнолуние", "sub": "Возвращение", "ssr": [a, b],
		"s_up": s, "hero": "mc", "color": "c99bff", "font": "playfair", "fallback": true}


static func state(S: Dictionary) -> Dictionary:
	if not (S.get("v10_gacha") is Dictionary):
		S["v10_gacha"] = {}
	return S.v10_gacha


static func eff_now(S: Dictionary) -> int:
	var st: = state(S)
	var t: = V10GClock.now()
	var hw: = int(st.get("hw", 0))
	if t > hw:
		st["hw"] = t
		return t
	return hw


static func current(S: Dictionary) -> Dictionary:
	var p: = phase_at(eff_now(S))
	p["target"] = target(S, p)
	return p


static func next_phase(S: Dictionary) -> Dictionary:
	var c: = phase_at(eff_now(S))
	var p: = phase_at(int(c.end))
	p["target"] = target(S, p)
	return p


static func target(S: Dictionary, phase: Dictionary) -> String:
	var ssr: Array = phase.get("ssr", [])
	if ssr.is_empty():
		return ""
	var tg = S.get("targets", {})
	var t: = String(tg.get(phase.id, "")) if tg is Dictionary else ""
	return t if t in ssr else String(ssr[0])


static func set_target(S: Dictionary, phase: Dictionary, id: String) -> bool:
	if not (id in phase.get("ssr", [])):
		return false
	if not (S.get("targets") is Dictionary):
		S["targets"] = {}
	S.targets[String(phase.id)] = id
	return true


static func countdown_visible(phase: Dictionary, t: int) -> bool:
	return int(phase.end) - t <= V10GClock.COUNTDOWN_MAX


static func shown(S: Dictionary, newbie_open: bool) -> Array:
	var out: = []
	if newbie_open:
		out.append(newbie())
	out.append(current(S))
	out.append(std())
	return out


static func schedule(from_t: int, weeks: int) -> Array:
	var out: = []
	var t: = from_t
	var end_t: = from_t + weeks * 7 * V10GClock.DAY
	while t < end_t:
		var p: = phase_at(t)
		out.append(p)
		t = int(p.end)
	return out
