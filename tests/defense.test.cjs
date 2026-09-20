const test = require("node:test"), assert = require("node:assert/strict");
const { createGame, isolate, step, C } = require("./harness.cjs");
const { DEFENSE } = require("../src/shared/defense.ts");
const game = (book='frost',mode='normal') => { const g=isolate(createGame(['sand','word'],book,mode));g.player.invuln=0;return g; };

test('arrow press immediately dodges once, preserves typing and grants one real second of invulnerability',()=>{
 for(const [key,x,y] of [['ArrowLeft',-1,0],['ArrowUp',0,-1],['ArrowDown',0,1],['ArrowRight',1,0]]) {
  const g=game(),e=g.spawnEnemy('guard',500,300);g.target=e;e.word='sand';g.input('s');const p={...g.player};
  g.input(key);assert.equal(g.dashes,1);assert.equal(g.player.invuln,1);assert.equal(g.prefix,'s');
  g.releaseKey(key);step(g,.2);assert.equal(Math.sign(g.player.x-p.x),x);assert.equal(Math.sign(g.player.y-p.y),y);
  const hp=g.player.hp;g.hurt(10);assert.equal(g.player.hp,hp);step(g,.81);g.hurt(10);assert.equal(g.player.hp,hp-10);
 }
 const g=game();g.input(' ');assert.equal(g.dashes,0);assert(g.player.parryTime>0);
});

test('Alt chooses a nontrivial landing away from enemy bodies and imminent hazards, including boundaries',()=>{
 const g=game();g.player.x=g.arena.l+26;g.player.y=490;
 g.makeBlast(g.player.x,326,115,0,null,false);
 const e=g.spawnEnemy('guard',g.player.x+160,490);e.grace=0;
 const q=g.findSafe();assert.equal(q.manual,false);assert(q.y>490);assert(q.x>=g.arena.l+25);
 g.input('Alt');assert.equal(g.dashes,1);assert.equal(g.player.dashState.tx,q.x);assert.equal(g.player.dashState.ty,q.y);
});

test('parry window expires, cooldown cannot be refreshed early, and zero dash charges do not block parry',()=>{
 const g=game();g.player.dash=0;g.input(' ');const hp=g.player.hp;
 assert.equal(g.player.parryTime,DEFENSE.window);assert.equal(g.player.parryCooldown,DEFENSE.cooldown);
 step(g,.25);assert.equal(g.player.parryTime,0);g.input(' ');assert.equal(g.player.parryTime,0);
 g.bullet(g.player.x+8,g.player.y,Math.PI,100,'#fff');g.updateBullets(.01);assert(g.player.hp<hp);
 step(g,.46);g.input(' ');assert.equal(g.player.parryTime,DEFENSE.window);
 g.relics.rebound=1;g.player.parryCooldown=0;g.input(' ');assert(Math.abs(g.player.parryCooldown-.49)<1e-8);
});

test('swept projectiles reflect physically, lose hostile curve, cannot hit the player, and hit the first enemy once',()=>{
 const g=game(),e=g.spawnEnemy('nib',800,490);e.hp=e.maxHp=1000;e.grace=0;
 const b=g.bullet(710,490,Math.PI,1500,'#fff',{source:e.id,curve:.2});const hp=g.player.hp;
 g.input(' ');g.updateBullets(.04);assert(b.reflected);assert.equal(b.curve,0);assert(b.vx>0);assert.equal(e.hp,1000);assert.equal(g.player.hp,hp);
 g.updateBullets(.12);assert(b.dead);assert.equal(e.hp,968);g.updateBullets(.12);assert.equal(e.hp,968);
 const orphan=g.bullet(g.player.x+12,g.player.y,Math.PI,100,'#fff');g.updateBullets(.01);assert(orphan.reflected);assert(orphan.vx>0);
});

test('successful parry handles a packet of projectiles with one reward and is not an offensive area attack',()=>{
 const g=game(),e=g.spawnEnemy('nib',g.player.x+75,g.player.y);e.hp=1000;
 for(let i=0;i<5;i++)g.bullet(g.player.x+20,g.player.y+i,Math.PI,100,'#fff');
 const energy=g.resonance;g.input(' ');g.updateBullets(.01);assert.equal(g.bullets.filter(b=>b.reflected).length,5);assert.equal(g.resonance,energy+3);assert.equal(e.hp,1000);
});

test('contact parry cancels charge, damages once and strongly knocks back without losing health',()=>{
 for(const type of ['ram','reaper','nib']) {
  const g=game(),e=g.spawnEnemy(type,g.player.x+10,g.player.y);e.grace=0;e.hp=e.maxHp=1000;e.charge=.4;e.cx=-1;e.cy=0;
  const hp=g.player.hp;g.input(' ');g.updateEnemies(.008);assert.equal(g.player.hp,hp);assert.equal(e.charge,0);assert(e.stun>=.8);assert(e.ix>200);assert.equal(e.hp,968);
  g.updateEnemies(.008);assert.equal(e.hp,968);
 }
});

test('parry does not provide blanket invulnerability to laser and ground explosion',()=>{
 const g=game();g.input(' ');const hp=g.player.hp;
 g.lasers=[{vertical:true,pos:g.player.x,width:20,warning:0,warningMax:1,active:.5,age:0,dead:false}];g.updateHazards(.01);assert(g.player.hp<hp);
 g.lasers=[];g.player.invuln=0;const health=g.player.hp;g.makeBlast(g.player.x,g.player.y,90,0,null,false);g.updateHazards(.01);assert(g.player.hp<health);
});

test('the affinity relic attaches each book effect to reflected and contact damage, and baseline counters stay neutral',()=>{
 for(const book of ['frost','storm','flame','spirit']) {
  const g=game(book),e=g.spawnEnemy('nib',800,490);e.hp=e.maxHp=1000;
  g.counterHit(e);assert.equal(e.chill,0);assert.equal(e.conduct,0);assert(!e.burn);assert.equal(e.mark,0);
  g.relics.inscription=1;g.counterHit(e);
  if(book==='frost')assert.equal(e.chill,48);
  if(book==='storm')assert.equal(e.conduct,1);
  if(book==='flame')assert(e.burn?.stacks===1);
  if(book==='spirit'){assert(e.mark>0);assert(g.spiritTime>0);}
 }
});

test('ranged enemies must approach and chargers can actually reach the player on every difficulty',()=>{
 for(const mode of Object.keys(C.MODES)) {
  const g=game('frost',mode),e=g.spawnEnemy('quill',200,490);e.grace=0;e.shoot=0;
  g.enemyAttack(e);assert.equal(g.bullets.length,0);const x=e.x;g.updateEnemies(.1);assert(e.x>x);
  e.x=500;g.enemyAttack(e);assert(g.bullets.length>0);
  for(const kind of ['ram','reaper']) {
   const h=game('frost',mode),r=h.spawnEnemy(kind,240,490);r.grace=0;r.shoot=0;r.hp=1e6;h.enemyAttack(r);assert.equal(r.windup,0);
   r.x=h.player.x-h.enemyProfile(r).chargeSpeed*Math.min(1.35,h.pressure.speed)*.4;
   assert(h.inAttackRange(r));h.enemyAttack(r);assert(r.windup>0);const hp=h.player.hp;
   step(h, r.windup+.65);assert(h.player.hp<hp, mode+' '+kind+' reaches target');
  }
 }
});

test('all modes share defense timing while low ranks offer longer recovery and gentler pressure',()=>{
 const modes=Object.keys(C.MODES);
 for(let i=0;i<modes.length;i++) {
  const m=C.MODES[modes[i]];assert.equal(m.dashI,1);
  if(i) {const last=C.MODES[modes[i-1]];assert(m.dashCD>last.dashCD);assert(m.spawn<last.spawn);assert(m.window<last.window);}
 }
});

test('numeric direction shortcuts preserve literal digits in C++ and imported words',()=>{
 const g=isolate(createGame(['char32_t'],'storm')), e=g.spawnEnemy('guard',640,300);e.hp=1000;g.target=e;
 for(const key of 'char32_t') { g.input(key);g.releaseKey(key); }
 assert.equal(g.casts,1);assert.equal(g.errors,0);assert.equal(g.dashes,0);
});

test('friendly reflected projectiles survive player clears and do not award false perfect dodges',()=>{
 const g=game();const b=g.bullet(g.player.x+35,g.player.y,Math.PI,100,'#fff');b.reflected=true;
 assert.equal(g.clearBullets(g.player.x,g.player.y,200),0);assert(!b.dead);
 g.input('ArrowLeft');assert.equal(g.perfectDodges,0);
});

test('a content-defined short-range ranged enemy approaches inside its configured range before stopping',()=>{
 const g=game(),base=g.enemyProfile.bind(g);g.enemyProfile=e=>({...base(e),attackRange:120});
 const e=g.spawnEnemy('quill',g.player.x-240,g.player.y);e.grace=0;e.shoot=0;
 step(g,10);assert(g.inAttackRange(e));assert(e.shoot>0);
});
