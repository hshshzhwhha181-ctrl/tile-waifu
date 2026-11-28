extends Node








var pending_post: = {}

func _ready() -> void :
	var a: = _args()
	if a.has("story_scene"):
		_dev_scene.call_deferred(a.story_scene)

func _args() -> Dictionary:
	var a: = {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	return a

func st() -> Dictionary:
	if not (G.S.get("v6_story", null) is Dictionary):
		G.S["v6_story"] = {}
	var d: Dictionary = G.S.v6_story
	if not (d.get("seen", null) is Dictionary):
		d["seen"] = {}
	return d

func enabled() -> bool:
	if G.demo or not st().get("on", true):
		return false
	var a: = _args()
	if a.has("story_off"):
		return false
	if a.has("shots") and not a.has("story_shots") and not a.has("pt"):
		return false
	return true

func seen(id: String) -> bool:
	return st().seen.has(id)

func mark(id: String) -> void :
	st().seen[id] = true
	G.save()

func _world_size(loc: int) -> int:
	var n: = 0
	for l in G.LEVELS:
		if int(l.get("loc", -1)) == loc:
			n += 1
	return maxi(n, 1)


func scenes_before(i: int) -> Array:
	if i < 0 or i >= G.LEVELS.size():
		return []
	var lv: Dictionary = TWLevels.at(i)
	var loc: = int(lv.get("loc", 0))
	var stage: = int(lv.get("stage", 0))
	var n: = _world_size(loc)
	var out: = []
	if stage == 0:
		out.append("intro" if loc == 0 else "w%d_pre" % loc)
	elif loc == 0 and stage == 1:
		out.append("w0_mid")
	elif n >= 4 and stage == mini(n / 2, 6):
		out.append("w%d_mid" % loc)
	return out.filter( func(s): return V6Scenes.SCENES.has(s))


func scenes_after(i: int) -> Array:
	if i < 0 or i >= G.LEVELS.size():
		return []
	var lv: Dictionary = TWLevels.at(i)
	var loc: = int(lv.get("loc", 0))
	var stage: = int(lv.get("stage", 0))
	var out: = []
	if loc == 0 and stage == 0:
		out.append("first_win")
	if lv.get("boss", false) or stage == _world_size(loc) - 1:
		out.append("w%d_post" % loc)
	return out.filter( func(s): return V6Scenes.SCENES.has(s))

func _is_story(args: Dictionary) -> bool:
	return args.get("mode", "") == "" and not args.get("daily", false) and not args.has("trial") and args.has("level")


func before_go(main, id: String, args: Dictionary) -> void :
	var ids: = []
	if main.screen_id == "play" and not pending_post.is_empty():
		if int(G.S.get("rp", 0)) > int(pending_post.rp0):
			ids.append_array(pending_post.ids)
		pending_post = {}
	if id == "play" and _is_story(args):
		var i: = int(args.get("level", G.current_level))
		ids.append_array(scenes_before(i))
		pending_post = {"ids": scenes_after(i), "rp0": int(G.S.get("rp", 0))}
	if not enabled():
		return
	ids = ids.filter( func(s): return not seen(s))
	if ids.is_empty():
		return
	main.busy = true
	for s in ids:
		await play(s)
	main.busy = false


func play(id: String) -> void :
	if not V6Scenes.SCENES.has(id):
		return
	var root: = get_tree().current_scene
	if root == null:
		return
	var sc: = V6StoryScene.new()
	root.add_child(sc)
	await sc.play(id)
	mark(id)

func _dev_scene(id: String) -> void :
	await get_tree().create_timer(0.6).timeout
	await play(id)
