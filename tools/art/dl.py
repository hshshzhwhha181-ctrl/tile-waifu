import sys,os,urllib.request,csv
A=os.path.dirname(os.path.abspath(__file__))
jobs={r[1]:r[0] for r in csv.reader(open(A+'/jobs.tsv'),delimiter='\t') if len(r)>1}
for url in sys.stdin.read().split():
    jid=url.rsplit('_',1)[1].split('.')[0]
    name=jobs.get(jid,jid)
    out=f'{A}/raw/{name}.png'
    urllib.request.urlretrieve(url,out); print(name, os.path.getsize(out))
