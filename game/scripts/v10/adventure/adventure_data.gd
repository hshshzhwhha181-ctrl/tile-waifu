class_name V10AdventureData
extends RefCounted

# V10AdventureData — data, combat math, save persistence & hub card metadata
# for Wave 3 Monster Battle RPG Mode ("Приключение: Битва с монстрами").

const SAVE_KEY: = "v10_adventure"
const SCREEN_ID: = "adventure"
const SCREEN_PATH: = "res://scripts/v10/adventure/adventure_screen.gd"
const ART_DIR: = "res://assets/v10/adventure"

const HERO_MAX_HP: = 100
const ULT_MAX: = 100
const BASE_PAIR_DMG: = 20
const GOLD_CRIT_MULT: = 2.2
const COMBO_STEP: = 0.25
const COMBO_CAP: = 6
const ULT_STUN_TURNS: = 2
const ULT_HEAL: = 15

const MONSTERS: Array[Dictionary] = [
	{
		"id": "paper_oni",
		"stage": 0,
		"name": "Бумажный Они",
		"title": "Страж Бумажных Фонарей",
		"boss": false,
		"element": "Огонь",
		"accent": Color("#E85A4F"),
		"hp": 160,
		"atk": 9,
		"cadence": 6,
		"debuff": "fog",
		"debuff_name": "Пелена офуда",
		"debuff_desc": "Затуманивает 2 фишки",
		"debuff_count": 2,
		"bg": "bg_shrine",
		"fx": "lanterns",
		"gems": 35,
		"coins": 120,
		"aff": 5,
		"board": {"shape": "diamond", "cols": 5, "rows": 6, "layers": 2, "fill": 0.65, "faces": 8, "gold": 4, "ice": 0, "seed": 7011},
	},
	{
		"id": "moon_kitsune",
		"stage": 1,
		"name": "Лунный Кицунэ",
		"title": "Девятихвостая Тень Луны",
		"boss": false,
		"element": "Луна",
		"accent": Color("#A68EFF"),
		"hp": 210,
		"atk": 11,
		"cadence": 6,
		"debuff": "fog",
		"debuff_name": "Лунный морок",
		"debuff_desc": "Затуманивает 2 фишки",
		"debuff_count": 2,
		"bg": "bg_palace",
		"fx": "fireflies",
		"gems": 45,
		"coins": 160,
		"aff": 6,
		"board": {"shape": "heart", "cols": 5, "rows": 6, "layers": 3, "fill": 0.64, "faces": 9, "gold": 4, "ice": 0, "seed": 7022},
	},
	{
		"id": "jade_golem",
		"stage": 2,
		"name": "Нефритовый Голем",
		"title": "Хранитель Древних Костей",
		"boss": true,
		"element": "Нефрит",
		"accent": Color("#5BC89F"),
		"hp": 270,
		"atk": 13,
		"cadence": 7,
		"debuff": "freeze",
		"debuff_name": "Нефритовый иней",
		"debuff_desc": "Замораживает 2 фишки",
		"debuff_count": 2,
		"bg": "bg_shrine",
		"fx": "mist",
		"gems": 65,
		"coins": 220,
		"aff": 8,
		"board": {"shape": "pyramid", "cols": 6, "rows": 6, "layers": 3, "fill": 0.66, "faces": 10, "gold": 6, "ice": 2, "seed": 7033},
	},
	{
		"id": "frost_tengu",
		"stage": 3,
		"name": "Ледяной Тэнгу",
		"title": "Вихрь Снежного Павильона",
		"boss": false,
		"element": "Мороз",
		"accent": Color("#7CE2FF"),
		"hp": 320,
		"atk": 14,
		"cadence": 6,
		"debuff": "freeze",
		"debuff_name": "Буран Тэнгу",
		"debuff_desc": "Замораживает 3 фишки",
		"debuff_count": 3,
		"bg": "bg_teahouse",
		"fx": "snow",
		"gems": 80,
		"coins": 260,
		"aff": 9,
		"board": {"shape": "butterfly", "cols": 6, "rows": 7, "layers": 3, "fill": 0.65, "faces": 11, "gold": 6, "ice": 2, "seed": 7044},
	},
	{
		"id": "crimson_kasha",
		"stage": 4,
		"name": "Багровая Кася",
		"title": "Колесница Пылающего Пламени",
		"boss": false,
		"element": "Пламя",
		"accent": Color("#FF8A4A"),
		"hp": 380,
		"atk": 15,
		"cadence": 6,
		"debuff": "fog",
		"debuff_name": "Угольный дым",
		"debuff_desc": "Затуманивает 3 фишки",
		"debuff_count": 3,
		"bg": "bg_festival",
		"fx": "embers",
		"gems": 95,
		"coins": 320,
		"aff": 10,
		"board": {"shape": "ring", "cols": 6, "rows": 7, "layers": 3, "fill": 0.68, "faces": 11, "gold": 6, "ice": 0, "seed": 7055},
	},
	{
		"id": "dragon_shadow",
		"stage": 5,
		"name": "Тень Дракона",
		"title": "Повелитель Забытого Стола",
		"boss": true,
		"element": "Дракон",
		"accent": Color("#F4C86A"),
		"hp": 480,
		"atk": 17,
		"cadence": 6,
		"debuff": "both",
		"debuff_name": "Дыхание Дракона",
		"debuff_desc": "Лёд и туман на столе",
		"debuff_count": 2,
		"bg": "bg_shrine",
		"fx": "embers",
		"gems": 150,
		"coins": 500,
		"aff": 15,
		"board": {"shape": "cross", "cols": 6, "rows": 7, "layers": 4, "fill": 0.68, "faces": 12, "gold": 8, "ice": 2, "seed": 7066},
	},
]

const HERO_PERKS: = {
	"mc": "Быстрый заряд ульты",
	"rin": "Золотые пары лечат +6 HP",
	"hana": "Усиленный урон от комбо",
	"yue": "Мощные криты золотых фишек",
	"nova": "Пробивной удар (+4 к каждой паре)",
}

static var _tex_cache: = {}


static func count() -> int:
	return MONSTERS.size()


static func monster_at(stage_idx: int) -> Dictionary:
	var i: = clampi(stage_idx, 0, MONSTERS.size() - 1)
	return MONSTERS[i]


static func art_path(monster_id: String) -> String:
	var png_p: = "%s/%s.png" % [ART_DIR, monster_id]
	if ResourceLoader.exists(png_p):
		return png_p
	var webp_p: = "%s/%s.webp" % [ART_DIR, monster_id]
	if ResourceLoader.exists(webp_p):
		return webp_p
	return png_p


static func monster_texture(monster_id: String) -> Texture2D:
	if _tex_cache.has(monster_id):
		return _tex_cache[monster_id]
	var p: = art_path(monster_id)
	var tex: Texture2D = null
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	if tex == null:
		# Graceful fallback crest if texture hasn't been imported yet
		var img: = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color("#140F1C"))
		for y in 128:
			for x in 128:
				var d: = Vector2(x - 64.0, y - 64.0).length()
				if d < 54.0 and d > 44.0:
					img.set_pixel(x, y, Color("#E8C47E"))
				elif d <= 44.0:
					var k: = 1.0 - d / 44.0
					img.set_pixel(x, y, Color(0.55 * k + 0.12, 0.18 * k + 0.08, 0.35 * k + 0.14, 1.0))
		tex = ImageTexture.create_from_image(img)
	_tex_cache[monster_id] = tex
	return tex


static func board_cfg(stage_idx: int, wave: int = 0) -> Dictionary:
	var m: Dictionary = monster_at(stage_idx)
	var b: Dictionary = (m.board as Dictionary).duplicate(true)
	b["name"] = String(m.name)
	b["bg"] = String(m.bg)
	b["fx"] = String(m.fx)
	b["seed"] = int(b.get("seed", 7000)) + wave * 997
	if wave > 0:
		b["gold"] = int(b.get("gold", 4)) + 2
	b["hidden"] = false
	b["mech"] = ""
	b["hard"] = 1 if bool(m.boss) else 0
	return b


# ── Pure Combat Math ──────────────────────────────────────────────────────────

static func calc_pair_damage(combo: int, is_gold: bool, hero_id: String = "mc") -> Dictionary:
	var c: = maxi(1, combo)
	var step_bonus: = COMBO_STEP * (1.15 if hero_id == "hana" else 1.0)
	var combo_mult: = 1.0 + float(mini(c - 1, COMBO_CAP)) * step_bonus
	var dmg_f: = float(BASE_PAIR_DMG) * combo_mult
	var crit: = is_gold
	if crit:
		var cm: = GOLD_CRIT_MULT * (1.20 if hero_id == "yue" else 1.0)
		dmg_f *= cm
	var dmg: = int(round(dmg_f))
	if hero_id == "nova":
		dmg += 4
	var ult_base: = 26 if crit else (14 + mini(c - 1, 4) * 2)
	if hero_id == "mc":
		ult_base = int(round(float(ult_base) * 1.20))
	var heal: = 6 if (crit and hero_id == "rin") else 0
	return {
		"damage": maxi(1, dmg),
		"crit": crit,
		"ult_gain": ult_base,
		"heal": heal,
		"combo_mult": combo_mult,
	}


static func calc_ult_damage(stage_idx: int, hero_id: String = "mc") -> Dictionary:
	var s: = clampi(stage_idx, 0, MONSTERS.size() - 1)
	var dmg: = 115 + s * 15
	if hero_id == "hana" or hero_id == "yue":
		dmg += 15
	elif hero_id == "nova":
		dmg += 10
	var heal: = ULT_HEAL + (10 if hero_id == "rin" else 0)
	return {
		"damage": dmg,
		"stun_turns": ULT_STUN_TURNS,
		"heal": heal,
	}


static func calc_monster_attack(stage_idx: int, overflow: bool = false) -> int:
	var m: Dictionary = monster_at(stage_idx)
	var base_atk: = int(m.atk)
	if overflow:
		return int(round(float(base_atk) * 1.25))
	return base_atk


# ── Save Persistence (G.S["v10_adventure"]) ───────────────────────────────────

static func defaults() -> Dictionary:
	return {
		"stage": 0,
		"cleared": [],
		"best_stage": 0,
		"wins": 0,
		"defeats": 0,
		"damage_total": 0,
	}


static func ensure(S: Dictionary) -> Dictionary:
	if not (S.get(SAVE_KEY) is Dictionary):
		S[SAVE_KEY] = defaults()
	var d: Dictionary = S[SAVE_KEY]
	var df: = defaults()
	for k in df:
		if not d.has(k):
			d[k] = df[k].duplicate(true) if (df[k] is Array or df[k] is Dictionary) else df[k]
	if not (d.get("cleared") is Array):
		d["cleared"] = []
	d["stage"] = clampi(int(d.get("stage", 0)), 0, MONSTERS.size() - 1)
	d["best_stage"] = clampi(int(d.get("best_stage", 0)), 0, MONSTERS.size())
	d["wins"] = maxi(0, int(d.get("wins", 0)))
	d["defeats"] = maxi(0, int(d.get("defeats", 0)))
	d["damage_total"] = maxi(0, int(d.get("damage_total", 0)))
	return d


static func _live_save() -> Dictionary:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.get("S") is Dictionary:
		return g.S
	return {}


static func st(S = null) -> Dictionary:
	var root: Dictionary = S if S is Dictionary else _live_save()
	return ensure(root)


static func is_stage_unlocked(stage_idx: int, S = null) -> bool:
	var d: = st(S)
	return stage_idx >= 0 and stage_idx < MONSTERS.size() and stage_idx <= int(d.best_stage)


static func is_stage_cleared(stage_idx: int, S = null) -> bool:
	var d: = st(S)
	var m_id: = String(monster_at(stage_idx).id)
	return m_id in (d.cleared as Array)


static func record_win(stage_idx: int, damage_dealt: int, S = null) -> Dictionary:
	var d: = st(S)
	var idx: = clampi(stage_idx, 0, MONSTERS.size() - 1)
	var m: Dictionary = monster_at(idx)
	var m_id: = String(m.id)
	var cleared: Array = d.cleared
	var first_clear: = not (m_id in cleared)
	if first_clear:
		cleared.append(m_id)
	d["wins"] = int(d.wins) + 1
	d["damage_total"] = int(d.damage_total) + maxi(0, damage_dealt)
	d["best_stage"] = maxi(int(d.best_stage), mini(idx + 1, MONSTERS.size()))
	var next_idx: = mini(idx + 1, MONSTERS.size() - 1)
	d["stage"] = next_idx
	var k: = 1.0 if first_clear else 0.4
	return {
		"first_clear": first_clear,
		"gems": maxi(5, int(round(float(m.gems) * k))),
		"coins": maxi(25, int(round(float(m.coins) * k))),
		"aff": maxi(2, int(round(float(m.aff) * k))),
		"next_stage": next_idx,
		"has_next": idx + 1 < MONSTERS.size(),
	}


static func record_defeat(damage_dealt: int, S = null) -> void:
	var d: = st(S)
	d["defeats"] = int(d.defeats) + 1
	d["damage_total"] = int(d.damage_total) + maxi(0, damage_dealt)


# ── Hub Card Metadata for tables_hub.gd ───────────────────────────────────────

static func hub_card_info(S = null) -> Dictionary:
	var d: = st(S)
	var cur: = clampi(int(d.stage), 0, MONSTERS.size() - 1)
	var m: Dictionary = monster_at(cur)
	var cleared_n: = (d.cleared as Array).size()
	return {
		"id": SCREEN_ID,
		"screen": SCREEN_ID,
		"title": "Приключение: Битва с монстрами",
		"short_title": "Битва с монстрами",
		"subtitle": "Этап %d/%d · %s" % [cur + 1, MONSTERS.size(), String(m.name)],
		"badge": "БОСС" if bool(m.boss) else "ЁКАЙ",
		"stage": cur,
		"cleared": cleared_n,
		"total": MONSTERS.size(),
		"open": true,
		"monster_id": String(m.id),
		"art": art_path(String(m.id)),
		"accent": m.accent,
	}
