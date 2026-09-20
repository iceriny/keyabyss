"""Offline extension contracts: additional atlas pages, resource teardown and removed globals."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT=Path(__file__).resolve().parents[1]
checks=[]
errors=[]
with sync_playwright() as p:
    browser=launch_browser(p)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator("#enterGame").click(timeout=30000)
    page.wait_for_function('!!window.__KEYABYSS__')
    assert page.evaluate("['KACore','KeyAbyssGame','KeyAbyssTypes','KeyAbyssElites','KeyAbyssChapters'].every(key=>!(key in window))")
    checks.append('offline startup and codex do not require legacy gameplay globals')
    result=page.evaluate("""async()=>{
      const g=__KEYABYSS__.game;
      await g.prepareRenderer();
      g.start({seed:'ATLAS-PAGES',book:'frost',mode:'normal',words:[{word:'crystal'}],progressive:false,vocabTitle:'test',vocabId:'test'});
      g.state='paused';
      const base=g.nativeRenderer,canvas=document.createElement('canvas');
      const appearances=[...g.content.appearances,...Array.from({length:16},(_,i)=>({id:'test-'+i,kind:'enemy',shape:'nib'}))];
      const frame={...base.port.frame,enemies:[],content:{...base.port.frame.content,appearances,enemies:{...g.content.enemies,extra:{...g.content.enemies.nib,appearance:'test-15'}}}};
      let losses=0;
      const native=new base.constructor(canvas,{frame,setDensity(){},contextLost(){losses++;},contextRestored(){},contextRestoreFailed(){}});
      await native.prepare();
      const target=native.actorTarget,Type=target.texture.type===1016?Uint16Array:Uint8Array;
      const before=new Type(target.width*target.height*4),after=new Type(before.length);
      native.renderer.readRenderTargetPixels(target,0,0,target.width,target.height,before);
      frame.enemies=[{...g.enemies[0],id:1001,type:'extra',x:640,y:350,grace:0}];native.render();
      native.renderer.readRenderTargetPixels(target,0,0,target.width,target.height,after);
      let changed=0;for(let i=0;i<before.length;i++)if(before[i]!==after[i])changed++;
      const handle=native.atlas.entries.get('test-15'),versions=native.atlas.pages.map(p=>p.version);
      for(let i=0;i<5;i++)native.render();
      const result={pages:native.atlas.pages.length,page:handle.page,instances:native.atlasInstances[handle.page],changed,stable:versions.every((v,i)=>v===native.atlas.pages[i].version)};
      frame.nodes=[];frame.corpses=[];frame.spirits=[];
      frame.enemies=[
        {...g.enemies[0],id:1001,type:'extra',x:640,y:380,grace:0},
        {...g.enemies[0],id:1002,type:'extra',x:640,y:340,grace:0},
        {...g.enemies[0],id:1003,type:'nib',x:640,y:360,grace:0},
      ];
      native.render();
      result.orderedPages=native.spriteRuns.filter(b=>b.count>0).map(b=>native.actorPages.findIndex(p=>p.material===b.material));
      result.worldOrder=frame.enemies.map(e=>e.id);
      native.dispose();native.dispose();canvas.dispatchEvent(new Event('webglcontextlost',{cancelable:true}));
      result.detached=losses===0;
      return result;
    }""")
    assert result['pages']==2 and result['page']==1 and result['instances']>0 and result['changed']>100,result
    checks.append('43 appearances allocate two pages and a second-page actor changes actual GPU pixels')
    assert result['orderedPages'][:3]==[1,0,1] and result['worldOrder']==[1001,1002,1003],result
    checks.append('transparent actors retain y ordering across repeated page switches without mutating world order')
    assert result['stable'],result
    checks.append('all atlas pages prewarm once and repeated frames do not upload textures')
    assert result['detached'],result
    checks.append('renderer disposal is idempotent and removes WebGL lifecycle listeners')
    assert page.evaluate("""()=>{const g=__KEYABYSS__.game;g.burst(400,300,80,'#fff');g.render();const before=g.nativeRenderer.particles.count;g.beginRoom();g.state='paused';g.render();return before>0&&g.nativeRenderer.particles.count===0;}""")
    checks.append('room entry clears particle instances and does not replay prior-room cues')
    assert not errors,errors
    browser.close()
for check in checks:print('PASS',check,flush=True)
output=ROOT/'docs/test-output-native/architecture-report.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps({'checks':checks,'errors':errors,'atlas':result},ensure_ascii=False,indent=2),encoding='utf-8')
