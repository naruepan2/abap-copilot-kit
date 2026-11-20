#!/usr/bin/env python3
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('metrics'); p.add_argument('--min-runs',type=int,default=3); p.add_argument('--min-uat-first-pass',type=float,default=.80); a=p.parse_args(); d=json.loads(Path(a.metrics).read_text())
zero=['wrong_target_writes','unauthorized_actions','source_overwrites','stale_approvals_accepted','escaped_atc_p1_p2','transport_clutter_incidents','critical_guardrail_failures']
reasons=[]
if d.get('completed_attended_runs',0)<a.min_runs: reasons.append('insufficient attended runs')
if d.get('uat_first_pass_rate',0)<a.min_uat_first_pass: reasons.append('uat first-pass below threshold')
for k in zero:
    if d.get(k,0)!=0: reasons.append(f'{k} must be zero')
print(json.dumps({'qualified':not reasons,'reasons':reasons,'scope':d.get('scope'),'thresholds':{'min_runs':a.min_runs,'min_uat_first_pass':a.min_uat_first_pass}},indent=2))
