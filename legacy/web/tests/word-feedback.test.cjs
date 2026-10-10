const test = require('node:test'), assert = require('node:assert/strict');
const { createGame, isolate, step } = require('./harness.cjs');
const { createOverlayFrame } = require('../src/application/overlay.ts');
const { layoutWordLabels } = require('../src/rendering/WordLabelLayout.ts');
const make = () => isolate(createGame(['cat','dog','bird']));
test('passive ice projectile preserves the current word and combo for continuation, even after waiting', () => {
 for (const delay of [0,7]) {
  const g=make();g.combo=12;
  const a=g.spawnEnemy('guard',640,300),b=g.spawnEnemy('guard',900,400);a.word='cat';b.word='dog';a.hp=1;
  g.input('c');g.launchShot({x:a.x-10,y:a.y+9},a,'ice',100,{direct:false,depth:1});g.updateShots(.02);
  assert(a.dead);assert.equal(g.combo,12);assert.equal(g.prefix,'c');assert.equal(g.target,a);
  g.player.invuln=999;step(g,delay);
  assert.equal(g.combo,12);for(const key of a.word.slice(g.prefix.length))g.input(key);
  assert.equal(g.combo,13);assert.equal(g.errors,0);assert.equal(g.casts,1);assert.equal(g.wordStats.cat.done,1);
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
 g.options.labelMeaning=true;assert.equal(label().meaningText,'守卫');assert.equal(label().h,base.h+17);
 e.meaning='这是一条很长的中文释义。'.repeat(20);assert(label().meaningText.endsWith('…'));assert(label().w<=234);assert.equal(label().meaningLines.length,2);assert.equal(label().h,base.h+34);
 e.meaning='';assert.equal(label().h,base.h);
 g.options.labelMeaning=false;e.meaning='守卫';assert(!label().meaningText);
});

test('label metric reuse retains moving hit boxes and invalidates on word and settings changes', () => {
 const g=make(), e=g.spawnEnemy('guard',640,300), frame=createOverlayFrame(g), cache=new WeakMap();
 let calls=0;const measure=(word,font)=>{calls++;return word.length*font;};
 const layout=()=>layoutWordLabels(frame,measure,cache)[0];
 const first=layout(), measured=calls;e.x+=20;const moved=layout();
 assert.equal(calls,measured);assert.equal(moved.x,first.x+20);
 e.word='thunder';layout();assert.ok(calls>measured);
 for(const change of [()=>g.options.largeText=true,()=>{g.options.labelMeaning=true;e.meaning='闪电';},()=>e.meaning='雷鸣']) {
   const prior=calls;change();assert.deepEqual(layout(),layoutWordLabels(frame,measure)[0]);assert.ok(calls>prior);
 }
});
