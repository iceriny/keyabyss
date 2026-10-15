"""Deterministic resource reservations; intervals are half-open [start, end)."""
from dataclasses import dataclass, field
import heapq

@dataclass(order=True)
class Event:
    time:float
    serial:int
    kind:str=field(compare=False)
    payload:object=field(compare=False,default=None)

class EventQueue:
    def __init__(self):self.heap=[];self.serial=0
    def push(self,time,kind,payload=None):
        if time<0:raise ValueError('Negative event time')
        self.serial+=1;heapq.heappush(self.heap,Event(time,self.serial,kind,payload))
    def pop(self):return heapq.heappop(self.heap)
    def __bool__(self):return bool(self.heap)

def reserve_central(start,duration,intervals):
    """Only planning (kind=1) is an exclusive central resource.
    Motor execution has fractional attention load and can overlap planning.
    """
    t=max(0.,float(start))
    for a,b,load,kind in sorted(intervals,key=lambda x:x[0]):
        if kind==1 and t<b and t+duration>a:t=b
    return t,t+duration

def interval_union_length(intervals,lo=0.,hi=float('inf')):
    xs=sorted((max(a,lo),min(b,hi)) for a,b in intervals if b>lo and a<hi)
    total=0.;end=lo
    for a,b in xs:
        if b>max(a,end):total+=b-max(a,end)
        end=max(end,b)
    return total
