"""Actual GPU displacement and stable label priority/click selection at 1080p."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-counter';OUT.mkdir(exist_ok=True)
checks=[];errors=[]
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
 page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 result=page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];g.nodes=[];g.bullets=[];g.state='paused';g.options.reduceMotion=false;
 for(let i=0;i<24;i++){const e=g.spawnEnemy(i===1?'scribe':'nib',600+(i%4)*18,290+Math.floor(i/4)*20,false,true);e.word=i===0?'cat':'reinterpret_cast';e.grace=0;}
 g.target=g.enemies[0];g.render();const ls=g.labels;const top=ls.at(-1);const before=ls.map(l=>({id:l.target.id,x:l.x,y:l.y}));
 const clicked=g.overlayPainter.hitTest(top.x+top.w/2,top.y+top.h/2);g.enemies[5].x+=1;g.render();
 return {count:ls.length,top:top.target.id,lock:g.target.id,clicked,stable:g.labels.every(l=>{const old=before.find(o=>o.id===l.target.id);return Math.abs(l.x-old.x-(l.target===g.enemies[5]?1:0))<.001&&l.y===old.y;})};}""")
 assert result['count']==24 and result['top']==result['lock']==result['clicked'] and result['stable'],result
 page.screenshot(path=str(OUT/'priority-labels-1080.png'))
 checks.append('24 overlapping labels remain owner-anchored and hit testing follows locked topmost text')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.cancel();g.enemies=[];g.player.x=640;g.player.y=400;
 for(let i=0;i<12;i++){const a=i/12*Math.PI*2;const e=g.spawnEnemy('guard',640+Math.cos(a)*125,400+Math.sin(a)*125,false,true);e.grace=0;}
 g.fx=[];g.player.parrySuccess=false;g.parryFeedback();g.fx=g.fx.filter(f=>f.kind==='parry');g.fx.forEach(f=>f.life=f.max*.75);g.options.fx=1;g.render();}""")
 delta=page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,r=n.renderer;
 const capture=()=>{const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const ctx=c.getContext('2d');ctx.drawImage(g.canvas,0,0);return ctx.getImageData(0,0,c.width,c.height).data;};
 g.render();const warped=capture();const strength=n.composite.material.uniforms.warpStrength.value;
 n.composite.material.uniforms.warpStrength.value=0;r.setRenderTarget(null);r.render(n.composite.scene,n.screenCamera);const flat=capture();
 let pixels=0,total=0;for(let i=0;i<flat.length;i+=4){const d=Math.abs(flat[i]-warped[i])+Math.abs(flat[i+1]-warped[i+1])+Math.abs(flat[i+2]-warped[i+2]);total+=d;if(d>24)pixels++;}
 g.render();return {pixels,total,strength,warps:n.warp.count};}""")
 assert delta['pixels']>1500 and delta['strength']==2.8 and delta['warps']==2,delta
 page.screenshot(path=str(OUT/'counter-distortion-1080.png'))
 qualities=page.evaluate("""()=>{const g=__KEYABYSS__.game;return [.3,.6,1].map(fx=>{g.options.fx=fx;g.render();return g.nativeRenderer.composite.material.uniforms.warpStrength.value;});}""")
 assert qualities==[1.25,2,2.8],qualities
 page.evaluate('__KEYABYSS__.game.options.reduceMotion=true;__KEYABYSS__.game.render()')
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.count')==0
 checks.append('native GPU counter displacement visibly changes pixels, scales with quality and respects reduced motion')
 assert not errors,errors
 b.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'gpu':delta,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
for check in checks:print('PASS',check,flush=True)
