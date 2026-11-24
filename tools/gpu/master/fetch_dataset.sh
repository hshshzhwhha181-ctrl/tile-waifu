#!/bin/bash
# Lay out the master dataset on the persistent disk: /workspace/tw/data/<DS_NAME>/<category>/<name>.{jpg,png,txt}
# Images: archive A (HANDOFF §26, permanent link) for heroines/environments/tiles_fx/ui; scenes are downloaded by URL
# from tools/art/master_captions/scenes/MANIFEST.tsv (column "url"), if that file exists.
# Captions ALWAYS come from the repo kit (tools/art/master_captions), so caption fixes in git reach the next run.
# Usage: DS_NAME=master_v1 bash fetch_dataset.sh   (ends with DATASET_OK and per-category counts)
set -euo pipefail
KIT=${KIT:-/workspace/tw/kit}
DS_NAME=${DS_NAME:-master_v1}
D=/workspace/tw/data/$DS_NAME
ARCH_A=https://d2ol7oe51mr4n9.cloudfront.net/user_3L5lNdYfxsf6b0O0pIlvJXXfClr/12f7b79f-3d5a-4137-b68e-5dfc5b66ae18.zip
mkdir -p "$D" /workspace/tw/dl
cd /workspace/tw/dl
if [ ! -f archA.ok ]; then
  curl -sSL --retry 4 -o archA.zip "$ARCH_A"
  rm -rf archA && mkdir archA
  python3 -c "import zipfile; z=zipfile.ZipFile('archA.zip'); [z.extract(m, 'archA') for m in z.namelist() if m.startswith('master/ds/')]"
  touch archA.ok
fi
for c in heroines environments tiles_fx ui; do
  mkdir -p "$D/$c"
  for cap in "$KIT"/tools/art/master_captions/$c/*.txt; do
    n=$(basename "$cap" .txt)
    img=$(ls archA/master/ds/$c/"$n".* 2>/dev/null | grep -E '\.(jpg|png|webp)$' | head -1 || true)
    if [ -z "$img" ]; then echo "MISSING image for $c/$n" >&2; exit 1; fi
    cp -n "$img" "$D/$c/" 2>/dev/null || true
    cp "$cap" "$D/$c/$n.txt"
  done
done
SM="$KIT/tools/art/master_captions/scenes/MANIFEST.tsv"
if [ -f "$SM" ]; then
  mkdir -p "$D/scenes"
  python3 - "$SM" "$D/scenes" "$KIT/tools/art/master_captions/scenes" <<'EOF'
import csv, io, os, sys, urllib.request
from PIL import Image
man, out, caps = sys.argv[1:4]
rows = [r for r in csv.DictReader(open(man), delimiter='\t') if r.get('approved', 'yes').strip() == 'yes']
for r in rows:
    name = os.path.splitext(r['file'])[0]
    dst = f"{out}/{name}.jpg"
    if not os.path.exists(dst):
        data = urllib.request.urlopen(r['url'], timeout=120).read()
        im = Image.open(io.BytesIO(data)).convert('RGB')
        s = 1024 / max(im.size)  # same scale as the rest of the dataset: long side 1024
        if s < 1:
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        im.save(dst, quality=95)
    with open(f"{caps}/{name}.txt") as f, open(f"{out}/{name}.txt", 'w') as g:
        g.write(f.read().strip())
print("scenes", len(rows))
EOF
fi
for c in "$D"/*/; do
  echo "$(basename "$c"): $(ls "$c" | grep -c -E '\.(jpg|png|webp)$') img, $(ls "$c" | grep -c '\.txt$') txt"
done
echo DATASET_OK
