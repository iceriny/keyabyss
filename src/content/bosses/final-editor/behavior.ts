import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  context.fire(b, "ring", { curve: index % 2 ? 0.14 : -0.14 });
  context.laser(b, true);
  if (phase >= 2)
    context.schedule(
      0.5,
      () =>
        context.makeBlast(context.player.x, context.player.y, 95, 1.15, b.id),
      b.id,
    );
  if (phase === 3)
    context.schedule(
      0.42,
      () => context.fire(b, "ring", { speed: 0.83 }),
      b.id,
    );
};
export default attack;
