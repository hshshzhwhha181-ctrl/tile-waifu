class_name V10MjCubeRelic
extends Node3D

# Реликвия героини в сердцевине Куба (docs/MODES.md §3.4.4, §4.4). Простые меши кодом, без текстур:
#   mc   шпилька          золотой стержень, цветок из пяти лепестков, две подвески
#   rin  чашка            селадоновая чашка с ручкой на блюдце, чай внутри
#   hana эстафетная палочка  оранжевая палочка с золотыми поясками
#   yue  лунное зеркало   серебряный диск в золотом ободе на ручке
#   nova кристалл-ключ    шестигранный кристалл её цвета на золотом ключе
# В сердцевине реликвия медленно вращается и светится её цветом сквозь щели между фишками (эмиссия, без ламп).
# finale_glow(v): 0…1 — вспышка её цветом (не белым, UX §6.7).

const NAMES: = {
	"mc": "Шпилька Маджонг-тян",
	"rin": "Чашка Рин",
	"hana": "Эстафетная палочка Ханы",
	"yue": "Лунное зеркало Юэ",
	"nova": "Кристалл-ключ Новы",
}
const SHORT: = {"mc": "шпилька", "rin": "чашка", "hana": "палочка", "yue": "зеркало", "nova": "кристалл-ключ"}
const COLORS: = {
	"mc": Color("ff8fb8"), "rin": Color("4fbf9f"), "hana": Color("ffb35c"), "yue": Color("c8b6ff"), "nova": Color("4fe3ff"),
}
const GOLD: = Color("e8c47e")

var hero: = "mc"
var accent: = Color.WHITE
var spin: = 0.6
var glow: = 0.0
var _mats: Array[StandardMaterial3D] = []
var _base_em: Array[float] = []
var body: Node3D


# «шпилька Маджонг-тян» — the name inside a sentence
static func lower_name(h: String) -> String:
	var n: String = NAMES.get(h, NAMES.mc)
	return n.substr(0, 1).to_lower() + n.substr(1)


static func make(hero_id: String) -> V10MjCubeRelic:
	var r: = V10MjCubeRelic.new()
	r.build(hero_id)
	return r


func build(hero_id: String) -> void:
	hero = hero_id if NAMES.has(hero_id) else "mc"
	accent = COLORS[hero]
	name = "Relic_" + hero
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	match hero:
		"mc":
			_hairpin()
		"rin":
			_cup()
		"hana":
			_baton()
		"yue":
			_mirror()
		"nova":
			_crystal_key()


func _process(dt: float) -> void:
	if body:
		body.rotate_y(spin * dt)


func _mat(c: Color, metal: = 0.0, rough: = 0.45, em: = 0.0, em_col: = Color.BLACK) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if em > 0.0:
		m.emission_enabled = true
		m.emission = em_col if em_col != Color.BLACK else c
		m.emission_energy_multiplier = em
	_mats.append(m)
	_base_em.append(em)
	return m


func _add(mesh: Mesh, mat: Material, pos: = Vector3.ZERO, rot: = Vector3.ZERO, sc: = Vector3.ONE) -> MeshInstance3D:
	var mi: = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, seg: = 20) -> CylinderMesh:
	var c: = CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _sphere(r: float, seg: = 14) -> SphereMesh:
	var s: = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func _hairpin() -> void:
	var gold: = _mat(GOLD, 0.9, 0.28, 0.35, accent)
	var pink: = _mat(accent, 0.0, 0.4, 0.9)
	var holder: = Node3D.new()
	holder.rotation = Vector3(0, 0, deg_to_rad(-28))
	body.add_child(holder)
	var rod: = MeshInstance3D.new()
	rod.mesh = _cyl(0.028, 0.012, 1.05, 10)
	rod.material_override = gold
	rod.position = Vector3(0, -0.12, 0)
	holder.add_child(rod)
	for k in 5:
		var a: = k * TAU / 5.0
		var p: = MeshInstance3D.new()
		p.mesh = _sphere(0.1, 10)
		p.material_override = pink
		p.position = Vector3(cos(a) * 0.11, 0.44, sin(a) * 0.11)
		p.scale = Vector3(1.0, 0.45, 1.0)
		holder.add_child(p)
	var c: = MeshInstance3D.new()
	c.mesh = _sphere(0.06, 10)
	c.material_override = gold
	c.position = Vector3(0, 0.47, 0)
	holder.add_child(c)
	for k in 2:
		var ch: = MeshInstance3D.new()
		ch.mesh = _cyl(0.006, 0.006, 0.2, 6)
		ch.material_override = gold
		ch.position = Vector3(-0.1 + k * 0.2, 0.32, 0)
		holder.add_child(ch)
		var bead: = MeshInstance3D.new()
		bead.mesh = _sphere(0.04, 8)
		bead.material_override = pink
		bead.position = Vector3(-0.1 + k * 0.2, 0.2, 0)
		holder.add_child(bead)


func _cup() -> void:
	var glaze: = _mat(Color("bfe8d4"), 0.0, 0.22, 0.25, accent)
	var gold: = _mat(GOLD, 0.9, 0.3, 0.2, accent)
	var tea: = _mat(Color("7fae5a"), 0.0, 0.15, 0.6, accent)
	_add(_cyl(0.43, 0.4, 0.04), glaze, Vector3(0, -0.2, 0))
	_add(_cyl(0.3, 0.2, 0.34), glaze, Vector3(0, 0.0, 0))
	_add(_cyl(0.305, 0.305, 0.018), gold, Vector3(0, 0.17, 0))
	_add(_cyl(0.27, 0.27, 0.01), tea, Vector3(0, 0.12, 0))
	var t: = TorusMesh.new()
	t.inner_radius = 0.07
	t.outer_radius = 0.11
	t.rings = 16
	t.ring_segments = 8
	_add(t, glaze, Vector3(0.3, 0.02, 0), Vector3(deg_to_rad(90), 0, 0))


func _baton() -> void:
	var orange: = _mat(accent, 0.15, 0.35, 0.7)
	var gold: = _mat(GOLD, 0.9, 0.25, 0.3, accent)
	var holder: = Node3D.new()
	holder.rotation = Vector3(0, 0, deg_to_rad(-34))
	body.add_child(holder)
	var b: = MeshInstance3D.new()
	b.mesh = _cyl(0.085, 0.085, 0.95, 18)
	b.material_override = orange
	holder.add_child(b)
	for y in [-0.4, -0.3, 0.3, 0.4]:
		var band: = MeshInstance3D.new()
		band.mesh = _cyl(0.092, 0.092, 0.035, 18)
		band.material_override = gold
		band.position = Vector3(0, y, 0)
		holder.add_child(band)


func _mirror() -> void:
	var silver: = _mat(Color("e9e6f6"), 1.0, 0.08, 0.6, accent)
	var gold: = _mat(GOLD, 0.9, 0.3, 0.25, accent)
	var holder: = Node3D.new()
	holder.rotation = Vector3(deg_to_rad(90), 0, 0)
	body.add_child(holder)
	var disc: = MeshInstance3D.new()
	disc.mesh = _cyl(0.34, 0.34, 0.04, 28)
	disc.material_override = silver
	disc.position = Vector3(0, 0, -0.08)
	holder.add_child(disc)
	var rim: = MeshInstance3D.new()
	var t: = TorusMesh.new()
	t.inner_radius = 0.33
	t.outer_radius = 0.39
	t.rings = 28
	t.ring_segments = 8
	rim.mesh = t
	rim.material_override = gold
	rim.position = Vector3(0, 0, -0.08)
	holder.add_child(rim)
	var handle: = MeshInstance3D.new()
	handle.mesh = _cyl(0.045, 0.05, 0.34, 12)
	handle.material_override = gold
	handle.rotation = Vector3(deg_to_rad(-90), 0, 0)
	handle.position = Vector3(0, 0, 0.27)
	holder.add_child(handle)


func _crystal_key() -> void:
	var cry: = _mat(accent.lerp(Color.WHITE, 0.25), 0.0, 0.1, 1.3)
	var gold: = _mat(GOLD, 0.9, 0.28, 0.3, accent)
	_add(_bipyramid(0.17, 0.32, 0.2), cry, Vector3(0, 0.18, 0))
	_add(_cyl(0.035, 0.035, 0.42, 10), gold, Vector3(0, -0.2, 0))
	_add(_cyl(0.07, 0.07, 0.04, 14), gold, Vector3(0, 0.0, 0))
	var bm: = BoxMesh.new()
	bm.size = Vector3(0.12, 0.05, 0.04)
	_add(bm, gold, Vector3(0.07, -0.33, 0))
	_add(bm, gold, Vector3(0.06, -0.24, 0))


# a six-sided double pyramid (the crystal of Nova)
func _bipyramid(r: float, h_top: float, h_bot: float) -> ArrayMesh:
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: = []
	for k in 6:
		var a: = k * TAU / 6.0
		ring.append(Vector3(cos(a) * r, 0, sin(a) * r))
	var top: = Vector3(0, h_top, 0)
	var bot: = Vector3(0, -h_bot, 0)
	for k in 6:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 6]
		for tri in [[top, b, a], [bot, a, b]]:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
			var c: Vector3 = (v0 + v1 + v2) / 3.0
			var t2: Array = tri
			if n.dot(c) > 0.0:
				t2 = [tri[0], tri[2], tri[1]]
				n = -n
			for v in t2:
				st.set_normal(-n)
				st.add_vertex(v)
	return st.commit()


# 0…1: emission flash in her colour (finale)
func finale_glow(v: float) -> void:
	glow = v
	for k in _mats.size():
		var m: = _mats[k]
		if not m.emission_enabled:
			m.emission_enabled = true
			m.emission = accent
		m.emission_energy_multiplier = _base_em[k] + v * 3.2
