class_name V10Wave1
extends RefCounted

# V10Wave1 — unified idempotent facade for the Five Wave-1 Heroines (docs/ROSTER_20.md §2, §3.2–3.4):
#   tsubame (A) · miel (A) · kohaku (S) · shirin (S) · zlata (SSR)
#
# Exposes:
#   V10Wave1.install(g = null, opts = {}) -> Dictionary   idempotent registration into all writable runtime registries
#   V10Wave1.register_all(g = null, opts = {}) -> Dictionary   alias of install()
#   V10Wave1.apply(g = null) -> void                      save sanitize + install(g) when released() (core_apply hook)
#   V10Wave1.count() -> Dictionary                        canonical counts across all Wave-1 sub-modules
#   V10Wave1.released() / set_released(on)                Wave-1 roster gate (default true; CLI --wave1=0|1)
#   V10Wave1.banners_enabled() / set_banners_enabled(on)  optional gacha banner splice gate (CLI --wave1_banners=0|1)
#   V10Wave1.install_into(targets: Dictionary) -> Dictionary   overlay merge on caller-supplied dictionaries (W4/tests)

const HERO_ORDER: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]
const SAVE_RELEASE_KEY: = "w1_released"
const SAVE_BANNERS_KEY: = "w1_banners"
const SAVE_RELEASE_T_KEY: = "w1_release_t"

static var _installed: = false
static var _released_override: int = -1      # -1 = auto (default true unless --wave1=0 or save sets false), 0 = off, 1 = on
static var _banners_override: int = -1       # -1 = auto (follows released() unless --wave1_banners=0), 0 = off, 1 = on
static var _release_t_override: int = 0
static var _merged_heroes: Dictionary = {}
static var _merged_order: Array = []
static var _merged_bases: Array = []
static var _last_report: Dictionary = {}


# ------------------------------------------------------------------ release & banner flags

static func _cli_flag(prefix: String) -> int:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s: = String(a)
		if s == prefix or s == prefix + "=1" or s == prefix + "=true":
			return 1
		if s == prefix + "=0" or s == prefix + "=false":
			return 0
	return -1


static func released() -> bool:
	if _released_override >= 0:
		return _released_override == 1
	var cli: = _cli_flag("--wave1")
	if cli >= 0:
		return cli == 1
	var g: = _g()
	if g != null:
		var sv = g.get("S")
		if sv is Dictionary and (sv as Dictionary).has(SAVE_RELEASE_KEY):
			return bool(sv[SAVE_RELEASE_KEY])
	return true


static func set_released(on: bool) -> void:
	_released_override = 1 if on else 0


static func banners_enabled() -> bool:
	if not released():
		return false
	if _banners_override >= 0:
		return _banners_override == 1
	var cli: = _cli_flag("--wave1_banners")
	if cli >= 0:
		return cli == 1
	var g: = _g()
	if g != null:
		var sv = g.get("S")
		if sv is Dictionary and (sv as Dictionary).has(SAVE_BANNERS_KEY):
			return bool(sv[SAVE_BANNERS_KEY])
	return true


static func set_banners_enabled(on: bool) -> void:
	_banners_override = 1 if on else 0
	_flush_banner_cache()


static func release_t() -> int:
	if _release_t_override > 0:
		return _release_t_override
	var g: = _g()
	if g != null:
		var sv = g.get("S")
		if sv is Dictionary and int(sv.get(SAVE_RELEASE_T_KEY, 0)) > 0:
			return int(sv[SAVE_RELEASE_T_KEY])
	return 0


static func set_release_t(t: int) -> void:
	_release_t_override = maxi(0, t)


static func is_installed() -> bool:
	return _installed


static func reset_for_test() -> void:
	_installed = false
	_released_override = -1
	_banners_override = -1
	_release_t_override = 0
	_merged_heroes.clear()
	_merged_order.clear()
	_merged_bases.clear()
	_last_report.clear()


# ------------------------------------------------------------------ counts & summary

static func hero_count() -> int:
	return V10W1Core.HERO_ORDER.size()


static func outfit_count() -> int:
	return V10W1Core.ITEMS.size()


static func count() -> Dictionary:
	var th_n: = 0
	for h in HERO_ORDER:
		th_n += V10W1Social.threads(h).size()
	var st_n: = 0
	var st_all: = V10W1Social.stickers()
	for h in HERO_ORDER:
		st_n += (st_all.get(h, []) as Array).size()
	var pose_n: = 5 # 5 <hero>_idle slots
	for h in HERO_ORDER:
		pose_n += (V10W1Core.POSE_SLOTS.get(h, []) as Array).size()
	return {
		"heroes": V10W1Core.HERO_ORDER.size(),
		"outfits": V10W1Core.ITEMS.size(),
		"legwear": V10W1Core.LEGWEAR.size(),
		"passives": V10W1Play.PASSIVES.size(),
		"ults": V10W1Ults.ULTS.size(),
		"kits": V10W1Look.KITS.size(),
		"themes": V10W1Look.THEMES.size(),
		"banners": V10W1Gacha.phases().size(),
		"emotions": V10W1Core.HERO_ORDER.size() * V10W1Core.EMOTIONS.size(),
		"poses": pose_n,
		"bday_sigs": V10W1Social.SIG.size(),
		"chat_threads": th_n,
		"stickers": st_n,
		"feed": V10W1Social.feed().size(),
		"voiced_lines": V10W1Audio.texts().size(),
		"installed": _installed,
		"released": released(),
		"banners_enabled": banners_enabled(),
	}


# ------------------------------------------------------------------ idempotent registration

static func register_all(g: Node = null, opts: Dictionary = {}) -> Dictionary:
	return install(g, opts)


static func apply(g: Node = null) -> void:
	var gn: = g if g != null else _g()
	if not released():
		if gn != null and gn.get("S") is Dictionary and gn.get("HEROES") is Dictionary:
			V10W1Core.sanitize_save(gn.S, gn.HEROES)
		return
	install(gn)


static func install(g: Node = null, opts: Dictionary = {}) -> Dictionary:
	if opts.has("released"):
		set_released(bool(opts.released))
	if opts.has("banners"):
		set_banners_enabled(bool(opts.banners))
	if opts.has("release_t"):
		set_release_t(int(opts.release_t))
	var gn: = g if g != null else _g()
	if not released():
		if gn != null and gn.get("S") is Dictionary and gn.get("HEROES") is Dictionary:
			V10W1Core.sanitize_save(gn.S, gn.HEROES)
		_last_report = {"installed": false, "released": false, "banners_enabled": false, "mutated": [], "pending_hooks": []}
		return _last_report
	var mutated: Array = []
	var pending: Array = []
	# 1. Build merged runtime views (always available via V10Wave1.heroes() / hero_order() / base_outfits())
	_build_merged_views(gn)
	# 2. G tables (ITEMS & ITEM are mutable vars right now; HEROES/HERO_ORDER/BASE_OUTFITS/SKILLS/PERKS merge once W4 var-hooks land)
	if gn != null:
		_install_g(gn, mutated, pending)
	# 3. Hero.RIGS & V8Art face tables
	_install_art(mutated, pending)
	# 4. Look kits, tile themes, frames, HUD accents & combo showcase lines
	_install_look(mutated, pending)
	# 5. Home lines, touch zones, letters, arrivals, rooms & barks
	_install_home(mutated, pending)
	# 6. Play tables (V6Heroines, V7Passives, V6ModesData, V8AI) when writable
	_install_play(mutated, pending)
	# 7. Ults (V9Ults.CORES / ULTS) when writable
	_install_ults(mutated, pending)
	# 8. Gacha banner cache invalidation + rituals tray provider
	_flush_banner_cache()
	_install_social_tray(mutated)
	_installed = true
	_last_report = {
		"installed": true,
		"released": true,
		"banners_enabled": banners_enabled(),
		"heroes": HERO_ORDER.size(),
		"outfits": V10W1Core.ITEMS.size(),
		"mutated": mutated,
		"pending_hooks": pending,
	}
	return _last_report


static func _build_merged_views(gn: Node) -> void:
	_merged_heroes.clear()
	_merged_order.clear()
	_merged_bases.clear()
	if gn != null and gn.get("HEROES") is Dictionary:
		for h in gn.HEROES:
			_merged_heroes[h] = (gn.HEROES[h] as Dictionary).duplicate(true)
	if gn != null and gn.get("HERO_ORDER") is Array:
		for h in gn.HERO_ORDER:
			if not (h in _merged_order):
				_merged_order.append(h)
	else:
		for h in FOUNDERS:
			_merged_order.append(h)
	if gn != null and gn.get("BASE_OUTFITS") is Array:
		for b in gn.BASE_OUTFITS:
			if not (b in _merged_bases):
				_merged_bases.append(b)
	for h in HERO_ORDER:
		if not _merged_heroes.has(h):
			_merged_heroes[h] = (V10W1Core.HEROES[h] as Dictionary).duplicate(true)
		if not (h in _merged_order):
			_merged_order.append(h)
	for b in V10W1Core.BASE_OUTFITS:
		if not (b in _merged_bases):
			_merged_bases.append(b)


static func _install_g(gn: Node, mutated: Array, pending: Array) -> void:
	# ITEMS and ITEM are mutable vars on G even before W4 hot-file hooks
	var items_v = gn.get("ITEMS")
	var item_m = gn.get("ITEM")
	if items_v is Array and item_m is Dictionary and not (items_v as Array).is_read_only() and not (item_m as Dictionary).is_read_only():
		for it in V10W1Core.items_copy():
			var id: = String(it.id)
			if not (item_m as Dictionary).has(id):
				(items_v as Array).append(it)
				(item_m as Dictionary)[id] = it
			else:
				# Ensure sfw, lw, rank metadata are present idempotently
				var cur: Dictionary = item_m[id]
				if not cur.is_read_only():
					for k in ["sfw", "lw", "rank"]:
						if it.has(k) and not cur.has(k):
							cur[k] = it[k]
		mutated.append("G.ITEMS+G.ITEM")
	else:
		pending.append("G.ITEMS")
	var gh = gn.get("HEROES")
	var go = gn.get("HERO_ORDER")
	var gb = gn.get("BASE_OUTFITS")
	if gh is Dictionary and not (gh as Dictionary).is_read_only():
		for h in HERO_ORDER:
			if not (gh as Dictionary).has(h):
				gh[h] = (V10W1Core.HEROES[h] as Dictionary).duplicate(true)
		mutated.append("G.HEROES")
	else:
		pending.append("G.HEROES")
	if go is Array and not (go as Array).is_read_only():
		for h in HERO_ORDER:
			if not (h in (go as Array)):
				(go as Array).append(h)
		mutated.append("G.HERO_ORDER")
	else:
		pending.append("G.HERO_ORDER")
	if gb is Array and not (gb as Array).is_read_only():
		for b in V10W1Core.BASE_OUTFITS:
			if not (b in (gb as Array)):
				(gb as Array).append(b)
		mutated.append("G.BASE_OUTFITS")
	else:
		pending.append("G.BASE_OUTFITS")
	for pair in [["SKILLS", V10W1Play.SKILLS], ["PERKS", V10W1Play.PERKS]]:
		var dst = gn.get(pair[0])
		if dst is Dictionary and not (dst as Dictionary).is_read_only():
			for h in HERO_ORDER:
				if not (dst as Dictionary).has(h):
					dst[h] = pair[1][h].duplicate(true) if pair[1][h] is Dictionary else pair[1][h]
			mutated.append("G." + String(pair[0]))
		else:
			pending.append("G." + String(pair[0]))


static func _install_art(mutated: Array, pending: Array) -> void:
	var probs: = V10W1Core.merge_art()
	var hs: = _klass("Hero")
	var vs: = _klass("V8Art")
	if hs != null and hs.get("RIGS") is Dictionary and not (hs.get("RIGS") as Dictionary).is_read_only():
		mutated.append("Hero.RIGS")
	else:
		pending.append("Hero.RIGS")
	if vs != null and vs.get("EMO_FACE") is Dictionary and not (vs.get("EMO_FACE") as Dictionary).is_read_only():
		mutated.append("V8Art.EMO_FACE*")
	else:
		pending.append("V8Art.EMO_FACE*")
	var _unused: = probs


static func _install_look(mutated: Array, pending: Array) -> void:
	# V10ProfileCos.register is already dynamic and writable on all branches
	for id in V10W1Look.FRAMES:
		V10ProfileCos.register(V10W1Look.FRAMES[id])
	mutated.append("V10ProfileCos.FRAMES")
	# Merge look tables individually whenever mutable
	_merge_class_dict("V10TileTheme", "THEMES", V10W1Look.THEMES, mutated, pending, false, true)
	_merge_class_dict("V10TileTheme", "TABLES", V10W1Look.TABLES, mutated, pending, false, true)
	var kd: = _klass("V10KitData")
	if kd != null and kd.get("KITS") is Dictionary and not (kd.get("KITS") as Dictionary).is_read_only():
		for h in HERO_ORDER:
			var e: Dictionary = (V10W1Look.KITS[h] as Dictionary).duplicate(true)
			e.erase("hidden")
			kd.KITS[h] = e
		mutated.append("V10KitData.KITS")
	else:
		pending.append("V10KitData.KITS")
	_merge_class_dict("V10KitData", "EXTRA_OUTFITS", V10W1Look.EXTRA_OUTFITS, mutated, pending, false, true)
	_merge_class_dict("V10DS", "HEROES", V10W1Look.HUD_HEROES, mutated, pending, false, false)
	_merge_class_dict("V10ComboShowcase", "LINES", V10W1Look.COMBO_LINES, mutated, pending, false, false)


static func _install_home(mutated: Array, pending: Array) -> void:
	for row in V10W1Home.merges():
		var parts: PackedStringArray = String(row[0]).split(".")
		_merge_class_dict(parts[0], parts[1], row[1], mutated, pending, bool(row[2]), false)


static func _install_play(mutated: Array, pending: Array) -> void:
	_merge_class_dict("V6Heroines", "RIVALS", V10W1Play.RIVALS, mutated, pending, false, false)
	_merge_class_dict("V6Heroines", "DUEL_LINES", V10W1Play.DUEL_LINES, mutated, pending, false, false)
	_merge_class_dict("V7Passives", "DATA", V10W1Play.PASSIVES, mutated, pending, false, false)
	_merge_class_dict("V6ModesData", "BLESS", V10W1Play.V6_BLESS, mutated, pending, false, false)
	_merge_class_dict("V6ModesData", "TASTE", V10W1Play.SHIFT_TASTE, mutated, pending, false, false)
	_merge_class_dict("V6ModesData", "ORDER_LINES", V10W1Play.SHIFT_ORDER_LINES, mutated, pending, false, false)
	_merge_class_dict("V6ModesData", "THANKS", V10W1Play.SHIFT_THANKS, mutated, pending, false, false)
	_merge_class_dict("V6ModesData", "LEAVE", V10W1Play.SHIFT_LEAVE, mutated, pending, false, false)
	_merge_class_dict("V8AI", "STYLES", V10W1Play.AI_STYLES, mutated, pending, false, false)
	_merge_class_dict("V10PathRules", "HOST_NAMES", V10W1Play.HOST_NAMES, mutated, pending, false, false)


static func _install_ults(mutated: Array, pending: Array) -> void:
	_merge_class_dict("V9Ults", "CORES", V10W1Ults.CORES, mutated, pending, false, false)
	var vu: = _klass("V9Ults")
	if vu != null and vu.get("ULTS") is Dictionary and not (vu.get("ULTS") as Dictionary).is_read_only():
		for id in V10W1Ults.ULTS:
			if not vu.ULTS.has(id):
				vu.ULTS[id] = V10W1Ults.get_ult(id)
		mutated.append("V9Ults.ULTS")
	else:
		pending.append("V9Ults.ULTS")


static func _flush_banner_cache() -> void:
	var vb: = _klass("V10Banners")
	if vb != null and vb.get("_data") is Dictionary and not (vb.get("_data") as Dictionary).is_read_only():
		vb._data.clear()


static func _install_social_tray(_mutated: Array) -> void:
	pass


static func _merge_class_dict(cname: String, prop: String, src: Dictionary, mutated: Array, pending: Array, nested: bool, overwrite_w1: bool) -> void:
	var sc: = _klass(cname)
	var tag: = cname + "." + prop
	if sc == null:
		pending.append(tag)
		return
	var dst = sc.get(prop)
	if not (dst is Dictionary) or (dst as Dictionary).is_read_only():
		pending.append(tag)
		return
	if nested:
		V10W1Home.merge_into(dst, src, true)
	else:
		for k in src:
			if overwrite_w1 or not (dst as Dictionary).has(k):
				var v = src[k]
				dst[k] = v.duplicate(true) if v is Dictionary or v is Array else v
	mutated.append(tag)


# Merge Wave-1 rows into caller-supplied mutable copies (used by selftests and overlay consumers)
static func install_into(targets: Dictionary) -> Dictionary:
	if targets.get("heroes") is Dictionary:
		for h in HERO_ORDER:
			if not targets.heroes.has(h):
				targets.heroes[h] = (V10W1Core.HEROES[h] as Dictionary).duplicate(true)
	if targets.get("hero_order") is Array:
		for h in HERO_ORDER:
			if not (h in targets.hero_order):
				targets.hero_order.append(h)
	if targets.get("base_outfits") is Array:
		for b in V10W1Core.BASE_OUTFITS:
			if not (b in targets.base_outfits):
				targets.base_outfits.append(b)
	if targets.get("items") is Array and targets.get("item_map") is Dictionary:
		for it in V10W1Core.items_copy():
			var id: = String(it.id)
			if not targets.item_map.has(id):
				targets.items.append(it)
				targets.item_map[id] = it
	if targets.get("kits") is Dictionary:
		for h in HERO_ORDER:
			var e: Dictionary = (V10W1Look.KITS[h] as Dictionary).duplicate(true)
			e.erase("hidden")
			targets.kits[h] = e
	if targets.get("extra_outfits") is Dictionary:
		for id in V10W1Look.EXTRA_OUTFITS:
			targets.extra_outfits[id] = (V10W1Look.EXTRA_OUTFITS[id] as Array).duplicate(true)
	if targets.get("themes") is Dictionary:
		for id in V10W1Look.THEMES:
			targets.themes[id] = (V10W1Look.THEMES[id] as Dictionary).duplicate(true)
	if targets.get("tables") is Dictionary:
		for id in V10W1Look.TABLES:
			targets.tables[id] = (V10W1Look.TABLES[id] as Dictionary).duplicate(true)
	if targets.get("passives") is Dictionary:
		for h in HERO_ORDER:
			targets.passives[h] = (V10W1Play.PASSIVES[h] as Dictionary).duplicate(true)
	if targets.get("ults") is Dictionary:
		for id in V10W1Ults.ULTS:
			targets.ults[id] = V10W1Ults.get_ult(id)
	return targets


# ------------------------------------------------------------------ W4 1-liner query hooks

static func heroes() -> Dictionary:
	if _merged_heroes.is_empty():
		_build_merged_views(_g())
	return _merged_heroes


static func hero_order() -> Array:
	if _merged_order.is_empty():
		_build_merged_views(_g())
	return _merged_order


static func base_outfits() -> Array:
	if _merged_bases.is_empty():
		_build_merged_views(_g())
	return _merged_bases


static func items() -> Array:
	return V10W1Core.items_copy()


static func outfit(id: String) -> Dictionary:
	return V10W1Core.item(id)


static func legwear(id: String) -> Dictionary:
	return V10W1Core.legwear(id)


static func hero_png(h: String) -> String:
	return V10W1Core.hero_png(h)


static func outfit_webp(img: String) -> String:
	return V10W1Core.outfit_webp(img)


static func emotion_webp(h: String, emo: String) -> String:
	return V10W1Core.emotion_webp(h, emo)


static func passive(h: String) -> Dictionary:
	return V10W1Play.PASSIVES.get(h, {})


static func dar_line(h: String) -> String:
	return V10W1Play.dar_line(h)


static func ult_has(id: String) -> bool:
	return released() and V10W1Ults.has(id)


static func ult(id: String) -> Dictionary:
	return V10W1Ults.get_ult(id)


static func ult_core(h: String, ranked: = false) -> Dictionary:
	return V10W1Ults.core(h, ranked)


static func kit(h: String) -> Dictionary:
	return V10W1Look.kit(h)


static func banners(base: Dictionary, keep_t: int = -1) -> Dictionary:
	if not banners_enabled():
		return base
	var kt: = keep_t if keep_t >= 0 else release_t()
	return V10W1Gacha.merge(base, kt)


static func droppable(id: String, owns: Callable, t: int) -> bool:
	return released() and V10W1Gacha.droppable(id, owns, t)


static func shop_ok(id: String, owns: Callable) -> bool:
	return released() and V10W1Gacha.shop_ok(id, owns)


static func chat_heroes() -> Array:
	return (FOUNDERS + V10W1Social.HEROES) if released() else FOUNDERS.duplicate()


static func chat_threads(h: String) -> Array:
	return V10W1Social.threads(h) if released() and (h in V10W1Social.HEROES) else []


static func stickers(base: Dictionary) -> Dictionary:
	return V10W1Social.with_stickers(base) if released() else base


static func reactions(base: Dictionary) -> Dictionary:
	return V10W1Social.with_reactions(base) if released() else base


static func feed(base: Array) -> Array:
	return V10W1Social.with_feed(base) if released() else base


static func bday_sig(h: String) -> String:
	return V10W1Social.sig_icon(h)


static func mj_bark(mode: String, h: String, ev: String) -> String:
	match mode:
		"riichi", "sanma":
			return V10W1Mj.riichi_bark(h, ev)
		"koikoi":
			return V10W1Mj.koikoi_line(ev, h)
		"triples":
			return V10W1Mj.triples_line(ev, h)
		"stage":
			var vs: = V10W1Mj.stage_variants(h, ev)
			return String(vs[0][0]) if not vs.is_empty() and vs[0] is Array and (vs[0] as Array).size() > 0 else ""
	return ""


static func _g() -> Node:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree != null else null


static func _klass(cname: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cname:
			return load(String(c.path)) as Script
	return null
