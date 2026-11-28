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

## Round 2 (owner answers and new orders, 2026-11-28)

Branch `claude/p50b`. Credits this round: **25.5** (12 + 3.5 + 10); session total 76.5 of the 250 cap; the 120 cr round-2 allowance is mostly unspent. Rows in `design/art_batches/SPEND_LOG.csv`. Nothing is approved or registered.

### Done

1. **Budget approved and old rules superseded.** H2 200 -> 350 cr and ceiling 3254 are recorded as approved. Banners (old text kept) were added to `docs/HEROINES.md` (top of file, section 4, and the rating paragraph "18+ не делаем"; the header now says the Yandex build is dropped and the 17+/18+ Full tier is the default), `docs/LEGWEAR.md` section 1.1 and `SPEC_V2.md` section 2 (scratchpad copy, `lora-v2/SPEC_V2.md`; it is not in the repo).
2. **Height and body variety.** Body table (cm and heads per heroine) is in `design/ART_TIER_FULL.md` section 3a and `tools/art/full_tier_wardrobe.py` (`HEIGHTS`): Yue 177 / 7.9, Zlata 176 / 7.8, Rin 172 / 7.5, MC 170 / 7.5, Hana 168 / 7.25, Tsubame 165 / 7.25, Shirin 163 / 7.25, Kohaku 160 / 7.0, Nova 158 / 7.0, Miel 155 / 6.75. The fixed "7.25 heads" is gone from tail `v5f`; every prompt now carries `Body: <tag>, about N cm tall (H heads tall)` and a per-heroine figure sentence with "a mature adult face and figure". Validator: `N heads tall` must equal the table, lie in 6.75 to 8.0, and a mature adult face must be stated; selftest cases added.
3. **Boldness ceiling.** `ART_TIER_FULL.md` section 3b and the rule-change table now cover underbust cut-outs and side-cut sides (fashion terms; `underboob` and `sideboob` stay banned in the validator, the fashion terms were enough), high-cut leotards and bodysuits, string-style bikinis, thigh straps and garters, sheer and wet-look fabric over lined garments, tight fabrics, back-view and hip-focused three-quarter angles (eye level), sprawled and reclined bed scenes, kneeling arched, hands in hair, leaning forward, lying on the side, straddling a chair backwards, bath and onsen scenes in robes or bikinis that stay covering, pillow hugging, close-up teasing faces. Not used: all fours, legs open toward the camera, open-knee squats, under-skirt or from-below angles. The wardrobe (`full_tier_wardrobe.py`) was rewritten: 10 heroines x 7 outfits, each with poses A/B/C (H2 search) plus 2 hero splash poses H1/H2 (H4 key art and `hero_prompt_variants` of H2 finals): 70 outfits, 350 poses.
4. **Batches rebuilt** (`build_art_batches.py`): H0..H4 and H2 use the body table; H4 is now 2 hero splash poses per SSR heroine (rin bunny tea-server, hana sunflower string bikini, yue dragon-scale armour; 7 search + 3 final per pose, same 80 cr, 13 tasks). `validate_batches.py`: OK (15 batches, 983 tasks, 0 errors), selftest 16/16.

### Generated

- `round2/lineup_10_height.jpg` (+ `_c1`): all ten heroines side by side, 21:9 2k, one prompt with 10 element ids. **It worked first try**: tallest (Yue) and shortest (Miel) differ clearly, all ten are recognisable and read as adults. Cost 3.5 cr for 2 images. Not a batch task (a multi-element prompt is outside the single-heroine validator rule).
- `round2/boldness_probes/` (12 frames, 2:3 1k): mc_swim (back view, wet hair, string bikini), mc_service hero (bunny leotard, kneeling arched), nova_battle hero (leaning over the bike, zip low), yue_robe (sprawled on the bed), kohaku_swim (kneeling arched, onsen, wet sarong), rin_robe (kneeling, taking her braid down), tsubame_service (straddling a crate), miel_robe (hugging a pillow), shirin_battle (backbend), zlata_swim (kneeling, wringing the braid), hana_service (straddling a bar stool), nova_evening (back view, latex bodysuit). **0 refusals**, all clothed. `contact_sheet_round2.jpg` shows the lineup and the 12 probes.
- `round2/height_rerolls/` (Nova x5 at 158 cm / 7.0 heads and Yue x5 at 177 cm / 7.9 heads, the H0 scenes with the new prompts, 1 candidate each): Nova reads as a petite adult woman, Yue as very tall and statuesque. Sheet: `height_rerolls_sheet.jpg`. MC (170 cm, 7.5) was not re-rolled: the change from 7.25 is too small to see.

### Weak spots (honest)

1. **The ceiling is reached by one probe and that one is the edge.** `kohaku_swim_H1`: string bikini plus wet-look sheer sarong, kneeling arched. Cups and bottoms cover everything, no nipple or groin outline, but it is as far as the hard lines allow. Anything bolder is out. The AD should look at it before the rest of the batch is released.
2. **Height shows in lineups, not in single frames.** In a solo frame it is only proportion and framing; the product needs lineups, duo scenes or the roster screen to show it.
3. **Petite risk.** Nova at 7.0 heads has a slightly larger head and softer face than the first set; still clearly adult, at the lower edge of the look. Miel (6.75) was only drawn in a probe (curvy, mature face). Watch every petite frame for childlike cues; the validator can only check the numbers and the words, not the faces.
4. **Hana's probe frame shows visible abs and arms** against the "no visible muscle definition" note, and a smudge-like mark on one sock in the lineup.
5. **Counts and checks not done**: head count was not measured on pixels (the model does not follow it per frame), no OCR / watermark scan, 1 candidate per re-roll frame. `H0` prompts changed (body table), so `golden_full/picks` of round 1 (7.25 heads for everyone) are no longer byte-identical to the batch; Nova and Yue round-2 frames are.
6. The Round-1 accent-colour failures (mc_tea, mc_win, mc_shop, yue_summon) are not addressed; the open question "measure hair only?" stands.
7. `transactions` still fails its output schema; spend is by image count.

### Open items for the lead

- Owner look at `round2/contact_sheet_round2.jpg` and `height_rerolls_sheet.jpg` (copies in the scratchpad `share/` folder).
- Decide whether `kohaku_swim_H1` is the accepted ceiling.
- Whether Shirin stays at 163 cm (canon text said tall; the owner's number was used).

## Round 3 (owner feedback on rounds 1-2: fuller thighs, accent on legs and bust, more hot poses)

Credits: **4** (4 pilot frames, 1k medium); session total 80.5 of 250. Nothing approved or registered. Pilots: `round3/round3_pilots.jpg` (copy in the scratchpad `share/round3_pilots.jpg`), frames `round3/*_1k.jpg`.

### Done

- **A. Figure descriptors** per heroine (`FIGURE` in `tools/art/full_tier_wardrobe.py`, table in `ART_TIER_FULL.md` section 3a, used in the prompt's Body clause): MC `full soft thighs, wide rounded hips ... full bust accented by the neckline`; Miel `thick shapely thighs and wide hips, soft curvy pear-shaped`; Kohaku and Rin full soft thighs; Zlata full thighs on long legs; Yue and Shirin very long statuesque legs with full thighs; Hana `strong thick thighs and soft definition`; Tsubame and Nova slim toned but shapely. Head counts and the adult-face floor (6.75) unchanged. `thick`, `curvy`, `full thighs`, `wide hips` are not hard-banned (the hard list is unchanged); the validator now requires each Full prompt to carry the heroine's exact descriptor.
- **B. Leg and bust shot types.** Each of the 70 outfits now has poses A..E: D = leg focus, E = bust focus, camera codes L (low knee-level full body), T (thigh-focus crop), S (seated, legs prominent), B (stocking-band and garter close crop), F (lean-forward bust-forward), all at eye, hip or knee level, never below the hem. Plus the 2 hero splash poses. H1 has 5 frames per heroine (base, win, tease, leg, bust); H3 was re-posed (T1 bust-forward, T2 long leg forward at knee level, T3 arched presenting); every prompt says "the composition accents her legs, thighs and bust".
- **New budgets** (recomputed, `ART_BATCHES.md` updated): **H2 350 -> 490 cr** (5 x 1 cr search + 1 x 2 cr final per outfit, 70 outfits, 140 tasks, pilot 15 cr); **H1 330 -> 530 cr** (50 frames x (6 + 2 x 2) + 30 post, 101 tasks); H0, H3, H4 unchanged (180, 150, 80). **Plan nominal 2712 -> 3052 cr, ceiling 3254 -> 3662 cr.** The owner confirms the new numbers (earlier approval covered 3254).
- **Validator**: green (15 batches, 1023 tasks, 0 errors), selftest **19/19** (new: missing figure descriptor, wardrobe variant losing it, minor word next to a fuller-thigh term, and the positive control now covers `thick shapely thighs`, `wide hips`, `curvy`).

### Pilots (4 cr, 0 refusals)

| frame | prompt | result |
|---|---|---|
| mc_base_D_leg_low | low knee-level full body, long leg forward, lace stocking top | works: long legs, full soft thighs, stocking top and garter band in view, adult face |
| miel_evening_D_thigh_crop | thigh-focus crop, perched on the counter, leg drawn up | works strongly: thick shapely thighs and wide hips, full bust, bow bands in view; the lifted leg shows the frilled petticoat of the skirt (not underwear, but close to the under-skirt line) |
| hana_base_D_leg_low | low full body, strong thick thighs | works moderately: athletic thicker thighs and strong calves, over-the-knee striped socks; less fuller than Miel or MC |
| yue_base_E_bust_forward | hands on knees, bust-forward, waist-up to hips | works: full bust framed by the plunging V, long statuesque legs with full thighs at the frame edge, adult face |

### Weak spots

1. Miel's lifted-leg crop is at the edge of "no under-skirt camera": for skirts with a lifted leg keep the T crop at hip level and use opaque tulle hems; do not drop the camera.
2. Hana's thicker thighs read only moderately; a stronger wording ("thick powerful thighs") may be needed if the owner wants more, with the athletic cue kept.
3. The model also enlarges the bust together with the thighs (Miel); the figure descriptors ask for "a full bust" only, so check the 7-head floor and the adult face on petite heroines in every frame.
4. 1 candidate per pilot frame; no OCR or watermark scan; head count not measured on pixels.
5. H1 grew to 5 frames per heroine and H2 to 5 poses per outfit: +340 cr over round 2; the budget numbers need the owner's yes.
