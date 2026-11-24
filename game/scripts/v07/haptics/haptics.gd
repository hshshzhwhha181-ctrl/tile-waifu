extends Node

# V7Haptics — vibration (autoload). kind(k) plays a named pattern from KINDS, combo(n, gold) the combo pulse,
# pulse(ms, amp) one raw pulse. Settings: S.v7_haptics.on / power. Taps on JButtons are answered by V9Feel
# (scripts/v09/core/feel.gd), which calls kind() — this autoload only hooks plain buttons, cards and boards.







const KINDS: = {
	"button": [[8, 0.25, 0]], 
	"tap": [[10, 0.35, 0]], 
	"select": [[14, 0.5, 0]], 
	"flip": [[9, 0.4, 40], [9, 0.3, 0]], 
	"match": [[22, 0.7, 0]], 
	"gold": [[18, 0.7, 50], [26, 0.9, 0]], 
	"deny": [[16, 0.55, 70], [16, 0.55, 0]], 
	"danger": [[30, 0.45, 0]], 
	"fail": [[60, 0.6, 90], [110, 0.4, 0]], 
	"clear": [[30, 0.8, 70], [30, 0.8, 70], [90, 1.0, 0]], 
	"reveal": [[24, 0.6, 0]], 
	"ssr": [[40, 0.9, 60], [40, 0.9, 60], [40, 1.0, 120], [160, 1.0, 0]], 
	"pet": [[14, 0.35, 60], [10, 0.25, 0]], 
	"egg": [[12, 0.6, 50], [12, 0.6, 50], [12, 0.6, 140], [60, 0.9, 0]], 
	"skill": [[20, 0.7, 40], [60, 0.9, 0]], 
}

var log_on: = false
var pulses: = 0
var _last: = -1.0
var _busy_until: = 0.0
var _boards: = {}
var _seen_play: = {}

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	log_on = "--v7_haptics_log=1" in OS.get_cmdline_user_args()
	get_tree().node_added.connect(_on_node_added)

func enabled() -> bool:
	var st = G.S.get("v7_haptics", {})
	return not (st is Dictionary) or st.get("on", true)

func power() -> float:
	var st = G.S.get("v7_haptics", {})
	return clampf(float(st.get("power", 1.0)) if st is Dictionary else 1.0, 0.1, 1.0)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func pulse(ms: int, amp: = 0.5, force: = false) -> void :
	if not enabled():
		return
	var t: = _now()
	if not force and (t - _last < 0.035 or t < _busy_until):
		return
	_last = t
	pulses += 1
	var a: = clampf(amp * power(), 0.05, 1.0)
	if log_on:
		print("[v7_haptics] %d ms @ %.2f" % [ms, a])
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, a)


func pattern(steps: Array) -> void :
	if not enabled() or steps.is_empty():
		return
	var total: = 0.0
	for s in steps:
		total += (float(s[0]) + float(s[2])) / 1000.0
	_busy_until = _now() + total
	var delay: = 0.0
	for s in steps:
		if delay <= 0.0:
			pulse(int(s[0]), float(s[1]), true)
		else:
			var ms: = int(s[0])
			var amp: = float(s[1])
			get_tree().create_timer(delay, true, false, true).timeout.connect( func(): pulse(ms, amp, true))
		delay += (float(s[0]) + float(s[2])) / 1000.0

func kind(k: String) -> void :
	if KINDS.has(k):
		var steps: Array = KINDS[k]
		if steps.size() == 1:
			pulse(int(steps[0][0]), float(steps[0][1]), k in ["match", "gold", "reveal"])
		else:
			pattern(steps)


func combo(n: int, gold: = false) -> void :
	if n >= 3 and (n in [3, 5, 8, 12, 16, 20] or (n > 20 and n % 5 == 0)):
		var a: = clampf(0.7 + n * 0.02, 0.7, 1.0)
		pattern([[20, a, 45], [34 + mini(n, 20), 1.0, 0]])
	elif gold:
		kind("gold")
	else:
		pulse(18 + mini(n, 8) * 2, clampf(0.55 + n * 0.04, 0.55, 0.9), true)


func _on_node_added(n: Node) -> void :
	if n is TrayBoard:
		_attach_board.call_deferred(n)
	elif n is JButton:
		pass # 0.9: JButton vibrates on touch-down through V9Feel.press_down
	elif n is BaseButton:
		n.pressed.connect( func(): pulse(8, 0.25))
	elif n is Hero:
		n.tapped.connect( func(): kind("pet"))
	elif n is Control:
		_hook_card.call_deferred(n)

# 0.8: cards wired through gui_input lambdas (league card, banners, mode tiles, rating rows, outfits…) get the
# same light tap pulse as a JButton. Checked a frame later, once the screen has connected its handler.
# A node can opt out with set_meta("no_haptic", true) (modal backdrops, passive panels).
func _hook_card(n) -> void :
	if not is_instance_valid(n) or not (n is Control) or n.mouse_filter != Control.MOUSE_FILTER_STOP or n.has_meta("no_haptic"):
		return
	if n.get_signal_connection_list("gui_input").is_empty():
		return
	n.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not n.has_meta("no_haptic"):
			pulse(8, 0.25))

# 0.9: a board that routes its feedback through V9Feel (meta "v9_feel") gets no second set of haptics from here
func _attach_board(b: Node) -> void :
	if not is_instance_valid(b) or _boards.has(b.get_instance_id()) or b.has_meta("v9_feel"):
		return
	_boards[b.get_instance_id()] = true
	b.tree_exiting.connect( func(): _boards.erase(b.get_instance_id()))
	var st: = {"tray": 0, "ice": 0}
	b.tray_changed.connect( func():
		if not is_instance_valid(b):
			return
		var n: int = b.tray.size()
		var ice: = 0
		for t in b.tiles:
			if t.alive and t.ice > 0:
				ice += 1
		if ice < st.ice:
			kind("flip")
		elif n > st.tray:
			if n >= b.slots - 1:
				kind("danger")
			else:
				kind("select")
		st.tray = n
		st.ice = ice)
	b.matched.connect( func(_mid, combo_n: int, gold: bool, shard: String):
		if shard != "":
			kind("reveal")
		combo(combo_n, gold))
	b.denied.connect( func(_t): kind("deny"))
	b.failed.connect( func(): kind("fail"))
	b.cleared.connect( func(): kind("clear"))


const SOUND_KIND: = {"reveal_ssr": "ssr", "reveal_sr": "reveal", "summon_boom": "reveal"}

func _process(_dt: float) -> void :
	var sfx = get_node_or_null("/root/Sfx")
	if sfx == null:
		return
	for p in sfx.pool:
		var playing: bool = p.playing
		var key: int = p.get_instance_id()
		var prev: Array = _seen_play.get(key, [false, null, 0.0])
		var pos: float = p.get_playback_position() if playing else 0.0
		if playing and p.stream and ( not prev[0] or prev[1] != p.stream or pos + 0.02 < prev[2]):
			var nm: String = p.stream.resource_path.get_file().get_basename()
			if SOUND_KIND.has(nm):
				kind(SOUND_KIND[nm])
		_seen_play[key] = [playing, p.stream, pos]
