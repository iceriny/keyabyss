"""Fonts must finish downloading and decoding before any game UI mounts."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/test-output-fonts'
OUT.mkdir(exist_ok=True)

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
    def end_headers(self):
        if '.woff2' in self.path:
            self.send_header('Cache-Control','public, max-age=31536000, immutable')
        super().end_headers()

server = ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(ROOT/'dist')))
Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html?debug'
errors=[]

def no_game(page):
    assert page.locator('#boot').is_visible()
    assert page.locator('.startup-gate, #home, #world').count()==0

try:
  with sync_playwright() as p:
    browser=launch_browser(p)
    context=browser.new_context(viewport={'width':1920,'height':1080},reduced_motion='reduce')
    page=context.new_page()
    page.on('pageerror',lambda e:errors.append(str(e)))
    held=[]
    page.route('**/font/*.woff2?*',lambda route:held.append(route))
    page.add_init_script('''
      const load=FontFace.prototype.load;
      FontFace.prototype.load=function(){
        return load.call(this).then(face=>face.family.includes('京華')
          ? new Promise(resolve=>{window.heldDecodeReady=true;window.releaseDecode=()=>resolve(face);}) : face);
      };
    ''')
    page.goto(url,wait_until='domcontentloaded')
    page.locator('#boot').wait_for()
    while len(held)<2: page.wait_for_timeout(30)
    no_game(page)
    page.keyboard.type('start');page.mouse.click(20,20)
    no_game(page)
    page.screenshot(path=str(OUT/'independent-font-loader.png'))
    next(r for r in held if 'huiwen' in r.request.url).continue_()
    page.wait_for_function("document.querySelector('#boot-detail').textContent.startsWith('1 / 2')")
    no_game(page)
    next(r for r in held if 'jinghua' in r.request.url).continue_()
    page.wait_for_function('window.heldDecodeReady')
    no_game(page)
    page.evaluate('releaseDecode()')
    page.locator('html[data-fonts=ready]').wait_for(state='attached')
    page.locator('#boot-continue').click()
    page.locator('#enterGame').wait_for(timeout=30000)
    assert page.locator('#boot').count()==0
    assert page.evaluate("Array.from(document.fonts).length===2 && Array.from(document.fonts).every(f=>f.status==='loaded')")
    assert '汇文明朝体' in page.locator('.startup-gate h1').evaluate('e=>getComputedStyle(e).fontFamily')
    assert '京華老宋体v3.0' in page.locator('#enterGame').evaluate('e=>getComputedStyle(e).fontFamily')
    page.screenshot(path=str(OUT/'startup-fonts.png'))
    page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached')
    page.locator('[data-command=ready]').click()
    assert page.locator('.modal').count()==0
    assert '汇文明朝体' in page.locator('.choice-card.selected strong').evaluate('e=>getComputedStyle(e).fontFamily')
    assert '京華老宋体v3.0' in page.locator('.choice-card.selected .cmd-badge').evaluate('e=>getComputedStyle(e).fontFamily')
    # Inspect actual rendered glyph fonts, not just the CSS fallback stack.
    cdp=context.new_cdp_session(page)
    cdp.send('DOM.enable');cdp.send('CSS.enable')
    doc=cdp.send('DOM.getDocument')['root']['nodeId']
    for selector in ['.choice-card.selected strong','.hero-caption p']:
        node=cdp.send('DOM.querySelector',{'nodeId':doc,'selector':selector})['nodeId']
        fonts=cdp.send('CSS.getPlatformFontsForNode',{'nodeId':node})['fonts']
        assert any(f['isCustomFont'] and f['glyphCount']>0 for f in fonts),fonts
    page.screenshot(path=str(OUT/'home-fonts.png'))
    print('PASS independent system-font widget; both download and decode gates block game UI; real custom glyphs render',flush=True)
    context.close()

    context=browser.new_context(viewport={'width':1280,'height':720},reduced_motion='reduce')
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
    fail=[True]
    page.route('**/font/*.woff2?*',lambda route:route.abort() if fail[0] else route.continue_())
    page.goto(url)
    page.locator('html[data-fonts=error]').wait_for(state='attached')
    no_game(page)
    fail[0]=False
    page.locator('#boot-retry').click()
    page.locator('html[data-fonts=ready]').wait_for(state='attached')
    page.locator('#boot-continue').click()
    page.locator('#enterGame').wait_for(timeout=30000)
    print('PASS failed downloads preserve the independent widget; retry loads fonts before revealing startup',flush=True)
    context.close()

    context=browser.new_context(viewport={'width':1280,'height':720},reduced_motion='reduce')
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
    held=[]
    page.route('**/font/*.woff2?*',lambda route:held.append(route))
    page.clock.install()
    page.goto(url,wait_until='domcontentloaded')
    while len(held)<2: page.wait_for_timeout(30)
    page.clock.fast_forward(30100)
    page.locator('html[data-fonts=error]').wait_for(state='attached')
    no_game(page)
    for route in held: route.continue_()
    page.wait_for_function("Array.from(document.fonts).filter(f=>f.status==='loaded').length===2")
    no_game(page)
    page.locator('#boot-retry').click()
    page.locator('html[data-fonts=ready]').wait_for(state='attached')
    page.locator('#boot-continue').click()
    page.locator('#enterGame').wait_for(timeout=30000)
    assert len(held)==2
    print('PASS slow downloads time out visibly; late completion cannot bypass the gate; retry reuses loaded fonts',flush=True)
    context.close()

    page=browser.new_page(viewport={'width':1920,'height':1080},reduced_motion='reduce')
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false}));")
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('html[data-fonts=ready]').wait_for(state='attached')
    page.locator('#boot-continue').click()
    page.locator('#enterGame').wait_for(timeout=30000)
    assert page.evaluate("Array.from(document.fonts).length===2 && Array.from(document.fonts).every(f=>f.status==='loaded')")
    page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached')
    page.locator('#startBtn').click()
    page.screenshot(path=str(OUT/'deployment-fonts.png'))
    page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'",timeout=30000)
    print('PASS offline release loads both local fonts and enters battle; only WOFF2 fonts are packaged',flush=True)
    assert len(list((ROOT/'dist/font').glob('*.woff2')))==2
    assert not list((ROOT/'dist/font').glob('*.ttf')) and not list((ROOT/'dist/font').glob('*.otf'))
    assert not errors,errors
    browser.close()
finally:
    server.shutdown();server.server_close()
