"""Check actual inverse UV mapping in four quadrants, then capture a travelling front."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-shockwave';OUT.mkdir(exist_ok=True)
errors=[];checks=[]
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
 page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.state='paused';g.cancel();g.enemies=[];g.nodes=[];g.fields=[];g.bullets=[];g.shake=0;g.kickX=0;g.kickY=0;g.visualTime=2;g.options.fx=1;g.options.reduceMotion=false;
 window.waveAt=(kind,t)=>{g.fx=[{type:'burst',kind,x:640,y:400,r:115,max:.65,life:.65*(1-t),color:'#b9efdf',seed:17}];g.render();};}""")
 # Unequal side columns and changing counters must not move the chapter/wave center.
 for width,height in [(2560,1440),(1920,1080),(1280,720),(800,600),(480,800)]:
  page.set_viewport_size({'width':width,'height':height})
  layout=page.evaluate("""()=>{const chapter=document.querySelector('.chapter-block'),actions=document.querySelector('.battle-actions');actions.firstElementChild.textContent='99:59 · 12345 击破';const c=chapter.getBoundingClientRect(),a=actions.getBoundingClientRect(),h=document.querySelector('.hud-top').getBoundingClientRect();return {center:c.x+c.width/2,visible:c.width>0,right:a.right,edge:h.right};}""")
  if width>600:assert abs(layout['center']-width/2)<1,layout
  else:assert not layout['visible'],layout
  assert abs(layout['right']-layout['edge'])<1,layout
 page.set_viewport_size({'width':1920,'height':1080})
 checks.append('chapter/wave remains viewport-centered at four desktop sizes; compact HUD keeps actions right-aligned')
 # UV ramps reveal the sign of the actual composite lookup, not merely the field vector.
 probes=page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,r=n.renderer,env=n.environment.material;
 const shader=env.fragmentShader;const samples=[];
 const capture=()=>{const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const ctx=c.getContext('2d');ctx.drawImage(g.canvas,0,0);return {data:ctx.getImageData(0,0,c.width,c.height).data,w:c.width};};
 for(const kind of ['parry','shock','implosion']){
   waveAt(kind,.4);const rect=n.warp.attributes[0].array,style=n.warp.attributes[1].array;const radius=rect[2]/2*style[3];
   env.fragmentShader='varying vec2 vUv;void main(){gl_FragColor=vec4(.5+(vUv.x-.5)*2.,.5+(vUv.y-.5)*2.,.1,1.);}';env.needsUpdate=true;
   r.setRenderTarget(n.environmentTarget);r.render(n.environment.scene,n.screenCamera);r.setRenderTarget(n.actorTarget);r.clear();n.composite.material.uniforms.bloomStrength.value=0;
   n.composite.material.uniforms.warpStrength.value=0;r.setRenderTarget(null);r.render(n.composite.scene,n.screenCamera);const flat=capture();
   n.composite.material.uniforms.warpStrength.value=2.8;r.render(n.composite.scene,n.screenCamera);const warped=capture();
   const result={kind};for(const [name,dx,dy] of [['right',1,0],['left',-1,0],['down',0,1],['up',0,-1],['center',0,0]]){
     const x=Math.round((640+dx*radius-n.camera.left)/(n.camera.right-n.camera.left)*g.canvas.width),y=Math.round((400+dy*radius-n.camera.top)/(n.camera.bottom-n.camera.top)*g.canvas.height);const i=(y*flat.w+x)*4;
     result[name]=[warped.data[i]-flat.data[i],warped.data[i+1]-flat.data[i+1]];
   }samples.push(result);env.fragmentShader=shader;env.needsUpdate=true;
 }g.render();return samples;}""")
 for item in probes:
  sign=1 if item['kind']=='implosion' else -1
  assert item['right'][0]*sign>0 and item['left'][0]*sign<0,item
  assert item['up'][1]*sign>0 and item['down'][1]*sign<0,item
  assert max(abs(x) for x in item['center'])<=1,item
  assert abs(item['right'][1])<=1 and abs(item['up'][0])<=1,item
 checks.append('GPU UV ramps confirm outward displacement in all quadrants, inward implosion, no central twist')
 radii=[]
 page.evaluate("""()=>{const g=__KEYABYSS__.game;for(let i=0;i<16;i++){const a=i/16*Math.PI*2;const e=g.spawnEnemy('guard',640+Math.cos(a)*150,400+Math.sin(a)*150,false,true);e.grace=0;}}""")
 for index,t in enumerate([.12,.3,.52,.76]):
  page.evaluate('t=>waveAt("parry",t)',t)
  radii.append(page.evaluate('(()=>{const w=__KEYABYSS__.game.nativeRenderer.warp;return w.attributes[0].array[2]/2*w.attributes[1].array[3]})()'))
  page.screenshot(path=str(OUT/f'wave-{index+1}.png'))
 assert all(a<b for a,b in zip(radii,radii[1:])),radii
 for kind in ['shock','ultimate','electric','flame','shard','implosion']:
  page.evaluate('kind=>waveAt(kind,.4)',kind)
  assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.count')==1,kind
 flame_ratio=page.evaluate("""()=>{waveAt('shock',.4);const reference=__KEYABYSS__.game.nativeRenderer.warp.attributes[1].array[1];waveAt('flame',.4);return __KEYABYSS__.game.nativeRenderer.warp.attributes[1].array[1]/reference;}""")
 assert abs(flame_ratio-.55)<1e-5,flame_ratio
 page.evaluate('waveAt("parry",1)');assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.count')==0
 checks.append('all six explosive effects share the travelling front; parry expands across frames and fully expires')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.fx=[];g.fields=[];g.addField('gravity',640,400,150,4);g.fields[0].age=1;g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.attributes[1].array[2]')==0
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.fields=[];g.addField('fire',640,400,150,4);g.fields[0].age=1;g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.attributes[1].array[2]')==2
 assert 0<page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.attributes[1].array[1]')<=2.7
 page.screenshot(path=str(OUT/'heat-and-centered-hud-1080.png'))
 page.evaluate('__KEYABYSS__.game.options.reduceMotion=true;__KEYABYSS__.game.render()');assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.count')==0
 checks.append('flame explosion displacement is 55 percent of other waves; heat strength stays below 2.7; reduced motion removes displacement')
 assert not errors,errors
 b.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'probes':probes,'radii':radii,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
for check in checks:print('PASS',check,flush=True)
