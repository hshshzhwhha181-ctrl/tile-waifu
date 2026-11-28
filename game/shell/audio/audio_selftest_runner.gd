extends Node

# Runner of the P30 audio selftest:
#   godot --headless --audio-driver Dummy --path game res://shell/audio/audio_selftest.tscn   -> "TWAUDIO_SELFTEST ok/total"


func _ready() -> void:
	await get_tree().process_frame
	var t: = TWAudioSelftest.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
