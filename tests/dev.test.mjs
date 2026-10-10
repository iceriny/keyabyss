import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { capture, writeLock, digest } from '../tools/assets/capture.mjs';

const workspace = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const evidence = path.join(workspace, '.delete', 'dev-tests', randomUUID());
const env = { ...process.env, GIT_LFS_SKIP_SMUDGE: '1' };
const write = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, value); };
const read = file => fs.readFileSync(file, 'utf8');
const json = file => JSON.parse(read(file));
const git = (directory, ...args) => execFileSync('git', ['-C', directory, ...args], { env, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trim();
function identity(directory) { git(directory, 'config', 'user.email', 'dev-test@example.invalid'); git(directory, 'config', 'user.name', 'Dev Test'); git(directory, 'config', 'core.autocrlf', 'false'); }
function command(root, ...args) {
  const result = spawnSync(process.execPath, ['tools/dev.mjs', ...args], { cwd: root, env, encoding: 'utf8' });
  console.log(`Device ${root}: node tools/dev.mjs ${args.join(' ')}\n${result.stdout}${result.stderr}`);
  return result;
}
const success = result => assert.equal(result.status, 0, result.stdout + result.stderr);
const asset = (root, name = 'one') => path.join(root, `assets/audio/clips/${name}.wav`);

async function fixture(name) {
  const base = path.join(evidence, name), root = path.join(base, 'device-one/game'), repo = path.join(base, 'device-one/keyabyss-assets');
  const codeRemote = path.join(base, 'code.git'), assetRemote = path.join(base, 'assets.git');
  fs.mkdirSync(root, { recursive: true }); fs.mkdirSync(repo);
  git(base, 'init', '--bare', codeRemote); git(base, 'init', '--bare', assetRemote);
  git(root, 'init', '-b', 'main'); git(repo, 'init', '-b', 'main'); identity(root); identity(repo);
  git(repo, 'lfs', 'install', '--local');
  git(repo, 'remote', 'add', 'origin', assetRemote); git(root, 'remote', 'add', 'origin', codeRemote);
  write(path.join(repo, '.gitattributes'), '*.wav filter=lfs diff=lfs merge=lfs -text\n');
  for (const relative of ['tools/dev.mjs', 'tools/assets/assets.mjs', 'tools/assets/capture.mjs', 'tools/assets/private-paths.json']) {
    const target = path.join(root, relative); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.copyFileSync(path.join(workspace, relative), target);
  }
  write(path.join(root, '.gitignore'), '.temp/\n.delete/\nassets/audio/clips/\ndevelopment/audio_library/clips/\ndevelopment/audio_library/.build.json\n');
  write(path.join(root, 'game.js'), 'public code v1\n');
  write(asset(root, 'one'), 'shared initial sound'); write(asset(root, 'two'), 'shared initial sound');
  write(path.join(root, 'development/audio_library/clips/library.wav'), 'library initial sound');
  write(path.join(root, 'development/audio_library/.build.json'), '{"recipe":1}\n');
  await capture(root, repo); git(repo, 'add', '--all'); git(repo, 'commit', '-m', 'initial assets'); git(repo, 'push', '-u', 'origin', 'main');
  git(assetRemote, 'symbolic-ref', 'HEAD', 'refs/heads/main');
  await writeLock(root, repo); git(root, 'add', '--all'); git(root, 'commit', '-m', 'initial code'); git(root, 'push', '-u', 'origin', 'main');
  git(codeRemote, 'symbolic-ref', 'HEAD', 'refs/heads/main');
  success(command(root, 'setup'));
  function cloneDevice(label) {
    const directory = path.join(base, label), game = path.join(directory, 'game'), assets = path.join(directory, 'keyabyss-assets');
    fs.mkdirSync(directory); git(base, '-c', 'core.autocrlf=false', 'clone', codeRemote, game); git(base, '-c', 'core.autocrlf=false', 'clone', assetRemote, assets); identity(game); identity(assets);
    git(assets, 'lfs', 'install', '--local'); return { root: game, repo: assets };
  }
  return { base, root, repo, codeRemote, assetRemote, cloneDevice };
}

test('one-command push publishes private LFS and the public lock; setup/pull restores another device; no-op push stays unchanged', async () => {
  const f = await fixture('handoff'), second = f.cloneDevice('device-two');
  success(command(second.root, 'setup'));
  const initialCatalog = json(path.join(f.repo, 'catalog.json'));
  const initialOne = initialCatalog.entries.find(entry => entry.destination.endsWith('/one.wav'));
  const initialTwo = initialCatalog.entries.find(entry => entry.destination.endsWith('/two.wav'));
  assert.equal(initialOne.path, initialTwo.path);
  write(asset(f.root), 'changed sound on first device'); write(path.join(f.root, 'game.js'), 'public code v2\n');
  success(command(f.root, 'push', 'sound and code together'));
  const lock = json(path.join(f.root, 'asset-lock.json')), commit = git(f.assetRemote, 'rev-parse', 'main');
  assert.equal(lock.commit, commit); assert.equal(lock.catalog_sha256, digest(execFileSync('git', ['-C', f.repo, 'show', `${commit}:catalog.json`])));
  const catalog = json(path.join(f.repo, 'catalog.json')), one = catalog.entries.find(entry => entry.destination.endsWith('/one.wav')), two = catalog.entries.find(entry => entry.destination.endsWith('/two.wav'));
  assert.notEqual(one.path, two.path); assert.equal(two.sha256, digest(Buffer.from('shared initial sound')));
  assert.equal(read(path.join(f.repo, two.path)), 'shared initial sound');
  const object = path.join(f.assetRemote, 'lfs/objects', one.sha256.slice(0, 2), one.sha256.slice(2, 4), one.sha256);
  assert.equal(read(object), 'changed sound on first device');
  assert.equal(JSON.parse(git(f.codeRemote, 'show', 'main:asset-lock.json')).commit, commit);
  success(command(second.root, 'pull'));
  assert.equal(read(asset(second.root)), 'changed sound on first device'); assert.equal(read(asset(second.root, 'two')), 'shared initial sound');
  assert.equal(read(path.join(second.root, 'game.js')), 'public code v2\n');
  const third = f.cloneDevice('device-three'); success(command(third.root, 'setup'));
  assert.equal(read(asset(third.root)), 'changed sound on first device');
  const beforeCode = git(f.codeRemote, 'rev-parse', 'main'), beforeAssets = git(f.assetRemote, 'rev-parse', 'main');
  success(command(second.root, 'push', 'nothing changed'));
  assert.equal(git(f.codeRemote, 'rev-parse', 'main'), beforeCode); assert.equal(git(f.assetRemote, 'rev-parse', 'main'), beforeAssets);
});

test('remote code ahead blocks push before asset publication; local private modifications block pull before moving the code lock', async () => {
  const f = await fixture('conflicts'), second = f.cloneDevice('device-two'); success(command(second.root, 'setup'));
  write(path.join(second.root, 'game.js'), 'other device code\n'); success(command(second.root, 'push', 'other device advance'));
  const beforeAssets = git(f.assetRemote, 'rev-parse', 'main'), beforeCode = git(f.root, 'rev-parse', 'HEAD');
  write(asset(f.root), 'local private work');
  const pushed = command(f.root, 'push', 'must reject remote ahead');
  assert.notEqual(pushed.status, 0); assert.match(pushed.stdout + pushed.stderr, /Remote main has changes/);
  assert.equal(git(f.assetRemote, 'rev-parse', 'main'), beforeAssets); assert.equal(git(f.root, 'rev-parse', 'HEAD'), beforeCode);
  const beforeLock = read(path.join(f.root, 'asset-lock.json')), pulled = command(f.root, 'pull');
  assert.notEqual(pulled.status, 0); assert.match(pulled.stdout + pulled.stderr, /Modified asset: assets\/audio\/clips\/one.wav/);
  assert.equal(git(f.root, 'rev-parse', 'HEAD'), beforeCode); assert.equal(read(path.join(f.root, 'asset-lock.json')), beforeLock);
  assert.equal(read(asset(f.root)), 'local private work');
});

test.after(() => console.log(`Retained local Git/LFS workflow fixtures: ${evidence}`));
