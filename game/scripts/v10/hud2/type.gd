class_name V10Type
extends RefCounted

# V10Type — the three type roles of HUD v2 (docs/HUD_V2.md §3) and fixed-box auto-fit (§2.3).
#
#   V10Type.font("display" | "display_italic" | "ui" | "num" | "overline" | "hand") -> Font
#   V10Type.settings(role, size, color, on_art := false) -> LabelSettings   (outline 0 always; shadow only on art)
#   V10Type.label(text, role, size, color, on_art := false) -> Label
#   V10Type.fit(label, text, role_steps, max_w, max_lines := 1) -> int     (chosen size; never resizes the box)
#   V10Type.quant(size, role) -> int                                         (snap any legacy size to the scale)
#   V10Type.overflow : Array of {text, steps, max_w}                         (strings that needed an ellipsis)
#
# Fonts come from V10Fonts (branch v10-fonts): Display = Playfair Display 700 (italic only for the combo
# number and the Приём name), UI = Nunito 700/800, Numerals = Nunito 900 with tnum + lnum, Overline = Nunito 900
# caps with +14 % tracking, hand = Caveat 600 (the heroine's voice, not a HUD role).

# fit() steps per plate role (§2.3 table)
const STEPS: = {
	"title_sm": {"role": "ui", "sizes": [22, 20, 18]},
	"caption_m": {"role": "ui", "sizes": [18]},
	"title_l": {"role": "display", "sizes": [32, 28, 26]},
	"text_l": {"role": "ui", "sizes": [22, 20, 18]},
	"value": {"role": "num", "sizes": [40, 32, 28]},
	"value_s": {"role": "num", "sizes": [22]},
	"button_play": {"role": "display", "sizes": [32, 28, 26]},
	"button_ui": {"role": "ui", "sizes": [22, 20, 18]},
}
# line heights (§3 «Межстрочие»)
const LINE: = {64: 72, 44: 52, 40: 44, 32: 40, 28: 36, 26: 34, 22: 32, 20: 28, 18: 26, 15: 20, 30: 36}

static var overflow: Array = []
static var _fonts: = {}
static var _ls: = {}


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	match kind:
		"display":
			f = V10Fonts.font("ui_display", 700)
		"display_italic":
			f = V10Fonts.font("ui_display_italic", 700)
		"ui":
			f = V10Fonts.font("ui_body", 700)
		"ui_strong":
			f = V10Fonts.font("ui_body", 800)
		"num":
			var fv: FontVariation = V10Fonts.font("ui_body", 900).duplicate()
			var ts: = TextServerManager.get_primary_interface()
			fv.opentype_features = {ts.name_to_tag("tnum"): 1, ts.name_to_tag("lnum"): 1}
			f = fv
		"overline":
			var ov: FontVariation = V10Fonts.font("ui_body", 900).duplicate()
			ov.spacing_glyph = 2  # +14 % of 15 px
			f = ov
		"hand":
			f = V10Fonts.font("hand")
		_:
			f = V10Fonts.font("ui_body", 700)
	_fonts[kind] = f
	return f


static func role_font(role: String) -> Font:
	return font(role)


static func line_h(size: int) -> int:
	return int(LINE.get(size, roundi(size * 1.4)))


static func settings(role: String, size: int, color: Color, on_art: = false) -> LabelSettings:
	var key: = "%s|%d|%s|%s" % [role, size, color.to_html(), on_art]
	if _ls.has(key):
		return _ls[key]
	var s: = LabelSettings.new()
	s.font = font(role)
	s.font_size = size
	s.font_color = color
	s.outline_size = 0
	s.line_spacing = float(line_h(size) - roundi(font(role).get_height(size)))
	if on_art:  # the one shadow rule (§3): only for text lying directly on art
		s.shadow_color = Color(V10DS.SHADOW, V10DS.SHADOW_A)
		s.shadow_offset = Vector2(0, 2)
		s.shadow_size = 6
	else:
		s.shadow_size = 0
		s.shadow_color = Color.TRANSPARENT
	_ls[key] = s
	return s


static func label(text: String, role: String, size: int, color: Color, on_art: = false) -> Label:
	var l: = Label.new()
	l.text = text
	l.label_settings = settings(role, size, color, on_art)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_meta("v10_role", role)
	return l


static func text_w(text: String, role: String, size: int) -> float:
	return font(role).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func lines_needed(text: String, role: String, size: int, max_w: float) -> int:
	var f: = font(role)
	var flags: = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var sz: = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, -1, flags)
	return maxi(1, roundi(sz.y / maxf(1.0, f.get_height(size))))


static func fit(l: Label, text: String, steps_key: String, max_w: float, max_lines: = 1, color: = V10DS.PAPER_100, on_art: = false) -> int:
	# §2.3: walk the role's sizes top-down; first size that fits wins; else bottom size + ellipsis + overflow log.
	# The label's box is never changed here: callers give it a fixed rect, clip_text stays on.
	var st: Dictionary = STEPS.get(steps_key, STEPS.title_sm)
	var role: String = st.role
	var sizes: Array = st.sizes
	var chosen: int = sizes[sizes.size() - 1]
	var ok: = false
	for s in sizes:
		if max_lines <= 1:
			if text_w(text, role, s) <= max_w:
				chosen = s
				ok = true
				break
		elif lines_needed(text, role, s, max_w) <= max_lines:
			chosen = s
			ok = true
			break
	if not ok:
		overflow.append({"text": text, "steps": steps_key, "max_w": max_w})
	l.text = text
	l.label_settings = settings(role, chosen, color, on_art)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if max_lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = max_lines
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.set_meta("v10_role", role)
	l.set_meta("v10_fit_ok", ok)
	return chosen


static func quant(size: int, role: = "ui") -> int:
	# legacy UI.label(…, size) -> nearest size of the closed scale (§9.1 row 3)
	if role == "display":
		for s in [64, 44, 32]:
			if size >= s - 6:
				return s
		return 32
	if role == "num":
		if size >= 34:
			return 40
		if size >= 25:
			return 28
		return 22
	if size <= 20:
		return 18
	if size <= 24:
		return 22
	return 26
