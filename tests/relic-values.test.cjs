const test = require("node:test");
const assert = require("node:assert/strict");
const { RELICS, BOOKS } = require("../src/content/catalog.ts");
const {
  describeRelic,
  relicMultiplier,
} = require("../src/shared/relic-values.ts");
const { ValueRules } = require("../src/shared/ValueRules.ts");
const { combatValues, baseValues } = require("../src/content/combat-values.ts");
const { previewDefaults } = require("../src/content/preview-defaults.ts");
const rules = new ValueRules(combatValues);
const { RelicRules } = require("../src/simulation/RelicRules.ts");
const game = (relics = {}) => ({
  relics,
  book: "frost",
  player: { hp: 80, maxHp: 100, maxDash: 2 },
  combo: 0,
  chapter: 0,
  target: null,
  mode: { dashCD: 4 },
  ultimateTime: 0,
});
const desc = (id, g, formulas = false, candidate = false) =>
  describeRelic(
    RELICS.find((r) => r.id === id),
    RELICS,
    rules,
    BOOKS,
    previewDefaults,
    g,
    formulas,
    candidate,
  );

test("candidate previews include next rank and build synergies without mutating the run", () => {
  const g = game({ blast: 1, reach: 2, power: 2 });
  const original = structuredClone(g);
  assert.match(desc("blast", g, false, true), /140 范围溅射，伤害 82.03/);
  assert.match(desc("blast", g), /伤害 41.01/);
  assert.deepEqual(g, original);
  assert.match(desc("ward", game({ ward: 1 }), false, true), /24 点护盾/);
  assert.match(desc("ward", game({ ward: 2 }), false, true), /24 点护盾/);
});

test("codex shows symbolic formulas; held key adds formulas to computed values", () => {
  assert.match(desc("blast"), /本次施法命中伤害×\(0.35×爆墨瓶层数\)/);
  assert.doesNotMatch(desc("blast", game({ blast: 1 })), /本次施法命中伤害×/);
  assert.match(
    desc("blast", game({ blast: 1 }), true),
    /26.25（\(本次施法命中伤害×\(0.35×爆墨瓶层数\)\)）/,
  );
  for (const r of RELICS) {
    assert.doesNotMatch(
      describeRelic(
        r,
        RELICS,
        rules,
        BOOKS,
        previewDefaults,
        game(),
        true,
        true,
      ),
      /NaN|undefined|Infinity/,
    );
  }
});

test("preview damage multipliers agree with simulation including low-health threshold", () => {
  const rules = new RelicRules(RELICS);
  for (const hp of [39, 40, 100]) {
    const g = game({ power: 3, glass: 1, bloodprice: 1, sacrifice: 1 });
    g.player.hp = hp;
    assert.equal(
      relicMultiplier(RELICS, g.relics, g.player),
      rules.damageMultiplier(g),
    );
  }
});

test("burn, summons, health and chapter-dependent values use the current build", () => {
  assert.match(desc("cinder", game({ cinder: 2, power: 1 })), /每跳伤害 12/);
  assert.match(
    desc("bond", game({ spirit: 2, bond: 1, power: 1 })),
    /单次伤害 29.25/,
  );
  assert.match(desc("rescue", game()), /回复 45 点生命/);
  const g = game({ conductor: 1, power: 1 });
  g.chapter = 2;
  assert.match(desc("conductor", g), /引爆伤害 84.38/);
  g.target = { word: "sevenxx", dead: false };
  const longerWord = desc("blast", g, false, true);
  g.target = null;
  assert.notEqual(longerWord, desc("blast", g, false, true));
});

const { CombatSimulation } = require("../src/simulation/CombatSimulation.ts");
const { builtinContent } = require("../src/bootstrap/content.ts");
const { createGame, isolate } = require("./harness.cjs");
const { collectValues, buildStats } = require("../src/shared/relic-build.ts");
const { validateValues } = require("../src/content-sdk/validate-values.ts");

function strikeWith(content, rank) {
  const base = createGame();
  const g = new CombatSimulation(content);
  g.start(base.config);
  isolate(g);
  g.relics = { blast: rank };
  const target = g.spawnEnemy("nib", 600, 400, false, true);
  const nearby = g.spawnEnemy("nib", 650, 400, false, true);
  const distant = g.spawnEnemy("nib", 950, 400, false, true);
  for (const e of [target, nearby, distant])
    Object.assign(e, { hp: 1000, maxHp: 1000, grace: 0 });
  g.strike(target, 100, { direct: true });
  return [1000 - target.hp, 1000 - nearby.hp, 1000 - distant.hp];
}

test("blast rank doubles splash only, excludes primary target and respects radius", () => {
  assert.deepEqual(strikeWith(builtinContent, 1), [100, 35, 0]);
  assert.deepEqual(strikeWith(builtinContent, 2), [100, 70, 0]);
});

test("editing only content coefficients changes actual damage, numeric preview and symbolic formula", () => {
  const relics = structuredClone(RELICS);
  const blast = relics.find((r) => r.id === "blast");
  blast.values["blast.ratio"].args[0] = 0.2;
  const content = { ...builtinContent, relics };
  assert.deepEqual(strikeWith(content, 2), [100, 40, 0]);
  const customRules = validateValues(baseValues, relics, Object.values(BOOKS));
  const plain = describeRelic(
    blast,
    relics,
    customRules,
    BOOKS,
    previewDefaults,
    game({ blast: 2 }),
  );
  assert.match(plain, /伤害 30/);
  const formula = describeRelic(
    blast,
    relics,
    customRules,
    BOOKS,
    previewDefaults,
  );
  assert.match(formula, /0.2/);
  assert.doesNotMatch(formula, /0.35/);
});

test("new content formulas and templates work without adding evaluator or UI branches", () => {
  const custom = {
    id: "new-relic",
    name: "新遗物",
    desc: "",
    max: 2,
    grants: { effectReach: 1 },
    values: {
      "new.radius": { op: "add", args: [{ ref: "blast.radius" }, 17] },
    },
    description: { template: "范围 {new.radius}。" },
  };
  const definitions = [...RELICS, custom];
  const customRules = validateValues(
    baseValues,
    definitions,
    Object.values(BOOKS),
  );
  assert.equal(
    describeRelic(
      custom,
      definitions,
      customRules,
      BOOKS,
      previewDefaults,
      game(),
      false,
      true,
    ),
    "范围 132。",
  );
  const g = new CombatSimulation({ ...builtinContent, relics: definitions });
  g.start(createGame().config);
  g.relics = { "new-relic": 1 };
  assert.equal(g.combatValue("new.radius"), 132);
});

test("formula validation rejects missing references, cycles, malformed operators and non-finite constants", () => {
  assert.throws(
    () => new ValueRules({ x: { ref: "missing" } }),
    /Unknown formula/,
  );
  assert.throws(
    () => new ValueRules({ x: { ref: "y" }, y: { ref: "x" } }),
    /cycle/,
  );
  assert.throws(() => new ValueRules({ x: Infinity }), /Non-finite/);
  assert.throws(() => new ValueRules({ x: { op: "pow", args: [1] } }), /arity/);
  assert.throws(
    () => new ValueRules({ x: { stat: "wrong", label: "错误" } }),
    /stat/,
  );
  assert.throws(
    () =>
      validateValues(
        baseValues,
        [...RELICS, { id: "bad", description: { template: "{missing}" } }],
        [],
      ),
    /Unknown formula/,
  );
  assert.throws(
    () => collectValues({ "blast.radius": 0 }, RELICS),
    /Duplicate/,
  );
  assert.throws(
    () => rules.evaluate("blast.damage", buildStats(RELICS, { blast: 1 })),
    /Missing formula input/,
  );
});

test("candidate acquisition health costs participate in conditional damage preview", () => {
  const g = game({ sacrifice: 1 });
  g.player.hp = 41;
  assert.match(desc("bloodprice", g, false, true), /施法伤害 157.49/);
  assert.equal(g.player.hp, 41);
});
