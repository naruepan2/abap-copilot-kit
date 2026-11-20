#!/usr/bin/env python3
import argparse,json,sys
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('run_dir'); a=p.parse_args(); r=Path(a.run_dir); errors=[]
required=['run-state.json','transition-log.jsonl','command-log.jsonl','review-log.jsonl','decision-log.jsonl']
for f in required:
    if not (r/f).exists(): errors.append(f'missing {f}')
try: s=json.loads((r/'run-state.json').read_text())
except Exception as e: errors.append(f'invalid run-state.json: {e}'); s={}
for k in ['run_id','task_id','state','spec_revision','target','interaction_policy','fencing_token']:
    if k not in s: errors.append(f'missing state field {k}')
t=s.get('target',{}); ip=s.get('interaction_policy',{})
if not {'system','client'} <= set(t): errors.append('target requires system and client')
mode=ip.get('execution_mode'); level=ip.get('review_level')
if mode not in ['unattended','attended']: errors.append('invalid execution_mode')
if mode=='unattended' and level!='not_applicable': errors.append('unattended requires review_level not_applicable')
if mode=='attended' and level not in ['standard','guided','controlled','strict','custom']: errors.append('invalid attended review_level')
print(json.dumps({'valid':not errors,'errors':errors},indent=2)); sys.exit(1 if errors else 0)
