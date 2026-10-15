"""Create an offline lexical dataset from packaged, traceable corpus counts.
No synthetic frequencies or behavioral records are substituted for observations.
"""
from pathlib import Path
import json, hashlib, shutil, re
from collections import Counter, defaultdict
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]

def prepare():
    raw = ROOT / 'data/raw'; raw.mkdir(exist_ok=True, parents=True)
    path = raw / 'en-spelling.txt'
    if not path.exists():
        import textblob
        shutil.copy(Path(textblob.__file__).parent / 'en/en-spelling.txt', path)
    records=[]
    for line in path.read_text().splitlines():
        z=line.split()
        if len(z)==2 and re.fullmatch('[a-z]+',z[0]): records.append((z[0],int(z[1])))
    df=pd.DataFrame(records,columns=['word','count']); total=int(df['count'].sum())
    df['length']=df.word.str.len()
    df['corpus_logfreq']=9+np.log10(df['count']/total)
    # These are within-word count-weighted n-grams, not cross-word bigrams.
    bi=Counter(); tri=Counter()
    for w,c in records:
        for i in range(len(w)-1): bi[w[i:i+2]]+=c
        for i in range(len(w)-2): tri[w[i:i+3]]+=c
    def ngscore(w,d,n):
        xs=[np.log10(1+d[w[i:i+n]]) for i in range(len(w)-n+1)]
        return float(np.mean(xs)) if xs else 0.
    df['bigram_logcount']=df.word.map(lambda w:ngscore(w,bi,2))
    df['trigram_logcount']=df.word.map(lambda w:ngscore(w,tri,3))
    # Coltheart-style substitution neighbors in this finite corpus lexicon.
    patterns=defaultdict(list)
    for w in df.word:
        if len(w)<=16:
            for i in range(len(w)):patterns[w[:i]+'*'+w[i+1:]].append(w)
    neighbors={}
    for w in df.word:
        s=set()
        if len(w)<=16:
            for i in range(len(w)):s.update(patterns[w[:i]+'*'+w[i+1:]])
        s.discard(w); neighbors[w]=sorted(s)
    df['orthographic_neighbors']=df.word.map(lambda w:len(neighbors[w]))
    df['neighbors']=df.word.map(lambda w:'|'.join(neighbors[w]))
    df.to_csv(ROOT/'data/processed/lexicon.csv',index=False)
    (ROOT/'data/processed/ngrams.json').write_text(json.dumps({'bigram':bi,'trigram':tri},sort_keys=True))
    meta={'source':'TextBlob 0.19.0 packaged en-spelling.txt',
          'source_url':'https://raw.githubusercontent.com/sloria/TextBlob/dev/src/textblob/en/en-spelling.txt',
          'header_provenance':'Project Gutenberg public domain books; Wiktionary and British National Corpus frequency lists; Norvig big.txt',
          'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'tokens':total,'types':len(df),'logfreq_definition':'9 + log10(count / total corpus counts)',
          'limitation':'Historical mixed corpus; not SUBTLEX, not wordfreq Zipf scores, includes names and archaic forms.',
          'main_pool_size':int(((df.length>=3)&(df.length<=8)&(df['count']>=10)).sum())}
    (ROOT/'data/metadata/lexicon.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    print(json.dumps(meta,ensure_ascii=False,indent=2))
if __name__=='__main__': prepare()
