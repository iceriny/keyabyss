import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

function find7Zip() {
  const candidates = process.env.SEVEN_ZIP ? [process.env.SEVEN_ZIP] : [
    "7zz", "7z", "7za",
    ...[process.env.ProgramFiles, process.env["ProgramFiles(x86)"]]
      .filter(Boolean).map(base => path.join(base, "7-Zip", "7z.exe")),
  ];
  for (const candidate of candidates) {
    const result = spawnSync(candidate, ["i"], { stdio: "ignore", windowsHide: true });
    if (!result.error && result.status === 0) return candidate;
  }
  throw Error("7-Zip not found. Install 7-Zip and add 7z/7zz to PATH, or set SEVEN_ZIP to its executable path. dist/ is preserved.");
}

export function archiveRelease(root) {
  const executable = find7Zip();
  const { version } = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  if (!/^[\w.+-]+$/.test(version)) throw Error("Invalid release version");
  const output = path.join(root, "releases");
  fs.mkdirSync(output, { recursive: true });
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "keyabyss-archives-"));
  const run = args => {
    const result = spawnSync(executable, args, {
      cwd: path.join(root, "dist"), stdio: "inherit", windowsHide: true,
    });
    if (result.error) throw result.error;
    if (result.status !== 0) throw Error(`7-Zip failed (${result.status})`);
  };
  try {
    const names = ["7z", "zip"].map(format => {
      const name = `keyabyss-${version}.${format}`;
      const archive = path.join(temporary, name);
      // A fresh archive avoids retaining deleted files from an earlier build.
      run(["a", `-t${format}`, "-mx=5", "-y", archive, "."]);
      run(["t", archive]);
      return name;
    });
    for (const name of names) {
      fs.copyFileSync(path.join(temporary, name), path.join(output, name));
      console.log(`Release archive: releases/${name}`);
    }
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}
