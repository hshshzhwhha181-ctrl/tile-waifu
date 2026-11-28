extends "res://scripts/screens/play.gd"

# «Вызов по коду»: play.gd with the R5 hooks, for main.SCREENS["challenge_play"] until the integrator moves the
# same lines into play.gd (README §Хуки). Hot files are not edited from this lane; this subclass is the proof that
# the hooks are enough. Like v06 mode_play.gd it only overrides the hook points.
#
#   args.challenge = {mode, gen, key, tenths, stars, core, code, nick, title}  → mode "challenge"
#   any other args → the ordinary table, but SEEDED like the hook asks (seed(cfg.seed) right before
#   board.setup(cfg) for Путь / Партия дня), so the author's table and the friend's table are the same deal.
#
# In a challenge: the deal is the author's (same seed, same specials plan, same gift draw — the gift itself is
# taken off), crystals per pair are 0 and the crystals of the table's specials are held back (ch_gems_lock; the
# clean hook is «if _mode() in ["trial", "challenge"]: return» in V6Specials._gems), heroine shards are not paid,
# riichi is not offered, paid helps are refused,
# the overflow window is the run's sheet (one free «Вернуть 3 фишки»), the win is the run's result sheet.

const CH_RUN: = preload("res://scripts/v10/duels/challenge/challenge_run.gd")
const CH_DEAL: = preload("res://core/modes/duels/challenge/challenge_deal.gd")
const CH_UTIL: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")

var ch_src_mode: = ""
var ch_fingerprint: = 0
var ch_gems_lock: = -1  # the crystal balance held during a challenge run (specials and gifts of the table pay nothing)


func build(m, args: Dictionary) -> void:
	super.build(m, args)
	if mode == "challenge":
		CH_RUN.attach(self, args.challenge)
		ch_gems_lock = V10Money.bal("gems")


# whatever crystals the table paid on its own go back through the same door they came in by
func _ch_hold_gems() -> void:
	var over: = V10Money.bal("gems") - ch_gems_lock
	if over > 0:
		V10Money.grant({"gems": -over}, "challenge_hold")


func _process(dt: float) -> void:
	super._process(dt)
	if ch_gems_lock >= 0 and V10Money.bal("gems") > ch_gems_lock:
		_ch_hold_gems()


func _v6_setup(args: Dictionary) -> bool:
	if not args.has("challenge"):
		return false
	var r: Dictionary = CH_RUN.play_cfg(args.challenge)
	mode = "challenge"
	if not r.ok:
		# the screen resolves the code before it starts a run; a stale call falls back to the first table
		cfg = (G.LEVELS[0] as Dictionary).duplicate(true)
		cfg.name = "Вызов"
		return true
	cfg = r.cfg
	var mid: = String(r.deal.get("mode_id", "path"))
	ch_src_mode = "daily" if mid == "daily" else ""
	if mid in ["path", "peak"]:
		lvl = int(CH_DEAL.path_unkey(int(args.challenge.key)).idx)
	return true


# HOOK _make_board: seed the global generator with cfg.seed right before board.setup(cfg) (TrayBoard._assign draws
# faces from it), then give the randomness back. In a challenge the author's mode is set for the specials plan and
# the gift draw, so the random sequence after setup is the author's too.
func _make_board() -> void:
	if not CH_DEAL.seeded(self):
		super._make_board()
		return
	var keep: = mode
	if mode == "challenge":
		mode = ch_src_mode
	# the omikuji «золото» of the author's own run is laid on AFTER the deal (its own generator), so the luck card
	# never shifts the table a code points at
	var fort_gold: = int(fortune.get("gold", 0)) if mode == "" else 0
	if fort_gold > 0:
		cfg = cfg.duplicate(true)
		cfg.gold = int(cfg.get("gold", 0)) - fort_gold
	seed(int(cfg.get("seed", 0)))
	super._make_board()
	randomize()
	mode = keep
	ch_fingerprint = CH_DEAL.board_fingerprint(board)
	if fort_gold > 0:
		cfg.gold = int(cfg.get("gold", 0)) + fort_gold
		_ch_more_gold(fort_gold / 2)
	if mode == "challenge":
		for t in board.tiles:
			if t.gift:
				t.gift = false


func _ch_more_gold(pairs: int) -> void:
	var r: = RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 0)) * 7 + 3
	var by: = {}
	for t in board.tiles:
		if not t.gold and t.shard == "" and t.ice == 0:
			by[t.step] = by.get(t.step, []) + [t]
	var steps: = by.keys().filter(func(k): return (by[k] as Array).size() == 2)
	steps.sort()
	for i in mini(pairs, steps.size()):
		var k: int = steps.pop_at(r.randi() % steps.size())
		for t in by[k]:
			t.gold = true
			if t.mat:
				t.mat.set_shader_parameter("gold", 1.0)
	gold_total = board.tiles.filter(func(t): return t.gold).size() / 2


func _apply_perk() -> void:
	super._apply_perk()
	if mode == "challenge":
		gem_bonus = -1.0  # crystals per pair: 0 — the challenge pays only its own reward (spec R5)
		riichi_offered = true


func _on_match(mid: Vector2, combo: int, gold: bool, shard: String) -> void:
	var n0: = fx_layer.get_child_count() if fx_layer else 0
	super._on_match(mid, combo, gold, shard)
	if mode == "challenge" and fx_layer:
		for i in range(n0, fx_layer.get_child_count()):
			var c: = fx_layer.get_child(i)
			if c is Label and (c as Label).text == "+0":
				c.queue_free()


func _shard_found(h: String, mid: Vector2) -> void:
	if mode == "challenge":
		return
	super._shard_found(h, mid)


func _on_clear() -> void:
	if mode != "challenge":
		super._on_clear()
		return
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	var secs: = now() - start_t
	var stars: = V8PlayRules.story_stars(fails, boosters_used)
	if riichi_btn:
		riichi_btn.queue_free()
	_v8_saved = true
	board.input_on = false
	_v8_end_overlays()
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	if ch_gems_lock >= 0:
		_ch_hold_gems()
		ch_gems_lock = -1
	var run: = CH_RUN.of(self)
	if run:
		run.on_clear(secs, stars)


func _on_fail() -> void:
	if mode != "challenge":
		super._on_fail()
		return
	_v6_clear_tips()
	fails += 1
	if stage:
		stage.flash_emotion("sad")
		stage.react("fail")
	Sfx.play("deny", 0.7)
	_v8_modal_open()
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var run: = CH_RUN.of(self)
	if run:
		run.on_fail()


# the run's «Вернуть 3 фишки»: free, once, counted as a help
func ch_rescue() -> void:
	rescue_free = false
	boosters_used += 1
	_v8_modal_close()
	board.return_tray(3)
	_refresh()


func _v8_pay(kind: String, title: String, text: String, price: int, on_yes: Callable) -> void:
	if mode == "challenge":
		CH_UTIL.sfx("tile_deny")
		if main and main.has_method("toast"):
			main.toast("В вызове помощь не покупается", "")
		return
	super._v8_pay(kind, title, text, price, on_yes)
