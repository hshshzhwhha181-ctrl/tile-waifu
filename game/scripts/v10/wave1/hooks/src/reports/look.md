## LOOK lane, wave 1: report

The look data for all five goddesses is finished and runs in Godot. I tested the whole install path on a throwaway copy of `game/` in the scratchpad, with the hooks below applied there, and deleted the copy afterwards:
- `install()` returns `[]` and is idempotent.
- `V10W1Look.selfcheck(true)` returns `[]`.
- Look selftest: 709/709 before install, **861/861 after**. The extra checks cover the new themes, tables and frames.
- Profile2 selftest 112/112, HUD2 selftest 854/854.

I made no edits outside my area and no git changes.

### Files
- `/home/user/tile-waifu/game/scripts/v10/wave1/w1_look.gd` (`V10W1Look`, extends RefCounted, plus its `.uid`)
- `/home/user/tile-waifu/game/scripts/v10/wave1/tools/w1_look_emblems.py`: procedural emblem generator, run as `python3 -I w1_look_emblems.py <out_dir>`
- `/home/user/tile-waifu/game/assets/v10/wave1/look/emblems/{crimson_moon,sugar_lace,foxfire,monisto}.png` (+ `.import`): RGBA, 112 px tall, cropped to alpha, same format as the look lane's emblems. I checked them by eye on their theme colours and in a rendered sheet.

### Data
| Goddess | Rank | Kit name | Frame | Theme | Table |
|---|---|---|---|---|---|
| Цубамэ | A | «Ночные ласточки» | `fr_g_tsubame` | `s_crimson_moon` «Алая луна» (via `tb_crimson`) | `tb_rooftops` «Крыши под луной» |
| Миэль | A | «Мёд и пар» | `fr_g_miel` | `s_sugar_lace` «Сахарное кружево» (via `me_gala`) | `tb_honeycomb` «Медовые соты» |
| Кохаку | S | «Тысяча врат» | `fr_g_kohaku` | `s_foxfire` «Лисьи огни» | `tb_torii` «Тысяча врат» |
| Ширин | S | «Семь колодцев» | `fr_g_shirin` | `s_monisto` «Монисто» | `tb_caravan` «Шатёр каравана» |
| Злата | SSR | «Лаковая сказка» | `fr_g_zlata` (already registered) | `s_lacquer` (already present) | `tb_lacquer_box` (already present) |

- **Accents:** reused from the stubs, with one fix. Kohaku's `deep` was ivory `f3efe9`, which I changed to `8a1f17`: every other kit's `deep` is a dark tone.
- **Signature tiles:** 1, 16, 31, 9, 12. All five kits keep `hidden: true`.
- **Tsubame and Miel (A) base tile:** they have no legacy skin of their own, so they show the default `s_sakura` with their accent colour, like the other A stubs.
- **SSR-outfit lift (`up`):** `tb_crimson` and `me_gala` lift the kit to S with their own theme and table.
- **Zlata:** keeps her full kit unchanged (palettes firebird / firebird / ember / dawn). Her fonts match spec D2 (Ruslan Display + Kurale) and the selfcheck verifies that.
- **Outfits:** `EXTRA_OUTFITS` holds all 18 as `[hero, rank, name]`.
- **Frames:** founders' frames are drawn in code, so these are data only, registered in `V10ProfileCos` with existing deco kinds:
  - Tsubame: silver ring, crimson moon.
  - Miel: honey ring, sugar pearls.
  - Kohaku: white ring, flames.
  - Shirin: sand-gold ring, sun rays.
- **HUD v2 accents (`HUD_HEROES`):** one per goddess, using the showcase elements leaf, spark, dust, spark and petal.
- **Combo lines (`COMBO_LINES`):** two per goddess, for tiers 2 and 3.
- **Combo sprite fallback:** `combo_sprite()` returns the wave-1 cut-out, or "" when the file is missing. `combo_meta()` takes the face rect from `w1_art_rig.json`, loaded once at runtime. Outfit images are not referenced anywhere, so a missing `sh_sun.webp` is harmless.

### Hooks for the integrator (exact code)
In Godot 4.5, `const` dictionaries are deeply read-only, so the overlay needs `const` turned into `static var`. No other consumer code changes: `look.gd`, `look_cos.gd`, `tile_picker.gd` and the look selftest keep working unchanged on these dictionaries.

**Pattern for hooks 1–4.** For each dictionary NAME listed below:
1. Rename `const NAME: = {` to `const NAME_BASE: = {`.
2. Directly after that dictionary's closing `}`, add:
```gdscript
# wave releases overlay full kits / themes here (V10W1Look.install() when V10Wave1.released())
static var NAME: Dictionary = NAME_BASE.duplicate(true)
```

1. `scripts/v10/look/kit_data.gd`: apply the pattern to `KITS` and `EXTRA_OUTFITS`.
2. `scripts/v10/look/tile_themes.gd`: apply the pattern to `THEMES` and `TABLES`.
3. `scripts/v10/hud2/tokens.gd`: apply the pattern to `HEROES`.
4. `scripts/v10/hud2/combo_showcase.gd`: apply the pattern to `LINES`, then make two more changes:
   - In `sprite_path()`, replace the final `return ""` with:
```gdscript
	return V10W1Look.combo_sprite(h, o, t) if V10Wave1.released() else ""
```
   - Replace the body of `sprite_meta()` with:
```gdscript
	var key: = path.get_file().get_basename()
	if not _meta.has(key) and V10Wave1.released():
		return V10W1Look.combo_meta(path)
	return _meta.get(key, {})
```
5. `wave1.gd` (`V10Wave1`), at boot or after the save loads, before any cosmetics list is built:
```gdscript
if released():
	var errs: Array = V10W1Look.install()   # idempotent; also registers the frames and resets V10LookCos
	if not errs.is_empty():
		push_warning("wave1 look: " + ", ".join(errs))
```
If a hook is missing, `install()` names the file that still has `const` and leaves that dictionary alone. When not released, nothing is overlaid and the stubs stay as they are.

A script that applies hooks 1–4 exactly as tested is at `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/apply_hooks.py`. Run it as `python3 -I apply_hooks.py <game/scripts/v10>`. The scratchpad may be cleared.

### Self-checks for `--wave1_selftest`
- `V10W1Look.selfcheck(false)` must return `[]`; it does on the real tree now. It covers:
  - five kits with ranks matching `V10ProfileCos.ROSTER`, correct signature tiles, `fr_g_<hero>` frames, valid particles and colours;
  - A kits carry only frame + accent; S kits have an existing theme and table; SSR has HUD, sting, font and a palette for every `zl_*` outfit;
  - every `up` entry is an SSR outfit of an A goddess, and every SSR outfit of Tsubame and Miel has one;
  - 18 outfits, base outfit rank equals the goddess's rank, `zl_*` matches `kit_data`;
  - theme and table keys follow the look selftest schema, theme signature equals the owner's, emblems exist, no ids already taken;
  - frame entries pass `V10ProfileCos.check_entry`;
  - Zlata's fonts are Ruslan Display + Kurale;
  - HUD element is valid and the HUD accent equals the kit accent; combo lines are 28 characters or fewer;
  - `V10Lint.scan` is clean and there are no Latin letters.
- After `install()`, `V10W1Look.selfcheck(true)` must return `[]`. It adds:
  - the resolve table, for example `tsubame/tb_crimson` gives S + `s_crimson_moon` + `tb_rooftops`, `kohaku/ko_kyubi` stays S, Zlata's palettes come out as expected, and only the SSR kit gets HUD, sting and font;
  - ranked mode shows standard faces;
  - the banner line `kit_line`;
  - `V10LookCos.validate_all()` is empty.
- After install, also run `V10LookSelftest.run(host)` and expect 861/861.

### Results of my own checks
- **Contrast:** the face contrast rule (ivory × tint against ink `3b2a2f`) gives 11.05 for `s_crimson_moon`, 11.54 for `s_sugar_lace`, 11.54 for `s_foxfire` and 11.56 for `s_monisto`. All are well above 4.5.
- **Stop-words:** grepping my files for the banned stems finds only the canonical outfit name «Тысяча и одна партия». `V10Lint` allows that phrase, and `V10Lint.scan` is clean.
- **Parse:** `--check-only` cannot pass here because the look dependencies reference the autoload `G`, which that mode doesn't load. I loaded and ran the file as a scene with autoloads instead: no script errors.
- **Render check:** a sheet rendered under xvfb shows all four themes on their tables, thumbs with the emblems, the four frames and the kit ribbons.