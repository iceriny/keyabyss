// Restore the selected Web audio clips as native Godot WAV resources.
// The Web files contain Base64 FLAC, which is decoded from the actual clipped audio.
import { readFileSync, mkdirSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const manifestText = readFileSync(join(root, 'legacy/web/src/generated/audio-manifest.ts'), 'utf8');
const manifest = JSON.parse(manifestText.slice(manifestText.indexOf('= {') + 2, manifestText.lastIndexOf('}') + 1));
const names = [
  'ui.enter', 'ui.book', 'ui.type', 'ui.focus', 'ui.select', 'ui.open',
  'ui.close', 'ui.confirm', 'ui.invalid', 'ui.ritualRise',
  'ui.ritualImpact', 'ui.ritualChime', 'ui.tab',
];
const destination = join(root, 'assets/audio/ui');
mkdirSync(destination, { recursive: true });

for (const name of names) {
  const clips = manifest[name];
  if (!clips?.length) throw new Error(`Missing manifest entry: ${name}`);
  for (const [index, clip] of clips.entries()) {
    const wrapper = readFileSync(join(root, 'legacy/web/public/audio', `${clip.id}.js`), 'utf8');
    const match = wrapper.match(/="([A-Za-z0-9+/=]+)";\s*$/);
    if (!match) throw new Error(`Unexpected clip wrapper: ${clip.id}`);
    const flac = Buffer.from(match[1], 'base64');
    if (flac.toString('ascii', 0, 4) !== 'fLaC') throw new Error(`Not FLAC: ${clip.id}`);
    const file = `${name.slice(3)}-${index + 1}.wav`;
    const output = join(destination, file);
    const converted = spawnSync('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-nostdin', '-y', '-f', 'flac', '-i', 'pipe:0',
      '-map', '0:a:0', '-map_metadata', '-1', '-bitexact',
      '-acodec', 'pcm_s16le', '-f', 'wav', output,
    ], { input: flac });
    if (converted.status !== 0) throw new Error(`ffmpeg failed for ${clip.id}: ${converted.stderr}`);
    console.log(`${name} ${index + 1}: ${clip.id} -> ${file} (${statSync(output).size} bytes)`);
  }
}
