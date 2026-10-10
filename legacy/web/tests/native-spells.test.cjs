const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createGame, isolate, type, step } = require('./harness.cjs');
const { RESOURCE_SCALE } = require('../src/contracts/build-resources.ts');
const { builtinContent } = require('../src/bootstrap/content.ts');
const { validateNativeSpell } = require('../src/shared/build/native.ts');

test('talent and relic copy entrances share one paid rule, expose pages, and release once', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  game.config = { ...game.config, talents: ['T19'] }; game.relics['copy-quill'] = 1;
  const target = enemy(game); type(game, target);
  assert.equal(game.nativeSpells.enabled, true);
  const runtime = game.nativeSpells.runtime, shells = runtime.active('shell');
  assert.equal(shells.length, 1); assert.equal(runtime.balance(0, 'work'), RESOURCE_SCALE);
  assert.equal(game.weave.pages.length, 0); assert.equal(game.nativeSpells.savedPages.length, 1);
  assert.equal(shells[0].program.rules.find(rule => rule.definition.id === 'copy.plain').sourceIds.length, 2);
  assert.equal(shells[0].shape, 'shot'); assert.equal(shells[0].remainingApplications, 1);
  const power = runtime.balance(shells[0].id, 'power');
  game.time = 1.99; game.nativeSpells.advance(); assert.equal(runtime.getObject(shells[0].id).state, 'stored');
  game.time = 2; game.nativeSpells.advance(); assert.equal(runtime.getObject(shells[0].id).state, 'closed');
  const released = runtime.active('spell').filter(object => object.exitOf === shells[0].id);
  assert.equal(released.length, 1); assert.equal(runtime.balance(released[0].id, 'power'), power);
  assert.equal(released[0].state, 'flight'); assert.equal(game.nativeSpells.savedPages.length, 0);
  game.time = 2.1; game.nativeSpells.advance(); assert.equal(runtime.active('shell').length, 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('short-lived copy pages need a real expiry release rule; an acquired rule cannot rewrite an old page', () => {
  for (const echo of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: echo ? ['T19', 'T22'] : ['T19'] }; game.relics.R075 = 1;
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    assert.ok(shell.expiresAtTick < shell.readyAtTick);
    if (!echo) game.config = { ...game.config, talents: ['T19', 'T22'] };
    game.time = shell.expiresAtTick / 60; game.nativeSpells.advance();
    const exits = runtime.active('spell').filter(object => object.exitOf === shell.id);
    assert.equal(exits.length, echo ? 1 : 0);
    assert.equal(runtime.getObject(shell.id).state, 'closed'); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('formal stored assembly merges funded copies once, shares entrances, and releases the same total power later', () => {
  const results = [];
  for (const size of [0, 2, 4]) {
    const game = isolate(createGame(['abcdefghijklmnop'], 'frost'));
    game.config = { ...game.config, talents: ['T19', ...(size ? ['T27'] : []), ...(size === 4 ? ['N17-01', 'N17-02', 'N17-03', 'N06-01'] : [])] };
    if (size) game.relics.R108 = 1;
    if (size === 4) game.relics.R077 = 1;
    const target = enemy(game); type(game, target);
    const runtime = game.nativeSpells.runtime, pages = runtime.active('shell');
    assert.equal(game.nativeSpells.enabled, true); assert.equal(pages.length, size ? 4 / size : 4);
    assert.equal(game.nativeSpells.savedPages.length, pages.length);
    const saved = pages.reduce((total, page) => total + runtime.balance(page.id, 'power'), 0);
    results.push([saved, runtime.balance(0, 'work')]);
    if (size) {
      assert.equal(pages[0].program.rules.find(rule => rule.definition.id === 'storage.merge').sourceIds.length, 2);
      assert.equal(pages[0].program.numerics['storage.capacity'], size === 4 ? 7 : 6);
      for (const page of pages) {
        assert.equal(page.readyAtTick, size === 4 ? 138 : 150); assert.equal(page.expiresAtTick, 600);
        const lots = runtime.ledger.getOwnedLots(page.id);
        assert.equal(lots.length, size); assert.ok(lots.every(lot => lot.ruleClaims['rule:storage.merge'] === 1));
        assert.equal(page.remainingApplications, 1); assert.equal(page.properties.material, 'paper');
      }
      const before = runtime.ledger.snapshot(); game.time = 2; game.nativeSpells.advance();
      assert.deepEqual(runtime.ledger.snapshot(), before);
    }
    game.time = pages[0].readyAtTick / 60; game.nativeSpells.advance();
    const exits = runtime.active('spell').filter(object => pages.some(page => page.id === object.exitOf));
    assert.equal(exits.length, pages.length); assert.equal(exits.reduce((total, spell) => total + runtime.balance(spell.id, 'power'), 0), saved);
    assert.equal(runtime.active('shell').length, 0); assert.equal(runtime.manualCount, 1);
    game.nativeSpells.advance(); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
  assert.deepEqual(results[1], results[0]); assert.deepEqual(results[2], results[0]);
});

test('merged pages pay one stronger interception and release only the actual unspent remainder', () => {
  const game = isolate(createGame(['abcdefghijklmnop'], 'frost'));
  game.config = { ...game.config, talents: ['T19', 'T21', 'T22', 'T27'] };
  game.relics.R077 = 1; type(game, enemy(game));
  const runtime = game.nativeSpells.runtime, page = runtime.active('shell')[0];
  assert.equal(runtime.active('shell').length, 1);
  const saved = runtime.balance(page.id, 'power');
  game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa'); const projectile = game.bullets[0];
  const blocked = game.nativeSpells.intercept(projectile, saved / RESOURCE_SCALE);
  assert.equal(Math.round(blocked * RESOURCE_SCALE), Math.floor(saved * .75));
  const exit = runtime.active('spell').find(object => object.exitOf === page.id);
  assert.ok(exit); assert.equal(runtime.balance(exit.id, 'power'), saved - Math.floor(saved * .75));
  const before = runtime.ledger.snapshot(); assert.equal(game.nativeSpells.intercept(projectile, saved / RESOURCE_SCALE), 0);
  assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('joint guard combines two compatible pages only when needed, with each actual remainder released once', () => {
  for (const [equipped, later, small] of [[true, true, false], [true, false, false], [false, true, false], [true, true, true]]) {
    const game = isolate(createGame(['abcdefghijklmnop'], 'frost'));
    game.config = { ...game.config, talents: ['T19', 'T21', 'T22', 'T27'] };
    if (equipped) game.relics.R176 = 1;
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime, pages = runtime.active('shell');
    assert.equal(pages.length, 2);
    const powers = pages.map(page => runtime.balance(page.id, 'power')), total = powers.reduce((a, b) => a + b, 0);
    game.relics = later ? { R176: 1 } : {};
    game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa'); const projectile = game.bullets[0];
    const input = small ? 1 : total / RESOURCE_SCALE;
    const blocked = Math.round(game.nativeSpells.intercept(projectile, input) * RESOURCE_SCALE);
    const count = equipped && !small ? 2 : 1;
    const expected = small ? RESOURCE_SCALE : powers.slice(0, count).reduce((sum, power) => sum + Math.floor(power * .75), 0);
    assert.equal(blocked, expected);
    const exits = runtime.active('spell').filter(spell => pages.some(page => spell.exitOf === page.id));
    assert.equal(exits.length, count);
    assert.equal(exits.reduce((sum, exit) => sum + runtime.balance(exit.id, 'power'), 0) + blocked,
      powers.slice(0, count).reduce((sum, power) => sum + power, 0));
    assert.equal(runtime.active('shell').length, 2 - count);
    const before = runtime.ledger.snapshot(); assert.equal(game.nativeSpells.intercept(projectile, input), 0);
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('joint guard never joins pages from different completed words', () => {
  const game = isolate(createGame(['abcdefgh'], 'frost'));
  game.config = { ...game.config, talents: ['T19', 'T21', 'T22', 'T27'] }; game.relics.R176 = 1;
  type(game, enemy(game)); type(game, enemy(game, 750));
  const runtime = game.nativeSpells.runtime, pages = runtime.active('shell'); assert.equal(pages.length, 2);
  assert.notEqual(pages[0].rootReceiptId, pages[1].rootReceiptId);
  const saved = runtime.balance(pages[0].id, 'power');
  game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa');
  assert.equal(Math.round(game.nativeSpells.intercept(game.bullets[0], 10000) * RESOURCE_SCALE), Math.floor(saved * .75));
  assert.equal(runtime.active('shell').length, 1); assert.equal(runtime.active('shell')[0].id, pages[1].id);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('acquiring merge later cannot rewrite existing pages or mix separate manual casts', () => {
  const game = isolate(createGame(['abcdefgh'], 'frost'));
  game.config = { ...game.config, talents: ['T19'] }; type(game, enemy(game));
  const runtime = game.nativeSpells.runtime, previous = runtime.active('shell'); assert.equal(previous.length, 2);
  game.config = { ...game.config, talents: ['T19', 'T27'] }; game.time = .2; type(game, enemy(game));
  const current = runtime.active('shell'); assert.equal(current.length, 3);
  assert.ok(previous.every(page => runtime.getObject(page.id) === page));
  const merged = current.find(page => !previous.includes(page));
  assert.equal(merged.readyAtTick, 162); assert.notEqual(merged.rootReceiptId, previous[0].rootReceiptId);
  game.nativeSpells.clearRoom(); assert.equal(runtime.active().length, 0); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('crystal storage diverts existing primary power and shares its efficiency with the talent entrance', () => {
  const saved = [];
  for (const talent of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    if (talent) game.config = { ...game.config, talents: ['T01'] };
    game.relics['crystal-seed'] = 1; type(game, enemy(game));
    const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    assert.equal(runtime.active('shell').length, 1); assert.equal(shell.properties.material, 'crystal');
    saved.push(runtime.balance(shell.id, 'power'));
    assert.equal(game.nativeSpells.savedPages[0].material, 'crystal');
    assert.equal(runtime.balance(0, 'work'), 5 * RESOURCE_SCALE);
    game.nativeSpells.clearRoom(); assert.deepEqual(game.nativeSpells.savedPages, []);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
  assert.ok(saved[1] > saved[0]);
});

test('native catalog validates finite loops and rejects a zero-price summon loop before combat', () => {
  for (const book of Object.values(builtinContent.books)) assert.deepEqual(validateNativeSpell(book.id, book.nativeSpell), []);
  const pattern = builtinContent.books.spirit.nativeSpell;
  assert.ok(validateNativeSpell('spirit', { ...pattern, summon: { ...pattern.summon, workCost: 0 } })
    .some(error => error.path === 'summon.workCost'));
});

function enemy(game, x = 640, y = 300) {
  const target = game.spawnEnemy('nib', x, y);
  target.hp = target.maxHp = 100000; target.grace = 0;
  return target;
}
function totals(runtime) {
  return runtime.ledger.snapshot().lots.reduce((sum, lot) => sum + (lot.resource === 'power' ? lot.quantityQ : 0), 0);
}
function burnBudget(runtime, objectId, retention = .9) {
  return runtime.ledger.getOwnedLots(objectId).filter(lot => lot.resource === 'power' || lot.resource === 'heat').map(lot => {
    const gross = Math.floor(lot.quantityQ * (lot.resource === 'heat' ? 4 : 1) * .35);
    return { gross, kept: Math.floor(gross * retention) };
  });
}

test('cold entrances share one conversion and numeric pool, including stacked legacy relics and copied material', () => {
  for (const book of ['flame', 'frost']) {
    const game = isolate(createGame(['constellation'], book));
    game.config = { ...game.config, talents: ['T50', 'N02-01', 'N02-02', 'N02-03', 'N02-04', 'N02-05', 'T19', 'T20'] };
    game.relics.frost = 3;
    const target = enemy(game); type(game, target);
    assert.equal(game.nativeSpells.enabled, true);
    const runtime = game.nativeSpells.runtime, root = runtime.active('spell').find(object => !object.derived);
    const entry = root.program.rules.filter(rule => rule.definition.id === 'cold.convert');
    assert.equal(entry.length, 1); assert.equal(entry[0].sourceIds.length, book === 'frost' ? 3 : 2);
    const efficiency = root.program.numerics['cold.efficiency']; assert.ok(Math.abs(efficiency - 1.75) < 1e-12);
    const page = runtime.active('shell')[0]; assert.ok(runtime.balance(page.id, 'cold') > 0);
    assert.ok(runtime.balance(root.id, 'cold') > 0);
    const applications = []; game.applyCold = (enemy, amount, duration) => applications.push([amount, duration]);
    const commits = [], commitHit = runtime.commitHit.bind(runtime);
    runtime.commitHit = (...args) => { const result = commitHit(...args); if (result.ok) commits.push(result.value); return result; };
    game.nativeSpells.hit({ room: runtime.room, objectId: root.id }, target, game.player);
    assert.equal(applications[0][0], commits[0].materials.cold / RESOURCE_SCALE * efficiency);
    assert.equal(applications[0][1], 1.55); // Legacy cold stacks do not add another duration bonus.
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('longer ongoing damage spreads the same funded power over more beats in fire and other books', () => {
  for (const book of ['flame', 'frost']) {
    const budgets = [];
    for (const level of [0, 2]) {
      const game = isolate(createGame(['alpha'], book)); game.relics.bleed = 2; game.relics.cinder = 3;
      if (level) game.relics.pitch = level;
      const target = enemy(game); type(game, target);
      assert.equal(game.nativeSpells.enabled, true);
      const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
      game.nativeSpells.hit(reference, target, game.player);
      const status = runtime.active('status')[0]; assert.ok(status);
      budgets.push(runtime.balance(status.id, 'power'));
      assert.equal(status.expiresAtTick - status.createdAtTick, 240 + level * 60);
      assert.equal(status.remainingApplications, 8 + level * 2);
      const paid = [], commitHit = runtime.commitHit.bind(runtime);
      runtime.commitHit = (...args) => { const result = commitHit(...args);
        if (result.ok && result.value.object.id === status.id) paid.push(result.value.powerQ); return result; };
      game.time = status.expiresAtTick / 60; game.nativeSpells.advance();
      assert.equal(paid.length, 8 + level * 2); assert.equal(paid.reduce((n, value) => n + value, 0), budgets.at(-1));
      assert.equal(runtime.getObject(status.id).state, 'closed');
      assert.equal(target.dotStacks, 0); assert.deepEqual(game.nativeSpells.diagnostics, []);
    }
    assert.equal(budgets[0], budgets[1]);
  }
});

test('formal repeated primary hits pay both ongoing relics from the old burn and incoming cold', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  game.config = { ...game.config, talents: ['T49', 'T04', 'T50'] }; game.relics.R165 = game.relics.R166 = 1;
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, first = runtime.active('spell').find(object => !object.derived);
  game.nativeSpells.hit({ room: runtime.room, objectId: first.id }, target, game.player);
  const burn = runtime.active('status')[0], power = runtime.balance(burn.id, 'power');
  game.time = .1; target.wordPending = false; type(game, target);
  const next = runtime.active('spell').find(object => !object.derived && object.id !== first.id);
  const cold = runtime.balance(next.id, 'cold'), appliedCold = [];
  assert.ok(cold >= 12 * RESOURCE_SCALE);
  game.applyCold = (enemy, amount) => appliedCold.push(amount);
  const reference = { room: runtime.room, objectId: next.id };
  game.nativeSpells.hit(reference, target, game.player);
  const changed = runtime.getObject(burn.id);
  assert.equal(changed.remainingApplications, 6); assert.ok(runtime.balance(burn.id, 'power') < power);
  assert.equal(changed.expiresAtTick, burn.expiresAtTick + 120);
  assert.equal(changed.status.nextAtTick, burn.status.nextAtTick + 120);
  assert.equal(appliedCold[0], (cold - 12 * RESOURCE_SCALE) / RESOURCE_SCALE * 1.1);
  assert.equal(runtime.active('status').length, 2);
  const snapshot = runtime.ledger.snapshot(); game.nativeSpells.hit(reference, target, game.player);
  assert.deepEqual(runtime.ledger.snapshot(), snapshot); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('cold-sealed storage absorbs less heat, survives longer and can choose retained heat through its own prerequisite', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  game.config = { ...game.config, talents: ['T01', 'T04', 'K04'] }; game.relics.R102 = 1;
  type(game, enemy(game)); assert.equal(game.nativeSpells.enabled, true);
  const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
  assert.equal(shell.program.numerics['heat.contactQ'], RESOURCE_SCALE);
  assert.equal(shell.expiresAtTick, 960);
  assert.equal(shell.readyAtTick, 300);
  assert.equal(shell.program.modes['heat.response'], 'retain');
  const initialHeat = runtime.balance(shell.id, 'heat');
  game.time = .1; type(game, enemy(game));
  assert.equal(runtime.balance(shell.id, 'heat'), initialHeat + RESOURCE_SCALE);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('boss cold has diminishing control and an unbankable recovery gap, while normal freezes still interrupt', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const { updateEnemyStatus } = require('../src/simulation/systems/StatusSystem.ts');
  const boss = enemy(game); boss.boss = true; boss.windup = 3; boss.charge = 2;
  game.applyCold(boss, 100, 1.55);
  assert.equal(boss.freeze, .8); assert.equal(boss.coldRecovery, 2.8);
  assert.equal(boss.windup, 3); assert.equal(boss.charge, 2);
  game.applyCold(boss, 10000, 1.55); assert.equal(boss.chill, 0); assert.equal(boss.freeze, .8);
  updateEnemyStatus.call(game, boss, 1);
  assert.equal(boss.freeze, 0); game.applyCold(boss, 10000, 1.55); assert.equal(boss.chill, 0);
  updateEnemyStatus.call(game, boss, 2);
  game.applyCold(boss, 100, 1.55); assert.equal(boss.freeze, 0);
  game.applyCold(boss, 100, 1.55); assert.equal(boss.freeze, .8 / 1.5);
  for (let i = 0; i < 4; i++) { updateEnemyStatus.call(game, boss, 4); game.applyCold(boss, 10000, 1.55); }
  assert.equal(boss.coldResistance, 3); assert.equal(boss.freeze, .32);
  const normal = enemy(game); normal.windup = 3; normal.charge = 2;
  game.applyCold(normal, 100, 1.55);
  assert.equal(normal.freeze, 1.55); assert.equal(normal.windup, 0); assert.equal(normal.charge, 0);
});

test('actual bullet collisions spend one saved page, preserving the exact remainder of partial damage', () => {
  for (const word of ['alpha', 'constellation']) {
    const game = isolate(createGame([word], 'frost')); game.config = { ...game.config, talents: ['T01', 'T21', 'T22'] };
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    const saved = runtime.balance(shell.id, 'power'), incoming = 11 * game.pressure.damage;
    const spent = Math.min(Math.floor(saved * .75), Math.ceil(incoming * RESOURCE_SCALE));
    const expected = Math.max(0, incoming - spent / RESOURCE_SCALE), damage = [];
    const hurt = game.hurt.bind(game); game.hurt = (amount, ...args) => { damage.push(amount); return hurt(amount, ...args); };
    const hp = game.player.hp; game.player.invuln = 0;
    game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa'); game.updateBullets(0);
    assert.equal(runtime.getObject(shell.id).state, 'closed'); assert.equal(game.nativeSpells.savedPages.length, 0);
    if (expected === 0) { assert.deepEqual(damage, []); assert.equal(game.player.hp, hp); }
    else { assert.deepEqual(damage, [expected]); assert.ok(game.player.hp < hp); }
    const exit = runtime.active('spell').find(object => object.exitOf === shell.id);
    assert.ok(exit); assert.equal(runtime.balance(exit.id, 'power'), saved - spent);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('guard selection follows the chosen order; heavy and expired collisions leave the pages unavailable', () => {
  for (const mode of ['oldest', 'newest']) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T01', 'T21', ...(mode === 'newest' ? ['T24'] : [])] };
    type(game, enemy(game)); game.time = .2; type(game, enemy(game));
    const runtime = game.nativeSpells.runtime, shells = runtime.active('shell'); assert.equal(shells.length, 2);
    game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa'); const bullet = game.bullets[0];
    bullet.heavy = true; assert.equal(game.nativeSpells.intercept(bullet, 11), 0);
    assert.ok(shells.every(shell => runtime.getObject(shell.id).state === 'stored'));
    bullet.heavy = false; assert.ok(game.nativeSpells.intercept(bullet, 11) > 0);
    const selected = mode === 'oldest' ? 0 : 1;
    assert.equal(runtime.getObject(shells[selected].id).state, 'closed');
    assert.equal(runtime.getObject(shells[1 - selected].id).state, 'stored');
    const snapshot = runtime.ledger.snapshot(); assert.equal(game.nativeSpells.intercept(bullet, 11), 0); assert.deepEqual(runtime.ledger.snapshot(), snapshot);
    game.time = shells[1 - selected].expiresAtTick / 60;
    assert.equal(game.nativeSpells.intercept({ ...bullet }, 11), 0); assert.deepEqual(runtime.ledger.snapshot(), snapshot);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('native and acquired heat share income and open either book\'s saved spells through actual casts', () => {
  for (const book of ['flame', 'frost']) {
    const game = isolate(createGame(['alpha'], book)); game.config = { ...game.config, talents: ['T01', 'T05'] };
    game.relics.emberink = 1; const target = enemy(game); type(game, target);
    const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    assert.equal(runtime.balance(0, 'work'), 5 * RESOURCE_SCALE / 2);
    assert.ok(runtime.balance(shell.id, 'heat') > 0); assert.equal(shell.state, 'stored');
    game.time = .1; type(game, enemy(game));
    assert.equal(runtime.getObject(shell.id).state, 'closed');
    const exit = runtime.active('spell').find(object => object.exitOf === shell.id);
    assert.ok(exit); assert.equal(exit.state, 'flight'); assert.equal(runtime.manualCount, 2);
    assert.equal(runtime.balance(0, 'work'), 5 * RESOURCE_SCALE); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('retaining heat prevents early opening and stores finite heat until the delayed release', () => {
  const game = isolate(createGame(['alpha'], 'flame')); game.config = { ...game.config, talents: ['T01', 'T05', 'K04'] };
  const target = enemy(game); type(game, target); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
  for (let i = 1; i < 6; i++) { game.time = i / 10; type(game, enemy(game)); }
  assert.equal(runtime.getObject(shell.id).state, 'stored'); assert.equal(runtime.balance(shell.id, 'heat'), 8 * RESOURCE_SCALE);
  const power = runtime.balance(shell.id, 'power');
  const storedHeat = runtime.active('shell').reduce((n, object) => n + runtime.balance(object.id, 'heat'), 0);
  game.time = shell.readyAtTick / 60; game.nativeSpells.advance();
  assert.equal(runtime.getObject(shell.id).state, 'closed');
  const exit = runtime.active('spell').find(object => object.exitOf === shell.id); assert.ok(exit);
  const heat = runtime.balance(exit.id, 'heat');
  assert.equal(heat + runtime.active('shell').reduce((n, object) => n + runtime.balance(object.id, 'heat'), 0), storedHeat);
  const loss = burnBudget(runtime, exit.id).reduce((sum, part) => sum + part.gross - part.kept, 0);
  game.nativeSpells.hit({ room: runtime.room, objectId: exit.id }, target, game.player);
  const remaining = runtime.active().filter(object => object.rootReceiptId === shell.rootReceiptId);
  assert.equal(game.nativeSpells.summary.committedPower * RESOURCE_SCALE + remaining.reduce((n, object) => n + runtime.balance(object.id, 'power'), 0) + loss, power + heat * 4);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('the quick heat mode opens on the first sufficient contact and retains its shorter lifetime', () => {
  const game = isolate(createGame(['alpha'], 'flame')); game.config = { ...game.config, talents: ['T01', 'T05', 'K05'] };
  type(game, enemy(game)); const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.active('shell').length, 0);
  const exit = runtime.active('spell').find(object => object.exitOf !== undefined); assert.ok(exit);
  const shell = runtime.getObject(exit.exitOf); assert.equal(shell.state, 'closed'); assert.equal(shell.expiresAtTick, 120);
  assert.equal(exit.state, 'flight'); assert.equal(runtime.manualCount, 1); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('heat fracture releases nearby basic fragments once and consumes the shell before it can guard', () => {
  const game = isolate(createGame(['alpha'], 'frost')); game.config = { ...game.config, talents: ['T01', 'T02', 'T21', 'T22'] };
  game.relics.R066 = 1; game.relics.R101 = 1;
  const target = enemy(game, game.player.x + 100, game.player.y); enemy(game, game.player.x - 100, game.player.y);
  type(game, target); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0], saved = runtime.balance(shell.id, 'power');
  game.time = .1; type(game, enemy(game, game.player.x + 120, game.player.y));
  assert.equal(runtime.getObject(shell.id).state, 'closed');
  const pieces = runtime.active('spell').filter(object => object.derived && object.rootReceiptId === shell.rootReceiptId);
  assert.equal(pieces.length, 3); assert.equal(pieces.reduce((n, object) => n + runtime.balance(object.id, 'power'), 0), saved);
  for (const piece of pieces) { assert.equal(piece.shape, 'shot'); assert.equal(piece.remainingApplications, 1); assert.equal(piece.properties.integrity, 0); }
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('actual input earns one main cast and one shared work income; automatic suffix adds no income', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const target = enemy(game); game.autofill = true; game.target = target;
  game.input('a'); game.input('l');
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.manualCount, 1);
  assert.equal(runtime.balance(0, 'work'), 2 * RESOURCE_SCALE);
  assert.equal(game.nativeSpells.summary.manualCharacters, 2);
  assert.equal(game.weave.summary.manualCharacters, 0);
  assert.equal(game.shots.filter(shot => shot.spell).length, 1);
  const origins = new Set(runtime.ledger.snapshot().lots.map(lot => lot.origin.receiptId));
  assert.deepEqual([...origins], ['input:2']);
  step(game, .1);
  assert.equal(runtime.balance(0, 'work'), 2 * RESOURCE_SCALE);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('spaces are not playable input positions and canceled words cannot carry income forward', () => {
  const game = isolate(createGame(['can not', 'alpha'], 'frost'));
  const target = enemy(game); target.word = 'can not'; game.target = target;
  for (const letter of 'cannot') game.input(letter);
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.balance(0, 'work'), 6 * RESOURCE_SCALE);
  game.cancel(); target.wordPending = false; target.word = 'alpha'; game.target = target;
  game.input('a'); game.cancel(); game.target = target; game.input('a');
  assert.equal(runtime.manualCount, 1);
  assert.deepEqual(game.inputPositions, [0]);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('native piercing hits consume the same finite root, and duplicate hit delivery cannot spend twice', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const first = enemy(game, 500), second = enemy(game, 600);
  type(game, first);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  const initial = totals(runtime);
  game.nativeSpells.hit(reference, first, game.player);
  const after = totals(runtime);
  assert.ok(after > 0 && after < initial);
  const hp = first.hp;
  game.nativeSpells.hit(reference, first, game.player);
  assert.equal(first.hp, hp); assert.equal(totals(runtime), after);
  game.nativeSpells.hit(reference, second, first);
  assert.equal(totals(runtime), 0);
  assert.equal(game.nativeSpells.accepts(reference), false);
  assert.equal(game.nativeSpells.summary.committedPower * RESOURCE_SCALE, initial);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('instant lightning follows finite nearby hops, with no nested lifecycle error or projectile damage source', () => {
  const game = isolate(createGame(['alpha'], 'storm'));
  let depth = 0, maximumDepth = 0;
  const hit = game.nativeSpells.hit.bind(game.nativeSpells);
  game.nativeSpells.hit = (...args) => { maximumDepth = Math.max(maximumDepth, ++depth); try { return hit(...args); } finally { depth--; } };
  const targets = [enemy(game, 500), enemy(game, 580), enemy(game, 660), enemy(game, 740)];
  type(game, targets[0]);
  assert.ok(targets.every(target => target.hp < target.maxHp));
  assert.equal(game.nativeSpells.runtime.manualCount, 1);
  assert.equal(totals(game.nativeSpells.runtime), 0);
  assert.equal(game.shots.length, 0);
  assert.equal(maximumDepth, 1);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('storm and acquired conduction share a finite supply, with arcs starting at the previous hit', () => {
  for (const acquired of [false, true]) {
    const game = isolate(createGame(['alpha'], 'storm'));
    if (acquired) { game.config = { ...game.config, talents: ['T13'] }; game.relics.R110 = 1; }
    const targets = [enemy(game, 500), enemy(game, 600), enemy(game, 700), enemy(game, 800)];
    const arcs = [], arc = game.arc.bind(game);
    game.arc = (from, to, ...args) => { arcs.push([[from.x, from.y], [to.x, to.y]]); return arc(from, to, ...args); };
    type(game, targets[0]); const runtime = game.nativeSpells.runtime;
    assert.equal(runtime.balance(0, 'work'), 2.5 * RESOURCE_SCALE);
    assert.equal(arcs.length, 4);
    for (let i = 1; i < arcs.length; i++) assert.deepEqual(arcs[i][0], arcs[i - 1][1]);
    assert.equal(runtime.active().length, 0); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('conduction on another book diverts paid power and charge without duplicating its native shape', () => {
  const game = isolate(createGame(['alpha'], 'frost')); game.config = { ...game.config, talents: ['T13'] };
  game.relics.R110 = 1;
  const targets = [enemy(game, 500), enemy(game, 580), enemy(game, 660)];
  type(game, targets[0]); const runtime = game.nativeSpells.runtime;
  const root = runtime.active('spell').find(object => !object.derived);
  const income = game.nativeSpells.summary.incomePower * RESOURCE_SCALE;
  const primaryPower = income - Math.floor(income * .12);
  assert.equal(runtime.balance(root.id, 'power') + game.nativeSpells.summary.committedPower * RESOURCE_SCALE, primaryPower);
  assert.equal(runtime.balance(root.id, 'charge'), 0);
  assert.equal(game.shots.filter(shot => shot.spell).length, 1);
  assert.ok(targets.every(target => target.hp < target.maxHp));
  assert.equal(runtime.manualCount, 1); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('routing stops at paid charge, distance, and target limits, without hitting a target twice', () => {
  for (const [word, talents, spacing, expected] of [
    ['a', [], 80, 2], ['alpha', [], 400, 1], ['alpha', ['T15'], 400, 3], ['alpha', ['T16'], 180, 6],
  ]) {
    const game = isolate(createGame([word], 'storm')); game.config = { ...game.config, talents };
    const targets = [[0, 0], [1, 0], [2, 0], [2, 1], [1, 1], [0, 1]]
      .map(([x, y]) => enemy(game, 200 + x * spacing, 150 + y * spacing));
    type(game, targets[0]);
    assert.equal(targets.filter(target => target.hp < target.maxHp).length, expected, `${word}/${talents}/${spacing}`);
    assert.equal(game.nativeSpells.runtime.active().length, 0);
    const before = targets.map(target => target.hp); game.nativeSpells.advance(); assert.deepEqual(targets.map(target => target.hp), before);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('a broken route recovers unspent charge and the optional priority competes with the same word budget', () => {
  for (const priority of [false, true]) {
    const game = isolate(createGame(['alpha'], 'storm')); game.config = { ...game.config, talents: ['T17', 'T12'] };
    if (priority) game.relics.R116 = 1;
    const target = enemy(game); type(game, target);
    const runtime = game.nativeSpells.runtime;
    assert.equal(runtime.balance(1, 'charge'), 1.25 * RESOURCE_SCALE);
    assert.ok(runtime.balance(1, 'power') > 12 * RESOURCE_SCALE);
    const uses = [], useReserve = runtime.useReserve.bind(runtime);
    runtime.useReserve = (...args) => {
      const result = useReserve(...args);
      if (result.ok) uses.push({ resource: args[1], amount: result.value.transaction.createdLotIds
        .reduce((sum, id) => sum + runtime.ledger.getLot(id).quantityQ, 0) });
      return result;
    };
    type(game, enemy(game, 800));
    assert.equal(uses[0].resource, priority ? 'charge' : 'power');
    assert.equal(uses.filter(use => use.resource === 'charge').reduce((sum, use) => sum + use.amount, 0), priority ? 1.25 * RESOURCE_SCALE : 0);
    assert.equal(uses.reduce((sum, use) => sum + use.amount, 0), 12 * RESOURCE_SCALE);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('shape-inheriting storm copies move real charge from the source and remain finite after release', () => {
  for (const recovery of [false, true]) {
    const game = isolate(createGame(['constellation'], 'storm'));
    game.config = { ...game.config, talents: ['T19', 'T20', ...(recovery ? ['T17'] : [])] };
    const targets = Array.from({ length: 6 }, (_, i) => enemy(game, 500 + i * 80));
    const revision = targets[1].wordRevision;
    type(game, targets[0]); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    assert.ok(shell); assert.equal(shell.shape, 'chain'); assert.ok(runtime.balance(shell.id, 'charge') > 0);
    assert.equal(targets[1].wordRevision, revision);
    const saved = runtime.balance(shell.id, 'power'), before = game.nativeSpells.summary.committedPower;
    const charge = runtime.balance(shell.id, 'charge'), reserve = runtime.balance(1, 'charge');
    game.cancel(false); game.target = targets[1]; game.input(targets[1].word[0]); const prefix = game.prefix;
    game.time = shell.readyAtTick / 60; game.nativeSpells.advance();
    assert.equal(runtime.active().length, 0);
    assert.ok((game.nativeSpells.summary.committedPower - before) * RESOURCE_SCALE <= saved);
    assert.equal(game.prefix, prefix); assert.equal(targets[1].wordRevision, revision);
    assert.equal(runtime.balance(1, 'charge'), reserve + (recovery ? Math.floor((charge - 1.5 * RESOURCE_SCALE) * .5) : 0));
    const hp = targets.map(target => target.hp); game.time += 4; game.nativeSpells.advance();
    assert.deepEqual(targets.map(target => target.hp), hp); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('durable targeting gives the original target only one paid automatic preference per manual root', () => {
  const game = isolate(createGame(['alphabeta'], 'frost')); game.config = { ...game.config, talents: ['T19', 'T29'] };
  const original = enemy(game, 750), durable = enemy(game, 900); durable.hp = durable.maxHp = 200000;
  type(game, original); const runtime = game.nativeSpells.runtime, shells = runtime.active('shell');
  assert.equal(shells.length, 2);
  game.time = 2; game.nativeSpells.advance();
  const exits = shells.map(shell => runtime.active('spell').find(object => object.exitOf === shell.id));
  assert.deepEqual(exits.map(object => object.targetId), [original.id, durable.id]);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('near threat, durable, fresh and blind preferences compose without redirecting the manual primary', () => {
  for (const choice of ['near', 'near-strong', 'blind', 'fresh', 'exit-near']) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T19', ...(choice === 'near-strong' || choice === 'blind' ? ['T29'] : []),
      ...(choice === 'near' || choice === 'near-strong' ? ['T30'] : []), ...(choice === 'exit-near' ? ['T22'] : [])] };
    if (choice === 'blind') game.relics.R162 = 1;
    if (choice === 'fresh') game.relics.R109 = 1;
    if (choice === 'exit-near') game.relics.R140 = 1;
    const original = enemy(game, game.player.x + 600, game.player.y);
    const close = enemy(game, game.player.x + 60, game.player.y), strong = enemy(game, game.player.x + 150, game.player.y);
    strong.hp = strong.maxHp = 200000;
    type(game, original); const runtime = game.nativeSpells.runtime, root = runtime.active('spell').find(object => !object.derived);
    assert.equal(root.targetId, original.id);
    if (choice === 'fresh') game.nativeSpells.hit({ room: runtime.room, objectId: root.id }, original, game.player);
    const shell = runtime.active('shell')[0]; game.time = 2; game.nativeSpells.advance();
    const exit = runtime.active('spell').find(object => object.exitOf === shell.id);
    assert.equal(exit.targetId, choice === 'near-strong' ? strong.id : close.id, choice);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('native frost leaves funded cold at the impact without entering legacy field mechanics', () => {
  const game = isolate(createGame(['alpha'], 'frost')), target = enemy(game), nearby = enemy(game, 670);
  type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  const cold = runtime.balance(reference.objectId, 'cold');
  game.nativeSpells.hit(reference, target, game.player);
  const field = runtime.active('field')[0]; assert.ok(field);
  assert.deepEqual(field.position, { x: target.x, y: target.y }); assert.equal(runtime.balance(field.id, 'power'), 0);
  assert.equal(runtime.balance(field.id, 'cold'), Math.floor(cold * .35));
  assert.equal(game.fields.length, 0); assert.equal(game.nativeSpells.fields.length, 1);
  const applied = []; game.applyCold = (enemy, amount) => applied.push([enemy.id, amount]);
  const before = runtime.balance(field.id, 'cold'), hp = nearby.hp;
  game.time = .5; game.nativeSpells.advance();
  assert.deepEqual(applied.map(([id]) => id), [target.id, nearby.id]);
  assert.equal(applied.reduce((sum, [, amount]) => sum + amount * RESOURCE_SCALE, 0), Math.ceil(before / 8));
  assert.equal(nearby.hp, hp); assert.equal(game.nativeSpells.fields[0].remainingShare, 7 / 8);
  game.nativeSpells.clearRoom(); assert.deepEqual(game.nativeSpells.fields, []);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('heat fields share paid burn, deduplicate entrances and split one pulse among all contacts', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  game.config = { ...game.config, talents: ['T45'] }; game.relics.R153 = 1;
  const target = enemy(game), nearby = enemy(game, 1000); type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  game.nativeSpells.hit(reference, target, game.player);
  const field = runtime.active('field')[0], status = runtime.active('status')[0];
  assert.equal(runtime.active('field').length, 1);
  assert.equal(field.program.rules.find(rule => rule.definition.id === 'field.heat').sourceIds.length, 2);
  const left = runtime.balance(field.id, 'power'), attached = runtime.balance(status.id, 'power');
  assert.ok(left > 0 && Math.abs(attached - left) <= 2);
  const expectedPulse = runtime.ledger.getOwnedLots(field.id).reduce((sum, lot) => sum + Math.ceil(lot.quantityQ / 8), 0);
  nearby.x = target.x + 20; const committed = [];
  const damage = game.damage.bind(game); game.damage = (enemy, amount, ...args) => { committed.push([enemy.id, amount, args.at(-1)]); return damage(enemy, amount, ...args); };
  game.time = .5; game.nativeSpells.advance();
  const remaining = runtime.balance(field.id, 'power');
  const fieldHits = committed.filter(([, , reference]) => reference.objectId === field.id);
  assert.equal(remaining, left - expectedPulse);
  assert.deepEqual(fieldHits.map(([id]) => id), [target.id, nearby.id]);
  assert.equal(fieldHits.reduce((sum, [, value]) => sum + value * RESOURCE_SCALE, 0), expectedPulse);
  assert.equal(game.fields.length, 0); assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('longer fields spread the same cold across more pulses; expired unspent cold can be recovered once', () => {
  const totals = [];
  for (const longer of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T48', 'T09'] }; if (longer) game.relics.R154 = 1;
    const target = enemy(game); type(game, target);
    const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
    game.nativeSpells.hit(reference, target, game.player);
    const field = runtime.active('field')[0], cold = runtime.balance(field.id, 'cold'); totals.push(cold);
    assert.equal(field.expiresAtTick - field.createdAtTick, longer ? 360 : 240);
    assert.equal(field.remainingApplications, longer ? 12 : 8);
    target.x += 250; game.time = (field.expiresAtTick + 1) / 60; game.nativeSpells.advance();
    assert.equal(runtime.getObject(field.id).state, 'closed');
    const expected = Math.floor(cold * .5); assert.equal(runtime.balance(1, 'cold'), expected);
    const before = runtime.ledger.snapshot(); game.nativeSpells.advance(); assert.deepEqual(runtime.ledger.snapshot(), before);
    assert.deepEqual(game.nativeSpells.fields, []); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
  assert.equal(totals[0], totals[1]);
});

test('universal ongoing and heat fields work across book names while cold stays in its own effect', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  game.config = { ...game.config, talents: ['T45', 'T49'] };
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  game.nativeSpells.hit(reference, target, game.player);
  assert.equal(runtime.active('status').length, 1); assert.equal(runtime.active('field').length, 2);
  const status = runtime.active('status')[0]; assert.equal(runtime.balance(status.id, 'cold'), 0);
  assert.equal(runtime.balance(status.id, 'charge'), 0);
  assert.ok(runtime.active('field').some(field => runtime.balance(field.id, 'power') > 0));
  assert.ok(runtime.active('field').some(field => runtime.balance(field.id, 'cold') > 0));
  const retained = runtime.balance(status.id, 'power');
  game.config = { ...game.config, talents: [] }; game.time = .25; game.nativeSpells.advance();
  assert.equal(runtime.balance(status.id, 'power'), retained);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('trail contacts follow their finite capsule and the render projection preserves its endpoints', () => {
  const game = isolate(createGame(['alpha'], 'flame')), target = enemy(game, 640, 300), outside = enemy(game, 640, 400);
  type(game, target); const runtime = game.nativeSpells.runtime, root = runtime.active('spell').find(object => !object.derived);
  const result = runtime.createFinite({ kind: 'field', fromObjectId: root.id, share: .5,
    resourceShares: { heat: 0 }, tick: 0, delayTicks: 0, lifeTicks: 60, applications: 2, position: { x: 700, y: 300 },
    field: { shape: 'trail', from: { x: 500, y: 300 }, radius: 20, allocation: 'onContact', onFinish: 'lose' } }, 4);
  assert.equal(result.ok, true, JSON.stringify(result.errors));
  const field = result.value.objects[0], remaining = runtime.balance(field.id, 'power'), hp = target.hp, untouched = outside.hp;
  game.time = .5; game.nativeSpells.advance();
  assert.equal((hp - target.hp) * RESOURCE_SCALE, Math.ceil(remaining / 2)); assert.equal(outside.hp, untouched);
  const view = game.nativeSpells.fields[0]; assert.equal(view.x, 700); assert.equal(view.y, 300);
  assert.deepEqual(view.from, { x: 500, y: 300 }); assert.equal(view.r, 20);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('the ongoing talent improves the same finite retention pool for the native fire entrance', () => {
  const powers = [];
  for (const learned of [false, true]) {
    const game = isolate(createGame(['alpha'], 'flame')); game.config = { ...game.config, talents: learned ? ['T49'] : [] };
    const target = enemy(game); type(game, target); const runtime = game.nativeSpells.runtime;
    const reference = game.shots.find(shot => shot.spell).spell;
    const budget = burnBudget(runtime, reference.objectId, learned ? .99 : .9);
    game.nativeSpells.hit(reference, target, game.player);
    const status = runtime.active('status')[0], power = runtime.balance(status.id, 'power'); powers.push(power);
    assert.equal(power, budget.reduce((sum, part) => sum + part.kept, 0));
    assert.ok(power <= budget.reduce((sum, part) => sum + part.gross, 0));
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
  assert.ok(powers[1] > powers[0]);
});

test('native fire pays future burn from the same root and consumes it exactly once through expiry', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime;
  const reference = game.shots.find(shot => shot.spell).spell;
  const initial = totals(runtime) + runtime.balance(reference.objectId, 'heat') * 4;
  const parts = burnBudget(runtime, reference.objectId), loss = parts.reduce((sum, part) => sum + part.gross - part.kept, 0);
  game.nativeSpells.hit(reference, target, game.player);
  const status = runtime.active('status')[0];
  assert.ok(status); assert.equal(status.properties.material, 'heat');
  const ongoing = runtime.balance(status.id, 'power');
  assert.equal(ongoing, parts.reduce((sum, part) => sum + part.kept, 0));
  assert.equal(game.nativeSpells.summary.committedPower * RESOURCE_SCALE + ongoing + loss, initial);
  assert.equal(target.burn, undefined);
  game.time = 4; game.nativeSpells.advance();
  assert.equal(runtime.active('status').length, 0);
  assert.equal(game.nativeSpells.summary.committedPower * RESOURCE_SCALE + loss, initial);
  const hp = target.hp; game.nativeSpells.advance(); assert.equal(target.hp, hp);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('lethal fire recovers only its paid future burn once, and a later manual spell spends it', () => {
  const game = isolate(createGame(['alpha'], 'flame'));
  game.config = { ...game.config, talents: ['T07'] }; game.relics.R090 = 1;
  const target = enemy(game), survivor = enemy(game, 950); target.hp = 1;
  type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  const root = runtime.getObject(reference.objectId);
  const future = burnBudget(runtime, root.id);
  game.nativeSpells.hit(reference, target, game.player);
  assert.equal(target.dead, true); assert.equal(runtime.active('status').length, 0);
  const recovered = Math.min(32 * RESOURCE_SCALE, future.reduce((sum, part) => sum + Math.floor(part.kept * .5), 0));
  assert.equal(runtime.balance(1, 'power'), recovered);
  const before = runtime.ledger.snapshot(); game.nativeSpells.hit(reference, target, game.player);
  assert.deepEqual(runtime.ledger.snapshot(), before);
  type(game, survivor);
  const next = runtime.active('spell').find(object => !object.derived && object.rootReceiptId !== root.rootReceiptId);
  const reused = runtime.ledger.getOwnedLots(next.id).filter(lot => lot.origin.receiptId === root.rootReceiptId);
  assert.equal(reused.reduce((sum, lot) => sum + lot.quantityQ, 0), Math.min(12 * RESOURCE_SCALE, recovered));
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('extracting the previous manual target reduces future burn and waits beyond the extracting word', () => {
  const game = isolate(createGame(['alpha'], 'flame')); game.config = { ...game.config, talents: ['T08'] };
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  game.nativeSpells.hit(reference, target, game.player);
  const status = runtime.active('status')[0], original = runtime.balance(status.id, 'power');
  const shares = runtime.ledger.getOwnedLots(status.id).map(lot => Math.floor(lot.quantityQ * .25));
  type(game, enemy(game, 950));
  const extracted = shares.reduce((sum, value) => sum + value, 0), kept = shares.reduce((sum, value) => sum + Math.floor(value * .5), 0);
  assert.equal(runtime.balance(status.id, 'power'), original - extracted);
  assert.equal(runtime.balance(1, 'power'), kept);
  const extracting = runtime.active('spell').find(object => !object.derived && object.rootReceiptId !== status.rootReceiptId);
  assert.equal(runtime.ledger.getOwnedLots(extracting.id).some(lot => lot.origin.receiptId === status.rootReceiptId), false);
  type(game, enemy(game, 1200));
  const later = runtime.active('spell').find(object => !object.derived
    && object.rootReceiptId !== status.rootReceiptId && object.id !== extracting.id);
  assert.equal(runtime.ledger.getOwnedLots(later.id).filter(lot => lot.origin.receiptId === status.rootReceiptId)
    .reduce((sum, lot) => sum + lot.quantityQ, 0), kept);
  assert.equal(runtime.balance(1, 'power'), 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('recovery rules cannot be acquired retroactively by an existing burn', () => {
  const game = isolate(createGame(['alpha'], 'flame')), target = enemy(game);
  type(game, target); const runtime = game.nativeSpells.runtime;
  game.nativeSpells.hit(game.shots.find(shot => shot.spell).spell, target, game.player);
  const status = runtime.active('status')[0], power = runtime.balance(status.id, 'power');
  game.config = { ...game.config, talents: ['T07', 'T08'] };
  type(game, enemy(game, 950)); assert.equal(runtime.balance(status.id, 'power'), power);
  target.dead = true; game.nativeSpells.advance();
  assert.equal(runtime.active('status').length, 0); assert.equal(runtime.reserveUsageQ(), 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('a lethal burn tick recovers only the unpaid ticks within the same simulation boundary', () => {
  const game = isolate(createGame(['alpha'], 'flame')); game.config = { ...game.config, talents: ['T07'] };
  const target = enemy(game); enemy(game, 950); type(game, target);
  const runtime = game.nativeSpells.runtime;
  game.nativeSpells.hit(game.shots.find(shot => shot.spell).spell, target, game.player);
  const status = runtime.active('status')[0];
  const expected = runtime.ledger.getOwnedLots(status.id).filter(lot => lot.resource === 'power')
    .reduce((sum, lot) => sum + Math.floor((lot.quantityQ - Math.ceil(lot.quantityQ / status.remainingApplications)) * .5), 0);
  target.hp = 1; game.time = .5; game.nativeSpells.advance();
  assert.equal(target.dead, true); assert.equal(runtime.active('status').length, 0);
  assert.equal(runtime.balance(1, 'power'), expected);
  const before = runtime.ledger.snapshot(); game.nativeSpells.advance(); assert.deepEqual(runtime.ledger.snapshot(), before);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('metered reserve and long archive trade immediate use for duration and space', () => {
  for (const [talents, limit, capacity] of [[[], 12, 32], [['T10'], 9, 32], [['T11', 'K06'], 6, 48]]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T12', ...talents] };
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime;
    const reference = game.shots.find(shot => shot.spell).spell;
    const root = runtime.getObject(reference.objectId);
    game.nativeSpells.miss(reference); const stored = runtime.balance(1, 'power');
    type(game, enemy(game, 950));
    const next = runtime.active('spell').find(object => !object.derived);
    assert.equal(runtime.ledger.getOwnedLots(next.id).filter(lot => lot.origin.receiptId === root.rootReceiptId)
      .reduce((sum, lot) => sum + lot.quantityQ, 0), limit * RESOURCE_SCALE);
    assert.equal(runtime.balance(1, 'power'), stored - limit * RESOURCE_SCALE);
    assert.equal(next.program.numerics['reserve.capacityQ'], capacity * RESOURCE_SCALE);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('concentrated reserve uses actual manual target durability and pays a shared mixed-material burst', () => {
  for (const enhanced of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T12', 'T09', 'T29', 'T10', 'K07'] };
    if (enhanced) game.relics.R089 = 1;
    const first = enemy(game); type(game, first);
    const runtime = game.nativeSpells.runtime, origin = runtime.active('spell').find(object => !object.derived);
    game.nativeSpells.miss({ room: runtime.room, objectId: origin.id });
    const before = { power: runtime.balance(1, 'power'), cold: runtime.balance(1, 'cold') };
    const target = enemy(game, 900); type(game, target);
    const root = runtime.active('spell').find(object => !object.derived), share = enhanced ? .9 : .75;
    for (const resource of ['power', 'cold']) {
      const used = runtime.ledger.getOwnedLots(root.id).filter(lot => lot.origin.receiptId === origin.rootReceiptId && lot.resource === resource);
      assert.equal(used.reduce((sum, lot) => sum + lot.quantityQ, 0), Math.floor(before[resource] * share));
      assert.ok(used.every(lot => lot.remainingUses < 8));
    }
    assert.equal(runtime.manualCount, 2);
    const held = runtime.reserveUsageQ(), frozen = runtime.ledger.snapshot();
    game.config = { ...game.config, talents: ['T12', 'T09', 'T29', 'T10'] }; game.relics.R089 = 0;
    for (let i = 0; i < (enhanced ? 3 : 2); i++) {
      const next = enemy(game, 1100 + i * 10); type(game, next);
      assert.equal(runtime.reserveUsageQ(), held);
    }
    game.config = { ...game.config, talents: ['T12', 'T09', 'T29', 'T10', 'K07'] };
    if (enhanced) game.relics.R089 = 1;
    const normalUse = Math.floor(runtime.balance(1, 'power') * .5) + Math.floor(runtime.balance(1, 'cold') * .5) / 16;
    target.wordPending = false; type(game, target);
    assert.equal(held - runtime.reserveUsageQ(), normalUse); assert.ok(runtime.ledger.snapshot().lots.length > frozen.lots.length);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('weak manual targets use ordinary reserves even when another durable enemy is available', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  game.config = { ...game.config, talents: ['T12', 'T09', 'T29', 'K07'] };
  type(game, enemy(game)); const runtime = game.nativeSpells.runtime, first = runtime.active('spell').find(object => !object.derived);
  game.nativeSpells.miss({ room: runtime.room, objectId: first.id });
  const weak = enemy(game, 900); weak.hp = 1; enemy(game, 1000);
  const held = runtime.reserveUsageQ(); type(game, weak);
  assert.equal(held - runtime.reserveUsageQ(), 12 * RESOURCE_SCALE);
  type(game, enemy(game, 1100)); assert.ok(runtime.reserveUsageQ() < held - 12 * RESOURCE_SCALE);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('charge priority also orders concentrated material use without activating the normal rule again', () => {
  for (const priority of [false, true]) {
    const game = isolate(createGame(['alpha'], 'storm'));
    game.config = { ...game.config, talents: ['T17', 'T12', 'T09', 'T29'] };
    if (priority) game.relics.R116 = 1;
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime;
    const expected = { power: Math.floor(runtime.balance(1, 'power') * .75), charge: Math.floor(runtime.balance(1, 'charge') * .75) };
    game.config = { ...game.config, talents: [...game.config.talents, 'K07'] };
    const uses = [], useReserve = runtime.useReserve.bind(runtime);
    runtime.useReserve = (...args) => {
      const result = useReserve(...args);
      if (result.ok) uses.push([args[1], result.value.transaction.createdLotIds.reduce((sum, id) => sum + runtime.ledger.getLot(id).quantityQ, 0)]);
      return result;
    };
    type(game, enemy(game, 800));
    assert.equal(uses.length, 2); assert.equal(uses[0][0], priority ? 'charge' : 'power');
    assert.deepEqual(Object.fromEntries(uses), expected); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('empty reserve cooldown survives a formal room boundary and blocks newly recovered power', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  game.config = { ...game.config, talents: ['T12', 'T09', 'T29', 'K07'] };
  type(game, enemy(game)); const old = game.nativeSpells.runtime, first = old.active('spell').find(object => !object.derived);
  game.nativeSpells.miss({ room: old.room, objectId: first.id });
  type(game, enemy(game, 900)); // Real concentrated use starts two skipped completions.
  game.config = { ...game.config, talents: [] }; // No archive; the ticket must still carry the skipped words.
  game.nativeSpells.clearRoom(); game.roomVisit++; game.shots = []; game.enemies = []; game.cancel();
  game.config = { ...game.config, talents: ['T12'] };
  type(game, enemy(game)); const runtime = game.nativeSpells.runtime, next = runtime.active('spell').find(object => !object.derived);
  assert.equal(runtime.reserveUsageQ(), 0);
  game.nativeSpells.miss({ room: runtime.room, objectId: next.id }); const held = runtime.reserveUsageQ(); assert.ok(held > 0);
  type(game, enemy(game, 900)); assert.equal(runtime.reserveUsageQ(), held);
  type(game, enemy(game, 1100)); assert.ok(runtime.reserveUsageQ() < held);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('miss recovery shares material capacity and never launches the leftover closing spell', () => {
  for (const mixed of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T12', ...(mixed ? ['T09'] : [])] };
    const target = enemy(game); type(game, target);
    const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
    const power = runtime.balance(reference.objectId, 'power'), cold = runtime.balance(reference.objectId, 'cold');
    const shots = game.shots.length;
    target.dead = true; game.nativeSpells.miss(reference);
    assert.equal(runtime.balance(1, 'power'), Math.floor(power * .5));
    assert.equal(runtime.balance(1, 'cold'), mixed ? Math.floor(cold * .5) : 0);
    assert.ok(runtime.reserveUsageQ() <= 32 * RESOURCE_SCALE);
    assert.equal(runtime.active().length, 0); assert.equal(game.shots.length, shots);
    const before = runtime.ledger.snapshot(); game.nativeSpells.miss(reference);
    game.nativeSpells.advance(); assert.deepEqual(runtime.ledger.snapshot(), before);
    type(game, enemy(game, 950));
    const next = runtime.active('spell').find(object => !object.derived);
    const root = runtime.getObject(reference.objectId).rootReceiptId;
    assert.equal(runtime.ledger.getOwnedLots(next.id).filter(lot => lot.resource === 'power' && lot.origin.receiptId === root)
      .reduce((sum, lot) => sum + lot.quantityQ, 0), 12 * RESOURCE_SCALE);
    if (mixed) assert.equal(runtime.balance(1, 'cold'), Math.floor(cold * .5)); // Power used this word's shared allowance.
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('shell recovery handles expiry after release claims and cannot take a normally released spell', () => {
  for (const ending of ['release', 'expiry', 'echo', 'guard']) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T19', ...(ending === 'echo' || ending === 'guard' ? ['T22'] : []),
      ...(ending === 'guard' ? ['T21'] : [])] };
    game.relics.R092 = 1;
    if (ending === 'expiry' || ending === 'echo') game.relics.R075 = 1;
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    const saved = runtime.balance(shell.id, 'power');
    if (ending === 'guard') {
      game.bullet(game.player.x, game.player.y, 0, 0, '#ffaaaa');
      assert.ok(game.nativeSpells.intercept(game.bullets[0], 1) > 0);
    } else { game.time = (ending === 'release' ? shell.readyAtTick : shell.expiresAtTick) / 60; game.nativeSpells.advance(); }
    assert.equal(runtime.getObject(shell.id).state, 'closed');
    assert.equal(runtime.balance(1, 'power'), ending === 'expiry' ? Math.floor(saved * .5) : 0);
    assert.equal(runtime.active('spell').filter(object => object.exitOf === shell.id).length, ending === 'expiry' ? 0 : 1);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('formal clear-room archive loses a share, preserves origins and uses the next room first word budget', () => {
  for (const archive of [false, true]) {
    const game = isolate(createGame(['alpha'], 'frost'));
    game.config = { ...game.config, talents: ['T12', ...(archive ? ['T11'] : [])] };
    type(game, enemy(game)); const old = game.nativeSpells.runtime;
    const root = old.active('spell').find(object => !object.derived), power = old.balance(root.id, 'power');
    const initialUses = old.ledger.getOwnedLots(root.id).find(lot => lot.resource === 'power').remainingUses;
    const expected = archive ? Math.floor(Math.floor(power * .5) * .65) : 0;
    game.nativeSpells.clearRoom(); game.nativeSpells.clearRoom();
    game.roomVisit++; game.shots = []; game.enemies = []; game.cancel();
    type(game, enemy(game)); const runtime = game.nativeSpells.runtime;
    const next = runtime.active('spell').find(object => !object.derived);
    const inherited = runtime.ledger.getOwnedLots(next.id).filter(lot => lot.origin.receiptId === root.rootReceiptId);
    assert.equal(inherited.reduce((sum, lot) => sum + lot.quantityQ, 0), Math.min(expected, 12 * RESOURCE_SCALE));
    assert.equal(runtime.balance(1, 'power'), Math.max(0, expected - 12 * RESOURCE_SCALE));
    if (archive) {
      assert.ok(inherited.every(lot => lot.remainingUses === initialUses - 2));
      game.nativeSpells.clearRoom(); game.nativeSpells.reset();
      game.roomVisit++; game.shots = []; game.enemies = []; game.cancel();
      type(game, enemy(game)); assert.equal(game.nativeSpells.runtime.reserveUsageQ(), 0);
    }
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('lost-target shots and room cleanup retire ownership; previous room references cannot hit new objects', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const target = enemy(game); type(game, target);
  const old = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  target.dead = true; game.updateShots(.01);
  assert.equal(old.active().length, 0);
  game.nativeSpells.clearRoom(); game.roomVisit++; game.shots = []; game.enemies = [];
  const next = enemy(game); type(game, next);
  const hp = next.hp; game.nativeSpells.hit(reference, next, game.player);
  assert.equal(next.hp, hp); assert.equal(game.nativeSpells.accepts(reference), false);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('paper dives consume paid shared work; stopping input eventually leaves no repeatable attack source', () => {
  const game = isolate(createGame(['alpha'], 'spirit'));
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.balance(0, 'work'), RESOURCE_SCALE);
  assert.equal(runtime.active('spell').length, 3);
  step(game, 5);
  assert.equal(runtime.active().length, 0);
  const hp = target.hp; step(game, 2); assert.equal(target.hp, hp);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('stored copies take their shared work before paper attacks; neither entrance creates extra work', () => {
  const game = isolate(createGame(['alpha'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25'] };
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.active('shell').length, 1);
  assert.equal(runtime.balance(0, 'work'), RESOURCE_SCALE);
  assert.equal(game.awakenedSpirits, 0);
  target.wordPending = false; type(game, target);
  assert.equal(runtime.active('shell').length, 2);
  assert.equal(runtime.balance(0, 'work'), 0);
  assert.equal(game.awakenedSpirits, 1);
  game.updateSpirits(.01);
  assert.equal(runtime.active('shell').filter(page => page.state === 'carried').length, 1);
  assert.equal(runtime.storedCount(0), 1);
  assert.equal(game.nativeSpells.savedPages.length, 1);
  assert.equal(game.spirits[0].nativeSpell, undefined);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('fleet assembles compatible saved pages only at pickup and pays one actual transport attack', () => {
  const game = isolate(createGame(['abcdefghijklmnopqrst'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25', 'T27', 'K12'] };
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, pages = runtime.active('shell');
  assert.equal(pages.length, 4); assert.ok(pages.every(page => page.state === 'stored'));
  const expected = pages.reduce((sum, page) => sum + runtime.ledger.getOwnedLots(page.id)
    .reduce((value, lot) => value + Math.floor(lot.quantityQ * .9), 0), 0);
  const tickets = runtime.active('spell').filter(spell => spell.derived && spell.state === 'ready');
  assert.equal(tickets.length, 2); game.updateSpirits(.01);
  const cargo = runtime.active('shell')[0];
  assert.equal(runtime.active('shell').length, 1); assert.equal(cargo.state, 'carried');
  assert.ok(pages.every(page => runtime.getObject(page.id).state === 'closed'));
  assert.ok(!pages.some(page => page.id === cargo.id)); assert.equal(runtime.storedCount(0), 0);
  assert.equal(cargo.readyAtTick, 150); assert.equal(cargo.expiresAtTick, 600);
  assert.equal(runtime.balance(cargo.id, 'power'), expected);
  assert.equal(tickets.filter(ticket => runtime.getObject(ticket.id).state === 'closed').length, 1);
  assert.equal(game.spirits[0].nativeCargo.objectId, cargo.id);
  assert.ok(runtime.ledger.getOwnedLots(cargo.id).every(lot => lot.ruleClaims['native.transport.merge'] === 1
    && lot.ruleClaims['native.transport.take'] === 1));
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('fleet falls back to one page instead of grouping separate manual casts', () => {
  const game = isolate(createGame(['abcdef'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25', 'T27', 'K12'] };
  const target = enemy(game); type(game, target); target.wordPending = false; type(game, target);
  const runtime = game.nativeSpells.runtime, pages = runtime.active('shell'); assert.equal(pages.length, 2);
  const action = game.nativeSpells.takeSummon(target.id, 0, game.player);
  assert.ok(action.cargo); assert.equal(action.cargo.objectId, pages[0].id);
  assert.equal(runtime.getObject(pages[1].id).state, 'stored');
  assert.equal(runtime.getObject(pages[0].id).readyAtTick, pages[0].readyAtTick);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('solo courier takes the strongest nearby page without outgoing loss while other spirits attack', () => {
  const game = isolate(createGame(['abcdefghijklmnopqrstuv'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25', 'K13'] };
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, root = runtime.active('spell').find(spell => !spell.derived);
  const result = runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: .6, tick: 0,
    delayTicks: 120, lifeTicks: 600, applications: 1, properties: { material: 'paper', integrity: 1 } }, 6);
  assert.equal(result.ok, true); const strongest = result.value.objects[0], power = runtime.balance(strongest.id, 'power');
  assert.ok(runtime.active('shell').filter(page => page.id !== strongest.id).every(page => runtime.balance(page.id, 'power') < power));
  assert.ok(game.nativeSpells.takeSummon(target.id, 1, game.player).spell);
  assert.equal(runtime.getObject(strongest.id).state, 'stored');
  const courier = game.nativeSpells.takeSummon(target.id, 0, game.player);
  assert.equal(courier.cargo.objectId, strongest.id); assert.equal(runtime.balance(strongest.id, 'power'), power);
  assert.ok(game.nativeSpells.takeSummon(target.id, 2, game.player).spell);
  assert.equal(runtime.active('shell').filter(page => page.state === 'carried').length, 1);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('a live charged cargo relays one distant chain using two paid legs and its frozen permission', () => {
  for (const equippedAtCreation of [false, true]) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: ['T19', 'T20', 'T25', 'T52'] };
    if (equippedAtCreation) game.relics.R119 = 1;
    const distant = enemy(game); type(game, distant); game.updateSpirits(.01);
    const spirit = game.spirits[0]; assert.ok(spirit?.nativeCargo);
    const runtime = game.nativeSpells.runtime, cargoId = spirit.nativeCargo.objectId;
    const charge = runtime.balance(cargoId, 'charge'), power = runtime.balance(cargoId, 'power');
    assert.ok(charge >= RESOURCE_SCALE / 2);
    // These are actual actor/world positions sampled by the formal relay selector.
    spirit.x = 500; spirit.y = 300; distant.x = 750; distant.y = 300;
    const source = enemy(game, 250, 300), before = distant.hp;
    game.relics.R119 = 1; game.config = { ...game.config, talents: ['T25', 'T52'] };
    const arcs = []; game.arc = (from, to) => arcs.push([from.x, to.x]);
    type(game, source);
    assert.equal(distant.hp < before, equippedAtCreation);
    assert.equal(runtime.balance(cargoId, 'charge'), charge - (equippedAtCreation ? RESOURCE_SCALE / 2 : 0));
    assert.equal(runtime.balance(cargoId, 'power'), power);
    assert.equal(!!runtime.getObject(cargoId).relayed, equippedAtCreation);
    if (equippedAtCreation) {
      assert.ok(arcs.some(([from, to]) => from === 250 && to === 500));
      assert.ok(arcs.some(([from, to]) => from === 500 && to === 750));
      const after = distant.hp; source.wordPending = false; type(game, source);
      assert.equal(distant.hp, after); assert.equal(runtime.balance(cargoId, 'charge'), charge - RESOURCE_SCALE / 2);
    }
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('a passive heat field relays from its frozen permission, spends its own future share and adds no field damage', () => {
  for (const equipped of [false, true]) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: ['T49', 'T45', 'T48', ...(equipped ? ['T47'] : [])] };
    const oldTarget = enemy(game, 500); type(game, oldTarget); oldTarget.dead = true;
    const runtime = game.nativeSpells.runtime, field = runtime.active('field')[0]; assert.ok(field);
    const power = runtime.balance(field.id, 'power'), used = runtime.ledger.getOwnedLots(field.id).reduce((sum, lot) => sum + Math.ceil(lot.quantityQ / 8), 0);
    assert.equal(runtime.balance(field.id, 'charge'), 0);
    game.config = { ...game.config, talents: ['T47'] };
    const far = enemy(game, 750), arcs = [];
    game.arc = (from, to) => arcs.push([from.x, to.x]); type(game, enemy(game, 250));
    assert.equal(far.hp < far.maxHp, equipped);
    assert.equal(runtime.getObject(field.id).remainingApplications, equipped ? 7 : 8);
    assert.equal(runtime.balance(field.id, 'power'), power - (equipped ? used : 0));
    assert.equal(runtime.balance(field.id, 'charge'), 0);
    const before = runtime.balance(field.id, 'power'), hp = far.hp;
    type(game, enemy(game, 250)); assert.equal(far.hp, hp); assert.equal(runtime.balance(field.id, 'power'), before);
    if (equipped) for (const [a, b] of [[250, 500], [500, 750]]) assert.ok(arcs.some(([x, y]) => x === a && y === b));
    const recovery = runtime.ledger.getOwnedLots(field.id).filter(lot => lot.resource === 'power')
      .reduce((sum, lot) => sum + Math.floor(lot.quantityQ * .5), 0);
    game.time = (field.expiresAtTick + 1) / 60; game.nativeSpells.advance();
    assert.equal(runtime.balance(1, 'power'), recovery);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('field relay range belongs to the stored area, and its final opportunity closes it without recovery', () => {
  for (const [extended, last] of [[false, false], [true, false], [true, true]]) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: ['T49', 'T45', 'T47', 'T48'] }; if (extended) game.relics.R120 = 1;
    const oldTarget = enemy(game, 500); type(game, oldTarget);
    const runtime = game.nativeSpells.runtime, field = runtime.active('field')[0];
    if (last) for (let i = 0; i < 7; i++) assert.equal(runtime.applyField(field.id, [oldTarget.id]).ok, true);
    oldTarget.dead = true; game.relics = {}; game.config = { ...game.config, talents: [] };
    const far = enemy(game, 830); type(game, enemy(game, 250));
    assert.equal(far.hp < far.maxHp, extended);
    assert.equal(runtime.getObject(field.id).state, last ? 'closed' : 'stored');
    if (last) {
      assert.equal(runtime.balance(field.id, 'power'), 0); assert.equal(runtime.balance(1, 'power'), 0);
      assert.deepEqual(game.nativeSpells.fields, []);
    }
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('stationary bridges use their frozen entrance and fee and preserve the saved attack', () => {
  for (const entrance of ['none', 'T14', 'R111', 'both']) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: ['T01', ...(entrance === 'T14' || entrance === 'both' ? ['T14'] : [])] };
    if (entrance === 'R111' || entrance === 'both') game.relics.R111 = 1;
    if (entrance === 'both') game.relics.R114 = 1;
    game.player.x = 500; game.player.y = 300;
    const oldTarget = enemy(game, 1400); type(game, oldTarget); oldTarget.dead = true;
    const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
    const charge = runtime.balance(shell.id, 'charge'), power = runtime.balance(shell.id, 'power');
    assert.ok(charge >= RESOURCE_SCALE / 2);
    // Later acquisitions/removals change the next cast, not the already stored bridge.
    game.config = { ...game.config, talents: ['T14'] }; game.relics = {};
    const far = enemy(game, 750), source = enemy(game, 250), arcs = [];
    game.arc = (from, to) => arcs.push([from.x, to.x]); type(game, source);
    const allowed = entrance !== 'none', cost = Math.floor(RESOURCE_SCALE / 2 / (entrance === 'both' ? 1.25 : 1));
    assert.equal(far.hp < far.maxHp, allowed);
    assert.equal(runtime.balance(shell.id, 'charge'), charge - (allowed ? cost : 0));
    assert.equal(runtime.balance(shell.id, 'power'), power);
    assert.equal(runtime.getObject(shell.id).state, 'stored');
    assert.equal(runtime.getObject(shell.id).expiresAtTick, shell.expiresAtTick);
    assert.equal(!!runtime.getObject(shell.id).relayed, allowed);
    if (allowed) {
      assert.ok(arcs.some(([a, b]) => a === 250 && b === 500));
      assert.ok(arcs.some(([a, b]) => a === 500 && b === 750));
      const hp = far.hp; source.wordPending = false; type(game, source); assert.equal(far.hp, hp);
    }
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('corridor crosses consecutive stored spells while ordinary routing cannot skip a missing leg', () => {
  for (const corridor of [false, true]) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: ['T01', 'T14'] };
    const oldTarget = enemy(game, 1500);
    for (const x of [500, 800]) {
      game.player.x = x; game.player.y = 300; oldTarget.wordPending = false; type(game, oldTarget);
    }
    oldTarget.dead = true;
    const runtime = game.nativeSpells.runtime, shells = runtime.active('shell'); assert.equal(shells.length, 2);
    const charges = shells.map(shell => runtime.balance(shell.id, 'charge'));
    game.config = { ...game.config, talents: ['T14', 'T15', ...(corridor ? ['K08'] : [])] };
    const far = enemy(game, 1100), first = enemy(game, 200), arcs = [];
    game.arc = (from, to) => arcs.push([from.x, to.x]); type(game, first);
    assert.equal(far.hp < far.maxHp, corridor);
    shells.forEach((shell, i) => {
      assert.equal(runtime.balance(shell.id, 'charge'), charges[i] - (corridor ? RESOURCE_SCALE / 2 : 0));
      assert.equal(!!runtime.getObject(shell.id).relayed, corridor);
    });
    if (corridor) for (const segment of [[200, 500], [500, 800], [800, 1100]])
      assert.ok(arcs.some(([a, b]) => a === segment[0] && b === segment[1]), JSON.stringify(arcs));
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('empty or expired pages cannot relay and a direct target never consumes a stationary bridge', () => {
  for (const condition of ['no-charge', 'expired', 'direct']) {
    const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
    game.config = { ...game.config, talents: [condition === 'no-charge' ? 'T19' : 'T01', 'T14'] };
    game.player.x = 500; game.player.y = 300;
    const oldTarget = enemy(game, 1400); type(game, oldTarget); oldTarget.dead = true;
    const runtime = game.nativeSpells.runtime, shells = runtime.active('shell'); assert.ok(shells.length);
    const charges = shells.map(shell => runtime.balance(shell.id, 'charge'));
    game.config = { ...game.config, talents: ['T14'] };
    if (condition === 'expired') game.time = shells[0].expiresAtTick / 60;
    const far = enemy(game, 750); type(game, enemy(game, condition === 'direct' ? 550 : 250));
    assert.equal(far.hp < far.maxHp, condition === 'direct');
    shells.forEach((shell, i) => {
      assert.equal(runtime.balance(shell.id, 'charge'), charges[i]);
      assert.equal(runtime.getObject(shell.id).relayed, undefined);
    });
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('single-route focus reduces real storm landings and concentrates only the same total power', () => {
  const outcomes = [];
  for (const focused of [false, true]) {
    const game = isolate(createGame(['abcdef'], 'storm'));
    game.config = { ...game.config, talents: ['T14', 'T15', 'K08'] };
    if (focused) game.relics.R118 = 1;
    const first = enemy(game, 400), next = enemy(game, 500); type(game, first);
    outcomes.push({ first: first.maxHp - first.hp, next: next.maxHp - next.hp, total: game.nativeSpells.summary.committedPower });
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
  assert.ok(outcomes[0].next > 0); assert.equal(outcomes[1].next, 0);
  assert.ok(outcomes[1].first > outcomes[0].first); assert.equal(outcomes[0].total, outcomes[1].total);
});

test('a directly reachable target keeps its route and does not spend nearby cargo charge', () => {
  const game = isolate(createGame(['abcdefghijklmnopqr'], 'storm'));
  game.config = { ...game.config, talents: ['T19', 'T20', 'T25', 'T52'] }; game.relics.R119 = 1;
  const target = enemy(game); type(game, target); game.updateSpirits(.01);
  const spirit = game.spirits[0], runtime = game.nativeSpells.runtime, cargoId = spirit.nativeCargo.objectId;
  spirit.x = 500; spirit.y = 300; target.x = 750; target.y = 300;
  const charge = runtime.balance(cargoId, 'charge'), before = target.hp;
  game.config = { ...game.config, talents: ['T25', 'T52'] };
  type(game, enemy(game, 550, 300));
  assert.ok(target.hp < before); assert.equal(runtime.balance(cargoId, 'charge'), charge);
  assert.equal(runtime.getObject(cargoId).relayed, undefined);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('physical transport replaces a paid dive, waits for preparation and delivers the cargo once', () => {
  const game = isolate(createGame(['abcdef'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25'] }; game.relics.R079 = 1;
  const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, page = runtime.active('shell')[0];
  const savedPower = runtime.balance(page.id, 'power');
  // Isolate the transported attack while keeping its genuinely paid ticket and cargo.
  for (const shot of game.shots) if (shot.spell) assert.equal(runtime.discard(shot.spell.objectId).ok, true);
  game.shots = [];
  step(game, 1);
  assert.equal(runtime.getObject(page.id).state, 'carried');
  assert.ok(game.spirits[0].nativeCargo);
  assert.equal(runtime.balance(page.id, 'power'), Math.floor(savedPower * .9));
  assert.equal(target.hp, target.maxHp);
  step(game, 1.5);
  assert.equal(runtime.getObject(page.id).state, 'closed');
  assert.equal(game.nativeSpells.summary.committedPower, Math.floor(savedPower * .9) / RESOURCE_SCALE);
  const hp = target.hp; step(game, 2);
  assert.equal(target.hp, hp); assert.equal(runtime.manualCount, 1);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('transport permission and pickup range belong to the stored spell, not later acquisitions', () => {
  const game = isolate(createGame(['abcdef'], 'spirit'));
  game.config = { ...game.config, talents: ['T19'] }; const target = enemy(game); type(game, target);
  const runtime = game.nativeSpells.runtime, oldPage = runtime.active('shell')[0];
  game.config = { ...game.config, talents: ['T19', 'T25'] };
  const first = game.nativeSpells.takeSummon(target.id, 7, game.player);
  assert.ok(first.spell); assert.equal(first.cargo, undefined); assert.equal(runtime.getObject(oldPage.id).state, 'stored');
  target.wordPending = false; type(game, target);
  const nextPage = runtime.active('shell').find(page => page.id !== oldPage.id);
  const distant = game.nativeSpells.takeSummon(target.id, 8, { x: game.player.x + 300, y: game.player.y });
  assert.ok(distant.spell); assert.equal(runtime.getObject(nextPage.id).state, 'stored');
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('lost-target cargo physically returns once, pays its loss and preserves its original deadline', () => {
  for (const rope of [false, true]) {
    const game = isolate(createGame(['abcdef'], 'spirit'));
    game.config = { ...game.config, talents: ['T19', 'T25', 'T26'] };
    if (rope) game.relics.R080 = 1;
    const target = enemy(game); type(game, target); step(game, .1);
    const runtime = game.nativeSpells.runtime, cargo = runtime.active('shell')[0], carriedPower = runtime.balance(cargo.id, 'power');
    assert.equal(cargo.state, 'carried'); target.dead = true;
    game.updateSpirits(.001);
    assert.equal(runtime.getObject(cargo.id).state, 'carried');
    assert.equal(runtime.getObject(cargo.id).transport.returning, true);
    assert.equal(runtime.storedCount(Math.floor(game.time * 60)), 0);
    step(game, .8);
    const returned = runtime.getObject(cargo.id);
    assert.equal(returned.state, 'stored'); assert.equal(returned.transportReturned, true);
    assert.equal(returned.expiresAtTick, cargo.expiresAtTick); assert.equal(returned.createdAtTick, cargo.createdAtTick);
    assert.equal(runtime.balance(cargo.id, 'power'), Math.floor(carriedPower * (rope ? .9 : .8)));
    assert.equal(game.spirits[0].nativeCargo, undefined);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('lost cargo never uses the shell echo exit, and only its frozen recovery can reclaim its remainder', () => {
  for (const recover of [false, true]) {
    const game = isolate(createGame(['abcdef'], 'spirit'));
    game.config = { ...game.config, talents: ['T19', 'T25', 'T22', ...(recover ? ['T12'] : [])] };
    const target = enemy(game); type(game, target); game.updateSpirits(.01);
    const runtime = game.nativeSpells.runtime, cargo = runtime.active('shell')[0], power = runtime.balance(cargo.id, 'power');
    target.dead = true; game.updateSpirits(.01);
    assert.equal(runtime.getObject(cargo.id).state, 'closed');
    assert.equal(runtime.active('spell').filter(spell => spell.exitOf === cargo.id).length, 0);
    assert.equal(runtime.balance(1, 'power'), recover ? Math.floor(power * .5) : 0);
    const before = runtime.ledger.snapshot(); game.nativeSpells.cancelTransport({ room: runtime.room, objectId: cargo.id });
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('non-paper books can fund the same physical spirits without a free repeatable attack', () => {
  for (const entry of ['T52', 'spirit', 'bond']) {
    const game = isolate(createGame(['abcdef'], 'frost'));
    game.config = { ...game.config, talents: ['T19', 'T25', ...(entry === 'T52' ? [entry] : [])] };
    if (entry !== 'T52') game.relics[entry] = 1;
    const target = enemy(game); type(game, target);
    assert.equal(game.nativeSpells.enabled, true); game.updateSpirits(.01);
    const runtime = game.nativeSpells.runtime;
    assert.equal(game.spirits.length, 1); assert.ok(game.spirits[0].nativeCargo);
    assert.equal(runtime.active('shell')[0].state, 'carried');
    step(game, 5); const hp = target.hp; step(game, 3); assert.equal(target.hp, hp);
    assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('return arrival with full storage recovers only cargo remainder and creates no phantom slot', () => {
  const game = isolate(createGame(['abcdef'], 'spirit'));
  game.config = { ...game.config, talents: ['T19', 'T25', 'T26', 'T12', 'T22'] };
  const target = enemy(game); type(game, target); game.updateSpirits(.01);
  const runtime = game.nativeSpells.runtime, cargo = runtime.active('shell')[0], ref = game.spirits[0].nativeCargo;
  const power = runtime.balance(cargo.id, 'power');
  assert.equal(game.nativeSpells.returnTransport(ref, 0), true);
  const root = runtime.active('spell').find(spell => !spell.derived);
  for (let i = 0; i < 6; i++) assert.equal(runtime.createFinite({ kind: 'shell', fromObjectId: root.id, share: .05,
    tick: 0, delayTicks: 120, lifeTicks: 600, applications: 1, properties: { material: 'paper', integrity: 1 } }, 6).ok, true);
  assert.equal(runtime.storedCount(0), 6);
  game.nativeSpells.finishTransportReturn(ref, 0, game.player);
  assert.equal(runtime.getObject(cargo.id).state, 'closed'); assert.equal(runtime.storedCount(0), 6);
  assert.equal(runtime.balance(1, 'power'), Math.floor(power * .5));
  assert.equal(runtime.active('spell').filter(spell => spell.exitOf === cargo.id).length, 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('cargo expires in transit and removed spirits cannot leave orphaned resources or extra echo damage', () => {
  for (const removal of ['expiry', 'spirit', 'room']) {
    const game = isolate(createGame(['abcdef'], 'spirit'));
    game.config = { ...game.config, talents: ['T19', 'T25', 'T22'] };
    const target = enemy(game); type(game, target); game.updateSpirits(.01);
    const runtime = game.nativeSpells.runtime, cargo = runtime.active('shell')[0], ref = game.spirits[0].nativeCargo;
    if (removal === 'expiry') { game.time = cargo.expiresAtTick / 60; game.nativeSpells.advance(); }
    else if (removal === 'spirit') { game.spiritTime = 0; game.updateSpirits(.01); }
    else game.nativeSpells.clearRoom();
    assert.equal(runtime.getObject(cargo.id).state, 'closed');
    assert.equal(runtime.balance(cargo.id, 'power'), 0);
    assert.equal(runtime.active('spell').filter(spell => spell.exitOf === cargo.id).length, 0);
    const before = runtime.ledger.snapshot(); game.nativeSpells.cancelTransport(ref);
    game.nativeSpells.finishTransportReturn(ref, 0, game.player);
    assert.deepEqual(runtime.ledger.snapshot(), before); assert.deepEqual(game.nativeSpells.diagnostics, []);
  }
});

test('transported inherited ice form keeps its real material, target and remaining applications', () => {
  const game = isolate(createGame(['abcdefgh'], 'frost'));
  game.config = { ...game.config, talents: ['T19', 'T20', 'T25', 'T52'] };
  const target = enemy(game), destination = enemy(game, 720, 400); type(game, target);
  const runtime = game.nativeSpells.runtime, shell = runtime.active('shell')[0];
  const materials = runtime.ledger.getOwnedLots(shell.id);
  const action = game.nativeSpells.takeSummon(destination.id, 4, game.player);
  assert.ok(action.cargo); assert.equal(runtime.getObject(shell.id).shape, 'pierce');
  game.time = shell.readyAtTick / 60;
  assert.equal(game.nativeSpells.deliverTransport(action.cargo, 4, destination, destination), true);
  const delivered = runtime.getObject(shell.id);
  assert.equal(delivered.state, 'flight'); assert.equal(delivered.targetId, destination.id);
  assert.deepEqual(delivered.position, { x: destination.x, y: destination.y });
  assert.equal(delivered.program, shell.program); assert.equal(delivered.remainingApplications, shell.remainingApplications);
  for (const lot of materials) assert.equal(runtime.ledger.getLot(lot.lotId).quantityQ, Math.floor(lot.quantityQ * .9));
  assert.ok(game.shots.some(shot => shot.spell?.objectId === shell.id));
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('catalog migration selects a complete cast owner and preserves income accumulated by both owners', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  game.relics.emberink = 1;
  const target = enemy(game); type(game, target);
  const native = game.nativeSpells.runtime;
  game.relics['thermal-wick'] = 1; target.wordPending = false; type(game, target);
  assert.equal(game.nativeSpells.enabled, false); // These coexisting legacy assets cannot both alias a max-one relic.
  assert.equal(native.manualCount, 1);
  assert.equal(game.weave.summary.manualCharacters, 5);
  assert.equal(game.nativeSpells.summary.manualCharacters, 5);
  let result; game.events.result = value => result = value;
  game.end(false);
  assert.equal(result.manualCharacters, 10);
  assert.equal(result.weave.manualCharacters, 10);
});

test('capturing spell positions never freezes live dash state or enemy status collections', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const target = enemy(game);
  game.player.dashState = { x: 0, y: 0, tx: 5, ty: 8, time: 0, duration: 1, trail: 0 };
  target.letterMarks = { word: 'alpha', positions: [1] };
  type(game, target);
  const runtime = game.nativeSpells.runtime, reference = game.shots.find(shot => shot.spell).spell;
  assert.deepEqual(Object.keys(runtime.getObject(reference.objectId).position), ['x', 'y']);
  assert.equal(Object.isFrozen(game.player.dashState), false);
  game.nativeSpells.hit(reference, target, game.player);
  assert.equal(Object.isFrozen(target.letterMarks.positions), false);
  target.letterMarks.positions.push(2);
  assert.deepEqual(Object.keys(runtime.getObject(reference.objectId).position), ['x', 'y']);
});

test('a paid lethal hit does not also run a legacy flat-damage shatter', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const target = enemy(game), neighbour = enemy(game, 670);
  target.hp = 1; target.freeze = 2;
  type(game, target);
  const reference = game.shots.find(shot => shot.spell).spell;
  game.nativeSpells.hit(reference, target, game.player);
  assert.equal(target.dead, true);
  assert.equal(neighbour.hp, neighbour.maxHp);
  assert.ok(game.nativeSpells.runtime.balance(reference.objectId, 'power') > 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});

test('the real room boundary carries only permitted reserves and reset discards the expedition ticket', () => {
  const game = isolate(createGame(['alpha'], 'frost'));
  const target = enemy(game); type(game, target);
  const old = game.nativeSpells.runtime, root = game.shots.find(shot => shot.spell).spell.objectId;
  const original = old.ledger.getOwnedLots(root)[0].origin.receiptId;
  assert.equal(old.recover(root, 'power', .5, .5, 100 * RESOURCE_SCALE, 'nextRoom').ok, true);
  const expected = old.balance(1, 'power'); assert.ok(expected > 0);
  game.nativeSpells.clearRoom(); game.nativeSpells.clearRoom();
  game.roomVisit++; game.shots = []; game.enemies = []; game.cancel();
  const next = enemy(game); type(game, next);
  const runtime = game.nativeSpells.runtime;
  assert.equal(runtime.balance(1, 'power'), expected);
  assert.equal(runtime.reserveEntries()[0].availableAfterManual, 1);
  assert.equal(runtime.ledger.getOwnedLots(1)[0].origin.receiptId, original);
  assert.equal(runtime.manualCount, 1);
  const nextRoot = game.shots.find(shot => shot.spell).spell.objectId;
  assert.equal(runtime.useReserve(nextRoot, 'power', expected).ok, true);
  assert.equal(runtime.balance(1, 'power'), 0);
  assert.equal(runtime.recover(nextRoot, 'power', .5, .5, 100 * RESOURCE_SCALE, 'nextRoom').ok, true);
  game.nativeSpells.clearRoom(); game.nativeSpells.reset();
  game.roomVisit++; game.shots = []; game.enemies = []; game.cancel();
  type(game, enemy(game));
  assert.equal(game.nativeSpells.runtime.balance(1, 'power'), 0);
  assert.deepEqual(game.nativeSpells.diagnostics, []);
});
