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
const ULT_VIDEO_DIR: = "res://assets/v10/ult_video"
const CG_16_DIR: = "res://assets/v10/cg_16"

const HERO_ULTS: = {
	"mc": {"title": "Цветение Тысячи Костей", "accent": Color("#FFB86C")},
	"rin": {"title": "Алый Шёлк Полнолуния", "accent": Color("#FF6B8B")},
	"hana": {"title": "Пламенный Рывок Бури", "accent": Color("#FF8E53")},
	"yue": {"title": "Приговор Лунного Зеркала", "accent": Color("#B89CFF")},
	"nova": {"title": "Квантовый Разлом Небес", "accent": Color("#6CE6FF")},
}

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
		"shield_max": 60,
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
		"shield_max": 70,
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
		"shield_max": 90,
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
		"shield_max": 100,
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
		"shield_max": 120,
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
		"shield_max": 140,
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

# ── 0.12 Squad of 3 goddesses + Boss Shield Break ─────────────────────────────

const SQUAD_SIZE: = 3
const DEFAULT_SQUAD: = ["mc", "rin", "yue"]
const SHIELD_PAIR: = 12
const SHIELD_GOLD: = 25
const SHIELD_ULT: = 45
const BREAK_TURNS: = 3
const BREAK_MULT: = 2
const BREAK_STUN: = 1
const AFF_SCRIPT_PATH: = "res://core/economy/affection_curve.gd"
const ONLINE_SCRIPT_PATH: = "res://scripts/v10/online/online_client.gd"
const WAVE1_EMO_DIR: = "res://assets/v10/wave1/emotions"

# Passive bonus of a goddess standing in a support slot (a Wave-1 lead uses it too).
# Keys: dmg_flat (+N to each pair), dmg_mult (+fraction of damage), crit_add (+gold crit multiplier),
# combo_step_add (+combo step), ult_gain_flat (+N ult charge per pair), heal_gold (+HP on a gold pair),
# ult_dmg_flat (+N ult damage), shield_flat (+N shield damage per pair and ult), shield_gold (+N on gold pairs),
# shield_mult (+fraction of all shield damage).
const SUPPORT_PERKS: = {
	"mc": {"name": "Заряд хозяйки", "desc": "+2 к заряду ульты за каждую пару", "ult_gain_flat": 2},
	"rin": {"name": "Чайное тепло", "desc": "Золотая пара лечит +3 HP", "heal_gold": 3},
	"hana": {"name": "Ритм забега", "desc": "Комбо растёт быстрее: +0.05 за шаг", "combo_step_add": 0.05},
	"yue": {"name": "Лунный прицел", "desc": "Золотой крит сильнее на +0.15", "crit_add": 0.15},
	"nova": {"name": "Пробой защиты", "desc": "+3 урона к каждой паре", "dmg_flat": 3},
	"tsubame": {"name": "Теневой надрез", "desc": "+3 к урону по щиту за пару", "shield_flat": 3},
	"miel": {"name": "Сахарная искра", "desc": "+3 к заряду ульты за пару", "ult_gain_flat": 3},
	"kohaku": {"name": "Лисий огонь", "desc": "Ульта бьёт на +12 сильнее", "ult_dmg_flat": 12},
	"shirin": {"name": "Танец монет", "desc": "Золотая пара: +6 к урону по щиту", "shield_gold": 6},
	"zlata": {"name": "Жар-птица", "desc": "+2 урона и +2 по щиту за пару", "dmg_flat": 2, "shield_flat": 2},
}

# Specific synergies first (the first match wins), the universal Trio last. "all" = every id must be in the squad,
# "any" = at least one of these ids must be in the squad. Bonus keys are the same as SUPPORT_PERKS.
const SQUAD_SYNERGIES: Array[Dictionary] = [
	{"id": "salon_owners", "name": "Хозяйки Салона", "desc": "Урон пар +0.12", "all": ["mc", "rin"], "any": [], "bonus": {"dmg_mult": 0.12}},
	{"id": "moon_storm", "name": "Лунный Шторм", "desc": "Золотой крит +0.30", "all": ["yue", "nova"], "any": [], "bonus": {"crit_add": 0.30}},
	{"id": "fire_east", "name": "Огонь Востока", "desc": "Щит боса ломается быстрее: +0.35", "all": ["hana"], "any": ["zlata", "kohaku"], "bonus": {"shield_mult": 0.35}},
	{"id": "night_swallows", "name": "Сладкая Доставка", "desc": "+4 к заряду ульты за пару", "all": ["tsubame", "miel"], "any": [], "bonus": {"ult_gain_flat": 4}},
	{"id": "temple_caravan", "name": "Храм и Караван", "desc": "Золотая пара лечит +4 HP, ульта +10", "all": ["kohaku", "shirin"], "any": [], "bonus": {"heal_gold": 4, "ult_dmg_flat": 10}},
	{"id": "trio_harmony", "name": "Трио Гармонии", "desc": "Любые три богини: урон +0.06, щит +0.10", "all": [], "any": [], "trio": true, "bonus": {"dmg_mult": 0.06, "shield_mult": 0.10}},
]

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
		var gp: = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var raw: = Image.load_from_file(gp)
			if raw != null and not raw.is_empty():
				tex = ImageTexture.create_from_image(raw)
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

static func calc_pair_damage(combo: int, is_gold: bool, hero_id: String = "mc", mods: Dictionary = {}) -> Dictionary:
	var c: = maxi(1, combo)
	var step_bonus: float = COMBO_STEP * (1.15 if hero_id == "hana" else 1.0) + float(mods.get("combo_step_add", 0.0))
	var combo_mult: float = 1.0 + float(mini(c - 1, COMBO_CAP)) * step_bonus
	var dmg_f: float = float(BASE_PAIR_DMG) * combo_mult
	var crit: = is_gold
	if crit:
		var cm: float = GOLD_CRIT_MULT * (1.20 if hero_id == "yue" else 1.0) + float(mods.get("crit_add", 0.0))
		dmg_f *= cm
	dmg_f *= 1.0 + float(mods.get("dmg_mult", 0.0))
	var dmg: = int(round(dmg_f))
	if hero_id == "nova":
		dmg += 4
	dmg += int(mods.get("dmg_flat", 0))
	var ult_base: = 26 if crit else (14 + mini(c - 1, 4) * 2)
	if hero_id == "mc":
		ult_base = int(round(float(ult_base) * 1.20))
	ult_base = int(round(float(ult_base) * (1.0 + float(mods.get("ult_gain_mult", 0.0))))) + int(mods.get("ult_gain_flat", 0))
	var heal: = 6 if (crit and hero_id == "rin") else 0
	if crit:
		heal += int(mods.get("heal_gold", 0))
	var sh: = (SHIELD_GOLD if crit else SHIELD_PAIR) + int(mods.get("shield_flat", 0))
	if crit:
		sh += int(mods.get("shield_gold", 0))
	sh = maxi(1, int(round(float(sh) * (1.0 + float(mods.get("shield_mult", 0.0))))))
	return {
		"damage": maxi(1, dmg),
		"crit": crit,
		"ult_gain": ult_base,
		"heal": heal,
		"combo_mult": combo_mult,
		"shield": sh,
	}


static func calc_ult_damage(stage_idx: int, hero_id: String = "mc", mods: Dictionary = {}) -> Dictionary:
	var s: = clampi(stage_idx, 0, MONSTERS.size() - 1)
	var dmg: = 115 + s * 15
	if hero_id == "hana" or hero_id == "yue":
		dmg += 15
	elif hero_id == "nova":
		dmg += 10
	dmg += int(mods.get("ult_dmg_flat", 0))
	dmg = int(round(float(dmg) * (1.0 + float(mods.get("dmg_mult", 0.0)))))
	var heal: = ULT_HEAL + (10 if hero_id == "rin" else 0)
	var sh: = maxi(1, int(round(float(SHIELD_ULT + int(mods.get("shield_flat", 0))) * (1.0 + float(mods.get("shield_mult", 0.0))))))
	return {
		"damage": dmg,
		"stun_turns": ULT_STUN_TURNS,
		"heal": heal,
		"shield": sh,
	}


# ── Squad: passives, synergies, affection bonuses ─────────────────────────────

static func hero_exists(hero_id: String) -> bool:
	return SUPPORT_PERKS.has(hero_id)


static func hero_available(hero_id: String) -> bool:
	if not SUPPORT_PERKS.has(hero_id):
		return false
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g == null:
		return true
	if not (g.get("HEROES") is Dictionary) or not (g.HEROES as Dictionary).has(hero_id):
		return false
	if g.has_method("hero_unlocked"):
		return bool(g.call("hero_unlocked", hero_id))
	return true


static func hero_name(hero_id: String) -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.get("HEROES") is Dictionary and (g.HEROES as Dictionary).has(hero_id):
		return String(g.HEROES[hero_id].name)
	if V10W1Core.HEROES.has(hero_id):
		return String(V10W1Core.HEROES[hero_id].name)
	return hero_id.capitalize()


static func hero_portrait(hero_id: String) -> Texture2D:
	var p: = "%s/%s_happy.webp" % [WAVE1_EMO_DIR, hero_id]
	if hero_id in ["tsubame", "miel", "kohaku", "shirin", "zlata"]:
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
		var gp: = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var im: = Image.load_from_file(gp)
			if im != null and not im.is_empty():
				return ImageTexture.create_from_image(im)
		return null
	return V8Art.emotion(hero_id, "happy")


static func normalize_squad(squad_in, lead_id: String = "", pad: bool = true) -> Array:
	var out: Array = []
	if lead_id != "" and hero_exists(lead_id):
		out.append(lead_id)
	if squad_in is Array:
		for v in (squad_in as Array):
			var h: = String(v)
			if hero_exists(h) and not (h in out) and out.size() < SQUAD_SIZE:
				out.append(h)
	if not pad:
		return out
	for h in DEFAULT_SQUAD:
		if out.size() < SQUAD_SIZE and not (h in out):
			out.append(h)
	for h in SUPPORT_PERKS.keys():
		if out.size() < SQUAD_SIZE and not (h in out):
			out.append(h)
	return out


# The squad that actually fights: the lead + saved supports she owns, topped up from owned heroines
# (a new player with only one goddess fights with fewer supports; an empty slot gives no bonus).
static func effective_squad(lead_id: String, S = null) -> Array:
	var saved: Array = squad_for_lead(lead_id, S)
	var out: Array = [String(saved[0])]
	for i in range(1, saved.size()):
		var h: = String(saved[i])
		if hero_available(h) and not (h in out):
			out.append(h)
	for h in SUPPORT_PERKS.keys():
		if out.size() < SQUAD_SIZE and hero_available(String(h)) and not (String(h) in out):
			out.append(String(h))
	return out


static func perk_of(hero_id: String) -> Dictionary:
	return SUPPORT_PERKS.get(hero_id, {})


static func active_synergy(squad: Array) -> Dictionary:
	var ids: Array = []
	for v in squad:
		if not (String(v) in ids):
			ids.append(String(v))
	for syn in SQUAD_SYNERGIES:
		if bool(syn.get("trio", false)):
			if ids.size() >= SQUAD_SIZE:
				return syn
			continue
		var ok: = true
		for need in (syn.all as Array):
			if not (String(need) in ids):
				ok = false
		var any_l: Array = syn.any
		if ok and not any_l.is_empty():
			var hit: = false
			for a in any_l:
				if String(a) in ids:
					hit = true
			ok = hit
		if ok:
			return syn
	return {}


static func _add_mods(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		if k == "name" or k == "desc":
			continue
		dst[k] = float(dst.get(k, 0.0)) + float(src[k])


# Aggregated bonus dict for a squad [lead, support1, support2] (+ optional affection bonuses of the lead).
static func squad_mods(squad: Array, aff: Dictionary = {}) -> Dictionary:
	var mods: Dictionary = {}
	if squad.is_empty():
		return mods
	for i in squad.size():
		var h: = String(squad[i])
		if i == 0 and HERO_PERKS.has(h):
			continue
		_add_mods(mods, perk_of(h))
	var syn: = active_synergy(squad)
	if not syn.is_empty():
		_add_mods(mods, syn.bonus as Dictionary)
	if not aff.is_empty():
		_add_mods(mods, {
			"dmg_mult": float(aff.get("atk_bonus", 0.0)),
			"crit_add": float(aff.get("crit_bonus", 0.0)) * 2.0,
			"ult_gain_mult": float(aff.get("ult_haste", 0.0)),
		})
	return mods


# Optional V10AffCurve milestone bonuses of one heroine ({} when the module is absent).
static func aff_bonuses(hero_id: String) -> Dictionary:
	if not ResourceLoader.exists(AFF_SCRIPT_PATH):
		return {}
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("G") == null:
		return {}
	return V10AffCurve.bonuses_for_level(V10AffCurve.hero_level(hero_id))



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
		"squad": DEFAULT_SQUAD.duplicate(),
		"best_raid_dmg": 0,
		"raid_stage_best": {},
		"shield_breaks": 0,
		"squad_custom": false,
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
	d["squad"] = normalize_squad(d.get("squad"))
	d["best_raid_dmg"] = maxi(0, int(d.get("best_raid_dmg", 0)))
	d["shield_breaks"] = maxi(0, int(d.get("shield_breaks", 0)))
	d["squad_custom"] = bool(d.get("squad_custom", false))
	if not (d.get("raid_stage_best") is Dictionary):
		d["raid_stage_best"] = {}
	return d


static func get_squad(S = null) -> Array:
	return (st(S).squad as Array).duplicate()


static func set_squad(squad_in: Array, S = null) -> Array:
	var d: = st(S)
	d["squad"] = normalize_squad(squad_in)
	d["squad_custom"] = true
	return (d.squad as Array).duplicate()


# [lead, support1, support2]: the saved squad with the chosen lead rotated to the front.
static func squad_for_lead(lead_id: String, S = null) -> Array:
	var d: = st(S)
	var lead: = lead_id if hero_exists(lead_id) else String((d.squad as Array)[0])
	var others: Array = []
	for h in (d.squad as Array):
		if String(h) != lead:
			others.append(String(h))
	return normalize_squad([lead] + others, lead)


# Boss Raid score: the best damage dealt in one fight (overall and per stage).
static func record_raid(stage_idx: int, damage: int, breaks: int = 0, S = null) -> Dictionary:
	var d: = st(S)
	var dmg: = maxi(0, damage)
	var key: = String(monster_at(stage_idx).id)
	var per: Dictionary = d.raid_stage_best
	var prev_stage: = int(per.get(key, 0))
	var new_stage_best: = dmg > prev_stage
	if new_stage_best:
		per[key] = dmg
	var new_best: = dmg > int(d.best_raid_dmg)
	if new_best:
		d["best_raid_dmg"] = dmg
	d["shield_breaks"] = int(d.shield_breaks) + maxi(0, breaks)
	return {"new_best": new_best, "new_stage_best": new_stage_best, "best": int(d.best_raid_dmg), "stage_best": int(per.get(key, 0))}


# Soft hook: sends the score to the server when the online client exists and the player is logged in.
# Expected client API (duck-typed, optional): static is_logged_in() -> bool, static submit_raid_score(stage_idx, damage).
static var _online_mock = null


static func online_api():
	if _online_mock != null:
		return _online_mock
	if ResourceLoader.exists(ONLINE_SCRIPT_PATH):
		return load(ONLINE_SCRIPT_PATH)
	return null


static func submit_raid_score(stage_idx: int, damage: int) -> bool:
	var api = online_api()
	if api == null or damage <= 0:
		return false
	if api.has_method("is_logged_in") and not bool(api.call("is_logged_in")):
		return false
	if not api.has_method("submit_raid_score"):
		return false
	api.call("submit_raid_score", stage_idx, damage)
	return true


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


static func record_win(stage_idx: int, damage_dealt: int, S = null, breaks: int = 0) -> Dictionary:
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
	var raid: = record_raid(idx, damage_dealt, breaks, S)
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
		"raid": raid,
	}


static func record_defeat(damage_dealt: int, S = null, breaks: int = 0, stage_idx: int = 0) -> Dictionary:
	var d: = st(S)
	d["defeats"] = int(d.defeats) + 1
	d["damage_total"] = int(d.damage_total) + maxi(0, damage_dealt)
	return record_raid(stage_idx, damage_dealt, breaks, S)


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


# ── Ultimate Video & CG Resolvers ──────────────────────

static func ult_video_path(hero_id: String, equipped_id: String = "") -> String:
	var cands: Array[String] = []
	if equipped_id != "":
		cands.append("%s/%s.ogv" % [ULT_VIDEO_DIR, equipped_id])
		if equipped_id in ["y_queen", "y_ball", "o_queen"]:
			cands.append("%s/yue_queen.ogv" % ULT_VIDEO_DIR)
		elif equipped_id in ["n_ssr", "n_offline", "o_roof"]:
			cands.append("%s/nova_roof.ogv" % ULT_VIDEO_DIR)
		elif equipped_id == "o_base" and hero_id == "mc":
			cands.append("%s/mc_base.ogv" % ULT_VIDEO_DIR)
	cands.append("%s/%s.ogv" % [ULT_VIDEO_DIR, hero_id])
	for p in cands:
		if ResourceLoader.exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			return p
	return ""


static func ult_cg_texture(hero_id: String, equipped_id: String = "") -> Texture2D:
	var cands: Array[String] = []
	if equipped_id == "o_roof":
		cands.append("%s/nova_roof.webp" % CG_16_DIR)
	elif equipped_id == "o_base" and hero_id == "mc":
		cands.append("%s/mc_base.webp" % CG_16_DIR)
	cands.append("%s/%s.webp" % [CG_16_DIR, hero_id])
	cands.append("res://assets/hero/%s.png" % hero_id)
	for p in cands:
		if ResourceLoader.exists(p):
			var t: = load(p) as Texture2D
			if t != null:
				return t
		var gp: = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var im: = Image.load_from_file(gp)
			if im != null and not im.is_empty():
				return ImageTexture.create_from_image(im)
	return null
