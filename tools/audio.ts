/** FFmpeg-backed source indexing and allowlisted lossless audio builds. Node >= 22.18. */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import os from 'node:os';
import { soundCues } from '../src/content/sound-cues.ts';

const root = fileURLToPath(new URL('../', import.meta.url));
const pack = path.join(root, 'art/Magic UI Designed');
const catalogPath = path.join(root, 'data/audio-catalog.json');
const overridesPath = path.join(root, 'data/audio-overrides.json');
const output = path.join(root, 'public/audio');
type Region = { start: number; end: number };
type Source = { file: string; bytes: number; mtime: number; rate: number; channels: number; duration: number; description: string; category: string; metadata: Record<string,string>; regions: Region[]; peaks: number[] };
type Catalog = { version: number; detector: { threshold: number; gap: number; lead: number; tail: number }; sources: Source[] };
const detector = { threshold: -60, gap: .6, lead: .015, tail: .12 };
const hash = (value: string | Buffer) => createHash('sha256').update(value).digest('hex').slice(0, 16);
function run(command: string, args: string[]): Promise<{ out: Buffer; err: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { windowsHide: true });
    const chunks: Buffer[] = []; let err = '';
    child.stdout.on('data', b => chunks.push(b)); child.stderr.on('data', b => err += b);
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve({ out: Buffer.concat(chunks), err }) : reject(Error(`${command}: ${err.slice(-2000)}`)));
  });
}
async function json<T>(file: string): Promise<T> { return JSON.parse(await fs.readFile(file, 'utf8')); }
async function writeJSON(file: string, data: unknown) { await fs.mkdir(path.dirname(file), { recursive: true }); await fs.writeFile(file, JSON.stringify(data, null, 2) + '\n'); }
async function pool<T>(items: T[], action: (item: T) => Promise<void>) {
  let next = 0;
  await Promise.all(Array.from({ length: 4 }, async () => { while (next < items.length) await action(items[next++]); }));
}
export function regionsFromSilence(log: string, duration: number, options = detector): Region[] {
  const silent: Region[] = []; let start = 0;
  for (const match of log.matchAll(/silence_(start|end): ([\d.]+)/g)) {
    if (match[1] === 'start') start = Number(match[2]);
    else silent.push({ start, end: Number(match[2]) });
  }
  const regions: Region[] = []; let cursor = 0;
  for (const silence of [...silent, { start: duration, end: duration }]) {
    if (silence.start - cursor > .025) regions.push({ start: Math.max(0, cursor - options.lead), end: Math.min(duration, silence.start + options.tail) });
    cursor = silence.end;
  }
  return regions;
}
export function validateRegions(regions: Region[], duration: number) {
  if (!regions.length) throw Error('No audible regions found');
  let previous = 0;
  for (const region of regions) {
    if (!Number.isFinite(region.start) || !Number.isFinite(region.end) || region.start < previous || region.end <= region.start || region.end > duration + .0001) throw Error('Invalid or overlapping audio regions');
    previous = region.end;
  }
}
async function overrides(): Promise<Record<string, Region[]>> {
  try { return await json(overridesPath); } catch (e) { if ((e as NodeJS.ErrnoException).code === 'ENOENT') return {}; throw e; }
}
async function scan() {
  const metadata = JSON.parse((await run(process.env.PYTHON || 'python', ['-X', 'utf8', path.join(root, 'tools/audio-metadata.py'), path.join(pack, '00_Magic_UI_DS_Metadata.xlsx')])).out.toString('utf8'));
  const sources: Source[] = []; const files = (await fs.readdir(pack)).filter(f => f.endsWith('.wav')).sort();
  await pool(files, async file => {
    const source = path.join(pack, file); const stat = await fs.stat(source);
    const probe = JSON.parse((await run('ffprobe', ['-v','error','-select_streams','a:0','-show_entries','stream=sample_rate,channels:format=duration','-of','json',source])).out.toString());
    // Detector works on the original stereo signal; downsampling is only for the editor overview.
    const analysis = await run('ffmpeg', ['-hide_banner','-i',source,'-map','0:a:0','-af',`silencedetect=noise=${detector.threshold}dB:d=${detector.gap}`,'-ac','1','-ar','8000','-f','f32le','pipe:1']);
    const duration = Number(probe.format.duration); const regions = regionsFromSilence(analysis.err, duration); validateRegions(regions, duration);
    const peaks = Array(640).fill(0); const samples = analysis.out.length / 4;
    for (let i=0; i<samples; i++) { const bin = Math.min(639, Math.floor(i / samples * 640)); peaks[bin] = Math.max(peaks[bin], Math.abs(analysis.out.readFloatLE(i*4))); }
    // Vendor supplied Next as a/b files, while the workbook describes their shared name.
    const entry = metadata[file] ?? metadata[file.replace(/MUIDS[ab]\.wav$/, 'MUIDS.wav')];
    if (!entry) throw Error(`Missing workbook description: ${file}`);
    sources.push({ file, bytes: stat.size, mtime: stat.mtimeMs, rate: Number(probe.streams[0].sample_rate), channels: probe.streams[0].channels, duration, description: entry.Description, category: entry.VendorCategory, metadata: entry, regions, peaks: peaks.map(n=>Math.round(n*10000)/10000) });
  });
  sources.sort((a,b)=>a.file.localeCompare(b.file));
  await writeJSON(catalogPath, { version: 1, detector, sources });
  console.log(`Indexed ${sources.length} sources / ${sources.reduce((n,s)=>n+s.regions.length,0)} variants. Originals untouched.`);
}
async function loadCatalog() {
  const catalog = await json<Catalog>(catalogPath); const edits = await overrides();
  for (const source of catalog.sources) { source.regions = edits[source.file] ?? source.regions; validateRegions(source.regions, source.duration); }
  for (const file of Object.keys(edits)) if (!catalog.sources.some(s=>s.file===file)) throw Error(`Unknown override source: ${file}`);
  return catalog;
}
/** Normalize vendor BWF/container metadata for reliable browser seeking; originals stay untouched. */
export async function previewAudio(file: string) {
  const catalog = await loadCatalog();
  if (!catalog.sources.some(s=>s.file===file)) throw Error('Unknown audio source');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(),'keyabyss-audio-'));
  const target = path.join(directory,'preview.flac');
  try {
    await run('ffmpeg',['-v','error','-i',path.join(pack,file),'-map','0:a:0','-map_metadata','-1','-ar','48000','-c:a','flac',target]);
    return await fs.readFile(target);
  } finally { await fs.unlink(target).catch(()=>{}); await fs.rmdir(directory); }
}
async function build() {
  const catalog = await loadCatalog(); const sources = new Map(catalog.sources.map(s=>[s.file,s]));
  const clips: Record<string, { id: string; url: string; duration: number; bytes: number }[]> = {};
  const jobs = new Map<string, { source: Source; region: Region; channels: number; duration: number }>();
  for (const [cue, definition] of Object.entries(soundCues)) {
    const source = sources.get(definition.source); if (!source) throw Error(`Missing cue source: ${definition.source}`);
    const stat = await fs.stat(path.join(pack, source.file));
    if (source.bytes !== stat.size || source.mtime !== stat.mtimeMs) throw Error(`Source changed; run npm run audio:scan: ${source.file}`);
    clips[cue] = definition.variants!.map(index => {
      const region = source.regions[index]; if (!region) throw Error(`${cue}: missing variant ${index}; inspect audio catalog`);
      const channels = definition.spatial ? 1 : 2;
      const id = 'clip-' + hash(JSON.stringify([source.file, source.bytes, source.mtime, region, channels, 'flac-48k-s24-fade3ms-v1']));
      const duration = region.end - region.start;
      jobs.set(id, { source, region, channels, duration });
      return { id, url: `./audio/${id}.js`, duration, bytes: 0 };
    });
  }
  await fs.mkdir(output, { recursive: true });
  await pool([...jobs], async ([id, job]) => {
    const target = path.join(output, id + '.js');
    try { await fs.access(target); return; } catch {}
    const result = await run('ffmpeg', ['-v','error','-i',path.join(pack, job.source.file),'-map','0:a:0','-af',`atrim=start=${job.region.start}:end=${job.region.end},asetpts=PTS-STARTPTS,afade=t=in:d=0.003,afade=t=out:st=${Math.max(0,job.duration-.005)}:d=0.005`,'-ar','48000','-ac',String(job.channels),'-sample_fmt','s32','-c:a','flac','-compression_level','8','-f','flac','pipe:1']);
    // Deferred classic script is also usable from file://, unlike fetch of local audio files.
    await fs.writeFile(target, `globalThis.KA_AUDIO??={};globalThis.KA_AUDIO[${JSON.stringify(id)}]=${JSON.stringify(result.out.toString('base64'))};\n`);
  });
  for (const file of await fs.readdir(output)) if (/^clip-[a-f0-9]{16}\.js$/.test(file) && !jobs.has(file.slice(0,-3))) await fs.unlink(path.join(output,file));
  for (const file of await fs.readdir(output)) if (!jobs.has(file.slice(0,-3)) || !file.endsWith('.js')) throw Error(`Unlisted audio asset in public/audio: ${file}`);
  for (const list of Object.values(clips)) for (const clip of list) clip.bytes = (await fs.stat(path.join(output, clip.id+'.js'))).size;
  await fs.mkdir(path.join(root,'src/generated'), { recursive: true });
  await fs.writeFile(path.join(root,'src/generated/audio-manifest.ts'), `// Generated by npm run audio:build. Do not edit.\nimport type { AudioClip } from '../contracts/audio.ts';\nexport const audioManifest: Record<string, readonly AudioClip[]> = ${JSON.stringify(clips)};\n`);
  const bytes = (await Promise.all([...jobs.keys()].map(async id=>(await fs.stat(path.join(output,id+'.js'))).size))).reduce((a,b)=>a+b,0);
  await writeJSON(path.join(root,'data/audio-build.json'), { cues: Object.keys(clips).length, sources: new Set([...jobs.values()].map(j=>j.source.file)).size, clips: jobs.size, bytes, sampleRate: 48000, codec:'FLAC', spatialChannels:1, uiChannels:2 });
  console.log(`Audio allowlist: ${Object.keys(clips).length} cues / ${jobs.size} clips / ${(bytes/1048576).toFixed(2)} MB.`);
}
async function main() {
  const [command, query, indexText, destination] = process.argv.slice(2);
  if (command === 'scan') return scan();
  if (command === 'build') return build();
  const catalog = await loadCatalog();
  if (command === 'query') { console.log(JSON.stringify(catalog.sources.filter(s=>`${s.file} ${s.description} ${s.category}`.toLowerCase().includes((query||'').toLowerCase())).map(({ peaks, metadata, ...s })=>s),null,2)); return; }
  if (command === 'export') {
    const source = catalog.sources.find(s=>s.file===query); const region = source?.regions[Number(indexText)];
    if (!source || !region || !destination) throw Error('Usage: export "exact filename.wav" zero-based-index output.wav');
    const target = path.resolve(destination);
    if (target.startsWith(pack + path.sep)) throw Error('Export outside the original pack');
    await run('ffmpeg', ['-v','error','-n','-i',path.join(pack,source.file),'-map','0:a:0','-af',`atrim=start=${region.start}:end=${region.end},asetpts=PTS-STARTPTS`,'-c:a','pcm_s24le',target]);
    console.log(target); return;
  }
  throw Error('Usage: node tools/audio.ts scan | build | query [text] | export filename index output.wav');
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(e=>{ console.error(e.message); process.exitCode=1; });
