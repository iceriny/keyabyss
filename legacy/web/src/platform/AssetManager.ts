import type { AssetDefinition } from "../contracts/assets.ts";

export interface AssetEnvironment {
  baseURL(): string;
  image(): HTMLImageElement;
  audio(): HTMLAudioElement;
  objectURL(file: Blob): string;
  revokeURL(url: string): void;
}
const browserEnvironment: AssetEnvironment = {
  baseURL: () => document.baseURI,
  image: () => new Image(),
  audio: () => new Audio(),
  objectURL: (file) => URL.createObjectURL(file),
  revokeURL: (url) => URL.revokeObjectURL(url),
};
type Resource = HTMLImageElement | HTMLAudioElement;
type Entry = {
  promise: Promise<Resource>;
  resource: Resource;
  cancel: () => void;
};

/** File/HTTP/data/blob assets use native browser loaders, including offline audio without fetch CORS. */
export class AssetManager {
  private readonly definitions = new Map<string, AssetDefinition>();
  private readonly cache = new Map<string, Entry>();
  private readonly ownedURLs = new Map<string, string>();
  private readonly voices = new Map<
    HTMLAudioElement,
    { id: string; stop: () => void }
  >();
  private readonly environment: AssetEnvironment;
  private readonly timeout: number;
  private disposed = false;

  constructor(
    definitions: readonly AssetDefinition[] = [],
    environment = browserEnvironment,
    timeout = 15000,
  ) {
    this.environment = environment;
    this.timeout = timeout;
    for (const definition of definitions) this.register(definition);
  }
  register(definition: AssetDefinition) {
    if (this.disposed) throw new Error("AssetManager disposed");
    if (
      !definition.id ||
      !definition.src ||
      !["image", "audio"].includes(definition.kind)
    )
      throw new Error("Invalid asset definition");
    if (this.definitions.has(definition.id))
      throw new Error(`Duplicate asset ${definition.id}`);
    this.definitions.set(definition.id, Object.freeze({ ...definition }));
  }
  resolve(id: string): string {
    if (this.disposed) throw new Error("AssetManager disposed");
    const definition = this.definitions.get(id);
    if (!definition) throw new Error(`Unknown asset ${id}`);
    return new URL(definition.src, this.environment.baseURL()).href;
  }
  /** Import user-picked media for the current session; unregister/dispose revokes the object URL. */
  importFile(id: string, file: File) {
    const kind = file.type.startsWith("image/")
      ? "image"
      : file.type.startsWith("audio/")
        ? "audio"
        : null;
    if (!kind) throw new Error("Only image and audio files are supported");
    if (this.definitions.has(id) || this.disposed)
      throw new Error(`Cannot import asset ${id}`);
    const src = this.environment.objectURL(file);
    try {
      this.register({ id, kind, src });
      this.ownedURLs.set(id, src);
    } catch (error) {
      this.environment.revokeURL(src);
      throw error;
    }
    return id;
  }
  loadImage(id: string): Promise<HTMLImageElement> {
    return this.load(id, "image") as Promise<HTMLImageElement>;
  }
  loadAudio(id: string): Promise<HTMLAudioElement> {
    return this.load(id, "audio") as Promise<HTMLAudioElement>;
  }
  async preload(
    ids: readonly string[],
    progress?: (loaded: number, total: number) => void,
  ) {
    const unique = [...new Set(ids)];
    let loaded = 0;
    progress?.(0, unique.length);
    await Promise.all(
      unique.map(async (id) => {
        const definition = this.definitions.get(id);
        if (!definition) throw new Error(`Unknown asset ${id}`);
        await this.load(id, definition.kind);
        progress?.(++loaded, unique.length);
      }),
    );
  }
  private load(id: string, kind: AssetDefinition["kind"]): Promise<Resource> {
    if (this.disposed)
      return Promise.reject(new Error("AssetManager disposed"));
    if (this.definitions.get(id)?.kind !== kind)
      return Promise.reject(new Error(`Unknown ${kind} asset ${id}`));
    const cached = this.cache.get(id);
    if (cached) return cached.promise;
    let url: string;
    try {
      url = this.resolve(id);
    } catch (error) {
      return Promise.reject(error);
    }
    const resource =
      kind === "image" ? this.environment.image() : this.environment.audio();
    const event = kind === "image" ? "load" : "loadeddata";
    let cancel = () => {};
    const promise = new Promise<Resource>((resolve, reject) => {
      let settled = false;
      const finish = (error?: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        resource.removeEventListener(event, ready);
        resource.removeEventListener("error", failed);
        if (error) {
          this.cache.delete(id);
          this.release(resource, kind);
          reject(error);
        } else resolve(resource);
      };
      const ready = () => finish();
      const failed = () => finish(new Error(`Asset failed to load: ${id}`));
      const timer = setTimeout(
        () => finish(new Error(`Asset loading timed out: ${id}`)),
        this.timeout,
      );
      cancel = () => finish(new Error(`Asset loading cancelled: ${id}`));
      resource.addEventListener(event, ready);
      resource.addEventListener("error", failed);
      if (kind === "audio") (resource as HTMLAudioElement).preload = "auto";
      resource.src = url;
      if (kind === "audio") (resource as HTMLAudioElement).load();
    });
    this.cache.set(id, { promise, resource, cancel });
    return promise;
  }
  /** Call from a user-authorized audio interaction. Playback errors remain visible to the caller. */
  async playAudio(
    id: string,
    options: { loop?: boolean; volume?: number } = {},
  ) {
    const source = await this.loadAudio(id);
    if (this.disposed) throw new Error("AssetManager disposed");
    const voice = source.cloneNode(true) as HTMLAudioElement;
    voice.loop = options.loop ?? false;
    voice.volume = Math.max(0, Math.min(1, options.volume ?? 1));
    const stop = () => {
      voice.pause();
      voice.removeAttribute("src");
      voice.load();
      this.voices.delete(voice);
      voice.removeEventListener("ended", stop);
    };
    this.voices.set(voice, { id, stop });
    voice.addEventListener("ended", stop);
    try {
      await voice.play();
    } catch (error) {
      stop();
      throw error;
    }
    return { element: voice, stop };
  }
  unload(id: string) {
    for (const voice of this.voices.values()) if (voice.id === id) voice.stop();
    const entry = this.cache.get(id);
    if (entry) {
      entry.cancel();
      this.release(entry.resource, this.definitions.get(id)!.kind);
      this.cache.delete(id);
    }
  }
  unregister(id: string) {
    this.unload(id);
    this.definitions.delete(id);
    const url = this.ownedURLs.get(id);
    if (url) {
      this.environment.revokeURL(url);
      this.ownedURLs.delete(id);
    }
  }
  private release(resource: Resource, kind: AssetDefinition["kind"]) {
    if (kind === "audio") (resource as HTMLAudioElement).pause();
    resource.removeAttribute("src");
    if (kind === "audio") (resource as HTMLAudioElement).load();
  }
  dispose() {
    if (this.disposed) return;
    for (const id of [...this.definitions.keys()]) this.unregister(id);
    for (const voice of this.voices.values()) voice.stop();
    this.voices.clear();
    this.disposed = true;
  }
}
