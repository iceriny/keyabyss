module.exports = {
  forbidden: [
    {
      name: "ui-session-boundary",
      severity: "error",
      from: { path: "^src/ui/" },
      to: { path: "^src/(game)\\.ts$|^src/(simulation|rendering)/" },
    },
    {
      name: "headless-rules",
      severity: "error",
      from: {
        path: "^src/(simulation|content-sdk|content|contracts|shared|vocabulary)/",
      },
      to: {
        path: "^src/(ui|application|bootstrap|rendering|platform)/|^src/(game|types|loading|core)\\.ts$|node_modules/(react|react-dom|three|postprocessing)(/|$)",
      },
    },
    {
      name: "injected-content",
      severity: "error",
      from: { path: "^src/simulation/" },
      to: { path: "^src/content/" },
    },
    {
      name: "render-frame-boundary",
      severity: "error",
      from: { path: "^src/rendering/" },
      to: { path: "^src/(game|types)\\.ts$|^src/(simulation|application|ui)/" },
    },
    {
      name: "no-runtime-cycles",
      severity: "error",
      from: {},
      to: { circular: true, dependencyTypesNot: ["type-only"] },
    },
    {
      name: "no-unresolved",
      severity: "error",
      from: {},
      to: { couldNotResolve: true },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    // SWC reads TypeScript and import type directly, without the TypeScript compiler API.
    // tsPreCompilationDeps requires the legacy compiler API unavailable in TypeScript 7.
    parser: "swc",
    enhancedResolveOptions: {
      extensions: [".ts", ".tsx", ".js", ".mjs", ".json"],
    },
  },
};
