extends Node

# Standalone runner (main.gd untouched):
#   godot --headless --path game res://scripts/v10/fonts/fonts_runner.tscn -- --fonts_selftest=1
#   xvfb-run -a godot --path game res://scripts/v10/fonts/fonts_runner.tscn -- --fonts_preview=/abs/out.png
# The preview needs a real renderer (xvfb), headless renders nothing.

const F: = preload("res://scripts/v10/fonts/fonts.gd")
const T: = preload("res://scripts/v10/fonts/fonts_selftest.gd")

const W: = 720
const BG: = Color("1d1726")
const INK: = Color("f5ead8")
const MUTED: = Color("a39a92")
const PANGRAM: = "Съешь же ещё этих мягких французских булок, да выпей чаю"
const DIGITS: = "0123456789 · №7 · 164 ₽ · «Ёлка» — ура…"

# id -> [sample line, accent colour (ROSTER palette, lifted for a dark table)]
const ROWS: = [
	["ui_body", "Шансы и правила · Лавка · 2 желания", "f5ead8"],
	["ui_display", "Карточка игрока", "e8c47e"],
	["ui_display_italic", "Мастерство наряда", "e3a3b2"],
	["hand", "Жду тебя вечером у чайного столика", "f5ead8"],
	["palm", "Линия сердца: долгая и тёплая", "d9c7a8"],
	["zlata_title", "Весна пришла!", "e8b23a"],
	["zlata_text", "Пепел — только начало", "f0a070"],
	["minamo_title", "Жемчужный дворец", "7fd3d0"],
	["minamo_text", "Приливы шепчут твоё имя", "f3e9f1"],
	["kira_title", "Хризантема на взлёте", "ff5a5e"],
	["kira_text", "Тактический симулятор: раунд 3", "f2f2f5"],
	["vesper_title", "Алая ночь", "e0475a"],
	["vesper_text", "Гранатовый чай остывает…", "c9c3cf"],
	["sigrid_title", "Северное сияние", "7fc8d8"],
	["sigrid_text", "Иней на ресницах", "b9b1f0"],
	["yue_title", "Любопытно…", "c8b6ff"],
	["nova_title", "Скачано.", "4fe3ff"],
]


func _ready() -> void:
	var args: = {}
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	await get_tree().process_frame
	if args.has("fonts_selftest"):
		var fails: = T.run()
		get_tree().quit(1 if fails > 0 else 0)
		return
	if args.has("fonts_preview"):
		await _preview(str(args.fonts_preview))
		get_tree().quit(0)
		return
	print("fonts_runner: pass --fonts_selftest=1 or --fonts_preview=/abs/path.png")
	get_tree().quit(0)


func _lab(text: String, f: Font, size: int, col: Color, w: float) -> Label:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	ls.font = f
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.size.x = w
	return l


func _preview(out: String) -> void:
	var vp: = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(W, 200)
	add_child(vp)
	var bg: = ColorRect.new()
	bg.color = BG
	vp.add_child(bg)
	var box: = VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.add_theme_constant_override("separation", 4)
	vp.add_child(box)
	var cw: = W - 40.0
	box.add_child(_lab("V10Fonts · превью кириллицы (%d шрифтов)" % ROWS.size(), F.font("ui_body", 900), 22, MUTED, cw))
	for r in ROWS:
		var id: String = r[0]
		var d: = F.info(id)
		var sep: = ColorRect.new()
		sep.color = Color(1, 1, 1, 0.08)
		sep.custom_minimum_size = Vector2(cw, 1)
		box.add_child(sep)
		var head: = "%s · %s%s · %s" % [id, d.name, " (RFN, без subset)" if d.rfn and str(d.file).begins_with(F.DIR) else "", d.who if d.who != "" else "UI"]
		box.add_child(_lab(head, F.font("ui_body", 800), 17, MUTED, cw))
		var f: = F.font(id)
		box.add_child(_lab(r[1], f, F.px(id, 44), Color(r[2]), cw))
		box.add_child(_lab(PANGRAM, f, F.px(id, 26), INK, cw))
		box.add_child(_lab(DIGITS, f, F.px(id, 26), INK.darkened(0.08), cw))
	await get_tree().process_frame
	await get_tree().process_frame
	var h: = int(box.get_combined_minimum_size().y + 40.0)
	vp.size = Vector2i(W, h)
	bg.size = Vector2(W, h)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img: = vp.get_texture().get_image()
	var e: = img.save_png(out)
	print("fonts_preview: %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), e])
