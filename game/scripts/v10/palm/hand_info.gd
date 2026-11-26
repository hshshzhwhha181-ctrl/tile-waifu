class_name V10PalmInfo
extends RefCounted

# V10PalmInfo — паспорт режима «Чтение руки» (docs/MODES.md §7.1, docs/0.10-spec.md R4).
# Сборка W4 читает INFO / LESSONS_INFO / HOW / afisha_entry() для вкладки «Столы → За столом» и «Афиши».

const T: = preload("res://scripts/v10/palm/hand_text.gd")
const ST: = preload("res://scripts/v10/palm/hand_state.gd")
const L: = preload("res://scripts/v10/palm/hand_lessons.gd")

const ID: = "hand"
const LESSONS_ID: = "hand_lessons"
const SCREEN_PATH: = "res://scripts/v10/palm/hand_screen.gd"

const INFO: = {
	"id": ID,
	"name": T.MODE,
	"shelf": "table",
	"line": T.MODE_LINE,
	"host": "yue",
	"gate": {"level": 30},
	"screen": SCREEN_PATH,
}

const LESSONS_INFO: = {
	"id": LESSONS_ID,
	"name": T.LESSONS_TITLE,
	"shelf": "table",
	"line": T.LESSONS_SUB,
	"host": "rin",
	"gate": {"level": 30},
	"screen": SCREEN_PATH,
	"args": {"view": "lessons"},
}

const HOW: = T.RULES


static func status(day_key: String = "") -> Dictionary:
	return ST.status(day_key)


static func afisha_entry() -> Dictionary:
	var stt: = ST.status()
	var state: = String(stt.get("state", "open"))
	if state == "locked":
		return {"open": false, "done": false, "title": T.MODE, "sub": String(stt.get("text", "")), "badge": ""}
	var done: = state == "done"
	return {
		"open": true,
		"done": done,
		"title": T.MODE,
		"sub": T.DONE_TODAY if done else T.MODE_LINE,
		"badge": "" if done else "Сегодня",
	}


static func lessons_progress_text() -> String:
	var pr: = L.progress()
	var done_n: = 0
	for x in pr:
		if int(x) >= L.TASKS:
			done_n += 1
	return "%d из %d" % [done_n, L.LESSONS.size()]