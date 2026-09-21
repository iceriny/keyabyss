const test = require('node:test'), assert = require('node:assert/strict');
const { createGame, isolate } = require('./harness.cjs');
const { layoutWordLabels } = require('../src/rendering/WordLabelLayout.ts');
const { createOverlayFrame } = require('../src/application/overlay.ts');
const make = () => isolate(createGame(['cat','dog','bird']));
const labels = g => layoutWordLabels(createOverlayFrame(g), word => word.length * 12);
test('cold entrants cannot be locked by click, cycling or typing and cannot inflict contact damage', () => {
 const g=make(),e=g.spawnEnemy('nib',20,400);e.grace=0;e.word='cat';
 g.clickTarget(e.x,e.y,e.id);assert.equal(g.target,null);
 g.cycle();assert.equal(g.target,null);
 g.input('c');assert.equal(g.target,null);assert(!e.combatLocked);
 g.player.x=e.x;g.player.y=e.y;g.player.invuln=0;
 const hp=g.player.hp;g.updateEnemies(.01);assert.equal(g.player.hp,hp);
 assert.equal(labels(g).length,0);
});
test('all targeting paths preserve a clear-arena lock, words and attacks after knockback', () => {
 for(const mode of ['click','cycle','input']){
 const g=make(),e=g.spawnEnemy('ram',640,400);e.grace=0;e.word='cat';
 if(mode==='click')g.clickTarget(e.x,e.y,e.id);else if(mode==='cycle')g.cycle();else g.input('c');
 assert.equal(e.combatLocked,true,mode);
 e.x=20;g.player.x=100;g.player.y=400;
 assert(g.canEnemyAct(e));assert(labels(g).some(l=>l.target.id===e.id));
 g.enemyAttack(e);assert(e.windup>0);
 g.cancel();assert(g.canEnemyAct(e),'lock history survives completed/cancelled input');
 assert(labels(g).some(l=>l.target.id===e.id));
 }
});
test('locked enemies retain source-owned hazards and scheduled abilities at the edge', () => {
 const g=make(),e=g.spawnEnemy('scribe',500,300);e.grace=0;
 g.clickTarget(e.x,e.y,e.id);g.laser(e);g.makeBlast(600,400,90,.5,e.id);
 let called=0;g.schedule(.01,()=>called++,e.id);e.x=20;
 g.updateHazards(.01);g.update(.02);
 assert(g.lasers.some(l=>!l.dead));assert(g.blasts.some(b=>!b.dead));assert.equal(called,1);
});
