const { test } = require('node:test');
const assert = require('node:assert/strict');
const { RESOURCE_SCALE: Q } = require('../src/contracts/build-resources.ts');
const { SpellResourceRuntime } = require('../src/simulation/spells/SpellResourceRuntime.ts');
const { SpellRuleExecutor } = require('../src/simulation/spells/SpellRuleExecutor.ts');
const { SpellLifecycle } = require('../src/simulation/spells/SpellLifecycle.ts');
const { LetterOpportunities } = require('../src/simulation/spells/LetterOpportunities.ts');
const { createRuleCompiler } = require('../src/shared/build/compile.ts');
const { NATIVE_RULES } = require('../src/content/build/native.ts');
const { createGame, isolate, type } = require('./harness.cjs');

function ok(result) { assert.equal(result.ok, true, JSON.stringify(result.errors)); return result.value; }
function error(result, code) { assert.equal(result.ok, false); if (code) assert.ok(result.errors.some(e => e.code === code), JSON.stringify(result.errors)); }
function program(allocated = ['T31']) {
  return ok(ok(createRuleCompiler(NATIVE_RULES)).compile({ version: 1, revision: 1, mainBook: 'flame', allocated,
    selectedModes: {}, assets: [], overrides: [] }));
}
const session = (targetId, revision = 1, word = 'aa') => ({ targetId, revision, word });
const binding = (targetId, position = 0, revision = 1, word = 'aa') => ({ session: session(targetId, revision, word), position,
  character: word.replace(/ /g, '')[position] });
function receipt(id, compiled, target = session(1), positions = [0, 1], opportunity = 0, tick = 0, overrides = {}) {
  return { id, program: compiled, wordLength: target.word.replace(/ /g, '').length, wordSession: target, humanPositions: positions,
    primaryPowerQ: 20 * Q, auxiliaryWorkQ: 2 * Q, auxiliaryResourcesQ: { opportunity }, shape: 'shot',
    targetId: target.targetId, position: { x: 0, y: 0 }, tick, lifeTicks: 120, applications: 1, processingUses: 8, ...overrides };
}
const plan = (overrides = {}) => ({ storedShare: .25, workShare: .25, storedRetention: .5, workRetention: .5,
  capacity: 8, delayTicks: 2, lifeTicks: 40, inheritShape: false, opportunityCostQ: Q,
  spread: false, maxPerWord: 2, ...overrides });

test('marks reserve earned opportunities atomically and refuse fake letters, fees and repeated positions', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const root = ok(runtime.acceptManual(receipt('source', compiled, session(1), [0, 1], 2 * Q)));
  const before = runtime.ledger.snapshot();
  error(runtime.markLetters(root.id, [{ ...binding(2), character: 'z' }], 0, 600, 'power', 6 * Q));
  error(runtime.markLetters(root.id, [binding(2), binding(2)], 0, 600, 'power', 6 * Q), 'DUPLICATE_CLAIM');
  error(runtime.markLetters(root.id, [binding(2)], 0, 600, 'power', 6 * Q, 3 * Q), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.equal(runtime.active('letter').length, 0);
  const result = ok(runtime.markLetters(root.id, [binding(2), binding(2, 1)], 0, 600, 'power', 6 * Q));
  assert.equal(runtime.balance(0, 'opportunity'), 0);
  assert.equal(runtime.balance(root.id, 'power'), 20 * Q);
  assert.equal(result.objects[0].id, root.id + 1);
  assert.ok(result.objects.every(letter => runtime.ledger.getOwnedLots(letter.id).every(lot => lot.origin.receiptId === 'source' && lot.remainingUses === 7)));
  error(runtime.commitHit(result.objects[0].id, 2));
  error(runtime.convert(root.id, 'power', 'opportunity', .5, 1, 1, 'forge'));
});

test('real completion redeems only entered positions of the exact word session, never an automatic suffix', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(1), [0, 1], 2 * Q)));
  ok(runtime.markLetters(source.id, [binding(2), binding(2, 1)], 0, 600, 'power', 6 * Q));
  const stale = ok(runtime.acceptManual(receipt('same-text-new-session', compiled, session(2, 2))));
  error(runtime.redeemLetters(stale.id, 0), 'INSUFFICIENT_RESOURCE');
  const manual = ok(runtime.acceptManual(receipt('only-first-manual', compiled, session(2), [0])));
  const result = ok(runtime.redeemLetters(manual.id, 0));
  assert.equal(runtime.balance(manual.id, 'power'), 26 * Q);
  assert.equal(runtime.active('letter').length, 1);
  assert.equal(runtime.active('letter')[0].letter.binding.position, 1);
  assert.equal(result.transaction.facts.some(fact => fact.kind === 'income'), false);
  error(runtime.redeemLetters(manual.id, 0), 'INSUFFICIENT_RESOURCE');
  assert.equal(runtime.balance(manual.id, 'power'), 26 * Q);
});

test('moving a letter retires the old binding, keeps its deadline and decreases finite routing uses', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(1), [0, 1], Q)));
  const original = ok(runtime.markLetters(source.id, [binding(2)], 0, 30, 'work', 6 * Q)).objects[0];
  const moved = ok(runtime.moveLetter(original.id, binding(3))).objects[0];
  assert.equal(moved.expiresAtTick, original.expiresAtTick);
  assert.equal(runtime.ledger.getOwnedLots(moved.id)[0].remainingUses, 6);
  const oldWord = ok(runtime.acceptManual(receipt('old-word', compiled, session(2))));
  error(runtime.redeemLetters(oldWord.id, 0), 'INSUFFICIENT_RESOURCE');
  const newWord = ok(runtime.acceptManual(receipt('new-word', compiled, session(3))));
  const before = runtime.balance(0, 'work');
  ok(runtime.redeemLetters(newWord.id, 0));
  assert.equal(runtime.balance(0, 'work'), before + Q);
  const returned = runtime.ledger.getOwnedLots(0).find(lot => lot.parentLots.length > 0);
  assert.equal(returned.origin.receiptId, 'source'); assert.equal(returned.remainingUses, 6);
  error(runtime.moveLetter(original.id, binding(4)), 'STALE_RESOURCE_OWNER');
});

test('unused letters and paid guard rewards expire without release or cross-room recovery', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(1), [0, 1], 2 * Q)));
  ok(runtime.markLetters(source.id, [binding(2), binding(3)], 0, 30, 'guard', 6 * Q));
  const recipient = ok(runtime.acceptManual(receipt('guard', compiled, session(2))));
  ok(runtime.redeemLetters(recipient.id, 0));
  const shield = runtime.active('shell')[0];
  assert.equal(runtime.balance(shield.id, 'power'), 6 * Q);
  assert.equal(ok(runtime.guard(shield.id, 'enemy-hit', 2 * Q)).blockedPowerQ, 2 * Q);
  const executor = new SpellRuleExecutor(runtime, { flightLifeTicks: 120, selectTarget: () => undefined,
    mark: () => { throw new Error('Unexpected Mark'); }, supply: () => { throw new Error('Unexpected Supply'); } });
  let launched = 0;
  const lifecycle = new SpellLifecycle(executor, { flightLifeTicks: 120, isAlive: () => true, target: () => ({ id: 8, x: 0, y: 0 }),
    launch: () => launched++, damage: () => {}, boundary: () => {} });
  lifecycle.advance(30);
  assert.equal(runtime.active('letter').length, 0); assert.equal(runtime.active('shell').length, 0);
  assert.equal(runtime.reserveEntries().length, 0); assert.equal(launched, 0);
  assert.deepEqual(lifecycle.diagnostics, []);
});

test('spread selection uses different matching words and stale word revisions cannot keep a mark', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program(['T31', 'T33']);
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(1), [0, 1], 2 * Q)));
  ok(runtime.commitHit(source.id, 5)); // The last manual attack is already spent when input is interrupted.
  let words = [2, 3].map(id => ({ session: session(id), position: { x: id * 10, y: 0 }, entered: 0 }));
  const adapter = new LetterOpportunities(runtime, () => words);
  const executor = new SpellRuleExecutor(runtime, { flightLifeTicks: 120, selectTarget: () => undefined,
    supply: () => { throw new Error('Unexpected Supply'); }, mark: (context, op) => adapter.mark(context, op) });
  const event = { id: 'interrupt', subject: runtime.getObject(source.id), event: 'word.interrupted', stage: 'income', tick: 0, counters: {},
    interrupted: { session: session(9), humanPositions: [0, 1], position: { x: 0, y: 0 } } };
  assert.deepEqual(executor.execute(event).errors, []);
  assert.deepEqual(runtime.active('letter').map(letter => letter.targetId), [2, 3]);
  assert.equal(runtime.balance(0, 'opportunity'), 0);
  executor.execute({ ...event, id: 'different-interrupt' });
  assert.equal(runtime.active('letter').length, 2);
  adapter.update(0); assert.equal(adapter.motes.length, 2);
  const old = runtime.active('letter')[0], uses = runtime.ledger.getOwnedLots(old.id)[0].remainingUses;
  words = [{ ...words[0], session: session(2, 2) }, words[1]];
  adapter.moveLost();
  assert.notDeepEqual(runtime.getObject(old.id).letter.binding.session, old.letter.binding.session);
  assert.equal(runtime.ledger.getOwnedLots(old.id)[0].remainingUses, uses - 1);
});

test('a real acquired scatter relic uses the native budget, matches manual input, and keeps same-text sessions distinct', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  game.relics['letters-dust'] = 1;
  const enemy = (x) => { const e = game.spawnEnemy('nib', x, 300); e.hp = e.maxHp = 100000; e.grace = 0; return e; };
  const first = enemy(500), interrupted = enemy(600), recipient = enemy(700);
  assert.equal(game.nativeSpells.enabled, true);
  type(game, first);
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.balance(0, 'opportunity'), Math.floor(5 * Q / 3)); // Flame heat, work and letters share one input budget.
  game.cancel(false); game.target = interrupted; game.input('a'); game.input('l');
  game.kill(interrupted, 1, false);
  assert.equal(runtime.active('letter').length, 1);
  assert.equal(game.weave.letters.length, 0);
  assert.ok(game.nativeSpells.letterMotes.length > 0);
  assert.deepEqual(game.nativeSpells.letterMotes[0].start, { x: interrupted.x, y: interrupted.y - 30 });
  const marked = runtime.active('letter')[0].letter.binding.session;
  const target = game.enemies.find(e => e.id === marked.targetId);
  const oldRevision = target.wordRevision;
  Object.assign(target, game.wordFor(false, target));
  assert.notEqual(target.wordRevision, oldRevision);
  assert.equal(target.word, marked.word); // Single-word pool repeats the text, not the session.
  game.nativeSpells.advance();
  assert.ok(runtime.active('letter').every(letter => letter.letter.binding.session.revision !== oldRevision
    || letter.letter.binding.session.targetId !== target.id));
  game.cancel(false);
  const finalTarget = game.enemies.find(e => e.id === runtime.active('letter')[0].targetId);
  const before = runtime.active('letter').length;
  type(game, finalTarget);
  assert.ok(runtime.active('letter').length < before);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
  assert.equal(runtime.manualCount, 2);
  game.nativeSpells.clearRoom();
  assert.equal(game.nativeSpells.letterMotes.length, 0);
  assert.equal(game.player.spellShield, 0);
});

test('matched guard allocation pays real incoming damage and expires without another attack', () => {
  const game = isolate(createGame(['alpha'], 'flame')); game.relics['letters-dust'] = 1;
  const enemy = x => { const e = game.spawnEnemy('nib', x, 300); e.hp = e.maxHp = 100000; e.grace = 0; return e; };
  const source = enemy(500), next = enemy(600); type(game, source);
  const runtime = game.nativeSpells.runtime, root = runtime.active('spell')[0];
  ok(runtime.markLetters(root.id, [binding(next.id, 0, next.wordRevision, next.word)], 0, 60, 'guard', 6 * Q));
  type(game, next);
  assert.equal(game.player.spellShield, 6);
  const hp = game.player.hp;
  game.player.invuln = 0; game.hurt(3);
  assert.equal(game.player.hp, hp); assert.equal(game.player.spellShield, 3);
  assert.equal(runtime.balance(runtime.active('shell')[0].id, 'power'), 3 * Q);
  game.time = 2; game.player.invuln = 0;
  game.hurt(2); // A deadline cannot be bypassed by hurting before the next simulation update.
  assert.equal(game.player.hp, hp - 2);
  game.nativeSpells.advance();
  assert.equal(game.player.spellShield, 0); assert.equal(runtime.active('shell').length, 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('planned reward partitions each source lot once and funds one merged paper page', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const a = ok(runtime.acceptManual(receipt('a', compiled, session(9), [0], Q)));
  ok(runtime.acceptManual(receipt('b', compiled, session(8), [0], Q)));
  const chosen = plan({ opportunityCostQ: 2 * Q });
  const letter = ok(runtime.markLetters(a.id, [binding(2)], 0, 50, 'power', 5 * Q, 0, undefined, chosen)).objects[0];
  assert.equal(letter.letter.plan.storedShare, .25);
  chosen.storedShare = 0;
  assert.equal(letter.letter.plan.storedShare, .25);
  assert.equal(Object.isFrozen(letter.letter.plan), true);
  const recipient = ok(runtime.acceptManual(receipt('recipient', compiled, session(2), [0], 0, 0,
    { position: { x: 13, y: 7 } })));
  const redeemed = ok(runtime.redeemLetters(recipient.id, 0));
  assert.equal(redeemed.matchedCount, 1);
  assert.equal(runtime.balance(recipient.id, 'power'), 20 * Q + 5 * Q);
  const page = redeemed.objects.find(object => object.kind === 'shell');
  assert.ok(page); assert.equal(runtime.balance(page.id, 'power'), 5 * Q / 4);
  assert.equal(runtime.balance(0, 'work'), 6 * Q + Q / 4);
  assert.deepEqual(page.position, { x: 13, y: 7 });
  assert.equal(page.targetId, 2); assert.equal(page.readyAtTick, 2); assert.equal(page.expiresAtTick, 40);
  assert.deepEqual(page.properties, { material: 'paper', integrity: 1 });
  assert.equal(page.letter, undefined); assert.equal(page.field, undefined); assert.equal(page.status, undefined);
  const pageLots = runtime.ledger.getOwnedLots(page.id);
  assert.deepEqual(pageLots.map(lot => lot.origin.receiptId).sort(), ['a', 'b']);
  assert.ok(pageLots.every(lot => lot.remainingUses === 6));
  assert.equal(redeemed.transaction.facts.some(fact => fact.kind === 'income'), false);
  error(runtime.redeemLetters(recipient.id, 0), 'INSUFFICIENT_RESOURCE');
});

test('planned share rounds per lot, and exhausted processing falls back to direct power', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const first = ok(runtime.acceptManual(receipt('tiny-a', compiled, session(8), [0], 1)));
  ok(runtime.acceptManual(receipt('tiny-b', compiled, session(9), [0], 2)));
  ok(runtime.markLetters(first.id, [binding(2)], 0, 50, 'power', Q, 0, undefined,
    plan({ opportunityCostQ: 3, workShare: .5, storedShare: .5, workRetention: 0, storedRetention: 0 })));
  const recipient = ok(runtime.acceptManual(receipt('tiny-recipient', compiled, session(2), [0])));
  const result = ok(runtime.redeemLetters(recipient.id, 0));
  assert.equal(runtime.balance(recipient.id, 'power'), 20 * Q + 1);
  assert.equal(result.objects.filter(object => object.kind === 'shell').length, 0);
  assert.equal(result.transaction.facts.filter(fact => fact.kind === 'spend' && fact.reason === 'loss')
    .reduce((sum, fact) => sum + fact.quantityQ, 0), 2);
  const exhausted = new SpellResourceRuntime(1);
  const source = ok(exhausted.acceptManual(receipt('one-use', compiled, session(9), [0], Q, 0,
    { processingUses: 1 })));
  ok(exhausted.markLetters(source.id, [binding(2)], 0, 50, 'power', 6 * Q, 0, undefined,
    plan({ workShare: .5, storedShare: .5 })));
  const target = ok(exhausted.acceptManual(receipt('target', compiled, session(2), [0])));
  const fallback = ok(exhausted.redeemLetters(target.id, 0));
  assert.equal(exhausted.balance(target.id, 'power'), 26 * Q);
  assert.equal(fallback.objects.some(object => object.kind === 'shell'), false);
});

test('different roots and plans isolate pages; shared capacity redirects saved share to current spell', () => {
  const compiled = program(), runtime = new SpellResourceRuntime(1);
  const a = ok(runtime.acceptManual(receipt('root-a', compiled, session(8), [0], Q)));
  const b = ok(runtime.acceptManual(receipt('root-b', compiled, session(9), [0], Q)));
  const single = plan({ storedShare: 1, workShare: 0, storedRetention: 1, capacity: 1 });
  ok(runtime.markLetters(a.id, [binding(2, 0)], 0, 50, 'power', Q, 0, undefined, single));
  ok(runtime.markLetters(b.id, [binding(2, 1)], 0, 50, 'power', Q, 0, undefined, single));
  const recipient = ok(runtime.acceptManual(receipt('target', compiled, session(2))));
  const result = ok(runtime.redeemLetters(recipient.id, 0));
  assert.equal(result.matchedCount, 2);
  assert.equal(result.objects.filter(object => object.kind === 'shell').length, 1);
  assert.equal(runtime.balance(recipient.id, 'power'), 21 * Q);
  assert.equal(runtime.balance(runtime.active('shell')[0].id, 'power'), Q);
  const other = new SpellResourceRuntime(1);
  const source = ok(other.acceptManual(receipt('source', compiled, session(9), [0], 2 * Q)));
  ok(other.markLetters(source.id, [binding(2, 0)], 0, 50, 'power', Q, 0, undefined,
    plan({ storedShare: 1, workShare: 0, storedRetention: 1 })));
  ok(other.markLetters(source.id, [binding(2, 1)], 0, 50, 'power', Q, 0, undefined,
    plan({ storedShare: 1, workShare: 0, storedRetention: .5 })));
  const target = ok(other.acceptManual(receipt('target', compiled, session(2))));
  assert.equal(ok(other.redeemLetters(target.id, 0)).objects.filter(object => object.kind === 'shell').length, 2);
});

test('same source and plan merge into one page with the original spell applications', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(9), [0], 2 * Q, 0,
    { shape: 'burst', applications: 3 })));
  ok(runtime.commitHit(source.id, 1));
  const chosen = plan({ storedShare: 1, workShare: 0, storedRetention: 1, inheritShape: true });
  ok(runtime.markLetters(source.id, [binding(2, 0), binding(2, 1)], 0, 50, 'power', Q, 0, undefined, chosen));
  const target = ok(runtime.acceptManual(receipt('target', compiled, session(2))));
  const result = ok(runtime.redeemLetters(target.id, 0));
  const pages = result.objects.filter(object => object.kind === 'shell');
  assert.equal(result.matchedCount, 2); assert.equal(pages.length, 1);
  assert.equal(runtime.balance(pages[0].id, 'power'), 2 * Q);
  assert.equal(pages[0].shape, 'burst'); assert.equal(pages[0].remainingApplications, 3);
  assert.equal(pages[0].inheritedShape, true);
});

test('invalid plans fail atomically without consuming the next letter id', () => {
  const runtime = new SpellResourceRuntime(1), compiled = program();
  const source = ok(runtime.acceptManual(receipt('source', compiled, session(9), [0], Q)));
  const before = runtime.ledger.snapshot();
  for (const invalid of [plan({ storedShare: .8, workShare: .3 }), plan({ capacity: 0 }),
    plan({ delayTicks: 0 }), plan({ lifeTicks: 72001 }), plan({ opportunityCostQ: 0 }),
    plan({ maxPerWord: 73 }), plan({ workRetention: NaN }), plan({ spread: 1 }), plan({ extra: true })]) {
    error(runtime.markLetters(source.id, [binding(2)], 0, 50, 'power', Q, 0, undefined, invalid), 'INVALID_QUANTITY');
  }
  error(runtime.markLetters(source.id, [binding(2)], 0, 50, 'guard', Q, 0, undefined, plan()), 'INVALID_QUANTITY');
  assert.deepEqual(runtime.ledger.snapshot(), before);
  const letter = ok(runtime.markLetters(source.id, [binding(2)], 0, 50, 'power', Q, 0, undefined, plan())).objects[0];
  assert.equal(letter.id, source.id + 1);
});

test('simultaneously redeemed shields reserve space and equivalent plan key order does not split a page', () => {
  for (const guard of [false, true]) {
    const runtime = new SpellResourceRuntime(1), compiled = program();
    const source = ok(runtime.acceptManual(receipt('source', compiled, session(9), [0], 2 * Q)));
    const allocation = plan({ storedShare: 1, workShare: 0, storedRetention: 1, capacity: 1 });
    ok(runtime.markLetters(source.id, [binding(2, 0)], 0, 50, 'power', Q, 0, undefined, allocation));
    ok(runtime.markLetters(source.id, [binding(2, 1)], 0, 50, guard ? 'guard' : 'power', Q, 0, undefined,
      guard ? undefined : Object.fromEntries(Object.entries(allocation).reverse())));
    const recipient = ok(runtime.acceptManual(receipt('recipient', compiled, session(2), [0, 1], 0, 0, { targetId: 3 })));
    const redeemed = ok(runtime.redeemLetters(recipient.id, 0));
    assert.equal(runtime.active('shell').length, 1);
    assert.equal(runtime.balance(recipient.id, 'power'), (guard ? 21 : 20) * Q);
    const page = runtime.active('shell')[0];
    assert.equal(runtime.balance(page.id, 'power'), (guard ? 1 : 2) * Q);
    if (!guard) assert.equal(page.targetId, 3); // The original word target may already have died.
    assert.equal(redeemed.matchedCount, 2);
  }
});

function letterBattle(talents, relics = {}, book = 'flame') {
  const game = isolate(createGame(['aaaabbbbcccc'], book));
  game.config = { ...game.config, talents }; Object.assign(game.relics, relics);
  const spawn = x => { const e = game.spawnEnemy('nib', x, 300); e.hp = e.maxHp = 100000; e.grace = 0; return e; };
  const source = spawn(500), interrupted = spawn(600), first = spawn(700), second = spawn(800);
  type(game, source); assert.equal(game.nativeSpells.enabled, true);
  const runtime = game.nativeSpells.runtime, sourceId = runtime.active('spell').find(object => !object.derived).id;
  game.cancel(false); game.target = interrupted; for (let i = 0; i < 3; i++) game.input('a');
  game.kill(interrupted, 1, false);
  return { game, runtime, sourceId, first, second, spawn };
}

test('real letter rewards save one paid page, dispatch a match event and use ordinary guard and release rules', () => {
  const { game, runtime, sourceId } = letterBattle(['T31', 'T32', 'T21', 'T22']);
  assert.equal(runtime.active('letter').length, 3);
  const target = game.enemies.find(enemy => enemy.id === runtime.active('letter')[0].targetId);
  const results = [], redeem = runtime.redeemLetters.bind(runtime);
  runtime.redeemLetters = (...args) => { const before = runtime.balance(args[0], 'power'), result = redeem(...args);
    if (result.ok) results.push({ before, after: runtime.balance(args[0], 'power'), result: result.value }); return result; };
  const executor = game.nativeSpells.current.lifecycle.executor, execute = executor.execute.bind(executor), events = [];
  executor.execute = event => { if (event.event === 'letter.match') events.push(event); return execute(event); };
  type(game, target);
  const reward = results[0], page = reward.result.objects.find(object => object.kind === 'shell');
  assert.equal(reward.after - reward.before, 9 * Q); assert.equal(runtime.balance(page.id, 'power'), 3 * 2611);
  assert.equal(page.rootReceiptId, runtime.getObject(sourceId).rootReceiptId);
  assert.equal(page.shape, 'shot'); assert.equal(page.remainingApplications, 1);
  assert.deepEqual(events.map(event => [event.stage, event.counters.matchedCharacters]), [['income', 3], ['assemble', 3]]);
  assert.equal(game.nativeSpells.savedPages.length, 1);
  game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa');
  assert.equal(game.nativeSpells.intercept(game.bullets[0], 2), 2);
  assert.equal(runtime.getObject(page.id).state, 'closed');
  const exit = runtime.active('spell').find(object => object.exitOf === page.id); assert.ok(exit);
  assert.equal(runtime.balance(exit.id, 'power'), 3 * 2611 - 2 * Q);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('reward and spread modes combine, keep one mark per word and preserve routing when a word disappears', () => {
  const { game, runtime, first, second, spawn } = letterBattle(['T31', 'T32', 'T33', 'K14', 'K15']);
  const letters = runtime.active('letter'); assert.equal(letters.length, 2);
  assert.deepEqual(letters.map(letter => letter.targetId), [first.id, second.id]);
  assert.ok(letters.every(letter => letter.letter.plan.maxPerWord === 1 && letter.letter.plan.workShare === .25 && letter.letter.plan.storedShare === .375));
  const before = runtime.ledger.getOwnedLots(letters[0].id)[0], expiry = letters[0].expiresAtTick;
  game.kill(first, 1, false); const last = spawn(900); game.nativeSpells.advance();
  const moved = runtime.getObject(letters[0].id); assert.equal(moved.targetId, last.id);
  assert.equal(moved.expiresAtTick, expiry);
  assert.equal(runtime.ledger.getOwnedLots(moved.id)[0].remainingUses, before.remainingUses - 1);
  const results = [], redeem = runtime.redeemLetters.bind(runtime);
  runtime.redeemLetters = (...args) => { const work = runtime.balance(0, 'work'), power = runtime.balance(args[0], 'power');
    const result = redeem(...args); if (result.ok) results.push({ result: result.value, work: runtime.balance(0, 'work') - work,
      power: runtime.balance(args[0], 'power') - power }); return result; };
  type(game, last);
  assert.equal(results[0].work, 217); assert.equal(results[0].power, 2304);
  const page = results[0].result.objects.find(object => object.kind === 'shell'); assert.equal(runtime.balance(page.id, 'power'), 1958);
  game.time = 2; game.nativeSpells.advance();
  assert.equal(runtime.getObject(page.id).state, 'closed');
  assert.ok(runtime.active('spell').some(object => object.exitOf === page.id));
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('concentrated marks pay twice the opportunity; acquired storage cannot rewrite already-bound rewards', () => {
  const paid = letterBattle(['T31'], { R127: 1 });
  assert.equal(paid.runtime.active('letter').length, 2);
  assert.ok(paid.runtime.active('letter').every(letter => paid.runtime.balance(letter.id, 'opportunity') === 2 * Q));
  const { game, runtime } = letterBattle(['T31']);
  const target = game.enemies.find(enemy => enemy.id === runtime.active('letter')[0].targetId);
  game.config = { ...game.config, talents: ['T31', 'T32'] };
  const redeem = runtime.redeemLetters.bind(runtime), results = [];
  runtime.redeemLetters = (...args) => { const result = redeem(...args); if (result.ok) results.push(result.value); return result; };
  type(game, target);
  assert.equal(results[0].objects.some(object => object.kind === 'shell'), false);
  assert.equal(runtime.active('shell').length, 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('letter-made pages inherit an already paid shape with a real retention cost and no copied materials', () => {
  const { game, runtime, sourceId } = letterBattle(['T31', 'T32', 'T19', 'T20', 'N24-01', 'N24-02', 'N24-03'], { R125: 1, R134: 1 }, 'frost');
  const original = runtime.getObject(sourceId), letters = runtime.active('letter');
  assert.equal(letters.length, 3); assert.equal(letters[0].letter.plan.storedShare, .75);
  assert.ok(Math.abs(letters[0].letter.plan.storedRetention - .84) < 1e-12);
  const target = game.enemies.find(enemy => enemy.id === letters[0].targetId);
  const results = [], redeem = runtime.redeemLetters.bind(runtime);
  runtime.redeemLetters = (...args) => { const result = redeem(...args); if (result.ok) results.push(result.value); return result; };
  type(game, target);
  const page = results[0].objects.find(object => object.kind === 'shell');
  assert.equal(page.shape, original.shape); assert.equal(page.remainingApplications, original.remainingApplications);
  assert.equal(page.inheritedShape, true); assert.ok(runtime.balance(page.id, 'power') > 0);
  assert.equal(runtime.balance(page.id, 'cold'), 0); assert.equal(runtime.balance(page.id, 'heat'), 0); assert.equal(runtime.balance(page.id, 'charge'), 0);
  game.time = 2; game.nativeSpells.advance();
  const exit = runtime.active('spell').find(object => object.exitOf === page.id); assert.ok(exit);
  assert.equal(exit.shape, original.shape); assert.equal(runtime.manualCount, 2);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});
