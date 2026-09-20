import * as THREE from "three";
import type { RenderFrame } from "../contracts/render-frame.ts";
import type { AppearanceDefinition } from "../contracts/content.ts";
import type { AtlasRegion } from "./InstancedBatch";
import { ActorPainter } from "./ActorPainter";
import { enemyDefaults } from "../combat/model";
export interface AppearanceHandle {
  readonly page: number;
  readonly uv: AtlasRegion;
}
const baseEnemy = {
  id: 0,
  word: "",
  mass: 1,
  vx: 0,
  vy: 0,
  ix: 0,
  iy: 0,
  tilt: 0,
  squash: 0,
  grace: 0,
  shoot: 0,
  chill: 0,
  freeze: 0,
  flash: 0,
  stun: 0,
  impactTime: 0,
  collisionCD: 0,
  poise: 0,
  conduct: 0,
  dot: 0,
  dotStacks: 0,
  dotTick: 0,
  mark: 0,
  phase: 0,
};

type Painter = (
  ctx: CanvasRenderingContext2D,
  appearance: AppearanceDefinition,
) => void;
/** Immutable authoring registry. New appearances reuse a painter without new simulation cases. */
export function createAtlas(game: RenderFrame, maxTextureSize = 2048) {
  const width = Math.min(2048, maxTextureSize),
    height = Math.min(1024, maxTextureSize),
    tileSize = 256;
  if (width < tileSize || height < tileSize)
    throw new Error("Texture size below actor tile requirement");
  const columns = Math.floor(width / tileSize),
    rows = Math.floor(height / tileSize),
    capacity = columns * rows;
  const canvases: HTMLCanvasElement[] = [],
    contexts: CanvasRenderingContext2D[] = [],
    entries = new Map<string, AppearanceHandle>();
  const author = new ActorPainter(game);
  const painters: Record<AppearanceDefinition["kind"], Painter> = {
    enemy(ctx, appearance) {
      const data =
        Object.values(game.content.enemies).find(
          (e) => e.appearance === appearance.id,
        ) ?? game.content.enemies[appearance.shape];
      author.drawEnemy(
        ctx,
        {
          ...enemyDefaults(),
          ...baseEnemy,
          type: appearance.shape,
          x: 0,
          y: 0,
          r: (data?.r ?? 20) * game.entityScale,
          hp: 1,
          maxHp: 1,
          age: 0,
          phase: 0,
        },
        data?.color,
      );
    },
    boss(ctx, appearance) {
      author.chapter = Number(appearance.shape) || 0;
      author.drawEnemy(ctx, {
        ...enemyDefaults(),
        ...baseEnemy,
        type: "guard",
        boss: true,
        x: 0,
        y: 0,
        r: 40,
        hp: 1,
        maxHp: 1,
        age: 0,
      });
    },
    player(ctx, appearance) {
      author.book = appearance.shape;
      author.bookData =
        Object.values(game.content.books).find(
          (b) => b.appearance === appearance.id,
        ) ?? Object.values(game.content.books)[0];
      author.player = { ...game.player, x: 0, y: 0, shield: 0, invuln: 0 };
      author.drawPlayer(ctx);
    },
    node(ctx, appearance) {
      author.drawNode(ctx, {
        id: 0,
        type: "node",
        word: "",
        r: 17,
        hp: 0,
        maxHp: 0,
        boss: false,
        dead: false,
        grace: 0,
        pendingHits: 0,
        wordPending: false,
        phaseLock: 0,
        source: null,
        x: 0,
        y: 0,
        kind: appearance.shape === "ink" ? "ink" : "rune",
        phase: 0,
        age: 1,
        life: 1,
      });
    },
    spirit(ctx) {
      ctx.scale(game.entityScale, game.entityScale);
      ctx.fillStyle = "#ceb4fb";
      ctx.strokeStyle = "#eadeff";
      ctx.lineWidth = 1.1;
      ctx.beginPath();
      ctx.moveTo(0, -15);
      ctx.lineTo(17, 7);
      ctx.lineTo(4, 3);
      ctx.lineTo(0, 10);
      ctx.lineTo(-4, 3);
      ctx.lineTo(-17, 7);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.strokeStyle = "#8873b3";
      ctx.beginPath();
      ctx.moveTo(0, -13);
      ctx.lineTo(0, 8);
      ctx.stroke();
    },
  };
  for (const appearance of game.content.appearances) {
    if (entries.has(appearance.id))
      throw new Error(`Duplicate appearance ${appearance.id}`);
    const index = entries.size,
      page = Math.floor(index / capacity),
      slot = index % capacity,
      x = (slot % columns) * tileSize,
      y = Math.floor(slot / columns) * tileSize;
    if (!canvases[page]) {
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("无法准备角色图集");
      canvases.push(canvas);
      contexts.push(ctx);
    }
    const c = contexts[page];
    entries.set(appearance.id, {
      page,
      uv: [
        x / width,
        1 - (y + tileSize) / height,
        tileSize / width,
        tileSize / height,
      ],
    });
    c.save();
    c.beginPath();
    c.rect(x, y, tileSize, tileSize);
    c.clip();
    c.translate(x + 128, y + 128);
    c.scale(2, 2);
    painters[appearance.kind](c, appearance);
    c.restore();
  }
  const pages = canvases.map((canvas) => {
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.generateMipmaps = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    return texture;
  });
  if (!pages.length) throw new Error("No appearance resources");
  return { texture: pages[0], pages, entries, width, height };
}
