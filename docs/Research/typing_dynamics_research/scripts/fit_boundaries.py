"""Whole-task moment closure after fixing within-word timing.
The fitted delay is an aggregate boundary residual, not a measured pure mental
process. Source task has richer preview/case/punctuation and different timing.
These limitations are retained in the report; matching a mean is not validation.
"""
from pathlib import Path
import sys,json
import pandas as pd
import numpy as np
import yaml
from scipy.interpolate import PchipInterpolator
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from run_experiments import job,batch

def main():
    obs=pd.read_csv(ROOT/'data/raw/typing_summary_observations.csv')
    grids={'beginner':[0.,.3,.6,.9,1.2,1.5],'ordinary':[0.,.1,.2,.3,.4,.5],
           'expert':[0.,.03,.06,.09,.12,.18]}
    jobs=[]
    for gi,(g,grid) in enumerate(grids.items()):
        for delay in grid:
            for i in range(64):jobs.append(job(g,7000000+gi*100000+i,'A',changes=dict(duration_s=60.,boundary_delay_s=delay),labels=dict(boundary_delay=delay)))
    df=batch(jobs,'boundary_calibration','validation',4);means=df.groupby(['group','boundary_delay']).wpm5.mean().reset_index()
    means.to_csv(ROOT/'results/validation/boundary_calibration_grid.csv',index=False)
    population=yaml.safe_load((ROOT/'configs/population.yaml').read_text());rows=[]
    for g,label in [('beginner','slow'),('ordinary','all'),('expert','fast')]:
        d=means[means.group==g].sort_values('boundary_delay');x=d.boundary_delay.to_numpy();y=d.wpm5.to_numpy()
        target=float(obs[(obs.population==label)&(obs.measure=='WPM')]['mean'].iloc[0])
        if not np.all(np.diff(y)<0):raise RuntimeError('Calibration curve not decreasing')
        if not y.min()<target<y.max():raise RuntimeError('Target outside calibration grid')
        delay=float(PchipInterpolator(y[::-1],x[::-1])(target))
        population[g]['boundary_delay_s']=delay
        rows.append(dict(group=g,target_wpm5=target,fitted_boundary_delay_s=delay,source='R01 Table3 WPM',
            method='monotone interpolation of simulated mean WPM; residual not physiologically identified'))
    population['skilled']['boundary_delay_s']=float(np.sqrt(population['ordinary']['boundary_delay_s']*population['expert']['boundary_delay_s']))
    population['elite']['boundary_delay_s']=.5*population['expert']['boundary_delay_s']
    (ROOT/'configs/population.yaml').write_text(yaml.safe_dump(population,sort_keys=False,allow_unicode=True))
    pd.DataFrame(rows).to_csv(ROOT/'results/validation/boundary_fit.csv',index=False)
    jobs=[]
    for gi,g in enumerate(grids):
        for i in range(64):jobs.append(job(g,7300000+gi*100000+i,'A',changes=dict(duration_s=60.),labels=dict(role='independent_simulated_individuals_not_independent_human_data')))
    check=batch(jobs,'boundary_holdout','validation',4)
    print(check.groupby('group').wpm5.mean(),flush=True)
if __name__=='__main__':main()
