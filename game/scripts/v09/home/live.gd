class_name V9HomeLive
extends Control

# 0.9 live heroine at home (docs/0.9-spec.md §C). One full-screen layer between her art and the home UI: it takes
# every tap that no button took and answers it by zone (V9Touch.classify: head / hand / outfit / body / room).
#
#   var live: = V9HomeLive.make(home, "rig" | "art" | "video", {hero | art + tex + focus + face_rect})
#   live.say(text, emo = "", voice = "")   speech bubble (+ her emotion portrait when she is a painting or a video),
#                                          lip-sync on the rig through Sfx.voice_started; home._say() routes here
#   live.tap_zone(zone)                    act as if that zone was tapped (demo, dev)
#
# A reaction: emotion (rig: her face crossfades to one of the 25 emotion portraits, aligned on the rig's face;
# painting / video: a round emotion portrait on the bubble), a line (V9TouchLines; voiced when an mp3 exists),
# a springy squash about her feet, a soft click and «pet» haptic, hearts (by S.fx_level). The first 3 touches a day
# on head / hand / outfit give +5 affection (the 0.8 «Коснись её» plate). Idle: blinks, glances, a small hop, and
# after a long pause one line (at most two a visit). Nothing here covers or blocks the home buttons: the layer sits
# under them, and its bubble / portrait / particles take no taps.
#
# Video pilot: video_wanted() — partner Маджонг-тян in her base outfit, effects «Полные» and
# assets/v09/video/mc_lobby.ogv present — home draws build_video(): the lobby loop (Theora, 720×1280, drawn full
# screen) over its first frame (mc_lobby_still.webp), so a slow decoder or a missing codec shows the still.
# Dev: --fps=1 (FPS + video state plate), --zones=1 (draws the tap zones).

const VIDEO_PATH: = "res://assets/v09/video/mc_lobby.ogv"
const STILL_PATH: = "res://assets/v09/video/mc_lobby_still.webp"
const PATCH_HOLD: = 2.1
const PATCH_IN: = 0.2
const PATCH_OUT: = 0.38
const IDLE_MICRO: = Vector2(6.5, 11.0)
const IDLE_LINE: = 24.0
const IDLE_LINES_MAX: = 2
const BUBBLE_X: = 114.0
const BUBBLE_W: = 300.0
# the bubble stays under the clock plate when it can; a long reply may rise to BUBBLE_TOP_MIN (under the top bar)
# while the clock plate fades out, so it still sits above her head instead of over her hand or chest
const BUBBLE_TOP: = 186.0
const BUBBLE_TOP_MIN: = 116.0
const AV: = 80.0
# the spam cooldown's tiny expression flicker (alternating) and how long the rig's face holds it
const COOL_EMO: = ["shy", "surprised"]
const COOL_HOLD: = 0.9
const ZONE_EMO: = {"head": "shy", "hand": "happy", "outfit": "happy", "bg": "surprised", "spam": "pout", "idle": "happy"}
# the face patch: the emotion portrait shows only inside a soft ellipse around her face, so hair, body and pose stay
# the rig's own and only the expression changes
const PATCH_SHADER: = "shader_type canvas_item;\nuniform vec2 c = vec2(0.5);\nuniform vec2 r = vec2(0.2);\nuniform float f = 0.42;\n" + \
	"void fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tfloat l = length((UV - c) / r);\n\tcol.a *= 1.0 - smoothstep(1.0 - f, 1.0, l);\n\tCOLOR = col * COLOR;\n}\n"

var home: Control
var hid: = "mc"
var mode: = "rig"
var hero: Hero
var art: TextureRect
var art_tex: = Vector2(859, 1280)
var art_focus: = Vector2(0.5, 0.4)
var geom: = {}
var touch: = V9Touch.new()
var video: VideoStreamPlayer
var patch: TextureRect
var patch_emo: = ""
var _patch_left: = 0.0
var _patch_tw: Tween
var sq: = 0.0
var sq_v: = 0.0
var idle_t: = 0.0
var next_micro: = 8.0
var idle_lines: = 0
var bubble: Control
var fps_lbl: Label
var zones_dbg: = false
var _t: = 0.0
var _cool_i: = 0


static func video_wanted(h: String) -> bool:
	return h == "mc" and G.equipped("mc") == "" and G.fx_level() == "full" and ResourceLoader.exists(VIDEO_PATH)


# the lobby loop over its own first frame; returns the player (null when the stream does not load)
static func build_video(parent: Control, sz: Vector2) -> VideoStreamPlayer:
	var stream = load(VIDEO_PATH)
	if not (stream is VideoStream):
		return null
	if ResourceLoader.exists(STILL_PATH):
		var still: = TextureRect.new()
		still.texture = load(STILL_PATH)
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		still.size = sz
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		still.name = "V9LobbyStill"
		parent.add_child(still)
	var vp: = VideoStreamPlayer.new()
	vp.name = "V9LobbyVideo"
	vp.stream = stream
	vp.expand = true
	vp.size = sz
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.volume_db = -80.0
	if "loop" in vp:
		vp.set("loop", true)
	vp.finished.connect(vp.play)
	parent.add_child(vp)
	vp.play()
	return vp


static func make(h_: Control, mode_: String, opts: Dictionary) -> V9HomeLive:
	var l: = V9HomeLive.new()
	l.home = h_
	l.mode = mode_
	l.hid = str(G.S.get("partner", "mc"))
	l.size = h_.size
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.name = "V9HomeLive"
	l.hero = opts.get("hero")
	match mode_:
		"rig":
			l.geom = V9Touch.rig_geom(l.hid)
		"art":
			l.art = opts.art
			l.art_tex = opts.tex_size
			l.art_focus = opts.focus
			l.geom = V9Touch.art_geom(opts.face_rect, str(opts.get("art_key", "")))
		"video":
			l.video = opts.get("video")
			l.geom = V9Touch.video_geom()
	h_.add_child(l)
	if mode_ == "video" and not G.settings_changed.is_connected(l._on_settings):
		G.settings_changed.connect(l._on_settings)
	var args: = OS.get_cmdline_user_args()
	l.zones_dbg = "--zones=1" in args
	if "--fps=1" in args:
		l._build_fps()
	l.next_micro = randf_range(IDLE_MICRO.x, IDLE_MICRO.y)
	return l


# «Эффекты» turned down while home is open: the loop stops on its first frame (the still under it)
func _on_settings(key: String) -> void:
	if key == "fx_level" and video and is_instance_valid(video) and G.fx_level() != "full":
		video.stop()
		video.visible = false


# ------------------------------------------------------------------ geometry

# a point on screen (global) -> the art's own pixels (rig texture, outfit texture or the 720×1280 video)
func to_art(p: Vector2) -> Vector2:
	match mode:
		"rig":
			return hero.sprite.get_global_transform().affine_inverse() * p
		"art":
			var loc: Vector2 = art.get_global_transform().affine_inverse() * p
			var uv: = loc / art.size
			var sc: = _cover_scale()
			var ctr: = art_focus.clamp(sc * 0.5, Vector2.ONE - sc * 0.5)
			return (ctr + (uv - Vector2(0.5, 0.5)) * sc) * art_tex
	return get_global_transform().affine_inverse() * p * (Vector2(720, 1280) / size)


func from_art(p: Vector2) -> Vector2:
	match mode:
		"rig":
			return hero.sprite.get_global_transform() * p
		"art":
			var sc: = _cover_scale()
			var ctr: = art_focus.clamp(sc * 0.5, Vector2.ONE - sc * 0.5)
			var uv: = (p / art_tex - ctr) / sc + Vector2(0.5, 0.5)
			return art.get_global_transform() * (uv * art.size)
	return get_global_transform() * (p * (size / Vector2(720, 1280)))


func _cover_scale() -> Vector2:
	var sa: = art.size.x / art.size.y
	var ta: = art_tex.x / art_tex.y
	return Vector2(1.0, ta / sa) if sa > ta else Vector2(sa / ta, 1.0)


func zone_at(p: Vector2) -> String:
	return V9Touch.classify(geom, to_art(p))


# a representative screen point of a zone (dev taps, demo)
func zone_point(zone: String) -> Vector2:
	match zone:
		"head":
			return from_art(geom.head)
		"hand":
			if geom.has("hand"):
				return from_art(geom.hand)
			return from_art(geom.head)
		"outfit":
			var by: Vector2 = geom.band_y
			var bd: Vector2 = geom.band_dx
			return from_art(Vector2(float(geom.cx) + (bd.x + bd.y) * 0.5, (by.x + by.y) * 0.5))
		"body":
			var b: Rect2 = geom.body
			return from_art(Vector2(float(geom.cx), b.position.y + b.size.y * 0.75))
	# the room: right of her, under the cards
	return Vector2(size.x - 70.0, size.y * 0.62)


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tap(get_global_transform() * e.position)


func tap_zone(zone: String) -> void:
	_tap(zone_point(zone), zone)


func _tap(p: Vector2, force: = "") -> void:
	idle_t = 0.0
	var zone: = force if force != "" else zone_at(p)
	var d: = touch.decide(zone, _t)
	if d.kind == "quiet":
		# 0.9 (spec §C): a tap on «body» (chest, hips, legs) gets no answer at all — no squash, haptic, sound or line,
		# and it does not count toward the «не так быстро» spam line either (decide() returns before the tally)
		return
	if d.kind == "cool":
		_cool_ack()
		return
	_react(d, p)


# 0.9: after «не так быстро» (V9Touch.SPAM_CD) every touch is still acknowledged, only smaller: a soft click and the
# tap haptic, a V9Feel press on her bubble (or its portrait), a light squash on the rig and a tiny expression
# flicker (COOL_EMO, a short hold) — no line, no affection, no hearts
func _cool_ack() -> void:
	_cool_i += 1
	var emo: String = COOL_EMO[_cool_i % COOL_EMO.size()]
	V9Feel.sound("pop", 1.12 + randf() * 0.06, -12)
	var b: Control = bubble if bubble and is_instance_valid(bubble) and not bubble.is_queued_for_deletion() else null
	if mode == "rig":
		_bump(0.5)
		show_emotion(emo, COOL_HOLD)
		if b and _settled(b):
			V9Feel.press(b, "", "tap")
		else:
			V9Feel.haptic("tap")
		return
	# painting / video: the expression lives on the bubble's round portrait — a new one springs in, the same one dips
	if b and b.has_meta("av"):
		_set_avatar(b, V8Art.emo_name(_paint_emo(emo)))
		V9Feel.haptic("tap")
	elif b and _settled(b):
		V9Feel.press(b, "", "tap")
	else:
		V9Feel.haptic("tap")
		if not b and V9Feel.can_fx():
			Fx.burst(home, from_art(geom.head), "petal", maxi(1, int(round(3 * V9Feel.fx_scale()))))


# a bubble / portrait still springing in (its own scale tween) is not pressed: V9Feel would keep that mid-tween
# scale as its resting one
static func _settled(n: CanvasItem) -> bool:
	return n.has_meta(V9Feel.META_BASE) or n.scale.is_equal_approx(Vector2.ONE)


func _react(d: Dictionary, p: Vector2) -> void:
	var zone: String = d.zone
	var entry: = V9TouchLines.entry(hid, zone, int(d.i)) if d.line else {}
	var emo: String = entry.get("emo", ZONE_EMO.get(zone, "happy"))
	var fs: = V9Feel.fx_scale()
	if zone == "bg":
		_glance(p)
		V9Feel.haptic("tap")
		V9Feel.sound("flip", 1.15, -9)
		if V9Feel.can_fx():
			Fx.burst(home, p, "petal", maxi(2, int(round(7 * fs))))
	else:
		_bump(0.7 if zone == "spam" else 1.0)
		V9Feel.haptic("pet")
		V9Feel.sound("pop", 1.08 + randf() * 0.1, -5)
		if V9Feel.can_fx() and zone != "spam":
			Fx.burst(home, p, "heart", maxi(2, int(round(6 * fs))))
	if zone != "bg" or not entry.is_empty():
		show_emotion(emo)
	if not entry.is_empty():
		say(entry.text, emo, entry.voice)
	if d.aff:
		_gain(p)


func _gain(p: Vector2) -> void:
	V9Touch.commit_aff(hid)
	G.save()
	if home.has_method("_build_affection"):
		home._build_affection()
		if home.get("aff_root"):
			UI.punch(home.aff_root, 0.12)
	V9Feel.sound("sparkle", 1.2, -6)
	var at: = from_art(geom.head)
	# «+5 ♥» rises from the affection plate it fills (beside her head it ran over the words of her bubble)
	var ar = home.get("aff_root")
	var ft: = at + Vector2(110, -10)
	if ar is Control and is_instance_valid(ar):
		var r: Rect2 = (ar as Control).get_global_rect()
		ft = Vector2(r.position.x + r.size.x * 0.72, r.position.y - 8.0)
	Fx.float_text(home, ft, "+%d ♥" % V9Touch.AFF, Color("ffd0e0"), 40)
	if V9Feel.can_fx():
		Fx.burst(home, at + Vector2(0, -50), "heart", maxi(3, int(round(14 * V9Feel.fx_scale()))))


# ------------------------------------------------------------------ her body

func _bump(a: float) -> void:
	if mode == "rig":
		sq_v += 12.0 * a


func _glance(p: Vector2) -> void:
	if mode == "rig" and hero and _patch_left <= 0.0:
		hero.tilt_v += 0.4 * (1.0 if p.x > hero.global_position.x else -1.0)


# the rig's face takes the emotion portrait's expression for PATCH_HOLD s (painting / video: the bubble portrait)
func show_emotion(emo: String, hold: = PATCH_HOLD) -> void:
	var en: = V8Art.emo_name(emo)
	if en == "":
		return
	if mode != "rig":
		if bubble and is_instance_valid(bubble) and bubble.has_meta("av"):
			_set_avatar(bubble, V8Art.emo_name(_paint_emo(en)))
		return
	if not V8Art.has_emotion(hid, en) or hero == null:
		return
	var tex: = V8Art.emotion(hid, en)
	var ef: = V8Art.emotion_face(hid, en)
	var efw: = V8Art.emotion_face_w(hid, en)
	var fw: float = float(V8Art.RIG_FACE_W.get(hid, 90.0)) * hero.sprite.scale.x
	var k: = fw / efw
	if patch == null or not is_instance_valid(patch):
		patch = TextureRect.new()
		patch.name = "V9FacePatch"
		patch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var m: = ShaderMaterial.new()
		var sh: = Shader.new()
		sh.code = PATCH_SHADER
		m.shader = sh
		patch.material = m
		patch.modulate.a = 0.0
		hero.add_child(patch)
	var ts: = Vector2(tex.get_width(), tex.get_height())
	patch.texture = tex
	patch.size = ts * k
	patch.position = hero.face_local() - ef * k
	patch.pivot_offset = ef * k
	var pm: ShaderMaterial = patch.material
	pm.set_shader_parameter("c", ef / ts)
	pm.set_shader_parameter("r", Vector2(efw * 0.8 / ts.x, efw * 1.02 / ts.y))
	var was: = _patch_left > 0.0 and patch.modulate.a > 0.5
	patch_emo = en
	_patch_left = hold
	if _patch_tw and _patch_tw.is_valid():
		_patch_tw.kill()
	_patch_tw = create_tween().set_parallel()
	if was:
		patch.scale = Vector2.ONE * 1.03
		_patch_tw.tween_property(patch, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_patch_tw.tween_property(patch, "modulate:a", 1.0, 0.1)
	else:
		patch.scale = Vector2.ONE
		_patch_tw.tween_property(patch, "modulate:a", 1.0, PATCH_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# her head stops swaying under the new face (the patch does not follow the shader's head sway / breathing)
		_patch_tw.tween_method(_set_sway, _sway(), 0.0, PATCH_IN)
	hero.tilt = 0.0
	hero.tilt_v = 0.0


func _sway() -> float:
	return float(hero.mat.get_shader_parameter("sway")) if hero and hero.mat.get_shader_parameter("sway") != null else 1.0


func _set_sway(v: float) -> void:
	if hero:
		hero.mat.set_shader_parameter("sway", v)
		hero.mat.set_shader_parameter("breath_amp", v)


func _end_patch() -> void:
	if patch == null or not is_instance_valid(patch):
		return
	if _patch_tw and _patch_tw.is_valid():
		_patch_tw.kill()
	_patch_tw = create_tween().set_parallel()
	_patch_tw.tween_property(patch, "modulate:a", 0.0, PATCH_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_patch_tw.tween_method(_set_sway, _sway(), 1.0, PATCH_OUT + 0.3)
	patch_emo = ""


# ------------------------------------------------------------------ bubble

# `talk` = false: the caller already played / announced the line (Sfx.say, V7DayNight.say_home emit voice_started)
func say(text: String, emo: = "", voice: = "", talk: = true) -> void:
	if text == "":
		return
	if bubble and is_instance_valid(bubble):
		bubble.queue_free()
	var with_av: = mode != "rig"
	var head: = from_art(geom.head)
	var pos: = Vector2(BUBBLE_X, 176.0)
	var tail_up: = false
	# 0.9: anchored by its bottom edge above her face, so extra lines grow upward (never lower than the clock plate
	# allows: the video frames her head high, so its bubble may start at 176). When a long line would still reach her
	# eyes (bottom past head − 0.45 r), it hangs just under her chin with the tail pointing up instead.
	var hr: float = (from_art(geom.head + Vector2(0, float(geom.head_r))) - head).y
	var h: = _bubble_h(text, with_av)
	var top: = 176.0 if mode == "video" else BUBBLE_TOP
	pos.y = maxf(top, head.y - hr - 30.0 - h)
	var over_clock: = false
	if pos.y + h > head.y - hr * 0.45:
		# 0.9: every reply (hand, outfit, room — not only the head) stays above her head: rise over the clock plate
		# first; only a line too long even for that hangs under her chin
		pos.y = maxf(BUBBLE_TOP_MIN, head.y - hr - 30.0 - h)
		over_clock = pos.y < top
		if pos.y + h > head.y - hr * 0.45:
			pos.y = head.y + hr * 0.85 + 26.0
			tail_up = true
			over_clock = false
	bubble = _bubble(text, pos, _paint_emo(emo) if with_av else emo, with_av, tail_up, head.x - pos.x)
	home.set("bubble", bubble)
	_clock_fade(over_clock, bubble)
	var dur: = minf(0.4 + text.length() * 0.045, 4.0)
	if talk and voice != "" and G.S.get("sound", true) and G.S.get("voice", true):
		var st = load(voice)
		if st is AudioStream and Sfx.voice:
			Sfx.voice.stream = st
			Sfx.voice.play()
			dur = (st as AudioStream).get_length()
	if talk:
		Sfx.voice_started.emit(hid, text, dur)
	var b: = bubble
	var t: Tween = b.create_tween()
	t.tween_interval(maxf(3.6, dur + 1.6))
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)


# the day/night clock plate (V7DayNight) gives way to a bubble that rises over it, and comes back when it is gone
func _clock_fade(hide_it: bool, b: Control) -> void:
	var chip: = home.get_node_or_null("V7ClockChip") as CanvasItem
	if chip == null:
		return
	var t: = chip.create_tween()
	t.tween_property(chip, "modulate:a", 0.0 if hide_it else 1.0, 0.18)
	if hide_it and is_instance_valid(b):
		b.tree_exiting.connect( func():
			if is_instance_valid(chip) and not (bubble and is_instance_valid(bubble) and bubble != b and not bubble.is_queued_for_deletion()):
				chip.create_tween().tween_property(chip, "modulate:a", 1.0, 0.25), CONNECT_ONE_SHOT)


# Common.bubble's look; with `av` a round emotion portrait sits in the bubble's left part (painting / video modes)
func _bubble_h(text: String, av: bool) -> float:
	var w: = BUBBLE_W + (AV - 6.0 if av else 0.0)
	var tx: = (AV + 8.0) if av else 18.0
	var tw: = w - tx - 18.0
	var th: float = UI.font("body", 800).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, tw - 4.0, 22, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	return maxf(AV + 12.0 if av else 56.0, 30.0 + th)


# the painting keeps its own smile: the bubble portrait never contradicts it with a sulk or tears (a tease reads «shy»)
func _paint_emo(emo: String) -> String:
	var en: = V8Art.emo_name(emo) if emo != "" else ""
	return "shy" if en in ["pout", "sad"] else emo


func _bubble(text: String, pos: Vector2, emo: String, av: bool, tail_up: = false, tail_x: = -1.0) -> Control:
	var w: = BUBBLE_W + (AV - 6.0 if av else 0.0)
	var tx: = (AV + 8.0) if av else 18.0
	var tw: = w - tx - 18.0
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = pos
	root.name = "V9Bubble"
	var h: = _bubble_h(text, av)
	var tail: = Polygon2D.new()
	tail.color = Color(0.12, 0.11, 0.13, 0.97)
	if tail_up:
		var tc: = clampf(tail_x, 60.0, w - 40.0) if tail_x >= 0.0 else w - 50.0
		tail.polygon = PackedVector2Array([Vector2(tc - 22, 6), Vector2(tc + 18, 6), Vector2(tc + 4, -22)])
	else:
		tail.polygon = PackedVector2Array([Vector2(w - 80, h - 6), Vector2(w - 40, h - 6), Vector2(w - 30, h + 22)])
	root.add_child(tail)
	var b: = UI.rbox("cream", Rect2(0, 0, w, h), 24, 3, 12)
	b.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	var l: = UI.label(text, 22, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(tx, 12)
	l.size = Vector2(tw, h - 24)
	l.custom_minimum_size = Vector2(tw, 0)
	root.add_child(l)
	if av:
		root.set_meta("av", true)
		_set_avatar(root, V8Art.emo_name(emo) if emo != "" else "happy", Vector2(8, (h - AV) * 0.5))
	root.size = Vector2(w, h)
	root.pivot_offset = Vector2(w * 0.7, 0.0 if tail_up else h)
	home.add_child(root)
	root.scale = Vector2(0.4, 0.4)
	root.modulate.a = 0
	var t: Tween = root.create_tween().set_parallel()
	t.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "modulate:a", 1.0, 0.15)
	return root


func _set_avatar(b: Control, en: String, at = null) -> void:
	if en == "" or not V8Art.has_emotion(hid, en):
		en = "happy"
	var old: Node = b.get_node_or_null("Av")
	var pos: Vector2 = at if at is Vector2 else (old.position if old else Vector2(8, 8))
	if old and str(old.get_meta("emo", "")) == en:
		# the same expression again: the portrait dips and springs back (V9Feel press, no click — the caller's tap
		# already sounded), never grows
		if _settled(old as CanvasItem):
			V9Feel.press(old as CanvasItem, "", "")
		return
	var a: = V8Art.emotion_avatar(hid, en, Rect2(pos, Vector2(AV, AV)), "gold")
	a.name = "Av"
	a.set_meta("emo", en)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if old:
		old.name = "AvOld"
		var ft: = old.create_tween()
		ft.tween_property(old, "modulate:a", 0.0, 0.16)
		ft.tween_callback(old.queue_free)
		a.pivot_offset = Vector2(AV, AV) * 0.5
		a.scale = Vector2.ONE * 0.9
		a.create_tween().tween_property(a, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.add_child(a)


# ------------------------------------------------------------------ idle + frame

func _process(dt: float) -> void:
	_t += dt
	if mode == "rig" and hero:
		sq_v += (-170.0 * sq - 9.0 * sq_v) * dt
		sq += sq_v * dt
		hero.scale = Vector2(1.0 + sq * 0.035, 1.0 - sq * 0.05)
	if _patch_left > 0.0:
		_patch_left -= dt
		if _patch_left <= 0.0:
			_end_patch()
	idle_t += dt
	if idle_t >= next_micro and mode == "rig" and hero and _patch_left <= 0.0:
		next_micro = idle_t + randf_range(IDLE_MICRO.x, IDLE_MICRO.y)
		_micro()
	if idle_t >= IDLE_LINE and idle_lines < IDLE_LINES_MAX and _quiet():
		idle_lines += 1
		idle_t = 0.0
		next_micro = randf_range(IDLE_MICRO.x, IDLE_MICRO.y)
		var n: = V9TouchLines.pool(hid, "idle").size()
		if n > 0:
			var e: = V9TouchLines.entry(hid, "idle", randi() % n)
			show_emotion(e.emo)
			say(e.text, e.emo, e.voice)
	if fps_lbl and is_instance_valid(fps_lbl) and Engine.get_process_frames() % 15 == 0:
		_update_fps()
	if zones_dbg:
		queue_redraw()


func _micro() -> void:
	match randi() % 4:
		0, 1:
			hero.blink_phase = 0.0
			var tw: = create_tween()
			tw.tween_interval(0.24)
			tw.tween_callback(func(): if hero: hero.blink_phase = 0.0)
		2:
			hero.tilt_v += randf_range(0.25, 0.4) * (1.0 if randf() < 0.5 else -1.0)
		3:
			_bump(0.4)


# no bubble, no popup or toast over home, no easter-egg line on its way
func _quiet() -> bool:
	if bubble and is_instance_valid(bubble):
		return false
	var eggs = get_node_or_null("/root/V7Eggs")
	if eggs and bool(eggs.get("home_line_busy")):
		return false
	var m = home.get("main")
	if m and m.has_method("_top_popup") and m._top_popup() != null:
		return false
	return true


# ------------------------------------------------------------------ dev

func _build_fps() -> void:
	var p: = UI.rbox("glass", Rect2(16, size.y - 296 - 50, 270, 40), 14, 2, 4)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.name = "V9Fps"
	home.add_child.call_deferred(p)
	fps_lbl = UI.label("FPS —", 17, Color("fff3c4"), UI.DARK, 3, "body", 900)
	fps_lbl.position = Vector2(12, 7)
	fps_lbl.size = Vector2(246, 26)
	p.add_child(fps_lbl)


func _update_fps() -> void:
	var s: = "FPS %d · " % int(Engine.get_frames_per_second())
	if video and is_instance_valid(video):
		s += ("видео ▶ %.1f с" % video.stream_position) if video.is_playing() else "видео ■ стоп-кадр"
	else:
		s += {"rig": "риг", "art": "арт наряда", "video": "стоп-кадр"}.get(mode, mode)
	fps_lbl.text = s


func _draw() -> void:
	if not zones_dbg:
		return
	var inv: = get_global_transform().affine_inverse()
	var hc: = inv * from_art(geom.head)
	var hr: = (inv * from_art(geom.head + Vector2(float(geom.head_r), 0))).distance_to(hc)
	draw_arc(hc, hr, 0, TAU, 48, Color(1, 0.2, 0.3), 3.0)
	if geom.has("hand"):
		var c: = inv * from_art(geom.hand)
		draw_arc(c, (inv * from_art(geom.hand + Vector2(float(geom.hand_r), 0))).distance_to(c), 0, TAU, 40, Color(1, 0.9, 0.2), 3.0)
	var by: Vector2 = geom.band_y
	var bd: Vector2 = geom.band_dx
	for sgn in [-1.0, 1.0]:
		var x0: float = float(geom.cx) + sgn * bd.x
		var x1: float = float(geom.cx) + sgn * bd.y
		var pts: = PackedVector2Array([inv * from_art(Vector2(x0, by.x)), inv * from_art(Vector2(x1, by.x)), inv * from_art(Vector2(x1, by.y)), inv * from_art(Vector2(x0, by.y)), inv * from_art(Vector2(x0, by.x))])
		draw_polyline(pts, Color(0.2, 0.9, 1), 3.0)
	var b: Rect2 = geom.body
	var bp: = PackedVector2Array([inv * from_art(b.position), inv * from_art(Vector2(b.end.x, b.position.y)), inv * from_art(b.end), inv * from_art(Vector2(b.position.x, b.end.y)), inv * from_art(b.position)])
	draw_polyline(bp, Color(0.6, 0.6, 0.6, 0.7), 2.0)
