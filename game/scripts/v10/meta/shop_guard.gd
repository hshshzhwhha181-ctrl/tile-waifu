class_name V10ShopGuard
extends RefCounted

# V10ShopGuard — the shop fuse (docs/0.10-spec.md M1 Ф7). In 0.9 `shop._buy()` hands out crystals for free behind
# «79 ₽ … 7 490 ₽» buttons. Until RuStore Pay (1.0) a STORE build must not show a single ₽ button; a TEST build keeps
# them with a red «ТЕСТ» plaque so testers know nothing is charged.
#
#   V10ShopGuard.build() -> "store" | "test"     feature tags of the export preset: tw_store → store, tw_test → test;
#                                                no tag: the editor / a debug run → test, ANY release export → store
#                                                (safe default: an APK built from an old preset never sells for free)
#   V10ShopGuard.rub_allowed() -> bool           ₽ buttons may be shown (test build)
#   V10ShopGuard.can_buy() -> bool               shop._buy() starts with `if not V10ShopGuard.can_buy(): return`
#   V10ShopGuard.guard(root) -> int              walks a built screen: store → hides every ₽ button and puts a grey
#                                                «Скоро» in its place (denies: «Покупки откроются с выходом игры в
#                                                RuStore») and hides the 0.9 caption «Тестовая версия: покупки
#                                                бесплатные…» (false in a store build); test → adds the «ТЕСТ» plaque
#                                                to each. Returns how many ₽ buttons it touched. Idempotent.
#                                                Call it on every built shop body AND on every popup that can sell
#                                                (pass popup, the 0.9 starter offer V8Starter.popup) — see README.
#   V10ShopGuard.test_notes(root) -> Array       visible 0.9 «test build» captions under root (selftest: 0 in store)
#   V10ShopGuard.visible_rub(root) -> Array      visible tappable ₽ controls (selftest: 0 in store)
#   V10ShopGuard.force(mode) / unforce()         dev / selftests
#
# Export presets (integrator, export_presets.cfg — two copies of «Android»):
#   [preset.N] name="Android-store" … custom_features="tw_store"
#   [preset.M] name="Android-test"  … custom_features="tw_test"

const T_TEST: = "ТЕСТ"
const T_SOON: = "Скоро"
const T_SOON_HINT: = "Покупки откроются с выходом игры в RuStore"
const META_DONE: = "v10_shop_guard"

static var _force: = ""


static func force(mode: String) -> void:
	_force = mode


static func unforce() -> void:
	_force = ""


static func build() -> String:
	if _force != "":
		return _force
	if OS.has_feature("tw_store"):
		return "store"
	if OS.has_feature("tw_test"):
		return "test"
	if OS.has_feature("editor") or OS.is_debug_build():
		return "test"
	return "store"


static func rub_allowed() -> bool:
	return build() != "store"


static func can_buy() -> bool:
	return rub_allowed()


static func is_rub(text: String) -> bool:
	if text.find("₽") >= 0:
		return true
	var low: = text.to_lower()
	var i: = low.find("руб")
	return i > 0 and low.substr(0, i).strip_edges().right(1).is_valid_int()


static func _texts(n: Node, out: Array, depth: = 0) -> void:
	if depth > 4:
		return
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out, depth + 1)


static func _has_rub(n: Node) -> bool:
	var t: = []
	_texts(n, t)
	for s in t:
		if is_rub(str(s)):
			return true
	return false


static func _tappable(n: Node) -> bool:
	return n is BaseButton or n is JButton or (n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP and
		(n.get_script() != null or (n as Control).gui_input.get_connections().size() > 0))


# ₽ controls: tappable nodes whose own captions (not a sub-tree card) carry a ruble price
static func rub_buttons(root: Node) -> Array:
	var out: = []
	_walk(root, out)
	return out


static func _walk(n: Node, out: Array) -> void:
	if _tappable(n) and n != null and _own_rub(n):
		out.append(n)
		return
	for c in n.get_children():
		_walk(c, out)


static func _own_rub(n: Node) -> bool:
	if n is JButton:
		var jb: JButton = n
		for l in [jb.lbl, jb.sub]:
			if l != null and is_rub(l.text):
				return true
		return false
	if n is Button:
		return is_rub((n as Button).text)
	return _has_rub(n)


static func visible_rub(root: Node) -> Array:
	var out: = []
	for b in rub_buttons(root):
		if b is CanvasItem and (b as CanvasItem).is_visible_in_tree():
			out.append(b)
	return out


# the 0.9 captions that only make sense in a test build («Тестовая версия: покупки бесплатные, реальная оплата
# отключена», V6Txt shop.test_note)
static func _is_test_note(t: String) -> bool:
	return t != "" and t == V6Txt.s("shop.test_note")


static func test_notes(root: Node) -> Array:
	var out: = []
	_notes(root, out)
	return out


static func _notes(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label and _is_test_note((n as Label).text):
		out.append(n)
	for c in n.get_children():
		_notes(c, out)


static func guard(root: Node) -> int:
	var n: = 0
	var store: = not rub_allowed()
	if store:
		for l in test_notes(root):
			(l as CanvasItem).visible = false
	for b in rub_buttons(root):
		var c: Control = b
		if c.has_meta(META_DONE):
			continue
		c.set_meta(META_DONE, true)
		n += 1
		if store:
			c.visible = false
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_soon(c)
		else:
			_plaque(c)
	return n


# in place of a hidden ₽ button: a grey «Скоро» of the same size — no dead card, no hole in the layout; a tap
# denies (shake, deny sound) and says why through the `denied` signal → toast T_SOON_HINT
static func _soon(btn: Control) -> void:
	var p: = btn.get_parent()
	if p == null:
		return
	var fs: = 22
	if btn is JButton and (btn as JButton).lbl != null:
		fs = mini(26, (btn as JButton).lbl.label_settings.font_size)
	var jb: = JButton.make(T_SOON, "graphite", Rect2(btn.position, btn.size), null, fs)
	jb.name = "V10Soon"
	jb.disabled = true
	jb.denied.connect(func():
		var tree: = Engine.get_main_loop() as SceneTree
		var main = tree.current_scene if tree else null
		if main != null and main.has_method("toast"):
			main.toast(T_SOON_HINT, "lock"))
	p.add_child(jb)
	p.move_child(jb, btn.get_index() + 1)


static func _plaque(c: Control) -> void:
	# Overline 15 (caps, UX §6.3) — the smallest size the type scale allows
	var fs: = 15
	var tw: = UI.font("body", 900).get_string_size(T_TEST, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var pl: = V10MetaUI.plate(Rect2(-6, -12, tw, 24), V10MetaUI.NIGHT_900, 0.95, false)
	pl.name = "V10TestPlaque"
	pl.rotation = deg_to_rad(-6.0)
	var l: = V10MetaUI.text(T_TEST, fs, V10MetaUI.GOLD_500, "body", 900)
	l.size = pl.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_child(l)
	c.add_child(pl)
