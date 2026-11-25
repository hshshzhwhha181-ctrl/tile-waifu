extends Node

func _ready() -> void:
	var out: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(4))
	var P = load("res://scripts/v10/duels/challenge/challenge_poster.gd")
	var D = load("res://scripts/v10/duels/challenge/challenge_deal.gd")
	var C = load("res://scripts/v10/duels/challenge/challenge_code.gd")
	var p = {"mode": 1, "gen": 0, "key": 3, "tenths": 1023, "stars": 3}
	var r = D.resolve(p)
	print("resolve ", r.get("ok"), " ", r.get("err"), " ", r.get("table"), " pairs ", r.get("pairs"))
	var looks = [["mc", ""], ["rin", "r_maid"], ["hana", "h_beach"], ["yue", "y_queen"]]
	for lk in looks:
		var inf = P.info(p, r, {"hero": lk[0], "outfit": lk[1], "nick": "Ника"})
		var img: Image = await P.render(inf, self)
		print(lk, " size ", img.get_size(), " art ", P.outfit_art(lk[0], lk[1]))
		if out != "" and not img.is_empty():
			img.save_png(out + "/poster_%s.png" % lk[0])
	get_tree().quit()
