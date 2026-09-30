const { test } = require('node:test');
const assert = require('node:assert/strict');
const { SpellResourceRuntime, multiplyResourceQ } = require('../src/simulation/spells/SpellResourceRuntime.ts');
const { mergeCompatible } = require('../src/shared/build/spell-merge.ts');
const { findRelayPaths } = require('../src/shared/build/spell-routing.ts');
const { createRuleCompiler } = require('../src/shared/build/compile.ts');

function ok(result) { assert.equal(result.ok, true, JSON.stringify(result.errors)); return result.value; }
function error(result, code) { assert.equal(result.ok, false); if (code) assert.ok(result.errors.some(e => e.code === code), JSON.stringify(result.errors)); }
const empty = { rules: [], capabilities: [], modifiers: [], modes: [] };
const compiler = ok(createRuleCompiler({ version: 1, rules: {}, talents: {}, relics: {}, numerics: {}, modeSlots: {},
  books: Object.fromEntries(['frost', 'flame', 'storm', 'spirit'].map(book => [book, empty])) }));
const program = ok(compiler.compile({ version: 1, revision: 1, mainBook: 'frost', allocated: [], selectedModes: {}, assets: [], overrides: [] }));
function receipt(id, power = 100, work = 0, overrides = {}) {
  return { id, wordLength: 4, humanPositions: [0, 1, 2, 3], primaryPowerQ: power, auxiliaryWorkQ: work,
    program, shape: 'pierce', position: { x: 1, y: 2 }, targetId: 8, tick: 0, lifeTicks: 1200, applications: 1, processingUses: 32, ...overrides };
}
function finite(runtime, sourceId, kind = 'shell', overrides = {}) {
  return ok(runtime.createFinite({ kind, fromObjectId: sourceId, share: 1, tick: 0, delayTicks: 0,
    lifeTicks: 600, applications: 1, properties: { material: 'paper' }, ...overrides }, 8)).objects[0];
}

const circleField = { shape: 'circle', radius: 12, allocation: 'equal', onFinish: 'lose' };

test('finite material shares and retention conserve each source lot and its history', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('finite-shares', 11, 0,
    { primaryMaterialsQ: { cold: 7, charge: 5 }, processingUses: 4 })));
  ok(runtime.transfer(root.id, 9, { x: 2, y: 2 }, 10, 1));
  const field = finite(runtime, root.id, 'field', { share: .5, resourceShares: { cold: 1, charge: 0 },
    retention: .5, field: circleField });
  assert.deepEqual(['power', 'cold', 'charge'].map(resource => [runtime.balance(root.id, resource), runtime.balance(field.id, resource)]),
    [[6, 2], [0, 3], [4, 0]]);
  assert.deepEqual(runtime.ledger.getOwnedLots(field.id).map(lot => [lot.resource, lot.origin.receiptId, lot.remainingUses]),
    [['power', 'finite-shares', 3], ['cold', 'finite-shares', 3]]);
  assert.deepEqual(runtime.ledger.snapshot().lots.filter(lot => lot.resource === 'power').reduce((sum, lot) => sum + lot.quantityQ, 0), 8);
  const status = finite(runtime, field.id, 'status', { share: .5 });
  assert.equal(status.field, undefined);
  assert.equal(field.field.shape, 'circle');
});

test('field applications divide each consumed lot exactly once and close after their final share', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('field-division', 11, 0,
    { primaryMaterialsQ: { cold: 5 }, processingUses: 3 })));
  const field = finite(runtime, root.id, 'field', { applications: 2, field: circleField });
  const before = runtime.ledger.snapshot();
  assert.equal(runtime.commitHit(field.id, 9, { x: 100, y: 100 }).ok, false);
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const first = ok(runtime.applyField(field.id, [9, 3, 5, 7]));
  assert.equal(first.transaction, first.commits[0].transaction);
  assert.deepEqual(first.commits.map(commit => [commit.targetId, commit.powerQ, commit.materials.cold ?? 0]),
    [[9, 2, 1], [3, 2, 1], [5, 1, 1], [7, 1, 0]]);
  assert.equal(first.commits.reduce((sum, commit) => sum + commit.powerQ, 0), 6);
  assert.equal(runtime.balance(field.id, 'power'), 5);
  assert.equal(first.object.position.x, 1);
  const second = ok(runtime.applyField(field.id, [3, 9]));
  assert.deepEqual(second.commits.map(commit => [commit.powerQ, commit.materials.cold]), [[3, 1], [2, 1]]);
  assert.ok(second.commits.every(commit => commit.object === second.object));
  assert.equal(second.object.state, 'closed');
  assert.equal(runtime.active('field').length, 0);
  assert.equal(runtime.balance(field.id, 'power'), 0);
  error(runtime.applyField(field.id, [3]), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.getOwnedLots(root.id).map(lot => lot.remainingUses), []);
});

test('empty field behavior follows allocation policy and keeps failed applications atomic', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('field-empty', 5)));
  const equal = finite(runtime, root.id, 'field', { applications: 2, field: circleField });
  const empty = ok(runtime.applyField(equal.id, []));
  assert.deepEqual(empty.commits, []);
  assert.equal(empty.transaction.facts.filter(fact => fact.kind === 'spend' && fact.reason === 'loss').length, 1);
  assert.equal(runtime.balance(equal.id, 'power'), 2);
  assert.equal(empty.object.remainingApplications, 1);
  ok(runtime.applyField(equal.id, []));
  assert.equal(runtime.getObject(equal.id).state, 'closed');
  const other = ok(runtime.acceptManual(receipt('field-contact', 7)));
  const contact = finite(runtime, other.id, 'field', { applications: 2,
    field: { ...circleField, allocation: 'onContact' } });
  const before = runtime.ledger.snapshot(), object = runtime.getObject(contact.id);
  error(runtime.applyField(contact.id, []), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.getObject(contact.id), object);
  assert.deepEqual(ok(runtime.applyField(contact.id, [4])).commits.map(commit => commit.powerQ), [4]);
});

test('invalid finite shares, field metadata and target lists leave accounts and identities unchanged', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('field-invalid', 20, 0, { primaryMaterialsQ: { cold: 3 } })));
  const base = { kind: 'field', fromObjectId: root.id, share: .5, tick: 0, delayTicks: 0,
    lifeTicks: 100, applications: 2, field: circleField };
  const badRequests = [
    { resourceShares: null }, { resourceShares: [] }, { resourceShares: { fake: .5 } },
    { resourceShares: { cold: -1 } }, { resourceShares: { cold: NaN } },
    { field: undefined }, { field: [] }, { field: { ...circleField, radius: 0 } },
    { field: { ...circleField, radius: Infinity } }, { field: { ...circleField, extra: true } },
    { field: { ...circleField, from: { x: 0, y: 0 } } },
    { field: { ...circleField, shape: 'trail' } },
    { field: { ...circleField, shape: 'trail', from: { x: NaN, y: 0 } } },
    { field: { ...circleField, shape: 'trail', from: { x: 0, y: 0, z: 0 } } },
    { kind: 'status' }, { kind: 'shell' },
  ];
  const before = runtime.ledger.snapshot(), active = runtime.active();
  for (const change of badRequests) {
    error(runtime.createFinite({ ...base, ...change }, 8), 'INVALID_QUANTITY');
    assert.deepEqual(runtime.ledger.snapshot(), before);
    assert.deepEqual(runtime.active(), active);
  }
  const field = ok(runtime.createFinite({ ...base, field: { ...circleField, shape: 'trail', from: { x: 0, y: 0 } } }, 8)).objects[0];
  assert.equal(field.id, root.id + 1);
  const badTargets = [null, {}, [, 1], [1, 1], [-1], [1.5], [NaN], [Number.MAX_SAFE_INTEGER + 1],
    Array.from({ length: 65 }, (_, index) => index)];
  const fieldBefore = runtime.ledger.snapshot(), fieldObject = runtime.getObject(field.id);
  for (const targets of badTargets) {
    error(runtime.applyField(field.id, targets), 'INVALID_QUANTITY');
    assert.deepEqual(runtime.ledger.snapshot(), fieldBefore);
    assert.equal(runtime.getObject(field.id), fieldObject);
  }
  assert.equal(ok(runtime.applyField(field.id, [2])).commits[0].powerQ, 5);
});

test('partial storage charges loss only to its selected portion and capacity failure is atomic', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('partial', 100)));
  const request = { kind: 'shell', fromObjectId: root.id, share: .2, retention: .9,
    tick: 0, delayTicks: 20, lifeTicks: 100, applications: 1 };
  const saved = ok(runtime.createFinite(request, 1)).objects[0];
  assert.equal(runtime.balance(root.id, 'power'), 80); assert.equal(runtime.balance(saved.id, 'power'), 18);
  const before = runtime.ledger.snapshot();
  error(runtime.createFinite(request, 1), 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  error(runtime.createFinite({ ...request, retention: 1.01 }, 2), 'INVALID_QUANTITY');
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('manual replay binds the exact compiled snapshot, including programs sharing a version and revision', () => {
  const runtime = new SpellResourceRuntime(1);
  const other = ok(compiler.compile({ version: 1, revision: 1, mainBook: 'frost', allocated: [], selectedModes: {}, assets: [], overrides: [] }));
  ok(runtime.acceptManual(receipt('same-receipt')));
  error(runtime.acceptManual(receipt('same-receipt', 100, 0, { program: other })), 'RECEIPT_CONFLICT');
  assert.equal(runtime.manualCount, 1);
});

test('small weighted hit portions advance without rounding up or manufacturing damage', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('small', 1, 0, { applications: 3 })));
  assert.equal(ok(runtime.commitHit(root.id, 1, undefined, .5)).powerQ, 0);
  assert.equal(ok(runtime.commitHit(root.id, 2, undefined, .5)).powerQ, 0);
  assert.equal(ok(runtime.commitHit(root.id, 3)).powerQ, 1);
  assert.equal(runtime.getObject(root.id).state, 'closed');
});

test('the same paid attack-save-guard-release flow works for paper and crystal without a book-pair recipe', () => {
  for (const material of ['paper', 'crystal']) {
    const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt(material)));
    const children = ok(runtime.allocate(root.id, [.3, .3])).objects;
    const shell = finite(runtime, children[0].id, 'shell', { properties: { material } });
    const other = finite(runtime, children[1].id, 'shell', { properties: { material } });
    const hit = ok(runtime.commitHit(root.id, 8));
    assert.equal(hit.powerQ, 40);
    assert.equal(Math.max(0, 25 - hit.powerQ), 0); // Overkill has already left the resource account.
    assert.equal(ok(runtime.guard(shell.id, 'bullet-1', 12)).blockedPowerQ, 12);
    const exit = ok(runtime.close(shell.id, 'guard', 1));
    assert.equal(ok(runtime.commitHit(exit.escrow.id, 9)).powerQ, 18);
    assert.equal(runtime.balance(other.id, 'power'), 30);
    assert.equal(runtime.ledger.snapshot().lots.reduce((sum, lot) => sum + (lot.resource === 'power' ? lot.quantityQ : 0), 0), 30);
    error(runtime.close(shell.id, 'expiry', 2), 'STALE_RESOURCE_OWNER');
    error(runtime.guard(other.id, 'bullet-1', 12), 'DUPLICATE_CLAIM');
    assert.equal(runtime.balance(other.id, 'power'), 30);
  }
});

test('multiple genuine words fund one copy, with source history preserved and no manufactured human receipt', () => {
  const runtime = new SpellResourceRuntime(1);
  const first = ok(runtime.acceptManual(receipt('first', 100, 4)));
  error(runtime.copy(first.id, 12, .36, []), 'INSUFFICIENT_RESOURCE');
  ok(runtime.acceptManual(receipt('second', 100, 4)));
  const third = ok(runtime.acceptManual(receipt('third', 100, 4)));
  const copy = ok(runtime.copy(third.id, 12, .36, ['shape'])).objects[0];
  assert.equal(runtime.balance(0, 'work'), 0); assert.equal(runtime.balance(copy.id, 'power'), 36);
  assert.equal(runtime.balance(third.id, 'power'), 100); assert.equal(copy.shape, 'pierce');
  assert.deepEqual(runtime.ledger.getOwnedLots(copy.id).map(lot => lot.origin.receiptId), ['first', 'second', 'third']);
  assert.equal(runtime.manualCount, 3);
  error(runtime.copy(copy.id, 12, .36, ['shape']), 'INSUFFICIENT_RESOURCE');
  assert.equal(runtime.manualCount, 3);
});

test('manual income is atomic across the spell and shared work account, including replay and failed capacity', () => {
  const runtime = new SpellResourceRuntime(1), input = receipt('human-1', 100, 8);
  const first = ok(runtime.acceptManual(input));
  assert.equal(ok(runtime.acceptManual({ ...input, humanPositions: [3, 2, 1, 0] })).id, first.id);
  assert.equal(runtime.manualCount, 1); assert.equal(runtime.balance(0, 'work'), 8);
  error(runtime.acceptManual({ ...input, auxiliaryWorkQ: 9 }), 'RECEIPT_CONFLICT');
  error(runtime.acceptManual(receipt('fake-input', 100, 8, { humanPositions: [0, 0] })));
  const before = runtime.ledger.snapshot();
  error(runtime.acceptManual(receipt('too-much-work', 100, 1024 * 1_000_000_000)), 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.equal(runtime.manualCount, 1);
  const next = ok(runtime.acceptManual(receipt('human-2'))); assert.equal(next.id, first.id + 1);
});

test('copy shape inheritance does not copy material balances or work income', () => {
  const runtime = new SpellResourceRuntime(1), source = ok(runtime.acceptManual(receipt('copy-material', 100, 24)));
  ok(runtime.convert(source.id, 'power', 'cold', .2, 1, 1, 'chill'));
  const bare = ok(runtime.copy(source.id, 12, .5, [])).objects[0];
  assert.equal(bare.shape, 'shot'); assert.equal(runtime.balance(bare.id, 'cold'), 0);
  const inherited = ok(runtime.copy(source.id, 12, .5, ['shape', 'cold'])).objects[0];
  assert.equal(inherited.shape, 'pierce'); assert.equal(runtime.balance(inherited.id, 'cold'), 10);
  assert.equal(runtime.balance(source.id, 'cold'), 10); assert.equal(runtime.balance(0, 'work'), 0);
});

test('conversion retains claims so converting a portion back cannot repeat its original bonus', () => {
  const runtime = new SpellResourceRuntime(1), source = ok(runtime.acceptManual(receipt('conversion')));
  ok(runtime.convert(source.id, 'power', 'heat', .5, 1, 1, 'warm'));
  ok(runtime.convert(source.id, 'heat', 'power', 1, 1, 1, 'cool'));
  const before = runtime.ledger.snapshot();
  error(runtime.convert(source.id, 'power', 'heat', 1, 1, 1, 'warm'), 'DUPLICATE_CLAIM');
  error(runtime.convert(source.id, 'power', 'work', .5, 1, 1, 'recycle-work'));
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('stored heat is a real paid balance; reaching the threshold atomically claims the shell exit', () => {
  const runtime = new SpellResourceRuntime(1), content = ok(runtime.acceptManual(receipt('stored', 50)));
  const shell = finite(runtime, content.id);
  const heater = ok(runtime.acceptManual(receipt('heater', 100)));
  ok(runtime.convert(heater.id, 'power', 'heat', 1, 1, 1, 'heat-material'));
  const retained = ok(runtime.heat(heater.id, shell.id, 20, 30, 1, 'retain'));
  assert.equal(retained.opened, false); assert.equal(runtime.balance(shell.id, 'heat'), 20);
  const opened = ok(runtime.heat(heater.id, shell.id, 20, 30, 2, 'open'));
  assert.equal(opened.opened, true); assert.equal(runtime.balance(opened.escrow.id, 'heat'), 10);
  assert.equal(runtime.balance(heater.id, 'heat'), 60);
  assert.equal(runtime.balance(opened.escrow.id, 'power'), 50);
  error(runtime.close(shell.id, 'expiry', 2), 'STALE_RESOURCE_OWNER');
  error(runtime.close(opened.escrow.id, 'thermal', 3), 'DUPLICATE_CLAIM');
  assert.equal(ok(runtime.commitHit(opened.escrow.id, 10)).powerQ, 50);
});

test('paid heat charges the donor and shell processing allowance, retaining atomic failure and expiry', () => {
  const runtime = new SpellResourceRuntime(1), content = ok(runtime.acceptManual(receipt('saved', 50, 0, { processingUses: 2 })));
  const shell = finite(runtime, content.id);
  const heater = ok(runtime.acceptManual(receipt('donor', 20, 5, { processingUses: 1, auxiliaryResourcesQ: { heat: 30 } })));
  const heat = tick => runtime.executePaid({ objectId: shell.id, ruleId: 'heat-paid', processingUses: 1,
    costs: [{ ownerId: 0, resource: 'work', quantityQ: 2 }] }, () => runtime.heat(heater.id, shell.id, 10, 40, tick, 'retain'));
  ok(heat(1)); assert.equal(runtime.balance(heater.id, 'heat'), 20); assert.equal(runtime.balance(shell.id, 'heat'), 10);
  assert.equal(runtime.balance(0, 'work'), 3);
  for (const lot of runtime.ledger.getOwnedLots(heater.id)) assert.equal(lot.remainingUses, 0);
  const before = runtime.ledger.snapshot(); error(heat(2), 'INSUFFICIENT_RESOURCE'); assert.deepEqual(runtime.ledger.snapshot(), before);
  error(runtime.heat(heater.id, shell.id, 10, 40, shell.expiresAtTick, 'open'));
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('ongoing damage extraction reduces future damage and is unavailable until a later manual spell', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('ongoing', 100)));
  const status = finite(runtime, root.id, 'status', { applications: 4 });
  assert.equal(ok(runtime.commitHit(status.id, 8)).powerQ, 25);
  ok(runtime.recover(status.id, 'power', .4, .5, 1000, 'nextManual'));
  assert.equal(runtime.balance(status.id, 'power'), 45); // 30 removed, 15 retained and 15 lost.
  assert.equal(runtime.reserveEntries()[0].quantityQ, 15);
  error(runtime.useReserve(root.id, 'power', 100), 'INSUFFICIENT_RESOURCE');
  const next = ok(runtime.acceptManual(receipt('next', 50)));
  error(runtime.useReserve(root.id, 'power', 100), 'INSUFFICIENT_RESOURCE');
  ok(runtime.useReserve(next.id, 'power', 100));
  assert.equal(runtime.balance(next.id, 'power'), 65); assert.equal(runtime.reserveEntries().length, 0);
  assert.equal(ok(runtime.commitHit(status.id, 8)).powerQ, 15);
  assert.equal(ok(runtime.commitHit(status.id, 8)).powerQ, 15);
  assert.equal(ok(runtime.commitHit(status.id, 8)).powerQ, 15);
  error(runtime.commitHit(status.id, 8), 'STALE_RESOURCE_OWNER');
});

test('ongoing advance spends exact successive portions without moving the natural schedule', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('advance', 11, 0,
    { primaryMaterialsQ: { cold: 5 } })));
  const status = finite(runtime, root.id, 'status', { applications: 4, delayTicks: 200, lifeTicks: 600 });
  assert.deepEqual(status.status, { intervalTicks: 150, nextAtTick: 200, delayedTicks: 0 });
  const first = ok(runtime.advanceOngoing(status.id, 2, 50));
  assert.equal(first.targetId, 8);
  assert.deepEqual([first.powerQ, first.materials.cold], [6, 3]);
  assert.deepEqual(first.object.status, status.status);
  assert.equal(first.object.remainingApplications, 2);
  assert.deepEqual(first.transaction.facts.filter(fact => fact.kind === 'spend').map(fact => [fact.resource, fact.reason, fact.quantityQ]),
    [['power', 'attack', 6], ['cold', 'processing', 3]]);
  const natural = ok(runtime.commitHit(status.id, 8));
  assert.deepEqual([natural.powerQ, natural.materials.cold], [3, 1]);
  assert.equal(natural.object.status.nextAtTick, 350);
  const final = ok(runtime.advanceOngoing(status.id, 64, 100));
  assert.equal(final.powerQ, 2);
  assert.equal(final.object.remainingApplications, 0);
  assert.equal(final.object.state, 'closed');
  assert.equal(runtime.balance(status.id, 'power'), 0);
  error(runtime.advanceOngoing(status.id, 1, 100), 'STALE_RESOURCE_OWNER');
});

test('ongoing advance rejects invalid time, amount and non-damage resources atomically', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('advance-invalid', 12, 0,
    { auxiliaryResourcesQ: { opportunity: 3 } })));
  const status = finite(runtime, root.id, 'status', { applications: 3 });
  const opportunity = runtime.ledger.getOwnedLots(0).find(lot => lot.resource === 'opportunity');
  const owners = [0, status.id].map(ownerId => ({ ownerId, version: runtime.ledger.getOwner(ownerId).version }));
  ok(runtime.ledger.commit({ id: 'test:status-opportunity', expects: owners,
    transfers: [{ lotId: opportunity.lotId, toOwnerId: status.id, uses: 0 }] }));
  const snapshot = runtime.ledger.snapshot(), original = runtime.getObject(status.id);
  for (const [count, tick] of [[0, 1], [65, 1], [1.5, 1], [1, -1], [1, status.expiresAtTick]]) {
    error(runtime.advanceOngoing(status.id, count, tick));
    assert.deepEqual(runtime.ledger.snapshot(), snapshot);
    assert.equal(runtime.getObject(status.id), original);
  }
  error(runtime.advanceOngoing(status.id, 1, 1));
  assert.deepEqual(runtime.ledger.snapshot(), snapshot);
  assert.equal(runtime.getObject(status.id), original);
});

test('paid ongoing delay spends source cold and processing from both owners without increasing damage', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('delay-status', 11, 0,
    { processingUses: 2 })));
  const status = finite(runtime, root.id, 'status', { applications: 4 });
  const source = ok(runtime.acceptManual(receipt('delay-source', 2, 0,
    { primaryMaterialsQ: { cold: 9 }, processingUses: 2 })));
  ok(runtime.dispatch(source.id, 99, 1, 100));
  const payment = { objectId: status.id, ruleId: 'delay-paid', processingUses: 1, costs: [] };
  const delay = (cold, ticks, limit, at = 2) => runtime.executePaid(payment,
    () => runtime.delayOngoing(status.id, source.id, cold, ticks, limit, at));
  const beforePower = runtime.balance(status.id, 'power');
  const first = ok(delay(3, 20, 30)).objects[0];
  assert.deepEqual(first.status, { intervalTicks: 150, nextAtTick: 170, delayedTicks: 20 });
  assert.equal(first.expiresAtTick, 620);
  assert.equal(runtime.balance(source.id, 'cold'), 6);
  assert.equal(runtime.balance(status.id, 'power'), beforePower);
  assert.equal(first.targetId, status.targetId);
  assert.deepEqual(first.position, status.position);
  const afterFirst = runtime.ledger.snapshot(), firstObject = runtime.getObject(status.id);
  error(delay(1, 11, 30), 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), afterFirst);
  assert.equal(runtime.getObject(status.id), firstObject);
  const natural = ok(runtime.commitHit(status.id, 8));
  assert.equal(natural.powerQ, 3);
  assert.equal(natural.object.status.nextAtTick, 320);
  const second = ok(delay(2, 10, 30)).objects[0];
  assert.equal(second.status.nextAtTick, 330);
  assert.equal(second.status.delayedTicks, 30);
  assert.equal(second.expiresAtTick, 630);
  assert.equal(runtime.balance(source.id, 'cold'), 4);
  assert.equal(runtime.balance(status.id, 'power'), beforePower - natural.powerQ);
  const snapshot = runtime.ledger.snapshot(), unchanged = runtime.getObject(status.id);
  error(runtime.delayOngoing(status.id, source.id, 5, 1, 40, 2), 'INSUFFICIENT_RESOURCE');
  error(runtime.delayOngoing(status.id, source.id, 1, 1, 72001, 2), 'INVALID_QUANTITY');
  assert.deepEqual(runtime.ledger.snapshot(), snapshot);
  assert.equal(runtime.getObject(status.id), unchanged);
});

test('paid delay cannot bypass either owner processing allowance', () => {
  for (const exhausted of ['status', 'source']) {
    const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt(`delay-${exhausted}-status`, 12, 0,
      { processingUses: exhausted === 'status' ? 1 : 2 })));
    const status = finite(runtime, root.id, 'status', { applications: 3 });
    const source = ok(runtime.acceptManual(receipt(`delay-${exhausted}-source`, 2, 0,
      { primaryMaterialsQ: { cold: 4 }, processingUses: exhausted === 'source' ? 1 : 2 })));
    ok(runtime.dispatch(source.id, 99, 1, 100));
    const payment = { objectId: status.id, ruleId: 'delay-processing', processingUses: 1, costs: [] };
    const delay = () => runtime.executePaid(payment, () => runtime.delayOngoing(status.id, source.id, 1, 5, 20, 2));
    ok(delay());
    const snapshot = runtime.ledger.snapshot(), unchanged = runtime.getObject(status.id);
    error(delay(), 'INSUFFICIENT_RESOURCE');
    assert.deepEqual(runtime.ledger.snapshot(), snapshot);
    assert.equal(runtime.getObject(status.id), unchanged);
  }
});

test('only newly created status owns an ongoing schedule', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('status-lineage', 32, 12)));
  const status = finite(runtime, root.id, 'status', { applications: 2, properties: { integrity: 1 } });
  assert.ok(status.status);
  const nested = finite(runtime, status.id, 'status', { share: .25, applications: 2, lifeTicks: 300 });
  assert.deepEqual(nested.status, { intervalTicks: 150, nextAtTick: 150, delayedTicks: 0 });
  const shell = finite(runtime, status.id, 'shell', { share: .25 });
  assert.equal(shell.status, undefined);
  const child = ok(runtime.allocate(status.id, [.25])).objects[0];
  assert.equal(child.status, undefined);
  const copy = ok(runtime.copy(status.id, 3, .25, [])).objects[0];
  assert.equal(copy.status, undefined);
  const piece = ok(runtime.fracture(status.id, 1, 2, 1, 'status.fracture')).objects[0];
  assert.equal(piece.status, undefined);
  const exit = ok(runtime.close(shell.id, 'release', 2));
  assert.equal(exit.escrow.status, undefined);
});

test('mixed reserves share exact sixteenth-power capacity and reject exhausted recovery atomically', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('mixed', 10, 0, { primaryMaterialsQ: { cold: 32, heat: 10 }, processingUses: 1 })));
  ok(runtime.recover(source.id, 'power', 1, .7, 2, 'nextManual'));
  assert.equal(runtime.reserveUsageQ(), 2);
  const before = runtime.ledger.snapshot(), entries = runtime.reserveEntries();
  error(runtime.recover(source.id, 'power', 1, .7, 2, 'nextManual'), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.reserveEntries(), entries);

  const finer = new SpellResourceRuntime(1);
  const input = ok(finer.acceptManual(receipt('fine', 4, 0, { primaryMaterialsQ: { cold: 2, heat: 4 } })));
  ok(finer.recover(input.id, 'power', 1, .5, 3, 'nextManual'));
  ok(finer.recover(input.id, 'cold', 1, .5, 3, 'nextManual'));
  assert.equal(finer.reserveUsageQ(), 2.0625);
  ok(finer.recover(input.id, 'heat', 1, .5, 3, 'nextManual'));
  assert.equal(finer.reserveUsageQ(), 2.0625);
  assert.deepEqual(finer.reserveEntries().map(entry => [entry.resource, entry.quantityQ]), [['power', 2], ['cold', 1]]);
});

test('recovery and later use each consume one allowance, with proportional and shared per-word limits', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('source', 40, 0, { primaryMaterialsQ: { cold: 32 }, processingUses: 2 })));
  ok(runtime.recover(source.id, 'power', 1, .5, 100, 'nextManual'));
  ok(runtime.recover(source.id, 'cold', 1, .5, 100, 'nextManual'));
  assert.deepEqual(runtime.ledger.getOwnedLots(1).map(lot => lot.remainingUses), [1, 1]);
  assert.equal(runtime.availableReserveQ(source.id, 'power'), 0);
  error(runtime.useReserve(source.id, 'power', 20), 'INSUFFICIENT_RESOURCE');
  const later = ok(runtime.acceptManual(receipt('later', 10)));
  assert.equal(runtime.availableReserveQ(later.id, 'power'), 20);
  ok(runtime.useReserve(later.id, 'power', 100, .5, 11));
  assert.equal(runtime.balance(later.id, 'power'), 20);
  ok(runtime.useReserve(later.id, 'cold', 100, 1, 11));
  assert.equal(runtime.balance(later.id, 'cold'), 16);
  assert.equal(runtime.reserveUsageQ(), 10);
  const before = runtime.ledger.snapshot();
  error(runtime.useReserve(later.id, 'power', 100, 1, 11), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const final = ok(runtime.acceptManual(receipt('final', 10)));
  ok(runtime.useReserve(final.id, 'power', 100));
  assert.equal(runtime.ledger.getOwnedLots(final.id).find(lot => lot.origin.receiptId === 'source').remainingUses, 0);
  assert.equal(runtime.reserveEntries().length, 0);
});

test('burst freezes one mixed-material limit only after a successful use and keeps lot history', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('burst-source', 40, 0,
    { primaryMaterialsQ: { cold: 64 }, processingUses: 3 })));
  ok(runtime.recover(source.id, 'power', 1, .5, 100, 'nextManual'));
  ok(runtime.recover(source.id, 'cold', 1, .5, 100, 'nextManual'));
  const spell = ok(runtime.acceptManual(receipt('burst-use', 1, 1)));
  const burst = { targetPowerRatio: 4, minimumTargetRatio: 2, share: 1, totalLimitQ: 10, cooldownManuals: 2 };
  const before = runtime.ledger.snapshot();
  error(runtime.useReserve(spell.id, 'heat', 100, .25, 2, burst), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  error(runtime.useReserve(spell.id, 'power', 100, .01, 2,
    { ...burst, targetPowerRatio: 0 }), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const payment = { objectId: spell.id, ruleId: 'burst-paid', processingUses: 0,
    costs: [{ ownerId: 0, resource: 'work', quantityQ: 2 }] };
  error(runtime.executePaid(payment, () => runtime.useReserve(spell.id, 'power', 9, .25, 2, burst)), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const paid = ok(runtime.executePaid({ ...payment, costs: [{ ownerId: 0, resource: 'work', quantityQ: 1 }] },
    () => runtime.useReserve(spell.id, 'power', 9, .25, 2, burst)));
  assert.ok(paid.transaction.facts.some(fact => fact.kind === 'spend' && fact.reason === 'processing'));
  assert.equal(runtime.balance(0, 'work'), 0);
  ok(runtime.useReserve(spell.id, 'cold', 100, .25, 2, burst));
  assert.equal(runtime.balance(spell.id, 'power'), 10);
  assert.equal(runtime.balance(spell.id, 'cold'), 16);
  assert.deepEqual(runtime.ledger.getOwnedLots(spell.id).filter(lot => lot.origin.receiptId === 'burst-source')
    .map(lot => [lot.resource, lot.remainingUses]), [['power', 1], ['cold', 1]]);
  const after = runtime.ledger.snapshot();
  error(runtime.useReserve(spell.id, 'power', 100, .25, 2, { ...burst, targetPowerRatio: 5 }), 'RECEIPT_CONFLICT');
  error(runtime.useReserve(spell.id, 'power', 100, .25, 2), 'RECEIPT_CONFLICT');
  error(runtime.useReserve(spell.id, 'power', 100, .5, 2, burst), 'RECEIPT_CONFLICT');
  assert.deepEqual(runtime.ledger.snapshot(), after);
});

test('burst is once per room target and cooldown advances on genuine manual words', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('cooldown-source', 100, 0, { primaryMaterialsQ: { cold: 32 } })));
  ok(runtime.recover(source.id, 'power', 1, .7, 100, 'nextManual'));
  ok(runtime.recover(source.id, 'cold', 1, .5, 100, 'nextManual'));
  const burst = { targetPowerRatio: 4, minimumTargetRatio: 2, share: 1, totalLimitQ: 10, cooldownManuals: 2 };
  const first = ok(runtime.acceptManual(receipt('cooldown-first', 1, 0, { targetId: 8 })));
  ok(runtime.useReserve(first.id, 'power', 9, .1, 2, burst));
  assert.equal(runtime.balance(first.id, 'power'), 10);
  const second = ok(runtime.acceptManual(receipt('cooldown-second', 1, 0, { targetId: 9 })));
  error(runtime.useReserve(second.id, 'power', 100), 'INSUFFICIENT_RESOURCE');
  const third = ok(runtime.acceptManual(receipt('cooldown-third', 1, 0, { targetId: 9 })));
  error(runtime.useReserve(third.id, 'power', 100, .1, 2, burst), 'INSUFFICIENT_RESOURCE');
  const sameTarget = ok(runtime.acceptManual(receipt('cooldown-same', 1, 0, { targetId: 8 })));
  ok(runtime.useReserve(sameTarget.id, 'power', 100, .1, 2, burst));
  assert.equal(runtime.balance(sameTarget.id, 'power'), 3);
  const newTarget = ok(runtime.acceptManual(receipt('cooldown-new', 1, 0, { targetId: 9 })));
  ok(runtime.useReserve(newTarget.id, 'power', 100, .1, 2, burst));
  assert.equal(runtime.balance(newTarget.id, 'power'), 11);
  ok(runtime.useReserve(first.id, 'cold', 100, .1, 2, burst));
  assert.equal(runtime.balance(first.id, 'cold'), 16);
});

test('successful plain use cannot switch to burst but may retain its original varying parameters', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('plain-source', 100, 0, { primaryMaterialsQ: { cold: 32 } })));
  ok(runtime.recover(source.id, 'power', 1, .5, 100, 'nextManual'));
  ok(runtime.recover(source.id, 'cold', 1, .5, 100, 'nextManual'));
  const spell = ok(runtime.acceptManual(receipt('plain-use', 1)));
  ok(runtime.useReserve(spell.id, 'power', 100, .1, 2));
  const burst = { targetPowerRatio: 4, minimumTargetRatio: 2, share: 1, totalLimitQ: 10, cooldownManuals: 2 };
  error(runtime.useReserve(spell.id, 'cold', 100, .1, 2, burst), 'RECEIPT_CONFLICT');
  ok(runtime.useReserve(spell.id, 'cold', 100, 1, 10));
  assert.equal(runtime.balance(spell.id, 'cold'), 16);
});

test('split calls cannot compound the frozen per-material fraction or retarget a burst receipt', () => {
  const runtime = new SpellResourceRuntime(1), source = ok(runtime.acceptManual(receipt('split-burst-source', 200, 0, { primaryMaterialsQ: { cold: 80 } })));
  ok(runtime.recover(source.id, 'power', 1, .5, 200, 'nextManual'));
  ok(runtime.recover(source.id, 'cold', 1, .5, 200, 'nextManual'));
  const spell = ok(runtime.acceptManual(receipt('split-burst', 1)));
  const burst = { targetPowerRatio: 4, minimumTargetRatio: 3, share: .75, totalLimitQ: 200, cooldownManuals: 2 };
  ok(runtime.useReserve(spell.id, 'power', 10, 1, 12, burst));
  ok(runtime.useReserve(spell.id, 'power', 100, 1, 12, burst));
  assert.equal(runtime.balance(spell.id, 'power'), 76); assert.equal(runtime.balance(1, 'power'), 25);
  const before = runtime.ledger.snapshot();
  error(runtime.useReserve(spell.id, 'power', 100, 1, 12, burst), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  ok(runtime.useReserve(spell.id, 'cold', 4, 1, 12, burst));
  ok(runtime.useReserve(spell.id, 'cold', 100, 1, 12, burst));
  assert.equal(runtime.balance(spell.id, 'cold'), 30);
  ok(runtime.dispatch(spell.id, 99, 0, 20));
  error(runtime.useReserve(spell.id, 'cold', 100, 1, 12, burst), 'RECEIPT_CONFLICT');
});

test('invalid burst values fail without creating a plan or spending reserve', () => {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('invalid-burst-source', 20)));
  ok(runtime.recover(source.id, 'power', 1, .5, 100, 'nextManual'));
  const spell = ok(runtime.acceptManual(receipt('invalid-burst-use', 1)));
  const burst = { targetPowerRatio: 4, minimumTargetRatio: 2, share: 1, totalLimitQ: 10, cooldownManuals: 2 };
  const before = runtime.ledger.snapshot();
  for (const invalid of [
    { targetPowerRatio: Infinity }, { targetPowerRatio: -1 }, { targetPowerRatio: 1_000_001 },
    { minimumTargetRatio: 0 }, { minimumTargetRatio: Infinity }, { share: 0 },
    { totalLimitQ: 0 }, { totalLimitQ: 1.5 }, { cooldownManuals: 0 }, { cooldownManuals: 65 }, { extra: true },
  ]) error(runtime.useReserve(spell.id, 'power', 10, 1, 10, { ...burst, ...invalid }), 'INVALID_QUANTITY');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  ok(runtime.useReserve(spell.id, 'power', 10, 1, 10, burst));
});

test('cooldown travels with nonempty and empty handoffs and replay cannot extend it', () => {
  for (const emptyTicket of [false, true]) {
    const source = new SpellResourceRuntime(4);
    const seed = ok(source.acceptManual(receipt(`handoff-seed-${emptyTicket}`, 100)));
    ok(source.recover(seed.id, 'power', 1, .5, 100, 'nextManual'));
    if (!emptyTicket) {
      const carry = ok(source.acceptManual(receipt('handoff-carry', 100)));
      ok(source.recover(carry.id, 'power', 1, .5, 100, 'nextRoom'));
    }
    const trigger = ok(source.acceptManual(receipt(`handoff-trigger-${emptyTicket}`, 1)));
    const burst = { targetPowerRatio: 4, minimumTargetRatio: 2, share: 1, totalLimitQ: 10, cooldownManuals: 2 };
    ok(source.useReserve(trigger.id, 'power', 100, 1, 10, burst));
    source.active().forEach(object => ok(source.discard(object.id)));
    const ticket = ok(source.exportReserves());
    assert.equal(ticket.cooldownManuals, 2);
    assert.equal(ticket.resources.lots.length, emptyTicket ? 0 : 1);
    const next = new SpellResourceRuntime(5);
    const invalid = { ...ticket, cooldownManuals: 65 };
    error(next.importReserves(invalid), 'INVALID_QUANTITY');
    assert.equal(next.reserveEntries().length, 0);
    ok(next.importReserves(ticket));
    const ledger = next.ledger.snapshot();
    error(next.importReserves({ ...ticket, cooldownManuals: 1 }), 'RECEIPT_CONFLICT');
    assert.deepEqual(next.ledger.snapshot(), ledger);
    const one = ok(next.acceptManual(receipt(`handoff-one-${emptyTicket}`, 1)));
    error(next.useReserve(one.id, 'power', 100), 'INSUFFICIENT_RESOURCE');
    ok(next.importReserves(ticket));
    const two = ok(next.acceptManual(receipt(`handoff-two-${emptyTicket}`, 1)));
    error(next.useReserve(two.id, 'power', 100), 'INSUFFICIENT_RESOURCE');
    const three = ok(next.acceptManual(receipt(`handoff-three-${emptyTicket}`, 1)));
    if (!emptyTicket) ok(next.useReserve(three.id, 'power', 100));
  }
});

test('archive is atomic and idempotent, preserving source history across rooms', () => {
  const source = new SpellResourceRuntime(4);
  const spell = ok(source.acceptManual(receipt('archive-source', 40, 0, { primaryMaterialsQ: { cold: 32 }, processingUses: 3 })));
  ok(source.recover(spell.id, 'power', 1, .5, 100, 'nextManual'));
  ok(source.recover(spell.id, 'cold', 1, .5, 100, 'nextManual'));
  error(source.archiveReserves(.5, 100));
  ok(source.discard(spell.id));
  const before = source.ledger.snapshot();
  error(source.archiveReserves(.91, 1), 'INVALID_QUANTITY');
  assert.deepEqual(source.ledger.snapshot(), before);
  const archive = ok(source.archiveReserves(.5, 11));
  assert.deepEqual(source.reserveEntries().map(entry => [entry.resource, entry.quantityQ, entry.availableInRoom]),
    [['power', 10, 5], ['cold', 8, 5]]);
  assert.equal(source.reserveUsageQ(), 10.5);
  assert.deepEqual(ok(source.archiveReserves(.5, 11)), archive);
  error(source.archiveReserves(.5, 6), 'RECEIPT_CONFLICT');
  error(source.acceptManual(receipt('blocked')));
  const ticket = ok(source.exportReserves());
  const next = new SpellResourceRuntime(5);
  ok(next.importReserves(ticket));
  const imported = next.ledger.getOwnedLots(1);
  assert.deepEqual(imported.map(lot => [lot.origin.receiptId, lot.remainingUses]), [['archive-source', 2], ['archive-source', 2]]);
  const manual = ok(next.acceptManual(receipt('next-room', 10)));
  ok(next.useReserve(manual.id, 'power', 100));
  assert.equal(next.ledger.getOwnedLots(manual.id).find(lot => lot.origin.receiptId === 'archive-source').remainingUses, 1);
  const empty = new SpellResourceRuntime(9);
  assert.deepEqual(ok(empty.archiveReserves(.5, 1)), ok(empty.archiveReserves(.5, 1)));
  assert.equal(ok(empty.exportReserves()).resources.lots.length, 0);
});

test('archive applies one shared capacity after retention in stable lot order', () => {
  const runtime = new SpellResourceRuntime(2);
  const spell = ok(runtime.acceptManual(receipt('trim', 40, 0, { primaryMaterialsQ: { cold: 64, heat: 16 } })));
  ok(runtime.recover(spell.id, 'power', 1, .5, 100, 'nextManual'));
  ok(runtime.recover(spell.id, 'cold', 1, .5, 100, 'nextManual'));
  ok(runtime.recover(spell.id, 'heat', 1, .5, 100, 'nextManual'));
  ok(runtime.discard(spell.id));
  ok(runtime.archiveReserves(.5, 6));
  assert.deepEqual(runtime.reserveEntries().map(entry => [entry.resource, entry.quantityQ]), [['power', 6]]);
  assert.equal(runtime.reserveUsageQ(), 6);
  error(runtime.importReserves({ fromRoom: 1, toRoom: 2, resources: { id: 'room:1:reserve', lots: [] } }));
});

test('same-root merge keeps input lots, waits for all inputs and never refreshes their lifetime', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('merge')));
  const [a, b] = ok(runtime.allocate(root.id, [.4, .4])).objects;
  const shells = [finite(runtime, a.id, 'shell', { delayTicks: 10, lifeTicks: 100 }), finite(runtime, b.id, 'shell', { delayTicks: 20, lifeTicks: 200 })];
  const output = ok(runtime.merge(shells.map(shell => shell.id), 5, 1)).objects[0];
  assert.equal(output.readyAtTick, 25); assert.equal(output.expiresAtTick, 100);
  assert.equal(runtime.balance(output.id, 'power'), 80); assert.equal(runtime.ledger.getOwnedLots(output.id).length, 2);
  const otherRoot = ok(runtime.acceptManual(receipt('other-merge'))), otherShell = finite(runtime, otherRoot.id);
  error(runtime.merge([output.id, otherShell.id], 1, 2));
  assert.equal(runtime.balance(output.id, 'power'), 80);
});

test('paid merge claims every real input once even when its payment object is empty', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('paid-merge', 100, 10, { processingUses: 3 })));
  const allocatePayment = { objectId: root.id, ruleId: 'earlier', processingUses: 1, costs: [] };
  const [a, b] = ok(runtime.executePaid(allocatePayment, () => runtime.allocate(root.id, [.5, .5]))).objects;
  assert.equal(runtime.balance(root.id, 'power'), 0);
  const inputLots = [a, b].map(object => runtime.ledger.getOwnedLots(object.id)[0]);
  assert.deepEqual(inputLots.map(lot => lot.remainingUses), [2, 2]);
  const payment = { objectId: root.id, ruleId: 'merge-paid', portionLimit: 1, processingUses: 1,
    costs: [{ ownerId: 0, resource: 'work', quantityQ: 3 }] };
  const result = ok(runtime.executePaid(payment, () => runtime.merge([a.id, b.id], 0, 1)));
  const outputLots = runtime.ledger.getOwnedLots(result.objects[0].id);
  assert.deepEqual(outputLots.map(lot => lot.lotId), inputLots.map(lot => lot.lotId));
  assert.deepEqual(outputLots.map(lot => lot.remainingUses), [1, 1]);
  assert.deepEqual(outputLots.map(lot => lot.ruleClaims), [
    { 'rule:earlier': 1, 'rule:merge-paid': 1 }, { 'rule:earlier': 1, 'rule:merge-paid': 1 },
  ]);
  assert.deepEqual(outputLots.map(lot => lot.origin.receiptId), ['paid-merge', 'paid-merge']);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'rule:merge-paid').length, 2);
  assert.equal(runtime.balance(0, 'work'), 7);
});

test('merge preserves oldest age and distinguishes preserved shape from one concentrated application', () => {
  for (const policy of ['preserveShape', 'concentrate']) {
    const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt(`policy-${policy}`, 101, 0, { applications: 4 })));
    const [a, b] = ok(runtime.allocate(root.id, [.5, .5])).objects;
    const left = finite(runtime, a.id, 'shell', { tick: 1, delayTicks: 10, lifeTicks: 99, applications: 4 });
    const right = finite(runtime, b.id, 'shell', { tick: 5, delayTicks: 20, lifeTicks: 200, applications: 3 });
    const output = ok(runtime.merge([right.id, left.id], 5, 8, policy)).objects[0];
    assert.equal(output.createdAtTick, 1); assert.equal(output.readyAtTick, 30); assert.equal(output.expiresAtTick, 100);
    assert.equal(output.remainingApplications, policy === 'concentrate' ? 1 : 3);
    assert.equal(output.shape, 'pierce'); assert.equal(runtime.balance(output.id, 'power'), 100);
    assert.equal(runtime.ledger.getOwnedLots(output.id).length, 2);
    assert.ok(runtime.ledger.getOwnedLots(output.id).every(lot => lot.origin.receiptId === root.rootReceiptId));
  }
});

test('merge rejects live effect timers, remote pages and changed inheritance without consuming their inputs', () => {
  for (const kind of ['field', 'status', 'shell', 'inheritance']) {
    const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt(`incompatible-${kind}`, 100, 10, { shape: 'shot' })));
    let parts;
    if (kind === 'inheritance') parts = [ok(runtime.copy(root.id, 2, .2, [])).objects[0], ok(runtime.copy(root.id, 2, .2, ['shape'])).objects[0]];
    else {
      const [a, b] = ok(runtime.allocate(root.id, [.5, .5])).objects;
      parts = [finite(runtime, a.id, kind, { ...(kind === 'field' ? { field: circleField } : {}) }),
        finite(runtime, b.id, kind, { ...(kind === 'field' ? { field: circleField } : {}), ...(kind === 'shell' ? { position: { x: 8, y: 2 } } : {}) })];
    }
    const before = runtime.ledger.snapshot(), objects = runtime.active();
    error(runtime.merge(parts.map(part => part.id), 1, 1));
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
  }
});

for (const [name, initialUses, priorUses, priorRule, code] of [
  ['exhausted input', 1, 1, 'earlier', 'INSUFFICIENT_RESOURCE'],
  ['prior rule claim', 3, 0, 'merge-limit', 'DUPLICATE_CLAIM'],
]) test(`paid merge rejects ${name} atomically`, () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt(`merge-${name}`, 100, 10, { processingUses: initialUses })));
  const [a, b] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  ok(runtime.executePaid({ objectId: a.id, ruleId: priorRule, portionLimit: 1,
    processingUses: priorUses, costs: [] }, () => runtime.allocate(a.id, [.5])));
  const before = runtime.ledger.snapshot(), objects = runtime.active().map(object => object.id);
  error(runtime.executePaid({ objectId: root.id, ruleId: 'merge-limit', portionLimit: 1,
    processingUses: 1, costs: [{ ownerId: 0, resource: 'work', quantityQ: 3 }] },
  () => runtime.merge([a.id, b.id], 0, 1)), code);
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.deepEqual(runtime.active().map(object => object.id), objects);
  assert.equal(runtime.balance(0, 'work'), 10);
  assert.equal(ok(runtime.allocate(b.id, [.5])).objects[0].id, 6);
});

test('capacity, empty resources and invalid properties fail without losing power or reserving phantom slots', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('capacity')));
  const request = { kind: 'shell', fromObjectId: root.id, share: .5, tick: 0, delayTicks: 20, lifeTicks: 10, applications: 1 };
  const shell = ok(runtime.createFinite(request, 1)).objects[0]; // Short lifetime is valid: expiry rules decide its exit.
  const before = runtime.ledger.snapshot();
  error(runtime.createFinite(request, 1), 'RESOURCE_LIMIT');
  error(runtime.createFinite({ ...request, properties: { arbitraryPermission: 'manual' } }, 2));
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const close = ok(runtime.close(shell.id, 'expiry', 10));
  ok(runtime.discard(close.escrow.id));
  assert.equal(runtime.active('shell').length, 0);
  ok(runtime.createFinite(request, 1));
});

test('fixed-point split remainder is deterministic even near safe-integer limits', () => {
  const quantity = Number.MAX_SAFE_INTEGER;
  assert.equal(multiplyResourceQ(quantity, .7), Number(BigInt(quantity) * 7n / 10n));
  for (const [policy, expectedChildren, expectedParent] of [['parent', [1, 1], 1], ['firstChild', [2, 1], 0], ['loss', [1, 1], 0]]) {
    const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt(policy, 3)));
    const children = ok(runtime.allocate(root.id, [.5, .5], policy)).objects;
    assert.deepEqual(children.map(child => runtime.balance(child.id, 'power')), expectedChildren);
    assert.equal(runtime.balance(root.id, 'power'), expectedParent);
  }
});

test('release takes the closing escrow into one finite flight and cannot dispatch it twice', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('release')));
  const shell = finite(runtime, root.id), exit = ok(runtime.close(shell.id, 'release', 2));
  const flying = ok(runtime.dispatch(exit.escrow.id, 10, 2, 120)).objects[0];
  assert.equal(flying.state, 'flight'); assert.equal(flying.expiresAtTick, 122);
  error(runtime.dispatch(exit.escrow.id, 11, 2, 120), 'STALE_RESOURCE_OWNER');
  assert.equal(ok(runtime.commitHit(flying.id, 10)).powerQ, 100);
});

test('routing checks actual distance and consumes charge and inherited processing uses atomically', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('routing', 100, 0, { processingUses: 2, applications: 3 })));
  ok(runtime.convert(root.id, 'power', 'charge', .5, 1, 1, 'charge'));
  const before = runtime.ledger.snapshot();
  error(runtime.transfer(root.id, 11, { x: 200, y: 2 }, 100, 10));
  assert.deepEqual(runtime.ledger.snapshot(), before);
  ok(runtime.transfer(root.id, 11, { x: 50, y: 2 }, 100, 10));
  ok(runtime.transfer(root.id, 12, { x: 140, y: 2 }, 100, 10));
  assert.equal(runtime.balance(root.id, 'charge'), 30); assert.equal(runtime.balance(root.id, 'power'), 50);
  error(runtime.transfer(root.id, 13, { x: 150, y: 2 }, 100, 10), 'INSUFFICIENT_RESOURCE');
  assert.equal(runtime.balance(root.id, 'charge'), 30);
  assert.equal(runtime.getObject(root.id).targetId, 12);
});

test('routing rejects insufficient charge without moving the spell or spending processing uses', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('routing-short', 20, 0,
    { primaryMaterialsQ: { charge: 3 }, applications: 2, processingUses: 2 })));
  const before = runtime.ledger.snapshot(), object = runtime.getObject(root.id);
  error(runtime.transfer(root.id, 9, { x: 2, y: 2 }, 10, 4), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.getObject(root.id), object);
  const shell = finite(runtime, root.id);
  error(runtime.transfer(shell.id, 9, { x: 2, y: 2 }, 10, 1), 'STALE_RESOURCE_OWNER');
});

test('resource shares allocate each material independently while preserving lot origin and processing history', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('resource-shares', 101, 0,
    { primaryMaterialsQ: { charge: 9, cold: 5 }, applications: 2, processingUses: 4 })));
  const children = ok(runtime.allocate(root.id, [.25, .25], 'parent', {
    resourceShares: { charge: [1, 0], cold: [0, 1] }, shape: 'chain', applications: 3,
  })).objects;
  assert.deepEqual(children.map(child => [child.shape, child.inheritedShape, child.remainingApplications]),
    [['chain', false, 3], ['chain', false, 3]]);
  assert.deepEqual(children.map(child => [runtime.balance(child.id, 'power'), runtime.balance(child.id, 'charge'), runtime.balance(child.id, 'cold')]),
    [[25, 9, 0], [25, 0, 5]]);
  assert.equal(runtime.balance(root.id, 'power'), 51);
  assert.equal(runtime.balance(root.id, 'charge'), 0);
  assert.equal(runtime.balance(root.id, 'cold'), 0);
  for (const child of children) for (const lot of runtime.ledger.getOwnedLots(child.id)) {
    assert.equal(lot.origin.receiptId, 'resource-shares');
    assert.equal(lot.remainingUses, 4);
  }
  const inherited = ok(runtime.allocate(root.id, [.5])).objects[0];
  assert.equal(inherited.shape, root.shape);
  assert.equal(inherited.inheritedShape, root.inheritedShape);
  assert.equal(inherited.remainingApplications, root.remainingApplications);
});

test('invalid resource allocation options leave balances, objects and ids unchanged', () => {
  const cases = [
    [[.5], { resourceShares: { fake: [.5] } }],
    [[.5], { resourceShares: { charge: [.5, .5] } }],
    [[.5], { resourceShares: { charge: [-.1] } }],
    [[.5], { resourceShares: { charge: [1.1] } }],
    [[.5], { resourceShares: { charge: [NaN] } }],
    [[.5, .5], { resourceShares: { charge: [1] } }],
    [[.5, .5], { resourceShares: { charge: [1, .1] } }],
    [[.5], { resourceShares: null }],
    [[.5], { resourceShares: [] }],
    [[.5, .5], { resourceShares: { charge: [, .5] } }],
    [[, .5], {}],
    [[.5], null],
    [[.5], []],
    [[.5], { unknown: true }],
    [[.5], { shape: 'unknown' }],
    [[.5], { applications: 0 }],
    [[.5], { applications: 65 }],
    [[.5], { applications: 1.5 }],
  ];
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('bad-shares', 100, 0,
    { primaryMaterialsQ: { charge: 10 } })));
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  for (const [shares, options] of cases) {
    error(runtime.allocate(root.id, shares, 'parent', options));
    assert.deepEqual(runtime.ledger.snapshot(), before);
    assert.deepEqual(runtime.active(), objects);
  }
  assert.equal(ok(runtime.allocate(root.id, [.5])).objects[0].id, root.id + 1);
});

test('chain hit retains charge for routing closure but cannot transfer after its last application', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('chain-hit', 20, 0,
    { primaryMaterialsQ: { charge: 10 }, shape: 'chain', applications: 1, processingUses: 2 })));
  const hit = ok(runtime.commitHit(root.id, 8));
  assert.equal(hit.powerQ, 20);
  assert.equal(hit.materials.charge, undefined);
  assert.equal(hit.object.state, 'flight');
  assert.equal(hit.object.remainingApplications, 0);
  assert.equal(runtime.balance(root.id, 'power'), 0);
  assert.equal(runtime.balance(root.id, 'charge'), 10);
  const before = runtime.ledger.snapshot();
  error(runtime.transfer(root.id, 9, { x: 2, y: 2 }, 10, 1), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const exit = ok(runtime.close(root.id, 'routing', 1));
  assert.equal(runtime.balance(exit.escrow.id, 'charge'), 10);
  assert.equal(runtime.balance(exit.escrow.id, 'power'), 0);
  assert.equal(ok(runtime.commitHit(exit.escrow.id, 8)).powerQ, 0);
  const shot = ok(runtime.acceptManual(receipt('shot-charge', 1, 0, { shape: 'shot', primaryMaterialsQ: { charge: 2 } })));
  const shotHit = ok(runtime.commitHit(shot.id, 8));
  assert.equal(shotHit.materials.charge, 2);
  assert.equal(runtime.balance(shot.id, 'charge'), 0);
  const dry = ok(runtime.acceptManual(receipt('chain-dry', 1, 0, { shape: 'chain' })));
  assert.equal(ok(runtime.commitHit(dry.id, 8)).object.state, 'closed');
});

test('fracture consumes structure and creates funded pieces without requiring simultaneous cold and heat', () => {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('fracture', 11)));
  const shell = finite(runtime, root.id, 'shell', { properties: { material: 'paper', integrity: 1 } });
  const pieces = ok(runtime.fracture(shell.id, 1, 3, 1, 'fracture.rule')).objects;
  assert.deepEqual(pieces.map(piece => runtime.balance(piece.id, 'power')), [4, 4, 3]);
  assert.ok(pieces.every(piece => piece.properties.integrity === 0));
  error(runtime.fracture(shell.id, 1, 3, 1, 'fracture.rule'), 'STALE_RESOURCE_OWNER');
  error(runtime.fracture(pieces[0].id, 1, 3, 1, 'fracture.rule'));
});

test('only next-room reserves cross the room boundary, preserving their processing history', () => {
  const source = new SpellResourceRuntime(4);
  const first = ok(source.acceptManual(receipt('carry', 100, 20)));
  ok(source.convert(first.id, 'power', 'cold', .5, 1, 1, 'cold-bonus'));
  ok(source.recover(first.id, 'cold', 1, .7, 100, 'nextRoom'));
  ok(source.recover(first.id, 'power', 1, .5, 100, 'nextManual'));
  // The previous room's ordinal must not block the first spell in the new room.
  const last = ok(source.acceptManual(receipt('later', 100)));
  ok(source.recover(last.id, 'power', 1, .5, 100, 'nextRoom'));
  error(source.exportReserves());
  source.active().forEach(object => ok(source.discard(object.id)));
  const ticket = ok(source.exportReserves());
  assert.deepEqual(ticket.resources.lots.map(lot => [lot.resource, lot.quantityQ]), [['cold', 35], ['power', 50]]);
  assert.equal(source.balance(0, 'work'), 20);
  assert.equal(source.balance(1, 'power'), 25);
  assert.deepEqual(ok(source.exportReserves()), ticket);
  error(source.acceptManual(receipt('too-late')));
  const next = new SpellResourceRuntime(5);
  error(new SpellResourceRuntime(6).importReserves(ticket));
  ok(next.importReserves(ticket));
  assert.equal(next.manualCount, 0);
  assert.equal(next.balance(0, 'work'), 0);
  const imported = next.ledger.getOwnedLots(1).find(lot => lot.resource === 'cold');
  assert.deepEqual(imported.appliedBonuses, ['cold-bonus']);
  assert.equal(imported.origin.receiptId, 'carry');
  assert.deepEqual(imported.parentLots, []);
  const spell = ok(next.acceptManual(receipt('new-room', 100)));
  ok(next.useReserve(spell.id, 'cold', 100));
  ok(next.useReserve(spell.id, 'power', 100));
  assert.equal(next.balance(spell.id, 'cold'), 35);
  assert.equal(next.balance(spell.id, 'power'), 150);
  const before = next.ledger.snapshot();
  ok(next.importReserves(ticket));
  assert.deepEqual(next.ledger.snapshot(), before);
  assert.equal(next.reserveEntries().length, 0);
  error(next.importReserves({ ...ticket, resources: { ...ticket.resources,
    lots: [{ ...ticket.resources.lots[0], quantityQ: 1 }] } }), 'RECEIPT_CONFLICT');
  ok(next.discard(spell.id));
  assert.equal(ok(next.exportReserves()).resources.lots.length, 0);
});

test('transport pays both lots, retains each cargo material and consumes its attack ticket', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('transport-pay', 100, 0,
    { primaryMaterialsQ: { cold: 9 }, processingUses: 4 })));
  const [source, attack] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id);
  const originalLots = runtime.ledger.getOwnedLots(shell.id);
  const result = ok(runtime.startTransport(shell.id, attack.id, 7, 1, .5));
  const cargo = result.objects[0];
  assert.equal(cargo.state, 'carried');
  assert.deepEqual(cargo.transport, { actorId: 7, returning: false });
  assert.equal(runtime.storedCount(1), 0);
  assert.equal(runtime.balance(shell.id, 'power'), 25);
  assert.equal(runtime.balance(shell.id, 'cold'), 2);
  assert.equal(runtime.balance(attack.id, 'power'), 0);
  assert.equal(runtime.balance(attack.id, 'cold'), 0);
  assert.equal(runtime.getObject(attack.id).state, 'closed');
  assert.deepEqual(runtime.ledger.getOwnedLots(shell.id).map(lot => lot.lotId), originalLots.map(lot => lot.lotId));
  assert.ok(runtime.ledger.getOwnedLots(shell.id).every(lot => lot.remainingUses === 3
    && lot.ruleClaims['native.transport.take'] === 1));
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'native.transport.take').length, 4);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'spend' && fact.reason === 'processing').length, 2);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'spend' && fact.reason === 'loss').length, 2);
});

test('paid transport claims both owners once and fails atomically when native allowance is exhausted', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('paid-transport', 100, 10, { processingUses: 2 })));
  const [source, ticket] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id);
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  error(runtime.executePaid({ objectId: shell.id, ruleId: 'transport-paid-full', processingUses: 2,
    costs: [{ ownerId: 0, resource: 'work', quantityQ: 3 }] },
  () => runtime.startTransport(shell.id, ticket.id, 1, 1, 1)), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
  assert.equal(runtime.balance(0, 'work'), 10);
  const result = ok(runtime.executePaid({ objectId: shell.id, ruleId: 'transport-paid', processingUses: 1,
    costs: [{ ownerId: 0, resource: 'work', quantityQ: 3 }] },
  () => runtime.startTransport(shell.id, ticket.id, 1, 1, 1)));
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'rule:transport-paid').length, 2);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'native.transport.take').length, 2);
  assert.equal(runtime.balance(0, 'work'), 7);
  assert.equal(runtime.ledger.getOwnedLots(shell.id)[0].remainingUses, 0);
});

test('transport failures preserve ledger, objects, actor ownership and processing uses', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('transport-atomic', 100, 0, { processingUses: 1 })));
  const [source, ticket] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id);
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  error(runtime.startTransport(shell.id, ticket.id, 2, 1, .01), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
  error(runtime.startTransport(shell.id, ticket.id, -1, 1, 1), 'INVALID_QUANTITY');
  const cargo = ok(runtime.startTransport(shell.id, ticket.id, 2, 1, 1)).objects[0];
  const secondRoot = ok(runtime.acceptManual(receipt('second-transport')));
  const [otherSource, otherTicket] = ok(runtime.allocate(secondRoot.id, [.5, .5])).objects;
  const otherShell = finite(runtime, otherSource.id);
  const occupied = runtime.ledger.snapshot();
  error(runtime.startTransport(otherShell.id, otherTicket.id, 2, 1, 1), 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), occupied);
  error(runtime.beginTransportReturn(cargo.id, 3, 2), 'STALE_RESOURCE_OWNER');
  assert.equal(runtime.getObject(cargo.id).transport.returning, false);
  ok(runtime.beginTransportReturn(cargo.id, 2, 2));
  error(runtime.beginTransportReturn(cargo.id, 2, 2), 'STALE_RESOURCE_OWNER');
  error(runtime.returnTransport(cargo.id, 2, 3, 1, 1, 0, { x: 1, y: 2 }), 'RESOURCE_LIMIT');
  assert.equal(runtime.getObject(cargo.id).state, 'carried');
  assert.equal(runtime.balance(cargo.id, 'power'), 50);
  error(runtime.returnTransport(cargo.id, 2, 599, 2, 1, 1, { x: 1, y: 2 }), 'STALE_RESOURCE_OWNER');
  error(runtime.returnTransport(cargo.id, 2, 3, 2, 1, 0, { x: Infinity, y: 2 }), 'INVALID_QUANTITY');
});

test('return uses real storage capacity and original expiry; a returned shell cannot return twice', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('transport-return')));
  const [source, ticket] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id, 'shell', { lifeTicks: 30 });
  ok(runtime.startTransport(shell.id, ticket.id, 4, 1, .8));
  ok(runtime.beginTransportReturn(shell.id, 4, 2));
  const returned = ok(runtime.returnTransport(shell.id, 4, 3, 1, .5, 5, { x: 9, y: 8 })).objects[0];
  assert.equal(returned.state, 'stored'); assert.equal(returned.transport, undefined);
  assert.equal(returned.transportReturned, true); assert.equal(returned.readyAtTick, 8);
  assert.equal(returned.expiresAtTick, shell.expiresAtTick);
  assert.deepEqual(returned.position, { x: 9, y: 8 });
  assert.equal(runtime.storedCount(3), 1); assert.equal(runtime.balance(shell.id, 'power'), 20);
  const nextRoot = ok(runtime.acceptManual(receipt('return-ticket')));
  const nextTicket = ok(runtime.allocate(nextRoot.id, [.5])).objects[0];
  ok(runtime.startTransport(shell.id, nextTicket.id, 4, 8, 1));
  error(runtime.beginTransportReturn(shell.id, 4, 9), 'STALE_RESOURCE_OWNER');
  error(runtime.returnTransport(shell.id, 4, 9, 1, 1, 0, { x: 0, y: 0 }), 'STALE_RESOURCE_OWNER');
  assert.equal(runtime.getObject(shell.id).state, 'carried');
  const exit = ok(runtime.close(shell.id, 'transport', 9));
  assert.equal(exit.escrow.transport, undefined);
});

test('returned and unreturned pages cannot merge their return histories', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('return-merge')));
  const [left, right, ticket] = ok(runtime.allocate(root.id, [.3, .3, .3])).objects;
  const returned = finite(runtime, left.id), fresh = finite(runtime, right.id);
  ok(runtime.startTransport(returned.id, ticket.id, 5, 1, 1));
  ok(runtime.beginTransportReturn(returned.id, 5, 2));
  ok(runtime.returnTransport(returned.id, 5, 3, 2, 1, 0, returned.position));
  const before = runtime.ledger.snapshot();
  error(runtime.merge([returned.id, fresh.id], 0, 4));
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.getObject(returned.id).transportReturned, true);
  const part = ok(runtime.allocate(returned.id, [.5])).objects[0];
  const repacked = finite(runtime, part.id);
  assert.equal(repacked.transportReturned, true, 'Repacking original portions must not renew return permission');
});

test('delivery waits for original ready time and keeps lifetime, form and program', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('transport-deliver', 100, 0, { shape: 'blade' })));
  const [source, ticket] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id, 'shell', { delayTicks: 20, lifeTicks: 40 });
  const cargo = ok(runtime.startTransport(shell.id, ticket.id, 6, 1, 1)).objects[0];
  const before = runtime.ledger.snapshot();
  error(runtime.deliverTransport(shell.id, 6, 99, 19, { x: 5, y: 5 }), 'STALE_RESOURCE_OWNER');
  error(runtime.deliverTransport(shell.id, 7, 99, 20, { x: 5, y: 5 }), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const delivered = ok(runtime.deliverTransport(shell.id, 6, 99, 20, { x: 5, y: 5 })).objects[0];
  assert.equal(delivered.kind, 'spell'); assert.equal(delivered.state, 'ready');
  assert.equal(delivered.transport, undefined); assert.equal(delivered.targetId, 99);
  assert.equal(delivered.targetPolicy, 'original'); assert.deepEqual(delivered.position, { x: 5, y: 5 });
  assert.equal(delivered.program, cargo.program); assert.equal(delivered.shape, cargo.shape);
  assert.equal(delivered.createdAtTick, cargo.createdAtTick);
  assert.equal(delivered.readyAtTick, cargo.readyAtTick); assert.equal(delivered.expiresAtTick, cargo.expiresAtTick);
  assert.equal(runtime.balance(shell.id, 'power'), 50);
});

test('carried shells cannot intercept, heat or merge', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('transport-no-guard', 100, 0,
    { primaryMaterialsQ: { heat: 10 } })));
  const [source, ticket] = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shell = finite(runtime, source.id);
  const cargo = ok(runtime.startTransport(shell.id, ticket.id, 1, 1, 1)).objects[0];
  const otherRoot = ok(runtime.acceptManual(receipt('merge-other')));
  const otherShell = finite(runtime, otherRoot.id);
  const before = runtime.ledger.snapshot();
  error(runtime.guard(cargo.id, 'projectile', 10));
  error(runtime.heat(root.id, cargo.id, 1, 1, 2, 'retain'));
  error(runtime.merge([cargo.id, otherShell.id], 0, 2));
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('transport assembly retains each original lot, pays every input once and keeps the earliest limits', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('assembly-lots', 17, 0,
    { primaryMaterialsQ: { charge: 11 }, processingUses: 8, applications: 4 })));
  const [left, right, ticket] = ok(runtime.allocate(root.id, [.3, .3, .3])).objects;
  const first = finite(runtime, left.id, 'shell', { tick: 0, delayTicks: 8, lifeTicks: 80, applications: 3 });
  const second = finite(runtime, right.id, 'shell', { tick: 5, delayTicks: 15, lifeTicks: 40, applications: 2 });
  const originalLots = [first, second].flatMap(part => runtime.ledger.getOwnedLots(part.id));
  const result = ok(runtime.startTransport(first.id, ticket.id, 7, 10, .5,
    { objectIds: [first.id, second.id], waitTicks: 7 }));
  const [cargo, closedFirst, closedSecond, closedTicket] = result.objects;
  assert.ok(cargo.id > Math.max(first.id, second.id, ticket.id));
  assert.deepEqual([cargo.state, cargo.createdAtTick, cargo.readyAtTick, cargo.expiresAtTick, cargo.remainingApplications],
    ['carried', 0, 27, 45, 2]);
  assert.equal(cargo.program, first.program);
  assert.equal(cargo.shape, first.shape);
  assert.deepEqual(cargo.properties, first.properties);
  assert.deepEqual([closedFirst, closedSecond, closedTicket].map(object => object.state), ['closed', 'closed', 'closed']);
  assert.deepEqual(runtime.ledger.getOwnedLots(cargo.id).map(lot => lot.lotId), originalLots.map(lot => lot.lotId));
  assert.equal(runtime.balance(cargo.id, 'power'), 4);
  assert.equal(runtime.balance(cargo.id, 'charge'), 2);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'native.transport.merge').length, 4);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'native.transport.take').length, 6);
  assert.equal(runtime.balance(ticket.id, 'power'), 0);
  assert.equal(runtime.ledger.getOwner(first.id).closed, true);
  assert.equal(runtime.ledger.getOwner(second.id).closed, true);
  assert.equal(runtime.ledger.getOwner(ticket.id).closed, true);
});

test('transport assembly validation and processing failures leave inputs, ticket and next ID unchanged', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('assembly-atomic', 90, 0, { processingUses: 1 })));
  const [left, right, ticket] = ok(runtime.allocate(root.id, [.3, .3, .3])).objects;
  const first = finite(runtime, left.id, 'shell', { lifeTicks: 30 });
  const second = finite(runtime, right.id, 'shell', { lifeTicks: 20 });
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  const invalid = [
    { objectIds: [first.id, first.id], waitTicks: 1 },
    { objectIds: [second.id, first.id], waitTicks: 1 },
    { objectIds: [first.id, ticket.id], waitTicks: 1 },
    { objectIds: [first.id, second.id], waitTicks: 0 },
    { objectIds: [first.id, second.id], waitTicks: 181 },
    { objectIds: [first.id, second.id], waitTicks: 1, extra: true },
    { objectIds: [first.id, , second.id], waitTicks: 1 },
  ];
  for (const assembly of invalid) error(runtime.startTransport(first.id, ticket.id, 2, 1, 1, assembly));
  error(runtime.startTransport(first.id, ticket.id, 2, 19, 1,
    { objectIds: [first.id, second.id], waitTicks: 1 }), 'STALE_RESOURCE_OWNER');
  error(runtime.startTransport(first.id, ticket.id, 2, 1, 1,
    { objectIds: [first.id, second.id], waitTicks: 1 }), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.deepEqual(runtime.active(), objects);
  assert.equal(runtime.balance(ticket.id, 'power'), 27);
  assert.equal(ok(runtime.allocate(root.id, [.5])).objects[0].id, second.id + 1);
});

test('three shell assembly claims every portion and cannot claim the same merged portions again', () => {
  const runtime = new SpellResourceRuntime(1);
  const root = ok(runtime.acceptManual(receipt('assembly-three', 120, 0, { processingUses: 12 })));
  const [a, b, c, ticket] = ok(runtime.allocate(root.id, [.2, .2, .2, .2])).objects;
  const shells = [a, b, c].map(item => finite(runtime, item.id));
  const cargo = ok(runtime.startTransport(shells[0].id, ticket.id, 4, 1, 1,
    { objectIds: shells.map(shell => shell.id), waitTicks: 1 })).objects[0];
  assert.equal(runtime.balance(cargo.id, 'power'), 72);
  assert.equal(runtime.ledger.getOwnedLots(cargo.id).length, 3);
  ok(runtime.beginTransportReturn(cargo.id, 4, 2));
  const returned = ok(runtime.returnTransport(cargo.id, 4, 3, 8, 1, 0, cargo.position)).objects[0];
  const [partA, partB] = ok(runtime.allocate(returned.id, [.25, .25])).objects;
  const repacked = [partA, partB].map(part => finite(runtime, part.id, 'shell', { tick: 3 }));
  const next = ok(runtime.acceptManual(receipt('assembly-next-ticket')));
  const nextTicket = ok(runtime.allocate(next.id, [.5])).objects[0];
  const before = runtime.ledger.snapshot();
  error(runtime.startTransport(repacked[0].id, nextTicket.id, 8, 4, 1,
    { objectIds: repacked.map(shell => shell.id), waitTicks: 1 }), 'DUPLICATE_CLAIM');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.getObject(nextTicket.id).state, 'ready');
});

function relayFixture(overrides = {}) {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('relay-source', 90, 0,
    { shape: 'chain', applications: 3, primaryMaterialsQ: { charge: 10 }, processingUses: 8 })));
  ok(runtime.dispatch(source.id, 8, 0, 100));
  ok(runtime.commitHit(source.id, 8));
  const page = ok(runtime.acceptManual(receipt('relay-page', 40, 0,
    { primaryMaterialsQ: { charge: 20 }, processingUses: 8, ...overrides })));
  const [pageSource, ticket] = ok(runtime.allocate(page.id, [.5, .5])).objects;
  const shell = finite(runtime, pageSource.id);
  const cargo = ok(runtime.startTransport(shell.id, ticket.id, 7, 1, 1)).objects[0];
  return { runtime, source, cargo, relay: { objectId: cargo.id, actorId: 7,
    position: { x: 50, y: 2 }, maxDistance: 60, chargeCostQ: 3 } };
}

function storedRelayFixture() {
  const runtime = new SpellResourceRuntime(1);
  const source = ok(runtime.acceptManual(receipt('static-source', 90, 0,
    { shape: 'chain', applications: 3, primaryMaterialsQ: { charge: 10 }, processingUses: 8 })));
  ok(runtime.dispatch(source.id, 8, 0, 100)); ok(runtime.commitHit(source.id, 8));
  const shells = [50, 100].map((x, index) => {
    const root = ok(runtime.acceptManual(receipt(`static-page-${index}`, 40, 0, { primaryMaterialsQ: { charge: 20 } })));
    return finite(runtime, root.id, 'shell', { position: { x, y: 2 }, delayTicks: 20, lifeTicks: 80 });
  });
  const relays = shells.map(shell => ({ objectId: shell.id, position: shell.position, maxDistance: 60, chargeCostQ: 3 }));
  return { runtime, source, shells, relays };
}

test('a multi-shell path pays each owner atomically without donating power, lifetime or hit counts', () => {
  const { runtime, source, shells, relays } = storedRelayFixture(), before = runtime.getObject(source.id);
  const result = ok(runtime.executePaid({ objectId: source.id, ruleId: 'path', processingUses: 1, costs: [] },
    () => runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, relays, 1)));
  assert.deepEqual(result.objects.map(object => object.id), [source.id, ...shells.map(shell => shell.id)]);
  assert.equal(runtime.balance(source.id, 'power'), 60); assert.equal(runtime.balance(source.id, 'charge'), 8);
  assert.equal(result.objects[0].remainingApplications, before.remainingApplications);
  assert.equal(result.objects[0].expiresAtTick, before.expiresAtTick);
  for (const shell of shells) {
    const current = runtime.getObject(shell.id);
    assert.equal(current.state, 'stored'); assert.equal(current.relayed, true);
    assert.equal(current.createdAtTick, shell.createdAtTick); assert.equal(current.readyAtTick, shell.readyAtTick);
    assert.equal(current.expiresAtTick, shell.expiresAtTick); assert.equal(current.remainingApplications, shell.remainingApplications);
    assert.equal(runtime.balance(shell.id, 'power'), 40); assert.equal(runtime.balance(shell.id, 'charge'), 17);
    assert.ok(runtime.ledger.getOwnedLots(shell.id).every(lot => lot.ruleClaims['native.routing.relay'] === 1 && lot.ruleClaims['rule:path'] === 1));
  }
  assert.equal(runtime.storedCount(1), 2);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'rule:path').length, 6);
});

test('passive field relay spends source charge and one original application without creating damage', () => {
  for (const applications of [1, 4]) {
    const { runtime, source, shells, relays } = storedRelayFixture();
    const field = finite(runtime, shells[1].id, 'field', { applications, position: { x: 100, y: 2 },
      field: circleField, delayTicks: 0 });
    const relay = { objectId: field.id, position: field.position, maxDistance: 60, chargeCostQ: 2, sourceCharge: true };
    const before = runtime.getObject(source.id);
    const result = ok(runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, [relays[0], relay], 1));
    assert.equal(runtime.balance(source.id, 'charge'), 6);
    assert.equal(runtime.balance(source.id, 'power'), 60);
    assert.equal(runtime.balance(shells[0].id, 'charge'), 17);
    assert.equal(runtime.balance(field.id, 'power'), 40 - Math.ceil(40 / applications));
    assert.equal(runtime.balance(field.id, 'charge'), 20 - Math.ceil(20 / applications));
    const after = runtime.getObject(field.id);
    assert.equal(after.remainingApplications, applications - 1); assert.equal(after.relayed, true);
    assert.equal(after.field.intervalTicks, field.field.intervalTicks); assert.equal(after.expiresAtTick, field.expiresAtTick);
    assert.equal(after.state, applications === 1 ? 'closed' : 'stored');
    assert.equal(result.objects[0].remainingApplications, before.remainingApplications);
    assert.ok(!result.transaction.facts.some(fact => fact.kind === 'spend' && fact.reason === 'attack'));
    const snapshot = runtime.ledger.snapshot(); error(runtime.transferVia(source.id, 10, { x: 155, y: 2 }, 60, 2, relay, 2));
    assert.deepEqual(runtime.ledger.snapshot(), snapshot);
  }
});

test('unfunded field hop or a forged payer never spends earlier path resources or field opportunities', () => {
  const { runtime, source, shells, relays } = storedRelayFixture();
  const field = finite(runtime, shells[1].id, 'field', { applications: 4, position: { x: 100, y: 2 }, field: circleField });
  const relay = { objectId: field.id, position: field.position, maxDistance: 60, chargeCostQ: 6, sourceCharge: true };
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  error(runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 6, [relays[0], relay], 1), 'INSUFFICIENT_RESOURCE');
  for (const malformed of [{ ...relay, chargeCostQ: 1 }, { ...relay, actorId: 1 },
    { ...relay, sourceCharge: false }, { ...relays[0], sourceCharge: true, chargeCostQ: 6 }])
    error(runtime.transferVia(source.id, 9, { x: 120, y: 2 }, 120, 6, malformed, 1));
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
});

test('a source-charge budget retains affordable detours through a shared relay', () => {
  const point = (id, x, y, range, sourceCharge = false) => ({ objectId: id, position: { x, y }, maxDistance: range,
    chargeCostQ: 1, ...(sourceCharge ? { sourceCharge: true } : {}) });
  const nodes = [point(1, 30, 0, 70, true), point(2, 30, 40, 100), point(3, 90, 0, 70), point(4, 150, 0, 70, true)];
  const budgeted = findRelayPaths({ x: 0, y: 0 }, 55, nodes, 3, 1).filter(path => path.relays.at(-1).objectId === 4);
  assert.deepEqual(budgeted.map(path => path.relays.map(relay => relay.objectId)), [[2, 3, 4]]);
  const funded = findRelayPaths({ x: 0, y: 0 }, 55, nodes, 3, 2).filter(path => path.relays.at(-1).objectId === 4);
  assert.deepEqual(funded[0].relays.map(relay => relay.objectId), [1, 3, 4]);
  assert.ok(!findRelayPaths({ x: 0, y: 0 }, 55, nodes, 3, 0).some(path => path.relays.at(-1).objectId === 4));
});

function jointGuardFixture() {
  const runtime = new SpellResourceRuntime(1), root = ok(runtime.acceptManual(receipt('joint-guard')));
  const parts = ok(runtime.allocate(root.id, [.3, .3, .3])).objects;
  const shells = parts.map(part => finite(runtime, part.id, 'shell', { delayTicks: 20, lifeTicks: 60 }));
  return { runtime, root, shells };
}

test('joint guard claims one projectile and pays only actual contributors while retaining their remainders', () => {
  const { runtime, shells } = jointGuardFixture();
  const result = ok(runtime.guardTogether(shells.map(shell => shell.id), 'guard:1', 35, .75, 1));
  assert.equal(result.blockedPowerQ, 35); assert.deepEqual(result.objects.map(object => object.id), shells.slice(0, 2).map(shell => shell.id));
  assert.deepEqual(shells.map(shell => runtime.balance(shell.id, 'power')), [8, 17, 30]);
  assert.ok(shells.every(shell => runtime.getObject(shell.id) === shell));
  for (const shell of shells.slice(0, 2)) assert.ok(runtime.ledger.getOwnedLots(shell.id).every(lot => lot.ruleClaims['native.guard.group'] === 1));
  assert.ok(runtime.ledger.getOwnedLots(shells[2].id).every(lot => !lot.ruleClaims['native.guard.group']));
  const before = runtime.ledger.snapshot(); error(runtime.guard(shells[2].id, 'guard:1', 1), 'DUPLICATE_CLAIM');
  error(runtime.guardTogether(shells.map(shell => shell.id), 'guard:1', 5, .75, 1), 'DUPLICATE_CLAIM');
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('joint guard rejects incompatible or unpaid participants atomically without taking the projectile claim', () => {
  const { runtime, root, shells } = jointGuardFixture();
  const other = finite(runtime, root.id, 'shell', { position: { x: 99, y: 2 }, lifeTicks: 60 });
  const before = runtime.ledger.snapshot();
  for (const ids of [[shells[0].id, shells[0].id], [shells[0].id, other.id], [shells[0].id, , shells[1].id]])
    error(runtime.guardTogether(ids, 'joint-invalid', 35, .75, 1));
  error(runtime.guardTogether(shells.map(shell => shell.id), 'joint-invalid', 35, .75, 60), 'STALE_RESOURCE_OWNER');
  error(runtime.executePaid({ objectId: shells[0].id, ruleId: 'joint-cost', processingUses: 32, costs: [] },
    () => runtime.guardTogether(shells.slice(0, 2).map(shell => shell.id), 'joint-invalid', 35, .75, 1)), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(ok(runtime.guard(shells[0].id, 'joint-invalid', 1)).blockedPowerQ, 1);
});

test('invalid or unpaid later relay leaves every earlier owner and object untouched', () => {
  const { runtime, source, shells, relays } = storedRelayFixture();
  const before = runtime.ledger.snapshot(), objects = runtime.active();
  for (const path of [[], [relays[0], relays[0]], [relays[0], , relays[1]],
    [relays[0], { ...relays[1], chargeCostQ: 21 }],
    [relays[0], { ...relays[1], maxDistance: 49 }],
    [relays[0], { ...relays[1], position: { x: 101, y: 2 } }],
    [relays[0], { ...relays[1], actorId: 7 }],
    [relays[0], { ...relays[1], extra: true }]]) {
    error(runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, path, 1));
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
  }
  error(runtime.executePaid({ objectId: source.id, ruleId: 'unpayable-path', processingUses: 32, costs: [] },
    () => runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, relays, 1)), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(runtime.active(), objects);
  error(runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, relays, 80), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.ok(shells.every(shell => !runtime.getObject(shell.id).relayed));
});

test('static relay history prevents a second relay after physical transport and ownership changes', () => {
  const { runtime, source, shells, relays } = storedRelayFixture();
  ok(runtime.transferAlong(source.id, 9, { x: 150, y: 2 }, 60, 2, relays, 1));
  const part = ok(runtime.allocate(shells[0].id, [.5])).objects[0];
  const repacked = finite(runtime, part.id, 'shell', { tick: 1 });
  const root = ok(runtime.acceptManual(receipt('static-ticket')));
  const ticket = ok(runtime.allocate(root.id, [.5])).objects[0];
  ok(runtime.startTransport(repacked.id, ticket.id, 4, 2, 1));
  const before = runtime.ledger.snapshot();
  error(runtime.transferVia(source.id, 10, { x: 200, y: 2 }, 60, 2,
    { objectId: repacked.id, actorId: 4, position: { x: 175, y: 2 }, maxDistance: 60, chargeCostQ: 2 }, 3), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.ok(runtime.ledger.getOwnedLots(repacked.id).every(lot => lot.ruleClaims['native.routing.relay'] === 1));
});

test('relay search skips dead ends, respects per-node ranges, and is deterministic without cyclic detours', () => {
  const point = (id, x, y, range) => ({ objectId: id, position: { x, y }, maxDistance: range, chargeCostQ: 1 });
  const candidates = [point(9, 10, 0, 5), point(3, 45, 10, 60), point(2, 45, -10, 60), point(4, 95, 0, 60), point(5, 145, 0, 60)];
  const describe = relays => findRelayPaths({ x: 0, y: 0 }, 50, relays, 4)
    .map(path => [path.relays.at(-1).objectId, path.relays.map(relay => relay.objectId)]);
  assert.deepEqual(describe(candidates), describe([...candidates].reverse()));
  assert.deepEqual(describe(candidates).find(([id]) => id === 5)[1], [2, 4, 5]);
  assert.ok(!findRelayPaths({ x: 0, y: 0 }, 50, candidates, 2).some(path => path.relays.at(-1).objectId === 5));
  assert.ok(findRelayPaths({ x: 0, y: 0 }, 50, candidates, 4).every(path => new Set(path.relays.map(relay => relay.objectId)).size === path.relays.length));
  const direct = point(6, 40, 0, 200);
  assert.deepEqual(findRelayPaths({ x: 0, y: 0 }, 50, [...candidates, direct], 4)
    .find(path => path.relays.at(-1).objectId === 5).relays.map(relay => relay.objectId), [6, 5]);
});

test('relay validates both legs and atomically spends charge and processing from both owners', () => {
  const { runtime, source, cargo, relay } = relayFixture();
  const before = runtime.ledger.snapshot(), sourceBefore = runtime.getObject(source.id), cargoBefore = runtime.getObject(cargo.id);
  error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 48, 2, relay, 2));
  error(runtime.transferVia(source.id, 9, { x: 111, y: 2 }, 60, 2, relay, 2));
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.getObject(source.id), sourceBefore);
  assert.equal(runtime.getObject(cargo.id), cargoBefore);
  const result = ok(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 2, relay, 2));
  assert.deepEqual(result.objects.map(object => object.id), [source.id, cargo.id]);
  assert.equal(runtime.balance(source.id, 'charge'), 8);
  assert.equal(runtime.balance(cargo.id, 'charge'), 7);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'native.routing.relay').length, 2);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'transfer' && fact.ownerId === source.id).length, 2);
  assert.deepEqual(result.objects[0].position, { x: 100, y: 2 });
  assert.deepEqual(result.objects[1].position, relay.position);
  assert.equal(result.objects[0].targetId, 9);
  assert.equal(result.objects[0].targetPolicy, 'nextUnhit');
  assert.equal(result.objects[1].relayed, true);
  assert.equal(runtime.balance(source.id, 'power'), 60);
  assert.equal(runtime.balance(cargo.id, 'power'), 20);
  assert.equal(result.objects[0].remainingApplications, sourceBefore.remainingApplications);
  assert.equal(result.objects[0].expiresAtTick, sourceBefore.expiresAtTick);
  assert.equal(result.objects[1].expiresAtTick, cargoBefore.expiresAtTick);
  const after = runtime.ledger.snapshot();
  error(runtime.transferVia(source.id, 10, { x: 101, y: 2 }, 60, 1, relay, 3), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.snapshot(), after);
});

test('relay rejects missing charge, exhausted processing, return, closed shell and wrong actor atomically', () => {
  for (const [sourceCost, relayCost] of [[11, 1], [1, 11]]) {
    const { runtime, source, relay } = relayFixture();
    const before = runtime.ledger.snapshot(), objects = runtime.active();
    error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, sourceCost,
      { ...relay, chargeCostQ: relayCost }, 2), 'INSUFFICIENT_RESOURCE');
    assert.deepEqual(runtime.ledger.snapshot(), before);
    assert.deepEqual(runtime.active(), objects);
  }
  const poor = relayFixture({ processingUses: 1 });
  const poorBefore = poor.runtime.ledger.snapshot();
  error(poor.runtime.transferVia(poor.source.id, 9, { x: 100, y: 2 }, 60, 1, poor.relay, 2), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(poor.runtime.ledger.snapshot(), poorBefore);
  const { runtime, source, cargo, relay } = relayFixture();
  const before = runtime.ledger.snapshot();
  error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 1, { ...relay, actorId: 8 }, 2), 'STALE_RESOURCE_OWNER');
  error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 1, { ...relay, extra: 1 }, 2), 'INVALID_QUANTITY');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  ok(runtime.beginTransportReturn(cargo.id, 7, 2));
  error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 1, relay, 3), 'STALE_RESOURCE_OWNER');
  ok(runtime.discard(cargo.id));
  error(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 1, relay, 3), 'STALE_RESOURCE_OWNER');
});

test('paid relay includes both owners and fees in the same transaction', () => {
  const failed = relayFixture();
  const before = failed.runtime.ledger.snapshot();
  error(failed.runtime.executePaid({ objectId: failed.source.id, ruleId: 'relay-paid', processingUses: 7,
    costs: [{ ownerId: failed.source.id, resource: 'charge', quantityQ: 1 }] },
  () => failed.runtime.transferVia(failed.source.id, 9, { x: 100, y: 2 }, 60, 2, failed.relay, 2)),
  'INSUFFICIENT_RESOURCE');
  assert.deepEqual(failed.runtime.ledger.snapshot(), before);
  const { runtime, source, cargo, relay } = relayFixture();
  const result = ok(runtime.executePaid({ objectId: source.id, ruleId: 'relay-paid', processingUses: 1,
    costs: [{ ownerId: source.id, resource: 'charge', quantityQ: 1 }] },
  () => runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 2, relay, 2)));
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'claim' && fact.reason === 'rule:relay-paid').length, 4);
  assert.equal(runtime.balance(source.id, 'charge'), 7);
  assert.equal(runtime.balance(cargo.id, 'charge'), 7);
});

test('relay history survives returning and repacking, and mixed relay histories cannot merge', () => {
  const { runtime, source, cargo, relay } = relayFixture();
  ok(runtime.transferVia(source.id, 9, { x: 100, y: 2 }, 60, 2, relay, 2));
  ok(runtime.beginTransportReturn(cargo.id, 7, 3));
  const returned = ok(runtime.returnTransport(cargo.id, 7, 4, 8, 1, 0, cargo.position)).objects[0];
  assert.equal(returned.relayed, true);
  const part = ok(runtime.allocate(returned.id, [.5])).objects[0];
  const repacked = finite(runtime, part.id, 'shell', { tick: 4 });
  assert.equal(repacked.relayed, true);
  assert.equal(mergeCompatible(repacked, { ...repacked, relayed: undefined }), false);
  const freshRoot = ok(runtime.acceptManual(receipt('relay-fresh')));
  const ticket = ok(runtime.allocate(freshRoot.id, [.5])).objects[0];
  const carriedAgain = ok(runtime.startTransport(repacked.id, ticket.id, 8, 5, 1)).objects[0];
  assert.equal(carriedAgain.relayed, true);
  const before = runtime.ledger.snapshot();
  error(runtime.transferVia(source.id, 10, { x: 105, y: 2 }, 60, 1,
    { ...relay, objectId: carriedAgain.id, actorId: 8 }, 5), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(runtime.ledger.snapshot(), before);
});
