extends Control

# main.gd screen adapter for Лавка 2 (integration: main.SCREENS["shop"] = preload(this)). Keeps the 0.9 screen
# contract build(main, args): args {"tab": 0|1|2} or {"v10": "pass"|"purchases"}.

var main


func build(m, args: Dictionary) -> void:
	main = m
	position = Vector2.ZERO
	if m is Control:
		size = (m as Control).get_viewport_rect().size
	if main.has_method("show_chrome"):
		main.show_chrome(false, not (String(args.get("v10", "")) in ["pass", "purchases"]))
	var model: = V10ShopHub.model()
	if model:
		model.free_paths_go = V10ShopHub.go_free_cb(main)
		model.ads_stub.host = self
	V10ShopHub.build_into(self, main, args)


func _view() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


func _set_tab(i: int) -> void:
	var v: = _view()
	if v and v.has_method("_set_tab"):
		v.call("_set_tab", i)
	elif v and v.get("seg") != null:
		v.seg.select(i)


func refresh() -> void:
	var v: = _view()
	if v and v.has_method("refresh"):
		v.call("refresh")
	if main and main.has_method("refresh_currency"):
		main.refresh_currency()


func currency_target(cur: String) -> Vector2:
	var v: = _view()
	if v and v.has_method("currency_target"):
		return v.call("currency_target", cur)
	return Vector2(size.x - 120, 80)
