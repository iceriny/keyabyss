import { readFileSync } from "node:fs";

const { version, license } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
export const appDefine = {
  __APP_VERSION__: JSON.stringify(version),
  __APP_LICENSE__: JSON.stringify(license),
};
