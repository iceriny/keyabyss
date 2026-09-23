const test = require('node:test');
const assert = require('node:assert/strict');
const { createGame, isolate, step } = require('./harness.cjs');

function game(book = 'frost') { return isolate(createGame([{ word: 'abcdefghijkl', meaning: 'test' }], book)); }
function enemy(g, x = 760, hp = 10000) {
  const e = g.spawnEnemy('nib', x, 400, false, true);
  e.hp = e.maxHp = hp; e.grace = 0; e.word = 'abcdefghijkl'; e.speed = 0; return e;
}
function cast(g, e, damage = 100, letters = 12, kind = 'ice') {
  g.weaveCast(e, damage, letters, target => g.strike(target, damage, { kind, direct: true }));
}

test('lethal first hit preserves crystal/heat reaction and never damages the corpse', () => {
  const g = game(); g.relics.emberink = 1;
  const a = enemy(g, 750, 1), others = [enemy(g, 825), enemy(g, 875), enemy(g, 925)];
  cast(g, a);
  assert.equal(a.dead, true); assert.equal(g.weave.summary.fragments, 3);
  const hp = a.hp; step(g, .6); assert.equal(a.hp, hp);
  assert.ok(others.some(e => e.hp < e.maxHp));
  assert.equal(g.weave.summary.manualCharacters, 12);
});
test('same crystal/heat combination operates on durable targets without any kill', () => {
  const g = game(); g.relics.emberink = 1; const a = enemy(g), b = enemy(g, 840);
  cast(g, a); assert.equal(a.dead, false); assert.ok(g.shots.some(s => s.targetId === b.id));
  assert.equal(g.kills, 0); assert.ok(g.weave.summary.fragments > 0);
});
test('paper copies only paid input, stops without typing, and does not inflate cast statistics', () => {
  const g = game(); g.relics.copyfolio = 2; const e = enemy(g);
  cast(g, e, 100, 11); assert.equal(g.weave.pages.length, 0);
  cast(g, e, 100, 1); assert.equal(g.weave.pages.length, 1);
  const count = g.weave.summary.manualCharacters, casts = g.casts;
  step(g, 7); assert.equal(g.weave.pages.length, 0);
  assert.equal(g.weave.summary.pagesCreated, 1); assert.equal(g.weave.summary.pagesReleased, 1);
  assert.equal(g.weave.summary.manualCharacters, count); assert.equal(g.casts, casts);
});
test('a page has one exit: ordinary defense sacrifices attack, release talent changes that exit', () => {
  const g = game('storm'); g.relics.copyfolio = 1; g.relics.guardseal = 1;
  const e = enemy(g); cast(g, e, 100, 12, 'storm');
  const hp = e.hp; assert.equal(g.weave.block(g), true);
  assert.equal(g.weave.pages.length, 0); assert.equal(e.hp, hp);
  assert.equal(g.weave.block(g), false); assert.equal(g.weave.summary.pagesReleased, 0);
  // A capability provider can be independent of an item ID.
  Object.defineProperty(g, 'stats', { value: { ...g.stats, carrierRelease: 1 } });
  cast(g, e, 100, 12, 'storm'); const before = e.hp;
  assert.equal(g.weave.block(g), true); assert.ok(e.hp < before);
  assert.equal(g.weave.summary.pagesReleased, 1); step(g, 3);
  assert.equal(g.weave.summary.pagesReleased, 1);
});
test('short-lived pages expire; release capability turns expiry into a finite attack', () => {
  const g = game('storm'); g.relics.copyfolio = 1; g.relics.swiftbinding = 1;
  const e = enemy(g); cast(g, e, 100, 8, 'storm'); step(g, 1.2);
  assert.equal(g.weave.summary.pagesReleased, 0); assert.equal(g.weave.pages.length, 0);
  Object.defineProperty(g, 'stats', { value: { ...g.stats, carrierRelease: 1 } });
  cast(g, e, 100, 8, 'storm'); step(g, 1.2);
  assert.equal(g.weave.summary.pagesReleased, 1); assert.equal(g.weave.pages.length, 0);
});
test('carrier branches change count and payload while keeping caps', () => {
  for (const [id, size, damage] of [['scatterfolio', 2, 25], ['heavyfolio', 1, 70]]) {
    const g = game(); g.relics.copyfolio = 2; g.relics[id] = 1;
    cast(g, enemy(g)); assert.equal(g.weave.pages.length, size);
    assert.equal(g.weave.pages[0].damage, damage);
  }
});
test('heat recovery has loss and capacity, preserves paid heat across rooms, and cannot recover copies', () => {
  const g = game('flame'); g.relics.thermalvault = 2;
  cast(g, enemy(g, 750, 1), 100, 12, 'fire');
  assert.ok(g.weave.heat > 0 && g.weave.heat <= 100);
  const heat = g.weave.heat; g.resetArrays(); assert.equal(g.weave.heat, heat);
  const victim = enemy(g, 750, 1); g.applyBurn(victim); g.damage(victim, 100, 1, false);
  assert.equal(g.weave.heat, heat);
  g.weave.reset(); assert.equal(g.weave.heat, 0);
});
test('a pending residual spell releases once and is cancelled on room cleanup', () => {
  const g = game(); const origin = enemy(g, 750, 1); g.kill(origin); let released = 0;
  g.weaveCast(origin, 50, 12, t => { released++; g.strike(t, 50, { direct: true, kind: 'ice' }); });
  assert.equal(released, 0); const target = enemy(g); g.weave.update(g, .01);
  assert.equal(released, 1); g.weave.update(g, .01); assert.equal(released, 1);
  g.kill(target); g.weaveCast(target, 50, 12, () => released++);
  g.resetArrays(); enemy(g); g.weave.update(g, .01); assert.equal(released, 1);
});
test('secondary materials require binding, exclude main book, and use only actual input', () => {
  const g = game(); g.config.secondaryBook = 'flame'; let e = enemy(g);
  cast(g, e); assert.equal(e.burn, undefined);
  Object.defineProperty(g, 'stats', { value: { ...g.stats, secondaryBinding: 1 } });
  cast(g, e, 100, 2); assert.equal(e.burn, undefined);
  cast(g, e, 100, 10); assert.ok(e.burn);
  g.config.secondaryBook = 'frost'; e = enemy(g, 900); cast(g, e); assert.equal(e.burn, undefined);
});
test('root depth and budget reject invalid derived hits and do not generate resources', () => {
  const g = game(); const e = enemy(g); const root = { id: 1, room: g.roomVisit, remaining: 0, primaryClaimed: true, crystal: true, heat: true, conduction: true, reserve: 0 };
  g.strike(e, 100, { kind: 'fire', weave: { root, source: 'carrier', depth: 1 } });
  assert.equal(e.hp, e.maxHp); root.remaining = 32;
  g.strike(e, 100, { kind: 'fire', weave: { root, source: 'carrier', depth: 7 } });
  assert.equal(e.hp, e.maxHp); assert.equal(g.weave.summary.manualCharacters, 0);
});
test('lethal third electric hit discharges from its receipt, without adding status to a corpse', () => {
  const g = game('storm'); const a = enemy(g, 750, 1), b = enemy(g, 810);
  a.conduct = 2; g.strike(a, 100, { kind: 'storm', direct: true });
  assert.equal(a.dead, true); assert.equal(a.conduct, 2);
  assert.equal(g.overloads, 1); assert.ok(b.hp < b.maxHp);
});
test('nearest scan preserves exclusion, strict radius and stable tie order', () => {
  const g = game(); const a = enemy(g, 740), b = enemy(g, 760);
  assert.equal(g.nearest({ x: 750, y: 400 }), a);
  assert.equal(g.nearest({ x: 750, y: 400 }, new Set([a.id])), b);
  assert.equal(g.nearest({ x: 750, y: 400 }, new Set(), 10), undefined);
});
test('scattered letters mark distinct matching positions and reward only manually entered marks', () => {
  const g = game(); g.relics.letterwake = 1;
  const a = enemy(g, 750, 1), b = enemy(g, 850); a.word = 'apple'; b.word = 'paper';
  g.target = a; g.prefix = 'app'; g.kill(a);
  assert.equal(g.target, a); assert.equal(g.prefix, 'app');
  assert.equal(g.weave.letters.length, 3);
  const positions = g.weave.letters.map(m => m.index); assert.equal(new Set(positions).size, 3);
  g.weave.update(g, 1.2); assert.equal(g.weave.letters.length, 0);
  assert.deepEqual([...b.letterMarks.positions].sort(), [0, 1, 2]);
  assert.equal(g.weave.letterMultiplier(b, 2), 1.3);
  assert.equal(g.weave.letterMultiplier(b, 5), 1);
});
test('changing a recipient word invalidates flying letters and existing letter marks', () => {
  const g = game(); g.relics.letterwake = 1;
  const a = enemy(g, 750, 1), b = enemy(g, 850); a.word = 'cat'; b.word = 'catch';
  g.weave.scatter(g, a, 'cat'); b.word = 'dog'; g.weave.update(g, 2);
  assert.equal(g.weave.letters.length, 0); assert.equal(b.letterMarks, undefined);
  b.letterMarks = { word: 'catch', positions: [0, 1] };
  assert.equal(g.weave.letterMultiplier(b, 3), 1);
});

test('native paper and relic carrier providers share one finite input supply', () => {
  for (const book of ['spirit', 'frost']) {
    const g = game(book); if (book === 'frost') g.relics.spirit = 1;
    g.relics.copyfolio = 1;
    const e = enemy(g); cast(g, e, 100, 12, 'paper');
    assert.equal(g.weave.pages.length, 1);
    cast(g, e, 100, 0, 'paper');
    assert.equal(g.weave.pages.length, 1);
    step(g, 6); assert.equal(g.weave.pages.length, 0);
    assert.equal(g.weave.summary.pagesCreated, 1);
  }
});

test('encounter completion clears pending casts, pages and letters on the same frame', () => {
  const g = game('spirit'); const e = enemy(g);
  cast(g, e, 100, 12, 'paper'); assert.equal(g.weave.pages.length, 1);
  g.enemies = []; g.spawned = g.roomQuota; g.tasks = [];
  g.weave.letters.push({ targetId: e.id });
  g.finishEncounter(1 / 120);
  assert.equal(g.roomEnded, true);
  assert.equal(g.weave.pages.length, 0); assert.equal(g.weave.letters.length, 0);
});
