"""Cluster-aware Monte Carlo intervals and within/between-person decomposition."""
import numpy as np

def cluster_summary(df,metric='wpm5',seed=3021,draws=1500):
    people=[x[metric].to_numpy(float) for _,x in df.groupby('person_id',sort=True)]
    n=len(people);means=np.array([x.mean() for x in people]);r=np.random.default_rng(seed)
    # Hierarchical resampling, not treating repetitions as independent people.
    boot=np.empty(draws)
    for b in range(draws):
        ix=r.integers(0,n,n)
        boot[b]=np.mean([people[i][r.integers(0,len(people[i]),len(people[i]))].mean() for i in ix])
    within=np.mean([np.var(x,ddof=1) if len(x)>1 else 0 for x in people])
    between_observed=np.var(means,ddof=1) if n>1 else 0
    reps=np.mean([len(x) for x in people])
    return dict(n_people=n,n_sessions=len(df),mean=float(means.mean()),median=float(np.median(means)),
        sd=float(np.std(means,ddof=1)) if n>1 else 0.,p05=float(np.quantile(means,.05)),
        p25=float(np.quantile(means,.25)),p75=float(np.quantile(means,.75)),p95=float(np.quantile(means,.95)),
        ci_low=float(np.quantile(boot,.025)),ci_high=float(np.quantile(boot,.975)),
        mc_se=float(np.sqrt(between_observed/n)),within_person_sd=float(np.sqrt(within)),
        between_person_sd=float(np.sqrt(max(0,between_observed-within/max(reps,1)))))

def simple_cluster_interval(df,metric='wpm5'):
    x=df.groupby('person_id')[metric].mean().to_numpy(float)
    mean=float(np.mean(x));se=float(np.std(x,ddof=1)/np.sqrt(len(x))) if len(x)>1 else 0.
    return mean,mean-1.96*se,mean+1.96*se

def paired_contrast(df,first,second,metric='wpm5',seed=998,draws=4000):
    a=df[df.task==first].groupby('person_id')[metric].mean()
    b=df[df.task==second].groupby('person_id')[metric].mean()
    ids=a.index.intersection(b.index);a=a.loc[ids].to_numpy();b=b.loc[ids].to_numpy()
    absolute=b-a;relative=(b-a)/np.maximum(a,1e-12)
    r=np.random.default_rng(seed);ix=r.integers(0,len(ids),(draws,len(ids)))
    bs=absolute[ix].mean(1);rs=relative[ix].mean(1)
    return dict(first=first,second=second,n_people=len(ids),difference=float(absolute.mean()),
        difference_ci_low=float(np.quantile(bs,.025)),difference_ci_high=float(np.quantile(bs,.975)),
        relative_percent=float(100*relative.mean()),relative_ci_low=float(100*np.quantile(rs,.025)),
        relative_ci_high=float(100*np.quantile(rs,.975)),ratio_of_means_percent=float(100*(b.mean()/a.mean()-1)))
