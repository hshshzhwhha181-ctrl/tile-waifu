class_name V10DuelInfo
extends RefCounted

# V10DuelInfo — паспорт «Дуэлей 2.0» и «Вызова по коду» для полки «Столы → Испытания и соперницы» (MODES.md §6.1, §7.1).

const D: = preload("res://scripts/v10/duels/duel_state.gd")
const R: = preload("res://scripts/v10/duels/duel_rank.gd")

const ID: = "duels"
const PLAY_ID: = "duel2"
const CHALLENGE_ID: = "challenge"

const SCREEN_PATH: = "res://scripts/v10/duels/duel_screen.gd"
const PLAY_PATH: = "res://scripts/v10/duels/duel_play.gd"
const CHALLENGE_PATH: = "res://scripts/v10/duels/challenge/challenge_screen.gd"
const CHALLENGE_PLAY_PATH: = "res://scripts/v10/duels/challenge/challenge_play.gd"

const LINE: = "Гонка за парами с героиней за одним столом"
const CHALLENGE_LINE: = "Тот же стол друга и сравнение времени"

const HOW: = [
	"Вы с героиней разбираете один стол наперегонки: чьих пар больше — за тем победа",
	"Её цель мерцает заранее: сними эту пару первым и перехвати ход",
	"Подлость соперницы и её лимит видны на карточке до боя",
]

const INFO: = {
	"id": ID,
	"name": "Дуэли",
	"shelf": "trials",
	"line": LINE,
	"host": "rin",
	"gate": {"rank": "Нефрит III"},
	"screen": SCREEN_PATH,
}

const CHALLENGE_INFO: = {
	"id": CHALLENGE_ID,
	"name": "Вызов по коду",
	"shelf": "trials",
	"line": CHALLENGE_LINE,
	"host": "nova",
	"gate": {},
	"screen": CHALLENGE_PATH,
}


static func status() -> Dictionary:
	if not D.menu_open():
		return {"open": false, "text": D.lock_text("menu"), "sub": ""}
	var si: = D.season_info()
	return {"open": true, "text": String(si.get("rating_text", "")), "sub": String(si.get("tier_name", ""))}