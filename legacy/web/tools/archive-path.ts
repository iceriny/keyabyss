import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

const sessions = new Map<string, string>();

function within(parent: string, child: string): boolean {
  const relative = path.relative(parent, child);
  return relative === '' || (relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative));
}

/** Preserve a generated artifact in the repository's ignored .delete directory. */
export function archivePath(root: string, source: string, task: string): boolean {
  if (!/^[a-z0-9-]+$/.test(task)) throw Error(`Invalid archive task: ${task}`);
  const workspace = fs.realpathSync(root);
  const absolute = path.resolve(source);
  const relative = path.relative(workspace, absolute);
  const deleteRoot = path.join(workspace, '.delete');
  if (!relative || !within(workspace, absolute) || within(deleteRoot, absolute))
    throw Error(`Refusing to archive outside workspace or inside .delete: ${absolute}`);
  let stat: fs.Stats;
  try { stat = fs.lstatSync(absolute); }
  catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false; throw error; }
  if (!within(workspace, fs.realpathSync(path.dirname(absolute))))
    throw Error(`Refusing to archive through a path outside workspace: ${absolute}`);
  if (!stat.isFile() && !stat.isDirectory() && !stat.isSymbolicLink())
    throw Error(`Unsupported archive source: ${absolute}`);
  fs.mkdirSync(deleteRoot, { recursive: true });
  if (fs.realpathSync(deleteRoot) !== deleteRoot)
    throw Error(`Invalid .delete directory: ${deleteRoot}`);
  const key = `${workspace}\0${task}`;
  let session = sessions.get(key);
  if (!session) {
    session = fs.mkdtempSync(path.join(deleteRoot, `${task}-${Date.now()}-${randomUUID().slice(0, 8)}-`));
    sessions.set(key, session);
  }
  const destination = path.join(session, relative);
  if (!within(deleteRoot, destination)) throw Error(`Invalid archive destination: ${destination}`);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (fs.existsSync(destination)) throw Error(`Archive destination already exists: ${destination}`);
  fs.renameSync(absolute, destination);
  return true;
}
