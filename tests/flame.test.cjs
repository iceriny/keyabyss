const test=require('node:test'),assert=require('node:assert/strict');
const {createGame,isolate,type,step}=require('./harness.cjs');
function game(){const g=isolate(createGame([{word:'combustion'},{word:'scorch'},{word:'ash'}],'flame'));g.player.invuln=999;return g;}
function enemy(g,x=600,y=320){const e=g.spawnEnemy('nib',x,y,false,true);e.hp=e.maxHp=10000;e.speed=0;e.shoot=999;e.grace=0;return e;}
test('fireball delays damage until contact and settles the original word lease',()=>{
 const g=game(),e=enemy(g);type(g,e);
 assert.equal(e.hp,10000);assert.equal(e.wordPending,true);assert.equal(g.shots[0].kind,'fire');
 step(g,.65);assert(e.hp<10000);assert(e.burn.stacks>=1);assert.equal(e.wordPending,false);assert.equal(e.pendingHits,0);
});
test('burn stacks, finite duration and half-second damage cadence pause with the world',()=>{
 const g=game(),e=enemy(g);for(let i=0;i<8;i++)g.applyBurn(e);
 assert.equal(e.burn.stacks,3);const hp=e.hp;g.tickBurn(e,.5);assert.equal(hp-e.hp,18);
 g.pause();const before=JSON.stringify(e.burn);step(g,1);assert.equal(JSON.stringify(e.burn),before);
 g.setState('playing');g.tickBurn(e,2.5);assert.equal(e.burn,undefined);assert.equal(hp-e.hp,108);
});
test('third flame cast hits nearby enemies, leaves a fire field and grants ember shields once',()=>{
 const g=game(),e=enemy(g),near=enemy(g,640,320);g.relics.coal=2;g.relics.crucible=2;g.bookCounter=2;
 type(g,e);assert(g.shots[0].empowered);assert.equal(g.player.shield,10);
 step(g,.6);assert(near.hp<10000);assert(near.burn);assert(g.fields.some(f=>f.kind==='fire'&&f.r===165));
});
test('wildfire spreads at most two generations and fresh direct burns establish a new source',()=>{
 const g=game();g.relics.wildfire=1;
 const a=enemy(g,300),b=enemy(g,430),c=enemy(g,560),d=enemy(g,690);
 g.applyBurn(a,2);g.kill(a);assert.equal(b.burn.spreadDepth,1);g.kill(b);assert.equal(c.burn.spreadDepth,2);
 g.kill(c);assert.equal(d.burn,undefined);g.applyBurn(d,1);assert.equal(d.burn.spreadDepth,0);
 const kills=g.kills;g.kill(c);assert.equal(g.kills,kills);
});
test('fire fields tick consistently and firewalk extends the dodge field',()=>{
 const g=game(),e=enemy(g);g.addField('fire',e.x,e.y,80,2);
 for(let i=0;i<60;i++)g.updateFields(1/120);assert.equal(e.burn.stacks,1);
 g.updateFields(.5);assert.equal(e.burn.stacks,2);
 g.relics.firewalk=2;g.bookBehavior.dash(g,{x:250,y:500});assert(g.fields.some(f=>f.x===250&&f.r===100&&f.life===4));
});
test('flame relic eligibility, burn scaling and inferno awakening compose through content grants',()=>{
 const g=game(),e=enemy(g);assert(!g.canUpgrade(g.content.relics.find(r=>r.id==='inferno')));
 g.relics.cinder=2;g.relics.pitch=1;assert(g.canUpgrade(g.content.relics.find(r=>r.id==='inferno')));
 g.relics.inferno=1;g.applyBurn(e,10);assert.equal(e.burn.stacks,5);assert.equal(e.burn.life,4);assert(Math.abs(e.burn.damage-9.6)<1e-8);
 g.resonance=100;g.ultimate();assert.equal(g.ultimateTime,7);assert.equal(g.resonance,0);assert(g.fields.some(f=>f.ultimate&&f.kind==='fire'));
 step(g,.3);assert(g.shots.some(s=>s.kind==='fire'));g.beginRoom();assert.equal(g.fields.length,0);assert.equal(g.shots.length,0);
 const frost=createGame();for(const r of frost.content.relics.filter(r=>r.book==='flame'))assert.equal(frost.canUpgrade(r),false);
});
test('flame runs accept underscore tokens, preserve RNG under visual settings and cancel old burns on restart',()=>{
 const make=()=>isolate(createGame([{word:'reinterpret_cast'}],'flame','normal','FIRE-RNG'));
 const a=make(),b=make();b.options.fx=.3;b.options.reduceMotion=true;
 for(const g of [a,b]){const e=enemy(g);type(g,e);step(g,1);}
 assert.equal(a.enemies[0].hp,b.enemies[0].hp);assert.equal(a.rng(),b.rng());assert.equal(a.ultimates,0);
 a.start(a.config);assert(a.enemies.every(e=>!e.burn));
});
