import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = new URL('../', import.meta.url);
const manifest = new URL('data/font-build.json', root);
if (!fs.existsSync(manifest)) throw Error('Missing packaged fonts. Run npm run fonts:build.');
const fonts = JSON.parse(fs.readFileSync(manifest, 'utf8'));
for (const font of fonts) {
  for (const [relative, expected] of [[font.source, font.sourceSha256], [`public/${font.file}`, font.sha256]]) {
    const file = new URL(relative, root);
    if (!fs.existsSync(file) || createHash('sha256').update(fs.readFileSync(file)).digest('hex') !== expected)
      throw Error(`Font changed or missing: ${fileURLToPath(file)}. Run npm run fonts:build.`);
  }
}
console.log(`Fonts verified: ${fonts.length} complete WOFF2 files / ${(fonts.reduce((n, f) => n + f.bytes, 0) / 1048576).toFixed(2)} MiB.`);
