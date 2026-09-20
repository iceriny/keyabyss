import "./assets.mjs";
import "./bundle-vocab.mjs";
import { spawnSync } from 'node:child_process';
import { build } from "vite";
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
const root = fileURLToPath(new URL("../", import.meta.url));
const audioBuild = spawnSync(process.execPath, ['tools/audio.ts','build'], { cwd:root, stdio:'inherit', windowsHide:true });
if (audioBuild.status !== 0) throw Error('Audio build failed');
// Classic deferred bundle preserves file:// distribution without module CORS.
const native = await build({
  configFile: false,
  root,
  publicDir: false,
  build: {
    target: "es2022",
    write: false,
    minify: true,
    lib: {
      entry: path.join(root, "src/rendering/native-entry.ts"),
      name: "KeyAbyssBattle",
      formats: ["iife"],
    },
  },
});
const nativeCode = (Array.isArray(native) ? native[0] : native).output.find(
  (item) => item.type === "chunk",
).code;
const nativeName = `battle-renderer-${createHash("sha256").update(nativeCode).digest("hex").slice(0, 8)}.js`;
const publicAssets = path.join(root, "public/assets");
for (const file of fs.readdirSync(publicAssets))
  if (/^battle-renderer-[a-f0-9]{8}\.js$/.test(file))
    fs.unlinkSync(path.join(publicAssets, file));
fs.writeFileSync(path.join(publicAssets, nativeName), nativeCode);
process.env.VITE_BATTLE_RENDERER = `./assets/${nativeName}`;
await build({ root });
const output = path.join(root, "dist");
const source = path.join(output, "index.html");
let html = fs.readFileSync(source, "utf8");
const licenses = [
  "LICENSE",
  "licenses/Qwerty-Learner-GPL-3.0.txt",
  "licenses/CMUdict-LICENSE.txt",
  "node_modules/react/LICENSE",
  "node_modules/react-dom/LICENSE",
  "node_modules/scheduler/LICENSE",
  "node_modules/three/LICENSE",
  "node_modules/postprocessing/LICENSE.md",
  "node_modules/three.quarks/LICENSE",
  "node_modules/quarks.core/LICENSE",
  "node_modules/@floating-ui/dom/LICENSE",
  "node_modules/@floating-ui/core/LICENSE",
  "node_modules/@floating-ui/utils/LICENSE",
];
const legal = licenses
  .map(
    (file) =>
      `=== ${file} ===\n${fs.readFileSync(path.join(root, file), "utf8")}`,
  )
  .join("\n\n");
html = html.replace(
  "</body>",
  () =>
    `<script type="text/plain" id="third-party-licenses">${legal.replace(/<\/script/gi, "<\\/script")}</script></body>`,
);
if (/<script\b[^>]*\bsrc=|<link\b[^>]*rel="stylesheet"/i.test(html))
  throw Error(
    "The bootstrap must be self-contained; dictionaries load on demand",
  );
fs.writeFileSync(source, html, "utf8");
const publicRoot = path.join(root, "public");
function releaseFiles(directory) {
  return fs
    .readdirSync(directory, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) =>
      path
        .relative(directory, path.join(entry.parentPath, entry.name))
        .split(path.sep)
        .join("/"),
    )
    .sort();
}
const files = ["index.html", ...releaseFiles(publicRoot)];
const actual = releaseFiles(output);
if (JSON.stringify(actual) !== JSON.stringify([...files].sort()))
  throw Error("Release differs from public asset manifest");
const dictionaries = JSON.parse(
  fs.readFileSync(path.join(root, "data/sources.json"), "utf8"),
).books;
for (const dictionary of dictionaries) {
  const matches = files.filter(
    (name) =>
      name.startsWith(`word/vocab-${dictionary.id}-`) && name.endsWith(".js"),
  );
  if (matches.length !== 1)
    throw Error(`Missing or ambiguous dictionary asset: ${dictionary.id}`);
}
if (!files.includes(`assets/${nativeName}`))
  throw Error("Missing native renderer asset");
for (const file of files.slice(1)) {
  if (
    !fs
      .readFileSync(path.join(publicRoot, file))
      .equals(fs.readFileSync(path.join(output, file)))
  )
    throw Error(`Release asset mismatch: ${file}`);
}
const artifacts = files.map((file) => {
  const data = fs.readFileSync(path.join(output, file));
  return {
    artifact: `dist/${file}`,
    bytes: data.length,
    sha256: createHash("sha256").update(data).digest("hex"),
  };
});
fs.writeFileSync(
  path.join(root, "docs/release-sha256.json"),
  JSON.stringify(
    {
      version: JSON.parse(
        fs.readFileSync(path.join(root, "package.json"), "utf8"),
      ).version,
      artifacts,
    },
    null,
    2,
  ) + "\n",
);
console.log(
  `Offline release: ${files.length} verified files (${(artifacts.reduce((sum, item) => sum + item.bytes, 0) / 1024 / 1024).toFixed(2)} MB)`,
);
