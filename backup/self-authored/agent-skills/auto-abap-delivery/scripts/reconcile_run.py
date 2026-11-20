#!/usr/bin/env python3
import argparse,json
from pathlib import Path
from datetime import datetime,timezone
p=argparse.ArgumentParser(); p.add_argument('run_dir'); p.add_argument('--observed-system',required=True); p.add_argument('--observed-client',required=True); p.add_argument('--observed-hash'); p.add_argument('--expected-hash'); a=p.parse_args(); r=Path(a.run_dir); s=json.loads((r/'run-state.json').read_text())
identity=(s['target']['system']==a.observed_system and str(s['target']['client'])==str(a.observed_client))
if not identity: outcome='target_mismatch_block'
elif a.expected_hash and a.observed_hash==a.expected_hash: outcome='expected_state_confirmed'
elif a.observed_hash and a.expected_hash: outcome='source_drift_block'
else: outcome='manual_reconciliation_required'
rep={'recovery_id':f"REC-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",'run_id':s['run_id'],'target_identity_match':identity,'observed_hash':a.observed_hash,'expected_hash':a.expected_hash,'outcome':outcome,'created_at':datetime.now(timezone.utc).isoformat()}
out=r/'recovery'/f"{rep['recovery_id']}.json"; out.write_text(json.dumps(rep,indent=2),encoding='utf-8'); print(out)
