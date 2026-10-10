const test = require("node:test"),
  assert = require("node:assert/strict");
const {
  shockwaveProfile,
  addShockwave,
} = require("../src/rendering/Shockwave.ts");
const effect = (kind, t) => ({
  kind,
  type: "burst",
  x: 640,
  y: 400,
  r: 115,
  max: 0.65,
  life: 0.65 * (1 - t),
  color: "#fff",
  seed: 1,
});
test("explosive wavefronts travel outward, implosion inward, and decay completely", () => {
  for (const kind of [
    "parry",
    "shock",
    "ultimate",
    "electric",
    "flame",
    "shard",
    "implosion",
  ]) {
    let last = shockwaveProfile(effect(kind, 0)).radius;
    for (let i = 1; i <= 100; i++) {
      const wave = shockwaveProfile(effect(kind, i / 100));
      assert(kind === "implosion" ? wave.radius < last : wave.radius > last);
      assert(wave.amplitude <= wave.width * 0.211);
      assert(wave.radius > 0);
      last = wave.radius;
    }
    assert.equal(shockwaveProfile(effect(kind, 0)).amplitude, 0);
    assert.equal(shockwaveProfile(effect(kind, 1)).amplitude, 0);
  }
});
test("wave quad includes its entire crest and wake with matching normalized radius and width", () => {
  const calls = [];
  const batch = { add: (...args) => calls.push(args) };
  for (const kind of ["parry", "implosion"]) {
    const wave = shockwaveProfile(effect(kind, 0.4));
    addShockwave(batch, 640, 400, wave);
    const args = calls.at(-1),
      extent = args[2] / 2;
    assert.equal(args[2], args[3]);
    assert.equal(args[6], 1);
    assert(Math.abs(args[8] * extent - wave.radius) < 1e-9);
    assert(Math.abs(args[10][0] * extent - wave.width) < 1e-9);
    assert.equal(args[10][1], kind === "implosion" ? -1 : 1);
    assert(extent >= wave.radius + 2.99 * wave.width);
  }
});
