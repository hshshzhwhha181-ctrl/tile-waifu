#!/usr/bin/env python3
"""Tile Waifu music style check (ear-proxy).
usage: style_check.py REF_DIR [candidate files...]
 - CLAP (laion/larger_clap_general; larger_clap_music checkpoint on HF is broken) audio embedding: cosine to approved centroid and nearest approved track,
   compared with leave-one-out baseline of the approved set.
 - zero-shot instrument/genre tags (cosine of audio vs text embedding), identity score.
"""
import sys, glob, json, subprocess, numpy as np, torch
from transformers import ClapModel, ClapProcessor
SR=48000
import os; MN=os.environ.get('CLAP','laion/larger_clap_general')
M=ClapModel.from_pretrained(MN).eval(); P=ClapProcessor.from_pretrained(MN)
TAGS={"guzheng":"guzheng Chinese zither plucked melody","erhu":"erhu Chinese two-string fiddle melody","dizi":"Chinese bamboo flute dizi",
 "koto":"Japanese koto plucks","pipa":"pipa lute plucking","piano":"warm piano chords","rhodes":"Rhodes electric piano","pads":"soft analog synth pads",
 "lofi":"lo-fi hip hop drums","taiko":"taiko drums","edm":"EDM supersaw synths four on the floor","orch":"orchestral strings","bells":"bells, celesta, glockenspiel",
 "anime":"anime pop game soundtrack","chinese":"traditional Chinese music","jazz":"jazz city pop","chiptune":"chiptune 8-bit",
 "OFF_rock":"distorted electric guitar rock","OFF_metal":"heavy metal","OFF_country":"country music banjo","OFF_vocal":"singing vocals with lyrics",
 "OFF_dubstep":"aggressive dubstep wobble bass","OFF_horror":"dark horror soundtrack","OFF_classical":"western classical symphony"}
def load(p):
    raw=subprocess.run(["ffmpeg","-v","error","-i",p,"-f","f32le","-ac","1","-ar",str(SR),"-"],check=True,capture_output=True).stdout
    return np.frombuffer(raw,dtype=np.float32)
@torch.no_grad()
def aemb(p):
    y=load(p); L=10*SR; chunks=[y[i:i+L] for i in range(0,max(1,len(y)-L//2),L)] or [y]
    chunks=[c for c in chunks if len(c)>3*SR] or [y]
    e=M.get_audio_features(**P(audios=chunks,sampling_rate=SR,return_tensors='pt'))
    e=getattr(e,'pooler_output',e)
    e=torch.nn.functional.normalize(e,dim=-1).mean(0); return torch.nn.functional.normalize(e,dim=0).numpy()
@torch.no_grad()
def temb():
    t=M.get_text_features(**P(text=list(TAGS.values()),return_tensors='pt',padding=True)); t=getattr(t,'pooler_output',t)
    return torch.nn.functional.normalize(t,dim=-1).numpy()
ref=sorted(glob.glob(sys.argv[1]+'/*.ogg')); cand=sys.argv[2:]
T=temb(); keys=list(TAGS)
R={p.split('/')[-1][:-4]:aemb(p) for p in ref}
names=list(R); E=np.stack([R[n] for n in names])
def tags(e):
    s=T@e; return {k:round(float(v),3) for k,v in zip(keys,s)}
def ident(tg):
    on=np.mean([tg[k] for k in ("guzheng","erhu","chinese","anime","pads")]); off=np.mean([tg[k] for k in keys if k.startswith("OFF_")]); return round(float(on-off),3)
out={"ref":{},"cand":{}}
loo=[]
for i,n in enumerate(names):
    others=np.delete(E,i,0); c=others.mean(0); c/=np.linalg.norm(c)
    sc=float(E[i]@c); nn=float((others@E[i]).max()); nnn=names[[j for j in range(len(names)) if j!=i][int((others@E[i]).argmax())]]
    tg=tags(E[i]); loo.append(sc)
    out["ref"][n]=dict(centroid_cos=round(sc,3),nn_cos=round(nn,3),nn=nnn,identity=ident(tg),tags=tg)
c=E.mean(0); c/=np.linalg.norm(c)
base=dict(loo_centroid_min=round(min(loo),3),loo_centroid_p10=round(float(np.percentile(loo,10)),3),loo_centroid_median=round(float(np.median(loo)),3),
          identity_min=min(v["identity"] for v in out["ref"].values()),identity_median=float(np.median([v["identity"] for v in out["ref"].values()])))
out["baseline"]=base
for p in cand:
    e=aemb(p); sims=E@e; tg=tags(e)
    out["cand"][p.split('/')[-1]]=dict(centroid_cos=round(float(e@c),3),nn_cos=round(float(sims.max()),3),nn=names[int(sims.argmax())],
        top3=[(names[j],round(float(sims[j]),3)) for j in np.argsort(-sims)[:3]],identity=ident(tg),tags=tg)
print(json.dumps(out,ensure_ascii=False,indent=1))
