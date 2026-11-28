#!/usr/bin/env python3
"""voice_registry.py - voice line registry for Tile Waifu (GDD v11 §8.4), Beta-24 x 10 heroines.

  python tools/audio/voice_registry.py build    # texts -> game/core/voice/voice_registry.json + design/voice/BETA24_TEXTS.md
  python tools/audio/voice_registry.py check    # validate the committed registry (prints VOICE_REGISTRY ok/total)
  python tools/audio/voice_registry.py check --strict-files   # also require every file to exist (100% map)
  python tools/audio/voice_registry.py coverage # which ids have an audio file (share)

Row = heroine x line_id x JP x kana x RU x condition x pool x duration x file.  No audio is produced here.
The registry is the single table that the future voice bank (P47) fills in: a line gets `status` "audio_ok"
and `measured_s` once its file exists.  Every JP text is model-written and carries np=true ([NP] = native
proofread pending) until a native speaker signs it off.

The same checks run in Godot: game/scripts/v10/voice/voice_registry_selftest.gd (mora counter and all rules are
mirrored there; the registry stores `mora` so the two implementations cross-check each other).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
GAME = REPO / "game"
REG_PATH = GAME / "core" / "voice" / "voice_registry.json"
MD_PATH = REPO / "design" / "voice" / "BETA24_TEXTS.md"

sys.path.insert(0, str(Path(__file__).resolve().parent))

HEROINES = ["mc", "rin", "hana", "yue", "nova", "zlata", "tsubame", "miel", "kohaku", "shirin"]
NAMES = {  # display names: RU and JP (katakana) - used by the "no third-party names" rule
    "mc": ("Маджонг-тян", "マージャン"), "rin": ("Рин", "リン"), "hana": ("Хана", "ハナ"),
    "yue": ("Юэ", "ユエ"), "nova": ("Нова", "ノヴァ"), "zlata": ("Злата", "ズラータ"),
    "tsubame": ("Цубамэ", "ツバメ"), "miel": ("Миэль", "ミエル"), "kohaku": ("Кохаку", "コハク"),
    "shirin": ("Ширин", "シリン"),
}

# --- duration model (kana -> seconds). Tunable; P47 replaces estimates with `measured_s`. -----------------
RATE = 6.5           # mora per second of delivered game voice (natural JP speech is 7-8; TTS "acted" lines slower)
PAUSE = {"、": 0.12, "。": 0.20, "！": 0.15, "？": 0.15, "…": 0.30, "〜": 0.0, "ー": 0.0}
SMALL = set("ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ")
KANA_RE = re.compile(r"^[ぁ-ゖァ-ヺー、。！？…〜]+$")
PUNCT = set("、。！？…〜")

# class -> (min s, max s)
CLASSES = {"call": (0.4, 1.2), "lobby": (1.5, 4.0), "intro": (2.0, 4.0)}

# Beta-24 category table (canonical order). cond = trigger text, pool = playback pool,
# prio = voice priority (GDD 8.5: ron > tsumo > riichi > other; lower number wins).
# NB: the GDD list sums to 27 (see DEC-P44-1 in design/voice/BETA24_TEXTS.md); idle_3, touch_head_2 and combo_t1
# are left to Launch-60.
CATEGORIES = [
    # id, class, pool, group, prio, cond (RU)
    ("login_morning", "lobby", "login", "system", 9, "первый вход за сессию, 05:00-11:00"),
    ("login_evening", "lobby", "login", "system", 9, "первый вход за сессию, 17:00-23:00"),
    ("intro_summon", "intro", "summon_intro", "system", 9, "первое появление героини после призыва (экран призыва), 1 раз; SSR-ритм 3-4 с"),
    ("outfit_equip", "lobby", "outfit", "system", 9, "игрок надел наряд героини (Салон/Гардероб)"),
    ("idle_1", "lobby", "idle", "idle", 9, "главный экран, простой 45-90 с без касаний, Bond 0-5"),
    ("idle_2", "lobby", "idle", "idle", 9, "главный экран, простой 45-90 с без касаний, Bond 0-5"),
    ("idle_warm_1", "lobby", "idle_warm", "idle", 9, "главный экран, простой, Bond >= 6"),
    ("touch_head_1", "lobby", "touch_head", "touch", 9, "касание зоны «голова» (Чайная/Салон), тир Bond 0-2"),
    ("touch_hand_1", "lobby", "touch_hand", "touch", 9, "касание зоны «рука», тир Bond 0-2"),
    ("touch_hair_1", "lobby", "touch_hair", "touch", 9, "касание зоны «волосы», тир Bond 0-2"),
    ("touch_outfit_1", "lobby", "touch_outfit", "touch", 9, "касание зоны «наряд»: смущение без привязки к телу, тир Bond 0-2"),
    ("touch_spam_1", "lobby", "touch_spam", "touch", 9, "3+ касания за 1,3 с"),
    ("touch_bold_1", "lobby", "touch_bold", "touch", 9, "касание, Bond >= 8, тир арта «Полный»; флирт только на игрока"),
    ("gift_normal", "lobby", "gift", "bond", 9, "подарок без предпочтения"),
    ("gift_liked", "lobby", "gift", "bond", 9, "любимый подарок героини"),
    ("level_max_vow", "lobby", "vow", "bond", 9, "Bond 10, церемония «Клятва» (сцена 20-35 с отдельно; это короткая строка-якорь)"),
    ("combo_t2", "call", "combo", "game", 9, "партия: комбо тир 2"),
    ("combo_t3", "call", "combo", "game", 9, "партия: комбо тир 3"),
    ("clear_normal", "lobby", "clear", "game", 9, "уровень пройден (итог партии)"),
    ("fail", "lobby", "fail", "game", 9, "нет ходов / поражение (итог партии)"),
    ("ult_cast", "call", "ult", "game", 9, "активация ульты; голос в первые 0,2 с"),
    ("riichi", "call", "riichi", "game", 3, "объявлено риичи (Riichi-режимы)"),
    ("ron", "call", "ron", "game", 1, "победа по рону (наивысший приоритет голоса)"),
    ("tsumo", "call", "tsumo", "game", 2, "победа цумо"),
]
CAT = {c[0]: c for c in CATEGORIES}

POLICY = {
    "jp_stop": ["胸", "乳", "おっぱい", "お尻", "おしり", "尻", "股", "太もも", "ふともも", "太腿", "膝", "ひざ",
                "谷間", "下着", "パンツ", "スカートの中", "裸", "はだか", "脱", "えっち", "エッチ", "セックス",
                "どこ見", "どこを見", "制服", "学校", "先生", "生徒", "教室", "授業", "酒", "ワイン", "ビール"],
    "ru_stop": ["грудь", "груди", "попка", "попку", "ягодиц", "бёдр", "бедр", "ляж", "трус", "бельё", "белье", "голая",
                "голый", "раздев", "интим", "секс", "коленк", "куда смотришь", "куда пялишься", "вырез",
                "школ", "урок", "учител", "ученик", "вино", "пиво", "водк", "алког"],
    "player_ru": ["ты", "тебя", "тебе", "тобой", "твой", "твоя", "твоё", "твои", "твоей", "твоих", "вам", "вас", "вы"],
    "player_jp": ["あなた", "あんた", "君", "きみ", "キミ"],
}

ID_RE = re.compile(r"^([a-z]+)_([a-z0-9_]+)_([0-9]+)$")
FILE_TEMPLATE = "res://assets/voice/{heroine}/{id}.ogg"


# ---------------------------------------------------------------------------------------------------------
# kana helpers
# ---------------------------------------------------------------------------------------------------------
def mora(s: str) -> int:
    """Count morae of a kana string: every kana and the long-vowel mark counts 1, small ゃゅょ.. count 0
    (they merge into the previous mora); っ ッ ん ン count 1."""
    n = 0
    for ch in s:
        o = ord(ch)
        if (0x3041 <= o <= 0x3096 or 0x30A1 <= o <= 0x30FA or ch == "ー") and ch not in SMALL:
            n += 1
    return n


def pauses(s: str) -> float:
    """Sum of inner pauses (trailing punctuation does not add silence); a run of punctuation counts its max."""
    t = s.rstrip("、。！？…〜 ")
    total, run = 0.0, 0.0
    for ch in t:
        if ch in PUNCT:
            run = max(run, PAUSE.get(ch, 0.0))
        else:
            total += run
            run = 0.0
    return total + run


def estimate(kana: str) -> float:
    return round(mora(kana) / RATE + pauses(kana), 2)


def to_hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in s)


def kana_subsequence_ok(jp: str, kana: str) -> bool:
    """Every kana character written in the display text must appear, in order, in the reading."""
    k = to_hira(kana)
    pos = 0
    for ch in to_hira(jp):
        if 0x3041 <= ord(ch) <= 0x3096:
            j = k.find(ch, pos)
            if j < 0:
                return False
            pos = j + 1
    return True


# ---------------------------------------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------------------------------------
def split_cat(cat: str) -> tuple[str, int]:
    """'idle_1' -> ('idle', 1); single-line categories ('ron') get N=1."""
    m = re.match(r"^(.*)_([0-9]+)$", cat)
    return (m.group(1), int(m.group(2))) if m else (cat, 1)


def build_rows() -> list[dict]:
    from voice_texts_beta24 import TEXTS
    rows = []
    for h in HEROINES:
        t = TEXTS[h]
        missing = [c[0] for c in CATEGORIES if c[0] not in t]
        extra = [k for k in t if k not in CAT]
        if missing or extra:
            raise SystemExit(f"{h}: missing {missing} extra {extra}")
        for cid, klass, pool, group, prio, cond in CATEGORIES:
            jp, kana, ru = t[cid]
            base, n = split_cat(cid)
            lid = f"{h}_{base}_{n}"
            lo, hi = CLASSES[klass]
            rows.append({
                "id": lid, "heroine": h, "category": base, "n": n, "tier": "beta24",
                "jp": jp, "kana": kana, "ru": ru,
                "cond": cond, "pool": pool, "group": group, "class": klass, "priority": prio,
                "mora": mora(kana), "dur_est": estimate(kana), "dur_min": lo, "dur_max": hi,
                "file": FILE_TEMPLATE.format(heroine=h, id=lid),
                "status": "text_draft", "np": True, "measured_s": None,
            })
    return rows


def build_doc(rows: list[dict]) -> dict:
    return {
        "schema": 1,
        "tier": "beta24",
        "note": "Beta-24 x 10 heroines. JP texts are model-written and UNVERIFIED (np=true = [NP], native proofread pending). No audio yet.",
        "rate_mora_per_s": RATE,
        "pause_s": {k: v for k, v in PAUSE.items() if v},
        "classes": {k: {"min_s": v[0], "max_s": v[1]} for k, v in CLASSES.items()},
        "file_template": FILE_TEMPLATE,
        "heroines": HEROINES,
        "categories": [c[0] for c in CATEGORIES],
        "names": {h: {"ru": NAMES[h][0], "jp": NAMES[h][1]} for h in HEROINES},
        "policy": POLICY,
        "lines": rows,
    }


def md_escape(s: str) -> str:
    return s.replace("|", "\\|")


def build_md(rows: list[dict]) -> str:
    out = []
    w = out.append
    w("# Beta-24: тексты реплик, 10 героинь x 24 строки = 240")
    w("")
    w("Сгенерировано `tools/audio/voice_registry.py build` из `tools/audio/voice_texts_beta24.py`. Руками не править: правим источник, запускаем `build`.")
    w("")
    w("**Статус: все 240 JP-строк `[НП]` (проверка носителем не пройдена).** Тексты написала модель; в озвучку (P47) идут только после подписи носителя (действие владельца M8). Озвучки нет: `status = text_draft`, файлов 0 из 240.")
    w("")
    w("## Решения и допущения")
    w("")
    w("- **DEC-P44-1. 27 -> 24.** Перечень Beta-24 в GDD §8.4 при буквальном подсчёте даёт 27 строк (login 2, intro_summon, outfit_equip, idle 3 + idle_warm 1, касания 7, gift 2, level_max_vow, combo_t1-t3, clear, fail, ult_cast, riichi, ron, tsumo), а число в тексте и в P44 — 24. Взято 24: убраны `idle_3` (остаются idle_1, idle_2, idle_warm_1 = «idle x3»), `touch_head_2`, `combo_t1` (самая слабая ступень; остаётся в Launch-60 вместе с `idle_3`, `touch_head_2`). Если владелец хочет иные три — меняется список `CATEGORIES` и тексты, схема не меняется.")
    w("- **Схема id:** `<героиня>_<категория>_<N>`, например `mc_touch_head_1`, `rin_ron_1`. Одиночные строки получают N=1 (`yue_riichi_1`), чтобы схема была одинакова и варианты (Launch-60: `touch_head_2`) добавлялись без переименований.")
    w("- **Длительность по кане:** `mora / 6,5 + паузы` (、0,12 с; 。0,20 с; ！？0,15 с; …0,30 с; хвостовая пунктуация не считается). Мора: каждая кана и `ー` = 1; малые ゃゅょぁぃぅぇぉ = 0; っ и ん = 1. Цели: вызовы (`call`) 0,4-1,2 с; лобби (`lobby`) 1,5-4 с; `intro_summon` 2-4 с (верхняя граница — 4 с по GDD). Это оценка, не измерение: 6,5 мора/с выбрано как середина между естественной речью (7-8) и «актёрским» ИИ-голосом. Старые мp3 в `audio/` (n=18, с хвостовой тишиной) дают 4,2 мора/с по медиане, поэтому P47 обязан записать `measured_s` и при необходимости пересчитать (`RATE` в одном месте).")
    w("- **Приоритет голоса** (GDD §8.5): ron 1 > tsumo 2 > riichi 3 > прочее 9 (меньше = важнее). `pon/chi/kan` (4) в Beta-24 нет.")
    w("- **Красные линии (проверяет тест):** 0 интимных зон в тексте (стоп-лист JP и RU: тело, бельё, «куда смотришь», коленки, школа, алкоголь); 0 упоминаний других героинь; `touch_bold` обращён к игроку (JP и RU содержат второе лицо); `touch_outfit` — смущение без привязки к телу (рукав, маска, шарф, плащ, вуаль, фартук).")
    w("- **Условия касаний Beta-24** заданы для тира Bond 0-2 (кроме `touch_bold`: Bond >= 8). Тиры 3-5, 6-8, 9-10 — пакет касаний (Launch-60).")
    w("- **Лицо к игроку:** обращение у героинь разное (あなた, 君, あんた), как в уже озвученных строках волны 1; Нова и Хана говорят неформально, Рин, Юэ, Миэль — вежливо.")
    w("")
    w("## Как читать таблицы")
    w("")
    w("`JP` — текст для субтитров-источника, `Кана` — чтение (мора, липсинк, TTS), `RU` — субтитр. `с` — оценка длительности (цель в скобках). Столбец `НП` — `[НП]` пока носитель не проверил.")
    w("")
    for h in HEROINES:
        hr = [r for r in rows if r["heroine"] == h]
        w(f"## {NAMES[h][0]} (`{h}`)")
        w("")
        w("| id | JP | Кана | RU | Условие | Пул | с (цель) | НП |")
        w("|---|---|---|---|---|---|---|---|")
        for r in hr:
            tgt = f"{r['dur_min']:g}-{r['dur_max']:g}"
            w(f"| `{r['id']}` | {md_escape(r['jp'])} | {md_escape(r['kana'])} | {md_escape(r['ru'])} | {md_escape(r['cond'])} | `{r['pool']}` | {r['dur_est']:.2f} ({tgt}) | [НП] |")
        w("")
    w("## Проверка")
    w("")
    w("```")
    w("python3 tools/audio/voice_registry.py check          # VOICE_REGISTRY ok/total + VOICE_FILES have/total")
    w("python3 tools/tw_test.py -s voice_registry          # то же в Godot (res://scripts/v10/voice/voice_registry_selftest.gd)")
    w("```")
    w("")
    w("Правила проверки и стоп-листы лежат в блоке `policy` самого `voice_registry.json`; тест требует, чтобы в стоп-листе были базовые слова (нельзя «пройти», опустошив список).")
    w("")
    return "\n".join(out)


def cmd_build(_args) -> int:
    rows = build_rows()
    doc = build_doc(rows)
    REG_PATH.parent.mkdir(parents=True, exist_ok=True)
    REG_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    MD_PATH.parent.mkdir(parents=True, exist_ok=True)
    MD_PATH.write_text(build_md(rows), encoding="utf-8")
    print(f"wrote {REG_PATH.relative_to(REPO)} ({len(rows)} lines) and {MD_PATH.relative_to(REPO)}")
    return 0


# ---------------------------------------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------------------------------------
class Checker:
    def __init__(self):
        self.ok = 0
        self.total = 0
        self.fails: list[str] = []

    def t(self, name: str, cond: bool, detail: str = ""):
        self.total += 1
        if cond:
            self.ok += 1
        else:
            self.fails.append(f"FAIL {name} {detail}".rstrip())


def file_exists(res_path: str) -> bool:
    return (GAME / res_path.removeprefix("res://")).is_file()


def run_checks(doc: dict, strict_files: bool = False) -> tuple[Checker, int, int]:
    c = Checker()
    lines = doc["lines"]
    pol = doc["policy"]
    rate = doc["rate_mora_per_s"]
    cats = doc["categories"]
    heroines = doc["heroines"]

    c.t("heroines.count_10", len(heroines) == 10, str(len(heroines)))
    c.t("categories.count_24", len(cats) == 24, str(len(cats)))
    c.t("lines.count_240", len(lines) == 240, str(len(lines)))
    c.t("policy.jp_stop_core", all(w in pol["jp_stop"] for w in ["胸", "お尻", "太もも", "下着", "どこ見"]))
    c.t("policy.ru_stop_core", all(w in pol["ru_stop"] for w in ["грудь", "коленк", "куда смотришь", "интим"]))
    c.t("policy.player_words", len(pol["player_ru"]) > 3 and len(pol["player_jp"]) > 1)

    ids = [r["id"] for r in lines]
    c.t("ids.unique", len(set(ids)) == len(ids), f"{len(ids) - len(set(ids))} duplicates")
    files = [r["file"] for r in lines]
    c.t("files.unique", len(set(files)) == len(files))

    by_h: dict[str, list[dict]] = {h: [] for h in heroines}
    for r in lines:
        by_h.setdefault(r["heroine"], []).append(r)
    for h in heroines:
        hl = by_h[h]
        c.t(f"{h}.lines_24", len(hl) == 24, str(len(hl)))
        got = [f"{r['category']}_{r['n']}" if f"{r['category']}_{r['n']}" in cats else r["category"] for r in hl]
        c.t(f"{h}.categories_match", sorted(got) == sorted(cats), "")

    for r in lines:
        rid = r["id"]
        m = ID_RE.match(rid)
        c.t(f"{rid}.id_format", bool(m) and m.group(1) == r["heroine"] and m.group(2) == r["category"]
            and int(m.group(3)) == r["n"], rid)
        c.t(f"{rid}.ru_nonempty", bool(r["ru"].strip()))
        c.t(f"{rid}.jp_nonempty", bool(r["jp"].strip()))
        c.t(f"{rid}.kana_charset", bool(KANA_RE.match(r["kana"])), r["kana"])
        c.t(f"{rid}.kana_matches_jp", kana_subsequence_ok(r["jp"], r["kana"]), r["jp"])
        mo = mora(r["kana"])
        c.t(f"{rid}.mora_matches", mo == r["mora"], f"{mo} vs {r['mora']}")
        est = round(mo / rate + pauses(r["kana"]), 2)
        c.t(f"{rid}.dur_est_matches", abs(est - r["dur_est"]) < 0.011, f"{est} vs {r['dur_est']}")
        cl = doc["classes"][r["class"]]
        c.t(f"{rid}.dur_in_range", cl["min_s"] <= r["dur_est"] <= cl["max_s"],
            f"{r['dur_est']} not in [{cl['min_s']},{cl['max_s']}] ({mo} mora) {r['kana']}")
        c.t(f"{rid}.dur_bounds_match_class", r["dur_min"] == cl["min_s"] and r["dur_max"] == cl["max_s"])
        # red lines
        bad_jp = [w for w in pol["jp_stop"] if w in r["jp"] or w in r["kana"]]
        bad_ru = [w for w in pol["ru_stop"] if w in r["ru"].lower()]
        c.t(f"{rid}.stoplist", not bad_jp and not bad_ru, f"{bad_jp}{bad_ru}")
        # no names of other heroines
        names_bad = []
        own_ru, own_jp = doc["names"][r["heroine"]]["ru"], doc["names"][r["heroine"]]["jp"]
        t_ru, t_jp, t_kana = r["ru"].replace(own_ru, ""), r["jp"].replace(own_jp, ""), r["kana"].replace(own_jp, "")
        for h2, nm in doc["names"].items():
            ru2, jp2 = nm["ru"], nm["jp"]
            if h2 == r["heroine"]:
                continue
            if ru2 in t_ru or jp2 in t_jp or jp2 in t_kana:
                names_bad.append(h2)
        c.t(f"{rid}.no_other_heroine", not names_bad, str(names_bad))
        if r["category"] == "touch_bold":
            ru_words = re.findall(r"[а-яё]+", r["ru"].lower())
            c.t(f"{rid}.flirt_targets_player",
                any(w in pol["player_ru"] for w in ru_words) and any(w in r["jp"] for w in pol["player_jp"]),
                r["jp"])
        c.t(f"{rid}.np_flag", r["np"] is True or r["status"] != "text_draft")
        c.t(f"{rid}.file_path", r["file"] == doc["file_template"].format(heroine=r["heroine"], id=rid), r["file"])
    # priority ladder ron > tsumo > riichi > other
    pr = {r["category"]: r["priority"] for r in lines}
    c.t("priority.ladder", pr["ron"] < pr["tsumo"] < pr["riichi"] < pr["combo_t2"] <= 9)

    have = sum(1 for r in lines if file_exists(r["file"]))
    if strict_files:
        c.t("files.all_exist", have == len(lines), f"{have}/{len(lines)}")
    return c, have, len(lines)


def cmd_check(args) -> int:
    doc = json.loads(REG_PATH.read_text(encoding="utf-8"))
    c, have, n = run_checks(doc, args.strict_files)
    for f in c.fails[:60]:
        print(f)
    if len(c.fails) > 60:
        print(f"... {len(c.fails) - 60} more")
    print(f"VOICE_FILES {have}/{n} {100.0 * have / max(n, 1):.1f}%")
    print(f"VOICE_REGISTRY {c.ok}/{c.total}")
    return 0 if c.ok == c.total else 1


def cmd_coverage(_args) -> int:
    doc = json.loads(REG_PATH.read_text(encoding="utf-8"))
    per = {}
    for r in doc["lines"]:
        a = per.setdefault(r["heroine"], [0, 0])
        a[1] += 1
        a[0] += 1 if file_exists(r["file"]) else 0
    for h, (a, b) in per.items():
        print(f"{h:8} {a:3}/{b}")
    have = sum(v[0] for v in per.values())
    n = sum(v[1] for v in per.values())
    print(f"VOICE_FILES {have}/{n} {100.0 * have / max(n, 1):.1f}%")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build").set_defaults(fn=cmd_build)
    p = sub.add_parser("check")
    p.add_argument("--strict-files", action="store_true", help="fail unless every line has its audio file")
    p.set_defaults(fn=cmd_check)
    sub.add_parser("coverage").set_defaults(fn=cmd_coverage)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
