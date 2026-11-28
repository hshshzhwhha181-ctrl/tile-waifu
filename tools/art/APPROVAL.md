# Art approval pipeline (P58)

Generated art never reaches a release by directory inclusion. The path is:

    model output
      -> approve.py register FILE --dest res://assets/<final path>   (copies into game/assets/incoming/, scrubs metadata,
                                                                      scans for watermarks, adds ONE manifest row: status=generated)
      -> approve.py audit ID -o DIR                                  (contact sheet: face / hands / fingers / feet / legs)
      -> human art director looks at the sheet and the full image
      -> approve.py approve ID --by NAME --audited                   (moves the file to its final path, flips that one row to approved)
      -> check_release.py                                            (CI: nothing but approved art can ship)

`game/assets/incoming/` carries a `.gdignore`: Godot neither imports nor exports it, so generated art cannot ship by accident.
A row keeps its final `path` from registration on, so the manifest stays sorted by path and `approve` touches one row
(`status`, `approved_by`, `watermark`, and the removal of `src`).

## Tools

| tool | job |
|---|---|
| `scrub_metadata.py` | lossless removal of EXIF, XMP, IPTC, PNG text chunks, C2PA/JUMBF (PNG caBX, JPEG APP11, WebP C2PA), comments, trailing data; PNG / JPEG / WebP; pixels are never re-encoded (SSIM 1.0). `--check` only reports. Cross-checks with exiftool when installed |
| `watermark_scan.py` | review aid: isolated text lines or compact marks near the border on smooth ground. No model. Known misses: marks inside busy texture, very faint (< ~30% alpha) logos. Measured false positives on the shipped art: about 2% |
| `audit_crops.py` | 8 crops from anatomical priors on the subject bbox (alpha, or distance from the border colour); `--landmarks` JSON for poses the priors miss (sitting, arms raised) |
| `approve.py` | `register`, `audit`, `approve`, `reject`, `list`; `--dry-run` everywhere |
| `check_release.py` | rules R1..R6 (see its docstring): non-approved file would ship, unregistered file under assets/, approved md5 drift, generated row without src, incoming/ without `.gdignore`, include-list with a non-approved id |
| `test_art.py` | acceptance tests: `ART_PIPELINE ok/total` |

Statuses: `approved` (may ship), `generated` (waiting in incoming/), `pending` (existing file under review), `rejected`.
`tools/assets/gen_manifest.py` skips incoming/, carries `generated` rows over verbatim and keeps curated row fields.

## Not done here

- The exporter does not yet build the include list from the manifest (that is TWAssets / export preset work); today the gate checks
  the existing `all_resources` + `exclude_filter` presets, and `--include-list` is ready for the generated list.
- exiftool is not installed in the cloud container; the scrub verifier is a built-in container parser. Run
  `exiftool -a -u -G1 FILE` on a few scrubbed files on a machine that has it before relying on this for store submission.
