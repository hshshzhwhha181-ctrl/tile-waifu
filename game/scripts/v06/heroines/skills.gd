class_name V6Skills
extends RefCounted




static func _pos(t: Tile) -> Vector2:
	return t.get_global_transform_with_canvas().origin

static func _pairs(board: TrayBoard, n: int, deepest: = false) -> Array:
	var ps: Array = board._pairs_on_board().filter( func(p): return p[0].face == p[1].face and p[0].ice <= 0 and p[1].ice <= 0)
	if deepest:
		ps.reverse()
	return ps.slice(0, n)


static func blocked(play) -> String:
	var board: TrayBoard = play.board
	match String(play.partner):
		"rin":
			if board.tray.is_empty():
				return "Лоток пуст. Чайную паузу прибережём на трудный момент."
		"yue":
			pass
		_:
			if _pairs(board, 1).is_empty():
				return "Сейчас мне нечего снять. Чуть позже!"
	return ""

static func use(play) -> void :
	# 0.9: the skill is the Ultimate now (scripts/v09/ult/ult_cast.gd); this path stays for old callers
	var u = play.get("ult")
	if u is V9UltCast:
		await u.begin()
		return
	var board: TrayBoard = play.board
	var st: V6HeroStage = play.stage
	var h: String = play.partner
	var sk: Dictionary = G.SKILLS[h]
	var targets: Array = []
	var pairs: Array = []
	match h:
		"mc":
			pairs = _pairs(board, 1)
		"hana":
			pairs = _pairs(board, 2)
		"nova":
			pairs = _pairs(board, 1, true)
		"rin":
			for t in board.tray:
				targets.append(_pos(t))
		"yue":
			for t in board.tiles:
				if board.on_board(t) and (t.secret or t.ice > 0) and targets.size() < 8:
					targets.append(_pos(t))
	for p in pairs:
		targets.append(_pos(p[0]))
		targets.append(_pos(p[1]))
	play.set_meta("v6_casting", true)
	st.say("skill")
	var was_on: = board.input_on
	board.input_on = false
	await st.cast(sk.name, targets, sk.desc)
	if not is_instance_valid(board) or not board.is_inside_tree():
		return
	play.set_meta("v6_casting", false)
	match h:
		"rin":
			board.return_tray(board.tray.size())
		"yue":
			board.moonlight()
			if was_on:
				board.input_on = true
		_:
			for p in pairs:
				if board.on_board(p[0]) and board.on_board(p[1]) and not p[0].pending and not p[1].pending:
					board._vanish_pair(p[0], p[1])
					await board.get_tree().create_timer(0.16).timeout
			if was_on and board.tiles.any( func(t): return t.alive):
				board.input_on = true
			board._check_clear()
