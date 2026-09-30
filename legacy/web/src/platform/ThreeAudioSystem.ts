import { Audio as ThreeAudio, AudioContext as ThreeAudioContext, AudioListener, Object3D, PositionalAudio } from 'three';
import type { AudioPoint, SoundCue } from '../contracts/audio.ts';
import { soundCues, type SoundCueId } from '../content/sound-cues.ts';
import { audioManifest } from '../generated/audio-manifest.ts';
import { AudioBufferCache } from './AudioBufferCache.ts';
import { audioVoiceLimits } from '../content/audio-policy.ts';
type Voice = { audio: ThreeAudio<GainNode | PannerNode>; cue: string; priority: number; started: number };
let sharedContext: AudioContext | undefined;
/** Independent audio scene: gameplay coordinates, unaffected by camera shake or render quality. */
export class ThreeAudioSystem {
  listener?: AudioListener;
  cache?: AudioBufferCache;
  private root = new Object3D();
  private pool: Voice[] = [];
  private last = new Map<string, number>();
  private previous = new Map<string, number>();
  private disposed = false;
  private epoch = 0;
  private worldEpoch = 0;
  private player = { x: 640, y: 400 };
  private sfxBus?: GainNode;
  private musicBus?: GainNode;
  private musicVoice?: ThreeAudio;
  private compressor?: DynamicsCompressorNode;
  private empty?: AudioBuffer;
  private _enabled = true;
  private _volume = .3;
  private _sfxVolume = 1;
  get sfxVolume() { return this._sfxVolume; }
  set sfxVolume(value: number) { this._sfxVolume = Number.isFinite(value) ? Math.max(0, Math.min(1,value)) : 1; this.mix(); }
  private _music = true;
  private blocked = false;
  private state = 'home';
  dropped = 0;
  played = 0;
  get ctx() { return this.listener?.context ?? null; }
  get voices() { return this.pool.filter(v=>v.audio.isPlaying).length; }
  get enabled() { return this._enabled; }
  set enabled(value: boolean) { this._enabled = value; if (!value) this.stopEffects(); this.mix(); }
  get volume() { return this._volume; }
  set volume(value: number) { this._volume = Math.max(0, Math.min(1, value)); this.mix(); }
  get music() { return this._music; }
  set music(value: boolean) { this._music = value; this.mix(); }
  private ensure() {
    if (this.disposed || this.listener) return;
    if (!sharedContext || sharedContext.state === 'closed') {
      sharedContext = new globalThis.AudioContext({ sampleRate: 48000, latencyHint: 'interactive' });
      ThreeAudioContext.setContext(sharedContext);
    }
    this.listener = new AudioListener(); this.root.add(this.listener);
    const ctx = this.listener.context;
    this.empty = ctx.createBuffer(1, 1, ctx.sampleRate);
    this.cache = new AudioBufferCache(ctx);
    this.compressor = ctx.createDynamicsCompressor();
    this.compressor.threshold.value = -14; this.compressor.knee.value = 18; this.compressor.ratio.value = 4;
    this.listener.setFilter(this.compressor);
    this.sfxBus = ctx.createGain(); this.musicBus = ctx.createGain();
    this.sfxBus.connect(this.listener.getInput()); this.musicBus.connect(this.listener.getInput()); this.mix();
    // Build the browser's HRTF database during startup, before the first combat transient.
    this.voice(true, '', 0);
  }
  init() {
    if (this.disposed) return;
    try { this.ensure(); if (this.ctx?.state === 'suspended') void this.ctx.resume().catch(()=>{}); }
    catch (error) { console.warn('Audio initialization failed', error); }
  }
  async prepare(group: SoundCue['group'] = 'ui') {
    try {
      this.ensure();
      const ids = Object.entries(soundCues).filter(([,c])=>c.group === group || (group !== 'ui' && c.group === 'battle'));
      await Promise.allSettled(ids.flatMap(([id]) => (group === 'ui' ? audioManifest[id] : audioManifest[id].slice(0,1)).map(clip => this.cache!.load(clip))));
    } catch (error) { console.warn('Audio preparation unavailable', error); }
  }
  private mix() {
    if (!this.listener) return;
    const time = this.listener.context.currentTime;
    this.listener.gain.gain.setTargetAtTime(this._volume, time, .02);
    this.sfxBus!.gain.setTargetAtTime(this._enabled && !this.blocked ? this._sfxVolume : 0, time, .015);
    this.musicBus!.gain.setTargetAtTime(this._music && !this.blocked ? (this.state === 'playing' ? .09 : .025) : 0, time, .15);
  }
  private voice(spatial: boolean, id: string, priority: number): Voice | undefined {
    const family = this.pool.filter(v => (v.audio instanceof PositionalAudio) === spatial);
    let slot = family.find(v=>!v.audio.isPlaying);
    if (!slot && family.length < (spatial ? audioVoiceLimits.spatial : audioVoiceLimits.nonSpatial)) {
      const audio = spatial ? new PositionalAudio(this.listener!) : new ThreeAudio(this.listener!);
      if (audio instanceof PositionalAudio) {
        audio.setRefDistance(2.2); audio.setMaxDistance(18); audio.setRolloffFactor(.65); audio.setDistanceModel('inverse'); audio.panner.panningModel = 'HRTF';
      }
      audio.gain.disconnect(); audio.gain.connect(this.sfxBus!); this.root.add(audio);
      slot = { audio, cue: '', priority: 0, started: 0 }; this.pool.push(slot);
      const current = slot;
      audio.onEnded = () => { ThreeAudio.prototype.onEnded.call(audio); audio.disconnect(); audio.setBuffer(this.empty!); current.cue = ''; };
    }
    if (!slot) slot = family.filter(v=>v.priority < priority).sort((a,b)=>a.priority-b.priority || a.started-b.started)[0];
    if (slot) {
      if (slot.audio.isPlaying) { slot.audio.stop(); slot.audio.disconnect(); }
      slot.cue = id; slot.priority = priority; slot.started = performance.now();
    }
    return slot;
  }
  play(id: SoundCueId, position?: AudioPoint, strength = 1, pitch = 1) {
    if (this.disposed || !this.enabled || this.blocked || !this.cache || this.ctx?.state !== 'running') return;
    const cue: SoundCue = soundCues[id]; const now = performance.now();
    if (cue.spatial && this.state !== 'playing') return;
    if (now - (this.last.get(id) ?? -Infinity) < cue.cooldown * 1000) { this.dropped++; return; }
    this.last.set(id, now);
    const variants = audioManifest[id]; if (!variants?.length) return;
    const prior = this.previous.get(id) ?? -1;
    const index = prior < 0 || variants.length === 1 ? 0 : (prior + 1 + Math.floor(Math.random() * (variants.length - 1))) % variants.length;
    this.previous.set(id, index);
    const clip = variants[index]; const point = position ? { ...position } : { ...this.player }; const epoch = this.epoch, worldEpoch = this.worldEpoch;
    const start = (buffer: AudioBuffer) => {
      if (this.disposed || epoch !== this.epoch || cue.spatial && worldEpoch !== this.worldEpoch || !this.enabled || this.blocked || this.ctx?.state !== 'running' || performance.now()-now > (cue.spatial ? 180 : 450)) return;
      if (this.pool.filter(v=>v.cue===id && v.audio.isPlaying).length >= cue.limit) { this.dropped++; return; }
      const voice = this.voice(cue.spatial, id, cue.priority); if (!voice) { this.dropped++; return; }
      const volume = cue.gain * Math.min(1.5, Math.max(0, strength));
      voice.audio.setBuffer(buffer).setVolume(volume).setPlaybackRate(pitch);
      voice.audio.offset = Math.min(cue.offset ?? 0, Math.max(0, buffer.duration - .001));
      const time = this.ctx.currentTime;
      voice.audio.gain.gain.cancelScheduledValues(time);
      voice.audio.gain.gain.setValueAtTime(cue.offset ? 0 : volume, time);
      if (cue.offset) voice.audio.gain.gain.linearRampToValueAtTime(volume, time + .006);
      voice.audio.duration = cue.duration;
      if (cue.duration) {
        const end = time + Math.min(cue.duration, buffer.duration - voice.audio.offset) / pitch;
        voice.audio.gain.gain.setValueAtTime(volume, Math.max(time, end - .025));
        voice.audio.gain.gain.linearRampToValueAtTime(0, end);
      }
      if (cue.spatial) voice.audio.position.set(point.x/160, -point.y/160, 0);
      voice.audio.play(); voice.audio.updateMatrixWorld(true); this.played++;
    };
    const buffer = this.cache.peek(clip.id);
    if (buffer) start(buffer); else void this.cache.load(clip).then(start).catch(()=>{});
  }
  update(point: AudioPoint, state: string, hidden: boolean) {
    this.player.x = point.x; this.player.y = point.y;
    if (this.state !== state || this.blocked !== hidden) {
      if (hidden) this.stopEffects();
      else if (this.state === 'playing' && state !== 'playing') this.stopEffects(true);
      this.state = state; this.blocked = hidden; this.mix();
    }
    if (this.listener) { this.listener.position.set(point.x/160, -point.y/160, 2.4); this.listener.updateMatrixWorld(true); }
  }
  stopEffects(spatialOnly = false) {
    if (spatialOnly) this.worldEpoch++; else this.epoch++;
    for (const voice of this.pool) if (!spatialOnly || voice.audio instanceof PositionalAudio) {
      if (!voice.cue) continue;
      if (voice.audio.isPlaying) voice.audio.stop();
      voice.audio.disconnect(); voice.audio.setBuffer(this.empty!); voice.cue = '';
    }
  }
  ambient(_dt: number, multiplier: number) {
    if (!this.listener || !this.music || this.ctx?.state !== 'running' || this.musicVoice) return;
    // The vendor pack has effects, not music; retain a separate quiet ambient bed.
    const buffer = this.ctx.createBuffer(1, this.ctx.sampleRate * 4, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i=0;i<data.length;i++) { const t=i/this.ctx.sampleRate; data[i] = Math.sin(Math.PI*t/4)**2 * (Math.sin(t*Math.PI*220)+.3*Math.sin(t*Math.PI*330)) * .22; }
    const audio = this.musicVoice = new ThreeAudio(this.listener);
    audio.gain.disconnect(); audio.gain.connect(this.musicBus!);
    audio.setBuffer(buffer); audio.setLoop(true); audio.setPlaybackRate(multiplier); audio.play();
  }
  diagnostics() { return { ...this.cache?.diagnostics(), voiceLimits: audioVoiceLimits, played: this.played, dropped: this.dropped, voices: this.voices, pool: this.pool.length, spatialVoices: this.pool.filter(v=>v.audio instanceof PositionalAudio && v.audio.isPlaying).map(v=>({ cue:v.cue, x:v.audio.position.x, y:v.audio.position.y, model:(v.audio as PositionalAudio).panner.panningModel })), listener: this.listener?.position.toArray() }; }
  dispose() {
    if (this.disposed) return;
    this.disposed = true; this.stopEffects(); this.cache?.dispose();
    for (const {audio} of this.pool) { audio.gain.disconnect(); if (audio instanceof PositionalAudio) audio.panner.disconnect(); }
    if (this.musicVoice) { this.musicVoice.stop(); this.musicVoice.disconnect(); this.musicVoice.gain.disconnect(); }
    this.sfxBus?.disconnect(); this.musicBus?.disconnect(); this.listener?.gain.disconnect(); this.compressor?.disconnect();
    this.root.clear(); this.pool.length = 0;
    // Three shares the AudioContext; closing it would break React remounts.
  }
}
