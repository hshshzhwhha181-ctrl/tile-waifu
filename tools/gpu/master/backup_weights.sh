#!/bin/bash
# HANDOFF §24.1: back up LoRA weights twice — on the persistent disk and as a permanent Higgsfield file link.
# Usage (on the box):
#   bash backup_weights.sh <name> <checkpoint_file_or_"final"> [upload_url]
#   e.g. bash backup_weights.sh tw_master_v1 tw_master_v1_000004000.safetensors "<upload_url from media_upload>"
#        TRIGGER="twaifu4 style" bash backup_weights.sh tw_heroines_v2b final "<upload_url>"   (older LoRAs, same way)
# 1) copies the chosen checkpoint (renamed to <name>.safetensors, never overwriting an existing backup) + runtime config
#    + training log + eval index into /workspace/tw/backups/<name>/ and writes SHA256SUMS;
# 2) zips that folder (store, no compression) to /workspace/tw/backups/<name>.zip;
# 3) if upload_url is given, PUTs the zip there (presigned URL from Higgsfield media_upload with source_type file_input,
#    workspace d56c6962-fcec-4bcb-a0d6-fd78e2c43e29); after HTTP 200 call media_confirm (type file) and record the
#    permanent cloudfront link in docs/STYLE_SYSTEM.md, table «Где лежат веса».
# Ends with BACKUP_OK (and UPLOAD_HTTP_200 when uploaded).
set -euo pipefail
NAME=$1; CK=${2:-final}; URL=${3:-}
OUT=/workspace/tw/output/$NAME
B=/workspace/tw/backups/$NAME
[ "$CK" = final ] && CK=$NAME.safetensors
[ -f "$OUT/$CK" ] || { echo "no checkpoint $OUT/$CK"; ls "$OUT"/*.safetensors; exit 1; }
mkdir -p "$B"
if [ -f "$B/$NAME.safetensors" ] && ! cmp -s "$OUT/$CK" "$B/$NAME.safetensors"; then
  echo "backup $B/$NAME.safetensors exists and differs: refusing to overwrite (use a new version name)"; exit 1
fi
cp "$OUT/$CK" "$B/$NAME.safetensors"
echo "$CK" > "$B/SOURCE_CHECKPOINT.txt"
cp /workspace/tw/$NAME.runtime.yaml "$B/" 2>/dev/null || true
tail -n 200 /workspace/tw/logs/$NAME.log > "$B/train_log_tail.txt" 2>/dev/null || true
cp /workspace/tw/eval/$NAME/index.json "$B/eval_index.json" 2>/dev/null || true
cat > "$B/README.txt" <<EOF
LoRA $NAME for Z-Image Turbo (Tongyi-MAI/Z-Image-Turbo), trained with ai-toolkit (see runtime yaml).
Trigger: ${TRIGGER:-twmaster style, <category>, ... (category = heroines | environments | ui | tiles_fx | scenes)}; all LoRAs and triggers: docs/STYLE_SYSTEM.md.
Generation: 9 steps, guidance 0, see tools/gpu/master/gen_eval.py and docs/STYLE_SYSTEM.md in hshshzhwhha181-ctrl/tile-waifu.
Source checkpoint: $CK
EOF
(cd "$B" && sha256sum * > SHA256SUMS)
rm -f "/workspace/tw/backups/$NAME.zip"
(cd /workspace/tw/backups && zip -q -0 -r "$NAME.zip" "$NAME")
ls -la "/workspace/tw/backups/$NAME.zip"
if [ -n "$URL" ]; then
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H 'Content-Type: application/zip' --upload-file "/workspace/tw/backups/$NAME.zip" "$URL")
  echo "UPLOAD_HTTP_$code"
fi
echo BACKUP_OK
