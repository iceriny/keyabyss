"""Startup module retry, vocabulary cancel race, WebGL failure and Vite entry."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-native';checks=[];errors=[]
url=(ROOT/'dist/index.html').as_uri()+'?debug'
with sync_playwright() as p:
 browser=launch_browser(p)
 for mode in ['retry','cancel','no-webgl']:
  page=browser.new_page(viewport={'width':1920,'height':1080})
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
  if mode=='no-webgl':
   page.add_init_script("const original=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(type,...args){return type.startsWith('webgl')?null:original.call(this,type,...args)}")
  elif mode=='retry':
   page.add_init_script("""const append=Node.prototype.appendChild;window.battleAttempts=0;
    Node.prototype.appendChild=function(node){if(node.tagName==='SCRIPT'&&node.src.includes('battle-renderer-')){window.battleAttempts++;if(window.battleAttempts===1){setTimeout(()=>node.dispatchEvent(new Event('error')),50);return node;}}return append.call(this,node);};""")
  else:
   page.add_init_script("""const append=Node.prototype.appendChild;window.vocabAttempts=0;
    Node.prototype.appendChild=function(node){if(node.tagName==='SCRIPT'&&node.src.includes('/word/vocab-')){window.vocabAttempts++;if(window.vocabAttempts===1){window.releaseVocab=()=>append.call(this,node);return node;}}return append.call(this,node);};""")
  page.goto(url)
  if mode=='retry':
   page.get_by_text('无法读取战场资源，请确认 assets 文件夹完整。',exact=True).wait_for()
   assert page.locator('#enterGame').count()==0
   page.locator('.startup-gate [data-command=retry]').click();page.locator('#enterGame').click(timeout=30000)
   assert page.evaluate('window.battleAttempts===2 && __KEYABYSS__.game.nativeRenderer.ready')
   checks.append('startup stays gated after resource failure and real UI retry prepares the native world')
  elif mode=='cancel':
   page.locator('#enterGame').click(timeout=30000);page.locator('#startBtn').click();page.locator('#beginRun').click()
   page.wait_for_function('!!window.releaseVocab');page.locator('.loading-screen [data-command=back]').click()
   page.evaluate('releaseVocab()');page.wait_for_timeout(150)
   assert page.evaluate("__KEYABYSS__.game.state==='home'")
   page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
   assert page.evaluate('window.vocabAttempts===1')
   checks.append('cancelled vocabulary loading never launches late; next deployment reuses resolved data')
  else:
   page.get_by_text('无法建立 WebGL 2 战场。请启用浏览器硬件加速后重试。',exact=True).wait_for()
   assert page.evaluate("__KEYABYSS__.game.state==='home'")
   assert page.locator('#enterGame').count()==0
   checks.append('unsupported WebGL cannot pass the startup gate or start invisible combat')
  print('PASS',checks[-1],flush=True);page.close()
 page=browser.new_page(viewport={'width':1920,'height':1080},device_scale_factor=2)
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto('http://127.0.0.1:4318/?debug');page.locator('#enterGame').click(timeout=30000)
 assert page.evaluate('__KEYABYSS__.game.canvas.width===1920 && __KEYABYSS__.game.overlay.width===3840')
 checks.append('Vite startup gate works at DPR 2 with 1080P world and independent crisp labels');print('PASS',checks[-1],flush=True)
 assert not errors,errors
 browser.close()
OUT.mkdir(exist_ok=True)
(OUT/'loading-report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
