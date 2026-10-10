const test = require("node:test");
const assert = require("node:assert/strict");
const ink = require("../src/content/bosses/ink-colossus/behavior.ts").default;
const echo = require("../src/content/bosses/echo-archivist/behavior.ts").default;
const editor = require("../src/content/bosses/final-editor/behavior.ts").default;

function run(action, phase, attackIndex) {
  const enemy = { id: 42, phase, attackIndex };
  const fires = [], lasers = [], blasts = [], tasks = [];
  const context = {
    player: { x: 500, y: 400 },
    fire: (source, pattern, options) => fires.push({ source: source.id, pattern, options }),
    laser: (source, boss) => lasers.push({ source: source.id, boss }),
    makeBlast: (x, y, r, warning, source, ring) => blasts.push({ x, y, r, warning, source, ring }),
    schedule: (delay, callback, source) => tasks.push({ delay, callback, source }),
  };
  action(context, enemy);
  return { fires, lasers, blasts, tasks, context };
}

for (const phase of [1, 2, 3]) {
  for (const index of [1, 2]) {
    test(`ink colossus phase ${phase} attack ${index}`, () => {
      const result = run(ink, phase, index);
      const odd = index % 2 === 1;
      assert.deepEqual(result.fires.map((call) => call.pattern), [odd ? "ring" : "fan"]);
      assert.deepEqual(result.blasts.map(({ x, y, r, warning }) => [x, y, r, warning]),
        odd ? [[500, 400, 90, 1.25]] : [[390, 400, 65, 1.25], [610, 400, 65, 1.25]]);
      assert.deepEqual(result.blasts.map((blast) => blast.source), Array(result.blasts.length).fill(42));
      if (odd) assert.equal(result.blasts[0].ring, false);
      assert.equal(result.lasers.length, phase === 3 && !odd ? 1 : 0);
      assert.equal(result.tasks.length, phase >= 2 ? 1 : 0);
      for (const task of result.tasks) {
        assert.equal(task.source, 42);
        task.callback();
        assert.equal(result.fires.at(-1).pattern, "fan");
        assert.equal(result.fires.at(-1).source, 42);
      }
    });

    test(`echo archivist phase ${phase} attack ${index}`, () => {
      const result = run(echo, phase, index);
      const odd = index % 2 === 1;
      assert.deepEqual(result.fires.map((call) => call.options.curve), [odd ? 0.23 : -0.23]);
      assert.equal(result.lasers.length, odd ? 1 : 0);
      assert.deepEqual(result.blasts.map(({ x, y, r, warning }) => [x, y, r, warning]),
        odd ? [] : [[500, 290, 65, 1.3], [500, 510, 65, 1.3]]);
      assert.ok(result.blasts.every((blast) => blast.source === 42));
      assert.equal(result.tasks.length, phase >= 2 ? 2 : 0);
      for (const task of result.tasks) {
        assert.equal(task.source, 42);
        task.callback();
        assert.equal(result.fires.at(-1).pattern, "fan");
        assert.equal(result.fires.at(-1).source, 42);
      }
    });

    test(`final editor phase ${phase} attack ${index}`, () => {
      const result = run(editor, phase, index);
      const odd = index % 2 === 1;
      assert.deepEqual(result.fires.map((call) => call.options.curve), [odd ? 0.14 : -0.14]);
      assert.equal(result.lasers.length, odd ? 1 : 0);
      assert.deepEqual(result.blasts.map(({ x, y, r, warning }) => [x, y, r, warning]),
        odd ? [] : [[365, 400, 75, 1.25], [635, 400, 75, 1.65]]);
      assert.ok(result.blasts.every((blast) => blast.source === 42));
      assert.equal(result.tasks.length, (phase >= 2 ? 1 : 0) + (phase === 3 ? 1 : 0));
      for (const task of result.tasks) {
        assert.equal(task.source, 42);
        task.callback();
      }
      if (phase >= 2) {
        assert.deepEqual(result.blasts.at(-1), { x: 500, y: 400, r: 95, warning: 1.15, source: 42, ring: undefined });
      }
      if (phase === 3) assert.deepEqual(result.fires.at(-1), { source: 42, pattern: "ring", options: { speed: 0.83 } });
      assert.ok(result.blasts.every((blast) => blast.warning >= 1.15));
    });
  }
}
