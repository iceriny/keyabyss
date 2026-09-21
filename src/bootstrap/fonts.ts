import { gameFonts } from "../generated/font-manifest.ts";

const pending = new Map<string, Promise<FontFace>>();

function loadFont(font: (typeof gameFonts)[number]) {
  let request = pending.get(font.family);
  if (!request) {
    const url = new URL(font.url, document.baseURI).href;
    const face = new FontFace(font.family, `url("${url}") format("woff2")`, {
      style: "normal", weight: "400", display: "block",
    });
    request = face.load().then((loaded) => {
      document.fonts.add(loaded);
      return loaded;
    }).catch((error) => {
      pending.delete(font.family);
      throw error;
    });
    pending.set(font.family, request);
  }
  return request;
}

/** Fonts and the first-visit acknowledgement are independent gates. */
export function startAfterFonts(mount: () => void | Promise<void>) {
  const status = document.getElementById("boot-status")!;
  const detail = document.getElementById("boot-detail")!;
  const hint = document.getElementById("boot-hint")!;
  const retry = document.getElementById("boot-retry") as HTMLButtonElement;
  const next = document.getElementById("boot-continue") as HTMLButtonElement;
  const fullscreen = document.getElementById("boot-fullscreen") as HTMLButtonElement;
  const root = document.documentElement;
  let first = true;
  try { first = localStorage.getItem("keyabyss.preflight-complete") !== "true"; } catch {}
  let running = false, mounted = false, entering = false, ready = false, acknowledged = !first;
  fullscreen.hidden = next.hidden = !first;
  if (first) hint.textContent = "推荐全屏游玩。准备完成后，请点击继续进入。";
  const full = async () => {
    try {
      if (!document.fullscreenElement) await document.documentElement.requestFullscreen();
      fullscreen.textContent = "已开启全屏";
    } catch { fullscreen.textContent = "请按 F11 开启全屏"; }
  };
  fullscreen.addEventListener("click", full);
  const enter = async () => {
    if (!ready || entering || mounted || !acknowledged) return;
    entering = true;
    next.disabled = true;
    retry.hidden = true;
    status.textContent = "正在展开书库";
    detail.textContent = "字体已就绪 · 正在准备游戏";
    try {
      await mount();
      mounted = true;
      try { localStorage.setItem("keyabyss.preflight-complete", "true"); } catch {}
      retry.removeEventListener("click", start);
      next.removeEventListener("click", continueGame);
      fullscreen.removeEventListener("click", full);
    } catch {
      status.textContent = "书库尚未准备完成";
      detail.textContent = "请检查网络，然后重试。字体无需重复下载。";
      retry.hidden = false;
    } finally { entering = false; }
  };
  const continueGame = () => { if (ready) { acknowledged = true; void enter(); } };
  const start = async () => {
    if (running || mounted || entering) return;
    running = true;
    ready = false;
    next.disabled = true;
    let active = true, completed = 0;
    root.dataset.fonts = "loading";
    retry.hidden = true;
    status.textContent = "正在准备字体";
    detail.textContent = `0 / ${gameFonts.length} · 首次加载 ${(gameFonts.reduce((n, font) => n + font.bytes, 0) / 1048576).toFixed(1)} MB`;
    await new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));
    const slow = setTimeout(() => {
      if (active) status.textContent = "字体仍在下载，请稍候";
    }, 8000);
    let timeout: ReturnType<typeof setTimeout> | undefined;
    try {
      await Promise.race([
        Promise.all(gameFonts.map(async (font) => {
          await loadFont(font);
          if (active) detail.textContent = `${++completed} / ${gameFonts.length} · 字体就绪`;
        })),
        new Promise<never>((_, reject) => {
          timeout = setTimeout(() => reject(new Error("Font loading timed out")), 30000);
        }),
      ]);
      await document.fonts.ready;
    } catch {
      root.dataset.fonts = "error";
      status.textContent = "字体尚未加载完成";
      detail.textContent = "请检查网络或字体文件，然后重试。";
      retry.hidden = false;
      return;
    } finally {
      active = false;
      running = false;
      clearTimeout(slow);
      clearTimeout(timeout);
    }
    root.dataset.fonts = "ready";
    ready = true;
    status.textContent = "准备就绪";
    detail.textContent = "字体已完整载入 · 等待启程";
    next.textContent = "继续进入 →";
    next.disabled = false;
    if (acknowledged) void enter();
  };
  retry.addEventListener("click", start);
  next.addEventListener("click", continueGame);
  void start();
}
