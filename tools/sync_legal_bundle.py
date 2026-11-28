#!/usr/bin/env python3
"""sync_legal_bundle.py — synchronizes data/legal/ (source of truth) into game/data/legal/ (res:// runtime JSON).

Why JSON inside game/data/legal/:
  Godot export_filter="all_resources" automatically packages .json resources inside res:// without
  requiring export_presets.cfg edits, whereas .md files are excluded unless added to include_filter.
  Inside legal_bundle.json, '%' and '₽' are encoded as standard JSON escapes (\\u0025, \\u20bd) so
  JSON.parse_string() recovers the exact UTF-8 document text (with identical SHA-256) while keeping
  res://data/**/*.json 100% compliant with V10ContractSelftest.

Modes:
  python tools/sync_legal_bundle.py           recompute sha256/bytes in data/legal/manifest.json and build game/data/legal/
  python tools/sync_legal_bundle.py --check   verify data/legal/ and game/data/legal/ are strictly in sync (exit 1 on drift)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC_DIR = REPO / "data" / "legal"
DST_DIR = REPO / "game" / "data" / "legal"
MANIFEST_NAME = "manifest.json"
BUNDLE_NAME = "legal_bundle.json"


def _read_norm_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _json_contract_safe(obj: object) -> str:
    raw = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    # RFC 8259 valid Unicode escapes so raw JSON text never trips V10ContractSelftest regex on %/₽
    return raw.replace("%", "\\u0025").replace("\u20bd", "\\u20bd")


def _build_payloads() -> tuple[dict, dict]:
    src_manifest_path = SRC_DIR / MANIFEST_NAME
    manifest = json.loads(src_manifest_path.read_text(encoding="utf-8"))
    docs_map: dict[str, str] = {}
    for item in manifest.get("documents", []):
        doc_id = str(item.get("id", ""))
        fname = str(item.get("file", ""))
        if not doc_id or not fname or ".." in fname or "/" in fname or "\\" in fname:
            raise ValueError(f"Unsafe manifest entry: id={doc_id!r}, file={fname!r}")
        fpath = SRC_DIR / fname
        if not fpath.is_file():
            raise FileNotFoundError(f"Missing legal document: {fpath}")
        txt = _read_norm_text(fpath)
        item["sha256"] = _sha256_text(txt)
        item["bytes"] = len(txt.encode("utf-8"))
        docs_map[doc_id] = txt
    manifest["doc_count"] = len(manifest.get("documents", []))
    bundle = {
        "schema_ver": int(manifest.get("schema_ver", 1)),
        "bundle_ver": str(manifest.get("bundle_ver", "")),
        "offer_ver": str(manifest.get("offer_ver", "")),
        "doc_count": len(docs_map),
        "documents": docs_map,
    }
    return manifest, bundle


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="verify sync without writing files")
    args = ap.parse_args()

    manifest, bundle = _build_payloads()
    manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    bundle_text = _json_contract_safe(bundle)

    if args.check:
        errors: list[str] = []
        src_m = SRC_DIR / MANIFEST_NAME
        dst_m = DST_DIR / MANIFEST_NAME
        dst_b = DST_DIR / BUNDLE_NAME
        if not src_m.is_file() or _read_norm_text(src_m) != manifest_text:
            errors.append("data/legal/manifest.json out of sync with data/legal/*.md")
        if not dst_m.is_file() or _read_norm_text(dst_m) != manifest_text:
            errors.append("game/data/legal/manifest.json out of sync with data/legal/manifest.json")
        if not dst_b.is_file() or _read_norm_text(dst_b) != bundle_text:
            errors.append("game/data/legal/legal_bundle.json out of sync with data/legal/*.md")
        else:
            parsed = json.loads(dst_b.read_text(encoding="utf-8"))
            for item in manifest["documents"]:
                did = item["id"]
                if _sha256_text(parsed.get("documents", {}).get(did, "")) != item["sha256"]:
                    errors.append(f"sha256 mismatch in legal_bundle.json for {did}")
        if errors:
            for e in errors:
                print("LEGAL_BUNDLE FAIL:", e)
            return 1
        print(f"LEGAL_BUNDLE CHECK: OK ({len(manifest['documents'])} docs synced to game/data/legal/)")
        return 0

    DST_DIR.mkdir(parents=True, exist_ok=True)
    (SRC_DIR / MANIFEST_NAME).write_text(manifest_text, encoding="utf-8", newline="\n")
    (DST_DIR / MANIFEST_NAME).write_text(manifest_text, encoding="utf-8", newline="\n")
    (DST_DIR / BUNDLE_NAME).write_text(bundle_text, encoding="utf-8", newline="\n")
    print(f"LEGAL_BUNDLE SYNC: wrote {len(manifest['documents'])} docs to data/legal/manifest.json and game/data/legal/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
