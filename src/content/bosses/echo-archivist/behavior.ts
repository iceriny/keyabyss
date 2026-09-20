import type { EnemyAction } from "../../../content-sdk/EnemyBehavior.ts";
const attack: EnemyAction = (context, b) => {
  const phase = b.phase,
    index = b.attackIndex;

  context.laser(b, true);
  context.fire(b, "ring", { curve: 0.23 });
  if (phase >= 2)
    for (let j = 1; j <= 2; j++)
      context.schedule(
        j * 0.3,
        () => context.fire(b, "fan", { curve: j % 2 ? 0.22 : -0.22 }),
        b.id,
      );
};
export default attack;
