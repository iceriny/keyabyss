// Explicitly collect development outputs into the authoritative asset repository.
import { readFile, writeFile, mkdir, readdir, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

export const digest = data => createHash('sha256').update(data).digest('hex');
const json = async file => JSON.parse(await readFile(file, 'utf8'));
const exists = async file => { try { return await readFile(file); } catch (e) { if (e.code === 'ENOENT') return null; throw e; } };
export const git = (root, args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }).trim();

async function walk(directory) {
  let children;
  try { children = await readdir(directory, { withFileTypes: true }); }
  catch (e) { if (e.code === 'ENOENT') return []; throw e; }
  const files = [];
  for (const child of children) {
    if (child.isSymbolicLink()) throw new Error(`Asset symlink is not supported: ${child.name}`);
    if (child.isDirectory()) files.push(...await walk(path.join(directory, child.name)));
    else if (child.isFile()) files.push(path.join(directory, child.name));
  }
  return files.sort();
}

export async function capture(root, repo) {
  const config = await json(path.join(root, 'tools/assets/private-paths.json'));
  const previousBytes = await exists(path.join(repo, 'catalog.json'));
  const previous = previousBytes ? JSON.parse(previousBytes) : { schema_version: 1, entries: [] };
  const stateBytes = await exists(path.join(root, '.temp/assets/state.json'));
  const installed = stateBytes ? JSON.parse(stateBytes).entries : {};
  const entries = new Map(previous.entries.map(entry => [entry.destination, entry]));
  const canonical = new Map(previous.entries.map(entry => [entry.sha256, entry.path]));
  const candidates = [...config.files];
  for (const rule of config.rules) {
    const directory = path.join(root, rule.directory);
    for (const file of await walk(directory)) {
      if (rule.extensions && !rule.extensions.includes(path.extname(file).toLowerCase())) continue;
      const suffix = path.relative(directory, file).split(path.sep).join('/');
      candidates.push({ destination: `${rule.directory}/${suffix}`, path: `${rule.prefix}/${suffix}`, profiles: rule.profiles });
    }
  }
  for (const candidate of candidates) {
    const bytes = await exists(path.join(root, candidate.destination));
    if (!bytes) continue; // A runtime-only device does not retire uninstalled source material.
    const hash = digest(bytes);
    let target = canonical.get(hash) ?? candidate.path;
    // An old canonical file can serve several aliases. A changed alias must not
    // replace the bytes still used by the others.
    if (previous.entries.some(entry => entry.path === target && entry.sha256 !== hash)) {
      const extension = path.extname(target);
      target = `${target.slice(0, -extension.length)}-${hash.slice(0, 16)}${extension}`;
    }
    const existingBytes = await exists(path.join(repo, target));
    if (!existingBytes || digest(existingBytes) !== hash) {
      await mkdir(path.dirname(path.join(repo, target)), { recursive: true });
      await copyFile(path.join(root, candidate.destination), path.join(repo, target));
    }
    canonical.set(hash, target);
    entries.set(candidate.destination, { id: candidate.destination, path: target,
      destination: candidate.destination, bytes: bytes.length, sha256: hash, profiles: candidate.profiles });
  }
  for (const destination of Object.keys(installed)) {
    if (entries.has(destination) && !await exists(path.join(root, destination))) entries.delete(destination);
  }
  const catalog = { schema_version: 1, entries: [...entries.values()].sort((a, b) => a.destination.localeCompare(b.destination, 'en')) };
  await writeFile(path.join(repo, 'catalog.json'), JSON.stringify(catalog, null, 2) + '\n');
  return catalog;
}

export async function writeLock(root, repo) {
  const commit = git(repo, ['rev-parse', 'HEAD']);
  const catalog = execFileSync('git', ['-C', repo, 'show', `${commit}:catalog.json`]);
  const lock = { schema_version: 1, repository: 'https://github.com/iceriny/keyabyss-assets.git', commit, catalog_sha256: digest(catalog) };
  await writeFile(path.join(root, 'asset-lock.json'), JSON.stringify(lock, null, 2) + '\n');
  return lock;
}
