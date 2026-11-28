#!/usr/bin/env python3
"""P46 blind JP voice test (GDD s8.4 gate R-06): 3 models x 3 voices x 10 lines = 90 samples.

  blind_test.py plan                      write design/voice/blind_test/plan.json (lines, voices, models, hashed names)
  blind_test.py requests OUT.json         Higgsfield generate_audio_batch request list (90 items, index = sample no.)
  blind_test.py ingest JOBS.json          jobs.json {index: url|path} -> download, normalize (P45 normalize.py), samples/<hash>.ogg
  blind_test.py page                      build offline index.html (data embedded) from plan.json
  blind_test.py score RESULTS.csv         per-model / per-voice share of "indistinguishable", gate decision (>=70%)
  blind_test.py selftest                  synthetic check of plan + score (marker BLIND_TEST SELFTEST)
Voices are stand-ins for the three flagship heroines named in R-06 (mc / yue / zlata); the listener only
hears hash names, the key is KEY.csv (open only after all results are collected).
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BT = ROOT / "design" / "voice" / "blind_test"
REG = ROOT / "game" / "core" / "voice" / "voice_registry.json"
SALT = "tw-p46-blind-2026"
THRESHOLD = 0.70
MIN_LISTENERS = 3

MODELS = [
    {"id": "seed_audio", "label": "Seed Audio 1.0", "credits": 0.20,
     "params": {"model": "seed_audio", "format": "wav", "sample_rate": 48000}},
    {"id": "elevenlabs_v4", "label": "Eleven v4", "credits": 0.23, "params": {"model": "elevenlabs_v4"}},
    {"id": "text2speech_v2", "label": "Text to Speech V2 (minimax)", "credits": 0.15,
     "params": {"model": "text2speech_v2", "variant": "minimax"}},
]
# voice -> heroine whose Beta-24 lines it reads. mc/yue use the casting in voice_cast.json; zlata=Helena (HANDOFF s3.2).
VOICES = [
    {"id": "luna", "name": "Luna", "heroine": "mc", "voice_id": "375a3398-e3b4-4f91-845d-42181e352899"},
    {"id": "naomi", "name": "Naomi", "heroine": "yue", "voice_id": "caeba733-3c17-43db-863e-69c7025512cd"},
    {"id": "helena", "name": "Helena", "heroine": "zlata", "voice_id": "3c2b83c0-2e0a-5ae8-998a-a5fe71b7eccd"},
]
# 10 typical lines: 7 lobby (long, emotional), 1 intro, 2 short calls
CATEGORIES = ["login_morning", "intro_summon", "idle_warm", "touch_head", "touch_spam",
              "gift_liked", "level_max_vow", "fail", "ult_cast", "ron"]


def sample_hash(key: str) -> str:
    return hashlib.sha1((SALT + key).encode()).hexdigest()[:10]


def build_plan() -> dict:
    if REG.exists():
        reg = json.loads(REG.read_text(encoding="utf-8"))
    else:  # P44 not merged into this branch yet: read it from its branch
        reg = json.loads(subprocess.check_output(["git", "-C", str(ROOT), "show", "claude/p44:game/core/voice/voice_registry.json"]))
    by_id = {l["id"]: l for l in reg["lines"]}
    samples = []
    for m in MODELS:
        for v in VOICES:
            for c in CATEGORIES:
                lid = f"{v['heroine']}_{c}_1"
                line = by_id[lid]
                key = f"{m['id']}|{v['id']}|{lid}"
                samples.append({"n": len(samples), "hash": sample_hash(key), "model": m["id"], "voice": v["id"],
                                "line_id": lid, "jp": line["jp"], "class": line["class"]})
    assert len({s["hash"] for s in samples}) == len(samples) == 90
    return {"schema": 1, "threshold": THRESHOLD, "min_listeners": MIN_LISTENERS, "models": MODELS, "voices": VOICES,
            "categories": CATEGORIES, "samples": samples}


def cmd_plan(_a) -> int:
    p = build_plan()
    BT.mkdir(parents=True, exist_ok=True)
    # plan.json holds the key; the page gets only hashes (see cmd_page)
    (BT / "plan.json").write_text(json.dumps(p, ensure_ascii=False, indent=1), encoding="utf-8")
    with open(BT / "KEY.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["hash", "model", "voice", "line_id", "jp"])
        for s in p["samples"]:
            w.writerow([s["hash"], s["model"], s["voice"], s["line_id"], s["jp"]])
    print(f"plan: {len(p['samples'])} samples, est. cost {sum(m['credits'] for m in MODELS) * 30:.2f} cr")
    return 0


def cmd_requests(a) -> int:
    p = json.loads((BT / "plan.json").read_text(encoding="utf-8"))
    vo = {v["id"]: v for v in p["voices"]}
    mo = {m["id"]: m for m in p["models"]}
    out = []
    for s in p["samples"]:
        prm = dict(mo[s["model"]]["params"])
        v = vo[s["voice"]]
        if s["model"] == "elevenlabs_v4":
            prm["prompt"] = s["jp"]
            prm["dialogue"] = [{"text": s["jp"], "voice_type": "preset", "voice_id": v["voice_id"]}]
        else:
            prm.update(prompt=s["jp"], voice_type="preset", voice_id=v["voice_id"])
        out.append({"index": s["n"], "params": prm})
    Path(a.out).write_text(json.dumps({"requests": out}, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {len(out)} requests")
    return 0


def _level_fix(wav: Path, lg, target: float = -14.0, tp: float = -1.0, tol: float = 0.4) -> dict:
    """Stage 2: normalize.py cannot lift peaky files to the target without breaking the true-peak ceiling (it only
    reports 'limited'). For a blind test every sample must sit at the same level (louder = 'better'), so such files
    get gain + ffmpeg alimiter. Measured with the P45 meter (lufs_gate); up to 4 correction rounds."""
    x, fs = lg.decode(str(wav))
    m = lg.measure_array(x, fs)
    for _ in range(4):
        lu, tpk = m["lufs"], m["true_peak"]
        if abs(lu - target) <= tol and tpk <= tp + 0.05:
            break
        gain = target - lu
        tmp = wav.with_suffix(".fix.wav")
        lim = 10 ** ((tp - 0.6) / 20)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-af",
                        f"volume={gain:.2f}dB,alimiter=limit={lim:.4f}:attack=2:release=60:level=disabled",
                        "-ar", "48000", str(tmp)], check=True)
        os.replace(tmp, wav)
        x, fs = lg.decode(str(wav))
        m = lg.measure_array(x, fs)
    return m


def cmd_ingest(a) -> int:
    import shutil
    import urllib.request
    p = json.loads((BT / "plan.json").read_text(encoding="utf-8"))
    jobs = json.loads(Path(a.jobs).read_text(encoding="utf-8"))
    norm = Path(a.normalize) if a.normalize else ROOT / "tools" / "audio" / "normalize.py"
    sys.path.insert(0, str(norm.parent))
    import lufs_gate as lg  # P45 meter (same dir as normalize.py)
    (BT / "samples").mkdir(exist_ok=True)
    rep = []
    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "raw"
        raw.mkdir()
        for s in p["samples"]:
            src = jobs.get(str(s["n"]))
            if not src:
                continue
            ext = Path(src.split("?")[0]).suffix or ".wav"
            dst = raw / f"{s['hash']}.src{ext}"
            if src.startswith("http"):
                urllib.request.urlretrieve(src, dst)
            else:
                shutil.copy(src, dst)
            # mono 48 kHz wav: uniform input for the normalizer (sources differ: stereo wav / mono mp3 32-44 kHz)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(dst), "-ac", "1", "-ar", "48000", str(raw / f"{s['hash']}.wav")], check=True)
            dst.unlink()
        outd = Path(td) / "norm"
        r = subprocess.run([sys.executable, str(norm), str(raw), "--kind", "voice", "--out", str(outd), "--trim-lead", "--keep-ms", "10"],
                           capture_output=True, text=True)
        if r.returncode not in (0, 1):
            sys.stderr.write(r.stdout[-1500:] + r.stderr[-1500:])
            return 2
        for w in sorted(outd.glob("*.wav")):
            _level_fix(w, lg)
            ogg = BT / "samples" / (w.stem + ".ogg")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(w), "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
            x, fs = lg.decode(str(ogg))  # report from the final ogg = what the listener hears
            f = lg.measure_array(x, fs)
            rep.append({"hash": w.stem, "lufs": round(f["lufs"], 2), "true_peak_db": round(f["true_peak"], 2),
                        "lead_ms": round(f["lead_ms"], 1), "dur_s": round(f["dur"], 2)})
    with open(BT / "samples_report.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["hash", "lufs", "true_peak_db", "lead_ms", "dur_s"])
        w.writeheader()
        w.writerows(sorted(rep, key=lambda r: r["hash"]))
    lu = [r["lufs"] for r in rep]
    print(f"ingested {len(rep)} samples; LUFS min/max {min(lu):.2f}/{max(lu):.2f}, max TP {max(r['true_peak_db'] for r in rep):.2f}, "
          f"max lead {max(r['lead_ms'] for r in rep):.1f} ms")
    return 0


PAGE = r"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Слепой тест JP-голосов</title>
<style>
:root{--bg:#faf7f2;--fg:#222;--mut:#777;--card:#fff;--ac:#b8452f;--ok:#2d7d46;--bd:#ddd}
@media (prefers-color-scheme:dark){:root{--bg:#1b1a19;--fg:#eee;--mut:#999;--card:#262524;--ac:#e0745c;--ok:#5fc27d;--bd:#3a3836}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
main{max-width:640px;margin:0 auto;padding:16px}
.card{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:16px;margin:12px 0}
button{font:inherit;padding:10px 16px;border-radius:8px;border:1px solid var(--bd);background:var(--card);color:var(--fg);cursor:pointer;min-height:44px}
button.on{background:var(--ac);color:#fff;border-color:var(--ac)}
button.pri{background:var(--ac);color:#fff;border-color:var(--ac)}
.row{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0}
.mut{color:var(--mut);font-size:14px}.jp{font-size:20px}
progress{width:100%}input[type=text]{font:inherit;padding:8px;border-radius:8px;border:1px solid var(--bd);background:var(--card);color:var(--fg);width:100%;box-sizing:border-box}
</style></head><body><main>
<h1>Слепой тест JP-голосов</h1>
<div id="start" class="card">
<p>Слушайте образцы по одному. Для каждого: оценка 1-5 (естественность, 5 = как у студийной сэйю) и ответ, отличаете ли вы его от студийной записи. Названия скрыты, порядок случайный для каждого слушателя. Работает офлайн, ничего не отправляется: итог сохраняется файлом CSV.</p>
<p><label>Ваше имя или код <input type="text" id="who" placeholder="например L1"></label></p>
<p><label><input type="checkbox" id="native"> Я носитель японского языка</label></p>
<p class="mut">Наушники, тихая комната, громкость не менять между образцами. Около 25 минут. Можно закрыть страницу: ответы сохраняются в браузере.</p>
<button class="pri" id="go">Начать</button>
</div>
<div id="test" class="card" hidden>
<progress id="prog" max="90" value="0"></progress>
<div class="mut" id="count"></div>
<p class="jp" id="jp"></p>
<audio id="aud" controls preload="auto" style="width:100%"></audio>
<p>Естественность (1 = синтетика, 5 = студия):</p>
<div class="row" id="stars"></div>
<p>Вы отличаете этот образец от студийной записи?</p>
<div class="row"><button id="b_ind">Не отличаю</button><button id="b_dis">Отличаю</button></div>
<div class="row"><button id="prev">Назад</button><button class="pri" id="next">Дальше</button></div>
</div>
<div id="done" class="card" hidden>
<h2>Готово</h2>
<p>Скачайте файл и передайте его организатору теста.</p>
<button class="pri" id="dl">Скачать результаты (CSV)</button>
<p class="mut" id="msg"></p>
</div>
<script>
const SAMPLES=__SAMPLES__;
const KEYSTORE='tw_p46_blind_v1';
let st={who:'',native:false,order:[],i:0,ans:{}};
try{const s=localStorage.getItem(KEYSTORE);if(s)st=JSON.parse(s)}catch(e){}
const $=id=>document.getElementById(id);
function save(){try{localStorage.setItem(KEYSTORE,JSON.stringify(st))}catch(e){}}
function rng(seed){let h=2166136261;for(const c of seed){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return()=>{h^=h<<13;h^=h>>>17;h^=h<<5;return((h>>>0)%100000)/100000}}
function shuffle(a,seed){const r=rng(seed+'|'+a.length),b=a.slice();for(let i=b.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[b[i],b[j]]=[b[j],b[i]]}return b}
function show(){
 if(st.i>=st.order.length){$('test').hidden=true;$('done').hidden=false;return}
 $('start').hidden=true;$('test').hidden=false;$('done').hidden=true;
 const h=st.order[st.i],s=SAMPLES.find(x=>x.hash===h),a=st.ans[h]||{};
 $('prog').value=st.i;$('count').textContent=(st.i+1)+' / '+st.order.length;
 $('jp').textContent=s.jp;$('aud').src='samples/'+h+'.ogg';
 $('stars').innerHTML='';
 for(let k=1;k<=5;k++){const b=document.createElement('button');b.textContent=k;if(a.score===k)b.className='on';b.onclick=()=>{st.ans[h]=Object.assign(st.ans[h]||{},{score:k});save();show()};$('stars').appendChild(b)}
 $('b_ind').className=a.ind===1?'on':'';$('b_dis').className=a.ind===0?'on':'';
}
function setInd(v){const h=st.order[st.i];st.ans[h]=Object.assign(st.ans[h]||{},{ind:v});save();show()}
$('b_ind').onclick=()=>setInd(1);$('b_dis').onclick=()=>setInd(0);
$('prev').onclick=()=>{if(st.i>0){st.i--;save();show()}};
$('next').onclick=()=>{const a=st.ans[st.order[st.i]]||{};if(!a.score||a.ind===undefined){alert('Нужны оценка 1-5 и ответ «отличаю / не отличаю».');return}st.i++;save();show()};
$('go').onclick=()=>{const w=$('who').value.trim();if(!w){alert('Введите имя или код');return}
 st={who:w,native:$('native').checked,order:shuffle(SAMPLES.map(x=>x.hash),w),i:0,ans:{}};save();show()};
$('dl').onclick=()=>{
 const rows=['listener,native,hash,score,indistinguishable'];
 for(const h of st.order){const a=st.ans[h]||{};rows.push([st.who.replace(/[,\n]/g,' '),st.native?1:0,h,a.score??'',a.ind??''].join(','))}
 const b=new Blob([rows.join('\n')+'\n'],{type:'text/csv'}),u=URL.createObjectURL(b),l=document.createElement('a');
 l.href=u;l.download='results_'+st.who.replace(/\W+/g,'_')+'.csv';l.click();$('msg').textContent='Сохранено: '+l.download};
if(st.order.length){$('who').value=st.who;$('native').checked=st.native;show()}
</script></main></body></html>
"""


def cmd_page(_a) -> int:
    p = json.loads((BT / "plan.json").read_text(encoding="utf-8"))
    pub = [{"hash": s["hash"], "jp": s["jp"]} for s in p["samples"]]
    (BT / "index.html").write_text(PAGE.replace("__SAMPLES__", json.dumps(pub, ensure_ascii=False)), encoding="utf-8")
    print(f"page: {len(pub)} samples embedded")
    return 0


def score(key_rows: list[dict], res_rows: list[dict]) -> dict:
    """key_rows: hash,model,voice; res_rows: listener,native,hash,score,indistinguishable (listener csv rows, concatenated)."""
    k = {r["hash"]: r for r in key_rows}
    listeners = {}
    for r in res_rows:
        if r["hash"] not in k or r.get("indistinguishable", "") == "":
            continue
        listeners.setdefault(r["listener"], str(r.get("native", "0")) == "1")
    agg = {"model": {}, "voice": {}, "cell": {}}
    for r in res_rows:
        h = r["hash"]
        if h not in k or r.get("indistinguishable", "") == "":
            continue
        ind = int(r["indistinguishable"])
        sc = int(r["score"]) if r.get("score", "") != "" else None
        for dim, key in (("model", k[h]["model"]), ("voice", k[h]["voice"]), ("cell", k[h]["model"] + "/" + k[h]["voice"])):
            a = agg[dim].setdefault(key, {"n": 0, "ind": 0, "score_sum": 0, "score_n": 0})
            a["n"] += 1
            a["ind"] += ind
            if sc:
                a["score_sum"] += sc
                a["score_n"] += 1
    out = {"listeners": len(listeners), "native_listeners": sum(1 for v in listeners.values() if v), "dims": {}}
    for dim, d in agg.items():
        out["dims"][dim] = {key: {"n": a["n"], "indistinguishable": round(a["ind"] / a["n"], 4),
                                  "mean_score": round(a["score_sum"] / a["score_n"], 2) if a["score_n"] else None}
                            for key, a in sorted(d.items())}
    valid = out["listeners"] >= MIN_LISTENERS and out["native_listeners"] >= 1
    out["protocol_ok"] = valid
    # gate: a model passes if its share >= 70% overall AND for each voice (R-06 names three flagship voices)
    models = {}
    for m, a in out["dims"]["model"].items():
        cells = {c.split("/")[1]: v for c, v in out["dims"]["cell"].items() if c.startswith(m + "/")}
        models[m] = {"overall": a["indistinguishable"],
                     "pass": a["indistinguishable"] >= THRESHOLD and all(v["indistinguishable"] >= THRESHOLD for v in cells.values()),
                     "voices_failing": [v for v, c in cells.items() if c["indistinguishable"] < THRESHOLD]}
    out["models"] = models
    # per voice (= per flagship heroine): is there any model whose share for that voice reaches the threshold?
    voice_best = {}
    for c, v in out["dims"]["cell"].items():
        m, vo = c.split("/")
        if vo not in voice_best or v["indistinguishable"] > voice_best[vo]["share"]:
            voice_best[vo] = {"model": m, "share": v["indistinguishable"]}
    for vo, b in voice_best.items():
        b["ai_ok"] = b["share"] >= THRESHOLD
    out["voice_best"] = voice_best
    # native-listener-only share per model (the protocol requires >= 1 native; report it separately)
    nat = {}
    for r in res_rows:
        h = r["hash"]
        if h in k and r.get("indistinguishable", "") != "" and str(r.get("native", "0")) == "1":
            a = nat.setdefault(k[h]["model"], [0, 0])
            a[0] += 1
            a[1] += int(r["indistinguishable"])
    out["native_only"] = {m: {"n": a[0], "indistinguishable": round(a[1] / a[0], 4)} for m, a in sorted(nat.items())}
    best = [m for m, v in models.items() if v["pass"]]
    if not valid:
        out["decision"] = "INVALID: need >= %d listeners incl. >= 1 native JP (have %d / %d native)" % (MIN_LISTENERS, out["listeners"], out["native_listeners"])
    elif best:
        out["decision"] = "GATE PASSED (>=70%%): AI voice acceptable with " + ", ".join(best)
    else:
        need = [vo for vo, b in voice_best.items() if not b["ai_ok"]]
        out["decision"] = "GATE NOT PASSED: live actress for MT, Yue, Zlata (R-06)" + (
            "; voices with no passing model: " + ", ".join(need) if need else "")
    return out


def cmd_score(a) -> int:
    key = list(csv.DictReader(open(BT / "KEY.csv", encoding="utf-8")))
    rows = []
    for f in a.results:
        p = Path(f)
        for q in ([p] if p.is_file() else sorted(p.glob("results_*.csv"))):
            rows += list(csv.DictReader(open(q, encoding="utf-8")))
    r = score(key, rows)
    print(json.dumps(r, ensure_ascii=False, indent=1))
    print("DECISION:", r["decision"])
    return 0


def cmd_selftest(_a) -> int:
    p = build_plan()
    fails = []
    chk = lambda ok, msg: None if ok else fails.append(msg)
    chk(len(p["samples"]) == 90, "90 samples")
    chk(len({s["hash"] for s in p["samples"]}) == 90, "unique hashes")
    chk(all(s["jp"] for s in p["samples"]), "texts present")
    chk(abs(sum(m["credits"] for m in MODELS) * 30 - 17.4) < 1e-6, "budget 17.4 cr")
    key = [{"hash": s["hash"], "model": s["model"], "voice": s["voice"]} for s in p["samples"]]
    # listener set where seed passes everywhere, eleven fails on helena, t2s fails everywhere
    res = []
    for who, nat in (("a", 1), ("b", 0), ("c", 0)):
        for s in p["samples"]:
            ind = 1 if s["model"] == "seed_audio" or (s["model"] == "elevenlabs_v4" and s["voice"] != "helena") else 0
            res.append({"listener": who, "native": nat, "hash": s["hash"], "score": 4, "indistinguishable": ind})
    r = score(key, res)
    chk(r["protocol_ok"] and r["listeners"] == 3 and r["native_listeners"] == 1, "protocol_ok")
    chk(r["models"]["seed_audio"]["pass"], "seed passes")
    chk(not r["models"]["elevenlabs_v4"]["pass"] and r["models"]["elevenlabs_v4"]["voices_failing"] == ["helena"], "eleven fails helena")
    chk(not r["models"]["text2speech_v2"]["pass"], "t2s fails")
    chk(score(key, res[:90])["protocol_ok"] is False, "1 listener invalid")
    chk(r["voice_best"]["luna"]["ai_ok"] and r["voice_best"]["helena"]["model"] == "seed_audio", "voice_best")
    chk(r["native_only"]["seed_audio"]["indistinguishable"] == 1.0, "native_only")
    # nobody passes -> live actress decision
    res0 = [dict(x, indistinguishable=0) for x in res]
    chk(score(key, res0)["decision"].startswith("GATE NOT PASSED"), "fail decision")
    print("BLIND_TEST SELFTEST %s (%d failures)" % ("OK" if not fails else "FAIL", len(fails)))
    for f in fails:
        print("  FAIL", f)
    return 1 if fails else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("plan").set_defaults(f=cmd_plan)
    q = sp.add_parser("requests"); q.add_argument("out"); q.set_defaults(f=cmd_requests)
    q = sp.add_parser("ingest"); q.add_argument("jobs"); q.add_argument("--normalize"); q.set_defaults(f=cmd_ingest)
    sp.add_parser("page").set_defaults(f=cmd_page)
    q = sp.add_parser("score"); q.add_argument("results", nargs="+"); q.set_defaults(f=cmd_score)
    sp.add_parser("selftest").set_defaults(f=cmd_selftest)
    a = ap.parse_args()
    return a.f(a)


if __name__ == "__main__":
    sys.exit(main())
