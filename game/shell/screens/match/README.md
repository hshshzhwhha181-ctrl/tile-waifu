# shell/screens/match - TWBoardView + TWMatchScreen (P31 / WP10a)

`board_view.gd` (`TWBoardView`, a Control that draws itself, no child nodes): the match view. It reads the events `TWBoard` returns
(`TWBoardEvents`) and plays a timeline; it holds **no rule**. `match_screen.gd` (`TWMatchScreen`, a `TWScreen`, id `match`) owns a
`TWBoard` and a view: tap -> `board.tap(id)` -> `view.play(events)` + `ctx.bus.publish_all(events)`.

Reachable only in the v11 shell: `godot --path game -- --shell=v11 --v11_match=1` (LegacyHost scans `shell/screens/*/spec.tres`;
`TWScreens.go("match", {cfg | level | board, tile_size})`). The default launch is untouched.

## Timeline (GDD 9.7)

| what | time |
|---|---|
| press lift | 6 px, same frame |
| tapped tile lifts, then the pair flies together (EXPO OUT), sparks 6 / 12 / 18 by combo | 90 ms + 180 ms |
| tile -> tray slot on an arc | 160 ms |
| neighbours that lost their cover settle 2 px (and light up) | 40 ms |
| tap on a covered tile: shake, no red | 120 ms |

All 20 core events have a picture (`TWBoardView.EVENT_ANIM`; the selftest checks 20/20 and that every event met in 100 real games
scheduled clips). The six acceptance events: MATCH, DENY, ICE_CRACK, TRAY_WARN (last free slot pulses = the silent stand-in of the
heartbeat), TRAY_FULL (tray shake + ember tint + field dim), CLEARED (gold sweep + sparks).

The LOGICAL mirror (`m_where`, `m_tray`) changes at once in `play()`; only the pictures lag. Call `play()` right after the board
operation that produced the events. The view never calls a board operation that changes the board (lint in the selftest).

## Layout and tile size

`TWBoardView.compute(vs, insets, positions, slots, size_key, top_reserved)` is pure: field = 94% x 62% of the screen (GDD >= 92% x
>= 60%), tray row under it (`TWTokens.TRAY_H`), tile 56 / 64 / 72 / 80 px at base 720 for S / M / L / XL (scaled by width / 720).
A board wider than the field at the chosen size shrinks to fit (`fits == false`); panning for big Classic layouts is a later package.
The HUD (P32) passes `top_reserved`; the hero strip (P34) goes under the tray.

## Free / blocked contrast (GDD 7.2) - measured, and one contradiction in the spec

A free tile is the plain face art; a blocked (covered / locked) tile is multiplied by `lerp(PAPER_300, PAPER_500, 0.5)`
(~0.72 of the free brightness) and loses its gold rim. The selftest renders 720x1280 and measures from the PIXELS: plate vs table
>= 4.5:1 for both free and blocked, blocked brightness >= 65% of free, and the two told apart.
The literal "free vs blocked >= 4.5:1" cannot hold together with "blocked not darker than 65% of free" (65% brightness is at most
~2.4:1 in WCAG terms), so the 4.5:1 is checked against the table and the free-vs-blocked WCAG ratio is only reported. Owner/GDD
decision needed if the intent was different.

## Selftest

`res://shell/screens/match/board_view_selftest.tscn`, suite `twboardview`, marker `TWBOARDVIEW_SELFTEST ok/total` (needs a display:
tools/tw_test.py runs it under xvfb). Sections: layout, 100 games with/without the view (same events, same state hash, mirror ==
board), events, input, pixel contrast, 60-tile frame p95, screen API through TWScreens, lint.

## Victory screen (P33 / WP10c)

`result_chain.gd` (`TWResultChain`, pure) + `result_modal.gd` (`TWResultModal`, a `TWModal` on the `ModalStack`) + the hook in `match_screen.gd`.
Suite `twresult`, marker `TWRESULT_SELFTEST ok/total` (renders: xvfb), files `match_selftest.gd/.tscn/_runner.gd`.

| | fast path (an ordinary win) | chain (a milestone) |
|---|---|---|
| when | every win that is not a milestone, and the first win on FTUE levels (L1-L3: the truncated chain) | first win of a life, chapter boss, first 3-star of a chapter, every 10th win (`facts`: `wins_before`, `is_boss`, `chapter_has_3star`, `ftue`) |
| panels | 1: «Поле чисто», stars, reward icons fly, Bond `+N`, Season XP ring, the primary button | 3: stars + «Поле чисто» + milestone line / rewards (counters roll) / heroine art + Bond + Season XP |
| time to the button | **1.40 s** (limit 3.0): 120 ms silence, a star every 120 ms, icons fly 0.66 s, bars fill 0.70-1.30 s | **15.0 s** (limit 20), nominal end 18.0 s: 400 ms silence, panels of 6 s |
| sting | `sting_victory_short` (~1.2 s) | `sting_victory` (9.3 s) from 0.4 s as a bed; the first tap cuts it (`stop_cue`) |
| tap on the stage | settles the animation at once; the button is the way on (a stray tap never throws a result away) | tap 1 settles the current panel, tap 2 goes to the next; Skip (always visible) jumps to the Confirm |
| buttons | «Ещё уровень» (primary), «На карту», «Поделиться» | the same three, shown on the last panel; one primary only |

The button rects (`TWResultModal.layout`) are one table per screen size, identical for both shapes and every frame (tested per frame). Android back:
first press = Skip, once the button is ready = «На карту». Scrim tap and a stray back never discard the screen. `on_close(result, reason)` runs once
with `{"action": "next" | "map", "kind", "milestones", "stars", "t"}`; a screen change (`clear_all`) gives a null result.

No text shows what is left today, no sale, no interstitial: `TWResultChain.TEXT` is the only copy, `TWRoundResult` has no such field, and the selftest greps
the two source files (string literals and identifiers) and every string a Label of the modal ever showed (0 hits of `остал`, `сегодня`, `лимит`, `купи`, `скидк`,
`магазин`, `рекл`, `₽`, ...).

`TWMatchScreen` opens the modal once when the board is cleared (only with a `ModalStack` in `ctx`; without one nothing changes). Params: `result_facts`,
`round_mode`, `round_cfg`, `round_state`, `boosters_used`, `show_result`. It runs `TWRound.resolve` on the board's stats, pays the grants once through a `wallet`
service when ctx has one, and emits `result_action(action, info)`; with no listener "next" restarts a default board (dev flow of `--shell=v11 --v11_match=1`).

Open points: the heroine art is `emotion:<hero>:happy` (a stand-in; the T3 `win` art id is not in the manifest yet; without art an accent plate is drawn); the real Bond / Season XP bar
fractions come from `facts.bond` / `facts.xp` (`{"from", "to"}`), the default only shows the earned step; `sting_victory_short`, `star`, `coin_fly`, `gem_fly` are cue NAMES sent
to an optional `audio` service (`play_cue(name, data)`, `stop_cue(name)`) - the 1.2 s short sting asset does not exist yet; the GDD line «любой тап сразу ведёт дальше» of the fast
path is implemented as "settle at once" (see above), a decision for the owner if he wants the stage tap to leave the screen.
