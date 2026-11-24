class_name V10AuthProviders
extends RefCounted

# Concrete providers. Only Guest works fully; the rest are polite stubs until the Gradle plugins / server land
# (CEO_PLAN №19–21: VK ID и Яндекс ID в 1.0, Google только в международной сборке).
#   V10AuthProviders.make("vkid") -> V10AuthProvider


static func make(id: String) -> V10AuthProvider:
	match id:
		"guest":
			return Guest.new()
		"vkid":
			return VKID.new()
		"yandex":
			return YandexID.new()
		"google":
			return Google.new()
		"yagames":
			return YandexGames.new()
		"email":
			return Email.new()
	push_warning("V10AuthProviders.make: unknown provider '%s'" % id)
	return null


# Guest: local only. The account «sub» is the install id; the player id itself is minted by V10Auth.
class Guest extends V10AuthProvider:
	func _init() -> void :
		id = "guest"
		needs_consent = false

	func available() -> bool:
		return true

	func sign_in(_ctx: = {}) -> Dictionary:
		await V10AuthProvider._wait(0.0)
		return V10AuthProvider.ok({"sub": "dev:" + V10Auth.install_id(), "name": ""}, V10Auth.random_hex(16))

	func restore(_sess: Dictionary) -> Dictionary:
		await V10AuthProvider._wait(0.0)
		return V10AuthProvider.ok({"sub": "dev:" + V10Auth.install_id(), "name": ""}, V10Auth.random_hex(16))


# VK ID (RuStore build). Real flow: VK ID Android SDK OneTap → authorization code + PKCE → our server exchanges it
# and returns a session token. The SDK cannot run without a Gradle plugin, so this answers not_available_yet.
class VKID extends V10AuthProvider:
	func _init() -> void :
		id = "vkid"


# Yandex ID (RuStore build). Real flow: Yandex LoginSDK (authorization code) → server.
class YandexID extends V10AuthProvider:
	func _init() -> void :
		id = "yandex"


# Google (Google Play / international build only; КоАП 13.55 — not in the RU build). Real flow: Credential
# Manager «Sign in with Google» → ID token → server.
class Google extends V10AuthProvider:
	func _init() -> void :
		id = "google"


# Yandex Games (web build): the platform signs the player in itself. Real flow (JavaScriptBridge):
#   ysdk.getPlayer({scopes: false}) → player.getUniqueID(), player.getName(), player.isAuthorized();
#   progress → player.setData()/getData(). Until wired, the web build plays as a guest silently.
class YandexGames extends V10AuthProvider:
	func _init() -> void :
		id = "yagames"
		needs_consent = false

	# true once the JS bridge above is wired (web export + ysdk loaded); until then the stub answers not_available_yet
	func available() -> bool:
		return false


# Own account by e-mail + one-time code (UI only; needs the server). request_code / verify answer not_available_yet.
class Email extends V10AuthProvider:
	func _init() -> void :
		id = "email"

	func request_code(_email: String) -> Dictionary:
		await V10AuthProvider._wait(V10AuthProvider.stub_delay)
		return V10AuthProvider.fail("not_available_yet")

	func verify(_email: String, _code: String) -> Dictionary:
		await V10AuthProvider._wait(V10AuthProvider.stub_delay)
		return V10AuthProvider.fail("not_available_yet")


static func valid_email(e: String) -> bool:
	var s: = e.strip_edges()
	if s.length() < 6 or s.length() > 120 or " " in s:
		return false
	var at: = s.find("@")
	if at < 1 or at != s.rfind("@"):
		return false
	var dom: = s.substr(at + 1)
	var dot: = dom.rfind(".")
	return dot > 0 and dot < dom.length() - 2
