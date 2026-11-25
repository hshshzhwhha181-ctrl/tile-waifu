## Lane 4 mj builder: final report

The five goddesses now have data for every per-hero table in the mahjong modes. Both files parse clean in Godot, and the temp harness I ran in the full project (autoloads loaded) ended at `W1_MJ_CHECK 42/42`. I deleted the harness afterwards (`scripts/v10/wave1/_tmp_mj_check/`), and none of my files contain a stem from the brief's banned list.

### Files (only these two)
- `/home/user/tile-waifu/game/scripts/v10/wave1/w1_mj.gd`: `class_name V10W1Mj`, extends RefCounted. It holds the data tables and small static helpers. The art JSONs are read at runtime, once, and cached.
- `/home/user/tile-waifu/game/scripts/v10/wave1/w1_mj_lines.gd`: `class_name V10W1MjLines`. It holds the text: `STAGE` (160 lines, each a Russian subtitle of 32 characters or fewer plus Japanese voiced text), `RIICHI`, `KOIKOI`, `TRIPLES`, and `all_ru()`.

### Consumers mirrored (founder entry used as the template)

**Riichi**
- `V8AI.STYLES` in `v08/table/ai.gd` → `V10W1Mj.RIICHI_STYLES`. Keys are call, riichi, defense, skill, value, speed, name, desc. Style names:
  - Цубамэ: «Ночной курьер»
  - Миэль: «Щедрая рука»
  - Кохаку: «Лисья игра»
  - Ширин: «Звёздный расклад»
  - Злата: «Царский размах»
- `V10MjRiichiBarks.LINES` → `V10W1MjLines.RIICHI`: 10 events. The 8 events shared with the stage lines use the same words.
- `V10MjRiichiPortrait.NEUTRAL_C` / `EMO_C` → `V10W1Mj.riichi_face_tex()`. Centres come from the rig `av` / `head_c` and from the emotion `face` in the cards JSON.
- `V10MjRiichiData.HERO_COLOR` / `HERO_NAME` / `FOUNDERS` → `COLOR`, `NAME`, `IDS`.

**Stage**
- `V10MjStageData.POSE_KEYS` → `POSE_KEYS`, from POSES.md §0.5.
- `V10MjStageLines.LINES` → `V10W1MjLines.STAGE`: 8 match events × 3 lines, plus 8 table events × 1.

**Koikoi**
- `V10MjKoikoiAI.STYLES` → `KOIKOI_STYLES`. Each entry adds a `"koi"` policy, which `koikoi_decide()` uses.
- `V10MjKoikoiLines.LINES` / `ACCENT` / `NAME` / `FRAME` → `V10W1MjLines.KOIKOI`, `COLOR`, `NAME`, `koikoi_frame()`. The frame uses the alpha bounds of her cut-out, with the rig as fallback.
- `V10MjKoikoiInfo.INFO.rivals` / `host` → `KOIKOI_RIVALS`, `KOIKOI_HOST = "kohaku"` (MODES §1: «Рин (потом Кохаку)»), applied through `koikoi_info(base)`.

**Triples**
- `V10MjTriplesLook.ACCENT` / `HERO_TRAY` / `HERO_TABLE` → `TRIPLES_ACCENT`, `TRIPLES_TRAY`, `TRIPLES_TABLE`.
- `V10MjTriplesPresence.SIGNATURE` / `LINES` → `SIG`, `V10W1MjLines.TRIPLES`.
- `V10MjTriplesGen.CHAPTER_HOST` → `TRIPLES_CHAPTER_HOST`. Each goddess takes one chapter that a founder hosted twice, and every founder keeps at least one.

**Sanma**
- `sanma_screen.gd` `ACCENT` / `NAMES` / `PORTRAIT_REGION` → `SANMA_ACCENT`, `NAME`, `sanma_region()`.

**Look**
- `TABLE_THEME` and `RANK` only reference the `V10MjTables.THEMES` records that already exist.
- The selftest checks that their `sig` and `rank` match.

Colours follow the brief everywhere: her colour equals `G.HEROES` color (c8283c, e0566f, f3efe9, d9b26f, c3242b), and the signature tiles are 1 / 16 / 31 / 9 / 12. The triples glow comes from the look kit.

One deliberate departure from the look kit: the triples "deep" must be dark, because it is the ground under her window, like the founders'. The kit "deep" is too light for that in three cases:
- **Миэль:** c98a4b → 64452a.
- **Ширин:** 1f8f8a → 114f4c.
- **Кохаку:** the kit "deep" is her white, so I used her tray lacquer, 8a1f17.

### Hooks (36 hooks in 16 files)
Apply this patch verbatim. `git apply --check` passes on the current tree. A copy is saved at `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/w1_mj_hooks.patch`, and the hook spec is at `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/w1mj/hooks.py`.

`V10Wave1` must exist before the patch is applied, because the hooked files refer to it. Every behaviour change is behind `V10Wave1.released()`. A few path and fallback hooks are ungated (`hero_png`, the default lookups such as `SIG.get(hero, …)`, the dora hero check), but they only change anything for a wave-1 id, and those ids only appear through gated pools. With wave 1 off, the founders behave exactly as before.

```diff
--- a/game/scripts/v10/mj/riichi/table_driver.gd
+++ b/game/scripts/v10/mj/riichi/table_driver.gd
@@ -59,2 +59,4 @@
 		pl.append({"id": h if V8AI.STYLES.has(h) else "mc", "ctl": "human" if s == me else "ai", "hero": h})
+		if V10Wave1.released() and V10W1Mj.has(h):
+			pl[s]["style"] = V10W1Mj.riichi_style(h)   # wave 1: V8AI.style_of reads players[s].style first
 	var o: = {"seed": int(opts.get("seed", 1)), "length": String(opts.get("length", "east")), "players": pl}
@@ -212,2 +214,4 @@
 	var st: Dictionary = V8AI.STYLES.get(hero_of[s], V8AI.STYLES.mc)
+	if V10Wave1.released() and V10W1Mj.has(hero_of[s]):
+		st = V10W1Mj.riichi_style(hero_of[s])
 	var sp: float = float(st.get("speed", 1.0))
--- a/game/scripts/v10/mj/riichi/riichi_screen.gd
+++ b/game/scripts/v10/mj/riichi/riichi_screen.gd
@@ -112,3 +112,3 @@
 	partner = String(a.get("partner", Sd.get("partner", "mc")))
-	if not D.HERO_COLOR.has(partner):
+	if not D.HERO_COLOR.has(partner) and not (V10Wave1.released() and V10W1Mj.has(partner)):
 		partner = "mc"
@@ -134,2 +134,4 @@
 		var pool: = D.FOUNDERS.duplicate()
+		if V10Wave1.released():
+			pool.append_array(V10W1Mj.IDS)
 		pool.erase(partner)
@@ -271,2 +273,4 @@
 	var h: String = partner if seat == me else String(heroes[seat])
+	if V10Wave1.released() and V10W1Mj.has(h):
+		return V10W1Mj.color(h)
 	return D.HERO_COLOR.get(h, D.GOLD_500)
@@ -276,2 +280,4 @@
 		return "Ты"
+	if V10Wave1.released() and V10W1Mj.has(String(heroes[seat])):
+		return V10W1Mj.hero_name(String(heroes[seat]))
 	return String(D.HERO_NAME.get(heroes[seat], heroes[seat]))
@@ -1285,3 +1291,3 @@
 		"dora":
-			fx.dora_scene(L.center.position + Vector2(L.center.size.x * 0.5, L.center.size.y * 0.53), hero if D.HERO_COLOR.has(hero) else partner, col)
+			fx.dora_scene(L.center.position + Vector2(L.center.size.x * 0.5, L.center.size.y * 0.53), hero if (D.HERO_COLOR.has(hero) or V10W1Mj.has(hero)) else partner, col)
 			_sfx("sparkle", -10)
@@ -2003,3 +2009,3 @@
 	# magazine cover: the partner steps out past the right edge, under the play button
-	var ap: = "res://assets/hero/%s.png" % partner
+	var ap: = V10W1Mj.hero_png(partner)
 	if ResourceLoader.exists(ap):
--- a/game/scripts/v10/mj/riichi/fx.gd
+++ b/game/scripts/v10/mj/riichi/fx.gd
@@ -268,3 +268,3 @@
 	c.add_child(band)
-	var ap: = art if art != "" else "res://assets/hero/%s.png" % hero
+	var ap: = art if art != "" else V10W1Mj.hero_png(hero)
 	if ResourceLoader.exists(ap):
--- a/game/scripts/v10/mj/riichi/barks.gd
+++ b/game/scripts/v10/mj/riichi/barks.gd
@@ -46,2 +46,4 @@
 			return String(v[0][0])
+	if not LINES.has(hero) and V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.riichi_bark(hero, ev)
 	var h: String = hero if LINES.has(hero) else "mc"
--- a/game/scripts/v10/mj/riichi/portrait.gd
+++ b/game/scripts/v10/mj/riichi/portrait.gd
@@ -50,2 +50,7 @@
 		return _tex[key]
+	if V10Wave1.released() and V10W1Mj.has(hero_id):
+		var w1: = V10W1Mj.riichi_face_tex(hero_id, f, NEUTRAL_R, EMO_R)
+		if w1 != null:
+			_tex[key] = w1
+			return w1
 	var path: = "res://assets/hero/%s.png" % hero_id if f == "neutral" else "res://assets/v08/emotions/%s_%s.webp" % [hero_id, f]
--- a/game/scripts/v10/mj/stage/stage_lines.gd
+++ b/game/scripts/v10/mj/stage/stage_lines.gd
@@ -127,2 +127,4 @@
 		return hero
+	if V10Wave1.released() and V10W1Mj.has(hero):
+		return hero
 	return String(FALLBACK.get(hero, "mc"))
@@ -131,3 +133,6 @@
 static func variants(hero: String, ev: String) -> Array:
-	return (LINES[hero_key(hero)] as Dictionary).get(ev, [])
+	var k: = hero_key(hero)
+	if not LINES.has(k):
+		return V10W1Mj.stage_variants(k, ev)
+	return (LINES[k] as Dictionary).get(ev, [])
 
--- a/game/scripts/v10/mj/stage/stage_data.gd
+++ b/game/scripts/v10/mj/stage/stage_data.gd
@@ -41,2 +41,4 @@
 static func pose_key(hero: String, slot: String) -> String:
+	if not POSE_KEYS.has(hero) and V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.pose_key(hero, slot)
 	var h: String = hero if POSE_KEYS.has(hero) else "mc"
@@ -47,2 +49,4 @@
 	var f: String = FRAME_OF.get(slot, slot)
+	if V10Wave1.released() and V10W1Mj.has(hero) and ResourceLoader.exists(V10W1Mj.emo_path(hero, f)):
+		return V10W1Mj.emo_path(hero, f)
 	var p: = EMO_DIR + "%s_%s.webp" % [hero, f]
@@ -58,2 +62,4 @@
 		return g.HEROES[hero].color
+	if V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.color(hero)
 	return Color(String(FALLBACK_ACCENT.get(hero, "ff8fb8")))
--- a/game/scripts/v10/mj/koikoi/koikoi_ai.gd
+++ b/game/scripts/v10/mj/koikoi/koikoi_ai.gd
@@ -20,2 +20,4 @@
 static func style_of(id: String) -> Dictionary:
+	if not STYLES.has(id) and V10Wave1.released() and V10W1Mj.KOIKOI_STYLES.has(id):
+		return V10W1Mj.KOIKOI_STYLES[id]
 	return STYLES.get(id, STYLES.mc)
@@ -140,2 +142,4 @@
 static func decide_koi(k: V10MjKoikoi, p: int, sid: String, rng: RandomNumberGenerator) -> bool:
+	if not STYLES.has(sid) and V10Wave1.released() and V10W1Mj.KOIKOI_STYLES.has(sid):
+		return V10W1Mj.koikoi_decide(k, p, sid, rng)
 	var s: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[p]))
--- a/game/scripts/v10/mj/koikoi/koikoi_lines.gd
+++ b/game/scripts/v10/mj/koikoi/koikoi_lines.gd
@@ -38,2 +38,4 @@
 static func line(kind: String, hero: String) -> String:
+	if not NAME.has(hero) and V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.koikoi_line(kind, hero)
 	return String(LINES.get(kind, {}).get(hero, ""))
@@ -41,2 +43,4 @@
 static func accent(hero: String) -> Color:
+	if not ACCENT.has(hero) and V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.color(hero)
 	return ACCENT.get(hero, Color("e8c47e"))
--- a/game/scripts/v10/mj/koikoi/koikoi_screen.gd
+++ b/game/scripts/v10/mj/koikoi/koikoi_screen.gd
@@ -134,3 +134,3 @@
 	hero = String(a.get("hero", "rin"))
-	if not V10MjKoikoiLines.NAME.has(hero):
+	if not V10MjKoikoiLines.NAME.has(hero) and not (V10Wave1.released() and V10W1Mj.has(hero)):
 		hero = "rin"
@@ -242,4 +242,4 @@
 	# поясной кадр
-	var tex: Texture2D = load("res://assets/hero/%s.png" % hero) if ResourceLoader.exists("res://assets/hero/%s.png" % hero) else null
-	var fr: Dictionary = V10MjKoikoiLines.FRAME.get(hero, V10MjKoikoiLines.FRAME.rin)
+	var tex: Texture2D = load(V10W1Mj.hero_png(hero)) if ResourceLoader.exists(V10W1Mj.hero_png(hero)) else null
+	var fr: Dictionary = V10W1Mj.koikoi_frame(hero) if V10W1Mj.has(hero) else V10MjKoikoiLines.FRAME.get(hero, V10MjKoikoiLines.FRAME.rin)
 	var ph: = strip_h() + 6.0
@@ -281,3 +281,3 @@
 	add_child(month_lbl)
-	her_name = _lbl(V10MjKoikoiLines.NAME.get(hero, ""), 26, PAPER_100, "title", 700)
+	her_name = _lbl(V10MjKoikoiLines.NAME.get(hero, V10W1Mj.hero_name(hero)), 26, PAPER_100, "title", 700)
 	her_name.position = Vector2(92, 40)
@@ -1154,3 +1154,3 @@
 	# она в полный рост справа (обложка журнала)
-	var hp: = "res://assets/hero/%s.png" % hero
+	var hp: = V10W1Mj.hero_png(hero)
 	if ResourceLoader.exists(hp):
--- a/game/scripts/v10/mj/triples/triples_look.gd
+++ b/game/scripts/v10/mj/triples/triples_look.gd
@@ -43,2 +43,4 @@
 static func accent(hero: String) -> Array:
+	if not ACCENT.has(hero) and V10Wave1.released() and V10W1Mj.has(hero):
+		return V10W1Mj.triples_accent(hero)
 	return ACCENT.get(hero, ACCENT.mc)
@@ -54,3 +56,3 @@
 			return t
-	return TRAYS[HERO_TRAY.get(hero, "lacquer")]
+	return TRAYS[V10W1Mj.TRIPLES_TRAY.get(hero, HERO_TRAY.get(hero, "lacquer"))]
 
--- a/game/scripts/v10/mj/triples/triples_screen.gd
+++ b/game/scripts/v10/mj/triples/triples_screen.gd
@@ -73,4 +73,5 @@
 	var partner: String = String(G.S.get("partner", "")) if G.S is Dictionary else ""
-	hero = String(a.get("hero", partner if partner != "" else V10MjTriplesGen.CHAPTER_HOST[V10MjTriplesGen.chapter_of(level)]))
-	if not V10MjTriplesLook.ACCENT.has(hero):
+	var hosts: Array = V10W1Mj.TRIPLES_CHAPTER_HOST if V10Wave1.released() else V10MjTriplesGen.CHAPTER_HOST
+	hero = String(a.get("hero", partner if partner != "" else hosts[V10MjTriplesGen.chapter_of(level)]))
+	if not V10MjTriplesLook.ACCENT.has(hero) and not (V10Wave1.released() and V10W1Mj.has(hero)):
 		hero = "mc"
@@ -96,3 +97,3 @@
 	var spare: = extra - minf(extra, 330.0)
-	cfg.bg = V10MjTriplesLook.HERO_TABLE.get(hero, "default")
+	cfg.bg = V10W1Mj.TRIPLES_TABLE.get(hero, V10MjTriplesLook.HERO_TABLE.get(hero, "default"))
 	lv = V10MjTriplesGen.build(level)
@@ -433,3 +434,3 @@
 			var add: = 1
-			if face == int(V10MjTriplesPresence.SIGNATURE.get(hero, -1)):
+			if face == int(V10MjTriplesPresence.SIGNATURE.get(hero, V10W1Mj.SIG.get(hero, -1))):
 				add += 1
--- a/game/scripts/v10/mj/triples/triples_gen.gd
+++ b/game/scripts/v10/mj/triples/triples_gen.gd
@@ -122,3 +122,3 @@
 		"hidden": c >= 4 and k in ["hard", "peak", "boss"],
-		"host": CHAPTER_HOST[c],
+		"host": (V10W1Mj.TRIPLES_CHAPTER_HOST if V10Wave1.released() else CHAPTER_HOST)[c],
 	}
--- a/game/scripts/v10/mj/triples/triples_presence.gd
+++ b/game/scripts/v10/mj/triples/triples_presence.gd
@@ -73,3 +73,3 @@
 func attach(screen: Control, h: String, opts: = {}) -> V10MjTriplesPresence:
-	hero = h if V10MjTriplesLook.ACCENT.has(h) else "mc"
+	hero = h if (V10MjTriplesLook.ACCENT.has(h) or (V10Wave1.released() and V10W1Mj.has(h))) else "mc"
 	acc = V10MjTriplesLook.accent(hero)
@@ -140,3 +140,3 @@
 	if path == "" or not ResourceLoader.exists(path):
-		path = "res://assets/hero/%s.png" % hero
+		path = V10W1Mj.hero_png(hero)
 	_art_tex = load(path) if ResourceLoader.exists(path) else null
@@ -445,3 +445,3 @@
 		return
-	var txt: String = LINES.get(kind, {}).get(hero, "")
+	var txt: String = LINES.get(kind, {}).get(hero, V10W1Mj.triples_line(kind, hero))
 	if txt == "":
--- a/game/scripts/v10/mj/sanma/sanma_screen.gd
+++ b/game/scripts/v10/mj/sanma/sanma_screen.gd
@@ -20,4 +20,4 @@
 }
-const ACCENT: = {"mc": "ff8fb8", "rin": "4fbf9f", "hana": "ffb35c", "yue": "c8b6ff", "nova": "4fe3ff"}
-const NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
+var ACCENT: = {"mc": "ff8fb8", "rin": "4fbf9f", "hana": "ffb35c", "yue": "c8b6ff", "nova": "4fe3ff"}
+var NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
 const TILE_DIR: = "res://assets/v08/table/"
@@ -112,2 +112,5 @@
 		presence = V10MjSanmaPresenceProbe.new()
+	if V10Wave1.released():
+		ACCENT.merge(V10W1Mj.SANMA_ACCENT)
+		NAMES.merge(V10W1Mj.NAME)
 	var partner: String = String(a.get("partner", _g_partner()))
@@ -196,3 +199,4 @@
 func emo_tex(seat: int, emo: String) -> Texture2D:
-	var t: = tex(EMO_DIR + "%s_%s.webp" % [ids[seat], emo])
+	var w1: = V10Wave1.released() and V10W1Mj.has(ids[seat])
+	var t: = tex(V10W1Mj.emo_path(ids[seat], emo) if w1 else EMO_DIR + "%s_%s.webp" % [ids[seat], emo])
 	if t == null:
@@ -201,3 +205,3 @@
 	at.atlas = t
-	at.region = PORTRAIT_REGION
+	at.region = V10W1Mj.sanma_region(ids[seat], emo) if w1 else PORTRAIT_REGION
 	return at
@@ -283,3 +287,3 @@
 		return
-	var t: = tex(EMO_DIR + "%s_shy.webp" % ids[host_seat])
+	var t: = tex(V10W1Mj.emo_path(ids[host_seat], "shy"))
 	if t == null:
--- a/game/scripts/v10/mj/sanma/landlord.gd
+++ b/game/scripts/v10/mj/sanma/landlord.gd
@@ -40,2 +40,4 @@
 	var st: Dictionary = V8AI.STYLES.get(host_id, V8AI.STYLES.mc)
+	if V10Wave1.released() and V10W1Mj.has(host_id):
+		st = V10W1Mj.riichi_style(host_id)
 	base = 3 if rng.randf() < p_triple(st) else 2
```

There is one more hook at hub level, because there is no hub file in the tree yet. Wherever the «Столы» hub reads the Коикои INFO:
```gdscript
var info: Dictionary = V10W1Mj.koikoi_info(V10MjKoikoiInfo.INFO) if V10Wave1.released() else V10MjKoikoiInfo.INFO
```

### Self-checks for `--wave1_selftest`
**`V10W1Mj.selftest()` returns `[]`.** It is verified in the game context (it needs autoloads, because some consumers need `G` to compile). It loads the consumer classes at runtime and checks:
- All five ids are present in every table.
- The schema matches each founder entry: `V8AI.STYLES.mc`, `V10MjKoikoiAI.STYLES.mc`, `V10MjStageData.POSE_KEYS.mc`, `V10MjStageLines.MATCH_EVENTS` (3 variants each) and `TABLE_EVENTS` (1 each), `V10MjRiichiBarks.EVENTS`, all `V10MjKoikoiLines.LINES` and `V10MjTriplesPresence.LINES` kinds.
- The call words «Кои-кои!» / «Забираю» / «Это мой месяц» match the founders' (the koikoi selftest expects them).
- Every riichi bark equals the matching stage call.
- Tray keys exist in `V10MjTriplesLook.TRAYS`, and board keys exist in `V6BoardTable.THEMES`.
- `SIG` and `RANK` match `V10MjTables.THEMES`.
- There are 12 chapter hosts; each goddess has one and every founder keeps at least one.
- Her colour is the same everywhere, and the window ground ("deep") is dark (luminance under 0.3).
- Stage subtitles are 32 characters or fewer and have Japanese text.
- Every Russian string passes all of: `V10Lint.check`, `V10MjRiichiData.lint`, `V10MjKoikoiLines.banned_hits`, and my union of the sanma, triples and stage lists plus the HEROINES red lines (`banned_hits()`, which also rejects any Latin letter).

**`V10W1Mj.all_texts()`** returns every Russian string from this lane, for a global lint.

**Results from the temp harness** (deleted; it compiled all 16 hooked consumers with the gate forced true):
- All 16 compile.
- Founders are unchanged: the stage still has exactly 160 lines, Hana's «Кои-кои!» rate is 93% (the koikoi selftest needs at least 80%) and Rin's is 4% (it needs at most 30%), and founder barks, accents and trays are identical.
- 600 hooked Коикои AI-vs-AI games, no hangs. «Кои-кои!» rate: Цубамэ 0%, Ширин 9%, Миэль 24%, Кохаку 38%, Злата 45%. Злата's captures hold more light cards than Хана's (the same test the founders use for Юэ).
- 60 riichi matches with the wave-1 styles injected exactly as the hook does: none hung, scores always sum to zero.

| Riichi, per 100 hands | riichi | deal-ins |
|---|---|---|
| Злата | 31.9 | 21.3 |
| Кохаку | 28.4 | 18.2 |
| Ширин | 25.1 | 12.0 (lowest of the five) |
| Цубамэ | 21.1 | 13.9 |
| Миэль | 20.0 | 18.9 |

Ширин also calls least (26.9). Цубамэ has the fastest AI pause (speed 1.15).
- Sanma ×3 declarations: Злата 52%, Цубамэ 15%.

### Skipped, and why
- **Koikoi book (12 pages):** each page is one combination, and all 12 are assigned to founders. Moving pages would change the founders' content.
- **Koikoi deck skins:** there are only 5 light cards, and all 5 belong to founders.
- **Sanma host lines:** «Лунный стол» is hosted by Юэ by design, and her lines are hers alone.
- **Tower (Пагода, Странствие):** `v10/tower` already has `BOSS`, `STYLE` and `BLESS` rows for all five. They appear once the five are in `G.HEROES`, which is the core lane's hook.
- **Look tables:** the `V10MjTables` records already exist, and the art is the look lane's. I did not add pages to `look_demo` for the same reason.
- **Дуэли:** owned by `w1_play.gd` (RIVALS, DUEL_LINES).
- **Triples ults:** owned by `w1_ults.gd`.
- **Dora crests:** there is no `crest_<id>.webp` for the five, so their dora scene shows no crest. This needs art from the look lane.
- **Voices and stings:** there are no files yet. The paths follow her own id (`stage/voice/<id>_<ev>_<n>.ogg`, `koikoi/voice/<id>_<key>.ogg`, `sting_<id>`), so subtitles play alone until the audio lane records them.

### For the integrator
- **Two riichi style tables:** `w1_play.gd` also defines `AI_STYLES` for `V8AI`, with different numbers and names. Keep one source. Mine matches this lane's brief and is the one measured above; to use play's table instead, point `V10W1Mj.riichi_style()` at `V10W1Play.AI_STYLES`.
- **Duplicate path helper:** `w1_core.gd` has a `hero_png()` that returns the same paths as mine.
- **Stale colours:** `V10MjStageData.FALLBACK_ACCENT` has old wave-1 colours (for example 7fa7ff for tsubame). The S4 hook overrides them whenever `G.HEROES` lacks the hero.
