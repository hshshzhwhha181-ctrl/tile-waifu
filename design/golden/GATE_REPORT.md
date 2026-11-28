# P50 - Gate "Single style": golden composites (3 heroines x 5 scenes)

Status: **PARTIAL - ready for owner/AD review, nothing approved.** No file here is registered in the asset manifest and no frame has status `approved`; M7 approval is the owner's.

Branch `claude/p50`. Generator: Higgsfield `gpt_image_2_6` + Elements (MC `7df3cc78-...`, Yue `8edeacc2-...`, Nova from the element list in HANDOFF 2.2) + recipe v4 prompts from `design/art_batches/H0_golden_composites.json` (P59 batch H0, tag `v4c`), 9:16, 1k medium, 4 candidates per frame (3 for some). Environment is described in the prompt text (the LoRA environment variant of the gate was NOT run: no GPU tonight, LoRA v2 does not exist yet).

## Files

| path | what |
|---|---|
| `contact_sheet.jpg` | the 15 picks, rows MC / Yue / Nova, columns match / tea / summon / shop / win (label = chosen candidate) |
| `picks/<heroine>_<scene>_1k.png` | the 15 finals (752x1344, metadata scrubbed: PNG text + C2PA removed, pixels untouched) |
| `picks/face_*.png`, `faces_sheet.jpg` | face crops for criterion a |
| `fullbody/*.png`, `fullbody_sheet.jpg` | 4 extra full-body test frames (MC x2, Yue x2) for the head-count ruler |
| `candidates/*.jpg` | all 54 gate candidates as q88 JPEG (the PNG originals stay out of git, 75 MB) |
| `sheets/*.jpg` | per-frame candidate sheets |
| `landmarks.json`, `gate_metrics.json`, `gate_metrics_fullbody.json` | measurement inputs / outputs; script `tools/art/golden_gate.py` |
| `picks.json` | chosen candidate per frame |

## Gate results

| # | criterion | result | evidence |
|---|---|---|---|
| a | faces distinguishable on >= 3 of 5 traits | **PASS (visual judgement, not automated)** | table below, `faces_sheet.jpg` |
| b | accent colour <= 20% of frame | **PASS on the strict mask, 15/15 (max 18.4%); FAIL on the loose upper bound for Yue** | table below |
| c | one tile set | **NOT FULLY TESTED** | tiles only appear in the 5 "win" frames (blank ivory, same shape everywhere; MC win also shows a table); match frames leave the board area empty for the engine |
| d | gold only SSR + one accent, no gold buttons | **N/A for art frames, no violation seen** | frames contain no UI chrome; saturated gold <= 0.2% of any frame (outfit embroidery, lamp trim, one arch ornament) |
| e | head count 7-7.5 by ruler | **PARTIAL, does not hold per frame** | table below: spread 6.6-7.65 around a mean of ~7.1 |
| - | anatomy double audit | **PASS with notes (viewer pass 1 only, second human pass is the AD's)** | all 15 viewed at full 752x1344; hands/fingers/feet counted, see notes |
| - | 0 text / logos / watermark | **PASS (visual) + scan** | `watermark_scan.py` flagged 3 frames, all corner leaves/petals/tiles on inspection; no glyphs seen |
| - | metadata scrubbed | **PASS** | `scrub_metadata.py --check` reports 0 dirty files over picks + fullbody |
| - | one set of navbar icons | **NOT IN SCOPE of this frame set** | no UI in frames |

### a) Face distinguishability (judged from `faces_sheet.jpg`)

| trait | MC | Yue | Nova | distinct? |
|---|---|---|---|---|
| eye shape | large, round, slightly upturned, rose iris, open-smile squint | narrow almond, half-lidded, long lashes, violet | sharp cat-eye with wing liner, blue, narrowed | yes (3 different) |
| face width | wide soft heart, full cheeks | long narrow oval, high forehead | angular, short jaw | yes |
| nose / mouth | small nose, wide open-mouth smile (4 of 5 frames) | slim high nose, small closed smile | small nose, one-sided smirk | yes |
| apparent age | ~24-26, youthful | ~28-30, mature | ~22-25 | weak (MC vs Nova close) |
| brows | soft, thin, half hidden by bangs | long, fine, arched | straight, angled, strong | yes |

4 of 5 traits differ for each pair, so the >= 3 of 5 bar is met. Caveat: this is a visual call from a face sheet; there is no landmark detector in this environment, and hair plus headgear make the three trivially separable even before the faces are compared.

### b) Accent colour share

Hue masks on HSV (`golden_gate.py`): MC = pink hair family, Yue = lavender, Nova = neon cyan + magenta. **strict** = clearly saturated accent pixels (the verdict mask); **loose** = whole hue family including haze and dark tints (an upper bound that also counts the brown floor as "pink").

| frame | match | tea | summon | shop | win |
|---|---|---|---|---|---|
| MC strict / loose | 9.9 / 36.8 | 7.6 / 11.5 | 11.3 / 16.8 | 10.0 / 10.2 | 12.8 / 16.4 |
| Yue strict / loose | 14.3 / 31.1 | 12.6 / 19.6 | 17.6 / 32.6 | 14.4 / 19.4 | 18.4 / 33.6 |
| Nova strict / loose | 1.1 / 2.9 | 0.4 / 4.3 | 0.0 / 2.6 | 0.4 / 4.4 | 0.0 / 2.7 |

Honest reading: Yue's whole costume and hair are lavender, so she is the tight one. Her strict values are 12.6-18.4%, i.e. under the line but with little margin; the loose upper bound exceeds 20% on four of five frames. Nova's neon stays confined to outfit, ears and face marks (strict <= 1.1%), as required. Note on `yue_win`: candidate c2 (22.3%, over the line) was swapped for c0 (18.4%); c0 has a slightly thinner right horn, the AD may prefer c2 on looks and then accept a 22% frame or re-roll.

### e) Head-count ruler

Heads = (hair crown -> sole) / (crown -> chin), pixel landmarks placed by hand on grid overlays (`landmarks.json`, +-8 px, about +-0.3 heads). Only figures with visible soles can be measured: the 4 Nova frames (full body) plus 4 dedicated full-body test frames (2 candidates each for MC and Yue, all 4 usable; knees-up framing is what H0 asks for MC/Yue, so those 10 gate frames are not measurable).

| frame | heads |
|---|---|
| nova_tea / summon / shop / win | 7.24 / 7.62 / 6.60 / 6.84 |
| mc_fullbody a / b | 6.83 / 6.98 |
| yue_fullbody a / b | 7.65 / 7.27 |

Means: Nova 7.08, MC 6.9, Yue 7.46. Only 3 of 8 measured frames sit inside 7.0-7.5; the spread (+-0.5) is larger than the 0.5 wide target band, and hair volume / tilted head poses (Nova shop) shift it. The prompt asks for "7.5 heads"; the model does not follow it per frame. Needs either a tighter pose spec ("head small, 7.25 heads, straight-on") with a re-roll loop, or accept the ruler on key-art finals only (H4) where candidates are cheap to filter. I did not iterate further.

### Anatomy notes (pass 1, full-res viewing)

- Hands: all 5-finger, no fusions in MC tea / summon / shop / win, Yue tea / summon / shop / win, Nova tea / summon / shop / win. Yue summon outstretched hand has very slim long fingers, borderline mannequin, acceptable.
- Feet / legs: Nova's boots, torn two-tone tights and crossed legs (tea) are coherent; MC full-body shoes fine. The torn-tights pattern is the same in every Nova frame (left leg black, right cyan, same slit placement), i.e. pattern consistency passes.
- MC win: sheer organza overskirt over the dress is intended, the dress underneath stays opaque.
- Automatic crop tool `audit_crops.py` (P58) mis-placed its windows on these compositions (it picks background as subject), so the crops were done by viewing the full frames; use `--landmarks` if the AD wants crops.

## Self-critique against the canon sheet (`lora-eval/canon_sheet.jpg`)

What works:
- One renderer, one line/shading language across three very different heroines; the "three worlds" palette problem (R-33) is gone: the shared lacquer/lantern/paper environment ties them together and each accent stays on the character.
- Identity holds: MC pink twin tails + mint cheongsam + jade pins + cuffs match canon; Yue horns, crescent forehead mark, moon fan and lavender hanfu match canon; Nova cyan-to-pink bob, cat-ear headphones, goggles, face stripes, neon-trim jacket match canon.
- Faces do read as different people (see a).

Where it deviates from canon / what the AD should look at:
1. **Nova skin tone is clearly darker (tan) than on the canon sheet** (pale peach) and her face is more angular and older. This is a drift on 5 of 5 frames, not a candidate-luck issue; a prompt line "fair skin" or a stronger element weight is needed before approval.
2. **Nova outfit is invented**: skirt, torn tights, platform boots are not on the canon sheet (canon shows jacket + black top only). Reads cohesive but needs a decision whether it becomes canon.
3. **MC and Yue are knees-up** by the H0 spec; MC's bust looks a bit more moderate than canon, her hips narrower; Nova's bust smaller than canon.
4. **Mood**: frames are night / muted by design (muted-background recipe), canon sheet is bright, saturated daylight. The in-game "daytime" scenes were not tested.
5. **Background parity**: the environment is the model's generic tea-house / courtyard, not the LoRA `tw_master` environment; the gate item "composed in the LoRA environment" is therefore untested.
6. **Text-free but repeated props**: every frame has paper lanterns and a moon; fine for the gate, monotone for the product.
7. **Head count** drift as above.

## Recommendation

Do not approve the set blind. Two cheap fixes before M7: (1) Nova skin/face re-roll with explicit pale-skin text, (2) head-count prompt tightening. Estimated cost of both, 15-20 candidates at 1 cr. Owner decision needed on Nova's outfit.

## Spend

This session: 4 credits (4 full-body test images at 1 cr each, quoted with `estimate_image_cost`; 1k medium = 1 cr). The 54 gate candidates and sheets were generated by an earlier run of this package whose spend log was not written and whose credit transactions could not be read back (`transactions` tool schema error). Upper-bound estimate for it: 54 images x 1 cr = ~54-60 cr plus unknown pilot/re-rolls. Combined estimate <= ~70 cr, well inside the 300 cr cap; `SPEND_LOG.csv` was not updated for the earlier part because no figures exist.
