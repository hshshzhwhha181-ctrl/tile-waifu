class_name V10MjCubeAtlas
extends RefCounted

# Куб: атлас лиц фишек, меш кубика с фаской и материалы (docs/MODES.md §4.4 «Стол и звук»).
#   atlas(look)        ImageTexture 6×6 ячеек по 128 px: плита цвета материала, символ фишки (G.tile_tex — те же лица, что
#                      у V6TileLook), тонкая кромка, fake-AO по краю лица запечён в текстуру. Кэш по материалу.
#   cube_mesh()        ArrayMesh: куб 1×1×1, шесть лиц (UV 0…1, символ прямо, если смотреть снаружи), 12 фасок и 8 уголков;
#                      UV лица 0…1; у фаски UV = (−1, −AO) — так шейдер отличает лицо от фаски без цвета вершин
#                      (в gl_compatibility цвет вершины у MultiMesh с custom data не доходит). 44 треугольника.
#   material(look, accent, opts)   ShaderMaterial (cube_tile.gdshader) для MultiMesh
#   id_material()      unshaded: цвет = номер инстанса (самотест: «луч попадает в нужный инстанс» сверяется с картинкой)
#   resolve_look(args_look, hero)  args.look → {plate, side, seam, accent, material}

const CELL: = 128
const GRID: = 6
const CHAMFER: = 0.085
const SHADER_PATH: = "res://scripts/v10/mj/cube/cube_tile.gdshader"
const LOOK_SCRIPT: = "res://scripts/v10/mj/look/tile_material.gd"
const ID_SHADER: = """
shader_type spatial;
render_mode unshaded, cull_back;
varying flat float idv;
void vertex() { idv = float(INSTANCE_ID + 1); }
void fragment() {
	float lo = mod(idv, 16.0);
	float hi = floor(idv / 16.0);
	ALBEDO = vec3(lo / 15.0, hi / 15.0, 0.0);
}
"""

static var _atlas: = {}
static var _mesh: ArrayMesh
static var _id_mat: ShaderMaterial
static var bake_ms: = 0


# args.look (V10MjTileMaterial.look_dict or {side, rim}) → cube colours. Without args.look: the player's material from
# the look lane (if present), else the skin look of 0.9.
static func resolve_look(lk, hero: String) -> Dictionary:
	var d: Dictionary = {}
	if lk is Dictionary and (lk as Dictionary).has("tiles") and lk.tiles is Dictionary:
		lk = lk.tiles
	if lk is Dictionary and not (lk as Dictionary).is_empty() and (lk.has("side") or lk.has("rim")):
		d = lk
	elif ResourceLoader.exists(LOOK_SCRIPT):
		var cls = load(LOOK_SCRIPT)
		if cls and cls.has_method("look_dict"):
			d = cls.look_dict("", hero)
	if d.is_empty():
		d = G.skin_look() if G.has_method("skin_look") else {}
	var ext: Dictionary = d.get("v10mj", {})
	var prm: Dictionary = ext.get("params", {})
	var plate: Color = prm.get("mat_face", d.get("rim", Color("f4ecdc")).lerp(Color("fbf6ec"), 0.6))
	var seam: Color = prm.get("mat_seam", Color("d6b26a"))
	return {
		"plate": plate,
		"side": d.get("side", Color("3f9c7c")),
		"seam": seam,
		"material": String(ext.get("material", "skin")),
		"tint": d.get("tint", Color.WHITE),
	}


static func atlas(lk: Dictionary) -> Texture2D:
	var key: = "%s|%s|%s" % [Color(lk.get("plate", Color.WHITE)).to_html(), Color(lk.get("seam", Color.WHITE)).to_html(),
		Color(lk.get("tint", Color.WHITE)).to_html()]
	if _atlas.has(key):
		return _atlas[key]
	var t0: = Time.get_ticks_msec()
	var img: = Image.create(CELL * GRID, CELL * GRID, false, Image.FORMAT_RGBA8)
	var plate: Color = lk.get("plate", Color("fbf6ec"))
	var seam: Color = lk.get("seam", Color("d6b26a"))
	img.fill(plate.darkened(0.25))
	var ao: = _ao_overlay()
	var gut: = int(round(0.035 * CELL))
	var inner: = CELL - gut * 2
	for f in GRID * GRID:
		var ox: = (f % GRID) * CELL
		var oy: = (f / GRID) * CELL
		img.fill_rect(Rect2i(ox + gut, oy + gut, inner, inner), plate)
		if f < 36:
			var src: Image = _face_image(f)
			if src:
				var h: = inner - 4
				var w: = int(round(h * float(src.get_width()) / float(src.get_height())))
				src.resize(w, h, Image.INTERPOLATE_LANCZOS)
				img.blend_rect(src, Rect2i(0, 0, w, h), Vector2i(ox + (CELL - w) / 2, oy + gut + 2))
		img.blend_rect(ao, Rect2i(0, 0, CELL, CELL), Vector2i(ox, oy))
		# a hairline seam (gold, 35 %) just inside the visible edge — the plate's lacquer rim
		var sc: = Color(seam, 0.42)
		for k in inner:
			for e in [Vector2i(ox + gut + k, oy + gut + 1), Vector2i(ox + gut + k, oy + CELL - gut - 2),
				Vector2i(ox + gut + 1, oy + gut + k), Vector2i(ox + CELL - gut - 2, oy + gut + k)]:
				img.set_pixelv(e, img.get_pixelv(e).blend(sc))
	img.generate_mipmaps()
	var tex: = ImageTexture.create_from_image(img)
	_atlas[key] = tex
	bake_ms = Time.get_ticks_msec() - t0
	return tex


static func _face_image(f: int) -> Image:
	var tex: Texture2D = G.tile_tex(f)
	if tex == null:
		return null
	var im: = tex.get_image()
	if im == null:
		return null
	if im.is_compressed():
		im.decompress()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	return im


# fake ambient occlusion of a cube face: darker towards the four edges and much darker in the corners
static func _ao_overlay() -> Image:
	var im: = Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var gut: = 0.035 * CELL
	for y in CELL:
		for x in CELL:
			var dx: = minf(x - gut, CELL - 1 - gut - x)
			var dy: = minf(y - gut, CELL - 1 - gut - y)
			var ex: = clampf(1.0 - dx / 15.0, 0.0, 1.0)
			var ey: = clampf(1.0 - dy / 15.0, 0.0, 1.0)
			var a: = 0.30 * ex * ex + 0.30 * ey * ey + 0.18 * ex * ey
			im.set_pixel(x, y, Color(0.06, 0.03, 0.05, clampf(a, 0.0, 0.62)))
	return im


# ── mesh ─────────────────────────────────────────────────────────────────────

# outward normal → (right, up) of the face as seen from outside, symbol upright (y up; top/bottom read from the front)
const FACES: = [
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
]


static func cube_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: = 0.5
	var w: = 0.5 - CHAMFER
	for fd in FACES:
		var n: Vector3 = fd[0]
		var u: Vector3 = fd[1]
		var v: Vector3 = fd[2]
		var p00: = n * h - u * w + v * w
		var p10: = n * h + u * w + v * w
		var p11: = n * h + u * w - v * w
		var p01: = n * h - u * w - v * w
		var col: = Color(1, 1, 0, 1)
		_tri(st, [p00, p10, p11], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], n, col)
		_tri(st, [p00, p11, p01], [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)], n, col)
	var axes: = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	# 12 edge strips
	for i in 6:
		for j in range(i + 1, 6):
			var n1: Vector3 = axes[i]
			var n2: Vector3 = axes[j]
			if absf(n1.dot(n2)) > 0.5:
				continue
			var e: = n1.cross(n2).normalized()
			var nn: = (n1 + n2).normalized()
			var a0: = n1 * h + n2 * w - e * w
			var a1: = n1 * h + n2 * w + e * w
			var b0: = n2 * h + n1 * w - e * w
			var b1: = n2 * h + n1 * w + e * w
			var c: = Color(0, 0.86, 0, 1)
			var ue: = Vector2(-1.0, -0.86)
			_tri(st, [a0, a1, b1], [ue, ue, ue], nn, c)
			_tri(st, [a0, b1, b0], [ue, ue, ue], nn, c)
	# 8 corners
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var nx: = Vector3(sx, 0, 0)
				var ny: = Vector3(0, sy, 0)
				var nz: = Vector3(0, 0, sz)
				var a: = nx * h + ny * w + nz * w
				var b: = ny * h + nx * w + nz * w
				var cc: = nz * h + nx * w + ny * w
				var uc: = Vector2(-1.0, -0.7)
				_tri(st, [a, b, cc], [uc, uc, uc], (nx + ny + nz).normalized(),
					Color(0, 0.7, 0, 1))
	_mesh = st.commit()
	return _mesh


# a triangle wound clockwise as seen from outside (Godot's front face), flat normal
static func _tri(st: SurfaceTool, p: Array, uv: Array, n: Vector3, c: Color) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var cc: Vector3 = p[2]
	var ua: Vector2 = uv[0]
	var ub: Vector2 = uv[1]
	var uc: Vector2 = uv[2]
	if (b - a).cross(cc - a).dot(n) > 0.0:
		var t: = b
		b = cc
		cc = t
		var tu: = ub
		ub = uc
		uc = tu
	for k in 3:
		st.set_normal(n)
		st.set_color(c)
		st.set_uv([ua, ub, uc][k])
		st.add_vertex([a, b, cc][k])


static func material(lk: Dictionary, accent: Color, opts: = {}) -> ShaderMaterial:
	var m: = ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	m.set_shader_parameter("atlas", atlas(lk))
	m.set_shader_parameter("body_col", Color(lk.get("side", Color("3f9c7c"))))
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("cells", float(GRID))
	m.set_shader_parameter("show_free", 1.0 if bool(opts.get("show_free", true)) else 0.0)
	m.set_shader_parameter("pulse_on", 0.0 if bool(opts.get("fx_min", false)) else 1.0)
	return m


static func id_material() -> ShaderMaterial:
	if _id_mat:
		return _id_mat
	var sh: = Shader.new()
	sh.code = ID_SHADER
	_id_mat = ShaderMaterial.new()
	_id_mat.shader = sh
	return _id_mat
