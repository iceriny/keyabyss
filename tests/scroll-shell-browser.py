"""Modal shells keep headings and actions fixed while only content scrolls."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-scroll-shell';OUT.mkdir(exist_ok=True)
with sync_playwright() as p:
    browser=launch_browser(p)
    page=browser.new_page(viewport={'width':1440,'height':900},reduced_motion='reduce')
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:true}));")
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000);page.keyboard.press('Enter')
    page.locator('.calibration-modal').wait_for()
    def check(scroll,anchors):
        box=page.locator('.modal-panel')
        assert box.evaluate('e=>getComputedStyle(e).overflowY')=='hidden'
        before=[page.locator(a).bounding_box() for a in anchors]
        for r in before:assert r['y']>=0 and r['y']+r['height']<900,r
        region=page.locator(scroll)
        assert region.evaluate('e=>e.scrollHeight>e.clientHeight'),scroll
        region.evaluate('e=>e.scrollTop=e.scrollHeight')
        page.wait_for_timeout(100)
        assert region.evaluate('e=>e.scrollTop')>0
        after=[page.locator(a).bounding_box() for a in anchors]
        assert all(abs(a['y']-b['y'])<1 for a,b in zip(before,after)),(before,after)
        assert box.evaluate('e=>e.scrollTop')==0
    check('.settings-content',['.modal-heading','.calibration-reading','[data-command=ready]','.calibration-settings .modal-footer'])
    page.locator('#settingFx').click()
    page.get_by_role('option',name='中 · 均衡表现').click()
    assert page.locator('.modal-panel').evaluate('e=>e.scrollTop')==0
    for _ in range(18): page.keyboard.press('Tab')
    assert page.locator('.modal-panel').evaluate('e=>e.scrollTop')==0
    page.screenshot(path=str(OUT/'calibration-fixed.png'))
    page.locator('[data-command=ready]').click()
    page.locator('[data-command=codex]').click()
    page.locator('[data-command=relics]').click()
    check('.codex-grid',['.modal-heading','.tabs'])
    page.screenshot(path=str(OUT/'codex-fixed.png'))
    page.keyboard.press('Escape');page.locator('[data-command=help]').click()
    check('.help-grid',['.modal-heading'])
    page.screenshot(path=str(OUT/'guide-fixed.png'))
    page.keyboard.press('Escape');page.locator('[data-command=settings]').click()
    check('.settings-content',['.modal-heading','.modal-footer'])
    page.keyboard.press('Escape');page.locator('[data-command=vocab]').click()
    page.locator('[data-command=paste]').click()
    # Force a long validation result to exercise import editor without submitting data.
    page.locator('#pasteText').fill('\n'.join('archive'+str(i) for i in range(100)))
    page.locator('[data-command=analyze]').click()
    check('.panel-scroll',['.modal-heading','.modal-footer'])
    page.screenshot(path=str(OUT/'import-fixed.png'))
    assert not errors,errors
    print('PASS calibration/settings, codex, guide, import: only inner content scrolls; titles/tabs/actions stay fixed',flush=True)
    browser.close()
