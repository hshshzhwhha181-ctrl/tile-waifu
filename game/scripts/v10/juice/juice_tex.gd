class_name V10JuiceTex
extends RefCounted

# V10JuiceTex — small procedural textures for V10Juice (built once, cached). Everything is white/greyscale so the
# effect tints it with modulate; nothing here needs an import or a file on disk.
#   star4   four-point twinkle (idle sparkles, crest, chest)     dot     soft round mote
#   ember   soft elongated spark (fever embers, god-ray motes)   ring    thin soft ring
#   coin    gold disc fallback when Common.ui_icon has no coin    gem     violet-blue cut-gem fallback

static var _cache: = {}


static func get_tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var img: Image
	match name:
		"star4":
			img = _star4(64)
		"dot":
			img = _dot(32)
		"ember":
			img = _ember(16, 40)
		"ring":
			img = _ring(64)
		"coin":
			img = _coin(48)
		"gem":
			img = _gem(48)
		_:
			img = _dot(32)
	var t: = ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


static func _star4(s: int) -> Image:
	var img: = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: = (s - 1) * 0.5
	for y in s:
		for x in s:
			var dx: = absf(x - c) / c
			var dy: = absf(y - c) / c
			# two crossed thin lobes + a soft core
			var a: = exp(-dx * 9.0) * exp(-dy * dy * 1.2) + exp(-dy * 9.0) * exp(-dx * dx * 1.2)
			a += exp(-(dx * dx + dy * dy) * 14.0) * 0.9
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return img


static func _dot(s: int) -> Image:
	var img: = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: = (s - 1) * 0.5
	for y in s:
		for x in s:
			var d: = Vector2(x - c, y - c).length() / c
			var a: = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img


static func _ember(w: int, h: int) -> Image:
	var img: = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx: = (x - (w - 1) * 0.5) / (w * 0.5)
			var dy: = (y - (h - 1) * 0.5) / (h * 0.5)
			var a: = exp(-dx * dx * 4.0) * clampf(1.0 - dy * dy, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _ring(s: int) -> Image:
	var img: = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: = (s - 1) * 0.5
	for y in s:
		for x in s:
			var d: = Vector2(x - c, y - c).length() / c
			var a: = exp(-pow((d - 0.82) / 0.09, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _coin(s: int) -> Image:
	var img: = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: = (s - 1) * 0.5
	for y in s:
		for x in s:
			var v: = Vector2(x - c, y - c) / c
			var d: = v.length()
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var lit: = clampf(0.75 - v.x * 0.25 - v.y * 0.35, 0.3, 1.0)
			var col: = Color(0.98, 0.78, 0.3) * lit
			if d > 0.78:
				col = Color(0.85, 0.58, 0.18) * (lit + 0.1)
			if absf(d - 0.55) < 0.05:
				col = col.lightened(0.18)
			col.a = clampf((1.0 - d) * 8.0, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return img


static func _gem(s: int) -> Image:
	var img: = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: = (s - 1) * 0.5
	for y in s:
		for x in s:
			var v: = Vector2(x - c, y - c) / c
			var d: = absf(v.x) + absf(v.y) * 0.8
			if d > 0.95:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var facet: = 0.6 + 0.4 * signf(v.x) * signf(v.y)
			var col: = Color(0.55, 0.5, 0.98).lerp(Color(0.7, 0.92, 1.0), facet * 0.5 + (0.0 if v.y > 0 else 0.3))
			col.a = clampf((0.95 - d) * 12.0, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return img
