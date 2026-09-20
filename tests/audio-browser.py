"""Real Chrome decode, Three positional audio, lifecycle and editor regression."""
from pathlib import Path
import json
import sys
from playwright.sync_api import sync_playwright
from browser_support import launch_browser

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'src/generated/audio-manifest.ts').read_text(encoding='utf-8').split(' = ',1)[1].rstrip(';\n'))
ui_clips={clip['id'] for key,group in manifest.items() if key.startswith('ui.') for clip in group}
clip_count=len({clip['id'] for group in manifest.values() for clip in group})
OUT=ROOT/'docs/test-output-audio';OUT.mkdir(exist_ok=True)
checks=[];errors=[];requests=[]
def check(text):checks.append(text);print('PASS',text,flush=True)

with sync_playwright() as p:
 browser=launch_browser(p)
 page=browser.new_page(viewport={'width':1920,'height':1080})
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('request',lambda r:requests.append(r.url))
 page.add_init_script("localStorage.setItem('keyabyss.tutorial','true');localStorage.setItem('keyabyss.settings',JSON.stringify({music:false}));")
 page.goto((ROOT/'dist/index.html').as_uri()+'?debug')
 page.locator('#enterGame').wait_for(timeout=30000)
 initial=page.evaluate('__KEYABYSS__.game.sound.diagnostics()')
 assert initial['cached']==len(ui_clips) and initial['errors']==0,initial
 assert len([r for r in requests if '/audio/' in r])==len(ui_clips)
 page.keyboard.press('a');page.locator('#startBtn').wait_for()
 page.wait_for_function('__KEYABYSS__.game.sound.played>0')
 check('file:// decodes the UI bank before entry; first user gesture unlocks real sample playback')
 page.locator('#startBtn').click();page.locator('#beginRun').click()
 page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.evaluate("""()=>{const g=__KEYABYSS__.game;g.godMode=true;g.enemies=[];g.nodes=[];g.spawnClock=g.nodeClock=999;g.roomQuota=999;g.sound.music=false;}""")
 assert page.evaluate('__KEYABYSS__.game.sound.diagnostics().errors')==0
 check('deployment prewarms common combat and the selected book, with original WAVs never requested')
 assert not any(r.lower().endswith('.wav') for r in requests)
 # Inspect actual stereo output after native HRTF panners, not just Object3D coordinates.
 page.evaluate("""()=>{const s=__KEYABYSS__.game.sound,c=s.ctx;window.audioSplit=c.createChannelSplitter(2);window.audioMeters=[c.createAnalyser(),c.createAnalyser()];s.listener.getInput().connect(audioSplit);audioMeters.forEach((a,i)=>{a.fftSize=2048;audioSplit.connect(a,i);});}""")
 measurements=[]
 for offset in [-500,500]:
  page.evaluate("""offset=>{const g=__KEYABYSS__.game,s=g.sound;s.stopEffects();s.impact('ice',1,{x:g.player.x+offset,y:g.player.y});}""",offset)
  page.wait_for_function('__KEYABYSS__.game.sound.diagnostics().spatialVoices.length>0')
  page.wait_for_timeout(180)
  result=page.evaluate("""()=>({meters:audioMeters.map(a=>{const d=new Float32Array(a.fftSize);a.getFloatTimeDomainData(d);return Math.sqrt(d.reduce((sum,n)=>sum+n*n,0)/d.length);}),diag:__KEYABYSS__.game.sound.diagnostics(),panners:__KEYABYSS__.game.sound.pool.filter(v=>v.audio.isPlaying&&v.audio.panner).map(v=>v.audio.panner.positionX.value)})""")
  measurements.append(result['meters'])
  left,right=result['meters']
  assert max(left,right)>.00005,result
  assert (left>right*1.1 if offset<0 else right>left*1.1),result
  assert all(v['model']=='HRTF' for v in result['diag']['spatialVoices'])
 check('actual PCM output pans left/right through Three HRTF with audible sample energy')
 page.keyboard.press('Escape');page.wait_for_selector('[role=dialog]')
 page.wait_for_function('__KEYABYSS__.game.sound.diagnostics().spatialVoices.length===0')
 page.evaluate("__KEYABYSS__.game.sound.ui('confirm')")
 assert page.evaluate('__KEYABYSS__.game.sound.voices')>0
 page.keyboard.press('Escape');page.wait_for_function("__KEYABYSS__.game.state==='playing'")
 page.wait_for_function("__KEYABYSS__.game.sound.state==='playing'")
 # Repeated calls exercise cooldown and voice reuse, without creating an unbounded graph.
 page.evaluate("""()=>{const s=__KEYABYSS__.game.sound;for(let i=0;i<200;i++)s.impact('ice',1,{x:100+i,y:300});}""")
 stress=page.evaluate('__KEYABYSS__.game.sound.diagnostics()')
 assert stress['dropped']>=190 and stress['pool']<=sum(stress['voiceLimits'].values()) and stress['bytes']<=stress['budget'],stress
 page.evaluate('__KEYABYSS__.game.sound.enabled=false;__KEYABYSS__.game.sound.enabled=false')
 assert page.evaluate('__KEYABYSS__.game.sound.voices')==0
 page.evaluate('__KEYABYSS__.game.sound.enabled=true')
 check('pause stops world voices but permits menu audio; repeated mute and burst traffic retain bounded resources')
 # Validate every packaged FLAC, including variants not selected during this short battle.
 page.evaluate("""async()=>{const s=__KEYABYSS__.game.sound;for(const group of ['frost','storm','spirit','flame'])await s.prepare(group);}""")
 clips=list({clip['id']:clip for group in manifest.values() for clip in group}.values())
 all_clips=page.evaluate("""async clips=>{const c=__KEYABYSS__.game.sound.cache;let peak=0;const timer=setInterval(()=>peak=Math.max(peak,c.diagnostics().activeDecoders),1);const loaded=await Promise.all(clips.map(clip=>c.load(clip)));clearInterval(timer);return {count:loaded.length,peak,diag:c.diagnostics(),rates:[...new Set(loaded.map(b=>b.sampleRate))]};}""",clips)
 assert all_clips['count']==clip_count and all_clips['peak']<=4 and all_clips['rates']==[48000],all_clips
 assert all_clips['diag']['bytes']<=all_clips['diag']['budget'] and all_clips['diag']['errors']==0
 check(f'all {clip_count} packaged variants decode at 48kHz within four concurrent decoders and the 64MiB LRU budget')
 # Repeated lifecycle exercise catches disconnected panners and stale playback callbacks.
 for i in range(3):
  page.evaluate("__KEYABYSS__.game.sound.cast('flame',false,{x:200,y:300})")
  page.wait_for_timeout(220)
  page.evaluate('__KEYABYSS__.game.sound.stopEffects();__KEYABYSS__.game.sound.stopEffects()')
 page.evaluate("""()=>{const s=__KEYABYSS__.game.sound;s.update({x:500,y:400},'playing',true);s.ui('confirm');}""")
 assert page.evaluate('__KEYABYSS__.game.sound.voices')==0
 page.evaluate('__KEYABYSS__.game.sound.dispose();__KEYABYSS__.game.sound.dispose()')
 disposed=page.evaluate('__KEYABYSS__.game.sound.diagnostics()')
 assert disposed['bytes']==0 and disposed['voices']==0 and disposed['pool']==0,disposed
 check('book changes, hidden-page muting and idempotent disposal release voices and decoded cache')
 assert not errors,errors
 if '--runtime-only' not in sys.argv:
  # The editor uses the same real Vite server and persistent override file.
  editor=browser.new_page(viewport={'width':1440,'height':1000})
  editor.on('pageerror',lambda e:errors.append(str(e)))
  editor.goto('http://127.0.0.1:4318/tools/audio-preview.html')
  editor.wait_for_function("document.querySelector('#summary').textContent.includes('576')")
  editor.locator('#search').fill('FOCUS-Hover');editor.locator('#list button').click()
  assert editor.locator('.region').count()==4
  editor.locator('.region button').first.click()
  editor.wait_for_function("document.querySelector('#player').currentTime>0")
  editor.wait_for_function("document.querySelector('#player').paused",timeout=10000)
  assert editor.evaluate("document.querySelector('#player').currentTime<1")
  editor.screenshot(path=str(OUT/'editor.png'))
  # Validate save endpoint with an existing reviewed entry so the test adds no edits.
  saved=(ROOT/'data/audio-overrides.json').read_bytes()
  try:
   file='UIClick_SELECT-Enter_B00M_MUIDS.wav';regions=json.loads(saved)[file]
   result=editor.request.post('http://127.0.0.1:4318/__audio/overrides',data={'file':file,'regions':regions})
   assert result.ok,result.text()
   invalid=editor.request.post('http://127.0.0.1:4318/__audio/overrides',data={'file':file,'regions':[{'start':-1,'end':9000}]})
   assert invalid.status==400
  finally:(ROOT/'data/audio-overrides.json').write_bytes(saved)
  check('editor searches workbook descriptions, auditions one region, saves valid boundaries and rejects invalid edits')
  assert not errors,errors
 browser.close()
(OUT/('runtime-report.json' if '--runtime-only' in sys.argv else 'report.json')).write_text(json.dumps({'checks':checks,'errors':errors,'stereoRMS':measurements,'stress':stress},ensure_ascii=False,indent=2),encoding='utf-8')
