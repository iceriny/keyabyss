// Copy selected library clips unchanged and generate native Godot variant pools.
import { readFile, writeFile, mkdir, rename, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const destination = path.join(root, 'assets/audio');
const stateFile = path.join(destination, 'selection.json');
const verify = process.argv[2] === 'verify';
if (process.argv.length > 2 && !verify) throw new Error('Usage: node tools/audio/build-game-audio.mjs [verify]');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = async file => JSON.parse(await readFile(file, 'utf8'));
const existing = async file => {
  try { return await readFile(file); }
  catch (error) { if (error.code === 'ENOENT') return null; throw error; }
};
const previous = JSON.parse((await existing(stateFile)) ?? '{}');
const outputs = {};
let written = 0;

async function archive(relative) {
  const from = path.resolve(destination, relative);
  const to = path.join(root, '.delete/audio-selection', `${Date.now()}-${written}`, relative);
  if (!from.startsWith(destination + path.sep) || !to.startsWith(path.join(root, '.delete') + path.sep))
    throw new Error(`Archive outside workspace: ${relative}`);
  await mkdir(path.dirname(to), { recursive: true });
  await rename(from, to);
}

async function emit(relative, bytes) {
  const digest = hash(bytes);
  outputs[relative] = digest;
  const file = path.join(destination, relative);
  const current = await existing(file);
  if (current && hash(current) === digest) return;
  if (verify) throw new Error(`Missing or different game audio: ${relative}`);
  if (current) {
    if (hash(current) !== previous[relative]) throw new Error(`Locally modified game audio: ${relative}`);
    await archive(relative);
  }
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, bytes, { flag: 'wx' });
  written++;
}

const cues = await json(path.join(root, 'audio/cues.json'));
const index = await json(path.join(root, 'development/audio_library/index.json'));
const libraryHashes = await json(path.join(root, 'development/audio_library/.build.json'));
const selected = new Map();
for (const [cue, group] of Object.entries(cues)) {
  if (!/^[a-zA-Z][a-zA-Z0-9.]*$/.test(cue)) throw new Error(`Invalid cue: ${cue}`);
  const variants = index.filter(row => row.variant_group === group);
  if (variants.length < 2) throw new Error(`Cue needs distinct variants: ${cue} / ${group}`);
  for (const row of variants) selected.set(row.file, row);
  const external = variants.map((row, i) => `[ext_resource type="AudioStream" path="res://assets/audio/clips/${path.basename(row.file)}" id="${i + 1}"]`);
  const pool = variants.map((_, i) => `stream_${i}/stream = ExtResource("${i + 1}")\nstream_${i}/weight = 1.0`);
  await emit(`cues/${cue}.tres`, Buffer.from([
    `[gd_resource type="AudioStreamRandomizer" load_steps=${variants.length + 1} format=3]`, '',
    ...external, '', '[resource]', `resource_name = "${cue}"`,
    'playback_mode = 0', 'random_pitch = 1.0', 'random_volume_offset_db = 0.0',
    `streams_count = ${variants.length}`, ...pool, '',
  ].join('\n')));
}
for (const row of selected.values()) {
  const name = path.basename(row.file);
  const bytes = await readFile(path.join(root, row.file));
  if (hash(bytes) !== libraryHashes[name]) throw new Error(`Modified library clip: ${row.file}`);
  await emit(`clips/${name}`, bytes);
  const importFile = path.join(destination, `clips/${name}.import`);
  // Godot owns the rest of this sidecar. Keep the source PCM unchanged; bound runtime sample cost.
  const sidecar = await existing(importFile);
  const params = { 'force/max_rate': 'true', 'force/max_rate_hz': '48000', 'edit/trim': 'true',
    'edit/normalize': 'false', 'edit/loop_mode': '0', 'compress/mode': '2' };
  let imported = sidecar?.toString() ?? '[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n';
  for (const [key, value] of Object.entries(params)) {
    const pattern = new RegExp(`^${key}=.*$`, 'm');
    if (verify && !imported.includes(`${key}=${value}\n`)) throw new Error(`Incorrect Godot import setting: ${name} / ${key}`);
    imported = pattern.test(imported) ? imported.replace(pattern, `${key}=${value}`) : imported + `${key}=${value}\n`;
  }
  if (!verify && imported !== sidecar?.toString()) await writeFile(importFile, imported);
}
for (const relative of Object.keys(previous)) {
  if (Object.hasOwn(outputs, relative)) continue;
  const file = await existing(path.join(destination, relative));
  if (!file) continue;
  if (verify) throw new Error(`Obsolete selected audio: ${relative}`);
  if (hash(file) !== previous[relative]) throw new Error(`Locally modified obsolete audio: ${relative}`);
  await archive(relative);
  if (await existing(path.join(destination, relative + '.import'))) await archive(relative + '.import');
}
for (const folder of ['clips', 'cues']) {
  for (const name of await readdir(path.join(destination, folder))) {
    if (!/\.(wav|tres)$/.test(name)) continue;
    if (!Object.hasOwn(outputs, `${folder}/${name}`)) throw new Error(`Unmanaged game audio: ${folder}/${name}`);
  }
}
const state = JSON.stringify(outputs, null, 2) + '\n';
if (verify) {
  if (await readFile(stateFile, 'utf8') !== state) throw new Error('Selection state does not match cues and library.');
} else if ((await existing(stateFile))?.toString() !== state) await writeFile(stateFile, state);
console.log(`${verify ? 'Verified' : 'Built'} ${Object.keys(cues).length} cues / ${selected.size} unchanged WAV clips; ${written} files written.`);
