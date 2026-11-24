# V10 living illustration rig (pilot: Маджонг-тян, evening gown)

One finished illustration is warped by a bone rig. Nothing is generated or morphed at runtime, so every
frame is the painting itself, bent a few pixels. This gives a deterministic, BD2-style idle without the
"AI video" look (no floaty morphing, no extra limbs).

## What is here

| Path | What it is |
|---|---|
| `scripts/v10/rig/live_rig.gd` | `class_name V10LiveRig`. Reusable runtime: procedural layered motion, spring chains, 2-bone IK pins, face patches, tap zones, reactions, entrance, lip-sync, and a dev strain probe |
| `scripts/v10/rig/rig_demo.gd`, `scenes/v10/rig_demo.tscn` | Demo with a scripted run of taps (`--script=0` to tap her yourself) |
| `scripts/v10/rig/tools/cutout.py` | rembg `isnet-anime` cutout. Uses one image per process and downscales to 1400 px first. Also bleeds edge colour |
| `scripts/v10/rig/tools/make_bg.py` | Background plate: removes the heroine (push-pull fill), applies depth-of-field blur, and extends to 9:16 in the cutout's frame |
| `scripts/v10/rig/tools/face_patches.py` | Aligns AI face variants and cuts feathered eye/mouth patches. Also makes the wink halves and the blush |
| `scripts/v10/rig/tools/build_rig.py` | Turns `rig_def.json` into `rig.tscn`: a Skeleton2D plus one skinned Polygon2D (grid mesh with painted weights) |
| `assets/v10/rig/mc_gown/rig_def.json` | **The rig, as data**: bones, weight regions, springs, IK, face patches, tap zones and layout |
| `assets/v10/rig/mc_gown/rig.tscn` | Generated rig scene. Do not hand-edit it; re-run `build_rig.py` |
| `assets/v10/rig/mc_gown/*.png` | `body.png` (1400² cutout), `bg.png` (plate), `eyes_closed`, `eyeL_closed`, `eyeR_closed`, `mouth_closed`, `mouth_small`, `blush` |

Use:
```gdscript
var rig: V10LiveRig = load("res://assets/v10/rig/mc_gown/rig.tscn").instantiate()
add_child(rig)
rig.scale = Vector2.ONE * 0.645                 # local units = body.png px
rig.position = Vector2(360 - 581 * 0.645, 1292 - 1400 * 0.645)
rig.appear()                                    # 0.6 s pop with overshoot
rig.talk(2.0)  /  rig.set_talking(true)  /  rig.set_mouth_level(amp)   # 3 mouth shapes
rig.react("head")                               # or let it take taps itself (handle_input)
rig.tapped.connect(func(zone): ...)             # head / armL / armR / hair / outfit / bg / none
```
Exports: `show_background` (bg layer with parallax), `handle_input`, `idle_mouth`, `motion` (amplitude), `parallax`.

## Why Skeleton2D + Polygon2D (and not a shader warp)

* **It runs on the GPU in the Compatibility renderer.** This was verified first with a test scene in GL
  Compatibility (llvmpipe): Polygon2D bone weights deform correctly. Per frame the CPU only writes 27 bone
  transforms. The mesh (4,795 vertices, 9,176 triangles, at most 4 weights per vertex) is skinned in the
  vertex shader, in 1 draw call for the body, plus the patches and bg.
* **The weights are data that the editor understands.** `rig.tscn` opens in the Godot editor: you can see the
  bones, and the Polygon2D UV editor can paint weights. A shader warp would hide the same information in
  uniforms and a hand-made weight texture.
* **A region-warp shader gives no more control.** You would still need per-region weights, and you lose IK,
  bone hierarchy and editor tooling. A shader warp only wins when you want a per-pixel effect (wind ripple,
  cloth noise). That can be added later as a material on `Body` on top of the skinning.

Cost measured in the demo (desktop CPU, Mesa llvmpipe software GL, 720x1280): `V10LiveRig._process`
averaged **0.23 ms** (0.6–0.9 ms peaks with 4 spring substeps at 120 Hz); the whole demo ran at 64–70 FPS on a
*software* rasterizer; 5–9 draw calls. On a phone GPU the rasterization of one 1400² textured mesh is trivial; the
GDScript update should stay ~1 ms. Run `-- --perf=1` to print `RIG PERF` lines.

## How it moves (all eased, nothing linear, nothing on a common period)

* **Breathing.** 3.6–4.4 s with a drifting period; inhale is a bit quicker than exhale. The chest bone rises
  4.2 px and scales (1.005, 1.011), so chest and shoulders lift about 1.2%. A deeper sigh comes every 16–26 s.
* **Weight shift and hip sway.** Layered sines at 7.3, 11.9 and 19.7 s. Hips translate and tilt, and the spine
  counter-rotates so the head stays over the feet.
* **Head drift.** Sines at 5.3, 8.9 and 13.7 s, plus a small nod at 6.7 and 10.3 s.
* **Camera drift.** The figure floats ±7 px and the background follows at 35% (parallax).
* **Springs** (tip-follower chains, simulated in art space at 120 Hz). Twin tails have 4 bones each; their root
  mostly ignores head rotation ("gravity"), and the lag shows down the chain. The skirt has 2 chains, plus the hip
  tassel, the navel pendant and the collar pendant. The bust is a soft translational spring that only follows
  breathing and body motion; it is kept subtle on purpose.
* **IK pins.** The hand on the hip stays on the hip while the chest moves. The raised hand stays behind the head
  and follows it, and the elbow solves.
* **Face.** Blink every 2.5–5 s; 22% of blinks are doubles. The eyes close in 90 ms and open in 110 ms. Winks,
  3 mouth shapes (35 ms crossfade) and a blush.
* **Reactions** (taps):
  * head: shy-happy. Eyes ^^, blush, laugh, shrug, head tilt with two bobs.
  * raised arm: she fiddles with her hair. The hand circles and the elbow follows.
  * hand: three pats on the hip.
  * hair: a toss of the twin tails.
  * outfit or room: a playful glance and a wink toward the tap, and the room drifts the other way.
  * **Dead zones** (no reaction): bust and hips/legs.

## Rigging the next heroine

Estimated time for one finished illustration: **about 1 working day** at first. Expect **4–5 h** once practised.
The pilot took longer because the tools were being written at the same time.

1. **Art (5 min).** Use a square 2048 illustration, ideally with the arms not crossing the face. Copy it into
   the scratchpad.
2. **Cutout (5 min).** Run `python3 tools/cutout.py art.png assets/v10/rig/<id>/body.png 1400`. Check the cutout on
   green, especially the gaps between the arms and the body.
3. **Background (5 min).** Run `python3 tools/make_bg.py art.png body.png assets/v10/rig/<id>/bg.png 0 1800 900`.
   Then put `bg_origin` and `bg_scale` into `layout` (the formula is in the script header).
4. **Face variants (20–30 min, about 5 credits).** Crop the face to 700², upscale it to 1024 and upload it
   (media_upload, then curl PUT, then media_confirm). Generate with `gpt_image_2_6` at 0.75 credits each, 2 variants
   per state: "same image, identical in every way, only her eyes are gently closed", "...mouth closed in a gentle
   smile", "...mouth slightly parted". Then edit the boxes and ellipses at the bottom of `tools/face_patches.py` and
   run it. Check `face_preview.png`. If the generations fail, paint closed-eye arcs in the line colour instead.
5. **Bones and regions (2–3 h; this is the craft part).** Make gridded tracing sheets of `body.png` (see
   `build_rig.py --debug` and the notes below). In `rig_def.json`:
   * Place the joints: root at the bottom centre, hips, spine, chest, neck, head pivot under the chin, the arm
     chains, the hair chains along each tail, and the skirt chains.
   * Trace region polygons. Regions are painted **in order**; each one takes over what it covers.
   * Choose `side` per region:
     * `"in"` puts the ramp inside the polygon. Use it for parts **behind** their neighbours, such as hair behind
       the body; the body edge then stays rigid.
     * `"out"` puts the ramp outside. Use it for parts **in front**, such as an arm over the dress or a tassel.
     * `"both"` is for soft areas.
   * Draw hair polygons far past the silhouette on the outer side. Otherwise the outer strands get pinned to the
     body.
   * `root_fade` blends a chain into its parent over N px. Tails need about 150–170.
6. **Build (1 min).** Run `python3 tools/build_rig.py assets/v10/rig/<id>/rig_def.json --debug /tmp/dbg`. Look at
   `weights.png` and `mesh.png`.
7. **Check (30–60 min).**
   * Run `rig_demo` with `-- --strain=1 --perf=1 --heat=11 --at=99 --shots=<dir>`. It writes `strain_heat.png`,
     the worst anisotropy per triangle over the scripted run: black is 0, red is 0.1, yellow is 0.25 and white is
     at least 0.5. Thin white lines show where a region boundary is too sharp for the motion across it: widen the
     `feather`, flip the `side`, or lower that bone's amplitude.
   * Record with `--write-movie out.avi --fixed-fps 30 --quit-after 360` and look at the frames.
8. **Tune (30–60 min).** The amplitudes are in `_pose_body()` and `_reaction_pose()` in `live_rig.gd`, and the
   springs are in `rig_def.json` under `dynamics`.

### What can be automated (on the GPU box)

* **Part segmentation.** Anime part segmenters or SAM 2 with point prompts can produce hair, face, each arm,
  torso and skirt masks. From those, region polygons and the `in`/`out` side (from layer order) follow
  automatically. This would remove most of step 5. Joints can be guessed from an anime pose model, but a human
  should still check them.
* **Background plate.** LaMa or SD inpainting on the GPU box would give a real clean plate instead of the
  push-pull fill. That allows bigger parallax and lets layers separate.
* **Under-painting for real layers.** Inpaint the dress under the hand, tassels and hair. Each part can then be
  its own mesh that slides instead of stretching (see "Known limits").
* **Face variants.** Batch the Higgsfield calls and run `face_patches.py` unattended. It already does the
  alignment, colour match and feathering.
* **QA.** The strain probe already gives a number. A CI-style run could fail a rig if p99 anisotropy rises above
  about 0.2.

## Known limits (honest)

* **It is one mesh, so nothing can pass behind anything.** Where a part moves against its neighbour, the
  boundary band compresses or stretches instead. Examples are the hair hanging behind the shoulder, the hand
  over the dress, and the tassels over the skirt. Amplitudes are kept small and the ramps sit on the hidden side,
  so frames show no tearing or seams. The probe still reports 0.2–0.35 anisotropy in thin bands along the
  hair/body edges during reactions. Hair texture hides it well; flat skin would not.
* **Head turns are tilts and leans, not real 3/4 turns.** There is no parallax inside the face, and the pupils
  cannot move because they are not on separate layers.
* **Crossfades briefly blend two images.** A blink or mouth change shows a blend for 1–2 frames, which is
  standard for patch swaps. Mouth shapes are 3 still images, not a continuous jaw.
* **The background top is a mirrored, darkened copy** of the ceiling. It is fine under UI, but a real outpaint
  would be better.
* **`rig.tscn` is an 850 KB text scene.** Before shipping, save it as a binary `.scn`, which loads faster on
  Android.

## Hook into the game (not done: the existing files are being edited elsewhere)

`scripts/v09/home/live.gd` (`V9HomeLive`) already has `mode = "rig"`. The proposed hook is a 4th mode,
`"rig10"`:
* In its build step, instantiate `res://assets/v10/rig/<hero>_<outfit>/rig.tscn` with `show_background` set
  according to whether home draws its own room.
* Place it with the same `art_tex` and `art_focus` maths.
* Set `handle_input = false` and forward `V9Touch` zones to `rig.react(zone)`.
* Map `Sfx.voice_started` / `voice_finished` to `rig.set_talking(true/false)`.
* Call `rig.appear()` on the select and partner-change flow.
* For idle lines, call `rig.talk(len)`.

The FX level can scale `rig.motion` (0.5 at «Минимум»).
