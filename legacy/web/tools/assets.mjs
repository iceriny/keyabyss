import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assets } from "../src/content/assets.ts";
const root = fileURLToPath(new URL("../", import.meta.url));
const publicRoot = path.join(root, "public");
const ids = new Set();
for (const asset of assets) {
  if (ids.has(asset.id)) throw Error(`Duplicate external asset ${asset.id}`);
  ids.add(asset.id);
  const source = path.resolve(root, asset.source),
    target = path.resolve(publicRoot, asset.src);
  if (!source.startsWith(root) || !target.startsWith(publicRoot + path.sep))
    throw Error("Asset path outside project");
  if (!fs.statSync(source).isFile())
    throw Error(`Missing external asset ${source}`);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  if (
    !fs.existsSync(target) ||
    !fs.readFileSync(source).equals(fs.readFileSync(target))
  )
    fs.copyFileSync(source, target);
}
console.log(`Prepared ${assets.length} external assets from art sources.`);
