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
| [`tools/tw_test.py`](../../../tools/tw_test.py) | Cross-platform (Linux / macOS / Windows) runner: `--import`, every Godot selftest suite + server e2e + ux_lint, regression check vs `tools/baseline.json`, `--shot` screenshots, `--clean-import`. Replaces `godot_qa.ps1` (now a thin shim). |
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

## 3. Run Godot Import, Selftests & Screenshots (`tools/tw_test.py`)

One Python runner for all platforms (docs: [`tools/README.md`](../../../tools/README.md)). It gives every Godot process an isolated
HOME/APPDATA (so parallel workers never share `user://`), runs suites in parallel, judges each suite by its **marker line**
(the engine's teardown abort, rc 134 / `0xC0000005`, is accepted only when the marker is green and there is no `SCRIPT ERROR:`),
and compares the result with `tools/baseline.json`: exit 0 = no regression, 1 = regression.

```bash
export GODOT_BIN=/path/to/Godot_v4.5.1-stable_linux.x86_64      # or --godot PATH, or godot4 on PATH
python tools/tw_test.py --import          # one-off headless asset import (also done automatically if game/.godot is missing)
python tools/tw_test.py --fast            # agent subset, ~4 min on 4 cores
python tools/tw_test.py                   # every suite (~11 min on 4 cores)
python tools/tw_test.py -s contract,mj_riichi,server_e2e
python tools/tw_test.py --list            # ids, groups, markers, timeouts
python tools/tw_test.py --shot v10pvp --out /tmp/pvp.png --res 450x1000 --at 2.5
python tools/tw_test.py --clean-import    # git checkout tracked *.import churn
```

Rendering suites (`responsive`, `phone`, `mj_look`, `summon`) need a display: on Linux without `$DISPLAY` the runner wraps them in `xvfb-run`.
`godot_qa.ps1` is kept only as a shim that forwards to the Python runner.
