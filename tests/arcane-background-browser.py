"""Shared GPU paper: autonomous motion, reduced motion, offline battle and budgets."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-arcane'; OUT.mkdir(exist_ok=True)
errors=[]; report={}
PIXELS="""()=>{const g=__KEYABYSS__.game;g.render();const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const x=c.getContext('2d');x.drawImage(g.canvas,0,0);const a=x.getImageData(0,0,c.width,c.height).data;let hash=0,sum=0;for(let i=0;i<a.length;i+=4){sum+=a[i]+a[i+1]+a[i+2];hash=(Math.imul(hash,31)+a[i]+a[i+1]*3+a[i+2]*7)|0;}return {hash,sum};}"""
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:false}));")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
 page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.wait_for_timeout(1700)
 a=page.evaluate(PIXELS);page.wait_for_timeout(1000);c=page.evaluate(PIXELS)
 assert a!=c, 'Background must animate without pointer movement'
 report['menuCalls']=page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.render.calls')
 assert report['menuCalls']==4,report
 page.screenshot(path=str(OUT/'home-1080.png'))
 # Isolate paper at fixed times to check it moves independently of dust and book rings.
 paper=page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,m=n.menu,u=m.backdrop.material.uniforms;
 const sample=t=>{u.time.value=t;n.renderer.render(m.scene,m.camera);const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const x=c.getContext('2d');x.drawImage(g.canvas,0,0);return Array.from(x.getImageData(0,0,c.width,c.height).data);};
 u.presence.value=1.;m.dust.points.visible=false;m.meshes.forEach(x=>x.visible=false);const a=sample(0),b=sample(6);let changed=0,diff=0;for(let i=0;i<a.length;i+=4){const d=Math.abs(a[i]-b[i])+Math.abs(a[i+1]-b[i+1])+Math.abs(a[i+2]-b[i+2]);if(d>0)changed++;diff+=d;}
 u.presence.value=.64;return {fraction:changed/(a.length/4),meanDifference:diff/(a.length/4)};}""")
 assert paper['fraction']>.2,(paper,errors)
 report['autonomousPaper']=paper
 print('paper',paper,flush=True)
 page.evaluate('__KEYABYSS__.game.render()')
 page.emulate_media(reduced_motion='reduce');page.wait_for_timeout(1600)
 a=page.evaluate(PIXELS);page.wait_for_timeout(300);assert page.evaluate(PIXELS)==a,(a,page.evaluate(PIXELS),page.evaluate('__KEYABYSS__.game.menuScene'))
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.menu.dust.points.visible')==False
 page.emulate_media(reduced_motion='no-preference');page.wait_for_timeout(100)
 page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'");page.locator('.battle-arrival').wait_for(state='detached')
 assert page.evaluate('(()=>{const g=__KEYABYSS__.game;return Math.abs(g.player.x*g.scale+g.ox-innerWidth/2)<1 && Math.abs(g.player.y*g.scale+g.oy-innerHeight/2)<1;})()'), 'Player must start at viewport center'
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.state='paused';g.visualTime=5;g.enemies=[];g.nodes=[];g.spawnClock=g.nodeClock=999;g.player.invuln=999;for(const [x,y] of [[390,320],[880,370],[650,530]]){const e=g.spawnEnemy('guard',x,y,false,true);e.word='archive';e.grace=0;e.speed=0;}g.render();}""")
 page.screenshot(path=str(OUT/'battle-1080.png'))
 a=page.evaluate(PIXELS);page.wait_for_timeout(250);assert page.evaluate(PIXELS)==a, 'Paused background must be pixel-stable'
 report['battle']=page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics()')
 # Inspect the actual central paper, excluding actors, particles and the visible effect ring.
 report['centralRefraction']=page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,r=n.renderer;
 g.fx=[{type:'burst',kind:'parry',x:640,y:400,r:180,max:.65,life:.65*.55,color:'#b9efdf',seed:17}];g.render();
 r.setRenderTarget(n.actorTarget);r.clear();const u=n.composite.material.uniforms;const oldBloom=u.bloomStrength.value,oldWarp=u.warpStrength.value;u.bloomStrength.value=0;
 const sample=strength=>{u.warpStrength.value=strength;r.setRenderTarget(null);r.render(n.composite.scene,n.screenCamera);const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const ctx=c.getContext('2d');ctx.drawImage(g.canvas,0,0);return ctx.getImageData(c.width/2-240,c.height/2-180,480,360).data;};
 const a=sample(0),b=sample(oldWarp);let changed=0,total=0,peak=0;for(let i=0;i<a.length;i+=4){let d=Math.abs(a[i]-b[i])+Math.abs(a[i+1]-b[i+1])+Math.abs(a[i+2]-b[i+2]);if(d>0)changed++;total+=d;peak=Math.max(peak,d);}
 u.bloomStrength.value=oldBloom;u.warpStrength.value=oldWarp;g.fx=[];g.render();return {changedFraction:changed/(a.length/4),meanDifference:total/(a.length/4),peakDifference:peak};}""")
 assert report['centralRefraction']['changedFraction']>.03,report['centralRefraction']
 for index,phase in enumerate([.2,.45,.7]):
  page.evaluate("""t=>{const g=__KEYABYSS__.game;g.fx=[{type:'burst',kind:'parry',x:640,y:400,r:180,max:.65,life:.65*(1-t),color:'#b9efdf',seed:17}];g.render();}""",phase)
  page.screenshot(path=str(OUT/f'wave-{index+1}.png'))
 page.evaluate('__KEYABYSS__.game.fx=[]')


 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.addField('gravity',880,370,190,4);g.fields[0].age=1;g.render();}""")
 warped=page.evaluate(PIXELS)
 page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.mesh.visible=false')
 assert page.evaluate(PIXELS)!=warped, 'Paper must participate in actual environment displacement'
 page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.mesh.visible=true;__KEYABYSS__.game.fields=[]')
 a=page.evaluate(PIXELS)
 page.evaluate("__KEYABYSS__.game.target=__KEYABYSS__.game.enemies[0];__KEYABYSS__.game.prefix='arc'")
 assert page.evaluate(PIXELS)!=a, 'Typing must still illuminate the scene'
 page.screenshot(path=str(OUT/'casting-1080.png'))
 page.evaluate("__KEYABYSS__.game.target=null;__KEYABYSS__.game.prefix=''")
 textures=page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.memory.textures')
 for fx in [.3,.7,1]:
  page.evaluate('(fx)=>{const g=__KEYABYSS__.game;g.options.fx=fx;g.nativeRenderer.resize();g.visualTime+=2;g.render();}',fx)
  assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.memory.textures')==textures
  page.screenshot(path=str(OUT/f'battle-fx-{fx}.png'))
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.options.reduceMotion=true;g.render();}""")
 a=page.evaluate(PIXELS)
 page.evaluate('__KEYABYSS__.game.visualTime+=10');assert page.evaluate(PIXELS)==a
 page.evaluate('__KEYABYSS__.game.options.reduceMotion=false')
 for w,h in [(1024,640),(3440,1440),(3840,2160)]:
  page.set_viewport_size({'width':w,'height':h});page.wait_for_timeout(100);page.evaluate(PIXELS)
  page.screenshot(path=str(OUT/f'battle-{w}.png'))
 page.set_viewport_size({'width':1920,'height':1080});page.wait_for_timeout(100)
 # Running simulation, wall-clock frame intervals and CPU render submission, not GPU timing.
 report['performance']=page.evaluate("""async()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer;g.state='playing';g.enemies=[];g.spawnClock=g.nodeClock=999;g.player.invuln=999;
 const times=[],cpu=[],original=n.render.bind(n);n.render=()=>{const t=performance.now();original();cpu.push(performance.now()-t);};let last=0;
 await new Promise(resolve=>{function frame(t){if(last)times.push(t-last);last=t;if(times.length<150)requestAnimationFrame(frame);else resolve();}requestAnimationFrame(frame);});n.render=original;g.state='paused';times.sort((a,b)=>a-b);cpu.sort((a,b)=>a-b);return {frames:times.length,fps:1000/(times.reduce((a,b)=>a+b,0)/times.length),frameP95:times[Math.floor(times.length*.95)],cpuSubmitP95:cpu[Math.floor(cpu.length*.95)],drawCalls:n.renderer.info.render.calls,textures:n.renderer.info.memory.textures};}""")
 page.evaluate('__KEYABYSS__.game.home()');page.wait_for_function('__KEYABYSS__.game.menuScene?.anchors.length>0')
 assert not errors,errors
 report['errors']=errors
 (OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(report,ensure_ascii=False,indent=2));b.close()

