#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates design/specs/ULT_CATALOGUE.md, design/specs/ult_catalogue.json, sim/_gen_heroine_tables.md and splices
sections 8.0-9.8 of design/specs/BATTLE_ULT_SPEC.md (between the GEN:HEROINES markers)
from ult_data_heroes.py + ult_data_rows.py.   Run:  python3 gen_catalogue.py
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

SHARED_SFX = ["ult_ring_pop", "ult_trigger_stamp", "ult_whoosh_in", "ult_cloth_snap", "ult_step_heel", "ult_inhale", "ult_hit_low",
              "ult_hit_high", "ult_sweep_fx", "ult_board_resolve", "ult_tail_air", "ult_skip_swish", "ult_assist_pop"]
TOKENS_OK = None


def load_tokens():
    p = os.path.abspath(os.path.join(OUT, "..", "..", "game", "shell", "design", "tokens.json"))
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def token_ok(tok, tokens):
    if "." in tok:
        h, k = tok.split(".")
        return h in tokens["heroes"] and k in tokens["heroes"][h]
    return tok in tokens["color"]


def stat_bonus(tier):
    """ATK % at star 0 and per star (spec 2.6)."""
    return {"BASE": (0, 0), "VOW": (0, 0), "S": (0.04, 0.010), "SSR": (0.08, 0.020), "FLAG": (0.10, 0.025)}[tier]


def asset_list(row):
    t = R.TIER[row["tier"]]
    base = "assets/v11/ult/%s/%s/" % (row["hero"], row["id"])
    a = []
    for i in range(1, t["poses"] + 1):
        a.append(base + "cutin_pose_%d.webp (1024x1536, <=170 KB)" % i)
    for i in range(1, t["plates"] + 1):
        a.append(base + "plate_%d.ogv (540x960, 24 fps, Theora q6, <=0.9 MB)" % i)
    a.append(base + "timeline.json (cue sheet, spec 7.4)")
    a.append(base + "vfx_preset.json (tokens only, spec 5.5)")
    n = len(row["voice_cues"])
    a.append(base + "voice/ %d x ogg mono q4 (JP) + subtitles RU in lines.json" % n)
    a.append(base + "gallery_thumb.webp (512x768)")
    if row["tier"] in ("SSR", "FLAG"):
        a.append(base + "gallery_splash.webp (1080x1620)")
    if row["tier"] == "FLAG":
        a.append(base + "takeover_skin.json + takeover_frame.webp (table skin 6 s)")
    return a


def build_rows():
    rows = []
    # BASE launch
    for hero, hem, legacy, vid, status in R.BASE_ROWS:
        d = H.BASE[hero]
        rows.append(dict(id="%s_base" % hero, hero=hero, tier="BASE", slot="base", name_ru=d["name_ru"], name_jp=d["name_jp"], status=status,
                         legacy_outfit=legacy, legacy_video=vid, hem_class=hem, twist="", concept=d["concept"], vfx=d["vfx"], heat=d["heat"],
                         voice=d["voice"], poses=d["poses"], sfx=d["sfx"]))
    # VOW launch
    hems = {b[0]: b[1] for b in R.BASE_ROWS}
    for hero, (nm, jp, concept, lines) in R.VOW.items():
        d = H.BASE[hero]
        rows.append(dict(id="%s_vow" % hero, hero=hero, tier="VOW", slot="vow", name_ru=nm, name_jp=jp, status="launch",
                         legacy_outfit={"kohaku": "ko_vow", "zlata": "zl_vow"}.get(hero, ""), legacy_video="", hem_class="long", twist="", concept=concept,
                         vfx=[d["vfx"][0], d["vfx"][2], "PAPER_100", "NIGHT_900"], heat="мягкий рассвет, тёплый пар, без вспышек",
                         voice=lines, poses=["портрет T3, взгляд на игрока", "крупный план рук/кольца-значка"], sfx=[]))
    # S
    for (rid, hero, slot, hem, nm, jp, legacy, status, twist, poses, voice, concept) in R.S_ROWS:
        d = H.BASE[hero]
        rows.append(dict(id=rid, hero=hero, tier="S", slot=slot, name_ru=nm, name_jp=jp, status=status, legacy_outfit=legacy, legacy_video="",
                         hem_class=hem, twist=twist, concept=concept, vfx=d["vfx"][:3] + ["PAPER_100"], heat=d["heat"].split(",")[0],
                         voice=voice, poses=poses, sfx=[]))
    # SSR / FLAG launch (full storyboards)
    for s in R.SSR_ROWS:
        rows.append(dict(id=s["id"], hero=s["hero"], tier=s["tier"], slot=s["slot"], name_ru=s["name_ru"], name_jp=s["name_jp"], status=s["status"],
                         legacy_outfit=s["legacy"], legacy_video=s["legacy_video"], hem_class=s["hem"], twist=s["twist"], concept=s["concept"],
                         vfx=s["vfx"], heat=s["heat"], voice=s["voice"], poses=s["poses"], sfx=[], beats=s["beats"]))
    # later FLAG
    for (rid, hero, hem, nm, jp, legacy, status, twist, slot) in R.LATER_FLAG:
        d = H.BASE[hero]
        rows.append(dict(id=rid, hero=hero, tier="FLAG", slot=slot, name_ru=nm, name_jp=jp, status=status, legacy_outfit=legacy, legacy_video="",
                         hem_class=hem, twist=twist, concept="заготовка: сторибоард по шаблону FLAG, делается за 6 недель до релиза", vfx=d["vfx"][:3] + ["GOLD_300", "GOLD_500", "NIGHT_900"],
                         heat=d["heat"], voice=[], poses=[], sfx=[]))
    # new heroines BASE + VOW
    for hid, h in R.NEW_HEROES.items():
        rows.append(dict(id="%s_base" % hid, hero=hid, tier="BASE", slot="base", name_ru="(по паспорту героини)", name_jp="", status=h["season"], legacy_outfit="",
                         legacy_video="", hem_class="knee", twist="", concept="сигнатурная ульта новой героини (%s, %s): сторибоард по шаблону BASE" % (H.ROLE_RU[h["role"]], H.AURA_RU[h["aura"]]),
                         vfx=["%s.accent" % hid, "%s.glow" % hid], heat="", voice=[], poses=[], sfx=[]))
        rows.append(dict(id="%s_vow" % hid, hero=hid, tier="VOW", slot="vow", name_ru="Обет", name_jp="", status=h["season"], legacy_outfit="", legacy_video="",
                         hem_class="long", twist="", concept="тихий кат-ин клятвы по шаблону VOW", vfx=["%s.accent" % hid, "PAPER_100"], heat="", voice=[], poses=[], sfx=[]))
    # derived fields
    tokens = load_tokens()
    for r in rows:
        t = R.TIER[r["tier"]]
        r["cutscene_s"] = t["len"]
        r["trigger_s"] = R.TRIGGER_S
        r["release_s"] = R.RELEASE_S
        r["total_s"] = round(R.TRIGGER_S + t["len"] + R.RELEASE_S, 2)
        r["beats_n"] = t["beats"]
        r["poses_n"] = t["poses"]
        r["plates_n"] = t["plates"]
        r["impact_frames"] = t["impact"]
        ncast = len(r["voice"]) if r["voice"] else (t["voice"] - (1 if r["tier"] == "VOW" else 0))
        cues = ["%s_ult_cast_%d" % (r["id"], i + 1) for i in range(ncast)]
        if r["tier"] == "VOW":
            cues.append("%s_ult_finish_1" % r["id"])
        r["voice_cues"] = cues
        r["sfx_cues"] = ["ult_%s_hit" % r["hero"], "ult_%s_fx" % r["hero"]] if r["tier"] in ("BASE", "S", "SSR", "FLAG") else []
        a, step = stat_bonus(r["tier"])
        r["atk_pct_star0"] = a
        r["atk_pct_per_star"] = step
        r["hud_format"] = t["hud"]
        factor = REMASTER if (r["tier"] == "BASE" and r["status"] == "launch") else 1.0
        r["credits"] = round(t["cr"] * factor)
        r["hours"] = round(t["hours"] * factor)
        r["size_mb"] = t["size"]
        r["pack"] = "pack_ult_%s" % r["hero"]
        r["needs_video"] = t["plates"] > 0
        r["needs_rig"] = True
        r["storyboard"] = "beats" in r or (r["tier"] == "BASE" and r["hero"] in H.BASE)
        for tok in r["vfx"]:
            if r["hero"] in R.NEW_HEROES:
                continue   # tokens of a new heroine are added when she is onboarded (tokens.json heroes.<id>)
            assert token_ok(tok, tokens), "unknown palette token %s in %s" % (tok, r["id"])
        r["assets"] = asset_list(r)
    return rows


def totals(rows, status_filter):
    sel = [r for r in rows if r["status"] in status_filter]
    by = {}
    for r in sel:
        d = by.setdefault(r["tier"], dict(n=0, cr=0, h=0, mb=0.0, plates=0, voice=0))
        d["n"] += 1
        d["cr"] += r["credits"]
        d["h"] += r["hours"]
        d["mb"] += r["size_mb"]
        d["plates"] += r["plates_n"]
        d["voice"] += len(r["voice_cues"])
    return by



def check_storyboards(rows):
    """consistency of the hand-written storyboards with the tier rules (fails the build, like AT-U08)."""
    for r in rows:
        b = r.get("beats")
        if b is None and r["tier"] == "BASE" and r["hero"] in H.BASE:
            b = H.BASE[r["hero"]]["beats"]
        if not b:
            continue
        t = R.TIER[r["tier"]]
        assert len(b) == t["beats"], "%s: %d beats, tier wants %d" % (r["id"], len(b), t["beats"])
        assert abs(b[0][0]) < 1e-6, "%s: first beat must start at 0" % r["id"]
        for i in range(1, len(b)):
            assert abs(b[i][0] - b[i - 1][1]) < 1e-6, "%s: gap/overlap before beat %d (%.2f vs %.2f)" % (r["id"], i + 1, b[i][0], b[i - 1][1])
        assert abs(b[-1][1] - t["len"]) < 0.051, "%s: storyboard ends at %.2f, tier length %.2f" % (r["id"], b[-1][1], t["len"])
        if r["tier"] in ("BASE",):
            assert len(r["voice"]) == t["voice"], "%s: voice lines" % r["id"]
        for v in r["voice"]:
            assert len(v) <= 28, "%s: voice line too long: %s" % (r["id"], v)
        assert len(r["poses"]) >= 2, r["id"]
        # camera floor words must not contradict hem class
        if r["hem_class"] in ("knee", "mini"):
            for bt in b:
                assert "на уровне колена" not in bt[3], "%s: knee-level camera on %s hem" % (r["id"], r["hem_class"])

def md_table(rows_, cols, head):
    out = ["| " + " | ".join(head) + " |", "|" + "|".join(["---"] * len(head)) + "|"]
    for r in rows_:
        out.append("| " + " | ".join(str(c(r)) for c in cols) + " |")
    return "\n".join(out)


def write_catalogue(rows):
    cols = [lambda r: "`%s`" % r["id"], lambda r: r["tier"], lambda r: r["slot"], lambda r: r["name_ru"], lambda r: r["legacy_outfit"] or "новый",
            lambda r: r["hem_class"], lambda r: "%.1f" % r["total_s"], lambda r: r["twist"] or "—", lambda r: "%d/%d/%d" % (r["poses_n"], r["plates_n"], len(r["voice_cues"])),
            lambda r: "%.2f" % r["size_mb"], lambda r: r["credits"], lambda r: r["hours"]]
    head = ["id", "класс", "слот", "название", "legacy-id", "подол", "с, всего", "твист", "позы/плиты/голос", "МБ", "кр", "ч"]
    md = []
    md.append("# Каталог ульт (ULT_CATALOGUE)\n")
    md.append("Файл сгенерирован `design/specs/sim/gen_catalogue.py` из `ult_data_heroes.py` и `ult_data_rows.py`; единственный источник правды — эти два файла, "
              "вручную таблицы не править. Машинный вид: `design/specs/ult_catalogue.json` (его же копирует игра в `game/core/ult/data/ult_catalogue.json`, "
              "`BATTLE_ULT_SPEC` §7.3). Правила классов, таймингов и красных линий — `BATTLE_ULT_SPEC.md` §4–§7.\n")
    md.append("**Красные линии (во всех строках):** все героини явно взрослые; нет наготы (нет открытых сосков и гениталий, нет контура паха), нет сексуальных актов и жидкостей; "
              "нет школьного/детского кода; нет текста и логотипов в арте (печать «東風» и т. п. рисуется шрифтом движка, не запечена в арт); камера не ниже границы подола "
              "(§6.2), нет вида под юбку, нет «сканирования тела»; флирт адресован только игроку.\n")
    md.append("**Статус id:** `launch` — релиз 1.0; `m6` — к 6-му месяцу; `m12` — к 12-му (план А: GDD §10.3, +1 SSR-«флагман», +3 S и +1 героиня за сезон). "
              "**ID наряда — предложение**, пока нет `SKIN_HUD_SYSTEM` (ветка `claude/spec-skin` на момент написания в origin отсутствует); колонка `legacy-id` — "
              "id в коде (`G.ITEM`, `V9Ults`, `V10W1Ults`), для миграции. Если спека скинов переименует наряд, меняется только колонка id и таблица соответствия, "
              "правила не меняются.\n")
    md.append("**Колонки:** класс — BASE (сигнатурная ульта героини) / VOW (Обет) / S / SSR / FLAG (SSR-флагман сезона); подол — класс подола для линтера камеры "
              "(`long`, `knee`, `mini`, `pants`, `swim`); с, всего — 0,8 с триггер + кат-сцена + 0,5 с выпуск; твист — риддер ульты T1…T8 (§2.6); "
              "позы/плиты/голос — ключевые позы кат-ина, видео-плиты, JP-голосовые реплики; МБ — вес пака одной ульты; кр — кредиты Higgsfield до запаса ×1,3; ч — человеко-часы.\n")
    for st, title in (("launch", "Релиз 1.0 (launch): %d ульт"), ("m6", "К 6-му месяцу (m6): +%d ульт"), ("m12", "К 12-му месяцу (m12): +%d ульт")):
        sel = [r for r in rows if r["status"] == st]
        md.append("\n## %s\n" % (title % len(sel)))
        md.append(md_table(sel, cols, head))
        tb = totals(rows, (st,))
        md.append("\n\nИтог по классам (%s):\n" % st)
        md.append("| класс | шт | кредиты (×1,3) | часы | МБ | видео-плит | голос-реплик |\n|---|---|---|---|---|---|---|")
        tot = dict(n=0, cr=0, h=0, mb=0.0, plates=0, voice=0)
        for tier in ("BASE", "VOW", "S", "SSR", "FLAG"):
            if tier in tb:
                d = tb[tier]
                md.append("| %s | %d | %d | %d | %.1f | %d | %d |" % (tier, d["n"], round(d["cr"] * REROLL), d["h"], d["mb"], d["plates"], d["voice"]))
                for k in tot:
                    tot[k] += d[k]
        md.append("| **итого** | **%d** | **%d** | **%d** | **%.1f** | **%d** | **%d** |" % (tot["n"], round(tot["cr"] * REROLL), tot["h"], tot["mb"], tot["plates"], tot["voice"]))
    allr = totals(rows, ("launch", "m6", "m12"))
    md.append("\n## Накопительно\n")
    md.append("| рубеж | ульт всего | кредиты (×1,3) | часы | МБ |\n|---|---|---|---|---|")
    for lab, stt in (("launch", ("launch",)), ("к m6", ("launch", "m6")), ("к m12", ("launch", "m6", "m12"))):
        tb = totals(rows, stt)
        n = sum(d["n"] for d in tb.values())
        md.append("| %s | %d | %d | %d | %.1f |" % (lab, n, round(sum(d["cr"] for d in tb.values()) * REROLL), sum(d["h"] for d in tb.values()), sum(d["mb"] for d in tb.values())))
    md.append("\nПеречень файлов ассетов каждой ульты — поле `assets` в `ult_catalogue.json` (шаблон по классу: `BATTLE_ULT_SPEC` §7.2).\n")
    with open(os.path.join(OUT, "ULT_CATALOGUE.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))


def write_json(rows):
    out = dict(schema=1, generated_by="design/specs/sim/gen_catalogue.py",
               tiers=R.TIER, trigger_s=R.TRIGGER_S, release_s=R.RELEASE_S,
               twists={k: dict(name=v[0], rule=v[1]) for k, v in R.TWISTS.items()},
               heroes={k: dict(name=v["name"], role=v["role"], aura=v["aura"], tags=v["tags"], core=v["core"], battle_ult=v["battle_ult"], battle=v["battle"])
                       for k, v in H.HEROES.items()},
               shared_sfx=SHARED_SFX, ults=[{k: v for k, v in r.items() if k not in ("beats",)} for r in rows])
    # compact storyboard as arrays
    for u, r in zip(out["ults"], rows):
        if "beats" in r:
            u["beats"] = [dict(t0=b[0], t1=b[1], shot=b[2], what=b[3]) for b in r["beats"]]
        elif r["tier"] == "BASE" and r["hero"] in H.BASE:
            u["beats"] = [dict(t0=b[0], t1=b[1], shot=b[2], what=b[3]) for b in H.BASE[r["hero"]]["beats"]]
    with open(os.path.join(OUT, "ult_catalogue.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)


def beats_md(beats):
    out = ["| № | t, с | кадр | что происходит (камера; поза; VFX; звук) |", "|---|---|---|---|"]
    for i, b in enumerate(beats, 1):
        out.append("| %d | %.2f–%.2f | %s | %s |" % (i, b[0], b[1], b[2], b[3]))
    return "\n".join(out)


def write_fragments(rows):
    md = []
    md.append("### 8.0 Сводка по 10 героиням (роль, аура, ядро Стола, боевой эффект)\n")
    md.append("| героиня | роль | аура | теги GDD | ядро на Столе (нормализовано) | боевой эффект ульты (Бой) | ульта | рост, см |")
    md.append("|---|---|---|---|---|---|---|---|")
    for hid, h in H.HEROES.items():
        b = H.BASE[hid]
        md.append("| %s (`%s`) | %s | %s | %s | %s | %s | «%s» %s | %d |" % (h["name"], hid, H.ROLE_RU[h["role"]], H.AURA_RU[h["aura"]], h["tags"], h["core"], h["battle"], b["name_ru"], b["name_jp"], h["hero_h_cm"]))
    md.append("")
    for i, (hid, h) in enumerate(H.HEROES.items(), 1):
        b = H.BASE[hid]
        md.append("\n### 8.%d %s — «%s» · %s · `%s_base`\n" % (i, h["name"], b["name_ru"], b["name_jp"], hid))
        md.append("- **Роль / аура:** %s · %s · теги GDD: %s. Рост %d см: пропорции взрослые (>= 6,75 головы, `ART_TIER_FULL` §3a).\n- **Концепт:** %s\n- **Ядро на Столе (нормализация, не меняется):** %s.\n- **Боевой эффект (слой Бой):** %s.\n"
                  % (H.ROLE_RU[h["role"]], H.AURA_RU[h["aura"]], h["tags"], h["hero_h_cm"], b["concept"], h["core"], h["battle"]))
        md.append("- **Сигнатурные позы кат-ина (4):** " + "; ".join("%d) %s" % (k + 1, p) for k, p in enumerate(b["poses"])) + ".")
        md.append("- **Палитра VFX (только токены):** " + ", ".join("`%s`" % t for t in b["vfx"]) + ". Акцент героини не более 20%% кадра; импакт-кадр — дуотон `NIGHT_900` + `%s.accent`." % hid)
        md.append("- **«Жар» (дым, пар, влажный блеск):** " + b["heat"] + ".")
        md.append("- **Реплики (RU-субтитры; JP-озвучка по Beta-24/Launch-60, ≤28 символов):** " + " · ".join("«%s»" % v for v in b["voice"]) +
                  "; id: `%s_ult_cast_1..3`, `%s_ult_ready_1`. Уникальные SFX: `%s`.\n" % (hid, hid, "`, `".join(b["sfx"])))
        md.append("**Сторибоард (8 кадров, 3,0 с; камера никогда не ниже подола, см. §6.2):**\n")
        md.append(beats_md(b["beats"]))
        md.append("")
    md.append("\n## 9. Варианты SSR и флагманов релиза (полные сторибоарды)\n")
    for s in R.SSR_ROWS:
        r = [x for x in rows if x["id"] == s["id"]][0]
        md.append("\n### 9.%s %s — «%s» · %s · `%s`, класс %s\n" % (str(R.SSR_ROWS.index(s) + 1), H.HEROES[s["hero"]]["name"], s["name_ru"], s["name_jp"], s["id"], s["tier"]))
        md.append("- **legacy:** наряд `%s`, видео `%s`; **твист:** %s «%s» — %s.\n- **Концепт:** %s\n- **Ключевые позы (%d):** %s.\n- **Палитра VFX:** %s.\n- **«Жар»:** %s.\n- **Реплики (%d):** %s; id `%s_ult_cast_1..%d`.\n- **Длина:** %.1f с кат-сцена (всего %.1f с), импакт-кадров до %d.\n"
                  % (s["legacy"], s["legacy_video"] or "нет, делается", s["twist"], R.TWISTS[s["twist"]][0], R.TWISTS[s["twist"]][1], s["concept"], len(s["poses"]), "; ".join(s["poses"]),
                     ", ".join("`%s`" % t for t in s["vfx"]), s["heat"], len(s["voice"]), " · ".join("«%s»" % v for v in s["voice"]), s["id"], len(s["voice"]),
                     R.TIER[s["tier"]]["len"], r["total_s"], R.TIER[s["tier"]]["impact"]))
        md.append(beats_md(s["beats"]))
        md.append("")

    # S variants and VOW
    md.append("\n### 9.7 S-варианты запуска (12): перекрашенный кат-ин на хореографии BASE\n")
    md.append("Что остаётся от BASE-хореографии: кадры 1, 3, 5, 6, 8; заменяются кадры 2 и 7 (две позы нового наряда), палитра VFX (`palette_remap` по токенам наряда), реплики, твист. Длина сцены 3,0 с, всего 4,3 с.\n")
    md.append("| id | героиня | слот | название (JP) | подол | legacy | твист | 2 позы кат-ина (кадры 2 и 7) | реплики | суть эффекта |")
    md.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        if r["tier"] == "S" and r["status"] == "launch":
            md.append("| `%s` | %s | %s | «%s» %s | %s | %s | %s «%s» | %s | %s | %s |" % (r["id"], H.HEROES[r["hero"]]["name"], r["slot"], r["name_ru"], r["name_jp"], r["hem_class"], r["legacy_outfit"] or "новый",
                      r["twist"], R.TWISTS[r["twist"]][0], "; ".join(r["poses"]), " · ".join("«%s»" % v for v in r["voice"]), r["concept"]))
    md.append("\n### 9.8 Обеты (VOW, 10): тихая ульта, 2,5 с, без удара\n")
    md.append("Структура 6 кадров: Глаз 0,30 → Портрет T3 0,60 → Руки/кольцо-значок 0,50 → Свет рассвета 0,50 → Взгляд на игрока 0,45 → Выход 0,15 (сумма 2,50). Одинаковый боевой эффект: лечение 15% max HP + иммунитет к печатям на 2 каста. Без импакт-кадров, без «Жара»; допустима белая вспышка 0,15 с только на смене наряда Клятвы (GDD §4.5), в ульте — нет.\n")
    md.append("| id | героиня | название (JP) | реплики (cast_1, cast_2; finish_1 — тихая) | сцена |")
    md.append("|---|---|---|---|---|")
    for r in rows:
        if r["tier"] == "VOW" and r["status"] == "launch":
            md.append("| `%s` | %s | «%s» %s | %s | %s |" % (r["id"], H.HEROES[r["hero"]]["name"], r["name_ru"], r["name_jp"], " · ".join("«%s»" % v for v in r["voice"]), r["concept"]))
    frag = "\n".join(md)
    with open(os.path.join(OUT, "sim", "_gen_heroine_tables.md"), "w", encoding="utf-8") as f:
        f.write(frag)
    # splice into BATTLE_ULT_SPEC.md between the markers (sections 8.0-9.8 are generated, do not edit by hand)
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
    ids = [r["id"] for r in rows]
    assert len(ids) == len(set(ids)), "duplicate ult ids"
    for st in ("launch", "m6", "m12"):
        print(st, sum(1 for r in rows if r["status"] == st))
    print("total", len(rows))


if __name__ == "__main__":
    main()
