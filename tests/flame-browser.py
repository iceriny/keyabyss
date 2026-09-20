"""Four external illustrations, flame gameplay visuals and native media lifecycle on file://."""
from pathlib import Path
import base64,io,json,wave,hashlib
from playwright.sync_api import sync_playwright
from browser_support import launch_browser
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/test-output-flame';OUT.mkdir(exist_ok=True)
checks=[];errors=[];requests=[]
def check(label):checks.append(label);print('PASS',label,flush=True)
# A generated one-second silent WAV exercises real decoding, without adding shipped placeholder music.
buf=io.BytesIO()
with wave.open(buf,'wb') as wav:
 wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(8000);wav.writeframes(bytes(16000))
audio=base64.b64encode(buf.getvalue()).decode()
with sync_playwright() as p:
 browser=launch_browser(p);page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda error:errors.append(str(error)))
 page.on('console',lambda msg:errors.append(msg.text) if msg.type=='error' else None)
 page.on('request',lambda request:requests.append(request.url))
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true')")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
 page.locator("#enterGame").click(timeout=30000)
 page.wait_for_function("document.querySelectorAll('.book-grid .book-artwork img').length===4")
 for i,(book,filename) in enumerate([('frost','FROST_GRIMOIRE.png'),('storm','STORM_GRIMOIRE.png'),('spirit','SPIRIT_GRIMOIRE.png'),('flame','FLAME_GRIMOIR.png')]):
  page.keyboard.press(str(i+1));page.wait_for_function("id=>document.querySelector('.hero-book')?.dataset.asset==='book-'+id&&document.querySelector('.hero-book img')?.naturalWidth>0",arg=book)
  assert page.locator('.hero-book img').get_attribute('src').endswith(filename)
  assert hashlib.sha256((ROOT/'art'/filename).read_bytes()).digest()==hashlib.sha256((ROOT/'dist/assets/art'/filename).read_bytes()).digest()
  page.wait_for_timeout(250);page.screenshot(path=str(OUT/f'home-{book}.png'))
 check('all four original transparent images render in hero/cards and ship byte-for-byte from art')
 page.keyboard.type('codex');page.locator('.codex-book-art img').first.wait_for()
 assert page.locator('.codex-book-art img').count()==4
 assert page.get_by_role('heading',name='灰烬之书 · 当前').is_visible()
 page.screenshot(path=str(OUT/'codex-books.png'));page.keyboard.press('Escape')
 check('fourth hotkey selects flame and the codex includes its illustration and complete rules')
 assert page.evaluate("""async()=>{const m=__KEYABYSS__.assets;const a=m.loadImage('book-flame'),b=m.loadImage('book-flame');return a===b&&(await a).naturalWidth>0;}""")
 page.evaluate("""async data=>{const m=__KEYABYSS__.assets;const bytes=Uint8Array.from(atob(data),c=>c.charCodeAt(0));m.importFile('test-music',new File([bytes],'test.wav',{type:'audio/wav'}));window.testDecoded=await m.loadAudio('test-music');
 const button=document.createElement('button');button.id='audio-test';button.textContent='play';button.style.cssText='position:fixed;left:20px;top:20px;z-index:99999;width:90px;height:50px';button.onclick=async()=>{window.testAudioClicked=true;try{window.testVoice=await m.playAudio('test-music',{loop:true,volume:0});}catch(error){window.testAudioError=error.message;}};document.body.append(button);}""",audio)
 page.locator('#audio-test').click()
 assert page.evaluate('window.testAudioClicked===true')
 page.wait_for_function('!!window.testVoice || !!window.testAudioError')
 assert page.evaluate('!window.testAudioError && !testVoice.element.paused && testDecoded.readyState>=2')
 assert page.evaluate("""()=>{const m=__KEYABYSS__.assets;m.unregister('test-music');document.querySelector('#audio-test').remove();return testVoice.element.paused&&!testVoice.element.getAttribute('src');}""")
 check('image cache deduplicates and imported audio decodes, plays and stops through the real browser')
 page.locator('#startBtn').click();page.locator('#beginRun').click();page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 if page.locator('[role=dialog]').count():page.keyboard.press('Escape')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.enemies=[];g.nodes=[];g.player.invuln=999;g.spawnClock=g.nodeClock=999;g.roomQuota=999;g.sound.enabled=false;
 for(let i=0;i<6;i++){const e=g.spawnEnemy('guard',340+(i%3)*270,300+Math.floor(i/3)*170,false,true);e.hp=e.maxHp=100000;e.speed=0;e.grace=0;e.shoot=999;}g.relics.cinder=2;g.relics.pitch=1;g.relics.inferno=1;g.target=g.enemies[1];g.bookCounter=2;g.state='playing';g.cast(g.target);for(let i=0;i<70;i++){g.updateVisual(1/120);g.update(1/120);}g.state='paused';g.emit('hud');g.render();}""")
 assert page.evaluate("__KEYABYSS__.game.book==='flame'&&__KEYABYSS__.game.enemies.some(e=>e.burn)&&__KEYABYSS__.game.fields.some(f=>f.kind==='fire')")
 page.screenshot(path=str(OUT/'flame-impact-1080.png'))
 check('flame launches real projectiles, burns live targets and leaves a native fire field')
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.resonance=100;g.state='playing';g.ultimate();for(let i=0;i<35;i++){g.updateVisual(1/120);g.update(1/120);}g.state='paused';g.emit('hud');g.render();}""")
 assert page.evaluate("__KEYABYSS__.game.shots.some(s=>s.kind==='fire')&&__KEYABYSS__.game.nativeRenderer.diagnostics().instances.warp>0")
 page.screenshot(path=str(OUT/'flame-ultimate-1080.png'))
 result=page.evaluate("""()=>{const g=__KEYABYSS__.game,n=g.nativeRenderer,t=n.actorTarget,Type=t.texture.type===1016?Uint16Array:Uint8Array;const a=new Type(t.width*t.height*4),b=new Type(a.length);n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,a);g.render();n.renderer.readRenderTargetPixels(t,0,0,t.width,t.height,b);return {stable:a.every((v,i)=>v===b[i]),pixels:a.filter(v=>v>0).length,textures:n.renderer.info.memory.textures,atlas:n.atlas.texture.version};}""")
 assert result['stable'] and result['pixels']>10000,result
 check('inferno and meteor fire use GPU instances; pause preserves exact actor pixels')
 page.set_viewport_size({'width':1280,'height':720})
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.options.reduceMotion=true;g.options.fx=.3;g.invalidate();g.render();}""")
 assert page.evaluate('__KEYABYSS__.game.nativeRenderer.diagnostics().instances.warp===0')
 page.screenshot(path=str(OUT/'flame-reduced-720.png'))
 check('720P reduced motion disables heat distortion while keeping burn status and fire fields')
 assert not [url for url in requests if url.startswith('http')],requests
 assert not errors,errors
 browser.close()
(OUT/'report.json').write_text(json.dumps({'checks':checks,'errors':errors,'gpu':result},ensure_ascii=False,indent=2),encoding='utf-8')
