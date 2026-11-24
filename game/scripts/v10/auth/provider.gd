class_name V10AuthProvider
extends RefCounted

# AuthProvider interface (docs: scripts/v10/auth/README.md). One instance per sign-in method.
#
#   id            "guest" | "vkid" | "yandex" | "google" | "yagames" | "email"
#   needs_consent true when signing in sends personal data off the device (152-ФЗ checkbox on the login screen)
#   available()   can this build/platform run the real flow now? Stubs return false.
#   await sign_in(ctx)   -> result Dictionary (below). ctx: {"silent": bool} (silent = auto sign-in, no UI)
#   await restore(sess)  -> result: refresh a stored session on launch (sess = the session file dictionary)
#   await link(ctx)      -> result: attach this method to the current player (keeps progress)
#   sign_out()           forget provider-side tokens (SDK logout)
#
# Result: {"ok": bool, "code": String, "account": {"sub": String, "name": String, "birthdate": String?},
#          "token": String?, "expires_in": int?}
# Codes: "ok", "not_available_yet" (SDK/server not wired yet), "cancelled", "network", "expired", "consent_required".
# Real SDKs (Gradle plugins VK ID / Yandex ID / Google Credential Manager, Yandex Games JS SDK) plug in by
# overriding these methods in the concrete provider: nothing else in the game changes.

var id: = ""
var needs_consent: = true

# stub latency (seconds): a «Подключаемся…» beat so the button press reads; 0 in the selftest
static var stub_delay: = 0.55


func available() -> bool:
	return false


func title() -> String:
	return V10AuthText.provider_name(id)


func sign_in(_ctx: = {}) -> Dictionary:
	await _wait(stub_delay)
	return fail("not_available_yet")


func restore(_sess: Dictionary) -> Dictionary:
	await _wait(0.0)
	return fail("not_available_yet")


func link(ctx: = {}) -> Dictionary:
	return await sign_in(ctx)


func sign_out() -> void :
	pass


static func ok(account: Dictionary, token: = "", expires_in: = 0) -> Dictionary:
	return {"ok": true, "code": "ok", "account": account, "token": token, "expires_in": expires_in}


static func fail(code: String) -> Dictionary:
	return {"ok": false, "code": code, "account": {}}


static func _wait(sec: float) -> void :
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if sec <= 0.0:
		await tree.process_frame
	else:
		await tree.create_timer(sec).timeout
