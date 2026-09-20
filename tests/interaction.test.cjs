'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {CommandBuffer}=require('../src/input.ts');
const {C,createGame,isolate}=require('./harness.cjs');
const make=(words=['start','storm','settings'])=>new CommandBuffer(words.map(word=>({word,id:word})));
function type(buffer,text){let out;for(const c of text)out=buffer.feed(c);return out;}

test('UI word completion executes exactly once and needs no Enter',()=>{
 const b=make();assert.equal(type(b,'sta').kind,'progress');assert.equal(b.value,'sta');
 assert.equal(type(b,'rt').command.id,'start');assert.equal(b.value,'');
 assert.equal(b.feed('Enter').kind,'ignored');
});
test('case is normalized without adding punctuation or modifier characters',()=>{
 const b=make();assert.equal(type(b,'STORM').command.id,'storm');
 for(const key of ['Shift','Control','_','Process','é','中',' '])assert.equal(b.feed(key).kind,'ignored');
});
test('wrong character preserves prefix and never falls through into another action',()=>{
 const b=make();type(b,'sta');const wrong=b.feed('o');assert.equal(wrong.kind,'miss');assert.equal(b.value,'sta');
 assert.equal(type(b,'rt').command.id,'start');
});
test('Backspace is one character, Escape-equivalent clear discards whole UI prefix',()=>{
 const b=make();type(b,'sett');b.backspace();assert.equal(b.value,'set');b.clear();assert.equal(b.value,'');
 b.backspace();assert.equal(b.value,'');
});
test('same initial can branch normally, but duplicate and prefix aliases are rejected',()=>{
 assert.doesNotThrow(()=>make(['start','storm','spirit']));
 assert.throws(()=>make(['go','gone']),/Prefix collision/);assert.throws(()=>make(['go','go']),/Duplicate/);
 assert.throws(()=>make(['1']),/Invalid/);assert.throws(()=>make(['Start']),/Invalid/);
});
test('disabled words produce an explicit disabled result, never an executable action',()=>{
 const b=new CommandBuffer([{word:'reroll',disabled:true}]);assert.equal(type(b,'reroll').kind,'disabled');assert.equal(b.value,'');
});
test('changing context drops partial input instead of carrying it to the next screen',()=>{
 const b=make();type(b,'sta');b.setCommands([{word:'begin'}]);assert.equal(b.value,'');
 assert.equal(type(b,'rt').kind,'miss');assert.equal(type(b,'begin').kind,'execute');
});
test('updating same context may preserve only a still-valid prefix',()=>{
 const b=make();type(b,'sto');b.setCommands([{word:'storm'},{word:'back'}],true);assert.equal(b.value,'sto');
 b.setCommands([{word:'back'}],true);assert.equal(b.value,'');
});
test('fixed-width imported-library identifiers never create prefix ambiguities',()=>{
 assert.doesNotThrow(()=>make(Array.from({length:20},(_,i)=>'local'+String(i+1).padStart(2,'0'))));
 const b=make(['grade1','grade2','cet4','cet6','cpp']);assert.equal(type(b,'cet6').command.word,'cet6');
});
test('all registered relics plus fallback and page actions are a valid prefix-free vocabulary',()=>{
 const words=C.RELICS.map(r=>r.id==='dash'?'fold':r.id==='dashnova'?'halo':r.id);
 assert.doesNotThrow(()=>make([...words,'renewal','reroll','quit']));
});
test('reverse target navigation chooses last target when unlocked, preserving typed prefix',()=>{
 const g=isolate(createGame(['cat','cow','cut']));const a=g.spawnEnemy('guard',600,300),b=g.spawnEnemy('guard',610,300),c=g.spawnEnemy('guard',620,300);
 a.word='cat';b.word='cow';c.word='cut';const sorted=g.targets().sort((x,y)=>g.priority(x)-g.priority(y));
 g.cycle(-1);assert.equal(g.target,sorted.at(-1));g.input('c');const prior=g.target;g.cycle(-1);
 assert.notEqual(g.target,prior);assert.equal(g.prefix,'c');g.cycle(1);assert.equal(g.target,prior);
});
test('UI command parsing has no route to combat counters or selected gameplay dictionary',()=>{
 const g=createGame(['start','quit','settings']);const before=[g.typedTotal,g.errors,g.casts,g.pool?.words?.length];
 const ui=make(['start','quit','settings']);type(ui,'settings');type(ui,'quit');
 assert.deepEqual([g.typedTotal,g.errors,g.casts,g.pool?.words?.length],before);
});
