## Lane 4 (gacha and audio) for Tile Waifu 0.10 wave 1: done

Both scripts parse clean, and the selfchecks pass 54/54. I made no git changes and edited nothing outside `game/scripts/v10/wave1/**`.

### Files
- **`/home/user/tile-waifu/game/scripts/v10/wave1/data/w1_banners.json`**
  - Uses the v10/gacha banners.json schema with ver 1, the same anchor (2026-11-23) and 21-day phases. It takes over from phase idx 4 (2027-02-15) with 12 phases that alternate A/B.
  - **«Масленица»:** idx 5, B half, 2027-03-08…03-29.
    - ssr is [zl_base, o_dragon]; the default target is zl_base.
    - `debut: zlata`, art `res://assets/v10/wave1/gacha/key_maslenitsa.webp`, font zlata.
    - fest «Масленичная неделя» runs 03-08…03-15, which covers Zlata's birthday on 18 March.
  - **Rerun:** «Жар-птица и Царица-пламя», idx 15 (2027-10-04), which is ≥ 180 days later.
  - **Kohaku and Shirin:** each is an S rate-up in ≥ 3 phases.
  - **Tsubame and Miel:** their bases are in the standard pool from release.
  - **Zlata:** stays banner-only until `std_entry` 2027-10-25.
  - Also included:
    - login7 «Семь писем Цубамэ» (tb_base, from 2027-04-05) and «Семь угощений Миэль» (me_base, from 2027-07-05);
    - event bake_1 «Испечь вместе», whose track reward is me_parlor;
    - econ entries lim_zlata and rerun_zlata.
- **`/home/user/tile-waifu/game/scripts/v10/wave1/w1_gacha.gd`** (`V10W1Gacha`, 636 lines)
  - Holds the 18 outfits with ranks; the vows ko_vow and zl_vow are excluded from all draws.
  - Main helpers:
    - `merge(base, keep_t)` and `droppable(id, owns, t)`;
    - `shop_ok(id, owns)` and `limited_now(t)`;
    - `std_notice(t)` and the `login7_*` functions (Tray card, granted once);
    - `econ_banners(base)` and `selfcheck(items, base)`.
  - `SHOP = {ko_matsuri: 480, sh_oasis: 480}` copies V10W1Core.ITEMS (`shop` + `nogacha`). These two are sold only to players who already own the heroine.
  - There are no per-item petals or constellation tables, so I added none.
- **`/home/user/tile-waifu/game/scripts/v10/wave1/w1_audio.gd`** (`V10W1Audio`, 572 lines)
  - **MOTIFS:** each goddess has a Russian description plus an `elevenlabs_music_v2_5` prompt in the AUDIO_BIBLE §9.3 template (30 s, batch 4).

    | Goddess | Tempo, key | Instruments |
    |---|---|---|
    | Цубамэ | 112 BPM, B minor | shakuhachi + taiko rim |
    | Миэль | 102 BPM, F major | music box + pizzicato |
    | Кохаку | 98 BPM, E minor | koto core + suzu |
    | Ширин | 94 BPM, D minor | oud + ney + darbuka |
    | Злата | 108 BPM, A minor (the §5.3 slot) | gusli + balalaika + wordless choir «ой» |

  - **STINGS.zlata:** short and full stings at the exact paths V10KitData.STINGS already reads.
  - **SFX:** 10 `w1_*` entries in the V10SfxBank.BANK schema with `mirelo_text_to_audio` prompts.
  - **VOICED:** 24 lines per goddess, 120 in total. They are the first lines of each kind in `V10W1HomeLines.BARKS`, so the subtitle always equals the recording.
  - **VOICE_CAST:** a voice description per goddess (model elevenlabs_v4, fallback qwen_audio_tts, language ru).
  - **Helpers:** `pending()`, `voice_json()`, `speak()` (spells «SSR» as «Эс-эс-эр», drops «~»), `selfcheck()`.
  - Note: I synced 2 lines after the home lane had shortened them: tsubame hint and miel skill.
- **`w1_gacha.gd.uid`:** Godot created it during the earlier import.

### Checks
- **Parse:** `timeout … flock /tmp/tw-godot.lock godot --headless --check-only --script` gives exit 0 for both files. I confirmed this mode does report parse errors.
- **Selfchecks:** a SceneTree runner in the scratchpad gave 32/32 for gacha and 22/22 for audio.
- **Gacha against ITEMS:**
  - Run against V10W1Core.ITEMS, it gives 33/34. The one failure is that `res://scripts/g.gd` fails to compile when loaded from a bare `--script` runner (runtime error "Nonexistent function 'stages'" at g.gd:125). That is not my file.
  - I verified the founder ranks against the g.gd text instead, and all 9 match. The integrator's selftest should pass `G.ITEMS` + `V10W1Core.ITEMS`.
- **JSON:** `python json.load` passes, and the merged result is checked against V10Banners rules (alternation, grid, phase shape).
- **Banned stems:**
  - The JSON has no hits.
  - In the .gd files the only hits are the BANNED lists themselves. I reworded two internal notes that accidentally contained «одна» (inside «холодная» and «народная»).
  - Heroine lines also pass V10Lint.check plus the red-line and UX-jargon list, and contain no Latin except «SSR».

### Hooks (each behind `V10Wave1.released()`; the facade belongs to the integrator)

**H-G1, `v10/gacha/banners.gd` `data()`.** After `_data = d`:
```gdscript
				if V10Wave1.released():
					_data = V10W1Gacha.merge(_data, V10Wave1.release_t())  # 0 if unknown: wave-1 phases start at idx 4
```
- `merge()` keeps base phases up to and including the one live at `keep_t`.
- Base phases after that are replaced by the wave-1 list, and the result gets `out.w1 = {from_idx, splice}`.
- The facade must set `V10Banners._data = {}` whenever the flag changes.

**H-G2, `v10/gacha/gacha2.gd`.** In `pool()`, after the start/nogacha/hidden/limited `continue`:
```gdscript
		var wid: = String(it.get("id", ""))
		if V10W1Gacha.is_w1(wid) and not (V10Wave1.released() and V10W1Gacha.droppable(wid, bank.owns, V10GClock.now())):
			continue
```
In `_grant`, after `var is_new: = bank.give(id)`:
```gdscript
	if is_new and V10W1Gacha.is_w1(id):
		_pool = {}
```
- No separate rule is needed for the featured SSR: the target and s_up are drawn with `item(id)`, not from the pool. So zl_base drops on «Масленица» while staying out of the standard pool until 2027-10-25.

**H-G3, `v10/gacha/ui/wish_screen.gd` `_title_block`, line 299:**
```gdscript
			over = "%s · %s" % [cur_b.name, "новая героиня" if String(cur_b.half) == "A" or cur_b.has("debut") else "цель на выбор"]
```

**H-G4, `wish_screen.gd` `_art_layer`, replacing the `if k == "phase":` branch:**
```gdscript
	if k == "phase":
		var own: = String(cur_b.get("art", ""))
		bg_path = own if own != "" and ResourceLoader.exists(own) else ("res://assets/v10/gacha/key_new_moon.webp" if String(cur_b.get("half", "A")) == "A" else "res://assets/v10/gacha/key_full_moon.webp")
```

**H-G5, `v10/shop/hub.gd` `items_fn`.** Add this to the outfit condition:
```gdscript
					and (not V10W1Gacha.is_w1(String(it.get("id", ""))) or (V10Wave1.released() and V10W1Gacha.shop_ok(String(it.id), _m.owns_fn)))
```

**H-G6, economy (optional):** `econ.gacha.banners = V10W1Gacha.econ_banners(V10Catalog.BANNERS)` when released.

**H-G7, V10Tray (at install):**
```gdscript
var w1_give: = func(r: Dictionary) -> void:
	if String(r.get("kind", "")) == "item":
		G.give(String(r.id))
V10Tray.register("w1_login7", func(k): return V10W1Gacha.login7_card(G.S, String(k), V10GClock.now(), w1_give) if V10Wave1.released() else {}, 85)
```

**H-G8, Афиша (meta lane):**
- When released, add the rows `V10W1Gacha.std_notice(V10GClock.now())`. Each row is `{hero, ids, t, text}`, for example «С 25 октября Злата — в постоянных желаниях: …».
- Rows appear only in the 14 days before the date, so there are no countdowns longer than 48 h.

**H-A1, `v10/audio/v10_music.gd`.** In `motif()`, first:
```gdscript
	if V10Wave1.released() and V10W1Audio.motif_ready(hero):
		inst()._call("_play", [V10W1Audio.track_id(hero), fade])
		return
```
In `path_of()`, first:
```gdscript
	if V10W1Audio.has_track(track_id):
		return V10W1Audio.track_path(track_id)
```
In `_stream()`:
- change the guard to `if not TRACKS.has(track_id) and not V10W1Audio.has_track(track_id): return null`;
- set the loop with `st.loop = bool(TRACKS[track_id]["loop"]) if TRACKS.has(track_id) else V10W1Audio.track_loops(track_id)`.

**H-A2, `v10/audio/v10_sfx_bank.gd`:**
- `has`: `return BANK.has(id) or (V10Wave1.released() and V10W1Audio.is_sfx(id))`
- `path_of`, first line: `if V10W1Audio.is_sfx(variant): return V10W1Audio.sfx_path(variant)`
- `_play`: replace the guard and the `BANK[id]` read with:
  ```gdscript
  	var e: Dictionary = BANK.get(id, {})
  	if e.is_empty() and V10Wave1.released():
  		e = V10W1Audio.sfx_entry(id)
  	if e.is_empty():
  		push_warning("V10SfxBank: unknown id %s" % id)
  		return
  ```
- `voice_path`, first line: `if V10Wave1.released() and V10W1Audio.is_hero(hero): return V10W1Audio.voice_path(hero, kind, 0)`
- `_voice_text`, first line: `if V10Wave1.released() and V10W1Audio.has_voice(hero, kind): return String(V10W1Audio.lines(hero, kind)[0])`

**H-A3, `sfx.gd` `say()`.** This needs the home lane's hook that puts `V10W1HomeLines.BARKS` into `src`; use one hook for the text source, not two. After `var arr: Array = src[hero][kind]`:
```gdscript
	var vo: Dictionary = VOICED
	var w1: bool = V10Wave1.released() and V10W1Audio.is_hero(hero)
	if w1:
		vo = V10W1Audio.VOICED
```
- Replace `VOICED` with `vo` in the override line and in the `voiced_ok` line.
- Replace the path line with:
  ```gdscript
  	var path: = V10W1Audio.voice_path(hero, kind, i) if w1 else "res://assets/voice/%s_%s%d.mp3" % [hero, kind, i + 1]
  ```
- As with the founders, the kinds match, combo, fever, win, lose and hint then use only the voiced lines.

**H-A4, `v10/audio/pipeline/voice_check.py`.** Add an optional third argument: `EXTRA = json.load(open(sys.argv[3], encoding="utf-8")) if len(sys.argv) > 3 else {}`.
- Set `want = EXTRA[name]["speak"] if name in EXTRA else TEXT.get(kind, {}).get(hero, "")`.
- Guard the empty reference set: `ref_f0[hero] = float(np.median(...)) if refs else 0.0`. The new goddesses have no reference voice files.
- The JSON comes from `print(V10W1Audio.voice_json())`.

**Stings:** no code change is needed. V10KitData and V10HudSkin already read `zlata_short.ogg` and `zlata_full.ogg`, and stay silent until the files exist.

### Pending assets (nothing generated yet; `V10W1Audio.pending()` lists all 137 with model, parameters and prompt or text)
- 5 motifs: `res://assets/v10/wave1/audio/music/motif_{tsubame,miel,kohaku,shirin,zlata}.ogg`
  - elevenlabs_music_v2_5, 30 s, then v10_loop.py to a 12–24 s loop at −16 LUFS.
- 2 stings: `res://assets/v10/audio/sting/zlata_short.ogg` (generate 4 s, keep 1.5 s) and `zlata_full.ogg` (generate 8 s, keep 5 s).
  - These paths are fixed by kit_data and sit outside the wave1 write zone, so whoever generates them must write there.
- 10 SFX: `res://assets/v10/wave1/audio/sfx/w1_{tb_smoke,tb_kunai,me_sugar,me_oven,ko_suzu,ko_foxfire,sh_coins,sh_sand,zl_feather,zl_wings}.ogg`
  - mirelo_text_to_audio, 1–2 s, −14 LUFS.
- 120 voice lines: `res://assets/v10/wave1/audio/voice/<hero>_<kind><n>.ogg`, n counted from 1.
  - elevenlabs_v4 (or qwen_audio_tts) in Russian, one designed voice per goddess from VOICE_CAST, −14 LUFS, checked with voice_check.py.
- Key art: `res://assets/v10/wave1/gacha/key_maslenitsa.webp`. With H-G4 the screen falls back to key_full_moon until it exists.
- The login7 icons `assets/v10/wave1/outfits/tb_base.webp` and `me_base.webp` already exist.

### Environment
The session's setup script failed at build (exit 127): `/tmp/init-script-…sh: line 4: permissions:: command not found`. A settings fragment (`permissions:`) has been pasted into the bash setup script, and that line should be removed or moved to settings.json. I did not change the environment because it is outside this lane and needs the owner's approval. Godot at `/opt/tw-tools/godot` is present and works.

Scratch runners are in `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/w1ga/`: `run_w1ga.gd` runs both selfchecks and `items.gd` runs the ITEMS check.