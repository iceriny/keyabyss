const clamp = (x: number, a: number, b: number) => Math.max(a, Math.min(b, x));
function random(seed: number) {
  let a = seed >>> 0;
  return () => {
    a += 0x6d2b79f5;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash(s: unknown) {
  let h = 2166136261;
  for (const c of String(s)) {
    h ^= c.charCodeAt(0);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
const pick = <T>(a: readonly T[], r = Math.random) =>
  a[Math.floor(r() * a.length)];
function shuffle<T>(a: T[], r = Math.random) {
  a = a.slice();
  for (let i = a.length - 1; i > 0; i--) {
    let j = Math.floor(r() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
// Segment-to-circle distance for fast projectiles: never tunnel between frames.
function segmentDistance(
  px: number,
  py: number,
  x: number,
  y: number,
  cx: number,
  cy: number,
) {
  const dx = x - px,
    dy = y - py,
    t = clamp(
      ((cx - px) * dx + (cy - py) * dy) / (dx * dx + dy * dy || 1),
      0,
      1,
    );
  return Math.hypot(px + t * dx - cx, py + t * dy - cy);
}

export { clamp, random, hash, pick, shuffle, segmentDistance };
