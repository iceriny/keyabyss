"""Execute all research experiments, saving exact jobs, sessions and metadata."""
from pathlib import Path
import sys,time,json,csv,gzip,platform,argparse,hashlib,datetime
from concurrent.futures import ProcessPoolExecutor
import multiprocessing as mp
import numpy as np
import pandas as pd
from scipy.stats import qmc
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import load_config,draw_person,GROUPS
from typing_sim.lexicon import Lexicon
from typing_sim.simulator import Simulator
SIM=None

def init_worker():
    global SIM
    SIM=Simulator(Lexicon())

def execute(job):
    t=time.perf_counter()
    p=draw_person(job['group'],job['person_id'],seed=job['cfg']['seed'],fixed=job.get('fixed',False))
    s,w,tr=SIM.session(p,job['task'],job['cfg'],repeat=job['repeat'])
    s.update(job.get('labels',{}));s['runtime_s']=time.perf_counter()-t
    return s,w if job.get('keep_words',False) else None

def job(g,pid,task='D',rep=0,changes=None,labels=None,keep_words=False,fixed=False):
    return dict(group=g,person_id=pid,task=task,repeat=rep,cfg=load_config(**(changes or {})),
                labels=labels or {},keep_words=keep_words,fixed=fixed)

def batch(jobs,name,folder,workers):
    directory=ROOT/'results'/folder;directory.mkdir(parents=True,exist_ok=True)
    stamp=datetime.datetime.now(datetime.timezone.utc).isoformat();t=time.perf_counter()
    configfile=directory/(name+'_jobs.jsonl.gz')
    with gzip.open(configfile,'wt',encoding='utf-8') as f:
        for j in jobs:f.write(json.dumps(j,ensure_ascii=False)+'\n')
    rows=[];wordfile=None;writer=None
    if any(j.get('keep_words') for j in jobs):wordfile=gzip.open(directory/(name+'_words.csv.gz'),'wt',encoding='utf-8',newline='')
    print(f'BEGIN {name}: {len(jobs)} sessions',flush=True)
    try:
        with ProcessPoolExecutor(max_workers=workers,mp_context=mp.get_context('spawn'),initializer=init_worker) as ex:
            for k,(s,w) in enumerate(ex.map(execute,jobs,chunksize=8),1):
                rows.append(s)
                if w and wordfile:
                    if writer is None:writer=csv.DictWriter(wordfile,fieldnames=list(w[0]));writer.writeheader()
                    writer.writerows(w)
                if k%256==0: print(f'{name}: {k}/{len(jobs)} ({time.perf_counter()-t:.1f}s)',flush=True)
    finally:
        if wordfile:wordfile.close()
    df=pd.DataFrame(rows);outfile=directory/(name+'_sessions.csv');df.to_csv(outfile,index=False)
    meta={'name':name,'started_utc':stamp,'finished_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'wall_seconds':time.perf_counter()-t,'python':sys.version,'platform':platform.platform(),
          'workers':workers,'planned_sessions':len(jobs),'executed_sessions':len(df),
          'sessions_with_recognition_failure':int((df.failure_count>0).sum()),
          'total_simulated_seconds':float(df.duration_s.sum()),'seed':20261014,
          'config_manifest':str(configfile.relative_to(ROOT)),'output':str(outfile.relative_to(ROOT)),
          'output_sha256':hashlib.sha256(outfile.read_bytes()).hexdigest()}
    (directory/(name+'_meta.json')).write_text(json.dumps(meta,indent=2))
    print(f'END {name}: {meta["wall_seconds"]:.1f}s',flush=True)
    return df

def baseline(workers):
    js=[]
    for gi,g in enumerate(GROUPS):
        for i in range(24):
            for task in 'ABCD':
                for rep in range(2):js.append(job(g,gi*100000+100+i,task,rep,dict(duration_s=40.)))
    pilot=batch(js,'pilot','baseline',workers);plan={}
    for g in GROUPS:
        a=pilot[(pilot.group==g)&(pilot.task=='D')].groupby('person_id').wpm5.mean()
        sd=float(a.std());n=int(np.ceil((1.96*sd/1.5)**2))
        plan[g]={'pilot_sd':sd,'target_halfwidth':1.5,'unconstrained_n':n,'n_people':int(np.clip(n,64,384)),
                 'repetitions':2,'session_seconds':60,'main_person_offset':1000}
    (ROOT/'results/baseline/sample_size_plan.json').write_text(json.dumps(plan,indent=2))
    js=[]
    for gi,g in enumerate(GROUPS):
        for i in range(plan[g]['n_people']):
            for task in 'ABCD':
                for rep in range(2):js.append(job(g,gi*100000+1000+i,task,rep,dict(duration_s=60.),keep_words=True))
    batch(js,'baseline','baseline',workers)
    js=[]
    for gi,g in enumerate(GROUPS):
        for i in range(48):
            for task in 'ABCD':
                for rep in range(2):js.append(job(g,gi*100000+3000+i,task,rep,dict(duration_s=60.,preview=0),keep_words=True))
    batch(js,'no_preview','baseline',workers)

def sensitivity(workers):
    cases=[]
    def add(factor,level,**changes):cases.append((factor,str(level),changes))
    for v in [0,1,3,6,10]:add('speed',v,speed_deg_s=v)
    for v in [.2,.5,.85,1.]:add('predictability',v,predictability=v)
    for v in [6,14,28,40]:add('field_width',v,field_width_deg=v,field_height_deg=v*15/28)
    for v in [0,.1,.25,.4]:add('occlusion_duty',v,occlusion_duty=v)
    for v in [.08,.25,.6,1.2]:add('occlusion_duration',v,occlusion_duty=.25,occlusion_duration_s=v)
    for v in [0,4,12,24]:add('distractors',v,distractors=v)
    for v in [.15,.35,.60,.80]:add('similarity',v,distractors=12,similarity=v,cue_strength=3.)
    for v in [3,5,8,11]:add('length',v,min_length=v,max_length=v,minimum_corpus_count=3)
    for lo,hi in [(2.5,3.5),(3.5,4.5),(4.5,5.5),(5.5,8.)]:add('frequency',f'{lo}-{hi}',frequency_min=lo,frequency_max=hi,minimum_corpus_count=1)
    for v in [.22,.30,.38,.55]:add('font',v,font_height_deg=v)
    for v in [0.,.35,.70,1.]:add('preview_fraction',v,preview_fraction=v)
    for v in [.5,1.,1.5]:add('lookahead',v,lookahead_multiplier=v)
    for v in ['immediate','end','submit','none']:add('correction',v,correction=v)
    for v in [.5,2,8,30]:add('memory_half_life',v,memory_half_life_s=v)
    for v in ['linear','bounce','periodic','ou','ou_accel','mixed']:add('trajectory',v,trajectory=v)
    for v in ['uniform','frequency','matched_A']:add('sampling',v,sampling=v)
    js=[]
    for gi,g in enumerate(['ordinary','expert','elite']):
        for factor,level,changes in cases:
            for i in range(24):js.append(job(g,500000+gi*100000+i,changes=dict(duration_s=35.,**changes),labels=dict(factor=factor,level=level)))
    batch(js,'sensitivity','sensitivity',workers)
    js=[]
    for gi,g in enumerate(['ordinary','expert']):
        for duration in [60,300,900,1800]:
            for fatigue in [False,True]:
                for i in range(12):js.append(job(g,800000+gi*100000+i,changes=dict(duration_s=duration,fatigue=fatigue),labels=dict(fatigue_enabled=fatigue,test_duration=duration)))
    batch(js,'fatigue','sensitivity',workers)
    js=[]
    for gi,g in enumerate(GROUPS):
        for scale in [.10,.20,.35,.5,.7,1.,1.4,2.0]:
            for i in range(16):js.append(job(g,1000000+gi*100000+i,changes=dict(duration_s=45.,motor_scale_multiplier=scale),labels=dict(motor_scale=scale)))
    batch(js,'motor_limit','sensitivity',workers)
    js=[]
    for speed in [0,3,6,10]:
        for distractors in [0,4,12,24]:
            for i in range(20):js.append(job('expert',1600000+i,changes=dict(duration_s=35.,speed_deg_s=speed,distractors=distractors),labels=dict(speed_level=speed,distractor_level=distractors)))
    batch(js,'interaction','sensitivity',workers)

def ablation(workers):
    cases={'full':{},'no_crowding':dict(crowding=False),'no_prediction':dict(prediction=False),
        'no_pursuit':dict(pursuit=False),'no_competition':dict(competition=False),'no_memory':dict(memory=False),
        'no_parallel':dict(parallel=False),'no_preview':dict(preview=0),'no_correction':dict(correction='none'),
        'no_boundary':dict(boundary_delay_multiplier=0.),'no_sequence':dict(sequence=False),'no_attention':dict(attention=False),'no_fatigue':dict(fatigue=False),
        'fixed_eye':dict(fixed_eye=True)}
    js=[]
    for gi,g in enumerate(['ordinary','expert']):
        for case,changes in cases.items():
            for i in range(32):
                c=dict(duration_s=45.,distractors=12,occlusion_duty=.2,similarity=.6,speed_deg_s=6.,cue_strength=8.);c.update(changes)
                js.append(job(g,1800000+gi*100000+i,changes=c,labels=dict(case=case)))
    batch(js,'ablation','ablation',workers)
    js=[]
    for g in ['ordinary','expert','elite']:
        gi=GROUPS.index(g)
        for phase in ['before','after']:
            for force in [False,True]:
                for duty in [0.,.35]:
                    for i in range(24):js.append(job(g,2000000+gi*100000+i,changes=dict(duration_s=35.,occlusion_phase=phase,force_tracking=force,occlusion_duty=duty),labels=dict(phase=phase,force_tracking=force,duty=duty)))
    batch(js,'encoding_visibility','ablation',workers)

def uncertainty(workers):
    specs={'recognition_base_s':(.14,.23),'saccade_latency_s':(.14,.23),'recognition_diffusion':(.25,.5),
           'attention_multiplier':(.6,1.4),'pursuit_gain_multiplier':(.92,1.06),'memory_half_life_s':(3.,15.),
           'motor_scale_multiplier':(.8,1.2),'boundary_delay_multiplier':(.6,1.4),'bouma_factor':(.3,.6),'context_drift_gain':(0.,.25)}
    design=qmc.LatinHypercube(d=len(specs),seed=20261015).random(128)
    out=pd.DataFrame({k:a+(b-a)*design[:,i] for i,(k,(a,b)) in enumerate(specs.items())});out.insert(0,'draw',np.arange(len(out)))
    out.to_csv(ROOT/'results/sensitivity/uncertainty_design.csv',index=False);js=[]
    for gi,g in enumerate(GROUPS):
        for d in out.to_dict('records'):
            draw=int(d.pop('draw'));changes=dict(duration_s=35.,**d)
            if g=='elite':changes['motor_scale_multiplier']=.7+1.5*(changes['motor_scale_multiplier']-.8)
            for i in range(4):js.append(job(g,2500000+gi*100000+i,changes=changes,fixed=True,labels=dict(draw=draw)))
    batch(js,'uncertainty','sensitivity',workers)

def validation(workers):
    js=[]
    for g in ['ordinary','expert','elite']:
        gi=GROUPS.index(g)
        for dt in [.001,.002,.005,.010]:
            for i in range(32):js.append(job(g,3000000+gi*100000+i,changes=dict(duration_s=40.,dt_s=dt),labels=dict(dt_level=dt)))
    batch(js,'time_step','validation',workers)
    js=[]
    for gi,g in enumerate(['ordinary','expert']):
        for task,changes,label in [('A',{},'coherent'),('B',{'sampling':'matched_A'},'random_matched'),('A',{'context_drift_gain':0.},'coherent_no_context'),('B',{},'random_uniform')]:
            for i in range(48):
                for rep in range(2):js.append(job(g,3400000+gi*100000+i,task,rep,changes=dict(duration_s=45.,**changes),labels=dict(control=label)))
    batch(js,'lexical_control','validation',workers)
    js=[]
    for dur in [15,30,60,120,300]:
        for i in range(24):js.append(job('expert',3700000+i,changes=dict(duration_s=dur),labels=dict(duration_level=dur)))
    batch(js,'duration','validation',workers)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--stage',default='all',choices=['all','baseline','sensitivity','ablation','uncertainty','validation']);ap.add_argument('--workers',type=int,default=4);args=ap.parse_args()
    for name,func in [('baseline',baseline),('sensitivity',sensitivity),('ablation',ablation),('uncertainty',uncertainty),('validation',validation)]:
        if args.stage in ('all',name):func(args.workers)
if __name__=='__main__':main()
