class_name V10GuestScene
extends Control

# V10GuestScene — «Ты больше не гость» (spec Г4): after the 50th wish of «Первый гость». Маджонг-тян at the salon
# door (key art guest_door), her line written by pen (UX_RULES §6.3 voice, no bubble), the frame and title
# «Свой за столом» granted through V10ProfileCos when it exists, then the hanko. A tap anywhere moves on
# (skippable from the first second).

const LINES: = ["Ты больше не гость.", "Теперь у этого стола есть твоё место. Садись — я налью чай."]

var main
var W: = 720.0
var H: = 1280.0
var done: = false
var step: = 0


static func open(parent: Control, m) -> V10GuestScene:
	var s: = V10GuestScene.new()
	s.size = parent.get_viewport_rect().size
	s.main = m
	var host: Control = m.overlay if m != null and "overlay" in m and m.overlay != null else parent
	host.add_child(s)
	s._build()
	return s


static func grant_cos(S: Dictionary, id: String) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "V10ProfileCos":
			var scr: Script = load(String(c.path))
			return bool(scr.call("grant", S, id))
	# before the profile lane is merged: keep the grant in the save, the registry picks it up (README hook H7)
	if not (S.get("v10_cos_owned") is Dictionary):
		S["v10_cos_owned"] = {}
	S.v10_cos_owned[id] = true
	return true


func _build() -> void:
	W = size.x
	H = size.y
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base: = ColorRect.new()
	base.size = size
	base.color = V10GUI.NIGHT_900
	add_child(base)
	# her face sits below the top bar (UX_RULES §2.2): the art starts at y = 120
	var art: = V10GUI.cover(V10GUI.tex_or_null("res://assets/v10/gacha/guest_door.webp"), Rect2(Vector2(0, 120), Vector2(W, H - 120)), Vector2(0.5, 0.1))
	add_child(art)
	var img: Control = art.get_node_or_null("Img")
	if img:
		img.pivot_offset = img.size * Vector2(0.5, 0.3)
		img.scale = Vector2(1.08, 1.08)
		img.create_tween().tween_property(img, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	art.modulate.a = 0.0
	art.create_tween().tween_property(art, "modulate:a", 1.0, 0.8)
	add_child(V10GUI.shade(Rect2(0, H * 0.52, W, H * 0.48), Color(V10GUI.NIGHT_900, 0.0), Color(V10GUI.NIGHT_900, 0.94), true))
	Fx.ambient(self, "petals", size)
	var y: = H * 0.7
	for i in LINES.size():
		var l: = V10GUI.lbl(LINES[i], 40 if i == 0 else 26, V10GUI.PAPER_100 if i == 0 else V10GUI.PAPER_300, "title", 700 if i == 0 else 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(W - 80, 10)
		l.position = Vector2(40, y)
		V10GUI.shadowed(l, 0.9)
		add_child(l)
		l.visible_ratio = 0.0
		var t: = l.create_tween()
		t.tween_interval(0.9 + i * 1.1)
		t.tween_property(l, "visible_ratio", 1.0, 0.4 + 0.02 * LINES[i].length())
		y += 64 if i == 0 else 90
	grant_cos(G.S, "fr_own")
	grant_cos(G.S, "t_own")
	var chip: = V10GUI.chip("Рамка и титул «Свой за столом»", null, 48, V10GUI.GOLD_300)
	chip.position = Vector2(40, y + 10)
	add_child(chip)
	chip.modulate.a = 0.0
	var ct: = chip.create_tween()
	ct.tween_interval(3.0)
	ct.tween_property(chip, "modulate:a", 1.0, 0.3)
	ct.tween_callback(func():
		Sfx.play("win", 1.0, -6.0)
		V10GUI.hanko(self, Vector2(W - 96, chip.position.y + 24), "СВОЙ", 112, -8.0))
	var tap: = V10GUI.lbl("Коснись, чтобы продолжить", 18, V10GUI.PAPER_500, "body", 700)
	UI.center_label(tap, Rect2(0, H - 70, W, 30))
	add_child(tap)
	var tt: = tap.create_tween().set_loops()
	tt.tween_property(tap, "modulate:a", 0.35, 0.8)
	tt.tween_property(tap, "modulate:a", 1.0, 0.8)
	Sfx.say("mc", "ssr")
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())


func close() -> void:
	if done:
		return
	done = true
	G.save()
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
