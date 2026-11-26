class_name V10AdventureSelftest
extends Control

# Automated selftest for Wave 3 Monster Battle RPG Mode ("adventure").
# Run: Godot --headless --audio-driver Dummy --path game res://scripts/v10/adventure/adventure_selftest.tscn '--' '--adventure_selftest=1'

var _pass: = 0
var _fail: = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("ADVENTURE_SELFTEST FAIL: %s" % msg)


func _ready() -> void:
	_run()
	print("ADVENTURE_SELFTEST %d/%d" % [_pass, _pass + _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _run() -> void:
	# 1. Data integrity (6 monsters, valid arts & boards)
	_check(V10AdventureData.count() >= 6, "at least 6 monsters defined")
	for i in V10AdventureData.count():
		var m: Dictionary = V10AdventureData.monster_at(i)
		_check(String(m.id) != "", "monster %d id non-empty" % i)
		_check(int(m.hp) >= 100, "monster %d hp valid" % i)
		_check(int(m.atk) > 0 and int(m.cadence) >= 3, "monster %d atk/cadence valid" % i)
		_check(V10AdventureData.monster_texture(String(m.id)) != null, "monster %d texture loads" % i)
		var bcfg: Dictionary = V10AdventureData.board_cfg(i, 0)
		_check(int(bcfg.get("cols", 0)) >= 5 and int(bcfg.get("faces", 0)) >= 7, "monster %d board cfg valid" % i)

	# 2. Combat math: pair, combo, crit, ult, monster attack, win/lose
	var bt: = V10AdventureBattle.new(0, "mc")
	var hp0: = bt.mon_hp
	var r1: = bt.on_pair(1, false)
	_check(int(r1.damage) > 0 and bt.mon_hp == hp0 - int(r1.damage), "pair damages monster")
	var r2: = bt.on_pair(4, true)
	_check(bool(r2.crit) and int(r2.damage) > int(r1.damage) * 2, "gold combo deals crit damage")
	_check(bt.ult > 0, "matching charges ult")

	# Charge ult to max and cast
	for _k in 8:
		if bt.over:
			break
		bt.on_pair(2, false)
	if not bt.over and bt.ult_ready():
		var u_hp: = bt.mon_hp
		var ur: = bt.use_ult()
		_check(int(ur.damage) >= 100 and bt.mon_hp < u_hp, "ult deals massive damage")
		_check(bt.stun == V10AdventureData.ULT_STUN_TURNS, "ult stuns monster")

	# Stun blocks monster attack on cadence
	var bt2: = V10AdventureBattle.new(1, "rin")
	bt2.ult = V10AdventureData.ULT_MAX
	bt2.use_ult()
	var h_before: = bt2.hero_hp
	var cadence: = int(bt2.m.cadence)
	var hit_ev: = {}
	for _k in cadence:
		hit_ev = bt2.on_move()
	_check(bool(hit_ev.get("stunned", false)) and bt2.hero_hp == h_before, "stun prevents monster attack")

	# Monster attack damages heroine when not stunned
	bt2.stun = 0
	for _k in cadence:
		hit_ev = bt2.on_move()
	_check(bool(hit_ev.get("attack", false)) and bt2.hero_hp < h_before, "monster attacks heroine after cadence")

	# Overflow deals heavy damage and can cause defeat
	var bt3: = V10AdventureBattle.new(5, "nova")
	for _k in 20:
		if bt3.over:
			break
		bt3.on_overflow()
	_check(bt3.over and not bt3.won and bt3.hero_hp == 0, "repeated overflow defeats heroine")

	# 3. Save persistence & hub metadata
	var fake_s: = {}
	var st: = V10AdventureData.ensure(fake_s)
	_check(int(st.stage) == 0 and int(st.best_stage) == 0, "default save initialized")
	var rw: = V10AdventureData.record_win(0, 180, fake_s)
	_check(bool(rw.first_clear) and int(rw.gems) > 0 and int(st.stage) == 1 and int(st.best_stage) == 1, "first clear unlocks stage 1")
	var info: = V10AdventureData.hub_card_info(fake_s)
	_check(String(info.screen) == "adventure" and int(info.stage) == 1, "hub_card_info reflects progression")

	# 4. Screen instantiation smoke test (no crash)
	var scr_script = load(V10AdventureData.SCREEN_PATH)
	_check(scr_script != null, "adventure_screen.gd compiles and loads")
