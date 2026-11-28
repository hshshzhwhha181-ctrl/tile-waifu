class_name V10MjSanmaLandlord
extends RefCounted

# Событие «Хозяйка против двоих» (крюк Доу Ди Чжу, раз в месяц).
#  - Перед каждой раздачей героиня-хозяйка объявляет ×2 или ×3 (по стилю: дорогие руки → чаще ×3).
#  - Каждый кан и каждый отложенный Север (дора) удваивают табло множителя. Потолок ×96.
#  - Множитель меняет ТОЛЬКО счёт события (`ev_score`). Очки стола, монеты и кристаллы он не трогает:
#    награды считает V10MjSanmaData.rewards() только по местам за столом.
#  - Счёт события: ценность руки = |выигрыш победителя| / 100 × множитель.
#    Хозяйка выиграла → получает 2 × ценность, каждая из двоих −ценность.
#    Выиграл кто-то из двоих → оба из двоих +ценность, хозяйка −2 × ценность. Ничья → 0. Сумма всегда 0.

const CAP: = 96

var host_seat: = 1
var host_id: = "yue"
var base: = 2
var mult: = 2
var doublings: = 0
var ev_score: = [0, 0, 0]
var history: = []
var rng: = RandomNumberGenerator.new()

func setup(host_seat_: int, host_id_: String, seed_: int) -> V10MjSanmaLandlord:
	host_seat = host_seat_
	host_id = host_id_
	rng.seed = seed_ ^ 0x5A17A
	ev_score = [0, 0, 0]
	history = []
	return self

# Вероятность ×3 по стилю хозяйки (V8AI.STYLES: value = любовь к дорогим рукам, riichi = азарт).
static func p_triple(style: Dictionary) -> float:
	var v: float = float(style.get("value", 0.6))
	var ri: float = float(style.get("riichi", 0.7))
	return clampf(0.15 + 0.45 * (v - 0.6) + 0.25 * (ri - 0.5), 0.1, 0.75)

# Объявление перед раздачей. Возвращает 2 или 3.
func declare() -> int:
	var st: Dictionary = V8AI.STYLES.get(host_id, V8AI.STYLES.mc)
	base = 3 if rng.randf() < p_triple(st) else 2
	mult = base
	doublings = 0
	return base

func double(reason: String) -> int:
	if mult < CAP:
		mult = mini(CAP, mult * 2)
		doublings += 1
	history.append({"why": reason, "mult": mult})
	return mult

# Реакция на событие движка. Возвращает true, если табло изменилось.
func on_engine(ev: Dictionary) -> bool:
	match ev.get("ev", ""):
		"kita":
			double("kita")
			return true
		"call":
			if String(ev.get("type", "")) in ["ankan", "minkan", "kakan"]:
				double("kan")
				return true
	return false

# Закрыть раздачу: начислить счёт события. Возвращает дельту события по местам.
func settle(res: Dictionary) -> Array:
	var d: = [0, 0, 0]
	if res.get("ev", "") == "win":
		var w: int = int(res.seat)
		var val: int = int(ceil(absf(float(res.delta[w])) / 100.0)) * mult
		if w == host_seat:
			for s in 3:
				d[s] = 2 * val if s == host_seat else - val
		else:
			for s in 3:
				d[s] = -2 * val if s == host_seat else val
	for s in 3:
		ev_score[s] += d[s]
	return d

func host_line_id() -> String:
	return "host_x3" if base == 3 else "host_x2"
