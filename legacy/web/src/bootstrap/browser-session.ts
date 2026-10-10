import { assetManager } from "./assets.ts";
import { Game } from "../game.ts";
import { SessionController } from "../application/SessionController.ts";
import { prepareBattle } from "../loading.ts";
import type { GameEvents, Vocabulary } from "../contracts/game.ts";

export function createBrowserSession(options: {
  canvas: HTMLCanvasElement;
  overlay: HTMLCanvasElement | null;
  events: GameEvents;
  books: () => Vocabulary[];
}) {
  const game = new Game(options.canvas, options.events);
  game.overlay = options.overlay ?? undefined;
  game.prepareRenderer = () => prepareBattle(game);
  const session = new SessionController(game);
  const pointer = (event: PointerEvent) => {
    session.unlockAudio();
    game.clickTarget(
      (event.clientX - game.ox) / game.scale,
      (event.clientY - game.oy) / game.scale,
    );
  };
  options.canvas.addEventListener("pointerdown", pointer);
  if (new URLSearchParams(location.search).has("debug"))
    window.__KEYABYSS__ = { game, books: options.books, assets: assetManager };
  return {
    session,
    dispose() {
      options.canvas.removeEventListener("pointerdown", pointer);
      session.dispose();
      game.destroy();
      if (window.__KEYABYSS__?.game === game) delete window.__KEYABYSS__;
    },
  };
}
