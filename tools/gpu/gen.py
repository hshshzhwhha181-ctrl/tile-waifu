import sys, os, json, torch
from diffusers import ZImagePipeline
lora = sys.argv[1]; jobs = json.load(open(sys.argv[2])); out = sys.argv[3]; os.makedirs(out, exist_ok=True)
pipe = ZImagePipeline.from_pretrained("Tongyi-MAI/Z-Image-Turbo", torch_dtype=torch.bfloat16).to("cuda")
if lora != "none":
    try:
        pipe.load_lora_weights(lora, adapter_name="tw")
    except Exception as e:
        from safetensors.torch import load_file
        sd = load_file(lora); sd = {k.replace("diffusion_model.", "transformer."): v for k, v in sd.items()}
        pipe.load_lora_weights(sd, adapter_name="tw")
    pipe.set_adapters(["tw"], adapter_weights=[float(os.environ.get("LORA_W", "1.0"))])
for j in jobs:
    p = f"{out}/{j['name']}.png"
    if os.path.exists(p): continue
    g = torch.Generator("cuda").manual_seed(j.get("seed", 42))
    im = pipe(prompt=j["prompt"], width=j.get("w", 768), height=j.get("h", 1024), num_inference_steps=j.get("steps", 9), guidance_scale=0.0, generator=g).images[0]
    im.save(p); print("saved", p, flush=True)
print("GEN_DONE", flush=True)
