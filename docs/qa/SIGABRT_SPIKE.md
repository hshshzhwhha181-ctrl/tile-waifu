# SIGABRT (rc 134) at Godot exit - spike P02

Godot 4.5.1-stable official linux x86_64 (stripped), project `game/` at claude/integration 5b8a84e, run headless with `nice -n 19`, one process at a time.
Probe script: a `SceneTree` script whose `_init` prints and calls `quit(0)` (`-s quit.gd`). rc column: `134` = SIGABRT (python `-6`). Each cell is 2-3 repeats; all repeats agreed, so the abort is deterministic.

## Verdict

* It is a real heap corruption (double free / use-after-free in engine teardown, glibc aborts in `free()` / `malloc_consolidate`), not a glibc heuristic and not test noise.
  Messages vary by heap layout: `malloc_consolidate(): invalid chunk size`, `... unaligned fastbin chunk detected`, `corrupted size vs. prev_size in fastbins`, `double free or corruption (!prev)`.
* It reproduces with `G` (`game/scripts/g.gd`) as the ONLY autoload. The trigger inside `G._ready` is `V10Registry.load_all()`; inside that, **keeping the discovered `module.gd` spec Dictionaries (which contain lambdas/Callables) in static storage until engine shutdown**.
  Erasing every Callable-valued key from the registered specs makes rc 0; erasing Dictionaries/Arrays only does not.
* **Not reproduced on an empty Godot 4.5.1 project** (rc 0) and **not reproduced by a synthetic 43-module project with the same pattern** (a static-var Dictionary in a `class_name` script holding 43 specs, each with a lambda and a `Callable(Class, "m")`, loaded via `load()` + `scr.call("spec")` from an autoload): rc 0 x3. So the exact shape/size matters (heap-layout dependent); a minimal engine-only repro was NOT obtained in the time box.
* Classification: **engine-side teardown bug exposed by our code shape** ("engine, not ours" cannot be claimed because it needs our 43-module registry to show up). Player risk: it happens after all output / saves are written, during process exit. On Android (export) a native abort at exit shows as a crash on swipe-away or `get_tree().quit()`; it is not observed to lose data, but it is not proven harmless on device (no device run in this spike). Recommended: ticket below, plus verify on the device build.
* Not fixed in this spike (a fix needs either a symbolised engine or restructuring ~43 manifests; `game/scripts` and `game/core` were out of scope tonight).

## Matrix A - launch variants on the full project (headless, `-s quit.gd` unless noted)

| # | variant | rc (x3) |
|---|---------|---------|
| 1 | `--headless --audio-driver Dummy` | 134 134 134 |
| 2 | `--headless`, no `--audio-driver` | 134 134 134 |
| 3 | `--audio-driver Dummy --rendering-driver vulkan` (flag only; headless) | 134 134 134 |
| 4 | `--text-driver Dummy` | 134 134 134 |
| 5 | main scene, `--quit-after 2` (no `-s`) | 134 134 134 |
| 6 | `--quit-after 1` together with `-s quit.gd` | 134 134 134 |
| 7 | `--single-threaded-scene` | 134 134 134 |
| 8 | `--disable-crash-handler` | 134 134 134 |
| 9 | `MALLOC_CHECK_=3` | 134 134 134 |
| 10 | `MALLOC_ARENA_MAX=1` | 134 134 134 |
| 11 | EMPTY project (no autoloads), `-s quit.gd` | 0 0 0 |
| 12 | EMPTY project, `--quit-after 2` | 1 1 1 (no main scene: not a valid test, not comparable) |

Audio driver, rendering driver, threading, text driver, quit path and malloc env knobs make no difference. (Earlier work in tools/README.md also covered `glibc.malloc.tcache_count=0`, `mxfast=0`, display-driver headless and valgrind: 128 invalid reads/writes, all in the shutdown call chain.)

## Matrix B - one autoload at a time (headless + Dummy audio, `-s quit.gd`, x2)

The project has 11 autoloads: `G Sfx V6Story V6Fx V7Haptics V7DayNight V7Eggs V7Album V7Event V10MetaTicker V10Hooks`.

| removed autoload | rc | | only this autoload | rc |
|---|---|---|---|---|
| G | **0** (but others log script errors without G) | | **G** | **134** |
| Sfx | 134 | | Sfx | 0 |
| V6Story | 134 | | V6Story | 0 |
| V6Fx | 134 | | V6Fx | 0 |
| V7Haptics | 134 | | V7Haptics | 0 |
| V7DayNight | 134 | | V7DayNight | 0 |
| V7Eggs | 134 | | V7Eggs | 0 |
| V7Album | 134 | | V7Album | 0 |
| V7Event | 134 | | V7Event | 0 |
| V10MetaTicker | 134 | | V10MetaTicker | 0 |
| V10Hooks | 134 | | V10Hooks | 0 |
| (none removed = case A1) | 134 | | no autoloads at all | 0 |

Minimal autoload trigger: **`G`** alone (necessary and sufficient).

## Bisect inside `G` (only `G` loaded)

`return` inserted into a scratch copy of `g.gd` `_ready` (scratch copy under the session scratchpad, repo untouched):

| return placed | rc |
|---|---|
| unmodified | 134 |
| top of `_ready` | 0 |
| after `ITEM` loop, `_collect_hidden_items`, `_build_levels` | 0 |
| before `V10Registry.load_all()` | 0 |
| after `V10Registry.load_all()` | 134 |
| after `V10Wave1.apply`, after `load_game()` | 134 |

Then inside `V10Registry` (`game/core/base/registry.gd`) in a scratch copy:

| experiment | rc |
|---|---|
| E1 `_scan` only (find the 43 `module.gd` paths) | 0 |
| E2 `load()` every `module.gd`, no `spec()` call | 0 |
| E3 `spec()` called on all, specs discarded | 0 |
| E6 `spec()` + `sort_custom(lambda)`, return before `module()` | 0 |
| E4 specs registered into static `_mods`, no wire/migrator loops | 134 |
| E7 same without `sort_custom` | 134 |
| E8 as E4 and then `_mods.clear(); _order.clear()` right away | 0 |
| E9 registered, every top-level Callable value erased | 0 |
| E10 registered, every top-level Dictionary value erased | 134 |
| E11 registered, Callables + Dictionaries + Arrays erased | 0 |
| E12 registered, `selftest` key erased | 134 |
| E13 erase only `ensure` / only `wire` / only `migrator` | 134 each |
| E14 erase `wire`+`migrator` (keep `ensure`); E15 erase `ensure`+`migrator` (keep `wire`) | 134 each |

Reading: the abort needs registered specs that still hold lambdas/Callables at shutdown; no single key (`ensure`/`wire`/`migrator`) is the culprit, any of them suffices (so it is the count of retained lambda Callables, i.e. `GDScriptLambdaCallable`s whose script is freed at `ScriptServer` teardown, rather than one spec).

## Workaround attempts that did NOT work (so do not repeat)

* `G._exit_tree()` calling `V10Registry.release()` (clear `_mods`, `_order`): confirmed it runs (`_mods` 43 -> 0), still 134 (with all autoloads and with G only).
* Also clearing `V10Save._migrators` in `_exit_tree`: still 134 x3.
* Clearing `_mods` immediately after the whole `load_all()` (E16): still 134 - because `wire()` / `V10Save.register_migrator` have by then copied lambdas into other statics (`V10Save._migrators`, hook statics such as `more_level.label_of`, `path_map.on_play`, `tower_ui.grant_hook`, ...). 200 `.gd` files declare `static var`, 425 contain `func(` lambdas, so a complete "release before quit" pass is a repo-wide change.

## Ticket (to file)

"Godot 4.5.1: heap corruption at exit when 43 `module.gd` specs with lambda Callables are retained in a static var (autoload G)".
Next steps, in order of cost: (1) run the same probe with Godot 4.5.2 / 4.6 export templates (no rebuild needed if official binaries exist); (2) if still reproducing, replace stored lambdas in `V10Registry` specs with named static methods (`Callable(Class, "m")` - the synthetic project shows no abort with that, but it was not isolated against lambdas separately, so verify) and re-run Matrix B; (3) only then build a `debug_symbols=yes` engine and valgrind it for an upstream issue; (4) device check: export an APK/preset and confirm exit behaviour on Android.

## Runner / CI changes in this package

* `python tools/tw_test.py --no-mask-rc ...`: a suite is red unless rc is 0 or the known teardown abort (134 / -6). SIGSEGV (139 / -11) and Windows `0xC0000005` are no longer swallowed. Default behaviour (without the flag) is unchanged. Verified: rc table via `parse_output` (0/134/-6 pass; 139/-11/1/0xC0000005 fail with the flag) and a real `-s economy --no-mask-rc` run (384/384, exit 0).
* `.github/workflows/qa.yml`: the Tests step now runs with `--no-mask-rc`. The workflow has never run on GitHub (see tools/README.md), so the CI change is unexecuted.
