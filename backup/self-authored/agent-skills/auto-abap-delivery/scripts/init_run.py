#!/usr/bin/env python3
import argparse, json
from pathlib import Path
from datetime import datetime, timezone
p=argparse.ArgumentParser()
p.add_argument('--base',required=True); p.add_argument('--run-id',required=True); p.add_argument('--task-id',required=True)
p.add_argument('--system',required=True); p.add_argument('--client',required=True); p.add_argument('--spec-revision',required=True)
p.add_argument('--execution-mode',choices=['unattended','attended'],default='attended')
p.add_argument('--review-level',choices=['not_applicable','standard','guided','controlled','strict','custom'],default='standard')
p.add_argument('--resolved-from',default='unqualified_scope_default')
p.add_argument('--qualification-state',choices=['unqualified','qualified','critical'],default='unqualified')
a=p.parse_args()
if a.execution_mode=='unattended' and a.review_level!='not_applicable': p.error('unattended requires review-level not_applicable')
if a.execution_mode=='attended' and a.review_level=='not_applicable': p.error('attended requires standard/guided/controlled/strict/custom')
root=Path(a.base)/a.run_id
for d in ['decisions','reviews','recovery','checkpoints','artifacts','uat','evidence']: (root/d).mkdir(parents=True,exist_ok=True)
now=datetime.now(timezone.utc).isoformat()
state={'run_id':a.run_id,'task_id':a.task_id,'state':'DRAFT','spec_revision':a.spec_revision,'target':{'system':a.system,'client':a.client},'interaction_policy':{'execution_mode':a.execution_mode,'review_level':a.review_level,'resolved_from':a.resolved_from,'qualification_state':a.qualification_state,'version':2},'checkpoint_sequence':0,'fencing_token':0,'created_at':now}
(root/'run-state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
for f in ['transition-log.jsonl','command-log.jsonl','review-log.jsonl','decision-log.jsonl']: (root/f).write_text('',encoding='utf-8')
print(root)
