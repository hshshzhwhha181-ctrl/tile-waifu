class_name V6Layouts
extends RefCounted




const NAMES: = {
	"hourglass": "Песочные часы", "arch": "Мостик", "flower": "Цветок", "crown": "Корона", 
	"bowl": "Чаша", "lantern": "Фонарь", "frame": "Рамка", "chevron": "Стрела", 
	"star": "Звезда", "torii": "Врата", "islands": "Острова", "moon": "Луна", "fan": "Веер", 
	"pagoda": "Пагода", "gem": "Кристалл", "wings": "Крылья", 
}
const UPPER_NAMES: = {"peak": "гора в центре", "walls": "крепостные стены", "checker": "шахматка", "rows": "ярусы", "ring": "кольцо башен"}

static func keep(shape: String, x: float, y: float) -> bool:
	var ax: = absf(x)
	var ay: = absf(y)
	match shape:
		"hourglass":
			return ax <= 0.3 + 0.75 * ay
		"arch":
			return y < -0.25 or ax > 0.45
		"flower":
			var r: = sqrt(x * x + y * y)
			var th: = atan2(y, x)
			return r <= 0.62 + 0.42 * absf(cos(2.0 * th)) or r < 0.35
		"crown":
			return y > -0.15 or ax > 0.7 or ax < 0.18
		"bowl":
			return x * x + y * y <= 1.25 and not (x * x + (y + 0.75) * (y + 0.75) < 0.55)
		"lantern":
			if y < -0.75:
				return ax < 0.35
			if y > 0.8:
				return ax < 0.45
			return ax <= 1.02 - 0.45 * y * y
		"frame":
			return ax > 0.6 or ay > 0.62 or (ax < 0.2 and ay < 0.25)
		"chevron":
			return y >= ax * 1.25 - 0.95 and y <= ax * 1.25 + 0.05
		"star":
			return ax < 0.2 or ay < 0.2 or absf(ax - ay) < 0.32
		"torii":
			return y < -0.6 or (y > -0.42 and y < -0.12 and ax < 0.85) or (ax > 0.4 and ax < 0.8)
		"islands":
			return (ax > 0.3 and ay < 0.5) or (ax < 0.22 and ay > 0.55)
		"moon":
			var inner: = (x * x + (y + 0.45) * (y + 0.45)) < 0.6
			return x * x + y * y <= 1.15 and not inner
		"fan":
			var r2: = sqrt(x * x + (y - 1.0) * (y - 1.0))
			return r2 <= 2.0 and r2 >= 0.55 and y > -1.1 + ax * 0.2
		"pagoda":
			if y < -0.55:
				return ax < 0.35
			if y < 0.05:
				return ax < 0.7
			return true
		"gem":
			return y < -0.4 and ax < 0.75 + (y + 1.0) * 0.5 or y >= -0.4 and ax <= 1.0 - (y + 0.4) * 0.85
		"wings":
			return ax > 0.12 and not (ax < 0.5 and y > 0.45) and not (ax > 0.75 and y < -0.6)
	return true

static func is_custom(shape: String) -> bool:
	return NAMES.has(shape)


static func upper_w(pattern: String, xx: int, yy: int, z: int, xs: Array, ys: Array) -> float:
	if pattern == "" or xs.is_empty() or ys.is_empty():
		return 1.0
	var cx: float = (xs[0] + xs[xs.size() - 1]) * 0.5
	var cy: float = (ys[0] + ys[ys.size() - 1]) * 0.5
	var hx: float = maxf(1.0, (xs[xs.size() - 1] - xs[0]) * 0.5)
	var hy: float = maxf(1.0, (ys[ys.size() - 1] - ys[0]) * 0.5)
	var nx: = absf(xx - cx) / hx
	var ny: = absf(yy - cy) / hy
	var d: = maxf(nx, ny)
	match pattern:
		"peak":
			return clampf(1.55 - d * 1.1, 0.15, 1.6)
		"walls":
			return 1.6 if d > 0.6 else (0.25 if z <= 2 else 0.6)
		"checker":
			return 1.5 if (int(xx) / 2 + int(yy) / 2 + z) % 2 == 0 else 0.15
		"rows":
			return 1.5 if (int(yy) / 2 + z) % 2 == 0 else 0.1
		"ring":
			var r: = sqrt(nx * nx + ny * ny)
			return 1.6 if absf(r - 0.7) < 0.35 else 0.2
	return 1.0


static func shape_name(shape: String) -> String:
	if NAMES.has(shape):
		return NAMES[shape]
	return G.SHAPE_NAMES.get(shape, shape)
