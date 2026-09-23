import type { BookId, Report } from "../contracts/game.ts";
import type { TalentConfiguration, TalentLoadout, TalentProgress, TalentReceipt } from "../contracts/talents.ts";
import type { StorageAdapter } from "../platform/StorageAdapter.ts";
import { TALENT_BOOKS } from "../content/talents.ts";
import { resolveTalentLoadout, MAX_TALENT_POINTS } from "../shared/talents.ts";

const count = (value: unknown): number => typeof value === "number" && Number.isFinite(value) ? Math.max(0, Math.min(Number.MAX_SAFE_INTEGER, Math.floor(value))) : 0;
const GRAPH_VERSION = 2;
export const emptyTalentConfiguration = (): TalentConfiguration => ({ version: 1, graphVersion: GRAPH_VERSION, byBook: {} });
export const emptyTalentProgress = (): TalentProgress => ({ ...emptyTalentConfiguration(), manualCharacters: 0, byRun: {}, receipts: {} });
export const earnedTalentPoints = (characters: number) => Math.min(MAX_TALENT_POINTS, 2 + Math.floor(count(characters) / 120));

function normalizedBooks(value: unknown, budget: number, godMode: boolean): TalentConfiguration["byBook"] {
  const raw = value && typeof value === "object" ? value as Record<string, TalentLoadout> : {};
  return Object.fromEntries(TALENT_BOOKS.filter(book => raw[book] && typeof raw[book] === "object").map(book => [book, resolveTalentLoadout(book, raw[book], budget, godMode)]));
}

export function readTalentProgress(storage: Pick<StorageAdapter, "read">): TalentProgress {
  const saved = storage.read<Partial<TalentProgress> | null>("talents", null);
  if (saved?.version !== 1) return emptyTalentProgress();
  const manualCharacters = count(saved.manualCharacters);
  const byRun = Object.fromEntries(Object.entries(saved.byRun && typeof saved.byRun === "object" ? saved.byRun : {}).map(([id, value]) => [id, count(value)]));
  const receipts = Object.fromEntries(Object.entries(saved.receipts && typeof saved.receipts === "object" ? saved.receipts : {}).filter(([, value]) => value && typeof value === "object").map(([id, value]) => [id, { characters: count(value.characters), points: Math.min(MAX_TALENT_POINTS, count(value.points)) }]));
  // Changed graph semantics return every allocation to the budget without changing earned progress.
  return { version: 1, graphVersion: GRAPH_VERSION, manualCharacters, byRun, receipts, byBook: saved.graphVersion === GRAPH_VERSION ? normalizedBooks(saved.byBook, earnedTalentPoints(manualCharacters), false) : {} };
}

export function readGodTalents(storage: Pick<StorageAdapter, "read">): TalentConfiguration {
  const saved = storage.read<Partial<TalentConfiguration> | null>("talents-god", null);
  return saved?.version === 1 && saved.graphVersion === GRAPH_VERSION ? { version: 1, graphVersion: GRAPH_VERSION, byBook: normalizedBooks(saved.byBook, MAX_TALENT_POINTS, true) } : emptyTalentConfiguration();
}

export function updateTalentLoadout<T extends TalentConfiguration>(configuration: T, book: BookId, loadout: TalentLoadout, budget: number, godMode = false): T {
  return { ...configuration, graphVersion: GRAPH_VERSION, byBook: { ...configuration.byBook, [book]: resolveTalentLoadout(book, loadout, budget, godMode) } };
}

export const talentReceiptId = (report: Report): string => report.settlementId ?? `${report.runId ?? report.seed}:${report.loop ?? 0}:${report.outcome ?? (report.win ? "victory" : "defeat")}`;

/** Reports carry cumulative completed human characters; retain the maximum per run forever. */
export function settleTalentProgress(progress: TalentProgress, report: Report): { progress: TalentProgress; receipt: TalentReceipt } {
  const zero = { characters: 0, points: 0 };
  if (report.godMode || typeof report.manualCharacters !== "number" || !Number.isFinite(report.manualCharacters)) return { progress, receipt: zero };
  const id = talentReceiptId(report);
  if (Object.hasOwn(progress.receipts, id)) return { progress, receipt: zero };
  const runId = report.runId ?? report.settlementId ?? id;
  const previous = Object.hasOwn(progress.byRun, runId) ? progress.byRun[runId] : 0;
  const completed = count(report.manualCharacters);
  const characters = Math.max(0, completed - previous);
  const manualCharacters = count(progress.manualCharacters + characters);
  const receipt = { characters, points: earnedTalentPoints(manualCharacters) - earnedTalentPoints(progress.manualCharacters) };
  return { progress: { ...progress, manualCharacters, byRun: { ...progress.byRun, [runId]: Math.max(previous, completed) }, receipts: { ...progress.receipts, [id]: receipt } }, receipt };
}
