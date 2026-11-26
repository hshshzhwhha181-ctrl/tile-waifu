class_name V10PlayerBday
extends RefCounted

# V10PlayerBday — the player's birthday under 152-ФЗ (docs/0.10-spec.md Р7).
#   * Asked once: the partner's letter on the 3rd day of play, after the first win of that day; «Рассказать» and
#     «Не хочу говорить» have equal weight (V10PlayerBdayScreen).
#   * Stored ONLY month and day, ONLY with a separate consent tick (purpose text), only locally until 1.0.
#     The year is never stored. Delete in Settings («Мой день рождения: 14 мар · Удалить») clears everything.
#   * Gift on the day: 3 билета, рамка «Мой праздник · YYYY», +50 симпатии партнёру — once a year.
#   * The date can change once per 365 days. Set less than 30 days before the date → «Я запомнила! Отпразднуем в
#     следующем году» (no gift this year: nobody gains by typing a fake date).
#   * Nothing outside v10/rituals reads S.v10_bday.player (shop, payments, analytics) — selftest greps it.
#
#   ask_due(key, first_key, won_today) -> bool     set_date(m, d, consent, key) -> {ok, err, later}
#   decline()      delete()      gift_due(key) -> bool      claim_gift(key) -> rows      settings_text() -> String
#   celebrate_md(year) -> [m, d]  (Feb 29 → Feb 28 in common years)

const ASK_DAY: = 3
const CHANGE_DAYS: = 365
const LATE_DAYS: = 30
const GIFT: = {"tickets": 3}
const GIFT_AFF: = 50
const PURPOSE: = "Мы храним только день и месяц, чтобы поздравить тебя. Можно удалить в настройках."
const MONTH_DAYS: = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


static func st() -> Dictionary:
	return V10RitSave.st("v10_bday").player


static func has_date() -> bool:
	return int(st().m) > 0 and int(st().d) > 0


static func ask_due(key: String, first_key: String, won_today: bool) -> bool:
	var p: = st()
	if bool(p.asked) or has_date() or first_key == "":
		return false
	return won_today and V10RitClock.days_between(first_key, key) >= ASK_DAY - 1


static func mark_asked() -> void:
	st().asked = true


static func decline() -> void:
	var p: = st()
	p.asked = true
	p.declined = true


static func valid(m: int, d: int) -> bool:
	return m >= 1 and m <= 12 and d >= 1 and d <= int(MONTH_DAYS[m - 1])


static func celebrate_md(y: int, m: = -1, d: = -1) -> Array:
	var p: = st()
	m = int(p.m) if m < 0 else m
	d = int(p.d) if d < 0 else d
	var leap: = (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
	if m == 2 and d == 29 and not leap:
		return [2, 28]
	return [m, d]


static func _next_occurrence(key: String, m: int, d: int) -> String:
	var y: = V10RitClock.year(key)
	for yy in [y, y + 1]:
		var md: = celebrate_md(yy, m, d)
		var k: = "%04d-%02d-%02d" % [yy, md[0], md[1]]
		if k >= key:
			return k
	return "%04d-%02d-%02d" % [y + 1, m, d]


static func set_date(m: int, d: int, consent: bool, key: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	var p: = st()
	if not consent:
		return {"ok": false, "err": "no_consent"}
	if not valid(m, d):
		return {"ok": false, "err": "invalid"}
	# change_key survives delete(): deleting and re-entering does not bypass the once-a-year change rule
	var ck: = str(p.get("change_key", ""))
	if ck != "" and V10RitClock.days_between(ck, key) < CHANGE_DAYS:
		return {"ok": false, "err": "too_soon", "next": V10RitClock.add_days(ck, CHANGE_DAYS)}
	p.m = m
	p.d = d
	p.set_key = key
	p.change_key = key
	p.consent_key = key
	p.asked = true
	p.declined = false
	var nxt: = _next_occurrence(key, m, d)
	var later: = V10RitClock.days_between(key, nxt) < LATE_DAYS
	p.skip_year = V10RitClock.year(nxt) if later else 0
	V10RitSave.save()
	return {"ok": true, "err": "", "later": later, "next": nxt}


static func delete() -> void:
	var p: = st()
	p.m = 0
	p.d = 0
	p.set_key = ""
	p.consent_key = ""
	p.skip_year = 0
	V10RitSave.save()


static func gift_due(key: = "") -> bool:
	key = key if key != "" else V10RitClock.day_key()
	if not has_date():
		return false
	var p: = st()
	var y: = V10RitClock.year(key)
	var md: = celebrate_md(y)
	if V10RitClock.md(key) != md:
		return false
	return int(p.last_gift_year) != y and int(p.skip_year) != y


static func frame_id(y: int) -> String:
	return "fr_me_%d" % y


static func claim_gift(key: = "") -> Array:
	key = key if key != "" else V10RitClock.day_key()
	if not gift_due(key):
		return []
	var y: = V10RitClock.year(key)
	st().last_gift_year = y
	V10RitBridge.register_frame(frame_id(y), "Мой праздник · %d" % y, {"type": "bday", "hero": "", "year": y})
	var r: Dictionary = GIFT.duplicate(true)
	r["frame"] = frame_id(y)
	r["aff"] = {V10RitBridge.partner(): GIFT_AFF}
	var rows: = V10RitBridge.grant(r, "player_bday")
	V10RitSave.save()
	return rows


static func settings_text() -> String:
	if not has_date():
		return "Мой день рождения: не указан"
	return "Мой день рождения: %s · Удалить" % V10RitClock.fmt_date_short(int(st().m), int(st().d))
