import json,csv,os
from PIL import Image
S='/tmp/claude-0/-home-user-tile-waifu/fdb5ddff-45d9-5a8d-88b3-d55165b777ed/scratchpad'
HF=S+'/hf-mining'; R='/home/user/wt/p04'
cat={r['id']:r for r in json.load(open(HF+'/catalog_final.json'))}
by8={k[:8]:k for k in cat}
crow={r['id']:r for r in csv.DictReader(open(HF+'/catalog.tsv'),delimiter='\t')}
kn={}
for l in open(S+'/p04/notes.jsonl'):
    d=json.loads(l); kn[d['id8']]=d   # later lines override
bn={}
for l in open(S+'/p04/bgnotes.jsonl'):
    d=json.loads(l); bn[d['id8']]=d
def rating(tags,note):
    t=' '.join(tags)
    if any(x in t for x in ('17plus','bunny','swimwear','bikini','leotard','suggestive','wet_')): return '17plus_only'
    return 'sfw_ok'
FIT={'teahouse':'57a2bc78 16f5c2ae 6c86232f f1b9cedd 7b9afb59 2456bfde f10aeb42 5639014a 2358f677 7a79d59a 176e0150 e201c7de f37ebb22 8e0699bc 1deb8db4 ce44ea7f 2b04512f 24b5ac07 686b2217'.split(),
 'salon':'c0cbba5b 05fd9a16 bf907bf1 57a2bc78 b7ee9bcf 096a5b3d 63587341 3060bffc 910c7d6f 5455fbf7 0de6b359 d9d08c1f b0726543 cb47ebbc f8a17240 f1972099 3ca873b6 f8b752b4 32a3e162 d9aab546 cc4b1e72 84ce8bae'.split()}
def fit(i8): return [k for k,v in FIT.items() if i8 in v]
def entry(i8,d,kind):
    k=by8[i8]; r=cat[k]; cr=crow[k]
    p=f"files/{cr['category']}/{k}.png"
    w,h=r['w'],r['h_']
    e={'fit':fit(i8),'id':k,'id8':i8,'src':p,'width':w,'height':h,'category':cr['category'],'heroine':cr['heroine'],'hf_status':cr['status'],
       'model':r['model'],'date':r['date'],'prompt_head':r['prompt'][:160].replace('\n',' '),
       'verdict':d['verdict'],'score':d['score'],'candidate':d.get('candidate',d['verdict']=='pass'),
       'defect_tags':[t for t in d['tags']],'rating_class':rating(d['tags'],d['note']),'note':d['note']}
    if kind=='key': e['crops_checked']=d.get('crops','')
    else: e['kind']=d.get('kind'); e['suggested_use']=d.get('use','')
    return e
keyorder=[ 'd29d446f','31ee1f9e','6a73cf62','5455fbf7','bd6a1c81','910c7d6f','6ec151d8','27a129fc','3bf37740','2b04512f','27c27ba3','946faf74','a4f9983f','39da4bd6','89d77fc5','ce44ea7f','b2de89bb','b868b3ae','8e0699bc','1deb8db4',
 '4fa461de','28139660','12093d91','3060bffc','24b5ac07','60fc5295','16bb0b24','476fd351','808c5558','686b2217']
key=[]
for i in keyorder:
    d=kn[i]; d['candidate']=(d['verdict']=='pass')
    key.append(entry(i,d,'key'))
bg=[entry(i,d,'bg') for i,d in bn.items()]
bg.sort(key=lambda e:(-e['candidate'],-e['score'],e['id8']))
meta={'package':'P04','date':'2026-11-28','method':'full-size visual audit (images opened at up to 1600px long edge, i.e. native for <=1360x2048; targeted hand/foot/leg crops at native resolution where noted); not automated','source':'hf-mining catalog (workspace scan 2026-11-27)','rules':'pass=no visible anatomy/text/artifact defect found; cond=usable with fix or only in 17+ build; fail=reject; candidate=pass (key arts) / pass-or-cond suitable as ref/bg (backgrounds); rating_class 17plus_only=violates SFW/Yandex red lines'}
json.dump({'meta':meta,'items':key},open(S+'/design/art_batches/triage_top30.json','w'),ensure_ascii=False,indent=1)
json.dump({'meta':meta,'items':bg},open(S+'/design/art_batches/triage_bg100.json','w'),ensure_ascii=False,indent=1)
for n in ('triage_top30.json','triage_bg100.json'):
    open(f'{R}/docs/art_triage/{n}','w').write(open(S+'/design/art_batches/'+n).read())
import collections
print('key',collections.Counter(e['verdict'] for e in key),sum(e['candidate'] for e in key),collections.Counter(e['rating_class'] for e in key if e['candidate']))
print('bg',collections.Counter(e['verdict'] for e in bg),sum(e['candidate'] for e in bg),collections.Counter(e['rating_class'] for e in bg if e['candidate']))
# previews for candidates
out=R+'/assets/incoming/p04_triage'; rows=[]
for e in key+bg:
    if not e['candidate']: continue
    im=Image.open(f"{HF}/{e['src']}").convert('RGB'); s=640/max(im.size)
    im=im.resize((int(im.width*s),int(im.height*s)),Image.LANCZOS)
    fn=f"{e['id8']}.jpg"; im.save(f'{out}/{fn}',quality=74)
    rows.append((e['id'],fn,e['category'],e['heroine'],e['width'],e['height'],e['rating_class'],'generated'))
with open(out+'/MANIFEST.tsv','w') as f:
    f.write('hf_id\tpreview\tcategory\theroine\torig_w\torig_h\trating_class\tstatus\n')
    for r in rows: f.write('\t'.join(map(str,r))+'\n')
print(len(rows),'previews')
