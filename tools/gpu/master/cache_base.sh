#!/bin/bash
# HANDOFF §24.2: keep the base model and the training adapter on the persistent disk, so training and generation
# do not depend on Hugging Face. Everything goes into HF_HOME=/workspace/tw/hf_home (the cache every script here uses),
# so later boxes load it with HF_HUB_OFFLINE=1. Safe to re-run; ends with CACHE_OK.
set -euo pipefail
export HF_HOME=/workspace/tw/hf_home HF_HUB_ENABLE_HF_TRANSFER=1
mkdir -p "$HF_HOME"
python3 - <<'EOF'
from huggingface_hub import snapshot_download, hf_hub_download
p = snapshot_download("Tongyi-MAI/Z-Image-Turbo")
a = hf_hub_download("ostris/zimage_turbo_training_adapter", "zimage_turbo_training_adapter_v2.safetensors")
print("base:", p)
print("adapter:", a)
EOF
du -sh "$HF_HOME" | tail -1
echo CACHE_OK
