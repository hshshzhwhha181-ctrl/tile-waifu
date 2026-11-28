# Pose and anatomy bake-off (art factory v6, 2026-11-28)

Test heroine: Mahjong-chan (MC element 7df3cc78). Six hard poses: (a) over-the-shoulder back view, (b) leaning on a table from behind-side, (c) seated crossed legs, (d) kneeling arch side-back, (e) lying on side hip-up, (f) one leg lifted. 2:3, 1k, `gpt_image_2_6` medium unless noted. 156 images generated (+2 refused by flux_3_image) + 6 mannequin uploads. Spend: **187.5 credits** (balance 16960.38 -> 16772.88), cap 220.
Files: `bakeoff.csv` (per candidate scores), `bakeoff_sheet.jpg` (one candidate per cell, green = accepted, red = rejected), `tools/art/pose_mannequin.py`, `tools/art/bakeoff_prompts.py` (exact prompts).

## Scoring (0-3, one rater, 4-up thumbnails at 0.5-0.72 scale, close checks at full size)
proportions (crotch 45-48 %, leg <= torso + head, 6.75-7.0 heads), limbs/hands/feet, twist continuity, thigh proportion, naturalness, boldness, plus two flags: `hardline_fail` (bare buttock cheek or underwear-like strip visible) and `style_match` (approved glossy gacha look: 3 = gpt look, 1 = flatter other-model look).
**Accepted = proportions >= 2, limbs 3, twist 3, thigh >= 2, naturalness 3, boldness >= 2, hard line clean.** Proportions are eye estimates (no landmarks); treat +-1 as noise.

## Results

| variant | what | n | accepted | rate | credits per accepted | hard-line fails | mean prop |
|---|---|---|---|---|---|---|---|
| V0 | current recipe (7.5 heads, "long legs", one-line pose, mini qipao) | 24 | 11 | 46 % | 2.2 | **13** | 1.67 |
| V1n | + anatomy grammar + new proportion grammar + joint-by-joint pose | 24 | 15 | 62 % | 1.6 | 9 | 2.00 |
| V1o | same as V1n but OLD descriptor (7.5 heads, long legs) | 12 | 5 | 42 % | 2.4 | 6 | 1.67 |
| V2 | V1n + pose-mannequin reference | 24 | 11 | 46 % | 2.2 | 10 | 2.00 |
| **V1h** | **V1n + hem rule + moderate heels (outfit grammar)** | 18 | **17** | **94 %** | **1.06** | **0** | **3.00** |
| V3k | Kling Image 4.0 (2 cr), V1h text + 2 element images | 18 | 3 | 17 % | 12 | 0 | 1.33 |
| V3s | Seedream 5.5 (1.5 cr), same | 12 | 2 | 17 % | 9 | 2 | 1.33 |
| V4 | edit pass ("same image, fix only: ...") on 6 near-misses, 2 each | 12 | 12 | 100 % of edits | 1.0 per edit (+1 for the source) | 0 | 2.17 |

Per pose, accepted / n (V0, V1n, V1o, V2, V1h, V3k, V3s):
a 0/4, 2/4, 0/2, 1/4, **2/3**, 0/3, 0/2 | b 0/4, 1/4, 0/2, 1/4, **3/3**, 0/3, 0/2 | c 4/4, 4/4, 2/2, 3/4, 3/3, 0/3, 0/2 | d 0/4, 0/4, 0/2, 0/4, **3/3**, 2/3, 2/2 | e 3/4, 4/4, 1/2, 3/4, 3/3, 1/3, 0/2 | f 4/4, 4/4, 2/2, 3/4, 3/3, 0/3, 0/2.

## What the data says

1. **The biggest defect was not anatomy, it was the hard line.** In the 102 gpt_image_2_6 candidates of V0-V2/V1h exactly 1 had a limb defect (V2 f2, thin lifted leg); Kling had 4 of 18 and Seedream 1 of 12: the model is already good at five fingers and two legs. What broke was every rear pose: a mini dress with side slits on a back view, lean or kneeling arch shows the lower buttock (V0: 13 of 24 fail; a, b, d fail almost always). Fixing the outfit grammar (hem at mid-thigh, explicit HEM RULE) took V1h to 0 hard-line fails in 18 and 94 % accepted. Any heroine with a short skirt or high-cut bottom needs the same rule on every rear, kneel, lean and side-lying pose.
2. **Twist continuity works from the text alone** once the pose is written joint by joint: "pelvis, buttocks and both legs face AWAY from the camera ... spine twists gradually ... only the head turns further". Twist was 3/3 in all gpt variants (V0 too, but the V0 rears were mostly hard-line fails). Kling d2 is the only twist miss.
3. **New proportion grammar beats the old descriptor only a little in words, a lot with the outfit change**: V1o (7.5 heads, long legs) 1.67 vs V1n 2.0 vs V1h 3.0. Eye measurement on 4 standing back views: crotch about 48-50 % of height for V0/V1o, about 47-49 % for V1n, about 46-48 % for V1h. Part of the V1h gain is the moderate court heel (stilettos add roughly 5-8 % to the leg line) and the longer hem hiding the upper thigh: the two changes were not separated (budget). Treat "heels of moderate height" as part of the proportion recipe. The words "very long legs" were not needed to keep the heroine sexy; boldness stayed 2.7-2.8 of 3.
4. **Thigh proportion is the remaining weak spot of gpt**: mean 2.3; V1h a2 has balloon thighs (score 1). Seen mostly on standing back views. A V4 edit "each thigh clearly narrower than the pelvis" slimmed them only slightly (score 2 -> 2). Kling and Seedream draw lean legs (thigh 2.8) but far too long (proportions 1.3).
5. **V2 mannequin: no measurable gain, not worth the upload step.** Accepted 46 % = V0 and below V1n (62 %); hard-line fails the same (10). It followed the lifted-leg pose (f) and the leaning angle (b) a little more literally, but it made (e) worse (a crude flat mannequin of a lying figure produced an upright semi-seated pose, twist 2, naturalness 2) and f2 got a thin lifted leg. The mannequin is crude by construction (2D capsules, no depth); do not invest more unless a real 3D rig (Blender/pose library with depth and foreshortening) replaces it. The text twist grammar already does the job.
6. **V3 other models (scout 14 images, then 30): not better.** Models tried: nano_banana_2_1, seedream_5_5, kling_image_4_0, grok_image_2_0, seedream_v5_pro, gpt_image_2_5 and flux_3_image. `flux_3_image` refused both prompts (moderation "nsfw"). nano_banana_2_1 and gpt_image_2_5 produced awkward or revealing results (gpt 2.5: thong-like cut-out on the kneel; nano: crossed standing legs). Seedream 5.5 and Kling 4.0: sound anatomy and fast pose adherence but (a) proportions (long legs, flat 1.3), (b) style (flatter, not the approved glossy-warm gacha look: style_match 1), (c) a changed outfit (backless variants, long panels), (d) seedream e-pose showed a dark strap line (hard-line fail). Kling cost 2 cr and queued slowly (~2 min). Verdict: for this style, gpt_image_2_6 + Element stays the base. Seedream 5.5 is the only credible fallback for kneeling arches (d 2/2) at 1.5 cr if gpt keeps failing there.
7. **V4 edit pass is the cheapest rescue for hard-line misses**: hem edits on 3 near-misses (V0 d2, V1n b3, V1n d1) fixed the hem in all 6 results while keeping pose, face and style (about 2 cr per rescued image including the source). Proportion edits ("shorten the legs") work weakly (V0 a2: slightly shorter, still 2); thigh edits are partial. Edits are for hem/clothing coverage and small anatomy faults, not for body proportions.

## The grammar that works (exact text in `tools/art/bakeoff_prompts.py`, variant V1h)

Prompt order: element + identity, **outfit with HEM RULE**, proportion grammar, anatomy rules, joint-by-joint pose, setting, style tail.

- Outfit: opaque skirt or dress with the **hem at mid-thigh**, moderate-height court heels (not stilettos), and the sentence "the opaque hem always stays in place and fully covers the buttocks from behind, from the side and in every pose; no bare skin of the buttocks is ever visible and the skin between hem and stocking tops is only the thigh".
- Proportions (owner binding): "soft shapely mature figure, 6.85 heads tall (170 cm), a slightly larger head and shoulders, compact torso, balanced proportions: the crotch line sits at about 46% of her total height and her leg length from crotch to floor is no longer than her shoulder-to-crotch length plus one head; proportionate legs, soft full thighs with a visible knee and a tapering calf ... Portrait-lens camera (long focal length) at hip height, no wide-angle distortion, no from-below angle". Never "long legs", "very long legs", "leggy".
- Anatomy rules: "exactly two arms and two legs, two hands with five fingers each, two feet; no duplicated, extra or fused limbs; both legs clearly separate and countable; thighs full and soft but anatomically proportional, a thigh is never wider than the pelvis at the hip line; knees and calves visible. The body twist is physically continuous: pelvis, buttocks and legs rotate together with the torso, the spine twists gradually through waist and ribcage and only the head and neck turn further."
- Pose: name the camera position, then which body parts face away, joint-by-joint (weight leg, knee, hands, head turn), and for lean/kneel: the angle of the torso and "the twist is continuous from the pelvis through the ribcage to the head".

## Recommended recipe by pose type

| pose type | recipe | expected accept (this test) |
|---|---|---|
| back view, twist (a) | V1h; add a thigh-width line ("thighs slimmer than hips") and reroll or V4 thigh edit | 67 % (2/3) |
| lean on table, kneel arch, rear-weighted (b, d) | V1h (hem rule is decisive); V4 hem edit for any near-miss | 100 % (6/6) |
| seated crossed legs (c), lying (e), one leg lifted (f) | V1h or V1n (hem rule harmless) | 100 % (9/9) |
| fallback for kneel | seedream_5_5 with element images | 100 % but style 1/3 |

Cost per accepted image: **1.06 cr (V1h)**, 1.6 cr (V1n), 2.2 cr (V0). For production plan on 1.2 cr per accepted candidate at 1k including a V4 rescue budget (about 1 in 8). Hold 4 candidates per cell, not 3: one reroll slot absorbs the 1-in-17 miss.

## What still fails or is untested

- Thigh width on standing back views (a2 balloon thighs) and head-count: no landmark-based measurement, the proportion scores are eyeballed (the crotch is hidden by the hem; head count looks about 7.0-7.4, not measured).
- Confound: V1h changes two things at once (hem + heels). Single-variable splits not run.
- One heroine, one outfit (a long-hair qipao set). Heroines with shorter hair, shorts or bunny/leotard bottoms must re-test the HEM RULE equivalent ("fully opaque bottom covers the buttocks in every pose").
- No OCR / watermark scan; no identity check beyond eye (all gpt variants kept the pink twin-tails and jade pins). Kling/Seedream faces drifted toward an older, flatter anime face.
- Moderation: 0 refusals on gpt_image_2_6, Kling, Seedream; flux_3_image 2 of 2 refused (`nsfw`); edits 0 refusals.
- Mannequin: 2D only; rejected as a method until a depth-aware rig exists.
