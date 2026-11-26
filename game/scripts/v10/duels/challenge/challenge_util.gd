class_name V10ChallengeUtil
extends RefCounted

# «Вызов по коду» (spec 0.10 R5): small glue shared by the module. Pure static helpers, no scene of its own.
#
# Optional classes of sibling lanes (V10Meta, V10Econ, V10Save, V10Lint, V10LevelGen, V10Journey, V10SfxBank,
# V10Music …) are looked up by name at run time (cls()), so this folder parses and its selftest runs even when a
# lane is missing. Inside the module every file reaches the others through preload(), never through class_name.
#
#   time      now_unix() · day_key() · day_index(key) · date_of_index(i) · clock_ok()   (V10Meta, else the old clock)
#   feel      press(node) · deny(node) · sfx(id) · fx_min()                               (V9Feel for EVERY tap)
#   clipboard clip_set(text) · clip_get()                                                 (only ever called from a tap)
#   text      fmt_time(t) «1:42» · fmt_time_full(t) «1:42,3» · fmt_delta(t) «−3,0 с» · plural() · bad_words(text)
#   nick      nick_ok(nick)                                     (G.nick_error + the V8 profanity list)
#   rewards   econ_num(key, def) · apply_rewards(r, src)        (THE one place that pays: economy facade if present)
#   save      save_game()                                       (G.save unless a test switched disk writes off)
#   album     save_poster(img) -> path                          (internal V7Album «Снимки»; no system gallery until 1.0)
#   screens   open_screen(main, script, id, args) · go_challenge(main, args) · go_play(main, args)

const ROOT: = "res://scripts/v10/duels/challenge/"
const SCREEN_PATH: = ROOT + "challenge_screen.gd"
const PLAY_PATH: = ROOT + "challenge_play.gd"

# ---------------------------------------------------------------- soft class lookup

static var _cls: = {}


static func cls(n: String) -> Script:
	if _cls.has(n):
		return _cls[n]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == n:
			s = load(String(c.path))
			break
	_cls[n] = s
	return s


static func has_fn(s, fn: String) -> bool:
	if s == null:
		return false
	if s is Script:
		for m in (s as Script).get_script_method_list():
			if String(m.get("name", "")) == fn:
				return true
		return false
	return s is Object and (s as Object).has_method(fn)


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func g() -> Node:
	var t: = tree()
	return t.root.get_node_or_null("G") if t else null


static func gs() -> Dictionary:
	var gg: = g()
	if gg and gg.get("S") is Dictionary:
		return gg.S
	return {}

# ---------------------------------------------------------------- time (spec §2.5: one clock, V10Meta)

static var fake_now: = 0  # tests: frozen unix time
static var fake_day: = ""  # tests: frozen day key
static var fake_clock_ok: = true  # tests: «the phone clock was moved back» while the time is frozen


static func now_unix() -> int:
	if fake_now != 0:
		return fake_now
	var m: = cls("V10Meta")
	if m:
		return int(m.call("now_unix"))
	return 0  # V10Meta is the one clock of the game; without it (a bare unit test) time stands still


static func day_key() -> String:
	if fake_day != "":
		return fake_day
	var m: = cls("V10Meta")
	if m:
		return String(m.call("day_key"))
	var gg: = g()
	return String(gg.call("today")) if gg else date_of_index(0)


static func clock_ok() -> bool:
	if fake_now != 0 or fake_day != "":
		return fake_clock_ok
	var m: = cls("V10Meta")
	return bool(m.call("clock_ok")) if m else true


static func day_index(key: String) -> int:
	if key.length() < 10:
		return -1
	return days_from_civil(int(key.substr(0, 4)), int(key.substr(5, 2)), int(key.substr(8, 2)))


# proleptic Gregorian calendar, pure integer math (Howard Hinnant): days since 1970-01-01
static func days_from_civil(y: int, m: int, d: int) -> int:
	var yy: = y - (1 if m <= 2 else 0)
	var era: = (yy if yy >= 0 else yy - 399) / 400
	var yoe: = yy - era * 400
	var doy: = (153 * (m + (-3 if m > 2 else 9)) + 2) / 5 + d - 1
	var doe: = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func civil_from_days(z0: int) -> Vector3i:
	var z: = z0 + 719468
	var era: = (z if z >= 0 else z - 146096) / 146097
	var doe: = z - era * 146097
	var yoe: = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y: = yoe + era * 400
	var doy: = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: = (5 * doy + 2) / 153
	var d: = doy - (153 * mp + 2) / 5 + 1
	var m: = mp + (3 if mp < 10 else -9)
	return Vector3i(y + (1 if m <= 2 else 0), m, d)


# «2026-11-24 12:30:05» pieces of a unix time, UTC
static func stamp_of(u: int) -> String:
	var days: = int(floor(float(u) / 86400.0))
	var rem: = u - days * 86400
	var c: = civil_from_days(days)
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [c.x, c.y, c.z, rem / 3600, (rem % 3600) / 60, rem % 60]


static func date_of_index(i: int) -> String:
	var c: = civil_from_days(i)
	return "%04d-%02d-%02d" % [c.x, c.y, c.z]


const MONTHS_GEN: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября",
	"ноября", "декабря"]


# «24 ноября»
static func date_text(key: String) -> String:
	if key.length() < 10:
		return key
	return "%d %s" % [int(key.substr(8, 2)), MONTHS_GEN[clampi(int(key.substr(5, 2)) - 1, 0, 11)]]

# ---------------------------------------------------------------- feel (UX §6.7, spec §1.2)

static func press(node: CanvasItem, snd: = "pop") -> void:
	if node and is_instance_valid(node):
		V9Feel.press(node, snd, "button")


static func deny(node: CanvasItem) -> void:
	if node and is_instance_valid(node):
		V9Feel.deny(node)


static func sfx(id: String) -> void:
	var bank: = cls("V10SfxBank")
	if bank and tree():
		bank.call("play", id, {})
		return
	V10Hud2Util.sfx(id)


static func music(method: String, args: = []) -> void:
	var m: = cls("V10Music")
	if m and tree():
		m.callv(method, args)


static func fx_level() -> String:
	return V10Hud2Util.fx_level()


static func fx_min() -> bool:
	return fx_level() == "min"


# «Шёлк» 180–240 ms QUINT OUT; at fx «минимум» every movement becomes a 120 ms fade (UX §6.7)
static func silk_in(c: CanvasItem, from_offset: = Vector2(0, 24), dur: = 0.22, delay: = 0.0) -> void:
	if c == null:
		return
	c.modulate.a = 0.0
	var tw: = c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	if fx_min():
		tw.tween_property(c, "modulate:a", 1.0, 0.12)
		return
	if c is Control:
		var p: Vector2 = (c as Control).position
		(c as Control).position = p + from_offset
		tw.set_parallel(true)
		tw.tween_property(c, "position", p, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- clipboard (only from a tap)

static var mem_clip: = false  # headless tests: keep the clipboard in memory
static var _clip: = ""


static func clip_set(text: String) -> void:
	_clip = text
	if not mem_clip and DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)


static func clip_get() -> String:
	if mem_clip or DisplayServer.get_name() == "headless":
		return _clip
	return DisplayServer.clipboard_get()

# ---------------------------------------------------------------- text

# «1:42» (minutes:seconds); the poster and the card round down to whole seconds, the result shows tenths
static func fmt_time(tenths: int) -> String:
	var s: = maxi(0, tenths) / 10
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


static func fmt_time_full(tenths: int) -> String:
	return "%s,%d" % [fmt_time(tenths), maxi(0, tenths) % 10]


# «−3,0 с» faster than the author, «+1,2 с» slower (true minus sign U+2212, comma decimals)
static func fmt_delta(tenths: int) -> String:
	var a: = absi(tenths)
	var sign: = "−" if tenths < 0 else ("+" if tenths > 0 else "")
	var s: = a / 10
	if s >= 60:
		return "%s%d:%02d,%d" % [sign, s / 60, s % 60, a % 10]
	return "%s%d,%d с" % [sign, s, a % 10]


# milliseconds of the process clock, for test timeouts and benchmarks only (never for game logic: that is V10Meta)
static func tick_ms() -> int:
	return int(Engine.get_singleton("Time").call("get_ticks_msec"))


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = absi(n) % 10
	var m100: = absi(n) % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


static func gems_text(n: int) -> String:
	return "%d %s" % [n, plural(n, "кристалл", "кристалла", "кристаллов")]


static func stars_text(n: int) -> String:
	return "★".repeat(clampi(n, 0, 3)) + "☆".repeat(3 - clampi(n, 0, 3))


# UX_RULES §4.2 / §4.3 words a player must not see (lower case, substring) + the contract signs «%» and «₽»
const UI_BANNED: = ["гарант", "пити", "pity", "50/50", "гача", "ролл", "крутк", "фивер", "ивент", "квартал", "перк",
	"ульта", "риичи", "яку", "банер", "донат", "выгодно", "успей", "последний шанс", "топ-100", "богин", "режимы",
	"лихорадк", "гардероб", "поручени", "лунная лестница", "осколок портрета"]


static func bad_words(text: String) -> Array:
	var out: = []
	var lint: = cls("V10Lint")
	if lint:
		out.append_array(lint.call("check", text))
	var low: = text.to_lower()
	for w in UI_BANNED:
		if low.find(w) >= 0:
			out.append(w)
	for sgn in ["%", "₽"]:
		if text.find(sgn) >= 0:
			out.append(sgn)
	return out

# ---------------------------------------------------------------- nick

# The V8 profanity filter is the second half of V8Population.BANNED (from «сука» on); the first half are league
# words reserved for the simulated population, and «бот» marks bots — both are fine in a real player's nick.
static func profanity() -> Array:
	var all: Array = V8Population.BANNED
	var i: = all.find("сука")
	var out: = []
	for k in range(maxi(0, i), all.size()):
		if not String(all[k]) in ["бот", "bot"]:
			out.append(String(all[k]))
	return out


static func nick_ok(n: String) -> bool:
	var gg: = g()
	if gg == null or String(gg.call("nick_error", n)) != "":
		return false
	var low: = n.to_lower()
	for b in profanity():
		if low.find(b) >= 0:
			return false
	return true


static func my_nick() -> String:
	var gg: = g()
	return String(gg.call("nick")) if gg else ""

# ---------------------------------------------------------------- numbers and rewards

# spec §2.2: the numbers live in economy.json via V10Econ; until a key is there the module default is used
static func econ_num(key: String, def):
	var e: = cls("V10Econ")
	if e and has_fn(e, "get_num"):
		var v = e.call("get_num", key)
		if v != null:
			return v
	return def


# tests / the integrator may route payments elsewhere: sink.call(rewards: Dictionary, src: String)
static var reward_sink: = Callable()


# THE one place that pays the module's rewards. {gems: n} → the economy facade (G.econ.grant({"crystal": n}, src))
# when the v10-economy lane is wired into G, else the 0.9 field S.gems. Nothing else in the module touches currency.
static func apply_rewards(r: Dictionary, src: String) -> void:
	if r.is_empty():
		return
	if reward_sink.is_valid():
		reward_sink.call(r, src)
		return
	var gg: = g()
	if gg == null:
		return
	var n: = int(r.get("gems", 0))
	if n <= 0:
		return
	var money: = cls("V10Money")
	if money != null:
		money.call("grant", {"gems": n}, src)

# ---------------------------------------------------------------- save

static var no_disk: = false


static func save_game() -> void:
	if no_disk:
		return
	var gg: = g()
	if gg and gg.has_method("save"):
		gg.call("save")

# ---------------------------------------------------------------- album (internal; system gallery is 1.0)

static var album_dir_override: = ""


static func album_dir() -> String:
	if album_dir_override != "":
		return album_dir_override
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--album_photos="):
			return a.substr(15)
	return OS.get_user_data_dir().path_join("photos")


# writes the poster PNG into the game's own photo folder and lists it in V7Album «Снимки»; returns the path or ""
static func save_poster(img: Image, tag: = "") -> String:
	if img == null or img.is_empty():
		return ""
	var d: = album_dir()
	if DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
		return ""
	var stamp: = stamp_of(now_unix())
	var p: = d.path_join("TileWaifu_vyzov_%s%s.png" % [stamp, ("_" + tag) if tag != "" else ""])
	if img.save_png(p) != OK or not FileAccess.file_exists(p):
		return ""
	var t: = tree()
	var album: Node = t.root.get_node_or_null("V7Album") if t else null
	if album and album.has_method("photos") and not no_disk:
		album.call("add_photo", p)
	elif album and album.has_method("st"):
		var s: Dictionary = album.call("st")
		(s.photos as Array).push_front(p)
	return p

# ---------------------------------------------------------------- screens

# mirrors main.go() for a screen that is not (yet) in main.SCREENS: same root, same rect, same meta, then build()
static func open_screen(main, script: Script, id: String, args: = {}) -> Control:
	if main == null:
		return null
	for p in main.overlay.get_children():
		if p.has_meta("popup") or p.has_meta("v8_back"):
			p.queue_free()
	# the history entry main.go() would write, so «назад» of the next screen comes back here
	var from_id: = String(main.screen_id)
	if main.get("history") is Array and from_id != "" and from_id != id and _has_screen(main, from_id):
		var fa: Dictionary = main.screen.get_meta("v8_args", {}) if main.screen and is_instance_valid(main.screen) else {}
		(main.history as Array).append([from_id, fa])
	if main.screen and is_instance_valid(main.screen):
		main.screen.queue_free()
	main.screen_id = id
	var match_z: bool = main.PLAY_BACK.has(id)
	main.overlay.z_index = 400 if match_z else 0
	main.trans.z_index = 450 if match_z else 0
	var sc: = Control.new()
	sc.set_script(script)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.position = main.CR.position
	sc.size = main.CR.size
	sc.set_meta("v8_args", args.duplicate())
	main.screen_root.add_child(sc)
	main.screen = sc
	sc.call("build", main, args)
	if main.has_method("refresh_nav"):
		main.refresh_nav()
	return sc


static func _has_screen(main, id: String) -> bool:
	return main != null and main.get("SCREENS") is Dictionary and (main.SCREENS as Dictionary).has(id)


# the «Вызов по коду» screen: main.go("challenge") once the integrator registered it, else the same build in place
static func go_challenge(main, args: = {}) -> void:
	if _has_screen(main, "challenge"):
		main.go("challenge", args)
	else:
		open_screen(main, load(SCREEN_PATH), "challenge", args)


# a challenge run: SCREENS["challenge_play"] (challenge_play.gd = play.gd + the R5 hooks), else the same in place
static func go_play(main, args: Dictionary) -> void:
	if _has_screen(main, "challenge_play"):
		main.go("challenge_play", args)
	else:
		open_screen(main, load(PLAY_PATH), "play", args)
