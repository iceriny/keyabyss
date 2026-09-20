const {simulate}=require('./balance.cjs'),fs=require('node:fs');
const results=[];
for(const mode of ['story','normal','hard','nightmare','apocalypse'])for(const wpm of [30,60,90])for(const book of ['frost','storm','spirit','flame'])results.push(simulate(book,mode,wpm,150,'DEFENSE-PROBE'));
const controls=[];
for(const mode of ['story','normal'])for(const book of ['frost','storm','spirit','flame'])controls.push(simulate(book,mode,30,150,'DEFENSE-PROBE',false));
fs.writeFileSync(require('node:path').join(__dirname,'../docs/defense-balance-probe.json'),JSON.stringify({note:'Deterministic heuristic, 5 characters per WPM word; fixed elementary dictionary; no God Mode or health/cooldown overrides. The bot observes exact threats and reacts more reliably than a human. Comparative pacing evidence only, not a human difficulty benchmark.',results,controls},null,2)+'\n');
for(const mode of ['story','normal','hard','nightmare','apocalypse'])for(const wpm of [30,60,90]){const group=results.filter(r=>r.mode===mode&&r.wpm===wpm);console.log(JSON.stringify({mode,wpm,survived:group.filter(r=>r.result!=='defeat').length,stages:group.map(r=>r.stage),health:group.map(r=>r.hp)}));}
console.log('controls',JSON.stringify(controls.map(r=>({book:r.book,mode:r.mode,hp:r.hp,result:r.result,seconds:r.seconds}))));
