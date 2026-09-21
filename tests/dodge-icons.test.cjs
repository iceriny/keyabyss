const test=require('node:test'),assert=require('node:assert/strict');
const {createGame,isolate,C}=require('./harness.cjs');
const {relicArt}=require('../src/ui/relic-art.ts');
const make=()=>isolate(createGame());
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
test('automatic dodge returns inward from all four edges without overriding arrow input',()=>{
 for(const edge of ['left','right','top','bottom']){
  const g=make(),a=g.arena,c={x:(a.l+a.r)/2,y:(a.t+a.b)/2};
  g.player.x=edge==='left'?a.l+35:edge==='right'?a.r-35:c.x;
  g.player.y=edge==='top'?a.t+35:edge==='bottom'?a.b-35:c.y;
  const q=g.findSafe();assert(distance(q,c)<distance(g.player,c)-80,edge);
  g.aimKeys.ArrowRight=true;assert.equal(g.findSafe().manual,true);assert(g.findSafe().x>=g.player.x);
 }
});
test('automatic dodge anticipates a bullet arriving after invulnerability and does not mutate it',()=>{
 const g=make(),q=g.findSafe();
 const b=g.bullet(q.x-220,q.y,0,200,'#fff');b.life=3;
 const before={...b};const safer=g.findSafe();
 assert(distance(safer,q)>50);assert.deepEqual(b,before);
 assert.deepEqual(g.findSafe(),safer,'search is deterministic');
});
test('moving bodies and imminent hazards override the inward preference',()=>{
 const g=make(),q=g.findSafe();const e=g.spawnEnemy('guard',q.x-200,q.y);
 e.vx=180;e.vy=0;e.grace=0;e.freeze=e.stun=0;
 assert(distance(g.findSafe(),q)>45);
 const h=make();h.player.x=h.arena.l+40;const inward=h.findSafe();
 h.makeBlast(inward.x,inward.y,120,1.1,null,false);
 assert(distance(h.findSafe(),inward)>100);
});
test('frost ultimate ice arrives from all four sides with unchanged damage and cadence',()=>{
 const g=make(),e=g.spawnEnemy('guard',640,400);let from,damage,options;
 g.launchShot=(origin,target,kind,dmg,opts)=>{from=origin;damage=dmg;options=opts;assert.equal(kind,'ice');};
 for(const angle of [0,.25,.5,.75]){
  let n=0;g.rng=()=>++n===3?angle:.5;g.ultTick=0;g.bookBehavior.tick(g);
  assert(Math.abs(distance(from,e)-264)<1e-7);
  assert(Math.abs(from.x-e.x-Math.cos(angle*Math.PI*2)*264)<1e-7);
  assert(Math.abs(from.y-e.y-Math.sin(angle*Math.PI*2)*264)<1e-7);
  assert.equal(damage,30*g.damageMultiplier());assert.equal(g.ultTick,.25);assert.equal(options.empowered,true);
 }
});
test('every relic has its own vector engraving and no emoji icon',()=>{
 assert.equal(Object.keys(relicArt).length,C.RELICS.length);
 assert.equal(new Set(Object.values(relicArt)).size,C.RELICS.length);
 for(const r of C.RELICS){assert(relicArt[r.id]?.startsWith('M'),r.id);assert.equal(r.icon,r.id);assert(!/\p{Extended_Pictographic}/u.test(r.icon));}
});
