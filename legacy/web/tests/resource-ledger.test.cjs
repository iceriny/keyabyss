'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { ResourceLedger } = require('../src/simulation/spells/ResourceLedger.ts');

const Q = 1024;
const max = Number.MAX_SAFE_INTEGER;
const definitions = [
  { id: 'power', maxQuantityQ: max, allowedOrigins: ['manual', 'enemyProjectile'] },
  { id: 'work', maxQuantityQ: max, allowedOrigins: ['manual'] },
  { id: 'cold', maxQuantityQ: max, allowedOrigins: ['manual', 'acquisition'] },
  { id: 'heat', maxQuantityQ: max, allowedOrigins: ['manual'] },
];
const conversions = [
  { id: 'chill', from: 'power', to: 'cold', numerator: 2, denominator: 3, origins: ['manual'] },
];
const ledger = () => new ResourceLedger(definitions, conversions);
const ok = result => { assert.equal(result.ok, true, JSON.stringify(result)); return result.value; };
const error = (result, code) => {
  assert.equal(result.ok, false, JSON.stringify(result));
  assert.equal(result.errors[0].code, code);
};
const issue = (book, receiptId, ownerId, grants, kind = 'manual') =>
  ok(book.issue({ origin: { kind, receiptId }, ownerId, grants }));
const grant = (resource, quantityQ, remainingUses = 3) => ({ resource, quantityQ, remainingUses });
const tx = (id, expects, rest = {}) => ({ id, expects, ...rest });
const version = (book, ownerId) => ({ ownerId, version: book.getOwner(ownerId).version });

test('one receipt atomically funds separate primary and work owners', () => {
  const book = ledger();
  const result = issue(book, 'split-income', 1, [grant('power', 100), { ...grant('work', 12), ownerId: 0 }]);
  assert.deepEqual(result.lotIds.map(id => book.getLot(id).ownerId), [1, 0]);
  assert.equal(book.getOwner(0).version, 1); assert.equal(book.getOwner(1).version, 1);
  const before = book.snapshot();
  error(book.issue({ origin: { kind: 'manual', receiptId: 'split-overflow' }, ownerId: 2,
    grants: [grant('power', 1), { ...grant('work', max), ownerId: 0 }] }), 'RESOURCE_LIMIT');
  assert.deepEqual(book.snapshot(), before); assert.equal(book.getOwner(2), undefined);
});

test('active owner lookup excludes consumed lots and follows only committed ownership changes', () => {
  const book = ledger(), [lot] = issue(book, 'lookup', 1, [grant('power', 10)]).lotIds;
  error(book.commit(tx('lookup-fail', [version(book, 1)], { opens: [2], transfers: [{ lotId: lot, toOwnerId: 2, uses: 4 }] })), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(book.getOwnedLots(1).map(part => part.lotId), [lot]); assert.deepEqual(book.getOwnedLots(2), []);
  ok(book.commit(tx('lookup-move', [version(book, 1)], { opens: [2], transfers: [{ lotId: lot, toOwnerId: 2, uses: 1 }], closes: [1] })));
  assert.deepEqual(book.getOwnedLots(1), []); assert.deepEqual(book.getOwnedLots(2).map(part => part.lotId), [lot]);
  ok(book.commit(tx('lookup-spend', [version(book, 2)], { spends: [{ lotId: lot, quantityQ: 10, reason: 'attack' }] })));
  assert.deepEqual(book.getOwnedLots(2), []); assert.equal(book.getLot(lot).quantityQ, 0);
});

test('registered conversion rates remain immutable when later builds add new rates', () => {
  const book = ledger();
  book.registerConversion(conversions[0]);
  assert.throws(() => book.registerConversion({ ...conversions[0], numerator: 3 }), /Invalid resource conversion/);
  book.registerConversion({ ...conversions[0], id: 'stronger-chill', numerator: 3 });
  const [lot] = issue(book, 'conversion-snapshot', 1, [grant('power', 3)]).lotIds;
  const result = ok(book.commit(tx('old-conversion', [version(book, 1)], { creates: [{ ownerId: 1, resource: 'cold',
    funding: [{ lotId: lot, quantityQ: 3 }], conversionId: 'chill', quantityQ: 2, remainingUses: 1 }] })));
  assert.equal(book.getLot(result.createdLotIds[0]).quantityQ, 2);
});

test('100 shares pay attack, guard and release exactly once; overshoot never returns', () => {
  const book = ledger();
  const [source] = issue(book, 'word-1', 1, [grant('power', 100 * Q)]).lotIds;
  const result = ok(book.commit(tx('allocate', [version(book, 1)], {
    opens: [2, 3, 4],
    spends: [{ lotId: source, quantityQ: 40 * Q, reason: 'attack' }],
    creates: [
      { ownerId: 2, resource: 'power', funding: [{ lotId: source, quantityQ: 12 * Q }], quantityQ: 12 * Q, remainingUses: 2 },
      { ownerId: 3, resource: 'power', funding: [{ lotId: source, quantityQ: 18 * Q }], quantityQ: 18 * Q, remainingUses: 2 },
    ],
    transfers: [{ lotId: source, toOwnerId: 4, uses: 1 }],
  })));
  assert.equal(book.getLot(source).quantityQ, 30 * Q);
  assert.equal(book.getLot(source).ownerId, 4);
  assert.deepEqual(result.createdLotIds.map(id => book.getLot(id).quantityQ), [12 * Q, 18 * Q]);
  assert.equal(result.facts[0].quantityQ, 40 * Q);
  assert.equal(40 + 12 + 18 + 30, 100);
  error(book.commit(tx('overshoot-return', [version(book, 4)], {
    spends: [{ lotId: source, quantityQ: 15 * Q, reason: 'attack' }, { lotId: source, quantityQ: 16 * Q, reason: 'attack' }],
  })), 'INSUFFICIENT_RESOURCE');
  assert.equal(book.getLot(source).quantityQ, 30 * Q);
});

test('competing closure rights and multi-cost failures leave no partial changes or ID gaps', () => {
  const book = ledger();
  const [power, work] = issue(book, 'word-2', 1, [grant('power', 10), grant('work', 4)]).lotIds;
  const before = book.snapshot();
  error(book.commit(tx('bad-cost', [version(book, 1)], {
    opens: [2], spends: [
      { lotId: power, quantityQ: 3, reason: 'processing' },
      { lotId: work, quantityQ: 5, reason: 'processing' },
    ], creates: [{ ownerId: 2, resource: 'power', funding: [{ lotId: power, quantityQ: 2 }], quantityQ: 2, remainingUses: 1 }],
  })), 'INSUFFICIENT_RESOURCE');
  assert.deepEqual(book.snapshot(), before);
  const first = ok(book.commit(tx('finish-heat', [version(book, 1)], {
    opens: [2], transfers: [{ lotId: power, toOwnerId: 2, uses: 1 }],
  })));
  assert.equal(first.owners.find(owner => owner.ownerId === 2).version, 1);
  error(book.commit(tx('finish-expire', [{ ownerId: 1, version: 1 }], {
    opens: [3], transfers: [{ lotId: power, toOwnerId: 3, uses: 1 }],
  })), 'STALE_RESOURCE_OWNER');
  const created = ok(book.commit(tx('split', [version(book, 2)], {
    creates: [{ ownerId: 2, resource: 'power', funding: [{ lotId: power, quantityQ: 1 }], quantityQ: 1, remainingUses: 1 }],
  })));
  assert.deepEqual(created.createdLotIds, [3]);
});

test('receipt and transaction identity is idempotent and conflicts on changed content', () => {
  const book = ledger();
  const receipt = { origin: { kind: 'manual', receiptId: 'word-3' }, ownerId: 1, grants: [grant('power', 9)] };
  const first = ok(book.issue(receipt));
  assert.deepEqual(ok(book.issue({ grants: [grant('power', 9)], ownerId: 1, origin: { receiptId: 'word-3', kind: 'manual' } })), first);
  error(book.issue({ ...receipt, grants: [grant('power', 10)] }), 'RECEIPT_CONFLICT');
  const transaction = tx('use', [version(book, 1)], { spends: [{ lotId: first.lotIds[0], quantityQ: 3, reason: 'attack' }] });
  const spent = ok(book.commit(transaction));
  assert.deepEqual(ok(book.commit(transaction)), spent);
  error(book.commit({ ...transaction, spends: [{ lotId: first.lotIds[0], quantityQ: 4, reason: 'attack' }] }), 'RECEIPT_CONFLICT');
  assert.equal(book.getLot(first.lotIds[0]).quantityQ, 6);
});

test('funding cannot mix roots or units; every existing affected owner needs a version', () => {
  const book = ledger();
  const [power, work] = issue(book, 'word-4', 1, [grant('power', 10), grant('work', 10)]).lotIds;
  const [other] = issue(book, 'word-5', 2, [grant('power', 10)]).lotIds;
  const base = { ownerId: 1, resource: 'power', quantityQ: 2, remainingUses: 1 };
  error(book.commit(tx('unit', [version(book, 1)], {
    creates: [{ ...base, funding: [{ lotId: work, quantityQ: 2 }] }],
  })), 'INVALID_UNIT');
  error(book.commit(tx('root', [version(book, 1), version(book, 2)], {
    creates: [{ ...base, funding: [{ lotId: power, quantityQ: 1 }, { lotId: other, quantityQ: 1 }] }],
  })), 'INVALID_RESOURCE_TRANSACTION');
  error(book.commit(tx('missing-destination', [version(book, 1)], {
    transfers: [{ lotId: power, toOwnerId: 2, uses: 0 }],
  })), 'STALE_RESOURCE_OWNER');
  assert.equal(book.getLot(power).quantityQ, 10);
});

test('conversions floor exactly with BigInt and ordinary resources cannot mint work', () => {
  const book = ledger();
  const [power] = issue(book, 'word-6', 1, [grant('power', 10)]).lotIds;
  const created = ok(book.commit(tx('convert', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'cold', funding: [{ lotId: power, quantityQ: 10 }],
      conversionId: 'chill', quantityQ: 6, remainingUses: 2 }],
  })));
  assert.equal(book.getLot(created.createdLotIds[0]).quantityQ, 6);
  assert.equal(book.getLot(power).quantityQ, 0);
  const [more] = issue(book, 'word-7', 1, [grant('power', 3)]).lotIds;
  error(book.commit(tx('wrong-rate', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'cold', funding: [{ lotId: more, quantityQ: 3 }],
      conversionId: 'chill', quantityQ: 3, remainingUses: 2 }],
  })), 'INVALID_QUANTITY');
  assert.throws(() => new ResourceLedger(definitions, [{ id: 'recycle', from: 'power', to: 'work',
    numerator: 1, denominator: 1, origins: ['manual'] }]), /Invalid resource conversion/);
  const big = ledger();
  const [large] = issue(big, 'huge-conversion', 1, [grant('power', max)]).lotIds;
  const expected = Number(BigInt(max) * 2n / 3n);
  const [converted] = ok(big.commit(tx('big-convert', [version(big, 1)], { creates: [
    { ownerId: 1, resource: 'cold', funding: [{ lotId: large, quantityQ: max }],
      conversionId: 'chill', quantityQ: expected, remainingUses: 1 },
  ] }))).createdLotIds;
  assert.equal(big.getLot(converted).quantityQ, expected);
});

test('manual opportunity converts to work without new income and preserves processing history', () => {
  const book = new ResourceLedger([...definitions,
    { id: 'opportunity', maxQuantityQ: max, allowedOrigins: ['manual'] }]);
  const parity = { id: 'redeem', from: 'opportunity', to: 'work', numerator: 1, denominator: 1, origins: ['manual'] };
  book.registerConversion(parity);
  book.registerConversion({ ...parity, id: 'discount', numerator: 1, denominator: 2 });
  const [root] = issue(book, 'earned-characters', 1, [grant('opportunity', 10, 3)]).lotIds;
  const [portion] = ok(book.commit(tx('prepare-opportunity', [version(book, 1)], {
    claims: [{ lotId: root, key: 'once', limit: 1, uses: 1 }],
    creates: [{ ownerId: 1, resource: 'opportunity', funding: [{ lotId: root, quantityQ: 4 }],
      quantityQ: 4, remainingUses: 2, claimBonus: 'prepared' }],
  }))).createdLotIds;
  const redemption = tx('redeem-opportunity', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'work', funding: [{ lotId: portion, quantityQ: 4 }],
      conversionId: 'redeem', quantityQ: 4, remainingUses: 2 },
    { ownerId: 1, resource: 'work', funding: [{ lotId: root, quantityQ: 6 }],
      conversionId: 'discount', quantityQ: 3, remainingUses: 1 },
  ] });
  const result = ok(book.commit(redemption));
  assert.deepEqual(result.createdLotIds, [3, 4]);
  assert.deepEqual(result.facts.map(fact => fact.kind), ['create', 'create']);
  assert.deepEqual(ok(book.commit(redemption)), result);
  assert.deepEqual(book.getOwnedLots(1).map(lot => [lot.resource, lot.quantityQ]), [['work', 4], ['work', 3]]);
  for (const [index, parent] of [portion, root].entries()) {
    const child = book.getLot(result.createdLotIds[index]);
    assert.deepEqual(child.origin, { kind: 'manual', receiptId: 'earned-characters' });
    assert.deepEqual(child.parentLots, [parent]);
    assert.deepEqual(child.ruleClaims, { once: 1 });
    assert.deepEqual(child.appliedBonuses, ['prepared']);
    assert.equal(child.remainingUses, index === 0 ? 2 : 1);
  }
  assert.equal(book.getLot(root).quantityQ, 0);
  assert.equal(book.getLot(portion).quantityQ, 0);
  assert.deepEqual(book.snapshot().lots.map(lot => lot.lotId), [1, 2, 3, 4]);
});

test('opportunity redemption rejects excess and mismatched output atomically', () => {
  const book = new ResourceLedger([...definitions,
    { id: 'opportunity', maxQuantityQ: max, allowedOrigins: ['manual'] }], [
    { id: 'discount', from: 'opportunity', to: 'work', numerator: 1, denominator: 2, origins: ['manual'] },
  ]);
  const [root] = issue(book, 'limited-characters', 1, [grant('opportunity', 5)]).lotIds;
  const before = book.snapshot();
  error(book.commit(tx('overdraw-opportunity', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'work', funding: [{ lotId: root, quantityQ: 4 }],
      conversionId: 'discount', quantityQ: 2, remainingUses: 1 },
    { ownerId: 1, resource: 'work', funding: [{ lotId: root, quantityQ: 2 }],
      conversionId: 'discount', quantityQ: 1, remainingUses: 1 },
  ] })), 'INSUFFICIENT_RESOURCE');
  error(book.commit(tx('wrong-opportunity-output', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'work', funding: [{ lotId: root, quantityQ: 5 }],
      conversionId: 'discount', quantityQ: 3, remainingUses: 1 },
  ] })), 'INVALID_QUANTITY');
  assert.deepEqual(book.snapshot(), before);
  const [converted] = ok(book.commit(tx('valid-opportunity', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'work', funding: [{ lotId: root, quantityQ: 5 }],
      conversionId: 'discount', quantityQ: 2, remainingUses: 1 },
  ] }))).createdLotIds;
  assert.equal(converted, 2);
  assert.equal(book.getLot(converted).quantityQ, 2);
});

test('conversion registration cannot mint opportunities or unrestricted work', () => {
  const resources = [...definitions.map(definition => definition.id === 'work'
    ? { ...definition, allowedOrigins: ['manual', 'acquisition'] } : definition),
    { id: 'charge', maxQuantityQ: max, allowedOrigins: ['manual'] },
    { id: 'opportunity', maxQuantityQ: max, allowedOrigins: ['manual', 'acquisition'] }];
  const book = new ResourceLedger(resources);
  const base = { id: 'invalid', from: 'opportunity', to: 'work', numerator: 1, denominator: 1, origins: ['manual'] };
  const forbidden = [
    { ...base, from: 'power' }, { ...base, from: 'cold' }, { ...base, from: 'heat' },
    { ...base, from: 'charge' }, { ...base, numerator: 2 },
    { ...base, origins: ['manual', 'acquisition'] }, { ...base, origins: ['acquisition'] },
    { ...base, to: 'opportunity' }, { ...base, from: 'power', to: 'opportunity' },
    { ...base, numerator: 0 }, { ...base, denominator: 0 },
    { ...base, numerator: 1.5 }, { ...base, denominator: 1.5 },
  ];
  for (const conversion of forbidden)
    assert.throws(() => book.registerConversion(conversion), /Invalid resource conversion/);
  book.registerConversion({ ...base, id: 'manual-only' });
  const [foreign] = issue(book, 'found-opportunity', 1, [grant('opportunity', 2)], 'acquisition').lotIds;
  const before = book.snapshot();
  error(book.commit(tx('foreign-redeem', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'work', funding: [{ lotId: foreign, quantityQ: 2 }],
      conversionId: 'manual-only', quantityQ: 2, remainingUses: 1 },
  ] })), 'INVALID_UNIT');
  assert.deepEqual(book.snapshot(), before);
});

test('same-root merge keeps parents, inherited bonuses and finite uses', () => {
  const book = ledger();
  const [root] = issue(book, 'word-8', 1, [grant('power', 20, 3)]).lotIds;
  const first = ok(book.commit(tx('claim', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'power', funding: [{ lotId: root, quantityQ: 8 }],
      quantityQ: 8, remainingUses: 2, claimBonus: 'gain' }],
  }))).createdLotIds[0];
  assert.deepEqual(book.getLot(root).appliedBonuses, ['gain']);
  error(book.commit(tx('claim-again', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'power', funding: [{ lotId: root, quantityQ: 1 }],
      quantityQ: 1, remainingUses: 2, claimBonus: 'gain' }],
  })), 'DUPLICATE_CLAIM');
  error(book.commit(tx('uses-grow', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'power', funding: [{ lotId: first, quantityQ: 1 }],
      quantityQ: 1, remainingUses: 3 }],
  })), 'INVALID_RESOURCE_TRANSACTION');
  const merged = ok(book.commit(tx('merge', [version(book, 1)], {
    creates: [{ ownerId: 1, resource: 'power', funding: [{ lotId: root, quantityQ: 2 }, { lotId: first, quantityQ: 3 }],
      quantityQ: 5, remainingUses: 1 }],
  }))).createdLotIds[0];
  assert.deepEqual(book.getLot(merged).parentLots, [root, first]);
  assert.deepEqual(book.getLot(merged).appliedBonuses, ['gain']);
  ok(book.commit(tx('move', [version(book, 1)], { opens: [2], transfers: [{ lotId: merged, toOwnerId: 2, uses: 1 }] })));
  assert.equal(book.getLot(merged).remainingUses, 0);
  error(book.commit(tx('move-again', [version(book, 2)], {
    opens: [3], transfers: [{ lotId: merged, toOwnerId: 3, uses: 1 }],
  })), 'INSUFFICIENT_RESOURCE');
});

test('safe integer boundaries, fractional quantities, negative and non-finite values are rejected atomically', () => {
  const book = ledger();
  const [large] = issue(book, 'word-9', 1, [grant('power', max - 3)]).lotIds;
  const before = book.snapshot();
  error(book.issue({ origin: { kind: 'manual', receiptId: 'overflow' }, ownerId: 1,
    grants: [grant('power', 4)] }), 'RESOURCE_LIMIT');
  for (const value of [-1, 1.5, Infinity, NaN, max + 1]) {
    error(book.issue({ origin: { kind: 'manual', receiptId: `bad-${String(value)}` }, ownerId: 9,
      grants: [grant('power', value)] }), 'INVALID_QUANTITY');
  }
  error(book.commit(tx('too-big', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'power', funding: [{ lotId: large, quantityQ: max - 3 }],
      quantityQ: max - 2, remainingUses: 1 },
  ] })), 'INVALID_QUANTITY');
  assert.deepEqual(book.snapshot(), before);
  const third = ok(book.commit(tx('integer-remainder', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'power', funding: [{ lotId: large, quantityQ: 1 }], quantityQ: 1, remainingUses: 1 },
    { ownerId: 1, resource: 'power', funding: [{ lotId: large, quantityQ: 2 }], quantityQ: 2, remainingUses: 1 },
  ] })));
  assert.deepEqual(third.createdLotIds, [2, 3]);
  assert.equal(book.getLot(large).quantityQ, max - 6);
});

test('resource permissions, duplicate transfer and positive-balance close are checked before publication', () => {
  const book = ledger();
  error(book.issue({ origin: { kind: 'enemyProjectile', receiptId: 'enemy-1' }, ownerId: 1,
    grants: [grant('work', 1)] }), 'INVALID_RESOURCE_TRANSACTION');
  error(book.issue({ origin: { kind: 'manual', receiptId: 'unknown' }, ownerId: 1,
    grants: [grant('mystery', 1)] }), 'UNKNOWN_DEFINITION');
  assert.equal(book.getOwner(1), undefined);
  const [lot] = issue(book, 'word-11', 1, [grant('power', 5, 1)]).lotIds;
  error(book.commit(tx('double-transfer', [version(book, 1)], {
    opens: [2], transfers: [
      { lotId: lot, toOwnerId: 2, uses: 1 },
      { lotId: lot, toOwnerId: 1, uses: 0 },
    ],
  })), 'INVALID_RESOURCE_TRANSACTION');
  error(book.commit(tx('close-positive', [version(book, 1)], { closes: [1] })), 'INSUFFICIENT_RESOURCE');
  assert.equal(book.getOwner(2), undefined);
  ok(book.commit(tx('use-and-close', [version(book, 1)], {
    spends: [{ lotId: lot, quantityQ: 5, reason: 'loss' }], closes: [1],
  })));
  assert.equal(book.getOwner(1).closed, true);
  error(book.issue({ origin: { kind: 'manual', receiptId: 'word-12' }, ownerId: 1,
    grants: [grant('power', 1)] }), 'STALE_RESOURCE_OWNER');
  error(book.commit(tx('reopen', [], { opens: [1] })), 'INVALID_RESOURCE_TRANSACTION');
});

test('balance index rolls back failed transfer and permits transfer followed by close', () => {
  const book = new ResourceLedger([{ id: 'power', maxQuantityQ: 10, allowedOrigins: ['manual'] }]);
  const [source] = issue(book, 'bounded-source', 1, [grant('power', 8)]).lotIds;
  const [destination] = issue(book, 'bounded-dest', 2, [grant('power', 5)]).lotIds;
  const before = book.snapshot();
  error(book.commit(tx('over-capacity', [version(book, 1), version(book, 2)], {
    spends: [{ lotId: source, quantityQ: 1, reason: 'processing' }],
    transfers: [{ lotId: source, toOwnerId: 2, uses: 1 }], closes: [1],
  })), 'RESOURCE_LIMIT');
  assert.deepEqual(book.snapshot(), before);
  const committed = ok(book.commit(tx('transfer-and-close', [version(book, 1), version(book, 2)], {
    spends: [{ lotId: destination, quantityQ: 3, reason: 'guard' }],
    transfers: [{ lotId: source, toOwnerId: 2, uses: 1 }], closes: [1],
  })));
  assert.equal(committed.owners.find(owner => owner.ownerId === 1).closed, true);
  assert.equal(book.getLot(source).ownerId, 2);
  error(book.issue({ origin: { kind: 'manual', receiptId: 'over-capacity-receipt' }, ownerId: 2,
    grants: [grant('power', 1)] }), 'RESOURCE_LIMIT');
});

test('conversion output must allow its actual origin', () => {
  const book = new ResourceLedger([
    { id: 'power', maxQuantityQ: 20, allowedOrigins: ['enemyProjectile'] },
    { id: 'cold', maxQuantityQ: 20, allowedOrigins: ['manual'] },
  ], [{ id: 'hostile-chill', from: 'power', to: 'cold', numerator: 1, denominator: 1,
    origins: ['enemyProjectile'] }]);
  const [lot] = issue(book, 'enemy-cast', 1, [grant('power', 5)], 'enemyProjectile').lotIds;
  error(book.commit(tx('hostile-convert', [version(book, 1)], { creates: [
    { ownerId: 1, resource: 'cold', funding: [{ lotId: lot, quantityQ: 5 }],
      conversionId: 'hostile-chill', quantityQ: 5, remainingUses: 1 },
  ] })), 'INVALID_RESOURCE_TRANSACTION');
  assert.equal(book.getLot(lot).quantityQ, 5);
});

test('returned snapshots and results are frozen copies', () => {
  const book = ledger();
  const [id] = issue(book, 'word-10', 1, [grant('power', 5)]).lotIds;
  const lot = book.getLot(id);
  const owner = book.getOwner(1);
  const snap = book.snapshot();
  assert.equal(Object.isFrozen(lot.origin), true);
  assert.equal(Object.isFrozen(snap.lots), true);
  assert.throws(() => snap.lots.push(lot), TypeError);
  assert.throws(() => { lot.quantityQ = 999; }, TypeError);
  assert.throws(() => { owner.version = 999; }, TypeError);
  assert.equal(book.getLot(id).quantityQ, 5);
  assert.equal(book.getOwner(1).version, 1);
});

test('handoff export is atomic, order-independent and consumes only selected reserves', () => {
  const book = ledger();
  const [power, cold, work] = issue(book, 'handoff-source', 1,
    [grant('power', 8), grant('cold', 4), grant('work', 2)]).lotIds;
  const before = book.snapshot();
  assert.deepEqual(ok(book.exportHandoff('empty-room', 1, [])), { id: 'empty-room', lots: [] });
  assert.deepEqual(book.snapshot(), before);
  error(book.exportHandoff('bad-duplicate', 1, [power, power]), 'INVALID_RESOURCE_TRANSACTION');
  error(book.exportHandoff('bad-mixed', 1, [power, work]), 'INVALID_RESOURCE_TRANSACTION');
  error(book.exportHandoff('bad-unknown', 1, [power, 999]), 'INVALID_RESOURCE_TRANSACTION');
  error(book.exportHandoff('bad-owner', 2, [power]), 'STALE_RESOURCE_OWNER');
  assert.deepEqual(book.snapshot(), before);
  const ticket = ok(book.exportHandoff('room-1', 1, [cold, power]));
  assert.deepEqual(ticket.lots.map(lot => lot.sourceLotId), [power, cold]);
  assert.deepEqual(ok(book.exportHandoff('room-1', 1, [power, cold])), ticket);
  error(book.exportHandoff('room-1', 1, [power]), 'RECEIPT_CONFLICT');
  assert.equal(book.getLot(power).quantityQ, 0);
  assert.equal(book.getLot(cold).quantityQ, 0);
  assert.equal(book.getLot(work).quantityQ, 2);
  assert.deepEqual(book.getOwnedLots(1).map(lot => lot.lotId), [work]);
  error(book.exportHandoff('second-room', 1, [power]), 'INVALID_RESOURCE_TRANSACTION');
});

test('handoff keeps provenance, bonuses, claims and uses without repeating a conversion bonus', () => {
  const source = ledger();
  const [root] = issue(source, 'handoff-origin', 1, [grant('power', 9, 3)]).lotIds;
  ok(source.commit(tx('handoff-claim', [version(source, 1)], {
    claims: [{ lotId: root, key: 'chill-limit', limit: 1, uses: 1 }],
    creates: [{ ownerId: 1, resource: 'power', funding: [{ lotId: root, quantityQ: 5 }],
      quantityQ: 5, remainingUses: 1, claimBonus: 'chill-bonus' }],
  })));
  const ticket = ok(source.exportHandoff('with-history', 1, [root]));
  const target = ledger();
  issue(target, 'target-owner', 7, [grant('heat', 1)]);
  const imported = ok(target.importHandoff(ticket, 7));
  const lot = target.getLot(imported.createdLotIds[0]);
  assert.deepEqual(lot.origin, { kind: 'manual', receiptId: 'handoff-origin' });
  assert.deepEqual(lot.parentLots, []);
  assert.deepEqual(lot.appliedBonuses, ['chill-bonus']);
  assert.deepEqual(lot.ruleClaims, { 'chill-limit': 1 });
  assert.equal(lot.remainingUses, 2);
  assert.equal(lot.quantityQ, 4);
  assert.equal(imported.facts[0].kind, 'import');
  error(target.commit(tx('bonus-again', [version(target, 7)], { creates: [
    { ownerId: 7, resource: 'power', funding: [{ lotId: lot.lotId, quantityQ: 1 }],
      quantityQ: 1, remainingUses: 1, claimBonus: 'chill-bonus' },
  ] })), 'DUPLICATE_CLAIM');
  error(target.commit(tx('claim-again', [version(target, 7)], { claims: [
    { lotId: lot.lotId, key: 'chill-limit', limit: 1, uses: 1 },
  ] })), 'DUPLICATE_CLAIM');
  assert.deepEqual(ok(target.importHandoff(ticket, 7)), imported);
  error(target.importHandoff(ticket, 8), 'RECEIPT_CONFLICT');
  error(target.importHandoff({ ...ticket, lots: [{ ...ticket.lots[0], quantityQ: 3 }] }, 7), 'RECEIPT_CONFLICT');
  assert.equal(target.getOwnedLots(7).filter(part => part.resource === 'power').length, 1);
});

test('handoff import rejects capacity and malformed tickets without partial lots or ID gaps', () => {
  const bounded = () => new ResourceLedger([
    { id: 'power', maxQuantityQ: 10, allowedOrigins: ['manual'] },
    { id: 'cold', maxQuantityQ: 10, allowedOrigins: ['manual'] },
    { id: 'opportunity', maxQuantityQ: 10, allowedOrigins: ['manual'] },
  ]);
  const source = bounded();
  const [power, cold] = issue(source, 'bounded-handoff', 1, [grant('power', 6), grant('cold', 4)]).lotIds;
  const [opportunity] = issue(source, 'bounded-opportunity', 1, [grant('opportunity', 1)]).lotIds;
  error(source.exportHandoff('opportunity-ticket', 1, [opportunity]), 'INVALID_RESOURCE_TRANSACTION');
  const ticket = ok(source.exportHandoff('bounded-ticket', 1, [power, cold]));
  const target = bounded();
  const [existing] = issue(target, 'existing', 2, [grant('power', 5)]).lotIds;
  const before = target.snapshot();
  error(target.importHandoff(ticket, 2), 'RESOURCE_LIMIT');
  assert.deepEqual(target.snapshot(), before);
  error(target.importHandoff({ ...ticket, lots: [{ ...ticket.lots[0], appliedBonuses: ['x', 'x'] }] }, 2), 'INVALID_RESOURCE_TRANSACTION');
  error(target.importHandoff({ ...ticket, lots: [{ ...ticket.lots[0], resource: 'opportunity' }] }, 2), 'INVALID_RESOURCE_TRANSACTION');
  assert.deepEqual(target.snapshot(), before);
  ok(target.commit(tx('make-space', [version(target, 2)], {
    spends: [{ lotId: existing, quantityQ: 1, reason: 'loss' }],
  })));
  const imported = ok(target.importHandoff(ticket, 2));
  assert.deepEqual(imported.createdLotIds, [2, 3]);
  assert.deepEqual(ok(target.importHandoff(ticket, 2)), imported);
});
