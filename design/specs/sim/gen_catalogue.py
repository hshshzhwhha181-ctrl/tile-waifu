#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates design/specs/ULT_CATALOGUE.md, design/specs/ult_catalogue.json, sim/_gen_heroine_tables.md and splices
sections 8.0-9.8 of design/specs/BATTLE_ULT_SPEC.md (between the GEN:HEROINES markers).
Sources: ult_data_heroes.py (10 signature ults, roles, auras) and ult_data_rows.py (tiers, VOW, S, SSR, SSR+ rows).
Run:  python3 gen_catalogue.py      (no arguments; fails the build on any inconsistency)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ult_data_heroes as H
import ult_data_rows as R

OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
REMASTER = 0.6      # BASE ults of the 10 launch heroines already have a legacy .ogv: 60 % of the full cost
REROLL = 1.3        # credits buffer for re-rolls (docs/ROSTER_20.md 5.2)
THEMES = ("SAKURA", "MOON", "JADE", "EMBER", "TIDE", "NEON", "INK", "GILT")
HERO_RAMP = ("H100", "H300", "H500", "H700", "H900")
SHARED_SFX = ["ult_ring_pop", "ult_trigger_stamp", "ult_whoosh_in", "ult_cloth_snap", "ult_step_heel", "ult_inhale", "ult_hit_low",
              "ult_hit_high", "ult_sweep_fx", "ult_board_resolve", "ult_tail_air", "ult_skip_swish", "ult_assist_pop"]
INSERT_SFX = ["ult_blink_tick", "ult_tile_glow", "ult_cup_set", "ult_fan_open", "ult_data_burst", "ult_kunai_spin", "ult_cookie_toss",
              "ult_bell_suzu", "ult_coin_chime", "ult_feather_ignite"]
SKIN_TIER_CODE = {"BASE": "base", "VOW": "vow", "S": "s", "SSR": "ssr", "SSRP": "ssrp"}
STATS = {"BASE": (0.0, 0.0), "VOW": (0.0, 0.0), "S": (0.04, 0.010), "SSR": (0.08, 0.020), "SSRP": (0.10, 0.025)}


def tokens_json():
    p = os.path.abspath(os.path.join(OUT, "..", "..", "game", "shell", "design", "tokens.json"))
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def token_ok(tok, tokens):
    """PALETTE_LOCK grammar: <hero>.H100..H900 | <THEME>.T1..T5 | NIGHT_*/PAPER_* (neutrals) [@alpha]."""
    tok = tok.split("@")[0]
    if "." in tok:
        a, b = tok.split(".")
        if a in tokens["heroes"] and b in HERO_RAMP:
            return True
        if a in THEMES and b in ("T1", "T2", "T3", "T4", "T5"):
            return True
        return False
    return tok in tokens["color"] and (tok.startswith("NIGHT_") or tok.startswith("PAPER_"))


def asset_list(r):
    t = R.TIER[r["tier"]]
    base = "skins/%s/%s/ult/" % (r["hero"], r["id"])
    a = []
    for i in range(1, t["poses"] + 1):
        a.append(base + "pose_%d.webp (1024x1536, <=170 KB; общий с art/ скина, если совпадает с card/splash/ult_key)" % i)
    for i in range(1, t["plates"] + 1):
        a.append(base + "plate_%d.ogv (540x960, 24 fps, Theora q6, <=0.9 MB; шот ult_full.ogv скина)" % i)
    a.append(base + "timeline.json (cue sheet, spec 7.4)")
    a.append(base + "vfx_preset.json (tokens only, spec 5.5)")
    a.append("skins/%s/%s/voice/ %d x ogg mono q4 (JP) + RU subtitles in registry" % (r["hero"], r["id"], len(r["voice_cues"])))
    a.append(base + "gallery_thumb.webp (512x768)")
    if r["tier"] in ("SSR", "SSRP"):
        a.append(base + "gallery_splash.webp (1080x1620)")
    if r["tier"] == "SSRP":
        a.append(base + "takeover.json (+ bg/riichi_rim.webp скина) - скин стола 6 с")
    return a


def row(**kw):
    kw.setdefault("beats", None)
    return kw


def build_rows():
    rows = []
    for hero, hem, legacy, vid, season in R.BASE_ROWS:
        d = H.BASE[hero]
        rows.append(row(id="%s_base" % hero, hero=hero, tier="BASE", slot="base", name_ru=d["name_ru"], name_jp=d["name_jp"], season=season,
                        legacy_outfit=legacy, legacy_video=vid, hem_class=hem, twist="", theme=None, concept=d["concept"], vfx=d["vfx"], heat=d["heat"],
                        voice=d["voice"], poses=d["poses"], beats=d["beats"]))
    for hero, (nm, jp, concept, lines) in R.VOW.items():
        d = H.BASE[hero]
        rows.append(row(id="%s_vow" % hero, hero=hero, tier="VOW", slot="vow", name_ru=nm, name_jp=jp, season="S1",
                        legacy_outfit={"kohaku": "ko_vow", "zlata": "zl_vow"}.get(hero, ""), legacy_video="", hem_class="long", twist="", theme=None, concept=concept,
                        vfx=[d["vfx"][0], d["vfx"][1], "PAPER_100", "NIGHT_900"], heat="мягкий рассвет, тёплый пар, без вспышек",
                        voice=lines, poses=["портрет T3, взгляд на игрока", "крупный план рук/кольца-значка"]))
    for (rid, hero, hem, nm, jp, legacy, season, twist, poses, voice, concept) in R.S_ROWS:
        d = H.BASE[hero]
        rows.append(row(id=rid, hero=hero, tier="S", slot="s", name_ru=nm, name_jp=jp, season=season, legacy_outfit=legacy, legacy_video="",
                        hem_class=hem, twist=twist, theme=None, concept=concept, vfx=d["vfx"][:2] + ["PAPER_100", "NIGHT_900"],
                        heat=d["heat"].split(",")[0], voice=voice, poses=poses))
    for s in R.SSR_ROWS:
        d = H.BASE[s["hero"]]
        rows.append(row(id=s["id"], hero=s["hero"], tier=s["tier"], slot=SKIN_TIER_CODE[s["tier"]], name_ru=s["name_ru"], name_jp=s["name_jp"], season=s["season"],
                        legacy_outfit=s["legacy"], legacy_video=s["legacy_video"], hem_class=s["hem"], twist=s["twist"], theme=s["theme"], concept=s["concept"],
                        vfx=["%s.H500" % s["hero"], "%s.H300" % s["hero"], "%s.T2" % s["theme"], "%s.T3" % s["theme"], "PAPER_100", "NIGHT_900"],
                        heat=s["heat"], voice=s["voice"], poses=s["poses"], beats=s["beats"]))
    for (rid, hero, tier, hem, nm, jp, legacy, season, twist, theme) in R.LATER:
        rows.append(row(id=rid, hero=hero, tier=tier, slot=SKIN_TIER_CODE[tier], name_ru=nm, name_jp=jp, season=season, legacy_outfit=legacy, legacy_video="",
                        hem_class=hem, twist=twist, theme=theme, concept="сторибоард по шаблону %s пишется за 6 недель до релиза сезона" % R.DISPLAY_TIER[tier],
                        vfx=["%s.H500" % hero, "%s.H300" % hero, "%s.T2" % theme, "%s.T3" % theme, "PAPER_100", "NIGHT_900"],
                        heat="по шаблону класса", voice=[], poses=[]))
    tokens = tokens_json()
    for r in rows:
        t = R.TIER[r["tier"]]
        r["status"] = R.SEASON_STATUS[r["season"]]
        r["cutscene_s"] = t["len"]
        r["trigger_s"] = R.TRIGGER_S
        r["release_s"] = R.RELEASE_S
        r["total_s"] = round(R.TRIGGER_S + t["len"] + R.RELEASE_S, 2)
        r["beats_n"] = t["beats"]
        r["poses_n"] = t["poses"]
        r["plates_n"] = t["plates"]
        r["impact_events_max"] = t["impact"]
        ncast = len(r["voice"]) if r["voice"] else (t["voice"] - (1 if r["tier"] == "VOW" else 0))
        cues = ["%s_ult_cast_%d" % (r["id"], i + 1) for i in range(ncast)]
        if r["tier"] == "VOW":
            cues.append("%s_ult_finish_1" % r["id"])
        r["voice_cues"] = cues
        r["sfx_cues"] = ["ult_%s_hit" % r["hero"], "ult_%s_fx" % r["hero"]] if r["tier"] != "VOW" else []
        a, step = STATS[r["tier"]]
        r["atk_pct_star0"] = a
        r["atk_pct_per_star"] = step
        r["hud_format"] = t["hud"]
        r["particles_full_mid_min"] = list(t["particles"])
        factor = REMASTER if (r["tier"] == "BASE") else 1.0
        r["credits"] = round(t["cr"] * factor)
        r["hours"] = round(t["hours"] * factor)
        r["credits_increment"] = max(0, round(t["cr"] * factor) - t["cr_overlap"])
        r["hours_increment"] = max(0, round(t["hours"] * factor - t["h_overlap"]))
        r["size_mb"] = t["size"]
        r["skin_pack"] = "skins/%s/%s" % (r["hero"], r["id"])
        r["skin_tier"] = SKIN_TIER_CODE[r["tier"]]
        r["display_tier"] = R.DISPLAY_TIER[r["tier"]]
        r["ult_key"] = "ult.%s.%s" % (SKIN_TIER_CODE[r["tier"]], r["id"])
        r["needs_video"] = t["plates"] > 0
        for tok in r["vfx"]:
            assert token_ok(tok, tokens) or tok.split(".")[0] in tokens["heroes"], "unknown palette token %s in %s" % (tok, r["id"])
        r["assets"] = asset_list(r)
    return rows


def check_storyboards(rows):
    """consistency of the hand-written storyboards with the tier rules (fails the build, like AT-U08)."""
    for r in rows:
        b = r.get("beats")
        if not b:
            continue
        t = R.TIER[r["tier"]]
        assert len(b) == t["beats"], "%s: %d beats, tier wants %d" % (r["id"], len(b), t["beats"])
        assert abs(b[0][0]) < 1e-6, "%s: first beat must start at 0" % r["id"]
        for i in range(1, len(b)):
            assert abs(b[i][0] - b[i - 1][1]) < 1e-6, "%s: gap/overlap before beat %d (%.2f vs %.2f)" % (r["id"], i + 1, b[i][0], b[i - 1][1])
        assert abs(b[-1][1] - t["len"]) < 0.051, "%s: storyboard ends at %.2f, tier length %.2f" % (r["id"], b[-1][1], t["len"])
        if r["tier"] == "BASE":
            assert len(r["voice"]) == t["voice"], "%s: voice lines" % r["id"]
        for bt in b:
            if r["hem_class"] in ("knee", "mini"):
                assert "на уровне колена" not in bt[3], "%s: knee-level camera on %s hem" % (r["id"], r["hem_class"])
    for r in rows:
        for v in r["voice"]:
            assert len(v) <= 28, "%s: voice line too long: %s" % (r["id"], v)
    ids = [r["id"] for r in rows]
    assert len(ids) == len(set(ids)), "duplicate ult ids"
    assert len(rows) == 58, "catalogue must have 58 ults (SKIN_HUD_SYSTEM §6.2), has %d" % len(rows)
    by_status = {}
    for r in rows:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    assert by_status == {"launch": 38, "m6": 8, "m12": 12}, by_status


def totals(rows, statuses):
    by = {}
    for r in rows:
        if r["status"] in statuses:
            d = by.setdefault(r["tier"], dict(n=0, cr=0, h=0, cri=0, hi=0, mb=0.0, plates=0, voice=0))
            d["n"] += 1
            d["cr"] += r["credits"]
            d["h"] += r["hours"]
            d["cri"] += r["credits_increment"]
            d["hi"] += r["hours_increment"]
            d["mb"] += r["size_mb"]
            d["plates"] += r["plates_n"]
            d["voice"] += len(r["voice_cues"])
    return by


def md_table(rows_, cols, head):
    out = ["| " + " | ".join(head) + " |", "|" + "|".join(["---"] * len(head)) + "|"]
    for r in rows_:
        out.append("| " + " | ".join(str(c(r)) for c in cols) + " |")
    return "\n".join(out)


def write_catalogue(rows):
    cols = [lambda r: "`%s`" % r["id"], lambda r: r["display_tier"], lambda r: r["season"], lambda r: r["name_ru"], lambda r: r["legacy_outfit"] or "новый",
            lambda r: r["hem_class"], lambda r: "%.1f" % r["total_s"], lambda r: r["twist"] or "—", lambda r: "%d/%d/%d" % (r["poses_n"], r["plates_n"], len(r["voice_cues"])),
            lambda r: "%.2f" % r["size_mb"], lambda r: r["credits"], lambda r: r["credits_increment"], lambda r: r["hours"], lambda r: r["hours_increment"]]
    head = ["id (= skin_id)", "класс", "сезон", "название ульты", "legacy-id", "подол", "с, всего", "твист", "позы/плиты/голос", "МБ", "кр", "кр прирост", "ч", "ч прирост"]
    md = []
    md.append("# Каталог ульт (ULT_CATALOGUE)\n")
    md.append("Файл сгенерирован `design/specs/sim/gen_catalogue.py` из `ult_data_heroes.py` и `ult_data_rows.py`; единственный источник правды — эти два файла, "
              "вручную таблицы не править. Машинный вид: `design/specs/ult_catalogue.json` (копия идёт в `game/core/ult/data/ult_catalogue.json`, `BATTLE_ULT_SPEC` §7.3). "
              "Правила классов, таймингов, красных линий и палитры — `BATTLE_ULT_SPEC.md` §4–§7.\n")
    md.append("**Красные линии (во всех строках):** все героини явно взрослые; нет наготы (нет открытых сосков и гениталий, нет контура паха), нет сексуальных актов и жидкостей; "
              "нет школьного/детского кода; нет текста и логотипов в арте (печати «東風» и т. п. рисует движок шрифтом); камера не ниже границы подола (§6.2), нет вида под юбку, "
              "нет «сканирования тела»; флирт адресован только игроку; золото — только в рамках редкости (`PALETTE_LOCK` U4).\n")
    md.append("**Ключ.** `id` совпадает с `skin_id` из `SKIN_HUD_SYSTEM.md` §6.2 (58 скинов к месяцу 12; запуск S1 = 38): ульта = кинематограф боя этого скина. "
              "Класс: BASE (сигнатурная ульта героини) / VOW (Обет, `*_vow`) / S / SSR / SSR+ (`ssrp`, «Витрина сезона»). Сезон: S1 запуск (m0–2), S2–S3 до m6, S4–S6 до m12 (`SKIN_HUD_SYSTEM` §6.5). "
              "`legacy-id` — ближайший наряд в коде (`G.ITEM`, `V9Ults`, `V10W1Ults`), **не 1:1**, только для переноса ассетов. Подол — класс для линтера камеры (`long`, `knee`, `mini`, `pants`, `swim`; §6.2). "
              "С, всего = 0,8 триггер + кат-сцена + 0,5 выпуск. Твист T1…T8 — §2.6. Позы/плиты/голос — ключевые позы, видео-плиты, JP-реплики. "
              "МБ — вес ульты внутри пака скина (входит в бюджеты `SKIN_HUD_SYSTEM` §1.4/§2.7, отдельно не складывать). "
              "Кр — Higgsfield-кредиты **автономно** (до запаса ×1,3); **прирост** — после вычета того, что уже оплачено строками «Ключ-арт» и «Видео-ульта» `SKIN_HUD_SYSTEM` §5.2. "
              "Ч — человеко-часы автономно; ч прирост — после вычета строки «Ульта» `SKIN_HUD_SYSTEM` §5.3.\n")
    md.append("**Вне каталога:** новые героини (по GDD — одна «Новая гостья» за сезон) не входят в 58 скинов; каждая добавляет `<hero>_base` + `<hero>_vow` (≈ +%d кр и +%d ч на героиню) — решение OD-14.\n" %
              (round((R.TIER['BASE']['cr'] + R.TIER['VOW']['cr']) * REROLL), R.TIER['BASE']['hours'] + R.TIER['VOW']['hours']))
    for st, title in (("launch", "Релиз 1.0, сезон S1 (launch): %d ульт"), ("m6", "Сезоны S2–S3, до 6-го месяца (m6): +%d ульт"), ("m12", "Сезоны S4–S6, до 12-го месяца (m12): +%d ульт")):
        sel = [r for r in rows if r["status"] == st]
        md.append("\n## %s\n" % (title % len(sel)))
        md.append(md_table(sel, cols, head))
        tb = totals(rows, (st,))
        md.append("\n\nИтог по классам (%s):\n" % st)
        md.append("| класс | шт | кредиты автономно (×1,3) | кредиты прирост (×1,3) | часы автономно | часы прирост | МБ | видео-плит | JP-реплик |\n|---|---|---|---|---|---|---|---|---|")
        tot = dict(n=0, cr=0, h=0, cri=0, hi=0, mb=0.0, plates=0, voice=0)
        for tier in ("BASE", "VOW", "S", "SSR", "SSRP"):
            if tier in tb:
                d = tb[tier]
                md.append("| %s | %d | %d | %d | %d | %d | %.1f | %d | %d |" % (R.DISPLAY_TIER[tier], d["n"], round(d["cr"] * REROLL), round(d["cri"] * REROLL), d["h"], d["hi"], d["mb"], d["plates"], d["voice"]))
                for k in tot:
                    tot[k] += d[k]
        md.append("| **итого** | **%d** | **%d** | **%d** | **%d** | **%d** | **%.1f** | **%d** | **%d** |" % (tot["n"], round(tot["cr"] * REROLL), round(tot["cri"] * REROLL), tot["h"], tot["hi"], tot["mb"], tot["plates"], tot["voice"]))
    md.append("\n## Накопительно\n")
    md.append("| рубеж | ульт всего | кр автономно (×1,3) | кр прирост (×1,3) | ч автономно | ч прирост | МБ |\n|---|---|---|---|---|---|---|")
    for lab, stt in (("launch (S1)", ("launch",)), ("к m6 (S1–S3)", ("launch", "m6")), ("к m12 (S1–S6)", ("launch", "m6", "m12"))):
        tb = totals(rows, stt)
        md.append("| %s | %d | %d | %d | %d | %d | %.1f |" % (lab, sum(d["n"] for d in tb.values()), round(sum(d["cr"] for d in tb.values()) * REROLL),
                                                           round(sum(d["cri"] for d in tb.values()) * REROLL), sum(d["h"] for d in tb.values()), sum(d["hi"] for d in tb.values()),
                                                           sum(d["mb"] for d in tb.values())))
    md.append("\nПеречень файлов ассетов каждой ульты — поле `assets` в `ult_catalogue.json` (шаблон по классу — `BATTLE_ULT_SPEC` §7.2; каталог — внутри `SkinPack`, подпапка `ult/`).\n")
    with open(os.path.join(OUT, "ULT_CATALOGUE.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))


def write_json(rows):
    out = dict(schema=1, generated_by="design/specs/sim/gen_catalogue.py", skin_catalogue="design/specs/SKIN_HUD_SYSTEM.md#6.2",
               tiers=R.TIER, display_tier=R.DISPLAY_TIER, trigger_s=R.TRIGGER_S, release_s=R.RELEASE_S,
               twists={k: dict(name=v[0], rule=v[1]) for k, v in R.TWISTS.items()},
               heroes={k: dict(name=v["name"], role=v["role"], aura=v["aura"], tags=v["tags"], core=v["core"], battle_ult=v["battle_ult"], battle=v["battle"])
                       for k, v in H.HEROES.items()},
               shared_sfx=SHARED_SFX, insert_sfx=INSERT_SFX, ults=[])
    for r in rows:
        u = {k: v for k, v in r.items() if k != "beats"}
        if r["beats"]:
            u["beats"] = [dict(t0=b[0], t1=b[1], shot=b[2], what=b[3]) for b in r["beats"]]
        out["ults"].append(u)
    with open(os.path.join(OUT, "ult_catalogue.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)


def beats_md(beats):
    out = ["| № | t, с | кадр | что происходит (камера; поза; VFX; звук) |", "|---|---|---|---|"]
    for i, b in enumerate(beats, 1):
        out.append("| %d | %.2f–%.2f | %s | %s |" % (i, b[0], b[1], b[2], b[3]))
    return "\n".join(out)


def write_fragments(rows):
    byid = {r["id"]: r for r in rows}
    md = []
    md.append("### 8.0 Сводка по 10 героиням (роль, аура, ядро Стола, боевой эффект)\n")
    md.append("| героиня | роль | аура | теги GDD | ядро на Столе (нормализовано) | боевой эффект ульты (Бой) | ульта (`<hero>_base`) | рост, см |")
    md.append("|---|---|---|---|---|---|---|---|")
    for hid, h in H.HEROES.items():
        b = H.BASE[hid]
        md.append("| %s (`%s`) | %s | %s | %s | %s | %s | «%s» %s | %d |" % (h["name"], hid, H.ROLE_RU[h["role"]], H.AURA_RU[h["aura"]], h["tags"], h["core"], h["battle"], b["name_ru"], b["name_jp"], h["hero_h_cm"]))
    md.append("")
    for i, (hid, h) in enumerate(H.HEROES.items(), 1):
        b = H.BASE[hid]
        md.append("\n### 8.%d %s — «%s» · %s · `%s_base`\n" % (i, h["name"], b["name_ru"], b["name_jp"], hid))
        md.append("- **Роль / аура:** %s · %s · теги GDD: %s. Рост %d см: пропорции взрослые (≥6,75 головы, `ART_TIER_FULL` §3a).\n- **Концепт:** %s\n- **Ядро на Столе (нормализация, не меняется):** %s.\n- **Боевой эффект (слой Бой):** %s.\n"
                  % (H.ROLE_RU[h["role"]], H.AURA_RU[h["aura"]], h["tags"], h["hero_h_cm"], b["concept"], h["core"], h["battle"]))
        md.append("- **Сигнатурные позы кат-ина (4):** " + "; ".join("%d) %s" % (k + 1, p) for k, p in enumerate(b["poses"])) + ".")
        md.append("- **Палитра VFX (только токены `PALETTE_LOCK`):** " + ", ".join("`%s`" % t for t in b["vfx"]) + ". Акцент героини ≤20%% кадра; импакт-кадр — дуотон `NIGHT_900` + `%s.H300`; золота в VFX нет." % hid)
        md.append("- **«Жар» (дым, пар, влажный блеск; управляет `TWHeat`):** " + b["heat"] + ".")
        md.append("- **Реплики (RU-субтитры; JP-озвучка по Beta-24/Launch-60, ≤28 символов):** " + " · ".join("«%s»" % v for v in b["voice"]) +
                  "; id: `%s_base_ult_cast_1..3`, `%s_ult_ready_1`. Уникальные SFX: `%s`.\n" % (hid, hid, "`, `".join(b["sfx"])))
        md.append("**Сторибоард (8 кадров, 3,0 с; камера никогда не ниже предела подола, §6.2):**\n")
        md.append(beats_md(b["beats"]))
        md.append("")
    md.append("\n## 9. Варианты SSR и SSR+ (полные сторибоарды запуска), S и Обеты\n")
    for n, s in enumerate(R.SSR_ROWS, 1):
        r = byid[s["id"]]
        md.append("\n### 9.%d %s — «%s» · %s · `%s`, класс %s, тема %s\n" % (n, H.HEROES[s["hero"]]["name"], s["name_ru"], s["name_jp"], s["id"], R.DISPLAY_TIER[s["tier"]], s["theme"]))
        md.append("- **legacy:** наряд `%s`, видео `%s`; **твист:** %s «%s» — %s.\n- **Концепт:** %s\n- **Ключевые позы (%d):** %s.\n- **Палитра VFX:** %s.\n- **«Жар»:** %s.\n- **Реплики (%d):** %s; id `%s_ult_cast_1..%d`.\n- **Длина:** %.1f с кат-сцена (всего %.1f с), импакт-событий ≤%d, частицы %d/%d/%d.\n"
                  % (s["legacy"], s["legacy_video"] or "нет, делается", s["twist"], R.TWISTS[s["twist"]][0], R.TWISTS[s["twist"]][1], s["concept"], len(s["poses"]), "; ".join(s["poses"]),
                     ", ".join("`%s`" % t for t in r["vfx"]), s["heat"], len(s["voice"]), " · ".join("«%s»" % v for v in s["voice"]), s["id"], len(s["voice"]),
                     R.TIER[s["tier"]]["len"], r["total_s"], R.TIER[s["tier"]]["impact"], *R.TIER[s["tier"]]["particles"]))
        md.append(beats_md(s["beats"]))
        md.append("")
    md.append("\n### 9.7 S-варианты запуска (12): перекрашенный кат-ин на хореографии BASE\n")
    md.append("Что остаётся от BASE-хореографии: кадры 1, 3, 5, 6, 8; заменяются кадры 2 и 7 (две позы нового наряда), палитра VFX (`palette_remap` по токенам скина), реплики, твист. Длина сцены 3,0 с, всего 4,3 с. "
              "Остальные 15 S каталога (S2–S6) — тот же шаблон, строки в `ULT_CATALOGUE.md`.\n")
    md.append("| id | героиня | название (JP) | подол | legacy | твист | 2 позы кат-ина (кадры 2 и 7) | реплики | суть эффекта |")
    md.append("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        if r["tier"] == "S" and r["status"] == "launch":
            md.append("| `%s` | %s | «%s» %s | %s | %s | %s «%s» | %s | %s | %s |" % (r["id"], H.HEROES[r["hero"]]["name"], r["name_ru"], r["name_jp"], r["hem_class"], r["legacy_outfit"] or "новый",
                      r["twist"], R.TWISTS[r["twist"]][0], "; ".join(r["poses"]), " · ".join("«%s»" % v for v in r["voice"]), r["concept"]))
    md.append("\n### 9.8 Обеты (VOW, 10): тихая ульта, 2,5 с, без удара\n")
    md.append("Структура 6 кадров: Глаз 0,30 → Портрет T3 0,60 → Руки/кольцо-значок 0,50 → Свет рассвета 0,50 → Взгляд на игрока 0,45 → Выход 0,15 (сумма 2,50). Одинаковый боевой эффект: лечение 15% max HP + иммунитет к печатям на 2 каста. "
              "Без импакт-кадров, без «Жара»; белая вспышка 0,15 с допустима только на смене наряда Клятвы (GDD §4.5), в ульте — нет.\n")
    md.append("| id | героиня | название (JP) | реплики (cast_1, cast_2; finish_1 — тихая) | сцена |")
    md.append("|---|---|---|---|---|")
    for r in rows:
        if r["tier"] == "VOW":
            md.append("| `%s` | %s | «%s» %s | %s | %s |" % (r["id"], H.HEROES[r["hero"]]["name"], r["name_ru"], r["name_jp"], " · ".join("«%s»" % v for v in r["voice"]), r["concept"]))
    frag = "\n".join(md)
    with open(os.path.join(OUT, "sim", "_gen_heroine_tables.md"), "w", encoding="utf-8") as f:
        f.write(frag)
    spec = os.path.join(OUT, "BATTLE_ULT_SPEC.md")
    if os.path.exists(spec):
        txt = open(spec, encoding="utf-8").read()
        b, e = "<!-- GEN:HEROINES:BEGIN -->", "<!-- GEN:HEROINES:END -->"
        if b in txt and e in txt:
            head, rest = txt.split(b, 1)
            _, tail = rest.split(e, 1)
            open(spec, "w", encoding="utf-8").write(head + b + "\n" + frag + "\n" + e + tail)


def main():
    rows = build_rows()
    check_storyboards(rows)
    write_catalogue(rows)
    write_json(rows)
    write_fragments(rows)
    for st in ("launch", "m6", "m12"):
        tb = totals(rows, (st,))
        print(st, sum(d["n"] for d in tb.values()), {k: v["n"] for k, v in tb.items()})
    print("total", len(rows))


if __name__ == "__main__":
    main()
