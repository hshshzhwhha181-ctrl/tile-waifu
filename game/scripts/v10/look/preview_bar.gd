class_name V10PreviewBar
extends Control

# V10PreviewBar — «Примерить стиль» from a banner (D1/D7): the whole kit is on (V10Look.preview), a plate under the
# header says «Примерка · Стиль Златы» with «Вернуть» and «К баннеру». No timer, no price, never writes S.look.
#
#   V10PreviewBar.open(parent, hero, outfit, on_banner, top = 120) -> V10PreviewBar

signal closed(to_banner: bool)

const H: = 80.0

var hero: = ""
var outfit: = ""


static func open(parent: Control, h: String, o: = "", on_banner: = Callable(), top: = 120.0) -> V10PreviewBar:
	var b: = V10PreviewBar.new()
	b.hero = h
	b.outfit = o
	V10Look.preview(h, o)
	V10HudSkin.sync(V10Look.current())
	var w: = minf(parent.size.x - 48.0, 672.0)
	b.position = Vector2((parent.size.x - w) * 0.5, top)
	b.size = Vector2(w, H)
	b.closed.connect(func(to_banner: bool):
		if to_banner and on_banner.is_valid():
			on_banner.call())
	parent.add_child(b)
	b._build()
	return b


func _build() -> void:
	add_child(V10HudSkin.nine("plate_m", size))
	var nm: = String(V10KitData.kit(hero).get("name", ""))
	var who: = V10ProfileCos.hero_name(hero)
	var cap: = V10HudSkin.label("Примерка", 15, V10HudSkin.tok("gold_500"))
	cap.uppercase = true
	cap.position = Vector2(24, 12)
	cap.size = Vector2(200, 20)
	add_child(cap)
	var t: = V10HudSkin.label("Стиль: %s" % (nm if nm != "" else who), 22, V10HudSkin.tok("paper_100"))
	t.position = Vector2(24, 34)
	t.size = Vector2(size.x - 24 - 300, 32)
	add_child(t)
	var back: = V10HudSkin.button("secondary", "Вернуть", Rect2(size.x - 296, 8, 140, 64), func(): _close(false))
	add_child(back)
	var ban: = V10HudSkin.button("secondary", "К баннеру", Rect2(size.x - 152, 8, 140, 64), func(): _close(true))
	add_child(ban)


func _close(to_banner: bool) -> void:
	V10Look.end_preview()
	V10HudSkin.sync(V10Look.current())
	closed.emit(to_banner)
	queue_free()
