const test=require('node:test'),assert=require('node:assert/strict');
const {C,createGame:game,isolate,type,step}=require('./harness.cjs');

test('lethal frost and paper casts never refresh the word before or after impact',()=>{
 for(const book of ['frost','spirit']){
  const g=isolate(game(['class','return'],book)),e=g.spawnEnemy('nib',640,280);
  let refreshes=0;const wordFor=g.wordFor.bind(g);g.wordFor=(...args)=>{refreshes++;return wordFor(...args);};
  const word=e.word;type(g,e);
  assert.equal(refreshes,0);assert.equal(e.word,word);assert.ok(e.wordPending);assert.ok(!g.targets().includes(e));
  const casts=g.casts;g.cast(e);assert.equal(g.casts,casts);
  step(g,.4);assert.ok(e.dead);assert.equal(refreshes,0);
 }
});

test('surviving targets regain a word on contact or projectile expiry, never stay locked',()=>{
 for(const expire of [false,true]){
  const g=isolate(game(['class','return'])),e=g.spawnEnemy('guard',640,280);e.hp=e.maxHp=10000;
  let refreshes=0;const wordFor=g.wordFor.bind(g);g.wordFor=(...args)=>{refreshes++;return wordFor(...args);};
  type(g,e);assert.equal(refreshes,0);
  if(expire){g.shots[0].life=0;g.updateShots(.001);}else step(g,.4);
  assert.ok(!e.dead&&!e.wordPending);assert.ok(g.targets().includes(e));assert.equal(refreshes,1);
 }
});

test('dead original targets do not refresh when their spell retargets',()=>{
 const g=isolate(game(['class','return'])),a=g.spawnEnemy('nib',640,280),b=g.spawnEnemy('guard',740,280);
 type(g,a);g.kill(a);g.wordFor=()=>{throw Error('dead target refreshed');};g.updateShots(.01);
 assert.ok(!a.wordPending);assert.equal(g.shots[0].targetId,b.id);
});

test('word-length relics are excluded from every offer and direct selection when unusable',()=>{
 for(const [words,excluded] of [[['cat','abcdef'],['long']],[['a','if'],['long','feather']],[['seventh'],['short']]]){
  const g=game(words);for(let i=0;i<80;i++)assert.ok(g.upgradeChoices().every(r=>!excluded.includes(r.id)));
  g.state='upgrade';for(const id of excluded){g.chooseUpgrade(id);assert.ok(!g.relics[id]);}
 }
 const g=game(['seventh']);assert.ok(g.canUpgrade(C.RELICS.find(r=>r.id==='long')));
});

test('blood contract pays immediately and once per new page, bypasses shield, cannot kill',()=>{
 const g=game();g.player.shield=20;const hp=g.player.hp;
 g.state='upgrade';g.afterUpgrade='play';g.chooseUpgrade('bloodprice');
 assert.equal(g.player.hp,hp-8);assert.equal(g.player.shield,20);g.payBloodPrice();assert.equal(g.player.hp,hp-8);
 g.stage++;g.beginRoom();assert.equal(g.player.hp,hp-16);
 g.stage++;g.player.hp=4;g.beginRoom();assert.equal(g.player.hp,1);
 const route=game();route.stage=1;route.state='route';route.chooseRoute({type:'normal',relic:true});
 const before=route.player.hp;route.chooseUpgrade('bloodprice');assert.equal(route.player.hp,before-8);
});

test('blood contract increases actual spell damage by 40 percent in every book',()=>{
 for(const book of ['frost','storm','spirit']){
  const damage=enabled=>{const g=isolate(game(['class'],book)),e=g.spawnEnemy('guard',640,280);e.hp=e.maxHp=10000;
   if(enabled)g.relics.bloodprice=1;g.cast(e);if(book!=='storm')for(let i=0;i<40;i++)g.updateShots(.01);return 10000-e.hp;};
  const base=damage(false);assert.ok(base>0);assert.ok(Math.abs(damage(true)/base-1.4)<1e-8);
 }
});

test('trial routes preserve opening counts and quotas across every mode and Boss page',()=>{
 for(const mode of Object.keys(C.MODES))for(const stage of [1,2,5,8]){
  const g=game(['class'],'frost',mode);g.stage=stage;g.rng=()=>.99;g.beginRoom();
  const count=g.enemies.length,quota=g.roomQuota,bossHP=g.boss?.maxHp;
  g.state='route';g.chooseRoute({type:'elite'});
  assert.equal(g.enemies.length,count);assert.equal(g.roomQuota,quota);assert.ok(g.enemies.every(e=>!e.elite));
  if(g.bossRoom)assert.ok(Math.abs(g.boss.maxHp/bossHP-g.pressure.trialHealth)<1e-8);
  g.stage++;g.beginRoom({type:'normal'});assert.equal(g.pressure.trialHealth,1);assert.equal(g.pressure.trialXP,1);
 }
});

test('trial risk and reward scale with difficulty while a higher mode remains the larger challenge',()=>{
 const modes=Object.keys(C.MODES);
 for(let rank=0;rank<modes.length;rank++){
  const base=C.difficulty(modes[rank],1),trial=C.difficulty(modes[rank],1,0,true);
  assert.ok(trial.health>base.health);assert.ok(trial.trialXP>trial.trialHealth);
  assert.equal(trial.damage,base.damage);assert.equal(trial.speed,base.speed);assert.equal(trial.interval,base.interval);
  assert.equal(trial.quota,base.quota);
  if(rank<2)assert.equal(trial.cap,base.cap);
  if(rank){const prev=C.difficulty(modes[rank-1],1,0,true);assert.ok(trial.trialHealth>prev.trialHealth);assert.ok(trial.trialXP>prev.trialXP);}
  if(rank<4){const next=C.difficulty(modes[rank+1],1);assert.ok(trial.health<next.health);assert.ok(trial.elite<next.elite);assert.ok(trial.cap<next.cap);}
  const g=isolate(game(['class'],'frost',modes[rank]));g.stage=1;g.rng=()=>.99;g.beginRoom({type:'elite'});
  const ordinary=game(['class'],'frost',modes[rank]);ordinary.stage=1;ordinary.rng=()=>.99;ordinary.beginRoom();
  ordinary.kill(ordinary.enemies[0]);g.kill(g.enemies[0]);assert.ok(Math.abs(g.xp/ordinary.xp-trial.trialXP)<1e-8);
 }
});

test('hourglass slows the world while typing continues and defenses use real time',()=>{
 const g=isolate(game(['sand'])),e=g.spawnEnemy('guard',640,280);g.target=e;g.input('s');g.relics.hourglass=1;
 g.input('ArrowLeft');const t=g.time,elapsed=g.elapsed;
 g.input('a');g.update(.1);
 assert.ok(Math.abs(g.time-t-.01)<1e-8);assert.ok(Math.abs(g.elapsed-elapsed-.1)<1e-8);
 assert.equal(g.prefix,'sa');assert.equal(g.target,e);assert.equal(g.errors,0);
 step(g,.1);const x=g.player.x,y=g.player.y;g.input('n');g.update(.1);
 assert.equal(g.player.x,x);assert.equal(g.player.y,y);assert.equal(g.prefix,'san');
 g.input(' ');const cd=g.player.parryCooldown;g.update(.1);assert.ok(Math.abs(g.player.parryCooldown-(cd-.1))<1e-8);
});

test('defense and hourglass timers freeze across pause and reset at a new room',()=>{
 const g=isolate(game());g.relics.hourglass=1;g.input('ArrowRight');step(g,.2);g.input(' ');
 const remaining=g.precisionTime,cd=g.player.parryCooldown,window=g.player.parryTime;
 g.pause();g.update(3);assert.equal(g.precisionTime,remaining);assert.equal(g.player.parryCooldown,cd);assert.equal(g.player.parryTime,window);assert.equal(Object.keys(g.aimKeys).length,0);
 g.resume();g.setState('upgrade');g.update(3);assert.equal(g.precisionTime,remaining);
 g.stage++;g.beginRoom();assert.equal(g.precisionTime,0);assert.equal(g.player.parryTime,0);assert.equal(g.player.parryCooldown,0);assert.equal(Object.keys(g.aimKeys).length,0);
});

test('dash does not consume charges into a wall, or reward dead and receding threats',()=>{
 const g=isolate(game());g.player.x=g.arena.r-25;g.input('ArrowRight');assert.equal(g.dashes,0);assert.equal(g.player.dash,2);
 g.releaseKey('ArrowRight');g.bullet(g.player.x-35,g.player.y,Math.PI,100,'#fff');
 g.lasers=[{dead:true,warning:0,pos:g.player.x,vertical:true,width:30}];
 g.blasts=[{dead:true,warning:0,x:g.player.x,y:g.player.y,r:90}];g.dodge();assert.equal(g.perfectDodges,0);
});

test('without held direction there is no automatic movement or suggested landing',()=>{
 const g=isolate(game());const origin={x:g.player.x,y:g.player.y};
 g.bullet(origin.x-150,origin.y,0,500,'#fff');g.input(' ');step(g,.05);
 assert.equal(g.player.x,origin.x);assert.equal(g.player.y,origin.y);assert.equal(g.dashes,0);assert.equal(g.safePoint,null);
});
