# Rig data contract — `gestures.json` (every heroine rig)

Shared by all rig lanes (Рин/Хана, Юэ/Нова, МТ). Spec 0.10 D4 (`V10RigStage`, `reactions.gd`, `--rig_selftest`) and
LEGWEAR §4–5 read **only this file** and `rig_def.json`; they never parse a heroine's GDScript. One file per rig folder:
`game/assets/v10/rig/<rig>/gestures.json`, next to `rig_def.json` and `rig.tscn`.

Rules for the shared code in `scripts/v10/rig/`:
* `live_rig.gd` (V10LiveRig) is the common engine. Heroine behaviour goes into her own subclass (`<rig>/<name>_rig.gd`,
  `extends V10LiveRig`), not into the engine, so the rig lanes never edit the same file. A real engine bug: fix it in a
  separate small commit and tell the other rig lanes.
* New shared helpers get their own files (`rig_sheen.gd`, `rig_data_selftest.gd`, …).

## File

```json
{
  "rig": "hana_base",
  "hero": "hana",
  "outfits": ["h_base"],
  "scene": "res://assets/v10/rig/hana_base/rig.tscn",
  "fit": {"center_x": 715, "height": 0.705, "bottom": 12},
  "motion": {"default": 1.0, "fx_min": 0.5, "profile": 0.7},
  "framing": "thigh",
  "up_amp": 0.6,
  "gestures": [
    {"id": "ha.bounce_toes", "name": "bounce_toes", "use": "auto", "tier": "base", "rig": "R", "legs": true,
     "framing": "knee", "outfits_allow": [], "outfits_deny": [], "aff_min": 0, "dur": 1.6, "sfx": "sneaker_squeak"}
  ],
  "reactions": {
    "zones": {"head": "hair_shake", "armL": "high_five", "armR": "hip_check", "hair": "hair_shake",
              "outfit": "jacket_tug", "bg": "look"},
    "dead_zones": ["bust", "hips"],
    "neutral": "look_neutral",
    "pout": "pout",
    "by_aff": {"0": ["smile", "look", "wave"], "3": ["wink"], "6": ["lean_in"], "9": ["air_kiss"]},
    "idle_20s": ["stopwatch_glance"],
    "greet": "wink_grin"
  },
  "shaders": {}
}
```

| Field | Meaning |
|---|---|
| `rig` | folder name |
| `hero` | heroine id (`mc`, `rin`, `hana`, `yue`, `nova`, …) |
| `outfits` | wardrobe outfit ids this rig shows (`V10RigStage.make(parent, hero, outfit, …)` picks the rig whose list has the outfit). Never empty |
| `scene` | the rig scene (`rig.tscn`; `.scn` once saved binary) |
| `fit` | portrait placement: art x at the screen centre, figure height as a fraction of the screen height, bottom overhang in screen px |
| `motion` | `rig.motion` for normal FX, FX «Минимум», the profile showcase (D4 §7) |
| `framing` | what the key art shows: `knee` (from the knees up), `thigh`, `waist` (LEGWEAR §2) |
| `up_amp` | amplitude of `tier: up` gestures in base builds (LEGWEAR §4.1: ×0.6). The rig script exposes `var up_amp: = 1.0` and scales its `up` gestures by it; the stage sets it |
| `gestures[]` | everything the rig can play (below) |
| `reactions` | what a tap or an affinity level plays (below) |
| `shaders` | optional live elements (LEGWEAR §5.1): `{"sheen": {"layer": "body", "mask": "sheen_mask.png", "knee_y": 1290, …}}` |

### `gestures[]`

| Field | Values | Meaning |
|---|---|---|
| `id` | `ha.bounce_toes`, `rin.over_glasses`, `leg_idle`, … | LEGWEAR / POSES id (heroine prefix for her own, bare for the shared ones) |
| `name` | `bounce_toes` | what `rig.gesture(name)` / `rig._build(name, s, p)` accepts |
| `use` | `auto` · `react` · `both` · `talk` · `layer` · `fx` | `auto` = in the autonomous pool; `react` = only as a reaction; `layer` = continuous (`leg_idle`); `fx` = shader (`sheen_sweep`) |
| `tier` | `base` · `up` · `bold` | LEGWEAR §4.1 / spec D4: `base` everywhere; `up` = ×`up_amp` in base builds, full in 18+; `bold` = 18+ only (`V10Age.bold_ok()`), **never a tap reaction**, only idle at affinity ≥ 6 |
| `rig` | `R` · `R+P` · `R+L` · `S` · `B` · `V` | LEGWEAR §4.1 (`V` = video clip, not in the rig) |
| `legs` | bool | moves the legs or legwear; not played in the `alt_rect` (Yandex) framing |
| `framing` | `knee` · `thigh` · `full` · `any` | smallest framing in which it reads (LEGWEAR §2 p.4) |
| `outfits_allow` / `outfits_deny` | outfit ids | LEGWEAR §4.3 |
| `aff_min` | 0–10 | lowest affinity for the autonomous pool |
| `dur` | seconds | |
| `sfx` | id or `null` | LEGWEAR: a legwear/ornament sound on every leg gesture |
| `status` | optional: `"n/a: <why>"` | a LEGWEAR gesture that this key art cannot show (e.g. no knee in the frame). Kept in the file so the audit sees it was considered; the stage never plays it |

### `reactions`

* `zones` — tap zone (`head`, `armL`, `armR`, `hair`, `outfit`, `bg`; the zone polygons are `rig_def.json → zones`) →
  gesture name. D4 §2.
* `dead_zones` — `rig_def.json → dead_zones` keys (bust, hips/skirt/legs…). A tap there plays only `neutral`, gives no
  line and no affinity, and never counts towards `pout` (D4 §4, LEGWEAR §1.1, UX §8.2).
* `neutral` — a plain look at the player: no wink, no blush, no smile change, no body move below the chest.
* `pout` — third tap within 2 s (D4 §4, «Ну хватит~»).
* `by_aff` — D4 §3: levels `0` (0–2), `3` (3–5), `6` (6–8), `9` (9–10) → gesture names unlocked at that level.
  `reactions.gd` keeps a 60 s cooldown per name and spaces the high levels.
* `idle_20s` — D4 §5: after 20 s without input (≤ 2 per visit).
* `greet` — D4 §1: after `appear()`.

Every name used in `reactions` must exist in `gestures[]` with `tier` `base` or `up` (never `bold`) and `use` ≠ `fx`/`layer`.

## Shared helpers

* `rig_sheen.gd` (`V10RigSheen`) + `v10_sheen.gdshader` — LEGWEAR `sheen_sweep`: a specular band over a mask painted
  in a layer's texture space (`tools/sheen_mask.py`), drawn by a copy of that skinned layer, so it follows the bones.
  The mask never goes above the knee (`knee_y`).
* `rig_data_selftest.gd` / `.tscn` — validates every `game/assets/v10/rig/*/gestures.json` against this contract
  and against the rig itself (names implemented, zones vs dead zones, bold never reachable from a tap, LEGWEAR masks
  and ornament bones below the knee). Godot: `--path game res://scripts/v10/rig/rig_data_selftest.tscn` →
  `RIG_DATA_SELFTEST PASS|FAIL n/m`. Part of `--rig_selftest` once the integrator wires D4.
