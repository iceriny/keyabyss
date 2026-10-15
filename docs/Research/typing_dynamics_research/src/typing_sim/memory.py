"""Word-level retention; recognition is not a requirement to continue tracking."""
import math
from .keyboard import nearest_letter

def memory_failure_probability(age,length,half_life,interference=0.):
    if half_life<=0:return 1.
    # Sparse retrieval failure, not complete decay of every stored word each second.
    hazard=.006*(max(0,age)/half_life)**1.3*(length/5)**2*(1+interference)
    return -math.expm1(-hazard)

def retrieve(word,age,person,cfg,rng):
    half=person.memory_half_life*cfg['memory_half_life_s']/8
    p=memory_failure_probability(age,len(word),half,cfg['distractors']*.02)
    if rng.random()>=p:return word,False
    if not word:return word,False
    i=int(rng.integers(len(word)))
    return word[:i]+nearest_letter(word[i],rng)+word[i+1:],True
