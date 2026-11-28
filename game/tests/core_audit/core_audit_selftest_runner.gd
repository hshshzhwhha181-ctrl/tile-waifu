extends Control

# Runner for Brief A independent core/shell audit selftest:
#   godot --headless --audio-driver Dummy --path game res://tests/core_audit/core_audit_selftest.tscn
# Prints "CORE_AUDIT_SELFTEST ok/total"; exit code 0 when all pass.


const AuditSuite = preload("res://tests/core_audit/core_audit_selftest.gd")


func _ready() -> void:
	await get_tree().process_frame
	var t: = AuditSuite.new()
	var r: Array = await t.run(self)
	get_tree().quit(0 if r[0] == r[1] else 1)
