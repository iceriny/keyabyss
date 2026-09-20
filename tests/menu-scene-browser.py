"""Menu shader lifecycle, reusable SVGs and open listbox keyboard behavior."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-output-menu'
OUT.mkdir(exist_ok=True)
checks, errors = [], []
def passed(text):
    checks.append(text)
    print('PASS', text, flush=True)

with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda m: errors.append(m.text) if m.type=='error' else None)
    page.add_init_script("localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false}));")
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.ready')
    page.evaluate('window.savedRenderer=__KEYABYSS__.game.nativeRenderer.renderer')
    page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached')
    page.wait_for_timeout(500)
    assert page.evaluate('__KEYABYSS__.game.menuScene.anchors.length') == 2
    t = page.evaluate('__KEYABYSS__.game.nativeRenderer.menu.meshes[0].material.uniforms.uTime.value')
    def native_pixels():
        return page.evaluate('''()=>{const g=__KEYABYSS__.game;g.render();const c=document.createElement('canvas');c.width=g.canvas.width;c.height=g.canvas.height;const ctx=c.getContext('2d');ctx.drawImage(g.canvas,0,0);const p=ctx.getImageData(0,0,c.width,c.height).data;let bright=0,sum=0;for(let i=0;i<p.length;i+=4){if(p[i+2]>60)bright++;sum+=p[i]+p[i+1]+p[i+2];}return {bright,sum};}''')
    before = native_pixels()
    assert before['bright'] > 1000, before
    page.wait_for_timeout(400)
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.menu.meshes[0].material.uniforms.uTime.value') > t
    assert native_pixels()['sum'] != before['sum']
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.render.calls') == 3
    page.screenshot(path=str(OUT/'home-1080.png'))
    for school in ['storm','spirit','flame','frost']:
        page.locator(f'[data-book="{school}"]').click()
        page.wait_for_timeout(80)
        assert school in page.locator('.hero-pattern').get_attribute('src')
        assert page.evaluate('__KEYABYSS__.game.menuScene.school') == ['frost','storm','spirit','flame'].index(school)
    assert page.evaluate("Array.from(document.querySelectorAll('.magic-pattern')).every(e=>e.complete&&e.naturalWidth>0)")
    assert page.evaluate("Promise.all(['frost','storm','spirit','flame'].map(s=>__KEYABYSS__.assets.loadImage('rune-'+s).then(i=>i.naturalWidth>0))).then(a=>a.every(Boolean))")
    passed('startup prewarms one shared renderer; two animated shader planes follow all four books and SVGs load offline')

    page.locator('#startBtn').click()
    page.locator('#vocabSelect').click()
    box = page.get_by_role('listbox')
    style = box.evaluate('(e)=>{const s=getComputedStyle(e);return [s.borderLeftWidth,s.borderRadius,s.backdropFilter]}')
    assert style == ['0px','0px','blur(26px) saturate(0.7)'], style
    page.wait_for_timeout(300)
    page.screenshot(path=str(OUT/'dropdown-1080.png'))
    page.keyboard.press('End');page.keyboard.press('Enter')
    assert box.count()==0
    assert page.locator('#vocabSelect').evaluate('(e)=>e===document.activeElement')
    page.locator('#vocabSelect').click();page.keyboard.press('Escape')
    assert box.count()==0
    page.locator('#vocabSelect').click();page.locator('#modalTitle').click()
    assert box.count()==0
    passed('open blurred listbox has no enclosing border; keyboard commit, Escape and outside click retain focus behavior')

    page.keyboard.press('Escape')
    page.set_viewport_size({'width':1280,'height':720});page.wait_for_timeout(250)
    anchors=page.evaluate('__KEYABYSS__.game.menuScene.anchors')
    icon=page.locator('.choice-card.selected .choice-icon').bounding_box()
    assert abs(anchors[-1]['x']-(icon['x']+icon['width']/2))<2
    page.screenshot(path=str(OUT/'home-720.png'))
    page.emulate_media(reduced_motion='reduce');page.wait_for_timeout(180)
    assert page.evaluate('__KEYABYSS__.game.menuScene.reduced')
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.menu.meshes[0].material.uniforms.uTime.value') == 0
    before=native_pixels();page.wait_for_timeout(250)
    assert native_pixels()==before
    passed('resize updates anchors; system reduced motion renders a stable native menu')

    page.emulate_media(reduced_motion='no-preference')
    page.locator('#startBtn').click();page.locator('#beginRun').click()
    page.wait_for_function("__KEYABYSS__.game.state==='playing'")
    assert page.evaluate('__KEYABYSS__.game.menuScene===null')
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer===window.savedRenderer')
    page.wait_for_timeout(200)
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer.info.render.calls')>3
    page.evaluate('__KEYABYSS__.game.home()')
    page.wait_for_function('__KEYABYSS__.game.menuScene?.anchors.length>0')
    assert page.evaluate('__KEYABYSS__.game.nativeRenderer.renderer===window.savedRenderer')
    assert not errors, errors
    passed('battle and return to menu reuse the same context with no shader or browser errors')
    browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
