const test=require('node:test'),assert=require('node:assert/strict');
const {C,createGame,step}=require('./harness.cjs');

test('opening has a readable grace period, smaller cap, and no first-wave elites',()=>{
 for(const mode of Object.keys(C.MODES)){
  const g=createGame(['class'],'frost',mode);assert.ok(g.spawnClock>=3.5);
  assert.ok(C.difficulty(mode,0,0).cap<C.difficulty(mode,0,55).cap);
  assert.ok(C.difficulty(mode,0,0).interval>C.difficulty(mode,0,55).interval);
  g.rng=()=>0;assert.equal(g.spawnEnemy('nib',300,250,false,true).elite,null);
  g.wave=2;assert.ok(g.spawnEnemy('nib',300,250,false,true).elite);
 }
});
test('a wave never overfills its quota and later waves wait for clear plus a real respite',()=>{
 const g=createGame(['class']);g.player.invuln=999;g.spawned=Math.ceil(g.roomQuota/3);g.spawnClock=0;
 const count=g.spawned;step(g,.2);assert.equal(g.spawned,count);assert.equal(g.wave,1);
 g.enemies=[];step(g,.2);assert.equal(g.wave,1);assert.ok(g.waveWaiting);assert.equal(g.spawned,count);
 g.pause();const remaining=g.waveRest;step(g,3);assert.equal(g.waveRest,remaining);g.resume();
 step(g,remaining+.1);assert.equal(g.wave,2);assert.ok(!g.waveWaiting);
});
test('all reinforcements across three waves remain mandatory before routing',()=>{
 const g=createGame(['class']);g.player.invuln=999;
 for(let i=0;i<1200&&g.state==='playing';i++){g.enemies=[];g.spawnClock=0;step(g,.1);if(g.wave<3)assert.equal(g.roomEnded,false);}
 assert.equal(g.spawned,g.roomQuota);assert.equal(g.wave,3);assert.equal(g.state,'route');
});
test('chapter HP growth is gentler than exponential and remains ordered across modes and loops',()=>{
 assert.ok(C.difficulty('normal',8).health<2.2);
 for(const mode of Object.keys(C.MODES))for(let stage=1;stage<=27;stage++)assert.ok(C.difficulty(mode,stage).health>C.difficulty(mode,stage-1).health);
});
