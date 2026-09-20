/** Deterministic heuristic-input probe, not a human playtest or an invulnerability run. */
const {createGame,C,school}=require('../tests/harness.cjs');
const fs=require('node:fs'),path=require('node:path');
function simulate(book,mode,wpm,seconds=150,seed='BALANCE-01',defenses=true){
 const g=createGame(school,book,mode,seed);let letterClock=0,elapsed=0,maxEnemies=0,maxBullets=0,upgrades=0,previousStage=0,parries=0;
 let offered=[];g.events.upgrade=choices=>{offered=choices;};
 const preferences=['power','short','frost','shatter','chain','spirit','armor','dashnova','heal','leech','perfect','haste','bond','brittle','conductor'];
 for(let ticks=0;ticks<seconds*60&&g.state!=='result';ticks++){
  if(g.state==='upgrade'){
   const choices=[...offered];if(!choices.length)throw new Error("Missing reward offer");choices.sort((a,b)=>score(b)-score(a));g.chooseUpgrade(choices[0].id);upgrades++;continue;
   function score(r){return (r.tag===g.bookData.short?5:0)+(r.rarity==='awaken'?30:0)+(r.id==='heal'&&g.player.hp<g.player.maxHp*.5?16:0)+(preferences.includes(r.id)?8-preferences.indexOf(r.id)*.2:0);}
  }
  if(g.state==='route'){const options=[...g.routeOffers].sort((a,b)=>routeScore(b)-routeScore(a));if(!options.length)throw new Error('Missing route offer');g.chooseRoute(options[0]);continue;function routeScore(r){return (r.heal&&g.player.hp<g.player.maxHp*.5?40:0)+(r.relic?20:0)+(r.shield?5:0)-(r.hurt?30:0)-(r.type==='elite'?20:0);}}
  if(g.state!=='playing')break;
  const dt=1/60;elapsed+=dt;const p=g.player;
  const danger=g.bullets.some(b=>!b.dead&&!b.reflected&&C.segmentDistance(b.x,b.y,b.x+b.vx*.18,b.y+b.vy*.18,p.x,p.y)<b.r+17)||g.lasers.some(l=>l.warning<.30&&(l.vertical?Math.abs(p.x-l.pos):Math.abs(p.y-l.pos))<l.width+15)||g.blasts.some(b=>b.warning<.3&&Math.hypot(b.x-p.x,b.y-p.y)<b.r+10)||g.enemies.some(e=>!e.dead&&e.grace<=0&&Math.hypot(e.x-p.x,e.y-p.y)<e.r+30);
  const areaDanger=g.lasers.some(l=>!l.dead&&l.warning<.3&&(l.vertical?Math.abs(p.x-l.pos):Math.abs(p.y-l.pos))<l.width+15)||g.blasts.some(b=>!b.dead&&!b.fired&&b.warning<.3&&Math.hypot(b.x-p.x,b.y-p.y)<b.r+10);
  if(defenses&&danger&&p.invuln<=.12&&!p.dashState){
   if(!areaDanger&&p.parryCooldown<=0){g.input(' ');parries++;}
   else if(p.dash>=1&&(areaDanger||p.parryTime<=0)) {
    // The probe chooses and holds a direction; the game never chooses a landing automatically.
    const candidates=[['ArrowLeft'],['ArrowRight'],['ArrowUp'],['ArrowDown'],['ArrowLeft','ArrowUp'],['ArrowRight','ArrowUp'],['ArrowLeft','ArrowDown'],['ArrowRight','ArrowDown']];
    const scored=candidates.map(keys=>{
     keys.forEach(k=>g.input(k));const q=g.findSafe();keys.forEach(k=>g.releaseKey(k));
     let score=Math.hypot(q.x-p.x,q.y-p.y);
     for(const e of g.enemies)if(!e.dead)score-=1200/(Math.hypot(e.x-q.x,e.y-q.y)+15);
     for(const l of g.lasers)if(!l.dead&&(l.vertical?Math.abs(q.x-l.pos):Math.abs(q.y-l.pos))<l.width+20)score-=300;
     for(const b of g.blasts)if(!b.dead&&Math.hypot(b.x-q.x,b.y-q.y)<b.r+15)score-=300;
     for(const b of g.bullets)if(!b.dead&&!b.reflected)score-=250/(C.segmentDistance(b.x,b.y,b.x+b.vx*.8,b.y+b.vy*.8,q.x,q.y)+15);
     return {keys,score};
    }).sort((a,b)=>b.score-a.score);
    scored[0].keys.forEach(k=>g.input(k));g.input(' ');scored[0].keys.forEach(k=>g.releaseKey(k));
   }
  }
  if(g.resonance>=100&&(g.enemies.length>2||g.bossRoom))g.input('Shift');
  letterClock-=dt;
  if(letterClock<=0){
   if(!g.target||g.target.dead){
    const choices=g.targets().filter(t=>!t.dead&&(!t.pendingHits||t.hp>t.maxHp*.65));
    choices.sort((a,b)=>priority(a)-priority(b));const target=choices[0];if(target){g.cancel(false);g.target=target;letterClock=.16;}
   }
   if(g.target&&!g.target.dead){const letter=g.target.word[g.prefix.length];if(letter){g.input(letter);g.releaseKey(letter);}letterClock+=60/(wpm*5);}
   function priority(t){const d=Math.hypot(t.x-p.x,t.y-p.y);return d*.3+t.word.length*12+(t.boss?70:0)+(t.pendingHits?150:0)+(t.kind==='rune'?(g.bullets.length>16?-220:100):0)+(t.type==='priest'?-65:0);}
  }
  g.updateVisual(dt);g.update(dt);maxEnemies=Math.max(maxEnemies,g.enemies.length);maxBullets=Math.max(maxBullets,g.bullets.length);previousStage=g.stage;
 }
 return {book,mode,wpm,seed,defenses,parries,dashes:g.dashes,result:g.state==='result'?(g.lastWin?'win':'defeat'):'ongoing',stage:g.stage+1,seconds:+g.elapsed.toFixed(1),hp:+g.player.hp.toFixed(1),kills:g.kills,casts:g.casts,ultimates:g.ultimates,level:g.level,upgrades,maxEnemies,maxBullets};
}
if(require.main===module){
 const results=[];
 for(const mode of ['story','normal','hard','nightmare','apocalypse'])for(const book of ['frost','storm','spirit','flame']){const r=simulate(book,mode,60,150);results.push(r);console.log(JSON.stringify(r));}
 fs.writeFileSync(path.join(__dirname,'../docs/balance-probe.json'),JSON.stringify({note:'Heuristic directed-dodge and parry simulation at 60 WPM; simulated combat time; no health, damage, cooldown or invulnerability overrides. Not a human difficulty benchmark.',results},null,2));
}
module.exports={simulate};
