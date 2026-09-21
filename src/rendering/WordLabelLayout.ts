import { enemyInCombat } from "../shared/arena.ts";
import type { CombatTarget, Label } from "../combat/model.ts";
import type { OverlayFrame } from "../contracts/overlay-frame.ts";
import { clamp } from "../shared/math.ts";

/** Stable threat classes, independent of subpixel movement or distance fluctuations. */
function threat(target: Readonly<CombatTarget>, frame: OverlayFrame) {
  if (target.kind) return 0;
  if (target.charge > 0 || target.windup > 0) return 6;
  if (target.boss) return 5;
  if (target.elite) return 4;
  const profile = frame.content.enemies[target.type]?.behavior;
  if (
    profile?.attack === "laser" ||
    profile?.attack === "bombard" ||
    profile?.attack === "charge"
  )
    return 3;
  if (profile?.ranged || (profile?.attack && profile.attack !== "pursue"))
    return 2;
  return 1;
}

/** Bottom-to-top paint order. Positions only depend on the owner and viewport. */
export function layoutWordLabels(
  frame: OverlayFrame,
  measure: (word: string, font: number) => number,
): Label[] {
  const base = frame.options.largeText ? 26 : 22;
  const labels = frame.targets
    .filter((t) => !t.dead && (t.kind || enemyInCombat(frame.arena, t)))
    .map((target) => {
      const font = Math.max(
        16,
        Math.min(base, 390 / Math.max(1, target.word.length)),
      );
      const meaning = frame.options.labelMeaning ? target.meaning?.trim().replace(/\s+/g, " ") : undefined;
      const meaningLines: string[] = [];
      if (meaning) {
        const chars = Array.from(meaning);
        for (let row = 0; row < 2 && chars.length; row++) {
          let line = "";
          while (chars.length && measure(line + chars[0], 12) <= 210) line += chars.shift();
          if (row === 1 && chars.length) {
            while (line && measure(line + "…", 12) > 210) line = Array.from(line).slice(0, -1).join("");
            line += "…";
          }
          meaningLines.push(line.trim());
        }
      }
      const meaningText = meaningLines.join(" ") || undefined;
      const w = Math.max(measure(target.word, font), ...meaningLines.map(line => measure(line, 12))) + 24,
        h = font + 13 + meaningLines.length * 17;
      return {
        target,
        meaningText,
        meaningLines,
        font,
        w,
        h,
        x: clamp(target.x - w / 2, frame.arena.l, frame.arena.r - w),
        y: clamp(
          target.y - target.r - h - 12,
          frame.arena.t + 4,
          frame.arena.b + 4 - h,
        ),
      };
    });
  const priority = new Map(
    labels.map((l) => [l.target.id, threat(l.target, frame)]),
  );
  return labels.sort(
    (a, b) =>
      Number(a.target.id === frame.target?.id) -
        Number(b.target.id === frame.target?.id) ||
      priority.get(a.target.id)! - priority.get(b.target.id)! ||
      a.target.word.length - b.target.word.length ||
      b.target.id - a.target.id,
  );
}
