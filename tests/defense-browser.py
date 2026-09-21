"""Real keyboard defense routing and full-screen menu presentation at 1080P/720P."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-defense';OUT.mkdir(exist_ok=True)
checks=[];errors=[]
def check(name):checks.append(name);print('PASS',name,flush=True)
with sync_playwright() as p:
 browser=launch_browser(p);page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
 page.locator('#enterGame').wait_for(timeout=30000)
 assert page.locator('#startBtn').count()==0
 assert page.evaluate("__KEYABYSS__.game.state==='home'&&__KEYABYSS__.game.nativeRenderer.ready")
 page.screenshot(animations="disabled",path=str(OUT/'startup-1080.png'));page.locator('#enterGame').click()
 check('startup waits for actual resources and a deliberate click before exposing the home menu')
 page.locator('#startBtn').click()
 assert page.locator('.modal-panel').evaluate("e=>getComputedStyle(e).borderTopWidth==='0px'&&getComputedStyle(e).boxShadow==='none'")
 page.screenshot(animations="disabled",path=str(OUT/'deployment-1080.png'))
 page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.update=()=>{};g.enemies=[];g.nodes=[];g.bullets=[];g.shots=[];g.fields=[];g.lasers=[];g.blasts=[];g.fx=[];g.spawnClock=g.nodeClock=999;g.player.invuln=0;
 const e=g.spawnEnemy('guard',800,400,false,true);Object.assign(e,{word:'sand',hp:10000,maxHp:10000,grace:0});g.target=e;g.emit('hud');}""")
 page.keyboard.type('s');page.keyboard.press('Space')
 assert page.evaluate("__KEYABYSS__.game.player.parryTime>0&&__KEYABYSS__.game.dashes===0&&__KEYABYSS__.game.prefix==='s'")
 assert page.locator('.defense-readout').count()==0
 page.screenshot(animations="disabled",path=str(OUT/'parry-1080.png'))
 check('Space starts a visible parry without consuming dodge charges or erasing the typed prefix')
 # Browser auto-repeat cannot chain a held Space into repeated defenses.
 page.evaluate("window.dispatchEvent(new KeyboardEvent('keydown',{key:' ',repeat:true,bubbles:true}))")
 assert page.evaluate('__KEYABYSS__.game.dashes===0')
 page.keyboard.press('ArrowRight')
 assert page.evaluate("__KEYABYSS__.game.dashes===1&&__KEYABYSS__.game.player.dashState.tx>__KEYABYSS__.game.player.x&&__KEYABYSS__.game.player.invuln===1&&__KEYABYSS__.game.prefix==='s'")
 page.evaluate("__KEYABYSS__.game.updatePlayer(.2)")
 page.keyboard.press('Space')
 assert page.evaluate('__KEYABYSS__.game.dashes===1')
 check('arrow key dashes immediately; release and auto-repeat cannot trigger unintended movement')
 page.evaluate("__KEYABYSS__.game.player.parryCooldown=0;__KEYABYSS__.game.player.parryTime=0")
 page.keyboard.press('ArrowUp')
 assert page.evaluate('__KEYABYSS__.game.dashes===2&&__KEYABYSS__.game.player.dashState.ty<__KEYABYSS__.game.player.y')
 page.evaluate("__KEYABYSS__.game.updatePlayer(.2)");page.keyboard.type('an')
 assert page.evaluate("__KEYABYSS__.game.prefix==='san'&&__KEYABYSS__.game.errors===0")
 check('arrow directions and typing remain independent, including zero remaining dodge charges')
 page.keyboard.press('Escape');page.wait_for_selector('.pause-menu')
 assert page.evaluate('Object.keys(__KEYABYSS__.game.aimKeys).length===0')
 page.screenshot(animations="disabled",path=str(OUT/'pause-1080.png'));page.keyboard.type('resume')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];g.bullets=[];g.fx=[];g.player.invuln=0;g.player.parryCooldown=0;
 const e=g.spawnEnemy('ram',g.player.x+10,g.player.y,false,true);Object.assign(e,{grace:0,hp:1000,maxHp:1000,charge:.4,cx:-1,cy:0});window.enemy=e;window.health=g.player.hp;}""")
 page.keyboard.press('Space');page.evaluate('__KEYABYSS__.game.updateEnemies(.008);__KEYABYSS__.game.emit("hud")')
 assert page.evaluate('enemy.charge===0&&enemy.hp===968&&__KEYABYSS__.game.player.hp===health')
 check('real Space input interrupts a contact charge and deals counter damage without losing health')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];g.bullets=[];g.fx=[];g.player.parryTime=0;g.player.parryCooldown=0;
 const e=g.spawnEnemy('nib',g.player.x+150,g.player.y,false,true);Object.assign(e,{grace:0,hp:1000,maxHp:1000});window.enemy=e;
 g.bullet(g.player.x+20,g.player.y,Math.PI,100,'#ff9988',{source:e.id});}""")
 page.keyboard.press('Space');page.evaluate('__KEYABYSS__.game.updateBullets(.01)')
 assert page.evaluate('__KEYABYSS__.game.bullets[0].reflected&&enemy.hp===1000')
 page.evaluate('__KEYABYSS__.game.updateBullets(.5)')
 assert page.evaluate('enemy.hp===968')
 check('real parry input sends a physical projectile back and damage occurs on impact')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.setState('upgrade');g.afterUpgrade='play';g.emit('upgrade',g.content.relics.filter(r=>['rebound','inscription','hourglass'].includes(r.id)));}""")
 page.wait_for_selector('.choice-grid')
 assert page.locator('[data-upgrade=rebound]').count()==1
 page.screenshot(animations="disabled",path=str(OUT/'relic-choice-1080.png'))
 for width,height in [(1280,720),(390,844)]:
  page.set_viewport_size({'width':width,'height':height});page.wait_for_timeout(100)
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  page.locator('[data-upgrade=rebound]').scroll_into_view_if_needed()
  page.screenshot(animations="disabled",path=str(OUT/f'relic-choice-{width}.png'))
 page.keyboard.type('rebound')
 assert page.evaluate('__KEYABYSS__.game.relics.rebound===1')
 check('shared open menu style renders deployment and relic selection at 1080P, 720P and narrow widths; keyboard selection works')
 assert not errors,errors
 browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
