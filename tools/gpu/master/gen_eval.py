#!/usr/bin/env python3
"""Generate the fixed tw_master eval suite for several LoRA checkpoints (and the base model as a control),
then build contact sheets for the three judges (see EVAL_RUBRIC.md).

Usage (on the GPU box):
  HF_HOME=/workspace/tw/hf_home python3 gen_eval.py --prompts eval_prompts.json --out /workspace/tw/eval/tw_master_v1 \
      --lora base=none --lora s3000=/workspace/tw/output/tw_master_v1/tw_master_v1_000003000.safetensors \
      --lora s6000=/workspace/tw/output/tw_master_v1/tw_master_v1.safetensors@0.8
  --only heroines,e05_...   restrict to categories and/or item ids
Outputs: <out>/<tag>/<id>.png, <out>/sheets/<tag>__<category>.jpg (one tag, all items of a category),
         <out>/sheets/compare__<category>.jpg (rows = items, columns = tags), <out>/index.json. Re-runs skip existing PNGs.
Ends with EVAL_DONE.
"""
import argparse, json, os, time

from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument('--prompts', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--lora', action='append', default=[], help='tag=path[@weight]; path "none" = base model without LoRA')
ap.add_argument('--only', default='')
ap.add_argument('--steps', type=int, default=0, help='override sampler steps from the prompts file')
ap.add_argument('--sheets_only', action='store_true')
a = ap.parse_args()

suite = json.load(open(a.prompts))
steps = a.steps or suite.get('sampler', {}).get('steps', 9)
only = {x for x in a.only.split(',') if x}
items = [it for it in suite['items'] if not only or it['id'] in only or it['category'] in only]
cats = list(dict.fromkeys(it['category'] for it in items))
specs = []
for s in a.lora:
    tag, rest = s.split('=', 1)
    path, _, w = rest.partition('@')
    specs.append((tag, path, float(w or 1.0)))
os.makedirs(f"{a.out}/sheets", exist_ok=True)


def load_lora(pipe, path, name):
    try:
        pipe.load_lora_weights(path, adapter_name=name)
    except Exception as e:  # ai-toolkit keys are "diffusion_model.*"; diffusers expects "transformer.*" (same fallback as tools/gpu/gen.py)
        print("direct load failed, converting keys:", repr(e)[:200], flush=True)
        from safetensors.torch import load_file
        sd = {k.replace("diffusion_model.", "transformer."): v for k, v in load_file(path).items()}
        pipe.load_lora_weights(sd, adapter_name=name)


timing = {}
if not a.sheets_only:
    import torch
    from diffusers import ZImagePipeline
    pipe = ZImagePipeline.from_pretrained("Tongyi-MAI/Z-Image-Turbo", torch_dtype=torch.bfloat16).to("cuda")
    for tag, path, w in specs:
        os.makedirs(f"{a.out}/{tag}", exist_ok=True)
        todo = [it for it in items if not os.path.exists(f"{a.out}/{tag}/{it['id']}.png")]
        if not todo:
            continue
        if path == 'none':
            if getattr(pipe, 'get_list_adapters', None) and pipe.get_list_adapters():
                pipe.disable_lora()
        else:
            load_lora(pipe, path, tag)
            pipe.enable_lora()
            pipe.set_adapters([tag], adapter_weights=[w])
        t0 = time.time()
        for it in todo:
            g = torch.Generator("cuda").manual_seed(int(it['seed']))
            im = pipe(prompt=it['prompt'], width=int(it['w']), height=int(it['h']), num_inference_steps=steps,
                      guidance_scale=float(suite.get('sampler', {}).get('guidance', 0.0)), generator=g).images[0]
            im.save(f"{a.out}/{tag}/{it['id']}.png")
            print("saved", tag, it['id'], flush=True)
        timing[tag] = round((time.time() - t0) / len(todo), 2)
        if path != 'none':
            try:
                pipe.delete_adapters([tag])
            except Exception as e:
                print("delete_adapters failed (ok):", repr(e)[:120], flush=True)

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
except Exception:
    FONT = ImageFont.load_default()


def thumb(path, box):
    im = Image.open(path).convert('RGB')
    im.thumbnail((box, box), Image.LANCZOS)
    return im


def sheet_one(tag, cat, box=384, cols=5):
    its = [it for it in items if it['category'] == cat and os.path.exists(f"{a.out}/{tag}/{it['id']}.png")]
    if not its:
        return
    rows = (len(its) + cols - 1) // cols
    s = Image.new('RGB', (cols * box, rows * (box + 26)), (24, 22, 28))
    d = ImageDraw.Draw(s)
    for i, it in enumerate(its):
        x, y = (i % cols) * box, (i // cols) * (box + 26)
        t = thumb(f"{a.out}/{tag}/{it['id']}.png", box - 8)
        s.paste(t, (x + (box - t.width) // 2, y + 4))
        d.text((x + 6, y + box), f"{it['id']} [{it.get('split', '')}]", fill=(235, 225, 210), font=FONT)
    s.save(f"{a.out}/sheets/{tag}__{cat}.jpg", quality=90)


def sheet_compare(cat, box=320):
    tags = [t for t, _, _ in specs if os.path.isdir(f"{a.out}/{t}")]
    its = [it for it in items if it['category'] == cat]
    if not tags or not its:
        return
    s = Image.new('RGB', (220 + len(tags) * box, 30 + len(its) * box), (24, 22, 28))
    d = ImageDraw.Draw(s)
    for j, t in enumerate(tags):
        d.text((220 + j * box + 8, 6), t, fill=(235, 225, 210), font=FONT)
    for i, it in enumerate(its):
        d.text((6, 30 + i * box + box // 2), it['id'][:22], fill=(235, 225, 210), font=FONT)
        for j, t in enumerate(tags):
            p = f"{a.out}/{t}/{it['id']}.png"
            if os.path.exists(p):
                th = thumb(p, box - 8)
                s.paste(th, (220 + j * box + (box - th.width) // 2, 30 + i * box + 4))
    s.save(f"{a.out}/sheets/compare__{cat}.jpg", quality=88)


for cat in cats:
    for tag, _, _ in specs:
        sheet_one(tag, cat)
    sheet_compare(cat)

idx_path = f"{a.out}/index.json"
idx = json.load(open(idx_path)) if os.path.exists(idx_path) else {"tags": {}, "items": []}
for tag, path, w in specs:
    idx["tags"][tag] = {"path": path, "weight": w, "sec_per_image": timing.get(tag, idx["tags"].get(tag, {}).get("sec_per_image"))}
idx["items"] = [{k: it[k] for k in ('id', 'category', 'split') if k in it} for it in suite['items']]
idx["steps"] = steps
json.dump(idx, open(idx_path, 'w'), indent=1, ensure_ascii=False)
print("EVAL_DONE", json.dumps(timing), flush=True)
