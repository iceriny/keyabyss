"""Manual menu focus, custom cursor, independent SFX gain and direct/automatic dodge."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-ritual';OUT.mkdir(exist_ok=True)
checks=[];errors=[]
def passed(text):checks.append(text);print('PASS',text,flush=True)
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
 assert page.locator('.startup-atmosphere > i').count()==64
 assert page.locator('.startup-mark path').count()>40
 page.screenshot(path=str(OUT/'startup-1080.png'))
 page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.wait_for_function('__KEYABYSS__.game.nativeRenderer.menu.dust.geometry.drawRange.count===96')
 page.keyboard.press('Tab');assert page.locator('[data-book=frost]').evaluate('(e)=>e===document.activeElement')
 assert page.locator('[data-book=frost]').evaluate('(e)=>e.classList.contains("game-focus")&&getComputedStyle(e).outlineStyle==="none"')
 page.keyboard.press('Shift+Tab');assert page.locator('#startBtn').evaluate('(e)=>e===document.activeElement')
 assert page.locator('button').evaluate_all('(els)=>els.every(e=>e.tabIndex===-1)')
 page.mouse.move(1550,720);page.wait_for_timeout(50)
 assert page.locator('.arcane-cursor').is_visible()
 assert page.locator('#startBtn').evaluate('(e)=>getComputedStyle(e).cursor')=='none'
 assert page.locator('.arcane-cursor').evaluate('(e)=>getComputedStyle(e).pointerEvents')=='none'
 page.screenshot(path=str(OUT/'home-cursor-1080.png'))
 passed('richer startup seal and 64 particles, native menu dust, explicit focus order and nonblocking custom cursor')
 page.locator('#startBtn').click()
 assert '双手打字，无自由移动' not in page.locator('#modal').inner_text()
 assert page.locator('[data-command=back]').get_attribute('data-nav-order') is None
 assert page.locator('[data-command=import]').get_attribute('data-nav-order') is None
 page.screenshot(path=str(OUT/'deployment-1080.png'))
 page.keyboard.press('Escape');page.keyboard.type('settings')
 page.locator('#settingSfxVolume').focus();page.keyboard.press('Home');page.wait_for_timeout(200)
 assert page.evaluate('__KEYABYSS__.game.sound.sfxVolume')==0
 assert page.evaluate('__KEYABYSS__.game.sound.sfxBus.gain.value')<.001
 assert page.evaluate('__KEYABYSS__.game.sound.musicBus.gain.value')>0
 assert page.evaluate('__KEYABYSS__.game.sound.volume')>.2
 page.screenshot(path=str(OUT/'audio-settings-1080.png'))
 page.locator('#settingSfxVolume').press('End');page.wait_for_timeout(100)
 assert page.evaluate('__KEYABYSS__.game.sound.sfxVolume')==1
 page.keyboard.press('Escape');page.keyboard.press('Escape')
 passed('removed deployment sentence, skipped secondary controls and independent live SFX volume')
 page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.update=()=>{};g.enemies=[];g.nodes=[];g.bullets=[];g.lasers=[];g.blasts=[];g.player.dash=2;g.player.invuln=0;g.player.dashState=null;}""")
 page.keyboard.press('ArrowLeft');assert page.evaluate('__KEYABYSS__.game.dashes===1&&__KEYABYSS__.game.player.dashState.tx<__KEYABYSS__.game.player.x')
 page.evaluate('__KEYABYSS__.game.updatePlayer(.2)')
 page.keyboard.down('Alt');page.keyboard.down('Alt');page.keyboard.up('Alt')
 result=page.evaluate('({dashes:__KEYABYSS__.game.dashes,invuln:__KEYABYSS__.game.player.invuln,state:__KEYABYSS__.game.state,dash:__KEYABYSS__.game.player.dash,keys:__KEYABYSS__.game.aimKeys})')
 assert result['dashes']==2 and result['invuln']==1,result
 page.evaluate('__KEYABYSS__.game.updatePlayer(.2)')
 page.keyboard.press('Space');assert page.evaluate('__KEYABYSS__.game.player.parryTime>0&&__KEYABYSS__.game.dashes===2')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.bullet(g.player.x+20,g.player.y,Math.PI,100,'#fff');g.updateBullets(.01);g.state='paused';g.fx=g.fx.filter(f=>f.kind==='parry');g.fx.forEach(f=>f.life=f.max*.7);g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.warp.count')==2
 page.screenshot(path=str(OUT/'counter-warp-1080.png'))
 passed('arrow and Alt keydown dodge immediately without repeats; Space parries independently with two distortion layers')
 assert not errors,errors
 b.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')


