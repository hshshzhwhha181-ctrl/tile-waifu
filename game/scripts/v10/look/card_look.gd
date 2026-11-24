class_name V10LookCard
extends RefCounted

# V10LookCard — the player card as others see it, with the goddess kit (D5/D6, ROSTER §1.5): the «рубашка» miniature
# is the real theme, the card names the theme and the table, a kit frame is used while the profile frame is default.
# Spends are never on the card; simulated rivals show only A elements (no SSR goddess, theme, table or HUD).
#
#   V10LookCard.payload(S, extra = {}) -> Dictionary      V10CardPayload.mine + look (tile, table, kit)
#   V10LookCard.validate(p) -> String                     V10CardPayload.validate + look rules; "" = ok
#   V10LookCard.sim(rng, tier, nick = "") -> Dictionary   rival card: A themes only, no table
#   V10LookCard.view(p, rect, mode) -> V10CardView        V10CardView with the theme miniature swapped in

const SIM_TILES: = ["s_sakura", "s_mint", "s_lemon"]


static func payload(S: Dictionary, extra: = {}) -> Dictionary:
	var p: = V10CardPayload.mine(S, extra)
	var cur: = V10Look.current(S)
	var prof = S.get("profile", {})
	var pf: = String(prof.get("frame", "")) if prof is Dictionary else ""
	if (pf == "" or pf == V10ProfileCos.DEFAULT.frame) and V10ProfileCos.has(String(cur.frame), "frame") \
			and V10ProfileCos.released(String(V10ProfileCos.entry(String(cur.frame)).get("hero", ""))):
		p.frame = String(cur.frame)
	p.tile = String(cur.tile) if V10TileTheme.has(String(cur.tile)) else "s_sakura"
	p["table"] = String(cur.table)
	p["kit"] = String(cur.hero)
	return p


static func validate(p) -> String:
	var err: = V10CardPayload.validate(p)
	if err != "":
		return err
	if not V10TileTheme.has(String(p.tile)):
		return "tile theme"
	var tb: = String(p.get("table", ""))
	if tb != "" and not V10TileTheme.has_table(tb):
		return "table"
	var owner: = String(V10TileTheme.theme(String(p.tile)).owner)
	if not V10ProfileCos.released(owner):
		return "unreleased tile"
	if bool(p.sim):
		if String(V10TileTheme.theme(String(p.tile)).tier) != "A":
			return "sim shows theme %s" % p.tile
		if tb != "":
			return "sim shows table"
		var kh: = String(p.get("kit", ""))
		if kh != "" and V10KitData.hero_rank(kh) == "SSR":
			return "sim shows SSR kit"
	return ""


static func sim(rng: RandomNumberGenerator, tier: int, nick: = "") -> Dictionary:
	var p: = V10CardPayload.sim(rng, tier, nick)
	p.tile = SIM_TILES[rng.randi() % SIM_TILES.size()]
	p["table"] = ""
	p["kit"] = String(p.showcase.hero)
	return p


static func view(p: Dictionary, rect: Rect2, mode: = "other", opts: = {}) -> V10CardView:
	var cv: = V10CardView.make(p, rect, mode, opts)
	swap_thumbs(cv, String(p.get("tile", "s_sakura")))
	return cv


# replace V10CardView.TileBack (0.9 colours only) with the v10 theme miniature, same rect
static func swap_thumbs(root: Node, tile_id: String) -> int:
	var n: = 0
	var stack: = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for ch in node.get_children():
			stack.append(ch)
		if node is V10CardView.TileBack:
			var tb: Control = node
			var th: = V10TileTheme.thumb(tile_id, tb.size)
			th.position = tb.position
			tb.get_parent().add_child(th)
			tb.get_parent().move_child(th, tb.get_index())
			tb.queue_free()
			n += 1
			# the theme name under the miniature
			for sib in tb.get_parent().get_children():
				if sib is Label and String(sib.text) != "" and sib.position.y > tb.position.y + tb.size.y - 4:
					sib.text = String(V10TileTheme.theme(tile_id).name)
	return n
