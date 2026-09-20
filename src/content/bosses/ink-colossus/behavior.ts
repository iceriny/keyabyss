import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  context.fire(b, "ring", { heavy: phase === 3 });
  if (phase >= 2) {
    context.schedule(0.32, () => context.fire(b, "fan", { accel: 1.13 }), b.id);
    context.makeBlast(
      context.player.x,
      context.player.y,
      90,
      1.25,
      b.id,
      false,
    );
  }
  if (phase === 3 && index % 2 === 0) context.laser(b, true);
};
export default attack;
