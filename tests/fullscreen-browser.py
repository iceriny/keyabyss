"""Fullscreen veil, native quality levels, complete offline vocabulary and God Mode UI."""
from pathlib import Path
from io import BytesIO
import json
from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-fullscreen';OUT.mkdir(exist_ok=True)
checks=[];errors=[];requests=[];quality=[]
def check(name):checks.append(name);print('PASS',name,flush=True)
with sync_playwright() as p:
 browser=launch_browser(p);page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.on('request',lambda r:requests.append(r.url))
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
 page.locator("#enterGame").click(timeout=30000)
 page.wait_for_selector('#startBtn')
 page.keyboard.type('imsuperman')
 assert page.evaluate('__KEYABYSS__.game.godMode')
 assert page.evaluate('__KEYABYSS__.game.casts||0')==0
 page.keyboard.type('vocab');page.keyboard.type('cet4')
 page.keyboard.type('use');page.keyboard.press('Escape')
 # Use persisted UI preference for deployment; no preview words are injected by the test.
 page.locator('#startBtn').click();page.locator('#beginRun').click()
 page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 assert page.evaluate('__KEYABYSS__.game.config.words.length')==2607
 assert any('/word/vocab-cet4-' in r for r in requests)
 assert page.locator('.god-mode-badge').is_visible()
 check('God Mode activates through the real command dock; deployment loads all 2607 CET4 words from word/')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.sound.enabled=false;g.enemies=[];g.nodes=[];g.spawnClock=g.nodeClock=999;g.roomQuota=999;
 g.player.invuln=0;g.hurt(9);window.hurtHP=g.player.hp;g.player.invuln=0;g.hurt(99999);g.state='paused';g.fx=[];g.shake=g.hitFlash=0;g.render();}""")
 assert page.evaluate('hurtHP<__KEYABYSS__.game.player.maxHp&&__KEYABYSS__.game.player.hp===__KEYABYSS__.game.player.maxHp')
 check('God Mode keeps actual damage feedback and restores lethal health without a result screen')
 page.add_style_tag(content='*,*::before,*::after{animation:none!important;transition:none!important} .toast{display:none!important}')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.visualTime=2;
 for(const [type,x,y,word] of [['ram',g.arena.l+18,400,'edge'],['quill',640,28,'above'],['guard',650,340,'center']]){
 const e=g.spawnEnemy(type,x,y,false,true);Object.assign(e,{word,grace:0,shoot:0,hp:99999,maxHp:99999});}
 g.nodes=[];g.spawnNode('rune');g.spawnNode('ink');g.fx=[];g.emit('hud');g.render();}""")
 page.wait_for_timeout(120)
 assert page.evaluate("(()=>{const g=__KEYABYSS__.game;return Math.abs(g.arena.l*g.scale+g.ox)<.01&&Math.abs(g.arena.r*g.scale+g.ox-innerWidth)<.01&&Math.abs(g.arena.b*g.scale+g.oy-innerHeight)<.01})()")
 veil=Image.open(BytesIO(page.screenshot(path=str(OUT/'arena-1080.png')))).convert('RGB')
 page.locator('.edge-veil').evaluate("e=>e.style.display='none'")
 raw=Image.open(BytesIO(page.screenshot(path=str(OUT/'veil-disabled.png')))).convert('RGB')
 diff=ImageChops.difference(veil,raw)
 assert diff.crop((0,200,120,850)).getbbox(), 'edge veil must affect actual screenshots'
 assert diff.crop((450,300,1450,800)).getbbox() is None, 'clear central area must remain pixel-identical'
 # Upper enemy word is inside the veil, while HUD sits above all filters.
 box=page.evaluate("(()=>{const g=__KEYABYSS__.game,l=g.labels.find(l=>l.target.word==='above');return [l.x*g.scale+g.ox,l.y*g.scale+g.oy,(l.x+l.w)*g.scale+g.ox,(l.y+l.h)*g.scale+g.oy]})()")
 assert diff.crop(tuple(round(v) for v in box)).getbbox(), 'word pixels must be covered too'
 page.locator('.edge-veil').evaluate("e=>e.style.display=''")
 check('fullscreen world fills 1080P and progressive edge blur changes words/world while the center stays exact')
 assert page.evaluate("""()=>{const g=__KEYABYSS__.game;g.state='playing';g.enemies.forEach(e=>g.enemyAttack(e));const edge=g.enemies.find(e=>e.word==='edge');g.updateEnemies(.02);g.state='paused';return edge.windup===0&&edge.charge===0&&g.bullets.every(b=>b.source!==edge.id);}""")
 check('visible edge enemies cannot shoot or charge through actual simulation entry points')
 # All qualities exercise the same frozen elemental scene so differences are attributable to settings.
 for value in [.3,.6,1]:
  diag=page.evaluate("""value=>{const g=__KEYABYSS__.game;g.options.fx=value;g.options.reduceMotion=false;
    g.fields=[];g.fx=[];g.addField('frost',430,370,130,5);g.addField('storm',760,430,130,5);g.addField('fire',1030,340,120,5);g.addField('gravity',680,570,145,5);
    g.fields.forEach(f=>f.age=.7);g.burst(650,330,190,g.bookData.color,'ultimate');g.fx.forEach(f=>f.life=f.max*.6);g.invalidate();g.render();return g.nativeRenderer.diagnostics();}""",value)
  quality.append(diag);page.screenshot(path=str(OUT/f'quality-{diag["quality"]}.png'))
 assert [d['quality'] for d in quality]==['low','medium','high']
 assert quality[0]['displacement'][0]<quality[1]['displacement'][0]<quality[2]['displacement'][0]
 assert quality[0]['instances']['effects']<quality[1]['instances']['effects']<quality[2]['instances']['effects']
 assert quality[2]['instances']['warp']>0
 assert page.evaluate("(()=>{const n=__KEYABYSS__.game.nativeRenderer;return n.effects.mesh.renderOrder>Math.max(...n.actorPages.map(b=>b.mesh.renderOrder))&&!n.effects.material.depthTest})()")
 check('low/medium/high change real native layer counts and render targets; foreground effects render after actors')
 # Capture the GPU directly to exclude DOM HUD animations and inspect paused differential background.
 assert page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,t=n.environmentTarget,Type=t.texture.type===1016?Uint16Array:Uint8Array;
  const a=new Type(t.width*t.height*4),b=new Type(a.length),c=new Type(a.length);n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,a);
  g.render();n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,b);g.visualTime+=3;g.render();n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,c);
  return a.every((v,i)=>v===b[i])&&a.some((v,i)=>v!==c[i]);}""")
 check('differential native background animates with visual time and stays pixel-exact when paused')
 page.set_viewport_size({'width':1280,'height':720})
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.options.reduceMotion=true;g.options.fx=.3;g.invalidate();g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().instances.warp')==0
 page.screenshot(path=str(OUT/'arena-reduced-720.png'))
 check('720P retains fullscreen presentation and reduced motion disables space distortion')
 page.evaluate("__KEYABYSS__.game.state='playing'")
 page.keyboard.press('Escape');page.wait_for_selector('[role=dialog]')
 page.screenshot(path=str(OUT/'pause-menu.png'))
 page.keyboard.type('imsuperman')
 assert page.evaluate('__KEYABYSS__.game.godMode')
 check('game menu remains keyboard operable and supports test commands while paused')
 assert not [r for r in requests if r.startswith('http')],requests
 assert not errors,errors
 browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors,'quality':quality},ensure_ascii=False,indent=2),encoding='utf-8')
