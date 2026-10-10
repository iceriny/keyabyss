// Source WAV -> sample-aligned clips and a four-column Agent catalog. Node >= 22.
import { readFile, writeFile, mkdir, readdir, copyFile, rename } from 'node:fs/promises';
import { constants } from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';

const root = path.resolve(import.meta.dirname, '../..');
const library = path.join(root, 'development/audio_library');
const recipePath = path.join(library, 'segments.json');
const clipsPath = path.join(library, 'clips');
const statePath = path.join(library, '.build.json');
const sha256 = data => createHash('sha256').update(data).digest('hex');
const relative = file => path.relative(root, file).split(path.sep).join('/');
const json = async file => JSON.parse(await readFile(file, 'utf8'));
const saveJSON = (file, data) => writeFile(file, JSON.stringify(data, null, 2) + '\n');

function workspacePath(value) {
  const resolved = path.resolve(root, value);
  if (!resolved.startsWith(root + path.sep)) throw new Error(`Path outside workspace: ${value}`);
  return resolved;
}

// BWF metadata is not audio. Preserve fmt and the selected PCM bytes, omitting
// unrelated RIFF chunks from the generated WAV. Stereo boundaries are frames.
function readWav(buffer, label) {
  if (buffer.toString('ascii', 0, 4) !== 'RIFF' || buffer.toString('ascii', 8, 12) !== 'WAVE')
    throw new Error(`Not a RIFF WAV: ${label}`);
  let format, data;
  for (let offset = 12; offset + 8 <= buffer.length;) {
    const id = buffer.toString('ascii', offset, offset + 4);
    const length = buffer.readUInt32LE(offset + 4);
    const start = offset + 8;
    if (start + length > buffer.length) throw new Error(`Truncated WAV chunk: ${label}`);
    if (id === 'fmt ') format = buffer.subarray(start, start + length);
    if (id === 'data') data = buffer.subarray(start, start + length);
    offset = start + length + (length & 1);
  }
  if (!format || format.length < 16 || !data || format.readUInt16LE(0) !== 1)
    throw new Error(`Expected PCM WAV: ${label}`);
  const channels = format.readUInt16LE(2);
  const rate = format.readUInt32LE(4);
  const block = format.readUInt16LE(12);
  const bits = format.readUInt16LE(14);
  if (![1, 2].includes(channels) || ![8, 16, 24, 32].includes(bits) || rate === 0
    || block !== channels * bits / 8 || data.length % block !== 0)
    throw new Error(`Unsupported PCM layout: ${label}`);
  return { format, data, channels, rate, block, bits, frames: data.length / block };
}

function sliceWav(wav, segment) {
  const data = wav.data.subarray(segment.start_frame * wav.block, segment.end_frame * wav.block);
  const size = 12 + 8 + wav.format.length + (wav.format.length & 1) + 8 + data.length + (data.length & 1);
  const output = Buffer.alloc(size);
  output.write('RIFF', 0); output.writeUInt32LE(size - 8, 4); output.write('WAVE', 8);
  output.write('fmt ', 12); output.writeUInt32LE(wav.format.length, 16); wav.format.copy(output, 20);
  const offset = 20 + wav.format.length + (wav.format.length & 1);
  output.write('data', offset); output.writeUInt32LE(data.length, offset + 4); data.copy(output, offset + 8);
  return output;
}

async function migrate() {
  const catalog = await json(path.join(root, 'legacy/web/data/audio-catalog.json'));
  const overrides = await json(path.join(root, 'legacy/web/data/audio-overrides.json'));
  const sources = [];
  const groups = new Set();
  for (const source of catalog.sources) {
    const suffix = source.file.match(/MUIDS([ab])\.wav$/)?.[1];
    const group = source.file.split('_').slice(1, -2).join('-').toLowerCase()
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') + (suffix ? `-${suffix}` : '');
    if (!group || groups.has(group)) throw new Error(`Duplicate variant group: ${source.file}`);
    groups.add(group);
    const file = `legacy/web/art/Magic UI Designed/${source.file}`;
    const buffer = await readFile(workspacePath(file));
    const wav = readWav(buffer, file);
    const segments = (overrides[source.file] ?? source.regions).map((region, index) => ({
      id: String(index + 1).padStart(2, '0'),
      start_frame: Math.round(region.start * wav.rate),
      end_frame: Math.round(region.end * wav.rate),
    }));
    sources.push({ file, sha256: sha256(buffer), group, description: source.description,
      boundary_source: overrides[source.file] ? 'manual' : 'detected', segments });
  }
  for (const file of Object.keys(overrides))
    if (!catalog.sources.some(source => source.file === file)) throw new Error(`Unknown manual source: ${file}`);
  await mkdir(library, { recursive: true });
  // Migration is one-time: later edits belong to the standalone recipe.
  await writeFile(recipePath, JSON.stringify({ version: 1, sources }, null, 2) + '\n', { flag: 'wx' });
  console.log(`Migrated ${sources.length} sources / ${sources.reduce((sum, source) => sum + source.segments.length, 0)} slices.`);
}

async function loadRecipe() {
  const recipe = await json(recipePath);
  if (recipe.version !== 1 || !Array.isArray(recipe.sources)) throw new Error('Invalid audio recipe.');
  const names = new Set();
  for (const source of recipe.sources) {
    workspacePath(source.file);
    if (!/^[a-z0-9-]+$/.test(source.group) || !source.description?.trim()
      || !/^[a-f0-9]{64}$/.test(source.sha256) || !source.segments?.length)
      throw new Error(`Invalid source definition: ${source.file}`);
    let previousEnd = 0;
    for (const segment of source.segments) {
      const name = `${source.group}-${segment.id}.wav`;
      if (!/^[a-z0-9-]+$/.test(segment.id) || names.has(name)
        || !Number.isSafeInteger(segment.start_frame) || !Number.isSafeInteger(segment.end_frame)
        || segment.start_frame < previousEnd || segment.end_frame <= segment.start_frame)
        throw new Error(`Invalid slice: ${name}`);
      names.add(name); previousEnd = segment.end_frame;
    }
  }
  return recipe;
}

async function existing(file) {
  try { return await readFile(file); }
  catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}

async function archive(file) {
  const destination = workspacePath(`.delete/audio-library/${Date.now()}-${randomUUID()}/${path.basename(file)}`);
  await mkdir(path.dirname(destination), { recursive: true });
  await rename(file, destination);
}

function csv(rows) {
  return rows.map(row => row.map(value => `"${String(value).replaceAll('"', '""')}"`).join(',')).join('\n') + '\n';
}

async function processLibrary(verify) {
  const recipe = await loadRecipe();
  const previous = (await existing(statePath)) ? await json(statePath) : {};
  const outputs = {}, rows = [];
  let written = 0, totalBytes = 0;
  if (!verify) await mkdir(clipsPath, { recursive: true });
  for (const source of recipe.sources) {
    const original = await readFile(workspacePath(source.file));
    if (sha256(original) !== source.sha256) throw new Error(`Source changed: ${source.file}`);
    const wav = readWav(original, source.file);
    for (const segment of source.segments) {
      if (segment.end_frame > wav.frames) throw new Error(`Slice exceeds source: ${source.group}-${segment.id}`);
      const name = `${source.group}-${segment.id}.wav`;
      const file = path.join(clipsPath, name);
      const output = sliceWav(wav, segment);
      const hash = sha256(output);
      const current = await existing(file);
      if (!current || sha256(current) !== hash) {
        if (verify) throw new Error(`Missing or different clip: ${relative(file)}`);
        if (current) {
          if (sha256(current) !== previous[name]) throw new Error(`Locally modified clip: ${relative(file)}`);
          await archive(file);
        }
        await writeFile(file, output, { flag: 'wx' }); written++;
      }
      outputs[name] = hash; totalBytes += output.length;
      rows.push({ file: relative(file), description: source.description,
        duration_seconds: Number(((segment.end_frame - segment.start_frame) / wav.rate).toFixed(6)),
        variant_group: source.group });
    }
  }
  const obsolete = (await readdir(clipsPath)).filter(name => name.endsWith('.wav') && !Object.hasOwn(outputs, name));
  for (const name of obsolete) {
    if (verify) throw new Error(`Unlisted clip: ${name}`);
    const file = path.join(clipsPath, name);
    if (sha256(await readFile(file)) !== previous[name]) throw new Error(`Unmanaged clip: ${relative(file)}`);
    await archive(file);
  }
  const index = JSON.stringify(rows, null, 2) + '\n';
  const table = csv([['file', 'description', 'duration_seconds', 'variant_group'],
    ...rows.map(row => [row.file, row.description, row.duration_seconds, row.variant_group])]);
  if (verify) {
    if (await readFile(path.join(library, 'index.json'), 'utf8') !== index
      || await readFile(path.join(library, 'index.csv'), 'utf8') !== table)
      throw new Error('Audio mapping does not match the slice recipe.');
  } else {
    await writeFile(path.join(library, 'index.json'), index);
    await writeFile(path.join(library, 'index.csv'), table);
    await saveJSON(statePath, outputs);
  }
  console.log(`${verify ? 'Verified' : 'Built'} ${recipe.sources.length} originals / ${rows.length} clips / ${(totalBytes / 1048576).toFixed(2)} MiB${verify ? '' : `; ${written} WAV written`}.`);
}

async function main() {
  const [command, query = '', destination] = process.argv.slice(2);
  if (command === 'migrate') return migrate();
  if (command === 'build') return processLibrary(false);
  if (command === 'verify') return processLibrary(true);
  const index = await json(path.join(library, 'index.json'));
  if (command === 'query') {
    const search = query.toLowerCase();
    console.log(JSON.stringify(index.filter(row => `${row.description} ${row.variant_group} ${row.file}`.toLowerCase().includes(search)), null, 2));
    return;
  }
  if (command === 'export') {
    const selected = index.find(row => row.file === query || path.basename(row.file) === query);
    if (!selected || !destination) throw new Error('Usage: export exact-clip-filename.wav assets/audio/target.wav');
    const target = workspacePath(destination);
    const expected = (await json(statePath))[path.basename(selected.file)];
    const clip = workspacePath(selected.file);
    if (sha256(await readFile(clip)) !== expected) throw new Error(`Modified clip: ${selected.file}`);
    await mkdir(path.dirname(target), { recursive: true });
    await copyFile(clip, target, constants.COPYFILE_EXCL);
    console.log(relative(target));
    return;
  }
  throw new Error('Usage: node tools/audio/library.mjs migrate | build | verify | query [text] | export clip.wav destination.wav');
}

main().catch(error => { console.error(error.stack); process.exitCode = 1; });
