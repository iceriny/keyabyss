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
  const departure = Math.min(distance * 0.45, (velocity * duration) / 3);
  s.mode = mode;
  s.flight = {
    start: { x: s.x, y: s.y },
    control: {
      x:
        s.x +
        (velocity > 30 ? (s.vx / velocity) * departure : dx * 0.2 + nx * bank),
      y:
        s.y +
        (velocity > 30 ? (s.vy / velocity) * departure : dy * 0.2 + ny * bank),
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
