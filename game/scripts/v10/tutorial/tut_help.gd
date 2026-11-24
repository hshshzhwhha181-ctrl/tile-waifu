class_name V10TutHelp
extends RefCounted
# SKELETON (API per README §2.5) — the implementation pass replaces the bodies.

const SCREEN_TOPIC: = {"home": "teahouse", "levels": "tables", "summon": "wishes", "collection": "heroines",
	"shop": "shop", "play": "play", "salon": "salon", "phone": "phone", "afisha": "today", "streak": "streak"}


static func topic_for_screen(screen_id: String) -> String:
	return String(SCREEN_TOPIC.get(screen_id, "play"))


static func open(host: Node, topic: String) -> Control:
	return null


static func open_how_to(host: Node) -> Control:
	return null


static func close_all(host: Node) -> void:
	pass


static func locked_toast(host: Node, at: Rect2, text: String) -> void:
	pass
