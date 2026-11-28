#!/usr/bin/env python3
"""Subprocess & CLI exit-code tests for tools/assets/export_filter.py (P92 / T3 & T12)."""
from __future__ import annotations

import base64
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "export_filter.py"
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import export_filter as ef  # noqa: E402


def _run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def _der_len(n: int) -> bytes:
    if n < 0x80:
        return bytes([n])
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(b)]) + b


def _der_tlv(tag: int, body: bytes) -> bytes:
    return bytes([tag]) + _der_len(len(body)) + body


def _der_int(val: int) -> bytes:
    raw = val.to_bytes((val.bit_length() + 7) // 8, "big")
    if raw[0] & 0x80:
        raw = b"\x00" + raw
    return _der_tlv(0x02, raw)


def _make_rsa_spki_pem(bits: int) -> bytes:
    modulus = (1 << (bits - 1)) | ((1 << (bits - 2)) - 1) | 1
    rsa_pub = _der_tlv(0x30, _der_int(modulus) + _der_int(65537))
    alg_id = _der_tlv(0x30, b"\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01\x05\x00")
    spki = _der_tlv(0x30, alg_id + _der_tlv(0x03, b"\x00" + rsa_pub))
    b64 = base64.b64encode(spki).decode("ascii")
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    return ("-----BEGIN PUBLIC KEY-----\n" + "\n".join(lines) + "\n-----END PUBLIC KEY-----\n").encode("utf-8")


class TestExportFilterCLI(unittest.TestCase):
    def test_01_selftest_exits_zero(self) -> None:
        r = _run_cli("--selftest")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("EXPORT_FILTER SELFTEST ", r.stdout)
        self.assertIn(" PASS", r.stdout)

    def test_02_check_apk_skins_dl_returns_red(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "bad_skins_dl.apk"
            pck = ef._build_synthetic_pck({
                "res://skins_dl/akari_ssr/1.0/manifest.json": b"{}",
                f"res://{ef.PACK_PUB_REL}": ef.SAMPLE_VALID_PUB_PEM,
            })
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
            self.assertIn("T3_SKINS_DL_IN_ARCHIVE", r.stdout)

    def test_03_check_apk_missing_pub_key_returns_red(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "missing_pub.apk"
            pck = ef._build_synthetic_pck({"res://skins_base/hana_base/manifest.json": b"{}"})
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
            self.assertIn("T12_MISSING_PUB_KEY", r.stdout)

    def test_04_check_apk_clean_returns_green(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "clean.apk"
            pck = ef._build_synthetic_pck({
                "res://skins_base/hana_base/manifest.json": b"{}",
                f"res://{ef.PACK_PUB_REL}": ef.SAMPLE_VALID_PUB_PEM,
            })
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("EXPORT_FILTER APK_CHECK: PASS", r.stdout)

    def test_05_check_pub_key_and_apply_on_temp_game(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            g = Path(td) / "game"
            (g / "scripts").mkdir(parents=True)
            (g / "scripts" / "main.gd").write_text("extends Node\n", encoding="utf-8")
            (g / "export_presets.cfg").write_text(
                ef._sample_presets_cfg(include_pub=False, exclude_skins_dl=False),
                encoding="utf-8",
            )
            # Missing pub key -> RED
            r_miss = _run_cli("--game", str(g), "--check-pub-key")
            self.assertEqual(r_miss.returncode, 1, r_miss.stdout)
            self.assertIn("T12_MISSING_PUB_KEY", r_miss.stdout)

            # Broken presets -> RED
            r_bad_cfg = _run_cli("--game", str(g), "--check")
            self.assertEqual(r_bad_cfg.returncode, 1, r_bad_cfg.stdout)

            # Provision valid key + run --apply -> both GREEN
            pub = g / ef.PACK_PUB_REL
            pub.parent.mkdir(parents=True, exist_ok=True)
            pub.write_bytes(ef.SAMPLE_VALID_PUB_PEM)
            r_apply = _run_cli("--game", str(g), "--apply")
            self.assertEqual(r_apply.returncode, 0, r_apply.stdout + r_apply.stderr)

            r_ok_pub = _run_cli("--game", str(g), "--check-pub-key")
            self.assertEqual(r_ok_pub.returncode, 0, r_ok_pub.stdout)
            r_ok_cfg = _run_cli("--game", str(g), "--check")
            self.assertEqual(r_ok_cfg.returncode, 0, r_ok_cfg.stdout)
            self.assertIn("EXPORT_FILTER CHECK: PASS", r_ok_cfg.stdout)

    def test_06_rejects_garbage_and_non_rsa2048_pub_keys(self) -> None:
        # 40-char '!!!!...' must be rejected (invalid base64)
        bang_pem = b"-----BEGIN PUBLIC KEY-----\n" + (b"!" * 40) + b"\n-----END PUBLIC KEY-----\n"
        self.assertTrue(ef.validate_pub_key_bytes(bang_pem, ef.PACK_PUB_REL), "40x '!' must be rejected")

        # Literal fake placeholder 'SyntheticKey000' must be rejected (invalid ASN.1 DER)
        fake_synth = (
            b"-----BEGIN PUBLIC KEY-----\n"
            b"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtwP92SyntheticKey000\n"
            b"0000000000000000000000000000000000000000000000000000000000000000\n"
            b"-----END PUBLIC KEY-----\n"
        )
        self.assertTrue(ef.validate_pub_key_bytes(fake_synth, ef.PACK_PUB_REL), "SyntheticKey000 placeholder must be rejected")

        # Valid base64 of non-ASN.1 garbage must be rejected
        junk_b64 = base64.b64encode(b"not-valid-asn1-der-subject-public-key-info-payload").decode("ascii")
        junk_pem = f"-----BEGIN PUBLIC KEY-----\n{junk_b64}\n-----END PUBLIC KEY-----\n".encode("utf-8")
        self.assertTrue(ef.validate_pub_key_bytes(junk_pem, ef.PACK_PUB_REL), "non-ASN.1 base64 must be rejected")

        # Valid ASN.1 RSA-1024 (< 2048 bits) must be rejected
        rsa1024 = _make_rsa_spki_pem(1024)
        self.assertTrue(ef.validate_pub_key_bytes(rsa1024, ef.PACK_PUB_REL), "RSA-1024 (<2048 bits) must be rejected")

        # Built-in SAMPLE_VALID_PUB_PEM must be a real RSA-2048 SPKI (not SyntheticKey000) and pass
        self.assertNotIn(b"SyntheticKey", ef.SAMPLE_VALID_PUB_PEM)
        self.assertEqual(ef.validate_pub_key_bytes(ef.SAMPLE_VALID_PUB_PEM, ef.PACK_PUB_REL), [])

        # CLI --check-apk with garbage key must return 1
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "garbage_key.apk"
            pck = ef._build_synthetic_pck({
                "res://skins_base/hana_base/manifest.json": b"{}",
                f"res://{ef.PACK_PUB_REL}": bang_pem,
            })
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_07_rejects_unrelated_glob_for_t3_skins_dl(self) -> None:
        # exclude_filter="*.json" matches manifest.json but NOT .png/.ctex/.webp under skins_dl/
        cfg_star_json = ef._sample_presets_cfg(include_pub=True, exclude_skins_dl=False).replace(
            'exclude_filter="assets/manifest/assets.json"',
            'exclude_filter="*.json"',
        )
        errs_star_json = ef.audit_presets_cfg(cfg_star_json)
        self.assertEqual(
            sum("T3_SKINS_DL_NOT_EXCLUDED" in e for e in errs_star_json),
            3,
            msg=f"exclude_filter='*.json' must fail T3_SKINS_DL_NOT_EXCLUDED across all 3 presets, got: {errs_star_json}",
        )

        # exclude_filter="skins_dl/**/*.json" also leaves .png/.ctex unexcluded
        cfg_partial = ef._sample_presets_cfg(include_pub=True, exclude_skins_dl=False).replace(
            'exclude_filter="assets/manifest/assets.json"',
            'exclude_filter="skins_dl/**/*.json"',
        )
        errs_partial = ef.audit_presets_cfg(cfg_partial)
        self.assertEqual(
            sum("T3_SKINS_DL_NOT_EXCLUDED" in e for e in errs_partial),
            3,
            msg=f"exclude_filter='skins_dl/**/*.json' must fail T3_SKINS_DL_NOT_EXCLUDED across all 3 presets, got: {errs_partial}",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
