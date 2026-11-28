#!/usr/bin/env python3
"""Validator for Tile Waifu G5 Russian text bank (Brief B + FIX_ROUND1).

Checks:
1. Exactly 10 heroine JSON files (mc, rin, hana, yue, nova, tsubame, miel, kohaku, shirin, zlata).
2. Exactly 32 entries per heroine (24 beta24 + 8 ssr_outfit), with required keys {id, text, emotion, max_words}.
3. 100% exact match (240/240) of tier=beta24 RU texts against design/voice/BETA24_TEXTS.md and
   game/core/voice/voice_registry.json.
4. Canonical SSR skin_id schema: ssr_skin_id, ssr_outfit_ref == '<legacy_outfit> / <skin_id>' matching
   design/specs/ult_catalogue.json; non-ult IDs match '<hero>.<skin_id>.<type>.<nn>' (SKIN_HUD_SYSTEM §6.1);
   ult IDs match '<skin_id>_ult_cast_<N>' in ult_catalogue.json voice_cues and match canonical voice[] when defined.
5. Pool-specific max_words: calls (combo/ult/riichi/ron) <= 3 words, tsumo <= 4 words, lobby/intro <= 12 words
   (checked on both hyphen-joined and hyphen-split word counts).
6. Zero Latin characters [A-Za-z] and zero tilde [~〜] in all 320 RU voice lines.
7. Global uniqueness of all 320 line IDs, per-heroine uniqueness of all 32 normalized texts,
   and global uniqueness of all non-call normalized texts across heroines.
8. Red-line compliance: expanded FORBIDDEN_PATTERNS (including non-word-start roots), zero cross-heroine
   mentions, touch_bold second-person player targeting.
9. liveops_events.json has exactly 12 Year-1 events with unique ids/titles, 1..2 sentence descriptions,
   expanded anti-FOMO patterns, and paid-bundle clarity guard.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent.parent
BETA24_MD_PATH = REPO_ROOT / "design" / "voice" / "BETA24_TEXTS.md"
VOICE_REG_PATH = REPO_ROOT / "game" / "core" / "voice" / "voice_registry.json"
ULT_CATALOGUE_PATH = REPO_ROOT / "design" / "specs" / "ult_catalogue.json"

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

HEROINE_NAMES_RU = {
    "mc": "Маджонг-тян",
    "rin": "Рин",
    "hana": "Хана",
    "yue": "Юэ",
    "nova": "Нова",
    "tsubame": "Цубамэ",
    "miel": "Миэль",
    "kohaku": "Кохаку",
    "shirin": "Ширин",
    "zlata": "Злата",
}

PLAYER_RU_WORDS = {
    "ты",
    "тебя",
    "тебе",
    "тобой",
    "твой",
    "твоя",
    "твоё",
    "твои",
    "твоей",
    "твоих",
    "вам",
    "вас",
    "вы",
    "ваш",
    "ваша",
}

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

CALL_SLOTS_MAX3 = {
    "combo_t2",
    "combo_t3",
    "ult_cast",
    "riichi",
    "ron",
    "ult_cast_a",
    "ult_cast_b",
}
CALL_SLOTS_MAX4 = {"tsumo"}
CALL_SLOTS = CALL_SLOTS_MAX3 | CALL_SLOTS_MAX4

FORBIDDEN_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("school", re.compile(r"школ\w*", re.IGNORECASE | re.UNICODE)),
    ("pupil_adj", re.compile(r"ученическ\w*", re.IGNORECASE | re.UNICODE)),
    ("student_f", re.compile(r"учениц\w*", re.IGNORECASE | re.UNICODE)),
    ("student_m", re.compile(r"ученик\w*", re.IGNORECASE | re.UNICODE)),
    ("uni_student", re.compile(r"студент\w*", re.IGNORECASE | re.UNICODE)),
    ("lyceum", re.compile(r"лице[йяюе]\w*", re.IGNORECASE | re.UNICODE)),
    ("gymnasium", re.compile(r"гимназ\w*", re.IGNORECASE | re.UNICODE)),
    ("college", re.compile(r"колледж\w*", re.IGNORECASE | re.UNICODE)),
    ("teacher", re.compile(r"учител\w*", re.IGNORECASE | re.UNICODE)),
    ("lesson", re.compile(r"\bурок\w*", re.IGNORECASE | re.UNICODE)),
    ("retake", re.compile(r"пересдач\w*", re.IGNORECASE | re.UNICODE)),
    ("academy", re.compile(r"академ\w*", re.IGNORECASE | re.UNICODE)),
    ("classroom", re.compile(r"\bкласс\w*", re.IGNORECASE | re.UNICODE)),
    ("desk", re.compile(r"\bпарт[аыуео]\w*", re.IGNORECASE | re.UNICODE)),
    ("seifuku", re.compile(r"сейфуку\w*", re.IGNORECASE | re.UNICODE)),
    ("backpack", re.compile(r"\bранец\w*", re.IGNORECASE | re.UNICODE)),
    ("loli", re.compile(r"лоли\w*", re.IGNORECASE | re.UNICODE)),
    ("child_yo", re.compile(r"ребён\w*", re.IGNORECASE | re.UNICODE)),
    ("child_e", re.compile(r"ребен\w*", re.IGNORECASE | re.UNICODE)),
    ("girl_child", re.compile(r"девоч\w*", re.IGNORECASE | re.UNICODE)),
    ("girl_young", re.compile(r"девчонк\w*", re.IGNORECASE | re.UNICODE)),
    ("minor_age", re.compile(r"малолетк\w*", re.IGNORECASE | re.UNICODE)),
    ("kids", re.compile(r"детск\w*|\bдети\b|\bдетей\b", re.IGNORECASE | re.UNICODE)),
    ("baby", re.compile(r"малыш\w*", re.IGNORECASE | re.UNICODE)),
    ("teen", re.compile(r"подрост\w*|несовершенн\w*", re.IGNORECASE | re.UNICODE)),
    ("nudity", re.compile(r"нагот\w*|обнаж\w*|\bголы\w*|\bголая\b|\bголое\b", re.IGNORECASE | re.UNICODE)),
    ("sex", re.compile(r"секс\w*|интим\w*|эротик\w*|порн\w*", re.IGNORECASE | re.UNICODE)),
    ("undress", re.compile(r"разден\w*|раздет\w*|раздев\w*", re.IGNORECASE | re.UNICODE)),
    ("lingerie", re.compile(r"\bбель[еёя]\w*|\bтрус[ыи]\w*|лифчик\w*", re.IGNORECASE | re.UNICODE)),
    ("anatomy", re.compile(r"\bсоск\w*|генитал\w*|\bгруд[ьия]\w*|ягодиц\w*|\bбёдр\w*|\bбедр\w*", re.IGNORECASE | re.UNICODE)),
    ("body_gaze", re.compile(r"куда\s+смотришь|куда\s+пялишься|коленк\w*", re.IGNORECASE | re.UNICODE)),
    ("alcohol", re.compile(r"алкогол\w*|\bвин[оауе]\b|\bпив[оауе]\b|\bводк\w*|пьян\w*", re.IGNORECASE | re.UNICODE)),
]

FOMO_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("hurry", re.compile(r"\bуспей\w*", re.IGNORECASE | re.UNICODE)),
    ("dont_miss", re.compile(r"не\s+упусти\w*", re.IGNORECASE | re.UNICODE)),
    ("last_chance", re.compile(r"последн\w+\s+шанс\w*", re.IGNORECASE | re.UNICODE)),
    ("only_today", re.compile(r"только\s+сегодня", re.IGNORECASE | re.UNICODE)),
    ("only_now", re.compile(r"только\s+сейчас", re.IGNORECASE | re.UNICODE)),
    ("remaining", re.compile(r"\bостал[оаи]сь\b", re.IGNORECASE | re.UNICODE)),
    ("exclusive", re.compile(r"эксклюзив\w*", re.IGNORECASE | re.UNICODE)),
    ("limited", re.compile(r"лимитирован\w*", re.IGNORECASE | re.UNICODE)),
    ("black_friday", re.compile(r"ч[её]рн\w+\s+пятниц\w*", re.IGNORECASE | re.UNICODE)),
    ("discount", re.compile(r"\bскидк\w*|распродаж\w*", re.IGNORECASE | re.UNICODE)),
    ("best_value", re.compile(r"выгодн\w+\s+всего", re.IGNORECASE | re.UNICODE)),
    ("never_returns", re.compile(r"исчезнет\s+навсегда|больше\s+не\s+верн[её]тся", re.IGNORECASE | re.UNICODE)),
]

WORD_RE = re.compile(r"[A-Za-zА-Яа-яЁё0-9]+(?:-[A-Za-zА-Яа-яЁё0-9]+)*", re.UNICODE)
SPLIT_WORD_RE = re.compile(r"[A-Za-zА-Яа-яЁё0-9]+", re.UNICODE)
LATIN_RE = re.compile(r"[A-Za-z]")
TILDE_RE = re.compile(r"[~〜]")
NON_ULT_SSR_ID_RE = re.compile(r"^([a-z]+)\.([a-z0-9_]+)\.([a-z0-9_]+)\.(\d{2})$")
ULT_SSR_ID_RE = re.compile(r"^([a-z0-9_]+)_ult_cast_(\d+)$")


def count_words(text: str) -> int:
    return len(WORD_RE.findall(text))


def count_words_split(text: str) -> int:
    return len(SPLIT_WORD_RE.findall(text))


def normalize_text(text: str) -> str:
    return " ".join(w.lower() for w in WORD_RE.findall(text))


def check_forbidden(text: str, patterns: list[tuple[str, re.Pattern[str]]]) -> list[str]:
    hits: list[str] = []
    for label, regex in patterns:
        m = regex.search(text)
        if m:
            hits.append(f"{label}='{m.group(0)}'")
    return hits


def load_beta24_canon() -> dict[str, str]:
    if not BETA24_MD_PATH.exists():
        return {}
    text = BETA24_MD_PATH.read_text(encoding="utf-8")
    rows = re.findall(
        r"^\| `([a-z0-9_]+)` \| [^|]+ \| [^|]+ \| ([^|]+) \| [^|]+ \| `[^`]+` \|",
        text,
        re.M,
    )
    return {lid: ru.strip() for lid, ru in rows}


def load_ult_catalogue() -> dict[str, dict]:
    if not ULT_CATALOGUE_PATH.exists():
        return {}
    doc = json.loads(ULT_CATALOGUE_PATH.read_text(encoding="utf-8"))
    return {u["id"]: u for u in doc.get("ults", [])}


def validate() -> int:
    errors: list[str] = []
    seen_ids: dict[str, str] = {}
    seen_non_call_texts: dict[str, str] = {}
    heroine_summaries: list[str] = []
    total_lines = 0
    max_words_observed = 0
    beta24_matched = 0

    canon_beta24 = load_beta24_canon()
    if len(canon_beta24) != 240:
        errors.append(f"BETA24_TEXTS.md: expected 240 canon rows, got {len(canon_beta24)}")

    if VOICE_REG_PATH.exists():
        reg_doc = json.loads(VOICE_REG_PATH.read_text(encoding="utf-8"))
        reg_map = {r["id"]: r["ru"] for r in reg_doc.get("lines", [])}
        if reg_map != canon_beta24:
            errors.append("voice_registry.json RU strings out of sync with BETA24_TEXTS.md")
    else:
        errors.append("MISSING file: game/core/voice/voice_registry.json")

    ults_by_id = load_ult_catalogue()
    if not ults_by_id:
        errors.append("MISSING or empty: design/specs/ult_catalogue.json")

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

        ssr_skin_id = str(data.get("ssr_skin_id", "")).strip()
        ssr_outfit_ref = str(data.get("ssr_outfit_ref", "")).strip()
        ult_entry = ults_by_id.get(ssr_skin_id)
        if not ssr_skin_id or ult_entry is None:
            errors.append(f"{path.name}: invalid or missing ssr_skin_id={ssr_skin_id!r}")
        else:
            if ult_entry.get("hero") != hid or ult_entry.get("tier") not in ("SSR", "SSRP"):
                errors.append(
                    f"{path.name}: ssr_skin_id={ssr_skin_id!r} is not an SSR/SSRP skin for {hid}"
                )
            exp_ref = f"{ult_entry.get('legacy_outfit', '')} / {ssr_skin_id}"
            if ssr_outfit_ref != exp_ref:
                errors.append(f"{path.name}: ssr_outfit_ref={ssr_outfit_ref!r} != expected {exp_ref!r}")

        lines = data.get("lines")
        if not isinstance(lines, list):
            errors.append(f"{path.name}: 'lines' must be a list")
            continue

        if len(lines) != 32:
            errors.append(f"{path.name}: expected 32 lines, got {len(lines)}")

        beta_slots: set[str] = set()
        ssr_slots: set[str] = set()
        heroine_texts: dict[str, str] = {}
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

            # Pool-specific max_words enforcement
            if slot in CALL_SLOTS_MAX3:
                pool_cap = 3
            elif slot in CALL_SLOTS_MAX4:
                pool_cap = 4
            else:
                pool_cap = 12

            if not isinstance(max_w, int) or max_w < 1 or max_w > pool_cap:
                errors.append(f"{path.name}({lid}): invalid max_words={max_w} for slot={slot!r} (cap={pool_cap})")

            wc = count_words(text)
            wc_split = count_words_split(text)
            h_max_w = max(h_max_w, wc_split)
            max_words_observed = max(max_words_observed, wc_split)
            if wc < 1 or wc > pool_cap or wc_split > pool_cap or (isinstance(max_w, int) and (wc > max_w or wc_split > max_w)):
                errors.append(
                    f"{path.name}({lid}): word count joined={wc}/split={wc_split} exceeds max_words={max_w} (cap={pool_cap}): {text!r}"
                )

            if LATIN_RE.search(text):
                errors.append(f"LATIN in {path.name}({lid}): {text!r}")
            if TILDE_RE.search(text):
                errors.append(f"TILDE in {path.name}({lid}): {text!r}")

            if lid in seen_ids:
                errors.append(f"DUPLICATE id '{lid}' in {path.name} and {seen_ids[lid]}")
            else:
                seen_ids[lid] = path.name

            norm = normalize_text(text)
            if norm in heroine_texts:
                errors.append(f"DUPLICATE text within {path.name}: {lid} and {heroine_texts[norm]}: {text!r}")
            else:
                heroine_texts[norm] = lid

            if slot not in CALL_SLOTS:
                if norm in seen_non_call_texts:
                    errors.append(
                        f"DUPLICATE non-call text in {path.name}({lid}) and {seen_non_call_texts[norm]}: {text!r}"
                    )
                else:
                    seen_non_call_texts[norm] = f"{path.name}({lid})"

            hits = check_forbidden(text, FORBIDDEN_PATTERNS)
            if hits:
                errors.append(f"FORBIDDEN in {path.name}({lid}): {', '.join(hits)} | {text!r}")

            # Zero cross-heroine name mentions
            own_name = HEROINE_NAMES_RU[hid]
            stripped = text.replace(own_name, "")
            for other_hid, other_name in HEROINE_NAMES_RU.items():
                if other_hid != hid and other_name in stripped:
                    errors.append(f"CROSS_MENTION in {path.name}({lid}): mentions {other_name!r}")

            # touch_bold must address the player in second person
            if slot == "touch_bold":
                words_low = {w.lower() for w in SPLIT_WORD_RE.findall(text)}
                if not (words_low & PLAYER_RU_WORDS):
                    errors.append(f"TOUCH_BOLD_NO_PLAYER in {path.name}({lid}): {text!r}")

            if tier == "beta24" and slot:
                beta_slots.add(slot)
                canon_ru = canon_beta24.get(lid)
                if canon_ru != text:
                    errors.append(
                        f"BETA24_DRIFT in {path.name}({lid}): bank={text!r} != canon={canon_ru!r}"
                    )
                else:
                    beta24_matched += 1
            elif tier == "ssr_outfit" and slot:
                ssr_slots.add(slot)
                if item.get("skin_id") != ssr_skin_id:
                    errors.append(f"{path.name}({lid}): skin_id={item.get('skin_id')!r} != {ssr_skin_id!r}")
                if slot in ("ult_cast_a", "ult_cast_b"):
                    m = ULT_SSR_ID_RE.match(lid)
                    if not m or m.group(1) != ssr_skin_id:
                        errors.append(f"{path.name}({lid}): ult id must match '{ssr_skin_id}_ult_cast_<N>'")
                    elif ult_entry is not None:
                        if lid not in ult_entry.get("voice_cues", []):
                            errors.append(f"{path.name}({lid}): not in ult_catalogue voice_cues")
                        canon_voices = ult_entry.get("voice", [])
                        cidx = int(m.group(2)) - 1
                        if canon_voices and 0 <= cidx < len(canon_voices) and text != canon_voices[cidx]:
                            errors.append(
                                f"{path.name}({lid}): ult text={text!r} != canon {canon_voices[cidx]!r}"
                            )
                else:
                    m = NON_ULT_SSR_ID_RE.match(lid)
                    if not m or m.group(1) != hid or m.group(2) != ssr_skin_id:
                        errors.append(
                            f"{path.name}({lid}): SSR id must match '{hid}.{ssr_skin_id}.<type>.<nn>'"
                        )

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
            f"  [OK] {hid:8s}: {len(lines):2d} lines (24 beta24 + 8 ssr [{ssr_skin_id}]), max_words={h_max_w}"
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
                if re.search(r"заберите\s+[^.]*набор", desc, re.IGNORECASE | re.UNICODE):
                    errors.append(f"PAID_BUNDLE_AS_PRIZE in liveops({eid}): {desc!r}")
                if re.search(r"свет[ауе]?\s+оазиса", combined, re.IGNORECASE | re.UNICODE):
                    errors.append(f"WRONG_SKIN_NAME in liveops({eid}): use 'Огни оазиса'")
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
    print(f"Total voice lines checked: {total_lines} / 320 (beta24_canon_match={beta24_matched}/240)")
    print(f"Max words per voice line (hyphen-split): {max_words_observed} / 12")
    print(f"LiveOps Year-1 events checked: {events_count} / 12")
    print(f"Validation violations: {len(errors)}")
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
