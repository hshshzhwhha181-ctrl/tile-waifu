class_name TWBattleBoardDeal
extends RefCounted

# TWBattleBoardDeal (P77 / BATTLE_ULT_SPEC §1.2, §1.4, §1.7, AT-B10):
# Pure integer helper that reconstructs a real `TWBoard` from a certified entry in `stages.json`
# (with weighted suit distribution `suit_weights` and pre-certified take order `cert`) and
# validates solvability via `TWBoard.verify_certificate()`.
# Zero Node / Control / G. / BATTLE_INT_ONLY violations.


static func from_certified_board(board_def: Dictionary) -> TWBoard:
	var flat_pos: Array = board_def.get("pos", [])
	var n: int = flat_pos.size() / 3
	var positions: Array = []
	for i in n:
		positions.append(Vector3i(int(flat_pos[3 * i]), int(flat_pos[3 * i + 1]), int(flat_pos[3 * i + 2])))
	var slots_n: int = int(board_def.get("slots", 5))
	var b: TWBoard = TWBoard.from_positions(positions, slots_n)
	b.deal_seed = int(board_def.get("seed", 1))
	b.code = "stage_" + str(b.deal_seed)
	b.rng = TWRng.make(b.deal_seed, 2)

	var faces_raw: Array = board_def.get("faces", [])
	var cert_raw: Array = board_def.get("cert", [])
	for i in mini(n, faces_raw.size()):
		b.face0[i] = int(faces_raw[i])
	var cert_arr: PackedInt32Array = PackedInt32Array()
	cert_arr.resize(cert_raw.size())
	for k in cert_raw.size():
		var tid: int = int(cert_raw[k])
		cert_arr[k] = tid
		if tid >= 0 and tid < n:
			b.step0[tid] = k / 2
	b.cert = cert_arr
	b.reset()
	return b


static func audit_suit_distribution(b: TWBoard) -> Dictionary:
	var counts: Dictionary = {"man": 0, "pin": 0, "sou": 0, "honor": 0}
	var distinct: Dictionary = {"man": {}, "pin": {}, "sou": {}, "honor": {}}
	for i in b.n:
		var f: int = int(b.face0[i])
		var s: String = TWBattleMath.suit_of_face(f)
		counts[s] = int(counts.get(s, 0)) + 1
		(distinct[s] as Dictionary)[f] = true
	return {
		"pair_counts": {
			"man": int(counts.man) / 2,
			"pin": int(counts.pin) / 2,
			"sou": int(counts.sou) / 2,
			"honor": int(counts.honor) / 2,
		},
		"distinct_faces": {
			"man": (distinct.man as Dictionary).size(),
			"pin": (distinct.pin as Dictionary).size(),
			"sou": (distinct.sou as Dictionary).size(),
			"honor": (distinct.honor as Dictionary).size(),
		},
	}
