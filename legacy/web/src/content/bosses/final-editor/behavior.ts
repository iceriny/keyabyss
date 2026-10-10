import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  context.fire(b, "ring", { curve: index % 2 ? 0.14 : -0.14 });
  if (index % 2) context.laser(b, true);
  else
    for (const offset of [-135, 135])
      context.makeBlast(context.player.x + offset, context.player.y, 75, offset < 0 ? 1.25 : 1.65, b.id);
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
