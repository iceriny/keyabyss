"""Preparation stays in the archive and hands its book anchor to battle arrival."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from threading import Thread
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-deployment';OUT.mkdir(exist_ok=True)
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(ROOT/'dist')))
Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1440,'height':900})
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:false}));")
 page.goto(f'http://127.0.0.1:{server.server_port}/?debug');page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.locator('.choice-card.selected .choice-icon').evaluate('e=>e.dataset.continuity="same"')
 page.locator('#startBtn').click();page.wait_for_timeout(750);assert page.locator('#modal').count()==0
 assert page.locator('.choice-card.selected .choice-icon').get_attribute('data-continuity')=='same'
 page.screenshot(path=str(OUT/'open.png'))
 page.locator('#vocabSelect').click();page.get_by_role('option').nth(2).click()
 page.locator('[data-mode="hard"]').click();page.locator('#seedInput').fill('SCENE')
 page.locator('.deployment-return button').click();page.locator('#startBtn').wait_for();page.locator('#startBtn').click();assert page.locator('#seedInput').input_value()=='SCENE'
 page.locator('.wing-left [data-command="import"]').click();page.locator('#modal').wait_for();page.locator('#modal [aria-label="返回"]').click();assert page.locator('#beginRun').is_visible()
 for w,h in [(1024,640),(1920,1080),(1440,900)]:
  page.set_viewport_size({'width':w,'height':h});page.wait_for_timeout(100)
  for selector in ['.wing-left','.wing-right','#beginRun']:
   box=page.locator(selector).bounding_box();assert box['x']>=0 and box['y']>=0 and box['x']+box['width']<=w and box['y']+box['height']<=h
 page.locator('#vocabSelect').click();page.get_by_role('option').nth(6).click()
 page.route('**/word/**',lambda route:route.abort())
 page.locator('#beginRun').click();page.locator('.deployment-status [data-command="retry"]').wait_for()
 assert page.locator('.loading-screen').count()==0
 assert page.locator('.choice-card.selected .choice-icon').get_attribute('data-continuity')=='same'
 page.unroute('**/word/**');page.locator('.deployment-status [data-command="retry"]').click()
 page.locator('.battle-arrival.in-place').wait_for();assert page.locator('.arrival-book').count()==0
 page.wait_for_timeout(500);page.screenshot(path=str(OUT/'departure.png'));page.wait_for_function("__KEYABYSS__.game.state==='playing'");assert page.evaluate('__KEYABYSS__.game.config.seed')=='SCENE'
 assert not errors,errors
 print('PASS: same book, inline configuration, library return, desktop bounds and in-place battle arrival.');b.close()

server.shutdown();server.server_close()
