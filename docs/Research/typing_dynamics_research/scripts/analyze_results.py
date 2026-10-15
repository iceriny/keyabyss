"""Derive all tables from executed sessions; intervals resample whole participants."""
from pathlib import Path
import sys,json,yaml
import numpy as np
import pandas as pd
from scipy.optimize import least_squares
from scipy.stats import spearmanr
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import GROUPS
from typing_sim.statistics import paired_contrast
OUT=ROOT/'results/analysis';OUT.mkdir(parents=True,exist_ok=True)

def read(folder,name):return pd.read_csv(ROOT/'results'/folder/(name+'_sessions.csv'))
def summary(frame,metric,seed=9064):
    # A participant and their entire repeat vector are the independent sampling unit.
    a=frame.groupby('person_id')[metric].agg(['mean','var','count']);x=a['mean'].to_numpy(float);n=len(x)
    r=np.random.default_rng(seed);boot=x[r.integers(0,n,(3000,n))].mean(axis=1)
    within=float(a['var'].fillna(0).mean());between=float(np.var(x,ddof=1)) if n>1 else 0.
    return dict(metric=metric,n_people=n,n_sessions=len(frame),mean=float(x.mean()),median=float(np.median(x)),
        sd=float(np.sqrt(between)),p05=float(np.quantile(x,.05)),p25=float(np.quantile(x,.25)),
        p75=float(np.quantile(x,.75)),p95=float(np.quantile(x,.95)),ci_low=float(np.quantile(boot,.025)),
        ci_high=float(np.quantile(boot,.975)),mc_se=float(np.sqrt(between/n)),
        within_person_sd=float(np.sqrt(within)),between_person_sd=float(np.sqrt(max(0,between-float((a['var'].fillna(0)/a['count']).mean())))))

def grouped(frame,keys,metrics=('wpm5',)):
    rows=[]
    for index,df in frame.groupby(keys,dropna=False,sort=False):
        if not isinstance(index,tuple):index=(index,)
        labels=dict(zip(keys,index))
        for metric in metrics:rows.append(dict(**labels,**summary(df,metric)))
    return pd.DataFrame(rows)

def main():
    a=read('baseline','baseline');no=read('baseline','no_preview')
    metrics=['wpm5','actual_wpm','lpm','cpm','backspace_ratio','uncorrected_error','corrected_errors_per_char',
             'mean_acquisition_s','mean_recognition_s','mean_correction_s','visual_bottleneck_fraction',
             'motor_bottleneck_fraction','mean_attention_lost_s','mean_iki_s','rollover_fraction','recognition_error_rate']
    grouped(a,['group','task'],metrics).to_csv(OUT/'baseline_statistics.csv',index=False)
    grouped(no,['group','task'],metrics).to_csv(OUT/'no_preview_statistics.csv',index=False)
    contrasts=[]
    for name,data in [('preview',a),('no_preview',no)]:
        for g,df in data.groupby('group'):
            for x,y in [('A','B'),('B','C'),('C','D'),('A','D')]:
                contrasts.append(dict(policy=name,group=g,**paired_contrast(df,x,y)))
    pd.DataFrame(contrasts).to_csv(OUT/'paired_task_contrasts.csv',index=False)
    for folder,name,keys in [
       ('sensitivity','sensitivity',['group','factor','level']),
       ('sensitivity','fatigue',['group','fatigue_enabled','test_duration']),
       ('sensitivity','motor_limit',['group','motor_scale']),
       ('sensitivity','interaction',['speed_level','distractor_level']),
       ('ablation','ablation',['group','case']),
       ('ablation','encoding_visibility',['group','phase','force_tracking','duty']),
       ('validation','time_step',['group','dt_level']),
       ('validation','lexical_control',['group','control']),
       ('validation','duration',['duration_level'])]:
        data=read(folder,name)
        grouped(data,keys,['wpm5','actual_wpm','mean_acquisition_s','mean_recognition_s',
            'recognition_error_rate','mean_actual_similarity','mean_correction_s','failure_count']).to_csv(OUT/(name+'_statistics.csv'),index=False)
    # Paired model interventions: all conditions share participant IDs and word streams.
    data=read('ablation','ablation');rows=[]
    for g,df in data.groupby('group'):
        tmp=df.copy();tmp['task']=tmp['case']
        for case in df['case'].unique():
            if case!='full':rows.append(dict(group=g,case=case,**paired_contrast(tmp,'full',case)))
    pd.DataFrame(rows).to_csv(OUT/'ablation_contrasts.csv',index=False)
    # Parameter uncertainty is prior-predictive, not a fitted posterior or an MC CI.
    u=read('sensitivity','uncertainty').groupby(['group','draw']).wpm5.mean().reset_index()
    design=pd.read_csv(ROOT/'results/sensitivity/uncertainty_design.csv');u.to_csv(OUT/'uncertainty_draw_means.csv',index=False)
    rows=[];rank=[]
    for g,d in u.groupby('group'):
        x=d.wpm5.to_numpy();rows.append(dict(group=g,mean=x.mean(),median=np.median(x),p025=np.quantile(x,.025),p05=np.quantile(x,.05),p95=np.quantile(x,.95),p975=np.quantile(x,.975),n_draws=len(x)))
        dd=d.merge(design,on='draw')
        for k in design.columns:
            if k=='draw':continue
            rho,p=spearmanr(dd[k],dd.wpm5)
            rank.append(dict(group=g,parameter=k,spearman_rho=rho,p_value_diagnostic=p))
    pd.DataFrame(rows).to_csv(OUT/'uncertainty_intervals.csv',index=False)
    pd.DataFrame(rank).to_csv(OUT/'sensitivity_rank.csv',index=False)
    # Reduced-order emulator. This is a fit to simulator outputs, never a human upper bound.
    ml=read('sensitivity','motor_limit').groupby(['group','motor_scale']).agg(wpm5=('wpm5','mean'),actual_wpm=('actual_wpm','mean')).reset_index()
    fitrows=[];curve=[]
    for g,d in ml.groupby('group'):
        x=d.motor_scale.to_numpy();y=d.wpm5.to_numpy();chars=float((5*d.wpm5/d.actual_wpm).mean())
        boundary=float(yaml.safe_load((ROOT/'configs/population.yaml').read_text())[g]['boundary_delay_s'])
        def fun(t,xx):
            v,m,q=t
            return 60*chars/(5*(boundary*np.sqrt(xx)+(v**q+(m*xx)**q)**(1/q)))
        train=np.array([True,False,True,True,False,True,True,True])
        fit=least_squares(lambda t:fun(t,x[train])-y[train],[.35,60*chars/(5*y[x==1][0]),3.],bounds=([.02,.05,1.],[5.,20.,16.]))
        v,m,q=fit.x;pred=fun(fit.x,x)
        fitrows.append(dict(group=g,visual_floor_s=v,motor_scale1_s=m,boundary_s=boundary,softmax_q=q,mean_chars=chars,
            fitted_asymptote_wpm5=60*chars/(5*v),rmse_train=np.sqrt(np.mean((pred[train]-y[train])**2)),
            rmse_heldout_sim_grid=np.sqrt(np.mean((pred[~train]-y[~train])**2)),
            empirical_grid_fastest_mean=float(y[x.argmin()]),caveat='simulator emulator, not a human physiological ceiling'))
        for xx in np.linspace(.05,2.,160):curve.append(dict(group=g,motor_scale=xx,predicted_wpm5=float(fun(fit.x,xx))))
    pd.DataFrame(fitrows).to_csv(OUT/'surrogate_parameters.csv',index=False)
    pd.DataFrame(curve).to_csv(OUT/'surrogate_curves.csv',index=False)
    # Descriptive external comparison deliberately exposes lack of macro-level agreement.
    obs=pd.read_csv(ROOT/'data/raw/typing_summary_observations.csv');r=[]
    for g,label in [('beginner','slow'),('ordinary','all'),('expert','fast')]:
        empirical=float(obs[(obs.population==label)&(obs.measure=='WPM')]['mean'].iloc[0]);model=float(a[(a.group==g)&(a.task=='A')].wpm5.mean())
        r.append(dict(group=g,reference_population=label,source_wpm5=empirical,model_A_wpm5=model,
             relative_discrepancy_percent=100*(model/empirical-1),same_stimuli=False,same_timing=False,
             interpretation='aggregate WPM calibration check in new simulated individuals; not independent human validation'))
    pd.DataFrame(r).to_csv(OUT/'external_macro_comparison.csv',index=False)
    # Time-step comparison is distributional: Brownian increments are not path-coupled across dt.
    dt=read('validation','time_step');r=[]
    for g,d in dt.groupby('group'):
        tmp=d.copy();tmp['task']=tmp.dt_level.map(str)
        for val in [.002,.005,.010]:r.append(dict(group=g,dt_s=val,**paired_contrast(tmp,'0.001',str(val))))
    pd.DataFrame(r).to_csv(OUT/'time_step_contrasts.csv',index=False)
    # Executed-run ledger: actual JSON metadata, not estimates from an intended plan.
    metas=[]
    for p in (ROOT/'results').rglob('*_meta.json'):
        m=json.loads(p.read_text())
        if 'executed_sessions' in m:metas.append(m)
    pd.DataFrame(metas).to_csv(OUT/'execution_ledger.csv',index=False)
    digest={'executed_sessions':int(sum(m['executed_sessions'] for m in metas)),
         'simulated_hours':sum(m['total_simulated_seconds'] for m in metas)/3600,
         'batch_compute_wall_seconds':sum(m['wall_seconds'] for m in metas),
         'failure_sessions':sum(m['sessions_with_recognition_failure'] for m in metas),
         'baseline_people':int(a.person_id.nunique()),'baseline_sessions':len(a),
         'baseline_completed_words':int(a.completed_words.sum()),
         'baseline_mean_metrics':a.groupby(['group','task'])[['wpm5','actual_wpm','lpm','cpm']].mean().reset_index().to_dict('records')}
    (OUT/'digest.json').write_text(json.dumps(digest,indent=2,ensure_ascii=False))
    print(json.dumps({k:v for k,v in digest.items() if k!='baseline_mean_metrics'},indent=2))
if __name__=='__main__':main()
