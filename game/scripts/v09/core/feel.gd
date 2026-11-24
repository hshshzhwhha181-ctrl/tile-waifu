class_name V9Feel
extends RefCounted

# V9Feel — 0.9 single feedback service (docs/0.9-spec.md §A). Every tap answer in the game goes through here, so
# «всё приятно нажимается» is tuned in one place. Static: no autoload, call it from anywhere.
#
# PRESS (a finger on something tappable)
#   V9Feel.press(node, sound = "pop", haptic = "button")    one-shot tap: dip to 0.94 and spring back to 1.0,
#                                                           click sound, light vibration. Control or Node2D.
#   V9Feel.press_down(node)                                 two-phase press (JButton): dip + vibration on touch
#   V9Feel.press_up(node, fire, sound = "pop")              release: spring back (overshoot when fired) + click
#   V9Feel.deny(node)                                       a disabled / not-free target: short «no» shake,
#                                                           deny sound and haptic (no scale)
# RESULTS
#   V9Feel.success(node = null, sound = "sparkle", strength = 1.0)   pop up 1.0→1.08→1.0, bright sound, «match» haptic
#   V9Feel.fail(node = null, sound = "deny")                         shake, low sound, «fail» haptic
#   V9Feel.big(node = null, sound = "summon_boom")                    punch 1.0→1.15→1.0, heavy haptic pattern
#   Each of them takes node = null to play only sound + haptic; sound = "" for haptic only.
# TILES (board owners call these instead of Sfx/V7Haptics directly; tiles animate their own lift/fly, so no scale)
#   V9Feel.tile_tap(ok)                   select click (pitch jitter) + «select» haptic, or deny sound + haptic
#   V9Feel.tile_match(combo, gold = false)     pitch-ladder chime (Sfx.combo_step) + combo haptic
#   A board that routes its feedback here sets board.set_meta("v9_feel", true): V7Haptics then stops adding its own
#   board haptics, so nothing vibrates twice.
# HAPTIC / SOUND primitives
#   V9Feel.haptic(kind)                   V7Haptics.kind(kind) when the autoload is there (headless-safe)
#   V9Feel.sound(name, pitch = 1, db = 0) Sfx.play
# EFFECT LEVEL GATES (S.fx_level, settings «Эффекты»)
#   V9Feel.level() -> "full" | "mid" | "min"
#   V9Feel.can_shake()        full only (screen shake)
#   V9Feel.can_edge_flash()   full only (flashes at the screen edges)
#   V9Feel.can_fx()           full and mid (particles, auras, glows, cut-in decor); min = press feedback only
#   V9Feel.fx_scale() -> float  particle count / intensity multiplier: full 1.0, mid 0.55, min 0.0
#   Press, deny, success, fail and big scale/sound/haptic always play: they are the press response that «минимум»
#   keeps. Their extra flourishes (big's shake) follow the gates.

const PRESS_SCALE: = 0.94
const PRESS_IN: = 0.06
const SPRING: = 0.32
const META_BASE: = "v9_feel_base"
const META_TW: = "v9_feel_tw"
const META_POS: = "v9_feel_pos"


static func level() -> String:
	return G.fx_level()


static func can_shake() -> bool:
	return level() == "full"


static func can_edge_flash() -> bool:
	return level() == "full"


static func can_fx() -> bool:
	return level() != "min"


static func fx_scale() -> float:
	match level():
		"mid":
			return 0.55
		"min":
			return 0.0
	return 1.0


# the process frame of the last V9Feel haptic: V7Haptics' generic card hook skips its light pulse in that frame,
# so a press or deny routed here is never overridden (or doubled) by the catch-all tap pulse
static var haptic_frame: = -1

static func haptic(kind: String) -> void :
	haptic_frame = Engine.get_process_frames()
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var hp = tree.root.get_node_or_null("V7Haptics")
	if hp:
		hp.kind(kind)


static func sound(name: String, pitch: = 1.0, db: = 0.0) -> void :
	if name == "":
		return
	var tree: = Engine.get_main_loop() as SceneTree
	var sfx = tree.root.get_node_or_null("Sfx") if tree else null
	if sfx:
		sfx.play(name, pitch, db)


# ── scale helpers: a node keeps its resting scale in meta, so repeated taps never drift ─────────────────────────

static func _base(node: CanvasItem) -> Vector2:
	if not node.has_meta(META_BASE):
		node.set_meta(META_BASE, node.scale)
	return node.get_meta(META_BASE)


# keep_base: the press is still held (press_down), so the resting scale must survive this tween's end
static func _tween(node: CanvasItem, keep_base: = false) -> Tween:
	if node.has_meta(META_TW):
		var old = node.get_meta(META_TW)
		if old is Tween and old.is_valid():
			old.kill()
	var t: = node.create_tween()
	node.set_meta(META_TW, t)
	if keep_base:
		return t
	t.finished.connect( func():
		if is_instance_valid(node):
			node.remove_meta(META_TW)
			node.remove_meta(META_BASE))
	return t


static func _centre(node: CanvasItem) -> void :
	if node is Control and node.pivot_offset == Vector2.ZERO:
		node.pivot_offset = node.size * 0.5


static func _ok(node) -> bool:
	return node != null and is_instance_valid(node) and node is CanvasItem and node.is_inside_tree()


static func press(node: CanvasItem, snd: = "pop", hap: = "button") -> void :
	haptic(hap)
	sound(snd, randf_range(0.96, 1.06))
	if not _ok(node):
		return
	_centre(node)
	var b: = _base(node)
	var t: = _tween(node)
	t.tween_property(node, "scale", b * PRESS_SCALE, PRESS_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", b, SPRING).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func press_down(node: CanvasItem) -> void :
	haptic("button")
	if not _ok(node):
		return
	_centre(node)
	var b: = _base(node)
	var t: = _tween(node, true)
	t.tween_property(node, "scale", b * PRESS_SCALE, PRESS_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func press_up(node: CanvasItem, fire: bool, snd: = "pop") -> void :
	if fire:
		sound(snd, randf_range(0.96, 1.06))
	if not _ok(node):
		return
	var b: = _base(node)
	var t: = _tween(node)
	if fire:
		t.tween_property(node, "scale", b * 1.03, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", b, SPRING).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func deny(node: CanvasItem) -> void :
	# one deny per node per frame: a gated JButton already denied this tap, so its owner's own deny is a no-op
	if node != null and is_instance_valid(node):
		var f: = Engine.get_process_frames()
		if int(node.get_meta("v9_deny_frame", -1)) == f:
			return
		node.set_meta("v9_deny_frame", f)
	sound("deny")
	haptic("deny")
	if not _ok(node):
		return
	_shake(node, [-6.0, 6.0, -4.0, 3.0, 0.0], 0.036)


static func _shake(node: CanvasItem, steps: Array, dt: float) -> void :
	if node.has_meta(META_POS):
		var old = node.get_meta(META_POS)
		if old[1] is Tween and old[1].is_valid():
			old[1].kill()
		node.position.x = old[0]
	var x0: float = node.position.x
	var t: = node.create_tween()
	node.set_meta(META_POS, [x0, t])
	for dx in steps:
		t.tween_property(node, "position:x", x0 + dx, dt)
	t.finished.connect( func():
		if is_instance_valid(node):
			node.remove_meta(META_POS))


static func success(node: CanvasItem = null, snd: = "sparkle", strength: = 1.0) -> void :
	haptic("match")
	sound(snd, 1.0 + 0.06 * (strength - 1.0))
	if not _ok(node):
		return
	_centre(node)
	var b: = _base(node)
	var t: = _tween(node)
	t.tween_property(node, "scale", b * (1.0 + 0.08 * strength), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", b, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func fail(node: CanvasItem = null, snd: = "deny") -> void :
	haptic("fail")
	sound(snd, 0.85)
	if not _ok(node):
		return
	_shake(node, [-10.0, 9.0, -7.0, 5.0, -2.0, 0.0], 0.04)


static func big(node: CanvasItem = null, snd: = "summon_boom") -> void :
	haptic("ssr")
	sound(snd)
	if _ok(node):
		_centre(node)
		var b: = _base(node)
		var t: = _tween(node)
		t.tween_property(node, "scale", b * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "scale", b, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if can_shake():
		var tree: = Engine.get_main_loop() as SceneTree
		var fx = tree.root.get_node_or_null("V6Fx") if tree else null
		if fx and fx.has_method("shake"):
			fx.shake(0.25)


# set around a replayed tap whose touch was already acknowledged (short ult clip buffer): no second click / haptic
static var quiet_tile_tap: = false

static func tile_tap(ok: bool) -> void :
	if ok and quiet_tile_tap:
		return
	if ok:
		sound("select", randf_range(0.96, 1.06))
		haptic("select")
	else:
		sound("deny")
		haptic("deny")


static func tile_match(combo: int, gold: = false) -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	var sfx = tree.root.get_node_or_null("Sfx") if tree else null
	if sfx:
		sfx.combo_step(combo)
	var hp = tree.root.get_node_or_null("V7Haptics") if tree else null
	if hp:
		hp.combo(combo, gold)
