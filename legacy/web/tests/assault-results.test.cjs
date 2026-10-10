const test = require('node:test'), assert = require('node:assert/strict');
const { createGame, isolate } = require('./harness.cjs');
const { assaultEntry, assaultAngle } = require('../src/shared/assault.ts');
const { readRunArchive, settleRun } = require('../src/application/runArchive.ts');
const { StorageAdapter } = require('../src/platform/StorageAdapter.ts');

function store() {
  const data = new Map();
  return { data, storage: new StorageAdapter(() => ({ getItem: k => data.get(k) ?? null, setItem: (k,v) => data.set(k,v) })) };
}
function report() {
  const g = createGame(); let r; g.events.result = value => r=value; g.end(false); return r;
}
test('new reports use the package version while archived reports retain their original version', () => {
  const r = report();
  assert.equal(r.version, require('../package.json').version);
  const { data, storage } = store();
  data.set('keyabyss.history', JSON.stringify([{ ...r, version: '0.6.2' }]));
  assert.equal(readRunArchive(storage).records[0].version, '0.6.2');
});
test('all eight approach sectors stay within the perimeter and span overlapping 110-degree arcs', () => {
  const arena = { l:-220, r:1500, t:-180, b:980 };
  for(let direction=0; direction<8; direction++) for(const spread of [0,.5,.99999]) {
    const p=assaultEntry(arena,direction,spread), a=Math.atan2(p.y-400,p.x-640);
    const difference=Math.atan2(Math.sin(a-assaultAngle(direction)),Math.cos(a-assaultAngle(direction)));
    assert(Math.abs(difference)<=55*Math.PI/180+1e-8);
    if(spread===0) assert(Math.abs(difference)>54*Math.PI/180);
    assert(p.x>=arena.l+24.99 && p.x<=arena.r-24.99 && p.y>=arena.t+24.99 && p.y<=arena.b-24.99);
    assert(Math.min(p.x-arena.l,arena.r-p.x,p.y-arena.t,arena.b-p.y)<25.01);
  }
});
test('each wave draws one seeded direction; spawning retains it and the next wave redraws', () => {
  const seen=new Set();
  for(let seed=0;seed<80;seed++) {
    const g=createGame(undefined,'frost','normal',String(seed)); seen.add(g.assaultDirection);
    const twin=createGame(undefined,'frost','normal',String(seed));
    assert.equal(g.assaultDirection,twin.assaultDirection);
    const direction=g.assaultDirection;
    for(let n=0;n<5;n++){g.enemies=[];g.spawnEnemy('nib');assert.equal(g.assaultDirection,direction);}
    g.enemies=[];g.waveWaiting=true;g.waveRest=.01;g.rng=()=>.74;g.updateEncounter(.02);
    assert.equal(g.wave,2);assert.equal(g.assaultDirection,5);
  }
  assert.equal(seen.size,8);
});
test('ambushes are a small minority from other sectors; positioned summons are untouched', () => {
  const g=isolate(createGame());g.assaultDirection=4;let ambushes=0;const sides=new Set();
  for(let i=0;i<5000;i++) {
    g.enemies=[];const e=g.spawnEnemy('nib');
    if(e.ambush){ambushes++;assert.notEqual(e.approachDirection,4);sides.add(e.approachDirection);}
    else assert.equal(e.approachDirection,4);
  }
  assert(ambushes>300 && ambushes<500,ambushes);assert.equal(sides.size,7);
  const e=g.spawnEnemy('nib',320,220,true,true);assert.equal(e.x,320);assert.equal(e.y,220);assert.equal(e.approachDirection,undefined);assert.equal(e.ambush,false);
});
test('settlement freezes real room progress, input details and one ID per loop', () => {
  const g=createGame();const records=[];g.events.result=r=>records.push(r);
  g.wordStats.alpha={errors:2,meaning:'a'};g.kills=12;g.completeRoom();
  assert.equal(g.state,'route');assert.equal(g.stage,1);
  g.end(false,'abandoned');g.end(false);
  assert.equal(records.length,1);assert.equal(records[0].stage,0);assert.equal(records[0].room,1);assert.equal(records[0].outcome,'abandoned');
  g.wordStats.alpha.errors=5;assert.equal(records[0].words.alpha.errors,2);
  g.start(g.config);g.end(true);const win=records.at(-1);g.continueLoop();g.end(false);
  assert.equal(records.at(-1).runId,win.runId);assert.notEqual(records.at(-1).settlementId,win.settlementId);
});
test('legacy reports remain readable; career checkpoints avoid loop and repeat rewards after history eviction', () => {
  const {data,storage}=store();const r=report();
  data.set('keyabyss.history',JSON.stringify([{...r,words:undefined,date:'2026-09-20T00:00:00Z'}]));
  const legacy=readRunArchive(storage);assert.equal(legacy.records.length,1);assert.deepEqual(legacy.records[0].words,{});
  let archive=readRunArchive(store().storage);let calls=0;
  const policy=(career,settlement)=>{calls++;assert.equal(settlement.eligible,true);return {...career,currencies:{ink:(career.currencies.ink??0)+settlement.delta.kills}};};
  const first={...r,runId:'one',settlementId:'one:0',win:true,outcome:'victory',kills:10,casts:8,elapsed:20};
  archive=settleRun(archive,first,policy);
  assert.equal(settleRun(archive,first,policy),archive);assert.equal(calls,1);
  archive=settleRun(archive,{...first,settlementId:'one:1',loop:1,kills:17,casts:10,elapsed:30},policy);
  assert.equal(archive.career.kills,17);assert.equal(archive.career.casts,10);assert.equal(archive.career.elapsed,30);assert.equal(archive.career.currencies.ink,17);
  for(let i=0;i<55;i++)archive=settleRun(archive,{...r,runId:`n${i}`,settlementId:`n${i}:0`});
  assert.equal(archive.records.length,50);assert.equal(settleRun(archive,first,policy),archive);
  storage.save('archive',archive);assert.deepEqual(readRunArchive(storage),JSON.parse(JSON.stringify(archive)));
});
test('future talent policies cannot award abandoned or debug runs; storage failures leave old state intact', () => {
  const {storage,data}=store();let archive=readRunArchive(storage);const r=report();
  const policy=()=>{throw Error('ineligible rewards');};
  archive=settleRun(archive,{...r,outcome:'abandoned'},policy);
  archive=settleRun(archive,{...r,runId:'debug',settlementId:'debug:0',godMode:true},policy);
  assert.deepEqual(archive.career.talentRanks,{});assert.deepEqual(archive.career.currencies,{});
  assert.equal(storage.save('archive',archive),true);
  const before=data.get('keyabyss.archive');const denied=new StorageAdapter(()=>({getItem:k=>data.get(k),setItem:()=>{throw Error('quota');}}));
  assert.equal(denied.save('archive',{...archive,records:[]}),false);assert.equal(data.get('keyabyss.archive'),before);
});
