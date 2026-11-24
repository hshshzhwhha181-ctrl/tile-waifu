#!/bin/bash
# HANDOFF §24.2: keep the base model and the training adapter on the persistent disk, so training and generation
# do not depend on Hugging Face. Uses the cache picked by hf_env.sh (the main thread's /workspace/tw/base_models if it
# already holds Z-Image Turbo, else /workspace/tw/hf_home); only missing files are fetched. Later boxes can run with
# TW_OFFLINE=1. Safe to re-run; ends with CACHE_OK.
set -euo pipefail
source "$(dirname "$0")/hf_env.sh"
mkdir -p "$HF_HOME"
python3 - <<'EOF'
from huggingface_hub import snapshot_download, hf_hub_download
p = snapshot_download("Tongyi-MAI/Z-Image-Turbo")
a = hf_hub_download("ostris/zimage_turbo_training_adapter", "zimage_turbo_training_adapter_v2.safetensors")
print("base:", p)
print("adapter:", a)
EOF
du -sh "${HF_HUB_CACHE:-$HF_HOME}" | tail -1
echo CACHE_OK
