import type { SpiritFlightProfile } from "../../../contracts/spirit-flight.ts";
export const spiritFlight: SpiritFlightProfile = {
  orbit: {
    radiusX: 104,
    radiusY: 66,
    speed: 0.5,
    lift: 17,
    sway: 13,
    response: 5,
  },
  dive: { speed: 470, minDuration: 0.48, maxDuration: 1.3, bend: 0.62 },
  return: { speed: 360, minDuration: 0.62, maxDuration: 1.5, bend: 0.72 },
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
