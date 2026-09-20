const test=require('node:test'),assert=require('node:assert/strict');
const {createGame,isolate}=require('./harness.cjs');
test('paper spirits accumulate one per completed spell, obey relic capacity and sleep/reset cleanly',()=>{
 const g=isolate(createGame(['sand'],'spirit')),e=g.spawnEnemy('guard',640,240);e.hp=e.maxHp=1e6;
 const cast=()=>{e.wordPending=false;g.cast(e);g.updateSpirits(0);};
 for(let i=1;i<=5;i++){cast();assert.equal(g.spirits.length,Math.min(i,3));}
 g.relics.spirit=2;cast();assert.equal(g.spirits.length,4);cast();assert.equal(g.spirits.length,5);
 g.updateSpirits(30);assert.equal(g.spirits.length,0);assert.equal(g.awakenedSpirits,0);
 cast();assert.equal(g.spirits.length,1);
 g.resonance=100;g.ultimate();g.updateSpirits(0);assert.equal(g.spirits.length,5);
 for(let i=0;i<8;i++)cast();assert.equal(g.spirits.length,9);
 g.ultimateTime=0;g.updateSpirits(0);assert.equal(g.spirits.length,5);
 g.beginRoom();assert.equal(g.awakenedSpirits,0);
});
test('storm cast retains instant single-target damage and propagates to three additional targets',()=>{
 const g=isolate(createGame(['sand'],'storm'));
 const enemies=Array.from({length:5},(_,i)=>{const e=g.spawnEnemy('nib',500+i*35,280);e.hp=e.maxHp=10000;e.grace=0;return e;});
 g.bookBehavior.cast(g,enemies[0],100,false,false);
 assert(enemies[0].hp<=9888); // Normal cast now exceeds its nominal base damage.
 // Allow any scheduled propagation to resolve with no summons or other player attacks.
 for(let i=0;i<100;i++)g.update(.01);
 assert(enemies.slice(0,4).every(e=>e.hp<10000));assert.equal(enemies[4].hp,10000);
});

