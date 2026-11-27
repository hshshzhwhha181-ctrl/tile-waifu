---
name: tw-godot-qa
description: >-
  Godot 4.5.1 QA, headless selftest runner, 20:9/16:9 screenshot capture, GDScript symbol
  outliner, and static UX/contract pre-commit linter for Tile Waifu. Activate this skill
  whenever running Godot tests, importing assets, taking screen captures, navigating large
  .gd scripts, or checking v10 scripts before commit.
---

# Tile Waifu — Godot QA & Static Gate (`tw-godot-qa`)

Use the bundled scripts in `./scripts/` instead of ad-hoc Godot command lines so every run uses an isolated temporary `APPDATA` directory, handles Godot 4.5.1 Windows teardown codes safely, and preserves `.import` hygiene.

## Tool Reference

| Script | Purpose |
| :--- | :--- |
| [godot_qa.ps1](./scripts/godot_qa.ps1) | PowerShell 5.1-safe 1-command runner for `--import`, `--*_selftest` suites, 20:9 / 16:9 screenshots, and tracked `*.import` cleanup. |
| [gd_outline.py](./scripts/gd_outline.py) | Fast GDScript symbol indexer (`class_name`, `extends`, `class`, `signal`, `enum`, `const`, `func` with exact line numbers + `--search`). |
| [ux_lint.py](./scripts/ux_lint.py) | Static pre-commit gate for `game/scripts/v10/**/*.gd` (`%` next to digits, `₽` in strings, `G.add_aff` in `salon/`, raw `res://assets/hero/%s.png`). |

---

## 1. Outline Large GDScript Files (`gd_outline.py`)

Before reading multi-thousand-line files (`play.gd`, `main.gd`, `home.gd`, `g.gd`, `koikoi_screen.gd`), inspect exact line numbers first:

```powershell
# Full symbol outline of a script
python .agents/skills/tw-godot-qa/scripts/gd_outline.py game/scripts/sfx.gd

# Filter symbols by regex/substring (case-insensitive)
python .agents/skills/tw-godot-qa/scripts/gd_outline.py game/scripts/screens/play.gd --search "combo|duck|ult"
```

---

## 2. Run Static UX & Contract Lint (`ux_lint.py`)

Always run `ux_lint.py` before committing changes in `game/scripts/v10/`:

```powershell
# Default pre-commit gate across game/scripts/v10/**/*.gd (exits 1 on violations)
python .agents/skills/tw-godot-qa/scripts/ux_lint.py

# Lint a specific directory or file list
python .agents/skills/tw-godot-qa/scripts/ux_lint.py game/scripts/v10/salon game/scripts/v10/online
```

Checked rules:
1. **`PCT_DIGIT`**: Bare `%` adjacent to digits in string literals (`CONTRACT_SELFTEST` violation; single source of odds is `V10Rates` / `V10Odds`).
2. **`RUB_LITERAL`**: Currency symbol `₽` in string literals outside `V10Sku` / `V10Catalog` / `V10Odds` / `V10Rates`.
3. **`SALON_ADD_AFF`**: Forbidden direct `G.add_aff` inside `game/scripts/v10/salon/` (must route through `V10Salon.bond_cb` / `V10Bond`).
4. **`RAW_HERO_PNG`**: Raw hardcoded `"res://assets/hero/%s.png"` without `V10W1Core.hero_art` / `V10W1Core.hero_png` or a `ResourceLoader.exists(...)` guard (Wave-1 heroines live under `res://assets/v10/wave1/hero/`).

---

## 3. Run Godot Import, Selftests & Screenshots (`godot_qa.ps1`)

`godot_qa.ps1` auto-discovers `Godot_v4.5.1-stable_win64_console.exe` (under `..\tw-tools\godot\` or `$env:GODOT_BIN`), creates a per-run temporary `APPDATA`/`LOCALAPPDATA` folder so parallel workers never collide on `user://` saves or shader caches, and treats Windows Godot 4.5.1's known post-`quit(0)` teardown `0xC0000005` (`-1073741819`) as green **only** when the test's pass marker matched and zero `SCRIPT ERROR:` lines occurred.

### A. Headless Asset Import & `.import` Cleanup

```powershell
# Re-import new/updated assets in isolated temp APPDATA
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -Import

# Restore tracked *.import churn without touching untracked new *.import files
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -CleanImport
```

### B. Run Selftests (`-Tests`)

Accepts short names (`contract`, `online`, `mj_triples`, `wave1`, `audio`), flag names (`--online_selftest`, `contract_selftest`), `"core"`, or `"all"` (add `-Fast` for fast Monte-Carlo counts):

```powershell
# Run targeted selftests and print summary table
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -Tests "contract_selftest,online_selftest,mj_triples_selftest"

# Run full suite (core + v10 modules) in fast mode
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -Tests "all" -Fast

# List all registered test IDs and scenes
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -ListTests
```

### C. Capture 20:9 & 16:9 Screenshots (`-Shot`)

Verify responsive layout on both tall **20:9** (`450x1000` / `720x1600`) and standard **9:16** (`720x1280`):

```powershell
# Tall 20:9 phone capture
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -Shot "v10pvp" -Out "C:\temp\pvp_20x9.png" -Res "450x1000"

# Standard 9:16 capture (custom settle delay -At 2.5)
powershell -ExecutionPolicy Bypass -File .agents/skills/tw-godot-qa/scripts/godot_qa.ps1 -Shot "mj_triples" -Out "C:\temp\triples_9x16.png" -Res "720x1280" -At 2.5
```
