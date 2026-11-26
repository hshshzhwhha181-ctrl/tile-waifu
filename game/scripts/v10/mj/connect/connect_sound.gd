class_name V10MjConnectSound
extends Node

# Звук Связей (MODES §4.3 «Стол и звук»): нить по героине (шёлк, звон, свист, хор, синт-свип из V10MjAsmr.thread)
# и «клак» пары по материалу, с ростом высоты в серии.

var hero: = "rin"
var material: = "porcelain"
var mute: = false
var log: Array = []


func pick() -> void:
	log.append("pick")
	if mute:
		return
	var asmr = V10MjAsmr.inst()
	if asmr:
		asmr.play_key("pick")
	else:
		V9Feel.tile_tap(true)
	V10MjHaptics.play("tap")


func thread_pair(combo: int) -> void:
	log.append("thread:%d" % combo)
	if mute:
		return
	var th: = V10MjConnectLook.thread_for(hero)
	var asmr = V10MjAsmr.inst()
	if asmr:
		V10MjAsmr.thread(int(th.get("sfx", 1)) - 1)
		V10MjAsmr.pair(material, combo)
	else:
		V9Feel.tile_match(combo)
	V10MjHaptics.combo(combo)


func deny() -> void:
	log.append("deny")
	if mute:
		return
	V9Feel.sound("deny", 0.95, -8.0)


func win() -> void:
	log.append("win")
	if mute:
		return
	V9Feel.sound("sparkle", 1.1, -4.0)
	V10MjHaptics.play("win")
