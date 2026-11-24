class_name V10AuthSelftest
extends RefCounted

# --auth_selftest=1 (scene res://scripts/v10/auth/auth_dev.tscn). Runs on its own save and its own auth dir:
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/auth/auth_dev.tscn -- \
#     --auth_selftest=1 --save=user://auth_selftest_save.json --save_wipe=1
# Prints AUTH_SELFTEST ok/total; returns [ok, total].
# Covers: first run → guest → relaunch auto-login → logout → login again; provider stubs; consent; corrupted /
# tampered / missing / expired / foreign sessions; 0.9 save migration; account deletion; nick ideas; lint; UI smoke.

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена", "бесплатн"]

static var ok: = 0
static var total: = 0
static var fails: = []


static func check(cond: bool, what: String) -> void :
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		printerr("AUTH FAIL: " + what)


static func _relaunch() -> void :
	# what a cold start does: reload the save from disk, forget every in-memory cache
	V10Auth._install = ""
	V10Auth._providers = {}
	V10Auth.last_boot = {}
	G.load_game()


static func _wipe_root() -> void :
	var da: = DirAccess.open(V10Auth.root)
	if da:
		for f in da.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(V10Auth.root + f))


static func _write_raw(path: String, txt: String) -> void :
	var f: = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()


static func run(host: Control) -> Array:
	ok = 0
	total = 0
	fails = []
	var tree: = host.get_tree()
	V10Auth.set_root("user://auth_test/")
	_wipe_root()
	V10AuthProvider.stub_delay = 0.0
	V10Auth.now_override = 1800000000
	V10Auth.flavor_override = "rustore"
	G.S = G.default_state()
	G.save()

	# ── 1. save record ──
	var st: = V10Auth.ensure()
	var snap: = JSON.stringify(st)
	V10Auth.ensure()
	check(JSON.stringify(V10Auth.state()) == snap, "ensure is idempotent")
	G.S.v10_auth.linked = "broken"
	G.S.v10_auth.created_at = 1.5e9
	G.S.v10_auth.player_id = "nope"
	V10Auth.ensure()
	check(G.S.v10_auth.linked is Dictionary and G.S.v10_auth.created_at is int and int(G.S.v10_auth.created_at) == 1500000000, "ensure repairs types")
	check(str(G.S.v10_auth.player_id) == "", "ensure drops an invalid player id")
	G.S.v10_auth.created_at = 0
	for k in ["player_id", "provider", "linked", "created_at", "last_login"]:
		check(V10Auth.state().has(k), "record has " + k)

	# ── 2. flavors ──
	check(V10Auth.login_buttons("rustore") == ["vkid", "yandex"], "rustore buttons")
	check(V10Auth.login_buttons("gplay") == ["google"], "gplay buttons")
	check(V10Auth.login_buttons("yagames").is_empty(), "yagames: no buttons")
	V10Auth.flavor_override = "yagames"
	check(not V10Auth.needs_login(), "yagames never shows the login screen")
	V10Auth.flavor_override = "rustore"

	# ── 3. first run → guest ──
	check(V10Auth.needs_login(), "fresh install shows the login screen")
	var r: = V10Auth.sign_in_guest()
	var pid: = V10Auth.player_id()
	check(bool(r.ok) and V10Auth.valid_player_id(pid), "guest sign-in mints a valid id: " + pid)
	check(V10Auth.current_provider() == "guest" and V10Auth.is_guest(), "provider guest")
	var sess: = V10Auth.read_session()
	check(not sess.is_empty() and not sess.has("_corrupt") and str(sess.player_id) == pid, "session written and valid")
	check(not V10Auth.needs_login(), "after guest sign-in no login screen")
	check(int(V10Auth.state().created_at) == 1800000000 and int(V10Auth.state().login_count) == 1, "created_at / login_count")
	G.set_profile("Лунный веер", "yue", true)
	G.S.gems = 1234
	G.save()

	# ── 4. relaunch → auto sign-in ──
	V10Auth.now_override += V10Auth.DAY
	_relaunch()
	check(not V10Auth.needs_login(), "relaunch: no login screen")
	var b: Dictionary = await V10Auth.restore()
	check(str(b.status) == "ok" and str(b.provider) == "guest", "relaunch restores silently: " + str(b))
	check(V10Auth.player_id() == pid and int(G.S.gems) == 1234, "same player, progress kept")
	check(int(V10Auth.state().login_count) == 2 and int(V10Auth.state().last_login) == V10Auth.now_override, "login_count / last_login")
	var wt: = V10Auth.welcome_text()
	check("Лунный веер" in wt and V10Auth.greet_hero() == "yue", "welcome names the player, from her avatar heroine: " + wt)
	var exp1: = int(V10Auth.read_session().expires_at)
	check(exp1 == V10Auth.now_override + V10Auth.GUEST_DAYS * V10Auth.DAY, "guest session slides forward")

	# ── 5. logout → login again ──
	V10Auth.sign_out()
	check(V10Auth.read_session().is_empty() and bool(V10Auth.state().logged_out), "logout drops the session")
	_relaunch()
	check(V10Auth.needs_login(), "after logout the login screen shows")
	check(int(G.S.gems) == 1234 and G.nick() == "Лунный веер", "logout keeps the progress")
	V10Auth.sign_in_guest()
	check(V10Auth.player_id() == pid and not bool(V10Auth.state().logged_out), "guest again = same player")
	check(int(V10Auth.state().login_count) == 3, "login counted")

	# ── 6. provider stubs ──
	V10Auth.set_consent(false)
	r = await V10Auth.sign_in("vkid")
	check(str(r.code) == "consent_required", "VK ID needs the 152-ФЗ consent")
	V10Auth.set_consent(true)
	check(V10Auth.has_consent() and str(V10Auth.state().consent.doc) == V10Auth.DOC_VER, "consent stored with doc version")
	for id in ["vkid", "yandex", "google", "yagames"]:
		r = await V10Auth.sign_in(id)
		check(not bool(r.ok) and str(r.code) == "not_available_yet", id + " stub answers not_available_yet")
		check(V10Auth.current_provider() == "guest" and V10Auth.player_id() == pid and int(G.S.gems) == 1234, id + " stub keeps the guest progress")
	r = await V10Auth.link("vkid")
	check(not bool(r.ok) and V10Auth.state().linked.is_empty(), "link stub links nothing")
	r = await V10Auth.provider("email").request_code("a@b.ru")
	check(str(r.code) == "not_available_yet", "email stub")
	check(V10AuthProviders.valid_email("player@mail.ru") and not V10AuthProviders.valid_email("player@mail") and not V10AuthProviders.valid_email("a b@c.ru") and not V10AuthProviders.valid_email("@x.ru"), "email validation")
	check(V10Auth.provider("guest").available() and not V10Auth.provider("vkid").available(), "availability flags")

	# ── 7. corrupted / tampered / missing / foreign session ──
	_write_raw(V10Auth.root + "v10_session.json", "{not json")
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "recovered" and V10Auth.player_id() == pid and int(G.S.gems) == 1234, "corrupted session → recovered: " + str(b))
	check(not V10Auth.read_session().has("_corrupt"), "a fresh session replaces the corrupted one")
	var s2: = V10Auth.read_session()
	s2.expires_at = int(s2.expires_at) + 999999
	_write_raw(V10Auth.root + "v10_session.json", JSON.stringify(s2))
	check(V10Auth.read_session().has("_corrupt"), "tampered session detected")
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "recovered" and V10Auth.player_id() == pid, "tampered session → recovered")
	V10Auth.clear_session()
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "recovered" and V10Auth.player_id() == pid, "missing session → recovered")
	V10Auth.write_session(V10Auth.new_player_id(), "guest", "x", 10)
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "recovered" and V10Auth.player_id() == pid, "foreign session: the save's player wins")
	V10Auth._install = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(V10Auth.root + "v10_device.json"))
	check(V10Auth.read_session().has("_corrupt"), "session from another install is rejected")
	b = await V10Auth.restore()
	check(str(b.status) == "recovered" and V10Auth.player_id() == pid, "other install → recovered, same player")

	# ── 8. provider session (simulated future success) ──
	V10Auth._apply_account("vkid", V10AuthProvider.ok({"sub": "vk:42", "name": "Тест"}, "tok"))
	check(V10Auth.current_provider() == "vkid" and V10Auth.state().linked.has("vkid") and V10Auth.player_id() == pid, "a provider account links to the same player")
	V10Auth.now_override += 5 * V10Auth.DAY
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "ok" and str(b.provider) == "vkid", "offline grace: unexpired provider session stays")
	V10Auth.now_override += 40 * V10Auth.DAY
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "fallback" and str(b.provider) == "guest" and "VK ID" in str(b.toast), "expired provider session → guest + toast: " + str(b))
	check(V10Auth.state().linked.has("vkid") and V10Auth.player_id() == pid and int(G.S.gems) == 1234, "fallback keeps progress and the link")
	V10Auth._apply_account("yandex", V10AuthProvider.ok({"sub": "ya:7"}))
	V10Auth.clear_session()
	_relaunch()
	b = await V10Auth.restore()
	check(str(b.status) == "fallback" and "Яндекс ID" in str(b.toast), "provider session lost → guest with a toast")
	V10Auth._apply_account("vkid", V10AuthProvider.ok({"sub": "vk:42"}))
	V10Auth.set_consent(false)
	check(V10Auth.is_guest() and V10Auth.state().linked.is_empty() and V10Auth.player_id() == pid, "withdrawn consent → guest, accounts unlinked")
	V10Auth.set_consent(true)
	# a guest who kept a link after an expired provider session: withdrawing consent still removes it
	V10Auth._apply_account("vkid", V10AuthProvider.ok({"sub": "vk:42", "name": "Тест"}, "tok"))
	V10Auth.now_override += 40 * V10Auth.DAY
	_relaunch()
	b = await V10Auth.restore()
	check(V10Auth.is_guest() and V10Auth.state().linked.has("vkid"), "expired provider: guest keeps the link")
	V10Auth.set_consent(false)
	check(V10Auth.is_guest() and V10Auth.state().linked.is_empty() and int(G.S.gems) == 1234, "withdrawn consent as a guest also unlinks, progress kept")
	V10Auth.set_consent(true)

	# ── 9. 0.9 save migration ──
	var keep_pid: = pid
	G.S = G.default_state()
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.unlocked = 12
	G.S.profile.nick = "Старожил"
	G.S.erase("v10_auth")
	V10Auth.clear_session()
	G.save()
	_relaunch()
	check(not V10Auth.needs_login(), "0.9 player: no login screen")
	b = await V10Auth.restore()
	check(str(b.status) == "migrated" and str(V10Auth.state().migrated_from) == "0.9" and V10Auth.valid_player_id(V10Auth.player_id()), "0.9 save migrated to a guest account")
	check(int(G.S.unlocked) == 12, "migration keeps progress")
	check(V10Auth.player_id() != keep_pid, "migration mints its own id")
	pid = V10Auth.player_id()

	# ── 10. account deletion ──
	G.S.gems = 999
	G.save()
	G.save()
	var bak: = G.save_path.get_basename() + ".bak.json"
	var dev0: = V10Auth.install_id()
	V10Auth._apply_account("vkid", V10AuthProvider.ok({"sub": "vk:9", "name": "Имя Фамилия"}, "tok"))
	var pre: = V10Auth.pre_import_path()
	_write_raw(pre, JSON.stringify(G.S))
	var del: = V10Auth.request_deletion()
	check(bool(del.ok) and str(del.player_id) == pid, "deletion accepted")
	check(int(G.S.gems) != 999 and not bool(G.S.profile_done) and int(G.S.unlocked) == 1, "deletion wipes local progress")
	check(V10Auth.read_session().is_empty() and V10Auth.needs_login(), "deletion → login screen")
	check(not FileAccess.file_exists(bak), "deletion removes the save backup")
	var ob: = V10Auth.outbox()
	check(ob.size() == 1 and str(ob[0].player_id) == pid and str(ob[0].type) == "delete_account", "deletion request queued for the server")
	check(not FileAccess.file_exists(pre), "deletion removes the 0.8 pre-import save copy")
	check(str(ob[0].get("linked", {}).get("vkid", "")) == "vk:9" and not ("Имя Фамилия" in JSON.stringify(ob)), "deletion request keeps ids only, no names")
	check(V10Auth.install_id() != dev0, "install id rotated")
	_relaunch()
	check(int(G.S.gems) != 999 and str(V10Auth.state().deletion.get("player_id", "")) == pid, "deletion survives a relaunch")

	# ── 11. ids, nicks, lint ──
	var seen: = {}
	var all_ok: = true
	for i in 300:
		var x: = V10Auth.new_player_id()
		all_ok = all_ok and V10Auth.valid_player_id(x) and not seen.has(x)
		seen[x] = true
	check(all_ok, "300 player ids valid and unique")
	var nick_ok: = true
	for h in V10AuthNicks.IDEAS:
		check(G.HEROES.has(h), "nick ideas hero " + h)
		for n in V10AuthNicks.IDEAS[h]:
			if G.nick_error(n) != "":
				nick_ok = false
				printerr("bad nick idea: ", n, " ", G.nick_error(n))
	check(nick_ok, "every nick idea passes G.nick_error")
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	var sug: = V10AuthNicks.suggest(5, rng)
	var hs: = {}
	for s in sug:
		hs[s.hero] = true
	check(sug.size() == 5 and hs.size() == 5, "5 ideas, one per founder")
	var lint_ok: = true
	var texts: Array = V10AuthText.T.values()
	for h in V10AuthText.GREET:
		texts.append_array(V10AuthText.GREET[h])
	for t in texts:
		for w in BANNED:
			if w in String(t).to_lower():
				lint_ok = false
				printerr("lint: '%s' in «%s»" % [w, t])
	check(lint_ok, "no V10Lint stop-words in auth texts")
	check(V10AuthText.GREET.size() == 5, "greetings for all five founders")

	# ── 12. age gate hook ──
	var gate: = GDScript.new()
	gate.source_code = "extends RefCounted\nstatic var hit := 0\nstatic func ensure(_host) -> void:\n\thit += 1\n"
	gate.reload()
	V10Auth.age_gate_override = gate
	await V10Auth.age_gate(host)
	check(int(gate.get("hit")) == 1, "V10AgeGate.ensure is called when present")
	V10Auth.age_gate_override = null
	await V10Auth.age_gate(host)
	check(true, "no V10AgeGate: no-op")

	# ── 13. UI smoke ──
	G.S = G.default_state()
	G.save()
	V10Auth.clear_session()
	for fl in ["rustore", "gplay", "dev"]:
		V10Auth.flavor_override = fl
		var ls: = V10LoginScreen.make(host, null)
		await tree.process_frame
		var want: Array = V10Auth.login_buttons(fl)
		check(ls.prov_btns.size() == want.size() and ls.guest_btn != null, fl + " login screen buttons")
		check(ls.find_child("Logo", true, false) != null and ls.art.heroes.texture != null and ls.art.bg.texture != null, fl + " key art + logo")
		ls.queue_free()
		await tree.process_frame
	V10Auth.flavor_override = "rustore"
	V10Auth.set_consent(false)
	var lsc: = V10LoginScreen.make(host, null)
	await tree.process_frame
	lsc.prov_btns.vkid.activate()
	await tree.create_timer(0.3).timeout
	check(lsc.find_child("V10AuthToast", true, false) != null and V10Auth.read_session().is_empty(), "provider tap without consent: toast, no sign-in")
	lsc.consent.set_on(true, false)
	lsc.consent.toggled.emit(true)
	check(V10Auth.has_consent(), "consent tick stores consent")
	lsc.prov_btns.yandex.activate()
	await tree.create_timer(0.4).timeout
	check(V10Auth.read_session().is_empty() and not lsc._done, "stub provider keeps the login screen")
	var res: = [null]
	lsc.finished.connect(func(x): res[0] = x)
	lsc.guest_btn.activate()
	await tree.create_timer(0.4).timeout
	var ns: = lsc.find_child("V10NickSheet", true, false)
	check(ns != null, "guest on a fresh save opens the name picker")
	if ns:
		check(ns.chips.size() == 5, "five heroine ideas")
		ns.dev_submit("Подсолнух", "hana")
	for i in 40:
		if res[0] != null:
			break
		await tree.create_timer(0.1).timeout
	check(res[0] != null and str(res[0].provider) == "guest" and bool(res[0].new_player), "login finished as a new guest: " + str(res[0]))
	check(G.nick() == "Подсолнух" and str(G.profile().avatar) == "hana" and bool(G.S.profile_done), "picked nick + heroine avatar saved")
	var acc: = V10AccountSheet.open(host)
	await tree.process_frame
	check(acc.find_child("IdBox", true, false) != null and acc.link_btns.size() == 2, "account sheet: id + link buttons")
	var lo: = [false]
	acc.logged_out.connect(func(): lo[0] = true)
	acc._ask_logout()
	await tree.process_frame
	var yes: = acc.find_child("Btn_logout_yes", true, false) as JButton
	check(yes != null, "logout confirm")
	if yes:
		yes.activate()
	await tree.create_timer(0.6).timeout
	check(lo[0] and V10Auth.needs_login(), "logout from the sheet")
	V10Auth.sign_in_guest()
	var acc2: = V10AccountSheet.open(host)
	await tree.process_frame
	var dd: = [false]
	acc2.deleted.connect(func(): dd[0] = true)
	acc2._ask_delete()
	acc2._holding = true
	await tree.create_timer(V10AccountSheet.HOLD_SEC + 0.6).timeout
	check(dd[0] and not bool(G.S.profile_done), "hold-to-delete deletes")
	var wl: = V10AuthUI.welcome(host, "rin", V10AuthText.greet("rin", "Тест"))
	check(wl != null and is_instance_valid(wl), "welcome card")

	V10Auth.now_override = -1
	V10Auth.flavor_override = ""
	_wipe_root()
	print("AUTH_SELFTEST %d/%d" % [ok, total])
	if not fails.is_empty():
		print("AUTH_SELFTEST FAILS: ", fails)
	return [ok, total]
