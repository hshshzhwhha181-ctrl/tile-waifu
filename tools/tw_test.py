#!/usr/bin/env python3
"""tw_test.py - cross-platform QA runner for Tile Waifu (replaces godot_qa.ps1).

One entry point for everything the project treats as a test gate:

  * every Godot selftest suite (core --*_selftest flags, v10 registry modules, a few screen-driven ones)
  * server/e2e_test.mjs   (node, skipped with a reason if node / node:sqlite is unavailable)
  * ux_lint.py            (static contract linter)

Results are parsed from the marker lines the suites print (SELFTEST n/m, OK, FAIL ...), compared with
tools/baseline.json and the run exits non-zero only on a REGRESSION against that baseline.

Typical use:
  python tools/tw_test.py --list
  python tools/tw_test.py --fast                      # agent subset, a few minutes
  python tools/tw_test.py                             # everything (+ regression check)
  python tools/tw_test.py -s mj_riichi,economy -j 2   # chosen suites
  python tools/tw_test.py --update-baseline           # rewrite tools/baseline.json from this run
  python tools/tw_test.py --import                    # headless asset import (first run in a clean checkout)
  python tools/tw_test.py --shot home --out /tmp/home.png

Godot binary: --godot PATH, or $GODOT_BIN, or godot4 / godot on PATH.
Godot 4.5.1 aborts at teardown on Linux (rc 134, "corrupted size vs. prev_size") and on Windows
(rc 0xC0000005) AFTER all output is written; a suite is judged by its marker line, not by that rc.
See tools/README.md.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
BASELINE_PATH = REPO / "tools" / "baseline.json"
UX_LINT = REPO / ".agents" / "skills" / "tw-godot-qa" / "scripts" / "ux_lint.py"
E2E = REPO / "server" / "e2e_test.mjs"
CORE_DIR = GAME / "core"   # V10Registry scans it for module.gd manifests

# return codes that mean "engine aborted/crashed while tearing down"; accepted only with a green marker
TEARDOWN_RCS = {134, -6, 139, -11, 0xC0000005, -1073741819, 3221225477}
# --no-mask-rc: only the one KNOWN teardown abort (SIGABRT, docs/qa/SIGABRT_SPIKE.md) is tolerated; a SIGSEGV (139 / -11) or a
# Windows access violation is no longer swallowed, so a NEW crash class shows up as a red suite instead of hiding behind the green marker.
KNOWN_ABORT_RCS = {134, -6}
WIN = os.name == "nt"
NO_MASK_RC = False   # set by --no-mask-rc (see KNOWN_ABORT_RCS)


# --------------------------------------------------------------------------------------------------
# catalog
# --------------------------------------------------------------------------------------------------
@dataclass
class Suite:
    id: str
    kind: str = "godot"            # godot | node | python
    group: str = "v10"             # core | v10 | extra | server | lint
    marker: str = ""               # substring of the result line (last matching line wins)
    scene: str = ""                # res:// scene to run (empty = main.tscn)
    script: str = ""               # res:// script run with -s
    args: list = field(default_factory=list)
    fast_args: list | None = None  # replaces args in --fast runs (cheaper Monte-Carlo counts)
    render: bool = False           # needs a display (xvfb-run on Linux without DISPLAY) + opengl3
    res: str = ""                  # --resolution for render suites
    timeout: int = 300             # seconds
    fast: bool = False             # member of the --fast subset
    soft: str = ""                 # regex of failure lines that are timing noise (perf budgets on software GL): warn only
    note: str = ""


def S(id, marker, scene="", args=(), fast_args=None, render=False, res="", timeout=300, fast=True,
      group="v10", script="", note="", soft=""):
    return Suite(id=id, marker=marker, scene=scene, script=script, args=list(args),
                 fast_args=None if fast_args is None else list(fast_args), render=render, res=res,
                 timeout=timeout, fast=fast, group=group, note=note, soft=soft)


SV = "res://scripts/v10/"
CATALOG: list[Suite] = [
    # ---- core: run on main.tscn through user args ------------------------------------------------
    S("contract", "CONTRACT_SELFTEST", args=["--contract_selftest=1"], group="core"),
    S("board", "SELFTEST", args=["--selftest=1"], group="core", timeout=300),
    S("event", "EVENT SELFTEST", args=["--event_selftest=1"], group="core"),
    S("league", "LEAGUE", args=["--league_selftest=1"], group="core"),
    S("profile", "PROFILE", args=["--profile_selftest=1"], group="core"),
    S("recovery", "RECOVERY", args=["--recovery_selftest=1"], group="core"),
    S("state", "STATE_SELFTEST", SV + "state/state_selftest.tscn", group="core",
      note="P12: TWClock/TWSave/TWMigrate/TWState, golden saves v4..v8, 500-case save fuzz (+ parity with the legacy G.apply_state)"),
    S("twgacha", "TWGACHA_SELFTEST", SV + "gacha/twgacha_selftest.tscn", ["--mc=1"], fast_args=["--mc=0.25"], group="core",
      note="P09: TWGacha.pull (the one wish engine): fixed-seed parity with the pre-P09 engine (6 pinned fingerprints + 60 seeds), exact Markov numbers "
           "pinned to the deleted odds class and to an independent chain, 1000-pull journal property (balance delta = ledger), gifted / refused pulls, "
           "pity guarantees, and a source scan: the deleted engine and the g.gd proxies are named nowhere"),
    S("round", "ROUND_SELFTEST", SV + "round/round_selftest.tscn", group="core",
      note="P20: TWRound.resolve + TWBoosters + TWModeCfg + TWRewards: 139-row table (independent python model of the legacy award code), 300-scenario diff vs the frozen play.gd transcription, ladder == G, bot rounds, outfit invariance, wallet payment, core purity"),
    S("twboard", "TWBOARD_SELFTEST", SV + "rules/tw_board_selftest.tscn", group="core",
      note="P16: TWRng, TWFree, TWBoardEvents, TWBoard (unified solitaire rules): scenarios, 1000 seeds, 200 Path levels (lockstep with V10LevelSim, certificate, solver bot), replay, shuffle, fuzz"),
    S("twparity", "TWPARITY_SELFTEST", SV + "rules/parity_selftest.tscn", group="core", timeout=900,
      fast_args=["--games_n=100", "--levels_n=200", "--fuzz_n=1000"],
      note="P17: TWBoard parity with the legacy TrayBoard: 500 recorded games (tests/fixtures/replays) replayed with 0 divergences of legality/outcome, layouts == TWFree, 1000/1000 level certificates replay on TWBoard, live fuzz of 5000 operations in lockstep with a real TrayBoard (free set = legacy is_free = TWFree.is_free)"),
    S("twnav", "TWNAV_SELFTEST", "res://shell/nav/nav_selftest.tscn", group="core",
      note="P23: ScreenSpec, TWScreen, TWScreens (go/back/history/tabs on 12 fake screens, 3 s watchdog), TWContext, TWBus"),
    S("twmodal", "TWMODAL_SELFTEST", "res://shell/nav/modal_selftest.tscn", group="core",
      note="P24: TWModal, ModalStack (scrim owned by the modal, on_close exactly once, clear_all), Android back table (4 rows), 500-sequence property test"),
    S("legacy_host", "LEGACY_HOST_SELFTEST", "res://shell/main_v11.tscn", ["--legacy_selftest=1"], group="core", timeout=400,
      note="P25: v11 root = LegacyHost (extends the frozen v10 main): v11 plumbing wired, main API intact, catalogue == SCREENS (46 ids), every legacy screen opened + closed through the host with 0 script errors / modal leaks"),
    S("twassets", "TWASSETS_SELFTEST", "res://shell/assets/assets_selftest.tscn", group="core", timeout=600,
      note="P29: TWAssets registry (direct + composite ids: every manifest asset and every resolver id loads, 0 missing), release gate (not approved -> null + code), dev flagged placeholder"),
    S("twwidgets", "TWWIDGETS_SELFTEST", "res://shell/design/widgets_selftest.tscn", group="core", timeout=600,
      note="P28: TWButton/TWPlate/TWSheet/TWHeader/TWTabBar/TWToast/TWCurrencyChip/TWSkin: carried hud2 suite (854) + press curve per tick, p95 tap response, skins, 3 resolutions"),
    S("twpresence", "TWPRESENCE_SELFTEST", "res://shell/stage/presence_selftest.tscn", group="core", timeout=600,
      note="P34: TWPresence over V10LiveRig: strip <= 28% on 3 aspects, 160 px medallion, never over the board, touches off, 7 reactions from core events < 100 ms, stub for heroines without a rig, draw/texture budget"),
    S("twboardview", "TWBOARDVIEW_SELFTEST", "res://shell/screens/match/board_view_selftest.tscn", group="core", render=True, res="720x1280",
      timeout=900, fast_args=["--games_n=40"],
      note="P31: TWBoardView + TWMatchScreen: layout (field >= 92% x 60%, tile 56/64/72/80), 20/20 events animated, 100 games with and without the view = same events and state hash, mirror == board, pixel contrast, 60-tile frame cost, screen API"),
    S("twresult", "TWRESULT_SELFTEST", "res://shell/screens/match/match_selftest.tscn", group="core", render=True, res="720x1280", timeout=600,
      note="P33: victory screen: TWResultChain (milestones, fast <= 3 s / chain <= 20 s timeline, tap + Skip state machine, 500 random sequences) + TWResultModal on the ModalStack (fixed button rects, one primary, Skip always visible, 0 banned words) + real-time <= 3 s + pixels + TWMatchScreen hook"),
    S("slice", "SLICE_SELFTEST", "res://shell/main_v11.tscn", ["--slice=play"], fast_args=["--slice=play", "--slice_games=20"], group="core",
      render=True, res="720x1280", timeout=1200,
      note="P37: vertical slice: N bot games (100; --fast 20) through the screen API: Home -> TWMatchScreen (solver / hint / random / mixed bot) -> victory modal -> Collection -> Wish -> Shop on the LegacyHost, 0 SCRIPT ERROR / engine ERROR, no modal leak, no stage > 10 s without an event"),
    S("skin_soak", "TWSKINSOAK_SELFTEST", "res://tests/skin_swap_soak/skin_swap_soak.tscn", group="core", timeout=300,
      note="QA plan T-SOAK-1: 61 synthetic+real skin manifests, 300 swaps through TWSkinHostStub -> TWSkin.apply -> tw_skinned group -> TWBus: no leak of the previous skin, "
           "locked tokens untouched, atomic rejection of bad manifests (hex / locked / unknown / wrong level), replay hash, no object/memory growth; pending items printed as PENDING"),
    S("core_audit", "CORE_AUDIT_SELFTEST", "res://tests/core_audit/core_audit_selftest.tscn", group="core", timeout=300,
      note="G1 Brief A: regression + property/fuzz suite for clock/save/migrate/board/nav/modal/bus/assets fixes"),
    S("twult", "TWULT_SELFTEST", "res://tests/ult/ult_selftest.tscn", group="core",
      note="P87: TWUltRegistry (58-id catalogue + legacy sources), TWUltPolicy, ult_seen modular save"),
    S("battle_progress", "BATTLE_PROGRESS_SELFTEST", "res://tests/battle/progress_selftest.tscn", group="core",
      note="P78: TWBattleProgress AT-B03, AT-B11 (100k pity), W15 catch-up, D30 cohort"),
    S("battle_core", "BATTLE_CORE_SELFTEST", "res://tests/battle/battle_core_selftest.tscn", group="core",
      note="P74: TWBattle/TWBattleMath/TWBattleEvents AT-B01..B06, AT-B15, AT-U10, XP table, ULT_AIM journal"),
    S("battle", "BATTLE_SELFTEST", "res://tests/battle/battle_selftest.tscn", ["--battle_selftest=1"], fast_args=["--battle_selftest=1", "--runs=300"], group="core",
      note="P75: TWBattleBot/TWBattleSelftest AT-B07 role spread, AT-B08 twist spread, AT-B09 sim parity, AT-B16 autobattle"),
    S("battle_stages", "BATTLE_STAGES_SELFTEST", "res://tests/battle/stages_selftest.tscn", group="core",
      note="P77: AT-B10 60 stages x 3 seeds = 180 certified boards + suit_weights + blind solver"),
    S("twage", "TWAGE_SELFTEST", "res://tests/age/age_selftest.tscn", group="core", timeout=180,
      note="P22: TWAge/TWConsent/TWSpendLimit/PullHistory"),
    S("twlegal", "TWLEGAL_SELFTEST", "res://tests/legal/legal_selftest.tscn", group="core", timeout=180,
      note="P108: 13 legal template docs, C16 clause, offer-versioned consent journal, TWLegalScreen"),
    S("analytics", "ANALYTICS_SELFTEST", "res://tests/analytics/analytics_selftest.tscn", group="core",
      note="P106: TWAnalyticsSchema + TWAnalyticsBuffer"),
    S("modal_soak", "MODAL_SOAK_SELFTEST", "res://shell/tests/modal_soak.tscn", group="core", timeout=300, fast_args=["--soak_ops=1200"],
      note="P26: 61 screens x 10 modal archetypes soak + 0.12.1 regression + leak check"),
    S("ults", "ULTS", args=["--ults_selftest=1"], group="core"),
    S("letters", "LETTERS", args=["--letters_selftest=1"], group="core"),
    # ---- v10 registry modules (docs/INTEGRATION_0.10.md; ids == V10RegistryList ids) -----------------
    S("responsive", "LAYOUT_SELFTEST", render=True, res="1536x2048", timeout=600,
      args=["--layout_selftest=1", "--save=user://layout_shots_save.json", "--save_wipe=1"]),
    S("economy", "ECON_SELFTEST", SV + "economy/econ_selftest.tscn", ["--econ_selftest=1"],
      fast_args=["--econ_selftest=1", "--econ_mc=0.1"]),
    S("affection", "AFFECTION_SELFTEST", SV + "economy/affection_selftest.tscn", ["--affection_selftest=1"]),
    S("meta", "META_SELFTEST", SV + "meta/meta_runner.tscn",
      ["--meta_selftest=1", "--save=user://meta_runner.json", "--save_wipe=1"]),
    S("hud2", "HUD2 SELFTEST", SV + "hud2/hud2_demo.tscn", ["--hud2_selftest=1"]),
    S("fonts", "FONTS SELFTEST", SV + "fonts/fonts_runner.tscn", ["--fonts_selftest=1"]),
    S("profile2", "PROFILE2_SELFTEST", SV + "profile/profile2_selftest.tscn", ["--profile2_selftest=1"]),
    S("look", "LOOK_SELFTEST", SV + "look/look_runner.tscn", ["--look_selftest=1"]),
    S("shop", "SHOP_SELFTEST", SV + "shop/shop_demo.tscn", ["--shop_selftest=1"]),
    S("auth", "AUTH_SELFTEST", SV + "auth/auth_dev.tscn",
      ["--auth_selftest=1", "--save=user://auth_selftest_save.json", "--save_wipe=1"]),
    S("clarity", "V10 CLARITY SELFTEST", SV + "clarity/clarity_selftest.tscn"),
    S("tutorial", "V10TUT", SV + "tutorial/tut_selftest.tscn",
      ["--save=user://tut_test.json", "--save_wipe=1", "--tut_static=1"]),
    S("juice", "JUICE SELFTEST", SV + "juice/demo/juice_demo.tscn", ["--juice_selftest=1"]),
    S("levels", "LEVELS SELFTEST", SV + "levels/levels_selftest.tscn", ["--levels_selftest=1"],
      fast_args=["--levels_selftest=1", "--levels_n=200"]),
    S("path", "PATH SELFTEST", SV + "path/path_demo.tscn", ["--path_selftest=1"], soft=r"map builds in <\d+ ms"),
    S("salon", "SALON_SELFTEST", SV + "salon/salon_runner.tscn", ["--salon_selftest=1"], fast=False),
    S("rituals", "RIT_SELFTEST", SV + "rituals/rituals_runner.tscn",
      ["--rit=selftest", "--save=user://rit_runner.json", "--save_wipe=1"]),
    S("chat", "CHAT SELFTEST", script=SV + "chat/chat_selftest_cli.gd"),
    S("phone", "PHONE SELFTEST", SV + "phone/phone_runner.tscn",
      ["--save=user://phone_st.json", "--save_wipe=1", "--phone_selftest=1"], render=True, res="720x1280"),
    S("gacha", "GACHA_SELFTEST", SV + "gacha/gacha_demo.tscn", ["--gacha_selftest=1"],
      fast_args=["--gacha_selftest=1", "--mc=0.5"]),
    S("rig", "RIG_SELFTEST", SV + "rig/rig_selftest.tscn"),
    S("voice", "V10VOICE OK", SV + "voice/v10_voice_selftest.tscn"),
    S("audio", "V10AUDIO", SV + "audio/v10_audio_selftest.tscn"),
    S("hudfx", "HUDFX SELFTEST", SV + "hudfx/hudfx_selftest.tscn", ["--hudfx_selftest=1"]),
    S("tower", "TOWER_SELFTEST", SV + "tower/tower_selftest.tscn", ["--tower_selftest=1"],
      fast_args=["--mods_selftest=1", "--pagoda_selftest=1", "--journey_selftest=1", "--tower_tables=1",
                 "--tower_rules=1", "--tower_hygiene=1"], timeout=600),
    S("mj_stage", "MJ_STAGE", SV + "mj/stage/stage_selftest.tscn", ["--mj_stage_selftest=1"]),
    S("mj_look", "MJ_LOOK", SV + "mj/look/look_selftest.tscn", ["--mj_look_selftest=1"], render=True, res="720x1280",
      soft=r"^FAIL perf\.", note="perf.144_le_16ms is a frame-time budget: fails on software GL (xvfb), ok on a GPU", fast=False),
    S("mj_triples", "MJ_TRIPLES", SV + "mj/triples/triples_selftest.tscn", ["--mj_triples_selftest=1"]),
    S("mj_riichi", "MJ_RIICHI", SV + "mj/riichi/riichi_selftest.tscn", ["--mj_riichi_selftest=1"],
      fast_args=["--mj_riichi_selftest=1", "--games=20"], timeout=900, fast=False),
    S("mj_sanma", "MJ_SANMA", SV + "mj/sanma/sanma_selftest.tscn", ["--mj_sanma_selftest=1"],
      fast_args=["--mj_sanma_selftest=1", "--games=20"], timeout=900, fast=False),
    S("mj_koikoi", "MJ_KOIKOI", SV + "mj/koikoi/koikoi_selftest.tscn", ["--mj_koikoi_selftest=1"],
      fast_args=["--mj_koikoi_selftest=1", "--games=100"], timeout=600),
    S("mj_classic", "MJ_CLASSIC", SV + "mj/classic/classic_selftest.tscn", ["--mj_classic_selftest=1"], fast=False),
    S("mj_connect", "MJ_CONNECT", SV + "mj/connect/connect_selftest.tscn", ["--mj_connect_selftest=1"], fast=False),
    S("mj_cube", "MJ_CUBE", SV + "mj/cube/cube_selftest.tscn", ["--mj_cube_selftest=1"]),
    S("mj_garden", "MJ_GARDEN", SV + "mj/garden/garden_selftest.tscn", ["--mj_garden_selftest=1"]),
    S("mj_bridge", "MJ_BRIDGE", SV + "mj/bridge/bridge_selftest.tscn", ["--mj_bridge_selftest=1"], fast=False),
    S("palm", "HAND_SELFTEST", SV + "palm/hand_selftest.tscn", ["--hand_selftest=1"],
      fast_args=["--hand_selftest=1", "--hand_real=24"]),
    S("duels", "DUEL_SELFTEST", SV + "duels/duel_selftest.tscn",
      ["--duel_selftest=1", "--save=user://duel_selftest.json", "--save_wipe=1"], fast=False),
    S("challenge", "CHALLENGE_SELFTEST", SV + "duels/challenge/challenge_selftest.tscn",
      ["--challenge_selftest=1", "--save=user://ch_selftest.json", "--save_wipe=1"], fast=False),
    S("wave1", "WAVE1_SELFTEST", SV + "wave1/wave1_selftest.tscn", ["--wave1_selftest=1"]),
    S("adventure", "ADVENTURE_SELFTEST", SV + "adventure/adventure_selftest.tscn", ["--adventure_selftest=1"]),
    S("online", "ONLINE_SELFTEST", SV + "online/online_selftest.tscn"),
    S("events", "EVENTS_SELFTEST", SV + "events/events_selftest.tscn"),
    S("tw_levels", "TW_LEVELS_SELFTEST", SV + "levels/tw_levels_selftest.tscn",
      note="TWLevels.at(n) is always a built level; trial cfg of levels 499/699/799/899/999 == the Path board (digest + real board)"),
    S("registry", "REGISTRY_SELFTEST", SV + "core/registry_selftest.tscn",
      note="V10Registry scan of game/core/**/module.gd: 43 legacy ids in order, no duplicates, no manifest errors"),
    # ---- extra: older suites that are not in the v10 registry ---------------------------------------
    S("spec", "SPECIAL SELFTEST", "res://scripts/v06/special/spec_selftest.tscn", group="extra"),
    S("summon", "SUMMON_SELFTEST", group="extra", render=True, res="720x1280",
      args=["--unlock=10", "--screen=summon", "--shots={shots}", "--at=1.5", "--act=selftest"],
      note="runs on the summon screen; needs a display because the dev shot hook saves a PNG"),
    S("ult_rin", "ULT SELFTEST rin", group="extra",
      args=["--screen=play", "--level=3", "--partner=rin", "--v9_ult_selftest=1"]),
    S("voice_registry", "VOICE_REGISTRY", group="extra", script="res://scripts/v10/voice/voice_registry_selftest.gd",
      note="P44: 240-line Beta-24 voice registry (schema, red-line stoplists, duration by kana, file map; VOICE_FILES share is informational)"),
]
BY_ID = {s.id: s for s in CATALOG}

# external (non-Godot) gates
EXTERNAL: list[Suite] = [
    Suite(id="server_e2e", kind="node", group="server", marker="E2E_OK", timeout=180, fast=True),
    Suite(id="ux_lint", kind="python", group="lint", marker="UX_LINT RESULT", timeout=120, fast=True),
    # game/core purity ratchet: selftest (6 synthetic files -> 6 findings) + violations vs tools/lint_baseline.json
    Suite(id="core_purity", kind="python", group="lint", marker="CORE_PURITY RESULT", timeout=60, fast=True,
          script="tools/lint_core_purity.py", args=["--selftest", "--check"]),
    Suite(id="battle_sim_v2", kind="python", group="lint", marker="[GATES]", timeout=120, fast=True, script="design/specs/sim/battle_sim.py", args=["--quick", "--check-gates"],
          note="P73: balance.json Variant A parity, W15 catch-up, T1-T8 twist spread, rules publication gate"),
    Suite(id="gen_stages", kind="python", group="lint", marker="GEN_STAGES VERIFY", timeout=60, fast=True, script="tools/gen_stages.py", args=["--selftest", "--verify"],
          note="P77: verify 60 stages x 3 seeds certified boards"),
    Suite(id="design_lint", kind="python", group="lint", marker="DESIGN_LINT RESULT", timeout=60, fast=True, script="tools/design_lint.py", args=["--selftest", "--check"],
          note="P93 W17: skins.json/shop.json <-> spec tables"),
    Suite(id="dashboards", kind="python", group="lint", marker="DASHBOARDS_SELFTEST", timeout=60, fast=True, script="tools/dashboards/test_dashboards.py", args=["--selftest"],
          note="P106: DB-01..DB-10"),
    Suite(id="export_filter", kind="python", group="lint", marker="EXPORT_FILTER SELFTEST", timeout=60, fast=True, script="tools/assets/export_filter.py", args=["--selftest"],
          note="P92: export filter selftest (--check-presets after export_presets.cfg is updated)"),
    # P19: the Path table is read through TWLevels.at(n) only; direct G.LEVELS[...] indexing is red
    Suite(id="no_direct_levels", kind="python", group="lint", marker="NO_DIRECT_LEVELS RESULT", timeout=60, fast=True,
          script="tools/lint_no_direct_levels.py", args=["--selftest", "--check"]),
    # P10: currency moves through TWWallet / V10Money only; a direct write of S.gems / coins / tickets / petals / moon is red
    Suite(id="no_direct_wallet", kind="python", group="lint", marker="NO_DIRECT_WALLET RESULT", timeout=60, fast=True,
          script="tools/lint_no_direct_wallet.py", args=["--selftest", "--check"],
          note="P10: 24 synthetic lines + 0 direct writes of the wallet mirrors under game/"),
    # P23: a screen folder without spec.tres / a TWScreen outside shell/screens / a bad or duplicate ScreenSpec is red
    Suite(id="screen_has_spec", kind="python", group="lint", marker="SCREEN_HAS_SPEC SELFTEST", timeout=60, fast=True,
          script="tools/lint_screen_has_spec.py", args=["--selftest", "--check"],
          note="SCREEN_HAS_SPEC: 7 synthetic trees + the repo has 0 violations"),
    # P24: modals only through the ModalStack: shell enforcing (0), legacy overlay scans counted as a ratchet (39 sites)
    Suite(id="modal_only_via_stack", kind="python", group="lint", marker="MODAL_ONLY_VIA_STACK SELFTEST", timeout=60, fast=True,
          script="tools/lint_modal_only_via_stack.py", args=["--selftest", "--check"],
          note="MODAL_ONLY_VIA_STACK: 14 synthetic cases + shell has 0 violations + legacy overlay-scan sites (report mode, 39) within tools/lint_modal_baseline.json"),
    # P29: assets are reached by id through TWAssets; a res://assets literal in game/shell is red, legacy literals are a ratchet
    Suite(id="asset_id_only", kind="python", group="lint", marker="ASSET_ID_ONLY SELFTEST", timeout=60, fast=True,
          script="tools/lint_asset_id_only.py", args=["--selftest", "--check"],
          note="ASSET_ID_ONLY: 13 synthetic cases + game/shell has 0 res://assets literals + legacy literals (report mode, 493) within tools/lint_asset_id_baseline.json"),
    # P37: the six slice screens x 3 sizes against game/tests/goldens (1.5 % of the pixels), rendered by the game under xvfb
    Suite(id="slice_goldens", kind="python", group="lint", marker="SLICE_GOLDENS", timeout=900, fast=False,
          script="tools/slice_goldens.py", args=[],
          note="P37: home/match/result/collection/wish/shop at 720x1280, 720x1600, 1536x2048 vs game/tests/goldens (<= 1.5 % of pixels differ); `python tools/slice_goldens.py --update` re-records"),
    # P37: 60-tile frame cost (headless + software GL) and the exported pack size
    Suite(id="perf_budget", kind="python", group="lint", marker="PERF_BUDGET", timeout=600, fast=False,
          script="tools/perf_budget.py", args=[],
          note="P37: p95 frame cost of a live 60-tile round <= 16.6 ms (headless and xvfb; device not verified) + the Android-store pack <= 135 MB (export-pack)"),
    # QA plan: tools/qa tool-belt (palette_audit on synthetic images, skin_lint + schema + 3 sample manifests, fuzz, ramps/schema in sync); numpy+Pillow optional (palette tests skip without them)
    Suite(id="qa_tools", kind="python", group="lint", marker="QA_TOOLS RESULT", timeout=120, fast=True,
          script="tools/qa/run_qa_tools.py",
          note="QA_TOOLS: unittest discover tools/qa + palette_ramps.json / skin schema in sync + skin_lint valid/invalid/missing-slot samples"),
    # P45: loudness meter self-test on synthetic signals (python + numpy + ffmpeg; the corpus scan is a separate CLI run)
    Suite(id="audio_gate", kind="python", group="lint", marker="AUDIO_GATE SELFTEST", timeout=120, fast=True,
          script="tools/audio/lufs_gate.py", args=["--selftest", "--no-write"],
          note="BS.1770 meter vs 12 reference signals (<=0.3 LU), true peak, leading silence, verdict rules"),
]
for _s in EXTERNAL:
    BY_ID[_s.id] = _s
ALL_SUITES = CATALOG + EXTERNAL


# --------------------------------------------------------------------------------------------------
# result model
# --------------------------------------------------------------------------------------------------
@dataclass
class Result:
    id: str
    status: str = "error"          # pass | fail | timeout | skip | error
    ok: int | None = None
    total: int | None = None
    marker_line: str = ""
    failures: list = field(default_factory=list)   # normalised failure ids
    script_errors: int = 0
    soft: list = field(default_factory=list)       # timing-noise failures that do not turn the suite red
    rc: int | None = None
    secs: float = 0.0
    reason: str = ""
    log: str = ""
    verdict: str = ""              # filled by compare(): ok | known-fail | REGRESSION | improved | new


def norm_fail(line: str) -> str:
    """Stable id for a failure line: strip timestamps/ordinals that change between runs."""
    t = ANSI_RE.sub("", line).strip()
    t = re.sub(r"\(\d+\)\s*$", "", t)           # trailing "(58)" seed / index
    t = re.sub(r"\[[^\]]*\]", "[..]", t)         # lists whose order/content jitters ("type sizes [44, 18]")
    t = re.sub(r"\b\d+\.\d+\b", "N", t)         # measured floats (17.53 ms)
    t = re.sub(r"\b\d{4,}\b", "N", t)          # long numbers (seeds, ms)
    return t[:160]


RATIO_RE = re.compile(r"(\d+)\s*/\s*(\d+)")
FAIL_RE = re.compile(r"\bFAIL(?:ED|URE)?\b")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def parse_output(suite: Suite, text: str, rc: int | None, timed_out: bool) -> Result:
    r = Result(id=suite.id, rc=rc)
    text = ANSI_RE.sub("", text)
    lines = [ln.rstrip("\r") for ln in text.split("\n")]
    marker_line = ""
    marker_idx = -1
    low = suite.marker.lower()
    for idx, ln in enumerate(lines):
        if low in ln.lower():
            marker_idx = idx
            marker_line = ln.strip()
    r.marker_line = marker_line
    # failure ids: FAIL lines and SCRIPT ERROR lines. The marker summary line itself ("X 12/13") is not a
    # failure line unless it says FAIL.
    fails = []
    for ln in lines:
        s = ln.strip()
        if FAIL_RE.search(s) and not s.startswith("at:"):
            fails.append(norm_fail(s))
    serr = [norm_fail(ln) for ln in lines if "SCRIPT ERROR:" in ln]   # P96/T19: anywhere, incl. teardown
    r.script_errors = len(serr)
    if suite.soft:
        soft_re = re.compile(suite.soft)
        r.soft = sorted({f for f in fails if soft_re.search(f)})
        fails = [f for f in fails if not soft_re.search(f)]
    n_soft = sum(1 for ln in lines if suite.soft and FAIL_RE.search(ln) and re.search(suite.soft, norm_fail(ln)))
    r.failures = sorted(set(fails) | set(serr))
    if marker_line:
        tail = marker_line[marker_line.lower().find(low) + len(low):]
        m = RATIO_RE.search(tail)
        if m:
            r.ok, r.total = int(m.group(1)), int(m.group(2))
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    if not marker_line:
        r.status, r.reason = "error", f"no marker line '{suite.marker}'"
        return r
    bad_ratio = r.ok is not None and (r.total - r.ok > n_soft or r.total == 0)
    marker_green = (marker_idx >= 0) and not bad_ratio and not r.failures and not FAIL_RE.search(marker_line)   # P96/T19
    rc_ok = rc == 0 or (rc in TEARDOWN_RCS and marker_green and not serr)
    if rc_ok and NO_MASK_RC and rc not in (0, *KNOWN_ABORT_RCS):
        rc_ok = False
    if bad_ratio or r.failures or not rc_ok:
        r.status = "fail"
        if not rc_ok:
            r.reason = f"rc={rc}"
    else:
        r.status = "pass"
    return r


# --------------------------------------------------------------------------------------------------
# process plumbing
# --------------------------------------------------------------------------------------------------
def find_godot(explicit: str | None) -> str | None:
    for c in (explicit, os.environ.get("GODOT_BIN")):
        if c and Path(c).exists():
            return str(c)
    for n in ("godot4", "godot", "Godot_v4.5.1-stable_linux.x86_64", "Godot_v4.5.1-stable_win64_console.exe"):
        p = shutil.which(n)
        if p:
            return p
    return None


def clean_env(tmp: Path) -> dict:
    """Per-run isolated user dir so parallel suites never share user:// saves or caches."""
    env = dict(os.environ)
    h = tmp / "home"
    h.mkdir(parents=True, exist_ok=True)
    hs = str(h)
    env.update(HOME=hs, USERPROFILE=hs, APPDATA=hs, LOCALAPPDATA=hs, XDG_DATA_HOME=hs + "/.local/share",
               XDG_CONFIG_HOME=hs + "/.config", XDG_CACHE_HOME=hs + "/.cache")
    return env


def have_display() -> bool:
    return WIN or sys.platform == "darwin" or bool(os.environ.get("DISPLAY"))


def kill_tree(p: subprocess.Popen):
    try:
        if WIN:
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        else:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)
    except Exception:
        try:
            p.kill()
        except Exception:
            pass


def run_cmd(cmd: list, env: dict, timeout: float, cwd: Path | None = None):
    t0 = time.time()
    kw = {}
    if not WIN:
        kw["start_new_session"] = True
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, cwd=cwd, **kw)
    timed_out = False
    try:
        out, _ = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        kill_tree(p)
        try:
            out, _ = p.communicate(timeout=10)
        except Exception:
            out = b""
    return p.returncode, out.decode("utf-8", "replace"), timed_out, time.time() - t0


def godot_cmd(godot: str, suite: Suite, fast: bool, shots: Path, extra_godot: list) -> list:
    cmd = []
    if suite.render and not have_display() and shutil.which("xvfb-run"):
        cmd += ["xvfb-run", "-a", "-s", "-screen 0 1600x2700x24"]
    cmd.append(godot)
    if suite.render:
        cmd += ["--rendering-driver", "opengl3"]
        if suite.res:
            cmd += ["--resolution", suite.res]
    else:
        cmd += ["--headless"]
    cmd += ["--audio-driver", "Dummy", "--path", str(GAME)] + extra_godot
    if suite.script:
        cmd += ["-s", suite.script]
    elif suite.scene:
        cmd.append(suite.scene)
    ua = suite.fast_args if (fast and suite.fast_args is not None) else suite.args
    if ua:
        cmd.append("--")
        cmd += [a.replace("{shots}", str(shots).replace("\\", "/")) for a in ua]
    return cmd


def run_suite(suite: Suite, godot: str | None, fast: bool, tscale: float, logdir: Path, extra_godot: list) -> Result:
    timeout = suite.timeout * tscale
    with tempfile.TemporaryDirectory(prefix=f"tw_{suite.id}_") as td:
        tmp = Path(td)
        env = clean_env(tmp)
        shots = tmp / "shots"
        shots.mkdir()
        if suite.kind == "godot":
            if not godot:
                return Result(suite.id, "skip", reason="no Godot binary (set --godot / GODOT_BIN)")
            if suite.render and not have_display() and not shutil.which("xvfb-run"):
                return Result(suite.id, "skip", reason="needs a display and xvfb-run is not installed")
            cmd = godot_cmd(godot, suite, fast, shots, extra_godot)
        elif suite.kind == "node":
            node = shutil.which("node")
            if not node:
                return Result(suite.id, "skip", reason="node not found")
            cmd = [node, str(E2E)]
        elif suite.script:
            sp = REPO / suite.script
            if not sp.exists():
                return Result(suite.id, "error", reason=f"missing {suite.script}")
            if suite.id == "audio_gate" and not (shutil.which("ffmpeg") and shutil.which("ffprobe")):
                return Result(suite.id, "skip", reason="ffmpeg/ffprobe not found")
            cmd = [sys.executable, str(sp)] + list(suite.args)
        else:
            tool = REPO / suite.script if suite.script else UX_LINT
            if not tool.exists():
                return Result(suite.id, "error", reason=f"missing {tool.relative_to(REPO)}")
            cmd = [sys.executable, str(tool)] + list(suite.args)
        # node's e2e spawns a server with its own temp db; keep cwd at the repo root for the lint paths
        rc, out, timed_out, secs = run_cmd(cmd, env, timeout, cwd=REPO)
    if suite.kind == "node":
        res = parse_node(suite, out, rc, timed_out)
    elif suite.kind == "python" and suite.id == "core_purity":
        res = parse_purity(suite, out, rc, timed_out)
    elif suite.kind == "python" and suite.id == "no_direct_levels":
        res = parse_nodl(suite, out, rc, timed_out)
    elif suite.kind == "python" and suite.id == "no_direct_wallet":
        res = parse_nodw(suite, out, rc, timed_out)
    elif suite.kind == "python" and not suite.script:
        res = parse_lint(suite, out, rc, timed_out)
    else:
        res = parse_output(suite, out, rc, timed_out)
    res.secs = round(secs, 1)
    logdir.mkdir(parents=True, exist_ok=True)
    lp = logdir / f"{suite.id}.log"
    lp.write_text("CMD: " + " ".join(map(str, cmd)) + f"\nRC: {rc}\n\n" + out, encoding="utf-8")
    res.log = str(lp)
    return res


def parse_node(suite: Suite, out: str, rc, timed_out) -> Result:
    r = Result(suite.id, rc=rc)
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    if "ERR_UNKNOWN_BUILTIN_MODULE" in out and "sqlite" in out:
        r.status, r.reason = "skip", "node build lacks node:sqlite (server needs node >= 22.5, engines says 24)"
        return r
    m = re.search(r"(\d+) passed, (\d+) failed", out)
    if m:
        r.ok, r.total = int(m.group(1)), int(m.group(1)) + int(m.group(2))
    r.failures = sorted({norm_fail(ln) for ln in out.split("\n") if ln.strip().startswith("FAIL")})
    r.marker_line = "E2E_OK" if "E2E_OK" in out else (m.group(0) if m else "")
    r.status = "pass" if (rc == 0 and "E2E_OK" in out and not r.failures) else "fail"
    return r


def parse_lint(suite: Suite, out: str, rc, timed_out) -> Result:
    r = Result(suite.id, rc=rc)
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    m = re.search(r"UX_LINT RESULT: (\w+) \((\d+) violations?\)", out)
    r.marker_line = m.group(0) if m else ""
    n = int(m.group(2)) if m else 0
    # failures = the violation table rows with a non-zero count, so baseline can name them
    r.failures = sorted({f"{row[0]} x{row[1]}" for row in re.findall(r"\|\s*([A-Z_]+)\s*\|\s*([1-9]\d*)\s*\|", out)})
    if not m:
        r.status, r.reason = "error", "no 'UX_LINT RESULT' line"
    else:
        r.status = "pass" if (rc == 0 and n == 0) else "fail"
    return r


def parse_nodl(suite: Suite, out: str, rc, timed_out) -> Result:
    """tools/lint_no_direct_levels.py --selftest --check: green = selftest k/k AND 0 direct G.LEVELS[...] sites."""
    r = Result(suite.id, rc=rc)
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    m = re.search(r"NO_DIRECT_LEVELS RESULT: (PASS|FAIL) \((\d+) violations\)", out)
    st = re.search(r"NO_DIRECT_LEVELS SELFTEST: (\d+)/(\d+) (PASS|FAIL)", out)
    r.marker_line = m.group(0) if m else ""
    if st:
        r.ok, r.total = int(st.group(1)), int(st.group(2))
    r.failures = sorted({norm_fail(ln) for ln in out.split("\n") if re.match(r"game/\S+:\d+: (INDEX|ALIAS)", ln)})
    if not m or not st:
        r.status, r.reason = "error", "missing 'NO_DIRECT_LEVELS RESULT' / 'NO_DIRECT_LEVELS SELFTEST' line"
    else:
        r.status = "pass" if (rc == 0 and m.group(1) == "PASS" and st.group(3) == "PASS") else "fail"
        r.reason = f"{m.group(2)} direct G.LEVELS[...] sites" if r.status != "pass" else ""
    return r


def parse_nodw(suite: Suite, out: str, rc, timed_out) -> Result:
    """tools/lint_no_direct_wallet.py --selftest --check: green = selftest k/k AND 0 direct writes of the wallet mirrors."""
    r = Result(suite.id, rc=rc)
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    m = re.search(r"NO_DIRECT_WALLET RESULT: (PASS|FAIL) \((\d+) violations", out)
    st = re.search(r"NO_DIRECT_WALLET SELFTEST: (\d+)/(\d+) (PASS|FAIL)", out)
    r.marker_line = m.group(0) if m else ""
    if st:
        r.ok, r.total = int(st.group(1)), int(st.group(2))
    r.failures = sorted({norm_fail(ln) for ln in out.split("\n") if re.match(r"game/\S+:\d+: (FIELD|DYN)", ln)})
    if not m or not st:
        r.status, r.reason = "error", "missing 'NO_DIRECT_WALLET RESULT' / 'NO_DIRECT_WALLET SELFTEST' line"
    else:
        r.status = "pass" if (rc == 0 and m.group(1) == "PASS" and st.group(3) == "PASS") else "fail"
        r.reason = f"{m.group(2)} direct wallet writes" if r.status != "pass" else ""
    return r


def parse_purity(suite: Suite, out: str, rc, timed_out) -> Result:
    """tools/lint_core_purity.py --selftest --check: green = selftest 6/6 AND no new violations vs lint_baseline.json."""
    r = Result(suite.id, rc=rc)
    if timed_out:
        r.status, r.reason = "timeout", "no exit within the limit"
        return r
    m = re.search(r"CORE_PURITY RESULT: (PASS|FAIL) \((\d+) violations, baseline (\d+), \+(\d+) new\)", out)
    st = re.search(r"CORE_PURITY SELFTEST: (\d+)/(\d+) (PASS|FAIL)", out)
    r.marker_line = m.group(0) if m else ""
    if st:
        r.ok, r.total = int(st.group(1)), int(st.group(2))
    r.failures = sorted({norm_fail(ln) for ln in out.split("\n") if ln.startswith(("NEW VIOLATION", "SELFTEST FAIL"))})
    if not m or not st:
        r.status, r.reason = "error", "missing 'CORE_PURITY RESULT' / 'CORE_PURITY SELFTEST' line"
    else:
        r.status = "pass" if (rc == 0 and m.group(1) == "PASS" and st.group(3) == "PASS") else "fail"
        r.reason = f"{m.group(2)} violations, baseline {m.group(3)}" if r.status != "pass" else ""
    return r


# --------------------------------------------------------------------------------------------------
# baseline
# --------------------------------------------------------------------------------------------------
def load_baseline(path: Path | None = None) -> dict:
    path = path or BASELINE_PATH
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"version": 1, "suites": {}}


def baseline_entry(r: Result) -> dict:
    e = {"status": r.status, "secs": r.secs}
    if r.ok is not None:
        e["ok"], e["total"] = r.ok, r.total
    if r.failures:
        e["expected_fail"] = r.failures
    if r.marker_line:
        e["marker"] = r.marker_line[:120]
    return e


def compare(r: Result, base: dict, fast: bool) -> None:
    mode = "fast" if fast else "full"
    entries = base.get("suites", {}).get(r.id, {})
    entry = entries.get(mode)
    counts_comparable = True
    if entry is None and fast:
        # fast counts differ from full counts: compare status / known failures against the full entry only
        entry = entries.get("full")
        counts_comparable = False
    if r.status == "skip":
        r.verdict = "skip"
        return
    if entry is None:
        r.verdict = "new" if r.status == "pass" else "REGRESSION"
        r.reason = r.reason or ("not in baseline" if r.status == "pass" else "new suite is red")
        return
    exp = set(entry.get("expected_fail", []))
    new_fail = sorted(set(r.failures) - exp)
    if entry["status"] == "pass" and r.status != "pass":
        r.verdict, r.reason = "REGRESSION", f"was pass, now {r.status}" + (f" ({r.reason})" if r.reason else "")
        return
    if entry["status"] != "pass" and r.status in ("timeout", "error"):
        r.verdict, r.reason = "REGRESSION", f"baseline {entry['status']} but now {r.status} ({r.reason})"
        return
    if new_fail:
        r.verdict, r.reason = "REGRESSION", f"new failure(s): {new_fail[:3]}"
        return
    if counts_comparable and r.ok is not None and entry.get("ok") is not None:
        if r.total is not None and r.total < entry["total"]:
            r.verdict, r.reason = "REGRESSION", f"total shrank {entry['total']} -> {r.total} (checks removed?)"
            return
        if r.ok < entry["ok"]:
            r.verdict, r.reason = "REGRESSION", f"ok dropped {entry['ok']} -> {r.ok}"
            return
        if r.ok > entry["ok"] or (r.total or 0) > entry["total"]:
            r.verdict = "improved"
            return
    if r.status == "pass" and entry["status"] != "pass":
        r.verdict = "improved"
    elif r.status == "pass":
        r.verdict = "ok"
    else:
        r.verdict = "known-fail"


# --------------------------------------------------------------------------------------------------
# drift check: registry modules that the catalog does not know
# --------------------------------------------------------------------------------------------------
def registry_manifests() -> list[tuple[int, str, Path, bool]]:
    """(order, id, module.gd, has_selftest) for every game/core/**/module.gd, in V10Registry order (order, id)."""
    out = []
    for f in sorted(CORE_DIR.rglob("module.gd")):
        txt = f.read_text(encoding="utf-8")
        mi = re.search(r'"id":\s*"(\w+)"', txt)
        mo = re.search(r'"order":\s*(\d+)', txt)
        if not mi:
            continue
        out.append((int(mo.group(1)) if mo else 1000, mi.group(1), f, '"selftest"' in txt))
    return sorted(out, key=lambda t: (t[0], t[1]))


def registry_ids() -> list[str]:
    return [rid for _o, rid, _f, st in registry_manifests() if st]


def check_drift() -> list[str]:
    cat = {s.id for s in CATALOG}
    alias = {"profile": "profile2"}  # registry id 'profile' runs profile2_selftest.tscn
    miss = [rid for rid in registry_ids() if alias.get(rid, rid) not in cat]
    ids = [rid for _o, rid, _f, _st in registry_manifests()]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    return miss + [f"duplicate module id {d}" for d in dup]


# --------------------------------------------------------------------------------------------------
# helper commands
# --------------------------------------------------------------------------------------------------
def do_import(godot: str, timeout: int) -> int:
    with tempfile.TemporaryDirectory(prefix="tw_import_") as td:
        env = clean_env(Path(td))
        rc, out, to, secs = run_cmd([godot, "--headless", "--audio-driver", "Dummy", "--path", str(GAME), "--import"],
                                    env, timeout)
    bad = to or "SCRIPT ERROR:" in out or rc not in (0, *TEARDOWN_RCS)
    print(f"[tw_test] import {'FAILED' if bad else 'OK'} ({secs:.0f}s, rc={rc})")
    if bad:
        print(out[-3000:])
    return 1 if bad else 0


def do_registry_dump(godot: str, dest: str, timeout: int) -> int:
    """Run the registry selftest scene in dump mode: ids in order + every spec (Callables as "<fn>"), depth graph,
    screens, ensure_all keys, wiring flags. Diff two dumps to prove a registry refactor changed nothing."""
    with tempfile.TemporaryDirectory(prefix="tw_regdump_") as td:
        env = clean_env(Path(td))
        rc, out, to, secs = run_cmd([godot, "--headless", "--audio-driver", "Dummy", "--path", str(GAME),
                                     "res://scripts/v10/core/registry_selftest.tscn", "--", "--registry_dump=1"], env, timeout)
    m = re.search(r"REGISTRY_DUMP_BEGIN\n(.*)\nREGISTRY_DUMP_END", out, re.S)
    if to or not m:
        print(out[-3000:])
        print("[tw_test] registry dump FAILED")
        return 1
    if dest == "-":
        print(m.group(1))
    else:
        Path(dest).write_text(m.group(1) + "\n", encoding="utf-8")
        print(f"[tw_test] registry dump written to {dest} ({secs:.0f}s)")
    return 0


def do_shot(godot: str, screen: str, out_png: Path, res: str, at: float, act: str, timeout: int) -> int:
    with tempfile.TemporaryDirectory(prefix="tw_shot_") as td:
        tmp = Path(td)
        env = clean_env(tmp)
        shots = tmp / "shots"
        shots.mkdir()
        cmd = []
        if not have_display() and shutil.which("xvfb-run"):
            cmd += ["xvfb-run", "-a", "-s", "-screen 0 1600x2700x24"]
        cmd += [godot, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", res,
                "--path", str(GAME), "--", "--splash=1" if screen in ("splash", "title") else f"--screen={screen}",
                "--shots=" + str(shots).replace("\\", "/"), "--name=capture", f"--at={at}", "--unlock=50",
                "--save=user://qa_shot_save.json", "--save_wipe=1", "--story_off=1"]
        if act:
            cmd.append(f"--act={act}")
        rc, out, to, secs = run_cmd(cmd, env, timeout)
        png = shots / "capture_0.png"
        if png.exists():
            out_png.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(png, out_png)
            print(f"[tw_test] screenshot OK: {out_png} ({png.stat().st_size // 1024} KB, {secs:.0f}s)")
            return 0
    print(f"[tw_test] screenshot FAILED (rc={rc})\n{out[-2000:]}")
    return 1


# --------------------------------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------------------------------
MAX_DEFAULT_JOBS = 4  # see tools/README.md "Parallelism": j=cores was fastest without flakes; j=6 on 4 cores flaked a timing check


def default_jobs() -> int:
    return max(1, min(MAX_DEFAULT_JOBS, os.cpu_count() or 1))


def select(args) -> list[Suite]:
    if args.suites:
        out = []
        for tok in args.suites.split(","):
            t = tok.strip().lower().removeprefix("--").split("=")[0]
            if t in ("all", ""):
                out += ALL_SUITES
            elif t in ("core", "v10", "extra", "server", "lint"):
                out += [s for s in ALL_SUITES if s.group == t]
            else:
                cand = t[:-len("_selftest")] if t.endswith("_selftest") else t
                if cand not in BY_ID:
                    raise SystemExit(f"unknown suite '{tok}'. --list shows ids.")
                out.append(BY_ID[cand])
        seen, res = set(), []
        for s in out:
            if s.id not in seen:
                seen.add(s.id)
                res.append(s)
        return res
    sel = [s for s in ALL_SUITES if s.fast] if args.fast else list(ALL_SUITES)
    if args.skip:
        skip = {x.strip() for x in args.skip.split(",")}
        sel = [s for s in sel if s.id not in skip and s.group not in skip]
    return sel


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Tile Waifu QA runner (selftests + server e2e + ux lint)")
    ap.add_argument("-s", "--suites", help="comma list of suite ids / groups (core,v10,extra,server,lint) / all")
    ap.add_argument("--fast", action="store_true", help="agent subset with cheap Monte-Carlo counts")
    ap.add_argument("--skip", help="comma list of ids/groups to leave out")
    ap.add_argument("-j", "--jobs", type=int, default=0, help=f"parallel workers (default {default_jobs()} here)")
    ap.add_argument("--godot", help="Godot 4.5.1 binary (else $GODOT_BIN, else PATH)")
    ap.add_argument("--timeout-scale", type=float, default=1.0, help="multiply every suite timeout")
    ap.add_argument("--list", action="store_true", help="list suites and exit")
    ap.add_argument("--baseline", help="baseline file to compare with / update (default tools/baseline.json)")
    ap.add_argument("--no-baseline", action="store_true", help="do not compare with tools/baseline.json (fail on any red)")
    ap.add_argument("--update-baseline", action="store_true", help="write this run's results into tools/baseline.json")
    ap.add_argument("--strict", action="store_true", help="fail on known failures too (same as --no-baseline)")
    ap.add_argument("--json", help="write full results to this file")
    ap.add_argument("--logs", help="directory for per-suite logs (default: <tmp>/tw_test_logs)")
    ap.add_argument("--import", dest="do_import", action="store_true", help="run headless asset import and exit")
    ap.add_argument("--clean-import", action="store_true", help="git checkout tracked *.import churn and exit")
    ap.add_argument("--shot", help="capture screen <name> to --out and exit")
    ap.add_argument("--out", help="png path for --shot")
    ap.add_argument("--res", default="450x1000")
    ap.add_argument("--at", type=float, default=2.0)
    ap.add_argument("--act", default="")
    ap.add_argument("--check-drift", action="store_true", help="verify the catalog covers every V10Registry selftest")
    ap.add_argument("--registry-dump", nargs="?", const="-", metavar="FILE",
                    help="print (or write to FILE) the canonical JSON dump of the whole V10Registry and exit")
    ap.add_argument("--no-mask-rc", action="store_true",
                    help="fail a suite on any exit code except 0 and the known teardown SIGABRT (134 / -6); default masks 139/-11/0xC0000005 too")
    ap.add_argument("--godot-arg", action="append", default=[], help="extra engine arg (before --), repeatable")
    args = ap.parse_args(argv)
    global NO_MASK_RC
    NO_MASK_RC = args.no_mask_rc

    if args.list:
        print(f"{'ID':<12} {'GROUP':<7} {'FAST':<5} {'RENDER':<6} {'TIMEOUT':>7}  MARKER")
        for s in ALL_SUITES:
            print(f"{s.id:<12} {s.group:<7} {'yes' if s.fast else '':<5} {'yes' if s.render else '':<6} {s.timeout:>7}  {s.marker}")
        print(f"\n{len(ALL_SUITES)} suites ({len(CATALOG)} godot, {len(EXTERNAL)} external); "
              f"fast subset: {sum(1 for s in ALL_SUITES if s.fast)}")
        return 0
    if args.check_drift:
        miss = check_drift()
        print("registry modules missing from tools/tw_test.py:", miss or "none")
        return 1 if miss else 0
    if args.clean_import:
        d = subprocess.run(["git", "-C", str(REPO), "diff", "--name-only", "--", "*.import"],
                           capture_output=True, text=True).stdout.split()
        if d:
            subprocess.run(["git", "-C", str(REPO), "checkout", "--", "*.import"], check=True)
        print(f"[tw_test] restored {len(d)} tracked *.import file(s)")
        return 0

    godot = find_godot(args.godot)
    if args.do_import:
        if not godot:
            print("Godot binary not found", file=sys.stderr)
            return 2
        return do_import(godot, int(600 * args.timeout_scale))
    if args.registry_dump:
        if not godot:
            print("Godot binary not found", file=sys.stderr)
            return 2
        return do_registry_dump(godot, args.registry_dump, int(300 * args.timeout_scale))
    if args.shot:
        if not godot or not args.out:
            print("--shot needs a Godot binary and --out", file=sys.stderr)
            return 2
        return do_shot(godot, args.shot, Path(args.out), args.res, args.at, args.act, int(300 * args.timeout_scale))

    suites = select(args)
    if any(s.kind == "godot" for s in suites):
        if not godot:
            print("Godot binary not found: pass --godot PATH or set GODOT_BIN", file=sys.stderr)
            return 2
        if not (GAME / ".godot" / "global_script_class_cache.cfg").exists():
            print("[tw_test] game/.godot missing: running the asset import first (one-off, ~2 min)")
            if do_import(godot, int(900 * args.timeout_scale)) != 0:
                return 2

    jobs = args.jobs or default_jobs()
    bpath = Path(args.baseline) if args.baseline else BASELINE_PATH
    base = load_baseline(bpath)
    logdir = Path(args.logs) if args.logs else Path(tempfile.gettempdir()) / "tw_test_logs"
    mode = "fast" if args.fast else "full"

    def weight(s: Suite) -> float:  # longest first, using recorded timings, so the pool finishes together
        return -float(base.get("suites", {}).get(s.id, {}).get(mode, {}).get("secs", s.timeout / 10))

    order = sorted(suites, key=weight)
    print(f"[tw_test] {len(order)} suite(s), mode={mode}, jobs={jobs}, godot={godot}", flush=True)
    results: dict[str, Result] = {}
    lock = threading.Lock()
    t0 = time.time()

    def work(s: Suite) -> Result:
        r = run_suite(s, godot, args.fast, args.timeout_scale, logdir, args.godot_arg)
        with lock:
            results[s.id] = r
            cnt = f" {r.ok}/{r.total}" if r.ok is not None else ""
            print(f"  [{len(results):>2}/{len(order)}] {s.id:<11} {r.status.upper():<7}{cnt:<12} {r.secs:>6.1f}s  {r.reason}", flush=True)
        return r

    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        list(ex.map(work, order))
    wall = time.time() - t0

    for s in suites:
        compare(results[s.id], base, args.fast)

    print(f"\n{'suite':<12} {'status':<8} {'ok/total':<12} {'secs':>6}  {'verdict':<11} marker / reason")
    print("-" * 110)
    for s in suites:
        r = results[s.id]
        cnt = f"{r.ok}/{r.total}" if r.ok is not None else "-"
        print(f"{s.id:<12} {r.status:<8} {cnt:<12} {r.secs:>6.1f}  {r.verdict:<11} {(r.reason or r.marker_line)[:70]}")
    rs = [results[s.id] for s in suites]
    reg = [r for r in rs if r.verdict == "REGRESSION"]
    n_pass = sum(1 for r in rs if r.status == "pass")
    n_skip = sum(1 for r in rs if r.status == "skip")
    known = [r.id for r in rs if r.verdict == "known-fail"]
    improved = [r.id for r in rs if r.verdict == "improved"]
    print(f"\n[tw_test] {n_pass}/{len(rs)} pass, {n_skip} skipped, known-fail {known or 'none'}, "
          f"improved {improved or 'none'}, wall {wall:.0f}s (j={jobs}); logs: {logdir}")

    if args.json:
        Path(args.json).write_text(json.dumps({"mode": mode, "jobs": jobs, "wall": round(wall, 1),
                                               "results": [r.__dict__ for r in rs]},
                                              ensure_ascii=False, indent=1), encoding="utf-8")
    if args.update_baseline:
        base.setdefault("suites", {})
        base["version"] = 1
        base["godot"] = "4.5.1-stable"
        base["updated"] = time.strftime("%Y-%m-%d")
        for r in rs:
            if r.status != "skip":
                base["suites"].setdefault(r.id, {})[mode] = baseline_entry(r)
        bpath.write_text(json.dumps(base, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"[tw_test] baseline updated: {bpath} ({mode})")
        return 0
    if args.no_baseline or args.strict:
        bad = [r.id for r in rs if r.status not in ("pass", "skip")]
        if bad:
            print("[tw_test] FAIL (strict):", ", ".join(bad))
            return 1
        return 0
    if reg:
        print("[tw_test] REGRESSION vs baseline:")
        for r in reg:
            print(f"   {r.id}: {r.reason}   (log {r.log})")
        return 1
    print("[tw_test] no regression vs baseline")
    return 0


if __name__ == "__main__":
    sys.exit(main())
