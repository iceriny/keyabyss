"""Directional warning, end-of-run presentation and persistent report navigation."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-assault-results'
OUT.mkdir(exist_ok=True)
errors=[]
with sync_playwright() as p:
    browser=launch_browser(p)
    page=browser.new_page(viewport={'width':1920,'height':1080},reduced_motion='reduce')
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script("localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false,reduceMotion:false}));")
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
    page.locator('[data-command=history]').click()
    assert page.locator('.history-empty').is_visible()
    page.keyboard.press('Escape')
    page.locator('#startBtn').click();page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    page.emulate_media(reduced_motion='no-preference')
    # Observe the real overlay draw path, then isolate a readable compass frame.
    page.evaluate('''()=>{const g=__KEYABYSS__.game;window.labelsDrawn=[];
      const fill=CanvasRenderingContext2D.prototype.fillText;
      CanvasRenderingContext2D.prototype.fillText=function(text,...args){if(String(text).includes('来袭')) labelsDrawn.push(text);return fill.call(this,text,...args)};
      g.enemies=[];g.assaultDirection=1;g.spawnClock=999;g.nodeClock=999;
      const e=g.spawnEnemy('nib');e.ambush=true;e.approachDirection=6;e.age=.2;
      g.pause();g.render();}''')
    assert page.evaluate("labelsDrawn.includes('东北 · 来袭')")
    page.keyboard.press('Escape')
    page.wait_for_timeout(100)
    page.screenshot(path=str(OUT/'direction-compass.png'))
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.kills=87;g.casts=132;g.maxCombo=24;g.correct=621;g.errors=18;g.typedTotal=639;g.elapsed=243;g.dashes=18;g.reflections=11;g.perfectDodges=6;g.ultimates=4;g.totalDamage=48213;g.level=7;g.wave=2;
      g.relics=Object.fromEntries(g.content.relics.slice(0,8).map((r,i)=>[r.id,i%2+1]));
      g.wordStats={whisper:{errors:4,meaning:'低语'},archive:{errors:2,meaning:'档案'},crystal:{errors:1,meaning:'水晶'}};
      g.player.invuln=0;g.player.shield=0;g.hurt(9999);}''')
    page.locator('.outcome-modal.defeat').wait_for()
    page.wait_for_timeout(220)
    page.screenshot(path=str(OUT/'defeat-impact.png'))
    page.wait_for_timeout(1600)
    page.screenshot(path=str(OUT/'defeat-report.png'))
    assert '第 2 /' in page.locator('.report-stage').inner_text()
    assert '48,213' in page.locator('.report-tactics').inner_text()
    assert 'whisper' in page.locator('.report-mistakes').inner_text()
    page.locator('[data-command=history]').click()
    assert page.locator('.history-entry').count()==1
    page.wait_for_timeout(1000)
    page.screenshot(path=str(OUT/'history-detail.png'))
    page.keyboard.press('Escape')
    assert page.locator('.outcome-modal.defeat').is_visible()
    page.locator('[data-command=home]').click()
    # Victory exercises campaign completion, with a new independent run.
    page.evaluate('''()=>{const g=__KEYABYSS__.game;g.start(g.config);g.stage=g.content.chapters.reduce((n,c)=>n+c.rooms.length,0)-1;g.beginRoom();g.kills=234;g.casts=310;g.correct=1430;g.typedTotal=1450;g.elapsed=600;g.maxCombo=41;g.completeRoom();}''')
    page.locator('.outcome-modal.victory').wait_for();page.wait_for_timeout(1800)
    page.screenshot(path=str(OUT/'victory-report.png'))
    assert '守页者' in page.locator('.report-stage').inner_text() or page.evaluate('__KEYABYSS__.game.bossRoom')
    page.locator('[data-command=next]').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing' && __KEYABYSS__.game.loopCount===1")
    page.locator('#pauseBtn').click();page.locator('[data-command=quit]').click();page.locator('[data-command=confirm]').click()
    page.locator('.outcome-modal.abandoned').wait_for()
    assert '第 2 周目' in page.locator('.report-stage').inner_text()
    page.locator('[data-command=home]').click()
    page.reload();page.locator('#enterGame').wait_for(timeout=30000)
    page.emulate_media(reduced_motion='reduce');page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
    page.locator('[data-command=history]').click()
    assert page.locator('.history-entry').count()==3
    page.locator('.history-entry').nth(1).click()
    assert '第 1 周目' in page.locator('.history-detail .report-stage').inner_text()
    with page.expect_download() as downloaded: page.locator('[data-command=export]').click()
    assert downloaded.value.suggested_filename=='keyabyss-history-report.json'
    saved=page.evaluate("JSON.parse(localStorage.getItem('keyabyss.archive')).data")
    assert saved['career']['kills']==321,saved['career']
    assert saved['career']['victories']==1 and saved['career']['abandoned']==1 and saved['career']['defeats']==1
    assert saved['career']['talentRanks']=={}
    assert not errors,errors
    print('PASS compass render, defeat and victory effects, stage data, next loop, abandonment, history reload/export, cumulative career without double counting',flush=True)
    browser.close()
