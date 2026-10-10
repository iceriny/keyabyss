import type { Word, Vocabulary } from "../contracts/game.ts";
import type { Game } from "../game.ts";
declare global {
  interface Window {
    KeyAbyssNativeRenderer?: new (
      canvas: HTMLCanvasElement,
      port: import("../contracts/render-frame.ts").PresentationPort,
    ) => NonNullable<Game["nativeRenderer"]>;
    KA_WORDS?: Record<string, (Word | string)[]>;
    KAVOCAB: { books: Vocabulary[] };
    __KEYABYSS__?: {
      game: Game;
      assets: import("../platform/AssetManager.ts").AssetManager;
      books(): Vocabulary[];
    };
  }
}
