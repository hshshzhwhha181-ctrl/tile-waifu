class_name V10Odometer
extends Control

# V10Odometer — «Прокрутка числа» (docs/HUD_V2.md §6, UX §6.7; lane: scripts/v10/hudfx/README.md).
# An integer drawn as an odometer: every digit is a column (tabular width = the widest digit, so the same digit
# count never changes width), digits in Numerals (tnum), prefix/suffix in the UI role, outline 0, the one shadow
# rule only with on_art. Line height from V10Type.LINE; minimum size from the font metrics.
#
#   var o := V10Odometer.make(1980, 22, V10DS.PAPER_100)       # (value, size, colour, digit role = "num")
#   o.prefix = "Осталось "; o.suffix = ""; o.align = "right"    # "left" | "right" | "center"
#   o.set_value(2130, "reward")    # "roll" | "reward" | "quiet" | "instant";  o.value = n uses o.mode_default
#   await o.finished               # once per settle (an animation re-targeted by a newer value does not emit)
#   V10Odometer.attach(label, n)   # take over a Numerals Label (V10HudMatch status «Осталось N»): quiet, label hidden
#   V10Odometer.in_plate(plate, n) # the value slot of a V10Plate (right-aligned); a "reward" also plate.ping()
#   V10Odometer.format(1980) -> "1 980"   (U+2009 thin space when the font has it, else a space; minus U+2212)
#
# Timings (§6): "roll" 320 ms EXPO_OUT — each changed column rolls through the intermediate digits (increase rolls
# up, decrease rolls down) and never more than 12 steps (big jumps skip: at most one extra full turn); the EXPO_OUT
# clock drives a geometric distance per column, so busy and quiet columns land together (no lingering wheel);
# a change of exactly ±1 is a 120 ms crossfade instead (old α→0, new α 0→1 with a 4 px drift);
# "reward" = roll, then the number does 1.0→1.06→1.0 in 160 ms while the digits tint toward gold.300;
# "quiet" (= "roll") never scales or tints: «Осталось» has no pulse. Digit-count changes (99→100) slide the new
# column in (its width and alpha follow the roll, it is unmasked by its clip). A new value during a roll
# re-targets from where the columns are (no jump; a running bump eases out over 120 ms); during a crossfade the
# old change completes first. Negative values show a minus that fades in/out, digits roll by magnitude;
# |value| is clamped to MAX_ABS (15 digits).
# fx_level: "full" = "mid" (no particles or light here); "min" → any change is one 120 ms fade of the whole
# number (no roll, no drift, no bump, no tint). calm() needs nothing: this module never flashes.
# Perf: Font.draw_string in _draw; static digits go into the control's own canvas item, rolling columns into
# pooled clipped RenderingServer canvas items (one per column, no node per digit, no per-frame allocations);
# _process only while animating; process mode ALWAYS (sheets over a paused game still count).

signal finished

const T_ROLL: = V10DS.T_ROLL  # 0.32
const T_STEP: = V10HudFx.T_MIN  # ±1 crossfade 0.12
const T_FADE: = V10HudFx.T_MIN  # fx min: one fade 0.12 (also the carried-bump ease-out)
const T_BUMP: = 0.16
const BUMP: = 0.06
const MAX_STEPS: = 12
const DRIFT: = 4.0
const MAX_ABS: = 999999999999999
const CAP_K: = 0.7  # lining-figure height / em (Nunito 900, Playfair ≈ 0.70): the visual centre of a digit
const WIN_AIR: = 4.0  # the column window is the line box + 4 px each side (neighbours one line away stay hidden)
const MODES: = ["roll", "reward", "quiet", "instant"]
const DIGITS: = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
const NONE: = -1.0e9

static var live_items: = 0  # clipped column canvas items alive (selftest: no leaks)

var value: int:
	get:
		return _target
	set(v):
		set_value(v, mode_default)
var prefix: = "":
	set(v):
		prefix = v
		_dirty()
var suffix: = "":
	set(v):
		suffix = v
		_dirty()
var align: = "left":
	set(v):
		align = v if v in ["left", "right", "center"] else "left"
		queue_redraw()
var font_size: = 40:
	set(v):
		font_size = maxi(1, v)
		_dirty()
var role: = "num":
	set(v):
		role = v
		_dirty()
var affix_role: = "ui":
	set(v):
		affix_role = v
		_dirty()
var color: = V10DS.PAPER_100:
	set(v):
		color = v
		queue_redraw()
var affix_color: = Color.TRANSPARENT:  # α 0 → same as color
	set(v):
		affix_color = v
		queue_redraw()
var on_art: = false:  # text lying directly on art: the §3 shadow (night.900 α 0.55, (0, 2), size 6)
	set(v):
		on_art = v
		queue_redraw()
var mode_default: = "roll"
var plate: Control = null  # optional V10Plate: ping() on "reward"
var pings: = 0
var manual_clock: = false:  # tests / demo stills: nothing advances unless advance() is called
	set(v):
		manual_clock = v
		set_process(not v and is_animating())

var _target: = 0
var _from: = 0
var _kind: = ""  # "" rest · "roll" · "cross" · "fade"
var _mode: = "roll"
var _t: = 0.0
var _dur: = 0.0
var _dir: = 1
var _bump_t: = -1.0
var _carry: = 0.0
var _carry_t: = 0.0
var _n: = 1
var _c0: = PackedFloat32Array([0.0])  # column start position (digit units; digit = posmod(position, 10))
var _cs: = PackedFloat32Array([0.0])  # signed steps of the current animation
var _ck: = PackedByteArray([0])  # 0 static · 1 roll · 2 crossfade
var _p0: = PackedFloat32Array([1.0])  # presence (width × alpha) from / to
var _p1: = PackedFloat32Array([1.0])
var _ba: = PackedFloat32Array([NONE])  # blank position at the start (leading zero of an appearing column)
var _bb: = PackedFloat32Array([NONE])  # blank position at the end (a column that goes away)
var _dfrom: = PackedInt32Array([0])
var _dto: = PackedInt32Array([0])
var _s0: = 0.0  # minus presence from / to
var _s1: = 0.0
var _last_steps: = 0
var _last_kind: = "instant"
var _ping_ms: = -100000

var _m_ok: = false
var _dw: = PackedFloat32Array()
var _colw: = 0.0
var _sep: = " "
var _sepw: = 0.0
var _sign: = "-"
var _signw: = 0.0
var _asc: = 0.0
var _fh: = 0.0
var _line: = 44
var _cap: = 0.0
var _pw: = 0.0
var _sw: = 0.0
var _col_rid: Array[RID] = []
var _col_used: = PackedByteArray()


static func make(v: int, sz: = 40, c: = V10DS.PAPER_100, digit_role: = "num") -> V10Odometer:
	var o: = V10Odometer.new()
	o.font_size = sz
	o.color = c
	o.role = digit_role
	o._instant(v)
	o.size = o.get_combined_minimum_size()
	return o


static func attach(label: Label, v: int, mode: = "quiet") -> V10Odometer:
	# replaces a Numerals Label in place (V10HudMatch.status_n): the label keeps its box and LabelSettings
	# (hud2 code and selftest still read them) but draws nothing; the odometer fills the label's rect.
	var ls: = label.label_settings
	var o: = make(v, ls.font_size if ls else 22, ls.font_color if ls else V10DS.PAPER_100)
	o.name = "Odometer"
	o.mode_default = mode
	o.on_art = ls != null and ls.shadow_size > 0 and ls.shadow_color.a > 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT:
			o.align = "right"
		HORIZONTAL_ALIGNMENT_CENTER:
			o.align = "center"
	label.add_child(o)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.self_modulate.a = 0.0
	return o


static func in_plate(p: V10Plate, v: int, c: = V10DS.PAPER_100) -> V10Odometer:
	# the value slot of a plate: S → Numerals 22, M → 28, L → 40, right-aligned inside the plate padding
	var px: int = {"S": 22, "M": 28, "L": 40}.get(p.size_class, 22)
	var o: = make(v, px, c)
	o.name = "Odometer"
	o.align = "right"
	o.plate = p
	p.value = ""
	p.add_child(o)
	var pad: = float(V10DS.PLATE_PAD.get(p.size_class, 16))
	o.position = Vector2(pad, 0.0)
	o.size = Vector2(float(p.plate_w) - pad * 2.0, float(p.plate_h()))
	return o


static func group_sep(f: Font) -> String:
	# narrow no-break space, else thin space, else a plain space (never a dot or comma)
	if f != null and f.has_char(0x202F):
		return String.chr(0x202F)
	if f != null and f.has_char(0x2009):
		return String.chr(0x2009)
	return " "


static func minus_for(f: Font) -> String:
	return String.chr(0x2212) if f != null and f.has_char(0x2212) else "-"


static func format(v: int, f: Font = null) -> String:
	if f == null:
		f = V10Type.font("num")
	v = clampi(v, -MAX_ABS, MAX_ABS)
	var sep: = group_sep(f)
	var s: = str(absi(v))
	var n: = s.length()
	var out: = ""
	for i in n:
		if i > 0 and n >= 4 and (n - i) % 3 == 0:
			out += sep
		out += s[i]
	return (minus_for(f) + out) if v < 0 else out


static func digit_count(v: int) -> int:
	var a: = absi(v)
	var n: = 1
	while a >= 10:
		a /= 10
		n += 1
	return n


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	# a script with _process gets processing switched on at READY: keep it off until something moves
	set_process(not manual_clock and is_animating())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for r in _col_rid:
			RenderingServer.free_rid(r)
			live_items -= 1
		_col_rid.clear()


# ------------------------------------------------------------------ API

func set_value(v: int, mode: = "roll") -> void:
	v = clampi(v, -MAX_ABS, MAX_ABS)
	if not mode in MODES:
		mode = "roll"
	if mode == "instant":
		_instant(v)
		finished.emit.call_deferred()
		return
	if v == _target:
		if is_animating():
			_mode = mode
		else:
			finished.emit.call_deferred()
		return
	if _bump_t >= 0.0:  # a running reward bump eases out under the new motion (no jump in scale)
		_carry = _bump_amount()
		_carry_t = 0.0
		_bump_t = -1.0
	_mode = mode
	if V10HudFx.is_min():
		if _kind != "":
			_settle_columns()
		_carry = 0.0
		_start_fade(v)
	elif _kind == "roll":
		_retarget(v)
	else:
		if _kind != "":
			_settle_columns()
		if absi(v - _target) == 1:
			_start_cross(v)
		else:
			_start_roll(v)
	if mode == "reward":
		_ping()
	update_minimum_size()
	queue_redraw()
	set_process(not manual_clock)


func advance(dt: float) -> void:
	# one clock for _process, the selftest and the demo stills
	if dt <= 0.0 or not is_animating():
		return
	var rest: = dt
	var done: = false
	if _kind != "":
		_t += dt
		if _t < _dur:
			rest = 0.0
		else:
			rest = _t - _dur
			var faded: = _kind == "fade"
			_settle_columns()
			update_minimum_size()
			if _mode == "reward" and not faded and not V10HudFx.is_min():
				_bump_t = 0.0
			else:
				done = true
	if _bump_t >= 0.0 and rest > 0.0:
		_bump_t += rest
		if _bump_t >= T_BUMP:
			_bump_t = -1.0
			done = true
	if _carry > 0.0:
		_carry_t += dt
		if _carry_t >= T_FADE:
			_carry = 0.0
	queue_redraw()
	if done:
		set_process(not manual_clock and is_animating())
		finished.emit()


func is_animating() -> bool:
	return _kind != "" or _bump_t >= 0.0 or _carry > 0.0


func anim_kind() -> String:
	# the last change: "roll" | "cross" | "fade" | "instant"
	return _last_kind


func anim_duration() -> float:
	# the main phase of the last change (roll 0.32 · crossfade 0.12 · min fade 0.12; the bump adds T_BUMP)
	match _last_kind:
		"roll":
			return T_ROLL
		"cross":
			return T_STEP
		"fade":
			return T_FADE
	return 0.0


func max_steps() -> int:
	return _last_steps


func current_scale() -> float:
	return 1.0 + BUMP * _bump_amount()


func current_tint() -> float:
	return _bump_amount()


func col_pos(i: int) -> float:
	if i >= _n:
		return 0.0
	return _c0[i] + _travel(i, _k())


func col_steps(i: int) -> float:
	return _cs[i] if i < _n else 0.0


func cross_dy() -> float:
	# vertical offset of the incoming glyph of a crossfade (4 px → 0, below for an increase)
	if _kind != "cross":
		return 0.0
	return DRIFT * _dir * (1.0 - _k())


func columns_in_use() -> int:
	var c: = 0
	for u in _col_used:
		c += u
	return c


func block_width() -> float:
	# current width of the number block (sign + columns + group gaps), follows presence while sliding
	_metrics()
	if _kind == "fade":
		var u: = clampf(_t / _dur, 0.0, 1.0)
		return lerpf(_block_w(digit_count(_from), _from < 0), _block_w(digit_count(_target), _target < 0), u)
	var k: = _k()
	var w: = lerpf(_s0, _s1, k) * _signw
	for i in _n:
		var p: = lerpf(_p0[i], _p1[i], k)
		w += p * _colw
		if i > 0 and i % 3 == 0:
			w += p * _sepw
	return w


func content_x() -> float:
	_metrics()
	return _x0(_pw + block_width() + _sw)


func width_for(v: int) -> float:
	_metrics()
	return _pw + _sw + _block_w(digit_count(v), v < 0)


func display_text() -> String:
	# what the columns show right now (at rest it equals prefix + format(value) + suffix)
	_metrics()
	if _kind == "fade":
		return prefix + format(_target if _t >= _dur * 0.5 else _from, V10Type.font(role)) + suffix
	var k: = _k()
	var s: = prefix
	if lerpf(_s0, _s1, k) >= 0.5:
		s += _sign
	for ii in _n:
		var i: = _n - 1 - ii
		if lerpf(_p0[i], _p1[i], k) < 0.5:
			continue
		var d: = posmod(roundi(_c0[i] + _travel(i, k)), 10)
		if _ck[i] == 2:
			d = _dto[i] if k >= 0.5 else _dfrom[i]
		s += DIGITS[d]
		if i > 0 and i % 3 == 0:
			s += _sep
	return s + suffix


# ------------------------------------------------------------------ animation setup

func _instant(v: int) -> void:
	_bump_t = -1.0
	_carry = 0.0
	_target = v
	_from = v
	_settle_columns()
	_mode = "instant"
	_last_kind = "instant"
	_last_steps = 0
	update_minimum_size()
	queue_redraw()
	set_process(false)


func _start_roll(v: int) -> void:
	_from = _target
	_target = v
	var cf: = digit_count(_from)
	var ct: = digit_count(v)
	var n: = maxi(cf, ct)
	_ensure(n)
	_n = n
	_fill(_dfrom, _from, n)
	_fill(_dto, v, n)
	var a: = absi(_from)
	var b: = absi(v)
	_dir = 1 if b >= a else -1
	var p10: = 1
	var mx: = 0
	for i in n:
		var d0: = _dfrom[i]
		var d1: = _dto[i]
		var pr0: = i < cf
		var pr1: = i < ct
		var steps: = posmod((d1 - d0) * _dir, 10)
		var s_true: = b / p10 - a / p10  # what a real odometer would turn
		if absi(s_true) >= 10 and steps + 10 <= MAX_STEPS:
			steps += 10  # big jump: one full turn when it fits, otherwise skip straight to the digit
		_c0[i] = float(d0)
		_cs[i] = float(steps * _dir)
		_ck[i] = 1 if (steps != 0 or pr0 != pr1) else 0
		_p0[i] = 1.0 if pr0 else 0.0
		_p1[i] = 1.0 if pr1 else 0.0
		_ba[i] = NONE if pr0 else float(d0)
		_bb[i] = NONE if pr1 else float(d0 + steps * _dir)
		mx = maxi(mx, steps)
		p10 *= 10
	_s0 = 1.0 if _from < 0 else 0.0
	_s1 = 1.0 if v < 0 else 0.0
	_kind = "roll"
	_t = 0.0
	_dur = T_ROLL
	_last_kind = "roll"
	_last_steps = mx


func _retarget(v: int) -> void:
	# a new value while rolling: every column continues from where it is now
	var k: = _k()
	var prev: = _target
	_from = prev
	_target = v
	var ct: = digit_count(v)
	var n: = maxi(_n, ct)
	_ensure(n)
	_fill(_dto, v, n)
	var a: = absi(prev)
	var b: = absi(v)
	_dir = 1 if b >= a else -1
	var p10: = 1
	var mx: = 0.0
	for i in n:
		var cur: = _c0[i] + _travel(i, k)
		var pres: = lerpf(_p0[i], _p1[i], k)
		var pr1: = i < ct
		var steps: = fposmod((float(_dto[i]) - cur) * _dir, 10.0)
		if steps < 0.001 or steps > 9.999:
			steps = 0.0
			cur = roundf(cur)
		var s_true: = b / p10 - a / p10
		if absi(s_true) >= 10 and steps + 10.0 <= MAX_STEPS:
			steps += 10.0
		if _bb[i] != NONE:
			_ba[i] = _bb[i]
		_c0[i] = cur
		_cs[i] = steps * _dir
		_p0[i] = pres
		_p1[i] = 1.0 if pr1 else 0.0
		_bb[i] = NONE if pr1 else cur + _cs[i]
		_ck[i] = 1 if (steps > 0.0 or absf(pres - _p1[i]) > 0.001) else 0
		mx = maxf(mx, steps)
		p10 *= 10
	_s0 = lerpf(_s0, _s1, k)
	_s1 = 1.0 if v < 0 else 0.0
	_n = n
	_t = 0.0
	_dur = T_ROLL
	_last_kind = "roll"
	_last_steps = ceili(mx)


func _start_cross(v: int) -> void:
	_from = _target
	_target = v
	var cf: = digit_count(_from)
	var ct: = digit_count(v)
	var n: = maxi(cf, ct)
	_ensure(n)
	_n = n
	_fill(_dfrom, _from, n)
	_fill(_dto, v, n)
	_dir = 1 if absi(v) >= absi(_from) else -1
	for i in n:
		var pr0: = i < cf
		var pr1: = i < ct
		_c0[i] = float(_dfrom[i])
		_cs[i] = 0.0
		_ck[i] = 2 if (_dfrom[i] != _dto[i] or pr0 != pr1) else 0
		_p0[i] = 1.0 if pr0 else 0.0
		_p1[i] = 1.0 if pr1 else 0.0
		_ba[i] = NONE if pr0 else 0.0  # crossfade: «old glyph is blank»
		_bb[i] = NONE if pr1 else 0.0  # «new glyph is blank»
	_s0 = 1.0 if _from < 0 else 0.0
	_s1 = 1.0 if v < 0 else 0.0
	_kind = "cross"
	_t = 0.0
	_dur = T_STEP
	_last_kind = "cross"
	_last_steps = 1


func _start_fade(v: int) -> void:
	_from = _target
	_target = v
	var n: = maxi(digit_count(_from), digit_count(v))
	_ensure(n)
	_fill(_dfrom, _from, n)
	_fill(_dto, v, n)
	_kind = "fade"
	_t = 0.0
	_dur = T_FADE
	_last_kind = "fade"
	_last_steps = 0


func _settle_columns() -> void:
	var ct: = digit_count(_target)
	_ensure(ct)
	_fill(_dto, _target, ct)
	_n = ct
	for i in ct:
		_c0[i] = float(_dto[i])
		_cs[i] = 0.0
		_ck[i] = 0
		_p0[i] = 1.0
		_p1[i] = 1.0
		_ba[i] = NONE
		_bb[i] = NONE
	_s0 = 1.0 if _target < 0 else 0.0
	_s1 = _s0
	_kind = ""
	_t = 0.0


func _ensure(n: int) -> void:
	var old: = _c0.size()
	if old >= n:
		return
	_c0.resize(n)
	_cs.resize(n)
	_p0.resize(n)
	_p1.resize(n)
	_ba.resize(n)
	_bb.resize(n)
	_ck.resize(n)
	_dfrom.resize(n)
	_dto.resize(n)
	for i in range(old, n):
		_c0[i] = 0.0
		_cs[i] = 0.0
		_p0[i] = 0.0
		_p1[i] = 0.0
		_ba[i] = NONE
		_bb[i] = NONE
		_ck[i] = 0


func _fill(out: PackedInt32Array, v: int, n: int) -> void:
	var a: = absi(v)
	for i in n:
		out[i] = a % 10
		a /= 10


func _k() -> float:
	if _kind == "" or _dur <= 0.0:
		return 1.0
	var u: = clampf(_t / _dur, 0.0, 1.0)
	if _kind == "roll":
		# EXPO_OUT, normalised so it lands exactly on 1
		return 1.0 if u >= 1.0 else (1.0 - pow(2.0, -10.0 * u)) / (1.0 - pow(2.0, -10.0))
	if _kind == "cross":
		return 1.0 - pow(1.0 - u, 3.0)
	return u


func _travel(i: int, k: float) -> float:
	# EXPO_OUT clock, geometric distance: the remaining steps shrink as (steps + 1)^(1 − k) − 1, so a 10-step
	# column and a 1-step column land in the same breath (no long tail on the busiest wheel)
	var s: = _cs[i]
	if s == 0.0:
		return 0.0
	var a: = absf(s) + 1.0
	return signf(s) * (a - pow(a, 1.0 - k))


func _bump_amount() -> float:
	var b: = 0.0
	if _bump_t >= 0.0:
		b = sin(PI * clampf(_bump_t / T_BUMP, 0.0, 1.0))
	if _carry > 0.0:
		b = maxf(b, _carry * (1.0 - clampf(_carry_t / T_FADE, 0.0, 1.0)))
	return b


func _ping() -> void:
	if plate == null or not is_instance_valid(plate) or not plate.has_method("ping"):
		return
	var now: = Time.get_ticks_msec()
	if now - _ping_ms < 360:  # one light dot at a time (cascades land every 80 ms)
		return
	_ping_ms = now
	pings += 1
	plate.call("ping")


func _process(delta: float) -> void:
	if manual_clock:
		return
	advance(delta)
	if not is_animating():
		set_process(false)


# ------------------------------------------------------------------ metrics

func _dirty() -> void:
	_m_ok = false
	update_minimum_size()
	queue_redraw()


func _metrics() -> void:
	if _m_ok:
		return
	_m_ok = true
	var f: = V10Type.font(role)
	var fa: = V10Type.font(affix_role)
	_dw.resize(10)
	_colw = 0.0
	for d in 10:
		_dw[d] = f.get_string_size(DIGITS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_colw = maxf(_colw, _dw[d])
	_sep = group_sep(f)
	_sepw = f.get_string_size(_sep, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_sign = minus_for(f)
	_signw = f.get_string_size(_sign, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_asc = f.get_ascent(font_size)
	_fh = f.get_height(font_size)
	_line = V10Type.line_h(font_size)
	_cap = roundf(font_size * CAP_K)
	_pw = fa.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if prefix != "" else 0.0
	_sw = fa.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if suffix != "" else 0.0


func _block_w(cnt: int, neg: bool) -> float:
	return cnt * _colw + float((cnt - 1) / 3) * _sepw + (_signw if neg else 0.0)


func _x0(total_w: float) -> float:
	match align:
		"right":
			return size.x - total_w
		"center":
			return (size.x - total_w) * 0.5
	return 0.0


func _get_minimum_size() -> Vector2:
	_metrics()
	var w: = width_for(_target)
	if _kind != "":
		w = maxf(w, width_for(_from))
	return Vector2(ceilf(w), float(_line))


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_metrics()
	_release_cols()
	var ci: = get_canvas_item()
	var f: = V10Type.font(role)
	var fa: = V10Type.font(affix_role)
	var h: = size.y if size.y >= 1.0 else float(_line)
	var base: = floorf((h - _fh) * 0.5) + _asc  # same baseline as a centred Label of this font
	var bump: = _bump_amount()
	var dc: = color.lerp(V10DS.GOLD_300, bump) if bump > 0.0 else color
	var ac: = affix_color if affix_color.a > 0.0 else color
	if _kind == "fade":
		_draw_fade(ci, f, fa, base, dc, ac)
		return
	var k: = _k()
	var u: = clampf(_t / _dur, 0.0, 1.0) if _kind != "" else 1.0
	var bw: = block_width()
	var x0: = _x0(_pw + bw + _sw)
	if _pw > 0.0:
		_glyph(ci, fa, prefix, Vector2(roundf(x0), base), ac, 1.0)
	if _sw > 0.0:
		_glyph(ci, fa, suffix, Vector2(roundf(x0 + _pw + bw), base), ac, 1.0)
	var s: = 1.0 + BUMP * bump
	var pivot: = Vector2(x0 + _pw + bw * 0.5, base - _cap * 0.5)
	var xf: = Transform2D(0.0, Vector2(s, s), 0.0, pivot * (1.0 - s))
	if bump > 0.0:
		draw_set_transform_matrix(xf)
	var top: = base - _cap * 0.5 - _line * 0.5 - WIN_AIR
	var x: = x0 + _pw + bw
	for i in _n:
		var p: = lerpf(_p0[i], _p1[i], k)
		if i > 0 and i % 3 == 0:
			x -= p * _sepw
		var cw: = p * _colw
		var left: = x - cw
		if p > 0.002:
			match _ck[i]:
				0:
					_digit(ci, f, posmod(roundi(_c0[i]), 10), left, cw, base, dc, p)
				1:
					var rid: = _col(i, left, cw, top, xf)
					var pos: = _c0[i] + _travel(i, k)
					var j0: = floori(pos)
					_roll_glyph(rid, f, i, j0, pos, left, cw, base, dc, p)
					_roll_glyph(rid, f, i, j0 + 1, pos, left, cw, base, dc, p)
				2:
					var rid2: = _col(i, left, cw, top, xf)
					var dy: = DRIFT * _dir
					if _ba[i] == NONE:
						_digit(rid2, f, _dfrom[i], left, cw, base - dy * k, dc, p * (1.0 - u))
					if _bb[i] == NONE:
						_digit(rid2, f, _dto[i], left, cw, base + dy * (1.0 - k), dc, p * u)
		x = left
	var sp: = lerpf(_s0, _s1, k)
	if sp > 0.002:
		x -= sp * _signw
		_glyph(ci, f, _sign, Vector2(roundf(x + sp * _signw - _signw), base), dc, sp)
	if bump > 0.0:
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_fade(ci: RID, f: Font, fa: Font, base: float, dc: Color, ac: Color) -> void:
	# fx min: the whole number fades old → new in 120 ms; unchanged digits in an unchanged layout stay put
	var u: = clampf(_t / _dur, 0.0, 1.0)
	var cf: = digit_count(_from)
	var ct: = digit_count(_target)
	var wa: = _block_w(cf, _from < 0)
	var wb: = _block_w(ct, _target < 0)
	var xa: = _x0(_pw + wa + _sw)
	var xb: = _x0(_pw + wb + _sw)
	var same: = cf == ct and (_from < 0) == (_target < 0) and absf(xa - xb) < 0.5
	if same:
		if _pw > 0.0:
			_glyph(ci, fa, prefix, Vector2(roundf(xa), base), ac, 1.0)
		if _sw > 0.0:
			_glyph(ci, fa, suffix, Vector2(roundf(xa + _pw + wa), base), ac, 1.0)
		var x: = xa + _pw + wa
		for i in ct:
			if i > 0 and i % 3 == 0:
				x -= _sepw
			x -= _colw
			if _dfrom[i] == _dto[i]:
				_digit(ci, f, _dto[i], x, _colw, base, dc, 1.0)
			else:
				_digit(ci, f, _dfrom[i], x, _colw, base, dc, 1.0 - u)
				_digit(ci, f, _dto[i], x, _colw, base, dc, u)
		if _target < 0:
			_glyph(ci, f, _sign, Vector2(roundf(x - _signw), base), dc, 1.0)
		return
	_static_number(ci, f, fa, _dfrom, cf, _from < 0, xa, wa, base, dc, ac, 1.0 - u)
	_static_number(ci, f, fa, _dto, ct, _target < 0, xb, wb, base, dc, ac, u)


func _static_number(ci: RID, f: Font, fa: Font, digs: PackedInt32Array, cnt: int, neg: bool, x0: float, bw: float,
		base: float, dc: Color, ac: Color, a: float) -> void:
	if _pw > 0.0:
		_glyph(ci, fa, prefix, Vector2(roundf(x0), base), ac, a)
	if _sw > 0.0:
		_glyph(ci, fa, suffix, Vector2(roundf(x0 + _pw + bw), base), ac, a)
	var x: = x0 + _pw + bw
	for i in cnt:
		if i > 0 and i % 3 == 0:
			x -= _sepw
		x -= _colw
		_digit(ci, f, digs[i], x, _colw, base, dc, a)
	if neg:
		_glyph(ci, f, _sign, Vector2(roundf(x - _signw), base), dc, a)


func _roll_glyph(rid: RID, f: Font, i: int, j: int, pos: float, left: float, cw: float, base: float, c: Color, p: float) -> void:
	var fj: = float(j)
	if absf(fj - _ba[i]) < 0.5 or absf(fj - _bb[i]) < 0.5:
		return  # the leading zero of a column that appears / goes away is never drawn
	var dist: = absf(fj - pos)
	if dist >= 1.0:
		return
	# soft window: full ink near the centre line, fading as the digit leaves (the clip makes the hard edge)
	var a: = 1.0 - smoothstep(0.15, 0.75, dist)
	_digit(rid, f, posmod(j, 10), left, cw, base + (fj - pos) * _line, c, p * a)


func _digit(ci: RID, f: Font, d: int, left: float, cw: float, base: float, c: Color, a: float) -> void:
	_glyph(ci, f, DIGITS[d], Vector2(roundf(left + (cw - _dw[d]) * 0.5), base), c, a)


func _glyph(ci: RID, f: Font, text: String, pos: Vector2, c: Color, a: float) -> void:
	if a <= 0.004:
		return
	if on_art:  # §3: the one shadow rule (same as V10Type.settings(on_art = true))
		var sc: = Color(V10DS.SHADOW, V10DS.SHADOW_A * a * c.a)
		f.draw_string(ci, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sc)
		f.draw_string_outline(ci, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, sc)
	f.draw_string(ci, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(c, c.a * a))


func _col(i: int, left: float, cw: float, top: float, xf: Transform2D) -> RID:
	# a pooled clipped canvas item per column: the odometer window (line box tall, column wide)
	while _col_rid.size() <= i:
		var r: = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(r, get_canvas_item())
		RenderingServer.canvas_item_set_clip(r, true)
		_col_rid.append(r)
		_col_used.append(0)
		live_items += 1
	var rid: = _col_rid[i]
	_col_used[i] = 1
	var pad: = 8.0 if on_art else 2.0
	RenderingServer.canvas_item_set_transform(rid, xf)
	RenderingServer.canvas_item_set_custom_rect(rid, true, Rect2(left - pad, top, cw + pad * 2.0, _line + WIN_AIR * 2.0 + (4.0 if on_art else 0.0)))
	return rid


func _release_cols() -> void:
	for i in _col_used.size():
		if _col_used[i]:
			RenderingServer.canvas_item_clear(_col_rid[i])
			_col_used[i] = 0
