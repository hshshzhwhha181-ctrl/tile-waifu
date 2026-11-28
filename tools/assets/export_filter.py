#!/usr/bin/env python3
"""Tile Waifu export packaging filter & P92 (T3/T12) audit gate for export_presets.cfg and APK/PCK.

Stage 5 + P92 (review T3 / T12):
  * Computes a SAFE `exclude_filter` for `game/export_presets.cfg`:
    - test / demo / selftest / runner / shots / dev-tool files outside game/assets, only when nothing shipped statically needs them;
    - ALWAYS includes `skins_dl/**` (T3: downloadable skin packs use versioned paths `res://skins_dl/<skin_id>/<major.minor>/...`;
      never bundled in APK, otherwise APK silently shadows downloaded packs);
    - NEVER excludes `skins_base/**` (base skins bundled in APK) or `shell/skin/pack_pub.pub` (signing public key).
  * Computes `include_filter` for all 3 Android presets (`Android`, `Android-test`, `Android-store`):
    - preserves existing font license entries (`assets/v10/fonts/*/OFL.txt`, `assets/v10/fonts/licenses/*.txt`);
    - ALWAYS includes `shell/skin/pack_pub.pub` (T12: PEM RSA-2048 public key for `CryptoKey.load(path, true)`).
  * Audits `export_presets.cfg` (`--check`, `--check-presets`), public key file (`--check-pub-key`), and built `.apk`/`.pck`
    archives (`--check-apk PATH`): red exit (1) if `skins_dl/` appears anywhere in APK/PCK or if `pack_pub.pub` is missing/invalid.
  * Built-in synthetic selftest (`--selftest`): covers `skins_dl/` leak -> red, `missing pub key` -> red, `.crt`/private key -> red,
    preset omissions -> red, clean APK+PCK -> green.

Usage:
  python tools/assets/export_filter.py                    # dry-run report (exclude + include + T3/T12 audit)
  python tools/assets/export_filter.py --apply            # write exclude_filter + include_filter into all presets
  python tools/assets/export_filter.py --check            # CI guard: presets match computed filters + T3/T12 rules
  python tools/assets/export_filter.py --check-presets    # CI guard: verify T3 (skins_dl/**) & T12 (.pub) in all 3 presets
  python tools/assets/export_filter.py --check-pub-key    # CI guard: verify game/shell/skin/pack_pub.pub exists & is PEM PUBLIC KEY
  python tools/assets/export_filter.py --check-apk FILE   # CI guard: verify APK/PCK has NO skins_dl/ and HAS valid pack_pub.pub
  python tools/assets/export_filter.py --selftest         # synthetic self-test (prints EXPORT_FILTER SELFTEST ok/total PASS|FAIL)
"""
from __future__ import annotations

import argparse
import base64
import binascii
import fnmatch
import io
import os
import re
import struct
import sys
import tempfile
import zipfile
from collections import defaultdict
from pathlib import Path

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")

CAND_RE = re.compile(
    r"(selftest|_demo\b|\bdemo_|/demo/|_runner\b|\brunner_|/tools/|/shots/|_shot_runner|_cli\b|bench\.(gd|tscn)|fuzz\.gd|story_test|"
    r"/devtools/|rig_demo|demo_host|(^|/)tests?/|_tests?\.(gd|tscn)$|/pipeline/|\.(py|md|sh)$)")
SKIP_ASSETS = "assets/"
TEXT_EXT = (".gd", ".tscn", ".tres", ".cfg", ".godot", ".gdshader")
# Never excluded even when they match: the gate in HANDOFF (--export-pack + `--main-pack x.pck --pt=fresh` => PT OK)
# needs the playtest, and it is class_name-referenced from main/g anyway; kept explicit for readability.
NEVER = ("scripts/v08/devtools/playtest.gd",)

# P92 (T3 / T12) packaging invariants
SKINS_DL_GLOB = "skins_dl/**"
SKINS_DL_PREFIX = "skins_dl/"
SKINS_BASE_PREFIX = "skins_base/"
PACK_PUB_REL = "shell/skin/pack_pub.pub"
REQUIRED_PRESETS = ("Android", "Android-test", "Android-store")
REQUIRED_EXCLUDES = (SKINS_DL_GLOB,)
REQUIRED_INCLUDES = (PACK_PUB_REL,)

PEM_PUB_BEGIN = "-----BEGIN PUBLIC KEY-----"
PEM_PUB_END = "-----END PUBLIC KEY-----"
PEM_FORBIDDEN_MARKERS = (
    "PRIVATE KEY",
    "BEGIN CERTIFICATE",
    "BEGIN RSA PRIVATE KEY",
    "BEGIN EC PRIVATE KEY",
)
RSA_ENCRYPTION_OID = b"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01"  # 1.2.840.113549.1.1.1
MIN_RSA_KEY_BITS = 2048
SKINS_DL_PROBES = (
    "skins_dl/sample_skin/1.0/manifest.json",
    "skins_dl/sample_skin/1.0/albedo.png",
    "skins_dl/sample_skin/1.0/albedo.png.ctex",
    "skins_dl/sample_skin/1.0/rig.webp",
    "skins_dl/sample_skin/1.0/theme.tres",
    "skins_dl/sample_skin/1.0/audio.ogg",
    "skins_dl/sample_skin/1.0/data.bin",
)
SKINS_BASE_PROBES = (
    "skins_base/hana_base/manifest.json",
    "skins_base/hana_base/albedo.png",
)


def _read_text(game_dir: str, rel_path: str) -> str:
    return open(os.path.join(game_dir, rel_path), encoding="utf-8", errors="replace").read()


def strip_comments(t: str) -> str:
    return re.sub(r"(?m)^\s*#.*$", "", t)


def all_files(game_dir: str = GAME) -> list[str]:
    out = []
    for dp, dn, fn in os.walk(game_dir):
        dn[:] = [d for d in dn if d not in (".godot", ".git")]
        if os.path.exists(os.path.join(dp, ".gdignore")):
            dn[:] = []
            continue
        for f in fn:
            out.append(os.path.relpath(os.path.join(dp, f), game_dir).replace(os.sep, "/"))
    return sorted(out)


def _split_filter_csv(val: str) -> list[str]:
    return [part.strip() for part in val.split(",") if part.strip()]


def _pattern_matches(path: str, patterns: list[str]) -> bool:
    p = path.lstrip("/")
    if p.startswith("res://"):
        p = p[6:]
    for pat in patterns:
        g = pat.strip().lstrip("/")
        if g.startswith("res://"):
            g = g[6:]
        if not g:
            continue
        if g.endswith("/**"):
            prefix = g[:-3].rstrip("/")
            if p == prefix or p.startswith(prefix + "/"):
                return True
        if fnmatch.fnmatch(p, g):
            return True
    return False


def compute_exclude_filter(game_dir: str = GAME) -> dict:
    files = all_files(game_dir)
    code = [f for f in files if f.endswith(TEXT_EXT) and not f.startswith("export_presets")]
    # Under assets/ only code/doc files are candidates; skins_base/ media is never a candidate;
    # everything under skins_dl/ is unconditionally excluded (T3).
    cands = {
        f for f in files
        if CAND_RE.search(f) and f not in NEVER and f != PACK_PUB_REL
        and not f.endswith((".import", ".jpg", ".png"))
        and not f.startswith(SKINS_BASE_PREFIX)
        and (not f.startswith(SKIP_ASSETS) or f.endswith((".gd", ".tscn", ".py", ".md", ".sh")))
    }
    skins_dl_files = {f for f in files if f.startswith(SKINS_DL_PREFIX)}

    class_of: dict[str, str] = {}
    texts: dict[str, str] = {}
    for f in code:
        t = _read_text(game_dir, f)
        texts[f] = t
        if f.endswith(".gd"):
            m = re.search(r"(?m)^class_name\s+(\w+)", t)
            if m:
                class_of[f] = m.group(1)

    def hard_refs(f: str) -> set[str]:
        t = texts[f]
        refs: set[str] = set()
        for m in re.finditer(r'(?:preload\(|extends\s+)"res://([^"]+)"', t):
            refs.add(m.group(1))
        if f.endswith((".tscn", ".tres")):
            for m in re.finditer(r'path="res://([^"]+)"', t):
                refs.add(m.group(1))
        if f == "project.godot":
            for m in re.finditer(r'"\*?res://([^"]+)"', t):
                refs.add(m.group(1))
        return refs

    hard = {f: hard_refs(f) for f in code}
    shipped = set(code) - cands - skins_dl_files
    cls_re = {c: re.compile(r"\b%s\b" % c) for c in class_of.values()}
    stripped = {f: strip_comments(texts[f]) for f in code if f.endswith(".gd")}

    # T3 hard guard: shipped code must NEVER hard-reference res://skins_dl/...
    skins_dl_hard_refs: list[str] = []
    for s in sorted(shipped):
        for ref in sorted(hard.get(s, ())):
            if ref.startswith(SKINS_DL_PREFIX):
                skins_dl_hard_refs.append(f"{s} -> res://{ref}")

    pinned: dict[str, str] = {}
    changed = True
    while changed:
        changed = False
        for c in sorted(cands - set(pinned)):
            reason = None
            cn = class_of.get(c)
            base = os.path.splitext(c)[0]
            for s in sorted(shipped):
                if c in hard.get(s, ()):
                    reason = "%s (preload/ext_resource/extends)" % s
                    break
                if cn and s.endswith(".gd") and s != c and cls_re[cn].search(stripped[s]):
                    reason = "%s (class_name %s)" % (s, cn)
                    break
                if s != c and os.path.splitext(s)[0] == base and s in pinned:
                    reason = "pair of " + s
                    break
            if reason:
                pinned[c] = reason
                shipped.add(c)
                changed = True

    excl = sorted(cands - set(pinned))
    soft: dict[str, list[str]] = defaultdict(list)
    ex_set = set(excl)
    for s in sorted(shipped):
        if s not in texts:
            continue
        for m in re.finditer(r'res://([A-Za-z0-9_./\-]+)', texts[s]):
            p = m.group(1)
            if p in ex_set:
                soft[s].append(p)

    # Build-time asset manifest (~0.6 MB) + T3 mandatory skins_dl/** glob (+ any concrete skins_dl files)
    excl_all = set(excl) | {f for f in files if f == "assets/manifest/assets.json"} | skins_dl_files
    uid = [e + ".uid" for e in sorted(excl_all) if os.path.exists(os.path.join(game_dir, e + ".uid"))]
    final = sorted((excl_all | set(uid) | set(REQUIRED_EXCLUDES)) - {PACK_PUB_REL})
    return {
        "cands": cands,
        "pinned": pinned,
        "excl": sorted(excl_all),
        "uid": uid,
        "soft": soft,
        "final": final,
        "skins_dl_files": sorted(skins_dl_files),
        "skins_dl_hard_refs": skins_dl_hard_refs,
    }


def compute_include_filter(existing_include: str) -> str:
    items = _split_filter_csv(existing_include)
    for req in REQUIRED_INCLUDES:
        if req not in items:
            items.append(req)
    return ", ".join(items)


def parse_presets(cfg_text: str) -> list[dict]:
    presets: list[dict] = []
    cur: dict | None = None
    for raw in cfg_text.splitlines():
        line = raw.strip()
        m_sec = re.match(r"^\[preset\.(\d+)\]$", line)
        if m_sec:
            cur = {"index": int(m_sec.group(1)), "name": "", "include_filter": "", "exclude_filter": "", "export_filter": ""}
            presets.append(cur)
            continue
        if line.startswith("["):
            cur = None
            continue
        if cur is None or "=" not in line:
            continue
        k, v = line.split("=", 1)
        k = k.strip()
        v = v.strip()
        if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
            v = v[1:-1]
        if k in ("name", "include_filter", "exclude_filter", "export_filter"):
            cur[k] = v
    return presets


def apply_filters_to_cfg(cfg_text: str, computed_excl: list[str]) -> str:
    excl_val = ", ".join(computed_excl)
    out = re.sub(r'(?m)^exclude_filter=.*$', lambda _m: f'exclude_filter="{excl_val}"', cfg_text)

    def _upd_inc(m: re.Match) -> str:
        cur = m.group(1)
        return f'include_filter="{compute_include_filter(cur)}"'

    out = re.sub(r'(?m)^include_filter="([^"]*)"$', _upd_inc, out)
    return out


def _has_skins_dl_dir_exclusion(excl_items: list[str]) -> bool:
    """Require a directory-scoped skins_dl/** (or skins_dl/*) glob that excludes ALL file types under skins_dl/."""
    has_dir_glob = False
    for pat in excl_items:
        g = pat.strip().lstrip("/")
        if g.startswith("res://"):
            g = g[6:]
        if g in (SKINS_DL_GLOB, "skins_dl/*"):
            has_dir_glob = True
            break
    if not has_dir_glob:
        return False
    return all(_pattern_matches(probe, excl_items) for probe in SKINS_DL_PROBES)


def audit_presets_cfg(
    cfg_text: str,
    computed_excl: list[str] | None = None,
    require_exact_excl: bool = False,
) -> list[str]:
    """Audit export_presets.cfg for T3 (exclude skins_dl/**) and T12 (include pack_pub.pub)."""
    errors: list[str] = []
    presets = parse_presets(cfg_text)
    by_name = {p["name"]: p for p in presets}

    for req_name in REQUIRED_PRESETS:
        if req_name not in by_name:
            errors.append(f"PRESET_MISSING: required preset '{req_name}' not found in export_presets.cfg")

    for p in presets:
        pname = p["name"] or f"preset.{p['index']}"
        excl_items = _split_filter_csv(p["exclude_filter"])
        inc_items = _split_filter_csv(p["include_filter"])

        # T3: skins_dl/** must be excluded in every preset across all asset types (not satisfied by '*.json')
        if not _has_skins_dl_dir_exclusion(excl_items):
            errors.append(f"T3_SKINS_DL_NOT_EXCLUDED: preset '{pname}' exclude_filter does not exclude '{SKINS_DL_GLOB}'")

        # T3: skins_base/ must NOT be excluded
        if any(_pattern_matches(probe, excl_items) for probe in SKINS_BASE_PROBES):
            errors.append(f"T3_SKINS_BASE_EXCLUDED: preset '{pname}' exclude_filter wrongly excludes skins_base/")

        # T12: pack_pub.pub must be matched by include_filter in every preset
        if not _pattern_matches(PACK_PUB_REL, inc_items):
            errors.append(f"T12_PUB_KEY_NOT_INCLUDED: preset '{pname}' include_filter does not include '{PACK_PUB_REL}' (or '*.pub')")

        # T12: pack_pub.pub must NOT be excluded
        if _pattern_matches(PACK_PUB_REL, excl_items):
            errors.append(f"T12_PUB_KEY_EXCLUDED: preset '{pname}' exclude_filter wrongly excludes '{PACK_PUB_REL}'")

        if require_exact_excl and computed_excl is not None:
            want = ", ".join(computed_excl)
            if p["exclude_filter"] != want:
                errors.append(f"EXCLUDE_DRIFT: preset '{pname}' exclude_filter differs from computed filter ({len(excl_items)} vs {len(computed_excl)} entries)")

    return errors


def _read_der_tlv(buf: bytes, offset: int) -> tuple[int, bytes, int]:
    """Parse one ASN.1 DER Tag-Length-Value at offset; returns (tag, value_bytes, next_offset)."""
    if offset >= len(buf):
        raise ValueError("unexpected end of DER buffer")
    tag = buf[offset]
    offset += 1
    if offset >= len(buf):
        raise ValueError("truncated DER length")
    first_len = buf[offset]
    offset += 1
    if first_len < 0x80:
        length = first_len
    else:
        num_octets = first_len & 0x7F
        if num_octets == 0 or num_octets > 4 or offset + num_octets > len(buf):
            raise ValueError("invalid DER indefinite/long length")
        len_bytes = buf[offset:offset + num_octets]
        if len_bytes[0] == 0:
            raise ValueError("non-minimal DER length encoding")
        length = int.from_bytes(len_bytes, "big")
        if length < 0x80:
            raise ValueError("non-minimal DER length encoding")
        offset += num_octets
    end = offset + length
    if end > len(buf):
        raise ValueError("DER value exceeds buffer")
    return tag, buf[offset:end], end


def _parse_der_positive_int(val: bytes) -> int:
    if not val:
        raise ValueError("empty ASN.1 INTEGER")
    if val[0] & 0x80:
        raise ValueError("negative ASN.1 INTEGER")
    if len(val) > 1 and val[0] == 0x00 and (val[1] & 0x80) == 0:
        raise ValueError("non-minimal ASN.1 INTEGER padding")
    return int.from_bytes(val, "big")


def _validate_rsa_spki_der(der: bytes, source: str) -> list[str]:
    """Validate ASN.1 DER SubjectPublicKeyInfo for an RSA >= 2048-bit public key (Godot CryptoKey.load compatible)."""
    try:
        tag, spki_body, end = _read_der_tlv(der, 0)
        if tag != 0x30 or end != len(der):
            return [f"T12_INVALID_ASN1_PUB_KEY: {source} outer element is not a single DER SEQUENCE"]

        alg_tag, alg_body, pos = _read_der_tlv(spki_body, 0)
        if alg_tag != 0x30:
            return [f"T12_INVALID_ASN1_PUB_KEY: {source} missing AlgorithmIdentifier SEQUENCE"]
        oid_tag, oid_val, alg_pos = _read_der_tlv(alg_body, 0)
        if oid_tag != 0x06 or oid_val != RSA_ENCRYPTION_OID:
            return [f"T12_UNSUPPORTED_KEY_ALG: {source} expected rsaEncryption OID (1.2.840.113549.1.1.1)"]
        if alg_pos < len(alg_body):
            null_tag, null_val, alg_pos2 = _read_der_tlv(alg_body, alg_pos)
            if null_tag != 0x05 or null_val != b"" or alg_pos2 != len(alg_body):
                return [f"T12_INVALID_ASN1_PUB_KEY: {source} invalid AlgorithmIdentifier parameters"]

        bs_tag, bs_val, pos2 = _read_der_tlv(spki_body, pos)
        if bs_tag != 0x03 or pos2 != len(spki_body) or len(bs_val) < 2 or bs_val[0] != 0x00:
            return [f"T12_INVALID_ASN1_PUB_KEY: {source} invalid subjectPublicKey BIT STRING"]

        rsa_der = bs_val[1:]
        rtag, rbody, rend = _read_der_tlv(rsa_der, 0)
        if rtag != 0x30 or rend != len(rsa_der):
            return [f"T12_INVALID_ASN1_PUB_KEY: {source} subjectPublicKey is not an RSAPublicKey SEQUENCE"]

        ntag, nval, rpos = _read_der_tlv(rbody, 0)
        etag, eval_, rpos2 = _read_der_tlv(rbody, rpos)
        if ntag != 0x02 or etag != 0x02 or rpos2 != len(rbody):
            return [f"T12_INVALID_ASN1_PUB_KEY: {source} RSAPublicKey must contain exactly (modulus, publicExponent)"]

        modulus = _parse_der_positive_int(nval)
        exponent = _parse_der_positive_int(eval_)
    except ValueError as exc:
        return [f"T12_INVALID_ASN1_PUB_KEY: {source} malformed ASN.1 DER ({exc})"]

    if modulus.bit_length() < MIN_RSA_KEY_BITS:
        return [f"T12_WEAK_RSA_PUB_KEY: {source} RSA modulus is {modulus.bit_length()} bits (minimum {MIN_RSA_KEY_BITS})"]
    if (modulus & 1) == 0:
        return [f"T12_INVALID_ASN1_PUB_KEY: {source} RSA modulus must be odd"]
    if exponent < 3 or (exponent & 1) == 0:
        return [f"T12_INVALID_ASN1_PUB_KEY: {source} invalid RSA public exponent {exponent}"]
    return []


def validate_pub_key_bytes(data: bytes, source: str = PACK_PUB_REL) -> list[str]:
    if not data or not data.strip():
        return [f"T12_EMPTY_PUB_KEY: {source} is empty"]
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return [f"T12_NON_PEM_PUB_KEY: {source} is not UTF-8 PEM text"]
    for bad in PEM_FORBIDDEN_MARKERS:
        if bad in text:
            return [f"T12_FORBIDDEN_KEY_TYPE: {source} contains '{bad}' (expected PEM PUBLIC KEY, not .crt or private key)"]
    if text.count(PEM_PUB_BEGIN) != 1 or text.count(PEM_PUB_END) != 1:
        return [f"T12_INVALID_PEM_PUB_KEY: {source} must contain exactly one '{PEM_PUB_BEGIN}' / '{PEM_PUB_END}' block"]
    begin_idx = text.index(PEM_PUB_BEGIN)
    end_idx = text.index(PEM_PUB_END)
    if end_idx <= begin_idx:
        return [f"T12_INVALID_PEM_PUB_KEY: {source} PEM END marker precedes BEGIN marker"]
    body = text[begin_idx + len(PEM_PUB_BEGIN):end_idx]
    b64_compact = "".join(body.split())
    if not b64_compact:
        return [f"T12_EMPTY_PUB_KEY: {source} PEM body is empty"]
    try:
        der = base64.b64decode(b64_compact, validate=True)
    except (binascii.Error, ValueError) as exc:
        return [f"T12_INVALID_PEM_BASE64: {source} invalid base64 in PEM body ({exc})"]
    return _validate_rsa_spki_der(der, source)


def check_pub_key_file(game_dir: str = GAME, rel_path: str = PACK_PUB_REL) -> list[str]:
    full = os.path.join(game_dir, rel_path)
    if not os.path.isfile(full):
        return [f"T12_MISSING_PUB_KEY: {rel_path} not found under {game_dir}"]
    with open(full, "rb") as f:
        return validate_pub_key_bytes(f.read(), rel_path)


# ── Godot PCK binary parser (GDPC v2/v3) & APK/ZIP inspector ────────────────────────────────────────────────

def read_pck_entries(buf: bytes) -> list[tuple[str, bytes]]:
    """Parse a Godot 4 GDPC v2/v3 .pck binary buffer into [(path, content_bytes), ...]."""
    bio = io.BytesIO(buf)
    magic = bio.read(4)
    if magic != b"GDPC":
        raise ValueError(f"Not a Godot PCK (magic={magic!r})")
    fmt_ver, _maj, _min, _pat = struct.unpack("<IIII", bio.read(16))
    if fmt_ver < 2:
        raise ValueError(f"Unsupported GDPC format version {fmt_ver}")
    flags, file_base = struct.unpack("<IQ", bio.read(12))
    if flags & 1:
        raise ValueError("Encrypted PCK directory is not supported by static inspector")
    dir_base = None
    if fmt_ver >= 3:
        (dir_base,) = struct.unpack("<Q", bio.read(8))
    bio.read(16 * 4)  # 16 reserved uint32s
    if dir_base is not None:
        bio.seek(dir_base)
    (file_count,) = struct.unpack("<I", bio.read(4))
    out: list[tuple[str, bytes]] = []
    for _ in range(file_count):
        (path_len,) = struct.unpack("<I", bio.read(4))
        raw_path = bio.read(path_len)
        path = raw_path.rstrip(b"\x00").decode("utf-8", errors="replace")
        offset, size = struct.unpack("<QQ", bio.read(16))
        _md5 = bio.read(16)
        _eflags = struct.unpack("<I", bio.read(4))[0]
        cur_pos = bio.tell()
        abs_off = file_base + offset
        content = buf[abs_off:abs_off + size]
        out.append((path, content))
        bio.seek(cur_pos)
    return out


def _normalize_archive_path(p: str) -> str:
    s = p.replace("\\", "/").lstrip("/")
    if s.startswith("res://"):
        s = s[6:]
    if s.startswith("assets/"):
        # Android APK places game files under assets/ (e.g. assets/shell/skin/pack_pub.pub or assets/skins_dl/...)
        return s
    return s


def _is_skins_dl_path(p: str) -> bool:
    norm = _normalize_archive_path(p).lower()
    return (
        norm.startswith("skins_dl/")
        or norm.startswith("assets/skins_dl/")
        or "/skins_dl/" in norm
    )


def _is_pack_pub_path(p: str) -> bool:
    norm = _normalize_archive_path(p)
    return norm == PACK_PUB_REL or norm == f"assets/{PACK_PUB_REL}"


def inspect_apk_or_pck(archive_path: str | Path, require_pub_key: bool = True) -> list[str]:
    """Inspect a built .apk/.zip or .pck archive for T3 (zero skins_dl/) and T12 (valid pack_pub.pub)."""
    path = Path(archive_path)
    if not path.is_file():
        return [f"ARCHIVE_NOT_FOUND: {path}"]

    errors: list[str] = []
    skins_dl_hits: list[str] = []
    pub_key_data: bytes | None = None
    pub_key_src: str = ""

    raw_head = path.read_bytes()[:4]
    if raw_head == b"GDPC":
        for ep, data in read_pck_entries(path.read_bytes()):
            if _is_skins_dl_path(ep):
                skins_dl_hits.append(ep)
            if _is_pack_pub_path(ep):
                pub_key_data = data
                pub_key_src = ep
    elif zipfile.is_zipfile(path):
        with zipfile.ZipFile(path, "r") as zf:
            for info in zf.infolist():
                ep = info.filename
                if _is_skins_dl_path(ep):
                    skins_dl_hits.append(ep)
                if _is_pack_pub_path(ep):
                    pub_key_data = zf.read(info)
                    pub_key_src = ep
                if ep.lower().endswith(".pck"):
                    pck_bytes = zf.read(info)
                    for pck_ep, pck_data in read_pck_entries(pck_bytes):
                        if _is_skins_dl_path(pck_ep):
                            skins_dl_hits.append(f"{ep}!{pck_ep}")
                        if _is_pack_pub_path(pck_ep):
                            pub_key_data = pck_data
                            pub_key_src = f"{ep}!{pck_ep}"
    else:
        return [f"UNSUPPORTED_ARCHIVE: {path} is neither ZIP/APK nor GDPC PCK"]

    for hit in sorted(skins_dl_hits):
        errors.append(f"T3_SKINS_DL_IN_ARCHIVE: forbidden downloadable skin asset found: {hit}")

    if require_pub_key:
        if pub_key_data is None:
            errors.append(f"T12_MISSING_PUB_KEY: '{PACK_PUB_REL}' missing from archive {path.name}")
        else:
            errors.extend(validate_pub_key_bytes(pub_key_data, pub_key_src))
    elif pub_key_data is not None:
        errors.extend(validate_pub_key_bytes(pub_key_data, pub_key_src))

    return errors


# ── Synthetic self-test (P92 acceptance: skins_dl/ -> RED, missing pub key -> RED, clean -> GREEN) ─────────

def _build_synthetic_pck(entries: dict[str, bytes]) -> bytes:
    """Build a valid Godot 4 GDPC v2 .pck binary in memory for self-testing."""
    dir_buf = io.BytesIO()
    data_chunks: list[bytes] = []
    rel_off = 0
    dir_buf.write(struct.pack("<I", len(entries)))
    for path, content in entries.items():
        pbytes = path.encode("utf-8")
        pad = (4 - (len(pbytes) % 4)) % 4
        pbytes_padded = pbytes + (b"\x00" * pad)
        dir_buf.write(struct.pack("<I", len(pbytes_padded)))
        dir_buf.write(pbytes_padded)
        dir_buf.write(struct.pack("<QQ", rel_off, len(content)))
        dir_buf.write(b"\x00" * 16)  # md5 placeholder
        dir_buf.write(struct.pack("<I", 0))  # flags
        data_chunks.append(content)
        rel_off += len(content)

    dir_bytes = dir_buf.getvalue()
    # Header: 4 (magic) + 16 (versions) + 12 (flags+file_base) + 64 (reserved) = 96 bytes
    file_base = 96 + len(dir_bytes)
    header = (
        b"GDPC"
        + struct.pack("<IIII", 2, 4, 5, 1)
        + struct.pack("<IQ", 0, file_base)
        + (b"\x00" * 64)
    )
    return header + dir_bytes + b"".join(data_chunks)


def _encode_der_len(n: int) -> bytes:
    if n < 0x80:
        return bytes([n])
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(raw)]) + raw


def _encode_der_tlv(tag: int, body: bytes) -> bytes:
    return bytes([tag]) + _encode_der_len(len(body)) + body


def _encode_der_int(val: int) -> bytes:
    raw = val.to_bytes((val.bit_length() + 7) // 8, "big")
    if raw[0] & 0x80:
        raw = b"\x00" + raw
    return _encode_der_tlv(0x02, raw)


def _build_test_rsa_spki_pem(bits: int = 2048) -> bytes:
    """Build a deterministic, structurally valid ASN.1 DER RSA-N SubjectPublicKeyInfo PEM (test fixture only, no private key)."""
    # Deterministic odd N-bit integer with MSB set so bit_length == bits
    modulus = (1 << (bits - 1)) | int("a55a" * (bits // 16), 16) % (1 << (bits - 1)) | 1
    rsa_pub = _encode_der_tlv(0x30, _encode_der_int(modulus) + _encode_der_int(65537))
    alg_id = _encode_der_tlv(0x30, _encode_der_tlv(0x06, RSA_ENCRYPTION_OID) + b"\x05\x00")
    spki = _encode_der_tlv(0x30, alg_id + _encode_der_tlv(0x03, b"\x00" + rsa_pub))
    b64 = base64.b64encode(spki).decode("ascii")
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    return (f"{PEM_PUB_BEGIN}\n" + "\n".join(lines) + f"\n{PEM_PUB_END}\n").encode("utf-8")


SAMPLE_VALID_PUB_PEM = _build_test_rsa_spki_pem(2048)

SAMPLE_CERT_PEM = (
    "-----BEGIN CERTIFICATE-----\n"
    "MIICertNotAllowedInGodotCryptoKeyLoad000000000000000000000000000\n"
    "-----END CERTIFICATE-----\n"
).encode("utf-8")

SAMPLE_PRIV_PEM = (
    "-----BEGIN PRIVATE KEY-----\n"
    "MIIPrivateKeyMustNeverBePackaged00000000000000000000000000000000\n"
    "-----END PRIVATE KEY-----\n"
).encode("utf-8")


def _sample_presets_cfg(include_pub: bool = True, exclude_skins_dl: bool = True, exclude_pub: bool = False) -> str:
    inc = "assets/v10/fonts/*/OFL.txt, assets/v10/fonts/licenses/*.txt"
    if include_pub:
        inc += f", {PACK_PUB_REL}"
    excl_list = ["assets/manifest/assets.json"]
    if exclude_skins_dl:
        excl_list.append(SKINS_DL_GLOB)
    if exclude_pub:
        excl_list.append(PACK_PUB_REL)
    excl = ", ".join(excl_list)
    blocks = []
    for idx, name in enumerate(REQUIRED_PRESETS):
        blocks.append(
            f"[preset.{idx}]\n\n"
            f'name="{name}"\n'
            f'platform="Android"\n'
            f'export_filter="all_resources"\n'
            f'include_filter="{inc}"\n'
            f'exclude_filter="{excl}"\n'
        )
    return "\n".join(blocks)


def selftest() -> tuple[int, int]:
    results: list[bool] = []

    def case(label: str, cond: bool, info: str = "") -> None:
        results.append(bool(cond))
        print(("PASS " if cond else "FAIL ") + label + ("" if cond else f" ({info})"))

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        gdir = root / "game"
        (gdir / "scripts").mkdir(parents=True)
        (gdir / "skins_base" / "hana_base").mkdir(parents=True)
        (gdir / "skins_dl" / "akari_ssr" / "1.0").mkdir(parents=True)
        (gdir / "shell" / "skin").mkdir(parents=True)

        (gdir / "scripts" / "main.gd").write_text("extends Node\n", encoding="utf-8")
        (gdir / "scripts" / "foo_selftest.gd").write_text("extends RefCounted\n", encoding="utf-8")
        (gdir / "skins_base" / "hana_base" / "manifest.json").write_text('{"id":"hana_base"}\n', encoding="utf-8")
        (gdir / "skins_dl" / "akari_ssr" / "1.0" / "manifest.json").write_text('{"id":"akari_ssr"}\n', encoding="utf-8")

        # 1. Computed filter excludes skins_dl/** and concrete skins_dl files, keeps skins_base/
        res = compute_exclude_filter(str(gdir))
        case(
            "compute: includes skins_dl/** & skins_dl files, keeps skins_base/ shipped",
            SKINS_DL_GLOB in res["final"]
            and "skins_dl/akari_ssr/1.0/manifest.json" in res["final"]
            and "skins_base/hana_base/manifest.json" not in res["final"]
            and "scripts/foo_selftest.gd" in res["final"],
            str(res["final"]),
        )

        # 2. include_filter helper preserves licenses and adds pack_pub.pub idempotently
        inc1 = compute_include_filter("assets/v10/fonts/*/OFL.txt, assets/v10/fonts/licenses/*.txt")
        inc2 = compute_include_filter(inc1)
        case(
            "include_filter: appends shell/skin/pack_pub.pub idempotently",
            PACK_PUB_REL in _split_filter_csv(inc1) and inc1 == inc2 and "assets/v10/fonts/*/OFL.txt" in inc1,
            inc1,
        )

        # 3. Valid 3-preset config passes audit
        e_valid = audit_presets_cfg(_sample_presets_cfg(include_pub=True, exclude_skins_dl=True))
        case("presets: valid 3 presets (Android/test/store) pass audit", not e_valid, str(e_valid))

        # 4. Missing skins_dl/** in presets -> RED
        e_no_dl = audit_presets_cfg(_sample_presets_cfg(include_pub=True, exclude_skins_dl=False))
        case(
            "presets: missing skins_dl/** fails audit across all 3 presets (RED)",
            len(e_no_dl) == 3 and all("T3_SKINS_DL_NOT_EXCLUDED" in e for e in e_no_dl),
            str(e_no_dl),
        )

        # 5. Missing pack_pub.pub in include_filter -> RED
        e_no_pub = audit_presets_cfg(_sample_presets_cfg(include_pub=False, exclude_skins_dl=True))
        case(
            "presets: missing .pub in include_filter fails audit across all 3 presets (RED)",
            len(e_no_pub) == 3 and all("T12_PUB_KEY_NOT_INCLUDED" in e for e in e_no_pub),
            str(e_no_pub),
        )

        # 6. Accidentally excluding pack_pub.pub -> RED
        e_ex_pub = audit_presets_cfg(_sample_presets_cfg(include_pub=True, exclude_skins_dl=True, exclude_pub=True))
        case(
            "presets: excluding pack_pub.pub fails audit (RED)",
            len(e_ex_pub) == 3 and all("T12_PUB_KEY_EXCLUDED" in e for e in e_ex_pub),
            str(e_ex_pub),
        )

        # 7. Missing pub key file in game/ -> RED
        e_miss_file = check_pub_key_file(str(gdir))
        case(
            "pub_key file: missing shell/skin/pack_pub.pub fails (RED)",
            len(e_miss_file) == 1 and "T12_MISSING_PUB_KEY" in e_miss_file[0],
            str(e_miss_file),
        )

        # 8. Valid PEM PUBLIC KEY passes
        (gdir / PACK_PUB_REL).write_bytes(SAMPLE_VALID_PUB_PEM)
        e_ok_file = check_pub_key_file(str(gdir))
        case("pub_key file: valid PEM PUBLIC KEY passes (GREEN)", not e_ok_file, str(e_ok_file))

        # 9. .crt / private key rejected -> RED
        e_cert = validate_pub_key_bytes(SAMPLE_CERT_PEM, PACK_PUB_REL)
        e_priv = validate_pub_key_bytes(SAMPLE_PRIV_PEM, PACK_PUB_REL)
        case(
            "pub_key validation: rejects X509 CERTIFICATE and PRIVATE KEY (RED)",
            any("T12_FORBIDDEN_KEY_TYPE" in e for e in e_cert) and any("T12_FORBIDDEN_KEY_TYPE" in e for e in e_priv),
            f"cert={e_cert} priv={e_priv}",
        )

        # 10. Clean APK with embedded GDPC PCK (skins_base + valid pack_pub.pub, 0 skins_dl/) -> GREEN
        clean_pck = _build_synthetic_pck({
            "res://skins_base/hana_base/manifest.json": b'{"id":"hana_base"}',
            f"res://{PACK_PUB_REL}": SAMPLE_VALID_PUB_PEM,
        })
        clean_apk = root / "clean.apk"
        with zipfile.ZipFile(clean_apk, "w") as zf:
            zf.writestr("AndroidManifest.xml", b"manifest")
            zf.writestr("assets/main.pck", clean_pck)
        e_clean_apk = inspect_apk_or_pck(clean_apk)
        case("apk/pck: clean APK with embedded PCK + valid pack_pub.pub passes (GREEN)", not e_clean_apk, str(e_clean_apk))

        # 11. APK with direct skins_dl/ entry -> RED
        leak_apk = root / "leak_zip.apk"
        with zipfile.ZipFile(leak_apk, "w") as zf:
            zf.writestr("assets/skins_dl/akari_ssr/1.0/manifest.json", b"{}")
            zf.writestr(f"assets/{PACK_PUB_REL}", SAMPLE_VALID_PUB_PEM)
        e_leak_apk = inspect_apk_or_pck(leak_apk)
        case(
            "apk: direct assets/skins_dl/ entry triggers T3_SKINS_DL_IN_ARCHIVE (RED)",
            any("T3_SKINS_DL_IN_ARCHIVE" in e for e in e_leak_apk),
            str(e_leak_apk),
        )

        # 12. APK with skins_dl/ hidden inside embedded main.pck -> RED
        leak_pck = _build_synthetic_pck({
            "res://skins_dl/akari_ssr/1.0/rig.webp": b"fakewebp",
            f"res://{PACK_PUB_REL}": SAMPLE_VALID_PUB_PEM,
        })
        leak_pck_apk = root / "leak_pck.apk"
        with zipfile.ZipFile(leak_pck_apk, "w") as zf:
            zf.writestr("assets/main.pck", leak_pck)
        e_leak_pck = inspect_apk_or_pck(leak_pck_apk)
        case(
            "apk/pck: skins_dl/ inside embedded main.pck triggers T3_SKINS_DL_IN_ARCHIVE (RED)",
            any("T3_SKINS_DL_IN_ARCHIVE" in e for e in e_leak_pck),
            str(e_leak_pck),
        )

        # 13. APK missing pack_pub.pub -> RED
        nopub_pck = _build_synthetic_pck({"res://skins_base/hana_base/manifest.json": b"{}"})
        nopub_apk = root / "missing_pub.apk"
        with zipfile.ZipFile(nopub_apk, "w") as zf:
            zf.writestr("assets/main.pck", nopub_pck)
        e_nopub_apk = inspect_apk_or_pck(nopub_apk)
        case(
            "apk/pck: missing pack_pub.pub triggers T12_MISSING_PUB_KEY (RED)",
            any("T12_MISSING_PUB_KEY" in e for e in e_nopub_apk),
            str(e_nopub_apk),
        )

        # 14. apply_filters_to_cfg fixes broken presets so audit passes cleanly
        broken_cfg = _sample_presets_cfg(include_pub=False, exclude_skins_dl=False)
        fixed_cfg = apply_filters_to_cfg(broken_cfg, res["final"])
        e_fixed = audit_presets_cfg(fixed_cfg, computed_excl=res["final"], require_exact_excl=True)
        case("apply: apply_filters_to_cfg repairs all 3 presets to pass strict audit (GREEN)", not e_fixed, str(e_fixed))

        # 15. Garbage '!!!!...' and weak RSA-1024 keys rejected (RED)
        bang_pem = f"{PEM_PUB_BEGIN}\n{'!' * 40}\n{PEM_PUB_END}\n".encode("utf-8")
        e_bang = validate_pub_key_bytes(bang_pem, PACK_PUB_REL)
        e_weak = validate_pub_key_bytes(_build_test_rsa_spki_pem(1024), PACK_PUB_REL)
        case(
            "pub_key validation: rejects non-base64 garbage and RSA-1024 (<2048) (RED)",
            any("T12_INVALID_PEM_BASE64" in e for e in e_bang) and any("T12_WEAK_RSA_PUB_KEY" in e for e in e_weak),
            f"bang={e_bang} weak={e_weak}",
        )

        # 16. Unrelated '*.json' glob does NOT satisfy T3 skins_dl/** check (RED)
        cfg_star_json = _sample_presets_cfg(include_pub=True, exclude_skins_dl=False).replace(
            'exclude_filter="assets/manifest/assets.json"',
            'exclude_filter="*.json"',
        )
        e_star_json = audit_presets_cfg(cfg_star_json)
        case(
            "presets: unrelated '*.json' glob fails T3_SKINS_DL_NOT_EXCLUDED across all 3 presets (RED)",
            sum("T3_SKINS_DL_NOT_EXCLUDED" in e for e in e_star_json) == 3,
            str(e_star_json),
        )

    return sum(results), len(results)


def main() -> int:
    ap = argparse.ArgumentParser(description="Tile Waifu export packaging filter & P92 (T3/T12) audit gate")
    ap.add_argument("--apply", action="store_true", help="Write exclude_filter and include_filter into game/export_presets.cfg")
    ap.add_argument("--check", action="store_true", help="Exit 1 if export_presets.cfg drifts from computed filters or fails T3/T12 rules")
    ap.add_argument("--check-presets", action="store_true", help="Exit 1 if any of the 3 presets violates T3 (skins_dl/**) or T12 (.pub)")
    ap.add_argument("--check-pub-key", action="store_true", help="Exit 1 if game/shell/skin/pack_pub.pub is missing or invalid PEM PUBLIC KEY")
    ap.add_argument("--check-apk", type=str, default="", help="Inspect an .apk/.zip or .pck archive (no skins_dl/, valid pack_pub.pub)")
    ap.add_argument("--selftest", action="store_true", help="Run synthetic self-test covering skins_dl/ and missing pub key -> red exit")
    ap.add_argument("--game", type=str, default=GAME, help="Path to Godot game/ directory")
    a = ap.parse_args()

    rc = 0
    ran_special = False

    if a.selftest:
        ran_special = True
        ok, total = selftest()
        status = "PASS" if ok == total else "FAIL"
        print(f"EXPORT_FILTER SELFTEST {ok}/{total} {status}")
        if ok != total:
            rc = 1

    if a.check_apk:
        ran_special = True
        errs = inspect_apk_or_pck(a.check_apk, require_pub_key=True)
        for e in errs:
            print("FAIL", e)
        print(f"EXPORT_FILTER APK_CHECK: {'PASS' if not errs else 'FAIL'} ({len(errs)} error(s))")
        if errs:
            rc = 1

    if a.check_pub_key:
        ran_special = True
        errs = check_pub_key_file(a.game)
        for e in errs:
            print("FAIL", e)
        print(f"EXPORT_FILTER PUB_KEY: {'PASS' if not errs else 'FAIL'} ({len(errs)} error(s))")
        if errs:
            rc = 1

    if a.check_presets:
        ran_special = True
        cfg_path = os.path.join(a.game, "export_presets.cfg")
        cfg_text = open(cfg_path, encoding="utf-8").read()
        errs = audit_presets_cfg(cfg_text)
        for e in errs:
            print("FAIL", e)
        print(f"EXPORT_FILTER PRESETS: {'PASS' if not errs else 'FAIL'} ({len(errs)} error(s))")
        if errs:
            rc = 1

    if ran_special and not (a.apply or a.check):
        return rc

    res = compute_exclude_filter(a.game)
    cands = res["cands"]
    pinned = res["pinned"]
    excl = res["excl"]
    uid = res["uid"]
    soft = res["soft"]
    final = res["final"]

    print("== candidates %d | pinned (shipped) %d | excluded %d (+%d .uid, incl. %s)" % (
        len(cands), len(pinned), len(excl), len(uid), SKINS_DL_GLOB))
    byext: dict[str, int] = defaultdict(int)
    for e in excl:
        byext[os.path.splitext(e)[1]] += 1
    print("   excluded by type:", dict(byext))
    if res["skins_dl_hard_refs"]:
        print("!! T3 HARD-REF ERROR: shipped code references res://skins_dl/:")
        for r in res["skins_dl_hard_refs"]:
            print("   ", r)
    print("-- pinned (not excluded), reason:")
    for p, r in sorted(pinned.items()):
        print("   %-62s <- %s" % (p, r))
    print("-- soft references from shipped code to excluded files (runtime literal; fine only if behind a dev/test flag):")
    for s, ps in soft.items():
        print("   %s -> %s" % (s, ", ".join(sorted(set(ps)))))

    cfg_path = os.path.join(a.game, "export_presets.cfg")
    cfg = open(cfg_path, encoding="utf-8").read()
    if a.apply or a.check:
        new = apply_filters_to_cfg(cfg, final)
        if a.check:
            errs = audit_presets_cfg(cfg, computed_excl=final, require_exact_excl=True)
            if res["skins_dl_hard_refs"]:
                errs.append(f"T3_HARD_REFS: {len(res['skins_dl_hard_refs'])} shipped file(s) hard-reference skins_dl/")
            for e in errs:
                print("FAIL", e)
            ok_cfg = (new == cfg) and not errs
            print(f"EXPORT_FILTER CHECK: {'PASS' if ok_cfg else 'FAIL'} ({len(errs)} error(s))")
            return 0 if (ok_cfg and rc == 0) else 1
        open(cfg_path, "w", encoding="utf-8", newline="\n").write(new)
        print("wrote exclude_filter (%d entries) + include_filter (%s) into %d presets" % (
            len(final), PACK_PUB_REL, len(re.findall(r"(?m)^exclude_filter=", cfg))))
        return rc
    else:
        preset_errs = audit_presets_cfg(cfg)
        pub_errs = check_pub_key_file(a.game)
        print("(dry-run) exclude_filter would have %d entries (incl. %s); include_filter adds %s; use --apply" % (
            len(final), SKINS_DL_GLOB, PACK_PUB_REL))
        print("(dry-run) current preset audit findings: %d | pub key findings: %d" % (len(preset_errs), len(pub_errs)))
        for e in preset_errs + pub_errs:
            print("   AUDIT", e)
        return rc


if __name__ == "__main__":
    sys.exit(main())
