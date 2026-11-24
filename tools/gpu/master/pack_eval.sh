#!/bin/bash
# Pack eval results for the judges (they run in the Claude container, not on the box): JPEG q92 copies of every
# generated image + contact sheets + index.json -> /workspace/tw/eval/<name>_pack.zip, optionally PUT to a presigned URL.
# Usage: bash pack_eval.sh <name> [upload_url]     Ends with PACK_OK (and UPLOAD_HTTP_200 when uploaded).
set -euo pipefail
NAME=$1; URL=${2:-}
E=/workspace/tw/eval/$NAME; P=/workspace/tw/eval/${NAME}_pack
rm -rf "$P" && mkdir -p "$P"
python3 - "$E" "$P" <<'EOF'
import os, sys, shutil
from PIL import Image
src, dst = sys.argv[1:3]
for root, _, files in os.walk(src):
    rel = os.path.relpath(root, src)
    os.makedirs(os.path.join(dst, rel), exist_ok=True)
    for f in files:
        s = os.path.join(root, f)
        if f.endswith('.png'):
            Image.open(s).convert('RGB').save(os.path.join(dst, rel, f[:-4] + '.jpg'), quality=92)
        else:
            shutil.copy(s, os.path.join(dst, rel, f))
EOF
rm -f "$P.zip" && (cd "$(dirname "$P")" && zip -q -r "$(basename "$P").zip" "$(basename "$P")")
ls -la "$P.zip"
if [ -n "$URL" ]; then
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/zip' --upload-file "$P.zip" "$URL")
  echo "UPLOAD_HTTP_$code"
fi
echo PACK_OK
