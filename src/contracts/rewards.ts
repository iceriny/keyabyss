import type { Relic } from "./content.ts";
export interface SupplyReward {
  kind: "supply";
  id: string;
  name: string;
  icon: string;
  tag: string;
  desc: string;
  heal: number;
  dash: number;
  command?: string;
  rarity?: never;
}
export type RewardChoice = Relic | SupplyReward;
export const isSupplyReward = (reward: RewardChoice): reward is SupplyReward =>
  "kind" in reward && reward.kind === "supply";
