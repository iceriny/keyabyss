"""Rich UI text, shared glossary, delegated tooltips and reduced motion, offline at 1080p."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/test-output-text'; OUT.mkdir(exist_ok=True)
checks=[]; errors=[]
def passed(name): checks.append(name); print('PASS',name,flush=True)
with sync_playwright() as p:
 b=launch_browser(p); page=b.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug'); page.locator('#enterGame').wait_for(timeout=30000)
 page.keyboard.press('Enter');page.locator('.startup-gate').wait_for(state='detached')
 page.keyboard.press('Tab');page.keyboard.press('ArrowDown');page.wait_for_timeout(400)
 assert page.locator('#gameTooltip').count()==0
 assert page.locator('h1 [data-term], h2 [data-term], h3 [data-term], .home-controls [data-term]').count()==0
 page.keyboard.type('help')
 assert page.locator('.help-grid p').nth(1).locator('[data-term=parry]').count()==1
 page.locator('.help-grid p [data-term=parry]').first.hover();page.locator('#gameTooltip').wait_for(state='visible')
 assert page.locator('#gameTooltip').count()==1
 assert page.locator('#gameTooltip .game-number').count()>=3
 assert '0.24' in page.locator('#gameTooltip').inner_text()
 assert page.locator('#gameTooltip [data-term]').count()==0
 box=page.locator('#gameTooltip').bounding_box();assert box['x']>=15 and box['y']>=15 and box['x']+box['width']<=1905 and box['y']+box['height']<=1065,box
 page.mouse.move(box['x']+30,box['y']+30);page.wait_for_timeout(250);assert page.locator('#gameTooltip').is_visible()
 page.screenshot(path=str(OUT/'tooltip-home-1080.png'))
 page.keyboard.press('Escape');assert page.locator('#gameTooltip').count()==0 and page.locator('#startBtn').is_visible()
 assert page.locator('[data-term][tabindex]').count()==0
 passed('one hoverable tooltip, numeric emphasis, viewport avoidance and Escape dismissal without navigating')
 page.mouse.move(10,10);page.locator('[data-command=back]').click();page.keyboard.type('codex');page.locator('[data-command=terms]').click()
 assert page.locator('[data-term-entry]').count()>40
 page.locator('#termSearch').fill('0.24');assert page.locator('[data-term-entry]').count()==1
 card=page.locator('[data-term-entry=parry]');description=card.locator('p').inner_text()
 card.locator('p [data-term=parry]').hover();page.locator('#gameTooltip').wait_for(state='visible')
 assert page.locator('#gameTooltip p').inner_text()==description
 page.wait_for_timeout(300);page.screenshot(path=str(OUT/'glossary-1080.png'))
 page.keyboard.press('Escape');page.locator('#termSearch').fill('不存在的知识')
 assert page.locator('.glossary-empty').is_visible()
 page.locator('#termSearch').fill('');page.locator('#termCategory').click()
 page.locator('[role=option]',has_text='火焰').click()
 assert page.locator('[data-term-entry]').count()>=4
 assert page.locator('[data-term-entry] .term-category').evaluate_all("els=>els.every(e=>e.textContent==='火焰')")
 passed('term search, empty state, categories and exact shared tooltip/codex descriptions')
 page.locator('[data-command=relics]').click()
 card=page.locator('[data-relic=armor]');card.scroll_into_view_if_needed()
 assert card.locator('.game-number',has_text='25%').count()==1
 assert card.locator('h3 [data-term]').count()==0
 page.locator('[data-relic=iceheart] p.accent [data-term]').first.hover();page.locator('#gameTooltip').wait_for(state='visible')
 assert page.locator('#gameTooltip p').inner_text()
 page.locator('[data-command=books]').click();page.wait_for_timeout(100)
 assert page.locator('#gameTooltip').count()==0
 assert page.locator('.game-term .game-term').count()==0
 page.screenshot(path=str(OUT/'codex-books-1080.png'))
 passed('relic values and named-content tooltips; removed anchors close immediately; no nested term triggers')
 page.set_viewport_size({'width':800,'height':900})
 page.locator('.codex-card p [data-term]').first.hover();page.locator('#gameTooltip').wait_for(state='visible')
 box=page.locator('#gameTooltip').bounding_box();assert box['x']>=15 and box['x']+box['width']<=785,box
 page.keyboard.press('Escape');page.mouse.move(5,5);page.locator('[data-command=back]').click()
 page.keyboard.type('settings');page.locator('#settingFx').click();page.locator('[role=option]',has_text='低').click()
 assert page.locator('body').get_attribute('data-ui-fx')=='low'
 page.locator('[data-command=motion]').click();page.locator('[data-command=back]').click()
 page.keyboard.type('help');page.locator('.help-grid p [data-term=parry]').first.hover();page.locator('#gameTooltip').wait_for(state='visible')
 assert page.locator('#gameTooltip').evaluate("e=>getComputedStyle(e).animationName==='none'&&getComputedStyle(e).backdropFilter==='none'")
 page.screenshot(path=str(OUT/'tooltip-low-motion.png'))
 passed('resized tooltip stays in viewport; low effects and reduced motion apply to new UI effects')
 page.keyboard.press('Escape');page.mouse.move(5,5);page.set_viewport_size({'width':1920,'height':1080})
 page.locator('[data-command=back]').click();page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 assert page.locator('#hud .game-number').count()>6
 assert page.locator('.defense-readout [data-term]').count()==0
 assert page.evaluate("__KEYABYSS__.game.state==='playing'")
 page.keyboard.press('Space');assert page.locator('#gameTooltip').count()==0
 assert page.evaluate('__KEYABYSS__.game.player.parryTime>0')
 page.screenshot(path=str(OUT/'hud-1080.png'))
 passed('HUD values remain colored while readouts do not trigger tooltips or intercept combat actions')
 assert not errors,errors
 b.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
