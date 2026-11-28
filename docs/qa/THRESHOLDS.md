# QA thresholds register

Every numeric threshold used by a QA gate lives here once. Raising a threshold to make a test green requires a new row (old, new, why, who), see `design/specs/UNIFIED_QA_PLAN.md` section 17.3. `[ГИПОТЕЗА]` = not yet measured on approved content / real devices.

| Gate | Parameter | Value | Status | Where | Changed |
|---|---|---|---|---|---|
| palette_audit chrome | warn / fail dE2000 | 3.5 / 6.0 | [ГИПОТЕЗА] calibrate (plan 3.3) | `tools/qa/build_palette_ramps.py` PROFILES | 2026-11-28 initial |
| palette_audit icon | warn / fail dE2000 | 4.5 / 8.0 | [ГИПОТЕЗА] | same | 2026-11-28 initial |
| palette_audit fx | warn / fail dE2000 | 7.0 / 14.0 | [ГИПОТЕЗА] | same | 2026-11-28 initial |
| palette_audit art | garish C(OKLCH) / min area / min dE | 0.24 / 3 % / 12 | [ГИПОТЕЗА] | same | 2026-11-28 initial |
| palette_audit edge trim | flat_tol / grow px | 0.04 / 2 | [ГИПОТЕЗА] | same, `EDGE_GROW` | 2026-11-28 initial |
| palette_audit ratchet | mean dE / coverage tolerance | 1.5 / 5 pts | [ГИПОТЕЗА] | `apply_baseline` | 2026-11-28 initial |
| skin_lint disk budget | per tier MB (+15 %) | 4.3 / 6.9 / 12.3 / 23.2 | from SKIN_HUD_SYSTEM 2.7 [ГИПОТЕЗА] | `build_skin_schema.py` | 2026-11-28 initial |
| skin_swap_soak | object growth after warm-up | <= +40 | [ГИПОТЕЗА] | `skin_swap_soak.gd` MAX_OBJECT_GROWTH | 2026-11-28 initial |
| skin_swap_soak | static memory growth | <= 1.5 MB | [ГИПОТЕЗА] | MAX_STATIC_GROWTH_BYTES | 2026-11-28 initial |
| skin_swap_soak | swap logic p95 | <= 20 ms | [ГИПОТЕЗА] | P95_SWAP_USEC | 2026-11-28 initial |
| golden diff | changed pixels outside dynamic zones | <= 0.10 % (WARN to 0.50 %) | AT-S24 | `golden_diff.py` (not implemented) | |
| skin_lint proportions | min heads | 7.0 (was 6.75) | review 2026-11-28 C3 | `build_skin_schema.py` | 2026-11-28 review |
| skin_lint nudity gate | exposed classes | FAIL, no manual bypass | [ГИПОТЕЗА] threshold to calibrate on approved ATF set; detector not implemented (P94) | `skin_lint --media` (planned) | 2026-11-28 review |
| skin_lint face coverage | body-without-face area share | <= 55 % | [ГИПОТЕЗА] | `SL-RL-07` (planned) | 2026-11-28 review |
| skin_lint video | Theora size, per clip | 540x960, <= 0.9 MB | review T7 | `SL-ULT-02` | 2026-11-28 review |
| golden PENDING | PENDING becomes FAIL after | 2026-12-12 (was: date X not set; P96 + 14 days) | active (P96) | `tools/qa/check_pending_gate.py`, `UNIFIED_QA_PLAN` Appendix R T13 | 2026-11-28 P96 |
| freeze watchdog | FREEZE_SUSPECT threshold | 2 s (was ANR 5 s) | [ГИПОТЕЗА] H11 | `UNIFIED_QA_PLAN` 15.2 | 2026-11-28 review |
| skin_swap_soak | live skin-slot Texture2D growth after warm-up | <= 0 (exact return to active slot count; 0 after clear) | active (P96, T11/T15d) | `game/tests/skin_swap_soak/skin_swap_soak.gd` `MAX_LIVE_TEX_GROWTH` | 2026-11-28 P96 |
| skin_swap_soak | render-mode pixel check (`--require_render=1`) | 0 PENDING allowed (real rendered pixel verified) | active (P96, T13) | `game/tests/skin_swap_soak/skin_swap_soak.gd` `_pixel_check` | 2026-11-28 P96 |
| skin_swap_soak | OKLab vs sRGB mix divergence | OKLab dist >= 0.02 (~dE >= 2) on saturated reference pair | active (P96, T15d) | `game/tests/skin_swap_soak/skin_host_stub.gd` `mix_oklab` | 2026-11-28 P96 |
| AT-S22 / T-CMP-1 | compliance draw-command & tree snapshot | 0 diff across skin tiers (pixel hash secondary) | active (P96, T13) | `game/tests/skin_swap_soak/skin_swap_soak.gd` `_compliance_snapshot_check` | 2026-11-28 P96 |
| tw_test rc 134 policy | teardown SIGABRT acceptance | rc 134/-6 accepted ONLY after green marker `OK` + `n/n` AND 0 `SCRIPT ERROR` (including after marker) | active (P96, T19) | `tools/tw_test.py` (registration patch in `design/ext/reports/P96.md`) + `tools/qa/check_pending_gate.py` | 2026-11-28 P96 |
| qa-render image | golden capture environment | pinned `docker/qa-render` (Ubuntu 24.04, Mesa llvmpipe GL 3.3, `LP_NUM_THREADS=1`, Godot 4.5.1, deterministic fontconfig) | active (P96, T13) | `docker/qa-render/Dockerfile`, `.github/workflows/qa-render.yml` | 2026-11-28 P96 |

## P96 Policy: Golden PENDING Deadline (Date X) & Render Image Lock

- **Date X = `2026-12-12` (UTC)** (`2026-11-28 + 14 days`, per `UNIFIED_QA_PLAN` Appendix R T13).
- Before `2026-12-12`: `PENDING` markers in golden/render logs produce `PENDING_GATE WARN` (exit 0) unless `--strict` is set.
- On or after `2026-12-12`: any `PENDING` marker in golden/render logs produces `PENDING_GATE FAIL` (exit 1) via `python tools/qa/check_pending_gate.py`.
- **Golden image provenance:** reference goldens (`AT-S24`, `TWSkinShot`, `golden_diff.py`) may only be captured inside `docker/qa-render/` (`TW_QA_RENDER_IMAGE=1` with `/etc/tw-qa-render/env.json` attached). Captures taken on host GPUs or `--headless` Dummy renderer are invalid.
- **Font / Mesa / Godot updates:** any update to `docker/qa-render/Dockerfile` or bundled fonts in `game/assets/**/fonts/` requires an explicit golden re-baseline PR reviewed by AD + QA (`UNIFIED_QA_PLAN` §7.3, §17.3).

