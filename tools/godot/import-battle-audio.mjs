// Restore all selected variants per battle cue from the frozen Web audio manifest.
// WAV files are generated assets; this script is their reproducible source.
import { readFileSync, mkdirSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const source = readFileSync(join(root, 'legacy/web/src/generated/audio-manifest.ts'), 'utf8');
const manifest = JSON.parse(source.slice(source.indexOf('= {') + 2, source.lastIndexOf('}') + 1));
const cues = [
  'cast.frost', 'cast.storm', 'cast.spirit', 'cast.flame',
  'impact.frost', 'impact.storm', 'impact.spirit', 'impact.flame',
  'dash', 'parry.activate', 'parry', 'hit', 'kill',
  'ultimate.frost', 'ultimate.storm', 'ultimate.spirit', 'ultimate.flame',
  'victory', 'defeat', 'key', 'ready', 'charge', 'laser', 'chapter',
  'parry.ring', 'overload', 'impact.blast', 'melee.swing', 'spirit.summon',
];
const aliases = { 'melee.swing': 'dash', 'spirit.summon': 'impact.spirit' };
const destination = join(root, 'assets/audio/battle');
mkdirSync(destination, { recursive: true });

for (const cue of cues) {
  const clips = manifest[aliases[cue] ?? cue];
  if (clips?.length !== 3) throw new Error(`Expected three selected variants: ${cue}`);
  for (const [index, clip] of clips.entries()) {
  const wrapper = readFileSync(join(root, 'legacy/web/public/audio', `${clip.id}.js`), 'utf8');
  const match = wrapper.match(/="([A-Za-z0-9+/=]+)";\s*$/);
  if (!match) throw new Error(`Unexpected clip wrapper: ${clip.id}`);
  const flac = Buffer.from(match[1], 'base64');
  if (flac.toString('ascii', 0, 4) !== 'fLaC') throw new Error(`Not FLAC: ${clip.id}`);
  const output = join(destination, `${cue.replaceAll('.', '-')}${index ? `-${index + 1}` : ''}.wav`);
  const converted = spawnSync('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-nostdin', '-y', '-f', 'flac', '-i', 'pipe:0',
    '-map', '0:a:0', '-map_metadata', '-1', '-bitexact',
    '-acodec', 'pcm_s16le', '-f', 'wav', output,
  ], { input: flac });
  if (converted.status !== 0) throw new Error(`ffmpeg failed for ${clip.id}: ${converted.stderr}`);
  console.log(`${cue}: ${clip.id} -> ${output} (${statSync(output).size} bytes)`);
  }
}
