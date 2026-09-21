"""Open surfaces, stable history geometry and secondary upgrade context."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-open-ui'
OUT.mkdir(exist_ok=True)
errors=[]
with sync_playwright() as p:
    browser=launch_browser(p)
    page=browser.new_page(viewport={'width':1920,'height':1080},reduced_motion='reduce')
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.preflight-complete','true');localStorage.setItem('keyabyss.calibration-complete','true');localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false,reduceMotion:false}));")
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
    page.locator('#startBtn').click();page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.emulate_media(reduced_motion='no-preference')
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.enemies=[];g.spawnClock=999;g.nodeClock=999;g.comboTimer=999;g.player.invuln=100;g.player.hp=72;g.player.shield=30;g.emit('hud');}''')
    shield=page.locator('#hud [role=progressbar][aria-label=护盾]')
    assert shield.get_attribute('aria-valuenow')=='30'
    assert shield.get_attribute('aria-valuemax')=='60'
    assert shield.locator('i').evaluate('e=>e.style.width')=='50%'
    samples=[]
    for count in [1,20,90]:
        page.evaluate('(n)=>{const g=__KEYABYSS__.game;g.combo=n;g.emit("hud")}',count)
        page.wait_for_timeout(50)
        samples.append(page.locator('.combo-value').evaluate('e=>parseFloat(getComputedStyle(e).fontSize)'))
        assert page.locator('.combo-figure').get_attribute('data-change')=='rise'
        assert page.locator('.combo-value').evaluate('e=>e.getAnimations().length')>0
    assert samples[0]<samples[1]<samples[2],samples
    assert page.locator('.combat-side').evaluate('e=>getComputedStyle(e).borderTopWidth')=='0px'
    page.evaluate('''()=>{const g=__KEYABYSS__.game;const e=g.spawnEnemy('nib',600,180);e.word='archive';e.meaning='档案';e.speed=0;g.cancel(false);g.target=e;g.prefix='arc';g.emit('hud');}''')
    assert page.locator('#castWord').inner_text()=='archive'
    assert page.locator('#castBox').evaluate('e=>getComputedStyle(e).backgroundColor')=='rgba(0, 0, 0, 0)'
    page.screenshot(path=str(OUT/'battle-open-hud.png'))
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.relics=Object.fromEntries(g.content.relics.slice(0,14).map(r=>[r.id,1]));g.pending=1;g.upgradeAt=g.time-1;g.postCombat();}''')
    page.locator('.upgrade-modal').wait_for();page.wait_for_timeout(1200)
    assert page.locator('[data-upgrade]').count()==3
    companion=page.locator('.upgrade-companion')
    assert companion.locator('[aria-label=护盾]').get_attribute('aria-valuenow')=='30'
    assert companion.locator('.companion-relics [data-tooltip-title]').count()==14
    choice_bottom=max(b['y']+b['height'] for b in page.locator('[data-upgrade]').evaluate_all('es=>es.map(e=>{const r=e.getBoundingClientRect();return {y:r.y,height:r.height}})'))
    assert companion.bounding_box()['y']>choice_bottom
    page.screenshot(path=str(OUT/'upgrade-companion.png'))
    term=companion.locator('[data-tooltip-title]').first
    term.hover();page.locator('.game-tooltip').wait_for();assert term.get_attribute('data-tooltip-title') in page.locator('.game-tooltip').inner_text()
    page.mouse.move(20,20)
    page.locator('[data-upgrade]').first.click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    # Empty, short and full builds must not move the window or list when switching records.
    page.evaluate('''()=>{const g=__KEYABYSS__.game;for(const count of [0,3,58]){g.start(g.config);g.relics=Object.fromEntries(g.content.relics.slice(0,count).map(r=>[r.id,1]));g.end(false);}}''')
    page.locator('.outcome-modal.defeat').wait_for();page.wait_for_timeout(1400)
    panel=page.locator('.outcome-modal .modal-panel')
    assert panel.evaluate('e=>getComputedStyle(e).backgroundColor')=='rgba(0, 0, 0, 0)'
    assert panel.evaluate('e=>getComputedStyle(e).borderTopWidth')=='0px'
    term=page.locator('.report-relics [data-tooltip-title]').first
    term.hover();page.locator('.game-tooltip').wait_for()
    page.mouse.move(20,20)
    page.screenshot(path=str(OUT/'open-defeat.png'))
    page.locator('[data-command=history]').click();page.wait_for_timeout(500)
    dimensions=[]
    for i in [0,1,2,0]:
        page.locator('.history-entry').nth(i).click();page.wait_for_timeout(50)
        dimensions.append(page.locator('.history-modal .modal-panel').bounding_box())
    assert all(abs(d['height']-dimensions[0]['height'])<1 and abs(d['y']-dimensions[0]['y'])<1 for d in dimensions),dimensions
    assert page.locator('.history-detail .report-relics').evaluate('e=>e.scrollHeight>e.clientHeight')
    page.screenshot(path=str(OUT/'stable-history.png'))
    page.keyboard.press('Escape');page.locator('[data-command=home]').click()
    page.emulate_media(reduced_motion='reduce')
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.start(g.config);g.combo=80;g.comboTimer=999;g.pending=1;g.upgradeAt=g.time-1;g.postCombat();}''')
    page.locator('.upgrade-companion').wait_for()
    assert page.locator('.upgrade-companion').evaluate('e=>getComputedStyle(e).animationName')=='none'
    assert page.locator('.companion-book > i').first.evaluate('e=>getComputedStyle(e).display')=='none'
    assert not errors,errors
    print('PASS growing combo feedback, open casting/buttons/results, live shield bars, upgrade summary/tooltips, stable history across 0/3/58 relics, reduced motion',flush=True)
    browser.close()
