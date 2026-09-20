"""Real Three voice graph: 64 simultaneous sources, priority and per-cue limits."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-audio';OUT.mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=launch_browser(p);page=browser.new_page()
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached')
    result=page.evaluate('''()=>{
      const s=__KEYABYSS__.game.sound;
      s.stopEffects();s.update({x:640,y:400},'playing',false);
      const buffer=s.ctx.createBuffer(1,s.ctx.sampleRate*2,s.ctx.sampleRate);
      // Actual AudioBufferSource/Panner nodes, silent fixture to avoid a loud test burst.
      const start=(spatial,id,priority)=>{const v=s.voice(spatial,id,priority);if(v){v.audio.setBuffer(buffer);v.audio.duration=undefined;v.audio.play();}return v;};
      for(let i=0;i<48;i++)start(true,'pool-'+i,1);
      for(let i=0;i<16;i++)start(false,'ui-pool-'+i,1);
      const full=s.diagnostics();
      const refused=!start(true,'overflow',1)&&!start(false,'overflow-ui',1);
      const stolen=!!start(true,'important',6);
      const bounded=s.voices===64&&s.pool.length===64;
      s.stopEffects();
      const peek=s.cache.peek;s.cache.peek=()=>buffer;
      const counts={};
      try{
        for(const id of ['cast.frost','impact.frost','key','ui.type']){
          s.stopEffects();
          for(let i=0;i<12;i++){s.last.delete(id);s.play(id);}
          counts[id]=s.voices;
        }
      }finally{s.cache.peek=peek;s.stopEffects();s.update({x:640,y:400},'home',false);}
      return {limits:full.voiceLimits,simultaneous:full.voices,refused,stolen,bounded,counts,stopped:s.voices};
    }''')
    assert result['simultaneous']==64 and result['limits']=={'spatial':48,'nonSpatial':16},result
    assert result['refused'] and result['stolen'] and result['bounded'],result
    assert result['counts']=={'cast.frost':6,'impact.frost':8,'key':8,'ui.type':8},result
    assert result['stopped']==0 and not errors,(result,errors)
    print('PASS 64 real concurrent voices, bounded priority replacement, per-cue 6/8 limits and full stop',flush=True)
    browser.close()
(OUT/'polyphony.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
