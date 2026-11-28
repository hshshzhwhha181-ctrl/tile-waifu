# FIX ROUND 1 Report — `ci-data` (G3 CI, Docker, Export Filter & Design Lint)

- **Branch:** `claude/ext-fix-ci-data` (branched from `origin/claude/integration`)
- **Role:** `fix-g3-ci-data` (CI / Docker / Export Filter / Design Lint split of `design/ext/FIX_ROUND1.md` §`## server-ci-data`)
- **Scope:** Confirmed MAJOR #4, Confirmed MAJOR #5, MINOR #1, MINOR #2. (`server/`, `tools/analytics/`, `tools/dashboards/`, and `game/tests/modal_soak/` left untouched for `fix-g6-server`.)

---

## Summary of Fixes

| Finding | Severity | Files Changed | Verification |
|---|---|---|---|
| **MAJOR #4** — `.github/workflows/qa-render.yml` `grep -E "PIXEL_CHECK\|GOLDEN"` stripped all `TWSKINSOAK PENDING` lines and never scanned `qa-render-out/logs` | MAJOR | `.github/workflows/qa-render.yml`, `tools/qa/check_pending_gate.py`, `tools/qa/test_check_pending_gate.py` | `test_check_pending_gate.py` RED (4 FAIL) → GREEN (12/12 OK) |
| **MAJOR #5** — `docker/qa-render/Dockerfile` unpinned base digest/apt packages, empty `GODOT_SHA256` skipped verification; `qa-render.yml` lacked `permissions:`, SHA-pinned Actions, and scoped caches | MAJOR | `docker/qa-render/Dockerfile`, `docker/qa-render/verify_image.sh`, `.github/workflows/qa-render.yml`, `tools/qa/test_check_pending_gate.py` | `test_check_pending_gate.py` RED (4 FAIL) → GREEN (12/12 OK) + `yaml.safe_load` OK |
| **MINOR #1** — `tools/assets/export_filter.py` accepted `'!!!!...'` / `'SyntheticKey000'` as PEM public keys and accepted `exclude_filter="*.json"` for T3 `skins_dl/**` | MINOR | `tools/assets/export_filter.py`, `tools/assets/test_export_filter.py` | `test_export_filter.py` RED (2 FAIL) → GREEN (7/7 OK); `--selftest` 16/16 PASS |
| **MINOR #2** — `tools/design_lint.py` did not cross-check `gacha`/`rules` against `MONETIZATION_PLAN.md`, `data/shop.json` used float RNG rates instead of integer `_bp`, `SHOP-SL-TXT` skipped `funds`/`season_pass`, and `tw_event_pass_mega` ratio `1.5` vs `1.6` was unchecked | MINOR | `tools/design_lint.py`, `data/shop.json`, `design/specs/MONETIZATION_PLAN.md`, `tools/test_design_lint.py` | `test_design_lint.py` RED (5 FAIL) → GREEN (16/16 OK); `design_lint.py` `--selftest` 14/14 OK, `--check` 54/54 OK |

---

## Detailed Changes & RED → GREEN Evidence

### 1. Confirmed MAJOR #4 — `qa-render.yml` PENDING → FAIL Gate Wiring

**Changes:**
- Removed the lossy `grep -E "PIXEL_CHECK|GOLDEN" qa-render-out/skin_swap_soak.log > qa-render-out/golden_scan.log` filter from `.github/workflows/qa-render.yml`.
- Wired `check_pending_gate.py --logs` directly to both raw `qa-render-out/skin_swap_soak.log` and `qa-render-out/logs` (render suites output directory).
- Updated `tools/qa/check_pending_gate.py` (`_expand_log_paths` + `scan_pending_lines`) to recursively scan files inside directories passed via `--logs` (in deterministic sorted order) as well as individual log files.

**RED (before fix):**
```text
$ python -m unittest -v tools/qa/test_check_pending_gate.py
test_skin_swap_soak_pending_lines_and_dir_logs_fail_after_date_x ... FAIL
AssertionError: 6 != 7 : ... (directory qa-render-out/logs skipped)
test_workflow_passes_raw_soak_and_render_logs_without_lossy_grep ... FAIL
AssertionError: 'golden_scan.log' unexpectedly found in ...
Ran 12 tests in 0.041s
FAILED (failures=4)
```

**GREEN (after fix):**
```text
$ python -m unittest -v tools/qa/test_check_pending_gate.py
test_skin_swap_soak_pending_lines_and_dir_logs_fail_after_date_x ... ok
test_workflow_passes_raw_soak_and_render_logs_without_lossy_grep ... ok
Ran 12 tests in 0.022s
OK
```

---

### 2. Confirmed MAJOR #5 — `docker/qa-render/Dockerfile` & `.github/workflows/qa-render.yml` Pinning & Hardening

**Changes:**
- `docker/qa-render/Dockerfile`:
  - Pinned base image to verified official Docker Hub manifest list digest for `ubuntu:24.04` (`noble-20261110.1`, updated `2026-11-23`):
    `FROM ubuntu:24.04@sha256:562111b88caa79c71391c0c4d3c2114a7d5c35915c20561fd893cb1e07929e6b`
  - Pinned apt sources to Ubuntu Snapshot Service (`ARG APT_SNAPSHOT=20261124T000000Z`, `https://snapshot.ubuntu.com/ubuntu/${APT_SNAPSHOT}/`) and pinned exact verified versions from that snapshot for every rendering-critical package:
    - `MESA_PKG_VERSION="25.2.8-0ubuntu0.24.04.5"` (`libgl1-mesa-dri`, `libglx-mesa0`, `libegl-mesa0`)
    - `LLVM_VERSION=18`, `LLVM_PKG_VERSION="1:18.1.3-1ubuntu1"` (`libllvm18`)
    - `XVFB_PKG_VERSION="2:21.1.12-1ubuntu1.9"` (`xvfb`)
    - `FONTCONFIG_PKG_VERSION="2.15.0-1.1ubuntu2"` (`fontconfig`)
    - `FONTS_DEJAVU_PKG_VERSION="2.37-8"` (`fonts-dejavu-core`)
    - `FONTS_NOTO_PKG_VERSION="20201225-2"` (`fonts-noto-core`)
  - Pinned official `Godot_v4.5.1-stable_linux.x86_64.zip` SHA-256 (`02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd`) and made checksum verification **fail-closed** (`test -n "${GODOT_SHA256}"`, 64-hex regex check, unconditional `sha256sum -c -`).
- `docker/qa-render/verify_image.sh`:
  - Added `apt_snapshot` and `libegl-mesa0` to `/etc/tw-qa-render/env.json` and enforced exact `dpkg-query` equality against `TW_QA_PIN_*` environment variables set by the Dockerfile.
- `.github/workflows/qa-render.yml`:
  - Added top-level least-privilege `permissions: contents: read`.
  - Pinned all 5 GitHub Actions to verified 40-char commit SHAs (resolved via `git ls-remote`):
    - `actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0`
    - `docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f # v3.12.0`
    - `docker/build-push-action@10e90e3645eae34f1e60eeb005ba3a3d33f178e8 # v6.19.2`
    - `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830 # v4.3.0`
    - `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2`
  - Scoped Buildx GHA cache and Godot import cache keys to `hashFiles('docker/qa-render/Dockerfile')`, restricted Buildx `cache-to` to `push` events, and removed the unscoped `restore-keys: godot-render-import-` fallback.

**RED (before fix):**
```text
$ python -m unittest -v tools/qa/test_check_pending_gate.py
test_dockerfile_pins_base_digest_apt_versions_and_fail_closed_godot_sha ... FAIL
AssertionError: Regex didn't match: '(?m)^FROM\\s+ubuntu:24\\.04@sha256:[0-9a-f]{64}\\s*$'
test_workflow_has_permissions_sha_pinned_actions_and_scoped_cache ... FAIL
AssertionError: Regex didn't match: '(?m)^permissions:\\s*\\n\\s+contents:\\s*read\\b'
Ran 12 tests in 0.041s
FAILED (failures=4)
```

**GREEN (after fix):**
```text
$ python -m unittest -v tools/qa/test_check_pending_gate.py
test_dockerfile_pins_base_digest_apt_versions_and_fail_closed_godot_sha ... ok
test_workflow_has_permissions_sha_pinned_actions_and_scoped_cache ... ok
Ran 12 tests in 0.022s
OK

$ python -c "import yaml, pathlib; yaml.safe_load(pathlib.Path('.github/workflows/qa-render.yml').read_text(encoding='utf-8')); print('QA_RENDER_YAML OK')"
QA_RENDER_YAML OK
```

---

### 3. MINOR #1 — `tools/assets/export_filter.py` Pubkey Validation & T3 Preset Check

**Changes:**
- Replaced naive PEM body length check in `validate_pub_key_bytes` with:
  - Strict single-block PEM framing (`-----BEGIN PUBLIC KEY-----` … `-----END PUBLIC KEY-----`).
  - Strict `base64.b64decode(..., validate=True)` rejecting `'!!!!...'` and malformed base64 (`T12_INVALID_PEM_BASE64`).
  - Zero-dependency ASN.1 DER SubjectPublicKeyInfo (SPKI) parser (`_read_der_tlv`, `_validate_rsa_spki_der`) verifying `rsaEncryption` OID `1.2.840.113549.1.1.1`, 0-unused-bits `BIT STRING`, inner `RSAPublicKey` `(modulus, publicExponent)`, odd positive modulus with `bit_length() >= 2048` (`T12_WEAK_RSA_PUB_KEY` / `T12_INVALID_ASN1_PUB_KEY`), and odd exponent `>= 3`.
- Replaced `'SyntheticKey000'` fixture with deterministic structurally valid DER RSA-2048 SPKI test helper `_build_test_rsa_spki_pem(2048)` (test public key fixture only; no private key).
- Hardened T3 `skins_dl/**` check in `audit_presets_cfg` (`_has_skins_dl_dir_exclusion`): requires a directory-scoped `skins_dl/**` (or `skins_dl/*`) exclusion AND verifies coverage across diverse probes (`.json`, `.png`, `.png.ctex`, `.webp`, `.tres`, `.ogg`, `.bin`) so unrelated globs like `*.json` or `skins_dl/**/*.json` fail with `T3_SKINS_DL_NOT_EXCLUDED`.
- Added 2 new selftest cases (total 16/16) and 2 new CLI/unit tests (`test_06_rejects_garbage_and_non_rsa2048_pub_keys`, `test_07_rejects_unrelated_glob_for_t3_skins_dl`).

**RED (before fix):**
```text
$ python -m unittest -v tools/assets/test_export_filter.py
test_06_rejects_garbage_and_non_rsa2048_pub_keys ... FAIL
AssertionError: [] is not true : 40x '!' must be rejected
test_07_rejects_unrelated_glob_for_t3_skins_dl ... FAIL
AssertionError: 0 != 3 : exclude_filter='*.json' must fail T3_SKINS_DL_NOT_EXCLUDED across all 3 presets
Ran 7 tests in 1.208s
FAILED (failures=2)
```

**GREEN (after fix):**
```text
$ python tools/assets/export_filter.py --selftest
...
PASS pub_key validation: rejects non-base64 garbage and RSA-1024 (<2048) (RED)
PASS presets: unrelated '*.json' glob fails T3_SKINS_DL_NOT_EXCLUDED across all 3 presets (RED)
EXPORT_FILTER SELFTEST 16/16 PASS

$ python -m unittest -v tools/assets/test_export_filter.py
test_06_rejects_garbage_and_non_rsa2048_pub_keys ... ok
test_07_rejects_unrelated_glob_for_t3_skins_dl ... ok
Ran 7 tests in 1.471s
OK
```

---

### 4. MINOR #2 — `tools/design_lint.py`, `data/shop.json`, & `MONETIZATION_PLAN.md`

**Changes:**
- `data/shop.json`: converted float RNG rate fields in `gacha` to integer basis points (`_bp` out of 10 000): `ssr_base_rate_bp: 150`, `soft_pity_step_bp: 500`, `props_base_rate_bp: 200`, `props_soft_pity_step_bp: 600`.
- `design/specs/MONETIZATION_PLAN.md` (§4.7 line 409): corrected `tw_event_pass_mini/mega` Ratio cell from `1,5` to `1,5 / 1,6` to match `447/299 = 1.5` and `640/399 = 1.6` (matching `data/shop.json`).
- `tools/design_lint.py`:
  - Added `JSON-GACHA-INT-BP` check enforcing integer `*_bp` fields and rejecting float rate parameters in `shop.json["gacha"]`.
  - Added `MP-3.2-GACHA-ODDS` check cross-verifying all §3.2 banner table rows (`b_first`, `b_std`, `b_moon_a`, `b_moon_b`, `b_ward`, `b_props`, `b_rot`) and §3.3 `gift_petals` against `shop.json["gacha"]` and `shop.json["rules"]`.
  - Added `MP-RULES-SYNC` check cross-verifying `shop.json["rules"]` (`wish_cost_gems`, `wish_10_cost_gems`, `props_wish_cost_gems`, `moon_pack_multiple`, `rub_per_wish_min/max`, `max_bundle_value_ratio`, `max_pass_value_ratio`, `second_confirm_min_rub`, `first_buy_bonus_max_moon`, `outfit_stats_enabled_default`, `bond_stats_enabled_default`) against `MONETIZATION_PLAN.md` (§1.3, §3.1, §3.5, §4.1, §4.3, §4.7, Red Line 6).
  - Expanded `SHOP-SL-TXT` forbidden-word scan to cover `funds` (`name_ru`, `sku_id`), `season_pass` (`premium`/`lux` `name_ru` & `sku_pattern`), and `moon_packs` (`sku_id`).
  - Extended `MP-4.7-BUNDLES` to verify both mini and mega ratios on `tw_event_pass_mini/mega` (`parse_all_floats`).
  - Added 5 new negative mutations to `design_lint.py --selftest` (14/14) and 5 new unit tests to `tools/test_design_lint.py` (16/16).

**RED (before fix):**
```text
$ python -m unittest -v tools/test_design_lint.py
test_forbidden_words_in_funds_and_season_pass_fail ... FAIL
AssertionError: True is not false : Forbidden word in funds.name_ru must fail SHOP-SL-TXT
test_gacha_odds_drift_against_mp_fails ... FAIL
AssertionError: True is not false : Editing gacha.soft_pity to 50 must fail design_lint
test_gacha_rates_must_be_int_bp_not_floats ... FAIL
AssertionError: 'ssr_base_rate_bp' not found in {'ssr_base_rate': 0.015, ...}
test_mega_event_pass_ratio_drift_fails ... FAIL
AssertionError: True is not false : Single '1,5' ratio for mini/mega (1.5 / 1.6) must fail MP-4.7-BUNDLES
test_rules_drift_against_mp_fails ... FAIL
AssertionError: 'MP-RULES-SYNC' not found in {'SHOP-SL-NUM'}
Ran 16 tests in 4.734s
FAILED (failures=5)
```

**GREEN (after fix):**
```text
$ python tools/design_lint.py --selftest --check
DESIGN_LINT SELFTEST 14/14 OK
DESIGN_LINT RESULT 54/54 OK

$ python -m unittest -v tools/test_design_lint.py
Ran 16 tests in 7.667s
OK
```

---

## Full Verification Summary

- `python -m unittest -v tools/qa/test_check_pending_gate.py`: **12/12 OK**
- `python tools/assets/export_filter.py --selftest`: **16/16 PASS**
- `python -m unittest -v tools/assets/test_export_filter.py`: **7/7 OK**
- `python tools/design_lint.py --selftest --check`: **SELFTEST 14/14 OK, CHECK 54/54 OK**
- `python -m unittest -v tools/test_design_lint.py`: **16/16 OK**
- `yaml.safe_load('.github/workflows/qa-render.yml')`: **QA_RENDER_YAML OK**
- Note on `tools/qa/run_qa_tools.py`: 86/88 (pre-existing `PALETTE_RAMPS STALE` on `design/specs/palette_ramps.json` on base branch, outside this fix package; all 12 `test_check_pending_gate` tests pass inside `run_qa_tools.py`).

---

## Нужна регистрация

Shared/registry files intentionally NOT edited by this branch (per registry boundaries):

1. **`game/export_presets.cfg`** — once `game/shell/skin/pack_pub.pub` (real RSA-2048 PEM public key) is provisioned in the repository, run:
   ```bash
   python tools/assets/export_filter.py --apply
   python tools/assets/export_filter.py --check --check-pub-key
   ```
   to add `skins_dl/**` to `exclude_filter` and `shell/skin/pack_pub.pub` to `include_filter` across all 3 Android presets (`Android`, `Android-test`, `Android-store`).
2. **`.github/workflows/qa.yml`** — wire the export filter & design lint checks into the main CI workflow (after `game/export_presets.cfg` and `game/shell/skin/pack_pub.pub` are provisioned):
   - `python tools/assets/export_filter.py --check-presets --check-pub-key`
   - `python tools/assets/export_filter.py --check-apk <built.apk>` on Android build jobs
   - `python -m unittest -v tools/assets/test_export_filter.py tools/test_design_lint.py tools/qa/test_check_pending_gate.py`
3. **`tools/tw_test.py`** — optionally add `test_export_filter.py` and `test_design_lint.py` alongside the existing `--selftest` / `design_lint` registrations.
