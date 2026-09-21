import { startAfterFonts } from "./fonts";

declare const __GAME_SCRIPT__: string;
declare const __GAME_STYLE__: string;

function resource(tag: "script" | "link", url: string) {
  return new Promise<void>((resolve, reject) => {
    const node = document.createElement(tag);
    if (node instanceof HTMLLinkElement) { node.rel = "stylesheet"; node.href = url; }
    else { node.src = url; node.async = true; }
    const timeout = setTimeout(() => { node.remove(); reject(new Error("Resource timeout")); }, 30000);
    node.onload = () => { clearTimeout(timeout); resolve(); };
    node.onerror = () => { clearTimeout(timeout); node.remove(); reject(new Error("Resource failed")); };
    document.head.append(node);
  });
}
let style: Promise<void> | undefined;
startAfterFonts(async () => {
  if (import.meta.env.DEV) { await import("../main"); return; }
  // Classic scripts preserve file:// releases; only load game code after the gate.
  style ??= resource("link", __GAME_STYLE__).catch(error => { style = undefined; throw error; });
  await style;
  await resource("script", __GAME_SCRIPT__);
});
