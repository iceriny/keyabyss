const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createRuleCompiler, validateRuleRegistry } = require('../src/shared/build/compile.ts');
const { validateCondition, evaluateCondition } = require('../src/shared/build/conditions.ts');
const { analyzeQuantity, evaluateQuantity } = require('../src/shared/build/quantities.ts');
const { validateOperation } = require('../src/shared/build/operations.ts');
const { createSemanticVocabulary, semanticProximity } = require('../src/shared/build/semantics.ts');
const { BUILD_CONCEPTS } = require('../src/content/build/semantics.ts');

const q = (value, unit = 'ratio') => ({ value, unit });
const contribution = (overrides = {}) => ({ rules: [], capabilities: [], modifiers: [], modes: [], ...overrides });
const semantic = { concepts: { storage: 1 }, objectKinds: ['shell'], operationKinds: ['Store'], inputProperties: [], outputProperties: [], tradeoffKinds: [] };
const talent = (id, overrides = {}) => ({ ...contribution(), id, name: id, description: '保存法术，稍后释放。', cost: 2, purchaseRequires: { all: [] }, permits: [`permit:talent:${id}`], semantic, appearance: 'mechanic', ...overrides });
const rule = (id, operation, overrides = {}) => ({ id, operation: structuredClone(operation), stage: 'assemble', event: 'spell.assemble', targetKind: 'spell',
  when: { all: [] }, resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 }, ...overrides });
const copy = { op: 'Copy', templateSelector: 'manualSpell', workCost: q(12288, 'work'), fundedPowerFactor: q(.35), inheritMask: ['shape'], maxCopies: q(1, 'count') };
const numeric = (id, unit, base, min, max, integer = false) => ({ id, unit, base, min, max, integer, stage: 'assemble', multiplierPools: ['efficiency'] });
function registry() {
  return { version: 1, modeSlots: { 'guard.order': ['oldest', 'newest'], 'letters.distribution': ['gather', 'scatter'], 'letters.reward': ['power', 'save'] },
    numerics: { 'copy.cost': numeric('copy.cost', 'work', 12288, 1024, 65536, true), 'spell.power': numeric('spell.power', 'ratio', 1, 0, 4),
      'reserve.capacity': numeric('reserve.capacity', 'power', 40960, 0, 102400, true) },
    rules: { copy: rule('copy', copy), old: rule('old', { ...copy }, { modeSlot: 'guard.order', modeValue: 'oldest' }),
      fresh: rule('fresh', { ...copy }, { modeSlot: 'guard.order', modeValue: 'newest' }) },
    talents: { T19: talent('T19', { rules: ['copy'], capabilities: ['copy'], modifiers: [{ stat: 'spell.power', pool: 'add', value: .1, unit: 'ratio' }] }),
      T22: talent('T22', { purchaseRequires: { allocated: 'T19' } }),
      T23: talent('T23', { rules: ['old'], modes: [{ slot: 'guard.order', value: 'oldest' }] }),
      T24: talent('T24', { rules: ['fresh'], modes: [{ slot: 'guard.order', value: 'newest' }] }) },
    relics: { R070: { ...contribution({ rules: ['copy'], capabilities: ['copy'] }), id: 'R070', name: '双尖抄笔', description: '积攒输入，复写法术。',
      maxLevel: 1, eligibility: { all: [] }, permitsAll: [], semantic, budget: { perOpportunity: 8, inherited: false } },
      R140: { ...contribution(), id: 'R140', name: '终页铃', description: '增强结束时释放的法术。', maxLevel: 1, eligibility: { capability: 'copy', source: 'build' },
        permitsAll: ['permit:talent:T22'], semantic, budget: { perOpportunity: 8, inherited: false } } },
    books: Object.fromEntries(['frost', 'flame', 'storm', 'spirit'].map(book => [book, contribution()])),
  };
}
const snapshot = (overrides = {}) => ({ version: 1, revision: 1, mainBook: 'frost', allocated: [], selectedModes: {}, assets: [], overrides: [], ...overrides });
function ok(result) { assert.equal(result.ok, true, JSON.stringify(result.errors)); return result.value; }
function error(result, code) { assert.equal(result.ok, false); assert.ok(result.errors.some(e => e.code === code), JSON.stringify(result.errors)); }
const asset = (definitionId, instanceId = definitionId, state = 'owned') => ({ definitionId, instanceId, state, level: 1 });

test('reserve operations validate material selection, fractional recovery and shared use limits', () => {
  const numerics = registry().numerics;
  const recovery = { op: 'Recover', remainingSelector: 'self', resource: 'cold', share: q(.25), retention: q(.5),
    capacityKey: 'reserve.capacity', reuseAfter: 'nextManual' };
  const extraction = operation => rule('extract', operation, { event: 'status.extract', targetKind: 'status' });
  assert.deepEqual(validateOperation(extraction(recovery), numerics), []);
  for (const invalid of [{ resource: 'work' }, { resource: 'opportunity' }, { share: q(0) }, { share: q(1.1) }, { share: q(.5, 'power') }])
    assert.ok(validateOperation(extraction({ ...recovery, ...invalid }), numerics).length);
  const attach = { op: 'Attach', lotSelector: 'reserve', targetSelector: 'spell', resource: 'heat', amount: q(1024, 'heat'),
    reserveShare: q(.5), reserveLimit: q(8192, 'power') };
  assert.deepEqual(validateOperation(rule('use', attach), numerics), []);
  for (const invalid of [{ lotSelector: 'self' }, { reserveShare: q(0) }, { reserveLimit: q(1, 'count') }, { resource: 'opportunity' }])
    assert.ok(validateOperation(rule('use', { ...attach, ...invalid }), numerics).length);
});

test('allocation validates resource-specific shares and explicit finite child shapes', () => {
  const operation = { op: 'Allocate', sourceLot: 'self', shares: [.25], maxChildren: 1, remainderPolicy: 'parent',
    resourceShares: { charge: [1], cold: [0] }, shape: 'chain', applications: q(3, 'count') };
  assert.deepEqual(validateOperation(rule('route', operation), {}), []);
  for (const invalid of [{ shape: 'unlimited' }, { applications: q(65, 'count') }, { applications: q(2, 'ratio') },
    { resourceShares: { charge: [.5, .5] } }, { resourceShares: { power: [1.1] } }, { resourceShares: { fake: [1] } },
    { resourceShares: [] }, { resourceShares: null }, { resourceShares: { charge: Array(1) } }, { shares: Array(1) }])
    assert.ok(validateOperation(rule('route', { ...operation, ...invalid }), {}).length);
});

test('merge accepts the stored assembly boundary and rejects unrelated effect kinds or output policies', () => {
  const operation = { op: 'Merge', compatibilityKey: 'shapeAndTarget', sameRoot: true, maxInputs: q(4, 'count'),
    waitTicks: q(30, 'ticks'), outputPolicy: 'preserveShape' };
  const stored = (overrides = {}) => rule('merge', operation, { event: 'shell.assemble', targetKind: 'shell', ...overrides });
  assert.deepEqual(validateOperation(stored(), {}), []);
  assert.deepEqual(validateOperation(stored({ operation: { ...operation, outputPolicy: 'concentrate' } }), {}), []);
  for (const overrides of [{ stage: 'dispatch' }, { event: 'status.extract', targetKind: 'status' },
    { operation: { ...operation, outputPolicy: 'multiply' } }, { operation: { ...operation, sameRoot: false } }])
    assert.ok(validateOperation(stored(overrides), {}).length);
});

test('reserve burst validates typed ratios, one shared limit and a finite manual cooldown', () => {
  const burst = { minimumTargetRatio: q(3), share: q(.75), totalLimit: q(48 * 1024, 'power'), cooldownManuals: q(2, 'count') };
  const operation = { op: 'Attach', lotSelector: 'reserve', targetSelector: 'spell', resource: 'power', amount: q(100 * 1024, 'power'),
    reserveLimit: q(12 * 1024, 'power'), reserveBurst: burst };
  assert.deepEqual(validateOperation(rule('burst', operation), {}), []);
  for (const bad of [{ ...burst, share: q(1.01) }, { ...burst, minimumTargetRatio: q(0) },
    { ...burst, cooldownManuals: q(65, 'count') }, { ...burst, cooldownManuals: q(2, 'ticks') },
    { ...burst, totalLimit: q(4, 'cold') }, { ...burst, unknown: true }, null, []])
    assert.ok(validateOperation(rule('burst', { ...operation, reserveBurst: bad }), {}).length);
  for (const bad of [{ lotSelector: 'self' }, { reserveLimit: undefined }, { resource: 'work', amount: q(2, 'work') }])
    assert.ok(validateOperation(rule('burst', { ...operation, ...bad }), {}).length);
});

test('concentrated reserve needs its talent prerequisites and conflicts with long archive mode', () => {
  const { NATIVE_RULES } = require('../src/content/build/native.ts');
  const compiler = ok(createRuleCompiler(NATIVE_RULES));
  const allocated = ['T09', 'T29', 'K07'];
  error(compiler.compile(snapshot({ allocated: ['K07'] })), 'INVALID_ALLOCATION');
  error(compiler.compile(snapshot({ allocated: [...allocated, 'T11', 'K06'] })), 'MODE_CONFLICT');
  error(compiler.compile(snapshot({ allocated: ['T12'], assets: [asset('R089')] })), 'MISSING_PERMIT');
  const compiled = ok(compiler.compile(snapshot({ allocated: [...allocated, 'T12', 'T10'], assets: [asset('R089')] })));
  assert.equal(compiled.modes['reserve.mode'], 'burst'); assert.equal(compiled.numerics['reserve.burstShare'], .9);
  assert.equal(compiled.numerics['reserve.useShare'], .5); assert.equal(compiled.numerics['reserve.burstCooldown'], 3);
});

test('transport modes enforce prerequisites and relay relics need the permanent transport permit', () => {
  const { NATIVE_RULES } = require('../src/content/build/native.ts');
  const compiler = ok(createRuleCompiler(NATIVE_RULES));
  error(compiler.compile(snapshot({ allocated: ['T25', 'K12'] })), 'INVALID_ALLOCATION');
  error(compiler.compile(snapshot({ allocated: ['K13'] })), 'INVALID_ALLOCATION');
  error(compiler.compile(snapshot({ allocated: ['T25', 'T27', 'K12', 'K13'] })), 'MODE_CONFLICT');
  error(compiler.compile(snapshot({ assets: [asset('R119')] })), 'MISSING_PERMIT');
  const fleet = ok(compiler.compile(snapshot({ allocated: ['T25', 'T27', 'K12', 'N17-01'], assets: [asset('R077')] })));
  assert.equal(fleet.modes['transport.mode'], 'fleet'); assert.equal(fleet.numerics['transport.mergeInputs'], 6);
  assert.equal(fleet.numerics['merge.waitTicks'], 30);
  assert.equal(evaluateCondition(fleet.rules.find(rule => rule.definition.id === 'storage.merge').definition.when,
    { modes: fleet.modes }), false);
  const solo = ok(compiler.compile(snapshot({ allocated: ['T25', 'K13'], assets: [asset('R119')] })));
  assert.equal(solo.modes['transport.mode'], 'solo'); assert.equal(solo.numerics['transport.retention'], 1);
  assert.equal(solo.numerics['transport.relay'], 1);
});

test('page bridge modes share one entrance, enforce permanent permits and retain their targeting tradeoffs', () => {
  const { NATIVE_RULES } = require('../src/content/build/native.ts');
  const compiler = ok(createRuleCompiler(NATIVE_RULES));
  error(compiler.compile(snapshot({ allocated: ['T14', 'K08'] })), 'INVALID_ALLOCATION');
  error(compiler.compile(snapshot({ allocated: ['K09'] })), 'INVALID_ALLOCATION');
  error(compiler.compile(snapshot({ allocated: ['T14', 'T15', 'K08', 'K09'] })), 'MODE_CONFLICT');
  error(compiler.compile(snapshot({ assets: [asset('R114')] })), 'MISSING_PERMIT');
  error(compiler.compile(snapshot({ assets: [asset('R118')] })), 'MISSING_PERMIT');
  const corridor = ok(compiler.compile(snapshot({ allocated: ['T14', 'T15', 'K08'], assets: [asset('R111'), asset('R114'), asset('R118')] })));
  assert.equal(corridor.numerics['routing.shellRelay'], 1);
  assert.equal(corridor.numerics['routing.relayLimit'], 4);
  assert.equal(corridor.numerics['routing.shellEfficiency'], 1.25);
  assert.equal(corridor.numerics['routing.targets'], 0);
  const mesh = ok(compiler.compile(snapshot({ allocated: ['T14', 'K09'] })));
  assert.equal(mesh.numerics['routing.relayLimit'], 1);
  assert.equal(mesh.numerics['routing.targets'], 5);
  assert.equal(mesh.numerics['routing.distance'], 195);
});

test('field relay and joint-guard tools preserve talent permits and bounded participation', () => {
  const { NATIVE_RULES } = require('../src/content/build/native.ts');
  const compiler = ok(createRuleCompiler(NATIVE_RULES));
  error(compiler.compile(snapshot({ assets: [asset('R120')] })), 'MISSING_PERMIT');
  error(compiler.compile(snapshot({ assets: [asset('R176')] })), 'MISSING_PERMIT');
  const built = ok(compiler.compile(snapshot({ allocated: ['T47', 'T27'], assets: [asset('R120'), asset('R176')] })));
  assert.equal(built.numerics['field.relay'], 1); assert.equal(built.numerics['field.relayRange'], 1.2);
  assert.equal(built.numerics['guard.maxInputs'], 2);
  const guard = { op: 'Guard', projectileClass: 'reflectable', selectionOrder: 'oldest', powerPerBlockedUnit: q(1),
    reserveShare: q(.75), projectileClaim: 'once', maxInputs: q(2, 'count') };
  const definition = op => rule('joint-guard', op, { event: 'projectile.intercept', stage: 'commitHit', targetKind: 'shell' });
  assert.deepEqual(validateOperation(definition(guard), {}), []);
  for (const invalid of [q(0, 'count'), q(9, 'count'), q(2, 'power')])
    assert.ok(validateOperation(definition({ ...guard, maxInputs: invalid }), {}).length);
});

test('shared operations deduplicate across talent and relic, retaining numeric increments and source explanations', () => {
  const compiled = ok(ok(createRuleCompiler(registry())).compile(snapshot({ allocated: ['T19'], assets: [asset('R070')] })));
  assert.equal(compiled.rules.length, 1);
  assert.deepEqual(compiled.rules[0].sourceIds, ['T19', 'asset:R070']);
  assert.equal(compiled.numerics['spell.power'], 1.1);
  assert.equal(compiled.byEvent['spell.assemble'].length, 1);
  assert.equal(compiled.byStage.assemble.length, 1);
  assert.deepEqual(compiled.permits, ['permit:talent:T19']);
  assert.deepEqual(compiled.claimsPerUnit, { receipt: 1, lot: 0, object: 0, enemyProjectile: 0 });
  assert.ok(Object.isFrozen(compiled.rules[0].definition.operation));
});

test('mode predicates read frozen runtime choices and reject unknown slots or acquisition dependencies', () => {
  const predicate = { mode: 'letters.reward', value: 'save' };
  assert.deepEqual(validateCondition(predicate, 'runtime'), []);
  assert.ok(validateCondition(predicate, 'purchase').length); assert.ok(validateCondition(predicate, 'acquisition').length);
  const state = { modes: { 'letters.reward': 'save' } };
  assert.equal(evaluateCondition(predicate, state), true);
  assert.equal(evaluateCondition(predicate, { modes: { 'letters.reward': 'power' } }), false);
  assert.equal(evaluateCondition({ not: predicate }, {}), false);
  const defs = registry(); defs.rules.copy.when = predicate;
  assert.deepEqual(validateRuleRegistry(defs), []);
  defs.rules.copy.when = { mode: 'letters.reward', value: 'unregistered' };
  assert.ok(validateRuleRegistry(defs).some(error => error.code === 'UNKNOWN_DEFINITION'));
});

test('letter reward plans validate the whole allocation and reject hidden or incompatible options', () => {
  const plan = { storedShare: q(.5), workShare: q(.25), storedRetention: q(.85), workRetention: q(.85),
    capacityUnits: q(6, 'count'), releaseDelayTicks: q(120, 'ticks'), lifeTicks: q(600, 'ticks'), inheritShape: false };
  const op = { op: 'Mark', positionSelector: 'nextWord', matchPolicy: 'manualOnly', maxPositions: q(6, 'count'),
    rewardAllocation: 'power', humanReceiptClaim: 'once', opportunityCost: q(1024, 'opportunity'), maxPerWord: q(1, 'count'), rewardPlan: plan };
  const check = operation => validateOperation(rule('mark', operation, { stage: 'income', event: 'word.interrupted' }), {});
  assert.deepEqual(check(op), []);
  for (const badPlan of [{ ...plan, workShare: q(.6) }, { ...plan, storedShare: q(.1, 'power') },
    { ...plan, capacityUnits: q(65, 'count') }, { ...plan, lifeTicks: q(0, 'ticks') }, { ...plan, storedRetention: q(1.01) },
    { ...plan, inheritShape: 'yes' }, { ...plan, extra: true }, null, []]) assert.ok(check({ ...op, rewardPlan: badPlan }).length);
  for (const invalid of [{ ...op, rewardAllocation: 'guard' }, { ...op, rewardPlan: undefined },
    { ...op, opportunityCost: q(0, 'opportunity') }, { ...op, maxPerWord: q(73, 'count') }]) assert.ok(check(invalid).length);
});

test('compiler owns an immutable catalog snapshot and recompiling never mutates prior programs', () => {
  const defs = registry(), compiler = ok(createRuleCompiler(defs));
  defs.rules.copy.operation.workCost.value = 0;
  const before = ok(compiler.compile(snapshot({ allocated: ['T19'] })));
  const after = ok(compiler.compile(snapshot({ revision: 2, allocated: [] })));
  assert.equal(before.rules[0].definition.operation.workCost.value, 12288);
  assert.equal(before.revision, 1); assert.equal(after.revision, 2); assert.equal(after.rules.length, 0);
});

test('permanent relic permits come only from departure talents, never from leased or event capabilities', () => {
  const compiler = ok(createRuleCompiler(registry()));
  const loan = { ...contribution({ rules: ['copy'], capabilities: ['copy'] }), id: 'loan', scope: 'chapter', expiresAfter: 1, shadows: [] };
  error(compiler.compile(snapshot({ overrides: [loan], assets: [asset('R140')] })), 'MISSING_PERMIT');
  const borrowed = ok(compiler.compile(snapshot({ overrides: [loan], assets: [asset('R140', 'temporary', 'leased')] })));
  assert.deepEqual(borrowed.permits, []); assert.deepEqual(borrowed.capabilities, ['copy']); assert.deepEqual(borrowed.talentCapabilities, []);
  ok(compiler.compile(snapshot({ allocated: ['T22', 'T19'], assets: [asset('R140')] })));
});

test('mode shadows replace only their declared slot, expire cleanly, and cannot legalize conflicting permanent choices', () => {
  const compiler = ok(createRuleCompiler(registry()));
  const override = { ...contribution({ rules: ['fresh'], modes: [{ slot: 'guard.order', value: 'newest' }] }), id: 'new-binding', scope: 'room', expiresAfter: 3, shadows: ['guard.order'] };
  const active = ok(compiler.compile(snapshot({ allocated: ['T23'], overrides: [override] })));
  assert.deepEqual(active.rules.map(r => r.definition.id), ['fresh']); assert.deepEqual(active.permits, ['permit:talent:T23']);
  assert.deepEqual(ok(compiler.compile(snapshot({ allocated: ['T23'] }))).rules.map(r => r.definition.id), ['old']);
  error(compiler.compile(snapshot({ allocated: ['T23', 'T24'], overrides: [override] })), 'MODE_CONFLICT');
  error(compiler.compile(snapshot({ allocated: ['T23'], overrides: [override, { ...override, id: 'duplicate-slot' }] })), 'MODE_CONFLICT');
});

test('mode defaults yield to a choice or temporary override and return after expiry', () => {
  const defs = registry(); defs.modeDefaults = { 'guard.order': 'oldest' };
  defs.books.frost.rules = ['old', 'fresh'];
  const compiler = ok(createRuleCompiler(defs));
  const ids = build => ok(compiler.compile(snapshot(build))).rules.map(rule => rule.definition.id);
  assert.deepEqual(ids({}), ['old']); assert.deepEqual(ids({ allocated: ['T24'] }), ['fresh']);
  const override = { ...contribution({ modes: [{ slot: 'guard.order', value: 'newest' }] }),
    id: 'new-order', scope: 'room', expiresAfter: 1, shadows: ['guard.order'] };
  assert.deepEqual(ids({ overrides: [override] }), ['fresh']); assert.deepEqual(ids({}), ['old']);
  error(compiler.compile(snapshot({ allocated: ['T23', 'T24'] })), 'MODE_CONFLICT');
  defs.modeDefaults['guard.order'] = 'unknown'; error(createRuleCompiler(defs), 'INVALID_DEFINITION');
});

test('prerequisite order rejects mutual unlocks, transient requirements, missing IDs and final exclusions', () => {
  const defs = registry();
  defs.talents.T19.purchaseRequires = { allocated: 'T22' };
  error(ok(createRuleCompiler(defs)).compile(snapshot({ allocated: ['T19', 'T22'] })), 'INVALID_ALLOCATION');
  defs.talents.T19.purchaseRequires = { capability: 'copy', source: 'build' };
  error(createRuleCompiler(defs), 'INVALID_CONDITION_CONTEXT');
  error(ok(createRuleCompiler(registry())).compile(snapshot({ allocated: ['missing'] })), 'UNKNOWN_DEFINITION');
  const exclusions = registry(); exclusions.talents.T19.purchaseRequires = { not: { allocated: 'T22' } };
  error(ok(createRuleCompiler(exclusions)).compile(snapshot({ allocated: ['T19', 'T22'] })), 'INVALID_ALLOCATION');
});

test('whole catalog rejects unused unknown operations, cyclic order and zero-cost recursive copies', () => {
  const defs = registry(); defs.rules.unused = rule('unused', { op: 'RunScript', script: 'bad()' });
  error(createRuleCompiler(defs), 'INVALID_DEFINITION');
  delete defs.rules.unused; defs.rules.copy.after = ['old']; defs.rules.old.after = ['copy'];
  error(createRuleCompiler(defs), 'UNBOUNDED_RULE_CYCLE');
  delete defs.rules.copy.after; delete defs.rules.old.after;
  defs.rules.copy.operation.workCost = q(0, 'work'); error(createRuleCompiler(defs), 'INVALID_QUANTITY');
});

test('numeric pools aggregate once, reject mixed dimensions, and retain stable compilation regardless of input order', () => {
  const defs = registry();
  defs.relics.R070.maxLevel = 2;
  defs.relics.R070.modifiers = [{ stat: 'spell.power', pool: 'efficiency', value: .1, unit: 'ratio' }];
  const compiler = ok(createRuleCompiler(defs));
  const assets = [asset('R070', 'one'), asset('R070', 'two')];
  const build = snapshot({ allocated: ['T19', 'T22'], assets });
  const a = ok(compiler.compile(build)), b = ok(compiler.compile({ ...build, allocated: [...build.allocated].reverse(), assets: [...assets].reverse() }));
  assert.deepEqual(a, b); assert.ok(Math.abs(a.numerics['spell.power'] - 1.32) < 1e-12);
  defs.relics.R070.modifiers[0].unit = 'ticks'; error(createRuleCompiler(defs), 'INVALID_UNIT');
});

test('distinct opportunity-distribution and reward-use slots can coexist; mode choices must be owned', () => {
  const defs = registry();
  defs.talents.T19.modes = [{ slot: 'letters.distribution', value: 'scatter' }];
  defs.talents.T22.modes = [{ slot: 'letters.reward', value: 'save' }];
  const compiler = ok(createRuleCompiler(defs));
  assert.equal(Object.keys(ok(compiler.compile(snapshot({ allocated: ['T19', 'T22'] }))).modes).length, 2);
  error(compiler.compile(snapshot({ selectedModes: { 'letters.reward': 'save' } })), 'INVALID_ALLOCATION');
});

test('income sources share a receipt and multiple independent suppliers cannot double it', () => {
  const defs = registry();
  defs.rules.supply = rule('supply', { op: 'Supply', incomeKind: 'work', receiptKind: 'manual', amountPerHumanCharacter: q(1024, 'work'), distributionWeights: { work: 1 } }, { stage: 'income', event: 'manual.complete' });
  defs.rules.extra = { ...defs.rules.supply, id: 'extra' };
  defs.talents.T19.rules = ['supply']; defs.relics.R070.rules = ['extra'];
  error(ok(createRuleCompiler(defs)).compile(snapshot({ allocated: ['T19'], assets: [asset('R070')] })), 'INVALID_DEFINITION');
});

test('quantity analysis rejects unit mixing, a possible zero divisor and unknown state', () => {
  const defs = registry().numerics;
  assert.deepEqual(ok(analyzeQuantity({ add: [{ stat: 'copy.cost' }, q(1024, 'work')] }, defs)), { unit: 'work', min: 2048, max: 66560 });
  error(analyzeQuantity({ add: [q(1, 'ticks'), q(1, 'work')] }, defs), 'INVALID_UNIT');
  error(analyzeQuantity({ divide: [q(1, 'work'), { stat: 'spell.power' }] }, defs), 'INVALID_QUANTITY');
  assert.throws(() => evaluateQuantity({ stat: 'missing' }, { numerics: {}, balances: {}, counters: {} }), /INVALID_QUANTITY/);
  assert.equal(evaluateQuantity({ multiply: [q(20, 'power'), q(.35)] }, { numerics: {}, balances: {}, counters: {} }), 7);
});

test('conditions admit only registered context-appropriate predicates', () => {
  assert.equal(validateCondition({ all: [{ mainBook: 'frost' }, { not: { allocated: 'T19' } }] }, 'purchase').length, 0);
  for (const c of [{ owned: 'R070', minLevel: 1 }, { permit: 'permit:talent:T19' }, { objectProperty: 'material', comparison: 'eq', value: 'paper' }]) assert.ok(validateCondition(c, 'purchase').length);
  assert.ok(validateCondition({ counter: 'healthShare', comparison: 'lte', value: .5 }, 'acquisition').length);
  assert.ok(validateCondition({ objectProperty: 'shape', comparison: 'gte', value: 'paper' }, 'runtime').length);
  assert.ok(validateCondition({ all: [], mainBook: 'frost' }, 'runtime').length);
  const state = { mainBook: 'frost', allocated: new Set(), permits: new Set(), owned: {}, buildCapabilities: new Set(['copy']), talentCapabilities: new Set() };
  assert.equal(evaluateCondition({ capability: 'copy', source: 'talent' }, state), false);
  assert.equal(evaluateCondition({ capability: 'copy', source: 'build' }, state), true);
});

test('all sixteen operation forms have unit and stage checks, including finite storage, transfer and recovery', () => {
  const cases = [
    ['Supply', 'income', 'manual.complete', 'spell', { incomeKind: 'work', receiptKind: 'manual', amountPerHumanCharacter: q(1024, 'work'), distributionWeights: { work: 1 } }],
    ['Attach', 'assemble', 'spell.assemble', 'spell', { lotSelector: 'self', targetSelector: 'spell', resource: 'cold', amount: q(1024, 'cold') }],
    ['Allocate', 'assemble', 'spell.assemble', 'spell', { sourceLot: 'self', shares: [.3, .3], maxChildren: 2, remainderPolicy: 'parent' }],
    ['Store', 'dispatch', 'spell.dispatch', 'spell', { shellArchetype: 'crystal', capacityUnits: q(1, 'count'), releaseDelayTicks: q(216, 'ticks'), lifeTicks: q(600, 'ticks'), onNoCapacity: 'retain' }],
    ['Transfer', 'afterHit', 'hit.after', 'spell', { targetPolicy: 'nextUnhit', maxDistance: q(340, 'distance'), hopCost: q(1024, 'charge'), maxHops: q(2, 'count'), onNoTarget: 'recover' }],
    ['Heat', 'afterHit', 'shell.heat', 'shell', { thermalLot: 'self', shellSelector: 'nearest', amount: q(1024, 'heat'), threshold: q(1024, 'heat'), heatMode: 'open' }],
    ['Fracture', 'afterHit', 'hit.after', 'spell', { integrityCost: q(1, 'count'), allocationPattern: 'radial', maxPieces: q(3, 'count'), trigger: 'hit' }],
    ['Release', 'finish', 'shell.finish', 'shell', { unspentLotSelector: 'unspent', targetPolicy: 'nearest', exitClaim: 'close', onNoTarget: 'lose' }],
    ['Copy', 'assemble', 'spell.assemble', 'spell', copy],
    ['Merge', 'assemble', 'spell.assemble', 'spell', { compatibilityKey: 'shapeAndTarget', sameRoot: true, maxInputs: q(2, 'count'), waitTicks: q(20, 'ticks'), outputPolicy: 'concentrate' }],
    ['Recover', 'finish', 'status.finish', 'status', { remainingSelector: 'ongoing', retention: q(.35), capacityKey: 'reserve.capacity', reuseAfter: 'nextManual' }],
    ['Guard', 'prepareHit', 'projectile.intercept', 'shell', { projectileClass: 'reflectable', selectionOrder: 'oldest', powerPerBlockedUnit: q(1), reserveShare: q(.4), projectileClaim: 'once' }],
    ['Convert', 'assemble', 'spell.assemble', 'spell', { fromComponent: 'heat', toComponent: 'cold', share: q(.2), rate: q(.8), conversionStage: 'assemble' }],
    ['Mark', 'afterHit', 'hit.after', 'spell', { positionSelector: 'nextWord', matchPolicy: 'manualOnly', maxPositions: q(2, 'count'), rewardAllocation: 'power', humanReceiptClaim: 'once' }],
    ['Field', 'afterHit', 'hit.after', 'spell', { shape: 'circle', radius: q(80, 'distance'), lifeTicks: q(240, 'ticks'), maxApplications: q(4, 'count'), lotAllocation: 'equal', onFinish: 'lose' }],
    ['Ongoing', 'prepareHit', 'status.contact', 'status', { action: 'advance', applications: q(2, 'count') }],
  ];
  for (const [op, stage, event, targetKind, fields] of cases) {
    const definition = rule(op, { ...fields, op }, { stage, event, targetKind });
    assert.deepEqual(validateOperation(definition, registry().numerics), [], op);
    assert.ok(validateOperation({ ...definition, stage: 'invalid-stage' }, registry().numerics).length, op);
  }
  assert.equal(cases.length, 16);
  assert.equal(validateRuleRegistry(registry()).length, 0);
});

test('ongoing timing validates each paid variant, units, event and target before combat', () => {
  const definition = operation => rule('timing', operation, { stage: 'prepareHit', event: 'status.contact', targetKind: 'status' });
  const advance = { op: 'Ongoing', action: 'advance', applications: q(2, 'count') };
  const delay = { op: 'Ongoing', action: 'delay', coldCost: q(12, 'cold'), extraTicks: q(20, 'ticks'), maxDelayTicks: q(40, 'ticks') };
  for (const operation of [advance, delay]) {
    assert.deepEqual(validateOperation(definition(operation), {}), []);
    for (const overrides of [{ stage: 'afterHit' }, { event: 'hit.prepare' }, { targetKind: 'spell' }])
      assert.ok(validateOperation({ ...definition(operation), ...overrides }, {}).length);
  }
  for (const invalid of [{ ...advance, applications: q(0, 'count') }, { ...advance, applications: q(65, 'count') },
    { ...advance, applications: q(2, 'ticks') }, { ...advance, coldCost: q(12, 'cold') }, { ...advance, action: 'refresh' },
    { ...delay, coldCost: q(0, 'cold') }, { ...delay, coldCost: q(12, 'power') }, { ...delay, extraTicks: q(.5, 'ticks') },
    { ...delay, maxDelayTicks: q(72001, 'ticks') }, { ...delay, extraTicks: undefined }])
    assert.ok(validateOperation(definition(invalid), {}).length, JSON.stringify(invalid));
});

test('field definitions validate material fractions and the status-start stage before combat', () => {
  const operation = { op: 'Field', shape: 'circle', radius: q(80, 'distance'), lifeTicks: q(240, 'ticks'),
    maxApplications: q(8, 'count'), lotAllocation: 'onContact', onFinish: 'recover', share: q(0), resourceShares: { power: .5 } };
  const definition = rule('field', operation, { stage: 'prepareHit', event: 'status.start', targetKind: 'status' });
  assert.deepEqual(validateOperation(definition, {}), []);
  for (const shares of [null, [], { power: 2 }, { cold: -1 }, { heat: NaN }, { fake: .2 }]) {
    assert.ok(validateOperation({ ...definition, operation: { ...operation, resourceShares: shares } }, {}).length);
  }
  assert.ok(validateOperation({ ...definition, targetKind: 'spell' }, {}).length);
  assert.ok(validateOperation({ ...definition, stage: 'commitHit' }, {}).length);
});

test('shared graph vocabulary normalizes aliases without granting capabilities and rejects unknown concepts', () => {
  const vocabulary = createSemanticVocabulary(BUILD_CONCEPTS, ['flame', 'storm', 'frost', 'spirit']);
  assert.deepEqual(ok(vocabulary.normalize({ 保存: 1, 时间: 1, heat: 2 })), { heat: .5, storage: .5 });
  const books = ok(vocabulary.bookAffinity({ 保存: 1, 热加工: 1 }));
  assert.ok(Math.abs(Object.values(books).reduce((a, b) => a + b, 0) - 1) < 1e-12);
  assert.ok(books.flame > books.storm); assert.ok(books.frost > books.storm);
  error(vocabulary.normalize({ '自造流派标签': 1 }), 'INVALID_DEFINITION');
  error(vocabulary.normalize({ storage: NaN }), 'INVALID_DEFINITION');
  assert.throws(() => createSemanticVocabulary([...BUILD_CONCEPTS, BUILD_CONCEPTS[0]], ['flame', 'storm', 'frost', 'spirit']), /Invalid concept/);
});

test('semantic proximity rewards compatible operations and object flow without multiplying duplicate tags', () => {
  const storage = { ...semantic, objectKinds: ['shell'], operationKinds: ['Store'], inputProperties: ['power'], outputProperties: ['stored'], tradeoffKinds: ['delay'] };
  const guard = { ...semantic, objectKinds: ['shell'], operationKinds: ['Guard'], inputProperties: ['stored'], outputProperties: ['unspent'], tradeoffKinds: ['delay'] };
  const distant = { ...semantic, objectKinds: ['letter'], operationKinds: ['Mark'], inputProperties: ['typed'], outputProperties: ['opportunity'], tradeoffKinds: ['resonance'] };
  assert.ok(semanticProximity(storage, guard) > semanticProximity(storage, distant));
  assert.equal(semanticProximity(storage, guard), semanticProximity(guard, storage));
  assert.equal(semanticProximity(storage, guard), semanticProximity({ ...storage, objectKinds: ['shell', 'shell'] }, guard));
});
