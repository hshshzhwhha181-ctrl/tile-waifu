## Lane 4 CORE: report

The core file is written and parse-checks clean. I also tested the hooks in a scratch copy of the game with wave 1 switched on, and they work.

### File written
`/home/user/tile-waifu/game/scripts/v10/wave1/w1_core.gd` (`class_name V10W1Core extends RefCounted`, 760 lines).
- **Parse check:** `--check-only` on the real file passes with no errors.
- **No compile-time dependencies:** the file uses no `G`, `Hero` or `V8Art` identifier, so the check works without autoloads. `G` is read through `_g()`, and `Hero` and `V8Art` are found by class name.
- **Wave-1 stopword check (V10Lint) on every text:** clean. The plain stem grep flags only «Тысяча и одна партия», because it contains «одна». `V10Lint.ALLOW` already whitelists «одна партия», so `V10Lint.check` passes it. The selftest uses `V10Lint.check`, not the plain grep.

### What it provides
- **`HEROES` and `HERO_ORDER`** (tsubame, miel, kohaku, shirin, zlata), with the founders' keys: `name`, `title`, `age`, `job`, `color`.
  - Colours: c8283c, e0566f, f3efe9, d9b26f, c3242b.
  - Jobs and ages are copied verbatim from the brief. Kohaku's age is «на вид 25 (лисе 900 лет)».
  - Titles were measured so they fit the Гардероб card: each is at most 246 px at 20 px, the founders' maximum.

    | Goddess | Title |
    |---|---|
    | tsubame | «Курьер миров, 24 года» |
    | miel | «Кондитер, 25 лет» |
    | kohaku | «Лиса-жрица, на вид 25» |
    | shirin | «Танцовщица, 26 лет» |
    | zlata | «Царевна весны, 25 лет» |

  - The longer titles «Куноити-курьер…», «Танцовщица и гадалка…» and «Царевна Жар-птица…» measured 254–310 px, which overflows the card.
- **`ITEMS`:** the 18 outfits in the founders' schema `{id, cat:"outfit", hero, rar, name, img}`. `img` equals the id, and ranks map A→R, S→SR, SSR→SSR. Flags:
  - **Shop:** `ko_matsuri` and `sh_oasis` have `shop: 480` plus `nogacha`. They are the S goddesses' everyday A outfits, which ROSTER §1.2 marks «повседневный, магазин». 480 is an A price on the existing shop price ladder; the founders use 680 for S and 1280 for SSR.
  - **Vows:** `ko_vow` and `zl_vow` have `nogacha` only (no shop, no pass). `VOW_AFF` says Симпатия 10 grants them.
  - **Bold outfit:** only `ko_kyubi` has `bold: true, sfw: false, alt: "ko_matsuri"`.
    - **Why ko_kyubi:** it is strapless and its slit runs to the hip with the ofuda band showing. That puts it in the same class as y_duel.
    - **Why not zl_ember or sh_night:** they are strapless or have a slit to the upper thigh, which is the same level as mc_dragon, and the founders do not mark that as bold.
    - **sh_base:** it shows a bare midriff, but it is a base outfit (the rigged full-body art), so it cannot be swapped.
  - **Not set, on purpose:** no `pass` (the economy lane picks the season prize), no `limited` (the gacha lane's self-check requires none to be static).
- **Other data:** `BASE_OUTFITS`, `FACTS` (rank, element, signature tile index and name, palette, birthday, base outfit), `STAGE_BG` (rooftop, street, shrine, festival, menu), `EMOTIONS`, `POSE_SLOTS`.
- **Lookups and paths:**
  - Lookups: `is_wave1_hero`, `is_wave1_item`, `is_wave1_img`, `item`, `items_copy`, `outfits_of`, `base_of`, `hero_of_img`, `vow_level`, `stage_bg`, `palette`.
  - Wave-1-only paths: `outfit_tex_path`, `hero_tex_path`, `emotion_path`, `pose_path`.
  - Paths for any id: `hero_png`, `outfit_webp`, `emotion_webp`. They return the founders' exact path for founder ids and the wave-1 path for wave-1 ids, so hooked consumers stay byte-identical for the founders.
- **Measured art data:** `rigs()` and `rig(h)` read `data/w1_art_rig.json` once and cache it. They convert to the founders' types (Vector2, Vector4, `Vector3 av`, `Color lash` from hex, float). A missing key gets a safe default and is reported in `rig_problems()`. `rig_face_w()` uses the rig's `face_w`, or 1.75 × the eye distance. `emo_face()` and `emo_face_w()` read `data/w1_art_cards.json` and convert pixels to fractions if needed. Also `outfit_rect(id, "face_rect"|"alt_rect")`, `outfit_face(img)` (round-avatar crop, calibrated on the founders' face rects) and `pose_face_rect`. `reload()` clears the cache.
- **Merge helpers for the facade (idempotent; each returns a list of problems):**
  - `merge_g(g)` adds the wave-1 rows to the end of G's hero, order, base-outfit and item tables, so founder indices do not move.
  - `merge_art()` adds to `Hero.RIGS` and V8Art's three face tables, and never replaces a founder row. It also reports incomplete rig data.
  - `sanitize_save(S, heroes)` resets `partner`, `level_partner` and `profile.avatar` to «mc» when they point at a wave-1 goddess who is not in `heroes`. Founder ids are never touched.
- **`selfcheck(files = true) -> Array`** returns failure strings and is ready for `--wave1_selftest`. It checks:
  - schema, the colour rule, and that each title ends with the age;
  - Russian-only text and `V10Lint` on every string;
  - signature tile against `G.TILE_NAMES`, birthdays, and that each backdrop exists;
  - one base outfit per goddess at her own rank, and 3–4 outfits each;
  - 18 unique ids with `img == id`, the shop/vow/bold-alt rules, and no clash with `G.ITEM`;
  - agreement with `V10KitData.KITS` (signature tile, rank), `EXTRA_OUTFITS` (the `zl_*` outfits) and `V10ProfileCos.ROSTER`;
  - art files: 18 outfits, 5 heroes, 25 emotions, pose slots;
  - rig sanity (feet, head, eyes, `av`, face width), emotion faces measured, outfit face and alt rects measured.

### Hooks (exact code)
The old→new pairs below were applied mechanically to a scratch copy; each matched exactly once. Script: `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/core/hooks/apply_hooks.py`. Each hook is listed as `file : function` → change.

- **H1** `g.gd` (top): `const HEROES: = {` → `var HEROES: = {`. Same for `const HERO_ORDER` → `var HERO_ORDER` and `const BASE_OUTFITS` → `var BASE_OUTFITS`. The play lane should do the same to `const PERKS` and `const SKILLS`: `levels.gd:925/948` and `play.gd:611/1402` index them by partner and would crash for a wave-1 partner.
- **H2** `g.gd : _ready()`, immediately before `load_game()`. It runs before the save is read so that `_ensure_profile()` keeps a saved wave-1 avatar:
  ```gdscript
  	if V10Wave1.released():
  		V10Wave1.apply(self)
  	load_game()
  ```
  `g.gd : _migrate()` becomes `_sync_v6_fx()` / `V10W1Core.sanitize_save(S, HEROES)` / `_ensure_profile()`.

  **Two requirements for the facade:**
  - `V10Wave1.released()` must not read `G.S`, because the save is not loaded yet. Read a save flag with `G.read_save_file(save_path)` instead.
  - `V10Wave1.apply(g)` should call `V10W1Core.merge_g(g) + V10W1Core.merge_art()`, plus the other lanes' merges.
- **H2b** `g.gd : item_tex` → `return load(V10W1Core.outfit_webp(item_img(it)))`. `g.gd : art_tex` → `return load(V10W1Core.outfit_webp(String(it.alt)))`.
- **H3** `hero.gd`: `const RIGS: = {` → `static var RIGS: = {`. In `setup()`: `var tex: Texture2D = load(V10W1Core.hero_png(id))`.
- **H4** `v08/hud/art.gd`:
  - `const EMO_FACE`, `const EMO_FACE_W` and `const RIG_FACE_W` become `static var`.
  - `emotion_path()` → `return V10W1Core.emotion_webp(emo_hero(hero), emo_name(emo))`.
  - `emotion()` fallback → `return tex(V10W1Core.hero_png(h))`.
  - `emo_hero()`: after the `Hero.RIGS.has` check, add `if V10W1Core.is_wave1_img(hero): return V10W1Core.hero_of_img(hero)`.
  - `_portrait()`: hero branch → `ResourceLoader.exists(V10W1Core.hero_png(s))` / `load(V10W1Core.hero_png(s))`. Outfit branch → `var p: = V10W1Core.outfit_webp(s)` and `var fc: Array = V10W1Core.outfit_face(s) if V10W1Core.is_wave1_img(s) else V8Population.face(s)`.
- **H5** Round portraits: `main.gd : _avatar`, `screens/common.gd : avatar` and `tile.gd : set_shard` → `load(V10W1Core.hero_png(hero_or_h))`.
- **H6** `screens/collection.gd : _build`:
  - Change `var bg: String = STAGE_BG[cur] if STAGE_BG.has(cur) else V10W1Core.stage_bg(cur)`; the current indexed read crashes for wave-1 heroes.
  - Hero row: for more than five heroes the step becomes `floorf((W-40)/n)` (68 px, circles 62 px). Five heroes give exactly the 0.9 row (step 136, AV 104). The full code is in `apply_hooks.py`; it uses locals `n_h`, `step`, `avd`, `ry` and `ins`, plus a scaled lock icon.
- **H8** `v08/league/population.gd:137,140`: replace `G.HERO_ORDER` with `V10W1Core.FOUNDERS`. Otherwise filtering `AVATARS` returns an empty list and `% 0` crashes; this way the league is also identical. `avatar_view`: `ResourceLoader.exists(V10W1Core.outfit_webp(img))`. `league_selftest.gd:93`: compare against `V10W1Core.FOUNDERS.size()`.
- **H9** `v10/auth/auth_nicks.gd : suggest`: `var heroes: Array = G.HERO_ORDER.filter(func(h): return not IDEAS.get(h, []).is_empty())`. A goddess with no list indexes an empty array. The social lane can add nickname ideas for the five.

### Other lanes' code that breaks once `HERO_ORDER` grows (for the integrator)
- **Crash (founders-only table indexed by hero):**
  - home lane: `room_data` (PREFS, ROOM_LINES, OPENERS); `v09/home/touch` (RIG_HAND)
  - social lane: `chat_validate` (OUTFIT_PREFIX); `bday_data` (DATES); `rit_lines`
  - mj lane: `riichi/barks` (LINES); `stage_data` (POSE_KEYS)
  - ults lane: `V9Ults.BASE`
  - play/levels lane: `G.PERKS` and `G.SKILLS` (see H1); `level_gen.READY_HEROES`
  - Also, `Sfx.say` falls back to «mc» lines and emits `hero="mc"`, so wave-1 goddesses need `V6Txt.LINES` rows.
- **Layout built for five heroes:**
  - `levels.pick_partner`: 160 px × 10 rows = 1820 px, more than the screen.
  - `modes.gd:404`: the duel popup is fixed at 760 px.
  - `room.gd` tabs: 1040 px wide.
  - `event_screen.gd:328`: an avatar row of 100 px each.
  - `profile_ui` `AvatarRow`: still works, but avatars shrink to about 52 px.
- **Ults selftest path check:** `ults_selftest` expects `ref_img == res://assets/outfits/<img>.webp`. It must accept `V10W1Core.outfit_webp(img)` instead.
- **0.9 gacha pool:** the old `G.pull` would put SSR `zl_*` outfits straight into the standard pool after release. `V10Gacha2` (the 0.10 gacha) or the gacha lane's `limited_now` handles this.

### Verification in a scratch copy
Placeholder founder art was copied into the wave-1 paths, with a test rig and cards JSON. The run used `--wave1=1` and `xvfb`.
- `merge` returned no problems. `HERO_ORDER` and `Hero.RIGS` hold all ten heroes.
- Every Hero loads her wave-1 PNG. `V8Art.has_emotion` is true and the emotion face and face width come from the JSON.
- Modest mode on `ko_kyubi` shows `ko_matsuri`. `emo_hero("zl_ember")` returns zlata. `set_avatar("shirin")` sticks.
- Founder paths are unchanged (`mc_happy.webp`, `mc_base.webp`).
- Гардероб builds for zlata and kohaku: the 10-circle row fits and the titles fit. Screenshots: `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/core/coll_pair.jpg`.
- The only `selfcheck` failures were the pose files, which do not exist yet in the scratch copy.
- With wave 1 off, `recovery_selftest` passed 42/42. `ults_selftest` timed out waiting on the shared Godot lock and was not run.

### Self-checks for `--wave1_selftest`
1. `V10W1Core.selfcheck(true)` returns an empty list.
2. Released:
   - `merge_g` and `merge_art` return no problems.
   - `G.HERO_ORDER` ends with the five; every wave-1 id is in `G.ITEM` and `G.BASE_OUTFITS`.
   - `Hero.new().setup(h, 800)` gives `texture.resource_path == V10W1Core.hero_tex_path(h)`.
   - `V8Art.has_emotion(h, e)` is true for all 25 emotions.
   - `G.art_tex(G.ITEM.ko_kyubi)` in modest mode is `ko_matsuri`.
3. Founders byte-identical: `V8Art.emotion_path("mc","happy") == "res://assets/v08/emotions/mc_happy.webp"` and `G.item_tex(o_base)` resolves to `res://assets/outfits/mc_base.webp`.
4. Not released:
   - `G.HEROES.size() == 5` and no wave-1 id is in `G.ITEM`.
   - A save with `partner = "zlata"` loads with `partner = "mc"`.
   - Running `merge` a second time changes nothing.

### Open questions
- **Kohaku's name colour f3efe9** (from the brief) is near-white. It reads on dark UI, and the story nameplate has a dark outline. `V10ProfileCos.ROSTER` uses d63a2a for kohaku and 1f8f8a for shirin as frame colours, which is a separate field. Confirm the brief's choice.
- **sh_sun** is still in audit. If the chosen candidate keeps the raised knee in the slit (the y_duel class), set `bold: true, sfw: false, alt: "sh_oasis"`.
- **Buying ko_matsuri or sh_oasis unlocks an S goddess** through `G.hero_unlocked`. The gacha lane's `shop_ok` restricts them to owners, but `V10ShopHub.items_fn` must call it.
- **Shared `tb_` prefix:** outfit ids `tb_*` share it with table ids in `V10TileThemes`. Nothing collides and no code uses the prefix, but the look lane must not create tables named `tb_base`, `tb_post` or `tb_crimson`.
