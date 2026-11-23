class_name V8ProfileSelftest
extends RefCounted

# Run: godot --headless --path . -- --profile_selftest=1   (exit code 1 on failure)
# Uses user://selftest/profile_save.json; the real save and G.S are restored afterwards.

static var fails: = 0
static var total: = 0


static func ok(c: bool, m: String) -> void :
	total += 1
	if not c:
		fails += 1
		printerr("FAIL " + m)


static func _press(page: Control, text: String) -> void :
	for c in page.get_children():
		if c is JButton and c.lbl and c.lbl.text == text:
			c.pressed.emit()


static func run(main) -> int:
	fails = 0
	total = 0
	var keep: Dictionary = G.S
	var keep_path: String = G.save_path
	var keep_ok: bool = G._main_ok
	DirAccess.make_dir_recursive_absolute("user://selftest")
	G.save_path = "user://selftest/profile_save.json"
	# nick generators
	var bad: = 0
	for i in 500:
		if G.nick_error(V8Nicks.random()) != "":
			bad += 1
		if G.nick_error(V8ProfileUI.random_nick()) != "":
			bad += 1
	ok(bad == 0, "1000 random nicks valid")
	ok(V8Nicks.from_seed(5) == V8Nicks.from_seed(5), "from_seed deterministic")
	# card flow
	G.S = G.default_state()
	G.S.rp = 333
	var host: = Control.new()
	host.size = Vector2(720, 1280)
	main.add_child(host)
	var card: = V8ProfileCard.make(null, host)
	card.nick_le.text = "  "
	card._on_play()
	ok(not G.S.profile_done, "blank nick rejected")
	ok(card.hint_lbl.text == "Введи ник", "error shown: " + card.hint_lbl.text)
	card.nick_le.text = "Ab"
	card._on_play()
	ok(not G.S.profile_done, "short nick rejected")
	card.avatars.select("yue")
	card._on_pick("yue")
	card.nick_le.text = "  Тест   Ник "
	card._on_play()
	ok(G.S.profile_done and G.S.profile.nick == "Тест Ник" and G.S.profile.avatar == "yue", "profile saved: %s/%s" % [G.S.profile.nick, G.S.profile.avatar])
	# avatar row + title chip build without errors
	ok(V8ProfileUI.title_chip(Rect2(0, 0, 720, 64)).get_child_count() >= 4, "title chip")
	# code import via card
	var code: String = V8Recovery.export_code()
	var other: Dictionary = G.default_state()
	other.profile_done = false
	other.intro_done = true
	other.rp = 77
	var code07: String = V8Recovery.export_code(other)
	G.S = G.default_state()
	var card2: = V8ProfileCard.make(null, host)
	card2._show_code()
	var te: TextEdit = null
	for c in card2.page_code.get_children():
		if c is TextEdit:
			te = c
	ok(te != null, "code field present")
	te.text = "TW8-garbage"
	_press(card2.page_code, "Перенести прогресс")
	ok(not card2.imported and card2.page_code != null, "bad code rejected")
	te.text = code07
	_press(card2.page_code, "Перенести прогресс")
	ok(card2.imported and int(G.S.rp) == 77 and not card2._done, "0.7 code imported, card stays for nick")
	ok(card2.page_main.visible, "back on main page")
	card2.nick_le.text = "Новый"
	card2._on_play()
	ok(G.S.profile_done and int(G.S.rp) == 77, "nick set after import")
	G.S = G.default_state()
	var card3: = V8ProfileCard.make(null, host)
	card3._show_code()
	for c in card3.page_code.get_children():
		if c is TextEdit:
			c.text = code
	_press(card3.page_code, "Перенести прогресс")
	ok(card3.imported and card3._done and int(G.S.rp) == 333 and G.S.profile.nick == "Тест Ник", "full code import finishes card")
	host.queue_free()
	G.S = keep
	G.save_path = keep_path
	G._main_ok = keep_ok
	printerr("PROFILE SELFTEST %d/%d" % [total - fails, total])
	return fails
