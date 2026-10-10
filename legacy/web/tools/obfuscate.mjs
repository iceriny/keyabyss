import JavaScriptObfuscator from "javascript-obfuscator";

// Keep frame-loop work and the offline, classic-script entry points intact.
// A fixed seed makes content hashes reproducible for identical inputs.
export function obfuscate(code) {
  return JavaScriptObfuscator.obfuscate(code, {
    target: "browser-no-eval",
    seed: 60921,
    compact: true,
    identifierNamesGenerator: "hexadecimal",
    renameGlobals: false,
    renameProperties: false,
    stringArray: false,
    controlFlowFlattening: false,
    deadCodeInjection: false,
    debugProtection: false,
    disableConsoleOutput: false,
    selfDefending: false,
    simplify: true,
    sourceMap: false,
  }).getObfuscatedCode();
}
