extends TWScreen

# Test double for Brief A audit (A-06c): opens a TWModal from exit() to verify that
# TWScreens.go() does not let a modal spawned during outgoing teardown survive onto the new screen.


func exit() -> void:
	var stack = ctx.service("modals") if ctx != null else null
	if stack is ModalStack:
		var m: = TWModal.new()
		m.name = "LeakedFromExit"
		(stack as ModalStack).open(m)
