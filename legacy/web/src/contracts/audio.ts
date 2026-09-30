export type AudioPoint = { x: number; y: number };
export type UISound = 'focus' | 'select' | 'open' | 'close' | 'confirm' | 'invalid' | 'tab' | 'type' | 'enter' | 'ritualRise' | 'ritualImpact' | 'ritualChime' | 'book';
export interface SoundCue {
  source: string;
  variants?: readonly number[];
  spatial: boolean;
  gain: number;
  cooldown: number;
  priority: number;
  limit: number;
  /** Short percussive cues can release their voice before the source's long reverb tail. */
  duration?: number;
  /** Start within the decoded clip, in source seconds, to align an authored transient. */
  offset?: number;
  group: 'ui' | 'battle' | 'frost' | 'storm' | 'spirit' | 'flame';
}
export interface AudioClip { id: string; url: string; duration: number; bytes: number }
