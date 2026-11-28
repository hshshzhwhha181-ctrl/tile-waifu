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
