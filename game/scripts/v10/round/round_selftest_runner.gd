extends Node

# Runner of the round-core selftest (P20): TWModeCfg, TWBoosters, TWRewards, TWRound, TWRoundStats (game/core/round/).
#   godot --headless --path game res://scripts/v10/round/round_selftest.tscn
# Prints "ROUND_SELFTEST ok/total"; exit code 0 when all pass. It runs as a scene so the legacy G exists as an ORACLE: the ladder and the
# yaku table of the live G are compared with the core's copy; the core classes themselves never see G.


func _ready() -> void:
	await get_tree().process_frame
	var env: = {"ranks": G.RANKS, "yaku": G.YAKU, "cats": G.CATS, "rank_of": Callable(G, "rank_of"), "rank_index": Callable(G, "rank_index"),
		"levels_size": G.LEVELS.size(), "text": func(k: String) -> String: return V6Txt.s(k)}
	var r: Array = TWRoundSelftest.run(env)
	get_tree().quit(0 if r[0] == r[1] else 1)
