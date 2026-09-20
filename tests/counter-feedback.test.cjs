const test = require("node:test"),
  assert = require("node:assert/strict");
const { createGame, isolate, step } = require("./harness.cjs");
const { DEFENSE, counterWorldDelta } = require("../src/shared/defense.ts");
const { layoutWordLabels } = require("../src/rendering/WordLabelLayout.ts");
const { createOverlayFrame } = require("../src/application/overlay.ts");
const make = () => isolate(createGame(["cat", "longword", "pursuit"]));
test("counter knocks contact target far away and pressure displaces neighbors without damage or bullet clearing", () => {
  const g = make();
  g.player.x = 400;
  g.player.y = 400;
  const main = g.spawnEnemy("ram", 410, 400),
    near = g.spawnEnemy("nib", 400, 485),
    outside = g.spawnEnemy("nib", 400, 550);
  for (const e of [main, near, outside]) {
    e.hp = e.maxHp = 10000;
    e.grace = 0;
    e.speed = 0;
  }
  const bullet = g.bullet(400, 540, 0, 50, "#fff");
  const bulletBefore = { ...bullet };
  g.parry();
  g.parryContact(main);
  assert.equal(main.hp, 9968);
  assert.equal(near.hp, 10000);
  assert.equal(outside.hp, 10000);
  assert(main.ix > 1000);
  assert(near.iy > 700);
  // The nearer cutoff must preserve the previous impulse at the same position.
  const previousImpulse = 1050 * (1 - 0.25 * 85 / 185) / Math.max(0.85, Math.sqrt(near.mass));
  assert(Math.abs(near.iy - previousImpulse) < 1e-6);
  assert.equal(outside.iy, 0);
  assert.deepEqual(bullet, bulletBefore);
  assert.equal(g.counterSlowTime, DEFENSE.slowDuration);
  const impulse = near.iy;
  g.parryFeedback();
  assert.equal(near.iy, impulse);
  for (let i = 0; i < 100; i++) g.updateEnemies(0.01);
  assert(main.x > 700, main.x);
  assert.equal(main.hp, 9968);
  assert.equal(near.hp, 10000);
  assert(main.shoot > 1);
  assert.equal(main.charge, 0);
});
test("counter pressure cannot turn wall/body collisions into collateral damage", () => {
  const g = make();
  g.player.x = g.arena.r - 45;
  g.player.y = 400;
  const near = g.spawnEnemy("nib", g.player.x + 20, 430),
    second = g.spawnEnemy("nib", g.player.x + 35, 438);
  for (const e of [near, second]) {
    e.hp = e.maxHp = 10000;
    e.grace = 0;
    e.speed = 0;
  }
  g.parry();
  g.parryFeedback();
  for (let i = 0; i < 90; i++) {
    g.updateEnemies(0.01);
    g.resolveBodies(0.01);
  }
  assert.equal(near.hp, 10000);
  assert.equal(second.hp, 10000);
});
test("counter slowdown holds then recovers smoothly, does not multiply hourglass or delay defenses, and resets", () => {
  const g = make();
  g.parry();
  assert.equal(g.counterSlowTime, 0);
  g.parryFeedback();
  const energy = g.counterSlowTime;
  const first = counterWorldDelta(energy, 0.02) / 0.02,
    middle = counterWorldDelta(0.26, 0.02) / 0.02,
    last = counterWorldDelta(0.02, 0.02) / 0.02;
  assert(first < 0.1 && middle > first && last > 0.98);
  const whole = counterWorldDelta(energy, 0.7);
  let sum = 0;
  for (let i = 0; i < 70; i++)
    sum += counterWorldDelta(Math.max(0, energy - i * 0.01), 0.01);
  assert(Math.abs(whole - sum) < 1e-9);
  const time = g.time;
  g.precisionTime = 1;
  g.update(0.02);
  assert(g.time - time >= 0.0011);
  assert(Math.abs(g.player.parryCooldown - (DEFENSE.cooldown - 0.02)) < 1e-9);
  const left = g.counterSlowTime;
  g.state = "paused";
  g.update(0.2);
  assert.equal(g.counterSlowTime, left);
  g.state = "playing";
  step(g, 0.55);
  assert.equal(g.counterSlowTime, 0);
  g.counterSlowTime = 0.3;
  g.beginRoom();
  assert.equal(g.counterSlowTime, 0);
  g.counterSlowTime = 0.3;
  g.home();
  assert.equal(g.counterSlowTime, 0);
});
test("dense labels stay attached and prioritize lock, threat and length", () => {
  const g = make();
  const normal = g.spawnEnemy("nib", 620, 300),
    long = g.spawnEnemy("nib", 620, 300),
    threat = g.spawnEnemy("scribe", 620, 300);
  normal.word = "cat";
  long.word = "longword";
  threat.word = "cat";
  const frame = createOverlayFrame(g),
    measure = (word, font) => word.length * font * 0.6;
  let labels = layoutWordLabels(frame, measure);
  assert.equal(labels.at(-1).target.id, threat.id);
  assert(
    labels.findIndex((l) => l.target.id === long.id) >
      labels.findIndex((l) => l.target.id === normal.id),
  );
  g.target = normal;
  labels = layoutWordLabels(frame, measure);
  assert.equal(labels.at(-1).target.id, normal.id);
  const before = labels.find((l) => l.target.id === long.id);
  threat.x += 80;
  g.target = long;
  const after = layoutWordLabels(frame, measure).find(
    (l) => l.target.id === long.id,
  );
  assert.equal(after.x, before.x);
  assert.equal(after.y, before.y);
  long.x += 1;
  long.y += 2;
  const moved = layoutWordLabels(frame, measure).find(
    (l) => l.target.id === long.id,
  );
  assert.equal(moved.x, after.x + 1);
  assert.equal(moved.y, after.y + 2);
});
