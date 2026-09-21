"""Release checks for the timed ritual and spatial book navigation."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-output-ritual-menu'
OUT.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto((ROOT / 'dist/index.html').as_uri() + '?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    page.evaluate('''() => {
      window.cues = [];
      const sound = __KEYABYSS__.game.sound, original = sound.ui.bind(sound);
      sound.ui = kind => { cues.push({kind, time: performance.now()}); original(kind); };
    }''')
    page.keyboard.press('Enter')
    page.wait_for_timeout(1900)
    assert page.locator('.startup-gate').count() == 1
    assert page.locator('.ritual-phase').inner_text().startswith('静候')
    page.screenshot(path=str(OUT / 'ritual-converge.png'))
    page.wait_for_function("cues.some(c => c.kind === 'ritualImpact')")
    page.wait_for_timeout(100)
    page.screenshot(path=str(OUT / 'ritual-impact.png'))
    assert page.locator('.startup-gate').count() == 1
    # Repeated commands cannot deploy while the seal is breaking.
    page.keyboard.type('start')
    assert page.locator('.modal').count() == 0
    page.locator('.startup-gate').wait_for(state='detached')
    cues = page.evaluate("cues.filter(c => ['enter','ritualRise','ritualImpact','ritualChime'].includes(c.kind))")
    assert [c['kind'] for c in cues] == ['enter', 'ritualRise', 'ritualImpact', 'ritualChime'], cues
    assert 2300 < cues[2]['time'] - cues[0]['time'] < 2700, cues
    print('PASS extended ritual consumes input and plays ordered, timed impact and texture cues', flush=True)

    books = page.locator('.book-grid .choice-card')
    assert books.count() == 4
    styles = books.evaluate_all("es => es.map(e => ({filter:getComputedStyle(e).filter, width:e.getBoundingClientRect().width, border:getComputedStyle(e).borderWidth}))")
    assert all(s['border'] == '0px' for s in styles), styles
    assert styles[0]['width'] > styles[2]['width'] * 1.7, styles
    assert 'blur(3.2px)' in styles[2]['filter'], styles
    for school in ['storm', 'spirit', 'flame', 'frost']:
        page.locator(f'[data-book={school}]').click()
        page.wait_for_timeout(1400)
        box = page.locator(f'[data-book={school}]').bounding_box()
        assert abs(box['x'] + box['width']/2 - 960) < 2, box
        assert page.locator(f'[data-book={school}]').get_attribute('aria-pressed') == 'true'
    assert page.evaluate("cues.filter(c => c.kind === 'book').length") == 4
    page.screenshot(path=str(OUT / 'archive-1080.png'))
    print('PASS all books rotate to foreground with depth blur and book-specific audio', flush=True)

    for width, height in [(1280,720)]:
        page.set_viewport_size({'width':width,'height':height})
        page.wait_for_timeout(250)
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        for selector in ['#startBtn', '.camp-menu', '.hero-caption']:
            box = page.locator(selector).bounding_box()
            assert box['x'] >= 0 and box['y'] >= 0 and box['x']+box['width'] <= width+1 and box['y']+box['height'] <= height, (width,selector,box)
        assert page.locator('#startBtn').evaluate('(e) => { const r=e.getBoundingClientRect(); return e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)); }')
        page.screenshot(path=str(OUT / f'archive-{width}.png'))
    page.locator('#startBtn').click()
    page.locator('#beginRun').wait_for()
    assert not errors, errors
    print('PASS desktop layout keeps deployment and camp navigation reachable', flush=True)
    browser.close()
