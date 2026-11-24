extends Node

# Profile 2.0 preview renderer (does not touch main.gd or the save). Renders sample cards into PNGs:
#   flock /tmp/tw-godot.lock xvfb-run -a -s "-screen 0 1600x1200x24" /opt/tw-tools/godot --path game \
#     --rendering-driver opengl3 --audio-driver Dummy res://scripts/v10/profile/card_preview.tscn -- --out=<dir>
# Writes card_1_celestial.png, card_2_gold.png, card_3_sim.png (mode other), card_own.png, rows.png, frames.png,
# sheet.png. Needs a real renderer (xvfb), not --headless. Flag --wait=<s> changes the capture delay (default 1.8 s,
# after the reveal animation).

const BG: = Color("17121a")


func _args() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a


static func samples() -> Array:
	var a: = {
		"v": 1, "nick": "ЛуннаяЛиса", "avatar": "yue", "frame": "fr_rank_5", "title": "t_rank_5",
		"badges": ["b_rank_5", "b_combo_15", "b_legend"], "card_bg": "cb_palace",
		"showcase": {"hero": "yue", "outfit": "y_queen", "pose": "base"}, "rank": {"tier": 5, "sub": 2}, "league": 5,
		"stats": {"heroes": 5, "heroes_total": 20, "games_week": 214, "best_combo": 17}, "ostars": 4, "tile": "s_night", "sim": false,
	}
	var b: = {
		"v": 1, "nick": "Чайный_Дракон", "avatar": "rin", "frame": "fr_g_rin", "title": "t_combo",
		"badges": ["b_streak_30", "b_heart", "b_summit_1"], "card_bg": "cb_ice",
		"showcase": {"hero": "rin", "outfit": "r_idol", "pose": "base"}, "rank": {"tier": 3, "sub": 1}, "league": 3,
		"stats": {"heroes": 4, "heroes_total": 20, "games_week": 58, "best_combo": 11}, "ostars": 2, "tile": "s_mint", "sim": false,
	}
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261124
	var c: = V10CardPayload.sim(rng, 1, "Ханами")
	c.stats.games_week = 12
	return [a, b, c]


static func own_sample() -> Dictionary:
	return {
		"v": 1, "nick": "Мастер_Ветров", "avatar": "mc", "frame": "fr_legend_1", "title": "t_legend",
		"badges": ["b_first_win", "b_streak_7"], "card_bg": "cb_salon",
		"showcase": {"hero": "mc", "outfit": "o_dragon", "pose": "base"}, "rank": {"tier": 4, "sub": 0}, "league": 4,
		"stats": {"heroes": 5, "heroes_total": 20, "games_week": 77, "best_combo": 13}, "ostars": 5, "tile": "s_gold", "sim": false,
	}


func _ready() -> void:
	var a: = _args()
	var out: = String(a.get("out", "user://profile_cards"))
	DirAccess.make_dir_recursive_absolute(out)
	var wait: = float(a.get("wait", "1.8"))
	# watchdog: a script error must never leave Godot running (and holding the shared lock)
	get_tree().create_timer(wait + 20.0).timeout.connect(func():
		print("PREVIEW TIMEOUT")
		get_tree().quit(3))
	var jobs: = []
	var s: = samples()
	var names: = ["card_1_celestial", "card_2_gold", "card_3_sim"]
	for i in 3:
		print("sample %d validate: '%s' bytes %d" % [i + 1, V10CardPayload.validate(s[i]), V10CardPayload.size_bytes(s[i])])
		jobs.append(_card_vp(s[i], "other", Vector2i(660 + 80, 880 + 80), names[i]))
	var own: = own_sample()
	print("own validate: '%s'" % V10CardPayload.validate(own))
	jobs.append(_card_vp(own, "own", Vector2i(672 + 80, 560 + 80), "card_own"))
	jobs.append(_rows_vp(s, own))
	jobs.append(_frames_vp())
	jobs.append(_editor_vp("frame"))
	jobs.append(_editor_vp("badges"))
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var imgs: = {}
	for j in jobs:
		var img: Image = (j[0] as SubViewport).get_texture().get_image()
		img.save_png(out.path_join(j[1] + ".png"))
		imgs[j[1]] = img
		print("saved ", out.path_join(j[1] + ".png"), " ", img.get_size())
	# contact sheet of the three «other» cards
	var sheet: = Image.create(740 * 3, 960, false, Image.FORMAT_RGBA8)
	for i in 3:
		var im: Image = imgs[names[i]]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(740 * i, 0))
	sheet.resize(int(740 * 3 * 0.6), int(960 * 0.6), Image.INTERPOLATE_LANCZOS)
	sheet.save_png(out.path_join("sheet.png"))
	print("PREVIEW OK")
	get_tree().quit(0)


func _vp(size: Vector2i) -> SubViewport:
	var vp: = SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg: = ColorRect.new()
	bg.color = BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	return vp


func _card_vp(p: Dictionary, mode: String, size: Vector2i, nm: String) -> Array:
	var vp: = _vp(size)
	var c: = V10CardView.make(p, Rect2(40, 40, 0, 0), mode)
	vp.add_child(c)
	return [vp, nm]


func _rows_vp(s: Array, own: Dictionary) -> Array:
	var vp: = _vp(Vector2i(720, 6 * 92 + 40))
	var list: = [own.duplicate(true), s[0], s[1], s[2]]
	list[0]["me"] = true
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	list.append(V10CardPayload.sim(rng, 2, "Кленовый_лист"))
	list.append(V10CardPayload.sim(rng, 0, "Новичок"))
	var pts: = [1840, 1712, 1530, 1204, 990, 410]
	for i in list.size():
		list[i]["pts"] = pts[i]
		var r: = V10CardView.make(list[i], Rect2(20, 20 + i * 92, 680, 84), "row")
		vp.add_child(r)
	return [vp, "rows"]


# every released frame once (the catalog at a glance)
func _frames_vp() -> Array:
	var ids: = []
	for e in V10ProfileCos.all("frame"):
		ids.append(e.id)
	var cols: = 8
	var cell: = 150
	var rows: = int(ceil(ids.size() / float(cols)))
	var vp: = _vp(Vector2i(cols * cell + 20, rows * (cell + 28) + 20))
	var heroes: = ["mc", "rin", "hana", "yue", "nova"]
	for i in ids.size():
		var x: = 10 + (i % cols) * cell
		var y: = 10 + (i / cols) * (cell + 28)
		var f: = V10FrameView.make(ids[i], heroes[i % heroes.size()], cell - 16.0, {"anim": true})
		f.position = Vector2(x + 8, y)
		vp.add_child(f)
		var l: = UI.label(String(V10ProfileCos.entry(ids[i]).name), 13, UI.INK, UI.DARK, 2, "body", 800)
		UI.center_label(l, Rect2(x, y + cell - 12, cell, 22))
		l.clip_text = true
		vp.add_child(l)
	return [vp, "frames"]


func _editor_vp(tab: String) -> Array:
	var vp: = _vp(Vector2i(720, 1280))
	var host: = Control.new()
	host.size = Vector2(720, 1280)
	vp.add_child(host)
	var save: = V10Profile2Selftest.save_mid()
	V10ProfileCos.grant(save, "fr_shop_lotus")
	save.profile.merge({"frame": "fr_g_rin", "title": "t_combo", "badges": ["b_streak_30", "b_first_win"], "card_bg": "cb_ice",
		"showcase": {"hero": "rin", "outfit": "r_idol", "pose": "base"}, "avatar": "rin"}, true)
	save["v10_cos_seen"] = {"fr_g_rin": true, "t_combo": true}
	var ed: = V10CardEditor.open(host, save)
	ed._set_tab(tab)
	return [vp, "editor_" + tab]
