#!/usr/bin/env python3
"""Validator for Tile Waifu G5 Russian text bank (Brief B).

Checks:
1. Exactly 10 heroine JSON files (mc, rin, hana, yue, nova, tsubame, miel, kohaku, shirin, zlata).
2. Exactly 32 entries per heroine (24 beta24 + 8 ssr_outfit), with required keys {id, text, emotion, max_words}.
3. Every heroine line has 1..12 words (and <= max_words).
4. Global uniqueness of all 320 line IDs and normalized line texts.
5. liveops_events.json has exactly 12 Year-1 events with unique ids/titles and 1..2 sentence descriptions.
6. Zero forbidden roots (school/child/nudity/sex/alcohol/body-gaze; plus anti-FOMO on liveops events).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

EXPECTED_HEROINES = [
    "mc",
    "rin",
    "hana",
    "yue",
    "nova",
    "tsubame",
    "miel",
    "kohaku",
    "shirin",
    "zlata",
]

REQUIRED_LINE_KEYS = {"id", "text", "emotion", "max_words"}

EXPECTED_BETA24_SLOTS = {
    "login_morning",
    "login_evening",
    "intro_summon",
    "outfit_equip",
    "idle_1",
    "idle_2",
    "idle_warm",
    "touch_head",
    "touch_hand",
    "touch_hair",
    "touch_outfit",
    "touch_spam",
    "touch_bold",
    "gift_normal",
    "gift_liked",
    "level_max_vow",
    "combo_t2",
    "combo_t3",
    "clear",
    "fail",
    "ult_cast",
    "riichi",
    "ron",
    "tsumo",
}

EXPECTED_SSR_SLOTS = {
    "outfit_new",
    "idle_2",
    "touch_2",
    "level_vow",
    "ult_cast_a",
    "ult_cast_b",
    "equip",
    "win",
}

FORBIDDEN_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("school", re.compile(r"\bшкол\w*", re.IGNORECASE | re.UNICODE)),
    ("student_f", re.compile(r"\bучениц\w*", re.IGNORECASE | re.UNICODE)),
    ("student_m", re.compile(r"\bученик\w*", re.IGNORECASE | re.UNICODE)),
    ("teacher", re.compile(r"\bучител\w*", re.IGNORECASE | re.UNICODE)),
    ("lesson", re.compile(r"\bурок\w*", re.IGNORECASE | re.UNICODE)),
    ("retake", re.compile(r"\bпересдач\w*", re.IGNORECASE | re.UNICODE)),
    ("academy", re.compile(r"\bакадем\w*", re.IGNORECASE | re.UNICODE)),
    ("classroom", re.compile(r"\bкласс\w*", re.IGNORECASE | re.UNICODE)),
    ("desk", re.compile(r"\bпарт[аыуео]\w*", re.IGNORECASE | re.UNICODE)),
    ("seifuku", re.compile(r"\bсейфуку\w*", re.IGNORECASE | re.UNICODE)),
    ("backpack", re.compile(r"\bранец\w*", re.IGNORECASE | re.UNICODE)),
    ("loli", re.compile(r"\bлоли\w*", re.IGNORECASE | re.UNICODE)),
    ("child_yo", re.compile(r"\bребён\w*", re.IGNORECASE | re.UNICODE)),
    ("child_e", re.compile(r"\bребен\w*", re.IGNORECASE | re.UNICODE)),
    ("girl_child", re.compile(r"\bдевоч\w*", re.IGNORECASE | re.UNICODE)),
    ("kids", re.compile(r"\bдетск\w*|\bдети\b|\bдетей\b", re.IGNORECASE | re.UNICODE)),
    ("baby", re.compile(r"\bмалыш\w*", re.IGNORECASE | re.UNICODE)),
    ("teen", re.compile(r"\bподрост\w*|\bнесовершенн\w*", re.IGNORECASE | re.UNICODE)),
    ("nudity", re.compile(r"\bнагот\w*|\bобнаж\w*|\bголы\w*|\bголая\b|\bголое\b", re.IGNORECASE | re.UNICODE)),
    ("sex", re.compile(r"\bсекс\w*|\bинтим\w*|\bэротик\w*|\bпорн\w*", re.IGNORECASE | re.UNICODE)),
    ("undress", re.compile(r"\bразден\w*|\bраздет\w*", re.IGNORECASE | re.UNICODE)),
    ("lingerie", re.compile(r"\bбель[еёя]\w*|\bтрус[ыи]\w*|\bлифчик\w*", re.IGNORECASE | re.UNICODE)),
    ("anatomy", re.compile(r"\bсоск\w*|\bгенитал\w*|\bгруд[ьия]\w*|\bягодиц\w*|\bбёдр\w*|\bбедр\w*", re.IGNORECASE | re.UNICODE)),
    ("body_gaze", re.compile(r"куда\s+смотришь|\bколенк\w*", re.IGNORECASE | re.UNICODE)),
    ("alcohol", re.compile(r"\bалкогол\w*|\bвин[оауе]\b|\bпьян\w*", re.IGNORECASE | re.UNICODE)),
]

FOMO_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("hurry", re.compile(r"\bуспей\w*", re.IGNORECASE | re.UNICODE)),
    ("last_chance", re.compile(r"последн\w+\s+шанс\w*", re.IGNORECASE | re.UNICODE)),
    ("black_friday", re.compile(r"ч[её]рн\w+\s+пятниц\w*", re.IGNORECASE | re.UNICODE)),
    ("discount", re.compile(r"\bскидк\w*", re.IGNORECASE | re.UNICODE)),
]

WORD_RE = re.compile(r"[A-Za-zА-Яа-яЁё0-9]+(?:-[A-Za-zА-Яа-яЁё0-9]+)*", re.UNICODE)


def count_words(text: str) -> int:
    return len(WORD_RE.findall(text))


def normalize_text(text: str) -> str:
    return " ".join(w.lower() for w in WORD_RE.findall(text))


def check_forbidden(text: str, patterns: list[tuple[str, re.Pattern[str]]]) -> list[str]:
    hits: list[str] = []
    for label, regex in patterns:
        m = regex.search(text)
        if m:
            hits.append(f"{label}='{m.group(0)}'")
    return hits


def validate() -> int:
    errors: list[str] = []
    seen_ids: dict[str, str] = {}
    seen_texts: dict[str, str] = {}
    heroine_summaries: list[str] = []
    total_lines = 0
    max_words_observed = 0

    for hid in EXPECTED_HEROINES:
        path = BASE_DIR / f"{hid}.json"
        if not path.exists():
            errors.append(f"MISSING file: {path.name}")
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"INVALID JSON in {path.name}: {exc}")
            continue

        lines = data.get("lines")
        if not isinstance(lines, list):
            errors.append(f"{path.name}: 'lines' must be a list")
            continue

        if len(lines) != 32:
            errors.append(f"{path.name}: expected 32 lines, got {len(lines)}")

        beta_slots: set[str] = set()
        ssr_slots: set[str] = set()
        h_max_w = 0

        for idx, item in enumerate(lines, start=1):
            if not isinstance(item, dict):
                errors.append(f"{path.name}[{idx}]: entry must be object")
                continue
            missing = REQUIRED_LINE_KEYS - set(item.keys())
            if missing:
                errors.append(f"{path.name}[{idx}]: missing keys {sorted(missing)}")
                continue

            lid = str(item["id"]).strip()
            text = str(item["text"]).strip()
            emotion = str(item["emotion"]).strip()
            max_w = item["max_words"]
            tier = item.get("tier")
            slot = item.get("slot")

            if not lid or not text or not emotion:
                errors.append(f"{path.name}[{idx}]: empty id/text/emotion")
            if not isinstance(max_w, int) or max_w > 12 or max_w < 1:
                errors.append(f"{path.name}({lid}): invalid max_words={max_w}")

            wc = count_words(text)
            h_max_w = max(h_max_w, wc)
            max_words_observed = max(max_words_observed, wc)
            if wc < 1 or wc > 12 or (isinstance(max_w, int) and wc > max_w):
                errors.append(f"{path.name}({lid}): word count {wc} > 12: {text!r}")

            if lid in seen_ids:
                errors.append(f"DUPLICATE id '{lid}' in {path.name} and {seen_ids[lid]}")
            else:
                seen_ids[lid] = path.name

            norm = normalize_text(text)
            if norm in seen_texts:
                errors.append(f"DUPLICATE text in {path.name}({lid}) and {seen_texts[norm]}: {text!r}")
            else:
                seen_texts[norm] = f"{path.name}({lid})"

            hits = check_forbidden(text, FORBIDDEN_PATTERNS)
            if hits:
                errors.append(f"FORBIDDEN in {path.name}({lid}): {', '.join(hits)} | {text!r}")

            if tier == "beta24" and slot:
                beta_slots.add(slot)
            elif tier == "ssr_outfit" and slot:
                ssr_slots.add(slot)

        if beta_slots != EXPECTED_BETA24_SLOTS:
            diff_missing = sorted(EXPECTED_BETA24_SLOTS - beta_slots)
            diff_extra = sorted(beta_slots - EXPECTED_BETA24_SLOTS)
            errors.append(f"{path.name}: beta24 slots mismatch missing={diff_missing} extra={diff_extra}")
        if ssr_slots != EXPECTED_SSR_SLOTS:
            diff_missing = sorted(EXPECTED_SSR_SLOTS - ssr_slots)
            diff_extra = sorted(ssr_slots - EXPECTED_SSR_SLOTS)
            errors.append(f"{path.name}: ssr_outfit slots mismatch missing={diff_missing} extra={diff_extra}")

        total_lines += len(lines)
        heroine_summaries.append(
            f"  [OK] {hid:8s}: {len(lines):2d} lines (24 beta24 + 8 ssr), max_words={h_max_w}"
        )

    # Validate liveops_events.json
    liveops_path = BASE_DIR / "liveops_events.json"
    events_count = 0
    if not liveops_path.exists():
        errors.append("MISSING file: liveops_events.json")
    else:
        try:
            ev_data = json.loads(liveops_path.read_text(encoding="utf-8"))
            events = ev_data.get("events", [])
            events_count = len(events)
            if events_count != 12:
                errors.append(f"liveops_events.json: expected 12 events, got {events_count}")
            ev_ids: set[str] = set()
            ev_titles: set[str] = set()
            for idx, ev in enumerate(events, start=1):
                eid = str(ev.get("id", "")).strip()
                title = str(ev.get("title", "")).strip()
                desc = str(ev.get("description", "")).strip()
                if not eid or not title or not desc:
                    errors.append(f"liveops_events.json[{idx}]: empty id/title/description")
                if eid in ev_ids:
                    errors.append(f"liveops_events.json: duplicate event id {eid}")
                ev_ids.add(eid)
                if title.lower() in ev_titles:
                    errors.append(f"liveops_events.json: duplicate event title {title}")
                ev_titles.add(title.lower())
                sentences = [s for s in re.split(r"[.!?]+", desc) if s.strip()]
                if not (1 <= len(sentences) <= 2):
                    errors.append(
                        f"liveops_events.json({eid}): expected 1-2 sentences, got {len(sentences)}"
                    )
                combined = f"{title} {desc}"
                for hits_list, kind in [
                    (check_forbidden(combined, FORBIDDEN_PATTERNS), "FORBIDDEN"),
                    (check_forbidden(combined, FOMO_PATTERNS), "FOMO"),
                ]:
                    if hits_list:
                        errors.append(f"{kind} in liveops({eid}): {', '.join(hits_list)}")
        except Exception as exc:
            errors.append(f"INVALID JSON in liveops_events.json: {exc}")

    print("=== Tile Waifu G5 Text Bank Validation ===")
    for line in heroine_summaries:
        print(line)
    print(f"Total heroines checked: {len(EXPECTED_HEROINES)} / 10")
    print(f"Total voice lines checked: {total_lines} / 320 (unique={len(seen_texts)})")
    print(f"Max words per voice line: {max_words_observed} / 12")
    print(f"LiveOps Year-1 events checked: {events_count} / 12")
    print(f"Forbidden/FOMO violations: {len(errors)}")
    if errors:
        print("ERRORS:")
        for err in errors:
            print(f"  - {err}")
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS (all 10 heroines x 32 lines + 12 liveops events valid)")
    return 0


if __name__ == "__main__":
    sys.exit(validate())
