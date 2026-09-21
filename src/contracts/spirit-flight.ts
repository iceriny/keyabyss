export interface SpiritFlightProfile {
  orbit: {
    radiusX: number;
    radiusY: number;
    speed: number;
    lift: number;
    sway: number;
    response: number;
  };
  dive: {
    speed: number;
    minDuration: number;
    maxDuration: number;
    bend: number;
  };
  return: {
    speed: number;
    minDuration: number;
    maxDuration: number;
    bend: number;
  };
  cross: {
    speed: number;
    minDuration: number;
    maxDuration: number;
    bend: number;
    reach: number;
    angle: number;
  };
  trailPoints: number;
}
