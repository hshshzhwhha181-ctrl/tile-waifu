class_name V10MetaUI
extends RefCounted

# Small UI kit of the meta components (docs/UX_RULES.md §6, docs/HUD_V2.md §2–§3).
#
# PALETTE — the token values of UX_RULES §6.2. These are the ONLY colour literals of lane meta: when V10DS
# (v10-hud2, `v10/design/tokens.gd`) lands, the integrator points each const at it (V10DS.NIGHT_800 …) and nothing
# else in the lane changes.
# TYPE — the closed scale of HUD_V2 §3: Display 32 (H2 / «Игра» button), Body 22, Caption 18 (minimum for any text),
# Overline 15 (caps only), Numerals 22. Text is set without outline (HUD_V2 §3: «Обводки нет нигде»).
#
#   V10MetaUI.text(t, size, color, kind = "body", weight = 800) -> Label
#   V10MetaUI.plate(rect, fill = NIGHT_800, alpha = 0.92, hair = true) -> Panel   HUD_V2 §2.2 surface: radius 4, no
#        border, no shadow, one gold.700 hairline at α 0.35 along the top edge (inset 12)
#   V10MetaUI.role(node, "primary" | "secondary" | "tertiary")      the `ux_role` meta of UX_RULES §3.4 (П-1)
#   V10MetaUI.TextButton.make(text, rect, size = 22) -> TextButton  class «Вторичная» (UX §6.5): paper.100 text with a
#        chevron, no box, hit zone = rect (≥ 80 high); signal pressed; .lbl
#   V10MetaUI.enter(node, offset, delay)   «Вдох» entrance; at fx_level=min only a 120 ms fade (UX §6.7)
#   V10MetaUI.trim(label, size) / keep(label, size) / refit(root)   ellipsis that survives entering the tree
#   Audit helpers for the selftests and the runner (UX_RULES §10 «А» items before --ux_selftest exists):
#   roles(root) -> {primary, secondary, tertiary} · font_sizes(root) -> Array · texts(root) -> Array ·
#   small_hits(root, min = 80) -> Array (tappable nodes smaller than the hit minimum) · tappables(root) -> Array
#
# trim(): a Label with OVERRUN_TRIM_ELLIPSIS whose size is set BEFORE it enters the tree grows back to its full
# text width on enter (Godot 4.5: the stale minimum size wins), so the ellipsis never shows and the text runs off
# the card. trim() remembers the wanted size; refit(root) re-applies it once the component is in the tree.

const NIGHT_900: = Color("121014")
const NIGHT_800: = Color("1B171C")
const NIGHT_700: = Color("26212A")
const NIGHT_600: = Color("332C36")
const PAPER_100: = Color("F5EAD8")
const PAPER_300: = Color("DDD2C4")
const PAPER_500: = Color("B3A89C")
const PAPER_700: = Color("7E756D")
const GOLD_300: = Color("F1D9A0")
const GOLD_500: = Color("E8C47E")
const GOLD_700: = Color("A87B3A")
const ROSE_300: = Color("ECC0C9")
const ROSE_500: = Color("D796A5")
const JADE_300: = Color("A9D9C4")
const JADE_500: = Color("5B9580")
const CINNABAR: = Color("C8463C")
const HAIR_A: = 0.35

const FS_DISPLAY: = 32
const FS_H3: = 26
const FS_BODY: = 22
const FS_CAPTION: = 18
const FS_OVERLINE: = 15
const HIT_MIN: = 80.0
const RADIUS: = 4

const META: = "v10_trim_size"
const ROLE: = "ux_role"


class TextButton extends Control:
	signal pressed
	var lbl: Label

	static func make(t: String, r: Rect2, size_px: int = 22) -> TextButton:
		var b: = TextButton.new()
		b.position = r.position
		b.size = r.size
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pivot_offset = r.size * 0.5
		b.lbl = V10MetaUI.text("%s  ›" % t, size_px, V10MetaUI.PAPER_100, "body", 800)
		b.lbl.size = r.size
		b.lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(b.lbl)
		return b

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			V9Feel.press(self)
			pressed.emit()
			accept_event()


static func text(t: String, size_px: int, color: Color, kind: = "body", weight: = 800) -> Label:
	return UI.label(t, size_px, color, Color(0, 0, 0, 0), 0, kind, weight)


static func plate(r: Rect2, fill: Color = NIGHT_800, alpha: float = 0.92, hair: bool = true) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(fill, alpha)
	sb.set_corner_radius_all(RADIUS)
	sb.set_border_width_all(0)
	p.add_theme_stylebox_override("panel", sb)
	if hair:
		var ln: = ColorRect.new()
		ln.name = "Hair"
		ln.color = Color(GOLD_700, HAIR_A)
		ln.position = Vector2(12, 0)
		ln.size = Vector2(maxf(0.0, r.size.x - 24), 1)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ln)
	return p


static func role(n: Node, r: String) -> Node:
	if n != null:
		n.set_meta(ROLE, r)
	return n


static func enter(n: CanvasItem, offset: Vector2, delay: float = 0.0, dur: float = 0.35) -> void:
	if n == null:
		return
	if V9Feel.can_fx():
		UI.slide_in(n, offset, delay, dur)
		return
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, 0.12).set_delay(delay)


static func trim(l: Label, sz: Vector2) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size = sz
	l.set_meta(META, sz)
	return l


# same for a wrapped caption (autowrap): only remembers and re-applies the size
static func keep(l: Label, sz: Vector2) -> Label:
	l.size = sz
	l.set_meta(META, sz)
	return l


static func refit(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is Label and root.has_meta(META):
		(root as Label).size = root.get_meta(META)
	for c in root.get_children():
		refit(c)


# ── audit helpers (selftests, runner) ──────────────────────────────────────────────────────────────────────────

static func _shown(n: Node) -> bool:
	return not (n is CanvasItem) or (n as CanvasItem).visible


static func _walk(n: Node, out: Array) -> void:
	if not _shown(n):
		return
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


static func roles(root: Node) -> Dictionary:
	var d: = {"primary": 0, "secondary": 0, "tertiary": 0}
	var all: = []
	_walk(root, all)
	for n in all:
		if n.has_meta(ROLE):
			var r: = str(n.get_meta(ROLE))
			d[r] = int(d.get(r, 0)) + 1
	return d


static func font_sizes(root: Node) -> Array:
	var out: = []
	var all: = []
	_walk(root, all)
	for n in all:
		if n is Label and (n as Label).text.strip_edges() != "" and (n as Label).label_settings != null:
			var fs: = (n as Label).label_settings.font_size
			if not (fs in out):
				out.append(fs)
	out.sort()
	return out


static func texts(root: Node) -> Array:
	var out: = []
	var all: = []
	_walk(root, all)
	for n in all:
		if n is Label and (n as Label).text.strip_edges() != "":
			out.append((n as Label).text)
	return out


static func is_tappable(n: Node) -> bool:
	if n is BaseButton or n is JButton or n is TextButton:
		return true
	return n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP and \
		(n as Control).gui_input.get_connections().size() > 0


static func tappables(root: Node) -> Array:
	var out: = []
	var all: = []
	_walk(root, all)
	for n in all:
		if is_tappable(n):
			out.append(n)
	return out


# tappable nodes whose hit zone is under `min_px` on a side (JButton: its own hit_rect; others: their rect)
static func small_hits(root: Node, min_px: float = HIT_MIN) -> Array:
	var out: = []
	for n in tappables(root):
		var r: Rect2 = (n as JButton).hit_rect() if n is JButton else Rect2(Vector2.ZERO, (n as Control).size)
		if n.has_meta("v10_hit"):
			r = n.get_meta("v10_hit")
		if r.size.x < min_px - 0.5 or r.size.y < min_px - 0.5:
			out.append("%s %dx%d" % [n.name, int(r.size.x), int(r.size.y)])
	return out
