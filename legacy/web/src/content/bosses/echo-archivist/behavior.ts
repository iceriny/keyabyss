import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  if (index % 2) {
    context.laser(b, true);
    context.fire(b, "ring", { curve: 0.23 });
  } else {
    context.fire(b, "ring", { curve: -0.23 });
    for (const offset of [-110, 110])
      context.makeBlast(context.player.x, context.player.y + offset, 65, 1.3, b.id);
  }
  if (phase >= 2)
    for (let j = 1; j <= 2; j++)
      context.schedule(
        j * 0.3,
        () => context.fire(b, "fan", { curve: j % 2 ? 0.22 : -0.22 }),
        b.id,
      );
};
export default attack;
