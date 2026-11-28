# tools/ — QA runner (`tw_test.py`), baseline, CI

`tools/tw_test.py` is the one cross-platform entry point for every automated gate in the repo. It replaces
`.agents/skills/tw-godot-qa/scripts/godot_qa.ps1` (now a 20-line shim that forwards here).

| gate | suites | how it is judged |
| --- | --- | --- |
| Godot selftests | 54 (8 core flags, 43 v10 registry modules, `spec`, `summon`, `ult_rin`) | marker line of each suite (`ECON_SELFTEST 384/384`, `V10VOICE OK`, ...) |
| `server/e2e_test.mjs` | `server_e2e` | `E2E_OK`, `N passed, 0 failed` (skipped with a reason if node or `node:sqlite` is missing) |
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
python tools/tw_test.py --check-drift          # every V10RegistryList selftest module is in the catalog?
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
| `summon` | 45/56 | `V9Summon` pity/guarantee replay differs from `G.pull` (11 checks) |
| `challenge` | 285/291 | 6 `ui:` checks "<= 4 type sizes" (typography budget) |
| `tower` | 6842/6880 (full only; `fast` is green 198/198) | 38 x "<= 4 type sizes + overline" at 720x1280 in the full UI matrix |

`challenge`/`tower` are typography checks that I did not verify on a Windows/GPU box; they may be platform dependent (fonts) — check there before "fixing".
The other 48 Godot suites + `server_e2e` + `ux_lint` are green: 50/56 full, 43/47 `--fast` (the 4 known reds in `--fast` are `ults`, `letters`, `profile2`, `summon`).

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
  by something `G._ready` registers. Bisecting `G._ready`: the abort needs `V10Registry.load_all()` (-> `V10RegistryList.register_all()`)
  and is layout dependent — cutting `register_all()` before `V10AdventureReg.register()` removes it, but even a bare
  `V10Registry.module("adventure", {"step": 4})` brings it back, so the trigger is the amount/shape of registered data
  (many `Callable` lambdas stored in static dictionaries), not a specific module.
* Not a test failure source, so the runner simply ignores the abort when the marker is green.
* Ideas not tried (need a symbolised engine): build Godot 4.5.1 with `debug_symbols=yes` and rerun valgrind; try 4.5.2/4.6; stop keeping
  lambdas/Callables in `static var` dictionaries of `V10Registry` (clear `_mods` on `NOTIFICATION_PREDELETE`/before `quit()`).

## CI

`.github/workflows/qa.yml` (ubuntu-24.04, Godot 4.5.1 downloaded from the official release, node 24, python 3.12, xvfb + GL libs, cached `game/.godot`):
PRs run `--fast`, pushes to `v10-integration`/`main` run the full set, `workflow_dispatch` lets you choose. Logs/JSON are uploaded as an artifact.
The workflow has not run on GitHub yet (only locally validated: same command, same Godot, same xvfb).

## Adding a suite

Add one `S(...)` line to `CATALOG` in `tw_test.py` (id, marker, scene/script, args, optional `fast_args`, `render`, `timeout`, `soft`), then
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
