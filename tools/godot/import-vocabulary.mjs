import { createHash } from 'node:crypto';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const source = resolve(root, 'legacy/web/data');
const destination = resolve(root, 'assets/vocabulary');
const digest = (buffer) => createHash('sha256').update(buffer).digest('hex');
const sourceText = await readFile(resolve(source, 'sources.json'));
const provenance = JSON.parse(sourceText.toString('utf8'));
if (!Array.isArray(provenance.books)) throw Error('sources.json has no books array');

await mkdir(destination, { recursive: true });
const books = [];
for (const book of provenance.books) {
  if (!/^[a-z0-9-]+$/.test(book.id)) throw Error(`Invalid vocabulary id: ${book.id}`);
  const filename = `${book.id}.json`;
  const contents = await readFile(resolve(source, filename));
  const parsed = JSON.parse(contents.toString('utf8'));
  if (parsed.id !== book.id || !Array.isArray(parsed.words) || parsed.words.length !== book.count) {
    throw Error(`Source index mismatch: ${book.id}`);
  }
  await copyFile(resolve(source, filename), resolve(destination, filename));
  books.push({ id: book.id, title: book.title, count: book.count, asset_sha256: digest(contents) });
}
await copyFile(resolve(source, 'sources.json'), resolve(destination, 'sources.json'));
const index = {
  schema_version: 1,
  source: 'legacy/web/data/sources.json',
  sources_sha256: digest(sourceText),
  books,
};
await writeFile(resolve(destination, 'index.json'), `${JSON.stringify(index, null, 2)}\n`, 'utf8');
console.log(`Imported ${books.length} vocabulary snapshots into assets/vocabulary`);
