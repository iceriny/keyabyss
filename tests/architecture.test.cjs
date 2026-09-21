const test = require("node:test"),
  assert = require("node:assert/strict");
const { createGame, isolate, type, step } = require("./harness.cjs");
const { manifest } = require("../src/content/manifest.ts");
const { Registry } = require("../src/content-sdk/Registry.ts");
const { validateContent } = require("../src/content-sdk/validate.ts");
const baseline = require("./fixtures/ritual-baseline.json");
const { builtinContent } = require("../src/bootstrap/content.ts");
const { CombatSimulation } = require("../src/simulation/CombatSimulation.ts");

test("headless simulation matches historical directional-assault traces from their original origin", () => {
  assert.equal(typeof globalThis.window, "undefined");
  for (const expected of baseline) {
    const g = isolate(createGame(["cat", "dog", "book", "alpha", "beta", "glyph", "frost", "storm", "spirit", "flame", "rune"], expected.book));
    // This saved trajectory predates centered spawning; preserve its explicit setup.
    g.player.y = 490;
    for (let i = 0; i < 6; i++)
      g.spawnEnemy(
        ["nib", "quill", "guard", "mirror", "split", "vortex"][i],
        200 + i * 140,
        250,
        false,
        true,
      );
    const frames = [];
    for (let i = 0; i < 60; i++) {
      if (i % 6 === 0) {
        const e = g.enemies.find((e) => !e.dead && !e.wordPending);
        if (e) type(g, e);
      }
      step(g, 1 / 30);
      frames.push({
        time: g.time,
        hp: g.player.hp,
        resonance: g.resonance,
        combo: g.combo,
        kills: g.kills,
        enemies: g.enemies.map((e) => [
          e.id,
          e.type,
          e.word,
          e.hp,
          e.x,
          e.y,
          e.freeze,
        ]),
        shots: g.shots.map((s) => [s.x, s.y, s.dmg]),
        xp: g.xp,
      });
    }
    assert.deepEqual(frames, expected.frames, expected.book);
  }
});
test("registry rejects duplicate IDs and seals nested definitions", () => {
  assert.throws(
    () => new Registry("test", [{ id: "a" }, { id: "a" }]),
    /duplicate/,
  );
  const registry = new Registry("test", [{ id: "a", stats: { hp: 10 } }]);
  assert(Object.isFrozen(registry.get("a").stats));
  assert.throws(() => registry.get("unknown"), /unknown/);
});
test("an additional book registers without editing the catalog implementation", () => {
  const books = [
    ...manifest.books,
    { ...manifest.books[0], id: "ember", command: "ember", shortcut: "5" },
  ];
  validateContent({ ...manifest, books });
  assert.equal(new Registry("books", books).list().length, manifest.books.length + 1);
});
test("content rejects invalid references, cyclic relics and keyboard conflicts", () => {
  const copy = () => structuredClone(manifest);
  let c = copy();
  c.relics[0].book = "unknown";
  assert.throws(() => validateContent(c), /unknown book/);
  c = copy();
  c.relics[0].requires = ["not-a-relic"];
  assert.throws(() => validateContent(c), /unknown prerequisite/);
  c = copy();
  c.relics[0].requires = [c.relics[1].id];
  c.relics[1].requires = [c.relics[0].id];
  assert.throws(() => validateContent(c), /cycle/);
  c = copy();
  c.books[0].command = "sta";
  assert.throws(() => validateContent(c), /conflicting commands/);
  c = copy();
  c.chapters[0].rooms[0].waves = 0;
  assert.throws(() => validateContent(c), /waves/);
});

test("injected additional book, composite enemy and four-room campaign run without central branches", () => {
  const base = createGame(),
    book = {
      ...builtinContent.books.frost,
      id: "ember",
      command: "ember",
      shortcut: "5",
    };
  const enemy = {
    ...builtinContent.enemies.quill,
    behavior: { attack: "fan", ranged: true, weave: true, frontArmor: true },
  };
  const chapter = {
    id: "test-chapter",
    name: "Test chapter",
    bossName: "Test guardian",
    rooms: Array.from({ length: 4 }, (_, i) => ({
      id: `test-${i}`,
      boss: false,
      waves: 2,
      enemies: ["test-enemy"],
      routes: ["rest"],
    })),
  };
  const content = {
    ...builtinContent,
    books: { ...builtinContent.books, ember: book },
    enemies: { ...builtinContent.enemies, "test-enemy": enemy },
    chapters: [chapter],
  };
  const g = new CombatSimulation(content);
  g.start({ ...base.config, book: "ember" });
  assert.equal(g.book, "ember");
  assert.equal(g.roomCount, 4);
  assert.equal(g.waveCount, 2);
  assert.deepEqual(g.allowedEnemies(), ["test-enemy"]);
  isolate(g);
  const target = g.spawnEnemy("test-enemy", 400, 300, false, true);
  type(g, target);
  assert.equal(g.shots[0].kind, "ice");
  g.enemyAttack(target);
  assert(g.bullets.length > 0);
  assert.equal(g.enemyProfile(target).frontArmor, true);
  for (let room = 0; room < 4; room++) {
    g.stage = room;
    g.beginRoom();
    assert.equal(g.roomNumber, room);
    assert.equal(g.waveCount, 2);
    g.completeRoom();
    assert.equal(g.state, room === 3 ? "result" : "route");
  }
  assert.equal(g.lastWin, true);
  g.continueLoop();
  assert.equal(g.stage, 4);
  assert.equal(g.loopCount, 1);
  assert.equal(g.roomNumber, 0);
});

test("new numeric and triggered relics use shared rules; cast pulse has stable precedence", () => {
  const custom = {
    ...builtinContent.relics[0],
    id: "test-relic",
    max: 3,
    damageModifiers: [{ factor: 1.1, perStack: true, priority: 50 }],
    hooks: [
      {
        phase: "afterCast",
        priority: 1,
        every: 2,
        effect: { kind: "heal", amount: 3 },
      },
    ],
  };
  const g = new CombatSimulation({
    ...builtinContent,
    relics: [...builtinContent.relics, custom],
  });
  g.start(createGame().config);
  g.relics = { "test-relic": 2 };
  g.player.hp = 20;
  g.casts = 2;
  g.afterCast(null, false);
  assert.equal(g.player.hp, 26);
  assert.equal(g.damageMultiplier(), Math.pow(1.1, 2));
  g.relics = { power: 3, bloodprice: 1, glass: 1, sacrifice: 1 };
  g.player.hp = 1;
  assert.equal(g.damageMultiplier(), Math.pow(1.25, 3) * 1.4 * 1.45 * 1.5);
  g.relics = { pulse: 1, nova: 1 };
  g.casts = 15;
  g.perfectWords = 3;
  const pulses = [];
  g.explode = (...args) => pulses.push(args);
  g.afterCast(null, true);
  assert.equal(pulses.length, 1);
  assert.equal(pulses[0][2], 220);
  assert.equal(pulses[0][3], 35);
});

test("room scheduler cancels dead sources and prevents old callbacks after replacement", () => {
  const { TaskScheduler } = require("../src/simulation/TaskScheduler.ts");
  const scheduler = new TaskScheduler(),
    seen = [];
  scheduler.schedule(0, 0, () => seen.push("dead"), 7);
  scheduler.schedule(0, 0, () => {
    seen.push("first");
    scheduler.schedule(0, 0, () => seen.push("next"));
  });
  scheduler.tick(
    0,
    () => false,
    () => false,
  );
  assert.deepEqual(seen, ["first"]);
  scheduler.tick(
    0,
    () => true,
    () => false,
  );
  assert.deepEqual(seen, ["first", "next"]);
  scheduler.schedule(0, 0, () => {
    scheduler.replace([]);
    scheduler.schedule(0, 0, () => seen.push("new-room"));
  });
  scheduler.schedule(0, 0, () => seen.push("stale"));
  scheduler.tick(
    0,
    () => true,
    () => false,
  );
  assert(!seen.includes("stale"));
  scheduler.tick(
    0,
    () => true,
    () => false,
  );
  assert.equal(seen.at(-1), "new-room");
});

test("session snapshots are stable and isolated, commands reject stale offers, disposal detaches", () => {
  const {
    SessionController,
  } = require("../src/application/SessionController.ts");
  const g = createGame(),
    session = new SessionController(g),
    snapshot = session.getSnapshot();
  let updates = 0;
  const unsubscribe = session.subscribe(() => updates++);
  assert.equal(session.getSnapshot(), snapshot);
  assert(Object.isFrozen(snapshot.player));
  assert(!("enemies" in session));
  g.player.hp = 12;
  assert.notEqual(snapshot.player.hp, 12);
  g.emit("hud");
  assert.equal(session.player.hp, 12);
  assert.equal(updates, 1);
  g.emit("hud");
  assert.equal(updates, 1);
  assert.equal(session.dispatch({ type: "upgrade", id: "power" }), false);
  g.state = "upgrade";
  g.emit("upgrade", [builtinContent.relics[0]]);
  assert.equal(session.dispatch({ type: "upgrade", id: "glass" }), false);
  assert.equal(session.dispatch({ type: "upgrade", id: "power" }), true);
  assert.equal(g.relics.power, 1);
  assert.equal(session.dispatch({ type: "upgrade", id: "power" }), false);
  unsubscribe();
  session.dispose();
  assert.equal(session.dispatch({ type: "pause" }), false);
  assert.equal(g.events.hud, undefined);
});

test("branching routes choose room IDs independently of catalog order and continue at the loop entry", () => {
  const chapter = {
    ...builtinContent.chapters[0],
    rooms: [
      {
        ...builtinContent.chapters[0].rooms[0],
        id: "entry",
        exits: [
          { route: "rest", to: "left" },
          { route: "trial", to: "right" },
        ],
      },
      { ...builtinContent.chapters[0].rooms[0], id: "left", exits: [] },
      { ...builtinContent.chapters[0].rooms[0], id: "right", exits: [] },
    ],
  };
  validateContent({ ...manifest, chapters: [chapter] });
  const g = new CombatSimulation({
    ...builtinContent,
    chapters: [chapter],
    routes: [...builtinContent.routes].reverse(),
  });
  g.start(createGame().config);
  g.completeRoom();
  assert.deepEqual(
    g.routeOffers.map((r) => r.id),
    ["rest", "trial"],
  );
  g.chooseRoute(g.routeOffers[1]);
  assert.equal(g.campaign.at(g.stage).room.id, "right");
  g.completeRoom();
  assert.equal(g.lastWin, true);
  g.continueLoop();
  assert.equal(g.campaign.at(g.stage).room.id, "entry");
  assert.equal(g.loopCount, 1);
  const cycle = structuredClone(chapter);
  cycle.rooms[2].exits = [{ route: "rest", to: "entry" }];
  assert.throws(
    () => validateContent({ ...manifest, chapters: [cycle] }),
    /Campaign cycle/,
  );
});

test("a custom Boss uses its own thresholds, summons and attack handler", () => {
  const boss = {
    ...Object.values(builtinContent.bosses)[0],
    id: "test-boss",
    behavior: "test-pattern",
    phases: [
      { name: "open", above: 0.5, floor: 0.49, summons: [] },
      {
        name: "finish",
        above: 0,
        floor: 0,
        summons: [{ enemy: "quill", x: 300, y: 250 }],
      },
    ],
  };
  const chapter = {
    ...builtinContent.chapters[0],
    bossId: boss.id,
    rooms: [{ ...builtinContent.chapters[0].rooms[2], id: "test-boss-room" }],
  };
  let attacks = 0;
  const g = new CombatSimulation({
    ...builtinContent,
    bosses: { ...builtinContent.bosses, [boss.id]: boss },
    bossBehaviors: {
      ...builtinContent.bossBehaviors,
      "test-pattern": () => attacks++,
    },
    chapters: [chapter],
  });
  g.start(createGame().config);
  const enemy = g.boss;
  g.damage(enemy, 1e6);
  assert.equal(enemy.hp / enemy.maxHp, 0.49);
  g.updateBossPhase(enemy);
  g.updateBossPhase(enemy);
  assert.equal(enemy.phase, 2);
  assert.equal(g.enemies.filter((e) => e.type === "quill").length, 1);
  g.bossAttack(enemy);
  assert.equal(attacks, 1);
});

test("new relic IDs combine existing hit behaviors without central ID branches", () => {
  const relic = {
    id: "crimson",
    name: "Test",
    tag: "Test",
    icon: "x",
    desc: "Test",
    max: 2,
    grants: { execution: 1, bleedStacks: 2 },
  };
  const g = new CombatSimulation({
    ...builtinContent,
    relics: [...builtinContent.relics, relic],
  });
  g.start(createGame().config);
  isolate(g);
  g.relics.crimson = 1;
  const enemy = g.spawnEnemy("nib", 400, 300, false, true);
  enemy.hp = 15;
  enemy.maxHp = 100;
  g.strike(enemy, 1, { direct: true });
  assert(enemy.dead);
  assert.equal(g.kills, 1);
  assert.equal(enemy.dotStacks, 1);
  g.kill(enemy);
  assert.equal(g.kills, 1);
});

test("room and session sources reject stale effects, required tasks block premature clear", () => {
  const g = isolate(createGame()),
    old = g.effectSource();
  g.beginRoom();
  g.player.hp = 20;
  assert.equal(g.applyEffect({ source: old, kind: "heal", amount: 20 }), false);
  assert.equal(g.player.hp, 20);
  const source = g.effectSource();
  assert(g.applyEffect({ source, kind: "heal", amount: 10 }));
  assert.equal(g.player.hp, 30);
  g.start(g.config);
  assert.equal(g.applyEffect({ source, kind: "heal", amount: 10 }), false);
  isolate(g);
  g.enemies = [];
  g.spawned = g.roomQuota;
  g.schedule(1, () => {}, null, { blocksClear: true });
  g.finishEncounter(0.1);
  assert.equal(g.roomEnded, false);
  g.tasks = [];
  g.finishEncounter(0.1);
  assert.equal(g.roomEnded, true);
});

test("word leases are released on room teardown without refreshing old targets", () => {
  const g = isolate(createGame()),
    enemy = g.spawnEnemy("guard", 900, 400, false, true);
  type(g, enemy);
  assert(enemy.wordPending);
  const word = enemy.word;
  g.resetArrays();
  assert.equal(enemy.wordPending, false);
  assert.equal(enemy.pendingHits, 0);
  assert.equal(enemy.word, word);
});

test("presentation readers are independent and new sessions cannot replay old cues", () => {
  const g = createGame(),
    a = g.presentationCues.reader(),
    b = g.presentationCues.reader();
  g.burst(200, 300, 40, "#fff");
  const events = a.after(0);
  assert.equal(events.length, 1);
  assert.deepEqual(b.after(0), events);
  assert(Object.isFrozen(events[0].value.effect));
  const previous = a.session;
  g.start(g.config);
  assert.equal(a.session, previous + 1);
  assert.equal(a.after(0).length, 0);
});

test("resource plans include Boss shields, death children, summons and valid appearance references", () => {
  const { roomResources } = require("../src/content-sdk/resources.ts");
  const plan = roomResources(
    builtinContent,
    builtinContent.chapters[2].rooms[2].id,
  );
  for (const id of ["tower", "priest", "nib", "wisp"])
    assert(plan.enemies.includes(id), id);
  const copy = structuredClone(manifest);
  copy.books[0].appearance = "missing";
  assert.throws(() => validateContent(copy), /Unknown appearance/);
  const broken = structuredClone(manifest);
  broken.bosses[0].phases[0].above = 0.2;
  assert.throws(() => validateContent(broken), /Invalid boss phase/);
});
const { StorageAdapter } = require("../src/platform/StorageAdapter.ts");
test("storage reads old settings and reports, versions writes, and survives denied storage", () => {
  const values = new Map([
    ["keyabyss.settings", JSON.stringify({ volume: 0.2 })],
    [
      "keyabyss.history",
      JSON.stringify([
        { book: "removed-book", bookName: "Old name", kills: 5 },
      ]),
    ],
  ]);
  const store = new StorageAdapter(() => ({
    getItem: (key) => values.get(key) || null,
    setItem: (key, value) => values.set(key, value),
  }));
  assert.equal(store.read("settings", {}).volume, 0.2);
  const history = store.read("history", []);
  assert(store.save("history", history));
  assert.deepEqual(store.read("history", []), history);
  assert.equal(JSON.parse(values.get("keyabyss.history")).version, 1);
  values.set(
    "keyabyss.prefs",
    JSON.stringify({ schema: "keyabyss", version: 999, data: { book: "x" } }),
  );
  assert.deepEqual(store.read("prefs", {}), {});
  const blocked = new StorageAdapter(() => {
    throw new Error("denied");
  });
  assert.equal(blocked.save("settings", {}), false);
  assert.equal(blocked.read("settings", "fallback"), "fallback");
});
test("elite traits compose under arbitrary IDs and label targeting validates living targets", () => {
  const g = new CombatSimulation({
    ...builtinContent,
    elites: {
      custom: {
        name: "Custom",
        color: "#fff",
        tip: "test",
        health: 2,
        mass: 3,
        speed: 1.1,
        cooldown: 0.8,
        unfrozenDamage: 0.5,
      },
    },
  });
  g.start({
    seed: "COMPOSITE",
    book: "frost",
    mode: "normal",
    words: [{ word: "crystal" }],
    progressive: false,
  });
  isolate(g);
  g.stage = 1;
  g.wave = 2;
  g.pressure.elite = 1;
  const e = g.spawnEnemy("nib", 400, 300);
  assert.equal(e.elite, "custom");
  assert.equal(e.mass, builtinContent.enemies.nib.mass * 3);
  e.freeze = 0;
  e.grace = 0;
  const before = e.hp;
  g.damage(e, 10, 0, false);
  assert.equal(before - e.hp, 5);
  g.clickTarget(0, 0, e.id);
  assert.equal(g.target, e);
  e.dead = true;
  g.cancel(false);
  g.clickTarget(0, 0, e.id);
  assert.equal(g.target, null);
  assert.equal("labels" in g, false);
  assert.equal("castLabel" in g, false);
});


test("new runs and room transitions spawn the player at the view center", () => {
  const { createPlayer } = require("../src/combat/model.ts");
  assert.deepEqual([createPlayer().x, createPlayer().y], [640, 400]);
  const g = createGame();
  assert.deepEqual([g.player.x, g.player.y], [640, 400]);
  g.player.x = 170; g.player.y = 600;
  g.stage++;
  g.beginRoom();
  assert.deepEqual([g.player.x, g.player.y], [640, 400]);
});
