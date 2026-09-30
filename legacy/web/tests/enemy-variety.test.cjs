const test = require("node:test");
const assert = require("node:assert/strict");
const { createGame, isolate } = require("./harness.cjs");
const { WordPool } = require("../src/vocabulary/index.ts");
const { random, hash } = require("../src/shared/math.ts");
const { enemyAttack } = require("../src/simulation/systems/EnemySystem.ts");
const { choosePreferredWord, chooseEnemyWord } = require("../src/simulation/targeting/EliteWords.ts");
const { enemyActions } = require("../src/content/shared/enemy-actions.ts");
const { manifest } = require("../src/content/manifest.ts");
const { validateContent } = require("../src/content-sdk/validate.ts");

test("content attack sequences rotate by release while absent sequences keep their legacy action", () => {
  for (const [type, expected] of [
    ["quill", ["fan", "curve", "fan"]],
    ["binder", ["bind", "laser", "bind"]],
    ["mortar", ["bombard", "crossfire", "bombard"]],
    ["nib", ["pursue", "pursue", "pursue"]],
  ]) {
    const behavior = manifest.enemies.find((entry) => entry.id === type).behavior;
    const calls = [];
    let rolls = 0;
    const context = {
      canEnemyAct: (enemy) => !enemy.dead && enemy.inCombat,
      inAttackRange: (enemy) => enemy.inRange,
      enemyProfile: () => behavior,
      eliteProfile: () => undefined,
      content: { enemyActions: Object.fromEntries(Object.keys(enemyActions).map((id) => [id, () => calls.push(id)])) },
      pressure: { attack: 1 },
      rng: () => { rolls++; return 0.5; },
    };
    const enemy = { attackIndex: 0, inCombat: true, inRange: true, dead: false };
    for (let i = 0; i < 3; i++) enemyAttack.call(context, enemy);
    assert.deepEqual(calls, expected, type);
    assert.equal(enemy.attackIndex, behavior.attackSequence ? 3 : 0);
    assert.equal(rolls, behavior.cooldown === undefined ? 3 : 0, "sequence selection adds no RNG calls");
    for (const state of [{ dead: true }, { inCombat: false }, { inRange: false }]) {
      const blocked = { ...enemy, ...state };
      enemyAttack.call(context, blocked);
      assert.equal(blocked.attackIndex, enemy.attackIndex);
      assert.equal(calls.length, 3);
    }
  }
});

test("crossfire creates two visible delayed blast zones with a center passage and no extra RNG", () => {
  const game = isolate(createGame(["cat"]));
  const enemy = game.spawnEnemy("mortar", 500, 400, false, true);
  const hp = game.player.hp;
  game.rng = () => { throw Error("crossfire must not consume randomness"); };
  enemyActions.crossfire(game, enemy);
  assert.equal(game.blasts.length, 2);
  assert.deepEqual(game.blasts.map((blast) => blast.x), [game.player.x - 110, game.player.x + 110]);
  for (const blast of game.blasts) {
    assert.equal(blast.y, game.player.y);
    assert.equal(blast.r, 65);
    assert.ok(blast.warning >= 1.2);
    assert.equal(blast.max, blast.warning);
    assert.equal(blast.ring, true);
    assert.equal(blast.fired, false);
    assert.equal(blast.source, enemy.id);
    assert.ok(Math.abs(blast.x - game.player.x) > blast.r + game.player.r);
  }
  assert.equal(game.player.hp, hp);
  game.blasts = [];
  game.player.x = game.arena.l + 30;
  enemy.x = game.player.x + 100;
  enemyActions.crossfire(game, enemy);
  assert.equal(game.blasts[0].x, game.arena.l + 20, "existing blast clamping handles edges");
});

test("punctuated preference uses only selected words and preserves their meanings", () => {
  const words = [{ word: "cat", meaning: "猫" }, { word: "x-ray", meaning: "X射线" }, { word: "can't", meaning: "不能" }];
  const pool = new WordPool(words, () => 0);
  const preferred = choosePreferredWord(pool, [], 1, 24, "punctuated", () => 0);
  assert.ok(/[\-']/.test(preferred.word));
  assert.deepEqual(preferred, words.find((word) => word.word === preferred.word));
  const allowed = new Set(words.map((word) => word.word));
  for (let seed = 0; seed < 100; seed++) {
    const rng = random(hash(seed));
    const source = new WordPool(words, rng);
    assert.ok(allowed.has(choosePreferredWord(source, [], 1, 24, "punctuated", rng).word));
  }
  assert.equal(pool.words.length, words.length);
});

test("missing candidates and single-word vocabularies fall back without consuming a preference roll", () => {
  const forbiddenRoll = () => { throw Error("unavailable preference must not consume a roll"); };
  for (const words of [["cat"], ["x-ray"], ["cat", "dog"], ["x-ray", "can't"]]) {
    const source = new WordPool(words, random(42));
    const baseline = new WordPool(words, random(42));
    for (let i = 0; i < 6; i++)
      assert.deepEqual(choosePreferredWord(source, [], 1, 6, "punctuated", forbiddenRoll), baseline.choose([], 1, 6));
  }
});

test("punctuated preference respects progressive length and global initial, duplicate and recency priorities", () => {
  const pool = (words) => new WordPool(words, () => 0);
  assert.equal(choosePreferredWord(pool(["cat", "x-ray"]), [], 1, 3, "punctuated", () => 0).word, "cat");
  assert.equal(choosePreferredWord(pool(["cat", "x-ray"]), [{ word: "xeno" }], 1, 24, "punctuated", () => 0).word, "cat");
  assert.equal(choosePreferredWord(pool(["cat", "x-ray"]), [{ word: "cat" }, { word: "x-ray" }], 1, 24, "punctuated", () => 0).word, "x-ray");
  assert.equal(choosePreferredWord(pool(["cat", "x-ray"]), [{ word: "cow" }, { word: "x-ray" }], 1, 24, "punctuated", () => 0).word, "cat");
  const recentPool = pool(["cat", "x-ray"]);
  recentPool.recent.push("x-ray");
  assert.equal(choosePreferredWord(recentPool, [], 1, 24, "punctuated", () => 0).word, "cat");
  const context = {
    pool: pool(["cat", "x-ray"]), targets: () => [], config: { progressive: true },
    mode: { baseLen: 3, rank: 1 }, chapter: 0, loopCount: 0, rng: () => 0,
  };
  assert.equal(chooseEnemyWord(context, false, null, "punctuated").word, "cat");
  context.chapter = 2;
  let roll = 0;
  context.rng = () => roll++ === 0 ? 0.8 : 0;
  assert.equal(chooseEnemyWord(context, false, null, "punctuated").word, "x-ray");
});

test("punctuated subpools are cached and feed chosen words back into the main recency history", () => {
  const source = new WordPool(["cat", "x-ray", "can't"], () => 0);
  choosePreferredWord(source, [], 1, 24, "punctuated", () => 0);
  assert.deepEqual(source.recent, ["x-ray"]);
  Object.defineProperty(source.words, "filter", { value: () => { throw Error("full corpus rescanned"); } });
  const next = choosePreferredWord(source, [], 1, 24, "punctuated", () => 0);
  assert.equal(next.word, "can't");
  assert.deepEqual(source.recent, ["x-ray", "can't"]);
});

test("spawn and refresh use elite metadata and never rewrite a word currently being typed", () => {
  const game = isolate(createGame(["cat", "x-ray", "can't"]));
  game.stage = 1;
  game.wave = 2;
  game.pressure.elite = 1;
  game.config.progressive = false;
  // elite roll, elite choice (iron), preference roll, pool draw, shoot, phase.
  const rolls = [0, 0.3, 0, 0, 0, 0];
  let used = 0;
  game.rng = () => rolls[used++] ?? 0;
  game.pool = new WordPool(["cat", "x-ray", "can't"], () => game.rng());
  const enemy = game.spawnEnemy("quill", 500, 400, false, true);
  assert.equal(enemy.elite, "iron");
  assert.ok(/[\-']/.test(enemy.word));
  assert.equal(used, 6, "spawn does not draw an ordinary word and discard it");
  enemy.elite = "echo";
  game.pool = new WordPool(["cat", "x-ray", "can't"], () => 0);
  game.rng = () => 0;
  game.target = enemy;
  game.prefix = enemy.word[0];
  const original = enemy.word;
  const word = game.wordFor(false, enemy);
  assert.ok(/[\-']/.test(word.word));
  assert.equal(enemy.word, original);
  assert.equal(game.prefix, original[0]);
});

test("content validation rejects empty or malformed sequences and unsupported word preferences", () => {
  validateContent(manifest);
  for (const sequence of [[], "fan", ["bad action"], [null], ["UPPER"], [""]]) {
    const copy = structuredClone(manifest);
    copy.enemies[0].behavior.attackSequence = sequence;
    assert.throws(() => validateContent(copy), /attack sequence|sequence attack/);
  }
  const copy = structuredClone(manifest);
  copy.elites[0].wordPreference = "phrase";
  assert.throws(() => validateContent(copy), /word preference/);
  for (const enemy of manifest.enemies)
    for (const id of enemy.behavior.attackSequence ?? [])
      assert.equal(typeof enemyActions[id], "function", `${enemy.id}:${id}`);
});
