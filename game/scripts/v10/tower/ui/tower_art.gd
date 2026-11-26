class_name V10TowerArt
extends RefCounted

# Art and sound of the tower track (Пагода Луны, Странствие). Files live in res://assets/v10/tower/.
# Every getter returns null when a file is missing, so screens always keep a procedural fallback
# (the art lane can land later without breaking anything).

const DIR: = "res://assets/v10/tower/"

# key -> path (relative to DIR). Textures: .webp / .png; sounds: .ogg
const TEX: = {
	# Pagoda parallax, 3 layers, 720×2400 (far is opaque; mid and near have alpha)
	"pagoda_far": "pagoda_far.webp",
	"pagoda_mid": "pagoda_mid.png",
	"pagoda_near": "pagoda_near.png",
	# Journey: a wide landscape behind the scroll (720×1600, opaque) and a tileable washi paper (512×512)
	"journey_far": "journey_far.webp",
	"paper": "paper.webp",
	# 11 curse icons «алая тушь на лаке», 160×160 with alpha: curses/<curse id>.png
	"curse_shroud": "curses/shroud.png",
	"curse_hourglass": "curses/hourglass.png",
	"curse_greedy": "curses/greedy.png",
	"curse_narrow": "curses/narrow.png",
	"curse_one_lamp": "curses/one_lamp.png",
	"curse_no_ult": "curses/no_ult.png",
	"curse_no_undo": "curses/no_undo.png",
	"curse_no_hint": "curses/no_hint.png",
	"curse_no_shuffle": "curses/no_shuffle.png",
	"curse_fog": "curses/fog.png",
	"curse_guards": "curses/guards.png",
	# the 12th icon: the Heat ember (chip «Жар 12»)
	"heat": "curses/heat.png",
}

const SFX: = {
	"gong": "sfx/gong.ogg",              # «Подняться», Страж этажа
	"heat_flare": "sfx/heat_flare.ogg",  # «вспыхнул Жар» (forced curse every 10th floor, heat roll)
	"feather": "sfx/feather.ogg",        # Journey scroll unroll / seal stamp
	"heart_break": "sfx/heart_break.ogg",  # Journey: a heart breaks
	"lantern_out": "sfx/lantern_out.ogg",  # Pagoda: a lantern goes out (exhale)
}

static var _cache: = {}

static func has(key: String) -> bool:
	return tex(key) != null

static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	var rel: String = TEX.get(key, "")
	if rel != "" and ResourceLoader.exists(DIR + rel):
		t = load(DIR + rel) as Texture2D
	_cache[key] = t
	return t

static func curse_tex(curse_id: String) -> Texture2D:
	return tex("curse_" + curse_id)

static func sound(key: String) -> AudioStream:
	var rel: String = SFX.get(key, "")
	if rel != "" and ResourceLoader.exists(DIR + rel):
		return load(DIR + rel) as AudioStream
	return null
