class_name V10OnlineReg
extends RefCounted

# V10OnlineReg — registers the 0.12.0 online module into V10Registry (one call from registry_list.gd:
# `V10OnlineReg.register()`), so main.go("v10account") / main.go("v10pvp") and --screen=v10pvp work without touching
# main.gd, home.gd or profile_screen.gd here.

const SCREENS: = {
	"v10account": "res://scripts/v10/online/account_screen.gd",
	"v10pvp": "res://scripts/v10/online/pvp_online_screen.gd",
}


static func register() -> void:
	V10Registry.module("online", {
		"step": 4,
		"selftest": {
			"scene": "res://scripts/v10/online/online_selftest.tscn",
			"args": [],
			"marker": "ONLINE_SELFTEST",
		},
		"screens": SCREENS,
		"nav": {"v10account": ["profile"], "v10pvp": ["tables"]},
		"save": {V10OnlineCfg.KEY: V10OnlineCfg.defaults()},
		"ensure": func(S: Dictionary) -> void: V10OnlineCfg.ensure(S),
	})
