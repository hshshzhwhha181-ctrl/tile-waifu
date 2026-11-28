class_name V10MjConnectUlts
extends RefCounted

# Приёмы в Связях (MODES §5.5, колонка «Связи»):
#   mc   — «Снять пару»: снимает 1 доступную пару
#   rin  — «Шёлковый перебор»: перемешать без штрафа и подсветить пару с путём
#   hana — «Рывок»: снимает 2 доступные пары
#   yue  — «Лунный свет»: показывает все доступные пары на 3 с
#   nova — «Взлом»: снимает пару с самым длинным путём

const NAMES: = {
	"mc": "Снять пару",
	"rin": "Шёлковый перебор",
	"hana": "Рывок",
	"yue": "Лунный свет",
	"nova": "Взлом",
}


static func ult_name(hero: String) -> String:
	return String(NAMES.get(hero, NAMES.rin))


static func need(aff_lvl: int) -> int:
	return maxi(5, V9Ults.need(aff_lvl, false))


static func plan(hero: String, board: V10MjConnectBoard) -> Dictionary:
	match hero:
		"mc":
			return {"kind": "take", "count": 1}
		"hana":
			return {"kind": "take", "count": 2}
		"rin":
			return {"kind": "rin_shuffle_hint"}
		"yue":
			var ids: = {}
			for m in board.moves():
				ids[int(m[0])] = true
				ids[int(m[1])] = true
			return {"kind": "show_all", "tiles": ids.keys(), "sec": 3.0}
		"nova":
			var best: Array = []
			var best_score: = -1
			for m in board.moves():
				var p: = board.path_for(int(m[0]), int(m[1]))
				if p.is_empty():
					continue
				var sc: = V10MjConnectPath.turns_of(p) * 1000 + V10MjConnectPath.length_of(p)
				if sc > best_score:
					best_score = sc
					best = [int(m[0]), int(m[1]), p]
			return {"kind": "longest", "pair": best}
	return {"kind": "take", "count": 1}
