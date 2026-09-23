"""Talent persistence and combat weave UI regression, through a fresh browser profile.

Run against a built distribution, or set KEYABYSS_URL to the local development URL.
The debug bridge creates deterministic combat scenarios; menus use actual UI controls.
"""
import json
import os
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.temp/combat-refactor/integration/browser'
OUT.mkdir(parents=True, exist_ok=True)
BASE = os.environ.get('KEYABYSS_URL', (ROOT / 'dist/index.html').as_uri())
URL = BASE + ('&' if '?' in BASE else '?') + 'debug'
checks, errors = [], []


def check(name):
    checks.append(name)
    print('PASS', name, flush=True)


def saved(page, key):
    return page.evaluate("key => JSON.parse(localStorage.getItem('keyabyss.' + key))?.data", key)


def command(page, word):
    return page.locator(f'[data-command="{word}"]:visible')


def allocate(page, name):
    page.get_by_role('button', name=re.compile('^' + name + '，')).click()
    expect(command(page, 'allocate')).to_be_enabled()
    command(page, 'allocate').click()
    expect(page.get_by_role('button', name=re.compile('^' + name + '，'))).to_have_attribute('aria-pressed', 'true')


SETUP = """async book => {
  const g = __KEYABYSS__.game;
  await g.prepareRenderer(); cancelAnimationFrame(g.frame);
  g.start({ book, mode:'normal', words:[{word:'abcdefghijkl',meaning:'组合测试'}],
    vocabTitle:'组合验证', seed:'WEAVE-BROWSER', progressive:false });
  g.sound.enabled=false; g.enemies=[]; g.nodes=[]; g.tasks=[];
  g.spawnClock=g.nodeClock=999; g.roomQuota=999; g.player.invuln=999;
  for (const [x,y] of [[760,320],[980,470],[330,350],[470,530]]) {
    const e=g.spawnEnemy('guard',x,y,false,true);
    e.grace=0; e.hp=e.maxHp=100000; e.speed=0;
  }
  g.emit('hud'); g.render();
}"""


with sync_playwright() as p:
    browser = launch_browser(p)
    context = browser.new_context(viewport={'width':1920,'height':1080}, reduced_motion='reduce')
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    # Skip previously covered introduction/calibration, while still loading real fonts and assets.
    page.add_init_script("""
      localStorage.setItem('keyabyss.preflight-complete','true');
      localStorage.setItem('keyabyss.calibration-complete','true');
      localStorage.setItem('keyabyss.intro-complete','true');
      localStorage.setItem('keyabyss.settings',JSON.stringify({reduceMotion:true,music:false,sound:false}));
    """)
    try:
        page.goto(URL)
        page.locator('.startup-gate[data-ready="true"]').wait_for(timeout=60000)
        page.keyboard.press('Enter')
        page.locator('.startup-gate').wait_for(state='detached')
        page.locator('#home').wait_for()
        command(page, 'talents').click()
        allocate(page, '凝墨')
        allocate(page, '晶构')
        page.get_by_role('button', name=re.compile('^合订，')).click()
        expect(command(page, 'allocate')).to_be_disabled()
        assert saved(page, 'talents')['manualCharacters'] == 0
        check('normal allocation obeys the initial two-point budget')

        # Layout assertions protect the fixed action/header while only the content scrolls.
        for width, height in [(1024,640),(1920,1080)]:
            page.set_viewport_size({'width':width,'height':height})
            page.locator('.talent-detail-scroll').evaluate('e => e.scrollTop=e.scrollHeight')
            rects = page.evaluate("""() => ['#modalTitle','.close-button','.talent-detail > .button','.talent-footer'].map(s => {
              const r=document.querySelector(s).getBoundingClientRect();
              return {selector:s,x:r.x,y:r.y,right:r.right,bottom:r.bottom};
            })""")
            assert all(r['x'] >= 0 and r['y'] >= 0 and r['right'] <= width and r['bottom'] <= height for r in rects), rects
            page.screenshot(path=str(OUT / f'talents-{width}.png'))
        check('talent title, back, allocate and footer stay visible at desktop window sizes')
        command(page, 'back').click()

        # Ten completed 12-letter words produce a real report and exactly one persistent point.
        page.evaluate(SETUP, 'storm')
        summary = page.evaluate("""() => {
          const g=__KEYABYSS__.game,e=g.enemies[0];
          for(let i=0;i<10;i++){g.cancel(false);g.target=e;for(const letter of e.word)g.input(letter);}
          const summary=g.weave.summary;g.end(false,'abandoned');return summary;
        }""")
        assert summary['manualCharacters'] == 120, summary
        page.locator('.outcome-modal').wait_for()
        expect(page.locator('.report-talents')).to_contain_text('120')
        ordinary = saved(page, 'talents')
        assert ordinary['manualCharacters'] == 120 and list(ordinary['receipts'].values())[0]['points'] == 1
        archive = saved(page, 'archive')
        page.evaluate('__KEYABYSS__.game.home()')
        page.locator('#home').wait_for()
        check('actual completed input settles one cross-run talent point and appears in the report')

        page.keyboard.type('imsuperman')
        command(page, 'talents').click()
        expect(page.locator('.talent-toolbar')).to_contain_text('GOD MODE')
        for name in ['凝墨','晶构','合订','热载','温墨','焰页']:
            allocate(page, name)
        page.locator('#talentSecondary').click()
        page.get_by_role('option', name='灰烬之书').click()
        god = saved(page, 'talents-god')
        assert god['byBook']['frost']['secondaryBook'] == 'flame', god
        assert len(god['byBook']['frost']['allocated']) > 5
        assert saved(page, 'talents') == ordinary
        check('God Mode exceeds the earned budget, selects a secondary book and keeps ordinary talents intact')
        command(page, 'back').click()
        page.evaluate(SETUP, 'flame')
        page.evaluate("""() => {const g=__KEYABYSS__.game;g.target=g.enemies[0];for(const l of g.target.word)g.input(l);g.end(false,'abandoned');}""")
        page.locator('.outcome-modal').wait_for()
        assert saved(page, 'talents') == ordinary
        assert saved(page, 'archive')['career'] == archive['career']
        page.evaluate('__KEYABYSS__.game.home()')
        page.locator('#home').wait_for()
        command(page, 'talents').click()
        command(page, 'cleargod').click()
        assert saved(page, 'talents-god')['byBook'] == {}
        cleared = saved(page, 'archive')
        assert cleared['records'] == archive['records'] and cleared['career'] == archive['career']
        assert 'godCareer' not in cleared and not any(c.get('godMode') for c in cleared['checkpoints'].values())
        assert saved(page, 'talents') == ordinary
        check('God cleanup removes its configuration, reports and counters while retaining all ordinary data')

        # Render actual new combat objects, including the retained target word and letter flight.
        command(page, 'back').click()
        page.evaluate(SETUP, 'frost')
        scene = page.evaluate("""() => {
          const g=__KEYABYSS__.game;g.relics.copyfolio=2;g.relics.emberink=1;g.relics.letterwake=1;
          const e=g.enemies[0];g.target=e;g.prefix='abc';g.kill(e);
          g.weaveCast(g.enemies[1],100,12,t=>g.strike(t,100,{kind:'ice',direct:true}));
          g.weave.update(g,.35);g.impact(980,470,'#8fdfff',1.3,'ice');
          g.arc(g.player,g.enemies[2],'#ffe2a6',4,.5);
          g.emit('hud');g.render();
          return {pages:g.weave.pages.length,letters:g.weave.letters.length,label:g.castLabel};
        }""")
        assert scene['pages'] > 0 and scene['letters'] == 3, scene
        assert scene['label']['text'] == 'abcdefghijkl', scene
        page.screenshot(path=str(OUT / 'weave-residual.png'))
        check('residual word, flying letters, carrier pages and elemental effects render together')
        assert not errors, errors
    except Exception as error:
        errors.append(str(error))
        raise
    finally:
        (OUT / 'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
        browser.close()
