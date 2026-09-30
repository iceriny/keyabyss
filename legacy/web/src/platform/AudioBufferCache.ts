import type { AudioClip } from '../contracts/audio.ts';
declare global { interface Window { KA_AUDIO?: Record<string, string> } }
/** Bounded decoded LRU, four concurrent decoders and deduplicated loads. */
export class AudioBufferCache {
  readonly budget = 64 * 1024 * 1024;
  private entries = new Map<string, AudioBuffer>();
  private pending = new Map<string, Promise<AudioBuffer>>();
  private failures = new Map<string, number>();
  private cancellations = new Set<() => void>();
  private waiting: (() => void)[] = [];
  private active = 0;
  private disposed = false;
  bytes = 0;
  loads = 0;
  errors = 0;
  constructor(private context: AudioContext) {}
  peek(id: string) {
    const buffer = this.entries.get(id);
    if (buffer) { this.entries.delete(id); this.entries.set(id, buffer); }
    return buffer;
  }
  load(clip: AudioClip): Promise<AudioBuffer> {
    if (this.disposed) return Promise.reject(Error('Audio cache disposed'));
    const cached = this.peek(clip.id); if (cached) return Promise.resolve(cached);
    const pending = this.pending.get(clip.id); if (pending) return pending;
    if (performance.now() - (this.failures.get(clip.id) ?? -Infinity) < 5000) return Promise.reject(Error('Audio retry backoff'));
    const request = this.decode(clip).catch(error => {
      if (!this.disposed) { this.errors++; this.failures.set(clip.id, performance.now()); console.warn(`Sound unavailable: ${clip.id}`, error); }
      throw error;
    }).finally(() => this.pending.delete(clip.id));
    this.pending.set(clip.id, request); return request;
  }
  private async decode(clip: AudioClip) {
    if (this.active >= 4) await new Promise<void>(resolve => this.waiting.push(resolve));
    if (this.disposed) throw Error('Audio cache disposed');
    this.active++;
    try {
      const encoded = await this.script(clip);
      if (this.disposed) throw Error('Audio cache disposed');
      const raw = atob(encoded); const bytes = new Uint8Array(raw.length);
      for (let i=0;i<raw.length;i++) bytes[i] = raw.charCodeAt(i);
      const buffer = await this.context.decodeAudioData(bytes.buffer);
      if (this.disposed) throw Error('Audio cache disposed');
      const size = buffer.length * buffer.numberOfChannels * 4;
      if (size > this.budget) throw Error('Audio clip exceeds decode budget');
      while (this.bytes + size > this.budget && this.entries.size) {
        const [id, oldest] = this.entries.entries().next().value!;
        this.bytes -= oldest.length * oldest.numberOfChannels * 4; this.entries.delete(id);
      }
      this.entries.set(clip.id, buffer); this.bytes += size; this.failures.delete(clip.id);
      return buffer;
    } finally { this.active--; this.waiting.shift()?.(); }
  }
  private script(clip: AudioClip): Promise<string> {
    this.loads++;
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = new URL(clip.url, document.baseURI).href; script.async = true;
      const finish = (error?: Error) => {
        clearTimeout(timer); this.cancellations.delete(cancel);
        script.remove(); script.onload = script.onerror = null;
        const payload = window.KA_AUDIO?.[clip.id];
        if (window.KA_AUDIO) delete window.KA_AUDIO[clip.id];
        if (error || !payload) reject(error ?? Error('Empty sound asset')); else resolve(payload);
      };
      const cancel = () => finish(Error('Audio load cancelled'));
      const timer = setTimeout(() => finish(Error('Audio load timed out')), 12000);
      this.cancellations.add(cancel);
      script.onload = () => finish(); script.onerror = () => finish(Error('Missing sound asset'));
      document.head.appendChild(script);
    });
  }
  diagnostics() { return { bytes: this.bytes, budget: this.budget, cached: this.entries.size, pending: this.pending.size, activeDecoders: this.active, loads: this.loads, errors: this.errors }; }
  dispose() {
    this.disposed = true;
    for (const cancel of [...this.cancellations]) cancel();
    for (const resolve of this.waiting.splice(0)) resolve();
    this.entries.clear(); this.failures.clear(); this.bytes = 0;
  }
}
