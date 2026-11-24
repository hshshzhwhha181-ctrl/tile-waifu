class_name V10TutSelftest
extends Node
# Entry scene of the tutorial checks.
#   -- --tut_compile=1   load every script of the module (autoloads are present), print COMPILE ok/fail, quit
# (--tut_selftest=1, --tut_shots=<dir>, --tut_bot=1 are added by the test pass, see README §5)

const DIR: = "res://scripts/v10/tutorial/"


func _ready() -> void:
	var args: = OS.get_cmdline_user_args()
	if "--tut_compile=1" in args:
		_compile()
		return


func _compile() -> void:
	var bad: = 0
	var n: = 0
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd"):
			continue
		n += 1
		var s = load(DIR + f)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate():
			bad += 1
			print("COMPILE FAIL ", f)
	print("COMPILE %s %d/%d" % ["ok" if bad == 0 else "fail", n - bad, n])
	get_tree().quit(1 if bad else 0)
