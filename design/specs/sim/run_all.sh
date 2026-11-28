#!/usr/bin/env bash
# Запускает все расчёты MONETIZATION_PLAN и пишет результаты в sim_results.txt (детерминировано: seed зафиксированы).
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
{
  echo "### gacha_exact.py";             python3 gacha_exact.py
  echo; echo "### banner_fullclear.py 60000"; python3 banner_fullclear.py 60000
  echo; echo "### f2p_paths.py";          python3 f2p_paths.py
  echo; echo "### economy_flow.py";       python3 economy_flow.py
  echo; echo "### ltv_model.py";          python3 ltv_model.py
  echo; echo "### whale_curve.py";        python3 whale_curve.py
  echo; echo "### props_and_packs.py";    python3 props_and_packs.py
  echo; echo "### charts_text.py";        python3 charts_text.py
} > sim_results.txt
wc -l sim_results.txt
