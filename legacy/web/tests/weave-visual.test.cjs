const test = require("node:test"), assert = require("node:assert/strict");
const { beginFlight, flightPoint, smoothPaperTrail } = require("../src/shared/spirit-flight.ts");
const { spiritFlight } = require("../src/content/books/spirit/flight.ts");

function velocityAt(flight, time) {
  const delta = 1e-6, from = Math.max(0, time - delta), to = Math.min(1, time + delta);
  const a = flightPoint(flight, from), b = flightPoint(flight, to);
  return { x: (b.x - a.x) / ((to - from) * flight.duration), y: (b.y - a.y) / ((to - from) * flight.duration) };
}

test("paper flight preserves low-speed and ordinary departure velocity in every phase", () => {
  for (const mode of ["dive", "return", "cross"]) {
    for (const velocity of [{ vx: 8, vy: -10 }, { vx: 100, vy: 60 }, { vx: 0, vy: 0 }]) {
      const s = { x: 100, y: 150, i: 1, ...velocity };
      const end = Object.freeze({ x: 500, y: 300 });
      beginFlight(s, mode, end, spiritFlight);
      const next = velocityAt(s.flight, 0);
      assert(Math.abs(next.x - s.vx) < 0.03);
      assert(Math.abs(next.y - s.vy) < 0.03);
      assert.deepEqual(flightPoint(s.flight, 0), { x: 100, y: 150 });
      assert.deepEqual(flightPoint(s.flight, 1), end);
      assert.equal(s.mode, mode);
      assert(s.flight.duration >= spiritFlight[mode].minDuration);
      assert(s.flight.duration <= spiritFlight[mode].maxDuration);
    }
  }
});

test("a redirected flight keeps its incoming tangent with a bounded control handle", () => {
  const s = { x: 100, y: 150, i: 0, vx: 110, vy: 35 };
  beginFlight(s, "dive", { x: 500, y: 330 }, spiritFlight);
  const position = flightPoint(s.flight, 0.5), velocity = velocityAt(s.flight, 0.5);
  Object.assign(s, position, { vx: velocity.x, vy: velocity.y });
  beginFlight(s, "return", { x: 150, y: 100 }, spiritFlight);
  const next = velocityAt(s.flight, 0);
  const alignment = (next.x * velocity.x + next.y * velocity.y) / (Math.hypot(next.x, next.y) * Math.hypot(velocity.x, velocity.y));
  assert(alignment > 0.99999);
  const distance = Math.hypot(s.flight.end.x - s.x, s.flight.end.y - s.y);
  assert(Math.hypot(s.flight.control.x - s.x, s.flight.control.y - s.y) <= Math.max(12, distance * 0.8) + 1e-9);
});

test("return arrival follows the supplied orbit tangent and clamps curve boundaries", () => {
  const s = { x: 20, y: 40, i: 0, vx: 60, vy: 10 };
  beginFlight(s, "return", { x: 200, y: 140 }, spiritFlight);
  s.flight.arrival = { x: 25 * s.flight.duration / 3, y: -18 * s.flight.duration / 3 };
  const arrival = velocityAt(s.flight, 1);
  assert(Math.abs(arrival.x - 25) < 0.02);
  assert(Math.abs(arrival.y + 18) < 0.02);
  assert.deepEqual(flightPoint(s.flight, -1), s.flight.start);
  assert.deepEqual(flightPoint(s.flight, 2), s.flight.end);
});

test("paper trail sampling preserves endpoints, input coordinates and a hard point budget", () => {
  for (const length of [0, 1, 2, 20, 2000]) {
    const points = Object.freeze(Array.from({ length }, (_, i) => Object.freeze({ x: i * 8, y: Math.sin(i * 0.3) * 30 })));
    for (const limit of [2, 12, 36, 64, 10000, NaN]) {
      const result = smoothPaperTrail(points, limit);
      assert(result.length <= 64);
      if (Number.isFinite(limit)) assert(result.length <= Math.max(2, Math.min(64, limit)));
      assert(result.every((p) => Number.isFinite(p.x) && Number.isFinite(p.y)));
      if (length) {
        assert.deepEqual(result[0], points[0]);
        assert.deepEqual(result.at(-1), points.at(-1));
        assert.notEqual(result[0], points[0]);
      }
      assert.deepEqual(result, smoothPaperTrail(points, limit));
    }
  }
});

test("uneven and repeated trail knots stay close to their original segments", () => {
  const points = [
    { x: 0, y: 0 }, { x: 120, y: 0 }, { x: 120, y: 2 },
    { x: 120, y: 2 }, { x: 110, y: 20 }, { x: 30, y: 10 },
  ];
  const before = structuredClone(points), sampled = smoothPaperTrail(points);
  for (let i = 0; i < sampled.length; i++) {
    const index = Math.min(points.length - 2, Math.floor(i / 3)), a = points[index], b = points[index + 1];
    const margin = Math.hypot(b.x - a.x, b.y - a.y) * 0.2 + 1e-9, p = sampled[i];
    assert(p.x >= Math.min(a.x, b.x) - margin && p.x <= Math.max(a.x, b.x) + margin);
    assert(p.y >= Math.min(a.y, b.y) - margin && p.y <= Math.max(a.y, b.y) + margin);
  }
  assert.deepEqual(points, before);
});

test("coincident flight endpoints and repeated trail points remain finite", () => {
  for (const velocity of [0, 900]) {
    const s = { x: 50, y: 50, i: 1, vx: velocity, vy: -velocity };
    beginFlight(s, "return", { x: 50, y: 50 }, spiritFlight);
    for (let i = 0; i <= 20; i++) {
      const point = flightPoint(s.flight, i / 20);
      assert(Number.isFinite(point.x) && Number.isFinite(point.y));
    }
  }
  assert(smoothPaperTrail(Array.from({ length: 20 }, () => ({ x: 50, y: 50 }))).every((p) => p.x === 50 && p.y === 50));
});
