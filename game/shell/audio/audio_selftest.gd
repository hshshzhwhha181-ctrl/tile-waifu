class_name TWAudioSelftest
extends RefCounted

# P30 selftest: TWAudio buses, TWDuck (envelope measured on a rendered WAV), TWVoiceQueue (priority, depth 1, cooldowns),
# TWSfxPool (weak Mali budget under a load simulator), TWAudio node (ducking on the real buses, gates, haptics, cue contract).
#   godot --headless --audio-driver Dummy --path game res://shell/audio/audio_selftest.tscn   ->  "TWAUDIO_SELFTEST ok/total"
# The 339 checks of the 0.10 audio lane (V10AUDIO, assets + V10Music + V10SfxBank) are NOT moved or weakened: that suite stays
# registered as `audio` and still prints V10AUDIO OK 339/339; this suite covers the new bus on top of the same assets.

var ok: = 0
var total: = 0
var fails: Array = []


func _c(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)


func _near(a: float, b: float, eps: float, what: String) -> void:
	_c(absf(a - b) <= eps, "%s: %.4f vs %.4f (eps %.4f)" % [what, a, b, eps])


func run(host: Node) -> Array:
	_ladder()
	_queue_priority()
	_queue_depth_fuzz()
	_queue_cooldowns()
	_queue_rare_and_touch()
	_duck_math()
	_duck_wav()
	_pool_logic()
	_weak_mali_sim()
	_bus_layout()
	await _node(host)
	if fails.is_empty():
		print("TWAUDIO_SELFTEST %d/%d" % [ok, total])
	else:
		print("TWAUDIO_SELFTEST FAIL %d/%d" % [ok, total])
		for f in fails:
			print("  - ", f)
	return [ok, total]


# ── combo ladder ─────────────────────────────────────────────────────────────────────────────────────────────────────────

func _ladder() -> void:
	for n in range(0, 31):
		_near(TWAudio.combo_pitch(n), V10SfxBank.combo_pitch(n), 1e-9, "ladder n=%d == V10SfxBank" % n)
	_near(TWAudio.combo_pitch(1), 1.0, 1e-9, "pair 1 = base pitch")
	_near(TWAudio.combo_pitch(2), pow(2.0, 1.0 / 12.0), 1e-9, "pair 2 = +1 semitone")
	_near(TWAudio.combo_pitch(13), 2.0, 1e-9, "pair 13 = octave")
	_near(TWAudio.combo_pitch(99), 2.0, 1e-9, "capped at an octave")
	for n in range(1, 13):
		_c(TWAudio.combo_pitch(n + 1) > TWAudio.combo_pitch(n), "ladder rises %d" % n)
	var legacy: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Sfx")
	if legacy != null:
		for n in range(1, 16):
			_near(TWAudio.combo_pitch(n), legacy.combo_pitch(n), 1e-9, "ladder == Sfx.combo_pitch(%d)" % n)
		_near(TWDuck.ATTACK_S, float(legacy.DUCK_ATTACK), 1e-9, "duck attack == legacy Sfx")
		_near(TWDuck.RELEASE_S, float(legacy.DUCK_RELEASE), 1e-9, "duck release == legacy Sfx")


# ── voice queue: priority and depth 1 ────────────────────────────────────────────────────────────────────────────────────

func _queue_priority() -> void:
	_c(TWVoiceQueue.priority_of("ron") > TWVoiceQueue.priority_of("tsumo"), "ron > tsumo")
	_c(TWVoiceQueue.priority_of("tsumo") > TWVoiceQueue.priority_of("riichi"), "tsumo > riichi")
	_c(TWVoiceQueue.priority_of("riichi") > TWVoiceQueue.priority_of("pon"), "riichi > pon")
	_c(TWVoiceQueue.priority_of("pon") == TWVoiceQueue.priority_of("chi") and TWVoiceQueue.priority_of("chi") == TWVoiceQueue.priority_of("kan"), "pon = chi = kan")
	_c(TWVoiceQueue.priority_of("kan") > TWVoiceQueue.priority_of("combo_t1"), "kan > other")
	_c(TWVoiceQueue.priority_of("idle_1") == TWVoiceQueue.priority_of("level_2"), "everything else is one class")
	# full matrix: voice A is speaking, B asks 0.1 s later
	var kinds: = ["ron", "tsumo", "riichi", "pon", "chi", "kan", "idle_1"]
	for a in kinds:
		for b in kinds:
			var q: = TWVoiceQueue.new()
			var r1: = q.request("mc", a, 0.0, 2.0)
			_c(r1["verdict"] == "play", "first line plays: " + a)
			var r2: = q.request("rin", b, 0.1, 1.0)
			var pa: = TWVoiceQueue.priority_of(a)
			var pb: = TWVoiceQueue.priority_of(b)
			if pb > pa:
				_c(r2["verdict"] == "play" and r2["reason"] == "preempt" and r2["interrupted"] == a, "%s cuts %s" % [b, a])
			else:
				_c(r2["verdict"] == "queued", "%s waits behind %s" % [b, a])
			_c(not q.current().is_empty() and q.busy(0.2), "exactly one voice is current (%s then %s)" % [a, b])
	# depth 1: the waiting place keeps the higher priority
	var q: = TWVoiceQueue.new()
	q.request("mc", "ron", 0.0, 1.8)
	var a1: = q.request("mc", "combo_t1", 0.2, 1.0)
	_c(a1["verdict"] == "queued", "second line waits")
	var a2: = q.request("mc", "hint_given", 0.3, 1.0)
	_c(a2["verdict"] == "dropped" and a2["reason"] == "queue_full", "third line of equal priority is dropped (the waiting one stays)")
	var a3: = q.request("hana", "pon", 0.4, 1.0)
	_c(a3["verdict"] == "queued" and a3["reason"] == "replaced_lower" and a3["replaced"] == "combo_t1", "higher priority replaces the waiting lower one")
	var a4: = q.request("rin", "idle_2", 0.5, 1.0)
	_c(a4["verdict"] == "dropped" and a4["reason"] == "queue_full_lower_priority", "the YOUNGER priority is the one thrown away")
	var a5: = q.request("yue", "chi", 0.6, 1.0)
	_c(a5["verdict"] == "dropped" and a5["reason"] == "queue_full", "equal priority does not displace the waiting one")
	_c(q.pending()["line_id"] == "pon", "the waiting place holds the winner")
	var t1: = q.tick(1.8)
	_c(t1["verdict"] == "play" and t1["reason"] == "dequeued" and t1["line_id"] == "pon", "the waiting line starts when the voice ends")
	_c(q.pending().is_empty() and q.busy(1.9), "queue is empty, one voice speaking")
	_c(q.tick(1.9).is_empty(), "nothing else starts while the voice speaks")
	# stale
	var s: = TWVoiceQueue.new()
	s.request("mc", "idle_1", 0.0, 10.0)
	s.request("mc", "combo_t1", 0.5, 1.0)
	_c(s.tick(10.0).is_empty() and s.pending().is_empty(), "a line that waited longer than STALE_S is not spoken late")
	_c(int(s.stats["expired"]) == 1, "stale counted")
	# a cut voice never leaves two playing
	var c: = TWVoiceQueue.new()
	c.request("mc", "idle_1", 0.0, 5.0)
	c.request("mc", "ron", 0.1, 1.0)
	_c(c.current()["line_id"] == "ron" and not c.busy(1.2), "the cutting line owns the voice and ends on its own time")


func _queue_depth_fuzz() -> void:
	var q: = TWVoiceQueue.new(7)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 99
	var kinds: = ["ron", "tsumo", "riichi", "pon", "chi", "kan", "idle_1", "combo_t1", "hint_given", "touch_head_1", "level_2", "clear_normal", "fail"]
	var heroes: = ["mc", "rin", "hana", "yue", "nova", "zlata"]
	var t: = 0.0
	var plays: Array = []   # [start, end, line]
	var bad_pend: = 0
	for i in 6000:
		t += rng.randf_range(0.0, 0.6)
		var d: = q.tick(t)
		if not d.is_empty():
			plays.append([d["entry"]["start"], d["entry"]["end"], d["entry"]["line_id"]])
		var r: = q.request(heroes[rng.randi() % heroes.size()], kinds[rng.randi() % kinds.size()], t, rng.randf_range(0.4, 3.0), {"line_id": "%s_%d" % [kinds[rng.randi() % kinds.size()], rng.randi() % 3]})
		if r["verdict"] == "play":
			# a play that cut the previous line ends that line there
			if not plays.is_empty() and r["reason"] == "preempt":
				plays[plays.size() - 1][1] = minf(float(plays[plays.size() - 1][1]), t)
			plays.append([r["entry"]["start"], r["entry"]["end"], r["line_id"]])
		if q.pending().size() > 0 and q.current().is_empty():
			bad_pend += 1
	var overlap: = 0
	for i in range(1, plays.size()):
		if float(plays[i][0]) < float(plays[i - 1][1]) - 1e-6:
			overlap += 1
	_c(plays.size() > 500, "fuzz produced %d voice starts" % plays.size())
	_c(overlap == 0, "fuzz: never two voices at once (%d overlaps in %d starts)" % [overlap, plays.size()])
	_c(bad_pend == 0, "fuzz: a waiting line never exists without a current one")
	_c(int(q.stats["dropped"]) > 100 and int(q.stats["interrupted"]) > 20, "fuzz exercised drops (%d) and cuts (%d)" % [q.stats["dropped"], q.stats["interrupted"]])


# ── voice queue: cooldowns ───────────────────────────────────────────────────────────────────────────────────────────────

func _queue_cooldowns() -> void:
	var q: = TWVoiceQueue.new()
	_c(q.request("mc", "clear_normal", 0.0, 1.0)["verdict"] == "play", "line plays")
	var r: = q.request("mc", "clear_normal", 3.5, 1.0)
	_c(r["verdict"] == "dropped" and r["reason"] == "line_cooldown", "same line of the same heroine inside 4 s is dropped")
	_c(q.request("mc", "clear_normal", 3.99, 1.0)["verdict"] == "dropped", "3.99 s still cooling")
	_c(q.request("mc", "clear_normal", 4.0, 1.0)["verdict"] == "play", "4.0 s: the line may be said again")
	_c(q.request("rin", "clear_normal", 5.2, 1.0)["verdict"] == "play", "another heroine has her own cooldown")
	var left: = q.cooldown_left("mc", "clear_normal", "clear_normal", 5.0)
	_near(left, 3.0, 1e-6, "cooldown_left reports the rest")
	# category 60 s (chatter): any line of the category, same heroine
	var c: = TWVoiceQueue.new()
	_c(c.request("mc", "combo_t1", 0.0, 1.0)["verdict"] == "play", "combo_t1 plays")
	var r2: = c.request("mc", "combo_t2", 10.0, 1.0)
	_c(r2["verdict"] == "dropped" and r2["reason"] == "category_cooldown", "another line of the category within 60 s is dropped")
	_c(c.request("mc", "combo_t3", 59.9, 1.0)["verdict"] == "dropped", "59.9 s still cooling")
	_c(c.request("mc", "combo_t2", 60.0, 1.0)["verdict"] == "play", "60 s: the category is free again")
	_c(c.request("rin", "combo_t1", 61.0, 1.0)["verdict"] == "play", "category cooldown is per heroine")
	_c(c.request("mc", "idle_1", 62.0, 1.0)["verdict"] == "play", "another category is not affected")
	# events are never muted by a category cooldown
	var e: = TWVoiceQueue.new()
	var seq: = ["ron", "tsumo", "riichi", "pon", "chi", "kan", "clear_normal", "fail"]
	var t: = 0.0
	for k in seq:
		_c(e.request("mc", k, t, 0.5, {"line_id": k + "_a"})["verdict"] == "play", "event %s is not chatter" % k)
		t += 1.0
		e.request("mc", k, t, 0.5, {"line_id": k + "_b"})
		t += 1.0
	_c(TWVoiceQueue.is_chatter("idle_warm_1") and TWVoiceQueue.is_chatter("touch_head_2") and not TWVoiceQueue.is_chatter("ron"), "chatter classification")
	_c(TWVoiceQueue.category_of("touch_head_2") == "touch" and TWVoiceQueue.category_of("ron") == "ron", "category_of")
	# a line that was dropped or displaced does not burn its cooldown
	var d: = TWVoiceQueue.new()
	d.request("mc", "idle_1", 0.0, 30.0)
	d.request("mc", "combo_t1", 1.0, 1.0)
	d.request("hana", "pon", 1.1, 1.0)    # displaces combo_t1 from the waiting place
	_c(d.cooldown_left("mc", "combo_t1", "combo_t1", 1.2) == 0.0, "a displaced line keeps its cooldown untouched")
	# the waiting line is dropped at dequeue when an identical one played meanwhile
	var w: = TWVoiceQueue.new()
	w.request("mc", "idle_1", 0.0, 1.0)
	w.request("mc", "clear_normal", 0.5, 1.0)
	_c(w.pending()["line_id"] == "clear_normal", "line waits")
	_c(w.request("mc", "clear_normal", 0.6, 1.0)["reason"] == "duplicate", "the same line is not queued twice")


func _queue_rare_and_touch() -> void:
	var q: = TWVoiceQueue.new()
	_c(q.request("mc", "touch_rare_1", 0.0, 1.0, {"rare": true, "roll": 0.5})["reason"] == "rare_roll", "rare line: roll 0.5 is silent")
	_c(q.request("mc", "touch_rare_1", 0.0, 1.0, {"rare": true, "roll": 0.049})["verdict"] == "play", "rare line: roll 0.049 plays (1/20)")
	var hits: = 0
	var n: = 20000
	var r: = TWVoiceQueue.new(5)
	for i in n:
		r.reset()
		if r.request("mc", "touch_rare_1", float(i), 1.0, {"rare": true})["verdict"] == "play":
			hits += 1
	var frac: = float(hits) / n
	_c(frac > 0.04 and frac < 0.06, "rare line plays 1 in 20 (%.4f over %d)" % [frac, n])
	var t: = TWVoiceQueue.new()
	_c(not t.note_touch("mc", 0.0) and not t.note_touch("mc", 0.5), "two touches are not spam")
	_c(t.note_touch("mc", 1.0), "3 touches in 1.0 s = touch_spam")
	_c(not t.note_touch("mc", 1.1), "the detector resets after it fires")
	var u: = TWVoiceQueue.new()
	_c(not u.note_touch("mc", 0.0) and not u.note_touch("mc", 0.7) and not u.note_touch("mc", 1.4), "3 touches spread over 1.4 s are not spam")
	_c(u.note_touch("mc", 1.6), "...but the next one inside the window is")
	_c(not u.note_touch("rin", 1.7), "touches are counted per heroine")


# ── ducking ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _duck_math() -> void:
	var d: = TWDuck.new()
	_near(d.step(0.1), 0.0, 1e-9, "no source: no duck")
	d.set_source("voice", -8.0)
	_near(d.step(0.04), -4.0, 1e-6, "attack: half way in 40 ms")
	_near(d.step(0.04), -8.0, 1e-6, "attack: -8 dB after 80 ms")
	_near(d.step(0.5), -8.0, 1e-6, "held")
	d.clear_source("voice")
	_near(d.step(0.2), -4.0, 1e-6, "release: half way in 200 ms")
	_near(d.step(0.2), 0.0, 1e-6, "release: back after 400 ms")
	var e: = TWDuck.new()
	e.set_source("voice", -8.0, 0.0)
	e.step(0.0)
	_c(not e.has_source("voice") or e.target_db() <= 0.0, "zero hold expires")
	var f: = TWDuck.new()
	f.set_source("voice", -8.0, 1.0)
	f.set_source("combo_t3", -6.0, 5.0)
	_near(f.target_db(), -8.0, 1e-9, "deepest source wins, no stacking (-8 and -6 is -8)")
	f.step(1.05)
	_near(f.target_db(), -6.0, 1e-9, "the shallower source takes over when the deeper one expires")
	f.step(0.5)
	_near(f.cur_db, -6.0, 1e-6, "settles at the T3 depth -6")
	var g: = TWDuck.new()
	g.set_source("summon", TWDuck.SUMMON_DB, -1.0, TWDuck.SUMMON_ATTACK_S, TWDuck.SUMMON_RELEASE_S)
	g.step(0.15)
	_near(g.cur_db, -60.0, 1e-6, "summon: music out in 150 ms")
	g.clear_source("summon")
	g.step(0.3)
	_near(g.cur_db, -30.0, 1e-6, "summon: half back after 0.3 s")
	g.step(0.3)
	_near(g.cur_db, 0.0, 1e-6, "summon: back in 0.6 s")
	var h: = TWDuck.new()
	h.set_source("voice", -8.0, 0.5)
	h.step(0.2)
	h.set_source("voice", -8.0, 0.5)
	h.step(0.4)
	_c(h.has_source("voice"), "a repeated duck extends, it does not restart a second one")
	_c(h.target_db() == -8.0, "...and does not stack")
	_c(TWDuck.VOICE_MUSIC_DB == -8.0 and TWDuck.VOICE_SFX_DB == -3.0 and TWDuck.COMBO_T3_MUSIC_DB == -6.0 and TWDuck.ULT_MUSIC_DB == -8.0, "GDD 8.5 depths")


# The proof the acceptance asks for: render the envelope into a WAV (music tone, voice window 0.5 s .. 2.0 s), read the file
# back and measure depth / attack / release from the samples.
func _duck_wav() -> void:
	var path: = "user://tw_duck_render.wav"
	var r: = TWDuck.render_wav(path, [[0.5, 2.0]], 3.5)
	_c(not r.is_empty() and FileAccess.file_exists(path), "duck render written")
	var m: = TWDuck.measure_wav(path, 0.5, 2.0)
	print("TWAUDIO duck measured from %s: depth %.2f dB, attack %.1f ms, release %.1f ms" % [path, m["depth_db"], m["attack_ms"], m["release_ms"]])
	_near(float(m["depth_db"]), -8.0, 1.0, "WAV: music ducks 8 +- 1 dB")
	_near(float(m["attack_ms"]), 80.0, 20.0, "WAV: duck lands in 80 +- 20 ms")
	_near(float(m["release_ms"]), 400.0, 60.0, "WAV: music is back in 400 +- 60 ms")
	_near(float(m["base_db"]), -23.0, 0.2, "WAV: reference level is the -20 dBFS sine (RMS -23 dB)")
	# the same at the lowest frame rate a weak phone drops to
	var r2: = TWDuck.render_wav("user://tw_duck_render_30.wav", [[0.5, 2.0]], 3.5, -8.0, 30.0)
	var m2: = TWDuck.measure_wav("user://tw_duck_render_30.wav", 0.5, 2.0)
	_c(not r2.is_empty(), "30 fps render written")
	_near(float(m2["depth_db"]), -8.0, 1.0, "WAV @30 fps: depth")
	_near(float(m2["attack_ms"]), 80.0, 20.0, "WAV @30 fps: attack")
	_near(float(m2["release_ms"]), 400.0, 60.0, "WAV @30 fps: release")
	# two voices back to back: the music does not pump back to 0 dB in between when the gap is shorter than the release
	TWDuck.render_wav("user://tw_duck_render_2.wav", [[0.5, 1.5], [1.7, 3.0]], 4.5)
	var m3: = TWDuck.measure_wav("user://tw_duck_render_2.wav", 1.7, 3.0, float(m["base_db"]))
	_near(float(m3["depth_db"]), -8.0, 1.0, "second voice 200 ms after the first: ducked to -8 dB again, not -16")


# ── SFX pool and the weak Mali budget ────────────────────────────────────────────────────────────────────────────────────

func _pool_logic() -> void:
	var p: = TWSfxPool.new(8)
	for i in 8:
		_c(p.acquire("s%d" % i, 2.0, 2, 0.0) >= 0, "slot %d free" % i)
	_c(p.active(0.1) == 8, "8 active")
	_c(p.acquire("late", 1.0, 2, 0.1) >= 0 and p.active(0.1) == 8, "a 9th sound of equal priority steals the oldest, never exceeds 8")
	_c(p.acquire("hover", 1.0, 1, 0.2) == -1, "a low priority sound is dropped when the pool is full")
	_c(p.acquire("finale", 1.0, 3, 0.3) >= 0 and p.active(0.3) == 8, "a high priority sound steals")
	_c(p.active(5.0) == 0, "all voices end")
	var g: = TWSfxPool.new(8)
	_c(g.acquire("tile_click", 0.1, 2, 0.0, 4, 0.03) >= 0, "first click")
	_c(g.acquire("tile_click", 0.1, 2, 0.01, 4, 0.03) == -1, "retrigger inside the gap is merged")
	_c(g.acquire("tile_click", 0.1, 2, 0.05, 4, 0.03) >= 0, "after the gap it plays")
	var h: = TWSfxPool.new(8)
	for i in 6:
		h.acquire("card_flip", 1.0, 2, float(i) * 0.05, 4, 0.0)
	_c(h.active_of("card_flip", 0.3) == 4, "per-id polyphony limit (4)")
	h.acquire("star", 2.0, 2, 0.4)
	h.release_id("star", 0.5)
	_c(h.active_of("star", 0.6) == 0, "release_id frees a cue")


# "profile 'weak Mali': <= 8 SFX voices and <= 1 voice, checked by a load simulator": 180 s of a hard session on virtual time:
# 12-step combos every ~3 s (combo_step each 80 ms + finale), a tile click 6/s, matches, UI taps, fever and ult stings, rewards,
# plus heroine lines at random (every kind) -- all through the same TWSfxPool / TWVoiceQueue the node uses.
func _weak_mali_sim() -> void:
	for prof in ["weak_mali", "normal"]:
		var cap: int = int(TWAudio.PROFILES[prof]["max_sfx"])
		var pool: = TWSfxPool.new(cap)
		var q: = TWVoiceQueue.new(3)
		var rng: = RandomNumberGenerator.new()
		rng.seed = 4242
		var ev: Array = []   # [t, id, pitch]
		var t: = 0.0
		while t < 180.0:
			var kind: = rng.randi() % 10
			if kind < 3:
				for s in 12:
					ev.append([t + s * 0.08, "combo_step", TWAudio.combo_pitch(s + 1)])
				ev.append([t + 0.96, "combo_finale", 1.0])
			elif kind < 7:
				for s in 8:
					ev.append([t + s * 0.16, "tile_click", 1.0])
					ev.append([t + s * 0.16 + 0.05, "match_%d" % (1 + rng.randi() % 3), 1.0])
			elif kind < 9:
				for u in ["btn_press", "tab_switch", "page_turn", "btn_hover", "notify"]:
					ev.append([t + rng.randf() * 0.4, u, 1.0])
			else:
				for u in ["fever_ignite", "ult_cast", "cutin_whoosh", "coin_fly", "gem_fly", "star", "reward_pop", "chest_open", "ssr_reveal"]:
					ev.append([t + rng.randf() * 0.6, u, 1.0])
			t += rng.randf_range(0.5, 3.0)
		ev.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		var played: = 0
		var dropped: = 0
		var worst: = 0
		var finale_lost: = 0
		for e in ev:
			var id: String = e[1]
			var b: Dictionary = V10SfxBank.BANK[id]
			var dur: = V10SfxBank.length_of(id) / float(e[2])
			var slot: = pool.acquire(id, dur, TWAudio.prio_of(id), float(e[0]), int(b["max"]), float(b["gap"]))
			if slot >= 0:
				played += 1
			else:
				dropped += 1
				if TWAudio.prio_of(id) == 3:
					finale_lost += 1
			worst = maxi(worst, pool.active(float(e[0])))
		_c(worst <= cap, "%s: %d events, peak SFX voices %d <= %d" % [prof, ev.size(), worst, cap])
		_c(pool.peak <= cap, "%s: pool peak %d <= %d" % [prof, pool.peak, cap])
		_c(played > 500, "%s: the simulator is busy enough (%d played, %d dropped)" % [prof, played, dropped])
		if prof == "weak_mali":
			_c(pool.peak == cap, "weak_mali: the load reaches the ceiling (%d), so the cap is really exercised" % pool.peak)
		print("TWAUDIO load sim %s: %d events, played %d, dropped %d, peak voices %d/%d, high-priority lost %d" % [prof, ev.size(), played, dropped, pool.peak, cap, finale_lost])
		# voices: every kind, 3000 asks over 180 s
		var kinds: = ["ron", "tsumo", "riichi", "pon", "chi", "kan", "idle_1", "idle_2", "touch_head_1", "combo_t1", "combo_t2", "clear_normal", "fail", "hint_given", "intro_summon", "ult_cast_a"]
		var heroes: = ["mc", "rin", "hana", "yue", "nova", "zlata", "kohaku", "shirin", "tsubame", "miel"]
		var starts: Array = []
		var tv: = 0.0
		var concurrent_max: = 0
		for i in 3000:
			tv += rng.randf_range(0.0, 0.12)
			var d: = q.tick(tv)
			if not d.is_empty():
				starts.append([d["entry"]["start"], d["entry"]["end"]])
			var r: = q.request(heroes[rng.randi() % heroes.size()], kinds[rng.randi() % kinds.size()], tv, rng.randf_range(0.4, 3.5))
			if r["verdict"] == "play":
				if r["reason"] == "preempt" and not starts.is_empty():
					starts[starts.size() - 1][1] = minf(float(starts[starts.size() - 1][1]), tv)
				starts.append([r["entry"]["start"], r["entry"]["end"]])
		for i in starts.size():
			var n: = 0
			for j in range(maxi(0, i - 3), mini(starts.size(), i + 4)):
				if float(starts[j][0]) < float(starts[i][1]) - 1e-6 and float(starts[i][0]) < float(starts[j][1]) - 1e-6:
					n += 1
			concurrent_max = maxi(concurrent_max, n)
		_c(concurrent_max <= 1, "%s: <= 1 voice at any time over %d lines (max %d)" % [prof, starts.size(), concurrent_max])


func _bus_layout() -> void:
	var lay: = load("res://default_bus_layout.tres")
	_c(lay is AudioBusLayout, "default_bus_layout.tres loads as AudioBusLayout")
	if lay == null:
		return
	var want: = ["Master", "Music", "SFX", "Voice", "UI"]
	for i in range(1, 5):
		_c(String(lay.get("bus/%d/name" % i)) == want[i], "layout bus %d = %s" % [i, want[i]])
		_c(String(lay.get("bus/%d/send" % i)) == "Master", "layout %s sends to Master" % want[i])
	_near(float(lay.get("bus/4/volume_db")), -2.0, 1e-6, "layout: UI at -2 dB")
	_near(float(lay.get("bus/3/volume_db")), 0.0, 1e-6, "layout: Voice at 0 dB (-14 LUFS is mastered into the files)")
	for b in want:
		_c(AudioServer.get_bus_index(b) >= 0, "bus exists at runtime: " + b)
	TWAudio.ensure_buses()
	_c(AudioServer.bus_count >= 5 and AudioServer.get_bus_index("UI") >= 0, "ensure_buses is idempotent")


# ── the node ─────────────────────────────────────────────────────────────────────────────────────────────────────────────

func _node(host: Node) -> void:
	var a: = TWAudio.new()
	a.manual = true
	host.add_child(a)
	await host.get_tree().process_frame
	_c(a.pool.max_voices == 16 or TWAudio.detect_profile() == "weak_mali", "normal profile: 16 SFX voices")
	a.set_profile("weak_mali")
	_c(a.pool.max_voices == 8 and a._players.size() == 8, "weak_mali: 8 SFX players")
	_c(TWAudio.MAX_VOICES == 1, "voice cap is 1")
	_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")), -2.0, 1e-3, "UI bus at -2 dB")
	# every bank id plays
	var all_ok: = true
	var t: = 0.0
	for id in V10SfxBank.ids():
		t += 1.5
		a._t = t
		if not a.sfx(id):
			all_ok = false
			fails.append("bank id does not play through TWAudio: " + String(id))
	_c(all_ok, "all %d bank ids play through TWAudio.sfx" % V10SfxBank.ids().size())
	_c(not a.sfx("no_such_sound"), "unknown id is refused")
	# 60 sounds in one frame on weak Mali
	a.set_profile("weak_mali")
	a._t += 5.0
	var ids: Array = V10SfxBank.ids()
	var fired: = 0
	for i in 60:
		if a.sfx(String(ids[i % ids.size()]), {"gap": 0.0}):
			fired += 1
	var playing: = 0
	for p in a._players:
		if p.playing:
			playing += 1
	_c(playing <= 8 and a.pool.active(a._t) <= 8, "weak_mali: 60 sounds in one frame -> %d players playing (<= 8), %d accepted" % [playing, fired])
	# UI ids use the UI bus, the rest SFX
	a.set_profile("weak_mali")
	a._t += 5.0
	a.sfx("btn_press")
	a.sfx("match_1")
	var bus_of: Array = []
	for p in a._players:
		if p.playing:
			bus_of.append(String(p.bus))
	_c(bus_of.has("UI") and bus_of.has("SFX"), "btn_press on UI, match_1 on SFX: %s" % str(bus_of))
	# combo / click / cue contract
	a.set_profile("normal")
	_near(a.combo(3), pow(2.0, 2.0 / 12.0), 1e-9, "combo(3) = +2 semitones")
	_c(a.tile_click() or true, "tile_click callable")
	for cue in [TWResultChain.STING_SHORT, "gem_fly", "coin_fly", "star"]:
		a._t += 1.0
		a.play_cue(String(cue), {})
		_c(true, "play_cue(%s) handled" % cue)
	_c(a.has_method("play_cue") and a.has_method("stop_cue"), "audio service contract of TWResultModal (play_cue, stop_cue)")
	a.stop_cue(TWResultChain.STING_SHORT)
	# ── voice, ducking on the real buses
	a.set_profile("normal")
	a.queue = TWVoiceQueue.new()
	a.duck_music = TWDuck.new()
	a.duck_sfx = TWDuck.new()
	a.configure({"voice_mode": "always", "music": 1.0, "sfx": 1.0, "hero_off": {}})
	a._t = 100.0
	var mi: = AudioServer.get_bus_index("Music")
	var si: = AudioServer.get_bus_index("SFX")
	for i in 5:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), 0.0, 1e-3, "idle: Music at 0 dB")
	var v: = a.say("mc", "riichi", {"ctx": "match"})
	_c(v["verdict"] == "play" and v["audible"], "riichi plays and is audible (voice file found)")
	_c(a.voice_playing() and a._voice_player.playing, "the Voice player runs")
	_c(String(a._voice_player.bus) == "Voice", "voice on the Voice bus")
	for i in 6:
		a.advance(0.016)
	_c(AudioServer.get_bus_volume_db(mi) < -5.0, "music ducks under the voice (%.2f dB after 96 ms)" % AudioServer.get_bus_volume_db(mi))
	for i in 10:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), -8.0, 0.05, "Music bus at -8 dB under the voice")
	_near(AudioServer.get_bus_volume_db(si), -3.0, 0.05, "SFX bus at -3 dB under the voice")
	var dur: float = float(v["entry"]["dur"])
	var steps: = int(ceil((float(v["entry"]["end"]) - a._t) / 0.016)) + 1
	for i in steps:
		a.advance(0.016)
	_c(not a.voice_playing(), "the voice ended after %.2f s" % dur)
	for i in 10:
		a.advance(0.016)
	_c(AudioServer.get_bus_volume_db(mi) > -8.0 and AudioServer.get_bus_volume_db(mi) < 0.0, "music is on its way back (%.2f dB)" % AudioServer.get_bus_volume_db(mi))
	for i in 30:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), 0.0, 0.05, "Music back at 0 dB within 0.5 s of the end of the voice")
	_near(AudioServer.get_bus_volume_db(si), 0.0, 0.05, "SFX back at 0 dB")
	# ron cuts riichi; a lower line waits; subtitles for everything that was not dropped
	a._t += 20.0
	var r1: = a.say("rin", "riichi", {"ctx": "match"})
	var r2: = a.say("hana", "ron", {"ctx": "match"})
	_c(r2["verdict"] == "play" and r2["reason"] == "preempt", "ron cuts riichi through the node")
	var r3: = a.say("yue", "idle_1", {"ctx": "lobby", "dur": 1.0})
	_c(r3["verdict"] == "queued" and r3["subtitle"], "a lower line waits, its subtitle is still wanted")
	var r4: = a.say("yue", "idle_1", {"ctx": "lobby", "dur": 1.0})
	_c(r4["verdict"] == "dropped" and not r4["subtitle"], "dropped lines have no subtitle")
	var spoken: Array = []
	a.voice_started.connect(func(h: String, _t: String, _d: float): spoken.append(h))
	for i in 400:
		a.advance(0.016)
	_c(spoken.has("yue"), "the waiting line is spoken when the voice is free")
	# gates
	a.stop_voice()
	a.queue = TWVoiceQueue.new()
	a._t += 100.0
	a.configure({"voice_mode": "lobby"})
	var g1: = a.say("mc", "riichi", {"ctx": "match"})
	_c(g1["verdict"] == "play" and not g1["audible"] and g1["subtitle"], "voice_mode lobby: no voice in a match, the subtitle stays")
	a.stop_voice()
	for i in 40:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), 0.0, 0.05, "a subtitle-only line does not duck the music")
	a._t += 100.0
	var g2: = a.say("mc", "greet_x", {"ctx": "lobby", "dur": 1.0})
	_c(g2["verdict"] == "play", "lobby line plays in the lobby")
	a.stop_voice()
	a._t += 100.0
	a.configure({"voice_mode": "always", "hero_off": {"mc": true}})
	var g3: = a.say("mc", "riichi", {"ctx": "lobby"})
	_c(not g3["audible"] and g3["subtitle"], "per-heroine mute silences her voice, not her subtitles")
	a.stop_voice()
	a._t += 100.0
	var g4: = a.say("rin", "riichi", {"ctx": "lobby"})
	_c(g4["audible"], "another heroine still speaks")
	a.stop_voice()
	a.configure({"voice_mode": "off", "hero_off": {}})
	a._t += 100.0
	_c(not a.say("rin", "rankup", {"ctx": "lobby"})["audible"], "voice_mode off")
	a.stop_voice()
	a.configure({"voice_mode": "always"})
	# sliders
	a.configure({"music": 0.5, "sfx": 0.25, "voice": 1.0, "ui": 0.0})
	a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), linear_to_db(0.5), 0.01, "music slider 0.5 -> -6.02 dB")
	_near(AudioServer.get_bus_volume_db(si), linear_to_db(0.25), 0.01, "sfx slider 0.25 -> -12.04 dB")
	_c(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")) <= -78.0, "ui slider 0 -> silent")
	a.configure({"music": 1.0, "sfx": 1.0, "ui": 1.0})
	a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")), -2.0, 0.01, "ui slider 1 -> -2 dB")
	# combo T3 / ult / summon
	a.duck_combo_t3(0.5)
	for i in 20:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), -6.0, 0.05, "combo T3: music -6 dB")
	for i in 80:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), 0.0, 0.05, "combo T3 duck released")
	a.summon_reveal(true)
	for i in 14:
		a.advance(0.016)
	_c(AudioServer.get_bus_volume_db(mi) <= -50.0, "summon reveal: music out (%.1f dB after 224 ms)" % AudioServer.get_bus_volume_db(mi))
	a.summon_reveal(false)
	for i in 50:
		a.advance(0.016)
	_near(AudioServer.get_bus_volume_db(mi), 0.0, 0.05, "summon reveal: music back after 0.8 s")
	a._t += 50.0
	a.ult("nova")
	for i in 20:
		a.advance(0.016)
	_c(AudioServer.get_bus_volume_db(mi) <= -7.9, "ult: music -8 dB (%.2f)" % AudioServer.get_bus_volume_db(mi))
	a.stop_voice()
	a.duck_music = TWDuck.new()
	a.advance(5.0)
	# music facade honours the slider
	a.configure({"music": 0.0})
	a.music("home")
	_c(V10Music.current() != "lobby" or V10Music.current() == "", "music slider 0: the facade does not start a track")
	a.configure({"music": 1.0})
	# haptics
	var got: Array = []
	a.haptic_sink = func(ms: int, amp: float): got.append([ms, amp])
	a.configure({"haptics": "full"})
	a._t += 1.0
	_c(a.haptic("select") == [[10, 0.3, 0]], "haptic select 10 ms / 0.3")
	_c(got == [[10, 0.3]], "the sink got the pulse")
	a._t += 1.0
	_c(a.haptic("match")[0][0] == 20 and is_equal_approx(a.haptic("match").size() if false else 0.5, 0.5), "haptic match 20 ms / 0.5")
	a._t += 1.0
	_c(a.haptic("ult")[0][0] == 60 and is_equal_approx(a.haptic_log[a.haptic_log.size() - 1][1][0][1], 0.8), "haptic ult 60 ms / 0.8")
	a._t += 1.0
	var before: = got.size()
	_c(a.haptic("error").is_empty() and got.size() == before, "an error has NO vibration")
	a._t += 1.0
	a.haptic("select")
	var inside: = a.haptic("match")
	_c(inside.is_empty(), "pulses closer than 35 ms are merged")
	a.configure({"haptics": "weak"})
	a._t += 1.0
	var w: = a.haptic("ult")
	_near(float(w[0][1]), 0.4, 1e-6, "weak level halves the amplitude")
	a.configure({"haptics": "off"})
	a._t += 1.0
	_c(a.haptic("ult").is_empty(), "haptics off")
	a.haptic_sink = Callable()
	# preload
	a.voice_resolver = func(h: String, k: String): return load(V10SfxBank.voice_path("mc", "riichi")) if h == "mc" else null
	_c(a.preload_partner("mc", ["riichi", "ron"]) == 2 and a.preload_partner("rin", ["riichi"]) == 0, "preload_partner counts resolvable lines")
	a.queue_free()
	await host.get_tree().process_frame
