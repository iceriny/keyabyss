"""Focused desktop check for the shared graphs and a committed build event."""
import json
import os
import time
import re
from pathlib import Path

from playwright.sync_api import expect, sync_playwright
from browser_support import launch_browser


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / os.environ.get('KEYABYSS_TEST_OUT', '.temp/combat-acceptance/browser/graph-event')
OUT.mkdir(parents=True, exist_ok=True)
checks = []
errors = []


def check(name):
    checks.append(name)
    print('PASS', name, flush=True)


def mouse_click(page, locator):
    bounds = locator.bounding_box()
    page.mouse.click(bounds['x'] + bounds['width'] / 2,
                     bounds['y'] + bounds['height'] / 2)


def assert_selected_center_in_frame(graph):
    frame = graph.locator('.graph-frame').bounding_box()
    ring = graph.locator('.graph-node.is-selected .graph-node-ring').bounding_box()
    assert ring is not None, 'Selected graph node is not rendered'
    center_x = ring['x'] + ring['width'] / 2
    center_y = ring['y'] + ring['height'] / 2
    assert frame['x'] <= center_x <= frame['x'] + frame['width'], (frame, ring)
    assert frame['y'] <= center_y <= frame['y'] + frame['height'], (frame, ring)
    detail = graph.page.locator('.talent-detail')
    if detail.count():
        assert center_x < detail.bounding_box()['x'], 'Selected node is hidden under floating details'


with sync_playwright() as playwright:
    browser = launch_browser(playwright)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080}, reduced_motion='reduce')
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
    page.add_init_script("""
      localStorage.setItem('keyabyss.preflight-complete','true');
      localStorage.setItem('keyabyss.calibration-complete','true');
      localStorage.setItem('keyabyss.intro-complete','true');
      localStorage.setItem('keyabyss.settings',JSON.stringify({reduceMotion:true,music:false,sound:false}));
    """)
    try:
        page.goto(os.environ.get('KEYABYSS_TEST_URL', (ROOT / 'dist/index.html').as_uri()) + '?debug')
        page.locator('.startup-gate[data-ready="true"]').wait_for(timeout=60000)
        page.keyboard.press('Enter')
        page.locator('.startup-gate').wait_for(state='detached')
        page.locator('#home').wait_for()

        mouse_click(page, page.locator('[data-command="codex"]'))
        page.locator('.modal').wait_for()
        mouse_click(page, page.locator('[data-command="relics"]'))
        graph = page.locator('.relic-graph-map .graph-viewport').first
        frame = graph.locator('.graph-frame')
        frame.wait_for()
        selected_name = page.locator('.relic-graph-detail h3').inner_text()
        search = graph.get_by_role('searchbox', name='搜索遗物图谱节点')
        search.fill(selected_name)
        graph.get_by_role('option', name=re.compile('^' + re.escape(selected_name))).first.click()
        expect(page.locator('.relic-graph-detail h3')).to_have_text(selected_name)
        assert_selected_center_in_frame(graph)
        view_before = graph.locator('svg.graph-canvas').get_attribute('viewBox')
        bounds = frame.bounding_box()
        page.mouse.move(bounds['x'] + bounds['width'] / 2, bounds['y'] + bounds['height'] / 2)
        page.mouse.wheel(0, -350)
        expect(graph.locator('svg.graph-canvas')).not_to_have_attribute('viewBox', view_before)
        frame.focus()
        page.keyboard.press('ArrowRight')
        expect(graph.locator('.graph-node.is-focused')).to_have_count(1)
        page.screenshot(path=str(OUT / 'relic-1920.png'))
        page.set_viewport_size({'width': 1024, 'height': 640})
        expect(frame).to_be_visible()
        page.screenshot(path=str(OUT / 'relic-1024.png'))
        check('relic graph search, zoom, keyboard focus and desktop views')

        page.locator('[data-command="back"]').click()
        started = time.perf_counter()
        mouse_click(page, page.locator('[data-command="talents"]:visible').first)
        page.locator('.talents-modal').wait_for()
        page.locator('.talent-map-region .graph-node').first.wait_for()
        print('Talent first nodes visible (ms):', round((time.perf_counter() - started) * 1000), flush=True)
        panel = page.locator('.talents-modal .modal-panel').bounding_box()
        assert abs(panel['x']) <= 1 and abs(panel['y']) <= 1
        assert abs(panel['width'] - page.viewport_size['width']) <= 1
        assert abs(panel['height'] - page.viewport_size['height']) <= 1
        page.screenshot(path=str(OUT / 'talent-1024-overview.png'))
        page.set_viewport_size({'width': 1920, 'height': 1080})
        page.screenshot(path=str(OUT / 'talent-1920-overview.png'))
        page.set_viewport_size({'width': 1024, 'height': 640})
        talents = page.locator('.talent-map-region .graph-viewport')
        talent_search = talents.get_by_role('searchbox', name='搜索天赋图谱节点')
        talent_search.fill('合订')
        talents.get_by_role('option', name=re.compile(r'^合订(?:\s|$)')).click()
        expect(page.locator('.talent-detail h3')).to_have_text('合订')
        expect(talents.locator('.graph-zoom-value')).not_to_have_text('100%')
        expect(talents.locator('.graph-node.is-selected .graph-node-name')).to_be_visible()
        assert talents.locator('.graph-node.is-selected .graph-node-name').bounding_box()['height'] >= 10
        assert_selected_center_in_frame(talents)
        page.screenshot(path=str(OUT / 'talent-1024-selected.png'))
        page.set_viewport_size({'width': 1920, 'height': 1080})
        assert_selected_center_in_frame(talents)
        page.screenshot(path=str(OUT / 'talent-1920-selected.png'))
        details_before = page.locator('.talent-detail').bounding_box()
        frame_bounds = talents.locator('.graph-frame').bounding_box()
        page.mouse.move(frame_bounds['x'] + 40, frame_bounds['y'] + 100)
        page.mouse.down()
        page.mouse.move(frame_bounds['x'] + 160, frame_bounds['y'] + 160, steps=10)
        page.mouse.up()
        assert page.locator('.talent-detail').bounding_box() == details_before
        page.locator('[data-command="back"]').click()
        check('talent graph search keeps the selected node in view after resize')

        page.evaluate("""async () => {
          const g=__KEYABYSS__.game;
          await g.prepareRenderer();
          cancelAnimationFrame(g.frame);
          g.start({book:'frost',mode:'normal',words:[{word:'abcdefghijkl',meaning:'事件验收'}],
            vocabTitle:'事件验收',seed:'EVENT-BROWSER',progressive:false});
          g.sound.enabled=false;
          g.player.invuln=999;
          g.spawnClock=g.nodeClock=999;
          if (!g.openBuildEvent()) throw Error('No eligible event offer');
        }""")
        page.locator('.event-modal').wait_for()
        before = page.evaluate('() => __KEYABYSS__.game.player.maxHp')
        page.get_by_role('radio', name=re.compile('校订本卷')).click()
        expect(page.locator('[data-command="chooseevent"]')).to_be_enabled()
        page.locator('[data-command="chooseevent"]').click()
        page.locator('.event-modal').wait_for(state='detached')
        result = page.evaluate("""() => ({
          maxHp: __KEYABYSS__.game.player.maxHp,
          records: __KEYABYSS__.game.buildEvents.records.map(r => ({choice:r.choice.id,status:r.status}))
        })""")
        assert result['maxHp'] == before - 3, (before, result)
        assert len(result['records']) == 1 and result['records'][0]['choice'] == 'annotate', result
        check('event UI commits exactly one choice and applies its health cost')
        assert not errors, errors
    except Exception as error:
        errors.append(str(error))
        page.screenshot(path=str(OUT / 'failure.png'))
        raise
    finally:
        (OUT / 'report.json').write_text(json.dumps({'checks': checks, 'errors': errors}, ensure_ascii=False, indent=2), encoding='utf-8')
        browser.close()
