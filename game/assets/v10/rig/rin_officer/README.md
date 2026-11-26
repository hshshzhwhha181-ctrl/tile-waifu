# Рин (officer coat) on the V10 living-illustration rig

Second heroine on `scripts/v10/rig/live_rig.gd` (V10LiveRig v2, see `scripts/v10/rig/README.md`). The art is
`docs/concepts/v4/dataset_v2b/r4_rin.webp` (job `79823c6d-b09f-4d2b-a8d0-62ff6cc600a5`, `r4_rin` in
`tools/art/jobs.tsv`): Рин in the black-and-gold officer coat with a closed fan, side braid, round gold glasses,
tea library behind. It is in the audited LoRA-v2b dataset (HANDOFF: "одобренный датасет арта, после аудита").
Re-checked here: adult face, 2 arms, 2 gloved hands, 2 legs (knee-up crop), no text, no nudity.

She is NOT a copy of Маджонг-тян's set. `rin_rig.gd` (extends V10LiveRig) gives her her own body language from
`docs/POSES.md` §2: vertical, still and economical, straight parallel legs, she moves about half as fast as the
others (her springs run at ~0.6-0.7 of the default frequencies with more damping, idle periods are ~1.6x longer,
idle amplitude 0.75), blinks half as often, speaks evenly with a small mouth, and talks with the look over her
glasses and her fan hand.

## Run it

```
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
    --resolution 720x1280 res://assets/v10/rig/rin_officer/rin_demo.tscn -- [args]
```
`--selftest=1` plays all 6 gestures and all reactions (head, fan hand, gloved hand, braid, room, coat, 3 quick taps,
talk) with the strain probe on and prints `RIN SELFTEST PASS|FAIL worst=...` (exit code 1 on FAIL, limit 0.2).
`--shots=<dir> --at=1,2.5` saves frames; `--heat=<s>` saves `strain_heat.png`; `--perf=1`; `--script=0` lets you
tap her yourself; `--gesture=<name>` starts the 20 s showcase with that gesture. Movie:
`... rin_demo.tscn --write-movie out.avi --fixed-fps 30 --quit-after 600` (20 s), then ffmpeg to mp4.

The demo fits any portrait screen (`_fit()`): the figure scales with the height, the background always covers
the screen (9:16, 9:20, 9:21 phones and 3:4 tablets were checked).

## Her gestures (autonomous, every 5-9 s, never the same twice in a row)

| Gesture | Dur | What happens | Face |
|---|---|---|---|
| `over_glasses` | 3.6 s | chin dips 4 px, head tilts −2°, slight lean-in (zoom +1.2 %), shoulders rise 1.5 | the glasses slide down her nose and she looks over the rims (painted variant) + teasing smirk, light blush |
| `adjust_glasses` | 3.4 s | a quick glance over the slipped glasses, then the fan hand rises (forearm −11 px, wrist −3°) and the glasses are back up; chin lifts; braid swings | glint sweeps across both lenses (shader over a lens mask), smirk |
| `fan_hide` | 3.4 s | the fan rises over her lips (−12 px, +1.6°), the head leans into it, shoulders shake softly | ^^ eyes and a quiet laugh behind the fan, blush 0.9 |
| `smirk` | 3.2 s | the head turns a touch away (−3°), the eyes stay on you | one-sided smirk, slow wink on the far side |
| `settle` | 3.6 s | posture reset: a slow breath with closed eyes, the shoulders drop, the spine lengthens (hips −3, chin up) | eyes closed 1.1-1.9 s, a soft "o" exhale |
| `ponder` | 3.6 s | the fan taps her chin twice (wrist wag ±1.6°), eyes up and to the side | "hm" (`oh`), then a decided smirk |

"Sips tea" from POSES.md is not in this outfit: in this art she holds a closed fan, no bowl. `fan_hide`/`ponder` take
that slot; a tea-bowl outfit (rin_base / rin_after) would get `sip` (bowl to the lips, the steam curls).

## Reactions (taps; bust and hips/legs are dead zones and never react)

| Tap | Reaction | Notes |
|---|---|---|
| head | `pat` | eyes close into the touch, then ^^, a quiet laugh, she leans 3° into the hand, small bounce, blush 1.0 |
| fan hand (`armL`) | `fan_hide` | as above |
| gloved hand (`armR`) | `adjust_glasses` | as above, with the glint |
| braid (`hair`) | `braid_flick` | small proud head toss, braid impulse −3.5°, eyes closed, sideways smirk |
| coat / room | `look` | her own, smaller than the default: eyes first (±2.6 px), head ±2.4°, wink, smirk |
| 3+ quick taps | `huff` | frown + pout with a small head shake (1.3 s), then a stern look over the glasses with a smirk |

## Face

Higgsfield `gpt_image_2_6` (quality high, 1.25 credits each) edits of a 720 px face crop of the 2048 art
(`face_ref`, art box 660,60-1380,780), cut by `tools/face_patches_cfg.py face_cfg.json` (aligned by phase
correlation, colour-matched, only changed pixels kept, feathered):

| Variant | Job | Patches |
|---|---|---|
| v1 eyes closed + fan and hand removed | `529b625f-9e7c-40ea-ae71-ba2e63f8c58d` | `eyes_closed` (+ `eyeL_closed`/`eyeR_closed` winks), `fan_plate.png` (what is behind the fan: chin, neck, collar, epaulette; pasted under the forearm layer) |
| v2 happy ^^ + laugh | `ff14308b-03bc-4d88-8e7d-7f6195ff32ad` | `eyes_happy`, `mouth_laugh` |
| v3 frown + pout | `0f37b51d-e87d-4aca-9182-ea926f6696a7` | `eyes_frown`, `mouth_pout` |
| v4 glasses slid down, look over the rims, smirk | `0fd8cacc-f4c1-4e3d-b776-35ab483c06aa` | `over_glasses` (eyes + glasses + brows), `mouth_smirk` |
| v5 "ah" | `686b2217-57cf-45e7-8328-823860af2927` | `mouth_ah` |
| v6 "oh" | `3d0ec26a-ad3f-44cf-aa64-590da44c2976` | `mouth_oh` |

Mouth states: closed (the painted smile), `smirk`, `ah`, `oh`, `pout`, `laugh` (`open` maps to `laugh`, `small` to
closed, `pucker` to `oh`, so the generic API keeps working). Moving irises (`tools/iris_patches_cfg.py iris_cfg.json`,
range ±2.6 × ±1.2 px), procedural blush, glasses glint (`glasses_lens.png` mask + an additive band shader).

## Layers and bones

6 skinned layers, 17 bones (`rig_def.json`, built by `tools/build_heroine.py rig_def.json`):

* `body` — everything else; under-painted below every split part.
* `forearm` (+ `hand` bone at the wrist) — the raised forearm, glove, fan; drawn ABOVE the face patches (the fan is
  in front of her chin). Behind it: Telea for the sleeve/skirt, the generated `fan_plate` for the face/neck/collar.
* `braid` — 5-bone spring chain, in front of the coat; the coat under it is re-painted from coat pixels only
  (`repaint` step), so a swing never reveals hair smears.
* `tassel` (jade bead + gold tassel on the epaulette) and `earR` (jade drop earring) — 1-bone pendulums.
* `handR` — the hanging gloved hand (flexes a little at the wrist); `armR` hangs from the hips bone (it moves with
  the skirt it touches; its shoulder is hidden under the braid).

## Measured (selftest, all gestures + reactions, strain probe every 3rd frame)

See the lane report for the final numbers (worst / p99.9 / p99). Earlier iterations and what fixed them:
0.76 → the hair behind the right shoulder (head→chest band; fixed with a `hair_back` neck region and a smaller
`look`), 0.45 → the hanging arm against the skirt (fixed by parenting `armR` to the hips), 0.21 → jaw/neck in
`pat` (smaller head move, wider neck feather).

## Hook into the game (not done here: those files belong to other lanes)

* Home / live screen (`scripts/v09/home/live.gd`, `"rig10"` mode as for mc_gown): pick the rig scene per heroine —
  `res://assets/v10/rig/rin_officer/rig.tscn` for `rin` (+ outfit `r4`/officer when that outfit exists in the
  wardrobe). Scale: `0.72 * screen_h / 1280`, bottom-anchored, centre x = 725 art px (see `rin_demo.gd::_fit()`).
* Same API as V10LiveRig: `appear()`, `gesture()`, `react(zone, pos)` (zones head/armL/armR/hair/outfit/bg),
  `talk()/set_talking()/set_mouth_level()`, signals `tapped`, `gesture_started`. Forward V9Touch taps with
  `handle_input = false`.
* Voice: map her line start/end to `set_talking`; FX level «Минимум» → `motion = 0.4` (her default is 0.75).
* Before shipping: save `rig.tscn` as binary `.scn`; `body.png` and `fan_plate.png` are build inputs only (not
  loaded at runtime) and can be excluded from the export.
