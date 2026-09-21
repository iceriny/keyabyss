"""Relic preview values, formula hold key and desktop reading layout."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080}, reduced_motion='reduce')
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({sound:false,reduceMotion:true}));")
    page.goto((ROOT / 'dist/index.html').as_uri() + '?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached')
    page.locator('[data-command=codex]').click()
    page.locator('[data-command=relics]').click()
    assert '本次施法命中伤害×(0.35' in page.locator('[data-relic=blast] p').first.inner_text()
    page.keyboard.press('Escape')
    page.locator('#startBtn').click()
    page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.locator('.battle-arrival').wait_for(state='detached')
    page.evaluate("""() => {
      const g = __KEYABYSS__.game;
      g.update = () => {}; g.target = null; g.combo = 0;
      g.relics = {blast:1,reach:2,power:2};
      g.setState('upgrade'); g.afterUpgrade = 'play';
      g.emit('upgrade', g.content.relics.filter(r => ['blast','bond','power'].includes(r.id)));
    }""")
    card = page.locator('[data-upgrade=blast] p')
    plain = card.inner_text()
    assert '140' in plain and '本次施法命中伤害×' not in plain, plain
    page.keyboard.down('Backslash')
    page.wait_for_function("document.querySelector('[data-upgrade=blast] p').textContent.includes('本次施法命中伤害×')")
    page.keyboard.up('Backslash')
    assert card.inner_text() == plain
    page.keyboard.down('Backslash')
    page.evaluate("window.dispatchEvent(new Event('blur'))")
    assert card.inner_text() == plain
    page.keyboard.up('Backslash')
    for width, height in [(1024,640), (1920,1080), (3440,1440)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.keyboard.down('Backslash')
        page.wait_for_timeout(100)
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        footer = page.locator('.upgrade-modal .modal-footer').bounding_box()
        companion = page.locator('.upgrade-companion').bounding_box()
        grid = page.locator('.upgrade-modal .choice-grid').bounding_box()
        assert grid['y'] + grid['height'] <= footer['y'] + 1
        assert footer['y'] + footer['height'] <= companion['y'] + 1
        assert companion['y'] + companion['height'] <= height
        page.keyboard.up('Backslash')
    page.set_viewport_size({'width':1920, 'height':1080})
    term = page.locator('.companion-relics [data-term=blast]')
    term.hover()
    page.locator('#gameTooltip').wait_for(state='visible')
    held = page.locator('#gameTooltip p').inner_text()
    assert '本次施法命中伤害×' not in held
    page.keyboard.down('Backslash')
    assert '本次施法命中伤害×' in page.locator('#gameTooltip p').inner_text()
    page.keyboard.up('Backslash')
    assert page.locator('#gameTooltip p').inner_text() == held
    assert not errors, errors
    print('PASS codex formulas, candidate and held values, hold/release/blur, tooltips, three desktop sizes')
    browser.close()
