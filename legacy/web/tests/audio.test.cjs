const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {regionsFromSilence,validateRegions} = require('../tools/audio.ts');
const {soundCues} = require('../src/content/sound-cues.ts');
const {audioManifest} = require('../src/generated/audio-manifest.ts');
test('silence segmentation retains attack and tail handles, ignores leading/trailing silence',()=>{
  const regions=regionsFromSilence('silence_start: 0\nsilence_end: 0.8\nsilence_start: 1.5\nsilence_end: 3\nsilence_start: 4\nsilence_end: 5',5);
  assert.deepEqual(regions,[{start:.785,end:1.62},{start:2.985,end:4.12}]);
  validateRegions(regions,5);
  assert.deepEqual(regionsFromSilence('',2),[{start:0,end:2}]);
});
test('edited boundaries reject overlap, non-finite values, empty and out-of-range cuts',()=>{
  for(const value of [[],[{start:0,end:6}],[{start:NaN,end:1}],[{start:1,end:.5}],[{start:0,end:2},{start:1,end:3}]])assert.throws(()=>validateRegions(value,5));
});
test('vendor metadata and reviewed regions cover every source and every selected variant',()=>{
  const catalog=require('../data/audio-catalog.json'),overrides=require('../data/audio-overrides.json');
  assert.equal(catalog.sources.length,144);
  let total=0;
  for(const source of catalog.sources){assert.ok(source.description);const regions=overrides[source.file]??source.regions;validateRegions(regions,source.duration);total+=regions.length;}
  assert.equal(total,576);
  for(const cue of Object.values(soundCues)){const source=catalog.sources.find(s=>s.file===cue.source);assert.ok(source);for(const variant of cue.variants)assert.ok((overrides[source.file]??source.regions)[variant]);}
});
test('release contains exactly the referenced clips, lossless FLAC payloads and no source WAVs',()=>{
  const expected=[...new Set(Object.values(audioManifest).flat().map(c=>c.id+'.js'))].sort();
  const directory=path.join(__dirname,'../dist/audio');assert.deepEqual(fs.readdirSync(directory).sort(),expected);
  assert.deepEqual(Object.keys(audioManifest).sort(),Object.keys(soundCues).sort());
  for(const file of expected){const text=fs.readFileSync(path.join(directory,file),'utf8');const encoded=JSON.parse(text.match(/\]=([^;]+);/)[1]);assert.equal(Buffer.from(encoded,'base64').subarray(0,4).toString(),'fLaC');}
  assert.ok(expected.length<576);
  assert.ok(!fs.existsSync(path.join(__dirname,'../dist/art')));
});
