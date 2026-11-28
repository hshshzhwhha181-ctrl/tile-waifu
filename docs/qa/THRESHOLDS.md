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
