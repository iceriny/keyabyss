const {builtinContent}=require('../src/bootstrap/content.ts');
const {CombatSimulation}=require('../src/simulation/CombatSimulation.ts');
const C=require('../src/bootstrap/catalog-api.ts');
const school=require('../data/primary3.json').words;
const cpp=require('../data/cpp.json').words;
function createGame(words=school,book='frost',mode='normal',seed='TEST-V2'){
 const g=new CombatSimulation(builtinContent);g.start({seed,book,mode,words,progressive:true,vocabTitle:'test'});return g;
}
function isolate(g){g.enemies=[];g.nodes=[];g.bullets=[];g.lasers=[];g.blasts=[];g.tasks=[];g.shots=[];g.fields=[];g.spirits=[];g.spawnClock=999;g.nodeClock=999;g.roomQuota=999;g.spawned=0;g.roomEnded=false;g.bossRoom=false;g.player.invuln=1;return g;}
function type(g,e){g.cancel(false);g.target=e;const word=e.word;for(const k of word)g.input(k);}
function step(g,time=.5,autoUpgrade=false){for(let t=0;t<time-1e-8;t+=1/120){if(g.state==='upgrade'&&autoUpgrade)g.chooseUpgrade(g.upgradeChoices()[0].id);g.updateVisual(1/120);g.update(1/120);}}
module.exports={C,createGame,isolate,type,step,school,cpp};
