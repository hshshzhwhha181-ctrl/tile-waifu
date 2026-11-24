#!/usr/bin/env python3
"""Scene candidates for the master dataset: download Higgsfield results for audit, then write the approved set.

  python3 collect.py download <jobs.json> <outdir>
      jobs.json: [{"scene_id": "sc_01_x", "variant": 1, "job_id": "...", "url": "https://...png"}, ...]
      -> <outdir>/<scene_id>__v<variant>.png (skips existing) and <outdir>/jobs.json copy
  python3 collect.py finalize <scenes.json> <selection.json>
      selection.json: [{"scene_id": "...", "job_id": "...", "url": "...", "caption": "<optional fixed caption>"}, ...]
      -> tools/art/master_captions/scenes/<scene_id>.txt + MANIFEST.tsv (file, source_job_id, url, approved)
         which fetch_dataset.sh downloads on the GPU box.
Only scenes that passed the double anatomy audit go into selection.json (HANDOFF §3: брак в датасет не попадает).
"""
import json, os, shutil, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CAPS = os.path.normpath(os.path.join(HERE, '..', 'master_captions', 'scenes'))

cmd = sys.argv[1]
if cmd == 'download':
    jobs = json.load(open(sys.argv[2])); out = sys.argv[3]
    os.makedirs(out, exist_ok=True)
    for j in jobs:
        dst = f"{out}/{j['scene_id']}__v{j.get('variant', 1)}.png"
        if not os.path.exists(dst):
            urllib.request.urlretrieve(j['url'], dst)
        print(dst, os.path.getsize(dst))
    shutil.copy(sys.argv[2], f"{out}/jobs.json")
elif cmd == 'finalize':
    scenes = {s['id']: s for s in json.load(open(sys.argv[2]))['scenes']}
    sel = json.load(open(sys.argv[3]))
    os.makedirs(CAPS, exist_ok=True)
    rows = ['file\tsource_job_id\turl\tapproved']
    for s in sel:
        sid = s['scene_id']
        cap = (s.get('caption') or scenes[sid]['caption']).strip()
        assert cap.startswith('twmaster style, scenes, '), sid
        open(f"{CAPS}/{sid}.txt", 'w').write(cap)
        rows.append(f"{sid}.jpg\t{s['job_id']}\t{s['url']}\tyes")
    open(f"{CAPS}/MANIFEST.tsv", 'w').write('\n'.join(rows) + '\n')
    print(len(sel), 'scenes ->', CAPS)
else:
    sys.exit(__doc__)
