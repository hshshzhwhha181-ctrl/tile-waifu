class_name V10TowerUI
extends RefCounted

# Shared kit of the tower screens (Пагода Луны, Странствие, веер карт, свиток проклятий, HUD партии).
# Built on HUD v2 «Тишина и лак» (V10DS tokens, V10Type roles, V10Plate, V10Button, V10Header, V10Icons) and
# UX_RULES. Owned by the lane lead: other files of the track call it and never edit it (ask for additions).
#
# Rules every tower screen follows (UX_RULES §3.4, §3.7, §6):
#   - exactly 1 node with meta ux_role = "primary" (Подняться / Начать забег / Продолжить),
#     <= 2 "secondary" (Правила, …), <= 2 "tertiary" (?, ⋯); set with V10TowerUI.role(node, "primary")
#   - colours only from V10DS / this file; text through V10Type (≥ 18 px, Overline 15 only caps);
#   - every tap through V10TowerUI.tap(node) (V9Feel spring + sound + haptic), hit zones ≥ 80 px;
#   - one infinite UI animation per screen (the «Игра» button breath); everything else is event-driven;
#   - respect fx level: V10TowerUI.fx() in ["full", "mid", "min"]; at "min" motion becomes a 120 ms fade.

const ART: = preload("res://scripts/v10/tower/ui/tower_art.gd")

# ---- tower colours (derived from the DS palette; the only hex literals of the tower UI live here)
const LACQUER: = Color("#1E1418")       # curse card: dark lacquer
const LACQUER_HI: = Color("#2C1C22")
const SEAL: = Color("#C8463C")          # cinnabar seal (UX §6.2 «cinnabar», only stamps / curse seals)
const SEAL_DEEP: = Color("#7E231D")
const EMBER_LO: = Color("#7A2E1E")      # heat embers along the screen edge
const EMBER_HI: = Color("#F0A35A")
const LANTERN_LIT: = Color("#F6C26B")   # a lit lantern
const LANTERN_GLOW: = Color("#FFB45A")
const LANTERN_OUT: = Color("#4A3B3F")   # a lantern that went out
const HEART_FULL: = Color("#E58C9E")
const HEART_EMPTY: = Color("#3D3038")
const MOON: = Color("#F3E6C4")
const PAPER_INK: = Color("#2A2024")     # ink on washi paper (Journey scroll)
const PAPER_BG: = Color("#E9DCC4")      # washi paper fallback colour

# ---------------------------------------------------------------- ux roles, taps, sounds

static func role(n: Node, r: String) -> Node:
	n.set_meta("ux_role", r)
	return n

static func tap(n: CanvasItem, snd: = "pop") -> void:
	if n and is_instance_valid(n):
		V9Feel.press(n, snd)

static func deny(n: CanvasItem) -> void:
	if n and is_instance_valid(n):
		V9Feel.deny(n)

# tower sound by key (V10TowerArt.SFX) with a fallback to the shared banks
static func sfx(key: String, fallback: = "pop", pitch: = 1.0, db: = 0.0) -> void:
	var st: = ART.sound(key)
	var ml: = Engine.get_main_loop()
	if st and ml is SceneTree:
		var p: = AudioStreamPlayer.new()
		p.stream = st
		p.pitch_scale = pitch
		p.volume_db = db
		p.bus = "Master"
		(ml as SceneTree).root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		return
	V10Hud2Util.sfx(fallback)

static func haptic(kind: = "button") -> void:
	V9Feel.haptic(kind)

# screen music: «Пагода» (эрху, дрон, 60) / «Странствие» (сякухати, ветер, 84) through V10Music when merged
static func music(track: String) -> void:
	V10Hud2Util.music("play", [track])

static func fx() -> String:
	return V10Hud2Util.fx_level()

static func calm() -> bool:
	return fx() == "min"

static func insets(vs: Vector2) -> Dictionary:
	return V10Hud2Util.safe_insets(vs)

# ---------------------------------------------------------------- rewards and save

# Rewards of the tower ({gems, coins, petals, tickets, pass_xp}). The logic modules never credit anything; the
# tower screens call grant() once per result. The integrator points grant_hook at V10Wallet / V10Pass
# (func(reward: Dictionary, src: String)); until then the 0.9 save keys are used.
static var grant_hook: = Callable()

static func grant(reward: Dictionary, src: String) -> void:
	if reward.is_empty():
		return
	if grant_hook.is_valid():
		grant_hook.call(reward, src)
		return
	var S: Dictionary = G.S
	for k in ["gems", "coins", "petals", "tickets"]:
		if int(reward.get(k, 0)) > 0:
			S[k] = int(S.get(k, 0)) + int(reward[k])
	if int(reward.get("pass_xp", 0)) > 0 and G.has_method("add_pass_xp"):
		G.add_pass_xp(int(reward.pass_xp))

# README §8: save right after a lantern / heart is lost, after a Journey start and after a floor / board clear
static func save_now() -> void:
	if G.has_method("save"):
		G.save()

# reward tokens for a result window (≤ 3 shown, UX §9 P0-3): [[key, amount, caption]]
const REWARD_NAMES: = {"gems": "кристаллы", "coins": "монеты", "petals": "лепестки", "tickets": "билет желания", "pass_xp": "опыт сезона"}

static func reward_tokens(reward: Dictionary, max_n: = 3) -> Array:
	var out: = []
	for k in ["tickets", "gems", "petals", "coins", "pass_xp"]:
		if int(reward.get(k, 0)) > 0 and out.size() < max_n:
			out.append([k, int(reward[k]), String(REWARD_NAMES[k])])
	return out

# ---------------------------------------------------------------- text

static func label(text: String, role_name: String, size: int, color: Color = V10DS.PAPER_100, on_art: = false) -> Label:
	return V10Type.label(text, role_name, size, color, on_art)

# UI names by UX_RULES §4.2: the engine data may still say «ульта» / «богиня» / «лихорадка»
static func ui_text(s: String) -> String:
	var rep: = [["Ульте", "Приёму"], ["ульте", "приёму"], ["Ульта", "Приём"], ["ульта", "приём"], ["Ульты", "Приёма"],
		["ульты", "приёма"], ["Ульту", "Приём"], ["ульту", "приём"], ["богини", "героини"], ["Богини", "Героини"],
		["богиня", "героиня"], ["Богиня", "Героиня"], ["богинь", "героинь"], ["лихорадк", "Азарт"]]
	for r in rep:
		s = s.replace(String(r[0]), String(r[1]))
	return s

static func heat_color(h: int) -> Color:
	var k: = clampf(float(h) / 34.0, 0.0, 1.0)
	return V10DS.GOLD_300.lerp(EMBER_HI, minf(1.0, k * 2.0)).lerp(SEAL, maxf(0.0, k * 2.0 - 1.0))

# ---------------------------------------------------------------- vector glyphs (procedural fallbacks)

# a paper lantern: lit 0..1 (0 = went out), centre at c, total height h
static func draw_lantern(ci: CanvasItem, c: Vector2, h: float, lit: float, accent: = LANTERN_GLOW) -> void:
	var w: = h * 0.62
	if lit > 0.01:
		var g: = accent
		for i in 4:
			var rr: = w * (1.25 + 0.35 * i)
			ci.draw_circle(c, rr, Color(g.r, g.g, g.b, 0.06 * lit))
	var body: = LANTERN_OUT.lerp(LANTERN_LIT, clampf(lit, 0.0, 1.0))
	var top: = c + Vector2(0, -h * 0.5)
	# cap and string
	ci.draw_line(top + Vector2(0, -h * 0.12), top, V10DS.GOLD_700, 2.0, true)
	ci.draw_rect(Rect2(top.x - w * 0.28, top.y, w * 0.56, h * 0.08), V10DS.NIGHT_600)
	# body: an ellipse of ribs
	var pts: = PackedVector2Array()
	for i in 33:
		var a: = TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.36))
	ci.draw_colored_polygon(pts, body)
	var rib: = Color(V10DS.NIGHT_900, 0.25 + 0.2 * (1.0 - lit))
	for k in [-0.25, 0.0, 0.25]:
		var x: float = c.x + w * 0.5 * float(k) * 1.6
		ci.draw_line(Vector2(x, c.y - h * 0.34), Vector2(x, c.y + h * 0.34), rib, 1.5, true)
	ci.draw_rect(Rect2(c.x - w * 0.28, c.y + h * 0.36, w * 0.56, h * 0.08), V10DS.NIGHT_600)
	# tassel
	ci.draw_line(c + Vector2(0, h * 0.44), c + Vector2(0, h * 0.56), Color(SEAL, 0.5 + 0.5 * lit), 2.0, true)

# a heart (Journey): full / empty; broken = the crack line
static func draw_heart(ci: CanvasItem, c: Vector2, s: float, full: bool, broken: = false) -> void:
	var pts: = PackedVector2Array()
	for i in 41:
		var t: = TAU * float(i) / 40.0
		var x: = 16.0 * pow(sin(t), 3)
		var y: = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * (s / 34.0))
	ci.draw_colored_polygon(pts, HEART_FULL if full else HEART_EMPTY)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(V10DS.PAPER_100, 0.35 if full else 0.18), 1.5, true)
	if broken:
		var k: = s / 34.0
		var crack: = PackedVector2Array([c + Vector2(-1, -10) * k, c + Vector2(3, -3) * k, c + Vector2(-3, 3) * k, c + Vector2(2, 10) * k])
		ci.draw_polyline(crack, V10DS.NIGHT_900, 2.5, true)

# a cinnabar seal (curse card, hanko stamp): rounded square with an inner frame
static func draw_seal(ci: CanvasItem, c: Vector2, r: float, col: = SEAL) -> void:
	var rc: = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	ci.draw_rect(rc, col)
	ci.draw_rect(rc.grow(-r * 0.14), Color(V10DS.PAPER_100, 0.55), false, maxf(1.5, r * 0.06))

# an ember (the heat glyph) when the heat.png icon is missing
static func draw_ember(ci: CanvasItem, c: Vector2, s: float, col: = EMBER_HI) -> void:
	var pts: = PackedVector2Array([c + Vector2(0, -s * 0.55), c + Vector2(s * 0.32, -s * 0.05), c + Vector2(s * 0.22, s * 0.38),
		c + Vector2(0, s * 0.5), c + Vector2(-s * 0.22, s * 0.38), c + Vector2(-s * 0.32, -s * 0.05)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(0, s * 0.18), s * 0.16, V10DS.GOLD_300)

# a Control that draws with a Callable(ci: CanvasItem, size: Vector2) — the tower's tiny «View»
class Glyph extends Control:
	var painter: Callable
	func _init(p: Callable, sz: Vector2) -> void:
		painter = p
		custom_minimum_size = sz
		size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self, size)

static func glyph(p: Callable, sz: Vector2) -> Control:
	return Glyph.new(p, sz)

# texture or procedural fallback (e.g. a curse icon): returns a TextureRect when the art exists
static func art_or(key: String, sz: Vector2, fallback: Callable) -> Control:
	var t: = ART.tex(key)
	if t:
		var tr: = TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = sz
		tr.custom_minimum_size = sz
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	return glyph(fallback, sz)

# ---------------------------------------------------------------- audit helper (selftests, shot runners)

# counts ux roles under a root (visible nodes only): {"primary": n, "secondary": n, "tertiary": n}
static func roles_of(root: Node) -> Dictionary:
	var out: = {"primary": 0, "secondary": 0, "tertiary": 0}
	_walk_roles(root, out)
	return out

static func _walk_roles(n: Node, out: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n.has_meta("ux_role"):
		var r: = String(n.get_meta("ux_role"))
		if out.has(r):
			out[r] = int(out[r]) + 1
	for c in n.get_children():
		_walk_roles(c, out)
