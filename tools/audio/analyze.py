#!/usr/bin/env python3
"""Ear-proxy metrics for Tile Waifu music. usage: analyze.py out.json file1 [file2 ...]"""
import json, sys, subprocess
import numpy as np, librosa, pyloudnorm as pyln
SR = 22050
MAJ = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88])
MIN = np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
NAMES = ['C','C#','D','Eb','E','F','F#','G','Ab','A','Bb','B']

def load(path, sr):
    raw = subprocess.run(["ffmpeg","-v","error","-i",path,"-f","f32le","-ac","2","-ar",str(sr),"-"],check=True,capture_output=True).stdout
    return np.frombuffer(raw,dtype=np.float32).reshape(-1,2).astype(np.float64)

def key_est(chroma_mean):
    best=[]
    for k in range(12):
        for mode,prof in (('maj',MAJ),('min',MIN)):
            r=np.corrcoef(np.roll(prof,k),chroma_mean)[0,1]; best.append((r,k,mode))
    best.sort(reverse=True)
    r,k,m=best[0]
    return f"{NAMES[k]} {'major' if m=='maj' else 'minor'}", float(r), [f"{NAMES[b[1]]} {b[2]} {b[0]:.2f}" for b in best[:3]]

def penta(chroma_mean):
    # best fraction of chroma energy in any major-pentatonic pitch set (covers relative minor)
    s=chroma_mean/chroma_mean.sum(); pat=np.array([1,0,1,0,1,0,0,1,0,1,0,0])
    vals=[float((np.roll(pat,k)*s).sum()) for k in range(12)]
    k=int(np.argmax(vals)); return max(vals), NAMES[k]

def analyze(path):
    st = load(path, 44100)
    meter = pyln.Meter(44100); lufs = meter.integrated_loudness(st)
    peak = 20*np.log10(np.abs(st).max()+1e-12)
    up = librosa.resample(st.mean(1), orig_sr=44100, target_sr=176400) if len(st)<44100*20 else None
    tp = 20*np.log10(np.abs(up).max()+1e-12) if up is not None else None
    mid=(st[:,0]+st[:,1])/2; side=(st[:,0]-st[:,1])/2
    width = float(np.sqrt((side**2).mean())/(np.sqrt((mid**2).mean())+1e-12))
    y = librosa.resample(st.mean(1), orig_sr=44100, target_sr=SR)
    dur = len(y)/SR
    # short-term loudness range proxy (3s windows)
    win=int(3*44100); hop=int(1*44100); sl=[]
    for i in range(0, len(st)-win, hop):
        try:
            v=meter.integrated_loudness(st[i:i+win])
            if np.isfinite(v): sl.append(v)
        except Exception: pass
    lra = float(np.percentile(sl,95)-np.percentile(sl,10)) if len(sl)>3 else None
    oenv = librosa.onset.onset_strength(y=y, sr=SR)
    tempo, beats = librosa.beat.beat_track(onset_envelope=oenv, sr=SR)
    tempo=float(np.atleast_1d(tempo)[0])
    ac_t = librosa.feature.tempo(onset_envelope=oenv, sr=SR, aggregate=None)
    ons = librosa.onset.onset_detect(onset_envelope=oenv, sr=SR)
    H = librosa.effects.harmonic(y)
    chroma = librosa.feature.chroma_cqt(y=H, sr=SR)
    cm = chroma.mean(1)
    key, kr, top3 = key_est(cm)
    pf, proot = penta(cm)
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=512))
    f = librosa.fft_frequencies(sr=SR, n_fft=2048)
    P = (S**2).sum(1)
    tot=P.sum()
    bands={'sub<60':(0,60),'bass60-250':(60,250),'lowmid250-2k':(250,2000),'presence2-6k':(2000,6000),'air>6k':(6000,11025)}
    be={k:float(10*np.log10(P[(f>=a)&(f<b)].sum()/tot+1e-12)) for k,(a,b) in bands.items()}
    cent=float(librosa.feature.spectral_centroid(S=S,sr=SR).mean())
    roll=float(librosa.feature.spectral_rolloff(S=S,sr=SR,roll_percent=0.85).mean())
    flat=float(librosa.feature.spectral_flatness(S=S).mean())
    contrast=librosa.feature.spectral_contrast(S=S,sr=SR).mean(1)
    mfcc=librosa.feature.mfcc(y=y,sr=SR,n_mfcc=20)
    Hp=float(np.sqrt((H**2).mean())/(np.sqrt((y**2).mean())+1e-12))
    rms=librosa.feature.rms(S=S)[0]; crest=float(20*np.log10(np.abs(y).max()/(np.sqrt((y**2).mean())+1e-12)))
    emb = np.concatenate([mfcc.mean(1), mfcc.std(1), cm/cm.sum(), contrast, [np.log(cent), np.log(roll), flat*10, Hp, width]])
    return dict(file=path.split('/')[-1], dur=round(dur,2), lufs=round(lufs,2), peak_dbfs=round(peak,2), lra_proxy=None if lra is None else round(lra,1),
        bpm_beattrack=round(tempo,1), bpm_median=round(float(np.median(ac_t)),1), onsets_per_s=round(len(ons)/dur,2),
        key=key, key_r=round(kr,2), key_top3=top3, penta_frac=round(pf,3), penta_root=proot,
        centroid_hz=round(cent), rolloff85_hz=round(roll), flatness=round(flat,4), harmonic_ratio=round(Hp,2),
        stereo_side_mid=round(width,2), crest_db=round(crest,1), bands_db=be, emb=emb.tolist())

out = sys.argv[1]; res=[analyze(p) for p in sys.argv[2:]]
json.dump(res, open(out,'w'), ensure_ascii=False, indent=1)
for r in res:
    print(f"{r['file']:20s} {r['dur']:6.1f}s LUFS {r['lufs']:6.1f} pk {r['peak_dbfs']:5.1f} LRA {r['lra_proxy']} BPM {r['bpm_beattrack']:6.1f}/{r['bpm_median']:6.1f} ons {r['onsets_per_s']:4.1f} key {r['key']:9s}({r['key_r']}) penta {r['penta_frac']:.2f}@{r['penta_root']} cent {r['centroid_hz']} flat {r['flatness']} harm {r['harmonic_ratio']} wid {r['stereo_side_mid']} crest {r['crest_db']} " + ' '.join(f"{k.split('<')[0].split('>')[0][:4]}{v:.0f}" for k,v in r['bands_db'].items()))
