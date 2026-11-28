#!/usr/bin/env python3
"""Regression & acceptance tests for G5 Russian Text Bank (FIX_ROUND1 ## texts).

Covers all 3 Confirmed MAJOR and 9 Confirmed MINOR findings from design/ext/FIX_ROUND1.md.
Run:
    python -m unittest discover -s design/ext/text_bank -p "test_*.py" -v
"""

from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

TEXT_BANK_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEXT_BANK_DIR.parent.parent.parent
BETA24_MD = REPO_ROOT / "design" / "voice" / "BETA24_TEXTS.md"
VOICE_REG_JSON = REPO_ROOT / "game" / "core" / "voice" / "voice_registry.json"
ULT_CAT_JSON = REPO_ROOT / "design" / "specs" / "ult_catalogue.json"
SKINS_JSON = REPO_ROOT / "data" / "skins.json"
LIVEOPS_JSON = TEXT_BANK_DIR / "liveops_events.json"

sys.path.insert(0, str(TEXT_BANK_DIR))
import validate_text_bank as vtb  # noqa: E402

HEROINES = [
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

EXPECTED_SSR_SKIN_MAP = {
    "mc": ("o_dragon", "mc_ssrp_dragonnight"),
    "rin": ("r_idol", "rin_ssr_bunnytea"),
    "hana": ("h_beach", "hana_ssr_beach"),
    "yue": ("y_duel", "yue_ssr_scalearmor"),
    "nova": ("n_diva", "nova_ssrp_idolstage"),
    "zlata": ("zl_ember", "zlata_ssr_firebird"),
    "tsubame": ("tb_crimson", "tsubame_ssr_ninjarose"),
    "miel": ("me_gala", "miel_ssr_seaside"),
    "kohaku": ("ko_kyubi", "kohaku_ssrp_moonfest"),
    "shirin": ("sh_sun", "shirin_ssrp_oasislight"),
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

SPLIT_WORD_RE = re.compile(r"[A-Za-zА-Яа-яЁё0-9]+", re.UNICODE)
LATIN_RE = re.compile(r"[A-Za-z]")
TILDE_RE = re.compile(r"[~〜]")


def load_heroine(hid: str) -> dict:
    return json.loads((TEXT_BANK_DIR / f"{hid}.json").read_text(encoding="utf-8"))


def parse_beta24_md() -> dict[str, str]:
    text = BETA24_MD.read_text(encoding="utf-8")
    rows = re.findall(
        r"^\| `([a-z0-9_]+)` \| [^|]+ \| [^|]+ \| ([^|]+) \| [^|]+ \| `[^`]+` \|",
        text,
        re.M,
    )
    return {lid: ru.strip() for lid, ru in rows}


def load_ult_catalogue() -> dict[str, dict]:
    doc = json.loads(ULT_CAT_JSON.read_text(encoding="utf-8"))
    return {u["id"]: u for u in doc["ults"]}


class TestTextBankFixRound1(unittest.TestCase):
    # --- MAJOR 1 ---
    def test_major1_beta24_matches_canon_240_of_240(self) -> None:
        canon_md = parse_beta24_md()
        self.assertEqual(len(canon_md), 240, "BETA24_TEXTS.md must have 240 rows")

        reg = json.loads(VOICE_REG_JSON.read_text(encoding="utf-8"))
        canon_reg = {r["id"]: r["ru"] for r in reg["lines"]}
        self.assertEqual(canon_md, canon_reg, "BETA24_TEXTS.md and voice_registry.json must match")

        mismatches = []
        matched = 0
        for hid in HEROINES:
            data = load_heroine(hid)
            for item in data["lines"]:
                if item.get("tier") != "beta24":
                    continue
                lid = item["id"]
                expected = canon_md.get(lid)
                actual = item["text"]
                if actual == expected:
                    matched += 1
                else:
                    mismatches.append(f"{lid}: bank={actual!r} != canon={expected!r}")

        self.assertEqual(
            matched,
            240,
            f"Only {matched}/240 Beta-24 RU strings match BETA24_TEXTS.md; sample: {mismatches[:5]}",
        )

    # --- MAJOR 2 ---
    def test_major2_ssr_skin_id_schema_refs_and_ult_cues(self) -> None:
        ults = load_ult_catalogue()
        skins_doc = json.loads(SKINS_JSON.read_text(encoding="utf-8"))
        skins_by_id = {
            s.get("skin_id", s.get("id")): s
            for s in (skins_doc.get("skins", skins_doc) if isinstance(skins_doc, dict) else skins_doc)
            if isinstance(s, dict)
        }

        non_ult_id_re = re.compile(r"^([a-z]+)\.([a-z0-9_]+)\.([a-z0-9_]+)\.(\d{2})$")
        ult_id_re = re.compile(r"^([a-z0-9_]+)_ult_cast_(\d+)$")

        errors: list[str] = []
        for hid in HEROINES:
            data = load_heroine(hid)
            exp_legacy, exp_skin = EXPECTED_SSR_SKIN_MAP[hid]
            if data.get("ssr_skin_id") != exp_skin:
                errors.append(f"{hid}: ssr_skin_id={data.get('ssr_skin_id')!r} != {exp_skin!r}")
            exp_ref = f"{exp_legacy} / {exp_skin}"
            if data.get("ssr_outfit_ref") != exp_ref:
                errors.append(f"{hid}: ssr_outfit_ref={data.get('ssr_outfit_ref')!r} != {exp_ref!r}")
            if exp_skin not in ults:
                errors.append(f"{hid}: {exp_skin} missing from ult_catalogue.json")
                continue
            if exp_skin not in skins_by_id:
                errors.append(f"{hid}: {exp_skin} missing from data/skins.json")

            ult_entry = ults[exp_skin]
            if ult_entry.get("legacy_outfit") != exp_legacy:
                errors.append(f"{hid}: catalogue legacy_outfit mismatch for {exp_skin}")

            for item in data["lines"]:
                if item.get("tier") != "ssr_outfit":
                    continue
                lid = item["id"]
                slot = item.get("slot")
                if item.get("skin_id") != exp_skin:
                    errors.append(f"{hid}({lid}): skin_id={item.get('skin_id')!r} != {exp_skin!r}")
                if slot in ("ult_cast_a", "ult_cast_b"):
                    m = ult_id_re.match(lid)
                    if not m or m.group(1) != exp_skin:
                        errors.append(
                            f"{hid}({lid}): ult slot '{slot}' must use '<skin_id>_ult_cast_N' ({exp_skin}_ult_cast_N)"
                        )
                    else:
                        if lid not in ult_entry.get("voice_cues", []):
                            errors.append(f"{hid}({lid}): not in ult_catalogue voice_cues {ult_entry.get('voice_cues')}")
                        canon_voices = ult_entry.get("voice", [])
                        cue_idx = int(m.group(2)) - 1
                        if canon_voices and 0 <= cue_idx < len(canon_voices):
                            if item["text"] != canon_voices[cue_idx]:
                                errors.append(
                                    f"{hid}({lid}): text={item['text']!r} != canon ult voice {canon_voices[cue_idx]!r}"
                                )
                else:
                    m = non_ult_id_re.match(lid)
                    if not m or m.group(1) != hid or m.group(2) != exp_skin:
                        errors.append(
                            f"{hid}({lid}): SSR line id must match '<hero>.<skin_id>.<type>.<nn>' "
                            f"(expected prefix '{hid}.{exp_skin}.')"
                        )

        # Ensure mismatched outfit motifs from FIX_ROUND1 are gone
        off_theme_checks = {
            "hana": ["каблук", "вечернем платье", "гала", "в платье выйду"],
            "rin": ["чистая операция", "тысяча листьев"],
            "yue": ["последний вальс", "вальс", "три четверти такта", "выпад полумесяца", "созвездие затмения"],
            "nova": ["форсаж", "офлайн", "root-доступ"],
            "zlata": ["белым кокошником", "перо на счастье", "купальск"],
            "mc": ["четыре ветра"],
            "miel": ["сахарный бал", "многоярусный торт", "длинные перчатки", "кружусь в платье"],
            "kohaku": ["солнечный дождь"],
        }
        for hid, bad_phrases in off_theme_checks.items():
            data = load_heroine(hid)
            for item in data["lines"]:
                if item.get("tier") != "ssr_outfit":
                    continue
                low = item["text"].lower()
                for bp in bad_phrases:
                    if bp in low:
                        errors.append(f"{hid}({item['id']}): off-theme phrase {bp!r} in {item['text']!r}")

        self.assertEqual(errors, [], "MAJOR 2 SSR schema/theme violations:\n  " + "\n  ".join(errors))

    # --- MAJOR 3 ---
    def test_major3_spring_ball_does_not_present_paid_bundle_as_prize(self) -> None:
        ev_doc = json.loads(LIVEOPS_JSON.read_text(encoding="utf-8"))
        ev = next(e for e in ev_doc["events"] if e["id"] == "ev_s2_spring_ball")
        desc = ev["description"]
        low = desc.lower()
        self.assertNotRegex(
            low,
            r"заберите\s+[^.]*набор",
            f"ev_s2_spring_ball presents paid bundle as a prize: {desc!r}",
        )
        if "витрин" in low or "набор" in low:
            self.assertIn(
                "платн",
                low,
                f"ev_s2_spring_ball mentions bundle without stating it is paid: {desc!r}",
            )

    # --- MINOR 1 ---
    def test_minor1_shirin_outfit_named_ogni_oazisa(self) -> None:
        ev_text = LIVEOPS_JSON.read_text(encoding="utf-8")
        shirin_text = (TEXT_BANK_DIR / "shirin.json").read_text(encoding="utf-8")
        self.assertNotRegex(ev_text, r"Свет[ауе]?\s+оазиса", "liveops_events.json still uses 'Свет оазиса'")
        self.assertNotRegex(shirin_text, r"Свет[ауе]?\s+оазиса", "shirin.json still uses 'Свет оазиса'")
        self.assertIn("Огни оазиса", ev_text)
        self.assertIn("Огней оазиса", ev_text)

    # --- MINOR 2 ---
    def test_minor2_s1_events_distinct_titles_and_no_vitrina_sezona(self) -> None:
        ev_doc = json.loads(LIVEOPS_JSON.read_text(encoding="utf-8"))
        by_id = {e["id"]: e for e in ev_doc["events"]}
        ev1 = by_id["ev_s1_dragonnight"]
        ev2 = by_id["ev_s1_night_teahouse"]

        t1 = ev1["title"].lower()
        t2 = ev2["title"].lower()
        self.assertFalse(
            ("чайный" in t1 and "ночь" in t1 and "чайным" in t2 and "ночь" in t2),
            f"ev_s1_dragonnight ({ev1['title']!r}) and ev_s1_night_teahouse ({ev2['title']!r}) titles are too similar",
        )
        self.assertNotIn(
            "витрину сезона",
            ev1["description"].lower(),
            "ev_s1_dragonnight must drop 'витрину сезона'",
        )

    # --- MINOR 3 ---
    def test_minor3_yue_natural_russian(self) -> None:
        yue_text = (TEXT_BANK_DIR / "yue.json").read_text(encoding="utf-8").lower()
        for bad in ("с тобой одним", "три четверти такта", "последний вальс"):
            self.assertNotIn(bad, yue_text, f"yue.json still contains awkward phrase {bad!r}")

    # --- MINOR 4 ---
    def test_minor4_rin_mc_zlata_natural_russian(self) -> None:
        checks = [
            ("rin", ["удивительно важно", "нужной температуры", "взгляд поверх очков — только твой"]),
            ("mc", ["самой яркой партии сегодня", "очко в плюс"]),
            ("zlata", ["под белым кокошником рассвета"]),
        ]
        for hid, bad_list in checks:
            raw = (TEXT_BANK_DIR / f"{hid}.json").read_text(encoding="utf-8").lower()
            for bad in bad_list:
                self.assertNotIn(bad, raw, f"{hid}.json still contains awkward phrase {bad!r}")

    # --- MINOR 5 ---
    def test_minor5_tsubame_cold_pro_and_no_body_garment_touch(self) -> None:
        data = load_heroine("tsubame")
        by_slot = {(i["tier"], i["slot"]): i for i in data["lines"]}

        bold = by_slot[("beta24", "touch_bold")]["text"].lower()
        self.assertNotIn("благодаришь", bold, f"tsubame touch_bold still talks about thanks: {bold!r}")
        self.assertRegex(bold, r"\b(ты|тебе|тебя|тобой|твой|твоя|твоё|твои)\b")

        ssr_touch = by_slot[("ssr_outfit", "touch_2")]["text"].lower()
        for bad in ("корсаж", "подол", "бретел", "бельё", "белье", "тело"):
            self.assertNotIn(bad, ssr_touch, f"tsubame ssr touch_2 references garment/body {bad!r}: {ssr_touch!r}")

    # --- MINOR 6 ---
    def test_minor6_kohaku_and_shirin_softened(self) -> None:
        kohaku = load_heroine("kohaku")
        k_by_slot = {(i["tier"], i["slot"]): i for i in kohaku["lines"]}
        self.assertNotIn("до рассвета", k_by_slot[("ssr_outfit", "touch_2")]["text"].lower())
        self.assertNotIn("погладь меня в награду", k_by_slot[("ssr_outfit", "win")]["text"].lower())

        shirin = load_heroine("shirin")
        s_by_slot = {(i["tier"], i["slot"]): i for i in shirin["lines"]}
        self.assertNotIn("чего ты хочешь", s_by_slot[("beta24", "touch_bold")]["text"].lower())

    # --- MINOR 7 ---
    def test_minor7_no_latin_no_tilde_and_mc_tsumo_clean(self) -> None:
        bad_latin = []
        bad_tilde = []
        for hid in HEROINES:
            data = load_heroine(hid)
            for item in data["lines"]:
                txt = item["text"]
                if LATIN_RE.search(txt):
                    bad_latin.append(f"{hid}({item['id']}): {txt!r}")
                if TILDE_RE.search(txt):
                    bad_tilde.append(f"{hid}({item['id']}): {txt!r}")
                if item["id"] == "mc_tsumo_1":
                    self.assertNotIn(
                        "партия окончена",
                        txt.lower(),
                        f"mc_tsumo_1 must not say game is over: {txt!r}",
                    )

        # Also verify BETA24_TEXTS.md RU column has no Latin or tilde
        for lid, ru in parse_beta24_md().items():
            if LATIN_RE.search(ru):
                bad_latin.append(f"BETA24({lid}): {ru!r}")
            if TILDE_RE.search(ru):
                bad_tilde.append(f"BETA24({lid}): {ru!r}")

        self.assertEqual(bad_latin, [], f"Latin characters found in RU voice lines: {bad_latin}")
        self.assertEqual(bad_tilde, [], f"Tilde characters found in RU voice lines: {bad_tilde}")

    # --- MINOR 8 ---
    def test_minor8_pool_specific_max_words(self) -> None:
        errors = []
        distinct_max_words = set()
        for hid in HEROINES:
            data = load_heroine(hid)
            for item in data["lines"]:
                lid = item["id"]
                slot = item["slot"]
                max_w = item["max_words"]
                distinct_max_words.add(max_w)
                wc_joined = vtb.count_words(item["text"])
                wc_split = len(SPLIT_WORD_RE.findall(item["text"]))

                if slot in CALL_SLOTS_MAX3:
                    if max_w > 3:
                        errors.append(f"{lid}: call slot '{slot}' must have max_words<=3, got {max_w}")
                elif slot in CALL_SLOTS_MAX4:
                    if max_w > 4:
                        errors.append(f"{lid}: call slot '{slot}' must have max_words<=4, got {max_w}")
                else:
                    if not (1 <= max_w <= 12):
                        errors.append(f"{lid}: lobby slot '{slot}' max_words out of 1..12: {max_w}")

                if wc_joined > max_w or wc_split > max_w:
                    errors.append(
                        f"{lid}: word count joined={wc_joined}/split={wc_split} > max_words={max_w}: {item['text']!r}"
                    )

        self.assertGreater(len(distinct_max_words), 1, "max_words must be pool-specific, not uniform 12")
        self.assertEqual(errors, [], "Pool-specific max_words errors:\n  " + "\n  ".join(errors))

    # --- MINOR 9 ---
    def test_minor9_expanded_forbidden_and_fomo_patterns(self) -> None:
        must_catch_forbidden = [
            "ученическая форма",
            "студентка первого курса",
            "весёлая девчонка",
            "старый лицей",
            "внешкольный кружок",
        ]
        for sample in must_catch_forbidden:
            hits = vtb.check_forbidden(sample, vtb.FORBIDDEN_PATTERNS)
            self.assertTrue(hits, f"FORBIDDEN_PATTERNS failed to catch {sample!r}")

        must_catch_fomo = [
            "Не упусти этот набор!",
            "Только сегодня в Лавке!",
            "Осталось три дня до закрытия!",
            "Эксклюзивный наряд сезона",
            "Лимитированный комплект",
        ]
        for sample in must_catch_fomo:
            hits = vtb.check_forbidden(sample, vtb.FOMO_PATTERNS)
            self.assertTrue(hits, f"FOMO_PATTERNS failed to catch {sample!r}")

        # Must NOT false-positive on normal game words
        must_allow = [
            "Сыграем партию в маджонг!",
            "Чай в «Пяти ветрах» уже готов.",
            "Напарник, ты лучший!",
        ]
        for sample in must_allow:
            self.assertEqual(vtb.check_forbidden(sample, vtb.FORBIDDEN_PATTERNS), [], f"False positive on {sample!r}")
            self.assertEqual(vtb.check_forbidden(sample, vtb.FOMO_PATTERNS), [], f"FOMO false positive on {sample!r}")

    def test_validator_passes(self) -> None:
        self.assertEqual(vtb.validate(), 0, "validate_text_bank.validate() must return 0")


if __name__ == "__main__":
    unittest.main()
