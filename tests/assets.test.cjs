const test=require('node:test'),assert=require('node:assert/strict');
const {AssetManager}=require('../src/platform/AssetManager.ts');
function environment(){
 const created=[],revoked=[];let fail=false;
 class Media extends EventTarget {
  _src='';paused=true;preload='';loop=false;volume=1;
  set src(value){this._src=value;if(value)queueMicrotask(()=>this.dispatchEvent(new Event(fail?'error':this.kind==='image'?'load':'loadeddata')));}
  get src(){return this._src;}
  removeAttribute(){this._src='';}load(){}pause(){this.paused=true;}
  play(){this.paused=false;return Promise.resolve();}
  cloneNode(){const voice=new Media();voice.kind='audio';voice._src=this.src;created.push(voice);return voice;}
 }
 const media=kind=>{const m=new Media();m.kind=kind;created.push(m);return m;};
 return {env:{baseURL:()=> 'file:///game/index.html',image:()=>media('image'),audio:()=>media('audio'),objectURL:()=> 'blob:test',revokeURL:url=>revoked.push(url)},created,revoked,setFail:value=>fail=value};
}
test('asset cache deduplicates loads, resolves offline URLs and rejects wrong media kinds',async()=>{
 const e=environment(),m=new AssetManager([{id:'art',kind:'image',src:'./assets/book.png'}],e.env);
 const a=m.loadImage('art'),b=m.loadImage('art');assert.equal(a,b);await a;assert.equal(e.created.length,1);
 assert.equal(m.resolve('art'),'file:///game/assets/book.png');await assert.rejects(m.loadAudio('art'),/Unknown/);
 m.unload('art');await m.loadImage('art');assert.equal(e.created.length,2);m.dispose();m.dispose();
});
test('failed asset loads can retry and disposal rejects pending resources',async()=>{
 const e=environment(),m=new AssetManager([{id:'art',kind:'image',src:'book.png'}],e.env);
 e.setFail(true);await assert.rejects(m.loadImage('art'),/failed/);e.setFail(false);await m.loadImage('art');
 m.unload('art');const pending=m.loadImage('art');m.dispose();await assert.rejects(pending,/cancelled/);
 await assert.rejects(m.loadImage('art'),/disposed/);
});
test('audio imports preload, play independent voices and release playback plus object URLs',async()=>{
 const e=environment(),m=new AssetManager([],e.env);m.importFile('music',new File(['audio'],'music.wav',{type:'audio/wav'}));
 const progress=[];await m.preload(['music','music'],(n,total)=>progress.push([n,total]));assert.deepEqual(progress,[[0,1],[1,1]]);
 const a=await m.playAudio('music',{loop:true,volume:.4}),b=await m.playAudio('music');
 assert.notEqual(a.element,b.element);assert.equal(a.element.loop,true);assert.equal(a.element.volume,.4);
 m.unregister('music');assert.equal(a.element.paused,true);assert.equal(b.element.paused,true);assert.equal(a.element.src,'');assert.deepEqual(e.revoked,['blob:test']);
 assert.throws(()=>m.importFile('bad',new File(['x'],'bad.txt',{type:'text/plain'})),/Only/);m.dispose();
});
