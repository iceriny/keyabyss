from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/test-output-desktop';OUT.mkdir(exist_ok=True)
SIZES=[(1024,640),(1280,720),(1366,768),(1440,900),(1536,864),(1600,900),(1920,1080),(2560,1440),(3440,1440),(3840,2160)]
with sync_playwright() as p:
 b=launch_browser(p);page=b.new_page(viewport={'width':1920,'height':1080},reduced_motion='reduce')
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:true}));")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug');page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 def rect(s):return page.locator(s).bounding_box()
 def disjoint(a,b):return a['x']+a['width']<=b['x']+1 or b['x']+b['width']<=a['x']+1 or a['y']+a['height']<=b['y']+1 or b['y']+b['height']<=a['y']+1
 for w,h in SIZES:
  page.set_viewport_size({'width':w,'height':h});page.wait_for_timeout(80)
  for book in ['frost','storm','spirit','flame']:
   page.locator(f'[data-book={book}]').click(force=True);page.wait_for_timeout(70)
   selectors=['.choice-card.selected strong','.choice-card.selected .cmd-badge','.hero-caption','#startBtn']
   rs=[rect(s) for s in selectors]
   assert all(a['y']+a['height']+5<=b['y'] for a,b in zip(rs,rs[1:])),(w,h,book,rs)
   for r in rs:assert r['y']>=0 and r['y']+r['height']<h-60,(w,h,book,r)
   assert disjoint(rect('.camp-menu'),rect('.hero-caption')),(w,h,'menu')
  if w in [1024,1366,1920,3440]:page.screenshot(path=str(OUT/f'home-{w}x{h}.png'))
  page.locator('[data-command=settings]').click();page.wait_for_timeout(40)
  foot=rect('.modal-footer');assert foot['y']+foot['height']<=h-64,(w,h,foot)
  page.keyboard.press('Escape')
 print('PASS four books and settings at ten desktop viewports',flush=True)
 page.set_viewport_size({'width':1280,'height':720});page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("()=>{const g=__KEYABYSS__.game;g.player.invuln=999;g.spawnClock=999;g.enemies=[];g.combo=100;g.emit('hud');}")
 for w,h in SIZES[:7]:
  page.set_viewport_size({'width':w,'height':h});page.wait_for_timeout(60)
  for a,c in [('.health-block','.chapter-block'),('.health-block','.combat-side'),('.level-block','#castBox'),('.ultimate-block','#castBox')]:assert disjoint(rect(a),rect(c)),(w,h,a,c,rect(a),rect(c))
  for sel in ['.build-button','.health-block','.chapter-block','.battle-actions','.combat-side','.level-block','#castBox','.ultimate-block']:
   r=rect(sel);assert r['x']>=0 and r['x']+r['width']<=w and r['y']>=0 and r['y']+r['height']<=h,(w,h,sel,r,page.locator(sel).evaluate('e=>({position:getComputedStyle(e).position,left:getComputedStyle(e).left,right:getComputedStyle(e).right,transform:getComputedStyle(e).transform})'))
  if w in [1024,1366,1920]:page.screenshot(path=str(OUT/f'hud-{w}x{h}.png'))
 page.evaluate("()=>{const g=__KEYABYSS__.game;g.pending=1;g.upgradeAt=g.time-1;g.postCombat();}")
 page.locator('.upgrade-companion').wait_for()
 for w,h in SIZES[:7]:
  page.set_viewport_size({'width':w,'height':h});page.wait_for_timeout(60)
  foot=rect('.upgrade-companion');assert foot['y']+foot['height']<h-64,(w,h,foot)
  assert disjoint(rect('.choice-grid'),foot),(w,h,'choices')
 page.evaluate("localStorage.removeItem('keyabyss.calibration-complete')")
 # Remove the test initialization so this reload can open the real first-run setup.
 page2=b.new_page(viewport={'width':1280,'height':720},reduced_motion='reduce')
 page2.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:true}));")
 page2.goto((ROOT/'dist/index.html').as_uri()+'?debug');page2.locator('#enterGame').wait_for(timeout=30000);page2.keyboard.press('Enter');page2.locator('.calibration-modal').wait_for()
 for w,h in SIZES[:7]:
  page2.set_viewport_size({'width':w,'height':h});page2.wait_for_timeout(60)
  for sel in ['.modal-heading','[data-command=ready]','.calibration-reading']:
   r=page2.locator(sel).bounding_box();assert r['y']>=0 and r['y']+r['height']<h-64,(w,h,sel,r)
  if w==1280:page2.screenshot(path=str(OUT/'calibration-1280x720.png'))
 assert not errors,errors
 print('PASS battle HUD and upgrade footer at seven desktop viewports',flush=True)
 b.close()
