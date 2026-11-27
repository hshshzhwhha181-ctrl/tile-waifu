class_name V10RitBridge
extends RefCounted

# V10RitBridge — every place the rituals touch the rest of the game goes through here, so the lane works before the
# other 0.10 modules are merged and the integrator changes one file, not six.
#
#   lint(text) -> Array        V10Lint.check when the class exists, else the same §2.7 list (copy below)
#   bond(h, n, src)            V10Bond.gain (hard sources: streak_milestone, comeback, bday) or G.add_aff
#   grant(rewards, src) -> Array   applies a reward dict; returns the cascade rows [{kind, n, icon, text}]
#                              keys: gems, coins, tickets, hints, shuffles, undos, petals, leaves, frame, title, badge,
#                              aff {h: n}, pick_outfit (the d5 ladder choice; integrator hook), rested
#                              A sink callable (set_sink) replaces the whole thing in selftests.
#   hero_name(h), hero_color(h), partner(), heroes() (only G.HEROES: unknown heroines never celebrate)
#   register_frame(id, name, src)  V10ProfileCos.register when present (frames live there, spec §2.7); src is the
#                              registry's source dict ({type: bday|grant|streak, …}); ids follow the registry:
#                              fr_tea_1/2, fr_bday_<h>_<year>, fr_me_<year>, fr_back_<year>
#   bond_src(src) -> String    grant source → V10Bond source (comeback_ladder → comeback: hard, past the soft cap)
#   face_of(motif) -> int      tile face id whose art shows that motif (G.TILE_NAMES), -1 when none
#   reward_icon(kind) -> Texture2D
#
# Fallback grant writes the 0.10 glossary keys straight into G.S (gems, coins, tickets, petals); V10Wallet/V10Econ
# replace that through set_sink() in the integration (README, hook H7).

const BANNED_FALLBACK: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк",
	"успей", "последн", "только сегодня", "купи", "баннер", "акци", "цена"]
const ALLOW_FALLBACK: = ["однажды", "ещё одна", "одна чашка", "одна партия"]

const ICONS: = {
	"gems": "res://assets/icons/gem.png", "coins": "res://assets/icons/coin.png",
	"tickets": "res://assets/icons/ticket.png", "hints": "res://assets/icons/hint.png",
	"shuffles": "res://assets/icons/shuffle.png", "undos": "res://assets/icons/undo.png",
	"aff": "res://assets/icons/heart.png", "frame": "res://assets/icons/trophy.png",
	"title": "res://assets/icons/trophy.png", "badge": "res://assets/v10/rituals/bowl_master.webp",
	"leaves": "res://assets/v10/rituals/leaf.webp", "petals": "res://assets/icons/gift.png",
	"pick_outfit": "res://assets/icons/wardrobe.png", "rested": "res://assets/v10/rituals/leaf.webp",
}
const NAMES: = {
	"gems": "Кристаллы", "coins": "Монеты", "tickets": "Билет желания", "hints": "Подсказка", "shuffles": "Перемешать",
	"undos": "Отмена", "aff": "Симпатия", "frame": "Рамка", "title": "Титул", "badge": "Значок", "leaves": "Чайный лист",
	"petals": "Лепестки", "pick_outfit": "Наряд на выбор", "rested": "Отдых ×2",
}

static var _sink: Callable = Callable()
static var _classes: = {}


static func set_sink(c: Callable) -> void:
	_sink = c


static func klass(name: String) -> Script:
	if _classes.has(name):
		return _classes[name]
	var s: Script = null
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == name:
			s = load(str(c.path))
	_classes[name] = s
	return s


static func has_g() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.get_node_or_null("G") != null


# ── text ───────────────────────────────────────────────────────────────────────────────────────────────────────

static func lint(text: String) -> Array:
	var k: = klass("V10Lint")
	if k:
		return k.call("check", text)
	var low: = text.to_lower()
	for a in ALLOW_FALLBACK:
		low = low.replace(a, "#".repeat(a.length()))
	var bad: = []
	for w in BANNED_FALLBACK:
		if low.find(w) >= 0:
			bad.append(w)
	return bad


# ── heroines ───────────────────────────────────────────────────────────────────────────────────────────────────

static func heroes() -> Array:
	if has_g():
		return G.HERO_ORDER.duplicate()
	return ["mc", "rin", "hana", "yue", "nova"]


static func hero_name(h: String) -> String:
	if has_g() and G.HEROES.has(h):
		return str(G.HEROES[h].name)
	return {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}.get(h, h.capitalize())


static func short_name(h: String) -> String:
	return hero_name(h)


# genitive for «Праздник Ханы», «торт Новы» (indeclinable names stay as they are)
const GEN: = {"hana": "Ханы", "nova": "Новы", "zlata": "Златы", "kira": "Киры", "mari": "Мари", "miel": "Миэль",
	"shirin": "Ширин", "vesper": "Веспер", "kohaku": "Кохаку", "tsubame": "Цубамэ", "minamo": "Минамо"}

static func gen_name(h: String) -> String:
	return str(GEN.get(h, short_name(h)))


static func hero_color(h: String) -> Color:
	if has_g() and G.HEROES.has(h):
		return G.HEROES[h].color
	return Color("e8c47e")


static func partner() -> String:
	if has_g() and G.S is Dictionary:
		return str(G.S.get("partner", "mc"))
	return "mc"


static func portrait(h: String) -> Texture2D:
	var p: = V10W1Core.hero_png(h)
	if not ResourceLoader.exists(p):
		p = "res://assets/hero/mc.png"
	return load(p) if ResourceLoader.exists(p) else null


# ── rewards ────────────────────────────────────────────────────────────────────────────────────────────────────

static func rows(rewards: Dictionary) -> Array:
	var out: = []
	for k in rewards:
		var v = rewards[k]
		if k == "aff":
			for h in v:
				out.append({"kind": "aff", "n": int(v[h]), "h": h, "icon": ICONS.aff, "text": "+%d · %s" % [int(v[h]), hero_name(h)]})
		elif v is String:
			out.append({"kind": k, "n": 1, "id": v, "icon": ICONS.get(k, ICONS.gems), "text": NAMES.get(k, k)})
		elif v is bool:
			if v:
				out.append({"kind": k, "n": 1, "icon": ICONS.get(k, ICONS.gems), "text": NAMES.get(k, k)})
		else:
			out.append({"kind": k, "n": int(v), "icon": ICONS.get(k, ICONS.gems), "text": "%s ×%d" % [NAMES.get(k, k), int(v)]})
	return out


static func grant(rewards: Dictionary, src: String) -> Array:
	var r: = rows(rewards)
	if _sink.is_valid():
		_sink.call(rewards, src)
		return r
	if not has_g() or not (G.S is Dictionary):
		return r
	for k in rewards:
		var v = rewards[k]
		match k:
			"gems", "coins", "tickets", "petals":
				var mon: = klass("V10Money")
				if not V10RitSave._bound and mon != null and mon.has_method("grant"):
					mon.call("grant", {k: int(v)}, src)
				else:
					G.S[k] = int(G.S.get(k, 0)) + int(v)
			"leaves":
				V10Streak.st().leaves = mini(V10Streak.LEAF_MAX, int(V10Streak.st().leaves) + int(v))
			"hints", "shuffles", "undos":
				var inv: Dictionary = G.S.get("v10_items", {})
				inv[k] = int(inv.get(k, 0)) + int(v)
				G.S["v10_items"] = inv
			"aff":
				for h in v:
					bond(h, int(v[h]), src)
			"frame", "title", "badge":
				var cos: = klass("V10ProfileCos")
				if cos:
					cos.call("grant", G.S, str(v))
				else:
					var own: Dictionary = G.S.get("v10_cos_owned", {})
					own[str(v)] = true
					G.S["v10_cos_owned"] = own
	return r


# spec §2.4: birthday, comeback and streak milestones are HARD sources (past the soft cap of 25 a day). V10Bond
# knows them as "bday", "comeback", "streak_milestone"; an unknown source would be capped as a soft one.
const BOND_SRC: = {"comeback_ladder": "comeback", "comeback": "comeback", "bday": "bday", "player_bday": "bday",
	"streak_milestone": "streak_milestone"}


static func bond_src(src: String) -> String:
	return str(BOND_SRC.get(src, src))


static func bond(h: String, n: int, src: String) -> void:
	src = bond_src(src)
	var b: = klass("V10Bond")
	if b:
		b.call("gain", h, n, src)


# the entry follows the V10ProfileCos schema (check_entry: tier A|S|SSR, src.type, look.base), so the registry
# accepts it and grant() can hand it out; a frame the registry already builds itself (fr_tea_1/2) is left alone
static func frame_entry(id: String, name: String, src: Dictionary) -> Dictionary:
	var look: = {"base": "ring", "deco": "plate", "deco_col": "f2d49a"}
	if src.has("year"):
		look["text"] = str(int(src.year))
	var h: = str(src.get("hero", ""))
	if h != "":
		look["deco_col"] = hero_color(h).to_html(false)
		look["glow"] = look.deco_col
	var e: = {"id": id, "kind": "frame", "name": name, "tier": "S", "src": src.duplicate(), "look": look}
	if h != "":
		e["hero"] = h
	return e


static func register_frame(id: String, name: String, src: Dictionary) -> void:
	var cos: = klass("V10ProfileCos")
	if cos == null:
		return
	if bool(cos.call("has", id, "")):
		return
	var err = cos.call("register", frame_entry(id, name, src))
	if str(err) != "":
		push_warning("V10RitBridge.register_frame: %s" % err)


# ── 0.9 login reward (moves onto the tray, UX_RULES §3.2) ─────────────────────────────────────────────────────

const LOGIN_FALLBACK: = [{"gems": 50}, {"gems": 50}, {"coins": 500}, {"gems": 100}, {"gems": 50}, {"coins": 1000}, {"gems": 300}]


static func login_reward(n: int) -> Dictionary:
	var arr: Array = G.LOGIN_REWARDS if has_g() else LOGIN_FALLBACK
	return (arr[posmod(n, arr.size())] as Dictionary).duplicate()


# the calendar date S.login.last is compared with: G.today() in the game, the pinned clock in selftests
static func legacy_today() -> String:
	if V10RitSave._bound or not has_g():
		var d: = Time.get_datetime_dict_from_unix_time(V10RitClock.now_unix() + V10RitClock.tz_bias_sec())
		return "%04d-%02d-%02d" % [d.year, d.month, d.day]
	return str(G.today())


# ── tiles ──────────────────────────────────────────────────────────────────────────────────────────────────────

const TILE_FALLBACK: = {"sakura": 0, "sunflower": 3, "moon": 7, "cake": 16, "matcha": 21, "diamond": 24}


static func face_of(motif: String) -> int:
	if motif == "":
		return -1
	if has_g():
		return (G.TILE_NAMES as Array).find(motif)
	return int(TILE_FALLBACK.get(motif, -1))


static func reward_icon(kind: String) -> Texture2D:
	var p: String = ICONS.get(kind, ICONS.gems)
	return load(p) if ResourceLoader.exists(p) else null
