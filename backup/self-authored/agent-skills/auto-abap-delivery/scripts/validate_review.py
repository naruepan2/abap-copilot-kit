#!/usr/bin/env python3
import argparse,json,sys
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('review_file'); p.add_argument('--current-spec'); p.add_argument('--source-hash',action='append',default=[]); a=p.parse_args(); errors=[]
try: d=json.loads(Path(a.review_file).read_text())
except Exception as e: print(json.dumps({'valid':False,'errors':[str(e)]},indent=2)); sys.exit(1)
for k in ['review_id','revision','state','snapshot','actions']:
    if k not in d: errors.append(f'missing {k}')
s=d.get('snapshot',{})
if a.current_spec and s.get('spec_revision')!=a.current_spec: errors.append('stale spec revision')
current={x.split('=',1)[0]:x.split('=',1)[1] for x in a.source_hash if '=' in x}
for obj,h in current.items():
    expected=s.get('source_hashes',{}).get(obj)
    if expected and expected!=h: errors.append(f'stale source hash for {obj}')
print(json.dumps({'valid':not errors,'errors':errors},indent=2)); sys.exit(1 if errors else 0)
