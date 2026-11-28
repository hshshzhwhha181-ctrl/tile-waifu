class_name V10Phone
extends RefCounted

# V10Phone — the «Телефон» facade (docs/0.10-spec.md §Р8–Р9): one place that the phone UI (and the integrator)
# talks to. It owns no game rules of its own: chats and feed rules live in v10/chat (V10Chat, V10ChatFeed,
# V10LocalTransport), letters in V9Letters. Here: save keys, ctx, the transport singleton, the badge, affection
# routing (V10Bond when it is in the build), day keys (V10Meta when it is in the build), sticker art, sounds.
#
#   V10Phone.ensure()                     adds S.v10_phone / S.v10_feed when missing (idempotent; V10Save does it in M1)
#   V10Phone.ctx() -> Dictionary          {day, md, partner, owned, levels, name, name_voc, gender}
#   V10Phone.transport() -> V10LocalTransport    the session transport (re-created when G.S was replaced by a load/restore)
#   V10Phone.tick()                       new day / app resume: opens today's threads
#   V10Phone.event(ev)                    game events → chats ({kind="first_win"} … see chat README)
#   V10Phone.badge() -> int               letters + chats waiting + new posts (the home «Телефон» button)
#   V10Phone.badge_parts() -> {mail, chats, feed}
#   V10Phone.gain(effects) -> int         affection through V10Bond.gain (soft cap 25); returns what was given
#   V10Phone.set_player_name(nom, g)             «Как ей тебя звать?»
#   V10Phone.sticker_tex(id) -> Texture2D the sticker art or null (UI then draws glyph + label)
#   V10Phone.open(main, args)             slides the phone over the current screen (overlay); see phone_screen.gd
#   V10Phone.shutdown()                   drops the static caches at app exit
#
# Test hooks: day_shift (days added to the day key), bond_sink (Callable(h, n, src) -> int used instead of V10Bond).

const C: = preload("res://core/chat/chat.gd")
const D: = preload("res://core/chat/chat_data.gd")
const FEED: = preload("res://core/chat/chat_feed.gd")
const TR: = preload("res://core/chat/local_transport.gd")
const NAMES: = preload("res://core/phone/names.gd")
const PUI: = preload("res://scripts/v10/phone/phone_ui.gd")

const META_PATH: = "res://core/meta/meta.gd"
const BOND_PATH: = "res://core/meta/bond.gd"
const STICKER_DIR: = "res://assets/v10/phone/stickers/"
const LOG_DIR: = "user://v10_logs/"
const TABS: = ["feed", "chats", "mail"]
# chat module source names → V10Bond source names (§2.4)
const SRC_MAP: = {"chat": "chat_branch", "feed_like": "feed_like", "feed_reply": "feed_reply"}

static var day_shift: = 0
static var bond_sink: Callable = Callable()
static var log_dir: = LOG_DIR
static var _tr: V10LocalTransport = null
static var _meta: Variant = null
static var _bond: Variant = null


static func _script(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


static func meta() -> Variant:
	if _meta == null:
		_meta = _script(META_PATH)
		if _meta == null:
			_meta = false
	return _meta if _meta is Script else null


static func bond() -> Variant:
	if _bond == null:
		_bond = _script(BOND_PATH)
		if _bond == null:
			_bond = false
	return _bond if _bond is Script else null


# --- save --------------------------------------------------------------------------

static func default_state() -> Dictionary:
	return {"chat": C.default_state(), "name": {"nom": "", "voc": "", "g": "m"}, "named": false, "tab": "chats",
		"recent_st": [], "intro": false}


static func ensure() -> Dictionary:
	var S: Dictionary = G.S
	if not S.get("v10_phone") is Dictionary:
		S["v10_phone"] = default_state()
	var p: Dictionary = S.v10_phone
	var d: = default_state()
	for k in d:
		if not p.has(k) or typeof(p[k]) != typeof(d[k]):
			p[k] = d[k]
	C.ensure(p.chat)
	if not str(p.tab) in TABS:
		p.tab = "chats"
	if not S.get("v10_feed") is Dictionary:
		S["v10_feed"] = FEED.default_state()
	FEED.ensure(S.v10_feed)
	return p


static func st() -> Dictionary:
	return ensure()


static func feed_st() -> Dictionary:
	ensure()
	return G.S.v10_feed


# --- day ----------------------------------------------------------------------------

# {day: int day index, key: "YYYY-MM-DD", md: "MM-DD"}; V10Meta (04:00 local day) when it is in the build
static func day_info() -> Dictionary:
	var key: = ""
	var idx: = 0
	var m = meta()
	if m != null:
		key = str(m.day_key())
		idx = int(m.day_index(key))
	else:
		# fallback before M1 is merged: local day that starts at 04:00 (same rule as V10Meta)
		var dt: = Time.get_datetime_dict_from_system()
		var u: = int(Time.get_unix_time_from_datetime_dict(dt)) - 4 * 3600
		var d2: = Time.get_datetime_dict_from_unix_time(u)
		key = "%04d-%02d-%02d" % [d2.year, d2.month, d2.day]
		idx = int(floor(u / 86400.0))
	if day_shift != 0:
		idx += day_shift
		var dd: = Time.get_datetime_dict_from_unix_time(idx * 86400)
		key = "%04d-%02d-%02d" % [dd.year, dd.month, dd.day]
	return {"day": idx, "key": key, "md": key.substr(5)}


# --- ctx ----------------------------------------------------------------------------

static func owned() -> Array:
	var out: = []
	for h in G.HERO_ORDER:
		if h in D.HEROES and G.hero_unlocked(h):
			out.append(h)
	return out


static func ctx() -> Dictionary:
	var p: = ensure()
	var di: = day_info()
	var lv: = {}
	for h in D.HEROES:
		lv[h] = G.aff_level(h)
	var nm: Dictionary = p.name
	return {"day": di.day, "md": di.md, "partner": str(G.S.get("partner", "mc")), "owned": owned(), "levels": lv,
		"name": str(nm.get("nom", "")), "name_voc": str(nm.get("voc", "")), "gender": str(nm.get("g", "m"))}


static func set_player_name(nom: String, g: = "") -> void:
	var p: = ensure()
	p.name = NAMES.record(nom, g)
	p.named = true


static func name_label() -> String:
	var nm: Dictionary = ensure().name
	return str(nm.nom) if str(nm.get("nom", "")) != "" else C.NAME_FALLBACK


# --- transport ----------------------------------------------------------------------

static func transport() -> V10LocalTransport:
	var p: = ensure()
	if _tr == null or not is_same(_tr.state, p.chat):
		_tr = TR.new(p.chat, log_dir)
	return _tr


static func reset() -> void:
	_tr = null


# app exit (integrator: main's NOTIFICATION_WM_CLOSE_REQUEST / tree_exiting) and test teardown: drop every static
# reference (transport, test sink, font / texture / sound caches) so nothing outlives the SceneTree
static func shutdown() -> void:
	_tr = null
	bond_sink = Callable()
	day_shift = 0
	PUI.clear()


static func tick() -> Array:
	return transport().tick(ctx()).get("opened", [])


static func event(ev: Dictionary) -> Array:
	return transport().post_event(ev, ctx()).get("opened", [])


# --- badge --------------------------------------------------------------------------

static func mail_unread() -> int:
	return V9Letters.badge_count()


static func badge_parts() -> Dictionary:
	var c: = ctx()
	return {"mail": mail_unread(), "chats": transport().unread(), "feed": FEED.unseen(feed_st(), c)}


static func badge() -> int:
	var b: = badge_parts()
	return int(b.mail) + int(b.chats) + int(b.feed)


# --- affection ----------------------------------------------------------------------

# every effect goes through V10Bond.gain (soft cap 25/day). Without V10Bond in the build (lane test) the effects
# go to bond_sink, or nowhere: this module never writes affection itself (spec §2.4 grep rule).
static func gain(effects: Array) -> int:
	var total: = 0
	for e in effects:
		var src: String = SRC_MAP.get(str(e.get("src", "")), str(e.get("src", "")))
		var h: = str(e.get("hero", ""))
		var n: = int(e.get("n", 0))
		if bond_sink.is_valid():
			total += int(bond_sink.call(h, n, src))
		else:
			var b = bond()
			if b != null:
				total += int(b.gain(h, n, src))
	return total


# --- art ----------------------------------------------------------------------------

static func sticker_path(id: String) -> String:
	var p: = STICKER_DIR + id + ".webp"
	return p if ResourceLoader.exists(p) else ""


static func sticker_tex(id: String) -> Texture2D:
	var p: = sticker_path(id)
	return load(p) if p != "" else null


static func photo_tex(img: String) -> Texture2D:
	var p: = D.photo_path(img)
	return load(p) if p != "" else null


static func hero_color(h: String) -> Color:
	return G.HEROES[h].color if G.HEROES.has(h) else PUI.HERO_FALLBACK


static func hero_name(h: String) -> String:
	return str(D.HERO_NAME.get(h, G.HEROES.get(h, {}).get("name", h)))


# --- open ---------------------------------------------------------------------------

# the phone slides up over whatever screen is open (home): main.overlay child, Android «назад» closes it
static func open(main, args: = {}) -> Control:
	var scr: GDScript = load("res://scripts/v10/phone/phone_screen.gd")
	var ph: Control = scr.new()
	ph.size = Vector2(main.W, main.H) if main != null and "W" in main else Vector2(720, 1280)
	var host: Control = main.overlay if main != null and "overlay" in main and main.overlay != null else main
	host.add_child(ph)
	ph.call("build_overlay", main, args)
	return ph
