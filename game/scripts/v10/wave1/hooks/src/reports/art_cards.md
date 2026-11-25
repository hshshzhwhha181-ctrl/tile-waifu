## ART-CARDS (lane 4): report

All 18 outfit cards, 19 pose slots and the 18 audited emotions are built and imported. The 7 emotions that failed the audit are left out until their regenerated files land, and a re-run picks those up automatically. The Godot `--import` exited 0 with no errors, and every webp has its `.import` file.

### What's on disk
- **Outfit cards:** 18 of 18 in `/home/user/tile-waifu/game/assets/v10/wave1/outfits/<id>.webp`, 850×1280 RGB, webp quality 88. This includes `sh_sun`, built from `gen/sh_sun_pick.png`.
- **Pose slots:** 19 in `/home/user/tile-waifu/game/assets/v10/wave1/poses/<hero>_<slot>.webp`, height 1280.
  - Five `<hero>_idle` files made from the FINAL cards.
  - Fourteen base-outfit slots: tsubame select/shy/win, miel select/tease/lose, kohaku select/shy/win, shirin select/shy, zlata select/win/lose.
  - `tsubame_win` and `miel_lose` are 1280×1280.
  - `sh_sun` is not a base outfit, so it has no pose slot. Its face and modest-crop rects are in its `outfits` entry in the JSON.
- **Emotions:** 18 in `/home/user/tile-waifu/game/assets/v10/wave1/emotions/<hero>_<emo>.webp`, RGBA, 600×800 (the same box as the founders' files).
  - The cut-out starts from `isnet-anime` and is then cleaned against the grey backdrop: no grey halo, gaps between hair strands opened, stray specks dropped.
  - I checked every result on #1d1b2e and #f6efe6 contact sheets, with zoomed edge crops and face-mark overlays. The edges are clean; the only leftover is a faint trace of the painted, out-of-focus pearl strands next to Zlata's real pearl strings, visible only when zoomed in.
  - **Rule 1 (hip crop):** each heroine has a hard bottom limit in source pixels: tsubame 870, zlata 860, kohaku 950, shirin 960, miel 1000. These sit above every slit, thigh-high top and lace band. Your limits were 980 for tsubame and 880 for zlata, so these are stricter.
- **Measurements:** `/home/user/tile-waifu/game/scripts/v10/wave1/data/w1_art_cards.json`, in the shape you asked for, with three additions:
  - Outfits and poses also carry `face_c` and `face_w`.
  - Emotions carry a fractional `face` and `face_w` in file pixels.
  - A top-level `_meta` lists `pending`, `emotions_missing` and `emotions_auto` (emotions measured automatically, see below).
  - Rects are in pixels of the 850-wide art. `w1_ults.gd` already converts them to the 859×1280 art space.
  - I checked them against the `V9Ults` selftest rules: every face rect is square, inside the art and 180–480 px; every modest-crop rect contains the face centre and is taller than the face rect.
- **Face landmarks:** read by hand on gridded zooms and checked with marker overlays, to about ±3–5 px. They are stored per source file, with a hash of the file, in `/home/user/tile-waifu/game/scripts/v10/wave1/tools/w1_art_landmarks.json`.

### Still missing (failed the audit, waiting for regeneration)
tsubame_sad, miel_sad, kohaku_happy, shirin_happy, shirin_sad, shirin_pout, zlata_pout.

- **Rule 2:** these are marked rejected for their current file only, so no webp and no JSON entry exist for them. I deleted the stale `shirin_sad` and `zlata_pout` webps and their `.import` files. The runtime falls back to her base art.
- When a regenerated file lands under the same name, its hash differs, so the script builds it straight away. It places the face automatically by matching against her audited emotions (about ±10 px). The entry gets `"measured": "auto"` and appears in `_meta.emotions_auto`.
- I tested this with a simulated regenerated tsubame_sad and a missing zlata_shy, in a scratch copy of the repo. Both behaved as expected.

### How to re-run
Here `S=/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad`.

**One regenerated emotion:**
```
cd /home/user/tile-waifu && python3 -B game/scripts/v10/wave1/tools/w1_art_cards.py $S /home/user/tile-waifu --only tsubame_sad --cache $S/art/maskcache --sheets $S/art/sheets_rerun
```
Then refresh the import:
```
cd game && flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path . --import
```

**To bring an auto-measured face to ±5 px:**
1. Write a gridded zoom of her head:
   ```
   ... --measure gen/emo/emo_tsubame_sad.png --sheets $S/art/m
   ```
2. Store the eye and mouth points:
   ```
   ... --set gen/emo/emo_tsubame_sad.png=elx,ely,erx,ery,mx,my
   ```
3. Run the `--only` command above again.

**Other runs:**
- Everything: drop `--only`. It takes about 2 minutes with the mask cache.
- Cards and poses only: add `--skip-emotions`.
- Re-running gives byte-identical files.

### Notes
- No source card looked defective.
- The JSON path differs from the brief: I wrote `w1_art_cards.json` as the task asked, not the brief's `w1_art.json`. The consumers (`w1_core`, `w1_ults`, `w1_play`, `w1_mj`) already read `w1_art_cards.json`.
- I wrote only under `game/assets/v10/wave1/{outfits,poses,emotions}`, `game/scripts/v10/wave1/tools/` (`w1_art_cards.py`, `w1_art_landmarks.json`) and that one JSON. No git.
- The contact sheets are in `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/art/sheets_all/`.