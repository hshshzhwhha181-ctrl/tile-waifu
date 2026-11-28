class_name V10W1Mj
extends RefCounted

# V10W1Mj — the five wave-1 goddesses at the mahjong tables (lane 4 «Волна 1», owner: mj builder).
# Pure data + small static helpers. Nothing here is gated: every consumer reads it only behind V10Wave1.released()
# (the hooks are listed in the lane report; founders stay byte-identical when wave 1 is off).
#
# Mirrors, table by table (founder entry = template):
#   RIICHI_STYLES     ↔ V8AI.STYLES (v08/table/ai.gd)            AI personality at «Стол на четверых» / «Лунный стол»
#   V10W1MjLines.RIICHI ↔ V10MjRiichiBarks.LINES                 rival subtitles (10 table events)
#   riichi_face_tex() ↔ V10MjRiichiPortrait.NEUTRAL_C / EMO_C    round seat portrait crops (from the art JSONs)
#   COLOR / NAME      ↔ V10MjRiichiData.HERO_COLOR / HERO_NAME, V10MjKoikoiLines.ACCENT / NAME, sanma ACCENT / NAMES
#   POSE_KEYS         ↔ V10MjStageData.POSE_KEYS                 (docs/POSES.md §0.5)
#   V10W1MjLines.STAGE ↔ V10MjStageLines.LINES                   presence lines + table calls
#   KOIKOI_STYLES     ↔ V10MjKoikoiAI.STYLES (+ "koi": her «Кои-кои!» policy, see koikoi_decide())
#   V10W1MjLines.KOIKOI ↔ V10MjKoikoiLines.LINES;  koikoi_frame() ↔ V10MjKoikoiLines.FRAME
#   TRIPLES_ACCENT / TRIPLES_TRAY / TRIPLES_TABLE ↔ V10MjTriplesLook.ACCENT / HERO_TRAY / HERO_TABLE
#   SIG               ↔ V10MjTriplesPresence.SIGNATURE (G.TILE_NAMES index, = V10Look kit «sig»)
#   V10W1MjLines.TRIPLES ↔ V10MjTriplesPresence.LINES;  TRIPLES_CHAPTER_HOST ↔ V10MjTriplesGen.CHAPTER_HOST
#   SANMA_ACCENT      ↔ sanma_screen.gd ACCENT;  sanma_region() ↔ PORTRAIT_REGION
#   TABLE_THEME       → V10MjTables.THEMES ids (the records already exist in v10/mj/look; table art = look lane)
#   KOIKOI_RIVALS / KOIKOI_HOST → V10MjKoikoiInfo.INFO.rivals / host (MODES §1: «Рин (потом Кохаку)»)
#
# Not here, on purpose: Пагода / Странствие (v10/tower already carries BOSS, STYLE and BLESS rows for all five, shown
# once they are in G.HEROES), Дуэли (v06 heroines_data RIVALS / DUEL_LINES — lane play), triples ults (lane ults),
# heroine tables and dora crests (art, lane look), voices (lane audio).

const IDS: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]

const NAME: = {"tsubame": "Цубамэ", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "zlata": "Злата"}

# her colour in every mj screen = G.HEROES[*].color (brief: first palette hex, tsubame/miel take their readable accent)
const COLOR: = {"tsubame": Color("c8283c"), "miel": Color("e0566f"), "kohaku": Color("f3efe9"), "shirin": Color("d9b26f"),
	"zlata": Color("c3242b")}

# signature tile (G.TILE_NAMES index; = V10Look kit «sig» and V10MjTables «sig»): plum, cake, fox, sun, fire
const SIG: = {"tsubame": 1, "miel": 16, "kohaku": 31, "shirin": 9, "zlata": 12}

# ---------------------------------------------------------------- «Стол на четверых» / «Лунный стол» (V8AI.STYLES)
# call = how often she opens, riichi = appetite for «Готов», defense = folding under threat, skill = discard accuracy
# (× hall skill), value = love of expensive hands, speed = 0.85 slow … 1.2 fast (AI pause 0.9 … 0.35 s).
const RIICHI_STYLES: = {
	"tsubame": {"call": 0.6, "riichi": 0.7, "defense": 0.75, "skill": 0.92, "value": 0.5, "speed": 1.15, "name": "Ночной курьер",
		"desc": "Быстрая дешёвая рука и выверенный сброс: в опасную фишку не шагнёт."},
	"miel": {"call": 0.5, "riichi": 0.6, "defense": 0.4, "skill": 0.8, "value": 0.75, "speed": 0.95, "name": "Щедрая рука",
		"desc": "Играет мягко: собирает красивые руки и порой угощает соперниц сбросом."},
	"kohaku": {"call": 0.7, "riichi": 0.95, "defense": 0.35, "skill": 0.86, "value": 0.95, "speed": 1.05, "name": "Лисья игра",
		"desc": "Рискует с улыбкой: готовность на удачу и азарт до конца раздачи."},
	"shirin": {"call": 0.25, "riichi": 0.55, "defense": 1.0, "skill": 0.95, "value": 0.9, "speed": 0.85, "name": "Звёздный расклад",
		"desc": "Читает стол наперёд: чует опасную фишку и вовремя сворачивает руку."},
	"zlata": {"call": 0.4, "riichi": 0.95, "defense": 0.3, "skill": 0.9, "value": 1.15, "speed": 1.0, "name": "Царский размах",
		"desc": "Идёт за большой рукой и давит готовностью: отступать не в её правилах."},
}

# ---------------------------------------------------------------- stage: POSES.md §0.5 silhouette keys (match slots)
const POSE_KEYS: = {
	"tsubame": {"idle": "ridge-tightrope-read-letter", "select": "profile-tuck-leap-letter", "win": "ridge-one-knee-landing",
		"lose": "roof-slope-knees-up-retie", "shy": "letter-for-me-arms-length"},
	"miel": {"idle": "bowl-on-hip-whisk", "select": "piping-cupcake-hip-sway", "win": "tray-forward-curtsy-dip",
		"lose": "souffle-horror-hands-cheeks", "shy": "cakebox-hug-chin-on-lid"},
	"kohaku": {"idle": "stair-split-level-wand-yoke", "select": "pillar-peek-tail-gives-away", "win": "airborne-heels-back-sleeves-flared",
		"lose": "steps-legs-long-tail-hug", "shy": "head-offer-pigeon-toe-tail-wag"},
	"shirin": {"idle": "lamp-on-head-snake-arms", "select": "promenade-veil-sweep", "win": "pirouette-retire-coin-spray",
		"lose": "cushion-side-fold-forearm-brow", "shy": "coin-strand-curtain-peek"},
	"zlata": {"idle": "frontal-mantle-braid-candle", "select": "folk-heel-step-arm-sweep", "win": "sunburst-V-tiptoe",
		"lose": "wet-firebird-cape-drooped", "shy": "turnaway-dip-pancake-plate"},
}

# ---------------------------------------------------------------- «Коикои» (V10MjKoikoiAI.STYLES)
# light / combo / defense / take / noise / slip as the founders; hold_light («держит месяц, где свет ещё в игре»).
# Measured (hooked AI × AI, 600 games, founders as rivals): «Кои-кои!» rate Цубамэ ≈ 0 %, Ширин ≈ 10 %, Миэль ≈ 30 %,
# Кохаку ≈ 40 %, Злата ≈ 45 % (founders: Рин 4 %, Нова 31 %, Хана 90 %).
# koi = her «Кои-кои!» decision (koikoi_decide): {p, max_s, left, threat} = «continue with chance p while the score is
# ≤ max_s, ≥ left cards remain and the rival's threat < threat»; mode "reader" = expected value, like Нова, but warier.
#   tsubame — fast and precise: takes early, rarely presses on;     miel — generous: soft play, a slip now and then;
#   kohaku  — trickster: noisy picks, presses her luck;             shirin — reads ahead: counts cards, defends, expected value;
#   zlata   — regal: hunts the lights (keeps a month whose light is still out) and doubles boldly.
const KOIKOI_STYLES: = {
	"tsubame": {"name": "Цубамэ", "light": 1.0, "combo": 1.2, "defense": 1.3, "take": 1.4, "noise": 0.15, "slip": 0.0,
		"koi": {"p": 0.35, "max_s": 2, "left": 4, "threat": 0.35}},
	"miel": {"name": "Миэль", "light": 1.0, "combo": 1.0, "defense": 0.5, "take": 1.1, "noise": 1.0, "slip": 0.1,
		"koi": {"p": 0.6, "max_s": 6, "left": 2, "threat": 0.7}},
	"kohaku": {"name": "Кохаку", "light": 1.5, "combo": 1.1, "defense": 0.6, "take": 0.7, "noise": 1.4, "slip": 0.0,
		"koi": {"p": 0.78, "max_s": 6, "left": 2, "threat": 0.8}},
	"shirin": {"name": "Ширин", "light": 1.2, "combo": 1.0, "defense": 1.6, "take": 0.9, "noise": 0.1, "slip": 0.0,
		"koi": {"mode": "reader", "left": 3, "fear": 0.8, "edge": 1.25}},
	"zlata": {"name": "Злата", "light": 2.8, "combo": 1.2, "defense": 0.45, "take": 0.6, "noise": 0.4, "slip": 0.0, "hold_light": 2.5,
		"koi": {"p": 0.85, "max_s": 7, "left": 2, "threat": 0.8}},
}
const KOIKOI_RIVALS: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const KOIKOI_HOST: = "kohaku"

# ---------------------------------------------------------------- «Тройки» (V10MjTriplesLook)
# accent / glow / deep: accent = her colour, glow = V10Look kit glow; deep is the dark ground under her window and
# the strip gradient (founders: 6a1f45 … 0f3a5a), so it is the kit «deep» where that is dark (tsubame, zlata) and the
# kit hue taken down to the founders' depth where it is not: miel caramel c98a4b → 64452a, shirin teal 1f8f8a → 114f4c,
# kohaku (kit «deep» = her white) → the lacquer of her table tray 8a1f17 (V10MjTables.THEMES.kohaku.tray.a)
const TRIPLES_ACCENT: = {
	"tsubame": [Color("c8283c"), Color("e6a0aa"), Color("1d1b2e")],
	"miel": [Color("e0566f"), Color("f6e7cf"), Color("64452a")],
	"kohaku": [Color("f3efe9"), Color("e2a23d"), Color("8a1f17")],
	"shirin": [Color("d9b26f"), Color("f6e3b8"), Color("114f4c")],
	"zlata": [Color("c3242b"), Color("ffd08a"), Color("8e1a14")],
}
# tray frame (V10MjTriplesLook.TRAYS key): night lacquer, tea tray, shrine lacquer, the moon boat of a star tent,
# the painted lacquer box (ROSTER: «Стол: расписная лаковая шкатулка»)
const TRIPLES_TRAY: = {"tsubame": "lacquer", "miel": "tea", "kohaku": "lacquer", "shirin": "moon", "zlata": "lacquer"}
# board table (V6BoardTable theme): indigo night, rose pastry, the shrine, wood + teal felt + gold, red + gold festival
const TRIPLES_TABLE: = {"tsubame": "bg_palace", "miel": "default", "kohaku": "bg_shrine", "shirin": "play", "zlata": "bg_festival"}
# chapter hosts when wave 1 is out: each goddess takes one chapter that a founder hosted twice (founders keep ≥ 1)
const TRIPLES_CHAPTER_HOST: = ["hana", "mc", "rin", "tsubame", "yue", "nova", "miel", "kohaku", "shirin", "yue", "zlata", "hana"]

# ---------------------------------------------------------------- «Лунный стол на троих» (sanma_screen.gd ACCENT, hex)
const SANMA_ACCENT: = {"tsubame": "c8283c", "miel": "e0566f", "kohaku": "f3efe9", "shirin": "d9b26f", "zlata": "c3242b"}

# ---------------------------------------------------------------- look: her table (V10MjTables.THEMES id; S/SSR = full
# table, A = house table in her light — UX §7.3). The records live in v10/mj/look/table_themes.gd.
const TABLE_THEME: = {"tsubame": "tsubame", "miel": "miel", "kohaku": "kohaku", "shirin": "shirin", "zlata": "zlata"}
const RANK: = {"tsubame": "A", "miel": "A", "kohaku": "S", "shirin": "S", "zlata": "SSR"}

# ---------------------------------------------------------------- art (lane 4 layout, loaded at runtime)
const ART_DIR: = "res://assets/v10/wave1/"
const CARDS_JSON: = "res://core/wave1/data/w1_art_cards.json"
const RIG_JSON: = "res://core/wave1/data/w1_art_rig.json"
const HERO_SIZE: = Vector2(848, 1264)
# when the art JSONs are not in yet: founders' averages on the same canvases (848×1264 cut-out, ≈600×800 emotion)
const NEUTRAL_FALLBACK: = Vector2(420, 190)
const FACE_FALLBACK: = Vector2(300, 210)
const FACE_W_FALLBACK: = 150.0


static func has(id: String) -> bool:
	return NAME.has(id)


static func hero_name(id: String) -> String:
	return String(NAME.get(id, ""))


static func color(id: String) -> Color:
	return COLOR.get(id, Color("e8c47e"))


# full-body cut-out: wave-1 path for the five, the founders' path otherwise (safe to call without the gate)
static func hero_png(id: String) -> String:
	if has(id):
		return ART_DIR + "hero/%s.png" % id
	return "res://assets/hero/%s.png" % id


# waist-up emotion frame (happy, sad, surprised, pout, shy)
static func emo_path(id: String, emo: String) -> String:
	if has(id):
		return ART_DIR + "emotions/%s_%s.webp" % [id, emo]
	return "res://assets/v08/emotions/%s_%s.webp" % [id, emo]


static func riichi_style(id: String) -> Dictionary:
	return RIICHI_STYLES.get(id, {})


static func riichi_bark(id: String, ev: String) -> String:
	return String(V10W1MjLines.RIICHI.get(id, {}).get(ev, ""))


static func stage_variants(id: String, ev: String) -> Array:
	return (V10W1MjLines.STAGE.get(id, {}) as Dictionary).get(ev, [])


static func pose_key(id: String, slot: String) -> String:
	return String((POSE_KEYS.get(id, {}) as Dictionary).get(slot, ""))


static func koikoi_line(kind: String, id: String) -> String:
	return String(V10W1MjLines.KOIKOI.get(kind, {}).get(id, ""))


static func triples_line(kind: String, id: String) -> String:
	return String(V10W1MjLines.TRIPLES.get(kind, {}).get(id, ""))


static func triples_accent(id: String) -> Array:
	return TRIPLES_ACCENT.get(id, [])


# INFO of «Коикои» with wave 1 out: Кохаку hosts the card (MODES §1), the five join the rivals
static func koikoi_info(base: Dictionary) -> Dictionary:
	var d: = base.duplicate(true)
	d.host = KOIKOI_HOST
	var rv: Array = d.get("rivals", []).duplicate()
	for id in KOIKOI_RIVALS:
		if not id in rv:
			rv.append(id)
	d.rivals = rv
	return d


# ---------------------------------------------------------------- «Кои-кои!» decision for the five
static func koikoi_decide(k: V10MjKoikoi, p: int, sid: String, rng: RandomNumberGenerator) -> bool:
	var s: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[p]))
	var left: int = k.hand[p].size()
	if left == 0:
		return false
	var threat: = V10MjKoikoiAI.threat_of(k, p)
	var pol: Dictionary = (KOIKOI_STYLES.get(sid, {}) as Dictionary).get("koi", {})
	if String(pol.get("mode", "")) == "reader":
		# Ширин: the future she reads is the expected value — double × survive versus the bird in hand
		var up: = V10MjKoikoiAI.upside_of(k, p)
		var ev_koi: = (float(s) * 2.0 + up) * (1.0 - threat) - float(s) * threat * float(pol.get("fear", 0.8))
		return left >= int(pol.get("left", 3)) and ev_koi > float(s) * float(pol.get("edge", 1.25))
	return s <= int(pol.get("max_s", 3)) and left >= int(pol.get("left", 4)) and threat < float(pol.get("threat", 0.5)) \
		and rng.randf() < float(pol.get("p", 0.5))


# ---------------------------------------------------------------- art JSONs (art-cards / art-rig agents), read once
static var _json: = {}


static func _load_json(path: String) -> Dictionary:
	if _json.has(path):
		return _json[path]
	var d: = {}
	if FileAccess.file_exists(path):
		var p = JSON.parse_string(FileAccess.get_file_as_string(path))
		if p is Dictionary:
			d = p
	_json[path] = d
	return d


static func _rig(id: String) -> Dictionary:
	var e = _load_json(RIG_JSON).get(id, {})
	if e is Dictionary and e.get("rig") is Dictionary:
		return e.rig
	return {}


static func _emo_card(id: String, emo: String) -> Dictionary:
	var em = _load_json(CARDS_JSON).get("emotions", {})
	if em is Dictionary and em.get(id + "_" + emo) is Dictionary:
		return em[id + "_" + emo]
	return {}


static func _v2(a, fb: Vector2) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return fb


# round-avatar focus on her full-body art: rig «av» → head_c + 15 px (Hero rigs without «av») → fallback
static func neutral_center(id: String) -> Vector2:
	var r: = _rig(id)
	if r.get("av") is Array:
		return _v2(r.av, NEUTRAL_FALLBACK)
	if r.get("head_c") is Array:
		return _v2(r.head_c, NEUTRAL_FALLBACK) + Vector2(0, 15)
	return NEUTRAL_FALLBACK


# eyes-to-mouth centre on an emotion frame, in px ([fx, fy] may be fractions of the image, like V8Art.EMO_FACE)
static func emo_face(id: String, emo: String) -> Vector2:
	var c: = _emo_card(id, emo)
	var f: = _v2(c.get("face"), FACE_FALLBACK)
	if f.x <= 1.5 and f.y <= 1.5:
		f *= _v2(c.get("size"), Vector2(600, 800))
	return f


static func emo_face_w(id: String, emo: String) -> float:
	return float(_emo_card(id, emo).get("face_w", FACE_W_FALLBACK))


# riichi seat portrait (V10MjRiichiPortrait.face_tex): the founders' crop circle sits a third of a face width above
# the eyes-to-mouth point on an emotion frame, on the avatar focus on the full-body art. null = no art yet.
static func riichi_face_tex(id: String, face: String, neutral_r: float, emo_r: float) -> Texture2D:
	var path: = hero_png(id) if face == "neutral" else emo_path(id, face)
	if not ResourceLoader.exists(path):
		face = "neutral"
		path = hero_png(id)
		if not ResourceLoader.exists(path):
			return null
	var src: Texture2D = load(path)
	if src == null:
		return null
	var c: Vector2
	var rr: float
	if face == "neutral":
		c = neutral_center(id)
		rr = neutral_r
	else:
		c = emo_face(id, face) - Vector2(0, emo_face_w(id, face) * 0.33)
		rr = emo_r
	var at: = AtlasTexture.new()
	at.atlas = src
	at.region = Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
	return at


# sanma seat portrait region on an emotion frame (founders: Rect2(150, 80, 300, 300) ≈ face centre + 24 px down)
static func sanma_region(id: String, emo: String) -> Rect2:
	var f: = emo_face(id, emo)
	var sz: = _v2(_emo_card(id, emo).get("size"), Vector2(600, 800))
	var x: = clampf(f.x - 150.0, 0.0, maxf(0.0, sz.x - 300.0))
	var y: = clampf(f.y - 126.0, 0.0, maxf(0.0, sz.y - 300.0))
	return Rect2(x, y, 300, 300)


# koikoi strip frame (V10MjKoikoiLines.FRAME schema): face centre on the 848×1264 art and the top of her silhouette
# (ears, kokoshnik and hair included: the alpha bounds of the cut-out; rig head as a fallback)
static var _frames: = {}


static func koikoi_frame(id: String) -> Dictionary:
	if _frames.has(id):
		return _frames[id]
	var face: = neutral_center(id)
	var r: = _rig(id)
	var top: = 40
	if r.get("head_c") is Array:
		top = maxi(0, int(_v2(r.head_c, face).y - float(r.get("head_r", 110.0)) * 1.5))
	var p: = hero_png(id)
	if ResourceLoader.exists(p):
		var tex: Texture2D = load(p)
		var img: Image = tex.get_image() if tex else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used: = img.get_used_rect()
			if used.size.y > 0:
				top = int(used.position.y)
	var fr: = {"face": face, "top": top}
	_frames[id] = fr
	return fr


# ---------------------------------------------------------------- self-checks (the integrator's --wave1_selftest)
# every Russian line this lane shows, plus the style names
static func all_texts() -> Array:
	var out: Array = V10W1MjLines.all_ru()
	for id in RIICHI_STYLES:
		out.append(String(RIICHI_STYLES[id].name))
		out.append(String(RIICHI_STYLES[id].desc))
	for id in NAME:
		out.append(String(NAME[id]))
	return out


# substring stems of the mj consumers' own lists (riichi STOP, koikoi BANNED, sanma UI_BANNED + HERO_BANNED, triples,
# stage BANNED_UX) and the HEROINES §4 red lines. The V10Lint stems are not copied here: banned_hits() reads
# V10Lint.BANNED (+ its price stem) at runtime, so this file holds no banned stem of the brief's grep.
const BANNED_SUB: = ["гарант", "пити", "pity", "50/50", "гача", "ролл", "крутк", "фивер", "ивент", "квартал", "перк", "ульт",
	"банер", "донат", "хит", "выгодно", "best", "new", "топ-100", "богин", "ставк", "пари", "казино", "джекпот", "лихорадк",
	"риичи", "режимы", "учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр",
	"вино", "пиво", "алкогол", "раздев", "бельё", "белье"]
# word-start stems (stage BANNED_UX regex and the triples list): «бонус», «яку»
const BANNED_WORD: = ["бонус", "яку"]


static func banned_hits(text: String) -> Array:
	var low: = text.to_lower()
	var masked: = low
	var stems: Array = BANNED_SUB.duplicate()
	var lint = _cls("V10Lint")
	if lint != null:
		for a in lint.ALLOW:
			masked = masked.replace(String(a), "#".repeat(String(a).length()))
		stems.append_array(lint.BANNED)
		stems.append(String(lint.PRICE_NEAR))
	var bad: = []
	for w in stems:
		if masked.find(String(w)) >= 0:
			bad.append(w)
	for w in BANNED_WORD:
		var re: = RegEx.create_from_string("(^|[^\\p{L}])" + w)
		if re.search(low) != null:
			bad.append(w)
	# no Latin at all in a Russian line (rule 6; also covers the riichi case-sensitive «R», «SR», «ID»)
	if RegEx.create_from_string("[A-Za-z]").search(text) != null:
		bad.append("latin")
	return bad


# a consumer class by its class_name, loaded at runtime (no compile-time tie from this data file to the screens)
static func _cls(cls: String):
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			var s = load(String(c.get("path", "")))
			return s
	return null


# → [] when every per-hero table is complete, mirrors its consumer's schema and every line is clean;
# else one string per failure. Run it in the game (autoloads present): some consumers need G to compile.
static func selftest() -> Array:
	var fails: = []
	var tables: = {"NAME": NAME, "COLOR": COLOR, "SIG": SIG, "RIICHI_STYLES": RIICHI_STYLES, "POSE_KEYS": POSE_KEYS,
		"KOIKOI_STYLES": KOIKOI_STYLES, "TRIPLES_ACCENT": TRIPLES_ACCENT, "TRIPLES_TRAY": TRIPLES_TRAY,
		"TRIPLES_TABLE": TRIPLES_TABLE, "SANMA_ACCENT": SANMA_ACCENT, "TABLE_THEME": TABLE_THEME, "RANK": RANK,
		"STAGE": V10W1MjLines.STAGE, "RIICHI": V10W1MjLines.RIICHI}
	for t in tables:
		for id in IDS:
			if not (tables[t] as Dictionary).has(id):
				fails.append("%s: no %s" % [t, id])
	for k in V10W1MjLines.KOIKOI:
		for id in IDS:
			if String(V10W1MjLines.KOIKOI[k].get(id, "")) == "":
				fails.append("KOIKOI.%s: no %s" % [k, id])
	for k in V10W1MjLines.TRIPLES:
		for id in IDS:
			if String(V10W1MjLines.TRIPLES[k].get(id, "")) == "":
				fails.append("TRIPLES.%s: no %s" % [k, id])
	for id in IDS:
		var acc: Array = TRIPLES_ACCENT[id]
		if acc.size() != 3 or acc[0] != COLOR[id] or Color(SANMA_ACCENT[id]) != COLOR[id]:
			fails.append("accent of %s is not her colour everywhere" % id)
		elif (acc[2] as Color).get_luminance() > 0.3:
			fails.append("TRIPLES_ACCENT.%s: deep is too light for the window ground" % id)
		for ev in V10W1MjLines.STAGE[id]:
			for v in V10W1MjLines.STAGE[id][ev]:
				if String(v[0]).length() > 32:
					fails.append("STAGE.%s.%s longer than 32: %s" % [id, ev, v[0]])
				if String(v[1]) == "":
					fails.append("STAGE.%s.%s: no voiced text" % [id, ev])
	for id in IDS:
		if not id in TRIPLES_CHAPTER_HOST:
			fails.append("TRIPLES_CHAPTER_HOST: no chapter for %s" % id)
	for f in ["mc", "rin", "hana", "yue", "nova"]:
		if not f in TRIPLES_CHAPTER_HOST:
			fails.append("TRIPLES_CHAPTER_HOST: %s lost every chapter" % f)
	# schema = the founders' schema in each consumer (founder entry = template)
	var ai = _cls("V8AI")
	var kai = _cls("V10MjKoikoiAI")
	var sd = _cls("V10MjStageData")
	var sl = _cls("V10MjStageLines")
	var rb = _cls("V10MjRiichiBarks")
	var kl = _cls("V10MjKoikoiLines")
	var tl = _cls("V10MjTriplesLook")
	var tg = _cls("V10MjTriplesGen")
	var bt = _cls("V6BoardTable")
	var tt = _cls("V10MjTables")
	var tp = _cls("V10MjTriplesPresence")
	if tp != null:
		for kind in tp.LINES:
			if not V10W1MjLines.TRIPLES.has(kind):
				fails.append("TRIPLES: no kind %s" % kind)
	for id in IDS:
		if ai != null:
			for key in ai.STYLES.mc:
				if not RIICHI_STYLES[id].has(key):
					fails.append("RIICHI_STYLES.%s: no %s" % [id, key])
		if kai != null:
			for key in kai.STYLES.mc:
				if not KOIKOI_STYLES[id].has(key):
					fails.append("KOIKOI_STYLES.%s: no %s" % [id, key])
		if sd != null:
			for key in sd.POSE_KEYS.mc:
				if pose_key(id, key) == "":
					fails.append("POSE_KEYS.%s: no %s" % [id, key])
		if sl != null:
			for ev in sl.MATCH_EVENTS:
				if stage_variants(id, ev).size() != 3:
					fails.append("STAGE.%s.%s: %d variants (need 3)" % [id, ev, stage_variants(id, ev).size()])
			for ev in sl.TABLE_EVENTS:
				if stage_variants(id, ev).size() != 1:
					fails.append("STAGE.%s.%s: need 1 variant" % [id, ev])
				elif riichi_bark(id, ev) != String(stage_variants(id, ev)[0][0]):
					fails.append("RIICHI.%s.%s differs from the stage call" % [id, ev])
		if rb != null:
			for ev in rb.EVENTS:
				if riichi_bark(id, ev) == "":
					fails.append("RIICHI.%s: no %s" % [id, ev])
		if kl != null:
			for kind in kl.LINES:
				if koikoi_line(kind, id) == "":
					fails.append("KOIKOI.%s: no %s" % [kind, id])
			for kind in ["koikoi", "take", "month"]:
				if koikoi_line(kind, id) != String(kl.LINES[kind].rin):
					fails.append("KOIKOI.%s.%s must be the shared call word" % [kind, id])
		if tl != null:
			if not tl.TRAYS.has(String(TRIPLES_TRAY[id])):
				fails.append("TRIPLES_TRAY.%s: unknown tray" % id)
		if bt != null and not bt.THEMES.has(String(TRIPLES_TABLE[id])):
			fails.append("TRIPLES_TABLE.%s: unknown board theme" % id)
		if tt != null:
			if not tt.THEMES.has(String(TABLE_THEME[id])):
				fails.append("TABLE_THEME.%s: no table record" % id)
			elif int(tt.THEMES[TABLE_THEME[id]].sig) != int(SIG[id]) or String(tt.THEMES[TABLE_THEME[id]].rank) != String(RANK[id]):
				fails.append("SIG / RANK of %s differ from V10MjTables" % id)
	if tg != null and TRIPLES_CHAPTER_HOST.size() != tg.CHAPTER_HOST.size():
		fails.append("TRIPLES_CHAPTER_HOST: %d chapters, V10MjTriplesGen has %d" % [TRIPLES_CHAPTER_HOST.size(), tg.CHAPTER_HOST.size()])
	# words: every Russian string through V10Lint, the union of the mj stop lists and each consumer's own checker
	var lint = _cls("V10Lint")
	var rd = _cls("V10MjRiichiData")
	for t in all_texts():
		var s: = String(t)
		var bad: = banned_hits(s)
		if lint != null:
			bad += lint.check(s)
		if rd != null:
			bad += rd.lint(s)
		if kl != null:
			bad += kl.banned_hits(s)
		if not bad.is_empty():
			fails.append("words «%s»: %s" % [s, str(bad)])
	return fails
