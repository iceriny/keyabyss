import type { Report } from "./game.ts";

/** Persisted separately from temporary in-run relics. No talents are enabled yet. */
export interface CareerProfile {
  version: 1;
  settlements: number;
  victories: number;
  defeats: number;
  abandoned: number;
  kills: number;
  casts: number;
  elapsed: number;
  talentRanks: Record<string, number>;
  currencies: Record<string, number>;
}
export interface SettlementContext {
  readonly id: string;
  readonly report: Readonly<Report>;
  /** Only the newly completed segment; later loops report cumulative combat counters. */
  readonly delta: Readonly<{ kills: number; casts: number; elapsed: number }>;
  readonly eligible: boolean;
}
/** Future talent progression plugs in as a pure reducer, committed with the report atomically. */
export type ProgressionPolicy = (profile: Readonly<CareerProfile>, settlement: SettlementContext) => CareerProfile;
export interface RunArchive {
  version: 1;
  records: Report[];
  career: CareerProfile;
  checkpoints: Record<string, { loop: number; kills: number; casts: number; elapsed: number }>;
}
