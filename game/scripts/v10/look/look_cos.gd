class_name V10LookCos
extends RefCounted

# V10LookCos — ONE catalogue of every cosmetic the player can own or show (D5 «единый реестр косметики»).
# Profile cosmetics (frames, titles, badges, card backgrounds) stay registered in V10ProfileCos (§2.7: the only
# registry of those); this facade adds the kit elements — tile themes, tables, HUD skins, stings, display fonts —
# with the same entry shape, so the wardrobe, the card, the banner «Набор: …» line and the selftests read one list.
#
#   V10LookCos.all(kind = "", include_hidden = false) -> Array   kinds: frame title badge bg tile table hud sting font
#   V10LookCos.entry(id) -> Dictionary
#   V10LookCos.owned(S, kind) -> Array                             ids
#   V10LookCos.kit_line(hero, outfit) -> String                    «Набор: рамка · тема · стол · HUD · стинг · шрифт»
#   V10LookCos.validate_all() -> Array                             error strings
#
# Entry: {id, kind, name, tier: A|S|SSR, hero, src: {type: goddess|outfit|legacy|default|…}, sim_ok, sold: false}
# Kit elements are NEVER sold separately (D7 «Скин не продаётся отдельно — только с богиней»).

const KINDS: = ["frame", "title", "badge", "bg", "tile", "table", "hud", "sting", "font"]
const LOOK_KINDS: = ["tile", "table", "hud", "sting", "font"]

static var _list: = []
static var _by_id: = {}


static func _ensure() -> void:
	if not _list.is_empty():
		return
	for e in V10ProfileCos.all("", true):
		var d: Dictionary = e.duplicate(true)
		d["sold"] = int(d.get("price", 0)) > 0
		_add(d)
	for id in V10TileTheme.THEMES:
		var th: Dictionary = V10TileTheme.THEMES[id]
		var legacy: = bool(th.get("legacy", false))
		_add({"id": id, "kind": "tile", "name": String(th.name), "tier": String(th.tier), "hero": String(th.owner),
			"src": {"type": "legacy" if legacy else "goddess", "hero": th.owner}, "sim_ok": th.tier == "A", "sold": false,
			"table": String(th.get("table", ""))})
	for id in V10TileTheme.TABLES:
		var tb: Dictionary = V10TileTheme.TABLES[id]
		var h: = String(tb.owner)
		_add({"id": id, "kind": "table", "name": String(tb.name), "tier": V10KitData.hero_rank(h) if V10KitData.hero_rank(h) != "A" else "S",
			"hero": h, "src": {"type": "goddess", "hero": h}, "sim_ok": false, "sold": false})
	for id in V10HudSkinData.SKINS:
		var sk: Dictionary = V10HudSkinData.SKINS[id]
		var base: bool = id == V10KitData.BASE_HUD
		_add({"id": "hud_" + id, "kind": "hud", "name": String(sk.name), "tier": "A" if base else "SSR",
			"hero": "" if base else String(sk.hero), "src": {"type": "default" if base else "goddess", "hero": sk.hero},
			"sim_ok": base, "sold": false, "skin": id})
	for sid in V10KitData.STINGS:
		_add({"id": "sting_" + sid, "kind": "sting", "name": String(V10KitData.STINGS[sid].name), "tier": "SSR", "hero": sid,
			"src": {"type": "goddess", "hero": sid}, "sim_ok": false, "sold": false})
	for h in V10Fonts.SKIN_FONTS:
		var fid: String = V10Fonts.SKIN_FONTS[h].title
		var rk: = V10KitData.hero_rank(h)
		_add({"id": "font_" + h, "kind": "font", "name": String(V10Fonts.FAMILIES[fid].name), "tier": "SSR" if rk == "SSR" else "S",
			"hero": h, "src": {"type": "goddess" if rk == "SSR" else "outfit", "hero": h}, "sim_ok": false, "sold": false, "font": fid})


static func _add(e: Dictionary) -> void:
	_list.append(e)
	_by_id[e.id] = e


static func reset() -> void:
	_list.clear()
	_by_id.clear()


static func _hidden(e: Dictionary) -> bool:
	var h: = String(e.get("hero", ""))
	return h != "" and not V10ProfileCos.released(h) and not V10Look.dev_reveal.has(h)


static func all(kind: = "", include_hidden: = false) -> Array:
	_ensure()
	var out: = []
	for e in _list:
		if kind != "" and e.kind != kind:
			continue
		if not include_hidden and _hidden(e):
			continue
		out.append(e)
	return out


static func entry(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func owned(S: Dictionary, kind: String) -> Array:
	if kind in ["frame", "tile", "table"]:
		return V10Look.owned_elements(S).get(kind, [])
	if kind == "hud":
		return V10Look.owned_elements(S).hud.map(func(x): return "hud_" + String(x))
	if kind in ["title", "badge", "bg"]:
		return V10ProfileCos.unlocked(kind, V10ProfileCos.ctx_from_save(S))
	var out: = []
	for e in all(kind, true):
		if V10Look.hero_owned(S, String(e.hero)) and V10KitData.hero_rank(String(e.hero)) == "SSR":
			out.append(e.id)
	return out


static func kit_line(hero: String, outfit: = "") -> String:
	var r: = V10Look.resolve(hero, outfit)
	var parts: = []
	for el in V10KitData.ELEMENTS:
		if r.open.get(el, false):
			parts.append(String(V10KitData.ELEMENT_NAMES[el]).to_lower() if el != "hud" else "HUD")
	return "Набор: " + " · ".join(parts)


static func validate_all() -> Array:
	reset()
	_ensure()
	var errs: = []
	var seen: = {}
	for e in _list:
		if seen.has(e.id):
			errs.append("%s: duplicate id across kinds" % e.id)
		seen[e.id] = true
		if not (String(e.kind) in KINDS):
			errs.append("%s: bad kind" % e.id)
		if not (String(e.get("tier", "")) in V10KitData.RANKS):
			errs.append("%s: bad tier" % e.id)
		if String(e.kind) in LOOK_KINDS and bool(e.get("sold", false)):
			errs.append("%s: kit elements are never sold" % e.id)
		if String(e.kind) in LOOK_KINDS and String(e.tier) == "SSR" and bool(e.get("sim_ok", false)):
			errs.append("%s: SSR element allowed on simulated rivals" % e.id)
	# every kit references existing elements
	for h in V10KitData.KITS:
		var r: = V10Look.resolve(h, "")
		if r.tile != "" and not V10TileTheme.has(r.tile):
			errs.append("kit %s: unknown tile %s" % [h, r.tile])
		if r.table != "" and not V10TileTheme.has_table(r.table):
			errs.append("kit %s: unknown table %s" % [h, r.table])
		if not V10HudSkinData.has(r.hud):
			errs.append("kit %s: unknown hud %s" % [h, r.hud])
		if not V10ProfileCos.has(r.frame, "frame"):
			errs.append("kit %s: frame %s not in V10ProfileCos" % [h, r.frame])
		for o in V10KitData.KITS[h].get("up", {}):
			var u: Dictionary = V10KitData.KITS[h].up[o]
			if not V10TileTheme.has(String(u.tile)) or not V10TileTheme.has_table(String(u.table)):
				errs.append("kit %s/%s: bad upgrade" % [h, o])
	return errs
