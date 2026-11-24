class_name V10Offers
extends RefCounted

# V10Offers — when a ladder offer may pop up (spec 0.10 Л3/Л7, UX §5.2.4, checklist О-3).
#   At most once per calendar day, ONLY right after a win (never after a loss), from Path level 8, not in the first
#   10 minutes after install, not in the session where the first SSR is chosen. Nothing else in the game may open an
#   offer by itself. Before the guarantee and the Candle the banner shows counters only — no windows.
#
# State (S.v10_shop.offers): {"last_day": -1, "shown": n}
# ctx: {"now": unix, "install": unix, "level": int, "result": "win"|"lose"|"", "first_ssr_session": bool, "day": int}


static func ensure(st: Dictionary) -> Dictionary:
	if not (st.get("offers") is Dictionary):
		st["offers"] = {}
	var o: Dictionary = st.offers
	o["last_day"] = int(o.get("last_day", -1))
	o["shown"] = int(o.get("shown", 0))
	return o


static func can_popup(st: Dictionary, ctx: Dictionary) -> Dictionary:
	var o: = ensure(st)
	if String(ctx.get("result", "")) != "win":
		return {"ok": false, "why": "not_after_win"}
	if int(ctx.get("level", 0)) < V10ShopData.POPUP_FROM_LEVEL:
		return {"ok": false, "why": "level"}
	if int(ctx.get("now", 0)) - int(ctx.get("install", 0)) < V10ShopData.POPUP_QUIET_SEC:
		return {"ok": false, "why": "quiet"}
	if bool(ctx.get("first_ssr_session", false)):
		return {"ok": false, "why": "first_ssr"}
	if int(o.last_day) == int(ctx.get("day", -2)):
		return {"ok": false, "why": "today"}
	return {"ok": true}


static func mark_shown(st: Dictionary, day: int) -> void:
	var o: = ensure(st)
	o.last_day = day
	o.shown = int(o.shown) + 1
