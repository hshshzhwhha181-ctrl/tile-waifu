# core/rules (P16 / WP5): one solitaire rules engine

New pure core, `tray_board.gd` is NOT touched yet (P17 turns it into a thin view adapter and proves parity).

| file | class | job |
|---|---|---|
| `tw_rng.gd` | `TWRng` | SplitMix64 in integer maths: same seed, same stream on every platform/Godot version (golden values pinned). `fork`, `shuffle`, `chance`, `mix`, `fnv`. Methods are `rand_f/rand_i31/rand_range` on purpose: a method named `randf` would NOT shadow the unseeded global inside the class. |
| `tw_free.gd` | `TWFree` | geometry and the ONE "free tile" rule: `gen_layout` (engine RNG on purpose: levels_bake certificates), `positions`, `topology`, `is_free`, `free_by_counts`, `world`. |
| `tw_events_board.gd` | `TWBoardEvents` | event types (plain Dictionaries with `t`): MATCH, TO_TRAY, TRAY_WARN, TRAY_FULL, CLEARED, DENY, BLOCKED, ICE_CRACK, REVEAL, JOKER, UNLOCK, UNCHAIN, UNSTICK, GIFT, BLAST, UNDO, RETURN, SHUFFLE, VANISH, MOONLIGHT. |
| `tw_board.gd` | `TWBoard` | the engine: integer tile ids, seeded deal (`from_cfg`) or payload (`from_level`), `tap(id) -> [Event]`, `undo`, `return_tray`, `shuffle`, `hint/best_move/solver_move`, `vanish_pairs/hack_deepest/moonlight/open_tile`, `state_hash`, `certificate/verify_certificate`, `snapshot/restore/fork_fresh`, `export_replay/play_replay`. Injected clock (`clock` Callable or `time`), no Node/Tween/await/G. |
| `tw_board_selftest.gd` | `TWBoardSelftest` | `TWBOARD_SELFTEST n/n`; runner `scripts/v10/rules/tw_board_selftest.tscn` (`-- --levels_n=200 --seeds_n=1000 --fuzz_n=48`). |

Rules merged from TrayBoard (tap, tray, pair, combo window, ice, secret/reveal, gold, shard, undo, return_tray, hint, shuffle,
ults), V6SpecialBoard (key/lock/chain/joker/bomb/gift/unstick) and V10LevelSim (representation, certificate replay).

Deliberate differences from the legacy board (all in `shuffle`/events, none in tap legality):
* a tap on a free lock/chain tile gives BLOCKED (not DENY); a covered tile gives DENY.
* `TRAY_FULL` is returned by the tap itself (legacy waited 0.45 s in a coroutine); a match is instant (legacy 0.24 s).
* `shuffle` pairs gold tiles with each other first (legacy `gs.pop_back() or gs.pop_back()` dropped one element when the first was gold).
* the bomb blast removes the same nearby pairs but is ordered with an id tie-break (legacy sort was unstable).

Parity facts proven by the selftest: layouts equal `V10LevelGen.positions` (TrayBoard.gen_layout path) for 200 levels, topology equals
`V10LevelSim`, lockstep random play equals `V10LevelSim` (moves, results, tray, pairs, unstuck) on 200 levels (also run: 1000/1000),
generator certificates replay on TWBoard, the solver bot clears the levels with bombs blasting.
