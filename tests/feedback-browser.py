"""Arrival timing, typing cadence, and distinct parry activation/success feedback."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-feedback';OUT.mkdir(exist_ok=True)
checks=[];errors=[]
def check(message):checks.append(message);print('PASS',message,flush=True)
with sync_playwright() as p:
 browser=launch_browser(p);page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false}));")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
 page.keyboard.press('Enter');page.wait_for_timeout(450)
 assert page.locator('.startup-gate').get_attribute('data-leaving')=='true'
 assert page.locator('.home-arrival').get_attribute('inert') is not None
 assert page.evaluate("__KEYABYSS__.game.sound.pool.some(v=>v.cue==='ui.enter'&&v.audio.isPlaying)")
 page.screenshot(path=str(OUT/'arrival-1080.png'))
 page.keyboard.type('start')
 assert page.locator('.modal').count()==0
 page.locator('.startup-gate').wait_for(state='detached')
 assert page.locator('#commandDock').inner_text().startswith('› 输入词令')
 check('1.6s arrival plays its own sample and reveals an inert menu; transition input cannot activate commands')
 before=page.evaluate('__KEYABYSS__.game.sound.played')
 page.keyboard.type('voca',delay=85)
 assert page.evaluate('__KEYABYSS__.game.sound.played')>=before+4
 assert page.evaluate("__KEYABYSS__.game.sound.pool.filter(v=>v.cue==='ui.type').every(v=>v.audio.duration===.11)")
 page.keyboard.press('Escape');page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];g.nodes=[];g.spawnClock=g.nodeClock=999;g.roomQuota=999;g.player.invuln=0;const e=g.spawnEnemy('guard',500,300,false,true);Object.assign(e,{word:'sand',hp:9999,maxHp:9999,grace:0});g.target=e;g.prefix='';}""")
 before=page.evaluate('__KEYABYSS__.game.sound.played')
 page.keyboard.type('san',delay=85)
 assert page.evaluate('__KEYABYSS__.game.prefix')=='san'
 assert page.evaluate('__KEYABYSS__.game.sound.played')>=before+3
 page.wait_for_timeout(140)
 assert page.evaluate("__KEYABYSS__.game.sound.pool.filter(v=>v.cue==='key'&&v.audio.isPlaying).length") == 0
 check('command and spell letters play short per-key samples and promptly release their voices')
 page.keyboard.press('Space')
 assert page.evaluate("__KEYABYSS__.game.sound.pool.some(v=>v.cue==='parry.activate')")
 assert not page.evaluate('__KEYABYSS__.game.player.parrySuccess')
 result=page.evaluate("""()=>{const g=__KEYABYSS__.game;for(let i=0;i<5;i++)g.bullet(g.player.x+20,g.player.y,Math.PI,100,'#fff');g.updateBullets(.01);return {success:g.player.parrySuccess,count:g.fx.filter(f=>f.kind==='parry').length,reflected:g.bullets.filter(b=>b.reflected).length,slow:g.counterSlowTime};}""")
 assert result['success'] and result['count']==1 and result['reflected']==5 and result['slow']==.52,result
 page.wait_for_function("__KEYABYSS__.game.sound.pool.some(v=>v.cue==='parry')")
 assert page.evaluate("__KEYABYSS__.game.sound.pool.some(v=>v.cue==='parry.ring')")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.state='paused';g.enemies=[];g.bullets=[];g.particles=[];g.visualTime=2;g.shake=0;g.fx=g.fx.filter(f=>f.kind==='parry');g.fx.forEach(f=>f.life=f.max*.72);g.render();}""")
 page.screenshot(path=str(OUT/'parry-1080.png'))
 counts=[]
 for value in [.3,.65,1]:
  counts.append(page.evaluate("""value=>{const g=__KEYABYSS__.game;g.options.fx=value;g.render();return g.nativeRenderer.diagnostics().instances.effects;}""",value))
 assert counts[0]<counts[1]<counts[2],counts
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.options.reduceMotion=true;g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().instances.warp')==0
 check('activation is separate; five reflected bullets yield one success pulse, layered audio and foreground effects across all qualities')
 assert not errors,errors
 browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
