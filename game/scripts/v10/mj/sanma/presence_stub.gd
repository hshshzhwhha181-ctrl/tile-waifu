class_name V10MjSanmaPresenceProbe
extends RefCounted

# Заглушка присутствия (контракт MODES §7.1): `on(event, data)` и `sacred(rect)`.
# Экран берёт её, если args.presence нет; самотест — чтобы считать события и блокировки.
# Настоящий режиссёр — V10MjPresence (дорожка stage); он подменяет этот объект целиком.

const EVENTS: = ["pick", "pair", "combo", "motif", "danger", "signature", "wave", "ult", "last_pair", "win", "lose", "idle",
	"call", "riichi", "dora", "ron", "tsumo", "tenpai", "noten", "dealin", "kita"]

var log: = []
var sacred_rects: = []
var max_block: = 0.0
var input_on: = true
var unknown: = 0

func on(event: String, data: = {}) -> void:
	if not event in EVENTS:
		unknown += 1
	log.append([event, data])
	max_block = maxf(max_block, float(data.get("block", 0.0)))

func sacred(rect: Rect2) -> void:
	sacred_rects.append(rect)

func count(event: String) -> int:
	var n: = 0
	for e in log:
		if e[0] == event:
			n += 1
	return n
