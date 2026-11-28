# tools/ — QA runner (`tw_test.py`), baseline, CI

`tools/tw_test.py` is the one cross-platform entry point for every automated gate in the repo. It replaces
`.agents/skills/tw-godot-qa/scripts/godot_qa.ps1` (now a 20-line shim that forwards here).

| gate | suites | how it is judged |
| --- | --- | --- |
| Godot selftests | 57 (10 core (8 flags + `state` + `twboard`), 43 v10 registry modules, `registry`, `spec`, `summon`, `ult_rin`) | marker line of each suite (`ECON_SELFTEST 384/384`, `V10VOICE OK`, ...) |
| Godot selftest `twparity` | 1 (core, P17) | `TWPARITY_SELFTEST n/n`: TWBoard vs the legacy TrayBoard. 500 recorded games (`game/tests/fixtures/replays/corpus_NN.json`, written from the REAL TrayBoard by `scripts/v10/rules/parity_record.tscn`) replayed on TWBoard with 0 divergences of legality / outcome, the stored layouts == `TWFree.positions`, 1000/1000 level certificates replay on TWBoard, live fuzz of 5000 operations in lockstep with a real TrayBoard (free set: legacy `is_free` == TWBoard counters == `TWFree.is_free`). `--fast` = 100 games, 200 levels, 1000 fuzz operations |
| `server/e2e_test.mjs` | `server_e2e` | `E2E_OK`, `N passed, 0 failed` (skipped with a reason if node or `node:sqlite` is missing) |
| Godot selftest `slice` | 1 (core, P37) | `SLICE_SELFTEST n/n` (renders: xvfb): the vertical slice driven through the screen API (`game/shell/tests/slice_playthrough.gd`, run as `res://shell/main_v11.tscn -- --slice=play`): N bot games (100; `--fast` 20), each Home -> `TWScreens.go("match")` -> bot (solver / hint / random / mixed, taps by `tap_tile` and by the view's `tile_tapped`) -> victory modal buttons -> Collection / Wish / Shop opened through `LegacyHost.open`. Per game: 0 SCRIPT ERROR / engine ERROR (the 2 known teardown noises excepted), no modal leak, one modal per win, none per loss; a watchdog quits with the stage name when no event happens for 10 s (a hang is a red line, not a suite timeout) |
| `slice_goldens.py` | `slice_goldens` (P37, full only) | `SLICE_GOLDENS n/n`: Home / Match / Result / Collection / Wish / Shop at 720x1280, 720x1600, 1536x2048 rendered by the game (xvfb, `--fixed-fps 60`, frozen calendar, effects min) vs `game/tests/goldens/<WxH>/<screen>.png`: <= 1.5 % of the pixels may differ by > 24/255. `--update` re-records (renders twice; the pixels that differ between the two renders = live heroine art are written as `<screen>.mask.png` and ignored). The folder has a `.gdignore`: not imported, not in the pack |
| `perf_budget.py` | `perf_budget` (P37, full only) | `PERF_BUDGET n/n`: p95 frame cost of a live 60-tile round (`--slice=perf`: view timeline + draw list) <= 16.6 ms, headless and under xvfb/llvmpipe; the 135 MB pack check (`--export-pack Android-store`, 134.50 MB at P37) runs unless `--no-pck` is given. `game/tests/fixtures/` carries a `.gdignore` so the 1.9 MB of test replays are not exported. Always labelled "device not verified": the phone is the owner's M2 check |
| Godot selftest `twresult` | 1 (core, P33) | `TWRESULT_SELFTEST n/n` (renders: xvfb): victory screen `TWResultChain` / `TWResultModal` (`game/shell/screens/match/`): milestones -> fast (<= 3 s to the button) or chain (<= 20 s, 3 panels, 1 Confirm), tap / Skip state machine + 500 random sequences, fixed button rects, 0 banned words (`остал...`, sales), real-time <= 3 s, pixels, `TWMatchScreen` hook |
| Godot selftest `twboardview` | 1 (core, P31) | `TWBOARDVIEW_SELFTEST n/n` (renders: runs under xvfb): `TWBoardView` + `TWMatchScreen` (`game/shell/screens/match/`). Layout (field >= 92% x 60%, tile 56/64/72/80 at 720), 20/20 core events animated, 100 games with and without the view give the same events and state hash, view mirror == board, pixel contrast (plate vs table >= 4.5:1, blocked >= 65% of free), 60-tile frame cost p95, TWScreens `match`. `--fast` = 40 games |
| Godot selftest `round` | 1 (core, P20) | `ROUND_SELFTEST n/n`: `TWRound.resolve` + `TWBoosters` + `TWModeCfg` + `TWRewards` (`game/core/round/`). 139-row table (expected values from an independent python model, `tools/gen_round_table.py`), 300-scenario diff vs the frozen legacy award code, rank ladder == `G`, bot rounds through `TWRoundStats`, the outfit does not change the result, no «осталось сегодня» field, wallet payment, core purity |
| `lint_no_direct_wallet.py` | `no_direct_wallet` (P10) | `NO_DIRECT_WALLET SELFTEST 24/24 PASS` + repo has 0 direct writes of `S.gems|coins|tickets|petals|moon` outside `game/core/economy/tw_wallet.gd` (a line may carry `# wallet-lint: ok <reason>`: raw-dict migrators, the guard's own test) |
| `lint_screen_has_spec.py` | `screen_has_spec` (P23) | `SCREEN_HAS_SPEC SELFTEST 7/7` + repo has 0 violations (a screen folder without `spec.tres`, bad/duplicate ScreenSpec, a `TWScreen` outside `shell/screens/`) |
| `lint_modal_only_via_stack.py` | `modal_only_via_stack` (P24) | `MODAL_ONLY_VIA_STACK SELFTEST 14/14` + shell has 0 violations + the legacy overlay-scan sites (report mode, 39) do not grow vs `tools/lint_modal_baseline.json` |
| Godot selftest + `legacy_host_shots.py` | `legacy_host` (P25) | `LEGACY_HOST_SELFTEST 314/314`: the v11 root `main_v11.tscn` (LegacyHost) boots Home, keeps the old `main` API, catalogue == `SCREENS` (46 ids), each legacy screen opened + closed through the host with 0 script errors / modal leaks. `tools/legacy_host_shots.py` (manual acceptance, not a suite) compares 6 screens default launch vs `--shell=v11` at 720x1280 |
| `slice_reel.py` / `slice_boot.py` | (P38, not suites) | `slice_reel.py --out design/slice_gate`: 3 screen recordings (720x1280, 720x1600, 1536x2048), >= 90 s of game time each, the solver bot playing whole rounds at a human pace (`--slice=reel`); `slice_boot.py --runs 5`: cold start split (engine -> host, Home, first board) + static memory peak (`--slice=boot`). Both on software GL: "device not verified". Report: `design/SLICE_REPORT.md`. `slice_goldens.py` / `slice_tour.py` pin the Home hour (`--v7_hour=12`): `V7DayNight` tints Home by the SYSTEM clock |
| `lint_asset_id_only.py` | `asset_id_only` (P29) | `ASSET_ID_ONLY SELFTEST 13/13` + `game/shell` has 0 `res://assets` literals (exempt: `shell/assets/`, selftests) + the legacy literals (report mode, 493) do not grow vs `tools/lint_asset_id_baseline.json` |
| `ux_lint.py` | `ux_lint` | `UX_LINT RESULT: OK (0 violations)` (lives at `.agents/skills/tw-godot-qa/scripts/ux_lint.py`, verified present) |
| `audio_gate` | 1 (`--selftest`) | `AUDIO_GATE SELFTEST 50/50`: loudness meter vs 12 synthetic signals with known loudness (<= 0.3 LU), true peak, leading silence, verdict rules |

## Use

```bash
export GODOT_BIN=/path/to/Godot_v4.5.1-stable_linux.x86_64     # or --godot PATH, or godot4/godot on PATH
python tools/tw_test.py --list                 # ids, group, fast?, render?, timeout, marker
python tools/tw_test.py --fast                 # 47 suites, cheap Monte-Carlo args  -> ~150 s on 4 cores
python tools/tw_test.py                        # all 56 suites, full counts        -> ~490 s on 4 cores
python tools/tw_test.py -s mj_riichi,economy   # chosen ids / groups (core,v10,extra,server,lint) / `_selftest` names
python tools/tw_test.py -j 2 --timeout-scale 2 # slower machine
python tools/tw_test.py --update-baseline      # rewrite tools/baseline.json (full, or fast with --fast)
python tools/tw_test.py --import               # headless asset import (automatic when game/.godot is missing)
python tools/tw_test.py --shot home --out /tmp/home.png --res 450x1000 --at 2
python tools/tw_test.py --check-drift          # every game/core/**/module.gd selftest module is in the catalog (and no duplicate ids)?
```

Exit code: `0` no regression vs `tools/baseline.json`, `1` regression, `2` setup problem (no Godot, import failed).
`--no-baseline` / `--strict` make any red suite fail. Per-suite logs go to `$TMP/tw_test_logs` (`--logs DIR`); `--json FILE` dumps results.

`--fast` = suites flagged `fast` (everything except `salon`, `mj_look`, `mj_riichi`, `mj_sanma`, `mj_classic`, `mj_connect`,
`mj_bridge`, `duels`, `challenge`) with each suite's `fast_args` (riichi/sanma `--games=20`, koikoi `--games=100`, `--econ_mc=0.1`,
`--levels_n=200`, `--mc=0.5`, `--hand_real=24`, tower sub-flags instead of the 6 min full matrix). Rendering suites run under `xvfb-run -a`
on Linux without `$DISPLAY` (skipped with a reason if xvfb is absent).

## How a suite is judged

* The **last line containing the suite's marker** (case-insensitive) is parsed. `n/m` after the marker must be equal and `m > 0`.
* Any `FAIL` line or `SCRIPT ERROR:` line in the output is a failure id (numbers, floats and `[..]` lists are normalised so ids are stable).
* **rc is not trusted**: `0`, `134`/`-6` (SIGABRT), `139`/`-11`, `0xC0000005` count as "process ended" and the suite is green only if the
  marker is green and there is no `SCRIPT ERROR`. Any other rc is red. No marker = `error`; no exit within the limit = `timeout` (process tree is killed).
* `soft` regex per suite = timing budgets that fail on software GL / loaded CI boxes but not on a GPU (`mj_look: perf.144_le_16ms`,
  `path: map builds in <250 ms`). They are reported but do not turn the suite red.
* Each Godot process gets its own `HOME`/`APPDATA`/`XDG_*` temp dir, so parallel suites never share `user://` saves.

## Baseline (`tools/baseline.json`, frozen at tag `v10-freeze`)

Per suite and per mode (`full` / `fast`): `status`, `ok`, `total`, `secs`, `expected_fail` (normalised failure ids), last `marker`.
A run **fails** when a suite: was `pass` and is not; is red with a failure id not in `expected_fail`; has `ok` below baseline or `total`
below baseline (checks silently removed); times out / has no marker where the baseline had one; or is a new suite and red. It **reports "improved"**
(and you should `--update-baseline`) when ok/total grow or a known failure disappears. Known failures stay green for the gate:

| suite | frozen result | cause (from logs; not fixed here) |
| --- | --- | --- |
| `ults` | 662/682 | 18x "ULTS has tb_/me_/ko_/sh_/zl_*" + `SCRIPT ERROR ... 'tsubame'`: wave-1 goddess outfits/ults are not wired into core `G`/`V9Ults` data (art is not under `res://assets/outfits/`) |
| `letters` | 4330/4355 | wave-1 goddesses have < 2 letter variants (`kohaku`, `zlata`, ...) + `SCRIPT ERROR ... 'hand'` in `letters_selftest.gd:206` |
| `profile2` | 110/112 | "unreleased goddess frame hidden/invalid" + missing `res://assets/outfits/tb_base.webp` -> `card_art` null deref |
| `challenge` | 285/291 | 6 `ui:` checks "<= 4 type sizes" (typography budget) |
| `tower` | 6842/6880 (full only; `fast` is green 198/198) | 38 x "<= 4 type sizes + overline" at 720x1280 in the full UI matrix |

`challenge`/`tower` are typography checks that I did not verify on a Windows/GPU box; they may be platform dependent (fonts) — check there before "fixing".
The other 48 Godot suites + `server_e2e` + `ux_lint` are green: 50/56 full, 43/47 `--fast` (the known reds in `--fast` are `ults`, `letters`, `profile2`; `summon` became green in P09).

## Measured performance (4 vCPU, 15 GB, Godot 4.5.1 headless, software GL via xvfb for 4 render suites)

`--fast` subset (47 suites, sum of per-suite time ~560 s serial):

| `-j` | 1 | 2 | 3 | 4 | 6 |
| --- | --- | --- | --- | --- | --- |
| wall | 567 s | 287 s | 189 s | 148 s | 133 s (and `path` flaked its 250 ms budget) |

Default `-j = min(4, cpu_count)`. Full run `-s all` at `-j 4`: 489 s (longest single suites: `tower` 353 s, `mj_riichi` ~400 s at `-j3`,
`mj_sanma` ~200 s). Godot startup is ~5-6 s per process, so most suites are 6-30 s.
First checkout needs `--import` (~110 s cold, 14 s warm).

## SIGABRT at quit (rc 134, "corrupted size vs. prev_size in fastbins") — findings

Output is always complete before the abort; every suite prints its marker and then glibc aborts in `free()` during engine teardown.
Windows shows the equivalent `0xC0000005`. Facts established (timeboxed, ~35 min):

* **Not the selftests, not audio, not rendering.** A 3-line `SceneTree` script that only prints and calls `quit(0)` aborts the same way as
  soon as the project's `G` autoload (`scripts/g.gd`) is loaded; every other autoload alone is clean; an empty Godot project is clean.
* Not influenced by: `--audio-driver Dummy` (present or absent), `--rendering-driver` (opengl3 under xvfb / headless dummy / vulkan flag),
  `--single-threaded-scene`, `--disable-crash-handler`, `--text-driver Dummy`, `--display-driver headless`, `MALLOC_CHECK_=3`,
  `MALLOC_ARENA_MAX=1`, `MALLOC_PERTURB_`, `glibc.malloc.tcache_count=0`. With `glibc.malloc.mxfast=0` the message just changes to
  "double free or corruption (!prev)" — it is a real double free / use-after-free, not a glibc heuristic.
* valgrind (3.22) on that trivial script: 128 errors / 64 contexts, all inside the engine's shutdown call chain: 55 invalid reads
  (`pthread_mutex_lock` on a freed 1,752-byte block), 7 invalid writes and an invalid `free()`. The official 4.5.1 binary is stripped, so
  frames are unsymbolised; this looks like an engine-side use-after-free of an object holding a mutex (GDScript/script-class teardown), triggered
  by something `G._ready` registers. Bisecting `G._ready`: the abort needs `V10Registry.load_all()` (before P07: `V10RegistryList.register_all()`, now the `module.gd` scan)
  and is layout dependent — cutting the old `register_all()` before `V10AdventureReg.register()` removed it, but even a bare
  `V10Registry.module("adventure", {"step": 4})` brings it back, so the trigger is the amount/shape of registered data
  (many `Callable` lambdas stored in static dictionaries), not a specific module.
* Not a test failure source, so the runner simply ignores the abort when the marker is green.
* Ideas not tried (need a symbolised engine): build Godot 4.5.1 with `debug_symbols=yes` and rerun valgrind; try 4.5.2/4.6; stop keeping
  lambdas/Callables in `static var` dictionaries of `V10Registry` (clear `_mods` on `NOTIFICATION_PREDELETE`/before `quit()`).

Update (P02 spike): root cause narrowed to `V10Registry.load_all()` retaining lambda-bearing spec Dictionaries in static storage; full matrix and
bisect in [docs/qa/SIGABRT_SPIKE.md](../docs/qa/SIGABRT_SPIKE.md). `python tools/tw_test.py --no-mask-rc` accepts only rc 0 / 134 / -6 (a SIGSEGV
139 / -11 or `0xC0000005` fails the suite); CI runs with it.

## CI

`.github/workflows/qa.yml` (ubuntu-24.04, Godot 4.5.1 downloaded from the official release, node 24, python 3.12, xvfb + GL libs, cached `game/.godot`):
PRs run `--fast`, pushes to `v10-integration`/`main` run the full set, `workflow_dispatch` lets you choose. Logs/JSON are uploaded as an artifact.
The workflow has not run on GitHub yet (only locally validated: same command, same Godot, same xvfb).

## Adding a suite

Add one `S(...)` line to `CATALOG` in `tw_test.py` (id, marker, scene/script, args, optional `fast_args`, `render`, `timeout`, `soft`), then
`python tools/tw_test.py -s <id> --update-baseline`. `--check-drift` fails if a `module.gd` appears under `game/core` without a catalog entry (or two modules share an id). `--registry-dump [FILE]` prints/writes a canonical JSON dump of the whole registry (ids in order, specs, depth graph, screens, ensure keys, wiring flags): diff two dumps to prove a registry change is behaviour-neutral.

## Core carve-out (WP3): `game/core`, `move_map.tsv`, two checkers

`game/core/` holds every UI-free script of the v06-v10 logic (`extends RefCounted/Resource`, no Node/Control/Tween/Audio tokens;
209 scripts, ~54k lines, plus their `.uid` files and the `data/*.json` they load). Files were moved with `git mv` (history kept), every
`class_name` is unchanged, so class references do not change; only path literals (`preload`/`load`/`extends "res://..."`, scene `ext_resource`s,
selftest source scans, `tools/tw_test.py`, `ux_lint.py`) were re-pointed. `project.godot` (autoloads) and `export_presets.cfg` are untouched.

| where it was | where it is |
| --- | --- |
| `scripts/v10/mj/<mode>/` | `core/modes/<mode>/` (`tower`, `duels`, `adventure`, `palm` also under `core/modes/`) |
| `scripts/v10/core/` | `core/base/` (`registry*.gd`, `money`, `rank`, `sku`) |
| `scripts/v10/<module>/` (economy, gacha, levels, meta, shop, rituals, wave1, ...) | `core/<module>/` |
| `scripts/v06..v09/<group>/` | `core/v06..v09/<group>/` |

Anything with a UI token, a Node base class, an autoload, or living in a presentation dir (`hud2`, `hudfx`, `fonts`, `juice`, `mj/stage`,
`mj/look`, `tower/ui`, `rig`, `audio`, `ult`, `clarity`, `responsive`, `events`) stays in `game/scripts` (the future shell / legacy).

* `tools/move_map.tsv` — every move (`old<TAB>new`, repo-relative; `.gd`, `.gd.uid` and data files).
* `python3 tools/check_move_map.py` — proves each move is mechanical: old path gone, new path present, content identical to the pre-move commit
  except for lines that mention a `res://` path. Exit 0 = clean.
* `python3 tools/lint_core_purity.py [--files|--by-file] [--json F] [--check] [--selftest] [--update-baseline]` — CORE_PURITY lint (pure Python, ~0.5 s).
  Six categories: NODE_BASE (`extends` a Node-family class), NODE_API (Node/Control/Tween/create_timer/get_tree/DisplayServer, incl. `await get_tree()`),
  AUDIO_FX (`Sfx`/`V9Feel`), AUTOLOAD_G (`G.`, the god-object that WP4/`TWState` removes), ROOT_PATH (`/root/`), SHELL_DEP (core names a `game/scripts` class).
  Comments and string literals are ignored. Default = report (exit 0). `--check` is the **ratchet**: counts per file/rule are frozen in
  `tools/lint_baseline.json` (total N); any growth or any new violating file is red, fewer is fine, then lower N with `--update-baseline`
  (it refuses to raise N without `--allow-raise`). `--selftest` = 6 synthetic files with one violation each must give exactly 6 findings (+1 clean look-alike).
  Runs as suite `core_purity` (group `lint`, fast) in `tools/tw_test.py` and as the first step of `.github/workflows/qa.yml`.
* `python3 tools/lint_no_direct_levels.py [--selftest] [--check]` (P19) — the Path table is read through `TWLevels.at(n)` (`game/core/levels/tw_levels.gd`) only;
  `G.LEVELS[i]` / `gg.LEVELS[i]` / bare `LEVELS[i]` / `= G.LEVELS` aliases outside tw_levels.gd are red (`.size()` and iteration stay allowed). Direct indexing
  returns a lazy stub for arcs not built yet - that is how trial mode played the boss levels 499/699/799/899/999 as plain rectangles.
  Runs as suite `no_direct_levels` (group `lint`, fast) and as a CI step; the `tw_levels` suite proves the trial cfg of those levels equals the Path board.
* Registry (P07): `registry_list.gd` is gone. Each of the 43 modules is `game/core/**/module.gd` (`static func spec() -> Dictionary`, same ids, explicit `order` = old line order) and `V10Registry` finds them by scanning `res://core`; callbacks that used to sit between the list lines are a module's `"wire"` Callable. A new module is ONE new `module.gd`; the `registry` suite (`REGISTRY_SELFTEST`) guards the 43 legacy ids and their order.
* Selftests that source-scan a module directory now scan `scripts/v10/<m>/` **and** `core/<m>/` (so nothing silently stops being checked).
* After pulling this change run `python3 tools/tw_test.py --import` once: `game/.godot/global_script_class_cache.cfg` must be regenerated for the new paths.
`python tools/tw_test.py -s <id> --update-baseline`. `--check-drift` fails if a module appears in `V10RegistryList` without a catalog entry.

## Audio loudness gate (P45, GDD s8.1 / s11.5 / N14)

`tools/audio/lufs_gate.py` measures every ogg / mp3 / wav under `game/assets` and `audio/` and writes
`tools/audio/audio_report.csv` (all files) and `tools/audio/audio_outside_contract.csv` (only the files that break the contract).

```bash
python tools/audio/lufs_gate.py -j 4          # ~20 s for 785 files on 4 cores; add --strict to exit 1 when anything is outside
python tools/audio/lufs_gate.py game/assets/v10/voice/rin --csv /tmp/rin.csv
python tools/audio/lufs_gate.py --selftest    # also what tw_test runs as suite `audio_gate`
python tools/audio/normalize.py game/assets/voice --kind voice --report --trim-lead      # dry run of a fix
python tools/audio/normalize.py DIR --kind music --out /tmp/fixed                        # write corrected copies
```

Dependencies: python3 + numpy and ffmpeg (decoding only; ffmpeg `ebur128` is used as an independent cross-check in the selftest, when present).
No pyloudnorm / scipy needed: the meter is a from-scratch BS.1770-4 (K-weighting, 400 ms blocks, absolute -70 and relative -10 LU gates).
Its values agree with pyloudnorm on the existing music loops (approved_metrics.json) within 0.1 LU and with ffmpeg ebur128 within 0.06 LU.

| class (by path) | checks |
| --- | --- |
| music (`/music/`, `/daynight/`, `koikoi/audio`) | -16 +-1 LUFS, true peak <= -1 dBTP |
| voice (`/voice/`, root `audio/`) | -14 +-1 LUFS, true peak <= -1 dBTP, leading silence <= 40 ms (first sample above -50 dBFS), spread inside one heroine +-1 LU vs her median, heroine medians within +-1.5 LU of the median of all heroines |
| sfx / ui (`/sfx/`, `/fx/`) | sample peak <= -5 dBFS (target -6, 1 dB tolerance), true peak <= -1 dBTP |
| ambient (`/amb/`) | true peak <= -1 dBTP |

Conventions: voice mono files are measured as the plain file (like ffmpeg / pyloudnorm / `voice_build.py`); music is judged by `lufs_play`
(mono duplicated to both speakers, +3.01 LU) because the asset slimming turned some stereo masters into mono (stings, `motif_rin`, `motif_nova`)
without changing what is heard. Both numbers are in the CSV. mp3 is measured as ffmpeg decodes it. True peak is a 4x windowed-sinc
oversampling (checked against an 8x FFT reconstruction within 0.1 dB).

## QA tool-belt (`tools/qa/`)

`python tools/qa/run_qa_tools.py` (suite `qa_tools` in `tw_test.py`) = palette_audit + skin_lint + schema/ramps sync + fuzz, see `tools/qa/README.md` and `design/specs/UNIFIED_QA_PLAN.md`. Suite `skin_soak` (`game/tests/skin_swap_soak`) swaps 60+ synthetic skin manifests through `TWSkin`/`TWBus` (marker `TWSKINSOAK_SELFTEST`).
