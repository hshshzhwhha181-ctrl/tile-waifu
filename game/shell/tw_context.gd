class_name TWContext
extends RefCounted

# TWContext (P23 / WP8a): what a screen gets instead of the untyped `main` god-object (173 main.go, 109 toast, 77 overlay,
# 88 has_method in v10). Four typed members the skeleton already has, plus a service table for the parts other lanes are
# still building (wallet, audio, assets, modals, content, ...). A screen asks for a service by name:
#
#   ctx.state / ctx.clock / ctx.bus / ctx.screens      typed, never null in a built context
#   ctx.provide("audio", obj)                          the integrator wires a service once
#   ctx.service("audio") -> Object                     null when it was not provided (a screen must cope)
#   ctx.has_service(name)
#
# The table is the only dynamic part and it is closed: provide() accepts only the names in SERVICES, so a typo or a smuggled
# `main` fails loudly instead of recreating the god-object. Services are Objects with real class_names (typed on use).
#
#   TWContext.build(state, clock, bus, screens) -> TWContext
#   TWContext.for_tests(save_dir) -> TWContext         scratch TWState on a fake clock, a fresh TWBus and TWScreens(not in tree)

const SERVICES: = ["wallet", "events", "audio", "assets", "modals", "content", "levels", "online", "analytics", "legacy_host"]

var state: TWState
var clock: TWClock
var bus: TWBus
var screens: TWScreens
var _svc: Dictionary = {}


static func build(p_state: TWState, p_clock: TWClock, p_bus: TWBus, p_screens: TWScreens) -> TWContext:
	var c: = TWContext.new()
	c.state = p_state
	c.clock = p_clock
	c.bus = p_bus
	c.screens = p_screens
	return c


static func for_tests(save_dir: String = "user://tw_ctx_selftest/") -> TWContext:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var clk: = TWClock.fake()
	var st: = TWState.new(TWSave.new(save_dir.path_join("save.json")), clk, {})
	var scr: = TWScreens.new()
	var c: = TWContext.build(st, clk, TWBus.new(), scr)
	scr.ctx = c
	return c


func provide(name: String, obj: Object) -> bool:
	if not SERVICES.has(name):
		push_warning("TWContext.provide: unknown service '%s'" % name)
		return false
	if obj == null:
		_svc.erase(name)
	else:
		_svc[name] = obj
	return true


func service(name: String) -> Object:
	if not _svc.has(name):
		return null
	var o = _svc[name]
	if o == null or not is_instance_valid(o):
		_svc.erase(name)
		return null
	return o


func has_service(name: String) -> bool:
	return service(name) != null
