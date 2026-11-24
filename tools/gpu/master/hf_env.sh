# Sourced by the tw_master scripts: pick the persistent Hugging Face cache on /workspace so the base model
# (Z-Image Turbo, ~20+ GB) and the ostris training adapter are not downloaded again.
# The main thread keeps a cache in /workspace/tw/base_models (STYLE_SYSTEM «Где лежат веса»); if it holds Z-Image Turbo,
# its hub folder is used as HF_HUB_CACHE, otherwise /workspace/tw/hf_home. Set TW_OFFLINE=1 to forbid any download.
_BM=/workspace/tw/base_models
_HUB=$(find "$_BM" -maxdepth 4 -type d -name 'models--Tongyi-MAI--Z-Image-Turbo' 2>/dev/null | head -1 || true)
export HF_HOME=${HF_HOME:-/workspace/tw/hf_home}
if [ -n "$_HUB" ]; then export HF_HUB_CACHE=$(dirname "$_HUB"); fi
export HF_HUB_ENABLE_HF_TRANSFER=1
if [ "${TW_OFFLINE:-0}" = 1 ]; then export HF_HUB_OFFLINE=1; fi
echo "hf cache: HF_HOME=$HF_HOME HF_HUB_CACHE=${HF_HUB_CACHE:-<HF_HOME/hub>}"
