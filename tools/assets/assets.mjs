import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const defaultRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const repository = 'https://github.com/iceriny/keyabyss-assets.git';
const profiles = ['runtime', 'library', 'authoring'];
const sha = /^[a-f0-9]{64}$/;
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw new Error(message); };
const json = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const exists = file => fs.existsSync(file);
const git = (repo, ...args) => execFileSync('git', ['-C', repo, ...args], {
  env: { ...process.env, GIT_LFS_SKIP_SMUDGE: '1' }, maxBuffer: 32 * 1024 * 1024,
});

function relative(value) {
  if (typeof value !== 'string' || !value || /[\\:*?"<>|,\[\]\x00-\x1f]/.test(value)
      || value.split('/').some(s => !s || s === '.' || s === '..' || /[. ]$/.test(s)
        || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)/i.test(s))) fail(`Unsafe asset path: ${value}`);
  return value;
}

function destination(value) {
  relative(value);
  if (['.git', '.godot', '.temp', '.delete'].includes(value.split('/')[0])
      || value === 'asset-lock.json' || value.endsWith('.import')) fail(`Reserved destination: ${value}`);
  return value;
}

function checkedPath(root, relativePath) {
  let current = root;
  for (const part of relativePath.split('/')) {
    current = path.join(current, part);
    if (fs.lstatSync(current, { throwIfNoEntry: false })?.isSymbolicLink()) fail(`Symlink asset path: ${current}`);
  }
  return current;
}

function catalogEntries(raw) {
  const catalog = JSON.parse(raw.toString('utf8'));
  if (catalog.schema_version !== 1 || !Array.isArray(catalog.entries)) fail('Invalid catalog schema');
  const ids = new Set(), destinations = new Set();
  for (const entry of catalog.entries) {
    if (!entry || typeof entry !== 'object') fail('Invalid catalog entry');
    relative(entry.id); relative(entry.path); destination(entry.destination);
    if (!Number.isSafeInteger(entry.bytes) || entry.bytes < 0 || !sha.test(entry.sha256)
        || !Array.isArray(entry.profiles) || new Set(entry.profiles).size !== entry.profiles.length
        || entry.profiles.some(p => !profiles.includes(p)) || !entry.profiles.includes('authoring')
        || (entry.profiles.includes('runtime') && !entry.profiles.includes('library'))) fail(`Invalid catalog entry: ${entry.id}`);
    const destKey = entry.destination.toLowerCase();
    if (ids.has(entry.id) || destinations.has(destKey)) fail(`Duplicate catalog path/id: ${entry.id}`);
    ids.add(entry.id); destinations.add(destKey);
  }
  for (const value of destinations) {
    const parts = value.split('/');
    while (parts.length > 1) { parts.pop(); if (destinations.has(parts.join('/'))) fail(`Overlapping destinations: ${value}`); }
  }
  return catalog.entries;
}

function fileInfo(file) {
  if (!exists(file)) return null;
  if (!fs.lstatSync(file).isFile()) fail(`Expected regular file: ${file}`);
  const bytes = fs.readFileSync(file);
  return { bytes: bytes.length, sha256: digest(bytes), pointer: bytes.subarray(0, 80).toString().startsWith('version https://git-lfs.github.com/spec/v1') };
}

function matches(info, entry) { return info && !info.pointer && info.bytes === entry.bytes && info.sha256 === entry.sha256; }

export function lfsIncludes(entries) {
  const batches = []; let current = [] , length = 0;
  for (const source of new Set(entries.map(entry => entry.path))) {
    if (source.length > 12000) fail(`Asset path exceeds the LFS command limit: ${source}`);
    if (length + source.length + 1 > 12000) { batches.push(current.join(',')); current = []; length = 0; }
    current.push(source); length += source.length + 1;
  }
  if (current.length) batches.push(current.join(','));
  return batches;
}

function readState(file) {
  if (!exists(file)) return {};
  const state = json(file);
  if (state.schema_version !== 1 || !state.entries || Array.isArray(state.entries) || typeof state.entries !== 'object') fail('Invalid asset state');
  for (const [dest, entry] of Object.entries(state.entries)) {
    destination(dest);
    if (!entry || !sha.test(entry.sha256) || !Number.isSafeInteger(entry.bytes) || entry.bytes < 0) fail(`Invalid asset state entry: ${dest}`);
  }
  return state.entries;
}

function loadCatalog(root, repo, lock, command) {
  const cache = checkedPath(root, `.temp/assets/catalog-${lock.catalog_sha256}.json`);
  if (!exists(cache) && !exists(repo)) fail('Locked catalog is not cached and the sibling asset repo is missing. Run sync with the requested --profile first.');
  const raw = command !== 'sync' && exists(cache) ? fs.readFileSync(cache) : git(repo, 'show', `${lock.commit}:catalog.json`);
  if (digest(raw) !== lock.catalog_sha256) fail('Locked catalog SHA-256 mismatch');
  const entries = catalogEntries(raw);
  if (command === 'sync') { fs.mkdirSync(path.dirname(cache), { recursive: true }); fs.writeFileSync(cache, raw); }
  return entries;
}

function prepareRepo(root, repo, lock) {
  const fresh = !exists(repo);
  if (fresh) execFileSync('git', ['clone', '--no-checkout', lock.repository, repo], {
    env: { ...process.env, GIT_LFS_SKIP_SMUDGE: '1' }, stdio: 'inherit',
  });
  if (path.resolve(git(repo, 'rev-parse', '--show-toplevel').toString().trim()).toLowerCase() !== repo.toLowerCase()) fail('Asset repo must be its own Git checkout');
  const storage = path.resolve(repo, git(repo, 'rev-parse', '--git-path', 'lfs').toString().trim());
  git(repo, 'config', '--local', 'lfs.storage', storage);
  if (!fresh && git(repo, 'status', '--porcelain').length) fail('Asset repository has uncommitted changes. Commit/push your asset changes, or restore them before sync.');
  git(repo, 'fetch', 'origin', lock.commit);
  const head = git(repo, 'rev-parse', 'HEAD').toString().trim();
  if (fresh || head !== lock.commit || git(repo, 'rev-parse', '--abbrev-ref', 'HEAD').toString().trim() !== 'HEAD') {
    git(repo, 'checkout', '--detach', lock.commit);
  }
}

function install(root, repo, entries, selected, lock, profile) {
  const stateFile = checkedPath(root, '.temp/assets/state.json');
  const stateBefore = fileInfo(stateFile), previous = readState(stateFile), next = Object.assign(Object.create(null), previous), changes = [], observed = [];
  for (const entry of selected) {
    const source = checkedPath(repo, entry.path), target = checkedPath(root, entry.destination);
    if (!matches(fileInfo(source), entry)) fail(`Source integrity mismatch: ${entry.path}`);
    const current = fileInfo(target); observed.push({ dest: entry.destination, before: current });
    if (!matches(current, entry)) {
      if (current && !matches(current, previous[entry.destination] ?? {})) fail(`Local modification: ${entry.destination}. Publish it to the asset repo, or move it aside before sync.`);
      changes.push({ dest: entry.destination, source, target, before: current, entry });
    }
    next[entry.destination] = { bytes: entry.bytes, sha256: entry.sha256 };
  }
  const retained = new Set(entries.map(entry => entry.destination));
  for (const [dest, entry] of Object.entries(previous)) {
    if (retained.has(dest)) continue;
    const target = checkedPath(root, dest), current = fileInfo(target); observed.push({ dest, before: current });
    if (current && !matches(current, entry)) fail(`Local modification of retired asset: ${dest}`);
    if (current) changes.push({ dest, target, before: current });
    delete next[dest];
  }
  const token = randomUUID(), stage = checkedPath(root, `.temp/assets/${token}`);
  const backup = checkedPath(root, `.delete/assets/${token}`);
  fs.mkdirSync(stage, { recursive: true });
  for (const change of changes) {
    if (!change.source) continue;
    change.staged = path.join(stage, 'files', change.dest);
    fs.mkdirSync(path.dirname(change.staged), { recursive: true }); fs.copyFileSync(change.source, change.staged);
    if (!matches(fileInfo(change.staged), change.entry)) fail(`Staged integrity mismatch: ${change.dest}`);
  }
  // Recheck the entire batch before moving any installed file.
  for (const change of observed) {
    const current = fileInfo(checkedPath(root, change.dest));
    if (current?.sha256 !== change.before?.sha256) fail(`Asset changed during staging: ${change.dest}`);
  }
  const stagedState = path.join(stage, 'state.json');
  fs.writeFileSync(stagedState, JSON.stringify({ schema_version: 1, commit: lock.commit, catalog_sha256: lock.catalog_sha256, profile, entries: next }, null, 2) + '\n');
  if (fileInfo(stateFile)?.sha256 !== stateBefore?.sha256) fail('Asset state changed during staging; retry sync');
  const operations = [...changes, { target: stateFile, staged: stagedState, dest: '.state/state.json', before: stateBefore, backup: path.join(backup, 'state.json') }];
  const applied = [];
  try {
    for (const op of operations) {
      op.backup ??= path.join(backup, 'files', op.dest); applied.push(op);
      if (op.before) { fs.mkdirSync(path.dirname(op.backup), { recursive: true }); fs.renameSync(op.target, op.backup); op.moved = true; }
      if (op.staged) { fs.mkdirSync(path.dirname(op.target), { recursive: true }); fs.renameSync(op.staged, op.target); op.installed = true; }
    }
  } catch (error) {
    const rollbackErrors = [];
    for (const op of applied.reverse()) {
      try {
        if (op.installed) { const evidence = path.join(stage, 'rollback', op.dest); fs.mkdirSync(path.dirname(evidence), { recursive: true }); fs.renameSync(op.target, evidence); }
        if (op.moved) fs.renameSync(op.backup, op.target);
      } catch (rollbackError) { rollbackErrors.push(rollbackError); }
    }
    if (rollbackErrors.length) throw new AggregateError([error, ...rollbackErrors], 'Asset installation and rollback failed');
    throw error;
  }
  console.log(`synced ${selected.length} ${profile} assets; ${changes.length} files changed; state: ${stateFile}`);
}

export function run({ command, profile, root = defaultRoot, repo }) {
  if (!['status', 'verify', 'sync'].includes(command) || !profiles.includes(profile)) fail('Usage: node tools/assets/assets.mjs status|verify|sync --profile runtime|library|authoring [--repo absoluteSiblingAssetRepo] [--root gameRoot]');
  root = path.resolve(root);
  if (repo && !path.isAbsolute(repo)) fail('--repo must be absolute');
  repo = repo ?? path.join(path.dirname(root), 'keyabyss-assets'); repo = path.resolve(repo);
  if (path.dirname(repo).toLowerCase() !== path.dirname(root).toLowerCase() || repo.toLowerCase() === root.toLowerCase()) fail('Asset repo must be a sibling of the game root');
  const lock = json(path.join(root, 'asset-lock.json'));
  if (lock.schema_version !== 1 || lock.repository !== repository || !/^[a-f0-9]{40}$/.test(lock.commit) || !sha.test(lock.catalog_sha256)) fail('Invalid asset lock');
  if (command === 'sync') prepareRepo(root, repo, lock);
  const entries = loadCatalog(root, repo, lock, command), selected = entries.filter(entry => entry.profiles.includes(profile));
  if (command === 'sync') {
    for (const include of lfsIncludes(selected)) git(repo, 'lfs', 'pull', `--include=${include}`, '--exclude=');
    install(root, repo, entries, selected, lock, profile); return true;
  }
  let valid = true;
  for (const entry of selected) {
    const info = fileInfo(checkedPath(root, entry.destination));
    if (!matches(info, entry)) { valid = false; console.log(`${!info ? 'missing' : info.pointer ? 'LFS pointer' : 'mismatch'}: ${entry.destination}`); }
  }
  console.log(`${command}: ${selected.length} ${profile} assets, ${valid ? 'complete' : 'incomplete'}`);
  return command === 'status' || valid;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [command, ...args] = process.argv.slice(2), options = { command };
  for (let i = 0; i < args.length; i += 2) {
    if (!['--profile', '--root', '--repo'].includes(args[i]) || !args[i + 1] || args[i + 1].startsWith('--')) fail(`Invalid CLI option: ${args[i]}`);
    if (options[args[i].slice(2)] !== undefined) fail(`Duplicate CLI option: ${args[i]}`);
    options[args[i].slice(2)] = args[i + 1];
  }
  if (!run(options)) process.exitCode = 1;
}
