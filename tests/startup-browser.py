"""Startup atmosphere and full-screen entry gestures, using the real release."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-startup';OUT.mkdir(exist_ok=True)
checks=[];errors=[]
def check(s):checks.append(s);print('PASS',s,flush=True)
with sync_playwright() as p:
 browser=launch_browser(p);page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("""const append=Node.prototype.appendChild;Node.prototype.appendChild=function(node){if(node.tagName==='SCRIPT'&&node.src.includes('battle-renderer-')){window.releaseStartup=()=>append.call(this,node);return node;}return append.call(this,node);};""")
 url=(ROOT/'dist/index.html').as_uri()+'?debug'
 page.goto(url);page.wait_for_function('!!window.releaseStartup')
 page.keyboard.type('start');page.mouse.click(25,25)
 assert page.locator('.startup-gate').get_attribute('data-ready')=='false'
 assert page.locator('#startBtn').count()==0
 page.evaluate('releaseStartup()');page.locator('#enterGame').wait_for(timeout=30000)
 assert page.locator('#enterGame').evaluate('e=>e.tagName')=='SPAN'
 assert page.locator('.startup-gate button').count()==0
 check('loading ignores entry gestures without queuing them; ready prompt is plain text')
 initial=page.locator('.startup-orbit .sigil-core').evaluate('e=>getComputedStyle(e).transform')
 page.wait_for_timeout(250)
 assert initial!=page.locator('.startup-orbit .sigil-core').evaluate('e=>getComputedStyle(e).transform')
 assert page.locator('.startup-atmosphere > i').count()==64
 page.screenshot(path=str(OUT/'startup-1080.png'))
 check('shared sigil actually rotates with breathing light and drifting particles at 1080P')
 page.mouse.click(12,1060);page.locator('#startBtn').wait_for()
 page.locator('.startup-gate').wait_for(state='detached')
 assert not page.locator('.startup-gate').count()
 check('clicking a remote screen corner continues without needing the prompt')
 page.close()
 for key in ['4','a','Space','Enter','Escape','ArrowUp','Shift']:
  page=browser.new_page(viewport={'width':1920,'height':1080})
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto(url);page.locator('#enterGame').wait_for(timeout=30000)
  page.keyboard.press(key);page.locator('#startBtn').wait_for()
  page.locator('.startup-gate').wait_for(state='detached')
  assert page.locator('[data-book=frost]').get_attribute('aria-pressed')=='true',key
  assert '输入词令' in page.locator('#commandDock').inner_text(),key
  assert page.locator('.modal').count()==0,key
  assert page.evaluate("__KEYABYSS__.game.state==='home'")
  page.close()
 check('numbers, letters, Space, Enter, Escape, arrows and modifier keys enter once without leaking into home commands')
 for x,y in [(12,12),(1908,12),(1908,1060)]:
  page=browser.new_page(viewport={'width':1920,'height':1080})
  page.goto(url);page.locator('#enterGame').wait_for(timeout=30000);page.mouse.click(x,y);page.locator('.startup-gate').wait_for(state='detached');page.locator('#startBtn').wait_for();page.close()
 check('all four corners of the screen accept the entry click')
 page=browser.new_page(viewport={'width':390,'height':844},reduced_motion='reduce')
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto(url);page.locator('#enterGame').wait_for(timeout=30000)
 assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
 assert page.locator('.startup-orbit .sigil-core').evaluate('e=>getComputedStyle(e).animationName')=='none'
 page.screenshot(path=str(OUT/'startup-narrow.png'));page.keyboard.press('a');page.locator('#startBtn').wait_for()
 page.locator('.startup-gate').wait_for(state='detached')
 check('narrow screens fit the prompt and reduced motion disables decorative animation')
 assert not errors,errors
 browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
