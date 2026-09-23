import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  if (index % 2) {
    context.fire(b, "ring", { heavy: phase === 3 });
    context.makeBlast(
      context.player.x,
      context.player.y,
      90,
      1.25,
      b.id,
      false,
    );
  } else {
    context.fire(b, "fan", { accel: 1.13 });
    for (const offset of [-110, 110])
      context.makeBlast(context.player.x + offset, context.player.y, 65, 1.25, b.id);
  }
  if (phase >= 2)
    context.schedule(0.32, () => context.fire(b, "fan", { accel: 1.13 }), b.id);
  if (phase === 3 && index % 2 === 0) context.laser(b, true);
};
export default attack;
