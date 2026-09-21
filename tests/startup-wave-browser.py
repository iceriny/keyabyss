"""Two startup pulses, localized refraction, audio transient timing and cleanup."""
from pathlib import Path
from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-output-startup-wave'
OUT.mkdir(exist_ok=True)
errors = []
with sync_playwright() as p:
    browser = launch_browser(p)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.add_init_script('''
      window.heldFrames = [];
      const raf = window.requestAnimationFrame.bind(window);
      window.requestAnimationFrame = cb => raf(t => {
        if (window.holdFrames) heldFrames.push(() => cb(t)); else cb(t);
      });
      window.playbacks=[];
      const start=AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start=function(when,offset=0,duration) {
        if (this.buffer && offset>0) {
          const channels=Array.from({length:this.buffer.numberOfChannels},(_,i)=>this.buffer.getChannelData(i));
          const rate=this.buffer.sampleRate, energies=[];
          let max=0;
          const step=Math.round(rate*.01);
          for(let i=Math.floor(offset*rate);i<Math.min(channels[0].length-step,rate);i+=step) {
            let energy=0;for(const data of channels)for(let j=i;j<i+step;j++)energy+=data[j]*data[j];
            max=Math.max(max,energy);energies.push({energy,time:i/rate});
          }
          const attack=energies.find(e=>e.energy>=max*.25).time;
          playbacks.push({source:this,time:performance.now(),offset,duration,attackSource:attack-offset});
        }
        return start.apply(this,arguments);
      };
    ''')
    page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
    page.locator('#enterGame').wait_for(timeout=30000)
    page.evaluate('''() => {
      window.cues=[]; const sound=__KEYABYSS__.game.sound, ui=sound.ui.bind(sound);
      sound.ui=kind=>{cues.push({kind,time:performance.now()});ui(kind);};
      const observer = new MutationObserver(() => {
        if (cues.length && !document.querySelector('.startup-gate')) {
          window.handoffTime=performance.now(); observer.disconnect();
        }
      });
      observer.observe(document.body,{childList:true,subtree:true});
    }''')
    page.mouse.click(30,30)
    def at(ms):
        page.wait_for_function('(ms) => performance.now()-cues[0].time >= ms', arg=ms)
    def light():
        return page.locator('.ritual-flare').evaluate('e=>parseFloat(getComputedStyle(e).opacity)')
    at(120)
    assert .2 < light() < .6
    assert page.locator('.startup-visual').get_attribute('data-wave') == 'first'
    first_strength = float(page.locator('feDisplacementMap').get_attribute('scale'))
    assert first_strength > 50
    page.screenshot(path=str(OUT/'01-seal-flash.png'))
    at(1550)
    assert light() == 0
    assert page.locator('.startup-visual').evaluate('e=>getComputedStyle(e).filter') == 'none'
    page.screenshot(path=str(OUT/'02-hold.png'))
    at(2800)
    assert light() > .5
    assert page.locator('.startup-visual').get_attribute('data-wave') == 'second'
    assert float(page.locator('feDisplacementMap').get_attribute('scale')) > first_strength * 2.5
    page.evaluate("window.holdFrames=true;window.heldAnimations=document.getAnimations().filter(a=>a.playState==='running');heldAnimations.forEach(a=>a.pause())")
    page.wait_for_timeout(80)
    page.screenshot(path=str(OUT/'03-wave-refracted.png'))
    effect = page.locator('.startup-visual').evaluate('e=>e.style.filter')
    page.locator('.startup-visual').evaluate("e=>e.style.filter='none'")
    page.screenshot(path=str(OUT/'03-wave-unfiltered.png'))
    diff = ImageChops.difference(Image.open(OUT/'03-wave-refracted.png').convert('RGB'), Image.open(OUT/'03-wave-unfiltered.png').convert('RGB'))
    changed = sum(max(pixel)>12 for pixel in diff.get_flattened_data())
    assert changed > 1000, changed
    page.locator('.startup-visual').evaluate('(e,value)=>e.style.filter=value', effect)
    page.evaluate('window.holdFrames=false;heldFrames.splice(0).forEach(f=>f());heldAnimations.forEach(a=>a.play())')
    at(4750)
    radius = page.locator('.startup-visual').evaluate("e=>parseFloat(e.style.getPropertyValue('--wave-radius'))")
    assert radius > (960**2 + (1080*.52)**2)**.5, radius
    page.screenshot(path=str(OUT/'04-wave-outside.png'))
    at(5600)
    assert light() == 0
    assert page.locator('.startup-visual').evaluate('e=>getComputedStyle(e).filter') == 'none'
    page.keyboard.type('start')
    assert page.locator('.modal').count() == 0
    page.locator('.startup-gate').wait_for(state='detached')
    elapsed=page.evaluate('handoffTime-cues[0].time')
    assert 6900 <= elapsed < 7300, elapsed
    assert page.locator('.startup-filter').count() == 0
    assert [c['kind'] for c in page.evaluate('cues')] == ['enter','ritualRise','ritualImpact','ritualChime']
    cues = page.evaluate('cues')
    attacks = page.evaluate('playbacks.map(({source,...entry})=>({...entry,rate:source.playbackRate.value,attackDelay:entry.attackSource/source.playbackRate.value}))')
    immediate = next(a for a in attacks if abs(a['offset']-.17)<.001)
    heavy = next(a for a in attacks if abs(a['offset']-.465)<.001)
    assert immediate['attackDelay'] < .06, immediate
    assert heavy['attackDelay'] < .13 and abs(heavy['rate']-.58)<.001, heavy
    assert abs(heavy['time'] - cues[2]['time']) < 80, (heavy,cues)
    assert 2300 < cues[2]['time']-cues[0]['time'] < 2600, cues
    assert page.locator('#startBtn').is_visible()
    print(f'PASS immediate lighter wave then strong wave, {changed} refracted pixels, wave exits corners, clean handoff at {elapsed:.0f}ms', flush=True)
    print(f"PASS decoded audio attacks: first {immediate['attackDelay']*1000:.0f}ms, hammer {heavy['attackDelay']*1000:.0f}ms after visual release", flush=True)
    page.emulate_media(reduced_motion='reduce')
    page.reload()
    page.locator('#enterGame').wait_for(timeout=30000)
    page.keyboard.press('Enter')
    page.locator('.startup-gate').wait_for(state='detached', timeout=2000)
    assert not errors, errors
    print('PASS reduced motion enters directly without refraction; no browser errors', flush=True)
    browser.close()
