# core/round — the end of a round (P20 / WP7)

`TWRound.resolve(state, mode, cfg, stats) -> TWRoundResult`: the award / rank / star / unlock / task / hook half of `play.gd`, as one pure function.
Nothing here reads `G`, the scene tree, the wallet or the clock; the shell hands in a read-only snapshot (`state`), the counters of the round
(`stats`) and applies the result (wallet grants through `TWWallet`, bond, tasks, `G.add_rp` / `G.record_game`, the state edits in `result.writes`).

| file | class | job |
| --- | --- | --- |
| `tw_round.gd` | `TWRound` | `resolve` for Path / daily / trial (clear or leave), blitz (end), zen (one board), duel (finish), tower family (pagoda / journey / practice) |
| `tw_round_result.gd` | `TWRoundResult` | stars, reward, `grants` (ordered, `pay(TWWallet)`), rank points and rank-ups, yaku, record, bond, tasks, `writes`, `flags`, `events` (ROUND_ENDED / RANK_UP / TASK_PROGRESS), `hook` (the V10Hooks game_ended payload). **No «осталось сегодня» field.** |
| `tw_rewards.gd` | `TWRewards` | pair gain, sets, yaku, stars, the rank ladder (`rank_of`, `rank_ups`), blitz / zen / duel / tower payouts, `mode_finish_plan` (reward half of `V10Hooks.handle_mode_finished`) |
| `tw_boosters.gd` | `TWBoosters` | hint / undo / shuffle decisions and prices (30 / rescue 60), `commit`, rescue, the overflow policy per mode, `loadout` (partner perk, affection, album sets, fortune, level extras; **the outfit is not an input**) |
| `tw_modecfg.gd` | `TWModeCfg` | the mode table (source, hook name, slots, clock), daily / blitz / zen / trial configs, Path fill-ins, the gold fortune |
| `tw_round_stats.gd` | `TWRoundStats` | the round's counters built from the `TWBoard` event stream (pair gains, fever, sets, combo, denies, fails) |
| `round_selftest.gd` | `TWRoundSelftest` | `ROUND_SELFTEST n/n`, runner `scripts/v10/round/round_selftest.tscn` |

## Tests

* **Table** `game/tests/fixtures/round/table.json` (139 rows, ~14 checks each): path / daily / trial / blitz / zen / duel / pagoda / journey / practice x win / lose / leave /
  rank ladders / riichi / first clear / mode of the day. The expected values come from an independent Python model of the legacy award code
  (`tools/gen_round_table.py`, `--check` verifies the file).
* **Legacy diff**: 300 random rounds (+ 300 random pair sequences, 500 rank additions) against a frozen transcription of the old `play.gd` /
  `duel.gd` / `tower_play.gd` code inside the selftest, 0 differences, incl. the game_ended payload.
* **Bot**: 24 `TWBoard` games played by the solver through `TWRoundStats`; the same seed with 3 different outfits gives an identical `RoundResult`.
* Quirks kept on purpose: a blitz run with no board cleared is recorded as a lost game; a duel draw is not a win; zen never counts a loss; `trial` pays
  nothing and gives no rank points; a kitsune rescue is consumed only on Path / daily.

## Not moved (still in the shell)

Everything with a face: banners, floats, sounds, the result window, the fail window, `V10PathState.on_win` (injected as `state.hooks.path_on_win`),
the league (inside `G.add_rp`), the tower's own `hook_clear` rewards (the tower module decides its crystals; only its rank points / bond come from here),
Climb / Etude / Shift / event / challenge payouts (they already use `V8PlayRules.*_rp`).
