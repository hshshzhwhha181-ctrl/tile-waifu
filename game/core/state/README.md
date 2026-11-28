# core/state + core/clock — the save record (P12 / WP4)

New code next to the old: `G` (game/scripts/g.gd) still owns the live save; P15 rewires it onto these classes. Nothing here reads `G`,
the scene tree or the real save, so the tests run on a scratch directory and a fake clock.

| class | file | job |
| --- | --- | --- |
| `TWClock` | `core/clock/tw_clock.gd` | injectable time: `now / safe_now / clock_ok / tick / day_key / mono_msec`; `TWClock.fake()` for tests. Same state keys and day rules as `V10Meta` (`S.v10_meta`): the day starts at 04:00 phone time and never goes below `last_key`; `safe_now()` and `day_key()` never go back when the phone clock is turned back; `mono_msec()` (debounce) ignores the wall clock entirely. |
| `TWSave` | `core/state/tw_save.gd` | one save slot at an injected path. Atomic write: `.tmp.json` written, flushed and read back byte for byte, then the live file becomes `.bak.json` (only if it is a valid save; a damaged live file goes to `.corrupt.json` instead, so a good `.bak` is never overwritten) and tmp is renamed over it. `load_best(validate)` tries main -> tmp -> bak and never throws on empty / binary / huge / non-dict files. A file from a newer game wins over any older readable copy (`future`). |
| `TWMigrate` | `core/state/tw_migrate.gd` | `check(d)` (is it a save this game may apply: future version, bad `ver`, wrong critical types) and `apply(d, ctx)`: merge over defaults, repair the kind of every known key (top level, nested defaults, and what the modules' `ensure` builds), clean `stars`, run ver<4 .. ver<8 and the 48 -> 1000 Path step (moved out of g.gd; `G.migrate_48_to_1000` delegates here), module keys ensured. Pure functions over a Dictionary; what g.gd read from itself arrives through `ctx`. |
| `TWState` | `core/state/tw_state.gd` | the one RefCounted record: `data` (the future `G.S`), dirty flag, debounced flush on the injected clock, status of the last load (`fresh / loaded / recovered / future / damaged`) with a Russian `message()`, `apply_state()` that refuses a future version exactly like load, `state_hash()`, per-module versions (`data.mod_ver`). |

## Flush rules (the risky part)

* any money operation -> `mark_dirty(true)`: written within **100 ms** (`MONEY_FLUSH_MS`);
* anything else -> `mark_dirty()`: written within **1 s** of the FIRST unsaved change (`DEBOUNCE_MS`; later changes do not extend the window, so a busy player cannot starve the save; a money op pulls a pending 1 s deadline forward, an ordinary change never pushes a money deadline back);
* `on_pause()` / `on_exit()`: flush at once if dirty. The shell must call `poll()` every frame (or every 100 ms) and the two lifecycle hooks on `NOTIFICATION_APPLICATION_PAUSED / FOCUS_OUT / WM_CLOSE_REQUEST` (P15 wires it; until then G keeps writing directly);
* a failed write keeps the state dirty and retries after `RETRY_MS` (2 s); a `future` state is locked and never writes.

Killing the process loses at most the unsaved debounce window of ordinary changes and at most 100 ms of money changes. `TWSave.kill_at` simulates a kill at five points of `write()`; the selftest proves a valid save loads after each.

## Golden saves

`game/tests/fixtures/saves/v4.json .. v8.json` are old saves (v8 is the real output of the legacy path), `golden.json` holds, per fixture, the
sha256 of the canonical migrated state (sorted keys, int/float-normalised, clock frozen at `TWStateSelftest.GOLD_NOW`) and the headline numbers.
The selftest migrates every fixture with `TWMigrate`, compares the hash, migrates the result again (must be unchanged) and compares the whole state with the
legacy `G.apply_state` (the oracle the runner passes in), except the keys listed in `TWStateSelftest.PARITY_SKIP`.
A change of the save format that moves a hash is a deliberate act: regenerate with
`godot --headless --path game res://scripts/v10/state/state_selftest.tscn -- --hashes_only=1` (fixtures stay) or `-- --gen_golden=1` (fixtures + hashes) and review the diff.

## Known gaps handed to P15 (found while writing this)

* Module `ensure` functions of `v10_challenge`, `v10_duel`, `v10_journey` and `v10_pagoda` ignore the dictionary they are given and work on `G.S`. Migrating a
  stand-alone dictionary therefore does not create those keys; they appear when `TWState.data` IS `G.S`. The parity check skips them.
* `petals` / `tickets` are wallet mirrors rewritten by `V10Money.attach`: the gacha migrator's `ex -> petals` and `free10 -> 10 tickets` (ver<8) are overwritten
  by the mirror at the next attach in the legacy path (visible in the parity run: new path keeps 2 / 10, legacy path ends with 0 / 0). Not changed here.
* A few module `ensure` functions (e.g. adventure `normalize_squad`, tutorial) throw a script error when an array / string field they own holds hostile
  content of the right kind; the fuzz therefore damages known keys with wrong KINDS and unknown keys with arbitrary content.
* `S.econ` is not sealed by `TWMigrate` (sealing is `V10Money`'s job): TWState has a `before_save` hook for it.
