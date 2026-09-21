import { readFileSync } from "node:fs";

const { license } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));
export const appDefine = {
  __APP_LICENSE__: JSON.stringify(license),
};
