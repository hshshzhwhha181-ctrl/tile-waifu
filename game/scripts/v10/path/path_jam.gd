class_name V10PathJam
extends RefCounted

# 0.10 · «Место затора» (0.10-spec П2): after a fail, the tile after which the reference order (the certificate)
# kept the tray at ≤2 while the player climbed to the full tray. Shown on the fail window for 2 s, works on every
# Path level (Peaks included — it is advice, not help).
#
# find(cfg, takes) — cfg = V10LevelGen.build(i) (payload + cert), takes = tile indices in the order the player TOOK them
# (a flip of a flip-back tile is not a take; play.gd collects the takes from V10Hooks.pair_taken / tile taps).
# Returns {} when there is nothing to show, else:
#   {step, tile, better, player_tray, ref_tray, text}
#   tile   — the player's take that started the climb (highlight it for 2 s)
#   better — the reference take at that step if it is still on the board (a soft «вот эту» hint), else -1

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const Sim = preload("res://scripts/v10/levels/level_sim.gd")


static func tray_curve(sim, cfg: Dictionary, order: PackedInt32Array) -> PackedInt32Array:
	Gen.load_into(sim, cfg)
	sim.reset()
	var out: = PackedInt32Array()
	for t in order:
		if t < 0 or t >= sim.n or sim.present[t] == 0 or not sim.is_free(t) or not sim.takeable(t):
			break
		while sim.ice[t] > 0:
			sim.tap(t)
		var r: int = sim.tap(t)
		out.append(sim.tray.size() if r >= 0 else sim.slots)
		if r < 0:
			break
	return out


static func find(cfg: Dictionary, takes: PackedInt32Array) -> Dictionary:
	if not cfg.has("v10") or takes.is_empty():
		return {}
	var sim: = Sim.new()
	var p: = tray_curve(sim, cfg, takes)
	var cert: PackedInt32Array = cfg.v10.cert
	var r: = tray_curve(sim, cfg, cert)
	if p.is_empty() or r.is_empty():
		return {}
	var end: = p.size() - 1
	# the point of the jam: the player's peak tray (the overflow on a fail)
	var top: = 0
	for k in p.size():
		if p[k] >= p[top]:
			top = k
	end = top
	var ref_at_end: = int(r[mini(end, r.size() - 1)])
	if p[end] <= ref_at_end:
		return {}
	# walk back to the last step where the player was not above the reference: the next take started the climb
	var j: = end
	while j > 0:
		var rr: = int(r[mini(j - 1, r.size() - 1)])
		if p[j - 1] <= rr:
			break
		j -= 1
	var better: = -1
	if j < cert.size():
		better = int(cert[j])
		# the reference tile must still be on the board after the player's first j takes
		for k in j:
			if takes[k] == better:
				better = -1
				break
	var ref_max: = 0
	for k in range(j, mini(end + 1, r.size())):
		ref_max = maxi(ref_max, int(r[k]))
	var text: = "Здесь лоток начал копиться: эталон держал в нём не больше %d, а у тебя дошло до %d." % [maxi(ref_max, 1), int(p[end])]
	return {"step": j, "tile": int(takes[j]), "better": better, "player_tray": int(p[end]), "ref_tray": ref_max, "text": text}


# a plausible losing takes for tests and the demo: the reference order with greedy «hold» mistakes injected
static func demo_fail_log(cfg: Dictionary, rseed: = 7) -> PackedInt32Array:
	var sim: = Sim.new()
	Gen.load_into(sim, cfg)
	sim.reset()
	var rng: = RandomNumberGenerator.new()
	rng.seed = rseed
	var takes: = PackedInt32Array()
	var guard: = sim.n * 3
	while sim.alive_n > 0 and guard > 0 and not sim.failed:
		guard -= 1
		var mv: PackedInt32Array = sim.moves_now()
		if mv.is_empty():
			break
		# prefer a tile whose face is NOT in the tray (a mistake that grows the tray)
		var pick: = -1
		var opts: = []
		for t in mv:
			var in_tray: = false
			for x in sim.tray:
				if sim.face[x] == sim.face[t]:
					in_tray = true
			if not in_tray and sim.ice[t] == 0:
				opts.append(t)
		if opts.size() > 0:
			pick = opts[rng.randi() % opts.size()]
		else:
			pick = mv[rng.randi() % mv.size()]
		while sim.ice[pick] > 0:
			sim.tap(pick)
		takes.append(pick)
		if sim.tap(pick) < 0:
			break
	return takes
