class_name V10ClarityTour
extends RefCounted

# dev: the screenshot tour — one run shows every clarity screen.
#   --screen=play --level=8 --v8_devsave=1 --shots=<dir> --at=120 --v10_tour=<dir> [--name=<prefix>]   (--shots skips the splash)
# Runs the selftest first («V10 CLARITY SELFTEST n/n»), then saves <prefix>_<step>.png: board (marks), bubble,
# board_big, bubble_flip, legend_1..3, glossary_1..2, glossary_card, settings, win (breakdown), win_card, win_why; quits.

static func run(play, ti: V10TileInfo, dir: String) -> void:
	var tree: SceneTree = play.get_tree()
	var pre: = V10Clarity._arg("name") if V10Clarity._arg("name") != "" else "clar"
	printerr("TOUR START")
	var r: = V10ClaritySelftest.run(play)
	printerr("V10 CLARITY SELFTEST %d/%d" % [r.ok, r.total])
	for f in r.fails:
		printerr("  FAIL: ", f)
	var shot: = func(n: String) -> void:
		await RenderingServer.frame_post_draw
		var img: Image = play.get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [dir, pre, n])
		printerr("SHOT ", n)
	var wait: = func(s: float) -> void:
		await tree.create_timer(s).timeout
	var guard: = 0
	while not play.board.input_on and guard < 300:
		guard += 1
		await wait.call(0.1)
	var st: = V10ClarityState.st()
	st.marks = "on"
	st.big = false
	st.asked = true
	V10TileMarks.refresh_all()
	await wait.call(1.0)
	await shot.call("board")
	await V10Clarity._dev_open(play, ti, "bubble")
	await wait.call(0.8)
	await shot.call("bubble")
	ti.close_bubble()
	st.big = true
	V10TileMarks.refresh_all()
	await wait.call(0.6)
	await shot.call("board_big")
	for t in play.board.tiles:
		if play.board.on_board(t) and t.back_spr != null and t.ice > 0:
			ti.show_for(t)
			break
	await wait.call(0.8)
	await shot.call("bubble_flip")
	ti.close_bubble()
	st.big = false
	V10TileMarks.refresh_all()
	var lg: = V10Legend.open(play)
	await wait.call(1.6)
	await shot.call("legend_1")
	lg.scroll.scroll_vertical = int(lg.scroll.size.y * 0.9)
	await wait.call(1.2)
	await shot.call("legend_2")
	lg.scroll.scroll_vertical = int(lg.scroll.size.y * 1.8)
	await wait.call(1.2)
	await shot.call("legend_3")
	lg.close()
	await wait.call(0.4)
	var gs: = V10GlossaryScreen.open(play, "bonus")
	await wait.call(1.2)
	await shot.call("glossary_1")
	(gs.tabs[1] as JButton).pressed.emit()
	await wait.call(1.0)
	await shot.call("glossary_2")
	V10InfoCard.open(gs, "state.flip", {"no_more": true})
	await wait.call(0.8)
	await shot.call("glossary_card")
	_close_cards(play)
	gs.close()
	await wait.call(0.4)
	V10Clarity.open_settings(play)
	await wait.call(1.0)
	await shot.call("settings")
	for c in V10InfoCard.layer_for(play).get_children():
		if c.has_meta("popup"):
			c.queue_free()
	await wait.call(0.4)
	# the victory: the same bonuses as --v8_yaku=1, everything «new»
	st.seen = {}
	G.S.yaku_seen = {}
	play.riichi = true
	play.sets_done = [0, 2]
	play.max_combo = 7
	play.last_combo = 4
	for t in play.board.tiles:
		t.alive = false
		t.hide()
	play._on_clear()
	await wait.call(9.0)
	await shot.call("win")
	var rows: = V10Breakdown.rows_for(play)
	var pick: Dictionary = rows[1] if rows.size() > 1 else rows[0]
	V10InfoCard.open(play, String(pick.id), {"points": "+%d %s ранга" % [int(pick.pts), V8PlayRules.points_word(int(pick.pts))], "count": 1, "new": true})
	await wait.call(0.8)
	await shot.call("win_card")
	_close_cards(play)
	await wait.call(0.3)
	V10Breakdown.summary(play, 3, 560, true)
	await wait.call(0.8)
	await shot.call("win_why")
	tree.quit()

static func _close_cards(play) -> void:
	for c in V10InfoCard.layer_for(play).get_children():
		if c is V10InfoCard:
			c.close()
