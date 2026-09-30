"""Skip from early/impact/late frames without opacity jumps or menu input leakage."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
errors=[]
with sync_playwright() as p:
 b=launch_browser(p)
 for delay in [500,2700,6100]:
  page=b.new_page(viewport={'width':1440,'height':900})
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.intro-complete','true');")
  page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
  assert page.evaluate("(()=>{const e=new MouseEvent('contextmenu',{bubbles:true,cancelable:true});document.body.dispatchEvent(e);return e.defaultPrevented;})()")
  page.keyboard.press('Enter');page.wait_for_timeout(delay)
  result=page.evaluate("""()=>{const g=document.querySelector('.startup-gate'),h=document.querySelector('#home');const before={gate:+getComputedStyle(g).opacity,home:+getComputedStyle(h).opacity};
 window.dispatchEvent(new KeyboardEvent('keydown',{key:'s',bubbles:true}));return before;}""")
  page.wait_for_function("document.querySelector('.startup-gate')?.dataset.skipping==='true'")
  immediate=page.locator('.startup-gate').evaluate('e=>+getComputedStyle(e).opacity')
  assert abs(immediate-result['gate'])<.2,(delay,result,immediate)
  assert page.locator('#home').evaluate('e=>e.parentElement.inert')
  page.wait_for_timeout(220)
  middle=page.locator('.startup-gate').evaluate('e=>+getComputedStyle(e).opacity')
  assert 0<middle<result['gate'],(delay,middle,result)
  page.mouse.click(30,30)
  page.locator('.startup-gate').wait_for(state='detached',timeout=1500)
  assert page.locator('#home').evaluate('e=>!e.parentElement.inert && +getComputedStyle(e).opacity===1')
  assert page.locator('#modal').count()==0
  assert '输入词令' in page.locator('.command-input').inner_text()
  print('PASS smooth skip at',delay,'ms; midpoint opacity',middle,flush=True)
  page.close()
 page=b.new_page(viewport={'width':1440,'height':900})
 page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000)
 page.keyboard.press('Enter');page.mouse.click(30,30)
 page.evaluate("window.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',repeat:true,bubbles:true}))")
 page.wait_for_timeout(450)
 page.keyboard.press('Space');page.mouse.click(30,30);page.wait_for_timeout(750)
 assert page.locator('.ritual-skip-hint').count()==0
 assert page.locator('.startup-gate').get_attribute('data-skipping')=='false'
 page.locator('.startup-gate').wait_for(state='detached',timeout=8500)
 assert page.locator('#home').evaluate('e=>!e.parentElement.inert')
 assert page.evaluate("JSON.parse(localStorage.getItem('keyabyss.intro-complete')).data") is True
 assert page.evaluate("(()=>{const e=new MouseEvent('contextmenu',{bubbles:true,cancelable:true});document.querySelector('#home').dispatchEvent(e);return e.defaultPrevented;})()")
 page.reload();page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter');page.wait_for_timeout(500);page.keyboard.press('Space')
 page.locator('.startup-gate').wait_for(state='detached',timeout=1500)
 print('PASS first visit cannot skip; completion persists; next visit can skip; context menus disabled')
 page.close()
 page=b.new_page(reduced_motion='reduce')
 page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter')
 page.locator('.startup-gate').wait_for(state='detached',timeout=1500)
 assert not errors,errors
 print('PASS reduced motion still enters directly; no page errors');b.close()
