class_name V10WinStack
extends RefCounted

# V10WinStack — the ONE victory-window stack (docs/0.10-spec.md M1 Ф5, §2.7). The 0.9 victory window (star stamps,
# yaku, roll) stays as it is; UNDER it go at most TWO progress bars by priority salon > mastery > pass, and every
# other progress (tea streak, Огонёк пути, «9/15», packs …) becomes a small tick icon in one row.
#
#   V10WinStack.add_bar(id, prio, builder, opts = {})   builder: Callable(ctx: Dictionary, width: float) -> Control
#                                                       (a V10WinBar or any Control; null = nothing to show now)
#       opts.when: Callable(ctx) -> bool     extra condition (default: always)
#       opts.modes: Array                   modes the bar may appear in (default: all); the salon bar is "path" only
#   V10WinStack.add_tick(id, builder, opts = {})        builder: Callable(ctx) -> Dictionary {icon: Texture2D|String,
#                                                       text: String} or {} to skip; opts.order (small first)
#   V10WinStack.remove(id), clear()
#   V10WinStack.pick(ctx) -> Array      the bars to show (≤ MAX_BARS, priority high → low)
#   V10WinStack.ticks(ctx) -> Array     the tick dicts to show (≤ MAX_TICKS)
#   V10WinStack.has_bar(id) -> bool
# ctx (from play.gd through V10Hooks.win_screen): {mode: "path"|"daily"|"blitz"|…, level: int, first: bool,
#   stars: int, was_done: bool (the level had stars before this win), next: int, salon_open: bool}
#
# Registration (each module, one line in v10/core/registry_list.gd):
#   salon   M2  V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, V10SalonWinBar.build, {"modes": ["path"]})
#   mastery M4  V10WinStack.add_bar("mastery", V10WinStack.PRIO_MASTERY, V10Mastery.win_bar)
#   pass    M4  V10WinStack.add_bar("pass", V10WinStack.PRIO_PASS, V10Pass.win_bar)
#   ticks   M3  add_tick("streak", …), add_tick("flame", …, {"order": 1}), add_tick("path15", …, {"order": 2})

const MAX_BARS: = 2
const MAX_TICKS: = 5
const PRIO_SALON: = 300
const PRIO_MASTERY: = 200
const PRIO_PASS: = 100

static var _bars: = {}
static var _ticks: = {}


static func add_bar(id: String, prio: int, builder: Callable, opts: Dictionary = {}) -> void:
	_bars[id] = {"id": id, "prio": prio, "builder": builder, "when": opts.get("when", Callable()),
		"modes": opts.get("modes", [])}


static func add_tick(id: String, builder: Callable, opts: Dictionary = {}) -> void:
	_ticks[id] = {"id": id, "order": int(opts.get("order", 0)), "builder": builder, "when": opts.get("when", Callable()),
		"modes": opts.get("modes", [])}


static func remove(id: String) -> void:
	_bars.erase(id)
	_ticks.erase(id)


static func clear() -> void:
	_bars.clear()
	_ticks.clear()


static func has_bar(id: String) -> bool:
	return _bars.has(id)


static func _fits(e: Dictionary, ctx: Dictionary) -> bool:
	var modes: Array = e.modes
	if not modes.is_empty() and not (str(ctx.get("mode", "")) in modes):
		return false
	var w: Callable = e.when
	return not w.is_valid() or bool(w.call(ctx))


static func pick(ctx: Dictionary) -> Array:
	return sorted(ctx).slice(0, MAX_BARS)


# every bar that fits ctx, priority high → low
static func sorted(ctx: Dictionary) -> Array:
	var all: = []
	for id in _bars:
		var e: Dictionary = _bars[id]
		if _fits(e, ctx):
			all.append(e)
	all.sort_custom(func(a, b): return int(a.prio) > int(b.prio) or (int(a.prio) == int(b.prio) and str(a.id) < str(b.id)))
	return all


static func ticks(ctx: Dictionary) -> Array:
	var all: = []
	for id in _ticks:
		var e: Dictionary = _ticks[id]
		if not _fits(e, ctx):
			continue
		var d = (e.builder as Callable).call(ctx)
		if d is Dictionary and not (d as Dictionary).is_empty():
			var dd: Dictionary = d.duplicate()
			dd["id"] = id
			dd["order"] = e.order
			all.append(dd)
	all.sort_custom(func(a, b): return int(a.order) < int(b.order) or (int(a.order) == int(b.order) and str(a.id) < str(b.id)))
	return all.slice(0, MAX_TICKS)


# builds bars in priority order; a builder that returns null (nothing to show now) gives its place to the next one.
# Never more than MAX_BARS Controls.
static func build_bars(ctx: Dictionary, width: float) -> Array:
	var out: = []
	for e in sorted(ctx):
		if out.size() >= MAX_BARS:
			break
		var c = (e.builder as Callable).call(ctx, width)
		if c is Control:
			(c as Control).set_meta("v10_bar_id", e.id)
			out.append(c)
	return out
