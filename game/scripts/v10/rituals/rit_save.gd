class_name V10RitSave
extends RefCounted

# V10RitSave — save keys of the rituals lane (spec §2.6: no own SAVE_VER bump; V10Save.register(key, defaults)).
#   V10RitSave.defaults() -> {key: default dict}     the integrator registers each with V10Save (README hook H1)
#   V10RitSave.st(key) -> Dictionary                 the live dict: G.S[key] (created and filled when missing), or
#                                                    the bound dict in selftests (bind(fake_S))
#   V10RitSave.ensure(S)                             idempotent: adds missing keys, never overwrites
# Logs (calendar history beyond 35 days, letters) do not live here; the streak keeps only 35 day keys.

static var _bound: = false
static var _S: Dictionary = {}


static func defaults() -> Dictionary:
	return {
		"v10_streak": {"n": 0, "best": 0, "last_win_key": "", "leaves": 0, "leaf_week": "", "leaf_new_key": "",
			"repair": {}, "got": [], "hist": {}, "gift": false, "checked_key": "", "pending": [], "events": []},
		"v10_comeback": {"rested": 0, "last_seen_key": "", "last_tier_key": "", "scene": "", "gap": 0,
			"ladder": {}, "ladder_start_key": "", "notify": []},
		"v10_bday": {"year_done": {}, "prog": {"key": "", "h": "", "n": 0}, "seen_key": "",
			"player": {"m": 0, "d": 0, "set_key": "", "change_key": "", "consent_key": "", "last_gift_year": 0, "skip_year": 0,
				"asked": false, "declined": false}},
		"v10_tray": {"day": "", "claimed": {}},
		"v10_tele": {"week": "", "cur": {}, "prev_week": "", "prev": {}, "sent_week": "", "first_key": ""},
	}


static func ensure(S: Dictionary) -> Dictionary:
	var df: = defaults()
	for k in df:
		if not (S.get(k) is Dictionary):
			S[k] = df[k].duplicate(true)
		else:
			_fill(S[k], df[k])
	return S


static func _fill(d: Dictionary, df: Dictionary) -> void:
	for k in df:
		if not d.has(k) or (typeof(d[k]) != typeof(df[k]) and not (typeof(d[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(df[k]) in [TYPE_INT, TYPE_FLOAT])):
			d[k] = df[k].duplicate(true) if (df[k] is Dictionary or df[k] is Array) else df[k]
		elif df[k] is Dictionary and not (df[k] as Dictionary).is_empty():
			_fill(d[k], df[k])
		elif df[k] is int:
			d[k] = int(d[k])


static func bind(S: Dictionary) -> void:
	_S = ensure(S)
	_bound = true


static func unbind() -> void:
	_bound = false
	_S = {}


static func root() -> Dictionary:
	if _bound:
		return _S
	if V10RitBridge.has_g() and G.S is Dictionary:
		return G.S
	if _S.is_empty():
		_S = {}
	return _S


static func st(key: String) -> Dictionary:
	var S: = root()
	if not (S.get(key) is Dictionary):
		ensure(S)
	return S[key]


static func save() -> void:
	if not _bound and V10RitBridge.has_g() and G.has_method("save"):
		G.save()
