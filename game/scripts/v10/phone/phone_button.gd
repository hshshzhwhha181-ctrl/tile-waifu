class_name V10PhoneButton
extends Control

# The home «Телефон» button (replaces «Письма», §Р8 п.1): a small lacquered phone with the partner's colour glow,
# a red badge = letters + chats waiting + new posts, a soft «buzz» wiggle every few seconds while something is unread.
#   home.gd (integrator):  add_child(V10PhoneButton.make(main, Rect2(x, y, 112, 128)))
# Tap → V10Phone.open(main). refresh() re-reads the badge (call on home_built / day_rolled / after a match).

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")

var main
var body: Control
var badge: Control
var _t: = 0.0


static func make(m, r: Rect2) -> V10PhoneButton:
	var b: = V10PhoneButton.new()
	b.main = m
	b.position = r.position
	b.size = r.size
	b.name = "PhoneButton"
	b._build()
	return b


func _build() -> void:
	pivot_offset = size * 0.5
	body = Control.new()
	body.size = size
	body.pivot_offset = Vector2(size.x * 0.5, size.y * 0.8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var pw: = size.x * 0.52
	var ph: = size.y * 0.7
	var px: = (size.x - pw) * 0.5
	var hc: = P.hero_color(str(G.S.get("partner", "mc")))
	# lacquered body with a gold rim, a glowing screen in the partner's colour, a speaker slit
	body.add_child(PUI.panel(Rect2(px, 2, pw, ph), PUI.box(PUI.LACQUER_A, 14, 3.0, PUI.GOLD, 12, Color(hc, 0.5))))
	body.add_child(PUI.panel(Rect2(px + 6, 14, pw - 12, ph - 22), PUI.box(hc.darkened(0.25), 9, 1.0, Color(1, 1, 1, 0.25))))
	body.add_child(PUI.panel(Rect2(px + pw * 0.5 - 9, 6, 18, 4), PUI.box(Color(0, 0, 0, 0.6), 2)))
	var heart: = PUI.label("♥", int(pw * 0.5), Color(1, 1, 1, 0.95), PUI.body(900), 3, Color(0.3, 0.05, 0.12, 0.5))
	heart.position = Vector2(px, 4)
	heart.size = Vector2(pw, ph)
	heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(heart)
	var cap: = PUI.label("Телефон", 19, PUI.TEXT, PUI.body(900), 4, Color(0.1, 0.03, 0.07, 0.85))
	cap.position = Vector2(-10, ph + 10)
	cap.size = Vector2(size.x + 20, 28)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cap)
	PUI.tap(self, func(): P.open(main, {}), "pop")
	refresh()


func refresh() -> void:
	if badge != null and is_instance_valid(badge):
		remove_child(badge)
		badge.queue_free()
	badge = PUI.badge(P.badge(), Vector2(size.x * 0.78 + 6, 8))
	add_child(badge)


func _process(dt: float) -> void:
	if badge == null or not badge.visible:
		return
	_t += dt
	# every 4 s a short «buzz»: the phone wiggles twice (never while the effects are set to minimum)
	if _t >= 4.0:
		_t = 0.0
		if V9Feel.can_fx():
			var t: = body.create_tween()
			for a in [0.09, -0.09, 0.06, -0.04, 0.0]:
				t.tween_property(body, "rotation", a, 0.06)
