"""Six motion families. Positions in degrees, velocity in degrees/s.
Bounded-acceleration paths use colored acceleration, not clipped white velocity
noise, which would vanish or change law under time-step refinement.
"""
import math
import numpy as np
from numba import njit

@njit(cache=True)
def reflect_one(x,v,limit):
    if limit<=0:return 0.,0.
    while x>limit or x< -limit:
        if x>limit:x=2*limit-x;v=-abs(v)
        if x< -limit:x=-2*limit-x;v=abs(v)
    return x,v

@njit(cache=True)
def motion_step(x,v,a,origin,mu,t,dt,kind,speed,width,height,amax,predictability,rng):
    if speed<=0:return
    n=x.shape[0]
    omega=.65
    for i in range(n):
        if kind==2:
            amp=min(width*.20,height*.28,speed/omega)
            for d in range(2):
                phase=i*.71+d*.83
                x[i,d]=origin[i,d]+amp*.70*(math.sin(omega*t+phase)-math.sin(phase))
                v[i,d]=amp*.70*omega*math.cos(omega*t+phase)
        elif kind==3:
            # Unbounded-acceleration OU velocity, separately identified in results.
            rate=.45+2.*(1-predictability)
            for d in range(2):v[i,d]+=-rate*(v[i,d]-mu[i,d])*dt+speed*(1-predictability+.12)*math.sqrt(dt)*rng.normal()
        elif kind>=4:
            rate=2.0
            for d in range(2):
                a[i,d]+=-rate*a[i,d]*dt+amax*(1-predictability+.12)*math.sqrt(dt)*rng.normal()
                if kind==5:a[i,d]+=.35*amax*math.sin(.9*t+i+d)*dt
            norm=math.sqrt(a[i,0]**2+a[i,1]**2)
            if norm>amax:a[i]*=amax/norm
            ax=a[i,0]-.20*(v[i,0]-mu[i,0]);ay=a[i,1]-.20*(v[i,1]-mu[i,1])
            effective_norm=math.sqrt(ax*ax+ay*ay)
            if effective_norm>amax:ax*=amax/effective_norm;ay*=amax/effective_norm
            v[i,0]+=ax*dt;v[i,1]+=ay*dt
        vmax=1.8*speed
        norm=math.sqrt(v[i,0]**2+v[i,1]**2)
        if norm>vmax:v[i]*=vmax/norm
        for d in range(2):
            lim=(width if d==0 else height)/2
            if kind!=2:x[i,d]+=v[i,d]*dt
            if kind==0:
                if abs(x[i,d])>lim:x[i,d]=min(lim,max(-lim,x[i,d]));v[i,d]=0.
            else:
                oldv=v[i,d]
                x[i,d],v[i,d]=reflect_one(x[i,d],v[i,d],lim)
                if oldv*v[i,d]<0:a[i,d]*=-1;mu[i,d]*=-1

@njit(cache=True)
def trajectory_trace(seed,x0,v0,duration,dt,kind,speed,width,height,amax,pred,rng):
    n=int(math.ceil(duration/dt))+1
    out=np.empty((n,5));x=x0.reshape((1,2)).copy();v=v0.reshape((1,2)).copy()
    a=np.zeros((1,2));origin=x.copy();mu=v.copy()
    for j in range(n):
        out[j,0]=j*dt;out[j,1:3]=x[0];out[j,3:5]=v[0]
        motion_step(x,v,a,origin,mu,(j+1)*dt,dt,kind,speed,width,height,amax,pred,rng)
    return out
