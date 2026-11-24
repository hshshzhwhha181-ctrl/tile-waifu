extends Control

# Standalone runner for the «Телефон» lane (no edits to main.gd needed):
#   godot --path game res://scripts/v10/phone/phone_runner.tscn -- --save=user://phone_save.json --save_wipe=1 [flags]
# flags:
#   --phone_selftest=1        run V10PhoneSelftest and quit (exit code 0 = all passed)
#   --phone_shots=<dir>       scripted tour with screenshots (run under xvfb with --resolution WxH)
#   (none)                    interactive: a seeded save, the phone opened over a home backdrop
# The runner plays the role of `main` for the phone: W, H, overlay, show_chrome(), back(), go(), toast().

const P: = preload("res://scripts/v10/phone/phone.gd")
const C: = preload("res://scripts/v10/chat/chat.gd")
const FEED: = preload("res://scripts/v10/chat/chat_feed.gd")
const ST: = preload("res://scripts/v10/phone/phone_selftest.gd")

var W: = 720.0
var H: = 1280.0
var overlay: Control
var phone: Control
var gained: = {}
var button: Control


func _ready() -> void:
	var vs: = get_viewport_rect().size
	W = vs.x
	H = vs.y
	size = vs
	var args: = OS.get_cmdline_user_args()
	for a in args:
		if a == "--phone_selftest=1":
			_selftest.call_deferred()
			return
	Common.backdrop(self, "menu", size, 0.0, 1.0, Color.WHITE, Vector2(0.5, 0.4))
	button = V10PhoneButton.make(self, Rect2(W - 150, H * 0.52, 112, 128))
	add_child(button)
	overlay = Control.new()
	overlay.size = vs
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	P.log_dir = "user://phone_runner_logs/"
	P.bond_sink = func(h, n, src):
		gained[h] = int(gained.get(h, 0)) + n
		return n
	seed_save()
	button.refresh()
	for a in args:
		if a.begins_with("--phone_shots="):
			_tour.call_deferred(a.substr(14))
			return
	phone = P.open(self, {"tab": "chats"})


func _selftest() -> void:
	var r: Array = await ST.run(self)
	print("PHONE SELFTEST %d/%d" % [r[0], r[1]])
	get_tree().quit(0 if r[0] == r[1] else 1)


# --- the fake main -------------------------------------------------------------------------

func show_chrome(_t: bool, _n: bool) -> void:
	pass


func back() -> void:
	if phone and is_instance_valid(phone):
		phone.queue_free()


func go(id: String, _args: = {}) -> void:
	print("RUNNER go(%s)" % id)


func toast(t: String, _icon: = "") -> void:
	print("RUNNER toast: ", t)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and phone and is_instance_valid(phone):
		phone.back()


# --- a lived-in save: 5 founders, affection 3–6, a week of chats, letters, a month of feed -------

static func seed_save() -> void:
	for h in ["rin", "hana", "yue", "nova"]:
		G.S.shards[h] = 5
	G.S.aff = {"mc": 520, "rin": 340, "hana": 260, "yue": 410, "nova": 230}
	G.S.partner = "mc"
	P.reset()
	P.ensure()
	P.set_player_name("Саша")
	V9Letters.install()
	V9Letters.demo()
	# a month of feed: the pool opened 24 days ago
	P.day_shift = -24
	FEED.visible(P.feed_st(), P.ctx())
	# a week of chats, mostly answered
	for d in range(-7, 0):
		P.day_shift = d
		P.tick()
		if d == -5:
			P.event({"kind": "first_win"})
		if d == -3:
			P.event({"kind": "combo_record", "combo": 12})
		for tid in C.open_threads(P.transport().state):
			if d < -1:
				_finish(tid)
	P.day_shift = 0
	P.tick()
	P.event({"kind": "first_win"})
	G.save()


static func _finish(tid: String) -> void:
	var guard: = 0
	while C.awaiting(P.transport().state, tid) and guard < 20:
		guard += 1
		var r: = P.transport().choose(tid, guard % 2, P.ctx())
		if not r.get("ok", false):
			break
		P.gain(r.get("effects", []))


# --- screenshot tour ----------------------------------------------------------------------------

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var path: = "%s/%dx%d_%s.png" % [dir, int(W), int(H), name]
	img.save_png(path)
	print("SHOT ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.6)
	await _shot(dir, "00_home_button")
	phone = P.open(self, {"tab": "chats"})
	await _wait(0.2)
	await _shot(dir, "00_slide")
	await _wait(0.9)
	await _shot(dir, "01_chats")
	phone.dev_act("name")
	await _wait(0.6)
	await _shot(dir, "02_name")
	phone.dev_act("pick:Саша")
	await _wait(0.5)
	var row: Array = phone.pages.chats.rows()
	var h: String = row[0].hero
	for r in row:
		if r.dot:
			h = r.hero
			break
	phone.dev_act("chat:" + h)
	await _wait(1.1)
	await _shot(dir, "03_typing")
	for i in 30:
		if not phone.chat.busy:
			break
		await _wait(0.4)
	await _wait(0.5)
	await _shot(dir, "04_chat_pills")
	phone.dev_act("pick0")
	await _wait(1.0)
	await _shot(dir, "05_answer_typing")
	for i in 40:
		if not phone.chat.busy:
			break
		await _wait(0.4)
	await _wait(0.6)
	await _shot(dir, "06_after_pick")
	phone.dev_act("react")
	await _wait(0.5)
	await _shot(dir, "07_reactions")
	phone.chat._react(_first_her(phone.chat), "heart", "♥")
	await _wait(0.4)
	phone.dev_act("tray")
	await _wait(0.8)
	await _shot(dir, "08_stickers")
	phone.chat.tray.picked.emit("mc_wink" if h == "mc" else "c_heart")
	phone.chat.tray.dismiss()
	await _wait(2.8)
	await _shot(dir, "09_sticker_sent")
	phone.chat.close()
	await _wait(0.5)
	phone.dev_act("feed")
	await _wait(0.9)
	await _shot(dir, "10_feed")
	phone.dev_act("like")
	await _wait(0.25)
	await _shot(dir, "11_feed_like")
	phone.dev_act("reply")
	await _wait(1.4)
	var fv: Control = phone.pages.feed
	fv.scroll.scroll_vertical = 520
	await _wait(0.3)
	await _shot(dir, "12_feed_reply")
	phone.dev_act("mail")
	await _wait(0.8)
	await _shot(dir, "13_mail")
	phone.dev_act("letter")
	await _wait(0.8)
	await _shot(dir, "14_letter")
	phone.back()
	await _wait(0.5)
	phone.back()
	await _wait(0.6)
	await _shot(dir, "15_closed")
	print("PHONE TOUR OK gained=", gained)
	if is_instance_valid(phone):
		phone.queue_free()
	for n in get_tree().get_nodes_in_group("v10_phone_sfx"):
		n.queue_free()
	# static callables connected to the tree (V9Letters.install) are dropped before quitting
	for c in get_tree().node_added.get_connections():
		get_tree().node_added.disconnect(c.callable)
	await _wait(0.6)
	get_tree().quit(0)


static func _first_her(cv: Control) -> V10Bubble:
	var last: V10Bubble = null
	for c in cv.list.get_children():
		if c is V10Bubble and not c.mine and c.index >= 0 and c.kind == "text":
			last = c
	return last
