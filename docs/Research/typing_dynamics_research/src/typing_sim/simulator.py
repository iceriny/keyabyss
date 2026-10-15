"""Max-plus discrete-event motor pipeline coupled to a continuous visual process."""
from dataclasses import replace
import math
import numpy as np
from .config import rng_stream,ROOT
from .vision import eye_kernel,encode_parameters,TRACE_COLUMNS
from .motor import Motor
from .memory import retrieve
from .metrics import score_words
from .lexicon import similarity
from .scheduler import EventQueue

class Simulator:
    def __init__(self,lexicon):self.lex=lexicon
    def session(self,person,task,cfg,repeat=0,trace=False):
        p=replace(person);seed=int(cfg['seed']);pid=int(p.person_id);duration=cfg['duration_s']
        if cfg.get('nonstandard',False):p.nonstandard=True
        # Capability manipulations act on mechanisms, not on a final WPM multiplier.
        p.motor_scale*=cfg.get('motor_scale_multiplier',1.)
        p.saccade_scale*=cfg.get('saccade_scale_multiplier',1.)
        p.lexical_scale*=cfg.get('lexical_scale_multiplier',1.)
        p.pursuit_gain*=cfg.get('pursuit_gain_multiplier',1.)
        p.motor_attention*=cfg.get('attention_multiplier',1.)
        p.lookahead=max(1,int(round(p.lookahead*cfg.get('lookahead_multiplier',1.))))
        p.fatigue_slope*=cfg.get('fatigue_multiplier',1.)
        motor=Motor(p,cfg,self.lex)
        word_rng=rng_stream(seed,pid,repeat,module=2)
        words=self.lex.sample_words(cfg,word_rng,max(300,int(duration*6)),task)
        gaze=np.array([0.,0.]);eye_free=0.;previous_end=0.;previous_start=0.
        prior_intervals=[];records=[];traces=[];scene_events=[];failures=0;previous_reveal=0.
        queue=EventQueue()
        for wi,word in enumerate(words):
            preview=cfg['preview'] and cfg['memory'] and not cfg['force_tracking']
            spawn=0. if wi==0 else previous_reveal if preview else previous_end
            search_start=max(spawn,eye_free)
            if search_start>=duration:break
            f=self.lex.features(word)
            scene_rng=rng_stream(seed,pid,repeat,wi,3)
            dw,simarr=self.lex.distractor_words(word,cfg,scene_rng)
            n=1+len(dw)
            x0=scene_rng.uniform([-cfg['field_width_deg']/2,-cfg['field_height_deg']/2],
                                 [cfg['field_width_deg']/2,cfg['field_height_deg']/2],size=(n,2))
            if task in ('A','B'):x0[0]=[(-1 if wi%2==0 else 1)*cfg['fixed_slot_x_deg'],0.]
            if cfg['trajectory']=='periodic':x0*=.35
            angles=scene_rng.uniform(0,2*np.pi,n)
            speed=cfg['speed_deg_s'] if task=='D' else 0.
            v0=np.column_stack((np.cos(angles),np.sin(angles)))*speed
            lengths=np.array([len(word)]+[len(w) for w in dw],dtype=float)
            neighbors=[w for w in str(f.get('neighbors','')).split('|') if w]
            internal=neighbors[0] if neighbors else word
            internal_sim=.6*similarity(word,internal) if internal!=word else 0.
            strongest=float(simarr.max()) if len(simarr) else internal_sim
            rival=dw[int(np.argmax(simarr))] if len(dw) else internal
            pars=encode_parameters(cfg,p,task,f,strongest)
            busy=np.array([iv for iv in prior_intervals if iv[1]>search_start],dtype=float).reshape((-1,4))
            summary,new_gaze,final_target,final_velocity,tr=eye_kernel(pars,x0,v0,lengths,simarr,gaze,busy,
                search_start,max(0.,search_start-spawn),bool(trace),
                rng_stream(seed,pid,repeat,wi,4),rng_stream(seed,pid,repeat,wi,5),
                rng_stream(seed,pid,repeat,wi,6),rng_stream(seed,pid,repeat,wi,9))
            visual_duration,acquisition,recognition,success=summary[:4]
            ready=search_start+visual_duration
            if trace:
                if len(tr):tr[:,0]+=search_start
                traces.append((wi,tr))
                queue.push(spawn,'target_appear',{'word_index':wi,'word':word})
                queue.push(ready,'recognition_complete',{'word_index':wi,'word':word,'success':int(success)})
            if success==0:
                failures+=1
                # Mandatory-correction task cannot silently skip an unread target.
                # Stop this censored session instead of entering an infinite retry loop.
                break
            recognized=word if success>0 else rival
            stored,memfail=retrieve(recognized,max(0,previous_end-ready),p,cfg,
                                    rng_stream(seed,pid,repeat,wi,8)) if cfg['memory'] else (recognized,False)
            gaze=new_gaze
            def refresh(j,when):
                nonlocal gaze
                tiny=dict(f);tiny['length']=1
                rp=encode_parameters(cfg,p,task,tiny,strongest)
                xx=x0.copy();xx[0,0]+=(min(j,len(word)-1)-(len(word)-1)/2)*cfg['font_height_deg']*.56
                ll=lengths.copy();ll[0]=1
                rs,gg,_,_,rr=eye_kernel(rp,xx,v0,ll,simarr,gaze,np.empty((0,4)),when,
                    max(0.,when-spawn),False,rng_stream(seed,pid,repeat,wi,4),
                    rng_stream(seed,pid,repeat,wi,50+j),rng_stream(seed,pid,repeat,wi,100+j),
                    rng_stream(seed,pid,repeat,wi,9))
                gaze=gg
                return float(rs[0])
            z=motor.word(word,stored,ready,previous_end,rng_stream(seed,pid,repeat,wi,7),
                previous_end,forced_refresh=refresh if not cfg['memory'] else None,prior_intervals=prior_intervals)
            end=z['end']
            prior_intervals=[iv for iv in prior_intervals if iv[1]>ready]+z['intervals']
            visual_stall=max(0.,ready-previous_end)
            service=max(0.,end-max(ready,previous_end))
            rec=dict(person_id=pid,group=p.group,task=task,repeat=repeat,word_index=wi,word=word,typed=z['buffer'],
                length=len(word),corpus_logfreq=f['corpus_logfreq'],reveal_time=spawn,search_start=search_start,
                recognized_time=ready,first_key=z['start'],submit_time=end,correct=z['correct'],
                acquisition_s=float(acquisition),recognition_s=float(recognition),visual_service_s=float(visual_duration),
                visual_stall_s=float(visual_stall),motor_service_s=float(service),
                attention_lost_s=float(summary[7]),occlusion_s=float(summary[8]),crowding=float(summary[9]),
                tracking_rms_deg=float(summary[10]),pursuit_s=float(summary[11]),saccades=int(summary[4]),
                reacquisitions=int(summary[5]),target_losses=int(summary[6]),motor_errors=len(z['errors']),
                recognition_error=success<0,memory_error=memfail,correction_s=z['correction_s'],
                actual_similarity=strongest,fatigue_factor=z['fatigue_factor'])
            records.append(rec)
            if trace:
                for e in z['events']:
                    ev=dict(e);ev['word_index']=wi
                    queue.push(ev['time'],ev.get('kind','key'),ev)
                for err in z['errors']:
                    scene_events.append(dict(word_index=wi,**err))
            if end>duration:break
            if cfg['force_tracking']:
                # Continue the same physical target while the word is being typed.
                hold=max(0.,end-ready)
                if hold>cfg['dt_s']:
                    pp=pars.copy();pp[19]=hold;pp[18]=1e8;pp[16]=0.
                    if cfg['occlusion_phase']=='after':pp[20]=cfg['occlusion_duty']
                    ss,gg,_,_,rr=eye_kernel(pp,x0,v0,
                        lengths,simarr,gaze,np.empty((0,4)),ready,max(0.,ready-spawn),bool(trace),
                        rng_stream(seed,pid,repeat,wi,4),rng_stream(seed,pid,repeat,wi,205),
                        rng_stream(seed,pid,repeat,wi,206),rng_stream(seed,pid,repeat,wi,9))
                    gaze=gg
                    if trace:
                        rr[:,0]+=ready;traces.append((wi,rr))
                eye_free=end
            else:eye_free=ready
            previous_start=z['start'];previous_end=end
            letters=[e['time'] for e in z['events'] if e.get('key') and e.get('key') not in ('\b',' ')]
            frac=float(cfg.get('preview_fraction',0.))
            previous_reveal=end if frac>=1. or not letters else letters[min(len(letters)-1,int(frac*len(letters)))]
        metrics=score_words(records,motor.events,duration)
        finished=[w for w in records if w['submit_time']<=duration]
        def mean(k):return float(np.mean([w[k] for w in finished])) if finished else 0.
        for name in ['acquisition_s','recognition_s','visual_service_s','motor_service_s','correction_s','attention_lost_s',
                     'tracking_rms_deg','crowding','actual_similarity','fatigue_factor']:
            metrics['mean_'+name]=mean(name)
        for name in ['visual_stall_s','motor_service_s','correction_s','attention_lost_s','target_losses','reacquisitions','saccades']:
            metrics['total_'+name]=float(sum(w[name] for w in finished))
        metrics['visual_bottleneck_fraction']=metrics['total_visual_stall_s']/duration
        metrics['motor_bottleneck_fraction']=metrics['total_motor_service_s']/duration
        key_events=[e for e in motor.events if e.get('key') and e['time']<=duration]
        ts=[e['time'] for e in key_events]
        metrics['mean_iki_s']=float(np.mean(np.diff(ts))) if len(ts)>1 else 0.
        metrics['rollover_fraction']=float(np.mean([key_events[i]['time']<key_events[i-1]['release'] for i in range(1,len(key_events))])) if len(key_events)>1 else 0.
        metrics['recognition_error_rate']=float(np.mean([w['recognition_error'] for w in finished])) if finished else 0.
        metrics['person_id']=pid;metrics['group']=p.group;metrics['task']=task;metrics['repeat']=repeat
        metrics['duration_s']=duration;metrics['failure_count']=failures;metrics['seed']=seed
        metrics['preview']=int(cfg['preview']);metrics['speed_deg_s']=speed;metrics['dt_s']=cfg['dt_s']
        event_stream=[]
        if trace:
            while queue:
                ev=queue.pop()
                if ev.time<=duration:event_stream.append({'time':ev.time,'kind':ev.kind,'payload':ev.payload})
        return metrics,records,{'eyes':traces,'keys':key_events,'events':event_stream,'errors':scene_events}
