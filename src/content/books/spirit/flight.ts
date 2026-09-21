import type { SpiritFlightProfile } from "../../../contracts/spirit-flight.ts";
export const spiritFlight: SpiritFlightProfile = {
  orbit: {
    radiusX: 78,
    radiusY: 48,
    speed: 0.95,
    lift: 17,
    sway: 9,
    response: 7,
  },
  dive: { speed: 780, minDuration: 0.28, maxDuration: 0.78, bend: 0.32 },
  return: { speed: 630, minDuration: 0.36, maxDuration: 0.85, bend: 0.46 },
  cross: {
    speed: 1450,
    minDuration: 0.18,
    maxDuration: 0.4,
    bend: 0.08,
    reach: 108,
    angle: Math.PI * 0.24,
  },
  trailPoints: 20,
};
