const test = require("node:test"), assert = require("node:assert/strict");
const { createGame, isolate, type, step } = require("./harness.cjs");

const make = (book = "storm") => isolate(createGame(["class", "clan", "dog"], book));
function enemy(g, word = "class", x = 640, y = 300) {
  const e = g.spawnEnemy("guard", x, y);
  e.word = word;
  e.meaning = word === "class" ? "类别" : "接收者";
  e.hp = e.maxHp = 10000;
  return e;
}
function traceWeave(g) {
  const casts = [], releases = [], weave = g.weaveCast;
  const nativeCast = g.nativeSpells.cast, nativeLaunch = g.nativeSpells.launch;
  g.nativeSpells.cast = (target, damage, empowered, critical, manualChars, input) => {
    casts.push({ target, damage, manualChars });
    nativeCast.call(g.nativeSpells, target, damage, empowered, critical, manualChars, input);
  };
  g.nativeSpells.launch = (object, target, from) => {
    if (!object.derived && object.targetPolicy === 'original') releases.push(g.enemies.find(enemy => enemy.id === target.id));
    nativeLaunch.call(g.nativeSpells, object, target, from);
  };
  g.weaveCast = (target, damage, manualChars, release) => {
    casts.push({ target, damage, manualChars });
    weave.call(g, target, damage, manualChars, (recipient) => {
      releases.push(recipient);
      release(recipient);
    });
  };
  return { casts, releases };
}
function passiveKill(g, e) {
  e.hp = 1;
  g.launchShot({ x: e.x - 10, y: e.y + 9 }, e, "ice", 100, { direct: false, depth: 1 });
  g.updateShots(0.02);
  assert(e.dead);
}

test("normal completion supplies every accepted manual character once", () => {
  const g = make(), e = enemy(g), trace = traceWeave(g);
  type(g, e);
  assert.equal(trace.casts.length, 1);
  assert.equal(trace.casts[0].manualChars, 5);
  assert.equal(trace.releases[0], e);
  assert.equal(g.casts, 1);
  assert.equal(g.manual, 1);
  assert.equal(g.combo, 1);
  assert.equal(g.correct, 5);
  assert.equal(g.wordStats.class.done, 1);
  assert.equal(g.target, null);
  assert.equal(g.prefix, "");
});

test("two letters survive a passive kill and completion redirects once using the original word", () => {
  const g = make(), original = enemy(g), near = enemy(g, "dog", 710), far = enemy(g, "clan", 1000);
  const trace = traceWeave(g);
  g.target = original;
  g.input("c"); g.input("l");
  passiveKill(g, original);
  step(g, 0.05);
  assert.equal(g.target, original);
  assert.equal(g.prefix, "cl");
  assert.equal(original.word, "class");
  assert.equal(original.meaning, "类别");
  assert(!g.targets().includes(original));
  assert(!g.enemies.includes(original));
  for (const key of "ass") g.input(key);
  assert.equal(trace.casts.length, 1);
  assert.equal(trace.casts[0].target, original);
  assert.equal(trace.casts[0].manualChars, 5);
  assert.equal(trace.casts[0].damage, g.combatValue("cast.base", {
    wordLength: 5, shortWord: 0, longWord: 0, perfect: 1,
  }));
  assert.deepEqual(trace.releases, [near]);
  assert(near.hp < near.maxHp);
  assert.equal(g.casts, 1);
  assert.equal(g.manual, 1);
  assert.equal(g.combo, 1);
  assert.equal(g.wordStats.class.done, 1);
  assert.equal(g.wordStats.dog?.done || 0, 0);
  assert.equal(original.word, "class");
  assert.equal(g.prefix, "");
  assert.equal(g.target, null);
  assert(!far.dead);
});

test("echo retains prior errors and wrong characters cannot branch to a live shared-prefix word", () => {
  const g = make(), original = enemy(g), alternative = enemy(g, "clan", 710), trace = traceWeave(g);
  g.combo = 10;
  g.target = original;
  g.input("c"); g.input("l"); g.input("z");
  assert.equal(g.castError, true);
  passiveKill(g, original);
  assert.equal(g.castError, true);
  assert.equal(g.combo, 9);
  g.input("a"); g.input("n");
  assert.equal(g.target, original);
  assert.notEqual(g.target, alternative);
  assert.equal(g.prefix, "cla");
  assert.equal(g.errors, 2);
  assert.equal(g.combo, 8);
  g.input("s"); g.input("s");
  assert.equal(g.wordStats.class.errors, 2);
  assert.equal(g.wordStats.class.done, 1);
  assert.equal(g.perfectWords, 0);
  assert.equal(g.combo, 9);
  assert.equal(trace.casts[0].manualChars, 5);
  assert.equal(g.correct, 5);
});

test("Tab leaves echo unchanged and Backspace cancels without supplying characters", () => {
  const g = make(), original = enemy(g), alternative = enemy(g, "clan", 710), trace = traceWeave(g);
  g.target = original;
  g.input("c"); g.input("l");
  passiveKill(g, original);
  g.input("Tab"); g.cycle(-1);
  assert.equal(g.target, original);
  assert.equal(g.prefix, "cl");
  g.input("Backspace");
  assert.equal(g.target, null);
  assert.equal(g.prefix, "");
  assert.equal(g.castError, false);
  assert.equal(trace.casts.length, 0);
  type(g, alternative);
  assert.equal(trace.casts.length, 1);
  assert.equal(trace.casts[0].manualChars, 4);
});

test("clicking a new target discards echo progress before the next word", () => {
  const g = make(), original = enemy(g), next = enemy(g, "dog", 710), trace = traceWeave(g);
  g.target = original;
  g.input("c"); g.input("l");
  passiveKill(g, original);
  g.clickTarget(next.x, next.y, next.id);
  assert.equal(g.target, next);
  assert.equal(g.prefix, "");
  assert.equal(trace.casts.length, 0);
  for (const key of "dog") g.input(key);
  assert.equal(trace.casts[0].manualChars, 3);
  assert.equal(g.wordStats.class?.done || 0, 0);
  assert.equal(g.wordStats.dog.done, 1);
});

test("autofill supplies only manually accepted characters for live words and echoes", () => {
  for (const continuation of [false, true]) {
    const g = make(), original = enemy(g), trace = traceWeave(g);
    enemy(g, "dog", 710);
    g.target = original;
    if (!continuation) g.autofill = true;
    g.input("c");
    if (continuation) {
      passiveKill(g, original);
      g.autofill = true;
    }
    g.input("l");
    assert.equal(trace.casts.length, 1);
    assert.equal(trace.casts[0].manualChars, 2);
    assert.equal(g.correct, 2);
    assert.equal(g.casts, 1);
    assert.equal(g.manual, 0);
    assert.equal(g.wordStats.class.done, 1);
    assert.equal(g.autofill, false);
  }
});

test("cast keeps pending words and ordinary dead targets invalid and never supplies nodes", () => {
  const g = make(), e = enemy(g), trace = traceWeave(g);
  e.wordPending = true;
  g.cast(e, true, false, 5, true);
  e.wordPending = false; e.dead = true;
  g.cast(e);
  assert.equal(g.casts, 0);
  assert.equal(trace.casts.length, 0);
  const n = g.spawnNode("rune");
  n.dead = true;
  g.cast(n, true, false, 5, true);
  assert.equal(g.casts, 0);
  n.dead = false;
  type(g, n);
  assert.equal(g.casts, 1);
  assert.equal(trace.casts.length, 0);
});

test("programmatic cast defaults to full manual characters and zero for unspecified autofill", () => {
  const g = make(), e = enemy(g), supplied = [];
  g.weaveCast = (target, damage, manualChars) => supplied.push(manualChars);
  g.nativeSpells.cast = (target, damage, empowered, critical, manualChars) => supplied.push(manualChars);
  g.cast(e);
  g.cast(e, true, true);
  assert.deepEqual(supplied, [5, 0]);
});

test("delayed release does not repeat completion bookkeeping or afterCast", () => {
  const g = make(), original = enemy(g), next = enemy(g, "dog", 710);
  let release, afterCasts = 0;
  const afterCast = g.afterCast;
  g.afterCast = (...args) => { afterCasts++; afterCast.apply(g, args); };
  g.weaveCast = (target, damage, manualChars, run) => { release = run; };
  const nativeLaunch = g.nativeSpells.launch;
  g.nativeSpells.launch = (object) => { release = target => nativeLaunch.call(g.nativeSpells, object, target); };
  g.target = original;
  g.input("c"); g.input("l");
  passiveKill(g, original);
  for (const key of "ass") g.input(key);
  assert.equal(afterCasts, 1);
  assert.equal(g.casts, 1);
  assert.equal(g.wordStats.class.done, 1);
  assert.equal(next.hp, next.maxHp);
  release(next);
  assert(next.hp < next.maxHp);
  assert.equal(afterCasts, 1);
  assert.equal(g.casts, 1);
  assert.equal(g.manual, 1);
  assert.equal(g.combo, 1);
  assert.equal(g.wordStats.class.done, 1);
  assert.equal(g.wordStats.dog?.done || 0, 0);
});
