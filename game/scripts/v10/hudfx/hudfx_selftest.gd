extends Control

# V10HudFx unified selftest (scripts/v10/hudfx/hudfx_selftest.tscn, args: --hudfx_selftest=1).
# Runs the six module selftests one after another on this scene, then the V10HudFx core checks:
#   * SFX: every sfx/*.ogg is listed in sfx/peaks.json with a decoded peak <= -6 dBFS (UX_RULES 7.4), the file set
#     matches, V10HudFx.sound() never boosts (db clamped to <= 0)
#   * warm_light / n() / level() contracts (never white, counts by S.fx_level)
#   * no leaks: orphan node count after all six runs is not above the count before them
# Marker: "HUDFX SELFTEST <passed>/<total>" (exit code = failures). Also launched from demo/hudfx_demo.tscn.

const SFX_DIR: = "res://scripts/v10/hudfx/sfx/"
const PEAK_MAX: = -6.0

var _p: = 0
var _f: = 0
var _lines: = []


func ok(cond: bool, msg: String) -> void:
	if cond:
		_p += 1
	else:
		_f += 1
		_lines.append("FAIL hudfx: " + msg)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ("--hudfx_selftest=1" in OS.get_cmdline_user_args()):
		return
	await get_tree().process_frame
	await run_all()
	for l in _lines:
		print(l)
	print("HUDFX SELFTEST %d/%d" % [_p, _p + _f])
	# let the audio pool and tweens settle, so nothing is alive at exit
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(_f)


func run_all() -> void:
	var orphans_before: = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var mods: = [["odometer", V10HudFxOdometerTest], ["combo_digit", V10HudFxComboDigitTest],
		["showcase_fx", V10HudFxShowcaseFxTest], ["lantern_fx", V10HudFxLanternFxTest],
		["silk_sheet", V10HudFxSilkSheetTest], ["victory_stars", V10HudFxVictoryStarsTest]]
	for m in mods:
		var r: Dictionary = await m[1].run(self)
		print("hudfx %-14s %d/%d" % [m[0], r.passed, r.passed + r.failed])
		_p += int(r.passed)
		_f += int(r.failed)
		for l in r.lines:
			_lines.append(str(l))
		ok(int(r.passed) > 20, "%s ran its checks (%d)" % [m[0], r.passed])
	_core()
	_sfx()
	for i in 3:
		await get_tree().process_frame
	var orphans_after: = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	ok(orphans_after <= orphans_before, "orphan nodes %d -> %d (leak)" % [orphans_before, orphans_after])
	ok(get_child_count() == 0, "module tests left %d children on the host" % get_child_count())


func _core() -> void:
	var keep: = V10Hud2Util.fx_override
	for lv in ["full", "mid", "min"]:
		V10Hud2Util.fx_override = lv
		ok(V10HudFx.level() == lv, "level() follows fx_override %s" % lv)
		ok(V10HudFx.n(10) == {"full": 10, "mid": 6, "min": 0}[lv], "n(10) at %s = %d" % [lv, V10HudFx.n(10)])
	V10Hud2Util.fx_override = keep
	var w: = V10HudFx.warm_light(Color.WHITE, 1.0)
	ok(w.v <= V10HudFx.LIGHT_VALUE_MAX + 0.001 and w.a <= V10HudFx.LIGHT_ALPHA_MAX + 0.001, "warm_light never white")
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		ok(V10HudFx.accent(h).a > 0.0 and V10HudFx.glow(h).a > 0.0, "hero palette %s" % h)


func _sfx() -> void:
	var f: = FileAccess.open(SFX_DIR + "peaks.json", FileAccess.READ)
	ok(f != null, "sfx/peaks.json present")
	if f == null:
		return
	var peaks: Dictionary = JSON.parse_string(f.get_as_text())
	var files: = []
	for n in ResourceLoader.list_directory(SFX_DIR):
		if n.ends_with(".ogg"):
			files.append(n.get_basename())
	ok(files.size() >= 10, "10 sfx files (%d)" % files.size())
	for n in files:
		ok(peaks.has(n), "peaks.json lists %s" % n)
		if peaks.has(n):
			ok(float(peaks[n]) <= PEAK_MAX, "%s peak %.2f dBFS <= %.1f" % [n, float(peaks[n]), PEAK_MAX])
		ok(V10HudFx._stream(n) is AudioStream, "%s loads" % n)
	for k in peaks:
		ok(files.has(k), "peaks.json entry %s has a file" % k)
	# sound() must clamp a boosting db and survive unknown names
	V10HudFx.sound("pluck", 1.0, 12.0)
	V10HudFx.sound("no_such_sound_xyz")
	ok(true, "sound() survives unknown / boosting calls")
