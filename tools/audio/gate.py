#!/usr/bin/env python3
"""Tile Waifu music style gate (AUDIO_BIBLE §9). Runs analyze.py + style_check.py and applies thresholds.
usage: gate.py REF_DIR kind:bpm:file [kind:bpm:file ...]    kind = loop | ambient | motif | sting (ambient = loop rules, BPM only warns: free-time/hovering tracks like summon) ; bpm = prompt BPM or 0
example: gate.py ref loop:100:music_tests/koikoi_a.ogg sting:0:music_tests/sting_x.ogg
"""
import sys, json, subprocess, os, tempfile
HERE=os.path.dirname(os.path.abspath(__file__))
TH=dict(clap_centroid_loop=0.70, clap_nn_loop=0.76, clap_centroid_sting=0.55, identity=0.05,
        bpm_tol=0.04, harm=(0.70,0.97), width_max=0.85, centroid=(750,3100), penta_min=0.45, lufs=(-16.5,-15.5), peak_max=-0.5)
ref=sys.argv[1]; items=[a.split(':',2) for a in sys.argv[2:]]
files=[f for _,_,f in items]
tmp=tempfile.mktemp(suffix='.json')
subprocess.run([sys.executable,'-I',os.path.join(HERE,'analyze.py'),tmp]+files,check=True,capture_output=True)
A={r['file']:r for r in json.load(open(tmp))}
C=json.loads(subprocess.run([sys.executable,'-I',os.path.join(HERE,'style_check.py'),ref]+files,check=True,capture_output=True,text=True).stdout)['cand']
out={}
for kind,bpm,f in items:
    n=os.path.basename(f); a=A[n]; c=C[n]; bpm=float(bpm); fails=[]
    if kind=='sting':
        if c['centroid_cos']<TH['clap_centroid_sting']: fails.append(f"clap_centroid {c['centroid_cos']}<{TH['clap_centroid_sting']}")
    else:
        if c['centroid_cos']<TH['clap_centroid_loop']: fails.append(f"clap_centroid {c['centroid_cos']}<{TH['clap_centroid_loop']}")
        if c['nn_cos']<TH['clap_nn_loop']: fails.append(f"clap_nn {c['nn_cos']}<{TH['clap_nn_loop']}")
        top3=[k for k,_ in sorted(c['tags'].items(),key=lambda x:-x[1])[:3]]
        if any(k.startswith('OFF_') for k in top3): fails.append(f"off-style tag in top3 {top3}")
        lo,hi=TH['harm']
        if not lo<=a['harmonic_ratio']<=hi: fails.append(f"harmonic_ratio {a['harmonic_ratio']} (no beat or no melody)")
        if a['stereo_side_mid']>TH['width_max']: fails.append(f"stereo width {a['stereo_side_mid']}")
        lo,hi=TH['centroid']
        if not lo<=a['centroid_hz']<=hi: fails.append(f"spectral centroid {a['centroid_hz']} Hz")
    if c['identity']<TH['identity']: fails.append(f"identity {c['identity']}<{TH['identity']}")
    if a['penta_frac']<TH['penta_min']: fails.append(f"pentatonic {a['penta_frac']}")
    if bpm>0:
        m=a['bpm_beattrack']; ok=any(abs(m*k-bpm)/bpm<=TH['bpm_tol'] for k in (1,2,0.5,1.5,2/3))
    else: ok=True
    warn=[]
    if bpm>0 and not ok: (warn if kind=='ambient' else fails).append(f"bpm {m} vs prompt {bpm}")
    lo,hi=TH['lufs']
    if not lo<=a['lufs']<=hi: warn.append(f"LUFS {a['lufs']} (run v10_loop.py)")
    if a['peak_dbfs']>TH['peak_max']: warn.append(f"peak {a['peak_dbfs']}")
    out[n]=dict(kind=kind,PASS=not fails,fails=fails,warn=warn,clap_centroid=c['centroid_cos'],clap_nn=c['nn_cos'],nearest=c['nn'],
                identity=c['identity'],bpm=a['bpm_beattrack'],key=a['key'],penta=a['penta_frac'],centroid_hz=a['centroid_hz'],harm=a['harmonic_ratio'],width=a['stereo_side_mid'],lufs=a['lufs'])
    print(f"{'PASS' if not fails else 'FAIL'} {n:24s} clap {c['centroid_cos']:.2f}/{c['nn_cos']:.2f}({c['nn']}) id {c['identity']:.3f} bpm {a['bpm_beattrack']} key {a['key']} {'; '.join(fails+warn)}")
json.dump(out,open(os.environ.get('GATE_OUT','gate_result.json'),'w'),ensure_ascii=False,indent=1)
