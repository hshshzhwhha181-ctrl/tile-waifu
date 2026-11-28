# Art tier FULL: the visual spec for every heroine image

Status: **owner decision, 2026-11-28.** Yandex Games is dropped, so there is no SFW / dual-build constraint any more. Tier FULL is THE art direction for the RuStore / APK 18+ build and for every heroine batch (H0 to H4). There is no "Standard" or "Neutral" fallback tier in the art packages; if a store ever needs a calmer build it is a separate later pass, not a tier of this spec.

Level: the very top of the 17+ / 18+ suggestive range that Brown Dust 2, Azur Lane and Nikke ship. Style class only; no character, costume, pose or asset is copied from any of them.

Written by P50b. Prompts and wardrobe tables in this document are generated from `tools/art/full_tier_wardrobe.py` and `tools/art/build_art_batches.py`, and the first Full-tier frames are in `design/golden_full/` (see `REPORT.md` there). Nothing here is approved or registered; the owner approves.

## 1. Why the P50 golden composites came out tame (root cause)

The P50 frames (`design/golden/contact_sheet.jpg`) were not a model limit. They were art-directed as the cautious tier:

- `lora-v2/SPEC_V2.md` section 2, "dataset policy for v2 (stricter intersection, so one LoRA serves both builds)": no bikini or swimwear, no bunny costume, no garter or lace-top stocking visible, no navel or torso cut-out windows, no sheer cloth over the torso, slits at or below mid-thigh, legwear = opaque tights or opaque thigh-high socks, no pleated mini skirts, no leg-raised poses in skirts. That policy was written so ONE style LoRA could serve both the Yandex build and the RuStore build.
- `docs/HEROINES.md` section 4 red lines (forbidden: lying down, all fours, arched back, sitting on a table, legs toward the camera, pulling collar or hem; "in prompts write only opaque tights and never stockings") and `docs/LEGWEAR.md` 1.1 (garter belt, lingerie, panties, upskirt never written; band or lace at the thigh only through a slit and not above mid-thigh) were written for the Yandex Games build.
- The P59 batch prompts (`H0_golden_composites.json` and the other H files) inherited all of that and added recipe v4's `form-fitting ... fully opaque fabric, garment stays exactly in place ... no loud bokeh ... matte skin ... no AI gloss`, a muted background and a "calm confident smile, hands lightly together" pose.
- The owner's decisions already allowed more for the RuStore build (HEROINES header, 2026-11-23 two tiers, 2026-11-24 target Mature 17+ / 18+): stockings and thigh-highs with lace tops, garters as part of a costume, bodysuits and swimsuits, deep slits and necklines, open back, mini skirts in an adult context, flirty poses, glance over the shoulder, maid / bartender / idol / evening outfits. P50 never used that room.

So the P50 frames were the Standard tier by construction. Tier FULL removes the Yandex intersection and uses the owner's allowance in full.

## 2. Hard lines (every build, not negotiable)

These did not change. The validator enforces the word-level part (`tools/art/validate_batches.py`, `HARD_BANNED_FULL`).

1. **Every character is clearly adult.** Adult face (mature features, adult makeup, no childlike roundness or large-eye infantilisation), adult proportions of 7 to 7.5 heads, age 20+ in canon and profile (all ten are 23 to 27). "Young face plus revealing outfit" is forbidden.
2. **No nudity.** No visible nipples or areolae, no genitals, no bare buttocks, no anatomical groin outline. Garments and legwear always cover chest, hips and groin and stay in place; the bold part is cut, fabric and pose, not exposure. A plunging neckline, a heart-shaped chest cutout, a keyhole front, an open back and a high slit are allowed only when fabric edges, trim or a closure still cover the nipples and everything below the waist.
3. **No sexual acts, no fluids**, no implied penetration, no sexualised violence, no bondage, no clothing destruction, no undressing as a reward.
4. **No school or minor coding.** No school uniform, seifuku, sailor collar, school skirt (including pleated mini skirts as a school look), classroom, desk, teacher-student, schoolbag, loafers with white knee socks, gingham, childlike props or accessories, and no "student", "teen", "kid", "minor" wording.
5. **No text, letters, numerals, logos or watermark in art.** Mahjong tiles blank or absent. (The owner's UI mock-ups 12 to 15 carry baked text and numerals: they are concept only.)
6. **Camera.** No under-the-skirt angle, no fly-over or body-part scanning, no isolated jiggle as the point of the frame. Tilt up at most 10 degrees on skirts. Eye-level to slightly high is the default.
7. **One character per frame** (no duo frames in this tier), no alcohol in hands (tea, cocktail shakers as props are fine), flirt is directed at the player only.

Vocabulary rule for the generator: fashion and pin-up words only. Never write `sexy`, `cleavage`, `busty`, `thicc`, `lingerie`, `panties`, `upskirt`, `nude`, `naked`, `nipple`, `topless`. Positive constraints only (the model has no negative prompt; the recipe ends with "Garments and legwear cover the chest, hips and groin and stay exactly in place").

## 3. What is IN (Tier FULL)

**Legwear.** Thigh-high stockings with lace tops, wide lace bands and garter straps as part of the costume (clipped to the hem, a ribbon-and-bell band, pearl or crystal garter chains), sheer and glossy tights and pantyhose, fishnet thigh-highs and ripped-window fishnet, striped thigh-highs, over-the-knee socks with a star or stripes, scale-pattern armoured stockings, thigh-high lace-up boots, stilettos, platform heels, heeled geta, barefoot with anklets.

**Cut and neckline.** High slits to the hip, deep plunging V and sweetheart necklines, keyhole and heart-shaped chest cutouts, bare shoulders and off-shoulder, open back, halter, corset bodices, bare midriff, side-open knit dresses, mini skirts (tiered, flared, frilled, holographic) in an adult context, short shorts, leotards and bodysuits, bunny-style leotards with ears and tail, maid dresses, bartender and idol outfits, swimsuits and bikinis with a sheer shirt or sarong, silk robe-dresses with a satin mini dress under them, armour dresses with scale or plate trim, sheer layered sleeves and sheer overlays on legs, arms and skirts (not over chest or groin).

**Fabric and finish.** Body-hugging satin, latex and glossy PVC-style bodysuits, lace gloves and detached lace sleeves, translucent chiffon over opaque lining, wet or sweat glow on skin, flushed cheeks, lacquer-like specular highlights on hair, satin and legwear, warm rim light.

**Poses.** Leaning on furniture or a pillar, perched on a table or armrest, reclining on a daybed, bed or window seat, kneeling (on a cushion, a towel, one knee), squatting in three-quarter view with knees together, arched back, hip tilt, hand on hip, hand in hair, hand at the collar or hem line, over-the-shoulder glance, both arms stretched overhead, leg lifted behind her, crossed legs, sitting on a table edge, lying on her side propped on an elbow, leaning forward toward the viewer, close-ups with flushed and teasing expression.

**Expression.** Teasing half-smile, one-eye wink, tongue-out wink, open-mouth laugh, sly sidelong look, lazy half-lidded look, playful smirk, flirty pout, tea-sipping glance over the rim. Direct gaze at the viewer.

**Camera and framing.** Full-body and three-quarter figures cut at mid-thigh so the thigh band or hem reads; waist-up and close-ups for portraits; eye level; strong diagonal for key art; thigh-up in the lower half of a vertical board screen.

**Look.** Glossy-warm painterly anime gacha key art, saturated warm palettes with a slightly softened supporting background, thin warm-coloured lineart, soft cel shading, detailed environments (lacquer, lanterns, blossoms, glass) at premium mobile-gacha quality. Accent colour of the heroine at most 20% of the frame.

**Out of the old restrictions (now allowed):** stockings and lace tops, garter, bikini and swimwear, bunny suit, navel or torso cut-out windows edged with fabric, sheer overlays, slits above mid-thigh, pleated or flared mini skirts that are clearly adult (not school), raised-knee poses in skirts, lying, arched back, sitting on a table, leaning toward camera, squatting.

## 4. The owner's reference bar (images 4 to 25)

These are the boldness bar. The frames must read at this level, not tamer. They are style and level references only; their composition is not to be copied.

| ref | shows | what it sets |
|---|---|---|
| 4 | MC sitting on the mahjong table in a crimson qipao, thick lace-top stockings, heels; Yue reclining with a moon-fan | seated on a table, high slit, lace-top thigh-highs, reclining on cushions |
| 5 | Kohaku at the shrine festival, arms out, fan, open pose | bare shoulders, thigh-high socks, high slit, confident open pose |
| 6 | Hana and Miel picnic, kneeling | kneeling with thick thigh-high stockings, off-shoulder corset, mini skirt |
| 7 | Tsubame on a roof, sitting with arms raised | arms-up pose, sheer tights, deep neckline, swallow tattoo |
| 8 | Hana at the track, leaning forward and pointing | lean toward camera, tight leggings, sweat glow |
| 9 | Kohaku leaning on a torii pillar, one-eye wink | deep neckline, white thigh-high with a ribbon-and-bell band, slit to the hip, playful lean |
| 10 | Miel baking, leaning over the counter | off-shoulder corset, brown thigh-highs with ribbon bows, heels, mini skirt, tongue-out wink |
| 11 | Nova cyber idol, hip tilt | tight bodysuit and skirt, ripped fishnet-window tights, smirk |
| idol (words) | Nova on a concert stage, square frame, singing and winking, pointing at the camera | strapless corset with neon piping and plunging sweetheart neckline, detached puffed sleeves, layered holographic tiered mini skirt with a big cat-badge bow, fishnet thighs, thigh-high lace-up boots; the Nova idol / win-scene bar |
| Hana (words) | Hana full body on white, wink, waving, hand on hip, leg lifted back | sports crop top with deep neckline, bare midriff, striped short shorts, off-shoulder track jacket, over-the-knee striped socks with a star, sunflower clip, freckles; the Hana bar |
| 12 | MC in a black-and-gold dragon qipao, hand on hip and hand in hair | plunging keyhole front, lace detached sleeves, lace-top thigh-highs, side slit to the hip, stilettos; MC `night` outfit |
| 13 | MC leaning on the mahjong table, holding a tile | white-and-red floral cheongsam, heart-shaped chest cutout with a pink bow, bare shoulders, detached sleeves, white thigh-high with a red ribbon-and-bell band; MC `tea` outfit |
| 14 | MC in the dragon qipao, full body, arm in her hair | same outfit; the plunging front here is the **upper bound** of the cut (see section 2, item 2: fabric edges must still close over the chest) |
| 15 | MC arm thrown up, hand pressing a tile on the felt | leaning forward over the table, laughing |
| 16 | Hana on a beach, kneeling, yellow tie bikini and sheer shirt, wink | swim slot bar (note: her body here is much fuller than canon; the canon body note stays athletic) |
| 17 | MC in a pink-and-white bunny leotard with a heart cutout, sheer pantyhose, heels, casino hall | service (bunny) slot bar |
| 18 | Nova on a rooftop, striped thigh-highs, crop top, holo mini skirt, chunky sneakers, arms-up stretch | seasonal slot bar |
| 19 | green-braid heroine with glasses (Rin), black bunny tailcoat and pantyhose serving tea | Rin service slot bar |
| 20 | Yue in dragon-scale armour, scale thigh-highs, moon glaive | battle slot bar |
| 21 | Rin in a library, off-shoulder cable-knit mini dress with an open side, lace-top black thigh-highs, stilettos, sipping tea, leaning on a bookshelf | Rin evening slot; lean-on-furniture and tea-sipping glance poses |
| 22 | Yue reclining at a moonlit window in a sheer lavender robe-dress, lace thigh-highs, moon fan | Yue evening / robe; recline-at-window pose |
| 23 | Nova squatting in a glossy latex bodysuit with a zipper neckline, holo jacket, platform lace-up boots, claw gesture, wink | squat pose. **Edge case:** the reference has the knees apart toward the camera; in this tier a squat is drawn in three-quarter view with the knees together or the near knee forward |
| 24 | MC close-up in the dragon qipao, lace gloves, hand on hip | close-up pose; keyhole front with a bare-midriff window: upper bound |
| 25 | Nova kneeling with arms stretched overhead, crop top with navel piercing, holo mini skirt, striped thigh-highs, chunky sneakers | kneel-with-stretch pose |

Images 1 to 3 in the owner's folder are chat screenshots, not art references.

Reference images as model input: Higgsfield `gpt_image_2_6` accepts them (`medias` role `image_references`, up to 16). P50b tested one (ref 24 on the MC summon frame): it works, and it pulls the result strongly toward the reference's exact cut, including the open navel keyhole of that reference, so a reference is a lever for boldness but also a risk for the hard line in section 2 item 2. Default recipe: prompt only, identity from the Element; use a reference only for a deliberate boldness push and look at the chest closure.

## 5. Rule changes versus SPEC_V2 section 2 and HEROINES section 4

| rule | SPEC_V2 section 2 / HEROINES section 4 (Yandex intersection) | Tier FULL |
|---|---|---|
| stockings, thigh-highs | opaque tights or opaque thigh-high socks only; "never write stockings" | thigh-high stockings, lace tops, wide bands, fishnet, striped, scale-pattern, all allowed |
| garter | never written; only as a dress part and not visible above mid-thigh | garter straps, ribbon-and-bell bands, pearl / crystal garter chains as costume parts, visible |
| swimwear, bikini | none | allowed (swim slot for every heroine) |
| bunny, maid, bartender, idol | bunny banned; maid / idol only closed | bunny leotards, maid dresses, bartender and idol outfits allowed (service slot) |
| slits | at or below mid-thigh | up to the hip |
| necklines | keyhole small, no cut-out windows | deep plunging V, heart / keyhole cutouts, bare midriff, open back; fabric still covers nipples and below the waist |
| sheer fabric | none over the torso; opaque garments | sheer sleeves, overlays and robes allowed; chest and groin stay lined and covered |
| mini skirts | pleated minis excluded (school code) | tiered, flared, frilled, holographic minis allowed; pleated school-looking skirts stay banned (hard line 4) |
| poses | no lying, all fours, arched back, legs toward camera, sitting on a table, pulling collar or hem, raised knee in a skirt | lying on the side, reclining, kneeling, arched back, sitting on a table or armrest, hand at collar or hem line, raised leg, squat (knees together), leaning toward camera allowed; all-fours and legs-apart-toward-camera stay out |
| over-the-shoulder look | at most one per heroine | allowed in any frame |
| body wording | no bust or hip size words; "moderate natural bust" | "shapely ... a full natural bust in proportion", "rounded hips", "soft thighs"; still no `busty`, `thicc` |
| camera | not below waist, tilt up at most 10 degrees | unchanged (hard line 6) |
| expression | calm, confident | teasing, winking, tongue-out, flushed, lazy half-lidded |
| finish | `matte skin`, `no AI gloss`, muted desaturated background | lacquer-like highlights, warm rim light, wet or sweat glow; background slightly softened, not muted |
| prompt tail | v4c (`form-fitting ... fully opaque`) | v5f (`adult fashion pin-up styling ... Garments and legwear cover the chest, hips and groin`) |
| banned-word list | garter, stockings, bikini, bunny, curvy, hourglass, wide hips, full thighs, full bust, lingerie, panties, upskirt, cleavage, sexy ... | costume words (garter, stockings, bikini, bunny, curvy, hourglass, wide hips, full thighs, full bust) allowed in Tier FULL files only; hard bans and vocabulary tripwires stay (validator) |
| dataset policy | stricter intersection for one LoRA | no intersection; heroines are generated with Elements, not a LoRA (unchanged), and a later style LoRA may learn Full images |
| tiers | Standard (Yandex) and Mature | one tier: Full |

`docs/HEROINES.md` section 4, `docs/LEGWEAR.md` 1.1 and `SPEC_V2.md` section 2 should be marked superseded by this document for art (not edited by P50b).

## 6. Prompt recipe (tested)

Tail `v5f` (in `build_art_batches.py`, `FULL_TAIL`): glossy-warm painterly anime gacha key art, adult fashion pin-up styling, adult woman 7.25 heads tall, long legs, shapely athletic-soft figure with a defined waist, direct teasing gaze, lacquer-like highlights on hair, satin and sheer legwear, warm rim light, saturated colours with a slightly softened background, "Garments and legwear cover the chest, hips and groin and stay exactly in place", adult mature face, one single character, no text, no letters or numerals, no logos, no watermark.

Order of a prompt: `<<<element id>>> is <name>, an adult woman of <age>, <role>. Hair / Eyes / Skin / Face / Signature items / Body. Outfit: ... Pose: ... Expression: ... Framing: ... Setting: ... accent-colour line, tail`. Identity comes from the Element; do not also pass the Element in `medias`.

Tested with `gpt_image_2_6` (1k medium, 9:16 or 2:3): the generator did not refuse or soften any of: thigh-high stockings with lace tops and garter straps, plunging keyhole and heart-cutout cheongsam, bikini with sheer shirt, bunny leotard with pantyhose, silk robe-dress with a mini dress under it, fishnet thigh-highs, latex-look bodysuit, reclining and leaning and kneeling poses, wink and tongue-out wink. 0 moderation refusals in 51 images. Fashion vocabulary was enough; the cut still reads clearly bold.

Learned: a "Skin: ... not tanned" clause fixes Nova's skin drift from P50; "thigh-up in the lower 55%" works for the board screen but the model fills the empty upper field with background decor on some seeds; a very bold cut can drift above the cut the prompt asks for when a reference image is attached.

## 7. Look gate for Full frames

A frame passes when all hold:

1. Boldness: stockings or thigh-high legwear with a band or lace top (or the slot's equivalent: swimwear, bunny, robe), a deep neckline or bare shoulders, and a playful pose from section 3. A frame that could appear in the P50 contact sheet fails.
2. Hard lines (section 2): adult face and about 7 to 7.5 heads, covered chest and groin, no text, no school coding.
3. Identity: face, hair and signature items match the canon card and the Element (at least 4 of 5 face traits; `hair_never` rules).
4. Anatomy: hands five fingers and no fusions, legs and feet coherent, crossed legs unambiguous, boots and heels with correct count.
5. Accent colour of the heroine at most 20% of the frame (strict mask in `tools/art/golden_gate.py`); gold only as an accent.
6. No text, logo or watermark glyphs anywhere; tiles blank.
7. Metadata scrubbed (`tools/art/scrub_metadata.py`).

## 8. Per-heroine signature bold costume (all 10)

The signature is the `base` slot; the full 7-slot table is in section 10.

| heroine | signature Full costume |
|---|---|
| MC | night: black-and-gold dragon qipao, plunging keyhole front, lace detached sleeves, lace-top thigh-highs, hip slit, stilettos; tea: white-and-red floral cheongsam, heart cutout with a pink bow, white thigh-high with a red ribbon-and-bell band |
| Rin | black phoenix cheongsam with plunging neckline and open back, hip slit, lace-top stockings with garter straps clipped to the hem, gold glasses and jade bangle kept |
| Hana | orange-striped sports crop top, deep neckline, bare midriff, striped short shorts, off-shoulder pink track jacket, over-the-knee striped socks with a star, sunflower clip, freckles |
| Yue | lavender hanfu gown, off-shoulder, plunging V, sheer layered sleeves, hip slit, white lace-top thigh-highs with pearl garter straps, horns and crescent ornament kept |
| Nova | strapless neon-piped corset bodice, sweetheart neckline, detached puffed sleeves, holographic tiered mini skirt with a cat-badge bow, fishnet thigh-highs with a garter strap, thigh-high lace-up platform boots |
| Tsubame | short indigo wrap kimono dress with plunging neckline and open sides, fishnet thigh-highs with crimson ribbon bands, tabi boots, fishnet arm guards, crimson scarf |
| Miel | off-shoulder puff-sleeve blouse with plunging ruffled neckline, rose corset, frilled apron mini skirt, brown thigh-highs with ribbon bow bands, bow heels |
| Kohaku | white shrine-maiden top with deep plunging neckline and bare shoulders, vermilion hakama with a side slit to the hip, white thigh-highs with a red ribbon-and-bell band, geta |
| Shirin | teal-gold choli with plunging neckline and sheer sleeves, bare midriff, low-slung plum skirt slit to the hip, coin belt, sheer gold thigh chains, anklets, barefoot |
| Zlata | scarlet corset sarafan, plunging sweetheart neckline, bare shoulders, feather wing-sleeves, short front-slit skirt over red lace-top thigh-highs with gold garter straps, embroidered heeled boots |

Seasonal and alt outfits per heroine (swimwear, bunny, maid, robe, battle, idol, winter, summer, new-year) are slots 3 to 7 of section 10; the owner's references 16 to 20 (beach bikini, bunny leotard, rooftop sneakers, bunny tailcoat, dragon-scale armour) are their bar.

## 9. Dataset images: which drops are fine for Tier FULL

There are two different drop lists.

**`lora-v2/drop_list_v2.txt` (53 files, "review-flagged" and removed from the v2 dataset on the box).** The file records no per-image reason (`dataset_v2_review.json` has only the counts), and the images are in `lora-v2/review/dropped/`. I looked at all 48 heroine files and the 5 environments. They are clothed, adult, and none breaks a hard line, so under Tier FULL **all 53 are acceptable** as identity and anatomy anchors. They are low value as boldness examples (most are covered, athletic or closed outfits: that is why they were never the problem; they were likely removed by the stricter review). Recommended use if a style LoRA is retrained:

- Re-admit as identity anchors (canon full-body and face anchors): `a_cute_mc`, `a_cute_yue`, `a_w1final_kohaku`, `a_w1final_miel`, `a_w1final_tsubame`, `a_w1final_zlata`, the 6 Tsubame files, the 5 Zlata files, the 3 Shirin files, the 5 Kohaku files, `g2_miel_gala`, `g_miel_parlor`, the Hana set (7), the Rin set (6), the 5 `g2_nova_base_*`, `g_nova_ssr`, `g_nova_offline`.
- Re-admit only after a crop: `g2_nova_base_select`, `g_nova_diva`, `g_nova_root`, `g2_yue_duel` carry a rounded card / UI frame in the image.
- Weak but harmless: `a_combo_*_x20`, `a_combo_*_x5` (slim figures on dark ground, tame).
- Environments `env_038`, `env_045`, `env_046`, `env_047`, `env_069`: fine, apply the stated grade.

**The v1 images dropped in `SPEC_V2.md` section 6 (58 heroine files, `v1_keep_drop.tsv`).** These are the ones the strict policy actually removed for boldness. Under Tier FULL:

- R1 (outfit, pose or camera red line): 24 files. 21 are fine (bikini, bunny, cut-out gown, plunging robe, stocking tops, latex crouch with the knees closed, reclined pose, raised leg): `a_L2a_hana_festival` (rear camera: re-shoot instead), `a_L2a_mc_gown`, `a_L2a_mc_maid`, `a_L2a_mc_racing`, `a_L2a_nova_catsuit` (legs apart: crop or skip), `a_L2a_rin_officer`, `a_L2a_yue_dragon`, `a_L2a_yue_terrace`, `a_L2b_hana_bikini`, `a_L2b_mc_beach`, `a_L2b_rin_bunny`, `a_L2b_rin_swim`, `a_L2b_yue_armor`, `a_L2b_yue_robe`, `a_fix_mc_bunny`, `a_fix_rin_qipao_a`, `a_r4_yue`, `g_hana_beach`, `g_kohaku_matsuri`, `g_rin_idol`, `g_shirin_night`. **3 stay dropped for school coding:** `a_L2b_hana_cheer` (pleated cheer skirt), `g_hana_winter` (pleated navy skirt), `a_fix_nova_rooftop` (striped thigh-highs with a pleated mini).
- R2 (exaggerated bust or hips): 28 files are fine as far as the rule goes (body wording is no longer a hard line). Check each for the 7 to 7.5 head rule; several draw the bust very large and the proportions childlike-short, those are rejected on proportions, not on size: `a_combo_*_x5/x10`, `a_r4_*`, `a_redraw_*`, `g2_*_base_idle/tease`, `g_*_base_select/win`.
- R3 (pink or lavender wash): 4 files (`g2_yue_base_idle`, `g_mc_base_lose`, `g_yue_base_select`, `g_yue_base_shy`): stay dropped unless re-graded, the problem is colour, not boldness.
- R4 (`g_nova_base_lose`, anatomy risk) and R5 (`g_rin_jade`, glasses removed): stay dropped.

Net: of the 58 v1-dropped heroine images, 49 are Full-compatible (21 R1 + 28 R2), 4 only after a colour re-grade, 5 stay out (3 school-coded, 1 anatomy, 1 signature).

## 10. Wardrobe tables (10 heroines x 7 outfits x 3 poses)

Source of truth: `tools/art/full_tier_wardrobe.py` (feeds batch H2 `design/art_batches/H2_wardrobe.json`, and the base slot feeds H0, H1, H3, H4). Identity items of the heroine (hair, horns, ears, glasses, headphones, signature accessories) are kept in every outfit by the prompt's identity block. MC's two canonical Full outfits are her `base` (night dragon qipao) and `evening` (tea floral cheongsam) slots, from the owner's mock-ups 12-15.

### Mahjong-chan (MC)

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Night dragon qipao | black-and-gold long qipao with gold dragon embroidery, a plunging keyhole front with a gold frog-button collar, bare shoulders, black lace detached arm sleeves, a side slit up to the hip, sheer black thigh-high stockings with wide lace tops, black stiletto heels | **A** standing with her weight on one leg, one hand on her hip and the other raised into her hair, the stocking top visible through the slit / **B** perched on the edge of the mahjong table with her legs crossed, looking back at the viewer over her shoulder / **C** leaning back against a lacquer pillar with an arched back, one knee bent, one hand touching her collar |
| evening | Tea floral cheongsam | white-and-red floral cheongsam with gold trim, a heart-shaped chest cutout under a pink bow, bare shoulders, white detached wide sleeves with red knotted ribbons, a red sash with a flower brooch, a side slit up to the hip, white thigh-high stockings with a red ribbon-and-bell garter band, red high heels | **A** leaning over the mahjong table on one hand, holding up a single blank tile in the other hand, a wink / **B** reclining sideways on a cushioned daybed propped on one elbow, one knee raised, holding a tea bowl / **C** kneeling on a cushion pouring tea, glancing up at the viewer |
| swim | Blossom bikini | pink-and-white halter bikini with jade-green ribbon ties at the hips, an open white sheer shirt tied at the waist, a gold anklet, a straw sun hat with a pink ribbon | **A** kneeling on the towel with both fists under her chin, leaning toward the viewer, a wink / **B** standing in shallow water with both arms stretched above her head, a hip tilted / **C** sitting on the towel leaning back on both hands, one knee raised, hair blowing in the breeze |
| service (bunny / maid / bartender) | Casino bunny leotard | white-and-pink floral cheongsam-style bunny leotard with gold trim and a heart-shaped chest cutout, a pink bow collar, white bunny-ear headband with a fluffy tail, white wrist cuffs, sheer pale pantyhose, white stiletto heels | **A** standing with one hand on her hip and a fan of blank mahjong tiles held beside her face, winking / **B** leaning forward on a felt table with both forearms on it, one leg lifted behind her / **C** standing in profile with an arched back and a hip tilted, glancing back over her shoulder |
| robe (sleepwear robe-dress) | Moonlit silk robe-dress | blush-pink silk robe-dress with a plunging neckline tied by a satin sash over a satin mini dress, white lace-top thigh-high stockings, pink satin mules, the jade hairpins and cuffs kept | **A** reclining on a silk bed propped on one elbow, one leg bent, the robe falling off one shoulder / **B** sitting at a vanity mirror looking back over her shoulder, a hand brushing her hair / **C** standing at a moonlit window with one hand holding the robe edge, arched back |
| battle / idol | Jade war-qipao | jade-green lamellar-armour cheongsam with gold shoulder plates, a plunging keyhole front, a short armoured skirt, scale-pattern thigh-high stockings, gold greaves, a large folding war fan with a tile pattern | **A** lunging forward with the war fan opened toward the viewer, hair flying / **B** kneeling on one knee with the fan planted like a standard, looking up at the viewer / **C** standing in a wide stance with the fan over one shoulder, a hand on her hip |
| seasonal | Winter festival mini-qipao | red velvet mini-cheongsam with white fur trim and gold knots, bare shoulders, white fur cuffs, white thigh-high stockings with red bows, red heeled boots, a fur-trimmed cape | **A** twirling with the cape flaring, one hand holding a lantern / **B** leaning against a lantern post with one knee bent, blowing a kiss / **C** sitting on a snowy bench with legs crossed, holding a steaming cup |

### Rin

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Phoenix cheongsam | sleeveless black cheongsam with gold-green phoenix embroidery, a deep plunging neckline, an open back, a skirt slit up to the hip, sheer black thigh-high stockings with lace tops and garter straps clipped to the hem, black stiletto heels, a jade bangle | **A** leaning against a bookshelf with one knee bent, sipping tea from a celadon cup, glancing at the viewer / **B** one hand adjusting her glasses, the other on her hip, hip tilted / **C** standing on the rolling ladder reaching for a book, looking back over her shoulder |
| evening | Knit tea dress | off-shoulder cable-knit mini sweater dress in forest green with an open side, lace-top black thigh-high stockings, black stiletto heels, a jade bangle | **A** leaning on a shelf with one leg lifted behind her, sipping tea / **B** sitting sideways on a window seat with legs crossed, a book on her knee / **C** reclining on a chaise with her braid over one shoulder, holding the cup |
| swim | Jade swimsuit | dark-green one-piece swimsuit with a deep plunging neckline and side cut-outs bordered in gold trim, a sheer green wrap skirt, gold sandals, the thin gold glasses kept | **A** sitting on the pool edge with her feet in the water, leaning back on one hand / **B** standing waist-deep in the pool wringing her braid, glancing over her shoulder / **C** lying on her side on a bamboo lounger propped on one elbow, a tea cup beside her |
| service (bunny / maid / bartender) | Bunny tea-server tailcoat | black bunny-style tailcoat leotard with gold-trimmed lapels, a deep plunging neckline, a green bow tie, black bunny-ear headband with a white tail, white gloves, sheer black pantyhose, black heels, a silver teapot | **A** bending slightly forward presenting a silver teapot on one hand, tilting her head / **B** standing with the teapot on a tray and a hand on her hip, a hip tilted / **C** sitting on the arm of a velvet sofa with crossed legs, pouring tea |
| robe (sleepwear robe-dress) | Jade silk robe | emerald silk robe-dress with a plunging neckline and a satin sash over a green satin mini dress, black lace-top thigh-high stockings, jade earrings, the thin gold glasses kept | **A** sitting on a low sofa with one leg crossed over the other, the robe slipping from one shoulder, holding a cup / **B** standing at a bookshelf with her back arched, looking over her shoulder / **C** reclining on a daybed with a book on her chest, one knee raised |
| battle / idol | Tea-master combat dress | black fitted high-slit combat cheongsam with green piping, shoulder plates and bracers, a plunging neckline, scale-pattern thigh-high stockings, black boots, a kunai-shaped tea whisk at her belt | **A** crouching on the ridge with one hand on the tiles, glancing sideways / **B** standing with one hand on her hip and the other holding a tea bowl, a hip tilted / **C** leaning back on a chimney with one leg bent, tying her braid |
| seasonal | Spring festival yukata | short sage-green yukata with cherry-blossom print, an off-shoulder neckline, a wide obi with a jade charm, a slit to the hip, white thigh-high socks with green ribbon bands, wooden geta | **A** holding a paper fan against her lips, a hip tilted / **B** sitting on a stone lantern base with legs crossed, a sweet dumpling stick in hand / **C** looking back over her shoulder under blossom branches |

### Hana

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Pin-up track set | orange-striped sports crop top with a deep neckline and bare midriff, short orange-striped running shorts, an off-shoulder pink track jacket sliding down one shoulder, white over-the-knee striped socks with a small star, white-orange sneakers, sport wristband | **A** leaning forward with hands on her knees, pointing at the viewer, a wink / **B** standing on one leg with the other lifted behind her, waving, a hand on her hip / **C** kneeling with arms stretched high above her head, back arched |
| evening | Gala backless dress | orange satin mini dress with a deep plunging neckline and an open back, a high slit, sunflower-yellow ribbon straps, sheer tan thigh-high stockings, white-orange heeled sandals, a sport wristband kept | **A** one hand on her hip, the other pushing back her hair, a hip tilted / **B** sitting on a balustrade with legs crossed, laughing, looking at the viewer / **C** looking back over her bare shoulder with an arched back |
| swim | Sunflower bikini | yellow tie-side bikini with an off-shoulder sheer white shirt tied at the waist, a wide straw sun hat with a yellow ribbon, a sport wristband | **A** kneeling on the towel with both fists under her chin, a wink / **B** squatting in the sand scooping a seashell, glancing up at the viewer, knees together / **C** lying on her side on the towel propped on one elbow, one knee bent |
| service (bunny / maid / bartender) | Bartender bunny | orange bunny-style leotard with white stripe trim, a black bow tie collar, white cuffs, a bunny-ear headband, sheer tan pantyhose, white platform sneakers, a shaker held as a prop | **A** leaning over the counter on both elbows, a wink / **B** shaking a cocktail shaker above her shoulder, hip tilted / **C** sitting on a bar stool with her legs crossed, a hand under her chin |
| robe (sleepwear robe-dress) | Locker-room satin robe | short orange satin robe with white piping tied loosely at the waist over a sports bodysuit, sheer tan thigh-high stockings, fluffy slippers | **A** sitting on a bench with one leg stretched out, towel around her neck, leaning back / **B** stretching with both arms overhead, the robe slipping off one shoulder / **C** kneeling on the bench looking back over her shoulder |
| battle / idol | Relay racer | tight orange-and-white racing bodysuit with a zip neckline pulled low and cut-out sides covered by mesh, thigh-high compression socks, spiked track shoes, a flowing relay baton ribbon | **A** sprinting start crouch with one hand on the track and a glance at the viewer / **B** standing with one hand on her hip holding up a baton, a hip tilted / **C** leaning against a hurdle with legs crossed, wiping her forehead |
| seasonal | Winter-rink set | short orange puffer jacket worn off one shoulder over a white crop sweater, a flared white skater mini skirt, white thigh-high stockings with orange stripes, white ice skates, a knitted headband | **A** spinning on one skate with one leg lifted behind her, arms out / **B** kneeling to tie a skate, looking up at the viewer / **C** leaning back on the rink barrier with legs crossed |

### Yue

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Moon-queen hanfu | lavender silk hanfu-style gown, off-the-shoulder with a deep plunging V front, sheer layered sleeves, gold moon-and-star embroidery, sash-cinched waist, skirt slit up to the hip, white lace-top thigh-high stockings with pearl garter straps, lavender high heels | **A** reclining on a moon-cushion divan with one leg crossed over the other, an arm extended offering a blank jade tile / **B** seated sideways on a throne armrest with legs crossed, the moon-phase fan against her lips / **C** standing in an S-curve with one hip tilted, one hand held out, the fan on her hip |
| evening | Sheer window robe-gown | sheer layered lavender robe-dress with a deep plunging neckline and a crescent sash over a lavender satin mini dress, lace-top thigh-high stockings with crystal garter charms, silver heels | **A** reclining against the window frame with one arm along the sill, the fan held by her cheek / **B** standing at the window with one hand drawing the curtain, arched back / **C** sitting on the sill with one knee raised, looking back at the moon |
| swim | Moon-lagoon swimsuit | lavender halter bikini with gold crescent rings and chain details, a sheer lavender sarong slit to the hip, gold anklets, a crescent forehead ornament kept | **A** sitting on the terrace edge with her feet in the water, leaning back on both hands / **B** standing waist-deep in the water gathering her long hair over one shoulder / **C** lying on a floating cushion on her side, the fan trailing in the water |
| service (bunny / maid / bartender) | Moon bunny | lavender bunny-style leotard with gold moon embroidery and a deep plunging neckline, long lavender bunny ears over her horns, a crescent bow tie, sheer white pantyhose, lavender stiletto heels, white cuffs | **A** standing with a tray of blank jade tiles on one hand, a hip tilted / **B** leaning forward on a table with both forearms on it, one leg lifted behind her / **C** sitting on a table edge with legs crossed, the fan at her lips |
| robe (sleepwear robe-dress) | Pearl silk robe | pearl-white silk robe-dress with a plunging neckline and a crescent sash, lavender satin mini dress under it, lace-top thigh-high stockings, a gold crescent forehead ornament kept | **A** reclining on the bed propped on one elbow, one leg bent, the robe slipping from a shoulder / **B** kneeling on the bed with a hand in her hair, looking at the viewer / **C** sitting on the bed edge with legs crossed, a fan covering half her smile |
| battle / idol | Dragon-scale armour | purple dragon-scale armour dress with gold filigree plates, a plunging keyhole front with a gem pendant, a short layered armoured skirt, scale thigh-high stockings with crescent gold garter bands, scale gloves, a moon glaive | **A** standing in a wide stance holding the moon glaive across her body / **B** lunging with the glaive swept back, hair flying / **C** kneeling on one knee with the glaive planted, looking up |
| seasonal | Moon-festival gown | short white-and-lavender festival hanfu with a deep neckline, a rabbit-motif sash, off-shoulder sheer sleeves, white thigh-high stockings with lavender ribbons, silver heels, a lantern held in one hand | **A** holding up a glowing lantern, looking back over her shoulder / **B** sitting on a stone bench with legs crossed, a mooncake in her fingers / **C** leaning against a lantern pole with one knee bent |

### Nova

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Neon idol corset set | strapless black corset bodice with neon cyan piping and a plunging sweetheart neckline, detached puffed black sleeves with neon trim, layered holographic tiered mini skirt with a big pink cat-badge bow at the hip, black fishnet thigh-highs with a neon cyan garter strap, black thigh-high lace-up platform boots with cyan laces | **A** singing into a microphone, pointing at the viewer, one leg stepped forward, a wink / **B** perched on a server rack with her boots crossed, tapping her headphones / **C** leaning forward with a hip tilt, a glowing hologram card between two fingers |
| evening | Latex catsuit | glossy black latex bodysuit with a zipper neckline pulled low and neon cyan piping, a holographic cropped jacket with a hood and cat ears, black thigh-high lace-up platform boots with cyan laces, a ring choker | **A** squatting in a three-quarter view with knees together, one hand on her knee and a claw gesture, a wink / **B** standing with her back arched and a hip tilted, the jacket slipping off one shoulder / **C** sitting sideways on a console with one boot raised on the edge |
| swim | Neon bikini | black-and-neon-cyan strappy bikini with a pink cat-badge clasp, an open holographic mesh hoodie, black thigh-high sandals with cyan straps, cat-ear headphones kept | **A** sitting on the pool edge with one leg bent, leaning back on both hands / **B** lying on her side on a glowing lounger propped on one elbow / **C** standing with arms stretched overhead in a stretch, a wink |
| service (bunny / maid / bartender) | Cyber maid | short black-and-pink cyber maid dress with a deep plunging neckline, a frilled holographic apron with a cat-badge bow, detached sleeves, black fishnet thigh-highs with a cyan garter strap, black platform heels, a headband over her cat ears | **A** holding a tray with one hand and a finger at her lips, a hip tilted / **B** leaning over a table toward the viewer with a hand on her hip / **C** sitting on a counter with legs crossed, tapping her headphones |
| robe (sleepwear robe-dress) | Hologram robe | translucent iridescent robe-dress over a black satin mini dress with a plunging neckline, a neon cyan sash, black lace-top thigh-high stockings, fluffy cat-ear slippers | **A** reclining on a beanbag with a laptop on her knees, one leg raised / **B** kneeling on a chair back looking over her shoulder at the screens / **C** standing at the window with her back arched, hugging a cup |
| battle / idol | Street-racer suit | tight black-and-cyan racing bodysuit with a zipper neckline pulled low, thigh-high armoured boots, a cropped racing jacket with neon piping, a visor pushed up on her forehead, race gloves | **A** leaning back against the bike with one knee bent, holding a helmet at her hip / **B** squatting by the bike tightening a strap, knees together, glancing sideways / **C** standing with a hip tilt and a thumbs-up, a wink |
| seasonal | Rooftop sneaker set | black crop top with a deep neckline, neon cyan piping and a navel stud, an iridescent holographic mini skirt, black-and-cyan striped thigh-high socks, chunky white-and-pink platform sneakers, an off-shoulder cropped jacket | **A** kneeling with both arms stretched high above her head, a wink / **B** standing with legs crossed at the ankle and arms overhead, back arched / **C** sitting on the parapet with one leg swinging, looking back |

### Tsubame

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Rooftop kunoichi | short indigo wrap kimono-style dress with a deep plunging neckline and open sides, a wide obi with crimson rope, fishnet thigh-high stockings with crimson ribbon thigh bands, black split-toe tabi boots, fishnet arm guards, a long crimson scarf | **A** sitting on the roof ridge with knees together, both arms raised tying her ponytail / **B** crouching on the ridge with one hand on the tiles, looking back over her shoulder / **C** leaning on a chimney with one leg bent, holding a sealed letter |
| evening | Crimson slit dress | black-and-crimson satin evening dress with a deep plunging neckline, an open back and a slit to the hip, sheer black lace-top thigh-high stockings with a crimson garter, black stiletto heels, the crimson scarf worn as a stole | **A** standing with one hand on the railing and her back arched, glancing over her shoulder / **B** sitting on the railing with legs crossed, the scarf trailing / **C** leaning against a pillar with a hand on her hip, a hip tilted |
| swim | Swallow swimsuit | indigo-and-crimson high-cut one-piece swimsuit with a deep plunging neckline and obi-style waist wrap, a sheer crimson sarong, fishnet arm guards, a swallow anklet | **A** sitting on a rock with her feet in the water, leaning back on one hand / **B** standing waist-deep wringing her long ponytail, glancing sideways / **C** lying on her side on a flat rock propped on one elbow |
| service (bunny / maid / bartender) | Courier bunny | black bunny-style leotard with a crimson obi sash and a messenger pouch, a deep plunging neckline, black bunny ears with a swallow pin, sheer black pantyhose, split-toe boots, white cuffs | **A** standing with a parcel on one hip and a hand on the other, a hip tilted / **B** leaning on a crate with one leg lifted behind her / **C** sitting on a parcel stack with legs crossed, tapping the sealed letter on her lips |
| robe (sleepwear robe-dress) | Night kimono robe | loose dark-indigo silk robe-dress with a plunging neckline tied by a crimson obi over a satin mini dress, fishnet thigh-highs with ribbon bands, the swallow hairpin kept | **A** reclining on tatami propped on one elbow, one knee raised / **B** kneeling at a low table pouring sake-free tea, glancing up / **C** standing at a sliding door with her back arched, looking back |
| battle / idol | Shadow courier armour | black fitted shinobi bodysuit with a deep plunging mesh neckline, crimson armoured shoulder guards, a short split skirt, fishnet thigh-high stockings, tabi boots with crimson ties, a kunai belt | **A** crouching on one knee on the ridge with a kunai between her fingers / **B** leaping between roofs with the scarf streaming / **C** standing in a wide stance with arms crossed, the scarf blowing |
| seasonal | Summer festival yukata | short crimson yukata with swallow print, an off-shoulder neckline, a black obi with a bell, a slit to the hip, black thigh-high socks with red ribbon bands, wooden geta | **A** holding a goldfish bag and a hand fan, a hip tilted / **B** sitting on a stone step with legs crossed, a candy apple in hand / **C** looking back over her shoulder at fireworks, arched back |

### Miel

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Patisserie corset set | cream off-shoulder puff-sleeve blouse with a plunging ruffled neckline, a fitted rose corset, a short frilled apron mini skirt with ribbons, brown thigh-high stockings with ribbon bow bands, rose high heels with bows | **A** leaning over the counter on one arm, holding out a spoon of cream toward the viewer, a wink / **B** standing with a whisk raised and a hip tilted, a dab of cream on her cheek / **C** sitting on the counter edge with legs crossed, holding a macaron to her lips |
| evening | Dessert-gala dress | rose-pink satin off-shoulder mini ball dress with a deep sweetheart neckline, a corset bodice with ribbons, a frilled tulle skirt, cream lace-top thigh-high stockings with bow bands, cream heels | **A** holding a strawberry tart toward the viewer, leaning forward, a hip tilted / **B** sitting on a banquet table edge with legs crossed, licking cream from a finger / **C** looking back over her shoulder with an arched back |
| swim | Strawberry bikini | pink strawberry-print bikini with cream ribbon ties and a sheer white frilled shirt tied at the waist, a straw hat with a white bow, a pearl anklet | **A** kneeling on the towel with a hand held up holding a strawberry, a wink / **B** lying on her stomach propped on both elbows, legs lifted and crossed behind her / **C** standing in shallow water holding her hat on, a hip tilted |
| service (bunny / maid / bartender) | Cafe maid | short caramel-and-cream maid dress with a deep plunging neckline, a frilled apron, puff sleeves, a lace headband with her bow kept, cream thigh-high stockings with lace tops and ribbon bands, rose heels | **A** balancing a tray of macarons on one hand, a hip tilted, a wink / **B** leaning over a table toward the viewer, resting on both hands / **C** sitting on a stool with legs crossed, hugging the tray |
| robe (sleepwear robe-dress) | Honey satin robe | honey-gold satin robe-dress with a plunging neckline and a cream sash over a cream satin mini dress, lace-top thigh-high stockings with ribbons, fluffy slippers, the macaron hair clip kept | **A** reclining on a cushioned window seat propped on one elbow, one knee raised, a cup in hand / **B** stretching with arms overhead, an arched back, the robe slipping from a shoulder / **C** kneeling on the bed looking back over her shoulder |
| battle / idol | Confection-knight | rose-and-cream armoured corset dress with whisk-shaped pauldrons and a plunging neckline, a short skirt with sugar-lace trim, thigh-high armoured stockings with bows, heeled boots, a giant piping-bag lance | **A** lunging forward with the piping-bag lance pointed at the viewer / **B** standing with the lance on her shoulder and a hand on her hip / **C** kneeling on one knee with the lance planted |
| seasonal | Winter bakery | red-and-cream velvet mini dress with white fur trim, a bare-shoulder neckline, a frilled apron, a Christmas-style fur-trimmed cape, white thigh-high stockings with red bows, red heels | **A** holding a gingerbread tray, leaning toward the viewer, a wink / **B** sitting on a flour sack with legs crossed, a candy cane at her lips / **C** twirling with the cape flaring |

### Kohaku

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Shrine-maiden festival | white shrine-maiden top with a deep plunging neckline, detached wide sleeves and bare shoulders, a vermilion hakama skirt with a side slit to the hip, white thigh-high stockings with a red ribbon-and-bell thigh band, red-thonged geta | **A** leaning on a red torii pillar with one knee bent, a one-eye wink / **B** standing with a folding fan raised in one hand and the other arm out, a hip tilted / **C** sitting on a stone step with legs crossed, tail curled around her |
| evening | Fox-lantern kimono dress | vermilion-and-gold short kimono dress with an off-shoulder plunging neckline, a wide obi with a bell charm, a slit to the hip, sheer white lace-top thigh-high stockings with a red ribbon band, red heeled geta | **A** holding a floating fire-lantern in cupped hands, looking up with a smile / **B** looking back over her shoulder with her tail swept forward, arched back / **C** kneeling on a tatami platform with a hand on her thigh band |
| swim | Shrine-spring bikini | white-and-vermilion halter bikini with red ribbon ties and a gold bell at the neck, a sheer white sarong with a red edge, white thigh bands with bells, the fox mask at the side of her head | **A** sitting on a rock with her feet in the water, her tail resting beside her / **B** standing waist-deep with her tail raised out of the water, glancing back / **C** lying on her side on a wooden deck propped on one elbow |
| service (bunny / maid / bartender) | Fox bunny-maid | white-and-red bunny-style leotard with a deep plunging neckline and a gold bell collar, white fox ears kept, a red bow, white cuffs, sheer white pantyhose, red heels, a tray with blank tea cups | **A** carrying a tray with one hand and a hip tilted, a wink / **B** leaning over a low table toward the viewer / **C** sitting on the table edge with legs crossed |
| robe (sleepwear robe-dress) | White silk robe | white silk robe-dress with red trim and a plunging neckline, tied by a red sash over a white satin mini dress, white lace-top thigh-high stockings with red ribbon bands, a gold bell collar | **A** reclining on tatami propped on one elbow with her tail wrapped around her legs / **B** kneeling with the robe slipping from a shoulder, looking back / **C** standing at an open sliding door with arched back, hugging her tail |
| battle / idol | Nine-tail warrior | white-and-red armoured miko dress with gold plates, a plunging neckline, a short split hakama, white thigh-high stockings with red lacquer greaves, nine fox tails fanned behind her, a gohei wand | **A** lunging with the gohei raised, tails fanned out / **B** standing in a wide stance with the gohei across her shoulders / **C** kneeling on one knee with the gohei planted, looking up |
| seasonal | New-year miko | short white-and-gold new-year kimono with a deep neckline, an oversized red obi bow, a slit to the hip, white thigh-high stockings with gold bell bands, red heeled geta, a fox mask on her head | **A** holding a lucky arrow and a fortune slip left blank, a wink / **B** leaning on a snowy lantern with one knee bent / **C** looking back over her shoulder with her tail around her |

### Shirin

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Caravan dancer | teal-and-gold choli top with a deep plunging neckline and sheer chiffon sleeves, a bare midriff, a low-slung plum skirt with a slit to the hip, a coin belt, gold arm bands, layered gold anklets, barefoot | **A** belly-dance pose with a hip tilted and both arms in a serpentine wave / **B** sitting on cushions with legs folded to one side, a lamp balanced on her palm / **C** reclining on a carpet propped on one elbow, one knee raised |
| evening | Oasis sheer gown | sheer teal chiffon evening gown with gold embroidery, a deep plunging neckline, an open back, a slit to the hip, a coin belt, sheer gold thigh chains, gold sandals | **A** standing with her back arched and a hip tilted, one hand on the veil / **B** sitting on a pool edge with legs crossed, the veil at her lips / **C** looking back over her shoulder with a hand in her long hair |
| swim | Oasis bikini | gold-and-teal coin-trimmed bikini with a sheer chiffon wrap skirt, gold arm bands and anklets, the forehead jewel kept | **A** sitting on the pool edge leaning back on both hands, a leg raised / **B** standing waist-deep gathering her wet hair over one shoulder / **C** lying on her side on a lounger propped on one elbow |
| service (bunny / maid / bartender) | Genie bunny | teal-and-gold bunny-style leotard with a deep plunging neckline, a coin belt, sheer teal harem pantyhose, bunny ears with a gold chain, gold cuffs, gold heels, a brass lamp as a prop | **A** holding the lamp out toward the viewer with a hip tilted / **B** leaning on a cushion pile on both forearms, legs lifted behind her / **C** sitting on a low table with legs crossed, a hand under her chin |
| robe (sleepwear robe-dress) | Chiffon robe | sheer teal chiffon robe-dress with gold trim and a plunging neckline over a teal satin mini dress, a gold sash, gold anklets, barefoot | **A** reclining on cushions propped on one elbow, one knee raised, the robe slipping off a shoulder / **B** kneeling on the cushions looking back over her shoulder / **C** standing at the tent door with her back arched, holding the curtain |
| battle / idol | Sand-dancer war outfit | gold-plated teal armour choli with a deep plunging neckline, a low-slung split skirt with coin chains, armoured arm bands, gold greaves with bells, two curved dancing blades | **A** mid-dance spin with a blade in each hand, hair flying / **B** kneeling on one knee with the blades crossed before her / **C** standing with a hip tilted and a blade resting on her shoulder |
| seasonal | Festival lantern set | short emerald silk festival dress with a deep neckline and gold coin trim, bare shoulders, a slit to the hip, sheer gold thigh chains, a lantern-patterned veil, gold heeled sandals | **A** holding up a glowing lantern with one hand, a hip tilted / **B** sitting on a stall counter with legs crossed, a pomegranate in hand / **C** looking back over her shoulder through hanging lamps |

### Zlata

| slot | outfit | cut and legwear | pose options (A / B / C) |
|---|---|---|---|
| base | Firebird sarafan | scarlet corset sarafan with gold folk ornament, a plunging sweetheart neckline, bare shoulders, feather wing-sleeves, a short front-slit skirt over sheer red lace-top thigh-high stockings with gold garter straps, red embroidered heeled boots | **A** standing with a hip tilted, the feather wing-sleeves spread, looking over her shoulder / **B** seated sideways on a gilded throne armrest with legs crossed, an ember candle in hand / **C** leaning on a gold column with an arched back, one knee bent |
| evening | Ember ball gown | scarlet-and-gold satin ball gown with a deep plunging neckline and an open back, a skirt slit to the hip, sheer red lace-top thigh-high stockings with ruby garter charms, gold heels, the pearl-and-ruby choker kept | **A** descending a stair with one hand on the rail and a hip tilted / **B** sitting on the stair with legs crossed, the gown spilling around her / **C** looking back over her bare shoulder with an arched back |
| swim | Firebird swimsuit | scarlet-and-gold high-cut swimsuit with a deep plunging neckline and ruby clasps, a sheer red wrap skirt, a feather-trimmed sheer cape, gold anklets, the kokoshnik kept | **A** sitting on the pavilion steps with her feet in the water, leaning back on one hand / **B** standing waist-deep draping the braid over a shoulder / **C** lying on her side on a gilded lounger propped on one elbow |
| service (bunny / maid / bartender) | Tsarina bunny | scarlet-and-gold bunny-style leotard with a deep plunging neckline and gold folk embroidery, red bunny ears under the kokoshnik, feather cuffs, sheer red pantyhose, red heeled boots, a tray with a blank tea set | **A** carrying the tray on one hand with a hip tilted / **B** leaning on a table with both forearms and one leg lifted behind her / **C** sitting on the table edge with legs crossed |
| robe (sleepwear robe-dress) | Firebird silk robe | scarlet silk robe-dress with gold folk trim and a plunging neckline over a gold satin mini dress, sheer red lace-top thigh-high stockings, feather-trimmed slippers, the braid over one shoulder | **A** reclining on the bed propped on one elbow with the braid over her arm / **B** sitting at a gilded vanity looking back over her shoulder / **C** standing at a tall window with an arched back |
| battle / idol | Firebird warrior | red-and-gold plate-and-feather armour dress with a plunging neckline, a short armoured skirt, scale thigh-high stockings with ruby garter bands, red greaves, a feathered spear, wing-cape of fire feathers | **A** lunging with the feathered spear pointed forward, the wing-cape flaring / **B** standing in a wide stance with the spear planted, a hand on her hip / **C** kneeling on one knee with the spear planted |
| seasonal | Winter-festival sarafan | short white-and-scarlet winter sarafan with white fur trim and gold ornament, a deep sweetheart neckline, bare shoulders, a fur-trimmed shawl, white thigh-high stockings with red ribbons, red heeled boots, a fur kokoshnik | **A** holding a glowing ember lantern, looking back over her shoulder / **B** sitting on a sleigh seat with legs crossed, a steaming cup in hand / **C** twirling with the shawl flaring in snow |
