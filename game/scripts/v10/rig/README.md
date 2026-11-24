# V10 living illustration rig — v2 (Маджонг-тян, evening gown)

One finished illustration, cut into a few layers and warped by one bone rig. Nothing is generated or morphed
at runtime: every frame is the painting itself, bent and slid a few pixels, so there is no "AI video" look.
v2 (after the owner watched the pilot: "livelier and flirtier, like BD2") adds:

* **Layers instead of one mesh.** Twin tails, the thigh in the dress slit, the raised arm, the hand-on-hip arm,
  two front hair locks and three hanging ornaments are separate skinned Polygon2Ds on the same Skeleton2D. Each is
  under-painted (what was hidden behind it is filled in), so parts slide over each other instead of stretching.
* **Animation principles.** Every pose channel runs through a second-order spring (snappy attack, ~15–20 %
  overshoot, soft settle). Gestures are keyframe tracks with an anticipation key, a quick attack, a long hold and
  a slower release. Head moves are shared by chest/neck/head (follow-through), tails and ornaments lag on springs.
* **2–3× livelier idle**: hip sway 11 px (was 5) and tilt 1.3° (was 0.55°) with spine/shoulder counter-tilt,
  head drift 2.6° (was 1.1°) and 3 px, random weight-shift "beats" every 2.5–5.5 s through the springs, eye
  micro-saccades, looser twin tails. Incommensurate sine layering is kept, so nothing reads as a loop.
* **7 autonomous flirty gestures** (every 4–8 s, never the same twice in a row) and **5 stronger reactions**.
* **Moving pupils** (iris patches inside the eye openings), **7 mouth shapes**, happy ^^ and frown eyes,
  a heart for the air kiss.

## What is here

| Path | What it is |
|---|---|
| `scripts/v10/rig/live_rig.gd` | `class_name V10LiveRig`. Runtime: idle layers, channel springs, gestures and reactions (`_build()`), spring chains, IK pins, face (blink, winks, eye states, irises, mouths, blush), hearts, tap zones, lip-sync, dev strain probe |
| `scripts/v10/rig/v10_iris.gdshader` | Draws an eye opening with the iris texture at an offset (pupils look around) |
| `scripts/v10/rig/rig_demo.gd`, `scenes/v10/rig_demo.tscn` | Demo: idle with autonomous gestures, then scripted taps (see args in the script header) |
| `scripts/v10/rig/tools/cutout.py` | rembg `isnet-anime` cutout (one image per process, 1400 px), edge colour bleed |
| `scripts/v10/rig/tools/make_bg.py` | Background plate (heroine removed, depth of field, extended to 9:16) |
| `scripts/v10/rig/tools/split_layers.py` | **v2.** Cuts `body.png` into layers by `rig_def.json` → `layers` and under-paints them (see below) |
| `scripts/v10/rig/tools/build_rig.py` | `rig_def.json` → `rig.tscn`: Skeleton2D + one skinned Polygon2D per `mesh_layers` entry |
| `scripts/v10/rig/tools/face_patches.py` | Aligns AI face variants and cuts feathered patches (`--v2`: pucker, pout, ah, oh, happy ^^, frown) |
| `scripts/v10/rig/tools/iris_patches.py` | **v2.** Eye sockets (iris painted out) + iris discs for the moving pupils |
| `assets/v10/rig/mc_gown/rig_def.json` | **The rig, as data**: bones, regions, layer split, mesh layers, springs, IK, face, zones |
| `assets/v10/rig/mc_gown/rig.tscn` | Generated (do not hand-edit; re-run `build_rig.py`). 11 layers, 29 bones |
| `assets/v10/rig/mc_gown/layer_*.png`, `layers_meta.json` | Split layers (cropped; origin in the json) |
| `assets/v10/rig/mc_gown/*.png` | `body.png` (source cutout), `bg.png`, eye/mouth/blush patches, `eye?_socket/iris.png` |

Use:
```gdscript
var rig: V10LiveRig = load("res://assets/v10/rig/mc_gown/rig.tscn").instantiate()
add_child(rig)
rig.scale = Vector2.ONE * 0.645                 # local units = body.png px
rig.position = Vector2(360 - 581 * 0.645, 1292 - 1400 * 0.645)
rig.appear()                                    # 0.6 s pop with overshoot (fades as one picture)
rig.gesture("air_kiss")                         # or let auto_gestures pick one every 4-8 s
rig.react("head", global_pos)                   # or let it take taps itself (handle_input)
rig.look_at_global(p, 1.5)                      # eyes + head follow a point
rig.talk(2.0) / rig.set_talking(true) / rig.set_mouth_level(amp)
rig.tapped.connect(func(zone): ...)             # head / armL / armR / hair / outfit / bg / none
rig.gesture_started.connect(func(name): ...)
```
Exports: `show_background`, `handle_input`, `idle_mouth`, `motion` (idle amplitude; 0.5 for FX «Минимум»),
`parallax`, `auto_gestures`, `gesture_gap` (Vector2 seconds, default 4–8), `gesture_seed` (0 = random).

## How it moves

**Channels and springs.** A pose is ~30 named channels (`hip_x`, `hip_rot`, `spine`, `chest_rot`, `shrug`, `lean`,
`neck`, `head`, `head_x/y`, `zoom`, `cam_x/y`, `bg_x`, `armL`, `ikL_x/y`, `armR`, `ikR_x/y`, `handR`, `thighL/R`,
`look_x/y`, `tailL/R` impulses). Active gestures/reactions sum their tracks into the channel *targets*; each channel
follows its target with second-order dynamics (`CH` in `live_rig.gd`: frequency f, damping ζ, response r).
ζ≈0.42–0.5 gives the BD2 "snap then settle" overshoot; the head (f 1.7) and arms (1.8–2.8) are a bit slower than
the hips, so they trail the body (overlapping action). Eyes are fast and critically damped (f 5.5, ζ 0.8).

**Idle layer** (added on top, all eased, nothing on a common period): breathing 3.6–4.4 s with a sigh every
16–26 s; weight shift with sines at 7.3/11.9/19.7 s (hips ±11 px, ±1.3°, hip rises on the loaded side; spine
+1.0° and chest +0.5° counter → contrapposto); head drift 5.3/8.9/13.7 s (±2.6°, ±3 px) and nod; camera float
±9 px with background parallax 0.35; random weight-shift beats (±7 px, through the springs); eye saccades
every 0.8–3 s (±1.3 px); tail breeze. Head moves are shared 30 % chest / 25 % neck / 45 % head so the whole upper
body leans into them. Shrugs lift the arm roots and neck more than the ribcage.

**Secondary.** Tail chains (4 bones each, k 11–13, ζ low, max 3.5–4.5°/bone), skirt panels, tassel, navel
and collar pendants (now separate layers, so they swing without stretching anything), a subtle bust spring
(only follows chest motion and breathing: amount 0.4, max 2.5 px — never driven directly). IK: the hand on the
hip is pinned to the hips (weight 0.65, so it slides a little instead of folding the elbow); the raised hand is
pinned in *chest* space and hidden behind the head hair, so head moves never pull the elbow.

### Autonomous gestures (every `gesture_gap` s, random, never the same twice in a row)

Units: px of body.png (×0.645 on screen), degrees, `zoom` = fraction. "s" = side (±1, random per play).
Keys are `[time, value]` pairs, smoothstep between; listed as attack-peak → hold → release. Edit `_build()`.

| Gesture | Dur | Main tracks (peak) | Face | Secondary |
|---|---|---|---|---|
| `hip_pop` | 2.0 s | hip_x −5s→+26s @0.42 s, hold 23s to 1.3 s; hip_rot +0.8s→−3.6s; hip_y −7; spine +2.6s; chest_rot +1.5s; head +3s; head_x −4s; thighL −1.2s | look_x +1.5s, closed smile 0.35–1.6 s, blush 0.35 | tails −3/−2s impulse |
| `lean_in` | 2.6 s | zoom −0.006→+0.03 about the face @0.7 s, hold to 1.9 s; lean 1.0 (chest/head forward scale); head_y +5 (chin down); head +2.2s; shrug +2.5; cam_y −3 | look_y −2.2 (eyes up to camera), blush 0.85, smile | — |
| `air_kiss` | 2.4 s | head −1.5s→+4.5s @0.55 s; head_x +5s; head_y −2→+2; zoom +0.012; shrug +3.5; chest_rot −1s; hip_x −6s | mouth pucker 0.35–1.2 s then smile; wink (side) 0.65–1.35 s; blush 0.75 | heart spawns at the lips @0.95 s, floats up and sideways |
| `tail_flick` | 1.9 s | head −2.5s→+6.5s @0.4 s→+4s; head_y +2→−4; head_x +4s; hip_x −6s; shrug −1.5→+3 | eyes closed 0.3–0.62 s (a proud toss), mouth small→smile | tailL −7.5s, tailR −5.5s impulse @0.45 s, springs whip and settle |
| `shoulder_roll` | 2.6 s | shrug +7 @0.7 s→+3→0; chest_rot +2.6s→−1s; armR/armL roll; head −3s; head_y +3; hip_x +4s | look_x −3.8s, look_y +0.8 (coy sideways glance), blush 0.55 | — |
| `knee_in` | 2.4 s | thighL +1.0→−5.6 @0.4 s, −3.4, −5.3 (fidget), −4.3; thighR +1.0 (other knee bends); hip_y +3; hip_rot +1.4; shrug +5; head −2.5, head_y +4 | mouth pout 0.3–1.5 s (jealous), look away (+3, +1.2) then back up, blush 0.9 | thigh layer slides under the slit trims |
| `hair_touch` | 2.4 s | ikL_x/y: raised hand twirls 2 loops (±7.5×6.5 px); armL −1→+4 (elbow lifts); head +3.5 (leans into the hand); hip_x −6; chest_rot +1.2 | look_x +2.8 towards the hand, mouth small→smile, blush 0.5 | tailR +2.5→−1.5 |

### Reactions (taps; intimate areas are dead zones and never react, nor count as taps)

| Tap | Reaction | Dur | Main tracks | Face |
|---|---|---|---|---|
| head | `nuzzle` towards the tap side | 2.6 s | head −1s→+5s, head_x +6s, head_y −2→+3, neck +2s; happy bounce cam_y +4/−14/+2/−9/0 over 0.95 s; shrug bounces; tails ±3–4 | eyes ^^ 0.08–1.9 s, laugh (painted open) → "ah" → smile, blush 1.0 |
| 3+ taps within 1.3 s anywhere live | `pout` → giggle | 2.8 s | huff: head +4s→−5s with a shake, head_y −3, shrug +7, hip_x −10s; then giggle: head +2s, head_y +2.5, shoulder bounces at ~6.7 Hz | 0.05–1.2 s puffed-cheek pout + frown eyes ("hey!"), then ^^ eyes and open/ah/small alternating every 0.13 s |
| background / outfit | `look` at the point | 2.3 s | look_x/y = direction × (4.2, 1.8) px (clamped to the eye opening); head ±4.2°, head_x ±6.5, head_y, neck; background drifts the other way | smile, wink on that side @1.55 s, blush |
| hand on hip | `wave` (finger wag) | 2.0 s | ikR_x +12 / ikR_y −5 (hand swings off the hip along the arc around the shoulder, so the elbow keeps its angle); handR wags −5/+3.5° ×3; head −3, look down-left | "ah" → small → smile, wink |
| raised arm | `hair_touch` | 2.4 s | as above | |
| hair | `tail_flick` | 1.9 s | as above | |

**Giving another heroine her own set:** copy the `match` branches of `_build()` she should have, and tune the
amplitudes to her rig (a pose with the arms down has no `hair_touch`; a long skirt has no `knee_in` — swap in e.g.
a skirt swish via the skirt chain impulses). Keep the shape *anticipation → quick attack → hold → slower release*
and let the springs add the overshoot. List her gestures in `GESTURES`. Keep reaction amplitudes ≤ the values
above unless her layers are split the same way; check with the strain probe.

### Face

* Blink every 2.5–5 s (22 % doubles), closes in 90 ms, opens in 110 ms. Winks are halves of the closed-eye patch.
* Eye states: `eyes_closed`, `eyes_happy` (^^), `eyes_frown` (annoyed brows). Blush patch.
* **Irises**: `eye?_socket.png` = the eye opening with the iris painted out (sclera colour with a lid shadow),
  `eye?_iris.png` = the iris disc (hidden parts inpainted from the visible iris). The shader draws the iris at
  `offset` inside the opening; offset 0 = the original art. Range ±4 px × ±1.8 px (body px).
* **Mouths**: `closed` (smile), `small`, `ah`, `oh`, `pucker`, `pout` (puffed cheeks) + the painted open laugh.
  35 ms crossfades. Lip-sync picks open/ah/oh/small/closed syllables (75–160 ms); `set_mouth_level()` maps voice
  amplitude onto closed/small/ah-oh/open.

## Layers (v2): how the split works

`tools/split_layers.py rig_def.json` reads `layers.split` and writes `layer_<name>.png` (cropped) + `layer_body.png`:

* **Selection modes**: `hair` (hair-coloured pixels in the zone that are not solid "front": skin, lace, dress;
  thin dark strokes inside the hair are opened away, small lace holes closed, the dark antialiased fringe of the
  front stays with the front), `front` (solid pixels + their outline; `take_all` polygons for see-through lace),
  `poly` (the zone), `color` (ornaments by hue, grown by their outline).
* **Behind or in front.** Parts behind the body (tails, thigh, raised arm) get **under-painting** `ext` px deep
  under whatever covered them: hair and lace by a *translated copy* of the strip just outside the cut (strands keep
  their direction, sparse hair stays sparse — a mirror copy echoes the cut's outline, Telea smears), skin by
  OpenCV Telea; darkened with depth (`ao`) so a slide reads as "behind". Parts in front (hand-on-hip arm, front
  hair locks, ornaments) leave a hole in the body that is under-painted by Telea from the body itself
  (`under` polygons: only where there really is body behind; elsewhere the hole shows the layers behind).
* **Roots.** Near `root.at` a split part cross-fades with the body; `disc` lock regions in `rig_def.json` give both
  layers identical weights there, so nothing ghosts; the lock fade in the part's own layer is wide (110–220 px) so
  the part bends smoothly out of its root.
* **Draw order** = `mesh_layers` order: tailL, tailR, thigh, armL (behind the head hair), body, locks, locksR,
  pendant, navel, tassel, armR. Face patches are on the head bone, above everything. The entrance fades the
  figure inside a temporary CanvasGroup, so the under-paintings never show through during the fade.

Inpainting tools: classic OpenCV inpaint (Telea) plus the translated-strip fill and painted sclera fills. No
generated inpainting was needed for the layers; the face variants (mouths, eye states) were generated (below).

## Measured

**Strain probe** (`-- --strain=1 --heat=<s> --shots=<dir>`, `--dump=<t>` lists the worst triangles; v2 runs over
every layer, counts a triangle when ≥3 of 4 samples are opaque, skips under-painting hidden at rest and the art's
cut bottom edge, and reports idle and reaction phases separately). Anisotropy = s1/s2 − 1 of the local warp.

| | worst | p99.9 | p99 |
|---|---|---|---|
| v1 pilot, its scripted run (one mesh; its own probe) | 1.55 (20.2 in one folded tail triangle during the flick) | — | 0.58 |
| v2, reactions (head, 3-tap pout, look, wave) | 0.16 | 0.13 | 0.09 |
| v2, idle gestures (incl. hair twirl, hip pop) | 0.22 (raised elbow crease in the twirl) | 0.18 | 0.10 |

The remaining peaks are joint creases (elbows, wrist) and the neck/collar band under big head moves: real bends,
not layer boundaries. The hair/shoulder and hand/dress bands of v1 (0.2–0.5+, white in v1's heat map) are gone.

**Motion vs v1** (mean absolute luma change per 0.25 s over each recording, entrance skipped): face 15.7 vs 9.1,
twin tails 15.3 vs 6.2, hips 13.6 vs 4.2, whole figure 11.4 vs 4.9 — about 1.7–3.3× livelier, although v1's
recording is almost all reactions and v2's includes 12 s of idle.

**Cost** (`-- --perf=1`, desktop CPU, Mesa llvmpipe software GL, with other Godot jobs on the box):
`V10LiveRig._process` 0.49 ms average, 1.5 ms peak (30 channel springs + chains at 120 Hz substeps); 11 mesh
layers, 9.4k vertices / 17k triangles including the one-cell slack ring; 16 draw calls for the whole demo; 40–44
FPS on the *software* rasterizer. On a phone GPU the rasterization is trivial; the GDScript update should stay
~1–1.5 ms.

## Rigging the next heroine

Plan **1–1.5 working days** (v2 adds the layer split and the gesture tuning).

1. **Art, cutout, background, face variants** — as in the pilot: `cutout.py`, `make_bg.py`, Higgsfield
   `gpt_image_2_6` face variants from a 700² face crop upscaled to 1024 (0.75 credits each; v2 set = 8 variants:
   pucker ×2, pout ×2, ah, oh, happy ^^, frown), then `face_patches.py` (`--v2`), check `face_preview*.png`.
2. **Irises** — trace the eye openings and iris circles on a 9× crop, edit `EYES` in `iris_patches.py`, run it.
3. **Bones and regions** — as in the pilot (joints; regions painted in order; `side` in/out/both; chains). Add
   thigh bones if her legs show, ornament bones for anything that dangles.
4. **Split** — in `layers.split`: zones for the tails (`hair`), arms (`front` + `take_all` over lace/gloves),
   front hair locks and ornaments (`poly`/`color`, `over: true`, `under`), legs in slits (`poly`, `inset`). Run
   `split_layers.py --debug <dir>` and look at `selections.png` and every `layer_*.png` on green: no lace in the
   hair, no hair in the body, no specks. Then `mesh_layers` (order = draw order) and the `disc` locks.
5. **Build** — `build_rig.py rig_def.json --debug <dir>`; check `weights_<layer>.png`. Godot `--import`.
6. **Check** — `rig_demo` with `--strain=1 --heat=… --shots=…`; fix hot spots with `--dump`; record and look at
   frames every 0.25 s (`ffmpeg -vf fps=4`): tearing, gaps where a part slides, ghosts of under-painting.
7. **Tune gestures** — amplitudes in `_build()`, springs in `CH`, idle in `_pose_body()`.

## Known limits (honest)

* **Still 2D warping.** No real 3/4 head turns; the head tilts, shifts and the pupils move. Big turns would need
  more face variants or a part-based face.
* **Under-painting is synthetic.** It holds for slides of ~10–35 px (that is all the gestures use); larger moves
  would show smeared hair or Telea-blurred dress under the hand. A proper inpaint (LaMa/SD on the GPU box) would
  allow bigger motion.
* **Crossfades blend images** for 1–2 frames (blink, mouth change), standard for patch swaps.
* **The hand-on-hip wag is small** (the dress under the hand is synthetic; the fingers are not separate).
* **Knee-in reads subtly** because the art is cut at mid-thigh.
* `rig.tscn` is ~1 MB of text: save it as a binary `.scn` before shipping.

## Hook into the game (not done: those files are being edited elsewhere)

As in the pilot: a `"rig10"` mode in `scripts/v09/home/live.gd`, `handle_input = false` and forward `V9Touch`
zones to `rig.react(zone, pos)`, map voice start/finish to `set_talking`, call `appear()` on select. FX level
scales `motion`; `auto_gestures = false` while dialogue UI is up if the gestures distract.
