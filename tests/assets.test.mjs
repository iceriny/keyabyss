import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import mutableFs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { syncBuiltinESMExports } from 'node:module';
import { run, lfsIncludes } from '../tools/assets/assets.mjs';

const workspace = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const cli = path.join(workspace, 'tools/assets/assets.mjs');
const evidence = path.join(workspace, '.delete', 'assets-tests', randomUUID());
const hash = value => createHash('sha256').update(value).digest('hex');
const write = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, value); };
const read = file => fs.readFileSync(file, 'utf8');
const parse = file => JSON.parse(read(file));
const git = (repo, ...args) => execFileSync('git', ['-C', repo, ...args], { stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, GIT_LFS_SKIP_SMUDGE: '1' } }).toString().trim();

function fixture(name) {
  const base = path.join(evidence, name), root = path.join(base, 'game'), repo = path.join(base, 'keyabyss-assets'), remote = path.join(base, 'remote.git');
  fs.mkdirSync(root, { recursive: true }); fs.mkdirSync(repo);
  git(base, 'init', '--bare', remote); git(repo, 'init', '-b', 'main');
  git(remote, 'config', 'lfs.storage', path.join(remote, 'lfs'));
  git(repo, 'config', 'user.email', 'assets-test@example.invalid'); git(repo, 'config', 'user.name', 'Assets Test');
  git(repo, 'config', 'core.autocrlf', 'false'); git(repo, 'lfs', 'install', '--local');
  git(repo, 'remote', 'add', 'origin', remote);
  write(path.join(repo, '.gitattributes'), '*.bin filter=lfs diff=lfs merge=lfs -text\n');
  const stateFile = path.join(root, '.temp/assets/state.json');
  let revision = 0;
  const entries = specs => specs.map(([name, content, profiles]) => ({ id: `assets/${name}.bin`, path: `payload/${name}.bin`, destination: `assets/${name}.bin`, bytes: Buffer.byteLength(content), sha256: hash(content), profiles }));
  function publish(specs, transform = value => value) {
    for (const [name, content] of specs) write(path.join(repo, `payload/${name}.bin`), content);
    const catalog = { schema_version: 1, entries: transform(entries(specs)) };
    write(path.join(repo, 'catalog.json'), JSON.stringify(catalog) + '\n');
    git(repo, 'add', '.'); git(repo, 'commit', '-m', `revision ${++revision}`); git(repo, 'push', 'origin', 'HEAD:refs/heads/main');
    git(remote, 'symbolic-ref', 'HEAD', 'refs/heads/main');
    const commit = git(repo, 'rev-parse', 'HEAD');
    const lock = { schema_version: 1, repository: 'https://github.com/iceriny/keyabyss-assets.git', commit, catalog_sha256: hash(fs.readFileSync(path.join(repo, 'catalog.json'))) };
    write(path.join(root, 'asset-lock.json'), JSON.stringify(lock));
    return lock;
  }
  const invoke = (command, profile = 'runtime') => run({ command, profile, root, repo });
  return { root, repo, remote, stateFile, publish, entries, invoke, asset: name => path.join(root, `assets/${name}.bin`) };
}

const runtime = ['runtime', 'library', 'authoring'], library = ['library', 'authoring'], authoring = ['authoring'];

test('large authoring catalogs use bounded, exact, deduplicated LFS include batches', () => {
  const unique = Array.from({ length: 763 }, (_, index) => `library/audio/raw/long-descriptive-source-name-${String(index).padStart(4, '0')}-multiple-variations-original-recording.wav`);
  const paths = [...unique, ...unique.slice(0, 207)], batches = lfsIncludes(paths.map(source => ({ path: source })));
  assert.ok(paths.join(',').length > 32767); assert.ok(batches.length > 1);
  assert.deepEqual(batches.flatMap(batch => batch.split(',')), unique);
  assert.ok(batches.every(batch => batch.length <= 12000 && !batch.includes('*')));
  console.log(`LFS include batching: ${paths.length} entries, ${unique.length} unique paths, ${paths.join(',').length} original characters, ${batches.length} batches, max ${Math.max(...batches.map(batch => batch.length))} characters`);
});

test('profile upgrades preserve all managed entries; downgrades retain files; verify works offline', () => {
  const f = fixture('profiles');
  f.publish([['run', 'runtime v1', runtime], ['lib', 'library v1', library], ['raw', 'authoring v1', authoring]]);
  f.invoke('sync');
  assert.equal(read(f.asset('run')), 'runtime v1');
  assert.equal(fs.existsSync(f.asset('lib')), false);
  assert.equal(f.invoke('status', 'library'), true);
  assert.equal(f.invoke('verify', 'library'), false);
  f.invoke('sync', 'library'); f.invoke('sync', 'authoring');
  assert.equal(Object.keys(parse(f.stateFile).entries).length, 3);
  f.invoke('sync');
  assert.equal(Object.keys(parse(f.stateFile).entries).length, 3);
  assert.equal(read(f.asset('lib')), 'library v1'); assert.equal(read(f.asset('raw')), 'authoring v1');
  const repoAside = path.join(path.dirname(f.repo), 'repo-offline'); fs.renameSync(f.repo, repoAside);
  assert.equal(f.invoke('verify', 'authoring'), true);
  const before = fs.statSync(f.stateFile).mtimeMs;
  assert.equal(f.invoke('status'), true); assert.equal(fs.statSync(f.stateFile).mtimeMs, before);
  write(f.asset('run'), 'version https://git-lfs.github.com/spec/v1\noid sha256:' + '0'.repeat(64) + '\nsize 1\n');
  const result = spawnSync(process.execPath, [cli, 'verify', '--profile', 'runtime', '--root', f.root, '--repo', f.repo], { encoding: 'utf8' });
  assert.equal(result.status, 1); assert.match(result.stdout, /LFS pointer/);
});

test('local edits reject the entire batch, successful updates retire files to .delete and commit complete state', () => {
  const f = fixture('transaction');
  f.publish([['one', 'one v1', runtime], ['two', 'two v1', runtime], ['lib', 'lib v1', library]]);
  f.invoke('sync', 'library'); const before = read(f.stateFile);
  f.publish([['one', 'one v2', runtime], ['two', 'two v2', runtime], ['lib', 'lib v1', library]]);
  write(f.asset('two'), 'my local edit');
  assert.throws(() => f.invoke('sync'), /Local modification: assets\/two/);
  assert.equal(read(f.asset('one')), 'one v1'); assert.equal(read(f.stateFile), before);
  write(f.asset('two'), 'two v1'); f.invoke('sync');
  let state = parse(f.stateFile);
  assert.equal(Object.keys(state.entries).length, 3);
  assert.equal(state.entries['assets/one.bin'].sha256, hash('one v2'));
  assert.equal(state.entries['assets/lib.bin'].sha256, hash('lib v1'));
  const deletionRoot = path.join(f.root, '.delete/assets');
  assert.ok(fs.readdirSync(deletionRoot).some(token => fs.existsSync(path.join(deletionRoot, token, 'files/assets/one.bin'))));
  f.publish([['one', 'one v3', runtime], ['two', 'two v3', runtime]]);
  write(f.asset('lib'), 'local library edit');
  const previousState = read(f.stateFile);
  assert.throws(() => f.invoke('sync'), /Local modification of retired asset/);
  assert.equal(read(f.asset('one')), 'one v2'); assert.equal(read(f.stateFile), previousState);
  write(f.asset('lib'), 'lib v1'); f.invoke('sync');
  state = parse(f.stateFile); assert.equal(Object.keys(state.entries).length, 2); assert.equal(fs.existsSync(f.asset('lib')), false);
  assert.equal(f.invoke('verify'), true);
});

test('existing identical files can be adopted; dirty asset checkout and source checksum mismatch are explicit failures', () => {
  const f = fixture('source'); f.publish([['run', 'payload', runtime]]);
  write(f.asset('run'), 'payload'); f.invoke('sync'); assert.equal(parse(f.stateFile).entries['assets/run.bin'].sha256, hash('payload'));
  write(path.join(f.repo, 'payload/run.bin'), 'uncommitted source');
  assert.throws(() => f.invoke('sync'), /uncommitted changes/);
  assert.equal(f.invoke('status'), true);
  write(path.join(f.repo, 'payload/run.bin'), 'payload');
  f.publish([['run', 'new payload', runtime]], entries => entries.map(entry => ({ ...entry, sha256: '0'.repeat(64) })));
  const before = read(f.stateFile);
  assert.throws(() => f.invoke('sync'), /Source integrity mismatch/);
  assert.equal(read(f.asset('run')), 'payload'); assert.equal(read(f.stateFile), before);
});

test('catalog trust boundary rejects hash, schema, paths, profile nesting and duplicate destinations', () => {
  const f = fixture('validation'), lock = f.publish([['run', 'payload', runtime]]);
  const goodEntry = f.entries([['run', 'payload', runtime]])[0];
  const cache = raw => {
    const bytes = Buffer.from(JSON.stringify(raw)), checksum = hash(bytes);
    write(path.join(f.root, `.temp/assets/catalog-${checksum}.json`), bytes);
    write(path.join(f.root, 'asset-lock.json'), JSON.stringify({ ...lock, catalog_sha256: checksum }));
  };
  const invalid = [
    { schema_version: 2, entries: [] },
    { schema_version: 1, entries: [{ ...goodEntry, path: '../escape.bin' }] },
    { schema_version: 1, entries: [{ ...goodEntry, destination: 'C:/escape.bin' }] },
    { schema_version: 1, entries: [{ ...goodEntry, destination: '.temp/state.json' }] },
    { schema_version: 1, entries: [{ ...goodEntry, profiles: ['runtime', 'authoring'] }] },
    { schema_version: 1, entries: [{ ...goodEntry, bytes: '7' }] },
    { schema_version: 1, entries: [goodEntry, { ...goodEntry, id: 'other', destination: 'ASSETS/RUN.BIN' }] },
    { schema_version: 1, entries: [goodEntry, { ...goodEntry, id: 'other', destination: 'assets/run.bin/nested.bin' }] },
  ];
  for (const catalog of invalid) { cache(catalog); assert.throws(() => f.invoke('status'), /Invalid|Unsafe|Reserved|Duplicate|Overlapping/); }
  write(path.join(f.root, 'asset-lock.json'), JSON.stringify({ ...lock, catalog_sha256: '0'.repeat(64) }));
  assert.throws(() => f.invoke('verify'), /catalog SHA-256 mismatch/);
  write(path.join(f.root, 'asset-lock.json'), JSON.stringify({ ...lock, commit: 'not-a-sha' }));
  assert.throws(() => f.invoke('verify'), /Invalid asset lock/);
});

test('failed state installation rolls back every installed asset and the prior state', t => {
  const f = fixture('rollback'); f.publish([['one', 'one v1', runtime], ['two', 'two v1', runtime]]); f.invoke('sync');
  const before = read(f.stateFile);
  f.publish([['one', 'one v2', runtime], ['two', 'two v2', runtime]]);
  const rename = mutableFs.renameSync;
  t.mock.method(mutableFs, 'renameSync', (source, target) => {
    if (target === f.stateFile && path.dirname(source).startsWith(path.join(f.root, '.temp/assets'))) throw new Error('Simulated state installation failure');
    return rename(source, target);
  });
  syncBuiltinESMExports();
  try { assert.throws(() => f.invoke('sync'), /Simulated state installation failure/); }
  finally { t.mock.restoreAll(); syncBuiltinESMExports(); }
  assert.equal(read(f.asset('one')), 'one v1'); assert.equal(read(f.asset('two')), 'two v1'); assert.equal(read(f.stateFile), before);
  assert.ok(fs.readdirSync(path.join(f.root, '.temp/assets')).some(name => fs.existsSync(path.join(f.root, '.temp/assets', name, 'rollback/assets/one.bin'))));
});

test('clean clone downloads selected LFS content and ignores global shared LFS storage', () => {
  const f = fixture('clone'); f.publish([['run', 'real LFS runtime payload', runtime], ['raw', 'large authoring payload', authoring]]);
  const targetRepo = path.join(path.dirname(f.repo), 'fresh-assets'), globalStorage = path.join(path.dirname(f.repo), 'shared-lfs');
  const config = path.join(path.dirname(f.repo), 'global.gitconfig');
  git(f.repo, 'config', '--file', config, `url.${pathToFileURL(f.remote).href}.insteadOf`, 'https://github.com/iceriny/keyabyss-assets.git');
  git(f.repo, 'config', '--file', config, 'lfs.storage', globalStorage);
  const result = spawnSync(process.execPath, [cli, 'sync', '--profile', 'runtime', '--root', f.root, '--repo', targetRepo], {
    encoding: 'utf8', env: { ...process.env, GIT_CONFIG_GLOBAL: config },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(read(f.asset('run')), 'real LFS runtime payload'); assert.equal(fs.existsSync(f.asset('raw')), false);
  assert.equal(fs.existsSync(globalStorage), false);
  assert.match(read(path.join(targetRepo, 'payload/raw.bin')), /^version https:\/\/git-lfs/);
  assert.equal(git(targetRepo, 'rev-parse', '--abbrev-ref', 'HEAD'), 'HEAD');
});

test.after(() => console.log(`Retained Git/LFS fixtures and recovery evidence: ${evidence}`));
