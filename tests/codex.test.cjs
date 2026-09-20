const test = require("node:test");
const assert = require("node:assert/strict");
const { RELICS } = require("../src/content/catalog.ts");
const { sortRelicsByRarity } = require("../src/ui/relic-presentation.ts");

test("codex sorts appended content by rarity without changing the reward pool", () => {
  const pool = Object.freeze([...RELICS]);
  const before = pool.map((r) => r.id);
  const sorted = sortRelicsByRarity(pool);
  const ranks = { common: 0, rare: 1, curse: 2, awaken: 3 };
  const levels = sorted.map((r) => ranks[r.rarity ?? "common"]);
  assert.deepEqual(
    levels,
    [...levels].sort((a, b) => a - b),
  );
  assert.deepEqual(
    pool.map((r) => r.id),
    before,
  );
  assert.equal(new Set(sorted.map((r) => r.id)).size, pool.length);
  for (const rarity of Object.keys(ranks)) {
    assert.deepEqual(
      sorted.filter((r) => (r.rarity ?? "common") === rarity),
      pool.filter((r) => (r.rarity ?? "common") === rarity),
      `stable order within ${rarity}`,
    );
  }
  assert.deepEqual(
    sorted.filter((r) => r.rarity === "rare").map((r) => r.id),
    ["feather", "rescue"],
  );
  assert.ok(
    sorted.findIndex((r) => r.id === "firewalk") <
      sorted.findIndex((r) => r.id === "avalanche"),
  );
});

test("owned relics sort independently of acquisition order, including empty inventory", () => {
  const owned = ["inferno", "glass", "rescue", "cinder", "feather"].map((id) =>
    RELICS.find((r) => r.id === id),
  );
  assert.deepEqual(
    sortRelicsByRarity(owned).map((r) => r.id),
    ["cinder", "rescue", "feather", "glass", "inferno"],
  );
  assert.deepEqual(sortRelicsByRarity([]), []);
});
