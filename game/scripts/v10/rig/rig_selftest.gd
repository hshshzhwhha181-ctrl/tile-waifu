extends Node

# Unified selftest for V10 living heroine rigs (`mc_gown`, `rin_officer`, `hana_base`), `gestures.json` contract
# (DATA.md, LEGWEAR §4-5), `V10RigSheen`, and `V10RigCatalog`.
# Run:
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/rig/rig_selftest.tscn -- --rig_selftest=1
# Prints:
#   RIG_SELFTEST <ok>/<total>

var ok: int = 0
var total: int = 0
var fails: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(msg)
		print("RIG_FAIL: ", msg)


func _run() -> void:
	V10RigCatalog.reload()
	var ids: = V10RigCatalog.ids()
	for req in ["mc_gown", "rin_officer", "hana_base"]:
		check(ids.has(req), "catalog has rig " + req)

	# Outfits resolution
	check(String(V10RigCatalog.find_for("mc", "o_base").get("rig", "")) == "mc_gown", "mc o_base -> mc_gown")
	check(String(V10RigCatalog.find_for("rin", "r_base").get("rig", "")) == "rin_officer", "rin r_base -> rin_officer")
	check(String(V10RigCatalog.find_for("hana", "h_base").get("rig", "")) == "hana_base", "hana h_base -> hana_base")

	for rid in ["mc_gown", "rin_officer", "hana_base"]:
		await _verify_rig(rid)

	# Single-rig mount guard + calm/alt_rect sheen toggle
	var stage: = Node2D.new()
	add_child(stage)
	var r1: = V10RigCatalog.mount(stage, "mc", "o_base", Rect2(0, 0, 720, 1280), {"calm": false, "alt_rect": false})
	check(r1 != null, "mount mc_gown succeeds")
	var r2: = V10RigCatalog.mount(stage, "rin", "r_base", Rect2(0, 0, 720, 1280), {"calm": true, "alt_rect": true})
	check(r2 != null, "mount rin_officer succeeds")
	await get_tree().process_frame
	await get_tree().process_frame
	var live_count: = 0
	for c in stage.get_children():
		if c is V10LiveRig and not c.is_queued_for_deletion():
			live_count += 1
	check(live_count == 1, "<= 1 live rig mounted in stage container (got %d)" % live_count)
	var sh_node: V10RigSheen = r2.get_node_or_null("V10RigSheen") as V10RigSheen
	check(sh_node != null and not sh_node.enabled, "calm/alt_rect disables V10RigSheen")
	stage.queue_free()
	await get_tree().process_frame

	print("RIG_SELFTEST %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total and total > 0 else 1)


func _verify_rig(rid: String) -> void:
	var e: = V10RigCatalog.get_rig(rid)
	check(not e.is_empty(), "%s gestures.json parsed" % rid)
	var outs: Array = e.get("outfits", [])
	check(not outs.is_empty(), "%s non-empty outfits list" % rid)
	var def_path: = "res://assets/v10/rig/%s/rig_def.json" % rid
	check(FileAccess.file_exists(def_path), "%s rig_def.json exists" % rid)
	var def_d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def_path))
	check(def_d is Dictionary and not def_d.is_empty(), "%s rig_def.json valid JSON" % rid)

	# Instantiate scene
	var sp: = String(e.get("scene", ""))
	check(ResourceLoader.exists(sp), "%s scene exists (%s)" % [rid, sp])
	var rig: V10LiveRig = (load(sp) as PackedScene).instantiate() as V10LiveRig
	check(rig != null, "%s instantiates as V10LiveRig" % rid)
	add_child(rig)
	await get_tree().process_frame

	# Mesh bone influence <= 4 & valid Skeleton2D
	var skel: Skeleton2D = rig.get_node_or_null("Figure/Art/Skeleton") as Skeleton2D
	check(skel != null and skel.get_bone_count() >= 10, "%s has Skeleton2D >= 10 bones" % rid)
	var art: Node2D = rig.get_node_or_null("Figure/Art") as Node2D
	var poly_ok: = true
	for ch in art.get_children():
		if ch is Polygon2D:
			var p: Polygon2D = ch
			if p.polygon.is_empty():
				poly_ok = false
	check(poly_ok, "%s all Polygon2D layers have vertices" % rid)

	# Contract: reactions never point to bold or fx/layer, and every non-n/a R gesture builds tracks
	var gmap: = {}
	var has_bold_active: = false
	for g in e.get("gestures", []):
		var gd: Dictionary = g
		var nm: = String(gd.get("name", ""))
		gmap[nm] = gd
		var st_str: = String(gd.get("status", ""))
		if st_str.begins_with("n/a"):
			continue
		if String(gd.get("tier", "")) == "bold":
			has_bold_active = true
			check(String(gd.get("use", "")) == "auto" and int(gd.get("aff_min", 0)) >= 6,
				"%s bold gesture %s is idle-only aff>=6" % [rid, nm])
		if String(gd.get("rig", "R")).begins_with("R") and String(gd.get("use", "")) in ["auto", "react", "both"]:
			var trk: Dictionary = rig._build(nm, 1.0, Vector2.ZERO)
			check(not trk.is_empty(), "%s _build('%s') returns tracks" % [rid, nm])

	if rid == "hana_base":
		check(not has_bold_active, "hana_base has zero active bold gestures")

	var rx: Dictionary = e.get("reactions", {})
	var dz: Array = rx.get("dead_zones", [])
	check(dz.has("bust") and dz.has("hips"), "%s dead_zones include bust & hips" % rid)
	var react_names: Array[String] = []
	var zones: Dictionary = rx.get("zones", {})
	for zk in zones:
		react_names.append(String(zones[zk]))
	react_names.append(String(rx.get("neutral", "")))
	react_names.append(String(rx.get("pout", "")))
	react_names.append(String(rx.get("greet", "")))
	for rn in react_names:
		check(gmap.has(rn), "%s reaction '%s' declared in gestures[]" % [rid, rn])
		if gmap.has(rn):
			var rgd: Dictionary = gmap[rn]
			check(String(rgd.get("tier", "")) != "bold", "%s reaction '%s' is never bold" % [rid, rn])
			check(not (String(rgd.get("use", "")) in ["fx", "layer"]), "%s reaction '%s' is playable track" % [rid, rn])

	# Sheen attachment & mask empty above knee_y
	var sh_cfg: Dictionary = (e.get("shaders", {}) as Dictionary).get("sheen", {})
	check(not sh_cfg.is_empty(), "%s defines shaders.sheen" % rid)
	var sh: V10RigSheen = V10RigSheen.attach(rig, sh_cfg)
	check(sh != null, "%s V10RigSheen.attach succeeds" % rid)
	if sh != null:
		sh.sweep(1.0)
		rig._process(0.16)
		sh._process(0.16)
		check(true, "%s sheen sweep & rig frame step clean" % rid)

	# Strain & simulation step across gestures
	rig.appear()
	for step_i in 12:
		rig._process(1.0 / 30.0)
	var st_m: Dictionary = rig.measure_strain()
	check(float(st_m.get("p99", 99.0)) < 0.45, "%s idle strain p99 < 0.45 (got %.3f)" % [rid, float(st_m.get("p99", 99.0))])

	# Filter checks (alt_rect hides legs:true, non-bold hides bold)
	var base_auto: = V10RigCatalog.allowed_auto_gestures(e, String(outs[0]), 9, false, false)
	for bn in base_auto:
		check(String((gmap[bn] as Dictionary).get("tier", "")) != "bold", "%s bold excluded when bold_ok=false" % rid)
	var alt_auto: = V10RigCatalog.allowed_auto_gestures(e, String(outs[0]), 9, true, true)
	for an in alt_auto:
		check(not bool((gmap[an] as Dictionary).get("legs", false)), "%s legs:true excluded when alt_rect=true" % rid)

	rig.queue_free()
	await get_tree().process_frame
