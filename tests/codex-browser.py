"""Offline codex/help layouts, keyboard navigation and displayed rarity ordering."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'test-output-codex'
OUT.mkdir(parents=True, exist_ok=True)


def audit(page, selector):
    result = page.locator(selector).evaluate_all('''elements => elements.map(el => {
      const s = getComputedStyle(el);
      return { border: s.borderWidth, radius: s.borderRadius, blur: s.backdropFilter,
        background: s.backgroundColor, overflow: el.scrollWidth > el.clientWidth + 1 };
    })''')
    assert result
    assert all(s['border'] == '0px' and s['radius'] == '0px'
               and s['blur'] != 'none' and s['background'] == 'rgba(0, 0, 0, 0)'
               and not s['overflow'] for s in result), result
    assert not page.evaluate('document.documentElement.scrollWidth > innerWidth')
    assert page.locator('.modal-panel').evaluate('e => e.scrollWidth <= e.clientWidth + 1')


with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto((ROOT / 'dist/index.html').as_uri() + '?debug')
    page.locator('#enterGame').click(timeout=30000)
    page.locator('.startup-gate').wait_for(state='detached')
    page.locator('#startBtn').wait_for()
    for width, height in [(1920, 1080), (1280, 720)]:
        page.set_viewport_size({'width': width, 'height': height})
        page.keyboard.type('codex', delay=20)
        for tab in ['books', 'enemies', 'relics']:
            page.locator(f'[data-command="{tab}"]').click()
            audit(page, '.codex-card')
            if tab == 'relics':
                ranks = {'common': 0, 'rare': 1, 'curse': 2, 'awaken': 3}
                cards = page.locator('[data-relic]').evaluate_all(
                    'els => els.map(e => ({id: e.dataset.relic, rarity: e.dataset.rarity}))')
                levels = [ranks[c['rarity']] for c in cards]
                assert levels == sorted(levels), cards
                assert len(cards) == 58 and len({c['id'] for c in cards}) == 58
                assert [c['id'] for c in cards if c['rarity'] == 'rare'] == ['feather', 'rescue']
                for rarity in ['rare', 'curse', 'awaken']:
                    page.locator(f'[data-rarity="{rarity}"]').first.scroll_into_view_if_needed()
                    page.screenshot(path=str(OUT / f'{rarity}-{width}.png'), animations='disabled')
            page.locator('.modal-panel').evaluate('e => e.scrollTop = 0')
            page.screenshot(path=str(OUT / f'{tab}-{width}.png'), animations='disabled')
        page.keyboard.press('Escape')
        page.keyboard.type('help', delay=20)
        audit(page, '.help-grid article')
        assert page.locator('.help-grid article').count() == 8
        page.screenshot(path=str(OUT / f'help-{width}.png'), animations='disabled')
        page.locator('.help-grid article').last.scroll_into_view_if_needed()
        page.screenshot(path=str(OUT / f'help-end-{width}.png'), animations='disabled')
        page.keyboard.press('Escape')
        print(f'PASS codex, rarity ordering and guide at {width}x{height}', flush=True)
    page.set_viewport_size({'width': 1280, 'height': 720})
    page.keyboard.type('codex', delay=20)
    page.keyboard.press('3')
    assert page.locator('[data-command="relics"]').get_attribute('aria-pressed') == 'true'
    page.keyboard.press('1')
    assert page.locator('[data-command="books"]').get_attribute('aria-pressed') == 'true'
    page.keyboard.press('Escape')
    assert not page.locator('[role="dialog"]').count()
    assert not errors, errors
    print('PASS keyboard tabs, Escape and no browser errors', flush=True)
    browser.close()
