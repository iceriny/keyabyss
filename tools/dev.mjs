// One command per device handoff. Git credentials remain in Git's credential helper.
import { readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { capture, writeLock, git } from './assets/capture.mjs';

const root = path.resolve(import.meta.dirname, '..');
const repo = path.resolve(root, '../keyabyss-assets');
const run = (command, args, cwd = root) => {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status}); see output above.`);
};
const sync = profile => run(process.execPath, ['tools/assets/assets.mjs', 'sync', '--profile', profile]);
function requireCurrent(directory) {
  run('git', ['fetch', 'origin'], directory);
  const branch = git(directory, ['symbolic-ref', '--short', 'HEAD']);
  const remote = git(directory, ['for-each-ref', '--format=%(objectname)', `refs/remotes/origin/${branch}`]);
  if (remote && git(directory, ['merge-base', 'HEAD', remote]) !== remote)
    throw new Error(`Remote ${branch} has changes. Run node tools/dev.mjs pull before pushing.`);
  return branch;
}
async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'pull') {
    if (git(root, ['status', '--porcelain'])) throw new Error('Commit local code first with node tools/dev.mjs push "message" before switching devices.');
    // Check ignored managed assets before moving the code lock to another version.
    const lock = JSON.parse(await readFile(path.join(root, 'asset-lock.json'), 'utf8'));
    const catalog = JSON.parse(git(repo, ['show', `${lock.commit}:catalog.json`]));
    const { digest } = await import('./assets/capture.mjs');
    for (const entry of catalog.entries) {
      let bytes;
      try { bytes = await readFile(path.join(root, entry.destination)); }
      catch (e) { if (e.code === 'ENOENT') continue; throw e; }
      if (digest(bytes) !== entry.sha256) throw new Error(`Modified asset: ${entry.destination}. Push your changes first.`);
    }
    run('git', ['pull', '--ff-only']);
    const index = args.indexOf('--profile');
    let profile = index >= 0 ? args[index + 1] : 'authoring';
    if (index < 0) {
      try { profile = JSON.parse(await readFile(path.join(root, '.temp/assets/state.json'), 'utf8')).profile ?? profile; }
      catch (e) { if (e.code !== 'ENOENT') throw e; }
    }
    sync(profile);
    return;
  }
  if (command === 'setup') { sync(args[0] ?? 'authoring'); return; }
  if (command !== 'push' || !args.join(' ').trim()) throw new Error('Usage: node tools/dev.mjs setup [runtime|library|authoring] | pull [--profile name] | push "commit message"');
  const message = args.join(' ');
  const branch = requireCurrent(root);
  if (git(repo, ['status', '--porcelain'])) throw new Error('Asset repository has direct edits. Commit and push them there, then update the code lock before using this shortcut.');
  run('git', ['fetch', 'origin'], repo);
  const locked = JSON.parse(await readFile(path.join(root, 'asset-lock.json'), 'utf8'));
  const assetMain = git(repo, ['rev-parse', 'origin/main']);
  if (locked.commit !== assetMain) throw new Error('Asset main advanced independently. Resolve that asset update before publishing; see docs/GIT-AND-ASSETS.md.');
  run('git', ['checkout', 'main'], repo);
  run('git', ['merge', '--ff-only', 'origin/main'], repo);
  if (git(repo, ['rev-parse', 'HEAD']) !== assetMain)
    throw new Error('Asset main has unpublished commits. Finish that asset change before publishing the workspace.');
  await capture(root, repo);
  run('git', ['add', '--all'], repo);
  if (git(repo, ['diff', '--cached', '--name-only'])) run('git', ['commit', '-m', message], repo);
  // Git LFS's pre-push hook uploads binaries before the Git reference advances.
  run('git', ['lfs', 'push', 'origin', 'main'], repo);
  run('git', ['push', 'origin', 'main'], repo);
  await writeLock(root, repo);
  let profile = 'authoring';
  try { profile = JSON.parse(await readFile(path.join(root, '.temp/assets/state.json'), 'utf8')).profile ?? profile; }
  catch (e) { if (e.code !== 'ENOENT') throw e; }
  sync(profile);
  run('git', ['add', '--all']);
  if (git(root, ['diff', '--cached', '--name-only'])) run('git', ['commit', '-m', message]);
  run('git', ['push', '--set-upstream', 'origin', branch]);
  console.log('Code and pinned assets uploaded. On the other device: node tools/dev.mjs pull');
}
main().catch(error => { console.error(error.stack); process.exitCode = 1; });
