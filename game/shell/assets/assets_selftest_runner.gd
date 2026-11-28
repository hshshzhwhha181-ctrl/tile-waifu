extends Node

# Runner of the TWAssets selftest (P29):
#   godot --headless --path game res://shell/assets/assets_selftest.tscn
# Prints "TWASSETS_SELFTEST ok/total"; exit code 0 when all pass.


func _ready() -> void:
	await get_tree().process_frame
	var t: TWAssetsSelftest = TWAssetsSelftest.new()
	var r: Array = t.run()
	get_tree().quit(0 if r[0] == r[1] else 1)
