import type { BurstEffect } from "../combat/model.ts";
export interface EventEnvelope<T> {
  readonly session: number;
  readonly sequence: number;
  readonly value: Readonly<T>;
}
export interface EventReader<T> {
  readonly session: number;
  readonly sequence: number;
  after(sequence: number): readonly EventEnvelope<T>[];
}
export type DomainEvent =
  | {
      type: "damage";
      entity: number;
      amount: number;
      depth: number;
      direct: boolean;
    }
  | { type: "death"; entity: number; depth: number }
  | { type: "cast"; entity: number; word: string }
  | { type: "room"; room: string; visit: number };
export type PresentationCue = {
  type: "burst";
  room: number;
  effect: Readonly<BurstEffect>;
};
