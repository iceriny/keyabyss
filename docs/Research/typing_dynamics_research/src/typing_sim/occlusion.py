"""Spatial overlap and temporal full/partial masks."""
from dataclasses import dataclass
import numpy as np
from numba import njit

@dataclass(frozen=True)
class Occluder:
    left:float
    bottom:float
    right:float
    top:float
    opacity:float=1.
    def visible_fraction(self,box):
        l,b,r,t=box
        overlap=max(0,min(r,self.right)-max(l,self.left))*max(0,min(t,self.top)-max(b,self.bottom))
        return float(np.clip(1-self.opacity*overlap/max((r-l)*(t-b),1e-12),0,1))

@njit(cache=True)
def crossing_visibility(x,lengths,font):
    """Fraction of target word box not geometrically overlapped by distractors.
    The target occupies the back layer in this stress configuration.
    """
    tw=lengths[0]*font*.56; area=max(tw*font,1e-10);hidden=0.
    for i in range(1,len(lengths)):
        dw=lengths[i]*font*.56
        ox=max(0.,min(x[0,0]+tw/2,x[i,0]+dw/2)-max(x[0,0]-tw/2,x[i,0]-dw/2))
        oy=max(0.,font-abs(x[0,1]-x[i,1]))
        hidden+=ox*oy
    return max(.0,1-min(hidden/area,1.))
