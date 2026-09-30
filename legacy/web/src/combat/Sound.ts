import type { AudioPoint, UISound } from '../contracts/audio.ts';
import type { FeedbackPort } from '../contracts/feedback.ts';
import { ThreeAudioSystem } from '../platform/ThreeAudioSystem.ts';
type Book = 'frost' | 'storm' | 'spirit' | 'flame';
const school = (book: string): Book => book === 'storm' || book === 'spirit' || book === 'flame' ? book : 'frost';
/** Semantic adapter: simulation knows neither Three nor asset filenames. */
export class Sound extends ThreeAudioSystem implements FeedbackPort {
  ui(kind: UISound) {
    const pitch = kind === 'ritualImpact' ? .58 : kind === 'ritualRise' ? .72 : kind === 'book' ? .86 : 1;
    const play = () => this.play(`ui.${kind}`, undefined, 1, pitch);
    if (this.ctx?.state === 'suspended') void this.ctx.resume().then(play).catch(()=>{});
    else play();
  }
  key(n: number, _book: string) { this.play('key', undefined, 1, 1 + Math.min(n,15)*.012); }
  wrong() { this.ui('invalid'); }
  cast(book: string, heavy = false, at?: AudioPoint) { this.play(`cast.${school(book)}`, at, heavy ? 1.2 : 1, heavy ? .92 : 1); }
  impact(kind: string, power = 1, at?: AudioPoint) {
    const key = kind === 'ice' || kind === 'frost' ? 'frost' : kind === 'storm' || kind === 'electric' ? 'storm' : kind === 'blade' || kind === 'paper' || kind === 'spirit' ? 'spirit' : kind === 'fire' || kind === 'flame' ? 'flame' : 'blast';
    this.play(`impact.${key}`, at, power);
  }
  kill(boss = false, at?: AudioPoint) { this.play(boss ? 'boss.kill' : 'kill', at); }
  hit() { this.play('hit'); }
  dash(at?: AudioPoint) { this.play('dash', at); }
  parryActivate(at?: AudioPoint) { this.play('parry.activate', at); }
  reflect(at?: AudioPoint) { this.play('parry', at); this.play('parry.ring', at); }
  perfect() { this.play('perfect'); }
  overload(at?: AudioPoint) { this.play('overload', at); }
  ready() { this.play('ready'); }
  charge(at?: AudioPoint) { this.play('charge', at); }
  laser(at?: AudioPoint) { this.play('laser', at); }
  ultimate(book: string, at?: AudioPoint) { this.play(`ultimate.${school(book)}`, at); }
  reward() { this.play('reward'); }
  level() { this.play('level'); }
  pickup(at?: AudioPoint) { this.play('pickup', at); }
  chapter() { this.play('chapter'); }
  result(win: boolean) { this.play(win ? 'victory' : 'defeat'); }
}
