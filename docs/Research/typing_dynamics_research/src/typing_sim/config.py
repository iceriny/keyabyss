"""Configuration, hierarchical participant parameters, and independent RNG streams."""
from dataclasses import dataclass, asdict
from pathlib import Path
import numpy as np
import yaml

ROOT=Path(__file__).resolve().parents[2]
GROUPS=('beginner','ordinary','skilled','expert','elite')
GROUP_CN={'beginner':'初学者','ordinary':'普通用户','skilled':'熟练者','expert':'高水平高手','elite':'顶尖情景'}
TRAJECTORIES={'linear':0,'bounce':1,'periodic':2,'ou':3,'ou_accel':4,'mixed':5}

def load_config(**changes):
    cfg=yaml.safe_load((ROOT/'configs/baseline.yaml').read_text())
    cfg.update(yaml.safe_load((ROOT/'configs/visual.yaml').read_text()))
    cfg.update(changes)
    if cfg['dt_s']<=0 or cfg['duration_s']<=0: raise ValueError('Times must be positive')
    if not 0<=cfg['occlusion_duty']<1: raise ValueError('occlusion_duty must be in [0, 1)')
    return cfg

def rng_stream(seed:int, person:int=0, repeat:int=0, word:int=0, module:int=0):
    """Streams do not depend on process order or task count; C/D share stimuli."""
    return np.random.default_rng(np.random.SeedSequence([int(seed),int(person),int(repeat),int(word),int(module)]))

@dataclass
class Person:
    group: str
    person_id: int
    alt_s: float
    left_ratio: float
    right_ratio: float
    repeat_s: float
    motor_scale: float
    planning_s: float
    planning_gap_s: float
    lookahead: int
    motor_attention: float
    lexical_scale: float
    saccade_scale: float
    pursuit_gain: float
    error_p: float
    detection_p: float
    keyboard_look_p: float
    memory_half_life: float
    fatigue_slope: float
    warmup_gain: float
    arousal_phase: float
    key_hold_s: float
    nonstandard: bool=False
    boundary_delay_s: float=0.

    def to_dict(self): return asdict(self)

def population_templates():
    p=ROOT/'configs/population.yaml'
    if p.exists(): return yaml.safe_load(p.read_text())
    raise FileNotFoundError('Run scripts/fit_parameters.py first')

def draw_person(group, person_id, seed=20261014, fixed=False):
    z=population_templates()[group]; r=rng_stream(seed,person_id,module=1)
    cv=z['between_motor_cv']; sigma=np.sqrt(np.log1p(cv*cv))
    shared=1. if fixed else float(r.lognormal(-sigma*sigma/2,sigma))
    # No skill-group advantage is imposed on elementary visual physiology.
    lex=1. if fixed else float(r.lognormal(-.5*.12**2,.12))
    sac=1. if fixed else float(r.lognormal(-.5*.12**2,.12))
    return Person(group,person_id,z['alt_s'],z['left_ratio'],z['right_ratio'],z['repeat_s'],
        shared,z['planning_s'],z['planning_gap_s'],z['lookahead'],z['motor_attention'],lex,sac,
        float(.93 if fixed else np.clip(r.normal(.93,.035),.78,1.02)),
        z['error_p']*(1 if fixed else float(r.lognormal(-.5*.20**2,.20))),
        z['detection_p'],z['keyboard_look_p'],
        8. if fixed else float(r.lognormal(np.log(8),.35)),
        .008 if fixed else float(np.clip(r.normal(.008,.007),-.008,.032)),
        .015 if fixed else float(np.clip(r.normal(.015,.015),-.03,.06)),
        0. if fixed else float(r.uniform(0,2*np.pi)), z['key_hold_s'],
        boundary_delay_s=float(z.get('boundary_delay_s',0.)))
