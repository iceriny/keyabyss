"""ANSI QWERTY key geometry in key-pitch units, including all ten finger states."""
from dataclasses import dataclass
import numpy as np

@dataclass(frozen=True)
class Key:
    name:str
    x:float
    y:float
    finger:int
    hand:int
    width:float=.9
    shift:bool=False

# 0..3 left pinky/ring/middle/index; 4/5 thumbs; 6..9 right index/middle/ring/pinky.
KEYS={}
for chars,offset,y,fingers in [
    ('qwertyuiop',0.,0.,[0,1,2,3,3,6,6,7,8,9]),
    ('asdfghjkl',.25,1.,[0,1,2,3,3,6,6,7,8]),
    ('zxcvbnm',.75,2.,[0,1,2,3,3,6,6])]:
    for i,(c,f) in enumerate(zip(chars,fingers)):
        KEYS[c]=Key(c,i+offset,y,f,0 if f<5 else 1)
KEYS[' ']=Key(' ',4.8,3.,5,1,5.8)
KEYS['\b']=Key('\b',12.,0.,9,1,1.8)
KEYS['\n']=Key('\n',11.8,1.,9,1,1.8)
KEYS['SHIFT_L']=Key('SHIFT_L',-.6,2.,0,0,1.5)
KEYS['SHIFT_R']=Key('SHIFT_R',11.,2.,9,1,1.5)
for c,x in [(',',7.75),('.',8.75),('/',9.75)]: KEYS[c]=Key(c,x,2.,8 if c==',' else 9,1)
HOME=np.array([[.25,1.],[1.25,1.],[2.25,1.],[3.25,1.],[4.0,3.],[5.0,3.],
               [6.25,1.],[7.25,1.],[8.25,1.],[9.25,1.]])

def key_for(c, nonstandard=False, previous_hand=0):
    k=KEYS[c.lower()] if c not in KEYS else KEYS[c]
    if c==' ':
        f=4 if previous_hand==1 else 5
        return Key(c,k.x,k.y,f,0 if f==4 else 1,k.width)
    if nonstandard and c.isalpha():
        return Key(c,k.x,k.y,3 if k.hand==0 else 6,k.hand,k.width)
    return k

def transition(a,b):
    if a==b: return 'repeat'
    ka,kb=key_for(a),key_for(b)
    if ka.finger==kb.finger:return 'same_finger'
    if ka.hand==kb.hand:return 'left' if kb.hand==0 else 'right'
    return 'alternation'

def nearest_letter(c,rng):
    if c not in KEYS or not c.isalpha():return c
    k=KEYS[c]; names=[x for x in KEYS if len(x)==1 and x.isalpha() and x!=c]
    ds=np.array([(KEYS[x].x-k.x)**2+(KEYS[x].y-k.y)**2 for x in names])
    ids=np.argsort(ds)[:4]
    return names[int(rng.choice(ids))]

def pixel_to_deg(px, width_px=1920,width_cm=53.1,distance_cm=60.):
    return np.degrees(2*np.arctan(np.asarray(px)*width_cm/width_px/(2*distance_cm)))
