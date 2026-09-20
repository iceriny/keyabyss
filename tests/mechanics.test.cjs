const test=require('node:test'),assert=require('node:assert/strict');
const {C,createGame:game,isolate,type,step,cpp}=require('./harness.cjs');

test('every one of the 17 enemy/pillar types, split children, boss and node has a current-library word',()=>{
 const g=isolate(game(['co_await'],'frost','apocalypse'));const names=['nib','quill','guard','split','wisp','scribe','leech','sentinel','tower','ram','mortar','priest','binder','mirror','brood','reaper','vortex'];
 g.pressure.cap=24; // This fixture inventories all types together, independently of opening-wave caps.
 for(const kind of names)assert.ok(g.spawnEnemy(kind,250+names.indexOf(kind)*40,300,false,true));g.spawnBoss();g.spawnNode('rune');g.spawnNode('ink');g.kill(g.enemies.find(e=>e.type==='split'));
 assert.ok(g.targets().length>=20);assert.ok(g.targets().every(e=>e.word==='co_await'));
});
test('typing frost launches a real projectile; damage is delayed until physical contact',()=>{
 const g=isolate(game(['class'])),e=g.spawnEnemy('nib',640,280);type(g,e);assert.equal(g.casts,1);assert.equal(e.hp,e.maxHp);assert.equal(g.shots.length,1);step(g,.34);assert.ok(e.dead);
});
test('wrong keys preserve progress, shared-prefix alternatives resolve without an artificial error',()=>{
 const g=isolate(game(['cat','cow'])),a=g.spawnEnemy('guard',400,300),b=g.spawnEnemy('guard',650,300);a.word='cat';b.word='cow';g.target=a;g.input('c');g.input('o');assert.equal(g.target,b);assert.equal(g.prefix,'co');assert.equal(g.errors,0);g.input('x');assert.equal(g.prefix,'co');assert.equal(g.errors,1);g.input('Backspace');assert.equal(g.prefix,'');
});
test('Tab cycles matching prefixes without erasing input',()=>{
 const g=isolate(game(['cat','cow','bird'])),a=g.spawnEnemy('guard'),b=g.spawnEnemy('guard');a.word='cat';b.word='cow';g.target=a;g.input('c');g.input('Tab');assert.equal(g.target,b);assert.equal(g.prefix,'c');
});
test('directed dash travels over time, retains text and consumes exactly one charge',()=>{
 const g=game(['class']);g.input('c');const e=g.target,x=g.player.x;g.input('ArrowRight');g.input(' ');assert.equal(g.player.x,x);assert.equal(g.player.dash,1);assert.ok(g.player.dashState);step(g,.04);assert.ok(g.player.x>x&&g.player.x<x+173);step(g,.2);assert.equal(g.player.dashState,null);assert.equal(g.target,e);assert.equal(g.prefix,'c');g.releaseKey('ArrowRight');
});
test('perfect dodge is risk-triggered, not awarded on every safe dash',()=>{
 const g=isolate(game());g.input("ArrowRight");g.dodge();assert.equal(g.perfectDodges,0);step(g,.25);g.bullets=[];g.bullet(g.player.x+35,g.player.y,Math.PI,100,'#ffaaaa');g.dodge();assert.equal(g.perfectDodges,1);assert.ok(g.resonance>=20);
});
test('mass distinguishes impact response; velocity decays instead of teleporting',()=>{
 const g=isolate(game()),light=g.spawnEnemy('nib',600,300),heavy=g.spawnEnemy('guard',600,500);g.impulse(light,{x:500,y:300},300);g.impulse(heavy,{x:500,y:500},300);assert.ok(light.ix>heavy.ix*2);const x=light.x,initial=light.ix;step(g,.05);assert.ok(light.x>x);assert.ok(light.ix<initial);
});
test('knocked enemy collides with arena wall, takes impact damage and rebounds',()=>{
 const g=isolate(game()),e=g.spawnEnemy('guard',g.arena.r-24,370);e.grace=0;e.hp=e.maxHp=10000;g.impulse(e,{x:900,y:370},1400);const hp=e.hp;step(g,.09);assert.ok(g.wallHits>0);assert.ok(e.hp<hp);assert.ok(e.ix<0);
});
test('body collision transmits momentum from a knocked enemy to another',()=>{
 const g=isolate(game()),a=g.spawnEnemy('guard',550,350),b=g.spawnEnemy('guard',550+a.r*2-1,350);a.grace=b.grace=0;a.ix=430;a.impactTime=.4;g.resolveBodies(.016);assert.ok(b.ix>0);assert.ok(a.ix<430);
});
test('fast projectile collision uses swept segments instead of endpoint-only hit tests',()=>{
 assert.equal(C.segmentDistance(0,0,1000,0,500,0),0);assert.ok(C.segmentDistance(0,0,1000,0,500,10)<=10);
 const g=isolate(game(['class'])),e=g.spawnEnemy('guard',640,350);e.hp=e.maxHp=10000;g.launchShot({x:640,y:490},e,'ice',100,{direct:true,pierce:0});const s=g.shots[0];s.speed=5000;g.updateShots(.06);assert.ok(e.hp<10000);
});
test('frost freezes and leaves a slow field while storm is instant multi-target damage',()=>{
 const f=isolate(game(['class'])),a=f.spawnEnemy('guard',640,315);a.hp=a.maxHp=1000;f.cast(a,true);assert.equal(a.hp,1000);step(f,.25);assert.ok(a.freeze>0);assert.ok(f.fields.some(x=>x.kind==='frost'));
 const s=isolate(game(['class'],'storm')),b=s.spawnEnemy('guard',500,300),c=s.spawnEnemy('guard',590,320),d=s.spawnEnemy('guard',675,320);[b,c,d].forEach(e=>e.hp=e.maxHp=1000);s.cast(b,true);assert.ok([b,c,d].every(e=>e.hp<1000));assert.equal(s.shots.length,0);
});
test('storm conductive marks overload on the third hit and stormcell clears nearby bullets',()=>{
 const g=isolate(game(['class'],'storm')),e=g.spawnEnemy('guard',640,300);e.hp=e.maxHp=10000;g.relics.stormcell=1;g.bullet(e.x+10,e.y,0,100,'#ffaaaa');for(let i=0;i<3;i++)g.conduct(e);assert.equal(g.overloads,1);assert.equal(e.conduct,0);assert.ok(g.bullets[0].dead);assert.ok(e.hp<10000);
});
test('paper summons require typing; paper agents actually dive and then expire',()=>{
 const g=isolate(game(['class'],'spirit')),e=g.spawnEnemy('guard',640,300);e.hp=e.maxHp=10000;assert.equal(g.spirits.length,0);g.cast(e,true);step(g,.45);assert.equal(g.spirits.length,1);assert.ok(g.spirits.some(s=>s.mode!=='orbit'));assert.ok(e.mark>0);step(g,5);assert.equal(g.spiritTime,0);assert.equal(g.spirits.length,0);assert.ok(e.hp<10000);
});
test('all three ultimates are distinct and require resource; resource cannot self-recharge during ultimate',()=>{
 for(const book of ['frost','storm','spirit']){const g=isolate(game(['class'],book)),e=g.spawnEnemy('guard',650,300);e.hp=e.maxHp=10000;g.ultimate();assert.equal(g.ultimates,0);g.resonance=100;g.input('Shift');assert.equal(g.ultimates,1);assert.equal(g.resonance,0);assert.ok(g.ultimateTime>0);g.addResonance(20);assert.equal(g.resonance,0);if(book==='frost')assert.ok(g.fields.some(f=>f.kind==='frost'&&f.ultimate));if(book==='storm')assert.ok(g.fields.some(f=>f.kind==='storm'));if(book==='spirit'){g.updateSpirits(.016);assert.equal(g.spirits.length,4);}}
});
test('green rune clears bullets and pending telegraphs, not an already active laser',()=>{
 const g=isolate(game(['if'])),n=g.spawnNode('rune');g.bullets=[{x:n.x,y:n.y,dead:false},{x:n.x+1000,y:n.y,dead:false}];g.lasers=[{warning:2},{warning:0}];g.blasts=[{warning:1},{warning:0}];type(g,n);assert.ok(g.bullets[0].dead);assert.ok(!g.bullets[1].dead);assert.equal(g.lasers.length,1);assert.equal(g.blasts.length,1);assert.equal(g.reflections,1);
});
test('telegraphs owned by a slain mortar are cancelled before explosion',()=>{
 const g=isolate(game()),e=g.spawnEnemy('mortar',500,300);g.enemyAttack(e);assert.equal(g.blasts.length,1);e.dead=true;g.updateHazards(.01);assert.ok(g.blasts[0].dead);
});
test('new enemies implement healer, finite brood, charger and mirror behavior',()=>{
 const g=isolate(game()),healer=g.spawnEnemy('priest',500,300),ally=g.spawnEnemy('guard',570,300);ally.hp=10;g.enemyAttack(healer);assert.ok(ally.hp>10);
 const ram=g.spawnEnemy('ram',640,350);g.enemyAttack(ram);assert.ok(ram.windup>0);
 const brood=g.spawnEnemy('brood',500,300);for(let i=0;i<15;i++){g.enemies=g.enemies.filter(e=>e===brood||e===ally);g.enemyAttack(brood);}assert.equal(brood.spawnCount,5);
 const m=g.spawnEnemy('mirror',500,300);m.grace=0;const hp=m.hp;g.damage(m,40,0,true);assert.ok(Math.abs(hp-m.hp-22)<.001);assert.equal(m.mirror,0);assert.ok(g.bullets.length>0);
});
test('pause freezes simulation, dash travel, enemies, charge and ultimates',()=>{
 const g=game();g.player.dash=0;g.resonance=100;g.ultimate();g.pause();const t=g.elapsed,u=g.ultimateTime;g.update(6);assert.equal(g.elapsed,t);assert.equal(g.player.dash,0);assert.equal(g.ultimateTime,u);g.resume();g.update(.1);assert.ok(g.elapsed>t);
});
test('input target is not rewritten by splash or paper effects; partial target death awards shield',()=>{
 const g=isolate(game(['class'])),e=g.spawnEnemy('guard');e.hp=e.maxHp=500;g.relics.shield=1;g.target=e;g.input('c');g.damage(e,1,1,false);assert.equal(e.word,'class');assert.equal(g.prefix,'c');g.kill(e);assert.equal(g.player.shield,10);assert.equal(g.target,null);
});
test('rescue prevents one fatal hit and only one',()=>{
 const g=game();g.relics.rescue=1;g.player.invuln=0;g.hurt(999);assert.equal(g.state,'playing');assert.ok(g.rescued);assert.equal(g.player.hp,g.player.maxHp*.45);g.player.invuln=0;g.hurt(999);assert.equal(g.state,'result');
});
test('feather completion is reserved for the next eligible long word, without recursively charging itself',()=>{
 const g=isolate(game(['class'],'storm'));g.relics.feather=1;const e=g.spawnEnemy('guard');e.hp=e.maxHp=1e6;for(let i=0;i<4;i++)type(g,e);assert.equal(g.manual,4);assert.ok(g.autofill);g.target=e;g.input('c');g.input('l');assert.equal(g.casts,5);assert.equal(g.manual,4);assert.ok(!g.autofill);
});
test('new generic relics implement damage risk, DOT, shield, execute and perfect-wave clear',()=>{
 const g=isolate(game(['class'],'storm')),e=g.spawnEnemy('guard',630,300);e.hp=e.maxHp=10000;g.relics.bloodprice=1;g.relics.glass=1;assert.ok(Math.abs(g.damageMultiplier()-1.4*1.45)<.001);
 g.relics.bleed=1;g.relics.ward=1;g.relics.nova=1;for(let i=0;i<5;i++)g.cast(e,true);assert.ok(e.dot>0&&e.dotStacks===3);assert.ok(g.player.shield>=12);
 g.relics.execute=1;e.hp=80;g.strike(e,1,{direct:true,kind:'storm',from:g.player});assert.ok(e.dead);
});
test('awakenings require the right school and both prerequisites; rerolls never offer maxed relics',()=>{
 const g=game();assert.ok(!g.upgradeChoices().some(r=>r.rarity==='awaken'));g.relics.shatter=1;g.relics.permafrost=1;g.relics.power=3;let found=false;
 for(let i=0;i<30;i++){const list=g.upgradeChoices();assert.equal(new Set(list.map(x=>x.id)).size,list.length);assert.ok(!list.some(r=>r.id==='power'||r.book&&r.book!=='frost'));if(list.some(r=>r.id==='avalanche'))found=true;}assert.ok(found);
 g.state='upgrade';const n=g.rerolls;g.rerollUpgrade();assert.equal(g.rerolls,n-1);
});
test('all fully stacked relics have a non-blocking repeatable fallback reward',()=>{
 const g=game();for(const r of C.RELICS)g.relics[r.id]=r.max;g.state='upgrade';g.player.hp=20;assert.equal(g.upgradeChoices()[0].id,'renewal');g.chooseUpgrade('renewal');assert.equal(g.player.hp,45);assert.ok(!g.relics.renewal);
});
test('boss towers have words, reduce incoming damage, and phase transition does not duplicate towers',()=>{
 const g=game(cpp);g.stage=8;g.beginRoom();g.boss.hp=g.boss.maxHp*.3;g.boss.grace=0;g.update(.1);assert.equal(g.enemies.filter(e=>e.type==='tower').length,2);g.update(.1);assert.equal(g.enemies.filter(e=>e.type==='tower').length,2);const hp=g.boss.hp;g.damage(g.boss,100);assert.ok(Math.abs((hp-g.boss.hp)-45)<.001);assert.ok(g.targets().every(e=>cpp.some(w=>w.word===e.word)));
});
test('all nine rooms route to victory, and continuation retains build while raising difficulty',()=>{
 const g=game();g.relics.power=1;
 for(let room=0;room<9;room++){
  assert.equal(g.stage,room);g.spawned=g.roomQuota;if(g.bossRoom)g.kill(g.boss);else for(const e of [...g.enemies])g.kill(e);
  for(let i=0;i<500&&g.state!=='route'&&g.state!=='result';i++){if(g.state==='upgrade')g.chooseUpgrade(g.upgradeChoices()[0].id);else g.update(.02);}
  if(room<8){assert.equal(g.state,'route');g.chooseRoute({type:'normal',heal:10});}else assert.equal(g.state,'result');
 }
 const dmg=g.relics.power;g.continueLoop();assert.equal(g.stage,9);assert.equal(g.loopCount,1);assert.equal(g.relics.power,dmg);assert.equal(g.state,'playing');assert.ok(g.pressure.health>C.difficulty(g.mode,0).health);
});
test('a single long C++ token works in every school, including the underscore',()=>{
 for(const book of ['frost','storm','spirit']){const g=isolate(game(['reinterpret_cast'],book));const e=g.spawnEnemy('guard');type(g,e);step(g,.4);assert.equal(g.casts,1);assert.equal(g.errors,0);assert.ok(g.targets().every(t=>t.word==='reinterpret_cast'));}
});
test('all five modes have increasing speed, damage, spawn pressure; every chapter and loop grows',()=>{
 let previous=null;for(const mode of Object.keys(C.MODES)){const p=C.difficulty(mode,0);if(previous){assert.ok(p.speed>previous.speed);assert.ok(p.health>previous.health);assert.ok(p.damage>previous.damage);assert.ok(p.interval<previous.interval);assert.ok(p.cap>previous.cap);}previous=p;
  for(let stage=1;stage<27;stage++){const a=C.difficulty(mode,stage-1),b=C.difficulty(mode,stage);assert.ok(b.speed>=a.speed);assert.ok(b.health>a.health);assert.ok(b.interval<=a.interval);}
  assert.ok(C.difficulty(mode,17).health>C.difficulty(mode,8).health);
 }
});
test('visual intensity does not perturb game random sequence or subsequent enemy words',()=>{
 const a=game(cpp,'storm','hard','SAME'),b=game(cpp,'storm','hard','SAME');a.sparks(600,300,300,'#ffffff',500);a.burst(500,400,300,'#ffffff');a.makeDebris(a.enemies[0],'#ffffff');for(let i=0;i<4;i++){assert.equal(a.spawnEnemy('guard').word,b.spawnEnemy('guard').word);}
});

test('Boss phase protection prevents one-hit phase skips and then expires',()=>{
 const g=game();g.stage=2;g.beginRoom();const e=g.boss;g.damage(e,e.maxHp*9);assert.ok(e.hp>=e.maxHp*.66);assert.ok(e.phaseLock>0);g.update(.1);assert.equal(e.phase,2);step(g,.6);assert.equal(e.phaseLock,0);g.damage(e,e.maxHp*9);assert.ok(e.hp>=e.maxHp*.33);g.update(.1);assert.equal(e.phase,3);
});
test('environmental words do not consume the next empowered attack cadence',()=>{
 const g=isolate(game(['class']));g.bookCounter=3;const n=g.spawnNode('rune');type(g,n);assert.equal(g.bookCounter,3);const e=g.spawnEnemy('guard');e.hp=e.maxHp=10000;type(g,e);assert.equal(g.bookCounter,4);assert.ok(g.shots.some(s=>s.empowered));
});
test('next-loop bosses scale beyond the preceding final boss and elite contract is honored',()=>{
 const g=game();g.stage=8;g.beginRoom();const before=g.boss.maxHp;g.stage=11;g.beginRoom();assert.ok(g.boss.maxHp>before);const ordinary=g.boss.maxHp;g.beginRoom({type:'elite'});assert.ok(Math.abs(g.boss.maxHp/ordinary-C.difficulty(g.mode,g.stage,0,true).trialHealth)<1e-8);
});
