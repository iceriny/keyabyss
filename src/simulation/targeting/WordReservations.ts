import type { Enemy, Shot } from "../../combat/model.ts";

/** A projectile owns its original word lease independently of later homing targets. */
export const WordReservations = {
  reserve(shot: Shot, target: Enemy, refresh = false) {
    target.pendingHits = (target.pendingHits || 0) + 1;
    shot.reserved = true;
    if (refresh) {
      target.wordPending = true;
      shot.wordTarget = target;
    }
  },
  release(
    shot: Shot,
    enemies: readonly Enemy[],
    refresh: (enemy: Enemy) => void,
  ) {
    if (shot.reserved) {
      const target = enemies.find((e) => e.id === shot.targetId);
      if (target) target.pendingHits = Math.max(0, target.pendingHits - 1);
      shot.reserved = false;
    }
    const owner = shot.wordTarget;
    if (owner) {
      shot.wordTarget = null;
      owner.wordPending = false;
      if (!owner.dead) refresh(owner);
    }
  },
  cancel(shots: readonly Shot[], enemies: readonly Enemy[]) {
    for (const shot of shots) this.release(shot, enemies, () => {});
  },
};
