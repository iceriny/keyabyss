import type { Mode } from "../../contracts/content.ts";
import type { Campaign } from "./Campaign.ts";
import { clamp } from "../../shared/math.ts";
// Difficulty is explicit: no hidden adaptive acceleration. depth is room + loop.
export function difficulty(
  m: Mode,
  stage: number,
  time: number,
  elite: boolean,
  position: ReturnType<Campaign["at"]>,
) {
  const loop = position.loop,
    room = position.index,
    progress = clamp(time / 55, 0, 1);
  const opening = 1 + 0.3 * Math.max(0, 1 - stage / 3) * (1 - progress);
  const growth = 1 + stage * 0.075 + loop * 0.12;
  // A route is a modest wager within the selected difficulty, not an extra difficulty tier.
  const trialHealth = elite ? [1.06, 1.08, 1.1, 1.12, 1.14][m.rank] : 1;
  const trialXP = elite ? [1.2, 1.25, 1.3, 1.35, 1.4][m.rank] : 1;
  return {
    growth,
    loop,
    room,
    trialHealth,
    trialXP,
    speed: Math.min(
      4.8,
      m.speed * (1 + stage * (0.028 + m.rank * 0.004) + loop * 0.06),
    ),
    health:
      m.health *
      (1 +
        stage * (0.065 + m.rank * 0.009) +
        stage * stage * 0.0025 +
        loop * 0.18) *
      trialHealth,
    damage: m.damage * (1 + stage * 0.045 + loop * 0.08),
    interval: Math.max(
      0.55,
      (m.spawn * opening) /
        (1 + stage * (0.025 + m.rank * 0.004) + progress * 0.12 + loop * 0.05),
    ),
    cap: Math.min(
      24,
      m.cap -
        2 +
        Math.floor(stage * 0.65) +
        Math.floor(progress * 2) +
        loop +
        (elite ? Math.floor(m.rank / 2) : 0),
    ),
    elite: Math.min(
      0.7,
      m.elite +
        stage * 0.019 +
        loop * 0.025 +
        (elite ? 0.01 * (m.rank + 2) : 0),
    ),
    warning: Math.max(0.67, m.window / (1 + stage * 0.02 + loop * 0.025)),
    quota: Math.round(
      (18 + m.rank * 6 + position.chapter * 8 + position.roomNumber * 4) *
        (1 + loop * 0.17),
    ),
    attack: Math.max(
      0.42,
      m.window / (1 + stage * (0.018 + m.rank * 0.004) + loop * 0.04),
    ),
  };
}
