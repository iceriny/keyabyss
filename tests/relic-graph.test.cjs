const test = require("node:test");
const assert = require("node:assert/strict");
const { manifest } = require("../src/content/manifest.ts");
const { collectCapabilities, relicConnections } = require("../src/shared/combat-capabilities.ts");
const { eligibleRelic } = require("../src/simulation/progression/EligibilityService.ts");
const { drawRelics, relicWeight, upgradeChoices } = require("../src/simulation/progression/RewardSystem.ts");
const { validateContent } = require("../src/content-sdk/validate.ts");
const { relicArt } = require("../src/ui/relic-art.ts");
const { random, hash } = require("../src/shared/math.ts");

const relic = (id) => manifest.relics.find((entry) => entry.id === id);
const book = (id) => manifest.books.find((entry) => entry.id === id);
const context = (levels = {}, capabilities = [], definitions = manifest.relics) => ({
  levels, capabilities, definitions, book: "frost", shortest: 3, longest: 12,
});
const fixture = (id, extra = {}) => ({ id, name: id, tag: "test", icon: id, desc: id, max: 2, ...extra });

test("capability prerequisites accept main book, another book, talent and relic sources", () => {
  const guard = relic("guardseal");
  for (const capabilities of [
    collectCapabilities(book("spirit"), manifest.relics, {}),
    collectCapabilities(book("frost"), manifest.relics, {}, book("spirit").combat.capabilities),
    collectCapabilities(book("frost"), manifest.relics, {}, ["carrier"]),
    collectCapabilities(book("frost"), manifest.relics, { copyfolio: 1 }),
    collectCapabilities(book("frost"), manifest.relics, { spirit: 1 }),
  ]) assert.equal(eligibleRelic(guard, context({}, capabilities)), true);
  assert.equal(eligibleRelic(guard, context({}, ["cold"])), false);
  assert.deepEqual(collectCapabilities(book("frost"), [fixture("unused", { provides: ["heat"], needs: ["guard"] })], {}, ["cold", "release"]), ["cold", "release"]);
  assert.deepEqual(collectCapabilities(book("frost"), [fixture("active", { provides: ["heat"], needs: ["guard"] })], { active: 1 }), ["cold", "heat"]);
});

test("provides introduces a capability while needs and modifies describe current connections", () => {
  const entry = fixture("provider", { provides: ["heat"], needs: ["carrier"], modifies: ["heat", "carrier", "release"] });
  assert.deepEqual(relicConnections(entry, ["cold", "carrier", "release"]), ["carrier", "release"]);
  assert.deepEqual(relicConnections(fixture("provider", { provides: ["heat"] }), ["heat"]), []);
  assert.equal(eligibleRelic(relic("emberink"), context()), true);
  assert.equal(eligibleRelic(relic("crystalframe"), context()), true);
});

test("copyfolio must reach rank II before either mutually exclusive branch can appear", () => {
  for (const id of ["scatterfolio", "heavyfolio"]) {
    assert.equal(eligibleRelic(relic(id), context({}, ["carrier"])), false);
    assert.equal(eligibleRelic(relic(id), context({ copyfolio: 1 }, ["carrier"])), false);
    assert.equal(eligibleRelic(relic(id), context({ copyfolio: 2 }, ["carrier"])), true);
    assert.equal(eligibleRelic(relic(id), context({ copyfolio: 2, [id]: 1 }, ["carrier"])), false);
  }
  assert.equal(eligibleRelic(relic("copyfolio"), context({ copyfolio: 2 })), false);
  assert.equal(eligibleRelic(relic("scatterfolio"), context({ copyfolio: 2, heavyfolio: 1 }, ["carrier"])), false);
  assert.equal(eligibleRelic(relic("heavyfolio"), context({ copyfolio: 2, scatterfolio: 1 }, ["carrier"])), false);
  const first = fixture("first", { excludes: ["second"] });
  const second = fixture("second");
  assert.equal(eligibleRelic(second, context({ first: 1 }, [], [first, second])), false);
  assert.equal(eligibleRelic(first, context({ second: 1 }, [], [first, second])), false);
});

test("capability selection preserves book, stack and word-length restrictions", () => {
  const entry = fixture("bounded", { book: "frost", requires: ["power"], minWordLength: 8, maxWordLength: 4 });
  const valid = context({ power: 1 });
  assert.equal(eligibleRelic(entry, valid), true);
  for (const change of [
    { book: "storm" }, { levels: {} }, { levels: { power: 1, bounded: 2 } },
    { longest: 7 }, { shortest: 5 },
  ]) assert.equal(eligibleRelic(entry, { ...valid, ...change }), false);
});

test("weighted sampling is seeded, distinct and preserves unconnected exploration", () => {
  const pool = [
    fixture("deep", { rarity: "awaken", affinity: ["frost"], modifies: ["cold"] }),
    fixture("linked", { modifies: ["cold"] }),
    fixture("more", { modifies: ["cold"] }),
    fixture("another", { modifies: ["cold"] }),
    fixture("exploration", { provides: ["heat"] }),
  ];
  assert.ok(Math.abs(relicWeight(pool[0], "frost", { deep: 1 }, ["cold"]) - 2.2) < 1e-9);
  assert.equal(relicWeight(pool[4], "frost", {}, ["cold"]), 1);
  assert.ok(Math.abs(relicWeight(pool[0], "frost", { deep: 2 }, ["cold"]) - 1.85) < 1e-9);
  const select = (seed) => drawRelics(pool, "frost", { deep: 1 }, ["cold"], random(hash(seed))).map((entry) => entry.id);
  assert.deepEqual(select("same-seed"), select("same-seed"));
  assert.equal(new Set(select("same-seed")).size, 3);
  const outcomes = Array.from({ length: 128 }, (_, seed) => select(seed));
  assert.ok(outcomes.some((ids) => ids.includes("exploration")));
  assert.ok(outcomes.some((ids) => !ids.includes("deep")));
  assert.ok(new Set(outcomes.map((ids) => ids.join())).size > 10);
  assert.equal(pool.length, 5);
  assert.deepEqual(drawRelics([], "frost", {}, [], random(1)), []);
  assert.equal(drawRelics(pool.slice(0, 2), "frost", {}, [], random(1)).length, 2);
});

test("reward integration draws only eligible content and keeps the exhausted-pool supply", () => {
  const make = (levels, seed) => {
    const capabilities = collectCapabilities(book("frost"), manifest.relics, levels);
    return {
      content: manifest, book: "frost", relics: levels, capabilities, rng: random(hash(seed)),
      canUpgrade: (entry) => eligibleRelic(entry, context(levels, capabilities)),
    };
  };
  for (let seed = 0; seed < 64; seed++) {
    const levels = { copyfolio: 2, scatterfolio: 1 };
    const choices = upgradeChoices.call(make(levels, seed));
    assert.equal(choices.length, 3);
    assert.ok(choices.every((entry) => !["copyfolio", "scatterfolio", "heavyfolio"].includes(entry.id)));
    assert.deepEqual(choices, upgradeChoices.call(make(levels, seed)));
  }
  const levels = Object.fromEntries(manifest.relics.map((entry) => [entry.id, entry.max]));
  assert.equal(upgradeChoices.call(make(levels, 1))[0].id, "renewal");
});

test("new content has distinct SVG engravings, valid commands and declared structural grants", () => {
  validateContent(manifest);
  const ids = ["copyfolio", "guardseal", "swiftbinding", "scatterfolio", "heavyfolio", "thermalvault", "crystalframe", "emberink", "wirestitch"];
  assert.equal(new Set(Object.values(relicArt)).size, Object.values(relicArt).length);
  for (const id of ids) {
    assert.equal(relic(id).icon, id);
    assert.match(relic(id).command, /^[a-z]+$/);
    assert.match(relicArt[id], /^M[0-9]/);
    assert.ok(relicArt[id].length > 60);
    assert.equal(Object.keys(relic(id).grants).length, 1);
  }
});

test("content validation rejects invalid capabilities, exclusions, levels and level dependency cycles", () => {
  const rejects = (change, expression) => {
    const copy = structuredClone(manifest);
    change(copy);
    assert.throws(() => validateContent(copy), expression);
  };
  for (const key of ["provides", "needs", "modifies"])
    rejects((copy) => { copy.relics[0][key] = ["unknown"]; }, /unknown capability/);
  rejects((copy) => { copy.books[0].combat.capabilities = ["unknown"]; }, /unknown capability/);
  rejects((copy) => { copy.books[0].combat.element = "unknown"; }, /unknown element/);
  rejects((copy) => { copy.relics[0].provides = ["cold", "cold"]; }, /duplicate capability/);
  rejects((copy) => { copy.relics[0].excludes = ["missing"]; }, /unknown exclusion/);
  rejects((copy) => { copy.relics[0].excludes = [copy.relics[0].id]; }, /cannot exclude itself/);
  rejects((copy) => { copy.relics[0].requiresLevels = { missing: 1 }; }, /unknown prerequisite/);
  for (const level of [0, -1, 1.5, 3, Infinity])
    rejects((copy) => { copy.relics[0].requiresLevels = { copyfolio: level }; }, /invalid prerequisite level/);
  rejects((copy) => { copy.relics[0].requiresLevels = { [copy.relics[0].id]: 1 }; }, /dependency cycle/);
});
