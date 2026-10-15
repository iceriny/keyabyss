"""Ten-finger event scheduling, overlapping preparation, actual error repair.
Empirical transition intervals constrain press ordering; travel time is a max
constraint, not an extra delay added to an already complete empirical IKI.
"""
from dataclasses import dataclass,field
import math
import numpy as np
from .keyboard import key_for, HOME, nearest_letter, transition
from .scheduler import reserve_central

@dataclass
class MotorState:
    available: np.ndarray=field(default_factory=lambda:np.zeros(10))
    position: np.ndarray=field(default_factory=lambda:HOME.copy())
    previous_press: float=0.
    previous_key: str=' '
    previous_hand:int=0
    rhythm:float=0.

class Motor:
    def __init__(self,person,cfg,lexicon):
        self.p=person;self.cfg=cfg;self.lex=lexicon;self.state=MotorState()
        self.events=[]
    def _press(self,char,ready,index,word,history,rng,intervals,kind='letter',fatigue=1.):
        p=self.p;c=self.cfg;s=self.state;k=key_for(char,p.nonstandard,s.previous_hand)
        lookahead=p.lookahead if c['parallel'] else 0
        looktime=history[min(index-lookahead,len(history)-1)] if index>=lookahead and history and lookahead>0 else ready
        if not c['parallel']:looktime=s.previous_press
        duration=p.planning_s*p.motor_scale*fatigue/(1-c.get("tracking_attention",.12) if c["force_tracking"] else 1.)
        start=max(ready+max(0,index)*p.planning_gap_s,looktime)
        a,b=reserve_central(start,duration,intervals)
        intervals.append((a,b,1.,1))
        previous=s.previous_key
        cat=transition(previous,char) if previous in 'abcdefghijklmnopqrstuvwxyz ' and char in 'abcdefghijklmnopqrstuvwxyz ' else 'other'
        base=p.repeat_s if char==previous else p.alt_s
        if cat in ('left','same_finger'):base*=p.left_ratio if k.hand==0 else p.right_ratio
        elif cat=='right':base*=p.right_ratio
        if cat=='same_finger':base*=1.16
        if char=='\b':base=max(p.repeat_s,.075)*.87
        if char==' ':base*=.92
        fam= self.lex.familiarity(word,index) if 0<index<len(word) else 3.7
        seq_factor=math.exp(.038*(4.2-fam)) if c['sequence'] else math.exp(.038*4.2)
        # The ablated system has no sequence facilitation, not a new fitted baseline.
        if char in '\b \n':seq_factor=1.
        s.rhythm=.35*s.rhythm+math.sqrt(1-.35**2)*float(rng.normal(0,.18))
        gap=max(.014,base*p.motor_scale*fatigue*seq_factor*math.exp(s.rhythm-.5*.18**2)/c['speed_policy'])
        distance=float(np.linalg.norm(s.position[k.finger]-[k.x,k.y]))
        travel=(.028+.040*math.log2(1+distance/k.width))*math.sqrt(p.motor_scale)*fatigue
        # Preparation/positioning can happen while other fingers press earlier keys.
        move_start=max(b,s.available[k.finger])
        if not c['parallel']:move_start=max(move_start,s.previous_press)
        arrival=move_start+travel
        order_time=s.previous_press+gap
        press=max(arrival,order_time)
        hold=p.key_hold_s*float(rng.lognormal(-.5*.16**2,.16))
        release=press+hold
        bottleneck='movement' if arrival>=order_time else 'sequence'
        s.available[k.finger]=release;s.position[k.finger]=[k.x,k.y]
        s.previous_press=press;s.previous_key=char;s.previous_hand=k.hand
        ev={'time':press,'release':release,'key':char,'kind':kind,'finger':k.finger,'hand':k.hand,
            'plan_start':a,'plan_end':b,'move_start':move_start,'arrival':arrival,'transition':cat,
            'bottleneck':bottleneck,'x':k.x,'y':k.y}
        self.events.append(ev);history.append(press)
        return press

    def word(self,target,recognized,ready,previous_end,rng,elapsed,forced_refresh=None,prior_intervals=None):
        c=self.cfg;p=self.p;start_event=len(self.events)
        history=[];intervals=list(prior_intervals or []);prior_count=len(intervals);errors=[];buffer='';corrective_time=0.
        fatigue=1.
        if c['fatigue']:
            mins=elapsed/60
            fatigue=math.exp(p.fatigue_slope*max(0,mins-c['fatigue_start_min'])
                             -p.warmup_gain*(1-math.exp(-mins/.7))
                             +.009*math.sin(mins*2.1+p.arousal_phase))
        # Word-boundary commitment is a separate residual service. It is fitted
        # from whole-task WPM after fixing within-word timing, not added per key.
        boundary=c.get('boundary_delay_s',p.boundary_delay_s)*c.get('boundary_delay_multiplier',1.)
        if boundary>0:
            delay=boundary*math.sqrt(p.motor_scale)*fatigue*float(rng.lognormal(-.5*.25**2,.25))
            ba,bb=reserve_central(max(ready,previous_end),delay,intervals)
            intervals.append((ba,bb,1.,1))
            self.events.append({'time':bb,'kind':'word_program_commit','key':'','finger':-1,'hand':-1,
                                'release':bb,'plan_start':ba,'plan_end':bb})
            launch=bb
        else:launch=max(ready,0.)
        # Output order across word boundaries is immutable, even under preview.
        self.state.previous_press=max(self.state.previous_press,previous_end)
        planned=recognized
        error_p=p.error_p*(c['speed_policy']**2.2)*fatigue
        word_freq=self.lex.features(target)['corpus_logfreq']
        error_p*=1+.07*max(0,5-word_freq)
        def push(ch,j,kind='letter',gate=None):
            nonlocal launch,buffer
            t=self._press(ch,max(launch,gate or 0),j,planned,history,rng,intervals,kind,fatigue)
            if ch=='\b':buffer=buffer[:-1]
            elif ch not in (' ','\n'):buffer+=ch
            return t
        def repair(goal,stage):
            nonlocal launch,corrective_time
            before=self.state.previous_press
            # Detection is a cognitive event; repairs are actual keypresses.
            detect=float(rng.lognormal(math.log(.14),.2))
            launch=max(launch,before+detect)
            k=0
            while k<min(len(buffer),len(goal)) and buffer[k]==goal[k]:k+=1
            for _ in range(len(buffer)-k):push('\b',len(history),'backspace')
            for ch in goal[k:]:push(ch,len(history),'repair')
            corrective_time+=self.state.previous_press-before
            self.events.append({'time':before+detect,'kind':'error_detect','stage':stage,'key':'',
                                'finger':-1,'hand':-1,'release':before+detect})
        j=0
        while j<len(planned):
            ch=planned[j]
            if not c['memory'] and j>0:
                # No whole-word buffer: one-letter refresh with actual visual acquisition.
                # Caller supplies per-refresh continuous-eye recognition durations.
                refresh=.08 if forced_refresh is None else forced_refresh(j,self.state.previous_press)
                launch=max(launch,self.state.previous_press+refresh)
            event=None
            same_hand=key_for(ch,p.nonstandard).hand==self.state.previous_hand
            local_error_p=error_p*(1+.20*same_hand+.15*p.keyboard_look_p)
            if c['errors'] and rng.random()<min(.25,local_error_p):
                probs=np.array([.40,.15,.13,.13,.10,.09])
                typ=str(rng.choice(['adjacent','omission','repeat','transpose','coordination','planning'],p=probs))
                event={'index':j,'type':typ}
                if typ in ('adjacent','coordination','planning'):
                    push(nearest_letter(ch,rng),j)
                elif typ=='omission':
                    # A missed action has a preparation interval, but no press.
                    launch=max(launch,self.state.previous_press+p.planning_s)
                elif typ=='repeat':push(ch,j);push(ch,j)
                elif typ=='transpose' and j+1<len(planned):
                    push(planned[j+1],j);push(ch,j+1);j+=1
                else:push(ch,j)
                errors.append(event)
            else:push(ch,j)
            if event and c['correction']=='immediate' and rng.random()<p.detection_p:
                repair(planned[:j+1],'within_word')
            j+=1
        if c['correction']=='end' and buffer!=target:repair(target,'word_end')
        if c['correction']=='immediate' and buffer!=target:repair(target,'word_end_fallback')
        first_letter=next((e['time'] for e in self.events[start_event:] if e.get('key') not in ('','\b',' ')),self.state.previous_press)
        push(' ',len(history),'submit')
        if c['correction']=='submit' and buffer!=target:
            repair(target,'after_submit');push(' ',len(history),'submit')
        end=self.state.previous_press
        intervals.append((first_letter,end,p.motor_attention,0))
        if rng.random()<p.keyboard_look_p:
            # Gaze demand while hands are active, handled by the continuous eye model.
            a=first_letter; b=min(end,a+.24)
            if b>a:intervals.append((a,b,1.,2))
        return {'start':first_letter,'end':end,'buffer':buffer,'correct':buffer==target,
                'events':self.events[start_event:],'intervals':intervals[prior_count:],'errors':errors,
                'correction_s':corrective_time,'fatigue_factor':fatigue,
                'recognition_error':recognized!=target}
