# Visual QA of the asset slimming (P03)

Scope: what WP2 (`0d83a09`) did to the art (lossy WebP q0.82 re-import of 446 textures) and to the 15 `.ogv` ult/lobby clips (Theora 1000 kbps).
ARCH_DECISION flagged two unchecked risks: Theora quality and gradient banding / cutout halos. This is the check.

## Method (reproducible, read-only on the game)
* Textures: `tools/assets/qa_dump.gd` dumps what Godot **really loads** (the imported `.ctex`) for all 446 lossy-imported textures
  (`grep compress/mode=1 **/*.import`), `tools/assets/qa_visual.py tex` compares with the untouched source file:
  alpha-weighted PSNR, SSIM (7x7, luma over grey), edge-zone PSNR (partial-alpha pixels +2 px, composited on black and white, so halos show),
  max |dAlpha|, banding score in smooth gradient tiles, worst-tile SSIM. Per file up to 3 crops (worst structure / worst alpha edge /
  worst gradient tile) as `ORIGINAL | LOADED | |diff|x8`.
* Video: `qa_visual.py vid` decodes the clip at 10/50/90 % with ffmpeg and compares with the pre-WP2 original from git (`0d83a09^`);
  whole-clip PSNR/SSIM + worst single frame SSIM + 3 crops per frame.
* Totals: 446 textures, 15 ogv, **963 detail crops**. Full per-file table: `docs/qa/slim_visual_qa.tsv` (verdict column). Reviewed crop sheets: `docs/qa/crops/`.
* Reproduce: `godot --headless --path game --script res://../tools/assets/qa_dump.gd -- OUT res://a.webp ...` (batches of ~90),
  then `python3 tools/assets/qa_visual.py tex DUMP OUT LIST` / `... vid OUT`, `python3 tools/assets/qa_report.py OUT docs/qa/slim_visual_qa.tsv`.

## Textures: verdict OK for all 446, nothing needs KEEP_LOSSLESS
* Acceptance gate (PSNR < 38 dB or SSIM < 0.95) flags **272 of 446** files. The gate is too strict for q0.82: median PSNR is 37.0 dB, median SSIM 0.983;
  PSNR is driven by the loss of fine paper/cloth/fabric grain, not by edges. Envelope over all files: SSIM >= 0.932, worst 64 px tile SSIM >= 0.901,
  edge-zone PSNR >= 29.9 dB, max |dAlpha| = 0 (alpha is stored losslessly, so no alpha halo/erosion).
* Visually reviewed (3-8x zoom, 30+ crops): the worst-SSIM files (mj table cloths, shop item icons, hud2/combo nova/hana/yue, key_heroes),
  the worst PSNR files (mj classic crests: PSNR 27-29 dB but SSIM 0.99, gold ornament, only micro-contrast lost), the worst edge-PSNR file of every cutout group
  (hero, wave1/hero, v08/emotions, wave1/emotions, outfits, poses), and the gradient/banding candidates (bg/summon, menu, tourney, key_bg, shop/bg_shop, far_* tables, cloth_jade).
  Findings: cutout edges stay clean (slight softening, no halo/fringe); grain and weave texture are smoothed, structure intact; gradients show no
  visible bands. Marginal case: `bg/summon.webp` (full-screen glow gradient) shows faint 16 px steps at 3x zoom and strong contrast stretch; the
  source is already a lossy WebP with the same steps, difference between source and loaded is below 2 levels almost everywhere. Kept lossy: reverting it to lossless would cost an estimated ~3 MB (not measured) and would break the 135 MB budget.
* The remaining flagged files (not individually looked at) sit inside the reviewed envelope; the verdict column marks them `flagged-envelope`. The phone check on the device (M2) is the final word.
* Not an issue: `ui/app_icon.png`, `ui/icon_*_432.png` are imported lossy but Android takes launcher icons from the source PNG in the preset.

## Video: 8 of 9 WP2 re-encodes were visibly worse than the original, fixed
Clip-average SSIM (WP2 guard 0.90) hides the problem: at 1000 kbps the worst frames of the heavy clips were SSIM 0.81-0.88 with clearly visible macroblocks / mushy fabric
(shirin f90 0.81, tsubame 0.83, zlata 0.88, o_dragon 0.885, miel 0.884, kohaku 0.881).
Fix (patch, no code change): `tools/assets/video_reencode.sh` got a second guard, **worst single frame SSIM >= 0.92** (`--min-frame-ssim`), ladder extended to 3000 kbps;
the six clips and `yue_queen` were re-encoded from the pre-WP2 originals by the script itself (`ogv_ladder_run.tsv`):

| clip | WP2 1000k (bytes / worst frame) | now (bytes / worst frame) | original |
|---|---|---|---|
| kohaku | 664118 / 0.881 | 990602 @1500k / 0.931 | 2111573 |
| miel | 663146 / 0.884 | 988857 @1500k / 0.935 | 1859603 |
| o_dragon | 729681 / 0.885 | 1217591 @2500k / 0.925 | 2116067 |
| shirin | 659988 / 0.814 | 1645506 @2500k / 0.936 | 2301768 |
| tsubame | 978142 / 0.827 | 1951460 @3000k / 0.930 | 3134602 |
| zlata | 988544 / 0.879 | 1961780 @3000k / 0.927 | 3372095 |
| yue_queen | 488349 / 0.916 | 730924 @1500k / 0.944 | 1326821 |

Unchanged and OK: `nova` (0.952), `mc_lobby` (0.878 worst frame, but only the first 5 frames of the loop, p5 0.929, background video: accepted at 1000k) and the 6 ult clips WP2 never touched (hana, mc, mc_base, nova_roof, rin, yue: byte-identical originals).
Theora can not be cheap on this footage: at 1000 kbps zlata is SSIM 0.90 vs the original no matter what, so "revert to original" was the alternative (+10 MB); the ladder buys back 5 of those 10 MB.
All 15 ogv still load as `VideoStreamTheora` in Godot 4.5.1 (checked headless).

## Size
`godot --headless --path game --export-pack Android-store`: **133,429,988 bytes = 133.4 MB** (was 128.99 MB after WP2; 139.3 MB if the six clips were simply reverted to the originals). Budget <= 135 MB: met, 1.6 MB headroom.
The 135 MB is decimal MB (WP2 reported 128.99 MB, same unit).

## Owner check on the phone (morning, M2)
Play the ults of Zlata, Shirin, Tsubame (the heaviest motion) and the Kohaku/Miel/O-dragon ults at full screen; look for blocks in cloth/hair. If any is still unacceptable the next rung is
`tools/assets/video_reencode.sh --min-frame-ssim 0.95` (about +2-3 MB) or restoring the original (`git checkout 0d83a09^ -- <file>`).
