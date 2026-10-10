import { createPresentationPort } from "./application/presentation.ts";
import type { Vocabulary, Word } from "./contracts/game.ts";
import type { Game } from "./game.ts";

let rendererModule: Promise<void> | undefined;
async function loadBattleModule() {
  if (window.KeyAbyssNativeRenderer) return;
  if (!rendererModule) {
    rendererModule = (
      import.meta.env.DEV
        ? import("./rendering/native-entry.ts").then(() => {})
        : new Promise<void>((resolve, reject) => {
            const script = document.createElement("script");
            script.src = new URL(
              import.meta.env.VITE_BATTLE_RENDERER,
              document.baseURI,
            ).href;
            const finish = (error?: Error) => {
              clearTimeout(timer);
              script.remove();
              script.onload = script.onerror = null;
              error ? reject(error) : resolve();
            };
            const timer = setTimeout(
              () => finish(new Error("战场资源读取超时，请重试。")),
              20000,
            );
            script.onload = () =>
              finish(
                window.KeyAbyssNativeRenderer
                  ? undefined
                  : new Error("战场资源不完整，请重新下载。"),
              );
            script.onerror = () =>
              finish(new Error("无法读取战场资源，请确认 assets 文件夹完整。"));
            document.head.appendChild(script);
          })
    ).catch((error) => {
      rendererModule = undefined;
      throw error;
    });
  }
  await rendererModule;
}

const rendererPending = new WeakMap<Game, Promise<void>>();
export async function prepareBattle(
  game: Game,
  stage?: (label: string) => void,
) {
  const previous = rendererPending.get(game);
  if (previous) return previous;
  const request = (async () => {
    stage?.("展开战场");
    await loadBattleModule();
    if (game.destroyed) return;
    stage?.("准备光影与空间");
    await paint();
    if (game.destroyed) return;
    if (!game.nativeRenderer) {
      try {
        game.nativeRenderer = new window.KeyAbyssNativeRenderer!(
          game.canvas,
          createPresentationPort(game),
        );
      } catch {
        throw new Error("无法建立 WebGL 2 战场。请启用浏览器硬件加速后重试。");
      }
    }
    await game.nativeRenderer.prepare();
  })();
  rendererPending.set(game, request);
  try {
    await request;
  } finally {
    rendererPending.delete(game);
  }
}

const pending = new Map<string, Promise<Word[]>>();
const resolved = new Map<string, Word[]>();

/** Classic scripts work with both HTTP and file://; only the chosen dictionary is parsed. */
export async function loadVocabulary(book: Vocabulary): Promise<Word[]> {
  if (book.custom || !book.asset) return book.words;
  if (resolved.has(book.id)) return resolved.get(book.id)!;
  const existing = pending.get(book.id);
  if (existing) return existing;
  const request = new Promise<Word[]>((resolve, reject) => {
    const script = document.createElement("script");
    script.async = true;
    script.src = new URL(book.asset!, document.baseURI).href;
    const cleanup = () => {
      clearTimeout(timeout);
      script.remove();
      script.onload = script.onerror = null;
    };
    const fail = () => {
      cleanup();
      delete window.KA_WORDS?.[book.id];
      reject(
        new Error(
          `无法读取「${book.title}」。请确认 word 文件夹与 index.html 位于同一目录。`,
        ),
      );
    };
    const timeout = setTimeout(fail, 15000);
    script.onerror = fail;
    script.onload = () => {
      const payload = window.KA_WORDS?.[book.id];
      if (
        !Array.isArray(payload) ||
        payload.length !== book.count ||
        !payload.every(
          (w) => typeof w === "string" || typeof w.word === "string",
        )
      ) {
        fail();
        return;
      }
      const words = payload.map((w) =>
        typeof w === "string" ? { word: w } : w,
      );
      cleanup();
      delete window.KA_WORDS?.[book.id];
      resolved.set(book.id, words);
      resolve(words);
    };
    document.head.appendChild(script);
  });
  pending.set(book.id, request);
  try {
    return await request;
  } finally {
    pending.delete(book.id);
  }
}

/** Yield a paint, not an artificial progress timer. */
export const paint = () =>
  new Promise<void>((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
  );
export const vocabularyCount = (book: Vocabulary) =>
  book.count ?? book.words.length;
