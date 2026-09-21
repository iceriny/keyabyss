"""First visit preflight, calibration persistence, and route companion."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-first-visit';OUT.mkdir(exist_ok=True)
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT/'dist')))
Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html?debug'
try:
  with sync_playwright() as p:
    browser=launch_browser(p)
    page=browser.new_page(viewport={'width':1920,'height':1080},reduced_motion='reduce')
    requests=[];page.on('request',lambda r:requests.append(r.url))
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
    held=[];page.route('**/font/*.woff2?*',lambda r:held.append(r))
    page.goto(url,wait_until='domcontentloaded')
    page.locator('#boot-fullscreen').wait_for()
    assert page.locator('#world').count()==0
    page.locator('#boot-fullscreen').click()
    page.wait_for_function('!!document.fullscreenElement')
    page.screenshot(path=str(OUT/'font-fullscreen.png'))
    while len(held)<2:page.wait_for_timeout(50)
    for r in held:r.continue_()
    page.locator('html[data-fonts=ready]').wait_for(state='attached')
    page.wait_for_timeout(1200)
    assert page.locator('#boot').is_visible()
    assert page.locator('#world').count()==0
    assert not any('/assets/game-' in r for r in requests)
    assert page.evaluate("localStorage.getItem('keyabyss.preflight-complete')") is None
    page.screenshot(path=str(OUT/'preflight-ready.png'))
    page.locator('#boot-continue').click()
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter');page.locator('.calibration-modal').wait_for()
    page.wait_for_function("Number(document.querySelector('.calibration-reading strong')?.textContent)>0")
    page.emulate_media(reduced_motion='no-preference')
    page.locator('[data-command=motion]').click()
    page.wait_for_timeout(1200)
    page.screenshot(path=str(OUT/'calibration-high.png'))
    # Apply a setting through the actual custom select and toggle controls.
    page.locator('#settingFx').click()
    page.get_by_role('option',name='低 · 精简粒子').click()
    page.locator('[data-command=sound]').click()
    page.wait_for_timeout(600)
    assert page.evaluate("JSON.parse(localStorage.getItem('keyabyss.settings')).data.fx") == .3
    assert page.evaluate("JSON.parse(localStorage.getItem('keyabyss.settings')).data.sound") == False
    done=page.locator('[data-command=ready]')
    assert done.bounding_box()['y']+done.bounding_box()['height']<1080
    page.screenshot(path=str(OUT/'calibration.png'))
    done.click();assert page.locator('.calibration-modal').count()==0
    page.unroute('**/font/*.woff2?*')
    held=[];page.route('**/font/*.woff2?*',lambda r:held.append(r))
    page.reload(wait_until='domcontentloaded')
    page.locator('#boot').wait_for()
    assert page.locator('#boot-fullscreen').is_hidden()
    while len(held)<2:page.wait_for_timeout(50)
    for r in held:r.continue_()
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
    assert page.locator('.calibration-modal').count()==0
    page.evaluate("localStorage.setItem('keyabyss.tutorial','true')")
    page.locator('#startBtn').click();page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.enemies=[];g.spawnClock=999;g.player.invuln=999;const width=Math.min(g.arena.r-g.arena.l,g.arena.b-g.arena.t)*.1;for(let i=0;i<4;i++){const e=g.spawnEnemy('nib',g.arena.l+width*(.25+i*.5),260+i*80);e.speed=0;e.grace=0;e.word='archive';}}''')
    page.wait_for_timeout(400)
    page.screenshot(path=str(OUT/'cold-zone.png'))
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.enemies=[];g.relics=Object.fromEntries(g.content.relics.slice(0,8).map(r=>[r.id,1]));g.player.shield=25;g.completeRoom();}''')
    page.locator('[data-route]').first.wait_for()
    page.locator('.upgrade-companion').wait_for();page.wait_for_timeout(1200)
    assert page.locator('.upgrade-companion [aria-label=护盾]').get_attribute('aria-valuenow')=='25'
    page.locator('.companion-relics [data-tooltip-title]').first.hover()
    page.locator('.game-tooltip').wait_for()
    page.screenshot(path=str(OUT/'route-companion.png'))
    assert not errors,errors
    print('PASS first-visit fullscreen, font gate, calibration FPS/settings persistence, repeat-visit suppression and route companion tooltip',flush=True)
    browser.close()
finally:server.shutdown()
