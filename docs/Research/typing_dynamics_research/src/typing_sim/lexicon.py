"""Corpus-count lexical features and controlled stimulus sampling."""
from pathlib import Path
import json, math
from functools import lru_cache
from collections import Counter
import numpy as np
import pandas as pd
from .config import ROOT

@lru_cache(maxsize=16384)
def edit_distance(a,b):
    old=list(range(len(b)+1))
    for i,x in enumerate(a,1):
        new=[i]
        for j,y in enumerate(b,1):new.append(min(new[-1]+1,old[j]+1,old[j-1]+(x!=y)))
        old=new
    return old[-1]

VISUAL_GROUPS=('iljt','oce','mn','uvwy','bdpq','sz','rn')
def visual_similarity(a,b):
    score=0.
    for x,y in zip(a,b):
        score+=1 if x==y else .55 if any(x in z and y in z for z in VISUAL_GROUPS) else 0
    return score/max(len(a),len(b),1)

@lru_cache(maxsize=32768)
def similarity(a,b):
    e=1-edit_distance(a,b)/max(len(a),len(b),1)
    aa={a[i:i+2] for i in range(len(a)-1)};bb={b[i:i+2] for i in range(len(b)-1)}
    j=len(aa&bb)/max(len(aa|bb),1)
    orth=float(len(a)==len(b) and edit_distance(a,b)==1)
    return float(np.clip(.45*e+.25*j+.20*visual_similarity(a,b)+.10*orth,0,1))

class Lexicon:
    def __init__(self):
        self.df=pd.read_csv(ROOT/'data/processed/lexicon.csv',keep_default_na=False)
        self.rows={r['word']:r for r in self.df.to_dict('records')}
        self.ng=json.loads((ROOT/'data/processed/ngrams.json').read_text())
        self.sentences=[s.split() for s in (ROOT/'data/raw/sentences.txt').read_text().splitlines() if s]
        self.tokens=[w for s in self.sentences for w in s]
        self.pools={}
    def features(self,w):
        r=self.rows.get(w)
        if r:return r
        # Explicit out-of-vocabulary floor, used only by authored sentence stimuli.
        return {'word':w,'length':len(w),'corpus_logfreq':2.5,'bigram_logcount':3.,
                'trigram_logcount':2.,'orthographic_neighbors':0,'neighbors':'','count':0}
    def pool(self,cfg):
        k=(cfg['min_length'],cfg['max_length'],cfg['minimum_corpus_count'],
           cfg.get('frequency_min',-100),cfg.get('frequency_max',100))
        if k not in self.pools:
            d=self.df
            m=(d.length>=k[0])&(d.length<=k[1])&(d['count']>=k[2])&(d.corpus_logfreq>=k[3])&(d.corpus_logfreq<=k[4])
            x=d.loc[m]
            if len(x)==0:raise ValueError('No eligible words')
            self.pools[k]=(x.word.to_numpy(),x['count'].to_numpy(float))
        return self.pools[k]
    def sample_words(self,cfg,rng,n=1000,task='B'):
        if task=='A':
            out=[]
            while len(out)<n:out.extend(self.sentences[int(rng.integers(len(self.sentences)))])
            return out[:n]
        if cfg.get('sampling')=='matched_A':return rng.choice(self.tokens,n).tolist()
        names,counts=self.pool(cfg)
        weights=counts/counts.sum() if cfg['sampling']=='frequency' else None
        return rng.choice(names,n,p=weights).tolist()
    def distractor_words(self,w,cfg,rng):
        n=int(cfg['distractors'])
        if not n:return [],np.empty(0)
        pool,_=self.pool(cfg)
        candidates=list(rng.choice(pool,max(64,n*8)))
        neighbors=self.features(w).get('neighbors','').split('|')
        candidates+= [x for x in neighbors if x and x!=w]
        candidates=[x for x in candidates if x!=w]
        scores=np.array([similarity(w,x) for x in candidates])
        goal=float(cfg.get('similarity',0))
        # Similarity selects actual words; it is never inserted as a false measured score.
        order=np.argsort(np.abs(scores-goal))
        chosen=[candidates[i] for i in order[:n]]
        return chosen,np.array([similarity(w,x) for x in chosen])
    def familiarity(self,word,j):
        if j<=0:return 0.
        bi=math.log10(1+self.ng['bigram'].get(word[max(0,j-1):j+1],0))
        tr=math.log10(1+self.ng['trigram'].get(word[max(0,j-2):j+1],0)) if j>=2 else bi
        return .7*bi+.3*tr
