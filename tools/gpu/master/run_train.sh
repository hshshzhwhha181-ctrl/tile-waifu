#!/bin/bash
# Start (or resume) a tw_master training run in the background from the kit config, with optional overrides.
# ai-toolkit resumes from the last checkpoint in /workspace/tw/output/<NAME>/ if the job name is unchanged.
# Env overrides (all optional), used by the v2/v3 playbook in EVAL_RUBRIC.md:
#   NAME=tw_master_v1  DS_NAME=master_v1  STEPS=6000  RANK=128  LR=0.0001  RES=512,768,1024
#   REPEATS=heroines=2,environments=2,ui=2,tiles_fx=2,scenes=3   SAVE_EVERY=500
# Writes /workspace/tw/<NAME>.runtime.yaml, log /workspace/tw/logs/<NAME>.log, pid /workspace/tw/logs/<NAME>.pid
# Stop ONLY with: kill $(cat /workspace/tw/logs/<NAME>.pid)   (never pkill -f run.py: it kills the exec shell)
set -euo pipefail
KIT=${KIT:-/workspace/tw/kit}
export NAME=${NAME:-tw_master_v1} DS_NAME=${DS_NAME:-master_v1}
export HF_HOME=/workspace/tw/hf_home HF_HUB_ENABLE_HF_TRANSFER=1 CC=gcc
mkdir -p /workspace/tw/logs
RT=/workspace/tw/$NAME.runtime.yaml
python3 - "$KIT/tools/gpu/master/train_master_v1.yaml" "$RT" <<'EOF'
import os, sys, yaml
src, dst = sys.argv[1:3]
c = yaml.safe_load(open(src)); p = c['config']['process'][0]
name, ds = os.environ['NAME'], os.environ['DS_NAME']
c['config']['name'] = name; c['meta']['name'] = name
e = os.environ.get
if e('STEPS'): p['train']['steps'] = int(e('STEPS'))
if e('LR'): p['train']['lr'] = float(e('LR'))
if e('RANK'): p['network']['linear'] = p['network']['linear_alpha'] = int(e('RANK'))
if e('SAVE_EVERY'): p['save']['save_every'] = int(e('SAVE_EVERY'))
rep = dict(kv.split('=') for kv in e('REPEATS', '').split(',') if kv)
res = [int(x) for x in e('RES', '').split(',') if x]
keep = []
for d in p['datasets']:
    cat = d['folder_path'].rstrip('/').split('/')[-1]
    d['folder_path'] = f"/workspace/tw/data/{ds}/{cat}"
    if cat in rep: d['num_repeats'] = int(rep[cat])
    if res: d['resolution'] = res
    n = len([f for f in os.listdir(d['folder_path']) if f.lower().endswith(('.jpg', '.png', '.webp'))]) if os.path.isdir(d['folder_path']) else 0
    if n == 0 or d.get('num_repeats', 1) == 0:
        print(f"skip dataset {cat}: {n} images"); continue
    print(f"dataset {cat}: {n} images x{d.get('num_repeats', 1)}")
    keep.append(d)
p['datasets'] = keep
yaml.safe_dump(c, open(dst, 'w'), sort_keys=False, allow_unicode=True, width=10000)
print("steps", p['train']['steps'], "rank", p['network']['linear'], "lr", p['train']['lr'])
EOF
cd /workspace/tw/ai-toolkit
nohup python3 run.py "$RT" > "/workspace/tw/logs/$NAME.log" 2>&1 &
echo $! > "/workspace/tw/logs/$NAME.pid"
echo "STARTED $NAME pid $(cat /workspace/tw/logs/$NAME.pid) log /workspace/tw/logs/$NAME.log"
