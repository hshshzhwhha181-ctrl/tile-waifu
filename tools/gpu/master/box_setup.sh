#!/bin/bash
# Idempotent setup of a fresh Higgsfield GPU box for tw_master training and eval.
# Usage (on the box): nohup bash /workspace/tw/kit/tools/gpu/master/box_setup.sh > /workspace/tw/logs/setup.log 2>&1 &
# Ends with the line SETUP_OK. Safe to re-run. Never git-pulls /workspace/tw/ai-toolkit: another box (UI-LoRA) may use it.
set -euo pipefail
export HF_HOME=/workspace/tw/hf_home HF_HUB_ENABLE_HF_TRANSFER=1 PIP_CACHE_DIR=/workspace/tw/pip-cache
mkdir -p /workspace/tw/logs "$HF_HOME" "$PIP_CACHE_DIR"
cd /workspace/tw
if [ ! -d ai-toolkit ]; then
  git clone -q https://github.com/ostris/ai-toolkit.git ai-toolkit
  (cd ai-toolkit && git submodule update -q --init --recursive)
fi
echo "ai-toolkit commit: $(git -C ai-toolkit rev-parse --short HEAD 2>/dev/null || echo unknown)"
if ! command -v gcc >/dev/null || ! command -v zip >/dev/null || [ ! -f /usr/include/python3.12/Python.h ]; then
  apt-get install -y -q gcc python3.12-dev zip >/dev/null 2>&1 || { apt-get update -q >/dev/null && apt-get install -y -q gcc python3.12-dev zip >/dev/null; }
fi
if ! python3 -c "import diffusers, lycoris, bitsandbytes, optimum.quanto; assert hasattr(diffusers, 'ZImagePipeline')" 2>/dev/null; then
  (cd ai-toolkit && pip install -q -r requirements.txt)
fi
pip install -q hf_transfer huggingface_hub pyyaml pillow >/dev/null
python3 - <<'EOF'
import torch, diffusers
print("torch", torch.__version__, "cuda", torch.version.cuda, "gpu", torch.cuda.get_device_name(0),
      "vram_gb", round(torch.cuda.get_device_properties(0).total_memory / 2**30))
print("diffusers", diffusers.__version__, "has ZImagePipeline", hasattr(diffusers, "ZImagePipeline"))
EOF
echo SETUP_OK
