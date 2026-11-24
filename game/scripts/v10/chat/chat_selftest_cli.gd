extends SceneTree

# Standalone runner for the chat selftest (no main.gd edits needed):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game -s res://scripts/v10/chat/chat_selftest_cli.gd
# Prints «CHAT SELFTEST ok/total», exit code 0 when all pass.

func _initialize() -> void:
	var r: Array = preload("res://scripts/v10/chat/chat_selftest.gd").run()
	quit(0 if r[0] == r[1] else 1)
