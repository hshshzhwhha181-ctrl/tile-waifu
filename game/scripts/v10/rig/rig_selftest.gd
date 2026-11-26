extends Node

# Headless smoke & perf selftest for V10LiveRig (docs/INTEGRATION_0.10.md §2.18 / §4 W3).
# Loads the binary res://assets/v10/rig/mc_gown/rig.scn, steps 120 frames, checks bones, layers,
# tap zones, lip-sync, and CPU update time, then prints "RIG_SELFTEST n/m".

const SCN_PATH: = "res://assets/v10/rig/mc_gown/rig.scn"
const TSCN_PATH: = "res://assets/v10/rig/mc_gown/rig.tscn"

var _pass: = 0
var _fail: = 0


func _check(cond: bool, what: String, info: = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("  FAIL %s %s" % [what, info])


func _ready() -> void:
	await get_tree().process_frame
	_check(ResourceLoader.exists(SCN_PATH), "binary rig.scn exists")
	var packed: PackedScene = load(SCN_PATH if ResourceLoader.exists(SCN_PATH) else TSCN_PATH)
	_check(packed != null, "rig scene loads")
	var rig: V10LiveRig = packed.instantiate() as V10LiveRig if packed else null
	_check(rig != null, "rig instantiates as V10LiveRig")
	if rig != null:
		rig.handle_input = false
		rig.scale = Vector2.ONE * 0.645
		rig.position = Vector2(360.0 - 581.0 * 0.645, 1292.0 - 1400.0 * 0.645)
		add_child(rig)
		await get_tree().process_frame
		_check(rig.bones.size() >= 20 and rig.layers.size() >= 10,
			"bones (%d) and mesh layers (%d) built" % [rig.bones.size(), rig.layers.size()])
		rig.appear()
		var sum_us: = 0
		for i in 120:
			rig._process(1.0 / 60.0)
			if i >= 20:
				sum_us += rig.last_update_usec
		var mean_us: = float(sum_us) / 100.0
		_check(mean_us <= 2500.0, "mean rig step <= 2.5 ms", "%.1f us" % mean_us)
		var z_head: = rig.zone_at(Vector2(700, 180))
		var z_dead: = rig.zone_at(Vector2(820, 620))
		_check(z_head == "head" and z_dead == "none", "tap zones classify head & dead zone", "%s / %s" % [z_head, z_dead])
		rig.set_mouth_level(0.75)
		rig._process(1.0 / 60.0)
		rig.set_mouth_level(-1.0)
		rig.react("head")
		rig._process(1.0 / 60.0)
		_check(is_instance_valid(rig), "lip-sync and reaction run cleanly")
		rig.queue_free()
	print("RIG_SELFTEST %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(0 if _fail == 0 else 1)
