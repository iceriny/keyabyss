const test = require("node:test"),
  assert = require("node:assert/strict");
const { createGame, isolate, step, C } = require("./harness.cjs");
const { inClearArena, clearArena } = require("../src/shared/arena.ts");

test("edge entrants cannot attack or charge, and stationary units move toward the clear arena", () => {
  const g = isolate(createGame());
  assert.deepEqual(g.arena, { l: 0, r: 1280, t: 0, b: 800 });
  for (const kind of [
    "ram",
    "quill",
    "scribe",
    "brood",
    "priest",
    "vortex",
    "binder",
    "mortar",
  ]) {
    const e = g.spawnEnemy(kind, 20, 300, false, true);
    e.grace = 0;
    e.shoot = 0;
    const before = [
      g.bullets.length,
      g.lasers.length,
      g.blasts.length,
      g.enemies.length,
    ];
    g.enemyAttack(e);
    assert.deepEqual(
      [g.bullets.length, g.lasers.length, g.blasts.length, g.enemies.length],
      before,
      kind,
    );
    assert.equal(e.windup, 0);
  }
  const tower = g.spawnEnemy("tower", 20, 400, false, true);
  tower.grace = 0;
  g.updateEnemies(0.1);
  assert(tower.x > 20);
  const ram = g.enemies.find((e) => e.type === "ram");
  ram.x = 640;
  ram.y = 350;
  g.enemyAttack(ram);
  assert(ram.windup > 0);
  ram.x = 20;
  ram.charge = 0.5;
  g.updateEnemies(0.01);
  assert.equal(ram.windup, 0);
  assert.equal(ram.charge, 0);
});

test("crossing into the veil cancels live lasers, blast telegraphs and source-owned scheduled abilities", () => {
  const g = isolate(createGame()),
    e = g.spawnEnemy("scribe", 500, 300, false, true);
  e.grace = 0;
  g.laser(e);
  g.makeBlast(600, 400, 90, 0.2, e.id);
  g.lasers[0].warning = 0;
  let called = 0;
  g.schedule(0.01, () => called++, e.id);
  e.x = 20;
  g.updateHazards(0.01);
  g.update(0.02);
  assert(g.lasers.every((l) => l.dead));
  assert(g.blasts.every((b) => b.dead));
  assert.equal(called, 0);
  const count = g.bullets.length;
  assert.equal(g.bullet(20, 300, 0, 100, "#fff", { source: e.id }), null);
  assert.equal(g.bullets.length, count);
  // A shield pillar in the veil must not protect its Boss from afar.
  const {
    limitBossDamage,
  } = require("../src/simulation/systems/PhaseController.ts");
  const definition = g.bossDefinition();
  g.spawnBoss();
  const tower = g.spawnEnemy(definition.shieldUnits[0], 20, 350, false, true);
  assert.equal(limitBossDamage(definition, g.boss, 20, [tower], g.arena), 20);
  tower.x = 500;
  assert.equal(
    limitBossDamage(definition, g.boss, 20, [tower], g.arena),
    20 * definition.shieldMultiplier,
  );
});

test("all pickup spawns stay inside the clear arena including source-positioned drops and unusual viewports", () => {
  const g = isolate(createGame());
  for (const arena of [
    { l: 0, r: 1280, t: 0, b: 800 },
    { l: -360, r: 1640, t: 0, b: 800 },
    { l: 0, r: 1280, t: -700, b: 1500 },
  ]) {
    g.arena = arena;
    const source = g.spawnEnemy(
      "quill",
      arena.l + 20,
      arena.t + 20,
      false,
      true,
    );
    for (let i = 0; i < 100; i++) {
      g.nodes = [];
      const node = g.spawnNode(i % 2 ? "ink" : "rune", i % 3 ? source : null);
      assert(inClearArena(arena, node, 32));
      assert.equal(node.r, 13);
    }
  }
});

test("edge death abilities do not spawn hostile children or hazards", () => {
  const g = isolate(createGame());
  g.mode.rank = 3;
  const e = g.spawnEnemy("split", 20, 300, false, true);
  e.elite = "volatile";
  g.kill(e);
  assert.equal(g.enemies.length, 1);
  assert.equal(g.blasts.length, 0);
});

test("God Mode takes damage, refills lethal health and bypasses ultimate/dodge resources without ending the run", () => {
  const g = isolate(createGame());
  g.activateGodMode();
  g.player.invuln = 0;
  g.hurt(10);
  assert.equal(g.player.hp, g.player.maxHp - 10);
  g.player.invuln = 0;
  g.hurt(10000);
  assert.equal(g.player.hp, g.player.maxHp);
  assert.equal(g.state, "playing");
  g.resonance = 0;
  g.ultimate();
  g.ultimate();
  assert.equal(g.ultimates, 2);
  assert.equal(g.resonance, 100);
  g.player.dash = 0;
  g.input("ArrowRight");
  g.dodge();
  assert(g.player.dashState);
  assert.equal(g.player.dash, g.player.maxDash);
  step(g, 0.2);
  g.player.dash = 0;
  g.input("ArrowRight");
  g.dodge();
  assert.equal(g.dashes, 2);
  g.pause();
  const t = g.time;
  g.update(1);
  assert.equal(g.time, t);
});

test("large dictionary draws never scan word arrays after construction, even with exhausted initials and adversarial RNG", () => {
  const words = Array.from({ length: 50000 }, (_, i) => ({
    word: "a" + i.toString(36).padStart(5, "0"),
  }));
  const pool = new C.WordPool(words, () => 0);
  for (const fn of ["filter", "map", "reduce", "flatMap", "find", "findIndex"])
    pool.words[fn] = () => {
      throw Error("whole dictionary scan");
    };
  const used = words.slice(0, 60);
  for (let i = 0; i < 200; i++)
    assert(
      !used.some(
        (w) => w.word === pool.choose(used, 1 + (i % 5), 6 + (i % 18)).word,
      ),
    );
  assert(pool.rangeCache.size <= 24 * 24);
  const tiny = new C.WordPool(["cat", "cow", "cup"], () => 0);
  assert.equal(
    tiny.choose([{ word: "cat" }, { word: "cow" }], 1, 24).word,
    "cup",
  );
  assert.equal(
    tiny.choose([{ word: "cat" }, { word: "cow" }, { word: "cup" }], 1, 24)
      .word,
    "cat",
  );
});

test("complete source dictionaries include both semesters, full textbook sets and complete exam sources", () => {
  for (const [id, min, files] of [
    ["primary3", 100, 2],
    ["junior", 1800, 5],
    ["senior", 2800, 11],
    ["cet4", 2500, 1],
    ["cet6", 2300, 1],
  ]) {
    const data = require("../data/" + id + ".json");
    assert.equal(data.snapshot, "complete");
    assert(data.words.length >= min);
    assert.equal(data.upstreamFiles.length, files);
    assert.equal(
      data.sourceRecords,
      data.words.length + data.excluded.length + data.duplicates,
    );
  }
});
