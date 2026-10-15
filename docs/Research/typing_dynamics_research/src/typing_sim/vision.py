"""Continuous scene + saccade/pursuit state machine + competing evidence races.
This is a mechanistic candidate model, not a claim to reconstruct real eye traces.
"""
import math
import numpy as np
from numba import njit
from .trajectories import motion_step
from .occlusion import crossing_visibility
from .config import TRAJECTORIES

EYE_STATES={0:'fixation',1:'saccade_preparation',2:'saccade',3:'smooth_pursuit',4:'reacquisition',5:'keyboard_glance'}
TRACE_COLUMNS=['time','gaze_x','gaze_y','target_x','target_y','state','evidence_true','evidence_rival',
               'visibility','eccentricity','crowding','attention_available','position_uncertainty','retinal_slip','selected']

@njit(cache=True)
def crowding_at(x,lengths,gaze,font,bouma):
    e=math.sqrt((x[0,0]-gaze[0])**2+(x[0,1]-gaze[1])**2)
    critical=.12+bouma*e
    value=0.
    target_half=lengths[0]*font*.28
    for i in range(1,x.shape[0]):
        dx=abs(x[i,0]-x[0,0]);dy=abs(x[i,1]-x[0,1])
        edge_x=max(0,dx-target_half-lengths[i]*font*.28)
        edge_y=max(0,dy-font)
        distance=math.sqrt(edge_x*edge_x+edge_y*edge_y)
        # Smooth bounded contribution computed from actual geometry.
        value+=math.exp(-.5*(distance/critical)**2)
    return value

@njit(cache=True)
def pick_candidate(x,gaze,similarities,cue,visited,t,rng):
    total=0.;weights=np.empty(x.shape[0])
    for i in range(x.shape[0]):
        e=math.sqrt((x[i,0]-gaze[0])**2+(x[i,1]-gaze[1])**2)
        salience=cue if i==0 else .55+.75*similarities[i-1]
        inhibition=.12 if t-visited[i]<.7 else 1.
        weights[i]=salience*inhibition/(1+.04*e)
        total+=weights[i]
    u=rng.random()*total;z=0
    for i in range(len(weights)):
        u-=weights[i]
        if u<=0:z=i;break
    return z

@njit(cache=True)
def eye_kernel(par,x0,v0,lengths,similarities,gaze0,busy,start_absolute,age_at_search,trace,
               world_rng,eye_rng,evidence_rng,occlusion_rng):
    dt=par[0];speed=par[1];width=par[2];height=par[3];kind=int(par[4]);amax=par[5];pred=par[6]
    font=par[7];lat=par[8];latcv=par[9];pursuitlat=par[10];gain=par[11];tau=par[12];pgain=par[13]
    catchup=par[14];bouma=par[15];drift=par[16];noise=par[17];threshold=par[18];max_t=par[19]
    duty=par[20];occ_dur=par[21];depth=par[22];cue=par[23]
    crowd_on=par[24]>0;pursuit_on=par[25]>0;prediction_on=par[26]>0;competition_on=par[27]>0
    attention_on=par[28]>0;fixed_eye=par[29]>0;sim=par[30];L=par[31]
    n=x0.shape[0];x=x0.copy();v=v0.copy();a=np.zeros_like(x);origin=x.copy();mu=v.copy()
    occ_remaining=occlusion_rng.exponential(occ_dur) if duty>0 and occlusion_rng.random()<duty else 0.
    rate=duty/max(occ_dur*(1-duty),1e-12)
    # Advance true environment from display onset, not from the observer's first look.
    for j in range(int(age_at_search/dt)):
        motion_step(x,v,a,origin,mu,(j+1)*dt,dt,kind,speed,width,height,amax,pred,world_rng)
        if occ_remaining>0:occ_remaining=max(0.,occ_remaining-dt)
        elif duty>0 and occlusion_rng.random()<1-math.exp(-rate*dt):occ_remaining=occlusion_rng.gamma(2.,occ_dur/2)
    gaze=gaze0.copy();eye_v=np.zeros(2)
    visited=np.full(n,-100.)
    sel=pick_candidate(x,gaze,similarities,cue,visited,0.,eye_rng)
    sigma=math.sqrt(math.log1p(latcv*latcv))
    remaining=lat*math.exp(eye_rng.normal()*sigma-.5*sigma*sigma)
    ecc0=math.sqrt((x[sel,0]-gaze[0])**2+(x[sel,1]-gaze[1])**2)
    state=0 if ecc0<.7 else 1
    fixation_start=0.;sacstart=gaze.copy();sacend=gaze.copy();sacdur=.025;sac_elapsed=0.
    estimate=x[sel].copy();est_v=np.zeros(2);Pxx=.10;Pxv=0.;Pvv=4.
    # Delayed retinal observations and predictive constant-velocity Kalman filter.
    delay_steps=max(1,int(round(pursuitlat/dt)))
    ring=np.empty((delay_steps+1,n,2))
    for j in range(delay_steps+1):ring[j]=x
    last_selected=sel
    since_hidden=0.;was_hidden=False;reacquire=0;loss=0;saccades=0
    E=0.;F=0.;acquired=-1.;attn_cost=0.;occ_total=0.;crowd_total=0.;rms=0.;pursuit_time=0.
    max_steps=int(math.ceil(max_t/dt));out=np.empty((max_steps+1,15)) if trace else np.empty((0,15))
    keyboard_active=False;keyboard_start=np.zeros(2);keyboard_age=0.
    success=0;recognized_time=max_t
    for j in range(max_steps):
        t=(j+1)*dt;abs_t=start_absolute+t
        motion_step(x,v,a,origin,mu,age_at_search+t,dt,kind,speed,width,height,amax,pred,world_rng)
        ring[j%(delay_steps+1)]=x
        old=ring[(j+1)%(delay_steps+1),sel]
        if occ_remaining>0:occ_remaining=max(0.,occ_remaining-dt)
        elif duty>0 and occlusion_rng.random()<1-math.exp(-rate*dt):occ_remaining=occlusion_rng.gamma(2.,occ_dur/2)
        visibility=(1-depth if occ_remaining>0 else 1.)*crossing_visibility(x,lengths,font)
        hidden=visibility<.1
        if hidden:since_hidden+=dt
        else:since_hidden=0.
        if hidden and not was_hidden:loss+=1
        if was_hidden and not hidden and since_hidden==0 and Pxx>.08:
            reacquire+=1
            if state!=2:state=4;remaining=lat*.8
        was_hidden=hidden
        occ_total+=(1-visibility)*dt
        load=0.;keyboard=False
        for k in range(busy.shape[0]):
            if busy[k,0]<=abs_t<busy[k,1]:
                if int(busy[k,3])==2:keyboard=True
                else:load+=busy[k,2]
        resource=max(0.,1-min(1.,load)) if attention_on else 1.
        if keyboard:
            if not keyboard_active:keyboard_start=gaze.copy();keyboard_age=0.
            keyboard_age+=dt
            u=min(1.,keyboard_age/.050);ease=u*u*(3-2*u)
            gaze[0]=keyboard_start[0]*(1-ease);gaze[1]=keyboard_start[1]*(1-ease)-18.*ease
            resource=0.;state=5;keyboard_active=True
        elif keyboard_active:
            keyboard_active=False;sel=0;state=4;remaining=lat
        attn_cost+=(1-resource)*dt
        # Kalman prediction is distinct from the true trajectory.
        if sel!=last_selected:
            estimate=x[sel].copy();est_v[:]=0.;Pxx=.15;Pxv=0.;Pvv=4.;last_selected=sel
        estimate+=est_v*dt
        q=par[38]
        Pxx=Pxx+2*dt*Pxv+dt*dt*Pvv+q*dt**3/3
        Pxv=Pxv+dt*Pvv+q*dt*dt/2;Pvv+=q*dt
        selected_visible=visibility if sel==0 else 1.
        if selected_visible>.05 and state!=2 and not keyboard:
            R=par[37]**2/max(selected_visible,.1)
            den=Pxx+R;Kx=Pxx/den;Kv=Pxv/den
            for d in range(2):
                obs=old[d]+eye_rng.normal()*par[37]
                innovation=obs-estimate[d]
                estimate[d]+=Kx*innovation;est_v[d]+=Kv*innovation
            oldp=Pxx;oldpv=Pxv
            Pxx=max(1e-8,(1-Kx)*oldp);Pxv=(1-Kx)*oldpv;Pvv=max(1e-8,Pvv-Kv*oldpv)
        predicted=estimate.copy()
        if prediction_on:predicted+=est_v*pursuitlat
        if not keyboard:
            if fixed_eye:
                # Fixed-delay ablation retains an actual smooth movement to the cue.
                u=min(1.,t/.24);gaze=gaze0+(x[0]-gaze0)*(u*u*(3-2*u));state=0 if u>=1 else 2
            elif state==1 or state==4:
                remaining-=dt
                if remaining<=0:
                    sacstart=gaze.copy()
                    amp=math.sqrt((predicted[0]-gaze[0])**2+(predicted[1]-gaze[1])**2)
                    sacdur=par[33]+par[34]*amp
                    sacend=predicted.copy()
                    if prediction_on:sacend+=est_v*sacdur
                    for d in range(2):sacend[d]+=eye_rng.normal()*(par[35]+par[36]*amp)
                    state=2;sac_elapsed=0.;saccades+=1
            elif state==2:
                sac_elapsed+=dt;u=min(1.,sac_elapsed/sacdur)
                f=10*u**3-15*u**4+6*u**5
                gaze=sacstart+(sacend-sacstart)*f
                if u>=1.:state=0;fixation_start=t;eye_v[:]=0.
            else:
                e_sel=math.sqrt((x[sel,0]-gaze[0])**2+(x[sel,1]-gaze[1])**2)
                if sel!=0 and t-fixation_start>.090:
                    visited[sel]=t;sel=pick_candidate(x,gaze,similarities,cue,visited,t,eye_rng)
                    state=1;remaining=lat*math.exp(eye_rng.normal()*sigma-.5*sigma*sigma)
                else:
                    if speed>0 and pursuit_on and t>pursuitlat:
                        state=3
                        for d in range(2):
                            command=gain*est_v[d]+pgain*(predicted[d]-gaze[d])
                            if selected_visible<.05 and not prediction_on:command=0.
                            accel=min(300.,max(-300.,(command-eye_v[d])/tau))
                            eye_v[d]+=accel*dt
                            eye_v[d]=min(35.,max(-35.,eye_v[d]))
                            gaze[d]+=eye_v[d]*dt
                        pursuit_time+=dt
                    if e_sel>catchup and t-fixation_start>.11:
                        state=4;remaining=lat*.8;reacquire+=1
        e=math.sqrt((x[0,0]-gaze[0])**2+(x[0,1]-gaze[1])**2)
        if e<1.0 and sel==0 and acquired<0 and state!=2 and visibility>.2:acquired=t
        crowded=crowding_at(x,lengths,gaze,font,bouma) if crowd_on else 0.
        crowd_total+=crowded*dt
        slip=math.sqrt((v[0,0]-eye_v[0])**2+(v[0,1]-eye_v[1])**2)
        rms+=e*e*dt
        # Average acuity over the actual positions of the letters.
        acuity=0.
        for letter in range(int(L)):
            lx=x[0,0]+(letter-(L-1)/2)*font*.56
            le=math.sqrt((lx-gaze[0])**2+(x[0,1]-gaze[1])**2)
            acuity+=math.exp(-(le/(.85+font*2.2))**1.45)
        acuity/=max(L,1.)
        size_factor=min(1.4,max(.12,(font/.38)**.6))
        motion_factor=1/(1+(slip/14.)**2)
        sensitivity=.025 if state==2 or state==5 else 1.
        evidence_dt=dt*resource*visibility*acuity*size_factor*motion_factor*sensitivity/(1+crowded)
        if sel!=0:evidence_dt*=.25
        last_E=E;last_F=F
        if evidence_dt>0:
            E=max(0.,E+drift*evidence_dt+noise*math.sqrt(evidence_dt)*evidence_rng.normal())
            if competition_on:
                competitor_ratio=.04+.68*sim**4
                F=max(0.,F+drift*competitor_ratio*evidence_dt+noise*math.sqrt(evidence_dt)*evidence_rng.normal())
        if trace:
            out[j]=np.array([t,gaze[0],gaze[1],x[0,0],x[0,1],state,E,F,visibility,e,crowded,resource,math.sqrt(Pxx),slip,sel])
        if E>=threshold or F>=threshold:
            cross_E=(threshold-last_E)/max(E-last_E,1e-12) if E>=threshold else 10.
            cross_F=(threshold-last_F)/max(F-last_F,1e-12) if F>=threshold else 10.
            success=1 if cross_E<=cross_F else -1
            recognized_time=t-dt+dt*min(cross_E,cross_F)
            if trace:out=out[:j+1]
            break
    else:
        if trace:out=out[:max_steps]
    if acquired<0:acquired=recognized_time
    summary=np.array([recognized_time,acquired,max(0.,recognized_time-acquired),success,saccades,
                      reacquire,loss,attn_cost,occ_total,crowd_total/max(recognized_time,dt),
                      math.sqrt(rms/max(recognized_time,dt)),pursuit_time])
    return summary,gaze,x[0].copy(),v[0].copy(),out

def encode_parameters(cfg,person,task,features,sim):
    freq=features['corpus_logfreq'];length=features['length']
    latent=cfg['recognition_base_s']+cfg['recognition_frequency_s']*max(0,5.5-freq)+cfg['recognition_length_s']*max(0,length-5)
    drift=1/(latent*person.lexical_scale)
    if task=='A':drift*=1+cfg['context_drift_gain']
    duty=cfg['occlusion_duty'] if cfg['occlusion_phase']!='after' else 0.
    return np.array([cfg['dt_s'],cfg['speed_deg_s'] if task=='D' else 0.,cfg['field_width_deg'],cfg['field_height_deg'],
        TRAJECTORIES[cfg['trajectory']],cfg['max_accel_deg_s2'],cfg['predictability'],cfg['font_height_deg'],
        cfg['saccade_latency_s']*person.saccade_scale,cfg['saccade_latency_cv'],cfg['pursuit_latency_s'],
        person.pursuit_gain,cfg['pursuit_tau_s'],cfg['pursuit_position_gain_s_inv'],cfg['catchup_threshold_deg'],
        cfg['bouma_factor'],drift,cfg['recognition_diffusion'],cfg['recognition_threshold'],cfg['max_recognition_s'],
        duty,cfg['occlusion_duration_s'],cfg['occlusion_depth'],cfg['cue_strength'],cfg['crowding'],cfg['pursuit'],
        cfg['prediction'],cfg['competition'],cfg['attention'],cfg['fixed_eye'],sim,length,0.,
        cfg['saccade_duration_intercept_s'],cfg['saccade_duration_s_per_deg'],cfg['saccade_endpoint_sd_deg'],
        cfg['saccade_endpoint_sd_per_deg'],cfg['sensory_observation_sd_deg'],cfg['position_process_noise']],dtype=float)
