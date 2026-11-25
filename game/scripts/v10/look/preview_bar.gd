class_name V10PreviewBar
extends Control

# V10PreviewBar — «Примерить стиль» from a banner (D1/D7): the whole kit is on (V10Look.preview), a plate under the
# header says «Примерка · Стиль Златы» with «Вернуть» and «К баннеру». No timer, no price, never writes S.look.
# The try-on ends with the bar: if the screen under it is torn down another way (tab switch, back gesture), the bar
# leaving the tree still ends the preview, so the player's own kit never stays replaced by a try-on.
# Both buttons are secondary with an 80 px hit zone (UX §6.1).
#
#   V10PreviewBar.open(parent, hero, outfit, on_banner, top = 120) -> V10PreviewBar

signal closed(to_banner: bool)

const H: = 96.0
const BTN: = Vector2(148, 80)

var hero: = ""
var outfit: = ""
var _open: = false


static func open(parent: Control, h: String, o: = "", on_banner: = Callable(), top: = 120.0) -> V10PreviewBar:
	var b: = V10PreviewBar.new()
	b.hero = h
	b.outfit = o
	b._open = true
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
	cap.position = Vector2(24, 18)
	cap.size = Vector2(200, 20)
	add_child(cap)
	var t: = V10HudSkin.label("Стиль: %s" % (nm if nm != "" else who), 22, V10HudSkin.tok("paper_100"))
	t.position = Vector2(24, 42)
	t.size = Vector2(size.x - 24 - (BTN.x * 2 + 24), 32)
	add_child(t)
	var y: = (H - BTN.y) * 0.5
	var back: = V10HudSkin.button("secondary", "Вернуть", Rect2(Vector2(size.x - BTN.x * 2 - 12, y), BTN), func(): _close(false))
	back.name = "Back"
	add_child(back)
	var ban: = V10HudSkin.button("secondary", "К баннеру", Rect2(Vector2(size.x - BTN.x - 4, y), BTN), func(): _close(true))
	ban.name = "ToBanner"
	add_child(ban)


func _end() -> void:
	if not _open:
		return
	_open = false
	V10Look.end_preview()
	V10HudSkin.sync(V10Look.current())


func _close(to_banner: bool) -> void:
	_end()
	closed.emit(to_banner)
	queue_free()


func _exit_tree() -> void:
	_end()
