"""Release metadata and local licenses remain accessible through game navigation."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-output-about'
OUT.mkdir(exist_ok=True)

with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width':1280,'height':720}, reduced_motion='reduce')
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:true}));")
    page.goto((ROOT / 'dist/index.html').as_uri())
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter')
    page.locator('[data-command=settings]').click()
    about = page.locator('.settings-about')
    metadata = json.loads((ROOT / 'package.json').read_text(encoding='utf-8'))
    for value in [metadata['version'], metadata['license'], 'Iceriny', 'serinamisssu@gmail.com']:
        assert value in about.inner_text(), value
    for width, height in [(1024,640),(1280,720),(1920,1080)]:
        page.set_viewport_size({'width':width,'height':height})
        page.locator('.settings-content').evaluate('e=>e.scrollTop=e.scrollHeight')
        assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
        for selector in ['.modal-heading','.modal-footer']:
            box = page.locator(selector).bounding_box()
            assert box['y'] >= 0 and box['y'] + box['height'] <= height
        page.screenshot(path=str(OUT / f'about-{width}.png'))
    # Reach every new link through the game's Tab order; do not launch mail or external sites.
    reached = set()
    for _ in range(20):
        page.keyboard.press('Tab')
        href = page.evaluate("document.activeElement.getAttribute('href')")
        if href:
            reached.add(href)
    assert reached == set(about.locator('a').evaluate_all("links=>links.map(a=>a.getAttribute('href'))")), reached
    link = page.get_by_role('link', name='许可全文', exact=True)
    link.focus()
    with page.expect_popup() as opened:
        page.keyboard.press('Enter')
    popup = opened.value
    popup.wait_for_load_state()
    assert 'GNU GENERAL PUBLIC LICENSE' in popup.locator('body').inner_text()
    popup.close()
    with page.expect_popup() as opened:
        page.get_by_role('link', name='第三方许可', exact=True).click()
    popup = opened.value
    popup.wait_for_load_state()
    assert 'node_modules/react/LICENSE' in popup.locator('body').inner_text()
    popup.close()
    assert not errors, errors
    print('PASS About metadata, desktop layout, Tab navigation, Enter activation, offline license text; no page errors', flush=True)
    browser.close()
