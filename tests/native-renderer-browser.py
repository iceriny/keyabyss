"""1080P native rendering contracts, visual states, lifecycle and running combat.
Run after build; performance samples are collected only after functional checks.
"""
from pathlib import Path
import json, sys
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-output-native'
OUT.mkdir(exist_ok=True)
checks, errors, requests, performance = [], [], [], []
performance_only = '--performance-only' in sys.argv

def check(name):
    checks.append(name)
    print('PASS', name, flush=True)

def shot(page, name):
    page.evaluate('__KEYABYSS__.game.render()')
    page.screenshot(path=str(OUT / f'{name}.png'))

SETUP = """async book => {
  const g=__KEYABYSS__.game;
  await g.prepareRenderer();
  g.start({book,mode:'normal',words:[{word:'crystal'},{word:'thunder'},{word:'gravity'},{word:'fold'}],vocabTitle:'原生战场验证',seed:'NATIVE-1080'});
  g.sound.enabled=false;g.enemies=[];g.nodes=[];g.spawnClock=g.nodeClock=999;g.roomQuota=999;g.player.invuln=999;
  for(const [type,x,y] of [['guard',760,320],['quill',990,470],['vortex',300,400],['ram',440,260]]) {
    const e=g.spawnEnemy(type,x,y,false,true);e.grace=0;e.hp=e.maxHp=999999;e.speed=0;
  }
  g.state='paused';g.visualTime=1;g.invalidate();
}"""

with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width':1920,'height':1080}, device_scale_factor=1)
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
    page.on('request', lambda r: requests.append(r.url))
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator("#enterGame").click(timeout=30000)
    page.wait_for_function('!!window.__KEYABYSS__')
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.ready')
    assert any('battle-renderer-' in url for url in requests)
    check('startup gate prepares the native renderer before deliberate entry')
    diag = {}
    if not performance_only:
        page.evaluate(SETUP, 'frost')
        diag = page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics()')
        assert diag['resolution']==[1920,1080] and diag['displacement']==diag['bloom']==[960,540],diag
        assert page.evaluate("__KEYABYSS__.game.canvas.getContext('2d')===null")
        assert not any(url.startswith('http') for url in requests),requests
        assert diag['ready'] and diag['atlasVersion']==1,diag
        assert page.evaluate("""()=>{const n=__KEYABYSS__.game.nativeRenderer,t=n.actorTarget;
          const buffer=t.texture.type===1016?new Uint16Array(t.width*t.height*4):new Uint8Array(t.width*t.height*4);
          n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,buffer);
          let count=0;for(let i=3;i<buffer.length;i+=4)if(buffer[i])count++;return count>500;
        }""")
        shot(page,'idle-1080')
        check('offline WebGL battle contains actual actors with 1080P / 540P targets')
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.target=g.enemies[0];g.target.word='crystal';g.prefix='cry';g.render();}""")
        shot(page,'charge-1080')
        assert page.evaluate("__KEYABYSS__.game.castLabel.text==='cry'")
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.impact(760,320,g.bookData.color,1,'ice');g.fx.forEach(f=>f.life=f.max*.65);g.render();}""")
        shot(page,'impact-1080')
        check('idle, typing charge and ordinary hit have distinct native light feedback')
        assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().particles > 0')
        particle_state = page.evaluate("""()=>{const n=__KEYABYSS__.game.nativeRenderer;
          n.renderer.setRenderTarget(null);return {count:n.particles.count, textures:n.renderer.info.memory.textures};}""")
        # Read the GPU actor buffer directly: DOM screenshots also include animated HUD ornaments.
        assert page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,t=n.actorTarget;
          const Type=t.texture.type===1016?Uint16Array:Uint8Array;
          const before=new Type(t.width*t.height*4),after=new Type(before.length);
          n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,before);
          g.render();g.render();
          n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,after);
          return before.every((value,index)=>value===after[index]);
        }""")
        assert page.evaluate('__KEYABYSS__.game.nativeRenderer.particles.count') == particle_state['count']
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.fx=[];g.particles=[];
          for(let i=0;i<65;i++){g.updateVisual(1/60);g.render();}}""")
        assert page.evaluate('__KEYABYSS__.game.nativeRenderer.particles.count') == 0
        assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.memory.textures') == particle_state['textures']
        check('Quarks bursts emit, freeze pixel-exactly on pause and expire without new textures')

        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.fx=[];g.particles=[];g.addField('gravity',870,420,190,4);g.fields[0].age=1;g.render();}""")
        labels_before = page.evaluate('__KEYABYSS__.game.overlay.toDataURL()')
        warped = page.locator('#world').screenshot()
        shot(page,'gravity-1080')
        page.evaluate("__KEYABYSS__.game.nativeRenderer.warp.mesh.visible=false;__KEYABYSS__.game.render()")
        unwarped = page.locator('#world').screenshot()
        assert warped != unwarped
        assert labels_before == page.evaluate('__KEYABYSS__.game.overlay.toDataURL()')
        page.evaluate("__KEYABYSS__.game.nativeRenderer.warp.mesh.visible=true;__KEYABYSS__.game.render()")
        check('local displacement changes actual environment pixels while text stays identical')
        for school in ['frost','storm','spirit']:
            page.evaluate(SETUP,school)
            page.evaluate("""()=>{const g=__KEYABYSS__.game;g.state='playing';g.resonance=100;g.input('Shift');
              for(let i=0;i<18;i++){g.update(1/90);g.updateVisual(1/90);}g.state='paused';g.render();}""")
            shot(page,f'{school}-ultimate-1080')
            assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().instances.effects>10')
        check('all three books render their real ultimate, field and projectile states')
        page.evaluate(SETUP,'spirit')
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];
          Object.keys(__KEYABYSS__.game.content.enemies).forEach((type,i)=>{const e=g.spawnEnemy(type,180+(i%6)*180,230+Math.floor(i/6)*130,false,true);e.grace=0;});g.render();}""")
        shot(page,'enemy-atlas-1080')
        assert page.evaluate('Object.keys(__KEYABYSS__.game.content.enemies).every(type=>__KEYABYSS__.game.nativeRenderer.atlas.entries.has(type))')
        for chapter in range(3):
            page.evaluate("""chapter=>{const g=__KEYABYSS__.game;g.enemies=[];g.chapter=chapter;g.spawnBoss();g.boss.grace=0;g.render();}""",chapter)
            shot(page,f'boss-{chapter+1}-1080')
        check('every enemy silhouette and all three bosses are uploaded in the resident atlas')
        page.evaluate("""()=>{const g=__KEYABYSS__.game;window.atlasVersion=g.nativeRenderer.atlas.texture.version;window.textureCount=g.nativeRenderer.renderer.info.memory.textures;
          for(let i=0;i<12;i++){g.updateVisual(1/60);g.render();}}""")
        assert page.evaluate('window.atlasVersion===__KEYABYSS__.game.nativeRenderer.atlas.texture.version && window.textureCount===__KEYABYSS__.game.nativeRenderer.renderer.info.memory.textures')
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.originalRender=g.render;g.renderCount=0;g.render=function(){this.renderCount++;this.originalRender();};g.renderDirty=false;}""")
        page.wait_for_timeout(250)
        assert page.evaluate('__KEYABYSS__.game.renderCount')==0
        check('frames reuse textures without uploads; paused combat stops rendering')
        page.set_viewport_size({'width':1280,'height':720})
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.options.fx=.3;g.options.reduceMotion=true;g.invalidate();g.render();}""")
        assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().instances.warp===0')
        shot(page,'low-motion-720')
        check('720P and reduced motion retain readable actors and disable displacement')
        # Real WebGL context loss pauses gameplay; restoration rebuilds warm resources.
        page.evaluate("""()=>{const g=__KEYABYSS__.game;g.setState('playing');g.nativeRenderer.renderer.forceContextLoss();}""")
        page.wait_for_function("__KEYABYSS__.game.nativeRenderer.lost && __KEYABYSS__.game.state==='paused'")
        page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.forceContextRestore()')
        page.wait_for_function('__KEYABYSS__.game.nativeRenderer.ready && !__KEYABYSS__.game.nativeRenderer.lost')
        check('context loss pauses combat and restored resources are prewarmed')
        page.set_viewport_size({'width':1920,'height':1080})
    # Measurements happen at the end, on moving simulations, never a frozen frame.
    for scenario in ['combat','dense','fields','ultimate']:
        page.evaluate(SETUP,'storm')
        page.evaluate("""scenario=>{const g=__KEYABYSS__.game;g.options.fx=1;g.options.reduceMotion=false;g.enemies=[];g.boss=null;g.bossRoom=false;
          const count=scenario==='dense'?24:8;
          for(let i=0;i<count;i++){const e=g.spawnEnemy(['guard','quill','mortar'][i%3],180+(i%6)*180,230+Math.floor(i/6)*85,false,true);e.hp=e.maxHp=999999;e.grace=0;}
          if(scenario==='fields') for(let i=0;i<6;i++){g.addField(['gravity','storm','frost'][i%3],300+i%3*320,300+Math.floor(i/3)*200,150,20);g.fields.at(-1).age=1;}
          if(scenario==='ultimate'){g.resonance=100;g.state='playing';g.input('Shift');}
          for(let i=0;i<(scenario==='dense'?96:24);i++)g.bullet(150+i%16*60,260+Math.floor(i/16)*45,i*.4,80,'#e9b29b');
          g.player.invuln=999;g.state='playing';g.render=g.originalRender||g.render;g.invalidate();
        }""",scenario)
        page.wait_for_timeout(350)
        sample=page.evaluate("""()=>new Promise(resolve=>{const g=__KEYABYSS__.game,gaps=[],submits=[];
          const render=g.render;g.render=function(){const start=performance.now();render.call(this);submits.push(performance.now()-start);};
          const start=performance.now(),elapsed=g.elapsed;let previous=start;
          const percentile=(a,p)=>a.slice().sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))];
          function frame(now){gaps.push(now-previous);previous=now;
            if(now-start<2200){requestAnimationFrame(frame);return;}
            g.render=render;resolve({frames:gaps.length,seconds:(now-start)/1000,fps:gaps.length*1000/(now-start),frameP50:percentile(gaps,.5),frameP95:percentile(gaps,.95),submitP50:percentile(submits,.5),submitP95:percentile(submits,.95),simulatedSeconds:g.elapsed-elapsed,renderer:g.nativeRenderer.diagnostics()});
          }requestAnimationFrame(frame);
        })""")
        sample['scenario']=scenario;performance.append(sample)
        assert sample['simulatedSeconds']>0
        page.evaluate("__KEYABYSS__.game.state='paused'")
    check('final 1080P running-combat samples include dense bullets, multiple fields and an ultimate')
    page.evaluate('__KEYABYSS__.game.home()')
    assert not errors,errors
    browser.close()

(OUT/('performance.json' if performance_only else 'report.json')).write_text(json.dumps({'checks':checks,'errors':errors,'initial':diag,'performance':performance,'environment':'Windows headless Chrome; 1920x1080 DPR 1; moving combat; RAF/CPU submit times, not GPU timer queries'},ensure_ascii=False,indent=2),encoding='utf-8')
