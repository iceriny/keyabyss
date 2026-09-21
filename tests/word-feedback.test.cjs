const test = require('node:test'), assert = require('node:assert/strict');
const { createGame, isolate, step } = require('./harness.cjs');
const { createOverlayFrame } = require('../src/application/overlay.ts');
const { layoutWordLabels } = require('../src/rendering/WordLabelLayout.ts');
const make = () => isolate(createGame(['cat','dog','bird']));
test('passive ice projectile killing the current word does not penalize the next correct word, even after waiting', () => {
 for (const delay of [0,7]) {
  const g=make();g.combo=12;
  const a=g.spawnEnemy('guard',640,300),b=g.spawnEnemy('guard',900,400);a.word='cat';b.word='dog';a.hp=1;
  g.input('c');g.launchShot({x:a.x-10,y:a.y+9},a,'ice',100,{direct:false,depth:1});g.updateShots(.02);
  assert(a.dead);assert.equal(g.combo,12);assert.equal(g.prefix,'');
  g.player.invuln=999;step(g,delay);
  assert.equal(g.combo,12);for(const key of b.word)g.input(key);
  assert.equal(g.combo,13);assert.equal(g.errors,0);
 }
});
test('waiting does not drain combo while wrong input and damage still do', () => {
 const g=make();g.combo=20;g.player.invuln=999;step(g,30);assert.equal(g.combo,20);
 g.input('z');assert.equal(g.combo,19);
 g.player.invuln=0;g.hurt(1);assert.equal(g.combo,Math.floor(19*.62));
});
test('optional overhead meaning defaults off, fits long text and leaves missing meanings unchanged', () => {
 const g=make(),e=g.spawnEnemy('guard',640,300);e.meaning='守卫';
 const frame=createOverlayFrame(g),measure=(text,font)=>Array.from(text).length*font;
 const label=()=>layoutWordLabels(frame,measure)[0];
 assert.equal(g.options.labelMeaning,false);const base=label();assert(!base.meaningText);
 g.options.labelMeaning=true;assert.equal(label().meaningText,'守卫');assert.equal(label().h,base.h+18);
 e.meaning='这是一条很长的中文释义。'.repeat(20);assert(label().meaningText.endsWith('…'));assert(label().w<=304);
 e.meaning='';assert.equal(label().h,base.h);
 g.options.labelMeaning=false;e.meaning='守卫';assert(!label().meaningText);
});
