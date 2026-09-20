import { prepareResourcePlan } from "../content-sdk/resources.ts";
import type { Game } from "../game.ts";
import type {
  PresentationPort,
  RenderFrame,
} from "../contracts/render-frame.ts";

export function createPresentationPort(game: Game): PresentationPort {
  prepareResourcePlan(game.content);
  const keys = [
    "roomVisit",
    "state",
    "book",
    "chapter",
    "bookData",
    "config",
    "options",
    "player",
    "target",
    "arena",
    "prefix",
    "ultimateTime",
    "visualTime",
    "kickX",
    "kickY",
    "shake",
    "hitFlash",
    "entityScale",
    "ox",
    "oy",
    "scale",
    "decoy",
    "enemies",
    "nodes",
    "decals",
    "fields",
    "trails",
    "corpses",
    "spirits",
    "bullets",
    "lasers",
    "blasts",
    "shots",
    "particles",
    "fx",
  ] as const satisfies readonly (keyof RenderFrame)[];
  const descriptors: PropertyDescriptorMap = {
    cues: { value: game.presentationCues.reader(), enumerable: true },
    content: {
      value: Object.freeze({
        appearances: game.content.appearances,
        bosses: game.content.bosses,
        books: game.content.books,
        enemies: game.content.enemies,
        chapters: game.content.chapters,
      }),
      enumerable: true,
    },
  };
  for (const key of keys)
    descriptors[key] = { get: () => game[key], enumerable: true };
  const frame = Object.freeze(
    Object.defineProperties({}, descriptors),
  ) as RenderFrame;
  return Object.freeze({
    frame,
    setDensity(value: number) {
      game.dpr = value;
    },
    contextLost() {
      if (game.state === "playing") game.pause();
      game.emit("toast", "画面连接已中断，恢复后可继续。");
    },
    contextRestored() {
      game.invalidate();
    },
    contextRestoreFailed() {
      game.emit("toast", "画面恢复失败，请重新加载游戏。");
    },
  });
}
