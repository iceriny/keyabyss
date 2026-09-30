export {};
type Region = { start: number; end: number };
type Source = { file: string; description: string; category: string; duration: number; regions: Region[]; peaks: number[] };
const el = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const player = el<HTMLAudioElement>('player'), canvas = el<HTMLCanvasElement>('wave');
let catalog: Source[] = [], edits: Record<string,Region[]> = {}, selected: Source, regions: Region[] = [], stopAt = Infinity, frame = 0;
const status = (text: string) => el('status').textContent = text;
function stop() { player.pause(); cancelAnimationFrame(frame); stopAt=Infinity; }
function watch() { if (player.currentTime >= stopAt) stop(); else if (!player.paused) frame=requestAnimationFrame(watch); }
player.addEventListener('play', () => { cancelAnimationFrame(frame); watch(); });
player.addEventListener('seeking', draw);player.addEventListener('timeupdate', draw);
function draw() {
  if (!selected) return;
  const ctx=canvas.getContext('2d')!, w=canvas.width, h=canvas.height;ctx.clearRect(0,0,w,h);
  regions.forEach((r,i)=> {ctx.fillStyle=['#8ebcbc23','#e2c87b23','#ae9ad723','#8aacdd23'][i%4];ctx.fillRect(r.start/selected.duration*w,0,(r.end-r.start)/selected.duration*w,h);ctx.fillStyle='#b8cccb';ctx.fillText(String(i),r.start/selected.duration*w+5,18);});
  const peak=Math.max(.01,...selected.peaks);ctx.fillStyle='#86abbf';
  selected.peaks.forEach((v,i)=>{const bar=v/peak*(h-44);ctx.fillRect(i/selected.peaks.length*w,(h-bar)/2,1.3,Math.max(1,bar));});
  ctx.fillStyle='#f3d789';ctx.fillRect(player.currentTime/selected.duration*w,0,2,h);
}
function renderRegions() {
  el('regions').replaceChildren();
  regions.forEach((r,i)=> {
    const box=document.createElement('div');box.className='region';const title=document.createElement('strong');title.textContent=`变体 ${i}`;box.append(title,document.createElement('br'));
    for (const key of ['start','end'] as const) {
      const label=document.createElement('label');label.textContent=key==='start'?'开始 / 秒':'结束 / 秒';
      const input=document.createElement('input');input.type='number';input.min='0';input.max=String(selected.duration);input.step='.001';input.value=r[key].toFixed(6);
      input.onchange=()=>{r[key]=Number(input.value);draw();status('边界已修改，尚未保存。');};label.append(input);box.append(label);
    }
    const play=document.createElement('button');play.textContent='试听';play.onclick=()=>{stop();player.currentTime=r.start;stopAt=r.end;void player.play().catch(e=>status(e.message));};
    const remove=document.createElement('button');remove.textContent='删除';remove.onclick=()=>{stop();regions.splice(i,1);renderRegions();draw();};box.append(document.createElement('br'),play,remove);el('regions').append(box);
  });
}
function select(source: Source) {
  stop();selected=source;regions=structuredClone(edits[source.file]??source.regions);
  el('title').textContent=source.category;el('filename').textContent=source.file;el('description').textContent=source.description;
  player.src='/__audio/preview?file='+encodeURIComponent(source.file);player.load();renderRegions();draw();status('');renderList();
}
function renderList() {
  const query=el<HTMLInputElement>('search').value.toLowerCase();el('list').replaceChildren();
  for (const source of catalog.filter(s=>`${s.file} ${s.category} ${s.description}`.toLowerCase().includes(query))) {
    const button=document.createElement('button');button.textContent=source.file.split('_')[1];button.setAttribute('aria-pressed',String(selected===source));
    const small=document.createElement('small');small.textContent=`${(edits[source.file]??source.regions).length} 个变体 · ${source.duration.toFixed(2)} 秒`;button.append(small);button.onclick=()=>select(source);el('list').append(button);
  }
  el('summary').textContent=`${catalog.length} 个文件 / ${catalog.reduce((n,s)=>n+(edits[s.file]??s.regions).length,0)} 个变体`;
}
el('search').addEventListener('input',renderList);
el('add').onclick=()=>{const start=regions.at(-1)?.end??0;regions.push({start,end:Math.min(selected.duration,start+.2)});renderRegions();draw();};
el('reset').onclick=()=>{stop();regions=structuredClone(selected.regions);renderRegions();draw();status('已恢复自动边界，保存后生效。');};
el('save').onclick=async()=>{
  stop();try {
    const response=await fetch('/__audio/overrides',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({file:selected.file,regions})});
    if(!response.ok)throw Error(await response.text());edits[selected.file]=structuredClone(regions);renderList();status('已保存到 data/audio-overrides.json。重新构建音效后游戏生效。');
  }catch(e){status(String(e));}
};
try {catalog=(await (await fetch('/data/audio-catalog.json')).json()).sources;edits=await (await fetch('/data/audio-overrides.json')).json();select(catalog[0]);}
catch(e){status(`无法读取索引，请先运行 npm run audio:scan。${e}`);}
