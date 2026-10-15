"""Small, explicitly controlled simulations for mechanistic figures and raw traces."""
from pathlib import Path
import sys,json,time
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import load_config,draw_person,rng_stream,TRAJECTORIES
from typing_sim.lexicon import Lexicon
from typing_sim.simulator import Simulator
from typing_sim.vision import eye_kernel,encode_parameters,TRACE_COLUMNS
from typing_sim.trajectories import trajectory_trace
OUT=ROOT/'results/traces';OUT.mkdir(parents=True,exist_ok=True)

def main():
    start=time.perf_counter();lex=Lexicon();sim=Simulator(lex);person=draw_person('expert',991,fixed=True)
    cfg=load_config(duration_s=10.,distractors=4,occlusion_duty=.1,speed_deg_s=3.)
    stats,words,tr=sim.session(person,'D',cfg,trace=True)
    eyes=[]
    for wi,a in tr['eyes']:
        d=pd.DataFrame(a,columns=TRACE_COLUMNS);d['word_index']=wi;eyes.append(d)
    pd.concat(eyes,ignore_index=True).to_csv(OUT/'session_eyes.csv.gz',index=False)
    # The event payloads retain word IDs and non-key central commitment events.
    keyed=[e['payload'] for e in tr['events'] if 'key' in e['payload']]
    pd.DataFrame(keyed).to_csv(OUT/'session_keys.csv',index=False)
    pd.DataFrame(words).to_csv(OUT/'session_words.csv',index=False)
    (OUT/'session_events.json').write_text(json.dumps(tr['events'],ensure_ascii=False,indent=2))
    (OUT/'session_summary.json').write_text(json.dumps(stats,indent=2))
    # Raw continuous target trajectories. Each family is reproducible from these arguments.
    curves=[]
    for name in TRAJECTORIES:
        a=trajectory_trace(881,np.array([-4.,-2.]),np.array([2.4,1.8]),6.,.005,TRAJECTORIES[name],3.,28.,15.,12.,.6,np.random.default_rng(881))
        d=pd.DataFrame(a,columns=['time','x','y','vx','vy']);d['family']=name;curves.append(d)
    pd.concat(curves).to_csv(OUT/'trajectory_families.csv.gz',index=False)
    rows=[];diag_count=0
    def ocular(cfg,x0,v0,lengths,sims,rep,gaze=None,hold=False):
        nonlocal diag_count
        diag_count+=1
        f=dict(length=int(lengths[0]),corpus_logfreq=5.)
        par=encode_parameters(cfg,person,'D',f,float(max(sims)) if len(sims) else 0.)
        if hold:par[16]=0.;par[18]=1e8
        return eye_kernel(par,np.array(x0,float),np.array(v0,float),np.array(lengths,float),np.array(sims,float),
            np.array([0.,0.] if gaze is None else gaze,float),np.empty((0,4)),0.,0.,True,
            rng_stream(903,rep,module=4),rng_stream(903,rep,module=5),rng_stream(903,rep,module=6),rng_stream(903,rep,module=9))
    for speed in [0.,1.,3.,6.,10.]:
        for rep in range(32):
            c=load_config(speed_deg_s=speed,max_recognition_s=6.,predictability=.6)
            z,g,x,v,tr=ocular(c,[[3.,1.]],[[speed,0.]], [5],[],rep,hold=True)
            # Acquisition excursions are excluded: only smooth pursuit, t >= 1 s.
            keep=(tr[:,0]>=1.) & (tr[:,5]==3.) & (tr[:,8]>.9)
            # Static reference is fixation, because pursuit is absent at zero speed.
            if speed==0:keep=(tr[:,0]>=1.) & (tr[:,5]==0.) & (tr[:,8]>.9)
            err=float(np.sqrt(np.mean(tr[keep,9]**2))) if keep.any() else np.nan
            rows.append(dict(speed_deg_s=speed,rep=rep,rms_deg=err,n_samples=int(keep.sum()),mode='fixation' if speed==0 else 'pursuit'))
            if speed==3 and rep==0:pd.DataFrame(tr,columns=TRACE_COLUMNS).to_csv(OUT/'pursuit_example.csv.gz',index=False)
    pd.DataFrame(rows).to_csv(OUT/'pursuit_speed.csv',index=False)
    rows=[];events=[]
    for duration in [.08,.25,.6,1.2]:
        for prediction in [False,True]:
            for rep in range(40):
                c=load_config(speed_deg_s=6.,predictability=.35,max_recognition_s=8.,occlusion_duty=.3,
                              occlusion_duration_s=duration,prediction=prediction)
                z,g,x,v,tr=ocular(c,[[3.,1.]],[[6.,0.]], [5],[],rep+1000,hold=True)
                visible=tr[:,8]>.8
                boundaries=np.flatnonzero(visible[1:] & ~visible[:-1])+1
                for j in boundaries:
                    if tr[j,0]<1.:continue
                    stop=j+1
                    while stop<len(tr) and visible[stop]:stop+=1
                    good=np.flatnonzero((tr[j:stop,9]<.8)&(tr[j:stop,5]!=2))
                    lag=float(tr[j+good[0],0]-tr[j,0]) if len(good) else np.nan
                    k=j-1
                    while k>=0 and not visible[k]:k-=1
                    events.append(dict(mean_occlusion_s=duration,prediction=prediction,rep=rep,
                         actual_occlusion_s=float(tr[j,0]-tr[max(0,k),0]),reacquisition_s=lag,censored=not len(good)))
                rows.append(dict(mean_occlusion_s=duration,prediction=prediction,rep=rep,target_losses=z[6],reacquisitions=z[5]))
    pd.DataFrame(events).to_csv(OUT/'occlusion_reacquisition.csv',index=False)
    pd.DataFrame(rows).to_csv(OUT/'occlusion_counts.csv',index=False)
    # Peripheral fixed-gaze brief exposure, not an unconstrained search task.
    rows=[]
    for gap in [.03,.1,.2,.4,.8,1.6]:
        for enabled in [False,True]:
            for rep in range(200):
                c=load_config(speed_deg_s=0.,max_recognition_s=.65,saccade_latency_s=10.,crowding=enabled,cue_strength=1e9)
                y=.38+gap
                z,g,x,v,tr=ocular(c,[[1.5,0.],[1.5,y],[1.5,-y]],np.zeros((3,2)),[5,5,5],[.2,.2],rep+2000)
                rows.append(dict(edge_gap_deg=gap,crowding_enabled=enabled,rep=rep,correct=int(z[3]==1),
                                 wrong=int(z[3]<0),uncertain=int(z[3]==0),mean_crowding=z[9],duration_s=z[0]))
    pd.DataFrame(rows).to_csv(OUT/'crowding_brief_exposure.csv',index=False)
    # Actual dictionary words, fixed length, with the same ocular geometry.
    rows=[];df=lex.df
    for low,high in [(2.5,3.5),(3.5,4.5),(4.5,5.5),(5.5,8.)]:
        pool=df[(df.length==5)&(df.corpus_logfreq>=low)&(df.corpus_logfreq<high)]
        if pool.empty:continue
        rr=np.random.default_rng(1900)
        for rep in range(120):
            w=str(pool.iloc[int(rr.integers(len(pool)))]['word']);f=lex.features(w)
            c=load_config(speed_deg_s=0.,max_recognition_s=3.)
            par=encode_parameters(c,person,'B',f,0.)
            z,g,x,v,tr=eye_kernel(par,np.array([[0.,0.]]),np.zeros((1,2)),np.array([5.]),np.array([]),
                np.array([0.,0.]),np.empty((0,4)),0.,0.,False,rng_stream(941,rep,module=4),
                rng_stream(941,rep,module=5),rng_stream(941,rep,module=6),rng_stream(941,rep,module=9))
            rows.append(dict(frequency_bin=f'{low}-{high}',word=w,corpus_logfreq=f['corpus_logfreq'],
                             recognition_s=z[0],correct=z[3]==1,rep=rep))
    pd.DataFrame(rows).to_csv(OUT/'lexical_frequency.csv',index=False)
    rows=[]
    for length in [3,5,8,11]:
        for rep in range(16):
            c=load_config(duration_s=35.,min_length=length,max_length=length,minimum_corpus_count=3)
            p=draw_person('expert',6000000+rep)
            z,w,tr=sim.session(p,'D',c)
            for r in w:
                if r['submit_time']<=35.:rows.append(r)
    pd.DataFrame(rows).to_csv(OUT/'word_length_trials.csv.gz',index=False)
    meta=dict(seconds=time.perf_counter()-start,ocular_microtrials=diag_count+len(pd.read_csv(OUT/'lexical_frequency.csv')),
              typing_sessions=65,master_seeds=[903,941,20261014],notes='Figure diagnostics, not recruited humans; raw traces retained')
    (OUT/'diagnostics_metadata.json').write_text(json.dumps(meta,indent=2));print(meta)
if __name__=='__main__':main()
