"""Replay retained representative jobs in a fresh interpreter and compare scores.
This is local computational replay, not independent human-study validation.
"""
from pathlib import Path
import sys,json,gzip,time
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import draw_person
from typing_sim.lexicon import Lexicon
from typing_sim.simulator import Simulator

def main():
    start=time.perf_counter();ref=pd.read_csv(ROOT/'results/baseline/baseline_sessions.csv')
    with gzip.open(ROOT/'results/baseline/baseline_jobs.jsonl.gz','rt') as f:jobs=[json.loads(x) for x in f]
    pick=[];seen=set()
    for j in jobs:
        tag=(j['group'],j['task'])
        if tag not in seen:pick.append(j);seen.add(tag)
    sim=Simulator(Lexicon());rows=[]
    for j in pick:
        p=draw_person(j['group'],j['person_id'],seed=j['cfg']['seed']);s,_,_=sim.session(p,j['task'],j['cfg'],repeat=j['repeat'])
        q=ref[(ref.person_id==j['person_id'])&(ref.task==j['task'])&(ref.repeat==j['repeat'])].iloc[0]
        metrics=['wpm5','actual_wpm','lpm','cpm','raw_key_count','backspaces','total_saccades','total_reacquisitions']
        ok=all(np.isclose(s[k],float(q[k]),rtol=1e-10,atol=1e-10) for k in metrics)
        rows.append(dict(group=j['group'],task=j['task'],person_id=j['person_id'],match=bool(ok)))
    pd.DataFrame(rows).to_csv(ROOT/'results/validation/replay.csv',index=False)
    meta=dict(checked_sessions=len(rows),passed=sum(r['match'] for r in rows),seconds=time.perf_counter()-start,
        scope='fresh-interpreter local replay against retained outputs; not another person or another machine')
    (ROOT/'results/validation/replay_metadata.json').write_text(json.dumps(meta,indent=2));print(meta)
    if meta['passed']!=len(rows):raise SystemExit(1)
if __name__=='__main__':main()
