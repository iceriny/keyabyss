import numpy as np
import pytest
from typing_sim.config import load_config,draw_person,rng_stream,GROUPS
from typing_sim.lexicon import Lexicon,edit_distance,similarity
from typing_sim.keyboard import HOME,KEYS,pixel_to_deg
from typing_sim.motor import Motor
from typing_sim.trajectories import trajectory_trace
from typing_sim.occlusion import Occluder
from typing_sim.scheduler import EventQueue,interval_union_length,reserve_central
from typing_sim.memory import memory_failure_probability
from typing_sim.metrics import score_words,aligned_correct_letters
from typing_sim.simulator import Simulator

@pytest.fixture(scope='module')
def lex():return Lexicon()
@pytest.fixture(scope='module')
def sim(lex):return Simulator(lex)

@pytest.mark.parametrize('kind',range(6))
def test_bounds(kind):
    r=np.random.default_rng(411)
    z=trajectory_trace(411,np.array([0.,0.]),np.array([2.,1.]),20.,.005,kind,3.,12.,8.,10.,.7,r)
    assert np.max(np.abs(z[:,1]))<=6+1e-10
    assert np.max(np.abs(z[:,2]))<=4+1e-10
    assert np.isfinite(z).all()

def test_bounded_acceleration_interior():
    z=trajectory_trace(1,np.array([0.,0.]),np.array([2.,1.]),2.,.002,4,3.,200.,200.,12.,.6,np.random.default_rng(9))
    # The complete acceleration, including reversion, obeys the configured cap.
    acc=np.linalg.norm(np.diff(z[:,3:5],axis=0)/.002,axis=1)
    assert acc.max()<=12.+1e-8

def test_occlusion():
    assert Occluder(0,0,1,1).visible_fraction((0,0,1,1))==0
    assert Occluder(0,0,.5,1).visible_fraction((0,0,1,1))==.5
    assert Occluder(2,2,3,3).visible_fraction((0,0,1,1))==1

def test_keyboard_geometry():
    assert HOME.shape==(10,2)
    assert all(c in KEYS for c in 'abcdefghijklmnopqrstuvwxyz \b\n')
    assert .35<float(pixel_to_deg(14))<.4

def test_lexical(lex):
    assert edit_distance('cat','cut')==1
    assert similarity('cat','cut')>similarity('cat','ship')
    assert lex.features('the')['corpus_logfreq']>lex.features('algorithm')['corpus_logfreq']
    p,c=lex.pool(load_config())
    assert len(p)==5875 and min(map(len,p))>=3 and max(map(len,p))<=8

def test_rng_streams():
    assert np.array_equal(rng_stream(4,2,1,0,3).normal(size=10),rng_stream(4,2,1,0,3).normal(size=10))
    assert not np.array_equal(rng_stream(4,2,1,0,3).normal(size=10),rng_stream(4,2,1,0,4).normal(size=10))

def test_event_queue():
    q=EventQueue();q.push(.2,'b');q.push(.1,'a');q.push(.1,'c')
    assert [q.pop().kind for _ in range(3)]==['a','c','b']
    with pytest.raises(ValueError):q.push(-1,'bad')

def test_resource_reservation():
    a,b=reserve_central(.15,.1,[(.1,.3,1,1),(.3,.4,1,1)])
    assert a>=.4 and b>a
    assert abs(interval_union_length([(0,2),(1,3),(4,5)])-4)<1e-10

def test_motor_sequence_and_overlap(lex):
    p=draw_person('expert',22,fixed=True);m=Motor(p,load_config(errors=False,fatigue=False),lex)
    z=m.word('animation','animation',0.,0.,np.random.default_rng(3),0.)
    ev=[e for e in z['events'] if e.get('key')]
    assert ''.join(e['key'] for e in ev)=='animation '
    assert np.all(np.diff([e['time'] for e in ev])>0)
    assert all(e['move_start']<=e['arrival']<=e['time']<e['release'] for e in ev)
    assert any(ev[i]['move_start']<ev[i-1]['time'] for i in range(1,len(ev)))
    for f in range(10):
        xs=[e for e in ev if e['finger']==f]
        assert all(xs[i]['move_start']>=xs[i-1]['release'] for i in range(1,len(xs)))

@pytest.mark.parametrize('strategy',['immediate','end','submit'])
def test_real_repairs(lex,strategy):
    p=draw_person('ordinary',22,fixed=True);p.error_p=.2
    m=Motor(p,load_config(correction=strategy),lex)
    z=m.word('garden','garment',0.,0.,np.random.default_rng(1),0.)
    assert z['buffer']=='garden'
    assert any(e.get('key')=='\b' for e in z['events'])
    assert len(z['events'])<150
    assert z['correction_s']>0

def test_no_correction(lex):
    p=draw_person('expert',22,fixed=True);m=Motor(p,load_config(errors=False,correction='none'),lex)
    z=m.word('garden','garment',0.,0.,np.random.default_rng(1),0.)
    assert not z['correct'] and z['buffer']=='garment'

def test_metrics_and_censoring():
    words=[dict(submit_time=2,correct=True,word='cat',typed='cat',motor_errors=0,recognition_error=False,memory_error=False),
           dict(submit_time=61,correct=True,word='dog',typed='dog',motor_errors=0,recognition_error=False,memory_error=False)]
    a=score_words(words,[dict(time=1,key='c')],60)
    assert a['wpm5']==.8 and a['actual_wpm']==1 and a['cpm']==4 and a['lpm']==3
    assert aligned_correct_letters('cat','caat')==(3,1)
    assert aligned_correct_letters('cat','cut')==(2,1)

def test_memory_probability():
    p=memory_failure_probability(3,8,5)
    assert 0<=p<=1
    assert p>memory_failure_probability(1,8,5)
    assert memory_failure_probability(0,8,5)==0

def test_reproducible_session(sim):
    p=draw_person('expert',118);c=load_config(duration_s=8)
    a,wa,_=sim.session(p,'D',c);b,wb,_=sim.session(p,'D',c)
    assert a==b and wa==wb

def test_scene_and_eye_states(sim):
    p=draw_person('expert',121);c=load_config(duration_s=8,distractors=4,occlusion_duty=.2)
    a,w,tr=sim.session(p,'D',c,trace=True)
    for _,x in tr['eyes']:
        assert set(x[:,5].astype(int))<=set(range(6))
        assert np.all((x[:,8]>=0)&(x[:,8]<=1))
        assert np.all((x[:,11]>=0)&(x[:,11]<=1))
        assert np.max(np.abs(x[:,3]))<=c['field_width_deg']/2+1e-10
        assert np.max(np.abs(x[:,4]))<=c['field_height_deg']/2+1e-10
    assert a['cpm']==5*a['wpm5'] and a['cpm']==a['lpm']+a['actual_wpm']

@pytest.mark.parametrize('g',GROUPS)
def test_baseline_finite(sim,g):
    p=draw_person(g,126);a,w,_=sim.session(p,'D',load_config(duration_s=6))
    assert 0<=a['wpm5']<300 and a['failure_count']==0
    assert all(z['submit_time']>=z['recognized_time']>=z['reveal_time'] for z in w)
    assert all(z['correct'] for z in w)

def test_after_encoding_occlusion_no_memory_cost(sim):
    p=draw_person('expert',110);c=load_config(duration_s=10)
    a,_,_=sim.session(p,'D',c)
    c.update(occlusion_duty=.4,occlusion_phase='after')
    b,_,_=sim.session(p,'D',c)
    assert a['wpm5']==b['wpm5']
    # Structural invariance, not external human validation.

def test_no_preview_and_memory_off_run(sim):
    p=draw_person('expert',130)
    for changes in [dict(preview=0),dict(memory=False),dict(force_tracking=True)]:
        a,_,_=sim.session(p,'D',load_config(duration_s=8,**changes))
        assert np.isfinite(a['wpm5']) and a['wpm5']>=0

def test_word_boundary_commitment_is_separate(lex):
    p=draw_person('expert',42,fixed=True)
    a=Motor(p,load_config(errors=False,boundary_delay_s=0.,fatigue=False),lex).word('language','language',0.,0.,np.random.default_rng(123),0.)
    b=Motor(p,load_config(errors=False,boundary_delay_s=.4,fatigue=False),lex).word('language','language',0.,0.,np.random.default_rng(123),0.)
    assert b['end']>a['end']
    assert sum(e['kind']=='word_program_commit' for e in b['events'])==1
    assert sum(e['kind']=='word_program_commit' for e in a['events'])==0
    assert ''.join(e['key'] for e in b['events'] if e.get('key'))=='language '
