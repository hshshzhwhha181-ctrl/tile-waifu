# P50b — Full-tier golden composites (RuStore 18+ default)
Status: ready for owner review, nothing registered or approved. Branch `claude/p50b`, commit f87d11e (+ this report).
Recipe: 15 frames (MC, Yue, Nova x match/tea/summon/shop/win), gpt_image_2_6 + Elements, 9:16, 1k medium, 2-3 candidates per frame, prompts identical to H0_golden_composites.json `.search`. 51 images, 51 credits. Moderation: 0 refusals, 0 softened results.
Root cause of the tame P50 set: art-directed for the Yandex intersection (SPEC_V2 section 2, HEROINES section 4, LEGWEAR 1.1, v4c tail), not a model limit.

## Weaknesses (honest)
1. Accent colour (<=20%, strict mask) fails on 4 of 15: mc_tea 28.9, mc_win 23.1, mc_shop 22.9, yue_summon 23.1. The MC mask also counts her red floral cheongsam and blossoms; Yue is a lavender wash. Needs a rule decision (measure hair only), not a re-roll.
2. Head count 7-7.5 not measured (no landmarks placed). By eye MC and Yue read at the top of the range or above; Yue ~7.5-8.
3. No OCR / watermark scan run; text-free is a visual check only.
4. Anatomy: yue_summon c2 thin loosely drawn raised left hand; nova_tea c1 ambiguous boot/fishnet crossing; mc_tea small burst of motion lines beside the tile.
5. One outfit per heroine across all five frames (MC two). Other 6 outfit slots exist only as H2 prompts (5 probes rendered).
6. Yue is the tamest: long sheer drapery hides the hip slit. Backgrounds are rich and saturated; for the board screen the heroines become cut-outs on a quiet ground.
7. 1k medium candidates, 2-3 per frame (not the 8 + 2k finals plan of H0); the environment is the model's own, not the LoRA one.
8. Hana is leaner than the owner's reference 16 (canon body note is athletic): owner's call.

## Open items
- Confirm H2 budget 200 -> 350 cr (plan nominal 2562 -> 2712, ceiling 3074 -> 3254).
- Mark docs/HEROINES.md section 4, docs/LEGWEAR.md 1.1 and SPEC_V2 section 2 as superseded (not edited).
