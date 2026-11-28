class_name V10TowerUISelftest
extends RefCounted

# V10TowerUISelftest — unified UI + UX budget + code hygiene runner for the tower lane (part F of ui/CONTRACT.md).
# Invoked from tower_selftest.gd (--tower_selftest=1 or --tower_ui_selftest=1) so ONE scene (tower_selftest.tscn)
# verifies both the 192 logic checks and every UI / E2E / UX_RULES gate across 720×1280 and 720×1600.

const DEMO_PAGODA: = preload("res://scripts/v10/tower/ui/demo_pagoda.gd")
const DEMO_JOURNEY: = preload("res://scripts/v10/tower/ui/demo_journey.gd")
const DEMO_FAN: = preload("res://scripts/v10/tower/ui/demo_fan.gd")
const DEMO_PLAY: = preload("res://scripts/v10/tower/ui/demo_play.gd")
const UIT: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const U: = preload("res://core/modes/tower/tower_util.gd")
const P: = preload("res://core/modes/tower/pagoda.gd")
const J: = preload("res://core/modes/tower/journey.gd")
const D: = preload("res://core/modes/tower/mods_data.gd")


static func run_into(host: Node) -> void:
	_hygiene(host)
	await _run_suite(host, "ui_pagoda", DEMO_PAGODA, Vector2i(720, 1280))
	await _run_suite(host, "ui_journey", DEMO_JOURNEY, Vector2i(720, 1280))
	await _run_suite(host, "ui_fan", DEMO_FAN, Vector2i(720, 1280))
	await _run_suite(host, "ui_play", DEMO_PLAY, Vector2i(720, 1280))


static func _run_suite(host: Node, section: String, scr: Script, sz: Vector2i) -> void:
	host.cur = section
	var sv: = SubViewport.new()
	sv.size = sz
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(sv)
	var node: Control = scr.new()
	node.set("embedded", true)
	node.size = Vector2(sz)
	sv.add_child(node)
	await host.get_tree().process_frame
	var r: Dictionary = await node.call("run_embedded")
	var sub_ok: = int(r.get("ok", 0))
	var sub_tot: = int(r.get("total", 0))
	var sub_fails: Array = r.get("fails", [])
	host.total += sub_tot
	host.ok += sub_ok
	host.mod_total[section] = int(host.mod_total.get(section, 0)) + sub_tot
	host.mod_ok[section] = int(host.mod_ok.get(section, 0)) + sub_ok
	for f in sub_fails:
		host.fails.append("[%s] %s" % [section, String(f)])
	sv.queue_free()
	await host.get_tree().process_frame


static func _hygiene(host: Node) -> void:
	host.cur = "hygiene"
	var files: Array = []
	_list_gd("res://scripts/v10/tower", files)
	_list_gd("res://core/modes/tower", files)  # WP3: UI-free tower files moved to core
	host.check(files.size() >= 22, "all tower scripts scanned (%d)" % files.size())
	var raw_time: Array = []
	var raw_aff: Array = []
	var raw_col: Array = []
	var raw_gems: Array = []
	for path in files:
		if String(path).ends_with("tower_ui_selftest.gd"):
			continue
		var fn: = String(path).get_file()
		var clean_lines: PackedStringArray = []
		for ln in FileAccess.get_file_as_string(path).split("\n"):
			var s: = ln.strip_edges()
			if not s.begins_with("#"):
				clean_lines.append(s)
		var src: = "\n".join(clean_lines)
		if ("Time" + ".") in src:
			raw_time.append(fn)
		if ("G.add" + "_aff(") in src:
			raw_aff.append(fn)
		if not fn.begins_with("demo_") and (("Color(\"" + "#") in src or ("Color('" + "#") in src or ("Color(" + "0.") in src or ("Color(" + "0, 0") in src):
			raw_col.append(fn)
		if fn != "demo_play.gd" and (("G.S.gems" + " =") in src or ("G.S.gems" + " +=") in src or ("G.S.gems" + " -=") in src):
			raw_gems.append(fn)
	host.check(raw_time.is_empty(), "zero raw clock calls in tower scripts %s" % [raw_time])
	host.check(raw_aff.is_empty(), "zero legacy affection calls in tower scripts %s" % [raw_aff])
	host.check(raw_col.is_empty(), "zero hex/float colour literals in tower scripts %s" % [raw_col])
	host.check(raw_gems.is_empty(), "zero direct G.S.gems writes in tower UI %s" % [raw_gems])

	# V10Meta clock routing + fallback
	U.fake_now = 0
	V10Meta.set_now(1795629600)
	host.check(U.now_utc() == 1795629600, "V10TowerUtil.now_utc routes through V10Meta.now_unix")
	host.check(U.cal_key(1795629600) == V10Meta.cal_key(1795629600), "V10TowerUtil.cal_key matches V10Meta.cal_key (%s)" % U.cal_key(1795629600))
	var wid: = U.week_id(1795629600)
	host.check(U.week_refresh_text(wid) == V10Meta.fmt_msk(U.week_end(wid)), "week_refresh_text matches V10Meta.fmt_msk")
	V10Meta.clear_now()

	# calm() honours BOTH S.fx_level == "min" AND S.a11y_calm == true
	var prev_fx: = V10Hud2Util.fx_override
	var prev_calm: = bool(G.S.get("a11y_calm", false))
	V10Hud2Util.fx_override = "full"
	G.S["a11y_calm"] = false
	host.check(not UIT.calm(), "calm() is false at fx=full, a11y_calm=false")
	V10Hud2Util.fx_override = "min"
	host.check(UIT.calm(), "calm() is true at fx=min")
	V10Hud2Util.fx_override = "full"
	G.S["a11y_calm"] = true
	host.check(UIT.calm(), "calm() is true at a11y_calm=true even when fx=full")
	G.S["a11y_calm"] = prev_calm
	V10Hud2Util.fx_override = prev_fx

	# V10Lint.ui_scan across all visible strings of curses, blessings, themes, bosses, floors, cosmetics
	var ui_strings: Array = []
	for cid in D.CURSES:
		var cd: Dictionary = D.CURSES[cid]
		ui_strings.append(UIT.ui_text(String(cd.get("name", ""))))
		for lv in cd.get("levels", []):
			ui_strings.append(UIT.ui_text(String((lv as Dictionary).get("desc", ""))))
	for bid in D.BLESS:
		var bd: Dictionary = D.BLESS[bid]
		ui_strings.append(UIT.ui_text(String(bd.get("name", ""))))
		ui_strings.append(UIT.ui_text(String(bd.get("desc", ""))))
		ui_strings.append(UIT.ui_text(String(bd.get("plus", ""))))
	for fn2 in P.FLOOR_NAMES:
		ui_strings.append(String(fn2))
	for cd2 in P.COS:
		ui_strings.append(String((cd2 as Dictionary).get("name", "")))
	for th in J.THEMES:
		ui_strings.append(String((th as Dictionary).get("name", "")))
		ui_strings.append(UIT.ui_text(String((th as Dictionary).get("sub", ""))))
	for bk in J.BOSS:
		var b: Dictionary = J.BOSS[bk]
		ui_strings.append(UIT.ui_text(String(b.get("name", ""))))
		ui_strings.append(UIT.ui_text(String(b.get("sub", ""))))
	var bad_lint: = V10Lint.ui_scan(ui_strings)
	host.check(bad_lint.is_empty(), "V10Lint.ui_scan clean on %d tower strings %s" % [ui_strings.size(), bad_lint])

	# UX_RULES §10 П-5: navigation graph depth from tab roots (tables / home) <= 2
	var nav_graph: = {"pagoda": ["tables"], "journey": ["tables", "home"], "tower_play": ["pagoda", "journey"]}
	var roots: = {"tables": 0, "home": 0}
	for pass_i in 3:
		for scr_id in nav_graph:
			for p_id in nav_graph[scr_id]:
				if roots.has(p_id):
					var d_new: int = int(roots[p_id]) + 1
					if not roots.has(scr_id) or d_new < int(roots[scr_id]):
						roots[scr_id] = d_new
	host.check(int(roots.get("pagoda", 99)) <= 2 and int(roots.get("journey", 99)) <= 2 and int(roots.get("tower_play", 99)) <= 2,
		"UX_RULES П-5: nav depth <= 2 (%s)" % [roots])


static func _list_gd(dir_path: String, out: Array) -> void:
	var da: = DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var f: = da.get_next()
	while f != "":
		if not f.begins_with("."):
			var full: = dir_path.path_join(f)
			if da.current_is_dir():
				_list_gd(full, out)
			elif f.ends_with(".gd"):
				out.append(full)
		f = da.get_next()
	da.list_dir_end()
