import type { Point, Spirit } from "../combat/model.ts";
import type { SpiritFlightProfile } from "../contracts/spirit-flight.ts";

export function orbitPoint(
  player: Point,
  time: number,
  i: number,
  count: number,
  profile: SpiritFlightProfile,
): Point {
  const o = profile.orbit,
    phase = time * o.speed + (i / Math.max(1, count)) * Math.PI * 2;
  return {
    x: player.x + Math.cos(phase) * (o.radiusX + Math.sin(phase * 2) * o.sway),
    y:
      player.y -
      o.lift +
      Math.sin(phase) * o.radiusY +
      Math.sin(phase * 2 + i) * o.sway,
  };
}

/** Preserve the departure tangent; alternating banks keep a flock from sharing one line. */
export function beginFlight(
  s: Spirit,
  mode: "dive" | "return" | "cross",
  end: Point,
  profile: SpiritFlightProfile,
) {
  const p = profile[mode],
    dx = end.x - s.x,
    dy = end.y - s.y;
  const distance = Math.hypot(dx, dy),
    d = distance || 1,
    side = s.i % 2 ? -1 : 1;
  const duration = Math.max(
    p.minDuration,
    Math.min(p.maxDuration, distance / p.speed),
  );
  const nx = (-dy / d) * side,
    ny = (dx / d) * side,
    bank = Math.min(distance, 240) * p.bend;
  const velocity = Math.hypot(s.vx, s.vy);
  const departure = Math.min(
    Math.max(12, distance * 0.8),
    (velocity * duration) / 3,
  );
  s.mode = mode;
  s.flight = {
    start: { x: s.x, y: s.y },
    control: {
      x:
        s.x +
        (velocity > 0.001 ? (s.vx / velocity) * departure : 0),
      y:
        s.y +
        (velocity > 0.001 ? (s.vy / velocity) * departure : 0),
    },
    bend: { x: nx * bank, y: ny * bank },
    end: { ...end },
    elapsed: 0,
    duration,
  };
}

export function flightPoint(
  f: NonNullable<Spirit["flight"]>,
  t: number,
): Point {
  t = Math.max(0, Math.min(1, t));
  const u = 1 - t;
  // The arrival control follows the endpoint, so moving enemies cannot leave a frozen aim point.
  const c2 = f.arrival
    ? { x: f.end.x - f.arrival.x, y: f.end.y - f.arrival.y }
    : {
        x: f.end.x - (f.end.x - f.control.x) * 0.22 + f.bend.x,
        y: f.end.y - (f.end.y - f.control.y) * 0.22 + f.bend.y,
      };
  return {
    x:
      u ** 3 * f.start.x +
      3 * u * u * t * f.control.x +
      3 * u * t * t * c2.x +
      t ** 3 * f.end.x,
    y:
      u ** 3 * f.start.y +
      3 * u * u * t * f.control.y +
      3 * u * t * t * c2.y +
      t ** 3 * f.end.y,
  };
}

/** Bounded Hermite sampling for paper trails; input points remain owned by the simulation. */
export function smoothPaperTrail(points: readonly Point[], maxPoints = 64): Point[] {
  if (points.length < 2) return points.map((p) => ({ x: p.x, y: p.y }));
  const limit = Number.isFinite(maxPoints) ? Math.max(2, Math.min(64, Math.floor(maxPoints))) : 64;
  const count = Math.min(limit, (points.length - 1) * 3 + 1);
  const tangent = (index: number) => {
    const p = points[index],
      before = points[Math.max(0, index - 1)],
      after = points[Math.min(points.length - 1, index + 1)];
    const dx = (after.x - before.x) * 0.5,
      dy = (after.y - before.y) * 0.5,
      length = Math.hypot(dx, dy);
    const incoming = index > 0 ? Math.hypot(p.x - before.x, p.y - before.y) : Infinity,
      outgoing = index + 1 < points.length ? Math.hypot(after.x - p.x, after.y - p.y) : Infinity,
      scale = length ? Math.min(1, Math.min(incoming, outgoing) * 0.75 / length) : 0;
    return { x: dx * scale, y: dy * scale };
  };
  const result: Point[] = [];
  let segment = -1, a = tangent(0), b = tangent(1);
  for (let sample = 0; sample < count; sample++) {
    const position = sample * (points.length - 1) / (count - 1),
      index = Math.min(points.length - 2, Math.floor(position)),
      t = position - index;
    if (segment !== index) {
      a = tangent(index); b = tangent(index + 1); segment = index;
    }
    const p = points[index], q = points[index + 1],
      h = t * t * (3 - 2 * t),
      departure = t * (1 - t) * (1 - t),
      arrival = -t * t * (1 - t);
    result.push({
      x: p.x + (q.x - p.x) * h + a.x * departure + b.x * arrival,
      y: p.y + (q.y - p.y) * h + a.y * departure + b.y * arrival,
    });
  }
  return result;
}
