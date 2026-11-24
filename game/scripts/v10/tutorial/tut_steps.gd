class_name V10TutSteps
extends RefCounted

# V10TutSteps — the guided first run, as data. Маджонг-тян (HEROINES.md §5: наставница, которая не умеет
# проигрывать и чуточку ревнует; тег «Партия окончена~») leads it. One step = one coach-mark.
#
# Chapter: {id, title, screen, need, when, entry, steps}
#   need   predicate that makes the chapter due at all (order of CHAPTERS = priority; "" = always)
#   when   predicate that starts it on its own screen (e.g. the victory window is up)
#   entry  optional bridge steps on another screen that lead the player to the chapter screen
# Step keys:
#   id        unique, saved in S.v10_tut.step (resume after the app was killed)
#   text      1–3 short lines ("\n" between lines). {slots} etc. are filled by V10TutFlow.fill()
#   emo       portrait: happy | shy | surprised | pout | sad   (assets/v08/emotions/mc_<emo>.webp)
#   target    see V10TutTarget (Array = fallbacks)
#   mode      "tap"  — read, tap anywhere to continue (other input blocked while it shows)
#             "do"   — forced: only the spotlight takes input; the step ends when `done` is true
#             "wait" — nothing to read: invisible until `done` (used to wait for an animation / screen)
#   done      predicate name (V10TutFlow.PRED) for "do" / "wait"
#   when      predicate that must hold before the step shows (else the flow waits on this step)
#   skip_if   predicate: the step is skipped (already done another way)
#   finger    true: the animated pointer sits on the target
#   resume    step id to restart from after an app kill (a match is not restored, so its chapter restarts)
#   timeout   seconds a "do" step waits before a «Дальше» chip appears (no softlock if the target misbehaves)
#   gift      one-time gift granted when the step shows (V10Tutorial.grant)
#   screen    overrides the chapter screen for this step

const CHAPTERS: = [
	{
		"id": "match1", "title": "Первая партия", "screen": "play", "need": "", "when": "first_match",
		"entry": [
			{"id": "m_bridge", "screen": "home", "mode": "do", "finger": true, "emo": "happy", "done": "screen_play_or_levels",
				"text": "Наша первая партия ещё не доиграна!\nСадись за стол — я подскажу.",
				"target": [{"prop": "play_btn"}, {"text": "Сесть за стол"}, {"px": [-418, -296, 400, 114]}]},
		],
		"steps": [
			{"id": "m_wait", "mode": "wait", "done": "board_ready"},
			{"id": "m_board", "mode": "tap", "emo": "happy", "resume": "m_wait",
				"text": "Это стол. Фишки лежат слоями, как пирожные на подносе.\nЗадача — убрать их все парами.",
				"target": [{"prop": "board_rect", "pad": 0}, {"dyn": "board"}, {"rect": [0.02, 0.25, 0.96, 0.58]}]},
			{"id": "m_free", "mode": "do", "finger": true, "emo": "happy", "done": "tile_in_tray", "resume": "m_wait", "timeout": 30,
				"text": "Светлые фишки — свободные: сверху пусто и хотя бы один бок открыт.\nТапни эту!",
				"target": [{"dyn": "pair_first", "pad": 8}]},
			{"id": "m_tray", "mode": "tap", "emo": "surprised", "resume": "m_wait",
				"text": "Фишка уехала в лоток.\nДве одинаковые в лотке исчезают — найди ей пару!",
				"target": [{"prop": "tray_box"}, {"rect": [0.02, 0.13, 0.62, 0.11]}]},
			{"id": "m_twin", "mode": "do", "finger": true, "emo": "happy", "done": "pair_done", "resume": "m_wait", "timeout": 30,
				"text": "Вот её близняшка. Тапни — и пара исчезнет.",
				"target": [{"dyn": "pair_twin", "pad": 8}]},
			{"id": "m_blocked", "mode": "tap", "emo": "pout", "resume": "m_wait", "skip_if": "no_blocked",
				"text": "А затенённые фишки заблокированы: на них лежит другая\nили их зажали с двух боков. Сначала освободи.",
				"target": [{"dyn": "blocked", "pad": 8}]},
			{"id": "m_full", "mode": "tap", "emo": "pout", "resume": "m_wait",
				"text": "В лотке всего {slots} места. Заполнишь — партия проиграна.\nНе бери лишнего, бери парами.",
				"target": [{"prop": "tray_box"}, {"rect": [0.02, 0.13, 0.62, 0.11]}]},
			{"id": "m_combo", "mode": "do", "finger": true, "emo": "happy", "done": "tile_in_tray", "resume": "m_wait", "timeout": 30,
				"text": "Ещё пара! Пары подряд без пауз — это комбо.\nКомбо копит мою ульту.",
				"target": [{"dyn": "pair_first", "pad": 8}]},
			{"id": "m_combo2", "mode": "do", "finger": true, "emo": "happy", "done": "pair_done", "resume": "m_wait", "timeout": 30,
				"text": "И вторую половинку!",
				"target": [{"dyn": "pair_twin", "pad": 8}, {"dyn": "pair_first", "pad": 8}]},
			{"id": "m_ult", "mode": "tap", "emo": "shy", "resume": "m_wait",
				"text": "Это я. Пары заряжают шкалу ульты.\nКогда я засияю — тапни меня, и я сниму пару сама.",
				"target": [{"prop": "stage"}, {"prop": "portrait"}, {"px": [-250, 66, 242, 240]}]},
			{"id": "m_hint", "mode": "tap", "emo": "happy", "resume": "m_wait",
				"text": "Подсказка покажет хороший ход.",
				"target": [{"prop": "btn_hint", "round": true}, {"text": "Подсказка"}]},
			{"id": "m_undo", "mode": "tap", "emo": "happy", "resume": "m_wait",
				"text": "Отмена вернёт последнюю фишку из лотка на стол.",
				"target": [{"prop": "btn_undo", "round": true}, {"text": "Отмена"}]},
			{"id": "m_shuffle", "mode": "tap", "emo": "surprised", "resume": "m_wait",
				"text": "Перемешать — если ходов совсем не видно.\nИх немного на партию, береги.",
				"target": [{"prop": "btn_shuffle", "round": true}, {"text": "Перемешать"}]},
			{"id": "m_go", "mode": "tap", "emo": "happy", "resume": "m_wait",
				"text": "Дальше сам! Я рядом и подскажу, если засмотришься.\nПартия окончена~ когда стол чист.",
				"target": []},
		],
	},
	{
		"id": "victory1", "title": "Победа", "screen": "play", "need": "after_match1", "when": "victory_shown",
		"steps": [
			{"id": "v_wait", "mode": "wait", "done": "victory_settled"},
			{"id": "v_stars", "mode": "tap", "emo": "happy", "resume": "v_wait",
				"text": "Стол чист! Звёзды — за чистую игру:\nбез ошибок и без помощи их больше.",
				"target": [{"dyn": "win_stars"}, {"meta": "win.stars"}, {"rect": [0.15, 0.2, 0.7, 0.14]}]},
			{"id": "v_reward", "mode": "tap", "emo": "happy", "resume": "v_wait",
				"text": "А это награда: кристаллы, симпатия и очки ранга.\nКристаллы пригодятся для Желаний.",
				"target": [{"meta": "win.rewards"}, {"dyn": "win_reward"}]},
			{"id": "v_next", "mode": "do", "finger": true, "emo": "happy", "done": "left_victory", "resume": "v_wait", "timeout": 40,
				"text": "«Ещё уровень» — и сразу следующий стол.\nЯ не устала, а ты?",
				"target": [{"meta": "win.next"}, {"prop": "victory_next_btn"}, {"text": "Ещё уровень"}, {"text": "Следующая партия"}]},
		],
	},
	{
		"id": "home1", "title": "Чайная", "screen": "home", "need": "after_match1", "when": "",
		"steps": [
			{"id": "h_wait", "mode": "wait", "done": "home_ready"},
			{"id": "h_hero", "mode": "tap", "emo": "shy", "resume": "h_wait",
				"text": "Добро пожаловать в мою Чайную!\nТапни меня, когда захочешь поболтать — симпатия растёт.",
				"target": [{"meta": "home.hero"}, {"rect": [0.28, 0.2, 0.5, 0.42]}]},
			{"id": "h_side", "mode": "tap", "emo": "happy", "resume": "h_wait",
				"text": "Слева — Поручения, Визиты, Письма и Рейтинг.\nТочка на значке значит «загляни, там подарок».",
				"target": [{"union": [{"prop": "side_btns.tasks"}, {"prop": "side_btns.rating"}]}, {"px": [6, 130, 104, 520]}]},
			{"id": "h_play", "mode": "tap", "emo": "happy", "resume": "h_wait",
				"text": "«Сесть за стол» — следующий уровень Пути.",
				"target": [{"prop": "play_btn"}, {"text": "Сесть за стол"}]},
			{"id": "h_modes", "mode": "tap", "emo": "surprised", "resume": "h_wait",
				"text": "«Режимы» — турнир, дуэли и другие столы.\nОни открываются по мере игры.",
				"target": [{"prop": "modes_btn"}, {"text": "Режимы"}]},
			{"id": "h_nav", "mode": "tap", "emo": "happy", "resume": "h_wait",
				"text": "Внизу вкладки: Чайная, Гардероб, Партия, Желания и Лавка.",
				"target": [{"prop": "navbar", "from": "main", "pad": 4}, {"px": [0, -120, 720, 120]}]},
			{"id": "h_profile", "mode": "tap", "emo": "shy", "resume": "h_wait",
				"text": "Сверху — твой профиль и ранг, справа валюта.\nТапни профиль, чтобы сменить ник и аватар.",
				"target": [{"prop": "prof_root", "from": "main"}, {"px": [8, 20, 360, 90]}]},
			{"id": "h_help", "mode": "tap", "emo": "happy", "resume": "h_wait",
				"text": "Забудешь что-то — открой «Как играть» в настройках\nили нажми «?» на любом экране.",
				"target": []},
		],
	},
	{
		"id": "summon1", "title": "Первое желание", "screen": "summon", "need": "summon_ready", "when": "",
		"entry": [
			{"id": "s_go", "screen": "home", "mode": "do", "finger": true, "emo": "surprised", "done": "screen_summon", "gift": "first_wish",
				"text": "Желания открылись! Первое — за мой счёт.\nПойдём загадаем.",
				"target": [{"prop": "tab_nodes.summon", "from": "main"}, {"px": [432, -120, 144, 120]}]},
		],
		"steps": [
			{"id": "s_wait", "mode": "wait", "done": "summon_idle"},
			{"id": "s_rates", "mode": "tap", "emo": "happy", "resume": "s_wait",
				"text": "Каждое желание приносит наряд или героиню.\nШансы всегда открыты — кнопка «Шансы» рядом.",
				"target": [{"meta": "gacha.rates"}, {"text": "Шансы"}, {"prop": "pity_lbl"}, {"rect": [0.05, 0.18, 0.9, 0.4]}]},
			{"id": "s_pull", "mode": "do", "finger": true, "emo": "happy", "done": "pulled", "resume": "s_wait", "timeout": 40,
				"text": "Загадай желание — подарок уже у тебя!",
				"target": [{"meta": "gacha.pull1"}, {"prop": "pull1_btn"}, {"text": "Загадать ×1"}, {"prop": "pull10_btn"}]},
			{"id": "s_after", "mode": "wait", "done": "summon_idle", "resume": "s_wait"},
			{"id": "s_wardrobe", "mode": "do", "finger": true, "emo": "shy", "done": "screen_collection", "resume": "s_wait", "timeout": 40,
				"text": "Красиво вышло! Наряды надевают в Гардеробе.",
				"target": [{"prop": "tab_nodes.collection", "from": "main"}, {"px": [144, -120, 144, 120]}]},
		],
	},
	{
		"id": "wardrobe1", "title": "Гардероб", "screen": "collection", "need": "after_summon1", "when": "",
		"steps": [
			{"id": "w_wait", "mode": "wait", "done": "screen_settled"},
			{"id": "w_heroes", "mode": "tap", "emo": "happy", "resume": "w_wait",
				"text": "Сверху — девушки квартала. Открытые помогают в партии\nсвоим умением, если взять их напарницей.",
				"target": [{"meta": "coll.heroes"}, {"px": [0, 226, 720, 130]}]},
			{"id": "w_card", "mode": "tap", "emo": "happy", "resume": "w_wait",
				"text": "Внизу — наряды. Тапни карточку, чтобы примерить.\nУ каждого наряда своя ульта.",
				"target": [{"meta": "coll.outfits"}, {"px": [14, -368, 692, 226]}]},
			{"id": "w_done", "mode": "tap", "emo": "shy", "resume": "w_wait",
				"text": "Надетый наряд я ношу в Чайной и за столом.\nВыбирай, что тебе нравится больше.",
				"target": []},
		],
	},
	{
		"id": "ult1", "title": "Ульта", "screen": "play", "need": "after_match1", "when": "ult_ready",
		"steps": [
			{"id": "u_tap", "mode": "do", "finger": true, "emo": "surprised", "done": "ult_used", "timeout": 25,
				"text": "Шкала полна — я сияю!\nТапни меня, и я сниму пару своей ультой.",
				"target": [{"prop": "stage"}, {"prop": "portrait"}, {"px": [-250, 66, 242, 240]}]},
			{"id": "u_after", "mode": "tap", "emo": "happy", "skip_if": "ult_skipped",
				"text": "Видел? Ульта зависит от наряда:\nв другом платье я сыграю по-другому.",
				"target": []},
		],
	},
]


static func chapter(id: String) -> Dictionary:
	for c in CHAPTERS:
		if c.id == id:
			return c
	return {}


# every step (entry steps included) with its chapter id, in flow order
static func all_steps() -> Array:
	var out: = []
	for c in CHAPTERS:
		for s in c.get("entry", []):
			out.append({"chapter": c.id, "entry": true, "step": s})
		for s in c.steps:
			out.append({"chapter": c.id, "entry": false, "step": s})
	return out


static func find_step(id: String) -> Dictionary:
	for e in all_steps():
		if e.step.id == id:
			return e
	return {}


# the steps a player sees (not "wait"): the step counter counts these within a chapter
static func visible_steps(chapter_id: String) -> Array:
	var out: = []
	for s in chapter(chapter_id).get("steps", []):
		if s.get("mode", "tap") != "wait":
			out.append(s.id)
	return out
