"""colorlib - the small colour-science kernel shared by tools/qa/*.py (numpy only).

sRGB <-> linear <-> XYZ(D65) <-> CIELAB, CIEDE2000 (Sharma, Wu, Dalal 2005, vectorised), OKLab/OKLCH
(Ottosson 2020) and the WCAG 2.x contrast ratio. Everything here is deterministic and has no I/O.

Conventions: RGB arrays are float in 0..1 with shape (..., 3); Lab arrays are (..., 3) = (L, a, b).
"""
from __future__ import annotations

import re

import numpy as np

_HEX_RE = re.compile(r"^#?([0-9a-fA-F]{6})$")
# sRGB D65 -> XYZ (IEC 61966-2-1), reference white D65 (Xn, Yn, Zn) = (0.95047, 1.0, 1.08883)
_M_RGB2XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
                       [0.2126729, 0.7151522, 0.0721750],
                       [0.0193339, 0.1191920, 0.9503041]])
_WHITE = np.array([0.95047, 1.0, 1.08883])


def hex_to_rgb(h: str) -> np.ndarray:
    m = _HEX_RE.match(h.strip())
    if not m:
        raise ValueError(f"not a #RRGGBB colour: {h!r}")
    v = m.group(1)
    return np.array([int(v[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def rgb_to_hex(rgb) -> str:
    a = np.clip(np.rint(np.asarray(rgb, dtype=np.float64) * 255.0), 0, 255).astype(int)
    return "#%02X%02X%02X" % (a[0], a[1], a[2])


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.asarray(c, dtype=np.float64)
    c = np.clip(c, 0.0, None)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    lin = srgb_to_linear(rgb)
    xyz = lin @ _M_RGB2XYZ.T / _WHITE
    eps, kappa = 216.0 / 24389.0, 24389.0 / 27.0
    f = np.where(xyz > eps, np.cbrt(xyz), (kappa * xyz + 16.0) / 116.0)
    L = 116.0 * f[..., 1] - 16.0
    a = 500.0 * (f[..., 0] - f[..., 1])
    b = 200.0 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


def lab_to_rgb(lab: np.ndarray) -> np.ndarray:
    lab = np.asarray(lab, dtype=np.float64)
    fy = (lab[..., 0] + 16.0) / 116.0
    fx = fy + lab[..., 1] / 500.0
    fz = fy - lab[..., 2] / 200.0
    eps, kappa = 216.0 / 24389.0, 24389.0 / 27.0
    f = np.stack([fx, fy, fz], axis=-1)
    xyz = np.where(f ** 3 > eps, f ** 3, (116.0 * f - 16.0) / kappa) * _WHITE
    lin = xyz @ np.linalg.inv(_M_RGB2XYZ).T
    return np.clip(linear_to_srgb(lin), 0.0, 1.0)


def hex_to_lab(h: str) -> np.ndarray:
    return rgb_to_lab(hex_to_rgb(h))


def lab_to_hex(lab) -> str:
    return rgb_to_hex(lab_to_rgb(np.asarray(lab)))


def delta_e2000(lab1: np.ndarray, lab2: np.ndarray, kL: float = 1.0, kC: float = 1.0, kH: float = 1.0) -> np.ndarray:
    """CIEDE2000, broadcasting over leading dims. lab1 (...,3) vs lab2 (...,3) -> (...)."""
    lab1 = np.asarray(lab1, dtype=np.float64)
    lab2 = np.asarray(lab2, dtype=np.float64)
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[..., 0], lab2[..., 1], lab2[..., 2]
    C1 = np.hypot(a1, b1)
    C2 = np.hypot(a2, b2)
    Cbar = (C1 + C2) / 2.0
    G = 0.5 * (1.0 - np.sqrt(Cbar ** 7 / (Cbar ** 7 + 25.0 ** 7)))
    a1p, a2p = (1.0 + G) * a1, (1.0 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360.0
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360.0
    dLp = L2 - L1
    dCp = C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180.0, dh - 360.0, np.where(dh < -180.0, dh + 360.0, dh))
    dh = np.where((C1p * C2p) == 0.0, 0.0, dh)
    dHp = 2.0 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2.0))
    Lbp = (L1 + L2) / 2.0
    Cbp = (C1p + C2p) / 2.0
    hsum = h1p + h2p
    hbp = np.where(np.abs(h1p - h2p) <= 180.0, hsum / 2.0,
                   np.where(hsum < 360.0, (hsum + 360.0) / 2.0, (hsum - 360.0) / 2.0))
    hbp = np.where((C1p * C2p) == 0.0, hsum, hbp)
    T = (1.0 - 0.17 * np.cos(np.radians(hbp - 30.0)) + 0.24 * np.cos(np.radians(2.0 * hbp))
         + 0.32 * np.cos(np.radians(3.0 * hbp + 6.0)) - 0.20 * np.cos(np.radians(4.0 * hbp - 63.0)))
    d_theta = 30.0 * np.exp(-(((hbp - 275.0) / 25.0) ** 2))
    Rc = 2.0 * np.sqrt(Cbp ** 7 / (Cbp ** 7 + 25.0 ** 7))
    Sl = 1.0 + (0.015 * (Lbp - 50.0) ** 2) / np.sqrt(20.0 + (Lbp - 50.0) ** 2)
    Sc = 1.0 + 0.045 * Cbp
    Sh = 1.0 + 0.015 * Cbp * T
    Rt = -np.sin(np.radians(2.0 * d_theta)) * Rc
    tl, tc, th = dLp / (kL * Sl), dCp / (kC * Sc), dHp / (kH * Sh)
    return np.sqrt(tl ** 2 + tc ** 2 + th ** 2 + Rt * tc * th)


# ---- OKLab / OKLCH -----------------------------------------------------------------------------
_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]])
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]])


def rgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    lin = srgb_to_linear(rgb)
    lms = np.cbrt(lin @ _M1.T)
    return lms @ _M2.T


def rgb_to_oklch(rgb: np.ndarray) -> np.ndarray:
    ok = rgb_to_oklab(rgb)
    C = np.hypot(ok[..., 1], ok[..., 2])
    h = np.degrees(np.arctan2(ok[..., 2], ok[..., 1])) % 360.0
    return np.stack([ok[..., 0], C, h], axis=-1)


def relative_luminance(rgb: np.ndarray) -> np.ndarray:
    lin = srgb_to_linear(rgb)
    return lin @ np.array([0.2126, 0.7152, 0.0722])


def contrast_ratio(rgb_a, rgb_b) -> float:
    la, lb = float(relative_luminance(np.asarray(rgb_a))), float(relative_luminance(np.asarray(rgb_b)))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
