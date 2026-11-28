# shell/stage - TWPresence (P34 / WP10)

`presence.gd` (`TWPresence`): the heroine in a round, over the finished `V10LiveRig` (`live_rig.gd` is untouched).

| mode | what | default for |
| --- | --- | --- |
| `standard` | strip under the tray, height <= 28% of the SCREEN height, waist-up, clipped to its rect | path, daily, free ... |
| `minimum` | 160 px disc medallion (rig head and shoulders, or the portrait stub) | classic, connect, garden |
| `full` | column on the right, board keeps >= 50% of the width (opt-in, DECISIONS 33) | settings only |

* `TWPresence.layout(screen, avoid, mode, insets)` is pure rect maths; `avoid` = field + tray rect, never overlapped (no room -> `hidden`).
* Touches are off: `rig.handle_input = false`, every Control ignores the mouse. The ult is a ring button; publish `{"t": "ULT_CAST"}` on the bus.
* `p.bind(bus)` subscribes to TWBoardEvents MATCH (combo 5 / 10 / 20 -> `combo_t1/t2/t3` by edge), CLEARED -> `clear`, TRAY_FULL -> `fail`,
  TRAY_WARN -> `tray_danger`, ULT_CAST -> `ult_cast`. Reaction -> gesture is data (`TWPresence.CANDIDATES`) resolved against each rig's
  gestures.json (no bold, no legs). The gesture starts synchronously in the event call.
* A heroine without a finished rig (all but mc_gown, rin_officer, hana_base) gets the medallion stub (portrait + pulse).
* `p.measure()` = structure side of the P41 method (draw items upper bound, unique textures, RGBA8 memory).
* Selftest: `res://shell/stage/presence_selftest.tscn` (suite `twpresence`, `TWPRESENCE_SELFTEST ok/total`).
