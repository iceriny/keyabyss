const test = require('node:test');
const assert = require('node:assert/strict');
const { BuildEventSystem } = require('../src/simulation/progression/BuildEventSystem.ts');
const { BUILD_EVENTS } = require('../src/content/build-events.ts');
const { builtinContent } = require('../src/bootstrap/content.ts');

const context = (changes = {}) => ({ runId: 'EVENT-TEST', room: 2, chapter: 0,
  capabilities: ['carrier', 'cold', 'heat', 'recovery', 'conduction'],
  talentGrants: { carrierGuard: 1 }, talents: [], talentSources: builtinContent.talents,
  relics: {}, definitions: builtinContent.relics, hp: 100, maxHp: 100, ...changes });
function open(system, id, ctx) {
  const offer = system.open(BUILD_EVENTS.filter(event => event.id === id), ctx, () => 0);
  assert.ok(offer, id);
  return offer;
}
function commit(system, id, ctx) {
  const offer = open(system, id, ctx);
  const result = system.commit(offer.id, 'rewrite', ctx);
  assert.ok(result);
  return result;
}

test('event offers are frozen and commit at most once against their original context', () => {
  const system = new BuildEventSystem(), ctx = context();
  const offer = open(system, 'loan-shell', ctx);
  assert.ok(Object.isFrozen(offer) && Object.isFrozen(offer.choices[0].grants));
  assert.equal(open(system, 'trial-supply', ctx), offer);
  assert.equal(system.commit(offer.id, 'rewrite', { ...ctx, hp: 99 }), undefined);
  assert.equal(system.commit(offer.id, 'missing', ctx), undefined);
  assert.equal(system.records.length, 0);
  const result = system.commit(offer.id, 'rewrite', ctx);
  assert.equal(result.maxHp, 96);
  assert.equal(result.hp, 96);
  assert.equal(system.commit(offer.id, 'rewrite', ctx), undefined);
  assert.equal(system.records.length, 1);
});

test('room and chapter loans expire at their declared boundaries without refunding health costs', () => {
  for (const [id, scope] of [['loan-relay', 'room'], ['loan-shell', 'chapter']]) {
    const system = new BuildEventSystem(), ctx = context();
    const result = commit(system, id, ctx);
    const granted = { ...system.grants };
    assert.ok(Object.keys(granted).length);
    system.advance(3, 0);
    assert.deepEqual(system.grants, granted);
    system.advance(4, 0);
    assert.deepEqual(system.grants, scope === 'room' ? {} : granted);
    system.advance(5, 1);
    assert.deepEqual(system.grants, {});
    assert.equal(system.records[0].status, 'expired');
    assert.equal(result.maxHp, id === 'loan-shell' ? 96 : 100);
  }
});

test('trial pressure is paid in the next room and its reward activates only after that room clears', () => {
  const system = new BuildEventSystem(), ctx = context();
  commit(system, 'trial-supply', ctx);
  assert.deepEqual(system.grants, {});
  assert.equal(system.records[0].status, 'pending');
  assert.equal(system.pressure(2), 0);
  assert.equal(system.pressure(3), .18);
  system.completeRoom(2);
  assert.deepEqual(system.grants, {});
  system.completeRoom(3);
  assert.equal(system.grants.materialRate, .12);
  system.completeRoom(3);
  system.advance(4, 1);
  assert.equal(system.grants.materialRate, .12);
  assert.equal(system.pressure(4), 0);
});

test('archive replacement removes its parent, charges one future reward and cannot be repeated', () => {
  const system = new BuildEventSystem(), ctx = context({ relics: { 'copy-quill': 1 } });
  const result = commit(system, 'archive-copy', ctx);
  assert.equal(result.relics['copy-quill'], undefined);
  assert.equal(result.relics['copy-palimp'], 1);
  assert.deepEqual(ctx.relics, { 'copy-quill': 1 });
  assert.equal(system.rewardDebt, 1);
  assert.equal(system.consumeRewardDebt(), true);
  assert.equal(system.consumeRewardDebt(), false);
  assert.equal(system.rewardDebt, 0);
  assert.equal(system.open(BUILD_EVENTS.filter(event => event.id === 'archive-copy'),
    { ...ctx, room: 3, relics: result.relics }, () => 0), undefined);
  system.reset();
  assert.deepEqual(system.records, []);
  assert.deepEqual(system.grants, {});
});

test('ineligible evolutions and health costs cannot be bypassed; keeping a manuscript is neutral', () => {
  const system = new BuildEventSystem();
  assert.equal(system.open(BUILD_EVENTS.filter(event => event.id === 'archive-copy'), context(), () => 0), undefined);
  assert.equal(system.open(BUILD_EVENTS.filter(event => event.id === 'loan-shell'), context({ hp: 25, maxHp: 25 }), () => 0), undefined);
  const ctx = context(), offer = open(system, 'loan-shell', ctx);
  const result = system.commit(offer.id, 'leave', ctx);
  assert.equal(result.hp, 100);
  assert.equal(result.maxHp, 100);
  assert.deepEqual(result.relics, {});
  assert.deepEqual(system.grants, {});
  assert.equal(system.rewardDebt, 0);
  assert.equal(system.records[0].status, 'kept');
});
