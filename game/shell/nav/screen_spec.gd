class_name ScreenSpec
extends Resource

# ScreenSpec (P23 / WP8a): the ONE declaration of a v11 screen. A screen exists for the shell only if it has a valid spec: the
# registry (TWScreens.scan / register) refuses everything else, and tools/lint_screen_has_spec.py (SCREEN_HAS_SPEC) turns
# a screen folder without spec.tres into a red build. There is no central SCREENS dict: a spec lives next to its screen
# (shell/screens/<name>/spec.tres + screen.gd) and is found by the directory scan.
#
#   id              snake_case, unique, the only handle other code uses: TWScreens.go("home")
#   scene           res:// .tscn whose root script extends TWScreen   } exactly one of the two:
#   script_path     res:// .gd that extends TWScreen (built with .new())  } scene wins when both are set
#   tab             tab id this screen lives under ("" = none, e.g. a full-screen match)
#   is_tab_root     the screen a tab shows first; entering it clears the history
#   chrome          flags of the common frame: header, tabbar, currency, back (anything else is rejected)
#   unlock_rule     rule ref ("" = always open); TWScreens.unlock_check(rule) decides, the spec never reads state
#   back_target     screen id used by back() when the history is empty ("" = leave the app)
#   tut_ids         stable ids of the FTUE targets on this screen (the coach never uses node paths)
#   analytics_name  event name, defaults to id
#   keep_history    false = transient screen (result, loading): never pushed on the history stack

const CHROME_FLAGS: = ["header", "tabbar", "currency", "back"]
const TWSCREEN_PATH: = "res://shell/nav/tw_screen.gd"

@export var id: String = ""
@export_file("*.tscn") var scene: String = ""
@export_file("*.gd") var script_path: String = ""
@export var tab: String = ""
@export var is_tab_root: bool = false
@export var chrome: PackedStringArray = PackedStringArray()
@export var unlock_rule: String = ""
@export var back_target: String = ""
@export var tut_ids: PackedStringArray = PackedStringArray()
@export var analytics_name: String = ""
@export var keep_history: bool = true


static func make(p_id: String, p_script: String, opts: Dictionary = {}) -> ScreenSpec:
	var s: = ScreenSpec.new()
	s.id = p_id
	s.script_path = p_script
	for k in opts:
		s.set(k, opts[k])
	return s


func name_for_analytics() -> String:
	return analytics_name if analytics_name != "" else id


func has_chrome(flag: String) -> bool:
	return chrome.has(flag)


# "" when the spec can be registered, otherwise the reason (short, machine-readable prefix before the colon)
func validate() -> String:
	if id == "":
		return "id: empty"
	var re: = RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	if re.search(id) == null:
		return "id: '%s' is not snake_case" % id
	if scene == "" and script_path == "":
		return "source: neither scene nor script_path"
	if scene != "":
		if not ResourceLoader.exists(scene):
			return "source: scene '%s' does not exist" % scene
	elif not ResourceLoader.exists(script_path):
		return "source: script '%s' does not exist" % script_path
	else:
		var sc = load(script_path)
		if not (sc is Script) or not _extends_tw_screen(sc):
			return "source: '%s' does not extend TWScreen" % script_path
	for c in chrome:
		if not CHROME_FLAGS.has(c):
			return "chrome: unknown flag '%s'" % c
	if back_target == id:
		return "back_target: points at the screen itself"
	if is_tab_root and tab == "":
		return "tab: is_tab_root without a tab"
	for t in tut_ids:
		if t == "" or t.contains(" "):
			return "tut_ids: '%s' is not a stable id" % t
	return ""


static func _extends_tw_screen(sc: Script) -> bool:
	var base = load(TWSCREEN_PATH)
	var cur: Script = sc
	var guard: = 0
	while cur != null and guard < 16:
		if cur == base:
			return true
		cur = cur.get_base_script()
		guard += 1
	return false
