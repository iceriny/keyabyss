"""Moment-constrained calibration to verified published transition summaries.
Not a raw-keystroke fit. The 12 table cells are not 12 independent participants.
The fitting loss is a numerical discrepancy, not a statistical likelihood.
"""
from pathlib import Path
import sys,json,time
import numpy as np
import pandas as pd
import yaml
from scipy.optimize import least_squares
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import Person,load_config
from typing_sim.lexicon import Lexicon
from typing_sim.motor import Motor

PAIRS={'alternation':'al la ak ka am ma an na ai ia so os sp ps en ne em me el le ep pe'.split(),
       'left':'as sa er re sd ds ec ce ew we wa aw cr sc cs'.split(),
       'right':'lk lo ol op po io oi no on in ni'.split(),
       'repeat':'ll cc aa nn tt ss pp'.split()}
CATS=['alternation','left','right','repeat']
DEFAULTS={
 'beginner':dict(between_motor_cv=.20,planning_s=.065,planning_gap_s=.04,lookahead=1,motor_attention=.58,error_p=.020,detection_p=.50,keyboard_look_p=.65,key_hold_s=.12899),
 'ordinary':dict(between_motor_cv=.18,planning_s=.026,planning_gap_s=.016,lookahead=2,motor_attention=.32,error_p=.013,detection_p=.70,keyboard_look_p=.15,key_hold_s=.11625),
 'skilled':dict(between_motor_cv=.14,planning_s=.016,planning_gap_s=.010,lookahead=3,motor_attention=.20,error_p=.010,detection_p=.82,keyboard_look_p=.04,key_hold_s=.110),
 'expert':dict(between_motor_cv=.10,planning_s=.010,planning_gap_s=.006,lookahead=4,motor_attention=.11,error_p=.007,detection_p=.90,keyboard_look_p=.01,key_hold_s=.10449),
 'elite':dict(between_motor_cv=.12,planning_s=.007,planning_gap_s=.004,lookahead=5,motor_attention=.07,error_p=.006,detection_p=.93,keyboard_look_p=.005,key_hold_s=.080)}

def makeperson(group,theta):
    d=DEFAULTS[group]
    return Person(group,0,float(theta[0]),float(theta[1]),float(theta[2]),float(theta[3]),1.,d['planning_s'],
       d['planning_gap_s'],d['lookahead'],d['motor_attention'],1.,1.,.93,0.,d['detection_p'],0.,8.,0.,0.,0.,d['key_hold_s'])

def predict(theta,group,lex):
    p=makeperson(group,theta);cfg=load_config(errors=False,correction='none',fatigue=False)
    all_means=[]
    for category in CATS:
        pairmeans=[]
        for pair in PAIRS[category]:
            # Matched bidirectional patterns; repeated characters remain same-key taps.
            m=Motor(p,cfg,lex);w=pair*8
            z=m.word(w,w,0.,0.,np.random.default_rng(7261),0.)
            ts=[e for e in z['events'] if e.get('kind')=='letter']
            vals=[ts[i]['time']-ts[i-1]['time'] for i in range(4,len(ts)) if ts[i-1]['key']+ts[i]['key']==pair]
            pairmeans.append(np.mean(vals))
        all_means.append(np.mean(pairmeans))
    return np.array(all_means)

def main():
    t=time.perf_counter();lex=Lexicon();obs=pd.read_csv(ROOT/'data/raw/typing_summary_observations.csv')
    fitted={};rows=[]
    for group,label in [('beginner','slow'),('ordinary','all'),('expert','fast')]:
        target=np.array([float(obs[(obs.population==label)&(obs.measure==k)]['mean'].iloc[0])/1000 for k in CATS])
        x0=[target[0],target[1]/target[0],target[2]/target[0],target[3]]
        fit=least_squares(lambda x:(predict(x,group,lex)-target)/.015,x0,
            bounds=([.02,.5,.5,.03],[.8,2.,2.,.6]),diff_step=.01,max_nfev=35,xtol=1e-7)
        theta=fit.x; fitted[group]=dict(DEFAULTS[group],alt_s=float(theta[0]),left_ratio=float(theta[1]),right_ratio=float(theta[2]),repeat_s=float(theta[3]),evidence='R01 Table 3 summary-constrained fit')
        pred=predict(theta,group,lex)
        for name,a,b in zip(CATS,target,pred):rows.append(dict(group=group,category=name,observed_ms=1000*a,model_ms=1000*b,residual_ms=1000*(b-a)))
        print(group,theta,'RMSE ms',np.sqrt(np.mean((pred-target)**2))*1000,flush=True)
    # Two additional profiles are interpolation/extrapolation, not measured cohorts.
    a=fitted['ordinary'];b=fitted['expert']
    fitted['skilled']=dict(DEFAULTS['skilled'],**{k:float(np.sqrt(a[k]*b[k])) for k in ['alt_s','left_ratio','right_ratio','repeat_s']},evidence='geometric interpolation R01 anchors + priors')
    fitted['elite']=dict(DEFAULTS['elite'],alt_s=.063,left_ratio=1.14,right_ratio=1.10,repeat_s=.105,evidence='explicit extrapolative prior; not a measured competition cohort')
    fitted={k:fitted[k] for k in DEFAULTS}
    (ROOT/'configs/population.yaml').write_text(yaml.safe_dump(fitted,sort_keys=False,allow_unicode=True))
    pd.DataFrame(rows).to_csv(ROOT/'results/validation/motor_calibration.csv',index=False)
    (ROOT/'results/validation/calibration_meta.json').write_text(json.dumps({'method':'nonlinear least squares on 12 verified aggregate cells','raw_keystroke_fit':False,'held_out_human_validation':False,'seconds':time.perf_counter()-t,'seed':7261,'fit_targets':'category IKI means; WPM not a target','note':'all group is a heterogeneous volunteer aggregate, not a population-representative ordinary subgroup'},indent=2))
if __name__=='__main__': main()
