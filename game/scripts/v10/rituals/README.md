# v10 rituals — Серия чая, утренний поднос, «Она ждала», дни рождения, письмо недели

Lane **rituals** of 0.10 (docs/0.10-spec.md M3: Р3, Р4, Р5, Р6, Р7, Р10). Everything lives in
`game/scripts/v10/rituals/` and `game/assets/v10/rituals/`; no hot file was edited. The integrator wires it with the
one-liners below.

## Files

| File | Class | What |
|---|---|---|
| `rit_clock.gd` | `V10RitClock` | Day key from 04:00 phone time, weeks (Mon), clock guard. Forwards to `V10Meta` when that class exists |
| `rit_bridge.gd` | `V10RitBridge` | The only place that touches other modules: `V10Lint`, `V10Bond`, `V10ProfileCos`, rewards (`grant`, sink), heroine names (incl. genitive) |
| `rit_save.gd` | `V10RitSave` | Save keys + defaults (`v10_streak`, `v10_comeback`, `v10_bday`, `v10_tray`, `v10_tele`); `bind()` for tests |
| `rit_lines.gd` | `V10RitLines` | All heroine lines (5 founders × forgiven/cooled/warmed/milestone/comeback/bday/ask/week voices), 24 weekly facts, Russian plurals `{p:…}` |
| `streak.gd` | `V10Streak` | Р3 tea streak with leaves and repair |
| `tray.gd` | `V10Tray` | Р4 morning tray registry (`register(id, provider, prio)`) |
| `comeback.gd` | `V10Comeback` | Р5 tiers, Отдых ×2, 7/3-day ladder, notification plan, «while away» letters |
| `bday_data.gd`, `bday.gd` | `V10BdayData`, `V10Bday` | Р6 dates (20 heroines), window ±3, visual tile swap, 24-pair goal, yearly frame |
| `player_bday.gd` | `V10PlayerBday` | Р7 152-ФЗ: day+month only, consent, once-a-year change, gift |
| `tele.gd`, `week_letter.gd` | `V10Tele`, `V10WeekLetter` | Р10 week counters (memory → flush at game end), white-list letter |
| `rituals.gd` | `V10Rituals` | **Facade for the integrator** |
| `rituals_selftest.gd` | `V10RitualsSelftest` | All selftests |
| `rituals_runner.gd/.tscn` | — | Standalone runner (selftest / screenshots / demo) |
| `ui/rit_ui.gd` | `V10RitUI` | Kit: «Тишина и лак» tokens, 3 voices of type (Caveat when `v10-fonts` is merged, else Playfair Italic), button classes with `V9Feel`, hanko seal, pentatonic reward cascade, steam/petal particles, sounds |
| `ui/streak_chip.gd` | `V10StreakChip` | The bowl by the partner: steam, number roll, leaves on the rim; `play_win/play_forgiven/play_cool/play_warmed` |
| `ui/streak_sheet.gd` | `V10StreakSheet` | Calendar bottom sheet: 5 weeks, milestones with hanko, repair plate, leaf rule |
| `ui/tray_view.gd` | `V10TrayView` | Lacquer tray overlay, «Забрать всё» → hanko on each card → cascade into counters → slides away |
| `ui/comeback_scene.gd` | `V10ComebackScene` | 4 s / 8 s / 12 s scenes, tap skips from the first second, no prices |
| `ui/ladder_screen.gd` | `V10LadderScreen` | Ladder of return, «Шансы» next to the 10 tickets |
| `ui/rested_bar.gd` | `V10RestedBar` | Turquoise «×2» strip for the play HUD |
| `ui/bday_cake.gd` | `V10BdayCake` | Lobby birthday: lantern garland, cake with live candles, blow-out, petals |
| `ui/bday_goal_chip.gd` | `V10BdayGoalChip` | «Праздник Рин: 12/24 пары её фишкой» with a progress ring |
| `ui/bday_sig_decor.gd` | `V10BdaySigDecor` | Draws the signature emblem over a tile face (visual only) |
| `ui/player_bday_screen.gd` | `V10PlayerBdayScreen` | Ask letter (two equal buttons) → consent + month/day drums → her answer |
| `ui/player_bday_scene.gd` | `V10PlayerBdayScene` | The player's birthday: partner centre, others peek from edges, gift cascade |
| `ui/week_letter_view.gd` + `rit_ink.gdshader`, `rit_paper.gdshader` | `V10WeekLetterView` | Washi paper, ink appears line by line, signature, tap = finish |
| `ui/rit_gallery.gd` | — | Runner gallery: every component in its states |

Assets (`game/assets/v10/rituals/`, Higgsfield, job ids in `jobs.tsv`): `bowl`, `bowl_master` (100-day badge), `leaf`,
`tray`, `cake_tier`, `cake_matcha`, `sig_mc/rin/hana/yue/nova` (signature emblems: сакура, маття, подсолнух, луна,
бриллиант), `envelope`; SFX `sfx/tea_pour, leaf_land, bell, blow, pen_scratch, paper_fan, hanko, steam` (.ogg, −4 dBFS peak).

## Rules implemented (checked by the selftest)

- **Streak.** Day from 04:00. Leaves +1 every Monday, max 2, 1 gift; never sold. Leaves are spent only when they
  cover ALL missed days; 1 uncovered day → bowl cools, «Серию можно согреть: 2 победы до чт 04:00» (2 wins above the
  daily win within 48 h; the warmed day joins the run); 2+ uncovered or the window passed → reset, leaves and best
  kept, milestones never taken back. Milestones 3/7/14/30/60/100/365 (+30 → 50 кр after 30) once per lifetime,
  +10 симпатии партнёру (hard source «рубеж серии»). Clock moved back → wins wait in `pending`.
- **Tray.** Providers by priority; «Забрать всё» calls each `claim` exactly once; no tray when nothing waits or
  after claiming today.
- **Comeback.** 3–6 / 7–29 / 30+ days; Отдых = min(600, (gap−2)×60), mastery only, ×1 in ranked, 1 per pair; ladder
  7 days (≥14) or 3 days (7–13), at most once per 60 days, a skipped day never burns; notifications (category off by
  default) on days 3, 7, 11…27 at 18:30, none after 30 days; ≤7 «while away» letters.
- **Heroine birthdays.** No blocked dates, ≥10 days apart; window −3…+3; overlay never changes the deal (hash test),
  never in ranked; frame «Праздник Ханы · 2027» once a year, 100 кр, +30, 1 leaf; only heroines in `G.HEROES`.
  UX_RULES override the spec's «конфетти»: petals of her colour.
- **Player birthday.** No consent → nothing stored; year never stored; set < 30 days before → «в следующем году»;
  gift once a year; change once per 365 days (survives delete); delete clears; 29.02 → 28.02; grep: no script
  outside `v10/rituals` reads `v10_bday`.
- **Weekly letter.** 24 fact kinds, 3 voices per founder, 3 facts of different kinds; black list (losses, night
  play, spending, absence, comparison) never reaches the text; 0 wins → no letter; once a week.
- **Lint.** Every line passes `V10Lint` (or its copy) and avoids gendered past tense about the player.

## Run

```
# selftests (headless). Spec flags map to --rit_only=<streak|tray|comeback|bday|player_bday|week_letter|lint>
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/rituals/rituals_runner.tscn -- \
  --rit=selftest --save=user://rit_runner.json --save_wipe=1
# screenshots of every component (xvfb, not headless)
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/rituals/rituals_runner.tscn -- --rit=shots --shots=<dir> \
  --save=user://rit_runner.json --save_wipe=1 [--rit_only=<scene>]
# interactive gallery
… -- --rit=demo [--rit_only=<scene>]
```

## Hooks for the integrator (hot files: one line each)

| # | Where | Line |
|---|---|---|
| H1 | `v10/core/registry_list.gd` | `V10Rituals.install()` (registers save defaults with `V10Save`, tray providers, `V10Hooks.game_ended`/`app_resumed`) and selftest `--v10_selftest`: `V10RitualsSelftest.run()` |
| H2 | entry queue (before home is built) | `var d = V10Rituals.day_start()`; if `d.scene` → `V10ComebackScene.play(main, d.scene.tier, {letters: d.comeback.letters, heroes: owned, news: …})`, then `V10LadderScreen.open` when `d.comeback.ladder != ""`; elif `d.player_bday` → `V10PlayerBdayScene.play(main, {name_voc, rows: V10PlayerBday.claim_gift()})`. One full-screen scene per launch (`V10Rituals.entries()` gives priorities 100/90/50) |
| H3 | home build (`home_built`) | `V10StreakChip` next to the partner plate / inside the «Серия» lantern; `chip.tapped → V10StreakSheet.open(main)`; `chip.setup(V10Streak.view())`; play `V10Streak.take_events()` (forgiven → `play_forgiven(leaves)` + `V10RitUI.voice(V10RitLines.pick("forgiven", partner))`; cooled → `play_cool()`; warmed → `play_warmed(n)`). Then `V10TrayView.open(main, [], {default: counter_pos, gems: gems_node, tickets: tickets_node})` when `V10Tray.should_show()`. Partner birthday: `V10BdayCake.open(home_scene_layer, partner)` when `V10Bday.today_hero() == partner` (it replaces the lobby scene; max 1 rig on screen, the cake view uses the still portrait) |
| H4 | win stack (`win_screen`) | `var r = V10Rituals.on_game_ended(result)` already ran from `game_ended`; show the tick «Серия · N» and, if `r.streak.new_day`, `chip.play_win(n-1, n)`; milestones → `V10RitUI.cascade`; `r.ask_bday` → queue the ask letter (H5) |
| H5 | `V9Letters` (letters.gd) | add events `bday`, `week`, `ask_bday`, `while_away` and `backfill(n)`; content from `V10Rituals.day_start().letters` (dicts `{h, ev, subj, body}`) and `V10WeekLetterView` for `ev == "week"`; `ask_bday` letter's action buttons open `V10PlayerBdayScreen.open(main, "ask")`. Priority `V10Bday.LETTER_PRIORITY` (bday before comeback). `V9Letters.check_comeback()` → `V10Comeback.tier` |
| H6 | board (`game_started` / `pair_taken`) | `var ov = V10Rituals.deal_overlay({ranked, faces, seed})`; for each tile whose `face in ov.faces`: `V10BdaySigDecor.apply(tile, ov.icon, face_rect)` and hide the face art; on a pair: `V10Rituals.on_pair(face, ov)` → `V10BdayGoalChip.bump(n)` |
| H7 | economy | `V10RitBridge.set_sink(func(rewards, src): V10Wallet.grant(rewards, src))` once the wallet is in (fallback writes `G.S.gems/coins/tickets/petals`; items to `G.S.v10_items`) |
| H8 | play HUD | `V10RestedBar` under the ult ring while `V10Comeback.rested() > 0`; mastery: `pairs_doubled = V10Rituals.mastery_pairs(pairs, ranked)` at the end of the game |
| H9 | odds | `V10LadderScreen.odds_requested` → `V10Odds.open("tickets")` |
| H10 | settings | row `V10PlayerBday.settings_text()`; «Удалить» → `V10PlayerBday.delete()`; notifications: `V10Comeback.notify_plan(last_unix, cats.comeback)`, `V10Bday.notify_at(key)` via `V10Notify` |
| H11 | profile | frames `tea_master_1/2`, `bday_<h>_<year>`, `my_bday_<year>`, `back_at_table` are registered in `V10ProfileCos` by `V10RitBridge.register_frame`; badge `tea_bowl_master` uses `assets/v10/rituals/bowl_master.webp`; title `year_at_table` |
| H12 | old `S.streak` | set to 0 in the SAVE_VER 8 migration (spec Р3); `V10Tele.add("touches"/"gifts"/"replies"/"floors"/"outfits"/"daily"/"tasks")` from those modules |

## Open points
- Caveat (heroine voice) comes with `v10-fonts`; until merged the kit falls back to Playfair Italic.
- Per-heroine birthday cake loop (spec: video 12 кр/heroine) replaced by the code-animated candles + still portrait
  (max 1 rig rule); when the rig of the partner exists, put the rig instead of the portrait in `V10BdayCake`.
- V9Letters event kinds are added by the integrator (letters.gd is a hot file).
