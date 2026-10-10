"""Arcana384 engraved-v4: deterministic, weight-compatible closed contours.
Render all contours of a centerline in one nonzero SVG path to preserve counters.
"""
import math, random, hashlib
from svgpathtools import parse_path

def unit(z):return z/abs(z) if abs(z)>1e-8 else 1+0j
def cross(a,b):return (a.conjugate()*b).imag
def area(a):return sum(cross(a[i],a[(i+1)%len(a)]) for i in range(len(a)))/2

def points(sp):
 p=[]
 for seg in sp:
  steps=1 if seg.__class__.__name__=='Line' else max(5,math.ceil(seg.length(error=1e-5)/1.1))
  # Subdivide straight lines too so pressure changes have fixed topology.
  steps=max(steps,math.ceil(seg.length(error=1e-5)/1.8))
  if not p:p.append(complex(seg.start))
  for j in range(1,steps+1):
   z=complex(seg.point(j/steps))
   if abs(z-p[-1])>1e-7:p.append(z)
 return p

def endpoint_profile(seed,subpath,is_end,angle,length):
 """Fixed design decisions, independent of requested variable weight."""
 key=f"arcana384-v4:{seed}:{subpath}:{'end' if is_end else 'start'}"
 rng=random.Random(int.from_bytes(hashlib.blake2s(key.encode(),digest_size=8).digest(),'big'))
 # Use nominal nib thickness, never the current variable width, for context bias.
 nominal=5.6*(.70+.56*abs(math.sin(angle-math.radians(-32))))
 short=length/nominal<3.8
 pick=rng.random()
 thresholds=(.58,.85,.98) if short else (.45,.70,.90)
 kind='plain' if pick<thresholds[0] else 'worn' if pick<thresholds[1] else 'chip' if pick<thresholds[2] else 'split'
 plain_slant=(rng.random()<.58)
 lean=(rng.uniform(-.10,.10) if kind=='plain' and not plain_slant else rng.uniform(-.38,.38))
 lean+=.06*math.sin(2*angle+.4)
 return {'kind':kind,'lean':lean,'wear':rng.uniform(.07,.23),
         'depth':rng.uniform(.13,.30) if kind=='split' else rng.uniform(.14,.31),
         'bias':rng.uniform(-.32,.32),'chip_side':-1 if rng.random()<.5 else 1,
         'center':rng.uniform(.40,.60),'span':rng.uniform(.20,.29),
         'positions':(.16+rng.uniform(-.025,.025),.34+rng.uniform(-.02,.02),.52+rng.uniform(-.025,.025),.71+rng.uniform(-.02,.02),.87+rng.uniform(-.02,.02))}

def cap_points(a,b,outward,profile):
 """Five compatible points: cap categories stay fixed for every master."""
 d=b-a;r=abs(d)/2;result=[]
 for t in profile['positions']:
  h=0.;kind=profile['kind']
  if kind=='worn':
   h=profile['wear']*math.sin(math.pi*t)**.82*(1+profile['bias']*(2*t-1))
  elif kind=='chip':
   center=.17 if profile['chip_side']<0 else .85
   h=-profile['depth']*max(0.,1-abs(t-center)/.245)
  elif kind=='split':
   h=-profile['depth']*max(0.,1-abs(t-profile['center'])/profile['span'])
  result.append(a+d*t+outward*(r*h))
 return result

def outlines(d,width=5.6,seed=0):
 out=[]
 for spi,sp in enumerate(parse_path(d).continuous_subpaths()):
  pts=points(sp)
  if len(pts)<2:continue
  closed=abs(pts[-1]-pts[0])<1e-6
  if closed:pts.pop()
  n=len(pts); distances=[0]
  for i in range(1,n):distances.append(distances[-1]+abs(pts[i]-pts[i-1]))
  total=distances[-1]+(abs(pts[-1]-pts[0]) if closed else 0)
  ue=unit(pts[-1]-pts[-2]);us=unit(pts[1]-pts[0])
  start_profile=endpoint_profile(seed,spi,False,math.atan2(us.imag,us.real),total)
  end_profile=endpoint_profile(seed,spi,True,math.atan2(ue.imag,ue.real),total)
  rng=random.Random(7103+seed*137+spi*997)
  cuts=[]
  count=max(3,int(total/20))
  for k in range(count):
   center=total*(k+.3+.4*rng.random())/count
   cuts.append((center,1 if (k+seed)%2==0 else -1,rng.uniform(1.4,3.0),rng.uniform(2.0,4.0),rng.uniform(.16,.38)))
  def radius(i,side):
   u=unit(pts[min(i+1,n-1)]-pts[max(i-1,0)]) if not closed else unit(pts[(i+1)%n]-pts[(i-1)%n])
   angle=math.atan2(u.imag,u.real); orient=abs(math.sin(angle-math.radians(-32)))
   r=width/2*(.70+.56*orient)
   t=distances[i]/total
   if not closed:
    s=min(t,1-t);r*=.77+.29*min(s/.045,1)-.06*min(s/.16,1)
   # Smooth pressure drift tied to path position rather than random noise.
   r*=1+.045*math.sin(2*math.pi*(1.0 if closed else 1.15)*t+seed*.61)
   r*=1+.025*math.sin(2*math.pi*t+seed*.73)*side
   # Light tool facets and multiple irregular, asymmetric gouges.
   cycles=max(3,round(total/17))
   tri=lambda z: 1-4*abs((z%1)-.5)
   r*=1+.045*tri(t*cycles+seed*.17+side*.23)
   r*=1+.022*math.sin(2*math.pi*(cycles+3)*t+side*1.9+seed)
   for center,cutside,leftspan,rightspan,depth in cuts:
    if cutside!=side:continue
    delta=distances[i]-center
    h=max(0,1-abs(delta)/(leftspan if delta<0 else rightspan))
    r*=1-depth*h
   return r
  sides=[]
  for side in (1,-1):
   a=[]
   for i,p in enumerate(pts):
    r=radius(i,side)
    if not closed and i in (0,n-1):
     u=unit(pts[1]-p) if i==0 else unit(p-pts[-2]);normal=u*1j*side
     profile=start_profile if i==0 else end_profile
     cut=profile['lean']*side*r
     a.append(p+normal*r+u*cut)
     continue
    u=unit(p-pts[(i-1)%n]);v=unit(pts[(i+1)%n]-p);nu=u*1j*side;nv=v*1j*side
    turn=math.atan2(cross(u,v),(u.conjugate()*v).real)
    if abs(turn)<1e-5:a.append(p+nu*r)
    elif turn*side<0 and abs(turn)>.12:
     # Chamfered carved outer join: two small faceted shoulders.
     a.extend([p+nu*r,p+(nu+nv)*r/(max(.6,abs(nu+nv))),p+nv*r])
    else:
     m=(nu+nv)/max(1+(u.conjugate()*v).real,1e-6)
     if abs(m)>2.4:m=unit(m)*2.4
     a.append(p+m*r)
   sides.append(a)
  if closed:
   outer,inner=sorted(sides,key=lambda p:abs(area(p)),reverse=True)
   if area(outer)<0:outer.reverse()
   if area(inner)>0:inner.reverse()
   out.extend([outer,inner])
  else:
   # Endpoint-specific wear: mostly intact cuts, occasional asymmetric chips.
   L,R=sides[0],sides[1]
   endcut=cap_points(L[-1],R[-1],ue,end_profile)
   startcut=cap_points(R[0],L[0],-us,start_profile)
   a=L+endcut+R[::-1]+startcut
   if area(a)<0:a.reverse()
   out.append(a)
 return ['M'+' L'.join(f'{z.real:.3f} {z.imag:.3f}' for z in a)+' Z' for a in out]
