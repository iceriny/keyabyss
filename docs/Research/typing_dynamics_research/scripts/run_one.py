"""Run a configurable single person/task; save session summary and word records."""
from pathlib import Path
import sys,argparse,json
import pandas as pd
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import load_config,draw_person,GROUPS
from typing_sim.lexicon import Lexicon
from typing_sim.simulator import Simulator

def main():
    a=argparse.ArgumentParser();a.add_argument('--group',choices=GROUPS,default='expert');a.add_argument('--task',choices=list('ABCD'),default='D')
    a.add_argument('--seconds',type=float,default=60);a.add_argument('--speed',type=float,default=3);a.add_argument('--distractors',type=int,default=0)
    a.add_argument('--no-preview',action='store_true');a.add_argument('--person',type=int,default=42);a.add_argument('--output',default='results/custom');z=a.parse_args()
    c=load_config(duration_s=z.seconds,speed_deg_s=z.speed,distractors=z.distractors,preview=int(not z.no_preview))
    p=draw_person(z.group,z.person,seed=c['seed']);s,w,_=Simulator(Lexicon()).session(p,z.task,c)
    out=Path(z.output);out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text(json.dumps(s,indent=2));(out/'config.json').write_text(json.dumps(c,indent=2));(out/'person.json').write_text(json.dumps(p.to_dict(),indent=2))
    pd.DataFrame(w).to_csv(out/'words.csv',index=False);print(json.dumps({k:s[k] for k in ['wpm5','actual_wpm','lpm','cpm','failure_count']},indent=2))
if __name__=='__main__':main()
