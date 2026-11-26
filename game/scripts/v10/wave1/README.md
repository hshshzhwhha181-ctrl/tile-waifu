# Wave-1 Goddesses (`game/scripts/v10/wave1/`)

Five Wave-1 heroines (`tsubame`, `miel`, `kohaku`, `shirin`, `zlata`) for **Tile Waifu 0.10**, packaged behind the idempotent facade `V10Wave1` (`wave1.gd`) with zero direct edits to shared hot files.

## 1. Roster & Outfits Summary

| Heroine | Name | Rank | Base Outfit | Extra Outfits | Legwear (`LW`) | Дар (`V10W1Play.PASSIVES`) | Приём (`V10W1Ults.CORES`) |
|---|---|---|---|---|---|---|---|
| `tsubame` | Цубамэ | **A** | `tb_base` (A) | `tb_post` (S), `tb_crimson` (SSR, lifts kit→S) | `LW33`–`LW35` | Обходной путь | Теневой шаг |
| `miel` | Миэль | **A** | `me_base` (A) | `me_parlor` (S), `me_gala` (SSR, lifts kit→S) | `LW36`–`LW38` | Добавка | Печенье-джокер |
| `kohaku` | Кохаку | **S** | `ko_base` (S) | `ko_matsuri` (A, shop 480), `ko_kyubi` (SSR, `sfw:false`, `alt:ko_matsuri`), `ko_vow` (SSR, Обет L10) | `LW48`–`LW51` | Лисьи огни | Лисий оберег |
| `shirin` | Ширин | **S** | `sh_base` (S) | `sh_oasis` (A, shop 480), `sh_sun` (SSR), `sh_night` (SSR) | `LW52`–`LW55` | Ритм каравана | Танец монет |
| `zlata` | Злата | **SSR** | `zl_base` (SSR) | `zl_fair` (S), `zl_ember` (SSR), `zl_vow` (SSR, Обет L10) | `LW68`–`LW71` | Оттепель | Огненный шлейф |

Zlata's SSR kit (`V10W1Look.KITS.zlata`) resolves HUD skin `V10HudSkinData.SKINS.zlata` (4 Khokhloma lacquer palettes), display/body font pair `Ruslan Display + Kurale` (`V10Fonts.SKIN_FONTS.zlata`), and sting metadata (`V10KitData.STINGS.zlata`).

---

## 2. Facade API (`class_name V10Wave1`, `wave1.gd`)

```gdscript
V10Wave1.install(g = null, opts = {}) -> Dictionary      # Idempotent registration into all writable runtime registries
V10Wave1.register_all(g = null, opts = {}) -> Dictionary # Alias of install()
V10Wave1.apply(g = null) -> void                         # Sanitizes save when off; calls install(g) when released()
V10Wave1.count() -> Dictionary                           # {heroes:5, outfits:18, legwear:18, emotions:25, poses:19, stickers:40, ...}
V10Wave1.released() -> bool / set_released(on: bool)     # Roster gate (default true; CLI --wave1=0|1; save S.w1_released)
V10Wave1.banners_enabled() -> bool / set_banners_enabled(on: bool) # Optional banner splice gate (--wave1_banners=0|1)
```

---

## 3. W4 Integration Call Sites (≤ 10 lines per hot file)

Automated idempotent patchers and diff references for every consumer live in `hooks/src/` (`core_apply.py`, `look_apply.py`, `gacha_audio.diff`, `home_hooks.diff`, `social.diff`, `play.diff`, `ults.diff`, `mj.diff`).

### 3.1 Boot & Core (`g.gd` + `hero.gd` + `v08/hud/art.gd`)
1. Turn `const HEROES`, `const HERO_ORDER`, `const BASE_OUTFITS`, `const SKILLS`, `const PERKS` in `g.gd` into `var`, `const RIGS` in `hero.gd` into `static var`, and `const EMO_FACE`, `EMO_FACE_W`, `RIG_FACE_W` in `v08/hud/art.gd` into `static var`.
2. At the end of `G._ready()` (after `load_game()`):
   ```gdscript
   V10Wave1.apply(self)
   ```
3. Route path literals for full-body, outfit cards, and emotion portraits through:
   ```gdscript
   V10Wave1.hero_png(id)          # founders -> res://assets/hero/<id>.png; wave-1 -> res://assets/v10/wave1/hero/<id>.png
   V10Wave1.outfit_webp(img)      # founders -> res://assets/outfits/<img>.webp; wave-1 -> res://assets/v10/wave1/outfits/<img>.webp
   V10Wave1.emotion_webp(h, emo)  # founders -> res://assets/v08/emotions/...; wave-1 -> res://assets/v10/wave1/emotions/...
   ```
   *(Or run `python game/scripts/v10/wave1/hooks/src/core_apply.py game`.)*

### 3.2 Look, Kits & Frames (`v10/look/kit_data.gd`, `v10/look/tile_themes.gd`, `v10/core/ds.gd`)
Turn `V10KitData.KITS`, `V10KitData.EXTRA_OUTFITS`, `V10TileTheme.THEMES`, `V10TileTheme.TABLES`, `V10DS.HEROES`, `V10ComboShowcase.LINES` from `const` into `static var` — `V10Wave1.install()` automatically populates them and registers all 5 `fr_g_*` avatar frames into `V10ProfileCos`. *(Or run `python game/scripts/v10/wave1/hooks/src/look_apply.py`.)*

### 3.3 Ults (`v09/ults/ults.gd` + `ult_cast.gd`) & Passives (`v07/passives/passives.gd`)
- In `V9Ults.get_ult(id)` / `V9Ults.core(hero, ranked)`:
  ```gdscript
  if V10Wave1.ult_has(id): return V10Wave1.ult(id)
  if V10W1Ults.is_wave1(hero) and V10Wave1.released(): return V10Wave1.ult_core(hero, ranked)
  ```
- In `V9UltCast`: delegate `V10W1Ults.is_wave1(hero)` to `V10W1Ults.cast_pairs / cast_blocked / cast_auto_pick / cast_apply` (`hooks/src/ults.diff`).
- Turn `V7Passives.DATA`, `V6Heroines.RIVALS` / `DUEL_LINES`, `V6ModesData.*`, `V8AI.STYLES` into `static var` (`V10Wave1.install()` merges them) and route `V7PassiveRun` via `V10W1Play.passive_engine(h)` (`hooks/src/play.diff`).

### 3.4 Gacha Banners & Shop (`v10/gacha/banners.gd` + `gacha_pool.gd` + `v10/econ/shop_catalog.gd`)
- In `V10Banners._load()`:
  ```gdscript
  _data = V10Wave1.banners(parsed)
  ```
- In `V10GachaPool._droppable(it, owns)`:
  ```gdscript
  if V10W1Gacha.is_w1(String(it.id)): return V10Wave1.droppable(String(it.id), owns, V10GClock.now())
  ```
- In Лавка outfit filter: check `V10Wave1.shop_ok(id, owns)` (`hooks/src/gacha_audio.diff`).

### 3.5 Phone Chat, Stickers, Feed & Rituals (`v10/chat/chat_data.gd` + `v10/rituals/*`)
- In `V10ChatData`: extend `HEROES` via `V10Wave1.chat_heroes()`, `hero_file(h)` via `V10W1Social.chat_file(h)`, `stickers()` via `V10Wave1.stickers(d)`, `reactions()` via `V10Wave1.reactions(d)`, `feed()` via `V10Wave1.feed(posts)` (`hooks/src/social.diff`).
- Birthday medallions (`res://assets/v10/wave1/rituals/sig_<hero>.webp`) and `V10Tray` provider `w1_bday` are wired automatically by `V10Wave1.install()`.

### 3.6 Home Lines & Mahjong Table Barks (`v06`..`v09` home + `v10/mj/*`)
- Turn the 26 home tables listed in `V10W1Home.merges()` (`V9TouchLines.LINES`, `V7Lines.*`, `V6Txt.LINES`, `V9LetterText.*`, `V6Scenes.*`, `V7RoomData.*`, `V7RoomScenes.SCENES`) from `const` into `static var` — `V10Wave1.install()` merges them idempotently (`hooks/src/home_hooks.diff`).
- In Riichi / Sanma / Koi-Koi / Triples / Stage mahjong modes: query `V10Wave1.mj_bark(mode, hero, ev, hand)` and `V10W1Mj.riichi_face_tex / sanma_region / koikoi_frame` (`hooks/src/mj.diff`).

### 3.7 Registry Runner (`v10/core/registry_list.gd`)
Add to `V10RegistryList.entries()`:
```gdscript
{"id": "wave1", "flag": "--wave1_selftest", "scene": "res://scripts/v10/wave1/wave1_selftest.tscn", "marker": "WAVE1_SELFTEST"},
```

---

## 4. Assets & Optional Post-Top-Up Replacement List

All **76 visual assets** are present on disk with Godot `.import` files and verified in `wave1_selftest`:
- **18/18** outfit cards (`assets/v10/wave1/outfits/*.webp`, `850×1280` RGB)
- **5/5** full-body cutouts (`assets/v10/wave1/hero/*.png`, `848×1264` RGBA)
- **19/19** pose slots (`assets/v10/wave1/poses/*.webp`, `height=1280`)
- **25/25** emotion portraits (`assets/v10/wave1/emotions/*.webp`, `600×800` RGBA, hip-cropped above `HIP_MAX`)
- **4/4** tile emblems (`assets/v10/wave1/look/emblems/*.png` RGBA) + **5/5** birthday sigils (`assets/v10/wave1/rituals/sig_*.webp` RGBA)

**Economy-mode derived emotion slots (7 of 25)** — generated locally (`_meta.emotions_derived` in `data/w1_art_cards.json`), passing all alpha/face/anatomy checks today, and optionally swappable post-Higgsfield top-up via `tools/w1_art_cards.py`:
1. `tsubame_sad.webp` (derived from `tsubame_pout`)
2. `miel_sad.webp` (derived from `miel_pout`)
3. `kohaku_happy.webp` (waist-up RGBA crop + expression polish from `hero/kohaku.png`)
4. `shirin_happy.webp` (waist-up RGBA crop + warm sunlit polish from `hero/shirin.png`)
5. `shirin_sad.webp` (derived from `shirin_shy`)
6. `shirin_pout.webp` (derived from `shirin_shy`)
7. `zlata_pout.webp` (derived from `zlata_sad`)

**Pending audio batch** (silent fallback active via `motif_ready` / `voice_ready` / `ResourceLoader.exists`): `V10W1Audio.pending(true)` lists all 137 audio specs (5 motifs, 2 Zlata stings, 10 SFX, 120 voiced lines).

---

## 5. Selftest (`WAVE1_SELFTEST 221/221`)

```powershell
& $godot --headless --audio-driver Dummy --path game res://scripts/v10/wave1/wave1_selftest.tscn -- --wave1_selftest=1
```
