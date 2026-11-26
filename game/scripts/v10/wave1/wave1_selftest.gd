extends Node

# wave1_selftest.gd — comprehensive verification of the Five Wave-1 Goddesses module (v10/wave1):
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/wave1/wave1_selftest.tscn -- --wave1_selftest=1

var _pass: = 0
var _fail: = 0
var _fails: Array[String] = []


func _ready() -> void:
	run_all()


func _ck(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		_fails.append(label)
		print("  FAIL: ", label)


func _ck_empty(errs: Array, prefix: String) -> void:
	if errs.is_empty():
		_pass += 1
	else:
		_fail += 1
		var msg: = "%s (%d): %s" % [prefix, errs.size(), "; ".join(errs.slice(0, 5))]
		_fails.append(msg)
		print("  FAIL: ", msg)


func run_all() -> void:
	print("=== WAVE1 SELFTEST START ===")
	_test_facade_and_idempotency()
	_test_ranks_outfits_sfw_legwear()
	_test_assets_and_alpha()
	_test_submodules()
	_test_look_and_zlata_ssr_hud()
	_test_global_lint_zero_banned()
	var total: = _pass + _fail
	print("WAVE1_SELFTEST %d/%d" % [_pass, total])
	V10W1Core.reload()
	V10W1Social.reload()
	V10Wave1.reset_for_test()
	if _fail > 0:
		for f in _fails:
			push_error("WAVE1_SELFTEST FAIL: " + f)
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _test_facade_and_idempotency() -> void:
	V10Wave1.reset_for_test()
	var c0: = V10Wave1.count()
	_ck(int(c0.get("heroes", 0)) == 5 and V10Wave1.hero_count() == 5, "count: 5 wave-1 heroines")
	_ck(int(c0.get("outfits", 0)) == 18 and V10Wave1.outfit_count() == 18, "count: 18 outfits")
	_ck(int(c0.get("legwear", 0)) == 18, "count: 18 LW legwear entries")
	_ck(int(c0.get("passives", 0)) == 5 and int(c0.get("ults", 0)) == 18, "count: 5 passives + 18 ults")
	_ck(int(c0.get("kits", 0)) == 5 and int(c0.get("themes", 0)) == 4, "count: 5 kits + 4 tile themes")
	_ck(int(c0.get("banners", 0)) == 12, "count: 12 banner phases")
	_ck(int(c0.get("emotions", 0)) == 25 and int(c0.get("poses", 0)) == 19, "count: 25 emotions + 19 poses")
	_ck(int(c0.get("bday_sigs", 0)) == 5 and int(c0.get("chat_threads", 0)) == 70, "count: 5 bday sigs + 70 chat threads")
	_ck(int(c0.get("stickers", 0)) == 40 and int(c0.get("feed", 0)) == 20 and int(c0.get("voiced_lines", 0)) == 120, "count: 40 stickers + 20 feed + 120 voiced lines")

	var g: = get_tree().root.get_node_or_null("G")
	_ck(g != null, "autoload G present")
	var founders_before: Array = []
	for h in V10Wave1.FOUNDERS:
		founders_before.append(String(g.HEROES[h].name))

	var r1: = V10Wave1.install(g)
	var n_items_1: int = g.ITEMS.size()
	var n_map_1: int = g.ITEM.size()
	var r2: = V10Wave1.register_all(g)
	var r3: = V10Wave1.install(g)
	_ck(bool(r1.get("installed", false)) and bool(r2.get("installed", false)) and bool(r3.get("installed", false)), "V10Wave1.install / register_all succeed")
	_ck(g.ITEMS.size() == n_items_1 and g.ITEM.size() == n_map_1, "V10Wave1.install is 100% idempotent across 3 calls")

	var founders_after: Array = []
	for h in V10Wave1.FOUNDERS:
		founders_after.append(String(g.HEROES[h].name))
	_ck(founders_before == founders_after, "founder HEROES untouched")
	_ck(V10Wave1.heroes().size() == 10 and V10Wave1.hero_order().size() == 10, "merged runtime view has 10 heroines (5 founders + 5 wave-1)")
	_ck(V10Wave1.hero_order().slice(0, 5) == V10Wave1.FOUNDERS and V10Wave1.hero_order().slice(5, 10) == V10Wave1.HERO_ORDER, "hero_order preserves founders then wave-1")

	# Banner activation flag toggle
	var base_b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(V10W1Gacha.BASE_PATH))
	V10Wave1.set_banners_enabled(false)
	_ck(not V10Wave1.banners_enabled() and not V10Wave1.banners(base_b).has("w1"), "set_banners_enabled(false) keeps base banners")
	V10Wave1.set_banners_enabled(true)
	_ck(V10Wave1.banners_enabled() and V10Wave1.banners(base_b).has("w1"), "set_banners_enabled(true) splices wave-1 banners")

	# Save sanitization when unreleased
	var fake_save: = {"partner": "zlata", "level_partner": "tsubame", "profile": {"avatar": "kohaku"}}
	var reset_n: = V10W1Core.sanitize_save(fake_save, g.HEROES)
	_ck(reset_n == 3 and fake_save.partner == "mc" and fake_save.level_partner == "mc" and fake_save.profile.avatar == "mc", "sanitize_save resets wave-1 pointers when off")

	# Overlay merge into mutable copies
	var ov: = V10Wave1.install_into({
		"heroes": g.HEROES.duplicate(true), "hero_order": g.HERO_ORDER.duplicate(),
		"base_outfits": g.BASE_OUTFITS.duplicate(), "items": [], "item_map": {},
		"kits": V10KitData.KITS.duplicate(true), "extra_outfits": V10KitData.EXTRA_OUTFITS.duplicate(true),
		"themes": V10TileTheme.THEMES.duplicate(true), "tables": V10TileTheme.TABLES.duplicate(true),
		"passives": V7Passives.DATA.duplicate(true), "ults": {},
	})
	_ck(ov.heroes.size() == 10 and ov.hero_order.size() == 10 and ov.base_outfits.size() == 10 and ov.items.size() == 18 and ov.ults.size() == 18, "install_into populates all overlay tables")


func _test_ranks_outfits_sfw_legwear() -> void:
	var g: = get_tree().root.get_node_or_null("G")
	var want_ranks: = {"tsubame": "A", "miel": "A", "kohaku": "S", "shirin": "S", "zlata": "SSR"}
	for h in V10Wave1.HERO_ORDER:
		_ck(String(V10W1Core.facts(h).get("rank", "")) == want_ranks[h], "hero rank %s = %s" % [h, want_ranks[h]])
		_ck(V10Wave1.dar_line(h).begins_with("Дар: ") and V10Wave1.dar_line(h).length() > 8, "dar_line(%s) formatted as Дар" % h)
		_ck(V10ProfileCos.has("fr_g_" + h, "frame"), "avatar frame fr_g_%s registered in V10ProfileCos" % h)

	var want_lw: = {
		"tb_base": "LW33", "tb_post": "LW34", "tb_crimson": "LW35",
		"me_base": "LW36", "me_parlor": "LW37", "me_gala": "LW38",
		"ko_base": "LW48", "ko_matsuri": "LW49", "ko_kyubi": "LW50", "ko_vow": "LW51",
		"sh_base": "LW52", "sh_oasis": "LW53", "sh_sun": "LW54", "sh_night": "LW55",
		"zl_base": "LW68", "zl_fair": "LW69", "zl_ember": "LW70", "zl_vow": "LW71",
	}
	for id in want_lw:
		var sid: = String(id)
		var it: Dictionary = g.ITEM.get(sid, {})
		var lw: Dictionary = V10Wave1.legwear(sid)
		_ck(not it.is_empty() and String(it.get("lw", "")) == want_lw[sid] and String(lw.get("code", "")) == want_lw[sid], "outfit %s registered with %s" % [sid, want_lw[sid]])
		var expect_sfw: bool = sid != "ko_kyubi"
		_ck(bool(it.get("sfw", true)) == expect_sfw and bool(lw.get("sfw", true)) == expect_sfw, "outfit %s sfw=%s" % [sid, str(expect_sfw)])
	_ck(String(g.ITEM.ko_kyubi.get("alt", "")) == "ko_matsuri" and bool(g.ITEM.ko_kyubi.get("bold", false)), "ko_kyubi bold + alt=ko_matsuri")


func _img_of(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var im: = tex.get_image()
	if im != null and im.is_compressed():
		im.decompress()
	return im


func _test_assets_and_alpha() -> void:
	# 1. 18 outfit cards (850x1280 + valid face_rect & alt_rect)
	for it in V10W1Core.ITEMS:
		var id: = String(it.id)
		var p: = V10W1Core.outfit_tex_path(id)
		var tex: = load(p) as Texture2D
		var fr: = V10W1Core.outfit_rect(id, "face_rect")
		var ar: = V10W1Core.outfit_rect(id, "alt_rect")
		_ck(tex != null and tex.get_width() == 850 and tex.get_height() == 1280 and fr.size.x >= 180.0 and ar.size.y > fr.size.y, "outfit tex + rects %s" % id)

	# 2. 5 hero full-body cutouts (848x1264 RGBA with real alpha silhouette)
	for h in V10Wave1.HERO_ORDER:
		var tex: = load(V10W1Core.hero_tex_path(h)) as Texture2D
		var im: = _img_of(tex)
		var used: = im.get_used_rect() if im != null else Rect2i()
		var has_alpha: = im != null and im.detect_alpha() != Image.ALPHA_NONE and used.size.x > 250 and used.size.y > 900
		_ck(tex != null and tex.get_width() == 848 and tex.get_height() == 1264 and has_alpha, "hero RGBA cutout %s" % h)

	# 3. 25 emotion portraits (5 heroes x 5 emotions: height=800, width<=600, RGBA alpha)
	V10W1Core.reload()
	var ef_all: = V10W1Core.emo_face()
	var efw_all: = V10W1Core.emo_face_w()
	for h in V10Wave1.HERO_ORDER:
		for emo in V10W1Core.EMOTIONS:
			var p: = V10W1Core.emotion_path(h, emo)
			var tex: = load(p) as Texture2D
			var im: = _img_of(tex)
			var has_alpha: = im != null and im.detect_alpha() != Image.ALPHA_NONE and im.get_used_rect().size.y > 500
			var fp: Array = ef_all.get(h, {}).get(emo, [])
			var fw: float = float(efw_all.get(h, {}).get(emo, 0.0))
			_ck(tex != null and tex.get_height() == 800 and tex.get_width() <= 600 and has_alpha and fp.size() == 2 and fw > 80.0, "emotion RGBA + face %s_%s" % [h, emo])

	# 4. 19 pose slots (5 idle + 14 extra slots, height=1280)
	var pose_count: = 0
	for h in V10Wave1.HERO_ORDER:
		var sh: = String(h)
		for s in V10W1Core.poses(sh):
			var ss: = String(s)
			var tex: = load(V10W1Core.pose_path(sh, ss)) as Texture2D
			var pr: = V10W1Core.pose_face_rect(sh, ss)
			_ck(tex != null and tex.get_height() == 1280 and pr.size.x > 0.0, "pose tex + face_rect %s_%s" % [sh, ss])
			pose_count += 1
	_ck(pose_count == 19, "all 19 pose slots verified")

	# 5. 4 look tile emblems + 5 birthday sig medallions
	for th_id in V10W1Look.THEMES:
		var ep: = String(V10W1Look.THEMES[th_id].get("emblem", ""))
		var tex: = load(ep) as Texture2D
		var im: = _img_of(tex)
		_ck(tex != null and im != null and im.detect_alpha() != Image.ALPHA_NONE, "look emblem RGBA %s" % th_id)
	for h in V10Wave1.HERO_ORDER:
		var sp: = V10Wave1.bday_sig(h)
		var tex: = load(sp) as Texture2D
		var im: = _img_of(tex)
		_ck(tex != null and tex.get_width() >= 64 and im != null and im.detect_alpha() != Image.ALPHA_NONE, "bday sig RGBA %s" % h)


func _test_submodules() -> void:
	var g: = get_tree().root.get_node_or_null("G")
	_ck_empty(V10W1Core.selfcheck(true), "V10W1Core.selfcheck(true)")
	_ck_empty(V10W1Play.self_check(), "V10W1Play.self_check()")
	_ck_empty(V10W1Ults.problems(true), "V10W1Ults.problems(true)")
	_ck_empty(V10W1Home.self_check(), "V10W1Home.self_check()")
	_ck_empty(V10W1Social.problems(true), "V10W1Social.problems(true)")
	_ck_empty(V10W1Mj.selftest(), "V10W1Mj.selftest()")
	_ck_empty(V10W1Look.selfcheck(false), "V10W1Look.selfcheck(false)")

	for row in V10W1Gacha.selfcheck(g.ITEMS):
		_ck(bool(row.get("ok", false)), "V10W1Gacha: " + String(row.get("name", "")))
	for row in V10W1Audio.selfcheck():
		_ck(bool(row.get("ok", false)), "V10W1Audio: " + String(row.get("name", "")))


func _test_look_and_zlata_ssr_hud() -> void:
	# Zlata SSR HUD skin, Ruslan Display + Kurale font pair, stings, and 4 outfit palettes
	var zk: = V10Wave1.kit("zlata")
	_ck(String(zk.get("rank", "")) == "SSR" and String(zk.get("hud", "")) == "zlata" and String(zk.get("font", "")) == "zlata" and String(zk.get("sting", "")) == "zlata", "zlata SSR kit carries hud + font + sting")
	_ck(V10HudSkinData.SKINS.has("zlata") and ResourceLoader.exists("res://assets/v10/look/zlata/menu_bg.webp"), "zlata HUD skin + menu_bg exist")
	var pals: Dictionary = V10HudSkinData.SKINS.zlata.get("palettes", {})
	for oid in ["zl_base", "zl_fair", "zl_ember", "zl_vow"]:
		var pk: = String(zk.get("palettes", {}).get(oid, ""))
		_ck(pals.has(pk), "zlata HUD palette for %s (%s)" % [oid, pk])
	# A->S lift on tb_crimson and me_gala
	_ck(V10Wave1.kit("tsubame").get("up", {}).has("tb_crimson") and V10Wave1.kit("miel").get("up", {}).has("me_gala"), "A heroines lift kit on SSR outfit")


func _collect_all_strings() -> Array[String]:
	var out: Array[String] = []
	for h in V10Wave1.HERO_ORDER:
		var hr: = V10W1Core.hero(h)
		for k in ["name", "title", "age", "job"]:
			out.append(String(hr.get(k, "")))
		out.append(String(V10W1Core.facts(h).get("element", "")))
	for it in V10W1Core.ITEMS:
		out.append(String(it.get("name", "")))
		out.append(String(V10W1Core.legwear(String(it.id)).get("ru", "")))
	for s in V10W1Play.all_texts():
		out.append(String(s))
	for s in V10W1Ults.texts():
		out.append(String(s))
	for row in V10W1Home.strings():
		out.append(String(row[1]))
	for s in V10W1Social.all_texts():
		out.append(String(s))
	for s in V10W1Mj.all_texts():
		out.append(String(s))
	for s in V10W1Look.texts():
		out.append(String(s))
	for s in V10W1Gacha.texts():
		out.append(String(s))
	for s in V10W1Audio.texts():
		out.append(String(s))
	return out


func _test_global_lint_zero_banned() -> void:
	var all_s: = _collect_all_strings()
	_ck(all_s.size() >= 2500, "collected %d visible strings across all 12 wave-1 modules" % all_s.size())
	var banned_hits: Array[String] = []
	var ui_hits: Array[String] = []
	for s in all_s:
		var b: = V10Lint.check(s)
		if not b.is_empty():
			banned_hits.append("«%s» -> %s" % [s, str(b)])
		var u: = V10Lint.ui_check(s)
		if not u.is_empty():
			ui_hits.append("«%s» -> %s" % [s, str(u)])
	_ck_empty(banned_hits, "V10Lint.BANNED across all wave-1 strings")
	_ck_empty(ui_hits, "V10Lint.UI_BANNED across all wave-1 strings")
