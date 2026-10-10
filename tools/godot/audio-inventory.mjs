// Reproducible source inventory. Vendor masters and legacy slice edits are read-only.
import { readFileSync, writeFileSync, statSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { soundCues } from '../../legacy/web/src/content/sound-cues.ts';

const root = resolve(import.meta.dirname, '../..');
const legacy = join(root, 'legacy/web');
const catalog = JSON.parse(readFileSync(join(legacy, 'data/audio-catalog.json'), 'utf8'));
const overrides = JSON.parse(readFileSync(join(legacy, 'data/audio-overrides.json'), 'utf8'));
const destination = join(root, 'docs/audio');
mkdirSync(destination, { recursive: true });
const originals = [['file', 'relative_path', 'category', 'fx_name', 'description', 'duration_seconds', 'sample_rate_hz', 'channels', 'bits_per_sample', 'bytes', 'variant_count', 'slice_source', 'legacy_cues', 'manufacturer', 'library', 'copyright']];
const slices = [['file', 'variant_index', 'start_seconds', 'end_seconds', 'duration_seconds', 'description', 'legacy_cues']];
for (const source of catalog.sources) {
  const relative = `legacy/web/art/Magic UI Designed/${source.file}`;
  const absolute = join(root, relative);
  const actual = statSync(absolute);
  if (actual.size !== source.bytes) throw Error(`Source changed: ${relative}; refresh the source catalog before indexing.`);
  const probe = spawnSync('ffprobe', ['-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=sample_rate,channels,bits_per_sample:format=duration', '-of', 'json', absolute], { encoding: 'utf8', windowsHide: true });
  if (probe.status !== 0) throw Error(probe.stderr);
  const info = JSON.parse(probe.stdout);
  const stream = info.streams[0];
  const regions = overrides[source.file] ?? source.regions;
  const cueEntries = Object.entries(soundCues).filter(([, cue]) => cue.source === source.file);
  originals.push([source.file, relative, source.category, source.metadata.FXName, source.description, info.format.duration, stream.sample_rate, stream.channels, stream.bits_per_sample, actual.size, regions.length, overrides[source.file] ? 'manual_override' : 'catalog', cueEntries.map(([name]) => name).join('; '), source.metadata.Manufacturer, source.metadata.Library, source.metadata.Notes]);
  let previousEnd = 0;
  regions.forEach((region, index) => {
    if (!Number.isFinite(region.start) || !Number.isFinite(region.end) || region.start < previousEnd || region.end <= region.start || region.end > Number(info.format.duration) + 0.0001) throw Error(`Invalid source slice: ${source.file} #${index}`);
    previousEnd = region.end;
    slices.push([source.file, index, region.start, region.end, (region.end - region.start).toFixed(6), source.description, cueEntries.filter(([, cue]) => cue.variants.includes(index)).map(([name]) => name).join('; ')]);
  });
}
const csv = rows => '\uFEFF' + rows.map(row => row.map(value => `"${String(value ?? '').replaceAll('"', '""')}"`).join(',')).join('\r\n') + '\r\n';
writeFileSync(join(destination, 'original-audio-details.csv'), csv(originals), 'utf8');
writeFileSync(join(destination, 'original-audio-slices.csv'), csv(slices), 'utf8');
console.log(`${originals.length - 1} verified source masters; ${slices.length - 1} effective slices. CSV: docs/audio/`);
