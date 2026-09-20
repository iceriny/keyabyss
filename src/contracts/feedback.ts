import type { AudioPoint } from './audio.ts';
/** Optional outgoing feedback port. The headless simulation has no audio dependencies. */
export interface FeedbackPort {
  init(): void;
  key(length: number, book: string): void;
  wrong(): void;
  cast(book: string, empowered: boolean, at?: AudioPoint): void;
  kill(boss: boolean, at?: AudioPoint): void;
  reward(): void;
  reflect(at?: AudioPoint): void;
  parryActivate(at?: AudioPoint): void;
  impact(kind: string, power: number, at?: AudioPoint): void;
  hit(): void;
  perfect(): void;
  dash(at?: AudioPoint): void;
  ambient(dt: number, chapter: number): void;
  overload(at?: AudioPoint): void;
  ready(): void;
  ultimate(book: string, at?: AudioPoint): void;
  charge(at?: AudioPoint): void;
  laser(at?: AudioPoint): void;
  level(): void;
  pickup(at?: AudioPoint): void;
  chapter(): void;
  result(win: boolean): void;
}
const ignore = () => {};
export const silentFeedback: FeedbackPort = Object.freeze({
  init: ignore,
  key: ignore,
  wrong: ignore,
  cast: ignore,
  kill: ignore,
  reward: ignore,
  reflect: ignore,
  parryActivate: ignore,
  impact: ignore,
  hit: ignore,
  perfect: ignore,
  dash: ignore,
  ambient: ignore,
  overload: ignore,
  ready: ignore,
  ultimate: ignore,
  charge: ignore,
  laser: ignore,
  level: ignore,
  pickup: ignore,
  chapter: ignore,
  result: ignore,
});
