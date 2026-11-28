extends Node

# Recorder of the P17 corpus: plays games on the REAL legacy TrayBoard and writes tests/fixtures/replays/corpus_NN.json.
#   godot --headless --path game res://scripts/v10/rules/parity_record.tscn [-- --games=500 --dir=res://tests/fixtures/replays/]
# Re-running it rewrites the corpus (the seeds are fixed, so the result is reproducible on the same Godot version).


func _ready() -> void:
	await get_tree().process_frame
	var n: = 500
	var dir: = TWParityLegacy.CORPUS_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--games="):
			n = int(a.substr(8))
		elif a.begins_with("--dir="):
			dir = a.substr(6)
	var s: Dictionary = await TWParityLegacy.record_all(self, n, dir)
	print("PARITY_RECORD ", s)
	get_tree().quit(0)
