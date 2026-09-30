export interface DamageModifier {
  factor: number;
  perStack?: boolean;
  belowHealth?: number;
  priority: number;
}

export type RelicEffect =
  | { kind: "heal"; amount: number }
  | { kind: "maxHealth"; amount: number; heal: number }
  | { kind: "dashCharge"; amount: number }
  | { kind: "bloodPrice"; amount: number }
  | { kind: "shield"; amount: number; cap: number; color: string }
  | { kind: "pulse"; radius: number; damage: number };

export interface RelicHook {
  phase: "acquire" | "afterCast";
  priority: number;
  every?: number;
  counter?: "casts" | "perfectWords";
  perfectOnly?: boolean;
  /** Only the first matching hook in a group runs for this event. */
  exclusiveGroup?: string;
  effect: RelicEffect;
}
