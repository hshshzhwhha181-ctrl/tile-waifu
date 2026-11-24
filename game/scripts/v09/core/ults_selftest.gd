class_name V9UltsSelftest
extends RefCounted

# --ults_selftest=1 (G._ready): headless checks of the 0.9 Foundation —
#   V9Ults table (every outfit in G.ITEM, names / lines / palette / art / rects / mods per HEROINES.md §2, §5),
#   charge and cut-in rules, save migration v6 -> v7 and the fx_level / ult_cutin setters, V9Feel gates,
#   the Sfx pitch ladder and music ducking. Prints «ULTS SELFTEST n/m» and quits 0 / 1.
# --ults_overlay=<dir>: contact sheets of every outfit art with face_rect (red) and alt_rect (cyan) drawn on it,
#   to check the measured crops by eye (needs the source .webp files, i.e. a project run, not an exported pack).

static var _pass: = 0
static var _fail: = 0


static func _check(name: String, ok: bool, info: = "") -> void :
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("ULTS FAIL: %s %s" % [name, info])


static func run() -> int:
	_pass = 0
	_fail = 0
	var saved: Dictionary = G.S.duplicate(true)
	_table()
	_charge()
	_cutin()
	_settings()
	_feel()
	_audio()
	G.S = saved
	printerr("ULTS SELFTEST %d/%d" % [_pass, _pass + _fail])
	return _fail


static func _outfits() -> Array:
	var ids: = []
	for id in G.ITEM:
		if String(G.ITEM[id].get("cat", "")) == "outfit":
			ids.append(id)
	return ids


static func _cyr(s: String) -> bool:
	for ch in s:
		var c: = ch.unicode_at(0)
		if c >= 0x0410 and c <= 0x044f:
			return true
	return false


static func _table() -> void :
	var ids: = _outfits()
	_check("23+ outfits known", ids.size() >= 23, str(ids.size()))
	for id in ids:
		_check("ULTS has %s" % id, V9Ults.has(id))
	for id in V9Ults.ULTS:
		_check("%s is an outfit in G.ITEM" % id, G.ITEM.has(id) and G.ITEM[id].cat == "outfit")
	var mods_by_hero: = {}
	for id in V9Ults.ULTS:
		var u: Dictionary = V9Ults.ULTS[id]
		var it: Dictionary = G.ITEM.get(id, {})
		var h: String = u.get("hero", "")
		_check("%s hero matches item" % id, h == String(it.get("hero", "")), h)
		_check("%s name Russian" % id, _cyr(String(u.get("name", ""))))
		var lines: Array = u.get("lines", [])
		_check("%s 2-3 lines" % id, lines.size() >= 2 and lines.size() <= 3, str(lines.size()))
		for ln in lines:
			_check("%s line short Russian «%s»" % [id, ln], _cyr(String(ln)) and String(ln).length() <= 28)
		var pal: Dictionary = u.get("palette", {})
		_check("%s palette main = heroine colour" % id, pal.get("main") is Color and pal.main.is_equal_approx(G.HEROES[h].color))
		_check("%s palette accent + ink" % id, pal.get("accent") is Color and pal.get("ink") is Color and pal.ink.get_luminance() < 0.3)
		var img: String = u.get("ref_img", "")
		_check("%s ref_img is the item art" % id, img == "res://assets/outfits/%s.webp" % String(it.get("img", "")), img)
		_check("%s ref_img exists" % id, ResourceLoader.exists(img), img)
		var key: = img.get_file().get_basename()
		_check("%s rects measured" % id, V9Ults.RECTS.has(key))
		var fr: Rect2 = u.get("face_rect", Rect2())
		var ar: Rect2 = u.get("alt_rect", Rect2())
		var art: = Rect2(Vector2.ZERO, V9Ults.ART_SIZE)
		_check("%s face_rect = RECTS" % id, V9Ults.RECTS.has(key) and fr == V9Ults.RECTS[key][0] and ar == V9Ults.RECTS[key][1])
		_check("%s face_rect inside art, 180-320 px" % id, art.encloses(fr) and fr.size.x >= 180 and fr.size.x <= 320 and is_equal_approx(fr.size.x, fr.size.y), str(fr))
		_check("%s alt_rect inside art, holds the face centre" % id, art.encloses(ar) and ar.has_point(fr.get_center()) and ar.size.y > fr.size.y, str(ar))
		_check("%s face in the upper half" % id, fr.get_center().y < 640.0)
		var m: String = u.get("mod", "?")
		if id in G.BASE_OUTFITS:
			_check("%s base outfit has no mod" % id, m == "")
		else:
			_check("%s mod is one of П/О/Л/В/Ц/С" % id, V9Ults.MODS.has(m), m)
			var seen: Dictionary = mods_by_hero.get(h, {})
			var rar: = String(it.get("rar", ""))
			# §2: no repeat within a heroine; from her 6th outfit a repeat is allowed only from another rarity
			if seen.has(m):
				_check("%s mod %s repeats only across rarities after 5 outfits" % [id, m], seen[m] != rar and seen.size() >= 5)
			seen[m] = rar
			mods_by_hero[h] = seen
		var sfx: String = u.get("sfx", "")
		_check("%s sfx exists" % id, ResourceLoader.exists("res://assets/sfx/%s.wav" % sfx), sfx)
		_check("%s fx key" % id, String(u.get("fx", "")) != "")
	# §5 names spot-check
	_check("names: o_base", V9Ults.get_ult("o_base").name == "Восточный ветер")
	_check("names: o_dragon", V9Ults.get_ult("o_dragon").name == "Пробуждение дракона")
	_check("names: r_idol", V9Ults.get_ult("r_idol").name == "Бис!")
	_check("names: y_ball", V9Ults.get_ult("y_ball").name == "Последний вальс")
	_check("names: n_offline", V9Ults.get_ult("n_offline").name == "Режим офлайн")
	_check("mods: §5 sample", V9Ults.mod("o_dragon") == "Л" and V9Ults.mod("r_agent") == "П" and V9Ults.mod("h_gym") == "С" and V9Ults.mod("y_duel") == "Ц" and V9Ults.mod("n_ssr") == "О")
	for h in G.HERO_ORDER:
		_check("core for %s" % h, V9Ults.CORES.has(h) and _cyr(String(V9Ults.core(h).desc)))
		_check("base ult for %s" % h, V9Ults.has(String(V9Ults.BASE[h])) and V9Ults.BASE[h] in G.BASE_OUTFITS)
	# shown(): hidden and modest swap to alt art with that art's rects
	var t: = V9Ults.shown("o_tutor", false)
	_check("shown: hidden o_tutor draws its alt", t.img.ends_with("mc_base.webp") and t.face_rect == V9Ults.RECTS.mc_base[0], str(t))
	var bm: = V9Ults.shown("h_beach", true)
	_check("shown: modest bold h_beach draws alt", bm.img.ends_with("hana_winter.webp"))
	var bn: = V9Ults.shown("h_beach", false)
	_check("shown: not modest keeps own art", bn.img.ends_with("hana_beach.webp") and bn.face_rect == V9Ults.get_ult("h_beach").face_rect)
	var px: = V9Ults.rect_px(Rect2(859, 1280, 859, 1280), Vector2(720, 1073))
	_check("rect_px scales to texture", px.position.is_equal_approx(Vector2(720, 1073)) and px.size.is_equal_approx(Vector2(720, 1073)))
	_check("line never repeats last", V9Ults.line("o_base", 0) != 0 or V9Ults.get_ult("o_base").lines.size() == 1)
	var last: = -1
	var ok: = true
	for i in 40:
		var k: = V9Ults.line("r_base", last)
		ok = ok and k != last and k >= 0 and k < 3
		last = k
	_check("line: 40 picks without a repeat", ok)
	_check("gold variant: fever / aff 7", V9Ults.gold_variant(true, 1) and V9Ults.gold_variant(false, 7) and not V9Ults.gold_variant(false, 6))
	var gp: = V9Ults.palette("y_base", true)
	_check("gold palette keeps ink, warms main", gp.ink == V9Ults.palette("y_base").ink and gp.main != V9Ults.palette("y_base").main)


static func _charge() -> void :
	_check("need: 8 at affection 1", V9Ults.need(1) == 8)
	_check("need: 7 at affection 4", V9Ults.need(4) == 7)
	_check("need: 5 at affection 10+", V9Ults.need(10) == 5 and V9Ults.need(40) == 5)
	_check("need: never below 5, never above 8", V9Ults.need(0) == 8 and V9Ults.need(-3) == 8)
	_check("need: ranked 6 regardless of affection", V9Ults.need(1, true) == 6 and V9Ults.need(10, true) == 6)
	for lv in range(1, 13):
		_check("need matches 0.6 skill_need at lv %d" % lv, V9Ults.need(lv) == 8 - mini(3, (lv - 1) / 3))
	_check("start: R 0 / SR 2 / SSR 3", V9Ults.start_charge("R") == 0 and V9Ults.start_charge("SR") == 2 and V9Ults.start_charge("SSR") == 3)
	_check("start: ranked 0", V9Ults.start_charge("SSR", true) == 0 and V9Ults.start_charge("SR", true) == 0)
	_check("start: base outfit 0 (y_base, n_base are SR)", V9Ults.start_charge_for("y_base") == 0 and V9Ults.start_charge_for("n_base") == 0)
	_check("start_for: o_dragon SSR 3, o_cafe SR 2", V9Ults.start_charge_for("o_dragon") == 3 and V9Ults.start_charge_for("o_cafe") == 2)
	_check("start_for: ranked 0", V9Ults.start_charge_for("o_dragon", true) == 0)
	_check("gain: +1 per pair, 0 from ult", V9Ults.gain(false) == 1 and V9Ults.gain(true) == 0)
	# 8 pairs from zero fill the bar; ult pairs never charge
	var c: = 0
	var n: = V9Ults.need(1)
	for i in 7:
		c = V9Ults.add(c, n)
		c = V9Ults.add(c, n, true)
	_check("7 pairs (+7 ult pairs) not ready", c == 7 and not V9Ults.is_ready(c, n))
	c = V9Ults.add(c, n)
	_check("8th pair ready", V9Ults.is_ready(c, n))
	c = V9Ults.add(c, n)
	_check("charge capped at need", c == n)
	c = V9Ults.start_charge_for("o_dragon")
	var pairs: = 0
	while not V9Ults.is_ready(c, n) and pairs < 20:
		c = V9Ults.add(c, n)
		pairs += 1
	_check("SSR starts 3 -> ready after 5 pairs", pairs == 5)
	_check("ranked: SSR ready after 6 pairs", _pairs_to_ready(V9Ults.start_charge_for("o_dragon", true), V9Ults.need(10, true)) == 6)
	_check("ready needs need > 0", not V9Ults.is_ready(0, 0))
	_check("auto-cast off in ranked", V9Ults.auto_cast_allowed(false) and not V9Ults.auto_cast_allowed(true))
	_check("ranked: modifiers off", V9Ults.mod("o_dragon", true) == "" and V9Ults.mod("o_dragon", false) == "Л")
	_check("ranked core: Hana 1 pair + 1 reveal", V9Ults.core("hana", true).pairs == 1 and V9Ults.core("hana", true).reveal == 1 and V9Ults.core("hana").pairs == 2)
	_check("ranked core: Rin returns tray + highlights", V9Ults.core("rin", true).return_tray and V9Ults.core("rin", true).get("highlight_pair", false) and not V9Ults.core("rin").has("highlight_pair"))
	_check("core: Rin with empty tray removes a pair", int(V9Ults.core("rin").empty_tray_pairs) == 1)
	_check("core: MT 1 pair, Nova deepest", V9Ults.core("mc").pairs == 1 and V9Ults.core("nova").deepest)
	_check("core table not mutated by ranked merge", not V9Ults.CORES.hana.has("reveal"))
	var targets: = {}
	for h in G.HERO_ORDER:
		targets[h] = V9Ults.core(h).target
	_check("targets per §2", targets == {"mc": "pair", "rin": "none", "hana": "swipe", "yue": "row", "nova": "tier"}, str(targets))
	_check("target window 2 s", is_equal_approx(V9Ults.TARGET_TIME, 2.0))


static func _pairs_to_ready(c: int, n: int) -> int:
	var k: = 0
	while not V9Ults.is_ready(c, n) and k < 50:
		c = V9Ults.add(c, n)
		k += 1
	return k


static func _cutin() -> void :
	_check("cutin: off stays off", V9Ults.cutin_mode("off", false, true) == "off" and V9Ults.cutin_mode("off", true, true) == "off")
	_check("cutin: ranked never full", V9Ults.cutin_mode("full", true, true) == "short")
	_check("cutin: full on first ult of the day", V9Ults.cutin_mode("full", false, true) == "full")
	_check("cutin: full setting, later ults short", V9Ults.cutin_mode("full", false, false) == "short")
	_check("cutin: short setting", V9Ults.cutin_mode("short", false, true) == "short")
	_check("cutin: album always full", V9Ults.cutin_mode("off", false, false, true) == "full")
	_check("clip: R/SR ≈1.33 s", absf(V9Ults.clip_len("SR", "mc") - 1.333) < 0.02 and absf(V9Ults.clip_len("R", "rin") - 1.333) < 0.02)
	_check("clip: SSR ≈2 s", absf(V9Ults.clip_len("SSR", "nova") - 2.0) < 0.02)
	_check("clip: Yue waltz 3 beats ≈1.33 s", V9Ults.beats("SR", "yue") == 3 and absf(V9Ults.clip_len("SR", "yue") - 1.333) < 0.02)
	_check("clip: Yue SSR 6 beats (two bars of 3/4)", V9Ults.beats("SSR", "yue") == 6 and absf(V9Ults.clip_len("SSR", "yue") - 2.0) < 0.02)
	_check("clip: short ≤0.6 s, off 0", V9Ults.clip_len("SSR", "mc", "short") <= 0.6 and V9Ults.clip_len("SSR", "mc", "off") == 0.0)
	_check("flash limits", V9Ults.MAX_FLASHES_PER_S <= 3 and V9Ults.FLASH_MAX <= 0.7)


static func _settings() -> void :
	G.S = G.default_state()
	_check("defaults full / full", G.fx_level() == "full" and G.ult_cutin() == "full" and int(G.S.ver) == 7)
	var v6: = G.default_state()
	v6.ver = 6
	v6.erase("fx_level")
	v6.erase("ult_cutin")
	v6["v6_fx"] = {"shake": false, "flash": false}
	_check("v6 save applies", G.apply_state(JSON.parse_string(JSON.stringify(v6))))
	_check("v6 -> v7: ver 7", int(G.S.ver) == 7)
	_check("v6 -> v7: shake off becomes mid", G.fx_level() == "mid" and G.ult_cutin() == "full")
	v6.v6_fx = {"shake": true}
	G.apply_state(JSON.parse_string(JSON.stringify(v6)))
	_check("v6 -> v7: shake on becomes full", G.fx_level() == "full" and G.S.v6_fx.flash == true)
	v6.erase("v6_fx")
	v6.cutins = false
	G.apply_state(JSON.parse_string(JSON.stringify(v6)))
	_check("v6 -> v7: no fx keys -> full; combo cut-in switch untouched", G.fx_level() == "full" and G.S.cutins == false)
	var bad: = G.default_state()
	bad.fx_level = "ultra"
	bad.ult_cutin = 3
	G.apply_state(JSON.parse_string(JSON.stringify(bad)))
	_check("garbage values fall back to full", G.fx_level() == "full" and G.ult_cutin() == "full")
	var seen: = []
	var cb: = func(k): seen.append(k)
	G.settings_changed.connect(cb)
	G.set_fx_level("min")
	_check("set_fx_level min: shake/flash off", G.fx_level() == "min" and G.S.v6_fx.shake == false and G.S.v6_fx.flash == false)
	G.set_fx_level("full")
	_check("set_fx_level full: shake/flash on", G.S.v6_fx.shake == true and G.S.v6_fx.flash == true)
	G.set_fx_level("bogus")
	_check("set_fx_level ignores unknown", G.fx_level() == "full")
	G.set_ult_cutin("short")
	_check("set_ult_cutin", G.ult_cutin() == "short")
	G.set_ult_cutin("nope")
	_check("set_ult_cutin ignores unknown", G.ult_cutin() == "short")
	G.settings_changed.disconnect(cb)
	_check("settings_changed emitted", seen == ["fx_level", "fx_level", "ult_cutin"], str(seen))
	var rt: = JSON.parse_string(JSON.stringify(G.S))
	_check("v7 round trip keeps settings", G.apply_state(rt) and G.ult_cutin() == "short" and G.fx_level() == "full")


static func _feel() -> void :
	G.S = G.default_state()
	G.set_fx_level("full")
	_check("feel full: shake, edge flash, fx, scale 1", V9Feel.can_shake() and V9Feel.can_edge_flash() and V9Feel.can_fx() and V9Feel.fx_scale() == 1.0)
	G.set_fx_level("mid")
	_check("feel mid: no shake / edge flash, fx on", not V9Feel.can_shake() and not V9Feel.can_edge_flash() and V9Feel.can_fx() and V9Feel.fx_scale() > 0.0 and V9Feel.fx_scale() < 1.0)
	G.set_fx_level("min")
	_check("feel min: press feedback only", not V9Feel.can_shake() and not V9Feel.can_edge_flash() and not V9Feel.can_fx() and V9Feel.fx_scale() == 0.0)
	# press on a live node: dips, then returns exactly to its resting scale (no drift on repeated taps)
	var tree: = Engine.get_main_loop() as SceneTree
	var c: = Control.new()
	c.size = Vector2(100, 60)
	c.scale = Vector2(1.5, 1.5)
	tree.root.add_child(c)
	V9Feel.press(c)
	V9Feel.press(c)
	_check("press keeps resting scale in meta", c.get_meta(V9Feel.META_BASE) == Vector2(1.5, 1.5))
	_check("press centres pivot", c.pivot_offset == Vector2(50, 30))
	V9Feel.press_down(c)
	V9Feel.press_up(c, true)
	_check("down/up keep resting scale", c.get_meta(V9Feel.META_BASE) == Vector2(1.5, 1.5))
	V9Feel.success(null, "")
	V9Feel.fail(null, "")
	V9Feel.tile_tap(true)
	V9Feel.tile_match(3)
	_check("null-node feedback is safe", true)
	c.free()


static func _audio() -> void :
	_check("pitch ladder: pair 1 base", is_equal_approx(Sfx.combo_pitch(1), 1.0) and is_equal_approx(Sfx.combo_pitch(0), 1.0))
	_check("pitch ladder: +1 semitone per pair", absf(Sfx.combo_pitch(2) - 1.059463) < 0.0001 and absf(Sfx.combo_pitch(8) / Sfx.combo_pitch(7) - 1.059463) < 0.0001)
	_check("pitch ladder: octave cap at pair 13", is_equal_approx(Sfx.combo_pitch(13), 2.0) and is_equal_approx(Sfx.combo_pitch(30), 2.0))
	_check("combo sample exists", ResourceLoader.exists("res://assets/sfx/%s.wav" % Sfx.COMBO_BASE))
	_check("music bus exists", AudioServer.get_bus_index(Sfx.MUSIC_BUS) >= 0)
	_check("music players on it", Sfx.music_a.bus == Sfx.MUSIC_BUS and Sfx.music_b.bus == Sfx.MUSIC_BUS)
	Sfx.duck(-8.0, 0.5)
	for i in 30:
		Sfx._process(1.0 / 60.0)
	_check("duck: lands at -8 dB within attack", is_equal_approx(Sfx.duck_db(), -8.0), str(Sfx.duck_db()))
	Sfx._duck_until = 0.0
	for i in 30:
		Sfx._process(1.0 / 60.0)
	_check("duck: releases to 0 within 0.5 s", is_equal_approx(Sfx.duck_db(), 0.0), str(Sfx.duck_db()))
	Sfx.duck_hold(true, -6.0)
	for i in 10:
		Sfx._process(1.0 / 60.0)
	_check("duck_hold holds", is_equal_approx(Sfx.duck_db(), -6.0))
	Sfx.duck_hold(false)
	for i in 30:
		Sfx._process(1.0 / 60.0)
	_check("duck_hold release", is_equal_approx(Sfx.duck_db(), 0.0))
	var bi: = AudioServer.get_bus_index(Sfx.MUSIC_BUS)
	_check("bus volume back to 0 dB", is_equal_approx(AudioServer.get_bus_volume_db(bi), 0.0))


# ── dev overlay ──────────────────────────────────────────────────────────────

static func _art(path: String) -> Image:
	var img: Image = null
	var tex = load(path)
	if tex is Texture2D:
		img = tex.get_image()
	if img == null or img.is_empty():
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(V9Ults.ART_SIZE.x), int(V9Ults.ART_SIZE.y), Image.INTERPOLATE_BILINEAR)
	return img


static func _frame(img: Image, r: Rect2, col: Color, w: int) -> void :
	var x0: = int(r.position.x)
	var y0: = int(r.position.y)
	var x1: = int(r.end.x)
	var y1: = int(r.end.y)
	img.fill_rect(Rect2i(x0, y0, x1 - x0, w), col)
	img.fill_rect(Rect2i(x0, y1 - w, x1 - x0, w), col)
	img.fill_rect(Rect2i(x0, y0, w, y1 - y0), col)
	img.fill_rect(Rect2i(x1 - w, y0, w, y1 - y0), col)


static func overlay(dir: String) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var ids: Array = V9Ults.ULTS.keys()
	var cw: = 215
	var ch: = 320
	var cols: = 6
	var per: = cols * 2
	var sheets: = 0
	for s0 in range(0, ids.size(), per):
		var sheet: = Image.create(cw * cols, ch * 4, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.07, 0.09))
		for j in range(s0, mini(s0 + per, ids.size())):
			var id: String = ids[j]
			var u: Dictionary = V9Ults.ULTS[id]
			var img: = _art(u.ref_img)
			if img == null:
				continue
			_frame(img, u.alt_rect, Color(0.2, 1, 1), 6)
			_frame(img, u.face_rect, Color(1, 0.15, 0.15), 6)
			var full: = img.duplicate() as Image
			full.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			var k: = j - s0
			sheet.blit_rect(full, Rect2i(0, 0, cw, ch), Vector2i((k % cols) * cw, (k / cols) * ch * 2))
			var fr: Rect2 = u.face_rect
			var face: = img.get_region(Rect2i(int(fr.position.x), int(fr.position.y), int(fr.size.x), int(fr.size.y)))
			face.resize(cw, cw, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(face, Rect2i(0, 0, cw, cw), Vector2i((k % cols) * cw, (k / cols) * ch * 2 + ch))
		sheet.save_png("%s/ults_overlay_%d.png" % [dir, sheets])
		sheets += 1
	return sheets
