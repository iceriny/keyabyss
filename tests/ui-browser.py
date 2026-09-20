"""React/TypeScript release integration: real file URL, keyboard, persistence and visual layouts."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'test-output-native-ui'
OUT.mkdir(parents=True, exist_ok=True)
checks, errors, requests = [], [], []

def record(name):
    checks.append(name)
    print('PASS', name, flush=True)

def word(page, text):
    page.keyboard.type(text, delay=20)
    page.wait_for_timeout(100)

def audit(page):
    result = page.evaluate('''() => {
      const root = document.querySelector('[role=dialog]') || document.querySelector('[data-menu-root]');
      const items = [...root.querySelectorAll('[data-command]')].filter(el => el.getClientRects().length && !el.closest('[hidden],[inert]'));
      const words = items.map(el => el.dataset.command);
      return { words, duplicates:words.filter((a,i)=>words.some((b,j)=>i!==j&&b.startsWith(a))),
        tiny: [...root.querySelectorAll('*')].filter(el=>el.getClientRects().length && [...el.childNodes].some(n=>n.nodeType===3&&n.textContent.trim()) && parseFloat(getComputedStyle(el).fontSize)<12).map(el=>el.textContent),
        overflow: document.documentElement.scrollWidth > innerWidth };
    }''')
    assert not result['duplicates'], result
    assert not result['tiny'], result
    assert not result['overflow'], result
    return result

with sync_playwright() as p:
    browser = launch_browser(p)
    context = browser.new_context(viewport={'width':1440,'height':900}, accept_downloads=True)
    page = context.new_page()
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('request', lambda r: requests.append(r.url))
    page.set_default_timeout(20000)
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator("#enterGame").click(timeout=30000)
    page.locator('.startup-gate').wait_for(state='detached')
    page.wait_for_selector('#startBtn')
    page.wait_for_function('!!window.__KEYABYSS__')
    audit(page)
    assert page.locator('select').count() == 0
    assert page.locator('body').evaluate("e=>getComputedStyle(e).userSelect") == 'none'
    assert not [r for r in requests if r.startswith('http')], requests
    page.screenshot(path=str(OUT/'home.png'))
    record('file:// boots with no runtime network requests, native selects or selectable game text')

    for width,height in [(1280,720),(1366,768),(1920,1080),(800,900),(390,844)]:
        page.set_viewport_size({'width':width,'height':height})
        page.wait_for_timeout(100)
        audit(page)
        page.locator('#startBtn').scroll_into_view_if_needed()
        box = page.locator('#startBtn').bounding_box()
        dock = page.locator('#commandDock').bounding_box()
        assert box['y'] >= 0 and box['y'] + box['height'] <= dock['y'], (width,height,box,dock)
        page.screenshot(path=str(OUT/f'home-{width}.png'))
    page.set_viewport_size({'width':1440,'height':900})
    record('start action remains reachable at 720p, 768p, 1080p, tablet and narrow widths')

    word(page,'staX')
    assert page.locator('#startBtn').evaluate("e=>e.classList.contains('command-match')")
    page.keyboard.press('Enter')
    assert not page.locator('[role=dialog]').count()
    page.keyboard.press('Escape')
    word(page,'storm')
    assert page.locator('[data-book=storm]').get_attribute('aria-pressed') == 'true'
    page.keyboard.press('3')
    assert page.locator('[data-book=spirit]').get_attribute('aria-pressed') == 'true'
    word(page,'frost'); word(page,'start'); audit(page)
    page.screenshot(path=str(OUT/'deployment.png'))
    record('menu prefix, ignored typo, Escape and book hotkeys work across React renders')

    old = page.locator('#vocabSelect .button-content').inner_text()
    word(page,'list'); page.keyboard.press('ArrowDown'); page.keyboard.press('Escape')
    assert page.locator('#vocabSelect .button-content').inner_text() == old
    assert page.locator('#vocabSelect').evaluate('e=>e===document.activeElement')
    word(page,'list'); page.keyboard.press('ArrowDown'); page.keyboard.press('Enter')
    assert page.locator('#vocabSelect .button-content').inner_text() != old
    word(page,'list')
    page.screenshot(path=str(OUT/'vocab-select.png'))
    page.keyboard.press('End'); page.keyboard.press('Enter')
    assert 'CMU' in page.locator('#vocabSelect').inner_text()
    word(page,'list'); page.keyboard.press('Home'); page.keyboard.press('Enter')
    word(page,'easy'); word(page,'seed'); page.keyboard.type('TEST-REACT')
    page.keyboard.press('Enter'); word(page,'seed'); page.keyboard.type('CANCELLED'); page.keyboard.press('Escape')
    assert page.locator('#seedInput').input_value() == 'TEST-REACT'
    record('custom listbox supports roving, selection, Escape rollback and focus return; fields own text input')

    word(page,'import'); audit(page); word(page,'paste')
    word(page,'name'); page.keyboard.type('QA.json'); page.keyboard.press('Enter')
    word(page,'content'); page.keyboard.type(json.dumps({'title':'<img src=x onerror=alert(1)>','words':['class','co_await','start','quit']}))
    page.keyboard.press('Tab'); word(page,'analyze'); audit(page)
    page.screenshot(path=str(OUT/'import.png'))
    word(page,'accept'); page.wait_for_timeout(100)
    assert page.locator('.vocab-detail h3').inner_text() == '<img src=x onerror=alert(1)>'
    assert page.locator('.vocab-detail img').count() == 0
    word(page,'back')
    assert page.locator('#modalTitle').inner_text() == '准备出征'
    record('JSON import previews and escapes content, custom vocabulary returns to deployment')

    word(page,'begin')
    if page.locator('#beginTutorial').count(): word(page,'begin')
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    assert page.evaluate('__KEYABYSS__.game.config.words.length') == 4
    assert page.locator('.portal').count() == 0
    page.screenshot(path=str(OUT/'combat.png'))
    page.keyboard.press('Escape'); word(page,'settings'); audit(page)
    page.screenshot(path=str(OUT/'settings.png'))
    word(page,'volume'); page.keyboard.press('ArrowLeft'); page.keyboard.press('Enter')
    word(page,'effects'); page.keyboard.press('End'); page.keyboard.press('Enter')
    assert page.evaluate('__KEYABYSS__.game.options.fx') == .3
    word(page,'motion'); assert page.evaluate('__KEYABYSS__.game.options.reduceMotion')
    word(page,'back'); assert page.locator('#modalTitle').inner_text() == '已暂停'
    word(page,'resume'); page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    record('selected library starts combat; pause/settings return to pause; live settings apply')

    # Inject a deterministic combat fixture; actual keystrokes exercise the production input path.
    page.evaluate('''() => {const g=__KEYABYSS__.game;g.enemies=[];g.nodes=[];g.tasks=[];g.shots=[];g.bullets=[];g.spawnClock=999;g.nodeClock=999;g.roomQuota=999;g.spawned=0;g.player.invuln=999;
      const e=g.spawnEnemy('guard',640,260);e.word='co_await';e.hp=e.maxHp=99999;g.target=e;g.resonance=100;g.sound.enabled=false;
    }''')
    page.keyboard.type('co'); page.keyboard.press('Shift+_')
    assert page.evaluate('__KEYABYSS__.game.ultimates') == 0
    page.keyboard.type('await')
    assert page.evaluate('__KEYABYSS__.game.casts') == 1, page.evaluate('({casts:__KEYABYSS__.game.casts,prefix:__KEYABYSS__.game.prefix,errors:__KEYABYSS__.game.errors,state:__KEYABYSS__.game.state,word:__KEYABYSS__.game.target?.word})')
    page.keyboard.press('Shift')
    assert page.evaluate('__KEYABYSS__.game.ultimates') == 1
    page.keyboard.press('Escape'); word(page,'quit'); word(page,'cancel')
    assert page.locator('#modalTitle').inner_text() == '已暂停'
    word(page,'quit'); word(page,'confirm'); audit(page)
    page.screenshot(path=str(OUT/'result.png'))
    record('C++ underscore does not trigger ultimate; Shift tap does; quit cancellation and result work')

    word(page,'retry')
    page.evaluate("() => {const g=__KEYABYSS__.game;g.setState('upgrade');g.emit('upgrade',g.upgradeChoices());}")
    page.wait_for_selector('[data-upgrade]'); audit(page)
    ids = page.locator('[data-upgrade]').evaluate_all('els=>els.map(e=>e.dataset.upgrade)')
    word(page,'quit'); word(page,'cancel')
    assert ids == page.locator('[data-upgrade]').evaluate_all('els=>els.map(e=>e.dataset.upgrade)')
    page.screenshot(path=str(OUT/'upgrade.png'))
    page.keyboard.press('1'); page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.evaluate('__KEYABYSS__.game.completeRoom()')
    page.wait_for_selector('[data-route]'); audit(page)
    page.screenshot(path=str(OUT/'route.png'))
    page.keyboard.press('1'); page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.evaluate('__KEYABYSS__.game.home()')
    page.reload(); page.locator("#enterGame").click(); page.locator('.startup-gate').wait_for(state='detached'); page.wait_for_selector('#startBtn'); word(page,'vocab')
    assert page.get_by_text('<img src=x onerror=alert(1)>', exact=True).count() >= 1
    record('upgrades and routes survive confirmation; local vocabulary persists across file reload')
    # Exercise all spell renderers at full effects, including the refraction pass.
    word(page,'back')
    for school in ['frost','storm','spirit']:
        page.evaluate('async()=>await __KEYABYSS__.game.prepareRenderer()')
        page.evaluate('''school => {const g=__KEYABYSS__.game;g.start({book:school,mode:'normal',words:[{word:'class',meaning:'类'}],vocabTitle:'VFX',progressive:false,seed:'VFX'});g.sound.enabled=false;g.options.fx=1;g.options.reduceMotion=false;g.player.invuln=999;g.resonance=100;g.input('Shift');}''', school)
        page.wait_for_timeout(120)
        page.screenshot(path=str(OUT/f'{school}-ultimate.png'))
        assert page.evaluate("__KEYABYSS__.game.nativeRenderer.diagnostics().backend==='three-native'")
        page.evaluate('__KEYABYSS__.game.home()')
        page.wait_for_timeout(100)
    record('three schools render native GPU ultimate effects without corrupting HUD')
    page.set_viewport_size({'width':1280,'height':720})
    page.evaluate("""() => {const g=__KEYABYSS__.game;g.start({book:'frost',mode:'apocalypse',words:[{word:'reinterpret_cast'}],vocabTitle:'Dense labels',progressive:false,seed:'DENSE'});g.enemies=[];g.nodes=[];g.spawnClock=999;g.nodeClock=999;g.player.invuln=999;g.sound.enabled=false;g.options.largeText=true;for(let i=0;i<24;i++)g.spawnEnemy('guard',550+(i%4)*30,270+Math.floor(i/4)*30,false,true);g.state='paused';}""")
    page.wait_for_timeout(150)
    dense = page.evaluate("""()=>{const ls=__KEYABYSS__.game.labels;return {count:ls.length,overlap:ls.flatMap((a,i)=>ls.slice(i+1).filter(b=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y)).length,minFont:Math.min(...ls.map(l=>l.font))}}""")
    assert dense['count'] == 24 and dense['overlap'] > 0 and dense['minFont'] >= 16, dense
    assert page.evaluate("__KEYABYSS__.game.labels.every(l=>Math.abs(l.x+l.w/2-l.target.x)<1&&Math.abs(l.y+l.h+12+l.target.r-l.target.y)<1)")
    page.screenshot(path=str(OUT/'dense-labels.png'))
    page.evaluate('__KEYABYSS__.game.home()')
    record('24 clustered long C++ labels keep stable owner anchors with deliberate priority overlap at 720p')
    # Source sync is fulfilled locally: exercise fallback without relying on live upstream data.
    library = context.new_page()
    library.on('pageerror', lambda e: errors.append(str(e)))
    await_sources = []
    library.route('https://raw.githubusercontent.com/**', lambda route: (await_sources.append(route.request.url), route.abort()))
    library.route('https://cdn.jsdelivr.net/**', lambda route: (await_sources.append(route.request.url), route.fulfill(status=200,content_type='application/json',body=json.dumps([{'name':'alpha','trans':['第一']},{'name':'beta','trans':['第二']}]))))
    library.goto((ROOT/'dist/index.html').as_uri())
    library.locator("#enterGame").click(timeout=30000)
    library.locator('.startup-gate').wait_for(state='detached')
    library.wait_for_selector('#startBtn')
    word(library,'vocab'); word(library,'grade1'); word(library,'sync')
    library.wait_for_function("document.querySelector('.vocab-detail h3').textContent.includes('同步版')")
    assert len(await_sources) == 4  # Both semesters, each with primary-source fallback.
    with library.expect_download() as download_event:
        word(library,'export')
    payload = json.loads(Path(download_event.value.path()).read_text(encoding='utf-8'))
    assert [w['word'] for w in payload['words']] == ['alpha','beta']
    with library.expect_file_chooser() as chooser:
        word(library,'file')
    chooser.value.set_files({'name':'file-qa.csv','mimeType':'text/csv','buffer':'word,meaning\nclass,类\nco_await,等待\nclass,重复'.encode('utf-8')})
    library.wait_for_selector('.import-report')
    assert '2 个可用词条' in library.locator('.import-report').inner_text()
    word(library,'accept')
    assert library.locator('.vocab-detail h3').inner_text() == 'file-qa'
    word(library,'delete'); word(library,'cancel')
    assert library.locator('.vocab-detail h3').inner_text() == 'file-qa'
    word(library,'delete'); word(library,'confirm')
    assert not library.get_by_text('file-qa',exact=True).count()
    library.close()
    record('source fallback, vocabulary export, real file input and delete confirmation preserve data flow')
    # No invisible combat if the native world cannot initialize.
    fallback = context.new_page()
    fallback.on('pageerror', lambda e: errors.append(str(e)))
    fallback.add_init_script("const original=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(type,...args){return type.startsWith('webgl')?null:original.call(this,type,...args)}")
    fallback.goto((ROOT/'dist/index.html').as_uri())
    fallback.get_by_text('无法建立 WebGL 2 战场。请启用浏览器硬件加速后重试。',exact=True).wait_for()
    assert fallback.locator('#enterGame').count()==0
    assert fallback.locator('.startup-gate [data-command=retry]').is_visible()
    fallback.screenshot(path=str(OUT/'webgl-fallback.png'))
    fallback.close()
    record('WebGL unavailable: startup explains the problem and offers a retry')
    assert not errors, errors
    assert not [r for r in requests if r.startswith('http')], requests
    (OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors,'network':requests},ensure_ascii=False,indent=2),encoding='utf-8')
    browser.close()
