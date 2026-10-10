const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createRuleCompiler } = require('../src/shared/build/compile.ts');
const { evaluateCondition } = require('../src/shared/build/conditions.ts');
const { SpellResourceRuntime } = require('../src/simulation/spells/SpellResourceRuntime.ts');
const { SpellRuleExecutor } = require('../src/simulation/spells/SpellRuleExecutor.ts');
const { SpellLifecycle } = require('../src/simulation/spells/SpellLifecycle.ts');

const ok = result => { assert.equal(result.ok, true, JSON.stringify(result.errors)); return result.value; };
const q = (value, unit) => ({ value, unit });
const base = { rules: [], capabilities: [], modifiers: [], modes: [] };
function program(rules = [], numerics = {}) {
  const registry = { version: 1, rules: Object.fromEntries(rules.map(rule => [rule.id, rule])), numerics, talents: {}, relics: {}, modeSlots: {},
    books: Object.fromEntries(['frost', 'flame', 'storm', 'spirit'].map(book => [book, { ...base, rules: rules.map(rule => rule.id) }])) };
  return ok(ok(createRuleCompiler(registry)).compile({ version: 1, revision: 1, mainBook: 'frost', allocated: [], selectedModes: {}, assets: [], overrides: [] }));
}
function rule(id, operation, overrides = {}) {
  return { id, operation, stage: 'assemble', event: 'spell.assemble', targetKind: 'spell', when: { all: [] }, resourceCost: [],
    inherit: 'paidProcessing', repeat: { unit: 'lot', limit: 1 }, ...overrides };
}
function primary(runtime, build, overrides = {}) {
  return ok(runtime.acceptManual({ id: 'word', wordLength: 4, humanPositions: [0,1,2,3], primaryPowerQ: 100, auxiliaryWorkQ: 10,
    program: build, shape: 'shot', position: { x: 0, y: 0 }, targetId: 1, tick: 0, lifeTicks: 100, applications: 1, processingUses: 8, ...overrides }));
}
const world = { flightLifeTicks: 60, selectTarget: () => ({ id: 2, x: 2, y: 0 }),
  supply: () => { throw new Error('This scenario has no native income adapter'); }, mark: () => { throw new Error('This scenario has no letter adapter'); } };
const event = (subject, id = 'event', overrides = {}) => ({ id, subject, event: 'spell.assemble', stage: 'assemble', tick: 0, counters: {}, ...overrides });
const copy = maxCopies => ({ op: 'Copy', templateSelector: 'manualSpell', workCost: q(2, 'work'),
  fundedPowerFactor: q(.5, 'ratio'), inheritMask: ['shape'], maxCopies: q(maxCopies, 'count') });

function ongoingBattle(actions, lethal = false) {
  const rules = actions.map(action => rule(action, action === 'advance'
    ? { op: 'Ongoing', action, applications: q(2, 'count') }
    : { op: 'Ongoing', action, coldCost: q(12, 'cold'), extraTicks: q(20, 'ticks'), maxDelayTicks: q(20, 'ticks') },
  { stage: 'prepareHit', event: 'status.contact', targetKind: 'status', repeat: { unit: 'object', limit: 1 },
    ...(action === 'delay' && actions.includes('advance') ? { after: ['advance'] } : {}) }));
  const runtime = new SpellResourceRuntime(1), build = program(rules), old = primary(runtime, build);
  const status = ok(runtime.createFinite({ kind: 'status', fromObjectId: old.id, share: 1, targetId: 2,
    tick: 0, delayTicks: 0, lifeTicks: 40, applications: 4 }, 4)).objects[0];
  ok(runtime.discard(old.id));
  const damage = []; let alive = true, sequence = 0;
  const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60,
    isAlive: () => alive, target: world.selectTarget, launch: () => {}, boundary: () => {},
    damage: commit => { damage.push(commit); if (lethal && commit.object.kind === 'status') alive = false; } });
  const incoming = (tick, cold = 0, currentBuild = build) => {
    const root = primary(runtime, currentBuild, { id: `contact:${++sequence}`, tick, targetId: 2,
      primaryMaterialsQ: { cold }, primaryPowerQ: 40 });
    lifecycle.start(root.id, tick); return root;
  };
  return { runtime, status, build, lifecycle, incoming, damage };
}

test('a paid letter match dispatches one assembly hook before normal assembly and cannot fabricate another income', () => {
  const save = rule('letter-save', { op: 'Store', shellArchetype: 'paper', share: q(.25, 'ratio'),
    capacityUnits: q(6, 'count'), releaseDelayTicks: q(10, 'ticks'), lifeTicks: q(30, 'ticks'), onNoCapacity: 'retain' },
  { event: 'letter.match', when: { counter: 'matchedCharacters', comparison: 'gte', value: 1 } });
  for (const matchedCharacters of [0, 2]) {
    const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([save]));
    const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
      target: world.selectTarget, damage: () => {}, launch: () => {}, boundary: () => {} });
    lifecycle.start(root.id, 0, {}, matchedCharacters); lifecycle.start(root.id, 0, {}, matchedCharacters);
    assert.equal(runtime.active('shell').length, matchedCharacters ? 1 : 0);
    assert.equal(runtime.balance(root.id, 'power'), matchedCharacters ? 75 : 100);
    assert.equal(runtime.manualCount, 1); assert.deepEqual(lifecycle.diagnostics, []);
  }
});

test('a manual contact advances existing applications once and preserves the next natural beat', () => {
  const { runtime, status, lifecycle, incoming, damage } = ongoingBattle(['advance']);
  const first = incoming(1); lifecycle.hit(first.id, 2, 1);
  assert.deepEqual(damage.map(commit => [commit.object.kind, commit.powerQ]), [['status', 50], ['spell', 40]]);
  assert.equal(runtime.getObject(status.id).remainingApplications, 2);
  assert.equal(runtime.getObject(status.id).status.nextAtTick, 10);
  const second = incoming(2); lifecycle.hit(second.id, 2, 2);
  assert.equal(runtime.balance(status.id, 'power'), 50);
  lifecycle.advance(10); assert.equal(runtime.balance(status.id, 'power'), 25);
  lifecycle.advance(20); assert.equal(runtime.getObject(status.id).state, 'closed');
  lifecycle.advance(100);
  assert.equal(damage.filter(commit => commit.object.kind === 'status').reduce((n, commit) => n + commit.powerQ, 0), 100);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('ongoing contact settles due damage first; derived hits and newly acquired rules cannot alter old effects', () => {
  const battle = ongoingBattle(['advance']);
  const root = battle.incoming(1);
  const child = ok(battle.runtime.allocate(root.id, [.5])).objects[0];
  ok(battle.runtime.dispatch(child.id, 2, 1, 60));
  battle.lifecycle.hit(child.id, 2, 1);
  assert.equal(battle.runtime.balance(battle.status.id, 'power'), 100);
  battle.lifecycle.hit(root.id, 2, 30);
  assert.deepEqual(battle.damage.filter(commit => commit.object.kind === 'status').map(commit => commit.powerQ), [25, 25, 25, 25]);
  assert.equal(battle.runtime.getObject(battle.status.id).state, 'closed');
  assert.deepEqual(battle.lifecycle.diagnostics, []);
  const old = ongoingBattle([]), next = old.incoming(1, 20, battle.build);
  old.lifecycle.hit(next.id, 2, 1);
  assert.equal(old.runtime.balance(old.status.id, 'power'), 100);
  assert.deepEqual(old.runtime.getObject(old.status.id).status, { intervalTicks: 10, nextAtTick: 10, delayedTicks: 0 });
  assert.deepEqual(old.lifecycle.diagnostics, []);
});

test('delaying ongoing damage pays the incoming cold once; a failed attempt preserves the later opportunity', () => {
  const { runtime, status, lifecycle, incoming, damage } = ongoingBattle(['delay']);
  const dry = incoming(1, 11); lifecycle.hit(dry.id, 2, 1);
  assert.equal(runtime.getObject(status.id), status);
  assert.equal(damage[0].materials.cold, 11);
  const paid = incoming(2, 20); lifecycle.hit(paid.id, 2, 2);
  assert.equal(damage[1].materials.cold, 8);
  assert.equal(runtime.getObject(status.id).expiresAtTick, 60);
  assert.equal(runtime.getObject(status.id).remainingApplications, 4);
  assert.deepEqual(runtime.getObject(status.id).status, { intervalTicks: 10, nextAtTick: 30, delayedTicks: 20 });
  const again = incoming(3, 20); lifecycle.hit(again.id, 2, 3);
  assert.equal(damage[2].materials.cold, 20);
  lifecycle.advance(29); assert.equal(runtime.balance(status.id, 'power'), 100);
  lifecycle.advance(60); assert.equal(runtime.getObject(status.id).state, 'closed');
  assert.equal(damage.filter(commit => commit.object.kind === 'status').reduce((n, commit) => n + commit.powerQ, 0), 100);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('advance and delay share one finite effect; a lethal advance does not spend the incoming primary hit', () => {
  for (const lethal of [false, true]) {
    const { runtime, status, lifecycle, incoming, damage } = ongoingBattle(['advance', 'delay'], lethal);
    const root = incoming(1, 20); lifecycle.hit(root.id, 2, 1);
    assert.equal(damage[0].powerQ, 50);
    if (lethal) {
      assert.equal(damage.length, 1); assert.equal(runtime.getObject(root.id).state, 'closed');
      assert.equal(runtime.getObject(status.id).state, 'closed');
      assert.equal(runtime.active().length, 0);
    } else {
      assert.equal(damage[1].materials.cold, 8);
      assert.equal(runtime.getObject(status.id).status.nextAtTick, 30);
      lifecycle.advance(60);
      assert.equal(damage.filter(commit => commit.object.kind === 'status').reduce((n, commit) => n + commit.powerQ, 0), 100);
    }
    assert.deepEqual(lifecycle.diagnostics, []);
  }
});

test('impact fields use the actual contact and only spend on funded application beats', () => {
  const definition = rule('field-impact', { op: 'Field', shape: 'trail', radius: q(12, 'distance'), lifeTicks: q(40, 'ticks'),
    maxApplications: q(4, 'count'), share: q(.4, 'ratio'), lotAllocation: 'onContact', onFinish: 'lose' },
  { stage: 'prepareHit', event: 'hit.prepare', repeat: { unit: 'object', limit: 1 } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([definition]));
  let present = false; const damage = [];
  const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
    target: world.selectTarget, launch: () => {}, boundary: () => {}, damage: commit => damage.push(commit),
    fieldTargets: () => present ? [{ id: 1, x: 80, y: 12 }, { id: 2, x: 85, y: 12 }] : [] });
  lifecycle.start(root.id, 0); lifecycle.hit(root.id, 1, 1, {}, { x: 80, y: 12 });
  const field = runtime.active('field')[0];
  assert.deepEqual(field.position, { x: 80, y: 12 }); assert.deepEqual(field.field.from, { x: 0, y: 0 });
  assert.equal(runtime.balance(field.id, 'power'), 40);
  lifecycle.advance(11); assert.equal(runtime.getObject(field.id).remainingApplications, 4);
  present = true; lifecycle.advance(21);
  assert.deepEqual(damage.filter(commit => commit.object.kind === 'field').map(commit => commit.powerQ), [5, 5]);
  assert.equal(runtime.balance(field.id, 'power'), 30);
  lifecycle.advance(21); assert.equal(runtime.balance(field.id, 'power'), 30);
  present = false; lifecycle.advance(41);
  assert.equal(runtime.getObject(field.id).state, 'closed'); assert.equal(runtime.balance(1, 'power'), 0);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('using a field before its first pulse preserves the original cadence and never refunds the spent share', () => {
  const runtime = new SpellResourceRuntime(1), build = program(), root = primary(runtime, build);
  const field = ok(runtime.createFinite({ kind: 'field', fromObjectId: root.id, share: 1, position: { x: 40, y: 0 },
    tick: 0, delayTicks: 0, lifeTicks: 40, applications: 4,
    field: { shape: 'circle', radius: 20, allocation: 'onContact', onFinish: 'recover' } }, 4)).objects[0];
  const source = primary(runtime, build, { id: 'field-relay', shape: 'chain', applications: 2, primaryMaterialsQ: { charge: 10 } });
  ok(runtime.dispatch(source.id, 1, 0, 60)); ok(runtime.commitHit(source.id, 1));
  ok(runtime.transferVia(source.id, 2, { x: 80, y: 0 }, 50, 2,
    { objectId: field.id, position: field.position, maxDistance: 50, chargeCostQ: 2, sourceCharge: true }, 1));
  const damage = [], lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60,
    isAlive: () => true, target: world.selectTarget, launch: () => {}, boundary: () => {}, damage: commit => damage.push(commit),
    fieldTargets: () => [{ id: 1, x: 40, y: 0 }] });
  assert.equal(runtime.getObject(field.id).remainingApplications, 3); assert.equal(runtime.balance(field.id, 'power'), 75);
  lifecycle.advance(9); assert.equal(damage.length, 0);
  lifecycle.advance(10); assert.deepEqual(damage.map(commit => commit.powerQ), [25]);
  lifecycle.advance(30); assert.deepEqual(damage.map(commit => commit.powerQ), [25, 25, 25]);
  assert.equal(runtime.getObject(field.id).state, 'closed'); assert.equal(runtime.balance(1, 'power'), 0);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('recoverable fields return only unused shares at expiry or room end and require their frozen rule', () => {
  for (const room of [false, true]) for (const recoverable of [false, true]) {
    const recovery = rule('field-recovery', { op: 'Recover', remainingSelector: 'unspent', retention: q(.5, 'ratio'),
      capacityKey: 'capacity', reuseAfter: 'nextManual' }, { stage: 'finish', event: room ? 'room.finish' : 'field.finish',
      targetKind: 'field', repeat: { unit: 'object', limit: 1 } });
    const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([recovery], {
      capacity: { id: 'capacity', unit: 'power', base: 100, min: 1, max: 100, integer: true, stage: 'finish', multiplierPools: [] },
    }));
    const field = ok(runtime.createFinite({ kind: 'field', fromObjectId: root.id, share: 1, tick: 0, delayTicks: 0,
      lifeTicks: 40, applications: 4, field: { shape: 'circle', radius: 20, allocation: 'onContact', onFinish: recoverable ? 'recover' : 'lose' } }, 4)).objects[0];
    let present = true; const commits = [];
    const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
      target: world.selectTarget, launch: () => {}, boundary: () => {}, damage: commit => commits.push(commit),
      fieldTargets: () => present ? [{ id: 1, x: 0, y: 0 }] : [] });
    lifecycle.advance(10); present = false;
    if (room) lifecycle.clearRoom(11); else lifecycle.advance(40);
    assert.equal(commits.reduce((sum, commit) => sum + commit.powerQ, 0), 25);
    assert.equal(runtime.balance(1, 'power'), recoverable ? 37 : 0);
    assert.equal(runtime.getObject(field.id).state, 'closed');
    const before = runtime.ledger.snapshot(); if (room) lifecycle.clearRoom(41); else lifecycle.advance(41);
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(lifecycle.diagnostics, []);
  }
});

test('stored copies reserve real slots with each payment; full storage leaves work for the next word', () => {
  const stored = { ...copy(3), inheritMask: [], storage: { shellArchetype: 'paper', capacityUnits: q(2, 'count'),
    releaseDelayTicks: q(10, 'ticks'), lifeTicks: q(30, 'ticks') } };
  const build = program([rule('copies', stored, { inherit: 'never', repeat: { unit: 'receipt', limit: 3 },
    resourceCost: [{ resource: 'work', amount: q(1, 'work') }] })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build, { applications: 4 }), executor = new SpellRuleExecutor(runtime, world);
  const result = executor.execute(event(root));
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.outcomes.map(outcome => outcome.status), ['applied', 'applied', 'skipped']);
  assert.equal(result.outcomes[2].reason, 'capacity');
  const shells = runtime.active('shell'); assert.equal(shells.length, 2);
  assert.ok(shells.every(shell => shell.readyAtTick === 10 && shell.expiresAtTick === 30 && shell.remainingApplications === 1));
  assert.equal(runtime.balance(0, 'work'), 4);
  const before = runtime.ledger.snapshot();
  assert.equal(executor.execute(event(root)), result); assert.deepEqual(runtime.ledger.snapshot(), before);
  const next = primary(runtime, build, { id: 'next', auxiliaryWorkQ: 0 });
  assert.equal(next.id, shells[1].id + 1); // The failed third copy did not reserve an ID.
});

test('a delayed merge is delivered at its deadline, without reassembling expired siblings', () => {
  const split = rule('split', { op: 'Allocate', sourceLot: 'self', shares: [.5, .5], maxChildren: 2, remainderPolicy: 'parent' }, { inherit: 'never' });
  const merge = rule('merge', { op: 'Merge', compatibilityKey: 'shapeAndTarget', sameRoot: true, maxInputs: q(3, 'count'),
    waitTicks: q(5, 'ticks'), outputPolicy: 'preserveShape' }, { after: ['split'] });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([split, merge])), launches = [];
  const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
    target: world.selectTarget, damage: () => {}, launch: object => launches.push(object.id), boundary: () => {} });
  lifecycle.start(root.id, 0, { humanCharacters: 4, wordLength: 4 });
  assert.deepEqual(launches, []);
  const merged = runtime.active('spell')[0]; assert.equal(merged.readyAtTick, 5);
  lifecycle.advance(4); assert.deepEqual(launches, []);
  lifecycle.advance(5); assert.deepEqual(launches, [merged.id]); assert.equal(runtime.balance(merged.id, 'power'), 100);
  lifecycle.advance(6); assert.deepEqual(launches, [merged.id]); assert.deepEqual(lifecycle.diagnostics, []);
  lifecycle.clearRoom(7); assert.equal(runtime.active().length, 0);
});

test('stored assembly skips incompatible or spent groups and leaves short-lived pages unchanged', () => {
  const merge = rule('merge-pages', { op: 'Merge', compatibilityKey: 'shapeAndTarget', sameRoot: true, maxInputs: q(2, 'count'),
    waitTicks: q(5, 'ticks'), outputPolicy: 'preserveShape' }, { event: 'shell.assemble', targetKind: 'shell' });
  for (const short of [false, true]) {
    const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([merge]));
    const parts = ok(runtime.allocate(root.id, [.2, .2, .2, .2])).objects;
    const shells = parts.map((part, index) => ok(runtime.createFinite({ kind: 'shell', fromObjectId: part.id, share: 1,
      tick: 0, delayTicks: 10, lifeTicks: short ? 12 : 60, applications: 1,
      properties: { material: index === 0 ? 'crystal' : 'paper' } }, 8)).objects[0]);
    const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
      target: world.selectTarget, damage: () => {}, launch: () => {}, boundary: () => {} });
    lifecycle.advance(1);
    if (short) assert.deepEqual(runtime.active('shell'), shells);
    else {
      assert.equal(runtime.active('shell').length, 3);
      const merged = runtime.active('shell').find(shell => !shells.includes(shell));
      assert.ok(merged); assert.equal(runtime.balance(merged.id, 'power'), 40);
      assert.equal(merged.readyAtTick, 15); assert.equal(merged.expiresAtTick, 60);
      assert.equal(runtime.getObject(shells[3].id).state, 'stored');
      assert.ok(runtime.ledger.getOwnedLots(merged.id).every(lot => lot.ruleClaims['rule:merge-pages'] === 1));
    }
    const snapshot = runtime.ledger.snapshot(), settled = runtime.active('shell');
    lifecycle.advance(2); lifecycle.advance(3);
    assert.deepEqual(runtime.ledger.snapshot(), snapshot); assert.deepEqual(runtime.active('shell'), settled);
    assert.deepEqual(lifecycle.diagnostics, []);
  }
});

test('one assembly event makes three paid copies, then receipt claims block replay and new events', () => {
  const build = program([rule('copy-three', copy(3), { repeat: { unit: 'receipt', limit: 3 } })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), executor = new SpellRuleExecutor(runtime, world);
  const first = executor.execute(event(root));
  const applied = first.outcomes.filter(outcome => outcome.status === 'applied');
  assert.deepEqual(first.errors, []); assert.equal(applied.length, 3);
  assert.deepEqual(applied.map(outcome => outcome.ruleId), ['copy-three', 'copy-three', 'copy-three']);
  assert.deepEqual(applied.map(outcome => outcome.result.objects[0].id), [root.id + 1, root.id + 2, root.id + 3]);
  assert.deepEqual(applied.map(outcome => runtime.balance(outcome.result.objects[0].id, 'power')), [50, 50, 50]);
  assert.equal(runtime.balance(0, 'work'), 4);
  const before = runtime.ledger.snapshot();
  assert.equal(executor.execute(event(root)), first);
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(executor.execute(event(root, 'new-event')).outcomes[0].reason, 'limit');
  assert.equal(executor.execute(event(applied[0].result.objects[0], 'child')).outcomes[0].reason, 'limit');
  assert.equal(runtime.balance(0, 'work'), 4);
});

test('copy stops after the affordable portions, preserves the failed portion, and keeps later rules running', () => {
  const split = rule('after-copy', { op: 'Allocate', sourceLot: 'self', shares: [.5], maxChildren: 1, remainderPolicy: 'parent' },
    { after: ['copy-lots'] });
  const build = program([rule('copy-lots', copy(3), { repeat: { unit: 'lot', limit: 3 },
    resourceCost: [{ resource: 'work', amount: q(2, 'work') }] }), split]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), executor = new SpellRuleExecutor(runtime, world);
  const first = executor.execute(event(root));
  assert.deepEqual(first.errors, []);
  assert.deepEqual(first.outcomes.map(outcome => [outcome.ruleId, outcome.status]),
    [['copy-lots', 'applied'], ['copy-lots', 'applied'], ['copy-lots', 'skipped'], ['after-copy', 'applied']]);
  assert.equal(first.outcomes[2].reason, 'resources');
  assert.equal(runtime.balance(0, 'work'), 2);
  assert.deepEqual(first.outcomes.slice(0, 2).map(outcome => outcome.result.objects[0].id), [root.id + 1, root.id + 2]);
  assert.equal(first.outcomes[3].result.objects[0].id, root.id + 3);
  assert.equal(executor.execute(event(root, 'next-event')).outcomes[0].reason, 'resources');
  assert.equal(runtime.balance(0, 'work'), 2);
});

test('per-lot copy claims and processing allowance bound later events', () => {
  const build = program([rule('copy-limited', copy(3), { repeat: { unit: 'lot', limit: 3 } })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build, { auxiliaryWorkQ: 12, processingUses: 2 });
  const executor = new SpellRuleExecutor(runtime, world), first = executor.execute(event(root));
  assert.deepEqual(first.errors, []);
  assert.deepEqual(first.outcomes.map(outcome => outcome.status), ['applied', 'applied', 'skipped']);
  assert.equal(first.outcomes[2].reason, 'resources');
  assert.equal(runtime.balance(0, 'work'), 8);
  const lot = runtime.ledger.getOwnedLots(root.id)[0];
  assert.equal(lot.ruleClaims['rule:copy-limited'], 2); assert.equal(lot.remainingUses, 0);
  assert.equal(executor.execute(event(root, 'another-event')).outcomes[0].reason, 'resources');
  assert.equal(runtime.active('spell').length, 3);
});

test('a full per-lot copy claim cannot be repeated with another event ID', () => {
  const build = program([rule('copy-two', copy(3), { repeat: { unit: 'lot', limit: 2 } })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), executor = new SpellRuleExecutor(runtime, world);
  const first = executor.execute(event(root));
  assert.deepEqual(first.errors, []); assert.deepEqual(first.outcomes.map(outcome => outcome.status), ['applied', 'applied']);
  assert.equal(runtime.ledger.getOwnedLots(root.id)[0].ruleClaims['rule:copy-two'], 2);
  assert.equal(executor.execute(event(root, 'new-lot-event')).outcomes[0].reason, 'limit');
  assert.equal(runtime.balance(0, 'work'), 6); assert.equal(runtime.active('spell').length, 3);
});

test('single-copy limit still produces one outcome', () => {
  const runtime = new SpellResourceRuntime(1), build = program([rule('single-copy', copy(1), { repeat: { unit: 'receipt', limit: 3 } })]);
  const root = primary(runtime, build), result = new SpellRuleExecutor(runtime, world).execute(event(root));
  assert.deepEqual(result.errors, []); assert.equal(result.outcomes.length, 1);
  assert.equal(result.outcomes[0].status, 'applied'); assert.equal(runtime.balance(0, 'work'), 8);
});

test('fees and per-portion claims commit with a split, survive children, and repeated events are idempotent', () => {
  const build = program([rule('split', { op: 'Allocate', sourceLot: 'self', shares: [.5,.5], maxChildren: 2, remainderPolicy: 'firstChild' },
    { resourceCost: [{ resource: 'power', amount: q(10, 'power') }, { resource: 'work', amount: q(3, 'work') }] })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), executor = new SpellRuleExecutor(runtime, world);
  const first = executor.execute(event(root));
  assert.deepEqual(first.errors, []); assert.equal(first.outcomes[0].status, 'applied');
  assert.equal(runtime.balance(0, 'work'), 7);
  const children = first.outcomes[0].result.objects;
  assert.deepEqual(children.map(child => runtime.balance(child.id, 'power')), [45,45]);
  for (const child of children) {
    const lot = runtime.ledger.getOwnedLots(child.id)[0];
    assert.equal(lot.ruleClaims['rule:split'], 1); assert.equal(lot.remainingUses, 7);
    assert.equal(executor.execute(event(child, `child:${child.id}`)).outcomes[0].reason, 'limit');
  }
  const before = runtime.ledger.snapshot();
  assert.equal(executor.execute(event(root)), first);
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(executor.execute(event(root, 'event', { tick: 1 })).errors[0].code, 'RECEIPT_CONFLICT');
});

test('capacity and cost failures retain the whole input and do not spend lineage uses', () => {
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program());
  const source = ok(runtime.allocate(root.id, [.5])).objects[0];
  const request = { kind: 'shell', fromObjectId: source.id, share: 1, tick: 0, delayTicks: 3, lifeTicks: 10, applications: 1 };
  ok(runtime.createFinite(request, 1));
  const before = runtime.ledger.snapshot();
  const failed = runtime.executePaid({ objectId: root.id, ruleId: 'store', portionLimit: 1, processingUses: 1,
    costs: [{ ownerId: root.id, resource: 'power', quantityQ: 5 }, { ownerId: 0, resource: 'work', quantityQ: 3 }] },
    () => runtime.createFinite({ ...request, fromObjectId: root.id }, 1));
  assert.equal(failed.ok, false); assert.equal(failed.errors[0].code, 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('a fee and an operation cannot both spend the same balance', () => {
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program());
  const converted = ok(runtime.executePaid({ objectId: root.id, ruleId: 'heat', portionLimit: 1, processingUses: 1,
    costs: [{ ownerId: root.id, resource: 'power', quantityQ: 20 }] }, () => runtime.convert(root.id, 'power', 'heat', 1, 1, 1, 'heat-conversion')));
  assert.equal(runtime.balance(root.id, 'power'), 0); assert.equal(runtime.balance(root.id, 'heat'), 80);
  assert.equal(runtime.ledger.getOwnedLots(root.id)[0].remainingUses, 7);
  assert.ok(converted.transaction.facts.some(fact => fact.kind === 'claim'));
});

test('missing transient facts remain unknown inside negation, so they cannot grant a conditional effect', () => {
  const state = { mainBook: 'frost', allocated: new Set(), permits: new Set(), owned: {}, buildCapabilities: new Set(), talentCapabilities: new Set() };
  const absent = { counter: 'healthShare', comparison: 'gte', value: .5 };
  assert.equal(evaluateCondition({ not: absent }, state), false);
  assert.equal(evaluateCondition({ not: { all: [absent] } }, state), false);
  assert.equal(evaluateCondition({ not: absent }, { ...state, counters: { healthShare: .3 } }), true);
});

test('lethal primary damage dispatches its prepared children before clear-room detection', () => {
  const build = program([rule('paid-fragments', { op: 'Allocate', sourceLot: 'self', shares: [.3,.3], maxChildren: 2, remainderPolicy: 'firstChild' },
    { event: 'hit.prepare', stage: 'prepareHit', inherit: 'never' })]);
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), log = [], hp = new Map([[1,25],[2,100]]);
  ok(runtime.dispatch(root.id, 1, 0, 60));
  const executor = new SpellRuleExecutor(runtime, world);
  const lifecycle = new SpellLifecycle(executor, { flightLifeTicks: 60, isAlive: id => hp.get(id) > 0,
    target: () => ({ id: 2, x: 2, y: 0 }), damage: hit => { hp.set(hit.targetId, hp.get(hit.targetId) - hit.powerQ); log.push(`damage:${hit.powerQ}`); },
    launch: object => log.push(`launch:${runtime.balance(object.id, 'power')}`), boundary: () => log.push('boundary') });
  lifecycle.hit(root.id, 1, 1);
  assert.deepEqual(log, ['damage:40','launch:30','launch:30','boundary']);
  assert.deepEqual(lifecycle.diagnostics, []); assert.equal(hp.get(1), -15);
});

test('normal saved casts release without an echo talent; expiry requires its actual rule and closes once', () => {
  for (const echo of [false, true]) {
    const build = program(echo ? [rule('echo', { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'nearest', exitClaim: 'close', onNoTarget: 'lose' },
      { event: 'shell.finish', stage: 'finish', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } })] : []);
    const runtime = new SpellResourceRuntime(1), root = primary(runtime, build), launches = [];
    const shell = ok(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: 1, tick: 0, delayTicks: echo ? 18 : 2,
      lifeTicks: 10, applications: 1 }, 4)).objects[0];
    const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true,
      target: () => ({ id: 2, x: 2, y: 0 }), damage: () => {}, launch: object => launches.push(object.id), boundary: () => {} });
    lifecycle.advance(echo ? 10 : 2);
    assert.equal(runtime.getObject(shell.id).state, 'closed'); assert.equal(launches.length, 1);
    lifecycle.advance(echo ? 11 : 3); assert.equal(launches.length, 1);
    lifecycle.clearRoom(12); assert.equal(runtime.active().length, 0); assert.deepEqual(lifecycle.diagnostics, []);
  }
});

test('an already-closed primary can recover an actually remaining status, charging that status atomically', () => {
  const recover = rule('remaining-dot', { op: 'Recover', remainingSelector: 'ongoing', retention: q(.5, 'ratio'), capacityKey: 'reserve-cap', reuseAfter: 'nextManual' },
    { event: 'hit.after', stage: 'afterHit', resourceCost: [{ resource: 'power', amount: q(5, 'power') }] });
  const build = program([recover], { 'reserve-cap': { id: 'reserve-cap', unit: 'power', base: 100, min: 0, max: 100, integer: true, stage: 'income', multiplierPools: [] } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, build);
  const status = ok(runtime.createFinite({ kind: 'status', fromObjectId: root.id, share: .5, tick: 0, delayTicks: 1, lifeTicks: 60, applications: 4 }, 4)).objects[0];
  ok(runtime.commitHit(root.id, 1));
  const result = new SpellRuleExecutor(runtime, world).execute(event(root, 'after-death', { event: 'hit.after', stage: 'afterHit', tick: 1 }));
  assert.deepEqual(result.errors, []); assert.equal(result.outcomes[0].status, 'applied');
  assert.equal(runtime.balance(status.id, 'power'), 0); assert.equal(runtime.balance(1, 'power'), 22);
  assert.equal(runtime.reserveEntries()[0].availableAfterManual, 2);
});

test('guard order selects the actual shell whose power is spent, with each projectile claimed once', () => {
  const guard = rule('guard-newest', { op: 'Guard', projectileClass: 'reflectable', selectionOrder: 'newest', powerPerBlockedUnit: q(1, 'ratio'), reserveShare: q(1, 'ratio'), projectileClaim: 'once' },
    { event: 'projectile.intercept', stage: 'commitHit', targetKind: 'shell', repeat: { unit: 'enemyProjectile', limit: 1 } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([guard]));
  const parts = ok(runtime.allocate(root.id, [.25,.75])).objects;
  const shells = parts.map((part, index) => ok(runtime.createFinite({ kind: 'shell', fromObjectId: part.id, share: 1, tick: index,
    delayTicks: 10, lifeTicks: 60, applications: 1 }, 4)).objects[0]);
  const executor = new SpellRuleExecutor(runtime, world);
  const intercepted = event(shells[0], 'bullet', { event: 'projectile.intercept', stage: 'commitHit', tick: 2, projectile: { id: 'enemy:1', powerQ: 10, reflectable: true } });
  const result = executor.execute(intercepted);
  assert.deepEqual(result.errors, []); assert.equal(result.outcomes[0].result.blockedPowerQ, 10);
  assert.deepEqual(shells.map(shell => runtime.balance(shell.id, 'power')), [25,65]);
  assert.equal(executor.execute({ ...intercepted, id: 'same-bullet' }).outcomes[0].reason, 'limit');
});

test('a released spell can wait only once for a missing target and still expires without one', () => {
  const release = rule('wait-release', { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'nearest', exitClaim: 'close', onNoTarget: 'waitOnce' },
    { event: 'shell.finish', stage: 'finish', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([release]));
  ok(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: 1, tick: 0, delayTicks: 2, lifeTicks: 10, applications: 1 }, 4));
  const launches = [];
  const executor = new SpellRuleExecutor(runtime, { ...world, selectTarget: () => undefined, flightLifeTicks: 4 });
  const lifecycle = new SpellLifecycle(executor, { flightLifeTicks: 4, isAlive: () => false, target: () => undefined,
    damage: () => {}, launch: object => launches.push(object.id), boundary: () => {} });
  lifecycle.advance(2);
  const waiting = runtime.active('spell').find(object => object.targetWaitUsed);
  assert.equal(waiting.readyAtTick, 6); assert.equal(waiting.expiresAtTick, 7);
  lifecycle.advance(6); lifecycle.advance(7);
  assert.equal(runtime.getObject(waiting.id).state, 'closed'); assert.deepEqual(launches, []); assert.deepEqual(lifecycle.diagnostics, []);
});

test('a short-lived shell without an expiry release rule loses its remaining power', () => {
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program()), launches = [];
  const shell = ok(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: 1, tick: 0, delayTicks: 18, lifeTicks: 10, applications: 1 }, 4)).objects[0];
  const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60, isAlive: () => true, target: world.selectTarget,
    damage: () => {}, launch: object => launches.push(object.id), boundary: () => {} });
  lifecycle.advance(10);
  assert.equal(runtime.getObject(shell.id).state, 'closed'); assert.deepEqual(launches, []);
  assert.equal(runtime.ledger.snapshot().lots.filter(lot => lot.resource === 'power').reduce((sum, lot) => sum + lot.quantityQ, 0), 0);
});

test('one guarded collision closes only the selected page and releases only its unspent remainder', () => {
  const guard = rule('guard', { op: 'Guard', projectileClass: 'reflectable', selectionOrder: 'oldest',
    powerPerBlockedUnit: q(.5, 'ratio'), reserveShare: q(.75, 'ratio'), projectileClaim: 'once' },
  { event: 'projectile.intercept', stage: 'commitHit', targetKind: 'shell', repeat: { unit: 'enemyProjectile', limit: 1 } });
  const release = rule('echo', { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'nearest', exitClaim: 'close', onNoTarget: 'lose' },
    { event: 'shell.finish', stage: 'finish', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([guard, release]));
  const parts = ok(runtime.allocate(root.id, [.5, .5])).objects;
  const shells = parts.map(part => ok(runtime.createFinite({ kind: 'shell', fromObjectId: part.id, share: 1,
    tick: 0, delayTicks: 30, lifeTicks: 60, applications: 1 }, 4)).objects[0]);
  const launches = [], lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, world), { flightLifeTicks: 60,
    isAlive: () => true, target: world.selectTarget, damage: () => {}, launch: object => launches.push(object), boundary: () => {} });
  const projectile = { id: 'incoming', powerQ: 100, reflectable: true };
  assert.equal(lifecycle.intercept({ ...projectile, reflectable: false }, 1), 0);
  assert.equal(lifecycle.intercept(projectile, 1), 74); // 37 saved power pays 74 incoming power; one page only.
  assert.equal(runtime.getObject(shells[0].id).state, 'closed'); assert.equal(runtime.getObject(shells[1].id).state, 'stored');
  assert.equal(launches.length, 1); assert.equal(runtime.balance(launches[0].id, 'power'), 13);
  const snapshot = runtime.ledger.snapshot(); assert.equal(lifecycle.intercept(projectile, 1), 0); assert.deepEqual(runtime.ledger.snapshot(), snapshot);
  assert.equal(lifecycle.intercept({ ...projectile, id: 'late' }, 60), 0); assert.deepEqual(lifecycle.diagnostics, []);
});

test('heat accumulates from distinct real contacts, then fractures exactly the remaining shell into nearby destinations', () => {
  const heat = rule('heat', { op: 'Heat', thermalLot: 'self', shellSelector: 'self', amount: q(20, 'heat'), threshold: q(30, 'heat'), heatMode: 'fracture' },
    { event: 'shell.heat', stage: 'prepareHit', targetKind: 'shell', repeat: { unit: 'object', limit: 64 } });
  const fracture = rule('fracture', { op: 'Fracture', integrityCost: q(1, 'count'), maxPieces: q(3, 'count'), allocationPattern: 'radial', trigger: 'heat' },
    { event: 'shell.fracture', stage: 'afterHit', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } });
  const release = rule('echo', { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'nearest', exitClaim: 'close', onNoTarget: 'lose' },
    { event: 'shell.finish', stage: 'finish', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } });
  const build = program([heat, fracture, release]), runtime = new SpellResourceRuntime(1), root = primary(runtime, build);
  const shell = ok(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: 1, tick: 0, delayTicks: 50,
    lifeTicks: 100, applications: 4, properties: { integrity: 1 } }, 4)).objects[0];
  const near = [{ id: 2, x: 20, y: 0 }, { id: 3, x: 0, y: 20 }], launches = [];
  const adapter = { ...world, selectTarget: () => ({ id: 99, x: 2000, y: 0 }), targetsWithin: (position, radius) => {
    assert.equal(radius, 260); return near;
  } };
  const lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, adapter), { flightLifeTicks: 60, isAlive: () => true,
    target: adapter.selectTarget, damage: () => {}, launch: (object, target) => launches.push({ object, target }), boundary: () => {} });
  const first = primary(runtime, build, { id: 'heat-one', tick: 1, auxiliaryResourcesQ: { heat: 25 } });
  lifecycle.start(first.id, 1); assert.equal(runtime.balance(shell.id, 'heat'), 20);
  // Hitting beside the same shell cannot heat it a second time with this object.
  lifecycle.hit(first.id, 99, 2, {}, { x: 0, y: 0 }); assert.equal(runtime.balance(shell.id, 'heat'), 20);
  const next = primary(runtime, build, { id: 'heat-two', tick: 3, auxiliaryResourcesQ: { heat: 20 } });
  lifecycle.start(next.id, 3);
  assert.equal(runtime.getObject(shell.id).state, 'closed');
  const pieces = launches.filter(item => item.object.derived); assert.equal(pieces.length, 3);
  assert.deepEqual(pieces.map(item => item.target.id), [2, 3, 2]);
  assert.equal(pieces.reduce((n, item) => n + runtime.balance(item.object.id, 'power'), 0), 100);
  assert.equal(pieces.reduce((n, item) => n + runtime.balance(item.object.id, 'heat'), 0), 10);
  for (const { object } of pieces) { assert.equal(object.shape, 'shot'); assert.equal(object.remainingApplications, 1); assert.equal(object.properties.integrity, 0); }
  const count = launches.length; lifecycle.advance(50); assert.equal(launches.length, count);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('fractured pages do not retarget outside their radius or reclaim another release', () => {
  const split = rule('split-end', { op: 'Fracture', integrityCost: q(1, 'count'), maxPieces: q(3, 'count'), allocationPattern: 'radial', trigger: 'finish' },
    { event: 'shell.finish', stage: 'finish', targetKind: 'shell', repeat: { unit: 'object', limit: 1 } });
  const runtime = new SpellResourceRuntime(1), root = primary(runtime, program([split]));
  ok(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: 1, tick: 0, delayTicks: 2,
    lifeTicks: 50, applications: 1, properties: { integrity: 1 } }, 4));
  const launches = [], lifecycle = new SpellLifecycle(new SpellRuleExecutor(runtime, { ...world, targetsWithin: () => [] }), {
    flightLifeTicks: 60, isAlive: () => true, target: world.selectTarget, damage: () => {}, launch: object => launches.push(object), boundary: () => {} });
  lifecycle.advance(2); assert.deepEqual(launches, []);
  assert.equal(runtime.active().filter(object => runtime.ledger.getOwnedLots(object.id).length).length, 0);
  assert.deepEqual(lifecycle.diagnostics, []);
});
