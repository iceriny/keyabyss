const { test } = require('node:test');
const assert = require('node:assert/strict');
const { ManualSpellIncome } = require('../src/simulation/spells/ManualSpellIncome.ts');
const { SpellResourceRuntime } = require('../src/simulation/spells/SpellResourceRuntime.ts');
const { SpellRuleExecutor } = require('../src/simulation/spells/SpellRuleExecutor.ts');
const { SpellLifecycle } = require('../src/simulation/spells/SpellLifecycle.ts');
const { createRuleCompiler } = require('../src/shared/build/compile.ts');
const { NATIVE_RULES } = require('../src/content/build/native.ts');

function ok(result) { assert.equal(result.ok, true, JSON.stringify(result.errors)); return result.value; }
function error(result, code) { assert.equal(result.ok, false); assert.ok(result.errors.some(e => e.code === code), JSON.stringify(result.errors)); }
function compile(registry = NATIVE_RULES, overrides = []) {
  return ok(ok(createRuleCompiler(registry)).compile({ version: 1, revision: 1, mainBook: 'flame',
    allocated: [], selectedModes: {}, assets: [], overrides }));
}
function input(program, extra = {}) {
  return { id: 'input-1', wordLength: 5, humanPositions: [0, 1], program, shape: 'shot', position: { x: 0, y: 0 },
    targetId: 8, tick: 0, lifeTicks: 120, applications: 1, processingUses: 8, ...extra };
}
function direction(id, resource, weight = 1) {
  return { id, scope: 'run', expiresAfter: 1, shadows: [], rules: [], capabilities: [], modifiers: [], modes: [],
    supplyDirections: [{ resource, weight }] };
}

test('input prices one primary and one auxiliary budget; replay cannot reprice after work is spent', () => {
  const runtime = new SpellResourceRuntime(1), income = new ManualSpellIncome(runtime), program = compile();
  const receipt = input(program), root = ok(income.accept(receipt));
  assert.equal(runtime.balance(root.id, 'power'), 24 * 1024);
  assert.equal(runtime.balance(0, 'work'), 1024); assert.equal(runtime.balance(root.id, 'heat'), 1024);
  ok(runtime.copy(root.id, 1024, .35, []));
  assert.equal(ok(income.accept({ ...receipt, humanPositions: [1, 0] })).id, root.id);
  assert.equal(runtime.balance(0, 'work'), 0);
  assert.equal(runtime.manualCount, 1);
  error(income.accept({ ...receipt, primaryMultiplier: 2 }), 'RECEIPT_CONFLICT');
  error(income.accept({ ...receipt, program: compile() }), 'RECEIPT_CONFLICT');
  const before = runtime.ledger.snapshot();
  error(income.accept(input(program, { id: 'bad', humanPositions: [0, 0] })), 'INVALID_RESOURCE_TRANSACTION');
  error(income.accept(input(program, { id: 'auto', humanPositions: [] })), 'INVALID_RESOURCE_TRANSACTION');
  assert.deepEqual(runtime.ledger.snapshot(), before);
});

test('material entrances share a finite auxiliary budget, deduplicate and honor selected modes', () => {
  const once = compile(NATIVE_RULES, [direction('cold', 'cold')]);
  const twice = compile(NATIVE_RULES, [direction('cold', 'cold'), direction('duplicate', 'cold')]);
  const two = compile(NATIVE_RULES, [direction('cold', 'cold'), direction('heat', 'heat')]);
  const weights = program => program.rules.find(rule => rule.definition.id === 'input.work').definition.operation.distributionWeights;
  assert.deepEqual(weights(once), weights(twice));
  assert.deepEqual(weights(twice), { work: 1 / 3, heat: 1 / 3, cold: 1 / 3 });
  assert.deepEqual(weights(twice), weights(two)); // The native flame direction and a second heat entrance do not stack.
  const runtime = new SpellResourceRuntime(1), income = new ManualSpellIncome(runtime);
  const root = ok(income.accept(input(two)));
  assert.equal(runtime.balance(root.id, 'cold') + runtime.balance(root.id, 'heat') + runtime.balance(0, 'work'), 2 * 1024);
  assert.equal(runtime.balance(root.id, 'power'), 24 * 1024);
  const registry = structuredClone(NATIVE_RULES);
  registry.modeSlots.material = ['cold', 'heat'];
  registry.books.flame.supplyDirections = [{ resource: 'cold', weight: 2, modeSlot: 'material', modeValue: 'cold' }];
  assert.deepEqual(weights(compile(registry)), { work: 1 });
  registry.books.flame.modes = [{ slot: 'material', value: 'cold' }];
  assert.deepEqual(weights(compile(registry)), { work: 1 / 3, cold: 2 / 3 });
});

test('a one-Q auxiliary budget is conserved across mixed resources with deterministic rounding', () => {
  const registry = structuredClone(NATIVE_RULES);
  registry.numerics['input.work.perCharacter'].base = 1;
  const program = compile(registry, [direction('cold', 'cold'), direction('heat', 'heat'), direction('letters', 'opportunity')]);
  const runtime = new SpellResourceRuntime(1), income = new ManualSpellIncome(runtime);
  const root = ok(income.accept(input(program, { humanPositions: [0] })));
  const lots = runtime.ledger.snapshot().lots;
  assert.equal(lots.filter(lot => lot.resource !== 'power').reduce((sum, lot) => sum + lot.quantityQ, 0), 1);
  assert.equal(runtime.balance(0, 'work'), 1);
  assert.ok(lots.every(lot => lot.origin.receiptId === root.rootReceiptId));
});

test('atomic income failure cannot publish a primary spell or consume an input receipt', () => {
  const runtime = new SpellResourceRuntime(1), income = new ManualSpellIncome(runtime), program = compile();
  ok(runtime.ledger.issue({ origin: { kind: 'manual', receiptId: 'full' }, ownerId: 0,
    grants: [{ resource: 'work', quantityQ: 1024 * 1_000_000_000, remainingUses: 1 }] }));
  const before = runtime.ledger.snapshot();
  error(income.accept(input(program)), 'RESOURCE_LIMIT');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.equal(runtime.manualCount, 0); assert.equal(runtime.active().length, 0);
});

test('both supply acknowledgements finish before an instant launch; no second income is emitted', () => {
  const runtime = new SpellResourceRuntime(1), income = new ManualSpellIncome(runtime), program = compile();
  const counters = { humanCharacters: 2, wordLength: 5 };
  const root = ok(income.accept(input(program))), paid = runtime.ledger.snapshot();
  const acknowledged = [], launches = [];
  const executor = new SpellRuleExecutor(runtime, { flightLifeTicks: 120, selectTarget: () => ({ id: 8, x: 0, y: 0 }),
    supply: (context, op) => { acknowledged.push(context.rule.definition.id); return income.supply(context, op); },
    mark: () => { throw new Error('Unexpected Mark'); } });
  const lifecycle = new SpellLifecycle(executor, { flightLifeTicks: 120, isAlive: () => true,
    target: () => ({ id: 8, x: 0, y: 0 }), damage: () => {}, boundary: () => {},
    launch: object => { launches.push(object.id); assert.deepEqual(acknowledged, ['input.primary', 'input.work']); lifecycle.hit(object.id, 8, 0, counters); } });
  lifecycle.start(root.id, 0, counters);
  lifecycle.start(root.id, 0, counters);
  assert.deepEqual(launches, [root.id]);
  assert.deepEqual(lifecycle.diagnostics, []);
  assert.equal(runtime.manualCount, 1); assert.equal(runtime.balance(0, 'work'), 1024);
  assert.equal(runtime.ledger.snapshot().lots.length, paid.lots.length);
});

test('invalid supply directions and charging suppliers are rejected before gameplay', () => {
  for (const invalid of [{ resource: 'cold', weight: -1 }, { resource: 'paper', weight: 1 }, { resource: 'heat', weight: NaN }]) {
    const registry = structuredClone(NATIVE_RULES); registry.books.flame.supplyDirections = [invalid];
    error(createRuleCompiler(registry), 'INVALID_DEFINITION');
  }
  const registry = structuredClone(NATIVE_RULES);
  registry.rules['input.work'].resourceCost = [{ resource: 'work', amount: { value: 1, unit: 'work' } }];
  error(createRuleCompiler(registry), 'INVALID_DEFINITION');
});

test('registered Attach draws a bounded reserve only on a later primary, including cross-room income', () => {
  const registry = structuredClone(NATIVE_RULES);
  registry.rules.reserve = { id: 'reserve', stage: 'assemble', event: 'spell.assemble', targetKind: 'spell', when: { all: [] },
    operation: { op: 'Attach', lotSelector: 'reserve', targetSelector: 'spell', resource: 'power', amount: { value: 400, unit: 'power' } },
    resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 } };
  registry.books.flame.rules.push('reserve');
  const program = compile(registry), source = new SpellResourceRuntime(1), income = new ManualSpellIncome(source);
  const first = ok(income.accept(input(program)));
  ok(source.recover(first.id, 'power', 1, .5, 10000, 'nextRoom'));
  source.active().forEach(object => ok(source.discard(object.id)));
  const ticket = ok(source.exportReserves()), runtime = new SpellResourceRuntime(2), next = new ManualSpellIncome(runtime);
  ok(runtime.importReserves(ticket));
  const root = ok(next.accept(input(program, { id: 'next-room' })));
  const initial = runtime.balance(root.id, 'power'), reserved = runtime.balance(1, 'power');
  const executor = new SpellRuleExecutor(runtime, { flightLifeTicks: 120, selectTarget: () => undefined,
    supply: (context, op) => next.supply(context, op), mark: () => { throw new Error('Unexpected Mark'); } });
  const event = { id: 'assembly', subject: root, event: 'spell.assemble', stage: 'assemble', tick: 0, counters: {} };
  assert.deepEqual(executor.execute(event).errors, []);
  assert.equal(runtime.balance(root.id, 'power'), initial + 400);
  assert.equal(runtime.balance(1, 'power'), reserved - 400);
  assert.equal(executor.execute({ ...event, id: 'second-assembly' }).outcomes[0].reason, 'limit');
  const child = ok(runtime.allocate(root.id, [.5])).objects[0];
  assert.equal(executor.execute({ ...event, id: 'derived', subject: child }).outcomes[0].reason, 'inheritance');
  assert.equal(runtime.balance(1, 'power'), reserved - 400);
});
