const profiles = {
  low: {
    name: "low",
    scale: 0.3,
    layers: 1,
    motes: 30,
    particles: 0.3,
    bloom: 0.65,
    warp: 1.25,
  },
  medium: {
    name: "medium",
    scale: 0.4,
    layers: 2,
    motes: 65,
    particles: 0.65,
    bloom: 0.9,
    warp: 2,
  },
  high: {
    name: "high",
    scale: 0.5,
    layers: 3,
    motes: 100,
    particles: 1,
    bloom: 1.12,
    warp: 2.8,
  },
} as const;
export function effectQuality(value: number) {
  return value < 0.6
    ? profiles.low
    : value < 0.9
      ? profiles.medium
      : profiles.high;
}
