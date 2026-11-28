# tools/assets: asset slimming pipeline + manifest

Goal: APK/PCK 432 MB -> ~129 MB without code changes. Everything is idempotent, has a `--dry-run` (or is read-only by default)
and is reversible through git (`git checkout -- game/assets game/export_presets.cfg`). Sources of textures are never touched.

| step | tool | what | measured effect (pck, Godot 4.5.1 `--export-pack`) |
|---|---|---|---|
| 1 | `reimport.py` | `.import` only: big art -> lossy WebP q0.82, small UI / 9-patch / rig layers / HUD skin plates stay lossless, wav -> QOA | .ctex 340.7 MB -> 81.4 MB, .sample 15.9 -> 3.5 MB |
| 2 | `audio_reencode.sh` | ogg in place: stereo >=15 s -> 80 kbps, rest -> mono 48 kbps; loop duration guard | .oggvorbisstr 38.1 -> 20.3 MB |
| 3 | `video_reencode.sh` | ogv in place: 1000 kbps ladder (1500 for heavy clips), SSIM >= 0.90 guard | .ogv 21.9 -> 9.7 MB |
| 4 | `export_filter.py` | computes a SAFE `exclude_filter` (tests/demos/runners/tools/docs) and writes it into the 3 presets | -1.3 MB, 4924 -> 4597 files |
| 5 | `dedupe.py` | md5 duplicate report (18 groups) + canonical map; no automatic remap (tried, no effect) | report only (~2.0 MB after slimming) |
| 6 | `gen_manifest.py` | `game/assets/manifest/assets.json` (id, path, kind, md5, bytes, px, status, referenced_by) | build-time artefact, excluded from the export |
| QA | `qa_dump.gd` + `qa_visual.py` (+ `qa_report.py`, older `qa_compare.py`), `verify_selftests.sh` | what Godot really loads vs the source (PSNR + detail crops); asset-sensitive headless selftests | |

Order after a fresh asset drop: `reimport.py --apply` -> `audio_reencode.sh --apply` -> `video_reencode.sh --apply` ->
`godot --headless --import --path game` -> `export_filter.py --apply` -> `gen_manifest.py` -> `godot --headless --path game --export-pack Android-store out.pck`.
New generated art gets `status: pending` in the manifest until someone flips it to `approved` (`gen_manifest.py --seed` marks everything approved).

Notes
* `reimport.py --cap N --cap-dir DIR` (process/size_limit) exists but is OFF: capping every >1536 px image saves only ~3.3 MB in total,
  and hud2/combo (face rects in texture pixels), rig layers and outfit art carry pixel coordinates in code/JSON.
* `export_filter.py` keeps every candidate that a shipped file needs at parse time (class_name use, preload, ext_resource). Today 17 selftest
  files are pinned because `main.gd` / `g.gd` / screens call e.g. `V8ProfileSelftest.run()` directly; removing that coupling is a code change.
* rig layers (13 MB) are kept lossless on purpose; making them lossy would save ~11 MB (pass `--keep` overrides / edit KEEP_LOSSLESS).

Visual QA of the slimming (P03): see `docs/qa/SLIM_VISUAL_QA.md` (446 textures + 15 ogv, 963 crops, verdict table `docs/qa/slim_visual_qa.tsv`).
video_reencode.sh now also guards the worst frame (SSIM >= 0.92); clip-average SSIM alone let visibly blocky clips through.
