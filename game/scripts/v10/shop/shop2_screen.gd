extends Control

# main.gd screen adapter for Лавка 2 (integration: main.SCREENS["shop"] = preload(this)). Keeps the 0.9 screen
# contract build(main, args): args {"tab": 0|1|2} or {"v10": "pass"|"purchases"}.

var main


func build(m, args: Dictionary) -> void:
	main = m
	if main.has_method("show_chrome"):
		main.show_chrome(false, not (String(args.get("v10", "")) in ["pass", "purchases"]))
	V10ShopHub.build_into(self, main, args)
