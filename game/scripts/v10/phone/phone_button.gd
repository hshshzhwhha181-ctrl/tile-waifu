class_name V10PhoneButton
extends Control

# The home «Телефон» button (replaces «Письма», §Р8 п.1): a small lacquered phone with the partner's colour glow and
# the one number badge of the game (UX_RULES §3.6: rose.300, до 9, дальше «9+») = letters + chats waiting + new posts.
# A quiet icon of the Чайная (role tertiary, §3.4). The badge never pulses and the button never wiggles (§3.6 п.6, §6.7).
#   home.gd (integrator):  add_child(V10PhoneButton.make(main, Rect2(x, y, 112, 128)))
# Tap → V10Phone.open(main). refresh() re-reads the badge (call on home_built / day_rolled / after a match).

const P: = preload("res://scripts/v10/phone/phone.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")

var main
var body: Control
var badge: Control


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
	PUI.role(self, "tertiary")
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
	var cap: = PUI.label("Телефон", PUI.FS_CAPTION, PUI.TEXT, PUI.body(900), 4, Color(0.1, 0.03, 0.07, 0.85))
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

