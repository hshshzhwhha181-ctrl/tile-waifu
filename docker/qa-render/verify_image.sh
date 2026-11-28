#!/usr/bin/env bash
# Verifies pinned Mesa/LLVM/Xvfb/Godot/fonts environment inside docker/qa-render
# and optionally writes /etc/tw-qa-render/env.json fingerprint for golden capture.
set -euo pipefail

MANIFEST_OUT=""
if [ "${1:-}" = "--write-manifest" ] && [ -n "${2:-}" ]; then
  MANIFEST_OUT="$2"
fi

GODOT="${GODOT_BIN:-/usr/local/bin/godot4}"
GODOT_VER="$("$GODOT" --version 2>/dev/null | head -n 1 | tr -d '\r')"
GLX_INFO="$(xvfb-run -a -s "-screen 0 1280x720x24 -ac +extension GLX +render -noreset" glxinfo -B 2>&1 || true)"

python3 - "$GODOT_VER" "$GLX_INFO" "$MANIFEST_OUT" <<'PY'
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

godot_ver, glx_info, manifest_out = sys.argv[1], sys.argv[2], sys.argv[3]

def dpkg_ver(pkg: str) -> str:
    p = subprocess.run(["dpkg-query", "-W", "-f=${Version}", pkg], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else "missing"

def py_ver(mod: str) -> str:
    m = __import__(mod)
    return str(getattr(m, "__version__", "unknown"))

renderer = ""
gl_version = ""
for ln in glx_info.splitlines():
    s = ln.strip()
    if s.startswith("OpenGL renderer string:"):
        renderer = s.split(":", 1)[1].strip()
    elif s.startswith("OpenGL version string:"):
        gl_version = s.split(":", 1)[1].strip()

fc_conf = Path("/etc/fonts/local.conf")
fc_sha = hashlib.sha256(fc_conf.read_bytes()).hexdigest()[:16] if fc_conf.exists() else ""

env_doc = {
    "profile": os.environ.get("TW_QA_RENDER_PROFILE", "llvmpipe-gl33-v1"),
    "apt_snapshot": os.environ.get("TW_QA_APT_SNAPSHOT", ""),
    "godot_version": godot_ver,
    "renderer": renderer,
    "opengl_version": gl_version,
    "lp_num_threads": os.environ.get("LP_NUM_THREADS", ""),
    "packages": {
        "libgl1-mesa-dri": dpkg_ver("libgl1-mesa-dri"),
        "libglx-mesa0": dpkg_ver("libglx-mesa0"),
        "libegl-mesa0": dpkg_ver("libegl-mesa0"),
        "libllvm18": dpkg_ver("libllvm18"),
        "xvfb": dpkg_ver("xvfb"),
        "fontconfig": dpkg_ver("fontconfig"),
        "fonts-dejavu-core": dpkg_ver("fonts-dejavu-core"),
        "fonts-noto-core": dpkg_ver("fonts-noto-core"),
    },
    "python": {
        "version": sys.version.split()[0],
        "numpy": py_ver("numpy"),
        "pillow": py_ver("PIL"),
        "jsonschema": py_ver("jsonschema"),
    },
    "fontconfig_local_sha256_16": fc_sha,
}

# Hard assertions for valid rendering QA image (including pinned package versions)
errors = []
if not godot_ver.startswith("4.5.1"):
    errors.append(f"expected Godot 4.5.1*, got {godot_ver!r}")
if "llvmpipe" not in renderer.lower():
    errors.append(f"expected llvmpipe OpenGL renderer, got {renderer!r}")
if env_doc["packages"]["xvfb"] == "missing":
    errors.append("xvfb missing")
pin_checks = [
    ("libgl1-mesa-dri", os.environ.get("TW_QA_PIN_MESA", "")),
    ("libglx-mesa0", os.environ.get("TW_QA_PIN_MESA", "")),
    ("libegl-mesa0", os.environ.get("TW_QA_PIN_MESA", "")),
    ("libllvm18", os.environ.get("TW_QA_PIN_LLVM18", "")),
    ("xvfb", os.environ.get("TW_QA_PIN_XVFB", "")),
    ("fontconfig", os.environ.get("TW_QA_PIN_FONTCONFIG", "")),
    ("fonts-dejavu-core", os.environ.get("TW_QA_PIN_FONTS_DEJAVU", "")),
    ("fonts-noto-core", os.environ.get("TW_QA_PIN_FONTS_NOTO", "")),
]
for pkg, expected in pin_checks:
    actual = env_doc["packages"].get(pkg, "missing")
    if expected and actual != expected:
        errors.append(f"pinned package drift for {pkg}: expected {expected!r}, got {actual!r}")

if manifest_out:
    Path(manifest_out).write_text(json.dumps(env_doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print(json.dumps(env_doc, indent=2, sort_keys=True))
if errors:
    print("QA_RENDER_IMAGE FAIL:", "; ".join(errors), file=sys.stderr)
    sys.exit(1)
print("QA_RENDER_IMAGE OK")
PY
